//+------------------------------------------------------------------+
//|                                             SevenOneFourEA_V7.04.mq5 |
//|                                                Developed by [Your Name/Handle] |
//|                                                Based on The 714 Trading Method by Mashaya |
//+------------------------------------------------------------------+
#property version      "7.04"
#property description  "Automated trading system based on the 714 Method. This version includes automatic GMT offset detection and consolidated logic."
#property copyright    "Your Name/Handle"
#property link         ""
#property strict
 
#include <Trade/Trade.mqh>
#include <Object.mqh>
/*
version 7.04
- added morning and afternoon zones
- added entry search window
- added session end time
- added entry search end time
- added session end time
- added session end minute







rough notes:
5 x12    60 min
5 x3     15

13:00    14:10
15 candles :: 5mins

The 15th M5 candle (in a 1-based count from the 1 PM candle) would begin at 1 PM + (14 * 5 minutes) = 1 PM + 70 minutes, which is 2:10 PM SAST.

 "3-candle delay" (13th, 14th, 15th candles) could be interpreted as a confirmation window. It gives the market time to:
Confirm a reversal: Price may break structure or show strong rejection candles during this 15-minute period.
Flush out weak hands: The move might extend slightly further, tricking more traders before the true reversal gains momentum.
Solidify the bias: It allows a bit more price action to unfold

*/
//--- Enumerations
enum Mode
  {
   Historical = 0, // Use historical data for indicator calculations
   Present    = 1  // Use present data for indicator calculations
  };

enum Style
  {
   Colored    = 0, // Use colored candles and objects
   Monochrome = 1  // Use monochrome candles and objects
  };

enum ENUM_OPERATING_MODE
  {
   TRADING,        // Execute trades automatically
   ANALYSIS_ALERTS // Monitor and send alerts, no trading
  };

enum rtBullishStructure
  {
   All   = 0, // Show all real-time bullish structures
   BoS   = 1, // Show only Real-time Bullish Break of Structure
   CHoCH = 2  // Show only Real-time Bullish Change of Character
  };
enum BullishStructure
  {
   All   = 0, // Show all bullish structures
   BoS   = 1, // Show only Bullish Break of Structure
   CHoCH = 2  // Show only Bullish Change of Character
  };

enum BearishStructure
  {
   All   = 0, // Show all bearish structures
   BoS   = 1, // Show only Bearish Break of Structure
   CHoCH = 2  // Show only Bearish Change of Character
  };

//--- Structure to store detected Order Blocks details for the day
struct st_OrderBlock
  {
   datetime          startTime;      // Time of the potential OB candle
   double            high;           // High of the potential OB candle
   double            low;            // Low of the potential OB candle
   ENUM_POSITION_TYPE type;         // POSITION_TYPE_BUY for Bullish, POSITION_TYPE_SELL for Bearish
   bool              isMitigated;    // Has price returned to and traded through this OB range?
   string            objectName;     // Name of the rectangle object if drawn
   string            labelName;      // Name of the text label if drawn
  };

//--- Session Times Structure
struct SessionTimes
  {
   datetime          keyTime;
   datetime          observationEnd;
   datetime          morningStart;
   datetime          morningEnd;
   datetime          afternoonStart;
   datetime          afternoonEnd;
   datetime          entrySearchEnd;
  };

//--- Forward Declarations for functions used before their main definition
    void           CalculateServerGmtOffset();
    datetime       ConvertGMTPlus2ToBrokerTime(int hourGMTPlus2,int minute=0);
    datetime       ConvertGMTPlus2ToBrokerTimeForDate(datetime target_date,int hourGMTPlus2,int minute=0);
    void           CalculateAndDrawDailyTimings();
    void           DrawHistoricKillzones();
    void           DrawHistoricTimeZone(datetime startTime,datetime endTime,string zoneName,color clr);
    void           RemoveAllVisuals();
    void           PlaceBuyOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref);
    void           PlaceSellOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref);
    string         TakeScreenshot();
    void           SendTelegramAlert(string message_text,string image_filepath);
    void           DetermineInitialBias();
    void           ScanForOrderBlocks();
    void           CheckForTradeSignal(int bar_idx);
    void           CheckAnchorPriceInteraction(int bar_idx);
    void           UpdateMitigationStatus(int current_closed_bar_index);
    void           ManageTrades();
    void           DrawOrderBlock(const st_OrderBlock &ob);
    void           UpdateOrderBlockVisual(const st_OrderBlock &ob);
    bool           YourBuyEntryConditionsMet(int closed_bar_index);
    bool           YourSellEntryConditionsMet(int closed_bar_index);
    bool           IsBullishOrderBlockCandidate(int bar_idx, const MqlRates &rates[]);
    bool           IsBearishOrderBlockCandidate(int bar_idx, const MqlRates &rates[]);
    void           GetAndDrawKeyPrice(datetime startTime, datetime endTime, double &keyPriceVariable, bool &isObtainedFlag, string zoneName, color lineColor);
    void           LabelObjectByTooltip();
    SessionTimes   GetTodaySessionTimes();
    void           DrawAlertSymbol(int bar_index, double price, string description, color symbol_color, uint symbol_code);
    void           DrawTimeLine(datetime time,string text,color clr,ENUM_LINE_STYLE style=STYLE_SOLID,int width=1,bool back=false,int ray=0,string name_prefix="");
    void           DrawTimeZone(datetime startTime,datetime endTime,string text,color clr);
    double         CalculateLotSize(double risk_perc,double entry_price,double stop_loss_price);


//+------------------------------------------------------------------+
//| Input Parameters
//+------------------------------------------------------------------+
//--- Operating Mode
    input group "=== Operating Mode ===";
    input ENUM_OPERATING_MODE Operating_Mode = ANALYSIS_ALERTS; // Default to the new analysis mode

//--- Trade Management Settings
    input group "=== Trade Management Settings ===";
    input long     magic_Number              = 71403;  // Unique identifier for EA trades
    input double   risk_Percent_Placeholder  = 1.0;    // Risk % per trade (0.1-5.0 recommended)
    input double   stop_Loss_Buffer_Pips     = 5.0;    // Buffer added to OB High/Low for SL
    input int      take_Profit_Pips_Placeholder = 50;  // Take Profit distance in pips

//--- Screenshot & Telegram Settings
input group "=== Screenshot & Telegram Settings ===";
input bool     enable_screenshot          = true;    // Enable/Disable taking screenshots on alerts
input string   screenshot_subfolder       = "714_Alerts"; // Subfolder in MQL5/Files for saving screenshots
input bool     enable_telegram_alert      = true;    // Enable/Disable sending Telegram alerts
input string   telegram_bot_token         = "YOUR_BOT_TOKEN_HERE"; // User must replace this
input string   telegram_chat_id           = "YOUR_CHAT_ID_HERE";   // User must replace this (e.g., @your_channel_name or user_id)
input string   telegram_message_prefix    = "[714EA Alert]";       // Prefix for all messages

//--- Anchor Price Alert Triggers ---
input group "--- Anchor Price Alert Triggers ---";
input bool alert_on_close_across_anchor = true;  // Trigger 1: Bar closes ABOVE or BELOW the Anchor Price
input bool alert_on_rejection_of_anchor = true;  // Trigger 2: Bar rejects the Anchor Price (e.g., pin bar)
input bool alert_on_break_and_retest_of_anchor = true; // Trigger 3: Price breaks, then returns to retest the Anchor Price

//--- Price Action Filter Settings ---
input group "=== Price Action Filter Settings ===";
input double min_wick_to_body_ratio = 1.5;  // The wick must be at least 1.5x the size of the candle body
input double min_candle_size_pips   = 5.0;   // Ignore tiny doji candles by requiring a minimum total candle size
input bool   use_atr_filter         = true;  // Filter rejections based on Average True Range
input int    atr_period             = 14;    // Period for ATR calculation

//--- Broker Timezone Settings
    input group    "=== Broker Timezone Settings ===";
    input bool     auto_detect_gmt_offset    = true;   // Auto-detect broker GMT offset
    input int      manual_gmt_offset_hours   = 0;      // Manual GMT offset (if auto-detect fails)

//--- Custom Indicator Settings
    input group "=== Custom Indicator Settings ===";
    input Mode     indicator_mode            = Historical; // Indicator calculation mode (Historical/Present)
    input Style    indicator_style           = Colored;    // Indicator color style
    input bool     ColorCandles              = false;      // Enable/disable candle coloring by the indicator
    input bool     ShowInternalStructure     = false;      // Enable/disable showing the internal structure
    input BullishStructure Bullish_Structure_Type = BullishStructure::All; // Type of bullish structure to display
    input color    ISBullishColor            = clrLime;    // Color for the bullish internal structure
    input BearishStructure Bearish_Structure_Type = BearishStructure::All; // Type of bearish structure to display
    input color    ISBearishColor            = clrRed;     // Color for the bearish internal structure
    input bool     ConfluenceFilter          = false;      // Enable/disable the confluence filter
    input bool     ShowSwingStructure        = false;      // Enable/disable showing the swing structure
    input rtBullishStructure rtBullish_Structure_Type = rtBullishStructure::All; // Type of real-time bullish structure to display
    input int      label_scan_interval_seconds = 5;       // How often (in seconds) to rescan for indicator objects to label
    input int      initial_scan_delay_seconds  = 3;     // Seconds to wait after EA start before the first object scan

//--- Primary Key Time Settings (UTC+2)
    input group    "=== Primary Key Time Settings (UTC+2) ===";
    input int      utcPlus2_KeyHour_1300     = 13;     // Key Hour (13:00 UTC+2)
    input int      utcPlus2_KeyMinute_1300   = 0;      // Key Minute
    input int      observation_Duration_Minutes= 60;   // Minutes to observe price action after Key Time
    input int      entry_Candlestick_Index   = 15;     // M5 candle index for entry (15 = 75 mins after Key Time)
    input bool     use_entry_search_window   = true;   // Enable to limit entry search to a specific window
//--- Morning Zone Settings (UTC+2)
    input group    "=== Morning Zone Settings (UTC+2) ===";
    input bool     enable_morning_zone          = false;   // Enable morning zone
    input int      morning_zone_start_hour_utc2 = 7;
    input int      morning_zone_end_hour_utc2   = 8;
    input color    morning_zone_color           = clrSteelBlue;
//--- Order Block Detection Settings
    input group    "=== Afternoon Zone Settings (UTC+2) ===";
    input bool     enable_afternoon_zone        = false;
    input int      afternoon_zone_start_hour_utc2 = 16;
    input int      afternoon_zone_end_hour_utc2   = 17;
    input color    afternoon_zone_color         = clrSteelBlue;
    input int      entry_search_end_hour_utc2= 17;     // Hour (UTC+2) to stop searching for new entries
    input int      entry_search_end_minute_utc2= 0;      // Minute to stop searching for new entries
    input int      session_End_UTC2_Hour     = 22;     // Session end hour UTC+2 (22 = 10:00 PM)
    input int      session_End_UTC2_Minute   = 0;      // Session end minute UTC+2


//--- Order Block Detection Settings
    input group    "=== Order Block Detection Settings ===";
    input int      ob_Lookback_Bars_For_Impulse = 7;     // Max bars to check for impulsive move after OB
    input double   ob_MinMovePips             = 7.0;  // Min price move (pips) to confirm OB
    input int      ob_MaxBlockCandles         = 3;    // Max candles to form OB body
    input bool     scan_before_obs_end_only   = true; // Only detect OBs formed before observation end

//--- Visual Display Settings
    input group    "=== Visual Display Settings ===";
    input bool     visual_enabled            = true;   // Master switch for all visuals
    input bool     visual_main_timing_lines  = true;   // Show Key Time & Observation End lines
    input bool     visual_order_blocks       = false;   // Show detected Order Blocks
    input bool     visual_obs_price_line     = true;   // Show price level during observation
    input bool     visual_on_chart_alerts   = true;  // Show visual alerts on chart during backtest/live
    input bool     historic_view_enabled     = false;  // Draw killzones for historical days
    input int      historic_view_days        = 14;     // Number of days to draw historic killzones (1-90)
    input color    vline_keytime_color       = clrSteelBlue;
    input color    vline_obsend_color        = clrSalmon;
    input color    ob_bullish_color          = clrLimeGreen;
    input color    ob_bearish_color          = clrRed;
    input color    ob_mitigated_color        = clrGray;
    input color    ob_label_color            = clrBlack;
    input color    obs_price_line_color      = clrDarkGray;
//--- Labeling Settings
    input group    "=== Labeling Settings ===";
    input int      chart_refresh_delay_ms      = 100;     // Milliseconds to wait after chart refresh before scanning tooltips
//--- Global Variables ---
    CTrade     trade;
    string     visual_comment_text = "714EA_v7.04"; // Prefix for chart comments/objects
    int        g_atr_handle = INVALID_HANDLE;      // Handle for the ATR indicator

//--- Time & Session Globals
    datetime   g_last_initialized_day_time = 0;      // To track the server time of the last daily reset
    int        g_server_gmt_offset_hours = 0;      // Auto-detected server GMT offset
    datetime   g_TodayKeyTime_Server;              // Server time for today's Primary Key Time (13:00 UTC+2 equivalent)
    datetime   g_ObservationEndTime_Server;        // Server time for the end of the observation window
    datetime   g_MorningZoneStartTime_Server;
    datetime   g_MorningZoneEndTime_Server;
    datetime   g_AfternoonZoneStartTime_Server;
    datetime   g_AfternoonZoneEndTime_Server;
    datetime   g_EntrySearchEndTime_Server;        // Server time to stop searching for new entries for the day

//--- Price & Bias Globals
    double     g_KeyPrice_At_KeyTime;              // Price at the open of the Key Time bar on the server
    double     g_MorningZone_KeyPrice;
    double     g_AfternoonZone_KeyPrice;
    int        g_InitialBias = 0;                  // 0: Undetermined, 1: Bullish after key time (look for sells), -1: Bearish after key time (look for buys)

//--- State Control Globals
    bool       g_key_price_obtained_today      = false;
    bool       g_MorningZone_KeyPrice_Obtained_Today = false;
    bool       g_AfternoonZone_KeyPrice_Obtained_Today = false;
    bool       g_bias_determined_today         = false;
    bool       g_anchor_price_broken           = false;
    bool       g_close_across_alert_sent       = false;
    bool       g_retest_alert_sent             = false;
    bool       g_order_blocks_scanned_today    = false;
    datetime   g_last_processed_bar_time_OnTimer = 0;
    datetime   g_last_label_scan_time          = 0;      // Tracks the last time we scanned for objects to label
    bool       g_trade_signal_this_bar = false;
    st_OrderBlock g_triggered_ob_for_trade;

//--- Order Block Storage
    st_OrderBlock g_bullishOrderBlocks[100];       // Max 100 Bullish OBs per day
    int           g_bullishOB_count = 0;
    st_OrderBlock g_bearishOrderBlocks[100];       // Max 100 Bearish OBs per day
    int           g_bearishOB_count = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Early validation checks
   if(Period() != PERIOD_M5 && Period() != PERIOD_M15)
     {
      Print("warning: This EA requires the M5 or M15 timeframe.");
      //return(INIT_FAILED);
     }

   // Initialize CTrade object with optimized settings
   trade.SetExpertMagicNumber(magic_Number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Optimize order filling
   
   // Set chart properties once
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(0, CHART_AUTOSCROLL, true);

   // Calculate timezone offset once
   if(auto_detect_gmt_offset)
     {
      CalculateServerGmtOffset();
      Print("Auto-detected Server GMT Offset: ", g_server_gmt_offset_hours);
     }
   else
     {
      g_server_gmt_offset_hours = manual_gmt_offset_hours;
      Print("Manual Server GMT Offset: ", g_server_gmt_offset_hours);
     }

   // Initialize the ATR indicator handle
   g_atr_handle = iATR(_Symbol, Period(), atr_period);
   if(g_atr_handle == INVALID_HANDLE)
     {
      Print(visual_comment_text, " - WARNING: Failed to create ATR indicator handle. ATR filter will be skipped. Error: ", GetLastError());
     }
   else
     {
      Print(visual_comment_text, " - ATR indicator initialized successfully.");
     }

   // Initialize daily timings and visuals
   CalculateAndDrawDailyTimings();

   // Consolidated indicator setup
   if(!SetupCustomIndicator())
     {
      Print("WARNING: Custom indicator setup failed, but EA will continue");
     }

   // Print key information once at the end
   PrintInitializationSummary();

   // Start timer as the final step
   EventSetTimer(5);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Optimized indicator setup function                              |
//+------------------------------------------------------------------+
bool SetupCustomIndicator()
  {
   string indicator_path = "2025SMART\\SmartMoneyConcepts";
   
   // Check if indicator already exists
   for(int i = 0; i < ChartIndicatorsTotal(0, 0); i++)
     {
      string ind_name_on_chart = ChartIndicatorName(0, 0, i);
      if(StringFind(ind_name_on_chart, "SmartMoneyConcepts", 0) != -1)
        {
         Print(visual_comment_text + " - Custom indicator already found on chart.");
         return true;
        }
     }

   // Add indicator if not found
   ResetLastError();
   int indicator_handle = iCustom(Symbol(), Period(), indicator_path,
                                  2000, "HEADER",
                                  (int)indicator_mode,
                                  (int)indicator_style,
                                  ColorCandles,
                                  "realtime int struct",
                                  ShowInternalStructure,
                                  (int)Bullish_Structure_Type,
                                  ISBullishColor,
                                  (int)Bearish_Structure_Type,
                                  ISBearishColor,
                                  ConfluenceFilter,
                                  "realtime swing",
                                  ShowSwingStructure,
                                  (int)rtBullish_Structure_Type,
                                  clrLime, 0, clrRed, false, 50, true,
                                  "OB", true, 5, true, 5, 0,
                                  clrLightBlue, clrLightPink, clrLightBlue, clrLightPink,
                                  "EQH EQL", true, 3, 0.1,
                                  "FVG", true, true, 0,
                                  clrLightBlue, clrLightPink, 1,
                                  "highs & lows mtf",
                                  false, 0, clrLightBlue, false, 0, clrLightBlue, false, 0, clrLightBlue,
                                  "PREM DISC",
                                  false, clrLightBlue, clrLightPink, clrLightPink);

   if(indicator_handle == INVALID_HANDLE)
     {
      Print(visual_comment_text + " - ERROR: iCustom failed. Error: ", GetLastError());
      return false;
     }

   if(!ChartIndicatorAdd(0, 0, indicator_handle))
     {
      Print(visual_comment_text + " - ERROR: Failed to add indicator to chart. Error: ", GetLastError());
      return false;
     }

   Print(visual_comment_text + " - Custom indicator added successfully.");
   ChartRedraw();
   return true;
  }

//+------------------------------------------------------------------+
//| Print initialization summary                                     |
//+------------------------------------------------------------------+
void PrintInitializationSummary()
  {
   SessionTimes times = GetTodaySessionTimes();
   
   Print("714 Method EA V7.01 initialized successfully on ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("13:00 UTC+2 Equivalent (Server Time): ", TimeToString(times.keyTime, TIME_DATE|TIME_MINUTES));
   Print("Observation End (Server Time): ", TimeToString(times.observationEnd, TIME_DATE|TIME_MINUTES));
   Print(visual_comment_text, " initialized successfully on ", _Symbol, " ", EnumToString(Period()));
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   RemoveAllVisuals();

//--- Release Indicator Handles ---
   if(g_atr_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atr_handle);
     }

//--- Remove ALL indicators from all chart windows ---
   Print(visual_comment_text, " - Removing all indicators from the chart as part of deinitialization.");
// Iterate through all windows on the chart, starting from the last one
   for(int w = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL) - 1; w >= 0; w--)
     {
      // Iterate through all indicators on the current window, starting from the last one
      for(int i = ChartIndicatorsTotal(0, w) - 1; i >= 0; i--)
        {
         string indicator_name = ChartIndicatorName(0, w, i);
         if(ChartIndicatorDelete(0, w, indicator_name))
           {
            Print(visual_comment_text, " - Removed indicator '", indicator_name, "' from window #", w, ".");
           }
         else
           {
            Print(visual_comment_text, " - ERROR: Failed to remove indicator '", indicator_name, "' from window #", w, ". Error: ", GetLastError());
           }
        }
     }

//--- Remove ALL visual objects from the chart ---
   Print(visual_comment_text, " - Removing all drawn objects from the chart.");
   ObjectsDeleteAll(0);

   Print("714 Method EA V7.03 deinitialized. Reason: ", reason);
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//| Finds an object by its tooltip and places a text label on it.    |
//+------------------------------------------------------------------+
void LabelObjectByTooltip(string searchText)
  {
   int totalObjects = ObjectsTotal(0);
   string newLabelName;

   for(int i = totalObjects - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i);

      // Skip our own labels to prevent trying to label a label.
      if(StringFind(objName, "LabelFor_", 0) == 0)
        {
         continue;
        }

      string tooltip = ObjectGetString(0, objName, OBJPROP_TEXT);

      // Check if the object's tooltip contains the text we're looking for
      if(StringFind(tooltip, searchText, 0) != -1)
        {
         // --- Match found! ---
         newLabelName = "LabelFor_" + objName;

         // OPTIMIZATION: If a label for this object already exists, skip it.
         // This makes the periodic scan very efficient.
         if(ObjectFind(0, newLabelName) >= 0)
           {
            continue;
           }

         // If we reach here, it means this is a NEW indicator object that needs a label.
         datetime labelTime = 0;
         double labelPrice = 0;
         ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, objName, OBJPROP_TYPE);

         if(objType == OBJ_RECTANGLE)
           {
            datetime time1 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
            double price1 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
            double price2 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);

            labelTime = time1 + (time2 - time1) / 2;
            labelPrice = price1 + (price2 - price1) / 2;
           }
         else
           {
            labelTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
            labelPrice = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
           }

         if(ObjectCreate(0, newLabelName, OBJ_TEXT, 0, labelTime, labelPrice))
           {
            ObjectSetString(0, newLabelName, OBJPROP_TEXT, searchText);
            ObjectSetInteger(0, newLabelName, OBJPROP_COLOR, clrWhite);
            ObjectSetInteger(0, newLabelName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(0, newLabelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, newLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, newLabelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, newLabelName, OBJPROP_SELECTABLE, false);

            PrintFormat("%s - Placed new label '%s' on object '%s'.",
                        visual_comment_text, searchText, objName);
           }
        }
     }
   ChartRedraw(); // Redraw chart once at the end of the scan
  }

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer()
  {
// --- Check for New Day and Re-initialize Timings if needed ---
   datetime server_midnight_today = iTime(_Symbol,PERIOD_D1,0);
   if(server_midnight_today > g_last_initialized_day_time && g_last_initialized_day_time != 0)
     {
      Print(visual_comment_text," - New Day Detected. Resetting daily variables.");
      CalculateAndDrawDailyTimings(); // This will reset all daily flags and redraw visuals
     }

// --- Process logic only on a NEW completed bar ---
   datetime current_completed_bar_time = iTime(_Symbol,PERIOD_CURRENT,1);
   if(current_completed_bar_time <= g_last_processed_bar_time_OnTimer)
     {
      return; // Not a new bar, do nothing
     }
   g_last_processed_bar_time_OnTimer = current_completed_bar_time;
   int current_bar_idx = 1; // We are analyzing the most recently closed bar

// --- Core Logic based on Time of Day ---
   datetime now = TimeCurrent();

// 1. Obtain Key Prices for all zones if not already done
   if(!g_key_price_obtained_today && now >= g_TodayKeyTime_Server)
      GetAndDrawKeyPrice(g_TodayKeyTime_Server, g_ObservationEndTime_Server, g_KeyPrice_At_KeyTime, g_key_price_obtained_today, "Main", obs_price_line_color);

   if(enable_morning_zone && !g_MorningZone_KeyPrice_Obtained_Today && now >= g_MorningZoneStartTime_Server)
      GetAndDrawKeyPrice(g_MorningZoneStartTime_Server, g_MorningZoneEndTime_Server, g_MorningZone_KeyPrice, g_MorningZone_KeyPrice_Obtained_Today, "Morning", morning_zone_color);

   if(enable_afternoon_zone && !g_AfternoonZone_KeyPrice_Obtained_Today && now >= g_AfternoonZoneStartTime_Server)
      GetAndDrawKeyPrice(g_AfternoonZoneStartTime_Server, g_AfternoonZoneEndTime_Server, g_AfternoonZone_KeyPrice, g_AfternoonZone_KeyPrice_Obtained_Today, "Afternoon", afternoon_zone_color);

// 2. Determine Bias after Observation Period ends
   if(!g_bias_determined_today && now >= g_ObservationEndTime_Server)
      DetermineInitialBias();

// NEW: Check for Anchor Price Interaction Alerts
   if(Operating_Mode == ANALYSIS_ALERTS && g_bias_determined_today)
     {
      if(alert_on_close_across_anchor || alert_on_rejection_of_anchor || alert_on_break_and_retest_of_anchor)
        {
         CheckAnchorPriceInteraction(current_bar_idx);
        }
     }

// 3. Scan for Order Blocks once bias is known
   if(g_bias_determined_today && g_InitialBias != 0 && !g_order_blocks_scanned_today)
      ScanForOrderBlocks();

// 4. Check for Trade Entry signals
   if(g_bias_determined_today && g_InitialBias != 0)
     {
      // Check if we are within the allowed time to search for entries
      bool is_entry_window_open = !use_entry_search_window || (now <= g_EntrySearchEndTime_Server);
      if(is_entry_window_open)
         CheckForTradeSignal(current_bar_idx);
     }

// 5. Update Mitigation Status of all Order Blocks
   UpdateMitigationStatus(current_bar_idx);

// 6. Manage any open trades
   ManageTrades();

// --- Periodically Scan for Indicator Objects to Label ---
   static datetime next_label_scan_time = 0;

// On the first run, set the initial scan time with a delay to allow the indicator to fully load
   if(next_label_scan_time == 0)
     {
      next_label_scan_time = now + initial_scan_delay_seconds;
     }

// Check if it's time to scan
   //if(label_scan_interval_seconds > 0 && now >= next_label_scan_time)
     //{
      // Force a chart refresh to ensure the indicator updates its object properties
      ChartRedraw();
      // Pause briefly to allow the terminal to process the redraw and update tooltips
      Sleep(chart_refresh_delay_ms);

      LabelObjectByTooltip();

      // Set the time for the next regular scan
      //next_label_scan_time = now + label_scan_interval_seconds;
    // }
  }

//+------------------------------------------------------------------+
//| TIME & SESSION MANAGEMENT                                        |
//+------------------------------------------------------------------+
void CalculateAndDrawDailyTimings()
  {
// Get all session times using the new function
   SessionTimes times=GetTodaySessionTimes();

// Update global variables
   g_TodayKeyTime_Server         = times.keyTime;
   g_ObservationEndTime_Server   = times.observationEnd;
   g_MorningZoneStartTime_Server = times.morningStart;
   g_MorningZoneEndTime_Server   = times.morningEnd;
   g_AfternoonZoneStartTime_Server = times.afternoonStart;
   g_AfternoonZoneEndTime_Server   = times.afternoonEnd;
   g_EntrySearchEndTime_Server   = times.entrySearchEnd;



// Draw visual elements if enabled
   if(visual_enabled)
     {
      RemoveAllVisuals();
      if(visual_main_timing_lines)
        {
         DrawTimeLine(times.keyTime,"Key Time",vline_keytime_color);
         DrawTimeLine(times.observationEnd,"Obs End",vline_obsend_color);
        }
      if(enable_morning_zone)
        {
         //DrawTimeZone(times.morningStart,times.morningEnd,"Morning Zone",morning_zone_color);
         DrawTimeLine(times.morningStart, "Morning Start", morning_zone_color, STYLE_SOLID, 2);
         DrawTimeLine(times.morningEnd, "Morning End", morning_zone_color, STYLE_SOLID, 2);
        }
      if(enable_afternoon_zone)
        {
         //DrawTimeZone(times.afternoonStart,times.afternoonEnd,"Afternoon Zone",afternoon_zone_color);
         DrawTimeLine(times.afternoonStart, "Afternoon Start", afternoon_zone_color, STYLE_SOLID, 2);
         DrawTimeLine(times.afternoonEnd, "Afternoon End", afternoon_zone_color, STYLE_SOLID, 2);
        }

      // Draw historic killzones if enabled
      if(historic_view_enabled)
        {
         DrawHistoricKillzones();
        }
     }

// Reset daily state flags
   g_last_initialized_day_time           = iTime(_Symbol,PERIOD_D1,0);
   g_bullishOB_count                     = 0;
   g_bearishOB_count                     = 0;
   g_bias_determined_today               = false;
   g_anchor_price_broken                 = false;
   g_close_across_alert_sent             = false;
   g_retest_alert_sent                   = false;
   g_order_blocks_scanned_today          = false;
   g_key_price_obtained_today            = false;
   g_MorningZone_KeyPrice_Obtained_Today = false;
   g_AfternoonZone_KeyPrice_Obtained_Today = false;

   Print(visual_comment_text, " - Daily timings reset and calculated for ", TimeToString(g_last_initialized_day_time, TIME_DATE));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SessionTimes GetTodaySessionTimes()
  {
   SessionTimes times;
   times.keyTime        = ConvertGMTPlus2ToBrokerTime(utcPlus2_KeyHour_1300,utcPlus2_KeyMinute_1300);
   times.observationEnd = times.keyTime + observation_Duration_Minutes * 60;
   times.morningStart   = ConvertGMTPlus2ToBrokerTime(morning_zone_start_hour_utc2,0);
   times.morningEnd     = ConvertGMTPlus2ToBrokerTime(morning_zone_end_hour_utc2,0);
   times.afternoonStart = ConvertGMTPlus2ToBrokerTime(afternoon_zone_start_hour_utc2,0);
   times.afternoonEnd   = ConvertGMTPlus2ToBrokerTime(afternoon_zone_end_hour_utc2,0);
   times.entrySearchEnd = use_entry_search_window ? ConvertGMTPlus2ToBrokerTime(entry_search_end_hour_utc2,entry_search_end_minute_utc2) : 0;

   Print(visual_comment_text, " - Today's session times: ",
         "Key Time: ", TimeToString(times.keyTime, TIME_DATE|TIME_MINUTES),
         ", Observation End: ", TimeToString(times.observationEnd, TIME_DATE|TIME_MINUTES),
         ", Morning Start: ", TimeToString(times.morningStart, TIME_DATE|TIME_MINUTES),
         ", Morning End: ", TimeToString(times.morningEnd, TIME_DATE|TIME_MINUTES),
         ", Afternoon Start: ", TimeToString(times.afternoonStart, TIME_DATE|TIME_MINUTES),
         ", Afternoon End: ", TimeToString(times.afternoonEnd, TIME_DATE|TIME_MINUTES),
         ", Entry Search End: ", use_entry_search_window ? TimeToString(times.entrySearchEnd, TIME_DATE|TIME_MINUTES) : "Disabled");
   return times;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateServerGmtOffset()
  {
   datetime server_time = TimeTradeServer();
   datetime gmt_time = TimeGMT();
   long offset_sec = server_time - gmt_time;
   g_server_gmt_offset_hours = (int)(offset_sec / 3600);

// Manual override if auto-detection fails or is disabled
   if(!auto_detect_gmt_offset || g_server_gmt_offset_hours == 0)
     {
      g_server_gmt_offset_hours = manual_gmt_offset_hours;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime ConvertGMTPlus2ToBrokerTime(int hourGMTPlus2, int minute = 0)
  {
// Calculate the difference in hours between the broker's server time and GMT+2
// If broker is GMT+3 and we want GMT+2 time, we need to add 1 hour to convert GMT+2 to GMT+3
   int hour_difference = g_server_gmt_offset_hours - 2;

// Get today's date from the server time
   MqlDateTime server_time_struct;
   TimeToStruct(TimeTradeServer(), server_time_struct);

// Set the desired time using the input hour/minute adjusted by the timezone difference
// Example: 07:00 GMT+2 on GMT+3 broker = 07:00 + (3-2) = 08:00 broker time
   server_time_struct.hour = hourGMTPlus2 + hour_difference;
   server_time_struct.min  = minute;
   server_time_struct.sec  = 0;

// Convert the struct back to a datetime value, which represents the correct moment in server time
   return StructToTime(server_time_struct);
  }


//+------------------------------------------------------------------+
//| CORE STRATEGY LOGIC FUNCTIONS                                    |
//+------------------------------------------------------------------+
void GetAndDrawKeyPrice(datetime startTime, datetime endTime, double &keyPriceVariable, bool &isObtainedFlag, string zoneName, color lineColor)
  {
   if(isObtainedFlag || !visual_enabled || !visual_obs_price_line)
      return;

   int barIndex = iBarShift(_Symbol, _Period, startTime, false);
   if(barIndex < 0)
      return;

   keyPriceVariable = iOpen(_Symbol, _Period, barIndex);
   if(keyPriceVariable > 0)
     {
      isObtainedFlag = true;
      Print(visual_comment_text, " - ", zoneName, " Key Price obtained: ", DoubleToString(keyPriceVariable, _Digits));
      string lineName = "KeyPrice_" + zoneName + "_" + TimeToString(startTime, TIME_DATE);
      ObjectDelete(0, lineName);
      if(ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, keyPriceVariable, endTime, keyPriceVariable))
        {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DetermineInitialBias()
  {
   int key_bar_idx = iBarShift(_Symbol,_Period,g_TodayKeyTime_Server,false);
   int obs_end_bar_idx = iBarShift(_Symbol,_Period,g_ObservationEndTime_Server,false);

   if(key_bar_idx < 0 || obs_end_bar_idx < 0)
     {
      Print(visual_comment_text," - Warning: Cannot determine bias, invalid bar indices for key times.");
      return;
     }

   double price_at_keytime = iOpen(_Symbol,_Period,key_bar_idx);
   double price_at_obs_end = iClose(_Symbol,_Period,obs_end_bar_idx);

   if(price_at_obs_end > price_at_keytime)
     {
      g_InitialBias = 1; // Bullish move -> look for Sells
      Print(visual_comment_text," - Bias determined: BULLISH. Looking for SELL setups.");
     }
   else
      if(price_at_obs_end < price_at_keytime)
        {
         g_InitialBias = -1; // Bearish move -> look for Buys
         Print(visual_comment_text," - Bias determined: BEARISH. Looking for BUY setups.");
        }
      else
        {
         g_InitialBias = 0; // Sideways
         Print(visual_comment_text," - Bias determined: SIDEWAYS. No trades today.");
        }
   g_bias_determined_today = true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ScanForOrderBlocks()
  {
   if(g_order_blocks_scanned_today)
      return;

   datetime scan_end_time   = g_ObservationEndTime_Server;
   datetime scan_start_time = g_TodayKeyTime_Server - (30 * PeriodSeconds()); // Scan 30 bars before key time

   int newest_idx = iBarShift(_Symbol,_Period,scan_end_time,false);
   int oldest_idx = iBarShift(_Symbol,_Period,scan_start_time,false);

   if(newest_idx < 0 || oldest_idx < 0 || newest_idx >= oldest_idx)
     {
      Print(visual_comment_text, " - OB Scan Error: Invalid bar range for scan.");
      g_order_blocks_scanned_today = true;
      return;
     }

   DetectOrderBlocksForToday(newest_idx, oldest_idx);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForTradeSignal(int bar_idx)
  {
// Ensure no position is already open for TRADING mode
   if(Operating_Mode == TRADING)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic_Number && PositionGetString(POSITION_SYMBOL) == _Symbol)
           {
            return; // Exit if a trade by this EA on this symbol exists
           }
        }
     }

   g_trade_signal_this_bar = false;
   bool conditions_met = false;
   string setup_description = "";

   if(g_InitialBias == -1)  // Bias is Bearish, look for BUYS
     {
      conditions_met = YourBuyEntryConditionsMet(bar_idx);
      if(conditions_met)
        {
         setup_description = _Symbol + " M" + IntegerToString(_Period) + " - Potential BUY Setup."
                           + "\n- Price interacting with Bullish OB from " + TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES)
                           + "\n- Initial Bias: BEARISH (Buy Opportunity)";
        }
     }
   else if(g_InitialBias == 1)  // Bias is Bullish, look for SELLS
     {
      conditions_met = YourSellEntryConditionsMet(bar_idx);
      if(conditions_met)
        {
         setup_description = _Symbol + " M" + IntegerToString(_Period) + " - Potential SELL Setup."
                           + "\n- Price interacting with Bearish OB from " + TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES)
                           + "\n- Initial Bias: BULLISH (Sell Opportunity)";
        }
     }

// --- Perform Action based on Operating Mode ---
   if(conditions_met)
     {
      if(Operating_Mode == ANALYSIS_ALERTS)
        {
         Print(visual_comment_text, " - ANALYSIS & ALERT MODE: Triggered Setup. Generating Alert...");
         Print(visual_comment_text, " - Details: ", setup_description);
         string screenshot_path = TakeScreenshot();
         if(screenshot_path != "") // Only send if screenshot was successful
           {
            SendTelegramAlert(setup_description, screenshot_path);
           }
        }
      else // TRADING mode
        {
         Print(visual_comment_text, " - TRADING MODE: Triggered Setup. Attempting trade execution...");
         if(g_InitialBias == -1)
           {
            Print(visual_comment_text, " - BUY Signal Triggered by OB at ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
            PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, bar_idx, g_triggered_ob_for_trade);
           }
         else if(g_InitialBias == 1)
           {
            Print(visual_comment_text, " - SELL Signal Triggered by OB at ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
            PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, bar_idx, g_triggered_ob_for_trade);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| ORDER BLOCK & ENTRY CONDITION LOGIC                              |
//+------------------------------------------------------------------+
void DetectOrderBlocksForToday(int scan_newest_chart_idx,int scan_oldest_chart_idx)
  {
   g_order_blocks_scanned_today=true;
   int total_bars = Bars(_Symbol,_Period);
   if(scan_oldest_chart_idx >= total_bars)
      scan_oldest_chart_idx = total_bars - 1;

   int bars_to_copy = scan_oldest_chart_idx + 1;
   if(bars_to_copy <= 0)
      return;

   MqlRates rates[];
   if(CopyRates(_Symbol,_Period,0,bars_to_copy,rates) < bars_to_copy)
     {
      Print("Error copying rates for OB scan. Error: ",GetLastError());
      return;
     }
   ArraySetAsSeries(rates,true); // rates[0] is current bar, rates[1] is previous, etc.

   g_bullishOB_count=0;
   g_bearishOB_count=0;

   Print(visual_comment_text, " - Scanning for OBs from bar ", scan_newest_chart_idx, " to ", scan_oldest_chart_idx);

   for(int i=scan_newest_chart_idx; i<=scan_oldest_chart_idx; i++)
     {
      if(IsBullishOrderBlockCandidate(i, rates))
        {
         if(g_bullishOB_count < ArraySize(g_bullishOrderBlocks))
           {
            st_OrderBlock ob;
            ob.startTime    = rates[i].time;
            ob.high         = rates[i].high;
            ob.low          = rates[i].low;
            ob.type         = POSITION_TYPE_BUY;
            ob.isMitigated  = false;
            string obj_name_part = TimeToString(ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_B" + (string)i;
            ob.objectName   = "BullOB_" + obj_name_part;
            ob.labelName    = "Lbl_BullOB_" + obj_name_part;

            g_bullishOrderBlocks[g_bullishOB_count] = ob;
            Print(visual_comment_text," - Found Bullish OB at ",TimeToString(ob.startTime, TIME_DATE|TIME_SECONDS));
            if(visual_enabled && visual_order_blocks)
               DrawOrderBlock(ob);

            g_bullishOB_count++;
           }
        }
      else
         if(IsBearishOrderBlockCandidate(i, rates))
           {
            if(g_bearishOB_count < ArraySize(g_bearishOrderBlocks))
              {
               st_OrderBlock ob;
               ob.startTime    = rates[i].time;
               ob.high         = rates[i].high;
               ob.low          = rates[i].low;
               ob.type         = POSITION_TYPE_SELL;
               ob.isMitigated  = false;
               string obj_name_part = TimeToString(ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_S" + (string)i;
               ob.objectName   = "BearOB_" + obj_name_part;
               ob.labelName    = "Lbl_BearOB_" + obj_name_part;

               g_bearishOrderBlocks[g_bearishOB_count] = ob;
               Print(visual_comment_text," - Found Bearish OB at ",TimeToString(ob.startTime, TIME_DATE|TIME_SECONDS));
               if(visual_enabled && visual_order_blocks)
                  DrawOrderBlock(ob);

               g_bearishOB_count++;
              }
           }
     }
   Print(visual_comment_text, " - OB scan finished. Bullish: ", g_bullishOB_count, ", Bearish: ", g_bearishOB_count);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishOrderBlockCandidate(int bar_idx, const MqlRates &rates[])
  {
   if(bar_idx + ob_Lookback_Bars_For_Impulse >= ArraySize(rates))
      return false; // Ensure enough data
   if(bar_idx < ob_Lookback_Bars_For_Impulse)
      return false; // Ensure we don't go into negative indices

// 1. Candidate candle must be bearish.
   if(rates[bar_idx].close >= rates[bar_idx].open)
      return false;

// 2. Check for bullish impulse move afterwards.
   double move_pips = 0;
   int impulse_end_idx = -1;
   int min_idx = MathMax(0, bar_idx - ob_Lookback_Bars_For_Impulse);
   for(int i = bar_idx - 1; i >= min_idx; i--)
     {
      // The move must break the high of the candidate candle.
      if(rates[i].high > rates[bar_idx].high)
        {
         move_pips = (rates[i].high - rates[bar_idx].high) / _Point;
         if(_Digits == 3 || _Digits == 5)
            move_pips /= 10.0;
         impulse_end_idx = i;
         break;
        }
     }
   if(move_pips < ob_MinMovePips)
      return false;

// 3. Check that candles between the OB and the impulse break do not take the low of the OB.
   for(int i = bar_idx - 1; i > impulse_end_idx && i >= 0; i--)
     {
      if(rates[i].low < rates[bar_idx].low)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishOrderBlockCandidate(int bar_idx, const MqlRates &rates[])
  {
   if(bar_idx + ob_Lookback_Bars_For_Impulse >= ArraySize(rates))
      return false; // Ensure enough data
   if(bar_idx < ob_Lookback_Bars_For_Impulse)
      return false; // Ensure we don't go into negative indices

// 1. Candidate candle must be bullish.
   if(rates[bar_idx].close <= rates[bar_idx].open)
      return false;

// 2. Check for bearish impulse move afterwards.
   double move_pips = 0;
   int impulse_end_idx = -1;
   int min_idx = MathMax(0, bar_idx - ob_Lookback_Bars_For_Impulse);
   for(int i = bar_idx - 1; i >= min_idx; i--)
     {
      // The move must break the low of the candidate candle.
      if(rates[i].low < rates[bar_idx].low)
        {
         move_pips = (rates[bar_idx].low - rates[i].low) / _Point;
         if(_Digits == 3 || _Digits == 5)
            move_pips /= 10.0;
         impulse_end_idx = i;
         break;
        }
     }
   if(move_pips < ob_MinMovePips)
      return false;

// 3. Check that candles between the OB and the impulse break do not take the high of the OB.
   for(int i = bar_idx - 1; i > impulse_end_idx && i >= 0; i--)
     {
      if(rates[i].high > rates[bar_idx].high)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateMitigationStatus(int current_closed_bar_index)
  {
   if(g_bullishOB_count == 0 && g_bearishOB_count == 0)
      return;

   double check_high = iHigh(_Symbol, _Period, current_closed_bar_index);
   double check_low  = iLow(_Symbol, _Period, current_closed_bar_index);

   for(int i = 0; i < g_bullishOB_count; i++)
     {
      if(!g_bullishOrderBlocks[i].isMitigated)
        {
         if(check_low < g_bullishOrderBlocks[i].low)
           {
            g_bullishOrderBlocks[i].isMitigated = true;
            Print(visual_comment_text, " - Bullish OB at ", TimeToString(g_bullishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " mitigated.");
            if(visual_enabled && visual_order_blocks)
               UpdateOrderBlockVisual(g_bullishOrderBlocks[i]);
           }
        }
     }

   for(int i = 0; i < g_bearishOB_count; i++)
     {
      if(!g_bearishOrderBlocks[i].isMitigated)
        {
         if(check_high > g_bearishOrderBlocks[i].high)
           {
            g_bearishOrderBlocks[i].isMitigated = true;
            Print(visual_comment_text, " - Bearish OB at ", TimeToString(g_bearishOrderBlocks[i].startTime, TIME_DATE|TIME_MINUTES), " mitigated.");
            if(visual_enabled && visual_order_blocks)
               UpdateOrderBlockVisual(g_bearishOrderBlocks[i]);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool YourBuyEntryConditionsMet(int closed_bar_index)
  {
   if(g_InitialBias != -1)
      return false; // We need a bearish bias to look for buys

   double current_high = iHigh(_Symbol, _Period, closed_bar_index);
   double current_low  = iLow(_Symbol, _Period, closed_bar_index);
   datetime current_time = iTime(_Symbol, _Period, closed_bar_index);

   for(int i = g_bullishOB_count - 1; i >= 0; i--)
     {
      st_OrderBlock ob = g_bullishOrderBlocks[i];
      if(!ob.isMitigated && ob.startTime < current_time)
        {
         // Condition: The low of the current bar has entered the OB's range
         if(current_low <= ob.high)
           {
            Print(visual_comment_text," - Buy Check: Bar at ", TimeToString(current_time), " interacted with Bullish OB at ", TimeToString(ob.startTime));
            g_triggered_ob_for_trade = ob;
            g_trade_signal_this_bar = true;
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool YourSellEntryConditionsMet(int closed_bar_index)
  {
   if(g_InitialBias != 1)
      return false; // We need a bullish bias to look for sells

   double current_high = iHigh(_Symbol, _Period, closed_bar_index);
   double current_low  = iLow(_Symbol, _Period, closed_bar_index);
   datetime current_time = iTime(_Symbol, _Period, closed_bar_index);

   for(int i = g_bearishOB_count - 1; i >= 0; i--)
     {
      st_OrderBlock ob = g_bearishOrderBlocks[i];
      if(!ob.isMitigated && ob.startTime < current_time)
        {
         // Condition: The high of the current bar has entered the OB's range
         if(current_high >= ob.low)
           {
            Print(visual_comment_text," - Sell Check: Bar at ", TimeToString(current_time), " interacted with Bearish OB at ", TimeToString(ob.startTime));
            g_triggered_ob_for_trade = ob;
            g_trade_signal_this_bar = true;
            return true;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| TRADE EXECUTION AND MANAGEMENT                                   |
//+------------------------------------------------------------------+
void PlaceBuyOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref)
  {
   double entry_price   = SymbolInfoDouble(_Symbol,SYMBOL_ASK);

// Fix pip value calculation
   double pip_value = _Point;
   if(_Digits == 3 || _Digits == 5)
      pip_value *= 10;

   double sl_price      = triggered_ob_ref.low - (sl_buffer_pips_input * pip_value);
   double tp_price      = entry_price + (tp_pips_placeholder_input * pip_value);

// Validate SL is below entry for BUY orders
   if(sl_price >= entry_price)
     {
      Print(visual_comment_text," - ERROR: SL (", sl_price, ") must be BELOW entry (", entry_price, ") for BUY orders");
      return;
     }

// Validate TP is above entry for BUY orders
   if(tp_price <= entry_price)
     {
      Print(visual_comment_text," - ERROR: TP (", tp_price, ") must be ABOVE entry (", entry_price, ") for BUY orders");
      return;
     }

// Check minimum distance requirements
   long min_stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = min_stops_level * _Point;

   if((entry_price - sl_price) < min_distance)
     {
      sl_price = entry_price - min_distance * 1.5;
      Print(visual_comment_text," - Adjusted SL to meet minimum distance: ", sl_price);
     }

   if((tp_price - entry_price) < min_distance)
     {
      tp_price = entry_price + min_distance * 1.5;
      Print(visual_comment_text," - Adjusted TP to meet minimum distance: ", tp_price);
     }

   double lot_size      = CalculateLotSize(risk_perc,entry_price,sl_price);

   if(lot_size > 0)
     {
      Print(visual_comment_text," - Attempting BUY: Lots=",lot_size,", Entry~",entry_price,", SL=",sl_price,", TP=",tp_price);
      if(trade.Buy(lot_size,_Symbol,entry_price,sl_price,tp_price,"714EA_Buy_OB"))
        {
         Print(visual_comment_text," - BUY Order Sent Successfully. Ticket: ",trade.ResultOrder());
        }
      else
        {
         Print(visual_comment_text," - Error placing BUY order: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
        }
     }
   else
     {
      Print(visual_comment_text," - BUY Order NOT Placed. Calculated lot size is zero or invalid.");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void PlaceSellOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref)
  {
   double entry_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);

// Fix pip value calculation
   double pip_value = _Point;
   if(_Digits == 3 || _Digits == 5)
      pip_value *= 10;

   double sl_price    = triggered_ob_ref.high + (sl_buffer_pips_input * pip_value);
   double tp_price    = entry_price - (tp_pips_placeholder_input * pip_value);

// Validate SL is above entry for SELL orders
   if(sl_price <= entry_price)
     {
      Print(visual_comment_text," - ERROR: SL (", sl_price, ") must be ABOVE entry (", entry_price, ") for SELL orders");
      return;
     }

// Validate TP is below entry for SELL orders
   if(tp_price >= entry_price)
     {
      Print(visual_comment_text," - ERROR: TP (", tp_price, ") must be BELOW entry (", entry_price, ") for SELL orders");
      return;
     }

// Check minimum distance requirements
   long min_stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = min_stops_level * _Point;

   if((sl_price - entry_price) < min_distance)
     {
      sl_price = entry_price + min_distance * 1.5;
      Print(visual_comment_text," - Adjusted SL to meet minimum distance: ", sl_price);
     }

   if((entry_price - tp_price) < min_distance)
     {
      tp_price = entry_price - min_distance * 1.5;
      Print(visual_comment_text," - Adjusted TP to meet minimum distance: ", tp_price);
     }

   double lot_size    = CalculateLotSize(risk_perc,entry_price,sl_price);

   if(lot_size > 0)
     {
      Print(visual_comment_text," - Attempting SELL: Lots=",lot_size,", Entry~",entry_price,", SL=",sl_price,", TP=",tp_price);
      if(trade.Sell(lot_size,_Symbol,entry_price,sl_price,tp_price,"714EA_Sell_OB"))
        {
         Print(visual_comment_text," - SELL Order Sent Successfully. Ticket: ",trade.ResultOrder());
        }
      else
        {
         Print(visual_comment_text," - Error placing SELL order: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
        }
     }
   else
     {
      Print(visual_comment_text," - SELL Order NOT Placed. Calculated lot size is zero or invalid.");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double risk_perc,double entry_price,double stop_loss_price)
  {
   if(risk_perc <= 0)
      return 0.0;
   double account_balance = AccountInfoDouble(ACCOUNT_EQUITY);
   if(account_balance <= 0)
      return 0.0;

   double risk_amount = account_balance * (risk_perc / 100.0);
   double sl_distance = MathAbs(entry_price - stop_loss_price);

   if(sl_distance < SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point)
     {
      Print(visual_comment_text, " - SL distance is too small. Cannot calculate lot size.");
      return 0.0;
     }

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_size <= 0)
      return 0.0;

   double loss_per_lot = (sl_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0)
      return 0.0;

   double volume = risk_amount / loss_per_lot;

//--- Normalize and check against limits
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathFloor(volume / volume_step) * volume_step;

   if(volume < min_volume)
     {
      Print(visual_comment_text, " - Calculated lot size ", DoubleToString(volume,2), " is below minimum. Cannot place trade with this risk.");
      return 0.0;
     }

   volume = MathMin(volume, max_volume);

   return(NormalizeDouble(volume, 2));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrades()
  {
   datetime now = TimeCurrent();
   datetime session_end_server_time = ConvertGMTPlus2ToBrokerTime(session_End_UTC2_Hour, session_End_UTC2_Minute);

   if(now >= session_end_server_time)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong position_ticket = PositionGetTicket(i);
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic_Number)
           {
            Print(visual_comment_text, " - Closing trade #", position_ticket, " due to session end.");
            trade.PositionClose(position_ticket);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| VISUALIZATION & UTILITY FUNCTIONS                                |
//+------------------------------------------------------------------+
void DrawTimeLine(datetime time,string text,color clr,ENUM_LINE_STYLE style=STYLE_SOLID,int width=1,bool back=false,int ray=0,string name_prefix="")
  {
   if(!visual_enabled)
      return;
   string name = name_prefix + text + "_" + TimeToString(time,TIME_DATE);
   ObjectDelete(0,name);
   if(ObjectCreate(0,name,OBJ_VLINE,0,time,0))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_STYLE,style);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTimeZone(datetime startTime,datetime endTime,string text,color clr)
  {
   if(!visual_enabled)
      return;

   string name = "Zone_" + text + "_" + TimeToString(startTime,TIME_DATE);
   ObjectDelete(0,name);

   double price_max = ChartGetDouble(0,CHART_PRICE_MAX,0);
   double price_min = ChartGetDouble(0,CHART_PRICE_MIN,0);

// If chart price range is invalid (0.0), use current price +/- reasonable range
   if(price_max <= 0 || price_min <= 0 || price_max == price_min)
     {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double price_range = current_price * 0.01; // 1% range
      price_max = current_price + price_range;
      price_min = current_price - price_range;
     }

   if(ObjectCreate(0,name,OBJ_RECTANGLE,0,startTime,price_max,endTime,price_min))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_FILL,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricKillzones()
  {
   if(!visual_enabled || !historic_view_enabled)
      return;

// Validate input range
   int days_to_draw = MathMax(1, MathMin(90, historic_view_days));

   Print(visual_comment_text, " - Drawing historic killzones for ", days_to_draw, " days");
   Print(visual_comment_text, " - Zone settings: Morning=", enable_morning_zone, ", Afternoon=", enable_afternoon_zone, ", Main=", visual_main_timing_lines);

// Get current server time and calculate start date
   datetime current_time = TimeTradeServer();
   MqlDateTime current_dt;
   TimeToStruct(current_time, current_dt);

// Start from yesterday and go back
   for(int day_offset = 1; day_offset <= days_to_draw; day_offset++)
     {
      // Calculate the date for this historic day
      datetime historic_date = current_time - (day_offset * 24 * 3600);
      MqlDateTime historic_dt;
      TimeToStruct(historic_date, historic_dt);

      // Skip weekends (Saturday = 6, Sunday = 0)
      if(historic_dt.day_of_week == 0 || historic_dt.day_of_week == 6)
         continue;

      // Calculate killzone times for this historic day
      datetime historic_key_time = ConvertGMTPlus2ToBrokerTimeForDate(historic_date, utcPlus2_KeyHour_1300, utcPlus2_KeyMinute_1300);
      datetime historic_obs_end = historic_key_time + observation_Duration_Minutes * 60;

      // Draw main killzone (Key Time to Observation End)
      if(visual_main_timing_lines)
        {
         string main_zone_name = "Historic_Main_" + TimeToString(historic_date, TIME_DATE);
         DrawHistoricTimeZone(historic_key_time, historic_obs_end, main_zone_name, C'70,70,140'); // Darker blue for historic
        }

      // Draw morning zone if enabled
      if(enable_morning_zone)
        {
         datetime historic_morning_start = ConvertGMTPlus2ToBrokerTimeForDate(historic_date, morning_zone_start_hour_utc2, 0);
         datetime historic_morning_end = ConvertGMTPlus2ToBrokerTimeForDate(historic_date, morning_zone_end_hour_utc2, 0);
         string morning_zone_name = "Historic_Morning_" + TimeToString(historic_date, TIME_DATE);
         Print(visual_comment_text, " - Drawing historic morning zone for ", TimeToString(historic_date, TIME_DATE),
               " from ", TimeToString(historic_morning_start, TIME_DATE|TIME_MINUTES),
               " to ", TimeToString(historic_morning_end, TIME_DATE|TIME_MINUTES));
         DrawHistoricTimeZone(historic_morning_start, historic_morning_end, morning_zone_name, C'15,30,45'); // Darker morning color
        }

      // Draw afternoon zone if enabled
      if(enable_afternoon_zone)
        {
         datetime historic_afternoon_start = ConvertGMTPlus2ToBrokerTimeForDate(historic_date, afternoon_zone_start_hour_utc2, 0);
         datetime historic_afternoon_end = ConvertGMTPlus2ToBrokerTimeForDate(historic_date, afternoon_zone_end_hour_utc2, 0);
         string afternoon_zone_name = "Historic_Afternoon_" + TimeToString(historic_date, TIME_DATE);
         DrawHistoricTimeZone(historic_afternoon_start, historic_afternoon_end, afternoon_zone_name, C'80,30,0'); // Darker afternoon color
        }
     }

   ChartRedraw();
   Print(visual_comment_text, " - Historic killzones drawing completed");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricTimeZone(datetime startTime, datetime endTime, string zoneName, color clr)
  {
   if(!visual_enabled)
      return;

   ObjectDelete(0, zoneName);

// Use maximum possible price range for historic killzones
   double price_max = DBL_MAX;
   double price_min = 0.0;

// Alternative approach: Get the absolute maximum range from chart data
   double chart_max = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   double chart_min = ChartGetDouble(0, CHART_PRICE_MIN, 0);

   if(chart_max > 0 && chart_min > 0 && chart_max != chart_min)
     {
      // Extend the range significantly beyond visible chart
      double chart_range = chart_max - chart_min;
      price_max = chart_max + (chart_range * 10); // Extend 10x above
      price_min = MathMax(0, chart_min - (chart_range * 10)); // Extend 10x below (but not negative)
     }
   else
     {
      // Fallback: use current price with very large range
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      price_max = current_price * 100; // 100x current price
      price_min = current_price * 0.01; // 1% of current price
     }

   if(ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, price_max, endTime, price_min))
     {
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, false);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
      ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT); // Use dotted style for historic zones
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime ConvertGMTPlus2ToBrokerTimeForDate(datetime target_date, int hourGMTPlus2, int minute = 0)
  {
// Calculate the difference in hours between the broker's server time and GMT+2
   int hour_difference = g_server_gmt_offset_hours - 2;

// Convert target date to struct
   MqlDateTime target_dt;
   TimeToStruct(target_date, target_dt);

// Set the desired time using the input hour/minute adjusted by the timezone difference
   target_dt.hour = hourGMTPlus2 + hour_difference;
   target_dt.min = minute;
   target_dt.sec = 0;

// Convert back to datetime
   return StructToTime(target_dt);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawOrderBlock(const st_OrderBlock &ob)
  {
   if(!visual_enabled || !visual_order_blocks)
      return;
   ObjectDelete(0, ob.objectName);
   ObjectDelete(0, ob.labelName);

   color ob_color = (ob.type == POSITION_TYPE_BUY) ? ob_bullish_color : ob_bearish_color;
   string ob_text = (ob.type == POSITION_TYPE_BUY) ? "Bull OB" : "Bear OB";

   datetime time2 = ob.startTime + PeriodSeconds();
   if(ObjectCreate(0,ob.objectName,OBJ_RECTANGLE,0,ob.startTime,ob.high,time2,ob.low))
     {
      ObjectSetInteger(0,ob.objectName,OBJPROP_COLOR,ob_color);
      ObjectSetInteger(0,ob.objectName,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,ob.objectName,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,ob.objectName,OBJPROP_FILL,true);
      ObjectSetInteger(0,ob.objectName,OBJPROP_BACK,true);
      ObjectSetInteger(0,ob.objectName,OBJPROP_SELECTABLE,false);
     }

   datetime lbl_time = ob.startTime + PeriodSeconds()/2;
   double lbl_price = (ob.high + ob.low) / 2.0;
   if(ObjectCreate(0,ob.labelName,OBJ_TEXT,0,lbl_time,lbl_price))
     {
      ObjectSetString(0,ob.labelName,OBJPROP_TEXT,ob_text);
      ObjectSetInteger(0,ob.labelName,OBJPROP_COLOR,ob_label_color);
      ObjectSetInteger(0,ob.labelName,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(0,ob.labelName,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,ob.labelName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,ob.labelName,OBJPROP_BACK,false);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateOrderBlockVisual(const st_OrderBlock &ob)
  {
   if(!visual_enabled || !visual_order_blocks)
      return;
   if(ObjectFind(0, ob.objectName) < 0)
      return; // Object not found

   ObjectSetInteger(0, ob.objectName, OBJPROP_COLOR, ob_mitigated_color);
   if(ObjectFind(0, ob.labelName) >= 0)
     {
      string newText = (ob.type == POSITION_TYPE_BUY ? "Bull" : "Bear") + string(" OB Mitigated");
      ObjectSetString(0, ob.labelName, OBJPROP_TEXT, newText);
      ObjectSetInteger(0, ob.labelName, OBJPROP_COLOR, clrGray);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveAllVisuals()
  {
   ObjectsDeleteAll(0,0,-1); // Deletes all objects on the chart
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Finds an object by its tooltip and places a text label on it.    |
//+------------------------------------------------------------------+
void LabelObjectByTooltip()
  {
   //Print(__FUNCTION__);
// Loop through all rectangle objects on the chart
   int total_objects = ObjectsTotal(0, -1, OBJ_RECTANGLE);

   for(int i = total_objects - 1; i >= 0; i--)
     {
      string objName = ObjectName(0, i, -1, OBJ_RECTANGLE);
      //Print(visual_comment_text, " - Labeling object: ", objName);
      // Ignore our own labels that might be named similarly by chance
      if(StringFind(objName, "auto_label_") != -1)
         continue;

      string tooltip = ObjectGetString(0, objName, OBJPROP_TOOLTIP);
      //Print(visual_comment_text, " - Tooltip: ", tooltip);

      // If the object has no tooltip, skip it
      if(tooltip == "")
         continue;

      // Check if a label for this object already exists to avoid re-labeling
      string labelName = "auto_label_" + objName;
      if(ObjectFind(0, labelName) == -1)
        {
         // Get the center coordinates of the rectangle to place the label
         datetime time1 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         double price1 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
         datetime time2 = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
         double price2 = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);

         datetime labelTime = time1 + (time2 - time1) / 2;
         double labelPrice = price1 + (price2 - price1) / 2;
         string labelText = tooltip; // Use the object's own tooltip as the label text
         //Print(visual_comment_text, " - Labeling object: ", labelName, " with text: ", labelText);
         //Print("going to create the label now for: ", labelName);

         // Create the new text label
         if(ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, labelPrice))
           {
            //Print(visual_comment_text, " - Label created: ", labelName);
            ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Calibri");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false); // No background for the text
           }
         else
           {
            //Print(visual_comment_text, " - Label not created: ", labelName);
           }
        
        }
     }
  }
//+------------------------------------------------------------------+
// --- Takes a screenshot and returns the file path if successful, or "" if failed ---
string TakeScreenshot()
  {
   if(!enable_screenshot)
      return "";

// Create a valid filename
   string filename = _Symbol + "_" + EnumToString((ENUM_TIMEFRAMES)_Period) + "_" + TimeToString(TimeCurrent(),"yyyy.MM.dd_HH-mm-ss") + ".gif";

// Construct path relative to MQL5/Files
   string relative_filepath = (screenshot_subfolder != "" ? screenshot_subfolder + "\\" : "") + filename;

// Ensure the subdirectory exists.
   if(screenshot_subfolder != "")
     {
      // FolderCreate returns true if the folder exists or was successfully created.
      if(!FolderCreate(screenshot_subfolder, FILE_COMMON))
        {
         Print(visual_comment_text," - ERROR: Failed to create screenshot directory: ", TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\MQL5\\Files\\" + screenshot_subfolder, ". Error: ", GetLastError());
         // We can still attempt to save in the root Files folder, so we don't return "" here.
        }
     }

// Take the screenshot. NOTE: "Allow DLL imports" must be enabled in EA properties.
   if(ChartScreenShot(0,relative_filepath,1024,768,ALIGN_RIGHT))
     {
      string full_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\MQL5\\Files\\" + relative_filepath;
      Print(visual_comment_text," - Screenshot saved to: ",full_path);
      return full_path;
     }
   else
     {
      Print(visual_comment_text," - ERROR: Failed to take screenshot! Error: ",GetLastError());
      return "";
     }
  }

// --- Sends a message with an attached screenshot to Telegram ---
// NOTE: For WebRequest to work, the URL 'https://api.telegram.org' must be added to the list
// of allowed URLs in MetaTrader 5 "Tools" -> "Options" -> "Expert Advisors" tab.
void SendTelegramAlert(string message_text,string image_filepath)
  {
   if(!enable_telegram_alert)
      return;
   if(telegram_bot_token == "" || telegram_bot_token == "YOUR_BOT_TOKEN_HERE" || telegram_chat_id == "" || telegram_chat_id == "YOUR_CHAT_ID_HERE")
     {
      Print(visual_comment_text," - Telegram settings (token/chat_id) are not configured. Alert not sent.");
      return;
     }

// Read image file
   uchar image_data[];
   int file_handle = FileOpen(image_filepath,FILE_READ|FILE_BIN|FILE_COMMON);
   if(file_handle == INVALID_HANDLE)
     {
      Print(visual_comment_text," - ERROR: Could not open screenshot file for sending to Telegram: ",image_filepath,". Error: ",GetLastError());
      return;
     }
   ulong file_size = FileSize(file_handle);
   ArrayResize(image_data,(int)file_size);
   FileReadArray(file_handle,image_data);
   FileClose(file_handle);

// Prepare multipart/form-data body
   string boundary = "----714EABotBoundary";
   string header = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

   string body_part1 = "--" + boundary + "\r\n"
                     + "Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n"
                     + telegram_chat_id + "\r\n"
                     + "--" + boundary + "\r\n"
                     + "Content-Disposition: form-data; name=\"caption\"\r\n\r\n"
                     + telegram_message_prefix + " " + message_text + "\r\n"
                     + "--" + boundary + "\r\n"
                     + "Content-Disposition: form-data; name=\"photo\"; filename=\"chart.gif\"\r\n"
                     + "Content-Type: image/gif\r\n\r\n";

   string body_part2 = "\r\n--" + boundary + "--\r\n";

// Convert string parts to uchar arrays
   uchar body_part1_arr[], body_part2_arr[];
   StringToCharArray(body_part1,body_part1_arr,0,StringLen(body_part1),CP_UTF8);
   StringToCharArray(body_part2,body_part2_arr,0,StringLen(body_part2),CP_UTF8);

// Combine all parts into the final request body
   uchar request_body[];
   int total_size = ArraySize(body_part1_arr) + ArraySize(image_data) + ArraySize(body_part2_arr);
   ArrayResize(request_body,total_size);

   int offset = 0;
   ArrayCopy(request_body,body_part1_arr,offset,0,ArraySize(body_part1_arr));
   offset += ArraySize(body_part1_arr);
   ArrayCopy(request_body,image_data,offset,0,ArraySize(image_data));
   offset += ArraySize(image_data);
   ArrayCopy(request_body,body_part2_arr,offset,0,ArraySize(body_part2_arr));

// Make the WebRequest
   string url = "https://api.telegram.org/bot" + telegram_bot_token + "/sendPhoto";
   char result_data[];
   int timeout = 10000; // 10 second timeout
   string result_headers;

   ResetLastError();
   int res_code = WebRequest("POST",url,header,timeout,request_body,result_data,result_headers);

   if(res_code == 200)
     {
      Print(visual_comment_text," - Telegram alert sent successfully.");
     }
   else
     {
      Print(visual_comment_text," - ERROR sending Telegram alert! Response code: ",res_code,", Error: ",GetLastError());
      Print(visual_comment_text," - Telegram response: ",CharArrayToString(result_data));
     }
  }

//+------------------------------------------------------------------+
//| Checks for various interactions with the Daily Anchor Price      |
//+------------------------------------------------------------------+
void CheckAnchorPriceInteraction(int bar_idx)
  {
   if(g_KeyPrice_At_KeyTime <= 0)
      return; // Can't check if price wasn't set

// Get current closed bar's data (using index 1 for confirmed closed data)
   double close = iClose(_Symbol,_Period,1);
   double prev_close = iClose(_Symbol,_Period,2);
   double high = iHigh(_Symbol,_Period,1);
   double low = iLow(_Symbol,_Period,1);
   double open = iOpen(_Symbol,_Period,1);

// --- Alert Trigger 1: Bar Closes Above or Below the Anchor Price ---
// We only send this alert ONCE, the very first time it happens for the day.
   if(alert_on_close_across_anchor && !g_close_across_alert_sent)
     {
      // Did price just close ABOVE the anchor, when it was below before?
      if(prev_close < g_KeyPrice_At_KeyTime && close > g_KeyPrice_At_KeyTime)
        {
         g_anchor_price_broken = true; // Set flag that price has broken
         g_close_across_alert_sent = true; // Prevent this alert from firing again today
         string desc = _Symbol + ": Closed above Anchor";
         Print(desc);
         DrawAlertSymbol(bar_idx, close, "Close Above", clrDodgerBlue, 241); // Draw a blue up arrow at the close price
         string path = TakeScreenshot();
         if(path != "")
            SendTelegramAlert(desc,path);
         return; // We handled an event, exit for this bar to prevent multiple alerts on same bar
        }
      // Did price just close BELOW the anchor, when it was above before?
      if(prev_close > g_KeyPrice_At_KeyTime && close < g_KeyPrice_At_KeyTime)
        {
         g_anchor_price_broken = true; // Set flag that price has broken
         g_close_across_alert_sent = true; // Prevent this alert from firing again today
         string desc = _Symbol + ": Closed below Anchor";
         Print(desc);
         DrawAlertSymbol(bar_idx, close, "Close Below", clrMediumVioletRed, 242); // Draw a red down arrow
         string path = TakeScreenshot();
         if(path != "")
            SendTelegramAlert(desc,path);
         return; // Exit
        }
     }

// --- Alert Trigger 2: Price Rejects the Anchor Price ---
   if(alert_on_rejection_of_anchor)
     {
      // --- Candle Anatomy & Filtering ---
      double body_size = MathAbs(open - close);
      double total_size = high - low;

      // Filter 1: Minimum Candle Size in Pips
      double pip_value = _Point;
      if(_Digits == 3 || _Digits == 5) pip_value *= 10.0;
      if(total_size < min_candle_size_pips * pip_value)
        {
         // Candle is too small and insignificant, do nothing.
        }
      else
        {
         // Filter 2: ATR Filter (optional)
         bool atr_filter_passed = true; // Assume it passes by default
         if(use_atr_filter)
           {
            // Use the pre-loaded indicator handle
            if(g_atr_handle != INVALID_HANDLE)
              {
               double atr_buffer[1]; // Array to hold the result
               if(CopyBuffer(g_atr_handle, 0, 1, 1, atr_buffer) > 0)
                 {
                  double atr_value = atr_buffer[0];
                  if(total_size < atr_value)
                    {
                     atr_filter_passed = false; // Candle is smaller than recent volatility.
                    }
                 }
               else
                 {
                  Print(visual_comment_text, " - WARNING: Could not copy ATR buffer. ATR filter skipped. Error: ", GetLastError());
                 }
              }
           }

         if(atr_filter_passed)
           {
            // --- Check for High-Quality Bullish Rejection (long lower wick) ---
            bool is_bullish_rejection = (low < g_KeyPrice_At_KeyTime && close > g_KeyPrice_At_KeyTime);
            if(is_bullish_rejection)
              {
               double lower_wick = MathMin(open, close) - low;
               if(body_size > 0 && lower_wick / body_size >= min_wick_to_body_ratio)
                 {
                  // HIGH-QUALITY BULLISH REJECTION FOUND
                  static datetime last_bullish_rejection_alert = 0;
                  if(TimeCurrent() > last_bullish_rejection_alert + 60 * 5) // Cooldown of 5 mins
                    {
                     string desc = "High-Quality Bullish Rejection";
                     Print(_Symbol + " ALERT: " + desc + " of Daily Anchor Price.");
                     DrawAlertSymbol(bar_idx, low, desc, clrLimeGreen, 241);
                     string path = TakeScreenshot();
                     if(path != "") SendTelegramAlert(_Symbol + " ALERT: " + desc + " of Daily Anchor Price (" + DoubleToString(g_KeyPrice_At_KeyTime, _Digits) + ").", path);
                     last_bullish_rejection_alert = TimeCurrent();
                    }
                 }
              }

            // --- Check for High-Quality Bearish Rejection (long upper wick) ---
            bool is_bearish_rejection = (high > g_KeyPrice_At_KeyTime && close < g_KeyPrice_At_KeyTime);
            if(is_bearish_rejection)
              {
               double upper_wick = high - MathMax(open, close);
               if(body_size > 0 && upper_wick / body_size >= min_wick_to_body_ratio)
                 {
                  // HIGH-QUALITY BEARISH REJECTION FOUND
                  static datetime last_bearish_rejection_alert = 0;
                  if(TimeCurrent() > last_bearish_rejection_alert + 60 * 5) // Cooldown of 5 mins
                    {
                     string desc = "High-Quality Bearish Rejection";
                     Print(_Symbol + " ALERT: " + desc + " of Daily Anchor Price.");
                     DrawAlertSymbol(bar_idx, high, desc, clrRed, 242);
                     string path = TakeScreenshot();
                     if(path != "") SendTelegramAlert(_Symbol + " ALERT: " + desc + " of Daily Anchor Price (" + DoubleToString(g_KeyPrice_At_KeyTime, _Digits) + ").", path);
                     last_bearish_rejection_alert = TimeCurrent();
                    }
                 }
              }
           }
        }
     }

// --- Alert Trigger 3: Price Breaks and then Retests the Anchor Price ---
// This requires price to have already broken through (g_anchor_price_broken == true)
   if(alert_on_break_and_retest_of_anchor && g_anchor_price_broken && !g_retest_alert_sent)
     {
      // Look for price to come BACK and touch the anchor line
      bool is_retesting_anchor = (low <= g_KeyPrice_At_KeyTime && high >= g_KeyPrice_At_KeyTime);

      if(is_retesting_anchor)
        {
         // We have a retest of the broken level. Send the alert.
         g_retest_alert_sent = true; // Send this alert only once
         string desc = "Break & Retest";
         Print(_Symbol + " ALERT: " + desc + " of Daily Anchor Price.");
         DrawAlertSymbol(bar_idx, g_KeyPrice_At_KeyTime, desc, clrGold, 159); // Draw a Gold Square at the anchor price
         string path = TakeScreenshot();
         if(path != "")
            SendTelegramAlert(_Symbol + " ALERT: Price is RETESTING the broken Daily Anchor Price level of " + DoubleToString(g_KeyPrice_At_KeyTime,_Digits) + ". Watch for confirmation.",path);
        }
     }
  }

//+------------------------------------------------------------------+
//| VISUALIZATION & UTILITY FUNCTIONS                                |
//+------------------------------------------------------------------+
// --- Draws a symbol and text on the chart to indicate a triggered alert ---
void DrawAlertSymbol(int bar_index, double price, string description, color symbol_color, uint symbol_code)
  {
// Do not draw if visuals are disabled or the on-chart alerts are disabled
   if(!visual_enabled || !visual_on_chart_alerts)
      return;

// Create a unique name for the alert object using its time and description type
   datetime alert_time = iTime(_Symbol, Period(), bar_index);
   string obj_name = "Alert_" + description + "_" + TimeToString(alert_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);

// --- Create the Arrow Symbol ---
   if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, alert_time, price))
     {
      ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, symbol_color);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);

      // --- Create a Corresponding Text Label ---
      string label_name = "AlertLabel_" + description + "_" + TimeToString(alert_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      double label_price = price + 50 * _Point; // Position the text slightly above/below the arrow (adjust as needed)

      if(ObjectCreate(0, label_name, OBJ_TEXT, 0, alert_time, label_price))
        {
         ObjectSetString(0, label_name, OBJPROP_TEXT, description);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, symbol_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM); // Anchor text below the price point
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
        }

      ChartRedraw(0); // Update the chart to show the new alert symbol
     }
  }
