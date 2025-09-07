//+------------------------------------------------------------------+
//| MQL5 NEWS CALENDAR PART 6 (Refined)                             |
//| Copyright 2025, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader. |
//| https://forexalgo-trader.com                                   |
//+------------------------------------------------------------------+

#property copyright "Copyright 2025, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader"
#property link      "https://forexalgo-trader.com"
#property description "MQL5 NEWS CALENDAR PART 6 - Refined UI & Structure"
#property version   "1.10" // Version bump

// --- Includes ---
#include <Trade\Trade.mqh> // Trading library

// --- Defines for UI Object Names ---
#define DASHBOARD_PREFIX    "NewsCal_" // Prefix for all dashboard objects for easy cleanup
#define MAIN_REC            DASHBOARD_PREFIX + "MAIN_REC"
#define SUB_REC1            DASHBOARD_PREFIX + "SUB_REC1" // Header Area BG
#define SUB_REC2            DASHBOARD_PREFIX + "SUB_REC2" // Data Area BG
#define HEADER_LABEL        DASHBOARD_PREFIX + "HEADER_LABEL"
#define TIME_STATUS_LABEL   DASHBOARD_PREFIX + "TIME_STATUS_LABEL" // Combined Time and Status
#define FILTER_SECTION_LABEL DASHBOARD_PREFIX + "FILTER_SECTION_LABEL"

#define COL_HEADER_BTN_     DASHBOARD_PREFIX + "ColHeader_" // Base name for column headers
#define NEWS_ROW_BG_        DASHBOARD_PREFIX + "NewsRowBG_"  // Base name for row background rectangles
#define NEWS_CELL_LABEL_    DASHBOARD_PREFIX + "NewsCell_" // Base name for data cell labels

// Filter Controls
#define FILTER_CURR_BTN     DASHBOARD_PREFIX + "FilterCurrBTN"
#define FILTER_IMP_BTN      DASHBOARD_PREFIX + "FilterImpBTN"
#define FILTER_TIME_BTN     DASHBOARD_PREFIX + "FilterTimeBTN"
#define FILTER_RESET_BTN    DASHBOARD_PREFIX + "FilterResetBTN" // Renamed Cancel Button
#define CURRENCY_BTN_       DASHBOARD_PREFIX + "CurrBTN_"      // Base name for currency buttons
#define IMPACT_BTN_         DASHBOARD_PREFIX + "ImpBTN_"       // Base name for impact buttons

// Trading Related UI (Keep separate prefix if needed, or include in dashboard)
#define TRADE_PREFIX        "NewsTrade_"
#define TRADE_COUNTDOWN     TRADE_PREFIX + "Countdown"
#define TRADE_INFO_LABEL    TRADE_PREFIX + "InfoLabel"

// --- Cosmetic Defines ---
#define FONT_HEADER          "Segoe UI Semibold" // Or Arial Bold
#define FONT_LABEL           "Segoe UI"          // Or Arial
#define FONT_BUTTON          "Segoe UI"          // Or Arial
#define FONT_DATA            "Segoe UI"          // Or Arial
#define FONT_ICON            "Wingdings"          // For check/cross symbols if needed reliably

#define FONT_SIZE_HEADER     16
#define FONT_SIZE_LABEL      10
#define FONT_SIZE_BUTTON     10
#define FONT_SIZE_COL_HEADER 10
#define FONT_SIZE_DATA       9
#define FONT_SIZE_IMPACT_SYM 18 // Adjusted size for the impact symbol

// Colors
#define CLR_PANEL_BG         C'40,40,45'        // Dark grey background
#define CLR_HEADER_AREA_BG   CLR_PANEL_BG        // Same as panel or slightly different
#define CLR_DATA_AREA_BG     C'50,50,55'        // Slightly lighter data area
#define CLR_ROW_BG_ALT       C'55,55,60'        // Alternating row color
#define CLR_BORDER           C'70,70,75'        // Subtle border color if needed
#define CLR_HEADER_FG        clrWhiteSmoke        // Header text
#define CLR_LABEL_FG         clrLightGray        // General labels
#define CLR_DATA_FG          clrGainsboro        // Data text
#define CLR_BUTTON_BG        C'60,60,65'        // Default button background
#define CLR_BUTTON_FG        clrWhiteSmoke        // Default button text
#define CLR_BUTTON_BORDER    C'80,80,85'        // Button border
#define CLR_BUTTON_SELECTED_BG C'75,75,80'      // Background for selected currency/impact buttons
#define CLR_BUTTON_SELECTED_BORDER clrDodgerBlue // Border for selected items
#define CLR_FILTER_ON        clrLimeGreen       // Text color for active filter toggle
#define CLR_FILTER_OFF       clrOrangeRed       // Text color for inactive filter toggle
#define CLR_RESET_BTN_BG     C'180,60,60'       // Red for reset button
#define CLR_RESET_BTN_FG     clrWhite

#define CLR_IMP_HIGH         C'255,60,60'       // Red
#define CLR_IMP_MED          C'255,153,0'       // Orange
#define CLR_IMP_LOW          C'255,216,0'       // Gold/Yellow
#define CLR_IMP_NONE         clrDimGray

// Icons (Using Unicode Characters - check font compatibility)
#define ICON_CHECKMARK       ShortToString(0x2714) // ✔
#define ICON_CROSSMARK       ShortToString(0x274C) // ❌ or 0x2716 (Heavy X)
#define ICON_IMPACT_SYMBOL   ShortToString(0x25CF) // ●

// --- Calendar Configuration ---
string array_calendar[] = {"Date", "Time", "Cur.", "Imp.", "Event", "Actual", "Forecast", "Previous"};
// Adjusted widths for better layout (especially Event)
int column_widths[] = {70, 50, 40, 40, 321, 60, 60, 60}; // Total Width: 701 (fits inside 740-margin)
int MAX_DISPLAY_ROWS = 10; // Max news rows to display on dashboard

// --- Filter Data ---
string curr_filter_options[] = {"AUD", "CAD", "CHF", "EUR", "GBP", "JPY", "NZD", "USD"};
string impact_filter_labels[] = {"None", "Low", "Medium", "High"};
ENUM_CALENDAR_EVENT_IMPORTANCE impact_enum_options[] = {
   CALENDAR_IMPORTANCE_NONE,
   CALENDAR_IMPORTANCE_LOW,
   CALENDAR_IMPORTANCE_MODERATE,
   CALENDAR_IMPORTANCE_HIGH
};

// --- Filter State ---
string selected_currencies[];
ENUM_CALENDAR_EVENT_IMPORTANCE selected_importances[];
bool enableCurrencyFilter = true;
bool enableImportanceFilter = true;
bool enableTimeFilter = true;

// --- Data Cache ---
MqlCalendarValue g_filtered_news_cache[]; // Global cache for filtered news
int g_total_considered = 0;
int g_total_filtered = 0;
int g_total_displayable = 0;
bool g_cache_needs_update = true; // Flag to signal need for data refresh

// --- Timer ---
#define TIMER_INTERVAL_SECONDS 30 // How often to refresh data automatically

// --- EA Inputs ---
sinput group "General Calendar Settings"
input ENUM_TIMEFRAMES p_time_range_past = PERIOD_H12;     // Look back this far
input ENUM_TIMEFRAMES p_time_range_future = PERIOD_H12;   // Look forward this far
input ENUM_TIMEFRAMES p_display_time_window = PERIOD_D1;  // Only display news +/- this window around now for filtering

sinput group "Trading Settings"
enum ETradeMode {
   TRADE_BEFORE, // Trade before the news event occurs
   TRADE_AFTER,  // Trade after the news event occurs
   NO_TRADE,     // Do not trade
   PAUSE_TRADING // Pause trading activity (no trades until resumed)
};
input ETradeMode p_tradeMode = TRADE_BEFORE;              // Choose the trade mode
input int p_tradeOffsetHours = 0;                         // Offset hours (e.g., 0 hours)
input int p_tradeOffsetMinutes = 5;                       // Offset minutes (e.g., 5 minutes before)
input int p_tradeOffsetSeconds = 0;                       // Offset seconds
input double p_tradeLotSize = 0.01;                       // Lot size for the trade
input int p_reset_delay_seconds = 15;                    // Seconds after news release to reset trade status

// --- Global Trade Variables ---
CTrade trade;
bool tradeExecuted = false;
datetime tradedNewsTime = 0;
long triggeredEventId = -1; // Store ID instead of using array for one trade
// --- Chart Appearance Restoration Variables ---
// ---> ADD THESE LINES START <---
 
 
 
 
color g_original_chart_line_color;
 
bool  g_original_chart_show_ohlc;
bool  g_original_chart_show_bid;
bool  g_original_chart_show_ask;
bool  g_original_chart_show_volume;
bool  g_original_chart_show_period_sep;
bool  g_original_chart_show_price_scale;
bool  g_original_chart_show_date_scale;
ENUM_CHART_MODE g_original_chart_mode;

// --- Chart Appearance Restoration Variables ---
color g_original_chart_bg_color;
color g_original_chart_fg_color;
color g_original_chart_grid_color;
color g_original_chart_vol_color;
color g_original_chart_candle_bull_color;
color g_original_chart_candle_bear_color;
// Use Bar Up/Down for Bar chart and line chart base color
color g_original_chart_bar_up_color; // Changed from line_color
color g_original_chart_bar_down_color; // Added
bool  g_original_chart_show_grid;
// ... rest of the bools and ENUM_CHART_MODE ...
// ---> ADD THESE LINES END <---
//+------------------------------------------------------------------+
//| Array Helper: Get Index of String in String Array                |
//| Returns -1 if not found. Case-sensitive.                        |
//+------------------------------------------------------------------+
int ArrayGetIndexOfString(const string &arr[], string value)
{
   for (int i = 0; i < ArraySize(arr); i++) {
      if (arr[i] == value) { // Case-sensitive comparison
         return i;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Custom Sort for MqlCalendarValue array by Time (Ascending)       |
//| Uses Bubble Sort - simple, okay for moderate array sizes.        |
//+------------------------------------------------------------------+
void SortMqlCalendarValueByTime(MqlCalendarValue &arr[])
{
   int n = ArraySize(arr);
   bool swapped;
   MqlCalendarValue temp; // Temporary variable for swapping structures
   if (n <= 1) {
      return; // Already sorted or empty
   }
   for (int i = 0; i < n - 1; i++) {
      swapped = false;
      for (int j = 0; j < n - i - 1; j++) {
         // Compare the 'time' member of adjacent elements
         if (arr[j].time > arr[j + 1].time) {
            // Swap the entire structures
            temp = arr[j];
            arr[j] = arr[j + 1];
            arr[j + 1] = temp;
            swapped = true;
         }
      }
      // If no two elements were swapped by inner loop, then break
      if (swapped == false) {
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Array Helper: Remove String Element by Index                     |
//+------------------------------------------------------------------+
bool ArrayRemoveString(string &arr[], int index, int count = 1)
{
   int size = ArraySize(arr);
   if (index < 0 || index >= size || count <= 0 || index + count > size) {
      Print(__FUNCTION__, ": Invalid index(", index, ") or count(", count, ") for array size ", size);
      return false; // Invalid index or count
   }
   // Shift elements down
   int elements_to_shift = size - (index + count);
   if(elements_to_shift > 0) {
      ArrayCopy(arr, arr, index, index + count, elements_to_shift);
   }
   // Resize array
   if(!ArrayResize(arr, size - count)) {
      Print(__FUNCTION__, ": Failed to resize string array! Error: ", GetLastError());
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Initialize Timer ---
   EventSetTimer(TIMER_INTERVAL_SECONDS);
   // ---> ADD THESE LINES START <---
   g_original_chart_bg_color = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_original_chart_fg_color = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_original_chart_grid_color = (color)ChartGetInteger(0, CHART_COLOR_GRID);
   g_original_chart_vol_color = (color)ChartGetInteger(0, CHART_COLOR_VOLUME);
   g_original_chart_candle_bull_color = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   g_original_chart_candle_bear_color = (color)ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   //g_original_chart_line_color = (color)ChartGetInteger(0, CHART_COLOR_LINE); // Also for bars if needed

   g_original_chart_show_grid = ChartGetInteger(0, CHART_SHOW_GRID);
   g_original_chart_show_ohlc = ChartGetInteger(0, CHART_SHOW_OHLC);
   g_original_chart_show_bid = ChartGetInteger(0, CHART_SHOW_BID_LINE);
   g_original_chart_show_ask = ChartGetInteger(0, CHART_SHOW_ASK_LINE);
   //g_original_chart_show_volume = ChartGetInteger(0, CHART_SHOW_VOLUME);
   g_original_chart_show_period_sep = ChartGetInteger(0, CHART_SHOW_PERIOD_SEP);
   g_original_chart_show_price_scale = ChartGetInteger(0, CHART_SHOW_PRICE_SCALE);
   g_original_chart_show_date_scale = ChartGetInteger(0, CHART_SHOW_DATE_SCALE);
   g_original_chart_mode = (ENUM_CHART_MODE)ChartGetInteger(0, CHART_MODE);

   // Apply Black Background and Hide Elements
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack); // Hide Axis text, OHLC
   ChartSetInteger(0, CHART_COLOR_GRID, clrBlack);       // Hide Grid color
   ChartSetInteger(0, CHART_SHOW_GRID, false);          // Hide Grid lines
   ChartSetInteger(0, CHART_SHOW_OHLC, false);          // Hide OHLC text
   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);      // Hide Bid line
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);      // Hide Ask line
   //ChartSetInteger(0, CHART_SHOW_VOLUME, false);        // Hide Volume bars/ticks
   ChartSetInteger(0, CHART_COLOR_VOLUME, clrBlack);     // Hide Volume color
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);   // Hide Period Separators
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);  // Hide Price Axis/Scale
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);   // Hide Time Axis/Scale

   // Make Candles/Bars/Line invisible by setting their color to the background color
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);
  // ChartSetInteger(0, CHART_COLOR_BAR_UP, clrBlack); // Same as line color usually
   //ChartSetInteger(0, CHART_COLOR_BAR_DOWN, clrBlack);
  // ChartSetInteger(0, CHART_COLOR_LINE, clrBlack);
   // ---> ADD THESE LINES END <---

   // --- Create Base Dashboard UI ---
   int panelX = 30, panelY = 30;
   int panelW = 740, panelH = 360; // Adjusted height
   int headerH = 30;
   int filterH = 55; // Height for filter section + status line
   int colHeaderH = 25;
   int dataAreaY = panelY + headerH + filterH + colHeaderH + 5; // +5 padding
   int dataAreaH = panelH - headerH - filterH - colHeaderH - 10; // Remaining height - padding
   // Main background
   createRecLabel(MAIN_REC, panelX, panelY, panelW, panelH, CLR_PANEL_BG, 1, CLR_BORDER);
   // Header area background (optional, could just use main panel BG)
   //createRecLabel(SUB_REC1, panelX + 1, panelY + 1, panelW - 2, headerH + filterH -2 , CLR_HEADER_AREA_BG, 0);
   // Header Text
   createLabel(HEADER_LABEL, panelX + 10, panelY + 5, "MQL5 Economic Calendar", CLR_HEADER_FG, FONT_SIZE_HEADER, FONT_HEADER);
   // Combined Time and Status Label
   createLabel(TIME_STATUS_LABEL, panelX + 10, panelY + headerH + 5, "Initializing...", CLR_LABEL_FG, FONT_SIZE_LABEL, FONT_LABEL);
   // --- Filter Controls ---
   int filterStartX = panelX + 280; // Start filters further right
   int filterY = panelY + headerH + 5; // Below main header text
   int filterBtnW_Curr = 100;
   int filterBtnW_Imp = 100;
   int filterBtnW_Time = 70;
   int filterBtnH = 25;
   int filterSpacing = 5;
   createLabel(FILTER_SECTION_LABEL, filterStartX, filterY, "Filters:", CLR_LABEL_FG, FONT_SIZE_LABEL, FONT_LABEL);
   filterStartX += 50; // Space after "Filters:"
   createButton(FILTER_CURR_BTN, filterStartX, filterY, filterBtnW_Curr, filterBtnH, "", CLR_BUTTON_FG, FONT_SIZE_BUTTON, CLR_BUTTON_BG, CLR_BUTTON_BORDER, FONT_BUTTON);
   filterStartX += filterBtnW_Curr + filterSpacing;
   createButton(FILTER_IMP_BTN, filterStartX, filterY, filterBtnW_Imp, filterBtnH, "", CLR_BUTTON_FG, FONT_SIZE_BUTTON, CLR_BUTTON_BG, CLR_BUTTON_BORDER, FONT_BUTTON);
   filterStartX += filterBtnW_Imp + filterSpacing;
   createButton(FILTER_TIME_BTN, filterStartX, filterY, filterBtnW_Time, filterBtnH, "", CLR_BUTTON_FG, FONT_SIZE_BUTTON, CLR_BUTTON_BG, CLR_BUTTON_BORDER, FONT_BUTTON);
   filterStartX += filterBtnW_Time + filterSpacing + 15; // Extra space before Reset
   createButton(FILTER_RESET_BTN, filterStartX, filterY, 40, filterBtnH, "X", CLR_RESET_BTN_FG, FONT_SIZE_BUTTON + 2, CLR_RESET_BTN_BG, CLR_BORDER, FONT_BUTTON);
   // --- Individual Filter Selection Buttons ---
   int selectorsStartY = filterY + filterBtnH + 5; // Below main filter buttons
   int currSelectorX = panelX + 10; // Start currency selectors on left
   int currSelectorY = selectorsStartY;
   int currBtnW = 50;
   int currBtnH = 22;
   int currSpacingX = 3;
   int currSpacingY = 3;
   int currMaxCols = 4; // Adjust as needed
   for (int i = 0; i < ArraySize(curr_filter_options); i++) {
      int row = i / currMaxCols;
      int col = i % currMaxCols;
      int x = currSelectorX + col * (currBtnW + currSpacingX);
      int y = currSelectorY + row * (currBtnH + currSpacingY);
      createButton(CURRENCY_BTN_ + curr_filter_options[i], x, y, currBtnW, currBtnH, curr_filter_options[i], CLR_BUTTON_FG, FONT_SIZE_BUTTON, CLR_BUTTON_BG, CLR_BUTTON_BORDER, FONT_BUTTON);
      ObjectSetInteger(0, CURRENCY_BTN_ + curr_filter_options[i], OBJPROP_STATE, enableCurrencyFilter); // Initially selected if filter is on
   }
   // Initialize selected_currencies if filter is on
   if(enableCurrencyFilter) {
      ArrayCopy(selected_currencies, curr_filter_options);
   }
   else {
      ArrayResize(selected_currencies, 0);
   }
   int impSelectorX = panelX + 250; // Position impact selectors
   int impSelectorY = selectorsStartY;
   int impBtnW = 65;
   int impBtnH = 22;
   int impSpacingX = 3;
   // Reset selected importances based on initial flag
   if(enableImportanceFilter) {
      ArrayResize(selected_importances, 0); // Clear first
      ArrayCopy(selected_importances, impact_enum_options); // Select all initially
   }
   else {
      ArrayResize(selected_importances, 0); // Empty if disabled
   }
   for (int i = 0; i < ArraySize(impact_filter_labels); i++) {
      int x = impSelectorX + i * (impBtnW + impSpacingX);
      color impColor = GetImpactColor(impact_enum_options[i]);
      // Create button with text, background is default, border might change on select
      createButton(IMPACT_BTN_ + impact_filter_labels[i], x, impSelectorY, impBtnW, impBtnH, impact_filter_labels[i], CLR_BUTTON_FG, FONT_SIZE_BUTTON, CLR_BUTTON_BG, CLR_BUTTON_BORDER, FONT_BUTTON);
      // Set initial selected state visually
      bool is_selected = false;
      for(int j=0; j<ArraySize(selected_importances); j++) {
         if(selected_importances[j] == impact_enum_options[i]) {
            is_selected = true;
            break;
         }
      }
      ObjectSetInteger(0, IMPACT_BTN_ + impact_filter_labels[i], OBJPROP_STATE, is_selected);
      ObjectSetInteger(0, IMPACT_BTN_ + impact_filter_labels[i], OBJPROP_BGCOLOR, is_selected ? CLR_BUTTON_SELECTED_BG : CLR_BUTTON_BG);
      ObjectSetInteger(0, IMPACT_BTN_ + impact_filter_labels[i], OBJPROP_BORDER_COLOR, is_selected ? CLR_BUTTON_SELECTED_BORDER : CLR_BUTTON_BORDER);
   }
   // --- Data Area ---
   // Data Area background
   createRecLabel(SUB_REC2, panelX + 1, dataAreaY, panelW - 2, dataAreaH, CLR_DATA_AREA_BG, 0);
   // Column Headers (Use Buttons for similar look/potential interactivity)
   int colStartX = panelX + 5; // Start columns slightly inside panel edge
   int colHeaderY = dataAreaY - colHeaderH - 2; // Position above data area
   for (int i = 0; i < ArraySize(array_calendar); i++) {
      // Use buttons for header look, disable interaction if not needed
      createButton(COL_HEADER_BTN_ + IntegerToString(i), colStartX, colHeaderY, column_widths[i], colHeaderH, array_calendar[i], CLR_HEADER_FG, FONT_SIZE_COL_HEADER, CLR_DATA_AREA_BG, clrNONE, FONT_HEADER); // No border, blend BG
      ObjectSetInteger(0, COL_HEADER_BTN_ + IntegerToString(i), OBJPROP_STATE, false);
      ObjectSetInteger(0, COL_HEADER_BTN_ + IntegerToString(i), OBJPROP_SELECTABLE, false);
      colStartX += column_widths[i] + 3; // +3 spacing between columns
   }
   // --- Update Filter Button Appearance ---
   UpdateFilterToggleButtonsAppearance(); // Set checkmarks/colors correctly
   // --- Initial Data Load ---
   g_cache_needs_update = true; // Flag for immediate update on first timer event or tick
   // We don't call Fetch/Display here directly anymore, OnTimer will handle it.
   Print("News Calendar Initialized. Waiting for first data update.");
   ChartRedraw(0); // Final redraw after all init setup
   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer(); // Stop the timer
   // Delete all objects created by this EA
   ObjectsDeleteAll(0, DASHBOARD_PREFIX);
   ObjectsDeleteAll(0, TRADE_PREFIX);
    // --- Restore Original Chart Settings ---
   // ---> ADD THESE LINES START <---
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, g_original_chart_bg_color);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, g_original_chart_fg_color);
   ChartSetInteger(0, CHART_COLOR_GRID, g_original_chart_grid_color);
   ChartSetInteger(0, CHART_COLOR_VOLUME, g_original_chart_vol_color);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, g_original_chart_candle_bull_color);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, g_original_chart_candle_bear_color);
   //ChartSetInteger(0, CHART_COLOR_LINE, g_original_chart_line_color);
   //ChartSetInteger(0, CHART_COLOR_BAR_UP, g_original_chart_line_color); // Restore Bar colors too
   //ChartSetInteger(0, CHART_COLOR_BAR_DOWN, g_original_chart_line_color);

   ChartSetInteger(0, CHART_SHOW_GRID, g_original_chart_show_grid);
   ChartSetInteger(0, CHART_SHOW_OHLC, g_original_chart_show_ohlc);
   ChartSetInteger(0, CHART_SHOW_BID_LINE, g_original_chart_show_bid);
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, g_original_chart_show_ask);
   //ChartSetInteger(0, CHART_SHOW_VOLUME, g_original_chart_show_volume);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, g_original_chart_show_period_sep);
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, g_original_chart_show_price_scale);
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, g_original_chart_show_date_scale);
   ChartSetInteger(0, CHART_MODE, g_original_chart_mode);
   // ---> ADD THESE LINES END <---
   
   Print("News Calendar Deinitialized. Reason: ", reason);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Expert timer function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // --- Refresh Dashboard Data Periodically ---
   RefreshDashboardData();
   // --- Less Frequent Check for Trade Candidates (Optional) ---
   // If CheckForNewsTrade's candidate search is heavy, run it here too.
   // The part checking *imminent* trades might still need OnTick.
   // Example: CheckForNewsTradeCandidates(); // A hypothetical lighter version
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Keep OnTick as light as possible
   // 1. Update Real-time Trade Countdowns & Check Imminent Trades
   UpdateTradeStatusAndCountdown(); // Renamed for clarity
   // 2. (Optional) Immediate data refresh if flagged
   // if(g_cache_needs_update) {
   //    RefreshDashboardData();
   // }
   // Typically handled by OnTimer and OnChartEvent now
}


//+------------------------------------------------------------------+
//| Chart Event handler function                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if (id == CHARTEVENT_OBJECT_CLICK) {
      bool refresh_needed = false;
      string clicked_object = sparam;
      // --- Reset Button ---
      if (clicked_object == FILTER_RESET_BTN) {
         // Reset filters to default ON state and clear selections
         enableCurrencyFilter = true;
         enableImportanceFilter = true;
         enableTimeFilter = true;
         ArrayCopy(selected_currencies, curr_filter_options);
         ArrayResize(selected_importances, 0); // Clear first
         ArrayCopy(selected_importances, impact_enum_options);
         // Update UI appearance
         UpdateFilterToggleButtonsAppearance();
         UpdateIndividualFilterButtonsAppearance();
         refresh_needed = true;
         Print("Filters Reset to Default.");
      }
      // --- Filter Toggle Buttons ---
      else if (StringFind(clicked_object, DASHBOARD_PREFIX + "Filter") == 0 && StringFind(clicked_object,"BTN") > 0 ) {
         bool current_state = ObjectGetInteger(0, clicked_object, OBJPROP_STATE);
         bool new_state = !current_state; // Toggle the state
         if (clicked_object == FILTER_CURR_BTN) {
            enableCurrencyFilter = new_state;
            if(!new_state) ArrayResize(selected_currencies, 0); // Clear selection if disabling
            else ArrayCopy(selected_currencies, curr_filter_options); // Select all if enabling
            UpdateIndividualFilterButtonsAppearance(); // Update currency button states
            Print("Currency Filter Toggled: ", enableCurrencyFilter ? "ON" : "OFF");
            refresh_needed = true;
         }
         else if (clicked_object == FILTER_IMP_BTN) {
            enableImportanceFilter = new_state;
            if(!new_state) ArrayResize(selected_importances, 0); // Clear selection if disabling
            else ArrayCopy(selected_importances, impact_enum_options); // Select all if enabling
            UpdateIndividualFilterButtonsAppearance(); // Update impact button states
            Print("Importance Filter Toggled: ", enableImportanceFilter ? "ON" : "OFF");
            refresh_needed = true;
         }
         else if (clicked_object == FILTER_TIME_BTN) {
            enableTimeFilter = new_state;
            Print("Time Filter Toggled: ", enableTimeFilter ? "ON" : "OFF");
            refresh_needed = true;
         }
         // Update the toggle button's own appearance (Check/Cross, color)
         ObjectSetInteger(0, clicked_object, OBJPROP_STATE, new_state); // Update the state
         UpdateFilterToggleButtonsAppearance(); // Update visual based on flags
      }
      // --- Individual Currency Buttons ---
      else if (StringFind(clicked_object, CURRENCY_BTN_) == 0) {
         if (!enableCurrencyFilter) return; // Ignore clicks if master filter is off
         string currency = StringSubstr(clicked_object, StringLen(CURRENCY_BTN_));
         bool is_selected = ObjectGetInteger(0, clicked_object, OBJPROP_STATE);
         bool new_selected_state = !is_selected; // Toggle selection
         if (new_selected_state) { // Add currency
            if (ArrayGetIndexOfString(selected_currencies, currency) < 0) {
               int size = ArraySize(selected_currencies);
               ArrayResize(selected_currencies, size + 1);
               selected_currencies[size] = currency;
            }
         }
         else {   // Remove currency
            int index = ArrayGetIndexOfString(selected_currencies, currency); // Use correct helper
            if (index >= 0) {
               ArrayRemove(selected_currencies, index, 1);
            }
         }
         ObjectSetInteger(0, clicked_object, OBJPROP_STATE, new_selected_state); // Update button state visually
         UpdateIndividualFilterButtonsAppearance(); // Reflect change (border/bg)
         Print("Currency selection updated: ", currency, new_selected_state ? " Added" : " Removed");
         ArrayPrint(selected_currencies);
         refresh_needed = true;
      }
      // --- Individual Impact Buttons ---
      else if (StringFind(clicked_object, IMPACT_BTN_) == 0) {
         if (!enableImportanceFilter) return; // Ignore clicks if master filter is off
         string label = StringSubstr(clicked_object, StringLen(IMPACT_BTN_));
         ENUM_CALENDAR_EVENT_IMPORTANCE level = GetImportanceEnumFromLabel(label);
         if (level == WRONG_VALUE) return; // Safety check
         bool is_selected = ObjectGetInteger(0, clicked_object, OBJPROP_STATE);
         bool new_selected_state = !is_selected; // Toggle selection
         if (new_selected_state) { // Add level
            if (ArrayGetIndexOfEnum(selected_importances, level) < 0) {
               int size = ArraySize(selected_importances);
               ArrayResize(selected_importances, size + 1);
               selected_importances[size] = level;
            }
         }
         else {   // Remove level
            int index = ArrayGetIndexOfEnum(selected_importances, level);
            if (index >= 0) {
               ArrayRemoveEnum(selected_importances, index, 1);
            }
         }
         ObjectSetInteger(0, clicked_object, OBJPROP_STATE, new_selected_state); // Update button state visually
         UpdateIndividualFilterButtonsAppearance(); // Reflect change (border/bg)
         Print("Importance selection updated: ", label, new_selected_state ? " Added" : " Removed");
         ArrayPrint(selected_importances);
         refresh_needed = true;
      }
      // --- Refresh data if any relevant filter changed ---
      if (refresh_needed) {
         g_cache_needs_update = true;
         RefreshDashboardData(); // Refresh immediately on filter change
         UpdateFilterInfoLog();  // Log the current filter state
      }
   }
}

//+------------------------------------------------------------------+
//| Refresh Dashboard Data (Call from OnTimer or OnChartEvent)       |
//+------------------------------------------------------------------+
void RefreshDashboardData()
{
   // If an update is already flagged, or if forced, proceed
   if (!g_cache_needs_update && !IsForceRefreshNeeded()) { // Add IsForceRefreshNeeded logic if applicable
      // Potentially add time check here: if last update was > X seconds ago, force refresh?
      //return;
   }
   if (FetchAndFilterNews(g_filtered_news_cache, g_total_considered, g_total_filtered)) {
      // Calculate how many are actually displayable based on limit
      g_total_displayable = MathMin(ArraySize(g_filtered_news_cache), MAX_DISPLAY_ROWS);
      ClearNewsDisplay();
      DisplayNewsOnDashboard(g_filtered_news_cache, g_total_displayable); // Pass display count
      UpdateStatusLabel(g_total_displayable, g_total_filtered, g_total_considered);
      g_cache_needs_update = false; // Reset flag after successful update
      ChartRedraw(0); // Redraw after updating dashboard content
      Print("Dashboard data refreshed.");
   }
   else {
      Print("Failed to fetch or filter news data for dashboard.");
      // Optionally update status label to show error?
      UpdateStatusLabel(-1,-1,-1, "Error loading data"); // Example error state
   }
}


//+------------------------------------------------------------------+
//| Check if a refresh is needed (placeholder for more complex logic)|
//+------------------------------------------------------------------+
bool IsForceRefreshNeeded()
{
   // Example: Check if time has significantly passed,
   // or if a critical event just happened, etc.
   // For now, mainly rely on the timer and g_cache_needs_update flag
   return false;
}

//+------------------------------------------------------------------+
//| Fetches and filters news based on current global settings       |
//+------------------------------------------------------------------+
bool FetchAndFilterNews(MqlCalendarValue &output_filtered_values[], int &count_considered, int &count_filtered)
{
   ArrayFree(output_filtered_values);
   count_considered = 0;
   count_filtered = 0;
   MqlCalendarValue all_values[];
   datetime startTime = TimeTradeServer() - PeriodSeconds(p_time_range_past);
   datetime endTime = TimeTradeServer() + PeriodSeconds(p_time_range_future);
   // Define the stricter time window for *filtering* based on p_display_time_window
   datetime filterWindowStart = TimeTradeServer() - PeriodSeconds(p_display_time_window);
   datetime filterWindowEnd = TimeTradeServer() + PeriodSeconds(p_display_time_window);
   int allValuesCount = CalendarValueHistory(all_values, startTime, endTime, NULL, NULL);
   if (allValuesCount < 0) {
      Print("Error fetching calendar history: ", GetLastError());
      return false;
   }
   if (allValuesCount == 0) return true; // No events, but successful fetch
   int initial_capacity = MathMin(allValuesCount, 100); // Preallocate reasonable size
   ArrayResize(output_filtered_values, 0, initial_capacity);
   for (int i = 0; i < allValuesCount; i++) {
      count_considered++;
      // Apply Time Filter first (using the tighter p_display_time_window)
      if (enableTimeFilter) {
         datetime eventTime = all_values[i].time;
         if (eventTime < filterWindowStart || eventTime > filterWindowEnd) {
            continue; // Skip if outside the display window
         }
      }
      MqlCalendarEvent event;
      if (!CalendarEventById(all_values[i].event_id, event)) {
         Print("Warning: Could not get event details for ID ", all_values[i].event_id);
         continue;
      }
      MqlCalendarCountry country;
      if (!CalendarCountryById(event.country_id, country)) {
         Print("Warning: Could not get country details for event ID ", all_values[i].event_id);
         continue;
      }
      // Apply Currency Filter
      if (enableCurrencyFilter) {
         bool currencyMatch = false;
         for (int j = 0; j < ArraySize(selected_currencies); j++) {
            if (country.currency == selected_currencies[j]) {
               currencyMatch = true;
               break;
            }
         }
         if (!currencyMatch) continue;
      }
      // Apply Importance Filter
      if (enableImportanceFilter) {
         bool importanceMatch = false;
         for (int k = 0; k < ArraySize(selected_importances); k++) {
            if (event.importance == selected_importances[k]) {
               importanceMatch = true;
               break;
            }
         }
         if (!importanceMatch) continue;
      }
      // If all filters passed, add to output array
      int current_size = ArraySize(output_filtered_values);
      // Check if resize needed (less frequent than resizing every time)
      if (count_filtered >= current_size) {
         // Increase capacity, e.g., double it or add a fixed amount
         ArrayResize(output_filtered_values, current_size + MathMax(current_size / 2, 10) );
      }
      // Copy the relevant data (ensure MqlCalendarValue struct has necessary fields populated by CalendarValueHistory)
      // It's often safer to copy specific fields if the whole struct is large or contains pointers/handles you don't need.
      // Assuming MqlCalendarValue is reasonably self-contained here.
      if(count_filtered < ArraySize(output_filtered_values)) { // Check bounds after potential resize
         output_filtered_values[count_filtered] = all_values[i];
         count_filtered++;
      }
      else {
         Print("Error: Filtered count exceeds array capacity after resize attempt."); // Should not happen with proper resize
      }
   }
   // Trim excess capacity from the array
   ArrayResize(output_filtered_values, count_filtered);
   // Sort the results by time (important for display and trading logic)
   //ArraySort(output_filtered_values); // MqlCalendarValue is sortable by time
   SortMqlCalendarValueByTime(output_filtered_values); // Use custom sort by time
   return true;
}


//+------------------------------------------------------------------+
//| Clears existing news display elements (rows and backgrounds)     |
//+------------------------------------------------------------------+
void ClearNewsDisplay()
{
   // Delete row backgrounds and cell labels specifically
   // Looping is safer than ObjectsDeleteAll with complex base names if other objects share prefix
   for(int i = 0; i < MAX_DISPLAY_ROWS + 5; i++) { // Loop slightly beyond max to catch potential leftovers
      ObjectDelete(0, NEWS_ROW_BG_ + IntegerToString(i));
      for (int k = 0; k < ArraySize(array_calendar); k++) {
         ObjectDelete(0, NEWS_CELL_LABEL_ + IntegerToString(i) + "_" + IntegerToString(k));
      }
   }
}

//+------------------------------------------------------------------+
//| Displays the filtered news data on the dashboard                 |
//+------------------------------------------------------------------+
void DisplayNewsOnDashboard(const MqlCalendarValue &filtered_data[], int display_count)
{
   int panelX = 30;
   int panelY = 30;
   int headerH = 30;
   int filterH = 55;
   int colHeaderH = 25;
   int dataAreaStartY = panelY + headerH + filterH + colHeaderH + 5; // Matches OnInit
   int rowHeight = 22; // Height for each data row + spacing
   int startY = dataAreaStartY + 2; // Start Y position inside data area
   for (int i = 0; i < display_count; i++) {
      MqlCalendarEvent event;
      if (!CalendarEventById(filtered_data[i].event_id, event)) continue;
      MqlCalendarCountry country;
      if (!CalendarCountryById(event.country_id, country)) continue;
      MqlCalendarValue value_details; // Fetch actual/forecast/prev separately if not in filtered_data
      if (!CalendarValueById(filtered_data[i].id, value_details)) continue;
      // Row Background
      color holder_color = (i % 2 == 0) ? CLR_DATA_AREA_BG : CLR_ROW_BG_ALT;
      int rowBgX = panelX + 3;
      int rowBgWidth = 734; // Fit within panel padding
      createRecLabel(NEWS_ROW_BG_ + string(i), rowBgX, startY - 2, rowBgWidth, rowHeight, holder_color, 0, clrNONE); // No border
      // Data Cells
      int startX = panelX + 5; // Start columns slightly inside panel edge
      string news_data[ArraySize(array_calendar)];
      string obj_id_base = NEWS_CELL_LABEL_ + IntegerToString(i) + "_";
      // Populate news_data array
      news_data[0] = TimeToString(filtered_data[i].time, TIME_DATE);
      news_data[1] = TimeToString(filtered_data[i].time, TIME_MINUTES);
      news_data[2] = country.currency;
      news_data[3] = ICON_IMPACT_SYMBOL;
      news_data[4] = event.name;
      // Use value_details for these as they might be updated after initial fetch
      news_data[5] = FormatValue(value_details.GetActualValue(), event.unit);
      news_data[6] = FormatValue(value_details.GetForecastValue(), event.unit);
      news_data[7] = FormatValue(value_details.GetPreviousValue(), event.unit);
      color importance_color = GetImpactColor(event.importance);
      for (int k = 0; k < ArraySize(array_calendar); k++) {
         string cell_obj_id = obj_id_base + IntegerToString(k);
         int current_col_width = column_widths[k];
         int cell_y_offset = (rowHeight - FONT_SIZE_DATA - 4)/2; // Center text vertically slightly
         // --- Create Label with specific alignment ---
         if (k == 0 || k == 1) { // Date, Time - Center
            createLabel(cell_obj_id, startX + current_col_width/2, startY + cell_y_offset, news_data[k], CLR_DATA_FG, FONT_SIZE_DATA, FONT_DATA, TextAnchor::Center);
         }
         else if (k == 2) {   // Currency - Center
            createLabel(cell_obj_id, startX + current_col_width/2, startY + cell_y_offset, news_data[k], CLR_DATA_FG, FONT_SIZE_DATA, FONT_DATA, TextAnchor::Center);
         }
         else if (k == 3) {   // Impact Symbol - Center
            createLabel(cell_obj_id, startX + current_col_width / 2, startY + (rowHeight - FONT_SIZE_IMPACT_SYM)/2, news_data[k], importance_color, FONT_SIZE_IMPACT_SYM, FONT_DATA, TextAnchor::Center);
         }
         else if (k == 4) {   // Event - Left Align
            createLabel(cell_obj_id, startX + 3, startY + cell_y_offset, news_data[k], CLR_DATA_FG, FONT_SIZE_DATA, FONT_DATA, TextAnchor::Left);
         }
         else {   // Actual, Forecast, Previous - Right Align
            createLabel(cell_obj_id, startX + current_col_width - 3, startY + cell_y_offset, news_data[k], CLR_DATA_FG, FONT_SIZE_DATA, FONT_DATA, TextAnchor::Right);
         }
         startX += current_col_width + 3; // +3 spacing between columns
      }
      startY += rowHeight; // Move to next row position
   }
}

//+------------------------------------------------------------------+
//| Updates the status label (Time & News Counts)                    |
//+------------------------------------------------------------------+
void UpdateStatusLabel(int displayable, int filtered, int considered, string prefix = "")
{
   string status_text;
   if (displayable < 0) { // Error state indication
      status_text = prefix;
   }
   else {
      status_text = prefix + "Server Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) +
                    " || News (Disp/Filt/Total): " + IntegerToString(displayable) + "/" +
                    IntegerToString(filtered) + "/" + IntegerToString(considered);
   }
   if (ObjectFind(0, TIME_STATUS_LABEL) >= 0) {
      ObjectSetString(0, TIME_STATUS_LABEL, OBJPROP_TEXT, status_text);
   }
   else {
      // Recreate if missing (shouldn't happen unless OnDeinit failed)
      int panelX = 30, panelY = 30, headerH = 30;
      createLabel(TIME_STATUS_LABEL, panelX + 10, panelY + headerH + 5, status_text, CLR_LABEL_FG, FONT_SIZE_LABEL, FONT_LABEL);
   }
}


//+------------------------------------------------------------------+
//| Updates visual state of main filter toggle buttons               |
//+------------------------------------------------------------------+
void UpdateFilterToggleButtonsAppearance()
{
   // Currency Filter Button
   string curr_text = (enableCurrencyFilter ? ICON_CHECKMARK : ICON_CROSSMARK) + " Currency";
   color curr_color = enableCurrencyFilter ? CLR_FILTER_ON : CLR_FILTER_OFF;
   ObjectSetString(0, FILTER_CURR_BTN, OBJPROP_TEXT, curr_text);
   ObjectSetInteger(0, FILTER_CURR_BTN, OBJPROP_COLOR, curr_color);
   //ObjectSetInteger(0, FILTER_CURR_BTN, OBJPROP_STATE, enableCurrencyFilter); // Ensure state matches flag
   // Importance Filter Button
   string imp_text = (enableImportanceFilter ? ICON_CHECKMARK : ICON_CROSSMARK) + " Importance";
   color imp_color = enableImportanceFilter ? CLR_FILTER_ON : CLR_FILTER_OFF;
   ObjectSetString(0, FILTER_IMP_BTN, OBJPROP_TEXT, imp_text);
   ObjectSetInteger(0, FILTER_IMP_BTN, OBJPROP_COLOR, imp_color);
   //ObjectSetInteger(0, FILTER_IMP_BTN, OBJPROP_STATE, enableImportanceFilter);
   // Time Filter Button
   string time_text = (enableTimeFilter ? ICON_CHECKMARK : ICON_CROSSMARK) + " Time";
   color time_color = enableTimeFilter ? CLR_FILTER_ON : CLR_FILTER_OFF;
   ObjectSetString(0, FILTER_TIME_BTN, OBJPROP_TEXT, time_text);
   ObjectSetInteger(0, FILTER_TIME_BTN, OBJPROP_COLOR, time_color);
   // ObjectSetInteger(0, FILTER_TIME_BTN, OBJPROP_STATE, enableTimeFilter);
}


//+------------------------------------------------------------------+
//| Updates individual currency/impact button appearances            |
//+------------------------------------------------------------------+
void UpdateIndividualFilterButtonsAppearance()
{
   // Update Currency Buttons
   for (int i = 0; i < ArraySize(curr_filter_options); i++) {
      string btn_name = CURRENCY_BTN_ + curr_filter_options[i];
      if(ObjectFind(0, btn_name) < 0) continue;
      bool is_selected = ArrayGetIndexOfString(selected_currencies, curr_filter_options[i]) >= 0;
      ObjectSetInteger(0, btn_name, OBJPROP_STATE, is_selected && enableCurrencyFilter); // Visually selected only if master filter is also ON
      ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, (is_selected && enableCurrencyFilter) ? CLR_BUTTON_SELECTED_BG : CLR_BUTTON_BG);
      ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, (is_selected && enableCurrencyFilter) ? CLR_BUTTON_SELECTED_BORDER : CLR_BUTTON_BORDER);
      ObjectSetInteger(0, btn_name, OBJPROP_COLOR, (is_selected && enableCurrencyFilter) ? clrWhite : CLR_BUTTON_FG); // Highlight text color maybe?
      // Dim the button if master filter is OFF
      if (!enableCurrencyFilter) {
         ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, CLR_DATA_AREA_BG); // Make it look disabled
         ObjectSetInteger(0, btn_name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, CLR_BUTTON_BORDER);
      }
   }
   // Update Impact Buttons
   for (int i = 0; i < ArraySize(impact_filter_labels); i++) {
      string btn_name = IMPACT_BTN_ + impact_filter_labels[i];
      if(ObjectFind(0, btn_name) < 0) continue;
      bool is_selected = ArrayGetIndexOfEnum(selected_importances, impact_enum_options[i]) >= 0;
      ObjectSetInteger(0, btn_name, OBJPROP_STATE, is_selected && enableImportanceFilter); // Visually selected only if master filter is also ON
      ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, (is_selected && enableImportanceFilter) ? CLR_BUTTON_SELECTED_BG : CLR_BUTTON_BG);
      ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, (is_selected && enableImportanceFilter) ? CLR_BUTTON_SELECTED_BORDER : CLR_BUTTON_BORDER);
      ObjectSetInteger(0, btn_name, OBJPROP_COLOR, (is_selected && enableImportanceFilter) ? clrWhite : CLR_BUTTON_FG); // Highlight text color maybe?
      // Dim the button if master filter is OFF
      if (!enableImportanceFilter) {
         ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, CLR_DATA_AREA_BG); // Make it look disabled
         ObjectSetInteger(0, btn_name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, CLR_BUTTON_BORDER);
      }
   }
}


//+------------------------------------------------------------------+
//| Format News Value (e.g., add K, M, %, etc.)                     |
//+------------------------------------------------------------------+
string FormatValue(double value, string unit)
{
   // Check for empty or zero value
   if ( value == 0.0) { // Handle zero specially if needed
      //if (value == CALENDAR_VALUE_EMPTY) 
      return "N/A"; // Or "-", " "
      // return "0.0"; // If 0.0 is a valid value
   }
   string suffix = "";
   if (unit == "K") suffix = "K"; // Thousands
   else if (unit == "M") suffix = "M"; // Millions
   else if (unit == "B") suffix = "B"; // Billions (if applicable)
   else if (unit == "%") suffix = "%"; // Percentage
   else if (StringFind(unit,".",0) >= 0) suffix = " " + unit; // Handle like "index pts." - could refine
   // Determine precision (crude example, adjust based on value magnitude/unit)
   int digits = 2;
   if (MathAbs(value) < 1) digits = 3;
   if (MathAbs(value) >= 1000 || unit == "%") digits = 1;
   if (unit == "K" || unit == "M" || unit == "B") digits = 1; // Often simplified
   if (value == 0.0) digits = 1;
   // Use built-in formatter or custom logic
   return DoubleToString(value, digits) + suffix;
}



//+------------------------------------------------------------------+
//| Get Impact Color                                                 |
//+------------------------------------------------------------------+
color GetImpactColor(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   switch (imp) {
   case CALENDAR_IMPORTANCE_HIGH:
      return CLR_IMP_HIGH;
   case CALENDAR_IMPORTANCE_MODERATE:
      return CLR_IMP_MED;
   case CALENDAR_IMPORTANCE_LOW:
      return CLR_IMP_LOW;
   case CALENDAR_IMPORTANCE_NONE:
      return CLR_IMP_NONE;
   default:
      return clrGray; // Default unknown
   }
}

//+------------------------------------------------------------------+
//| Get Importance Enum from Label Text                             |
//+------------------------------------------------------------------+
ENUM_CALENDAR_EVENT_IMPORTANCE GetImportanceEnumFromLabel(string label)
{
   for(int i=0; i<ArraySize(impact_filter_labels); i++) {
      if(impact_filter_labels[i] == label) {
         return impact_enum_options[i];
      }
   }
   return WRONG_VALUE; // Indicate not found
}

//+------------------------------------------------------------------+
//| Array Helper: Get Index of Enum in Enum Array                    |
//+------------------------------------------------------------------+
int ArrayGetIndexOfEnum(const ENUM_CALENDAR_EVENT_IMPORTANCE &arr[], ENUM_CALENDAR_EVENT_IMPORTANCE value)
{
   for (int i = 0; i < ArraySize(arr); i++) {
      if (arr[i] == value) {
         return i;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Array Helper: Remove Enum Element by Index                       |
//+------------------------------------------------------------------+
bool ArrayRemoveEnum(ENUM_CALENDAR_EVENT_IMPORTANCE &arr[], int index, int count = 1)
{
   int size = ArraySize(arr);
   if (index < 0 || index >= size || count <= 0 || index + count > size) {
      return false; // Invalid index or count
   }
   // Shift elements down
   for (int i = index; i < size - count; i++) {
      arr[i] = arr[i + count];
   }
   // Resize array
   ArrayResize(arr, size - count);
   return true;
}


//+------------------------------------------------------------------+
//| Log current filter settings                                     |
//+------------------------------------------------------------------+
void UpdateFilterInfoLog()
{
   string filterInfo = "Filters Active -> ";
   filterInfo += "Curr: " + (enableCurrencyFilter ? ArrayToString(selected_currencies) : "OFF");
   filterInfo += "; Imp: " + (enableImportanceFilter ? EnumArrayToString(selected_importances) : "OFF");
   filterInfo += "; Time: " + (enableTimeFilter ? EnumToString(p_display_time_window) : "OFF");
   Print(filterInfo);
}

//+------------------------------------------------------------------+
//| Convert Enum Array to String for Logging                        |
//+------------------------------------------------------------------+
string EnumArrayToString(const ENUM_CALENDAR_EVENT_IMPORTANCE &arr[])
{
   string result = "[";
   for(int i=0; i<ArraySize(arr); i++) {
      result += EnumToString(arr[i]);
      if(i < ArraySize(arr) - 1) result += ", ";
   }
   result += "]";
   return result;
}

//+------------------------------------------------------------------+
//| Convert String Array to String for Logging                       |
//+------------------------------------------------------------------+
string ArrayToString(const string &arr[])
{
   string result = "[";
   for(int i=0; i<ArraySize(arr); i++) {
      result += arr[i];
      if(i < ArraySize(arr) - 1) result += ", ";
   }
   result += "]";
   return result;
}


// --- UI HELPER FUNCTIONS (Standardized Names) ---

//+------------------------------------------------------------------+
//| Creates a Rectangle Label                                        |
//+------------------------------------------------------------------+
bool createRecLabel(string objName, int xD, int yD, int xS, int yS,
                    color clrBg, int widthBorder, color clrBorder = clrNONE,
                    ENUM_BORDER_TYPE borderType = BORDER_FLAT, ENUM_LINE_STYLE borderStyle = STYLE_SOLID,
                    bool back = false, bool selectable = false)   // Added optional params
{
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": Failed to create '", objName, "' Error: ", _LastError);
      return (false);
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xD);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yD);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xS);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, yS);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrBg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, borderType);
   if(borderType == BORDER_FLAT) { // These only apply if flat border
      ObjectSetInteger(0, objName, OBJPROP_STYLE, borderStyle);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, widthBorder);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBorder); // Border color
   }
   ObjectSetInteger(0, objName, OBJPROP_BACK, back); // Let it be background?
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, objName, OBJPROP_STATE, false); // Ensure initial state is correct
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   // No ChartRedraw here - caller should batch redraws
   return (true);
}


//+------------------------------------------------------------------+
//| Creates a Button                                                 |
//+------------------------------------------------------------------+
bool createButton(string objName, int xD, int yD, int xS, int yS,
                  string txt = "", color clrTxt = clrBlack, int fontSize = 12,
                  color clrBg = clrNONE, color clrBorder = clrNONE,
                  string font = "Arial", bool state = false, bool selectable = true)   // Default selectable=true
{
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0)) {
      Print(__FUNCTION__, ": Failed to create '", objName, "' Error: ", _LastError);
      return (false);
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xD);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yD);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, xS);
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, yS);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, objName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTxt);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clrBg);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBorder);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false); // Buttons are usually not background objects
   ObjectSetInteger(0, objName, OBJPROP_STATE, state); // Initial pressed state
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   // No ChartRedraw here
   return (true);
}

//+------------------------------------------------------------------+
//| Creates a Text Label (with Anchor option)                       |
//+------------------------------------------------------------------+
enum TextAnchor {
   Left,
   Center,
   Right
};
//+------------------------------------------------------------------+
//| Creates a Text Label (with Anchor option)                       |
//+------------------------------------------------------------------+
bool createLabel(string objName, int xD, int yD, string txt,
                 color clrTxt = clrBlack, int fontSize = 12, string font = "Arial",
                 TextAnchor anchor = TextAnchor::Left, int angle = 0,
                 bool back = false, bool selectable = false)
{
   ResetLastError();
   if (!ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
      Print(__FUNCTION__, ": Failed to create '", objName, "' Error: ", _LastError);
      return (false);
   }
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, xD);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, yD);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER); // Anchor point of the object itself
   // Set anchor point for the text *within* the object's bounds
   ENUM_ANCHOR_POINT point = ANCHOR_LEFT_UPPER; // Default MQL5 anchor
   if (anchor == TextAnchor::Left) point = ANCHOR_LEFT;
   else if (anchor == TextAnchor::Center) point = ANCHOR_CENTER;
   else if (anchor == TextAnchor::Right) point = ANCHOR_RIGHT;
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, point);
   ObjectSetString(0, objName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clrTxt);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, font);
   ObjectSetDouble(0, objName, OBJPROP_ANGLE, angle); // Set angle
   ObjectSetInteger(0, objName, OBJPROP_BACK, back);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   // No ChartRedraw here
   return (true);
}


// --- TRADING LOGIC ---
// Needs significant refactoring based on the new structure
// Recommendation: Call a CheckForTradeOpportunities function from OnTimer (less frequent)
// And keep the UpdateTradeStatusAndCountdown in OnTick

//+------------------------------------------------------------------+
//| Updates trade status, countdowns, handles trade reset           |
//+------------------------------------------------------------------+
void UpdateTradeStatusAndCountdown()
{
   // Exit if trading is disabled
   if (p_tradeMode == NO_TRADE || p_tradeMode == PAUSE_TRADING) {
      DeleteTradeUI();
      return;
   }
   datetime currentTime = TimeTradeServer();
   // --- Post-Trade Logic ---
   if (tradeExecuted) {
      string countdownText = "";
      color bgColor = clrBlue; // Default countdown color
      if (currentTime < tradedNewsTime) { // Before news release
         int remainingSeconds = (int)(tradedNewsTime - currentTime);
         int hrs = remainingSeconds / 3600;
         int mins = (remainingSeconds % 3600) / 60;
         int secs = remainingSeconds % 60;
         countdownText = StringFormat("News In: %02d:%02d:%02d", hrs, mins, secs);
         bgColor = clrDarkSlateGray; // Or some neutral color for waiting
      }
      else {   // After news release
         int elapsed = (int)(currentTime - tradedNewsTime);
         if (elapsed < p_reset_delay_seconds) { // In reset window
            int remainingDelay = p_reset_delay_seconds - elapsed;
            countdownText = StringFormat("Released. Resetting in: %ds", remainingDelay);
            bgColor = CLR_RESET_BTN_BG; // Red during reset delay
         }
         else {   // Reset delay over
            Print("News time passed. Resetting trade status.");
            tradeExecuted = false;
            tradedNewsTime = 0;
            triggeredEventId = -1; // Reset triggered ID
            DeleteTradeUI();
            // Potentially trigger a check for new opportunities now?
            // CheckForTradeOpportunities();
            return; // Exit after reset
         }
      }
      // Update or Create Countdown UI Object
      UpdateOrCreateTradeCountdown(countdownText, bgColor);
      return; // Don't check for new trades while one is active/pending reset
   }
   // --- Pre-Trade Logic (Check for Opportunities) ---
   // This part might be better called less frequently (e.g., OnTimer or every few seconds)
   // If called from OnTick, ensure it's very efficient.
   CheckForTradeOpportunities(currentTime);
}

//+------------------------------------------------------------------+
//| Checks for news events meeting trade criteria                     |
//+------------------------------------------------------------------+
void CheckForTradeOpportunities(datetime currentTime)
{
   // Use the globally filtered news cache if available and recent enough
   // Avoid fetching/filtering again here if possible
   if(g_cache_needs_update || ArraySize(g_filtered_news_cache) == 0) {
      // Maybe trigger a refresh or wait? For now, we proceed but results might be stale.
      // Alternatively, force a FetchAndFilterNews here if high precision needed, but defeats purpose of OnTimer
      // Let's assume g_filtered_news_cache is reasonably up-to-date from OnTimer
      Print("Warning: Checking for trades, but news cache might be stale or empty.");
      DeleteTradeUI(); // Clear any old countdown
      return;
   }
   long candidateEventID = -1;
   datetime candidateEventTime = 0;
   string candidateTradeSide = "";
   string candidateEventName = "";
   int offsetSeconds = p_tradeOffsetHours * 3600 + p_tradeOffsetMinutes * 60 + p_tradeOffsetSeconds;
   // Iterate through the *already filtered and sorted* cache
   for (int i = 0; i < ArraySize(g_filtered_news_cache); i++) {
      MqlCalendarValue event_data = g_filtered_news_cache[i];
      datetime eventTime = event_data.time;
      // Skip events too far in the past or already happened
      if (eventTime < currentTime - 60) continue; // Skip events released > 1 min ago
      // Skip if already triggered (though single trade logic might make this less needed)
      //if(event_data.event_id == triggeredEventId) continue; // Should be handled by tradeExecuted flag primarily
      // Check for TRADE_BEFORE condition
      if (p_tradeMode == TRADE_BEFORE) {
         datetime tradeStartTime = eventTime - offsetSeconds;
         // Is current time within the trade window *before* the event?
         if (currentTime >= tradeStartTime && currentTime < eventTime) 
         {
               //                    // Get specific values for trade decision (Forecast vs Previous)
               //                    MqlCalendarValue value_details;
               //                    if (!CalendarValueById(event_data.id, value_details)) {
               //                        Print("CheckForTradeOpportunities: Error getting value details for event ID ", event_data.id);
               //                        continue; // Skip if cannot get details
               //                    }
               //                    double forecast = value_details.GetForecastValue();
               //                    double previous = value_details.GetPreviousValue();
               //
               //                    // Basic trade logic (Forecast vs Previous) - Refine as needed!
               //                     if (value_details.IsValueEmpty(forecast) || value_details.IsValueEmpty(previous) || forecast == previous) {
               //                          // Print("Skipping event ", event_data.id, " due to missing/equal forecast/previous."); // Maybe too verbose
               //                          continue; // Skip if data unsuitable for this simple logic
               //                     }
               //
               //                     string side = (forecast > previous) ? "BUY" : "SELL";
            MqlCalendarValue value_details;
            if (!CalendarValueById(event_data.id, value_details)) {
               Print("Error getting value details for event ID ", event_data.id);
               continue;
            }
            double forecast = value_details.forecast_value;
            double previous = value_details.prev_value;
            if (forecast == 0.0 || previous == 0.0 || forecast == previous) {
               continue;
            }
            string side = (forecast > previous) ? "BUY" : "SELL";
            // Proceed with your trading logic using 'side'
            // Select the *earliest* upcoming event that meets criteria
            if (candidateEventTime == 0 || eventTime < candidateEventTime) {
               candidateEventTime = eventTime;
               candidateEventID = event_data.event_id; // Use MqlCalendarValue 'id' or 'event_id'? 'event_id' seems more persistent.
               candidateEventName = GetEventName(event_data.event_id); // Helper needed
               candidateTradeSide = side;
            }
         }
         // Else if currentTime is *before* tradeStartTime (upcoming) - Set countdown
         else if (currentTime < tradeStartTime && eventTime > currentTime) {
            // Only show countdown for the *next* event overall, even if others meet criteria later
            if(candidateEventTime == 0 || eventTime < candidateEventTime) { // Found an earlier potential candidate
               int remainingSeconds = (int)(tradeStartTime - currentTime); // Time until trade window opens
               if (remainingSeconds > 0 && remainingSeconds < 3 * 3600) { // Only show reasonable countdowns (e.g., < 3 hrs)
                  int hrs = remainingSeconds / 3600;
                  int mins = (remainingSeconds % 3600) / 60;
                  int secs = remainingSeconds % 60;
                  string countdownText = StringFormat("Trade Window In: %02d:%02d:%02d", hrs, mins, secs);
                  UpdateOrCreateTradeCountdown(countdownText, clrSteelBlue); // Blue for upcoming window
               }
               else {
                  DeleteTradeUI(); // No countdown if too far out
               }
            }
         }
      }
      // Add logic for TRADE_AFTER mode here if needed
      // else if (p_tradeMode == TRADE_AFTER) { ... }
   }
   // --- Execute Trade if Candidate Found ---
   if (candidateEventID != -1 && candidateEventTime != 0) {
      datetime tradeStartTime = candidateEventTime - offsetSeconds;
      // Double check we are IN the trade window NOW
      if (currentTime >= tradeStartTime && currentTime < candidateEventTime) {
         // Make sure we haven't *just* executed a trade (race condition safety)
         if (!tradeExecuted) {
            Print("Executing ", candidateTradeSide, " trade for event: ", candidateEventName, " (ID: ", candidateEventID, ") at ", TimeToString(currentTime));
            // --- Place Trade ---
            bool tradeResult = false;
            if (candidateTradeSide == "BUY") {
               tradeResult = trade.Buy(p_tradeLotSize, _Symbol, 0, 0, 0, "News Buy " + candidateEventName);
            }
            else if (candidateTradeSide == "SELL") {
               tradeResult = trade.Sell(p_tradeLotSize, _Symbol, 0, 0, 0, "News Sell " + candidateEventName);
            }
            // --------------------
            if (tradeResult) {
               Print("Trade successful. Ticket: ", trade.ResultDeal());
               tradeExecuted = true;
               tradedNewsTime = candidateEventTime;
               triggeredEventId = candidateEventID; // Store ID of traded event
               // Update UI immediately to show post-trade countdown
               UpdateTradeStatusAndCountdown();
            }
            else {
               Print("Trade FAILED! Error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
               // Optional: Maybe block retrying same event immediately? Add a short cooldown?
            }
         } // end !tradeExecuted check
      } // end check currentTime in window
      // If we have a candidate but are not yet in the window, the countdown logic above handles it.
   }
   else {
      // No viable candidate found in the near term, ensure no stale countdown is showing
      // Unless countdown was set above for an upcoming window
      bool countdownExists = (ObjectFind(0, TRADE_COUNTDOWN) >= 0);
      // Check if the existing countdown is for trade window opening
      // string currentText = countdownExists ? ObjectGetString(0, TRADE_COUNTDOWN, OBJPROP_TEXT) : "";
      // if (countdownExists && StringFind(currentText, "Trade Window In:") < 0) {
      // DeleteTradeUI(); // If no candidate AND countdown is not for 'Trade Window In'
      //}
      // Simpler: If no candidate, generally clear UI unless set explicitly above for trade window.
      // The logic above should handle this reasonably now.
      if(candidateEventTime == 0 && !tradeExecuted) { // If no candidate AND no active trade/reset
         DeleteTradeUI();
      }
   }
}


//+------------------------------------------------------------------+
//| Update or Create the Trade Countdown UI                          |
//+------------------------------------------------------------------+
void UpdateOrCreateTradeCountdown(string text, color bgColor)
{
   int x = 30, y = 10; // Position top-left, adjust as needed
   int w = 240, h = 20; // Size
   if (ObjectFind(0, TRADE_COUNTDOWN) < 0) {
      // Create button style label
      createButton(TRADE_COUNTDOWN, x, y, w, h, text, clrWhiteSmoke, 9, bgColor, CLR_BORDER, FONT_LABEL, false, false); // Not selectable
      ChartRedraw(0); // Draw it now
   }
   else {
      ObjectSetString(0, TRADE_COUNTDOWN, OBJPROP_TEXT, text);
      ObjectSetInteger(0, TRADE_COUNTDOWN, OBJPROP_BGCOLOR, bgColor);
      // Don't redraw excessively if called from OnTick - rely on main loop redraw or ChartRedraw if state changed significantly
   }
}


//+------------------------------------------------------------------+
//| Deletes Trade-Related UI Objects                                 |
//+------------------------------------------------------------------+
void DeleteTradeUI()
{
   if(ObjectFind(0, TRADE_COUNTDOWN) >= 0) {
      ObjectDelete(0, TRADE_COUNTDOWN);
      ChartRedraw(0); // Redraw after deletion
   }
   // Delete other trade related objects if any (like TRADE_INFO_LABEL)
   if(ObjectFind(0, TRADE_INFO_LABEL) >= 0) ObjectDelete(0, TRADE_INFO_LABEL);
}

//+------------------------------------------------------------------+
//| Helper to get event name from ID (cached maybe?)                |
//+------------------------------------------------------------------+
string GetEventName(long event_id)
{
   MqlCalendarEvent event;
   if(CalendarEventById(event_id, event)) {
      return event.name;
   }
   return "Unknown Event";
}


// --- END OF CODE --- 
//+------------------------------------------------------------------+
