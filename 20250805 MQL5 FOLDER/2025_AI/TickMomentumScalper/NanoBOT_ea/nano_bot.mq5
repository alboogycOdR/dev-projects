//+------------------------------------------------------------------+
//|                                                      Nanobot.mq5 |
//|                                  Copyright 2023, Your Name/Company |
//|                                              https://www.yourlink.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.yourlink.com"
#property version   "1.02" // Version updated for BE logic
#property description "Nanobot EA: Manual entry grid system with partial recovery and BE."
#property strict


/*
Areas for Potential Refinement / Clarification / More Robustness (Consider these Phase 2 or advanced features):
ATR Take Profit (CheckAnchorOnlyTP): The current implementation uses open_price +/- atr_value. You might want to add a user input (InpAnchorOnlyTPATRMultiplier) to make it open_price +/- atr_value * multiplier for more flexibility.
Hedging Account Compatibility: The code heavily relies on Position... functions and PositionClosePartial, which are primarily suited for Netting accounts. If this EA needs to run on a Hedging account, significant changes are required. You'd need to track orders explicitly, manage opposite order closures (potentially via OrderCloseBy), and handle partial closing by opening smaller offsetting orders or closing parts of specific order tickets if the broker supports it via OrderSend modifications. This is a major potential incompatibility if hedging is required.
Error Handling in Sequences: While basic result checks are done after individual trade actions, complex sequences like HandleSLHitEvent could partially fail due to network errors, requotes, or context busy issues. For example, if the SL closes some positions, but the EA fails to close positions N and N-1 immediately after, the system state will be inconsistent. Adding more robust retry logic or state recovery mechanisms would enhance resilience but significantly increases complexity.
Timeframe / Symbol Changes: While basic handle revalidation can be added, a full re-initialization or state recalculation might be safer if the user frequently changes the chart's timeframe or symbol while the EA is active with open positions/orders.
OrderCalcProfit Accuracy: Relying on OrderCalcProfit for the PartialCloseAnchor decision is generally okay for estimation, but be aware that live swap and commission applied at the moment of closure might differ slightly, potentially leading to a situation where the available profit barely covers the loss, and the actual closure results in a tiny unexpected net loss from that step.
Resource Management (CList): While delete is used, ensure all code paths correctly clean up allocated CList and PositionInfo objects, especially in error conditions, to prevent memory leaks over long-term operation. Consider using std::vector<PositionInfo> from the Standard Library (if MQL5 supports it adequately now) or smart pointers for more automatic memory management if preferred.
Stops Level Dynamic Check: The PlaceInitialPendingOrders and MaintainPendingOrderCount functions check the stops level at the time of placement. If the stops level changes dynamically while the order is pending, the pending order might become invalid later. This is usually less critical for limit orders far from the market but could be relevant.



Strategy Tester: Test extensively!
Use Visual Mode to watch order placements, SL movements, and closures.
Test different symbols and timeframes.
Test scenarios:
Price moves against anchor -> Grid builds -> Price reverses -> SL hit -> Recovery works?
Price moves against anchor -> Grid builds -> Price reverses -> Compound Profit hit -> Closes?
Price moves with anchor -> Anchor TP hit?
System SL hit?
Manual close button?
Rapid price changes / Gaps.
Start/Stop EA with positions open.



Chart Controls: Added Label, Edit Box, Sell Button, and Close Button with positioning logic. Includes basic validation on lot size input.
OpenAnchorPosition: Implemented logic to read lots, validate, open the position using CTrade, store the ticket, and immediately call PlaceInitialPendingOrders.
PlaceInitialPendingOrders: Calculates levels based on Spread + ATR distance from the previous level (starting at anchor price). Uses BUY_LIMIT / SELL_LIMIT. Includes basic check against broker stops level.
DeleteAllPendingOrders: Loops through orders and deletes matching ones.
CheckSystemSL: Calculates floating P/L of all positions for the magic/symbol, compares loss to account equity, and calls CloseEntireSystem if threshold breached.
CheckAnchorOnlyTP: Implements logic for both Points TP (priority) and ATR TP. Closes the anchor if TP is hit. Includes a call to DeleteAllPendingOrders when TP closes the anchor.
CheckCompoundProfit: Calculates separate profit/loss sums, computes ROI, and calls CloseEntireSystem if threshold reached. Handles the zero-loss case.
ManageOppositeStopLosses: Uses a CList to gather opposite positions, sorts them by time, identifies the correct SL level (price of N-2), and modifies SL for positions 1 to N-2 using trade.PositionModify. Uses dynamic memory (new/delete) for the list and nodes, ensure correct cleanup.
*/
//--- Include standard libraries
#include <Trade\Trade.mqh> // Include the CTrade class for simplified trading
#include <Arrays\List.mqh>     // For sorting positions/orders
#include <Arrays\ArrayObj.mqh>
//--- Input parameters
// --- Enum for System State ---
enum ENUM_SYSTEM_STATE {
   STATE_NO_ANCHOR,
   STATE_ANCHOR_ONLY,
   STATE_ANCHOR_WITH_OPPOSITES
};


// Structure to hold position info for sorting/management
class PositionInfo : public CObject {
public:
   long           ticket;
   double         open_price;
   double         volume;
   datetime       open_time;
   ENUM_POSITION_TYPE type;
   double         current_sl; // Store SL for comparison

   PositionInfo()
   {
      ticket = 0;
      open_price = 0.0;
      volume = 0.0;
      open_time = 0;
      type = POSITION_TYPE_BUY;
      current_sl = 0.0;
   }

   // --- Add Compare method here ---
   virtual int Compare(const CObject* node, int mode = 0) const override
   {
      const PositionInfo* other = (const PositionInfo*)node; // Cast node to compare against
      if(other == NULL) return 0; // Or handle error/comparison logic as needed
      // Primary sort by open time
      if(this.open_time < other.open_time) return -1;
      if(this.open_time > other.open_time) return 1;
      // Secondary sort by ticket (tie-breaker)
      if(this.ticket < other.ticket) return -1;
      if(this.ticket > other.ticket) return 1;
      return 0; // Objects are considered equal for sorting purposes
   }
   // --- End of added Compare method ---
};
// Custom comparator for PositionInfo sorting by time - REMOVE THIS CLASS
// class ComparePositionInfoByTime // Removed inheritance from CObject
// { ... deleted ... };
datetime    g_last_sl_hit_check_time = 0;       // Time of last SL hit deal check
// Identification
sinput group           "Identification"
sinput long            InpMagicNumber              = 15151;         // Magic Number

// Pending Order Settings
sinput group           "Pending Orders"
sinput int             InpPendingOrderSpacingATRPeriod = 14;        // ATR Period for Spacing Calculation
sinput double          InpPendingOrderSizeFactor   = 3.0;          // Pending Order Size (% of Anchor)
sinput int             InpPendingOrderCount        = 6;            // Number of Pending Orders to Maintain

// Closing Conditions
sinput group           "Closing Conditions"
sinput double          InpSystemStopLossPercent    = 2.0;           // System Stop Loss (% of Equity, 0=disabled)
sinput int             InpAnchorOnlyTPPoints       = 100;           // Anchor TP in Points (0=disabled, Priority 1)
sinput int             InpAnchorOnlyTPATRPeriod    = 21;            // Anchor TP ATR Period (0=disabled, Priority 2)
// sinput double          InpAnchorOnlyTPATRMultiplier = 1.0;       // Anchor TP ATR Multiplier (Add if needed)
sinput double          InpCompoundProfitPercent    = 25.0;          // Compound Profit ROI % (0=disabled)

// Trading Settings
sinput group           "Trading Settings"
sinput uint            InpSlippage                 = 5;             // Slippage in points

// Chart Controls Display
sinput group           "Chart Controls"
sinput bool            InpShowChartControls        = true;          // Show Chart Control Panel
sinput ENUM_BASE_CORNER InpControlCorner            = CORNER_RIGHT_LOWER;// Corner for controls
sinput int             InpControlOffsetX           = 10;            // X offset from corner
sinput int             InpControlOffsetY           = 30;            // Y offset from corner

//--- Global variables
CTrade      trade;                       // Trading object instance
string      g_chart_prefix;              // Unique prefix for chart objects
int         g_atr_handle_spacing = INVALID_HANDLE; // Handle for spacing ATR
int         g_atr_handle_tp      = INVALID_HANDLE; // Handle for TP ATR
long        g_anchor_ticket      = 0;              // Ticket of the current anchor position
double      g_tally_profit       = 0.0;            // Profit/Loss from SL hit event
int         g_points_digits      = 0;              // Number of digits after decimal for points
double      g_point_value        = 0;              // Value of 1 point
int         g_required_bars_spacing = 0;        // Bars needed for spacing ATR
int         g_required_bars_tp = 0;             // Bars needed for TP ATR


//--- Chart Object Names (using prefix for uniqueness)
#define ID_PANEL_BG     "_PanelBG"
#define ID_BUTTON_BUY   "_ButtonBuy"
#define ID_BUTTON_SELL  "_ButtonSell"
#define ID_EDIT_LOTS    "_EditLots"
#define ID_BUTTON_CLOSE "_ButtonClose"
#define ID_LABEL_LOTS   "_LabelLots"
#define ID_LABEL_STATUS "_LabelStatus" // Example for status display
// ... (Includes, Inputs, Globals - mostly unchanged) ...
// Add a definition for clarity
#define BE_LEVEL_OFFSET_POINTS 1 // Optional: Move SL 1 point into profit instead of exactly BE
//+------------------------------------------------------------------+
//| Creates the on-chart control panel                             |
//+------------------------------------------------------------------+
void AddChartControls()
{
   RemoveChartControls(); // Clear previous first
   // Define starting position and spacing for controls
   int x_start = InpControlOffsetX;
   int y_start = InpControlOffsetY;
   int x = x_start;
   int y = y_start;
   // Define control dimensions - local defines are fine here
#define CTRL_WIDTH 65
#define CTRL_HEIGHT 20
#define CTRL_SPACING_X 5
#define CTRL_SPACING_Y 5
   // Optional background Panel - Uncomment and adjust size/color if desired
   /*
   int panel_width = (CTRL_WIDTH * 2 + 40 + CTRL_SPACING_X * 3); // Example width based on elements below
   int panel_height = (CTRL_HEIGHT * 3 + CTRL_SPACING_Y * 4); // Example height
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_XDISTANCE, x);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_YDISTANCE, y);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_XSIZE, panel_width);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_YSIZE, panel_height);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_CORNER, InpControlCorner);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_BGCOLOR, clrLightSteelBlue); // Or another color
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_SELECTABLE, false);
       ObjectSetInteger(ChartID(), g_chart_prefix + ID_PANEL_BG, OBJPROP_BACK, true); // Send to back
       // Adjust start coords if using panel border/padding
       // x += CTRL_SPACING_X;
       // y += CTRL_SPACING_Y;
   }
   */
   // --- First Row: Lots Label and Edit Box ---
   x = x_start; // Reset X for the row
   // Create Label for Lots
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJ_LABEL, 0, 0, 0)) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_XDISTANCE, x+100);
      // Adjust Y distance slightly to vertically center label text with edit box
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_YDISTANCE, y + 4);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_CORNER, InpControlCorner);
      ObjectSetString(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_TEXT, "Lots:");
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_LOTS, OBJPROP_COLOR, clrBlack); // Set text color
   }
   else {
      Print("Nanobot Error: Failed to create Lots label! Error ", GetLastError());
   }
   x += 40; // Allocate space for the "Lots:" text
   // Create Edit Box for Lots
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJ_EDIT, 0, 0, 0)) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_XDISTANCE, x+100);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_XSIZE, CTRL_WIDTH);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_YSIZE, CTRL_HEIGHT);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_CORNER, InpControlCorner);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_BORDER_COLOR, clrGray); // Add border
      ObjectSetString(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_TEXT, DoubleToString(NormalizeVolume(0.1), 2)); // Default lot size
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_ALIGN, ALIGN_CENTER); // Center text
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_READONLY, false); // Editable initially
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_SELECTABLE, true);
   }
   else {
      Print("Nanobot Error: Failed to create Lots edit box! Error ", GetLastError());
   }
   // --- Second Row: Buy and Sell Buttons ---
   y += CTRL_HEIGHT + CTRL_SPACING_Y; // Move Y down to the next row
   x = x_start; // Reset X coordinate for the new row
   // Create Buy Button (using code structure from your provided file)
   if(!ObjectCreate(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJ_BUTTON, 0, 0, 0)) {
      Print("Nanobot Error: Failed to create Buy button! Error ", GetLastError());
   }
   else {
      // *** Shift 20 pixels left ***
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_XDISTANCE, x + 100); // Position at start of row minus 20px
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_XSIZE, CTRL_WIDTH); // Use defined width
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_YSIZE, CTRL_HEIGHT); // Use defined height
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_CORNER, InpControlCorner);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_BGCOLOR, clrLightGreen);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_BORDER_COLOR, clrGray); // Ensure border color is set
      ObjectSetString(ChartID(),  g_chart_prefix + ID_BUTTON_BUY, OBJPROP_TEXT, "Buy");
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_STATE, false); // Initial state (unpressed)
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_SELECTABLE, true); // Selectable initially
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_SELECTED, false);
   }
   x += CTRL_WIDTH + CTRL_SPACING_X; // Move X past the Buy button and spacing
   // Create Sell Button
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJ_BUTTON, 0, 0, 0)) {
      // *** Shift 20 pixels left ***
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_XDISTANCE, x+ 100); // Position next to Buy minus 20px
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_XSIZE, CTRL_WIDTH);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_YSIZE, CTRL_HEIGHT);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_CORNER, InpControlCorner);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_BGCOLOR, clrPink);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_BORDER_COLOR, clrGray); // Add border
      ObjectSetString(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_TEXT, "Sell");
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_STATE, false); // Initial state (unpressed)
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_SELECTABLE, true); // Selectable initially
   }
   else {
      Print("Nanobot Error: Failed to create Sell button! Error ", GetLastError());
   }
   // --- Third Row: Close Button ---
   y += CTRL_HEIGHT + CTRL_SPACING_Y; // Move Y down to the next row
   x = x_start; // Reset X
   // Calculate width and position for Close button (e.g., span two button widths + spacing)
   int close_button_width = CTRL_WIDTH * 2 + CTRL_SPACING_X;
   // Position it centered below the Buy/Sell buttons
   int close_button_x = x_start; // Start at the same X as the Buy button row
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJ_BUTTON, 0, 0, 0)) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_XDISTANCE, close_button_x+170);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_XSIZE, close_button_width);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_YSIZE, CTRL_HEIGHT);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_CORNER, InpControlCorner);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_BGCOLOR, clrLightGray);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_BORDER_COLOR, clrGray); // Add border
      ObjectSetString(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_TEXT, "Close System");
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_STATE, true); // Initial state (pressed/disabled look)
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_SELECTABLE, false); // Initially non-selectable
   }
   else {
      Print("Nanobot Error: Failed to create Close button! Error ", GetLastError());
   }
   // --- Optional Status Label ---
   /*
   y += CTRL_HEIGHT + CTRL_SPACING_Y; // Move Y down
   x = x_start;
   if(ObjectCreate(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJ_LABEL, 0, 0, 0)) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_CORNER, InpControlCorner);
      ObjectSetString(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_TEXT, "Status: Initializing...");
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_COLOR, clrDimGray);
   } else {
       Print("Nanobot Error: Failed to create Status label! Error ", GetLastError());
   }
   */
   ChartRedraw(ChartID()); // Redraw once after attempting to create all controls
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveChartControls()
{
   // Delete objects by name - Use tolerance for errors (object might already be gone)
   ObjectDelete(ChartID(), g_chart_prefix + ID_BUTTON_BUY);
   ObjectDelete(ChartID(), g_chart_prefix + ID_BUTTON_SELL);
   ObjectDelete(ChartID(), g_chart_prefix + ID_EDIT_LOTS);
   ObjectDelete(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE);
   ObjectDelete(ChartID(), g_chart_prefix + ID_LABEL_LOTS);
   ObjectDelete(ChartID(), g_chart_prefix + ID_LABEL_STATUS);
   ObjectDelete(ChartID(), g_chart_prefix + ID_PANEL_BG); // Delete background last if used
   ChartRedraw(ChartID());
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize CTrade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetAsyncMode(false); // Using synchronous for SL hit handling sequences
   //--- Generate unique prefix for chart objects
   g_chart_prefix = "NanoBot_" + IntegerToString(InpMagicNumber) + "_" + IntegerToString(ChartID()) + "_";
   //--- Check inputs sanity
   if(InpPendingOrderSizeFactor <= 0 || InpPendingOrderSizeFactor >= 100) {
      Alert("Nanobot Error: Pending Order Size Factor (%) must be between 0 and 100.");
      return(INIT_FAILED);
   }
   if(InpPendingOrderCount <= 0) {
      Alert("Nanobot Error: Pending Order Count must be greater than 0.");
      return(INIT_FAILED);
   }
   if(InpPendingOrderSpacingATRPeriod <=0) {
      Alert("Nanobot Error: Pending Order Spacing ATR Period must be > 0.");
      return(INIT_FAILED);
   }
   //--- Calculate required bars for ATR indicators
   g_required_bars_spacing = InpPendingOrderSpacingATRPeriod + 1;
   g_required_bars_tp = InpAnchorOnlyTPATRPeriod > 0 ? InpAnchorOnlyTPATRPeriod + 1 : 0;
   //--- Initialize ATR Handles
   g_atr_handle_spacing = iATR(_Symbol, _Period, InpPendingOrderSpacingATRPeriod);
   if(g_atr_handle_spacing == INVALID_HANDLE) {
      Alert("Nanobot Error: Failed to create ATR indicator handle for spacing. Error ", GetLastError());
      return(INIT_FAILED); // Critical for placing orders
   }
   // Only initialize TP ATR if ATR TP is active and Point TP is not (or handle priorities later)
   if(InpAnchorOnlyTPATRPeriod > 0 && InpAnchorOnlyTPPoints <= 0) {
      g_atr_handle_tp = iATR(_Symbol, _Period, InpAnchorOnlyTPATRPeriod);
      if(g_atr_handle_tp == INVALID_HANDLE) {
         Alert("Nanobot Warning: Failed to create ATR handle for TP. ATR TP disabled. Error ", GetLastError());
         // Non-critical if point TP exists or TP is disabled
      }
   }
   else {
      g_atr_handle_tp = INVALID_HANDLE; // Ensure it's invalid if not used
   }
   //--- Get point size and calculate appropriate digits for price normalization
   g_point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   // Adjust g_points_digits for TP/SL calculations - Forex often needs 3/5, others raw digits
   g_points_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE) == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE ? digits :
                     (StringFind(_Symbol,"JPY")>=0 ? 3 : 5);
   //--- Create Chart Controls if enabled
   if(InpShowChartControls) {
      AddChartControls(); // Calls the function to create buttons etc.
   }
   //--- Reset Anchor Ticket and check history
   g_anchor_ticket = 0;
   FindAnchorPosition(); // Check if an anchor already exists
   //--- Set initial time for history check
   g_last_sl_hit_check_time = TimeCurrent();
   //--- Set initial display state AFTER finding anchor
   if(InpShowChartControls) {
      UpdateChartControlsState();
   }
   //--- Initialization successful message
   Print("Nanobot EA Initialized . BE Logic Added. Magic: ", InpMagicNumber, " Symbol: ", _Symbol);
   return(INIT_SUCCEEDED);
}



//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(g_atr_handle_spacing != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle_spacing);
   if(g_atr_handle_tp != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle_tp);
   //--- Remove chart controls
   if(InpShowChartControls)
      RemoveChartControls();
   //--- Final print message
   Print("Nanobot EA Deinitialized. Reason code: ", reason);
   Comment(""); // Clear any chart comment
   ChartRedraw();
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateStatusLabel(ENUM_SYSTEM_STATE state)
{
   string status_text = "Status: ";
   switch(state) {
   case STATE_NO_ANCHOR:
      status_text += "Idle";
      break;
   case STATE_ANCHOR_ONLY:
      status_text += "Anchor Open";
      break;
   case STATE_ANCHOR_WITH_OPPOSITES:
      status_text += "Grid Active";
      break;
   }
   // TODO: Add P/L, ROI etc. if desired
   // ObjectSetString(ChartID(), g_chart_prefix + ID_LABEL_STATUS, OBJPROP_TEXT, status_text);
   // ChartRedraw(ChartID());
   Comment(status_text); // Using Comment for simplicity now
}
//+------------------------------------------------------------------+
//| Updates the enabled/disabled state of chart controls             |
//+------------------------------------------------------------------+
void UpdateChartControlsState()
{
   // Check if controls are meant to be shown at all
   if(!InpShowChartControls) return;
   // Determine if an anchor position managed by this EA instance currently exists.
   // Re-check the anchor ticket just to be absolutely sure the state is current.
   if(g_anchor_ticket != 0) {
      // If we think an anchor exists, verify it still exists
      if(!PositionSelectByTicket(g_anchor_ticket)) {
         // Anchor might have been closed externally or by another part of the EA,
         // try to find it again just in case state desynchronized.
         if (!FindAnchorPosition()) {
            // It's definitely gone now.
            g_anchor_ticket = 0;
         }
      }
      // After verification, check the ticket again
      bool anchor_exists = (g_anchor_ticket != 0);
   }
   else {
      // If we think no anchor exists, try to find one just in case
      // EA was restarted or state desynchronized.
      FindAnchorPosition();
      bool anchor_exists = (g_anchor_ticket != 0);
   }
   // Now use the reliably checked 'anchor_exists' status
   bool anchor_exists = (g_anchor_ticket != 0);
   // --- Update Edit Box (Lots) ---
   // If anchor exists, make it read-only and grey; otherwise, editable and white.
   // Use ObjectSetInteger because OBJPROP_READONLY is boolean but set via integer (0/1).
   // Use ObjectSetInteger for color properties too.
   if(ObjectFind(ChartID(), g_chart_prefix + ID_EDIT_LOTS) >= 0) { // Check if object exists before setting properties
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_READONLY, anchor_exists);
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_BGCOLOR, anchor_exists ? clrLightGray : clrWhite);
   }
   // --- Update Buy/Sell Buttons ---
   // If anchor exists, disable Buy/Sell buttons (show pressed state, make non-selectable).
   // If no anchor exists, enable Buy/Sell buttons (show unpressed state, make selectable).
   if(ObjectFind(ChartID(), g_chart_prefix + ID_BUTTON_BUY) >= 0) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_STATE, anchor_exists);      // true (pressed) if anchor exists
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_BUY, OBJPROP_SELECTABLE, !anchor_exists); // selectable only if NO anchor
   }
   if(ObjectFind(ChartID(), g_chart_prefix + ID_BUTTON_SELL) >= 0) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_STATE, anchor_exists);     // true (pressed) if anchor exists
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_SELL, OBJPROP_SELECTABLE, !anchor_exists);// selectable only if NO anchor
   }
   // --- Update Close Button ---
   // If anchor exists, enable the Close button (show unpressed/active state, make selectable).
   // If no anchor exists, disable the Close button (show pressed/inactive state, make non-selectable).
   if(ObjectFind(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE) >= 0) {
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_STATE, !anchor_exists);     // false (unpressed) if anchor exists
      ObjectSetInteger(ChartID(), g_chart_prefix + ID_BUTTON_CLOSE, OBJPROP_SELECTABLE, anchor_exists); // selectable only if anchor EXISTS
   }
   // --- Request chart redraw to apply visual changes ---
   ChartRedraw(ChartID());
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Basic checks before processing tick
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return; // Trading not allowed
   if(IsStopped()) // Check if EA was stopped from chart context menu
      return;
   //--- Check for sufficient bars
   if (Bars(_Symbol, _Period) < MathMax(g_required_bars_spacing, g_required_bars_tp))
      return; // Not enough bars for indicators
   //--- Ensure ATR handles are still valid (e.g., after timeframe change) - Reinitialize if needed
   // Basic check: if needed, add more robust re-initialization logic
   if(InpPendingOrderSpacingATRPeriod > 0 && g_atr_handle_spacing == INVALID_HANDLE) {
      g_atr_handle_spacing = iATR(_Symbol, _Period, InpPendingOrderSpacingATRPeriod);
      if (g_atr_handle_spacing == INVALID_HANDLE) return; // Failed to reinit
   }
   if(InpAnchorOnlyTPATRPeriod > 0 && InpAnchorOnlyTPPoints <= 0 && g_atr_handle_tp == INVALID_HANDLE) {
      g_atr_handle_tp = iATR(_Symbol, _Period, InpAnchorOnlyTPATRPeriod);
      // Warning if failed to reinit, but continue
   }
   //--- Check System State and perform actions
   ENUM_SYSTEM_STATE systemState = GetSystemState();
   // Global check first: System SL
   if(systemState != STATE_NO_ANCHOR && CheckSystemSL()) {
      UpdateChartControlsState();
      return; // System closed
   }
   // --- State-Specific Logic ---
   switch(systemState) {
   case STATE_ANCHOR_ONLY:
      CheckAndSetBreakEven();             // <<< Check and potentially move SL to BE
      if(CheckAnchorOnlyTP()) {          // Try to close anchor by TP
         UpdateChartControlsState();
         return; // Anchor closed
      }
      // HandleBackfilling(); // Omitted as requested
      break;
   case STATE_ANCHOR_WITH_OPPOSITES:
      // Reset BE status check if grid activates? Optional, depends on desired behavior
      // if(IsBreakEvenSet()) ResetBESetFlag(); // Example flag logic if needed
      if(CheckCompoundProfit()) { // Try to close everything by ROI
         UpdateChartControlsState();
         return; // System closed
      }
      ManageOppositeStopLosses();    // Update grid SLs first
      if(HandleSLHitEvent()) {     // Check if SL hit and recover
         systemState = GetSystemState(); // Re-evaluate state
         UpdateChartControlsState(); // Update display
         // Exit tick after potential major change from SL hit handling
         return;
      }
      MaintainPendingOrderCount();   // Ensure enough grid orders exist
      break;
   case STATE_NO_ANCHOR:
      // Button presses handled by OnChartEvent
      break;
   }
   //--- Update Status Label on Chart (Optional)
   if(InpShowChartControls)
      UpdateStatusLabel(systemState);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Handle clicks on our chart objects
   if(id == CHARTEVENT_OBJECT_CLICK) {
      string clicked_object_name = sparam;
      //--- Compare clicked name with our button names (stripping instance prefix)
      string base_name = StringSubstr(clicked_object_name, StringLen(g_chart_prefix));
      // Find Anchor if we lost track (e.g. EA restart)
      if(g_anchor_ticket == 0) FindAnchorPosition();
      if(base_name == ID_BUTTON_BUY) {
         if(g_anchor_ticket == 0) // Only open if no anchor exists
            OpenAnchorPosition(ORDER_TYPE_BUY);
         else
            Print("Nanobot Info: Anchor position already exists (Ticket: ", g_anchor_ticket, "). Cannot open new BUY.");
         return;
      }
      if(base_name == ID_BUTTON_SELL) {
         if(g_anchor_ticket == 0) // Only open if no anchor exists
            OpenAnchorPosition(ORDER_TYPE_SELL);
         else
            Print("Nanobot Info: Anchor position already exists (Ticket: ", g_anchor_ticket, "). Cannot open new SELL.");
         return;
      }
      if(base_name == ID_BUTTON_CLOSE) {
         Print("Nanobot Info: Close System button clicked by user.");
         CloseEntireSystem();
         return;
      }
   }
   //--- Handle end of editing for the lot size text box (optional, if needed)
   /* if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      string edited_object_name = sparam;
      string base_name = StringSubstr(edited_object_name, StringLen(g_chart_prefix));
      if(base_name == ID_EDIT_LOTS)
      {
         // Validate the input, store it, update display etc.
         // For simplicity, we read the value directly when Open button is clicked for now.
      }
   } */
}



// --- Getters and Checkers (Mostly unchanged) ---
ENUM_SYSTEM_STATE GetSystemState()
{
   /* Unchanged from previous */
   if (g_anchor_ticket == 0) FindAnchorPosition();
   if (g_anchor_ticket == 0) return STATE_NO_ANCHOR;
   int opposite_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         if (ticket != g_anchor_ticket) opposite_count++;
      }
   }
   return (opposite_count > 0) ? STATE_ANCHOR_WITH_OPPOSITES : STATE_ANCHOR_ONLY;
}
bool FindAnchorPosition()   /* Unchanged from previous */
{
   g_anchor_ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         g_anchor_ticket = ticket;
         //Print("Nanobot Info: Found existing Anchor Position. Ticket: ", g_anchor_ticket);
         return true; // Found one, assuming it's the anchor
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetATRValue(int handle, int index = 1)   // Default to last closed bar (index 1) for stability
{
   if(handle == INVALID_HANDLE) return 0.0;
   double atr_buffer[];
   if(CopyBuffer(handle, 0, index, 1, atr_buffer) > 0) {
      return NormalizeDouble(atr_buffer[0], g_points_digits); // Raw ATR value in price units
   }
   else {
      //Print("Nanobot Error: Failed to copy ATR buffer. Handle:", handle, " Error:", GetLastError());
      return 0.0;
   }
}
double NormalizeVolume(double volume)   /* Unchanged from previous */
{
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   volume = MathMax(volume, min_volume);
   volume = MathRound(volume / step_volume) * step_volume;
   volume = MathMin(volume, max_volume);
   return NormalizeDouble(volume, 2); // Use symbol volume digits later if needed
}

// --- Opening and Placing Orders ---

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenAnchorPosition(ENUM_ORDER_TYPE orderType)
{
   if(!InpShowChartControls) { // Protection if controls accidentally removed
      Print("Nanobot Error: Cannot open position, chart controls not found.");
      return;
   }
   // 1. Get and Validate Lot Size
   string lot_string = ObjectGetString(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_TEXT, 0);
   double lots = StringToDouble(lot_string);
   lots = NormalizeVolume(lots); // Re-normalize just in case
   double min_lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lots < min_lots) {
      Alert("Nanobot Error: Lot size ", DoubleToString(lots, 2), " is below minimum ", DoubleToString(min_lots, 2));
      ObjectSetString(ChartID(), g_chart_prefix + ID_EDIT_LOTS, OBJPROP_TEXT, DoubleToString(min_lots, 2)); // Reset edit box
      ChartRedraw();
      return;
   }
   // Max lots check maybe needed too: SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)
   // 2. Execute Trade
   MqlTradeResult result;
   bool success = false;
   string typeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   Print("Nanobot Attempting: Open Anchor ", typeStr, " ", DoubleToString(lots, 2), " lots for Magic ", InpMagicNumber);
   if(orderType == ORDER_TYPE_BUY) success = trade.Buy(lots, _Symbol, 0, 0, 0, "Nanobot Anchor");
   else if(orderType == ORDER_TYPE_SELL) success = trade.Sell(lots, _Symbol, 0, 0, 0, "Nanobot Anchor");
   trade.Result(result); // Get the result details
   // 3. Check Result
   if(success && result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE) {
      // 4. Success Path
      ulong deal_ticket = result.deal;
      if(HistoryDealSelect(deal_ticket)) { // Select the deal to get position ID
         g_anchor_ticket = (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         Print("Nanobot Success: Anchor ", typeStr, " opened. Position Ticket: ", g_anchor_ticket, " (Deal: ", deal_ticket, ")");
      }
      else {
         Alert("Nanobot Error: Could not select deal ", deal_ticket, " to get position ID after opening anchor!");
         g_anchor_ticket = 0; // Failed to get ticket, cannot proceed
         UpdateChartControlsState(); // Update UI to reflect failure
         return; // Exit the function as we failed to get the anchor ticket
      }
      if(PositionSelectByTicket(g_anchor_ticket)) {
         double anchor_lots = PositionGetDouble(POSITION_VOLUME);
         double anchor_price = PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE anchor_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         // 5. Place Initial Pending Orders
         if(!PlaceInitialPendingOrders(g_anchor_ticket, anchor_lots, anchor_price, anchor_type)) {
            // Handle failure - maybe close anchor? For now, just warn.
            Alert("Nanobot Warning: Anchor opened but failed to place initial pending orders!");
            // CloseEntireSystem(); // Option: Force close if setup fails?
         }
      }
      else {
         Alert("Nanobot Error: Anchor opened but failed to select the position ", g_anchor_ticket, " to place pending orders!");
         // Maybe try finding it again or close? Critical error.
         g_anchor_ticket = 0; // Reset anchor state
      }
   }
   else {
      // 6. Failure Path
      Alert("Nanobot Error: Failed to open Anchor ", typeStr, " position. Retcode: ", result.retcode, " Comment: ", result.comment, " LastError: ", GetLastError());
      g_anchor_ticket = 0; // Ensure anchor ticket is zeroed on failure
   }
   // 7. Update UI State
   UpdateChartControlsState();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// bool PlaceInitialPendingOrders(long anchorTicket, double anchorLots, double anchorPrice, ENUM_POSITION_TYPE anchorType)
// {
//    if(g_atr_handle_spacing == INVALID_HANDLE) {
//       Print("Nanobot Error: Cannot place pending orders, invalid ATR handle.");
//       return false;
//    }
//    // 1. Determine Opposite Order Type & Size
//    ENUM_ORDER_TYPE pending_order_type;
//    if(anchorType == POSITION_TYPE_BUY) pending_order_type = ORDER_TYPE_SELL_LIMIT; // Place below anchor
//    else if(anchorType == POSITION_TYPE_SELL) pending_order_type = ORDER_TYPE_BUY_LIMIT; // Place above anchor
//    else return false; // Should not happen
//    double pending_lots = NormalizeVolume(anchorLots * InpPendingOrderSizeFactor / 100.0);
//    if(pending_lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
//       Print("Nanobot Warning: Calculated pending order volume ", DoubleToString(pending_lots, 2), " is too small. Cannot place orders.");
//       return false;
//    }
//    Print("Nanobot: Placing ", InpPendingOrderCount, " initial pending ", EnumToString(pending_order_type), " orders of size ", DoubleToString(pending_lots,2));
//    // 2. Loop and Place Orders
//    double last_level = anchorPrice;
//    int placed_count = 0;
//    double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD); // Spread in points
//    double stops_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); // Stops level in points
//    for(int i = 0; i < InpPendingOrderCount; i++) {
//       // 3a. Get Spacing Components
//       double atr_value = GetATRValue(g_atr_handle_spacing, 1); // Use last closed bar ATR
//       if (atr_value <= 0) {
//          Print("Nanobot Warning: ATR for spacing is zero or negative, cannot calculate level for pending #", i + 1);
//          continue; // Skip this one
//       }
//       // 3b. Calculate Distance and Price Level
//       double distance = current_spread_points * g_point_value + atr_value; // Total price distance
//       double level;
//       if(anchorType == POSITION_TYPE_BUY) level = last_level - distance;
//       else level = last_level + distance;
//       level = NormalizeDouble(level, g_points_digits);
//       // 3c. Check Stops Level
//       double market_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
//       double market_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
//       double min_stop_dist_price = stops_level_points * g_point_value;
//       bool level_too_close = false;
//       if (pending_order_type == ORDER_TYPE_BUY_LIMIT && (level - market_ask) < min_stop_dist_price ) level_too_close = true;
//       if (pending_order_type == ORDER_TYPE_SELL_LIMIT && (market_bid - level) < min_stop_dist_price ) level_too_close = true;
//       // Add checks for BUY_STOP (level < ask + stop_dist) / SELL_STOP (level > bid - stop_dist) if using stops later
//       if (level_too_close) {
//          Print("Nanobot Warning: Calculated pending level ", DoubleToString(level, g_points_digits), " for order #", i+1, " is too close to market / stops level. Skipping.");
//          continue; // Skip placing this order
//       }
//       // 3d. Place Order
//       MqlTradeResult result;
//       bool success = false;
//       string comment = StringFormat("Nanobot Pending %d", i+1);
//       if(pending_order_type == ORDER_TYPE_BUY_LIMIT) success = trade.BuyLimit(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
//       else if(pending_order_type == ORDER_TYPE_SELL_LIMIT) success = trade.SellLimit(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
//       // Add BuyStop / SellStop if logic requires them
//       trade.Result(result);
//       if(success && (result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE)) {
//          placed_count++;
//          last_level = level; // Update for next iteration
//          // Print("Nanobot Success: Placed pending order #", i+1, " Ticket: ", result.order);
//       }
//       else {
//          Print("Nanobot Error: Failed to place pending order #", i+1, " at level ", DoubleToString(level, g_points_digits), ". Retcode: ", result.retcode, " Comment: ", result.comment);
//          // Decide: continue placing others or abort? For now, continue.
//       }
//       Sleep(50); // Small pause between orders
//    }
//    Print("Nanobot: Finished placing initial pendings. Placed ", placed_count, " out of ", InpPendingOrderCount, " attempted.");
//    return (placed_count > 0); // Return true if at least one was placed
// }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   int deleted_count = 0;
   Print("Nanobot: Deleting all pending orders for Magic ", InpMagicNumber);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong order_ticket = OrderGetTicket(i);
      // No need to select if just getting properties accessible directly
      if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol) {
         MqlTradeResult result;
         if(trade.OrderDelete(order_ticket)) {
            deleted_count++;
            trade.Result(result);
            // Print("Nanobot: Deleted pending order ticket ", order_ticket);
         }
         else {
            trade.Result(result);
            Print("Nanobot Error: Failed to delete pending order ", order_ticket, ". Retcode: ", result.retcode, " Comment: ", result.comment);
         }
         Sleep(20); // Small pause
      }
   }
   Print("Nanobot: Deleted ", deleted_count, " pending orders.");
}

// --- Closing Conditions ---

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckSystemSL()
{
   if(InpSystemStopLossPercent <= 0) return false; // SL disabled
   double total_pl = 0;
   int position_count = 0; // Count positions managed by this EA instance
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            position_count++;
            total_pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); // Include swap
         }
      }
   }
   if(position_count == 0) return false; // No positions to monitor SL for
   double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(account_equity <= 0) return false; // Avoid division by zero
   if(total_pl < 0) {
      double loss_percent = (MathAbs(total_pl) / account_equity) * 100.0;
      if(loss_percent >= InpSystemStopLossPercent) {
         Alert("Nanobot ALERT: System Stop Loss triggered! Loss ", DoubleToString(loss_percent, 1),"% >= ", DoubleToString(InpSystemStopLossPercent, 1),"%. Closing system.");
         CloseEntireSystem();
         return true; // System was closed
      }
   }
   return false; // SL not hit
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckAnchorOnlyTP()
{
   if (g_anchor_ticket == 0) return false; // Should already be checked by state, but good safeguard
   if (!PositionSelectByTicket(g_anchor_ticket)) {
      Print("Nanobot Error: Could not select anchor ", g_anchor_ticket, " for TP check.");
      g_anchor_ticket = 0; // Lost the anchor
      return false;
   }
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp_level = 0;
   bool use_points_tp = (InpAnchorOnlyTPPoints > 0);
   bool use_atr_tp = (!use_points_tp && InpAnchorOnlyTPATRPeriod > 0 && g_atr_handle_tp != INVALID_HANDLE);
   if(!use_points_tp && !use_atr_tp) return false; // No TP method defined or available
   // Calculate TP Level
   if(use_points_tp) {
      tp_level = (type == POSITION_TYPE_BUY) ? open_price + InpAnchorOnlyTPPoints * g_point_value : open_price - InpAnchorOnlyTPPoints * g_point_value;
   }
   else if(use_atr_tp) {
      double atr_value = GetATRValue(g_atr_handle_tp, 1);
      if(atr_value <= 0) return false; // Cannot calculate TP with invalid ATR
      tp_level = (type == POSITION_TYPE_BUY) ? open_price + atr_value /* * Multiplier? */ : open_price - atr_value /* * Multiplier? */;
   }
   tp_level = NormalizeDouble(tp_level, g_points_digits);
   // Check if TP Hit
   bool tp_hit = false;
   if(type == POSITION_TYPE_BUY && current_bid >= tp_level) tp_hit = true;   // Check Bid for closing BUY
   if(type == POSITION_TYPE_SELL && current_ask <= tp_level) tp_hit = true;  // Check Ask for closing SELL
   if(tp_hit) {
      Print("Nanobot Info: Anchor Only TP Hit at level ", DoubleToString(tp_level, g_points_digits), ". Closing anchor ", g_anchor_ticket);
      MqlTradeResult result;
      if(trade.PositionClose(g_anchor_ticket, InpSlippage)) {
         trade.Result(result);
         Print("Nanobot Success: Anchor TP closed. Deal: ", result.deal);
         g_anchor_ticket = 0; // Reset anchor state
         // Any remaining pendings should also be cleared IF this TP fires
         DeleteAllPendingOrders();
         return true;
      }
      else {
         trade.Result(result);
         Print("Nanobot Error: Failed to close Anchor position ", g_anchor_ticket," by TP. Retcode: ", result.retcode, " Comment: ", result.comment);
         // Position might be closed already, or network issue. State might be wrong on next tick.
         // Try FindAnchorPosition() again next tick might resolve.
         return false; // Indicate TP triggered but closure failed this tick
      }
   }
   return false; // TP not hit
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckCompoundProfit()
{
   if(InpCompoundProfitPercent <= 0) return false;
   double total_pl = 0;
   double total_loss = 0;
   double total_profit = 0;
   int pos_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            pos_count++;
            double current_pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            total_pl += current_pl;
            if(current_pl >= 0) total_profit += current_pl;
            else total_loss += MathAbs(current_pl);
         }
      }
   }
   if(pos_count <= 1) return false; // Need anchor + at least one opposite for compound profit logic
   bool close_system = false;
   if(total_loss < 0.001) { // Effectively zero loss, just check for profit
      if (total_profit > 0) close_system = true; // Profitable with no loss means infinite ROI technically
   }
   else {
      double roi = (total_profit - total_loss) / total_loss;
      if(roi >= (InpCompoundProfitPercent / 100.0)) {
         close_system = true;
      }
   }
   if(close_system) {
      Print("Nanobot Info: Compound Profit triggered! ROI threshold ", DoubleToString(InpCompoundProfitPercent, 1), "% met. Closing system.");
      CloseEntireSystem();
      return true; // System was closed
   }
   return false; // ROI not met
}


// --- Order Management ---

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOppositeStopLosses()
{
   CArrayObj *list = new CArrayObj();
   // ... add PositionInfo objects as before
   list.Sort(); // sorts using Compare method of PositionInfo
   // list.Comparator(comparator); // Removed
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == g_anchor_ticket) continue; // Skip anchor
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            PositionInfo *posInfo = new PositionInfo();
            posInfo.ticket     = ticket;
            posInfo.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            posInfo.open_time  = (datetime)PositionGetInteger(POSITION_TIME);
            posInfo.current_sl = PositionGetDouble(POSITION_SL);
            list.Add(posInfo);
         }
      }
   }
   int count = list.Total();
   if(count < 3) {
      // Print("Nanobot Debug: Less than 3 opposites (", count, "), no SL management needed.");
      delete list; /* delete comparator; Removed */ return; // Clean up
   }
   // 2. Sort by open time (uses PositionInfo::Compare)
   list.Sort();
   // 3. Determine SL level (open price of the second newest)
   PositionInfo *second_newest = (PositionInfo*)list.At(count - 2);
   if(second_newest == NULL) {
      Print("Nanobot Error: Failed to get second newest position from list.");
      delete list; /* delete comparator; Removed */ return;
   }
   double sl_level = NormalizeDouble(second_newest.open_price, g_points_digits);
   // 4. Loop through positions that need SL (#0 to #count - 3)
   // Print("Nanobot Debug: Managing SLs. Found ", count, " opposites. Target SL Level: ", DoubleToString(sl_level, _Digits));
   bool sl_modified = false;
   for(int i = 0; i < count - 2; i++) {
      PositionInfo *pos = (PositionInfo*)list.At(i);
      if(pos == NULL) continue;
      // Check if SL needs setting or modification (allow for floating point differences)
      if(MathAbs(pos.current_sl - sl_level) > g_point_value * 0.1) {
         //Print("Nanobot Info: Modifying SL for ticket ", pos.ticket, " from ", DoubleToString(pos.current_sl, _Digits), " to ", DoubleToString(sl_level, _Digits));
         MqlTradeResult result;
         // Note: TP is assumed 0 for these grid orders according to spec
         if(trade.PositionModify(pos.ticket, sl_level, 0)) {
            sl_modified = true;
            Sleep(20); // Pause after modification
         }
         else {
            trade.Result(result);
            Print("Nanobot Error: Failed to modify SL for position ", pos.ticket, ". Retcode: ", result.retcode, " Comment: ", result.comment);
         }
      }
   }
   // if(sl_modified) Print("Nanobot Debug: Finished SL modifications.");
   // 5. Clean up dynamically allocated objects
   delete list;
   // delete comparator; // Removed
}
//+------------------------------------------------------------------+
//| Checks if a value exists in a long array up to a specific count  |
//+------------------------------------------------------------------+
bool ArrayContainsLong(const long &arr[], int count, long value)
{
   for(int i=0; i<count; i++) {
      if(arr[i]==value)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HandleSLHitEvent()
{
   // Detection strategy: Check history for SL closures for relevant tickets since last check.
   if(!HistorySelect(g_last_sl_hit_check_time, TimeCurrent())) {
      //Print("Nanobot Warning: Failed to select history for SL hit check.");
      g_last_sl_hit_check_time = TimeCurrent() - 1; // Ensure next check covers current time
      return false;
   }
   bool sl_was_hit = false;
   long sl_hit_ticket = 0;
   g_tally_profit = 0.0; // Reset tally for this potential event
   // CList *closed_by_sl_list = new CList(); // REMOVED: Using dynamic array instead
   long closed_by_sl_tickets[]; // ADDED: Array to store tickets
   int closed_by_sl_count = 0;  // ADDED: Counter for the array
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--) { // Check recent deals first
      ulong deal_ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetString(deal_ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT && // Outgoing deal (closure)
            HistoryDealGetInteger(deal_ticket, DEAL_REASON) == DEAL_REASON_SL) { // Closed by Stop Loss
         long closed_position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
         sl_was_hit = true;
         sl_hit_ticket = closed_position_id; // Store one of the tickets that hit SL
         // Add P/L to tally (Profit + Swap + Commission for this closing deal)
         g_tally_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + HistoryDealGetDouble(deal_ticket, DEAL_SWAP) + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         // Replace CList check and add with array check and add
         // if (!closed_by_sl_list.SearchLinear(sl_hit_ticket))
         //    closed_by_sl_list.Add(sl_hit_ticket);
         if (!ArrayContainsLong(closed_by_sl_tickets, closed_by_sl_count, sl_hit_ticket)) { // Use helper
            ArrayResize(closed_by_sl_tickets, closed_by_sl_count + 1);
            closed_by_sl_tickets[closed_by_sl_count] = sl_hit_ticket;
            closed_by_sl_count++;
         }
         Print("Nanobot Info: Detected SL Hit closure deal #", deal_ticket, " for position #", sl_hit_ticket, ". Deal P/L(+Swap+Comm): ", DoubleToString(HistoryDealGetDouble(deal_ticket, DEAL_PROFIT) + HistoryDealGetDouble(deal_ticket, DEAL_SWAP) + HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION), 2) );
         // No need to break, capture all SL deals within the time window
      }
   }
   g_last_sl_hit_check_time = TimeCurrent(); // Update check time AFTER processing
   if(!sl_was_hit) {
      // delete closed_by_sl_list; // REMOVED
      return false; // No SL hit detected
   }
   // SL WAS HIT! Now perform recovery steps.
   Print("Nanobot Action: SL Hit detected! Tally from SL closures: ", DoubleToString(g_tally_profit, 2), ". Proceeding with recovery...");
   // 1. Identify the two "newest" open opposite positions
   CArrayObj *opposites_list = new CArrayObj();
   // ComparePositionInfoByTime *comparator = new ComparePositionInfoByTime(); // Already removed
   //opposites_list.SortMode(true); // Enable sorting
   opposites_list.Sort();
   // opposites_list.Comparator(comparator); // Already removed
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      // Replace CList check with array check
      // if(ticket == g_anchor_ticket || closed_by_sl_list.SearchLinear(ticket)) continue;
      if(ticket == g_anchor_ticket || ArrayContainsLong(closed_by_sl_tickets, closed_by_sl_count, (long)ticket)) continue; // Use helper
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         PositionInfo *posInfo = new PositionInfo(); // Allocate on heap
         posInfo.ticket     = (long)ticket; // Store as long
         posInfo.open_time  = (datetime)PositionGetInteger(POSITION_TIME);
         // Add other fields if needed
         opposites_list.Add(posInfo);
      }
   }
   opposites_list.Sort(); // Sort by time (uses PositionInfo::Compare)
   int open_opposites_count = opposites_list.Total();
   long ticket_N = 0, ticket_N_minus_1 = 0; // Newest and second-newest still open
   if(open_opposites_count > 0) {
      PositionInfo* pos_N = (PositionInfo*)opposites_list.At(open_opposites_count - 1);
      if(pos_N) ticket_N = pos_N.ticket;
   }
   if(open_opposites_count > 1) {
      PositionInfo* pos_N_minus_1 = (PositionInfo*)opposites_list.At(open_opposites_count - 2);
      if(pos_N_minus_1) ticket_N_minus_1 = pos_N_minus_1.ticket;
   }
   // 2. Close these two positions (if they exist)
   double profit_from_manual_closes = 0;
   MqlTradeResult close_result;
   if(ticket_N != 0) {
      Print("Nanobot Action: Closing newest opposite #", ticket_N);
      if(trade.PositionClose(ticket_N)) {
         trade.Result(close_result);
         profit_from_manual_closes += HistoryDealGetDouble(close_result.deal, DEAL_PROFIT); // Accumulate P/L from closed deal
      }
      else {
         trade.Result(close_result);
         Print("Nanobot Error: Failed to close #", ticket_N, " Retcode: ", close_result.retcode);
      }
      Sleep(50);
   }
   if(ticket_N_minus_1 != 0) {
      Print("Nanobot Action: Closing second newest opposite #", ticket_N_minus_1);
      if(trade.PositionClose(ticket_N_minus_1)) {
         trade.Result(close_result);
         profit_from_manual_closes += HistoryDealGetDouble(close_result.deal, DEAL_PROFIT); // Accumulate P/L from closed deal
      }
      else {
         trade.Result(close_result);
         Print("Nanobot Error: Failed to close #", ticket_N_minus_1, " Retcode: ", close_result.retcode);
      }
      Sleep(50);
   }
   g_tally_profit += profit_from_manual_closes; // Add P/L from these closures to the overall tally
   Print("Nanobot Action: Tally after manually closing N and N-1: ", DoubleToString(g_tally_profit, 2));
   // 3. Partial Close Anchor if profitable tally
   if(g_tally_profit > 0 && g_anchor_ticket != 0) {
      PartialCloseAnchor(g_tally_profit);
   }
   // 4. Delete Remaining Pending Orders
   DeleteAllPendingOrders();
   // 5. Re-establish Pending Orders if Anchor still exists
   FindAnchorPosition(); // Ensure g_anchor_ticket is up-to-date after partial close
   if(g_anchor_ticket != 0) {
      if(PositionSelectByTicket(g_anchor_ticket)) {
         double current_anchor_lots = PositionGetDouble(POSITION_VOLUME);
         double current_anchor_price = PositionGetDouble(POSITION_PRICE_OPEN); // Use original open price or current? Let's use original
         ENUM_POSITION_TYPE current_anchor_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         // Re-evaluate market price context?
         // For simplicity, place relative to anchor's original price again.
         Print("Nanobot Action: Re-establishing pending orders for remaining anchor volume ", DoubleToString(current_anchor_lots,2));
         PlaceInitialPendingOrders(g_anchor_ticket, current_anchor_lots, current_anchor_price, current_anchor_type);
      }
      else {
         Print("Nanobot Error: Anchor position ",g_anchor_ticket," not found after partial close/SL hit. Cannot reset pendings.");
         g_anchor_ticket = 0; // Lost the anchor
      }
   }
   else {
      Print("Nanobot Info: Anchor was fully closed during recovery or already closed.");
   }
   // Clean up memory
   delete opposites_list;
   // delete comparator; // Already removed
   // delete closed_by_sl_list; // REMOVED
   return true; // Indicate SL hit was handled
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PartialCloseAnchor(double available_profit)
{
   if(available_profit <= 0 || g_anchor_ticket == 0) return false;
   if(!PositionSelectByTicket(g_anchor_ticket)) {
      Print("Nanobot Error: Failed to select anchor ", g_anchor_ticket, " for partial close.");
      return false;
   }
   double anchor_volume = PositionGetDouble(POSITION_VOLUME);
   double anchor_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE anchor_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   string anchor_symbol = PositionGetString(POSITION_SYMBOL); // Should be _Symbol
   double step_volume = SymbolInfoDouble(anchor_symbol, SYMBOL_VOLUME_STEP);
   double min_volume = SymbolInfoDouble(anchor_symbol, SYMBOL_VOLUME_MIN);
   double profit_remaining = available_profit;
   bool   closed_partially = false;
   Print("Nanobot Info: Attempting partial anchor close for ticket ", g_anchor_ticket, " using available profit: ", DoubleToString(available_profit, 2));
   while(profit_remaining > 0 && anchor_volume >= min_volume + step_volume) { // Leave at least min_volume
      double close_vol = step_volume;
      // Ensure we don't try to close more than available (just in case)
      // close_vol = MathMin(close_vol, anchor_volume - min_volume); // redundant due to while condition?
      // Estimate loss for closing this step
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double close_price = (anchor_type == POSITION_TYPE_BUY) ? current_bid : current_ask;
      double profit_for_step = 0;
      ENUM_ORDER_TYPE order_type_for_calc;
      if(anchor_type == POSITION_TYPE_BUY)
         order_type_for_calc = ORDER_TYPE_BUY;
      else
         order_type_for_calc = ORDER_TYPE_SELL;
      // Use OrderCalcProfit - careful with its limitations regarding swap/commission tracking live
      if(!OrderCalcProfit(order_type_for_calc, anchor_symbol, close_vol, anchor_open_price, close_price, profit_for_step)) {
         Print("Nanobot Error: OrderCalcProfit failed during partial close check. Cannot proceed.");
         break; // Abort partial close attempt
      }
      double loss_for_step = MathMax(0, -profit_for_step); // Only consider the loss component
      //Print("Nanobot Debug: Close step ", DoubleToString(close_vol, 2), ", Estimated loss: ", DoubleToString(loss_for_step, 2), ", Profit remaining: ", DoubleToString(profit_remaining, 2));
      if(profit_remaining >= loss_for_step || loss_for_step < 0.001) { // Can afford the loss (or it's profitable step)
         MqlTradeResult result;
         Print("Nanobot Action: Closing ", DoubleToString(close_vol, 2), " lots of anchor ", g_anchor_ticket);
         if(trade.PositionClosePartial(g_anchor_ticket, close_vol, InpSlippage)) {
            trade.Result(result);
            profit_remaining -= loss_for_step; // Reduce available profit by the estimated loss absorbed
            anchor_volume -= close_vol;        // Update tracked volume
            closed_partially = true;
            Print("Nanobot Success: Partial close executed. Remaining Vol: ", DoubleToString(anchor_volume, 2), " Remaining Profit: ",
                  DoubleToString(profit_remaining, 2),
                  " Deal P/L: ", DoubleToString(HistoryDealGetDouble(result.deal, DEAL_PROFIT),2) );
            Sleep(100); // Pause after successful partial close
         }
         else {
            trade.Result(result);
            Print("Nanobot Error: Failed partial close step. Retcode: ", result.retcode, " Comment: ", result.comment);
            break; // Stop trying if one step fails
         }
      }
      else {
         //Print("Nanobot Info: Not enough profit (", DoubleToString(profit_remaining, 2),") to cover estimated loss (", DoubleToString(loss_for_step, 2), ") for next step.");
         break; // Cannot afford the loss for this step
      }
   }
   // Final check if anchor needs full close (if volume == min_volume after loop)
   // This isn't specified, so leaving it partially open is the default behavior.
   Print("Nanobot Info: Finished partial anchor close attempt. Anchor remaining vol: ", DoubleToString(anchor_volume, 2));
   return closed_partially;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseEntireSystem()
{
   Print("Nanobot Action: Closing entire system for Magic ", InpMagicNumber, " Symbol ", _Symbol);
   int closed_pos = 0;
   int closed_ord = 0;
   // Close Open Positions first
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            MqlTradeResult result;
            if(trade.PositionClose(ticket, InpSlippage)) {
               closed_pos++;
               trade.Result(result);
               //Print("Nanobot Closed Position: ", ticket, " Deal: ", result.deal, " P/L: ", result.profit);
            }
            else {
               trade.Result(result);
               Print("Nanobot Error Closing Position: ", ticket, " Retcode: ", result.retcode, " Comment: ", result.comment);
            }
            Sleep(50); // Pause between close attempts
         }
      }
   }
   // Delete Pending Orders
   DeleteAllPendingOrders(); // Use existing function
   Print("Nanobot: System Closure Complete. Closed ", closed_pos, " positions.");
   g_anchor_ticket = 0; // Reset state
   Comment("System Closed."); // Update chart comment
   // UpdateChartControlsState() will be called on next tick or event implicitly
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// void MaintainPendingOrderCount()
// {
//    // Count current pending orders
//    int current_pending_count = 0;
//    double furthest_level = 0; // Price of the order furthest from anchor's favour
//    ENUM_ORDER_TYPE opposite_type = ORDER_TYPE_BUY_LIMIT; // Determine actual type based on anchor
//    long anchor_ticket_local = g_anchor_ticket; // Use local copy
//    if(!PositionSelectByTicket(anchor_ticket_local)) {
//       Print("Nanobot Error MaintainPendings: Cannot select anchor ", anchor_ticket_local);
//       return;
//    }
//    ENUM_POSITION_TYPE anchor_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
//    double anchor_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
//    if(anchor_type == POSITION_TYPE_BUY) { // Anchor Buy -> Look for Sell Limits furthest DOWN
//       opposite_type = ORDER_TYPE_SELL_LIMIT;
//       furthest_level = anchor_open_price; // Start comparison from anchor
//       for(int i = OrdersTotal() - 1; i >= 0; i--) {
//          ulong order_ticket = OrderGetTicket(i);
//          if (OrderSelect(order_ticket)) { // Select the order first
//             if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_TYPE) == opposite_type) {
//                current_pending_count++;
//                furthest_level = MathMin(furthest_level, OrderGetDouble(ORDER_PRICE_OPEN)); // Correct call
//             }
//          }
//       }
//    }
//    else {   // Anchor Sell -> Look for Buy Limits furthest UP
//       opposite_type = ORDER_TYPE_BUY_LIMIT;
//       furthest_level = anchor_open_price; // Start comparison from anchor
//       for(int i = OrdersTotal() - 1; i >= 0; i--) {
//          ulong order_ticket = OrderGetTicket(i);
//          if (OrderSelect(order_ticket)) { // Select the order first
//             if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_TYPE) == opposite_type) {
//                current_pending_count++;
//                furthest_level = MathMax(furthest_level, OrderGetDouble(ORDER_PRICE_OPEN)); // Correct call
//             }
//          }
//       }
//    }
//    if(current_pending_count < InpPendingOrderCount) {
//       int orders_to_add = InpPendingOrderCount - current_pending_count;
//       Print("Nanobot MaintainPendings: Need to add ", orders_to_add, " orders (Current: ", current_pending_count, ")");
//       double anchor_lots = PositionGetDouble(POSITION_VOLUME); // Get current anchor vol
//       double pending_lots = NormalizeVolume(anchor_lots * InpPendingOrderSizeFactor / 100.0);
//       if(pending_lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
//          Print("Nanobot MaintainPendings Warning: Pending volume too small. Cannot add more.");
//          return;
//       }
//       double last_level = furthest_level;
//       for(int i = 0; i < orders_to_add; i++) {
//          double atr_value = GetATRValue(g_atr_handle_spacing, 1);
//          double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
//          double distance = current_spread_points * g_point_value + atr_value;
//          double level;
//          if(anchor_type == POSITION_TYPE_BUY) level = last_level - distance;
//          else level = last_level + distance;
//          level = NormalizeDouble(level, _Digits);
//          // Stops level check
//          double market_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
//          double market_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
//          double min_stop_dist_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point_value;
//          bool level_too_close = false;
//          if (opposite_type == ORDER_TYPE_BUY_LIMIT && (level - market_ask) < min_stop_dist_price ) level_too_close = true;
//          if (opposite_type == ORDER_TYPE_SELL_LIMIT && (market_bid - level) < min_stop_dist_price ) level_too_close = true;
//          if (level_too_close) {
//             Print("Nanobot MaintainPendings Warning: Calculated level ", DoubleToString(level, _Digits)," too close. Skipping add #", i+1);
//             continue; // Skip this specific addition attempt
//          }
//          // Place Order
//          MqlTradeResult result;
//          bool success = false;
//          string comment = StringFormat("Nanobot Maint %d", current_pending_count + i + 1);
//          if(opposite_type == ORDER_TYPE_BUY_LIMIT) success = trade.BuyLimit(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
//          else if(opposite_type == ORDER_TYPE_SELL_LIMIT) success = trade.SellLimit(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
//          if(success) {
//             last_level = level;
//             Sleep(50);
//          }
//          else {
//             trade.Result(result);
//             Print("Nanobot MaintainPendings Error: Failed add #", i+1, " Retcode: ", result.retcode);
//          }
//       }
//    }
//    // else { Print("Nanobot Debug MaintainPendings: Count OK (", current_pending_count, ")"); }
// }
//+------------------------------------------------------------------+
//| Place Initial Pending Orders after Anchor is opened               |
//+------------------------------------------------------------------+
bool PlaceInitialPendingOrders(long anchorTicket, double anchorLots, double anchorPrice, ENUM_POSITION_TYPE anchorType)
{
    if(g_atr_handle_spacing == INVALID_HANDLE) { Print("Nanobot Error PlaceInit: Invalid ATR handle."); return false; }

    // *** Determine STOP Order Type ***
    ENUM_ORDER_TYPE pending_order_type = (anchorType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
    double pending_lots = NormalizeVolume(anchorLots * InpPendingOrderSizeFactor / 100.0);
    if(pending_lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) { Print("Nanobot Warn PlaceInit: Pending vol too small."); return false; }

    Print("Nanobot PlaceInit: Placing ", InpPendingOrderCount, " ", EnumToString(pending_order_type), " size ", DoubleToString(pending_lots,2));

    double current_calc_level = anchorPrice; // Start with anchor price for the first level calculation base
    int placed_count = 0;
    double stops_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); 
    double min_stop_dist_price = stops_level_points * g_point_value; 

    for(int i = 0; i < InpPendingOrderCount; i++) 
    {
        bool ok = false; 
        double atr_value = GetATRValue(g_atr_handle_spacing, 1);
        double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        
        double distance = (atr_value > 0 ? atr_value : 0) + (current_spread_points > 0 ? current_spread_points * g_point_value : 0); 
        if (distance <= 0) {
            Print("Nanobot Warn PlaceInit: Zero or negative distance calculated #",i+1); 
            current_calc_level = (anchorType == POSITION_TYPE_BUY) ? current_calc_level - (g_point_value * 1) : current_calc_level + (g_point_value*1); 
            current_calc_level = NormalizeDouble(current_calc_level, g_points_digits);
            continue;
        }

        double level = (anchorType == POSITION_TYPE_BUY) ? current_calc_level - distance : current_calc_level + distance;
        level = NormalizeDouble(level, g_points_digits);
        current_calc_level = level; 

        double market_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double market_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // --- Pre-Placement Checks (for STOP orders) --- 

        // Check 1: Price Validity (Buy Stop > Ask, Sell Stop < Bid)
        bool price_is_valid = true;
        if (pending_order_type == ORDER_TYPE_BUY_STOP && level <= market_ask) {
            price_is_valid = false;
            PrintFormat("Nanobot Warn PlaceInit #%d: Buy Stop level %.*f <= Ask %.*f. Invalid.", i+1, g_points_digits, level, _Digits, market_ask);
        }
        if (pending_order_type == ORDER_TYPE_SELL_STOP && level >= market_bid) {
            price_is_valid = false;
            PrintFormat("Nanobot Warn PlaceInit #%d: Sell Stop level %.*f >= Bid %.*f. Invalid.", i+1, g_points_digits, level, _Digits, market_bid);
        }
        if (!price_is_valid) {
            continue; 
        }

        // Check 2: Stops Level (Buy Stop level - Ask >= min_dist, Bid - Sell Stop level >= min_dist)
        bool level_too_close = false;
        string check_reason = "";
        if (pending_order_type == ORDER_TYPE_BUY_STOP && (level - market_ask) < min_stop_dist_price) { 
            level_too_close = true;
            check_reason = StringFormat("Level %.5f - Ask %.5f < StopsDist %.5f", level, market_ask, min_stop_dist_price);
        }
        if (pending_order_type == ORDER_TYPE_SELL_STOP && (market_bid - level) < min_stop_dist_price) { 
            level_too_close = true;
            check_reason = StringFormat("Bid %.5f - Level %.5f < StopsDist %.5f", market_bid, level, min_stop_dist_price);
        }

        if (level_too_close) {
            PrintFormat("Nanobot Warn PlaceInit #%d: Level %.*f too close to market/stops level (%s). Skipping.", i+1, g_points_digits, level, check_reason);
            continue; 
        }

        // Check 3: Positive Price
        if (level <= 0) {
           Print("Nanobot Error PlaceInit #%d: Calculated level is zero or negative (%.*f). Skipping.", i+1, g_points_digits, level);
           continue; 
        }

         // --- Place STOP Order --- 
         MqlTradeResult result;
         string comment = StringFormat("NInitPend%d", i+1);
         if(pending_order_type == ORDER_TYPE_BUY_STOP)
            ok = trade.BuyStop(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment); 
         else if(pending_order_type == ORDER_TYPE_SELL_STOP)
            ok = trade.SellStop(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment); 

         if(ok){ 
             trade.Result(result); 
             if(result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE) { 
                placed_count++;
             } else {
                Print("Nanobot Error PlaceInit: Place OK but bad Retcode #%d: %d Comment: %s", i+1, result.retcode, result.comment);
             }
         } else { 
             trade.Result(result); 
             Print("Nanobot Error PlaceInit: Failed place #%d Level: %.*f Ret: %d Comm: %s", 
                    i+1, g_points_digits, level, result.retcode, result.comment);
         }
          Sleep(50); 
    }
    Print("Nanobot PlaceInit: Placed ", placed_count, "/", InpPendingOrderCount);
    return (placed_count > 0);
}


//+------------------------------------------------------------------+
//| Maintain correct number of Pending Orders                       |
//+------------------------------------------------------------------+
void MaintainPendingOrderCount()
{
    int current_pending_count = 0;
    double furthest_level = 0;
    ENUM_ORDER_TYPE opposite_type = ORDER_TYPE_BUY_STOP; // *** Changed to STOP ***
    long anchor_ticket_local = g_anchor_ticket;

    if (anchor_ticket_local == 0 || !PositionSelectByTicket(anchor_ticket_local)) {
       if (!FindAnchorPosition()) { Print("Nanobot Error Maintain: No anchor."); g_anchor_ticket=0; return; }
       anchor_ticket_local = g_anchor_ticket;
       if (!PositionSelectByTicket(anchor_ticket_local)) { Print("Nanobot Error Maintain: Cannot select anchor."); return;}
       }

    ENUM_POSITION_TYPE anchor_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double anchor_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    furthest_level = anchor_open_price;
    opposite_type = (anchor_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP; // *** Changed to STOP ***

    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong order_ticket = OrderGetTicket(i);
       if (OrderSelect(order_ticket)) { 
          if (OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
                OrderGetString(ORDER_SYMBOL) == _Symbol &&
                OrderGetInteger(ORDER_TYPE) == opposite_type) { // Check for STOP order type
                    current_pending_count++;
             double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
             if (anchor_type == POSITION_TYPE_BUY) furthest_level = MathMin(furthest_level, order_price);
             else furthest_level = MathMax(furthest_level, order_price);
          }
       }
    }

    if (current_pending_count < InpPendingOrderCount) {
       int orders_to_add = InpPendingOrderCount - current_pending_count;
       double anchor_lots = PositionGetDouble(POSITION_VOLUME);
       double pending_lots = NormalizeVolume(anchor_lots * InpPendingOrderSizeFactor / 100.0);
       if (pending_lots < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) { Print("Nanobot Warn Maintain: Vol too small."); return; }

       Print("Nanobot Maintain: Adding ", orders_to_add, " orders (Have ", current_pending_count, ")");

       double last_level = furthest_level; // Start placing from the furthest existing order
       double stops_level_points = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL); 
       double min_stop_dist_price = stops_level_points * g_point_value; 

       double current_calc_level = last_level; // Initialize calculation base

       for (int i = 0; i < orders_to_add; i++) {
          double atr_value = GetATRValue(g_atr_handle_spacing, 1);
          double current_spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         if(atr_value <= 0 || current_spread_points < 0) {
            Print("Nanobot Warn Maintain: Invalid ATR/Spread #",i+1); 
            current_calc_level = (anchor_type == POSITION_TYPE_BUY) ? current_calc_level - (g_point_value * 1) : current_calc_level + (g_point_value*1); 
            current_calc_level = NormalizeDouble(current_calc_level, g_points_digits);
            continue;
         }
             double distance = (atr_value > 0 ? atr_value : 0) + (current_spread_points > 0 ? current_spread_points * g_point_value : 0); 
          if (distance <= 0) { 
            Print("Nanobot Warn Maintain: Zero Distance calc #", i+1);
             current_calc_level = (anchor_type == POSITION_TYPE_BUY) ? current_calc_level - (g_point_value * 1) : current_calc_level + (g_point_value*1); 
             current_calc_level = NormalizeDouble(current_calc_level, g_points_digits);
             continue;
             } // Skip if dist is zero

          double level = (anchor_type == POSITION_TYPE_BUY) ? current_calc_level - distance : current_calc_level + distance;
          level = NormalizeDouble(level, g_points_digits);
          current_calc_level = level; // Update calc base for next iteration

          double market_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
          double market_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         // --- Pre-Placement Checks (for STOP orders) --- 
         bool price_is_valid = true;
         if (opposite_type == ORDER_TYPE_BUY_STOP && level <= market_ask) { price_is_valid = false; }
         if (opposite_type == ORDER_TYPE_SELL_STOP && level >= market_bid) { price_is_valid = false; }
         if (!price_is_valid) { PrintFormat("Nanobot Warn Maintain #%d: Stop Level invalid vs market (%.*f)", current_pending_count + i + 1, g_points_digits, level); continue; }

         bool level_too_close = false;
         if (opposite_type == ORDER_TYPE_BUY_STOP && (level - market_ask) < min_stop_dist_price) { level_too_close = true; }
         if (opposite_type == ORDER_TYPE_SELL_STOP && (market_bid - level) < min_stop_dist_price) { level_too_close = true; }
         if (level_too_close) { PrintFormat("Nanobot Warn Maintain #%d: Stop Level too close to market (%.*f)", current_pending_count + i + 1, g_points_digits, level); continue; }

         if (level <= 0) { PrintFormat("Nanobot Error Maintain #%d: Stop Level zero/negative (%.*f)", current_pending_count + i + 1, g_points_digits, level); continue; }

          // --- Place Order --- 
          MqlTradeResult result;
          bool success = false;
          string comment = StringFormat("NMaint%d", current_pending_count + i + 1);
          if (opposite_type == ORDER_TYPE_BUY_STOP) success = trade.BuyStop(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
          else if (opposite_type == ORDER_TYPE_SELL_STOP) success = trade.SellStop(pending_lots, level, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);

         if(success){ 
             trade.Result(result); 
             if(result.retcode == TRADE_RETCODE_PLACED || result.retcode == TRADE_RETCODE_DONE) { 
               // OK 
               Sleep(50); 
             } else { 
                Print("Nanobot Error Maintain: Place OK but bad Retcode #%d: %d Comment: %s", current_pending_count + i + 1, result.retcode, result.comment);
             } 
         } else { 
             trade.Result(result); 
             Print("Nanobot Error Maintain: Failed add #%d Level: %.*f Ret: %d Comm: %s", current_pending_count + i + 1, g_points_digits, level, result.retcode, result.comment);
         } 
       }
    }
}
// --- New Helper Function for TP Calculation ---
bool CalculateAnchorTPLevel(double &tpLevel) // Returns false if TP not applicable
{
   if (g_anchor_ticket == 0) return false;
   if (!PositionSelectByTicket(g_anchor_ticket)) {
      // Attempt to find it again if selection fails mid-operation
      if(!FindAnchorPosition() || !PositionSelectByTicket(g_anchor_ticket)) {
         Print("Nanobot Error CalculateTP: Cannot select anchor ", g_anchor_ticket);
         g_anchor_ticket=0; // Anchor lost
         return false;
      }
   }
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   bool use_points_tp = (InpAnchorOnlyTPPoints > 0);
   bool use_atr_tp = (!use_points_tp && InpAnchorOnlyTPATRPeriod > 0 && g_atr_handle_tp != INVALID_HANDLE);
   if (!use_points_tp && !use_atr_tp) return false; // No TP set
   if (use_points_tp) {
      tpLevel = (type == POSITION_TYPE_BUY) ? open_price + InpAnchorOnlyTPPoints * g_point_value : open_price - InpAnchorOnlyTPPoints * g_point_value;
   }
   else {   // Must be ATR TP
      double atr_value = GetATRValue(g_atr_handle_tp, 1);
      if (atr_value <= 0) {
         Print("Nanobot Warning CalculateTP: Invalid ATR value (<=0).");
         return false; // Invalid ATR
      }
      // Optional: Apply multiplier here if added as input
      tpLevel = (type == POSITION_TYPE_BUY) ? open_price + atr_value /* * multiplier */ : open_price - atr_value /* * multiplier */;
   }
   tpLevel = NormalizeDouble(tpLevel, _Digits);
   return true;
}


// --- Break-Even Logic Implementation ---
void CheckAndSetBreakEven()
{
   // --- Guard Clauses ---
   // 1. Check state: Only apply in Anchor Only mode
   if (GetSystemState() != STATE_ANCHOR_ONLY || g_anchor_ticket == 0) return;
   // 2. Select the Anchor Position
   if (!PositionSelectByTicket(g_anchor_ticket)) {
      Print("Nanobot Error BE: Cannot select anchor ", g_anchor_ticket);
      // Maybe try FindAnchorPosition() ? If selection fails repeatedly, anchor might be closed.
      // If FindAnchorPosition() fails too, reset g_anchor_ticket = 0; and return
      return;
   }
   // 3. Get Position Info
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_sl = PositionGetDouble(POSITION_SL);
   // 4. Calculate TP Level using helper
   double tp_level;
   if (!CalculateAnchorTPLevel(tp_level)) {
      // Print("Nanobot Debug BE: TP not defined or calculable for anchor ", g_anchor_ticket);
      return; // Cannot proceed without a defined TP
   }
   // 5. Calculate 50% Trigger Level
   double distance_to_tp = MathAbs(tp_level - open_price);
   if (distance_to_tp < g_point_value * 2) return; // TP is too close to open price for meaningful BE
   double trigger_level;
   if(type == POSITION_TYPE_BUY) trigger_level = open_price + distance_to_tp / 2.0;
   else trigger_level = open_price - distance_to_tp / 2.0;
   trigger_level = NormalizeDouble(trigger_level, _Digits);
   // 6. Calculate Break-Even Level (with optional offset)
   double be_level;
   if (type == POSITION_TYPE_BUY) be_level = open_price + BE_LEVEL_OFFSET_POINTS * g_point_value;
   else be_level = open_price - BE_LEVEL_OFFSET_POINTS * g_point_value;
   be_level = NormalizeDouble(be_level, _Digits);
   // 7. Check Trigger Price Reached
   double market_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double market_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bool trigger_met = false;
   if (type == POSITION_TYPE_BUY && market_bid >= trigger_level) trigger_met = true;
   if (type == POSITION_TYPE_SELL && market_ask <= trigger_level) trigger_met = true;
   if (!trigger_met) return; // Price hasn't reached the 50% mark yet
   // 8. Check if SL needs modification (only move if current SL is worse than BE)
   bool modify_sl = false;
   if (type == POSITION_TYPE_BUY) {
      // Move SL if current SL is below BE level (or zero)
      if (current_sl < be_level || current_sl == 0) {
         modify_sl = true;
      }
   }
   else {   // Position Type is SELL
      // Move SL if current SL is above BE level (or zero)
      if (current_sl > be_level || current_sl == 0) {
         modify_sl = true;
      }
   }
   // Optional: Check if the BE level itself is too close according to stops level
   double min_stop_dist_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point_value;
   if (modify_sl) {
      bool be_too_close = false;
      if(type == POSITION_TYPE_BUY && (market_bid - be_level) < min_stop_dist_price) be_too_close = true;
      if(type == POSITION_TYPE_SELL && (be_level - market_ask) < min_stop_dist_price) be_too_close = true;
      if(be_too_close) {
         // Print("Nanobot Warning BE: Calculated BE Level ", DoubleToString(be_level, _Digits), " is too close to market. Cannot set SL.");
         modify_sl = false; // Do not modify if too close
      }
   }
   // 9. Perform Modification
   if (modify_sl) {
      Print("Nanobot Info: Price reached 50% to TP. Setting SL to Break-Even (~", DoubleToString(be_level, _Digits), ") for Anchor ", g_anchor_ticket);
      MqlTradeResult result;
      // VERY Important: Pass the ORIGINAL TP level again when modifying ONLY the SL.
      if (trade.PositionModify(g_anchor_ticket, be_level, tp_level)) {
         Print("Nanobot Success: SL moved to BE for ticket ", g_anchor_ticket);
         Sleep(50); // Allow time for update
      }
      else {
         trade.Result(result);
         Print("Nanobot Error: Failed to modify SL to BE for ticket ", g_anchor_ticket, ". Retcode: ", result.retcode, " Comment: ", result.comment);
      }
   }
   // else { Print("Nanobot Debug BE: Trigger met but SL ", DoubleToString(current_sl, _Digits)," already >= BE level ", DoubleToString(be_level, _Digits), " or BE level too close."); }
}
//+------------------------------------------------------------------+
