//+------------------------------------------------------------------+
//|                                      GoldAdvisorDashboard_EA.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.00"
#property description "Displays a trading dashboard similar to the Gold Advisor EA status."

//--- Draw on the main chart window
#property indicator_chart_window

#include <ChartObjects\ChartObjectsTxtControls.mqh> // For CChartObjectLabel etc. (Optional, can use direct functions too)
#include <MovingAverages.mqh> // For simple trend example

//--- Input Parameters (Optional)
input int               MagicNumberToTrack = 236274; // Set to 0 to display the first found position for the symbol, otherwise specify Magic#
input double            RiskPercentDisplay = 1.5;    // Static Risk % to display
input int               TimerIntervalSeconds = 1;     // Update frequency in seconds
input color             clrBackground = clrDimGray;   // Panel background color
input color             clrText       = clrWhite;     // Default text color
input color             clrHighlight  = clrLimeGreen; // Highlight color (Profit, Bullish)
input color             clrStopLoss   = clrRed;       // Stop Loss color
input color             clrTakeProfit = clrDeepSkyBlue;// Take Profit color
input color             clrSeparator  = clrGray;      // Separator line color
input string            FontName      = "Arial";      // Font for labels
input int               FontSize      = 9;            // Font size for labels
int                     line_height   = 20;           // Standard height between text lines <<< ADD THIS LINE

//--- Object Prefixes (for easier management)
string objPrefix = "GADash_";

//--- Global variables for object names
string panelMainName;
//... (add names for all labels, rectangles etc.)

//--- Position Info Cache (to avoid constant lookups if position doesn't change)
ulong  cachedPositionTicket = 0;
datetime cachedPositionOpenTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Generate unique object names based on chart ID
   panelMainName = objPrefix + (string)ChartID() + "_PanelMain";
   // ... generate other unique names ...

   //--- Create dashboard elements
   CreateDashboardLayout();

   //--- Set up timer for periodic updates
   EventSetTimer(TimerIntervalSeconds);

   //--- Initial Update
   UpdateDashboardData();
   ChartRedraw();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Kill the timer
   EventKillTimer();

   //--- Remove all created objects
   ObjectsDeleteAll(ChartID(), objPrefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdateDashboardData();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Tick function (optional, can be used for other EA logic)         |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- EA trading logic could go here if needed
}

//+------------------------------------------------------------------+
//| Create the static layout of the dashboard                        |
//+------------------------------------------------------------------+
void CreateDashboardLayout()
{
   int x_start = 10;
   int y_start = 10;
   int panel_width = 650; // Adjust as needed
   int panel_height = 300; // Adjust as needed
   int col1_x = x_start + 10;
   int col2_x = x_start + 130;
   int col3_x = x_start + 320;
   int col4_x = x_start + 450;
   int line_height = 20;
   int current_y = y_start;

   //--- Main Background Panel
   CreatePanel(panelMainName, x_start, y_start, panel_width, panel_height, clrBackground);

   //--- Header
   current_y += 5;
   CreateLabel(objPrefix + "Header", col1_x, current_y, "GOLD ADVISOR EA - POSITION STATUS", clrText, 12);
   CreateLabel(objPrefix + "DateTime", col3_x + 120, current_y, "DATE: -- TIME: --", clrText, FontSize, ANCHOR_RIGHT); // Anchor right
   current_y += line_height + 5;

   //--- Separator
   CreateSeparator(objPrefix + "Sep1", x_start + 5, current_y, panel_width - 10);
   current_y += 5;

   //--- Account Information Section
   CreateLabel(objPrefix + "AccInfoHeader", col1_x, current_y, "ACCOUNT INFORMATION", clrText, FontSize + 1);
   CreateLabel(objPrefix + "MarketHeader", col3_x, current_y, "MARKET STATUS", clrText, FontSize + 1);
   current_y += line_height;

   CreateLabel(objPrefix + "BrokerLabel", col1_x, current_y, "BROKER:", clrText);
   CreateLabel(objPrefix + "BrokerValue", col2_x, current_y, "...", clrText);
   CreateLabel(objPrefix + "RiskLabel", col3_x, current_y, "RISK %:", clrText);
   CreateLabel(objPrefix + "RiskValue", col4_x, current_y, StringFormat("%.1f%%", RiskPercentDisplay), clrText); // Display input Risk %
   current_y += line_height;

   CreateLabel(objPrefix + "BalanceLabel", col1_x, current_y, "BALANCE:", clrText);
   CreateLabel(objPrefix + "BalanceValue", col2_x, current_y, "...", clrText);
   CreateLabel(objPrefix + "SpreadLabel", col3_x, current_y, "SPREAD:", clrText);
   CreateLabel(objPrefix + "SpreadValue", col4_x, current_y, "...", clrText);
   current_y += line_height;

   CreateLabel(objPrefix + "EquityLabel", col1_x, current_y, "EQUITY:", clrText);
   CreateLabel(objPrefix + "EquityValue", col2_x, current_y, "...", clrText);
   CreateLabel(objPrefix + "DailyPLLabel", col3_x, current_y, "DAILY P/L:", clrText);
   CreateLabel(objPrefix + "DailyPLValue", col4_x, current_y, "...", clrHighlight); // Assume profit color
   current_y += line_height;

   //--- Market Status Section (within Account Info columns for simplicity here)
   CreateLabel(objPrefix + "InstrumentLabel", col1_x + 310, current_y, "INSTRUMENT:", clrText); // Align with col3_x
   CreateLabel(objPrefix + "InstrumentValue", col4_x, current_y, "...", clrText);
   current_y += line_height;
   CreateLabel(objPrefix + "PriceLabel", col3_x, current_y, "CURRENT PRICE:", clrText);
   CreateLabel(objPrefix + "PriceValue", col4_x, current_y, "...", clrText);
   current_y += line_height;
   CreateLabel(objPrefix + "TrendLabel", col3_x, current_y, "TREND H1/D1:", clrText);
   // Trend Value placeholder rectangle
   CreatePanel(objPrefix + "TrendRect", col4_x, current_y - 3, 55, line_height - 4, clrGray);
   CreateLabel(objPrefix + "TrendValue", col4_x + 27, current_y, "...", clrWhite, FontSize, ANCHOR_CENTER); // Centered text
   current_y += line_height + 5;


   //--- Separator
   CreateSeparator(objPrefix + "Sep2", x_start + 5, current_y, panel_width - 10);
   current_y += 5;

   //--- Active Position Section
   CreateLabel(objPrefix + "ActivePosHeader", col1_x, current_y, "ACTIVE POSITION", clrText, FontSize + 1);
   current_y += line_height;

   CreateLabel(objPrefix + "TicketLabel", col1_x, current_y, "TICKET #:", clrText);
   CreateLabel(objPrefix + "TicketValue", col2_x - 40, current_y, "---", clrText);
   CreateLabel(objPrefix + "TypeLabel", col1_x + 170, current_y, "TYPE:", clrText);
   CreatePanel(objPrefix + "TypeRect", col1_x + 210, current_y - 3, 45, line_height - 4, clrGray);
   CreateLabel(objPrefix + "TypeValue", col1_x + 232, current_y, "---", clrWhite, FontSize, ANCHOR_CENTER);
   CreateLabel(objPrefix + "LotsLabel", col3_x - 10, current_y, "LOT SIZE:", clrText);
   CreateLabel(objPrefix + "LotsValue", col3_x + 50, current_y, "---", clrText);
   CreateLabel(objPrefix + "OpenTimeLabel", col4_x - 20, current_y, "OPEN TIME:", clrText);
   CreateLabel(objPrefix + "OpenTimeValue", col4_x + 60, current_y, "---", clrText);
   current_y += line_height;

   CreateLabel(objPrefix + "OpenPriceLabel", col1_x, current_y, "OPEN PRICE:", clrText);
   CreateLabel(objPrefix + "OpenPriceValue", col2_x - 40, current_y, "---", clrText);
   CreateLabel(objPrefix + "SLLabel", col1_x + 170, current_y, "SL:", clrText);
   CreateLabel(objPrefix + "SLValue", col1_x + 210, current_y, "---", clrStopLoss);
   CreateLabel(objPrefix + "TPLabel", col3_x - 10, current_y, "TP:", clrText);
   CreateLabel(objPrefix + "TPValue", col3_x + 50, current_y, "---", clrTakeProfit);
   CreateLabel(objPrefix + "TrailingLabel", col4_x - 20, current_y, "TRAILING:", clrText);
   CreateLabel(objPrefix + "TrailingValue", col4_x + 60, current_y, "---", clrText);
   current_y += line_height;

   CreateLabel(objPrefix + "ProfitLossLabel", col1_x, current_y, "PROFIT/LOSS:", clrText);
   CreateLabel(objPrefix + "ProfitLossValue", col2_x - 40, current_y, "---", clrText);
   CreateLabel(objPrefix + "DurationLabel", col1_x + 170, current_y, "DURATION:", clrText);
   CreateLabel(objPrefix + "DurationValue", col1_x + 235, current_y, "---", clrText); // Adjusted X position
   CreateLabel(objPrefix + "MagicLabel", col3_x + 100, current_y, "MAGIC #:", clrText);
   CreateLabel(objPrefix + "MagicValue", col3_x + 160, current_y, "---", clrText);
   CreateLabel(objPrefix + "CommentLabel", col4_x - 20, current_y, "COMMENT:", clrText);
   CreateLabel(objPrefix + "CommentValue", col4_x + 60, current_y, "---", clrText);
   current_y += line_height + 5;

   //--- Progress Bar Area
   int bar_y = current_y;
   int bar_height = 15;
   int bar_width = panel_width - 20; // Width of the progress bar background
   CreatePanel(objPrefix + "ProgressBarBack", col1_x, bar_y, bar_width, bar_height, clrBlack); // Background for the bar area

   // Placeholders for dynamic bar elements (created/updated in UpdatePositionInfo)
   // Create static labels for SL/TP/Entry markers below the bar
   CreateLabel(objPrefix + "EntryMarkerLabel", col1_x, bar_y + bar_height + 2, "ENTRY", clrText, FontSize - 1);
   CreateLabel(objPrefix + "SLMarkerLabel", col1_x, bar_y + bar_height + 2, "SL", clrStopLoss, FontSize - 1);
   CreateLabel(objPrefix + "TPMarkerLabel", col1_x + bar_width, bar_y + bar_height + 2, "TP", clrTakeProfit, FontSize - 1, ANCHOR_RIGHT);
   current_y += bar_height + line_height; // Space for bar and labels below

   //--- Separator
   CreateSeparator(objPrefix + "Sep3", x_start + 5, current_y, panel_width - 10);
   current_y += 5;

   //--- Upcoming News Section
   CreateLabel(objPrefix + "NewsHeader", col1_x, current_y, "UPCOMING HIGH IMPACT NEWS", clrText, FontSize + 1);
   current_y += line_height;

   // Placeholder News Items - Replace with real data retrieval if possible
   CreateLabel(objPrefix + "NewsItem1", col1_x, current_y, "", clrText); // Text set in Update
   current_y += line_height;
   CreateLabel(objPrefix + "NewsItem2", col1_x, current_y, "", clrText); // Text set in Update
   current_y += line_height;

   //--- Adjust main panel height if needed based on content
   ObjectSetInteger(ChartID(), panelMainName, OBJPROP_YSIZE, current_y - y_start + 10);

}

//+------------------------------------------------------------------+
//| Update all dynamic data on the dashboard                         |
//+------------------------------------------------------------------+
void UpdateDashboardData()
{
   //--- Update Date/Time
   UpdateDateTime();

   //--- Update Account Info
   UpdateAccountInfo();

   //--- Update Market Info
   UpdateMarketInfo();

   //--- Update Active Position Info (and progress bar)
   UpdatePositionInfo();

   //--- Update News Info (Placeholders)
   UpdateNewsInfo();
}

//+------------------------------------------------------------------+
//| Update Date and Time                                             |
//+------------------------------------------------------------------+
void UpdateDateTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   string dtString = StringFormat("DATE: %02d %s %d   TIME: %02d:%02d:%02d",
                                  dt.day,
                                  MonthToString(dt.mon),
                                  dt.year,
                                  dt.hour, dt.min, dt.sec);
   ObjectSetString(ChartID(), objPrefix + "DateTime", OBJPROP_TEXT, dtString);
}


//+------------------------------------------------------------------+
//| Update Account Information Labels                                |
//+------------------------------------------------------------------+
void UpdateAccountInfo()
{
   //--- Broker
   ObjectSetString(ChartID(), objPrefix + "BrokerValue", OBJPROP_TEXT, AccountInfoString(ACCOUNT_COMPANY));

   //--- Balance
   ObjectSetString(ChartID(), objPrefix + "BalanceValue", OBJPROP_TEXT, FormatMoney(AccountInfoDouble(ACCOUNT_BALANCE)));

   //--- Equity
   ObjectSetString(ChartID(), objPrefix + "EquityValue", OBJPROP_TEXT, FormatMoney(AccountInfoDouble(ACCOUNT_EQUITY)));

   //--- Daily P/L (Note: This is tricky, requires tracking trades for the day)
   // This is a simplified placeholder - real daily P/L needs history tracking.
   // We can show the current floating P/L of *all* open positions as an approximation.
   double floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   string plStr = StringFormat("%+.2f", floatingPL);
   ObjectSetString(ChartID(), objPrefix + "DailyPLValue", OBJPROP_TEXT, plStr);
   ObjectSetInteger(ChartID(), objPrefix + "DailyPLValue", OBJPROP_COLOR, (floatingPL >= 0) ? clrHighlight : clrStopLoss);

}

//+------------------------------------------------------------------+
//| Update Market Information Labels                                 |
//+------------------------------------------------------------------+
void UpdateMarketInfo()
{
   string sym = Symbol();
   MqlTick last_tick;
   if(!SymbolInfoTick(sym, last_tick))
   {
      Print("Error getting tick for ", sym, " - Error ", GetLastError());
      return;
   }

   //--- Instrument
   string desc = SymbolInfoString(sym, SYMBOL_DESCRIPTION);
   ObjectSetString(ChartID(), objPrefix + "InstrumentValue", OBJPROP_TEXT, StringFormat("%s (%s)", sym, desc));

   //--- Current Price
   double currentPrice = (last_tick.ask + last_tick.bid) / 2.0; // Mid price
   ObjectSetString(ChartID(), objPrefix + "PriceValue", OBJPROP_TEXT, FormatPrice(currentPrice));

   //--- Spread
   long spread_points = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   double spread_real = spread_points * SymbolInfoDouble(sym, SYMBOL_POINT);
   // Format spread based on typical gold quote (e.g., 2 decimals)
   ObjectSetString(ChartID(), objPrefix + "SpreadValue", OBJPROP_TEXT, DoubleToString(spread_real, 2));


   //--- Trend H1/D1 (Simple MA Example)
   double ma_fast_h1 = iMA(sym, PERIOD_H1, 10, 0, MODE_SMA, PRICE_CLOSE); // Previous bar MA
   double ma_slow_h1 = iMA(sym, PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE);
   double ma_fast_d1 = iMA(sym, PERIOD_D1, 10, 0, MODE_SMA, PRICE_CLOSE);
   double ma_slow_d1 = iMA(sym, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);

   string trendText = "---";
   color trendColor = clrGray;

   // Very basic trend logic - consider H1 more heavily maybe?
   if(ma_fast_h1 > ma_slow_h1 && ma_fast_d1 > ma_slow_d1)
   {
      trendText = "BULLISH";
      trendColor = clrHighlight;
   }
   else if(ma_fast_h1 < ma_slow_h1 && ma_fast_d1 < ma_slow_d1)
   {
      trendText = "BEARISH";
      trendColor = clrStopLoss;
   }
   else
   {
      trendText = "MIXED"; // Or "SIDEWAYS" etc.
      trendColor = clrOrange;
   }

   ObjectSetString(ChartID(), objPrefix + "TrendValue", OBJPROP_TEXT, trendText);
   ObjectSetInteger(ChartID(), objPrefix + "TrendRect", OBJPROP_BGCOLOR, trendColor);
   ObjectSetInteger(ChartID(), objPrefix + "TrendValue", OBJPROP_COLOR, clrWhite); // Keep text white on colored bg
}

//+------------------------------------------------------------------+
//| Update Active Position Information                               |
//+------------------------------------------------------------------+
void UpdatePositionInfo()
{
   bool position_found = false;
   ulong position_ticket = 0;
   string currentSymbol = Symbol();
   double currentPrice = (SymbolInfoDouble(currentSymbol, SYMBOL_ASK) + SymbolInfoDouble(currentSymbol, SYMBOL_BID)) / 2.0;


   //--- Iterate through open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == currentSymbol) // Match symbol
      {
         position_ticket = PositionGetTicket(i);
         if(position_ticket == 0) continue; // Should not happen, but check

         //--- Optional: Filter by Magic Number
         if(MagicNumberToTrack > 0)
         {
            if(PositionGetInteger(POSITION_MAGIC) != (long)MagicNumberToTrack)
            {
               continue; // Skip if Magic# doesn't match
            }
         }

         //--- Found the position (or the first one if MagicNumberToTrack is 0)
         position_found = true;
         break; // Display info for this position
      }
   }

   //--- If a position to display was found
   if(position_found && PositionSelectByTicket(position_ticket))
   {
       //--- Get Position Data
       long        ticket      = (long)PositionGetInteger(POSITION_TICKET);
       long        type_long   = PositionGetInteger(POSITION_TYPE); // 0=Buy, 1=Sell
       double      lots        = PositionGetDouble(POSITION_VOLUME);
       datetime    open_time   = (datetime)PositionGetInteger(POSITION_TIME);
       double      open_price  = PositionGetDouble(POSITION_PRICE_OPEN);
       double      sl_price    = PositionGetDouble(POSITION_SL);
       double      tp_price    = PositionGetDouble(POSITION_TP);
       double      profit      = PositionGetDouble(POSITION_PROFIT);
       double      swap        = PositionGetDouble(POSITION_SWAP);
       long        magic       = PositionGetInteger(POSITION_MAGIC);
       string      comment     = PositionGetString(POSITION_COMMENT);
       datetime    current_time = TimeCurrent();
       long        duration_sec = (long)(current_time - open_time);

       // Check if it's the same position as last time to potentially save object updates
       bool positionChanged = (ticket != (long)cachedPositionTicket || open_time != cachedPositionOpenTime);
       cachedPositionTicket = ticket;
       cachedPositionOpenTime = open_time;

       //--- Update Labels (only update if data changed or first time)
       //if(positionChanged) // Optimization: Only update static parts if position changes
       //{
          ObjectSetString(ChartID(), objPrefix + "TicketValue", OBJPROP_TEXT, (string)ticket);
          ObjectSetString(ChartID(), objPrefix + "LotsValue", OBJPROP_TEXT, DoubleToString(lots, 2));
          ObjectSetString(ChartID(), objPrefix + "OpenTimeValue", OBJPROP_TEXT, TimeToString(open_time, TIME_DATE | TIME_MINUTES));
          ObjectSetString(ChartID(), objPrefix + "OpenPriceValue", OBJPROP_TEXT, FormatPrice(open_price));
          ObjectSetString(ChartID(), objPrefix + "SLValue", OBJPROP_TEXT, (sl_price > 0) ? FormatPrice(sl_price) : "---");
          ObjectSetString(ChartID(), objPrefix + "TPValue", OBJPROP_TEXT, (tp_price > 0) ? FormatPrice(tp_price) : "---");
          ObjectSetString(ChartID(), objPrefix + "MagicValue", OBJPROP_TEXT, (magic > 0) ? (string)magic : "---");
          ObjectSetString(ChartID(), objPrefix + "CommentValue", OBJPROP_TEXT, comment);

          // Type Button
          string typeText = (type_long == POSITION_TYPE_BUY) ? "BUY" : "SELL";
          color typeColor = (type_long == POSITION_TYPE_BUY) ? clrLimeGreen: clrRed;
          ObjectSetString(ChartID(), objPrefix + "TypeValue", OBJPROP_TEXT, typeText);
          ObjectSetInteger(ChartID(), objPrefix + "TypeRect", OBJPROP_BGCOLOR, typeColor);
          ObjectSetInteger(ChartID(), objPrefix + "TypeValue", OBJPROP_COLOR, clrWhite);

          // Trailing Stop (MQL5 doesn't expose the *current* trailing SL activation price directly)
          // We can only know *if* SL/TP were set. Trailing logic is internal to the terminal/broker or EA.
          // Displaying "ACTIVE @ price" needs the EA that *manages* the trailing stop to store and provide this info.
          // Placeholder:
          ObjectSetString(ChartID(), objPrefix + "TrailingValue", OBJPROP_TEXT, (sl_price > 0) ? "ACTIVE @ ..." : "---"); // Needs real data source

       //}

       //--- Update Dynamic Labels (Profit, Duration) - Update always
       double profitPercent = 0;
       if(AccountInfoDouble(ACCOUNT_BALANCE) > 0 && lots > 0 && open_price > 0) // Avoid division by zero
       {
            // Approximate initial margin used (very simplified)
            double contract_size = SymbolInfoDouble(currentSymbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double margin_approx = (lots * contract_size * open_price) / AccountInfoInteger(ACCOUNT_LEVERAGE);
            if (margin_approx > 0)
            {
                // Note: Calculating % P/L based on balance is common, not margin.
                // profitPercent = (profit / margin_approx) * 100.0;
                // Let's calculate vs Balance as it's more standard view
                 profitPercent = (profit / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0;
            }
       }

       string profitStr = StringFormat("%+.2f (%+.2f%%)", profit, profitPercent);
       ObjectSetString(ChartID(), objPrefix + "ProfitLossValue", OBJPROP_TEXT, profitStr);
       ObjectSetInteger(ChartID(), objPrefix + "ProfitLossValue", OBJPROP_COLOR, (profit >= 0) ? clrHighlight : clrStopLoss);

       // Duration
       long hours = duration_sec / 3600;
       long mins = (duration_sec % 3600) / 60;
       long secs = duration_sec % 60;
       string durationStr = StringFormat("%dh %02dm %02ds", hours, mins, secs);
       ObjectSetString(ChartID(), objPrefix + "DurationValue", OBJPROP_TEXT, durationStr);


       //--- Update Progress Bar
       UpdateProgressBar(open_price, sl_price, tp_price, currentPrice, (ENUM_POSITION_TYPE)type_long);

   }
   else //--- No position found
   {
      if(cachedPositionTicket != 0) // Clear fields only if there WAS a position displayed before
      {
         ObjectSetString(ChartID(), objPrefix + "TicketValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "TypeValue", OBJPROP_TEXT, "---");
         ObjectSetInteger(ChartID(), objPrefix + "TypeRect", OBJPROP_BGCOLOR, clrGray);
         ObjectSetString(ChartID(), objPrefix + "LotsValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "OpenTimeValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "OpenPriceValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "SLValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "TPValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "TrailingValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "ProfitLossValue", OBJPROP_TEXT, "---");
         ObjectSetInteger(ChartID(), objPrefix + "ProfitLossValue", OBJPROP_COLOR, clrText);
         ObjectSetString(ChartID(), objPrefix + "DurationValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "MagicValue", OBJPROP_TEXT, "---");
         ObjectSetString(ChartID(), objPrefix + "CommentValue", OBJPROP_TEXT, "---");

         // Clear progress bar elements
         ClearProgressBar();
         cachedPositionTicket = 0; // Reset cache
         cachedPositionOpenTime = 0;
      }
   }
}


//+------------------------------------------------------------------+
//| Update Progress Bar Elements                                     |
//+------------------------------------------------------------------+
void UpdateProgressBar(double openPrice, double slPrice, double tpPrice, double currentPrice, ENUM_POSITION_TYPE positionType)
{
    //--- Get background bar dimensions
    string backBarName = objPrefix + "ProgressBarBack";
    int bar_x = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_XDISTANCE);
    int bar_y = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_YDISTANCE);
    int bar_w = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_XSIZE);
    int bar_h = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_YSIZE);

    //--- Basic validation: Need SL and TP for a meaningful range
    if(slPrice <= 0 || tpPrice <= 0 || slPrice == tpPrice)
    {
        ClearProgressBar(); // Cannot draw bar without valid SL/TP
        return;
    }

    // Ensure SL is below TP for BUY, and SL is above TP for SELL
    if ((positionType == POSITION_TYPE_BUY && slPrice >= tpPrice) ||
        (positionType == POSITION_TYPE_SELL && slPrice <= tpPrice))
    {
       // Consider logging an error or handling this case (e.g. invalid SL/TP)
       ClearProgressBar();
       return;
    }

    double range = MathAbs(tpPrice - slPrice);
    if(range <= 0) { ClearProgressBar(); return; } // Avoid division by zero

    // Calculate positions as percentages of the total range (0% at SL, 100% at TP)
    double open_perc = MathAbs(openPrice - slPrice) / range;
    double current_perc = MathAbs(currentPrice - slPrice) / range;

    // Clamp percentages between 0.0 and 1.0
    open_perc = MathMax(0.0, MathMin(1.0, open_perc));
    current_perc = MathMax(0.0, MathMin(1.0, current_perc));

    // Calculate pixel positions
    int sl_pixel_x = bar_x; // SL is always at the start (left)
    int tp_pixel_x = bar_x + bar_w; // TP is always at the end (right)
    int entry_pixel_x = sl_pixel_x + (int)(open_perc * bar_w);
    int current_pixel_x = sl_pixel_x + (int)(current_perc * bar_w);

    // --- Adjust Marker Label Positions ---
    // SL Label (already positioned left)
    ObjectSetInteger(ChartID(), objPrefix + "SLMarkerLabel", OBJPROP_XDISTANCE, sl_pixel_x);
    ObjectSetInteger(ChartID(), objPrefix + "SLMarkerLabel", OBJPROP_YDISTANCE, bar_y + bar_h + 2);

    // TP Label (already positioned right)
    ObjectSetInteger(ChartID(), objPrefix + "TPMarkerLabel", OBJPROP_XDISTANCE, tp_pixel_x);
    ObjectSetInteger(ChartID(), objPrefix + "TPMarkerLabel", OBJPROP_YDISTANCE, bar_y + bar_h + 2);

    // Entry Label (Center around its pixel position)
    ObjectSetInteger(ChartID(), objPrefix + "EntryMarkerLabel", OBJPROP_XDISTANCE, entry_pixel_x);
    ObjectSetInteger(ChartID(), objPrefix + "EntryMarkerLabel", OBJPROP_YDISTANCE, bar_y + bar_h + 2);
    ObjectSetInteger(ChartID(), objPrefix + "EntryMarkerLabel", OBJPROP_ANCHOR, ANCHOR_CENTER); // Center horizontally


    // --- Create/Update Dynamic Bar Elements ---
    string barFillName = objPrefix + "ProgressBarFill";
    string currentLineName = objPrefix + "CurrentPriceLine";
    string currentLabelName = objPrefix + "CurrentPriceLabel";

    int fill_start_x = 0;
    int fill_width = 0;
    color fill_color = clrGray;

    // Determine fill direction and color based on position type and current price vs entry
    if (positionType == POSITION_TYPE_BUY)
    {
        fill_start_x = entry_pixel_x;
        fill_width = current_pixel_x - entry_pixel_x;
        fill_color = (currentPrice >= openPrice) ? clrHighlight : clrStopLoss; // Green if above entry, red if below
        if (fill_width < 0) // If current is below entry
        {
             fill_start_x = current_pixel_x;
             fill_width = MathAbs(fill_width);
        }
    }
    else // POSITION_TYPE_SELL
    {
        fill_start_x = current_pixel_x;
        fill_width = entry_pixel_x - current_pixel_x;
        fill_color = (currentPrice <= openPrice) ? clrHighlight : clrStopLoss; // Green if below entry, red if above
         if (fill_width < 0) // If current is above entry
        {
             fill_start_x = entry_pixel_x;
             fill_width = MathAbs(fill_width);
        }
    }

    // Ensure width is at least 1 if not zero, prevent negative width
    fill_width = MathMax(0, fill_width);

    // Create/Update the fill rectangle
    if(ObjectFind(ChartID(), barFillName) < 0) // Create if doesn't exist
        CreatePanel(barFillName, fill_start_x, bar_y, fill_width, bar_h, fill_color, 1); // Border 1
    else // Update existing
    {
        ObjectSetInteger(ChartID(), barFillName, OBJPROP_XDISTANCE, fill_start_x);
        ObjectSetInteger(ChartID(), barFillName, OBJPROP_YDISTANCE, bar_y);
        ObjectSetInteger(ChartID(), barFillName, OBJPROP_XSIZE, fill_width);
        ObjectSetInteger(ChartID(), barFillName, OBJPROP_YSIZE, bar_h);
        ObjectSetInteger(ChartID(), barFillName, OBJPROP_BGCOLOR, fill_color);
    }
    ObjectSetInteger(ChartID(), barFillName, OBJPROP_BACK, false); // Bring fill slightly forward


    // Create/Update the current price vertical line marker
    if(ObjectFind(ChartID(), currentLineName) < 0)
       ObjectCreate(ChartID(), currentLineName, OBJ_VLINE, 0, 0, 0);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_BACK, false);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_XDISTANCE, current_pixel_x); // Use distance for pixel positioning
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_YDISTANCE, bar_y);
    ObjectSetInteger(ChartID(), currentLineName, OBJPROP_YSIZE, bar_h); // Make line height of bar


     // Create/Update the "CURRENT" label above the line
     if(ObjectFind(ChartID(), currentLabelName) < 0)
        CreateLabel(currentLabelName, current_pixel_x, bar_y - line_height + 5 , "CURRENT", clrWhite, FontSize-1, ANCHOR_CENTER);
     else
     {
        ObjectSetInteger(ChartID(), currentLabelName, OBJPROP_XDISTANCE, current_pixel_x);
        ObjectSetInteger(ChartID(), currentLabelName, OBJPROP_YDISTANCE, bar_y - line_height + 8); // Position above bar
        ObjectSetInteger(ChartID(), currentLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
     }


}

//+------------------------------------------------------------------+
//| Clear Progress Bar Dynamic Elements                              |
//+------------------------------------------------------------------+
void ClearProgressBar()
{
     ObjectDelete(ChartID(), objPrefix + "ProgressBarFill");
     ObjectDelete(ChartID(), objPrefix + "CurrentPriceLine");
     ObjectDelete(ChartID(), objPrefix + "CurrentPriceLabel");

     // Reset marker label positions slightly
     string backBarName = objPrefix + "ProgressBarBack";
     if(ObjectFind(ChartID(), backBarName) >= 0)
     {
         int bar_x = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_XDISTANCE);
         int bar_y = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_YDISTANCE);
         int bar_w = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_XSIZE);
         int bar_h = (int)ObjectGetInteger(ChartID(), backBarName, OBJPROP_YSIZE);
         ObjectSetInteger(ChartID(), objPrefix + "EntryMarkerLabel", OBJPROP_XDISTANCE, bar_x + bar_w/2); // Center Entry label
         ObjectSetInteger(ChartID(), objPrefix + "EntryMarkerLabel", OBJPROP_ANCHOR, ANCHOR_CENTER);
         ObjectSetInteger(ChartID(), objPrefix + "SLMarkerLabel", OBJPROP_XDISTANCE, bar_x);
         ObjectSetInteger(ChartID(), objPrefix + "TPMarkerLabel", OBJPROP_XDISTANCE, bar_x + bar_w);
     }
}

//+------------------------------------------------------------------+
//| Update Upcoming News Labels (Placeholder)                        |
//+------------------------------------------------------------------+
void UpdateNewsInfo()
{
   // --- THIS IS PLACEHOLDER DATA ---
   // --- Real news requires external data source ---
   string news1 = "USD - FOMC Statement - 25 APR 19:00 GMT (in 4h 25m)"; // Example from image
   string news2 = "EUR - ECB Press Conference - 26 APR 12:30 GMT (in 21h 55m)"; // Example

   ObjectSetString(ChartID(), objPrefix + "NewsItem1", OBJPROP_TEXT, "\xE2\x80\xA2 " + news1); // Add bullet point
   ObjectSetInteger(ChartID(), objPrefix + "NewsItem1", OBJPROP_COLOR, clrOrangeRed); // Red dot color

   ObjectSetString(ChartID(), objPrefix + "NewsItem2", OBJPROP_TEXT, "\xE2\x80\xA2 " + news2); // Add bullet point
   ObjectSetInteger(ChartID(), objPrefix + "NewsItem2", OBJPROP_COLOR, clrOrangeRed); // Red dot color

   // You would need logic here to calculate the "in Xh Ym" part dynamically if you had the future event times.
}


//+------------------------------------------------------------------+
//| Helper Function to Create Text Labels                            |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int font_size = -1, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT, long corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(ChartID(), name) < 0) // Only create if it doesn't exist
   {
      ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, corner);
      ObjectSetInteger(ChartID(), name, OBJPROP_ANCHOR, anchor);
      ObjectSetString(ChartID(), name, OBJPROP_FONT, FontName);
      ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, (font_size == -1) ? FontSize : font_size);
      ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, clr);
      ObjectSetInteger(ChartID(), name, OBJPROP_BACK, true); // Draw behind price chart
      ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
   }
   // Optional: Could add logic here to update properties if object already exists
}

//+------------------------------------------------------------------+
//| Helper Function to Create Background Panels (Rectangles)         |
//+------------------------------------------------------------------+
void CreatePanel(string name, int x, int y, int width, int height, color bg_clr, int border_width = 0, color border_clr = clrNONE, long corner = CORNER_LEFT_UPPER)
{
   if(ObjectFind(ChartID(), name) < 0) // Only create if it doesn't exist
   {
      ObjectCreate(ChartID(), name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(ChartID(), name, OBJPROP_XSIZE, width);
      ObjectSetInteger(ChartID(), name, OBJPROP_YSIZE, height);
      ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, corner);
      ObjectSetInteger(ChartID(), name, OBJPROP_BGCOLOR, bg_clr);
      ObjectSetInteger(ChartID(), name, OBJPROP_BORDER_TYPE, (border_width > 0) ? BORDER_FLAT : BORDER_SUNKEN); // <<< CORRECTED LINE
      ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, border_clr); // Border color
       //ObjectSetInteger(ChartID(), name, OBJPROP_WIDTH, border_width); // Note: OBJPROP_WIDTH applies to line thickness for line objects, not border thickness for rectangles. Use BORDER_TYPE.
      ObjectSetInteger(ChartID(), name, OBJPROP_BACK, true); // Draw behind price chart
      ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
   }
}
//+------------------------------------------------------------------+
//| Helper Function to Create Separator Lines                        |
//+------------------------------------------------------------------+
void CreateSeparator(string name, int x, int y, int width, long corner = CORNER_LEFT_UPPER)
{
    // Use a thin rectangle as a separator
    CreatePanel(name, x, y, width, 1, clrSeparator, 0, clrNONE, corner);
}

//+------------------------------------------------------------------+
//| Format Price based on Symbol Digits                              |
//+------------------------------------------------------------------+
string FormatPrice(double price)
{
   return DoubleToString(price, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Format Money based on Account Currency Digits                    |
//+------------------------------------------------------------------+
string FormatMoney(double money)
{
   return StringFormat("%.*f", (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS), money);
   // Optional: Add currency symbol
   // return AccountInfoString(ACCOUNT_CURRENCY) + " " + StringFormat("%.*f", (int)AccountInfoInteger(ACCOUNT_CURRENCY_DIGITS), money);
}

//+------------------------------------------------------------------+
//| Convert Month Number to String                                   |
//+------------------------------------------------------------------+
string MonthToString(int month)
{
    switch(month)
    {
        case 1: return "JAN";
        case 2: return "FEB";
        case 3: return "MAR";
        case 4: return "APR";
        case 5: return "MAY";
        case 6: return "JUN";
        case 7: return "JUL";
        case 8: return "AUG";
        case 9: return "SEP";
        case 10: return "OCT";
        case 11: return "NOV";
        case 12: return "DEC";
        default: return "???";
    }
}
//+------------------------------------------------------------------+