//+------------------------------------------------------------------+
//|                                             SevenOneFourEA_V7.03.mq5 |
//|                                                Developed by [Your Name/Handle] |
//|                                                Based on The 714 Trading Method by Mashaya |
//+------------------------------------------------------------------+
#property version      "7.03"
#property description  "Automated trading system based on the 714 Method. This version includes automatic GMT offset detection and consolidated logic."
#property copyright    "Your Name/Handle"
#property link         ""
#property strict

//--- Include necessary libraries
#include <Trade/Trade.mqh>
#include <Object.mqh>

//--- Structure to store detected Order Blocks details for the day
struct st_OrderBlock
  {
   datetime         startTime;      // Time of the potential OB candle
   double           high;           // High of the potential OB candle
   double           low;            // Low of the potential OB candle
   ENUM_POSITION_TYPE type;         // POSITION_TYPE_BUY for Bullish, POSITION_TYPE_SELL for Bearish
   bool             isMitigated;    // Has price returned to and traded through this OB range?
   string           objectName;     // Name of the rectangle object if drawn
   string           labelName;      // Name of the text label if drawn
  };

//--- Session Times Structure
struct SessionTimes
  {
   datetime         keyTime;
   datetime         observationEnd;
   datetime         morningStart;
   datetime         morningEnd;
   datetime         afternoonStart;
   datetime         afternoonEnd;
   datetime         entrySearchEnd;
  };

//--- Forward Declarations for functions used before their main definition
void           CalculateServerGmtOffset();
datetime       ConvertGMTPlus2ToBrokerTime(int hourGMTPlus2,int minute=0);
void           CalculateAndDrawDailyTimings();
void           RemoveAllVisuals();
void           PlaceBuyOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref);
void           PlaceSellOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref);
void           DetermineInitialBias();
void           ScanForOrderBlocks();
void           CheckForTradeSignal(int bar_idx);
void           UpdateMitigationStatus(int current_closed_bar_index);
void           ManageTrades();
void           DrawOrderBlock(const st_OrderBlock &ob);
void           UpdateOrderBlockVisual(const st_OrderBlock &ob);
bool           YourBuyEntryConditionsMet(int closed_bar_index);
bool           YourSellEntryConditionsMet(int closed_bar_index);
bool           IsBullishOrderBlockCandidate(int bar_idx, const MqlRates &rates[]);
bool           IsBearishOrderBlockCandidate(int bar_idx, const MqlRates &rates[]);
void           GetAndDrawKeyPrice(datetime startTime, datetime endTime, double &keyPriceVariable, bool &isObtainedFlag, string zoneName, color lineColor);
SessionTimes   GetTodaySessionTimes();
void           DrawTimeLine(datetime time,string text,color clr,ENUM_LINE_STYLE style=STYLE_SOLID,int width=1);
void           DrawTimeZone(datetime startTime,datetime endTime,string text,color clr);
double         CalculateLotSize(double risk_perc,double entry_price,double stop_loss_price);


//+------------------------------------------------------------------+
//| Input Parameters
//+------------------------------------------------------------------+
//--- Primary Key Time Settings (UTC+2)
input group    "=== Primary Key Time Settings (UTC+2) ===";
input int      utcPlus2_KeyHour_1300     = 13;     // Key Hour (13:00 UTC+2)
input int      utcPlus2_KeyMinute_1300   = 0;      // Key Minute

//--- Observation and Entry Settings
input group    "=== Observation and Entry Settings ===";
input int      observation_Duration_Minutes= 60;   // Minutes to observe price action after Key Time
input int      entry_Candlestick_Index   = 15;     // M5 candle index for entry (15 = 75 mins after Key Time)
input bool     use_entry_search_window   = true;   // Enable to limit entry search to a specific window
input int      entry_search_end_hour_utc2= 17;     // Hour (UTC+2) to stop searching for new entries
input int      entry_search_end_minute_utc2= 0;      // Minute to stop searching for new entries
input int      session_End_UTC2_Hour     = 22;     // Session end hour UTC+2 (22 = 10:00 PM)
input int      session_End_UTC2_Minute   = 0;      // Session end minute UTC+2

//--- Additional Time Zones (UTC+2)
input group    "--- Additional Time Zones (UTC+2) ---";
input bool     enable_morning_zone          = true;
input int      morning_zone_start_hour_utc2 = 7;
input int      morning_zone_end_hour_utc2   = 8;
input color    morning_zone_color           = C'25,50,75';
input bool     enable_afternoon_zone        = true;
input int      afternoon_zone_start_hour_utc2 = 16;
input int      afternoon_zone_end_hour_utc2   = 17;
input color    afternoon_zone_color         = C'135,50,0';


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
input bool     visual_order_blocks       = true;   // Show detected Order Blocks
input bool     visual_obs_price_line     = true;   // Show price level during observation

//--- Visual Colors
input group    "--- Visual Colors ---";
input color    vline_keytime_color       = clrSteelBlue;
input color    vline_obsend_color        = clrSalmon;
input color    ob_bullish_color          = clrLimeGreen;
input color    ob_bearish_color          = clrRed;
input color    ob_mitigated_color        = clrGray;
input color    ob_label_color            = clrBlack;
input color    obs_price_line_color      = clrDarkGray;

//--- Trade Management Settings
input group "=== Trade Management Settings ===";
input long     magic_Number              = 71403;  // Unique identifier for EA trades
input double   risk_Percent_Placeholder  = 1.0;    // Risk % per trade (0.1-5.0 recommended)
input double   stop_Loss_Buffer_Pips     = 5.0;    // Buffer added to OB High/Low for SL
input int      take_Profit_Pips_Placeholder = 50;  // Take Profit distance in pips


//--- Global Variables ---
CTrade     trade;
string     visual_comment_text = "714EA_v7.03"; // Prefix for chart comments/objects

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
bool       g_order_blocks_scanned_today    = false;
datetime   g_last_processed_bar_time_OnTimer = 0;
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
//--- Basic Setup
   ChartSetInteger(0,CHART_SHOW_PERIOD_SEP,true);
   trade.SetExpertMagicNumber(magic_Number);
   trade.SetDeviationInPoints(10);

//--- Check for valid timeframe
   if(Period() != PERIOD_M5 && Period() != PERIOD_M15)
     {
      Print("ERROR: This EA requires the M5 or M15 timeframe.");
      return(INIT_FAILED);
     }

//--- Initialize time settings
   CalculateServerGmtOffset();
   CalculateAndDrawDailyTimings();

//--- Start a timer for periodic checks
   EventSetTimer(5); // Check every 5 seconds

   Print(visual_comment_text," initialized successfully on ",_Symbol," ",EnumToString(Period()));
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   RemoveAllVisuals();
   Print(visual_comment_text," deinitialized. Reason code: ",reason);
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
         DrawTimeZone(times.morningStart,times.morningEnd,"Morning Zone",morning_zone_color);
      if(enable_afternoon_zone)
         DrawTimeZone(times.afternoonStart,times.afternoonEnd,"Afternoon Zone",afternoon_zone_color);
     }

   // Reset daily state flags
   g_last_initialized_day_time           = iTime(_Symbol,PERIOD_D1,0);
   g_bullishOB_count                     = 0;
   g_bearishOB_count                     = 0;
   g_bias_determined_today               = false;
   g_order_blocks_scanned_today          = false;
   g_key_price_obtained_today            = false;
   g_MorningZone_KeyPrice_Obtained_Today = false;
   g_AfternoonZone_KeyPrice_Obtained_Today = false;
   
   Print(visual_comment_text, " - Daily timings reset and calculated for ", TimeToString(g_last_initialized_day_time, TIME_DATE));
  }

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
   return times;
  }

void CalculateServerGmtOffset()
{
   long offset_sec = TimeTradeServer() - TimeGMT();
   g_server_gmt_offset_hours = (int)(offset_sec / 3600);
   PrintFormat("%s - Server time is %s, GMT is %s. Auto-detected Server GMT Offset: %+d hours.",
               visual_comment_text,
               TimeToString(TimeTradeServer()),
               TimeToString(TimeGMT()),
               g_server_gmt_offset_hours);
}

datetime ConvertGMTPlus2ToBrokerTime(int hourGMTPlus2, int minute = 0)
{
    MqlDateTime ts;
    TimeToStruct(TimeTradeServer(), ts);
    ts.hour=0; ts.min=0; ts.sec=0;
    datetime server_midnight = StructToTime(ts);
    
    // Convert input time from UTC+2 to seconds from midnight GMT
    long gmt_seconds = (long)(hourGMTPlus2 - 2) * 3600 + (long)minute * 60;
    
    // Add broker's GMT offset to find the target time in broker's timezone
    datetime broker_time = server_midnight + gmt_seconds + (g_server_gmt_offset_hours * 3600);
    
    return broker_time;
}


//+------------------------------------------------------------------+
//| CORE STRATEGY LOGIC FUNCTIONS                                    |
//+------------------------------------------------------------------+
void GetAndDrawKeyPrice(datetime startTime, datetime endTime, double &keyPriceVariable, bool &isObtainedFlag, string zoneName, color lineColor)
{
    if (isObtainedFlag || !visual_enabled || !visual_obs_price_line) return;

    int barIndex = iBarShift(_Symbol, _Period, startTime, false);
    if (barIndex < 0) return;

    keyPriceVariable = iOpen(_Symbol, _Period, barIndex);
    if (keyPriceVariable > 0)
    {
        isObtainedFlag = true;
        Print(visual_comment_text, " - ", zoneName, " Key Price obtained: ", DoubleToString(keyPriceVariable, _Digits));
        string lineName = "KeyPrice_" + zoneName + "_" + TimeToString(startTime, TIME_DATE);
        ObjectDelete(0, lineName);
        if (ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, keyPriceVariable, endTime, keyPriceVariable))
        {
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
        }
    }
}

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
   else if(price_at_obs_end < price_at_keytime)
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
  
void ScanForOrderBlocks()
  {
   if(g_order_blocks_scanned_today) return;

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

void CheckForTradeSignal(int bar_idx)
{
    // Ensure no position is already open
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(PositionGetInteger(POSITION_MAGIC) == magic_Number && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            return; // Exit if a trade by this EA on this symbol exists
        }
    }

    g_trade_signal_this_bar = false;
    bool conditions_met = false;

    if (g_InitialBias == -1) // Bias is Bearish, look for BUYS
    {
        conditions_met = YourBuyEntryConditionsMet(bar_idx);
        if (conditions_met)
        {
            Print(visual_comment_text, " - BUY Signal Triggered by OB at ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
            PlaceBuyOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, bar_idx, g_triggered_ob_for_trade);
        }
    }
    else if (g_InitialBias == 1) // Bias is Bullish, look for SELLS
    {
        conditions_met = YourSellEntryConditionsMet(bar_idx);
        if (conditions_met)
        {
            Print(visual_comment_text, " - SELL Signal Triggered by OB at ", TimeToString(g_triggered_ob_for_trade.startTime, TIME_DATE|TIME_MINUTES));
            PlaceSellOrder(risk_Percent_Placeholder, stop_Loss_Buffer_Pips, take_Profit_Pips_Placeholder, bar_idx, g_triggered_ob_for_trade);
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
   if(scan_oldest_chart_idx >= total_bars) scan_oldest_chart_idx = total_bars - 1;

   int bars_to_copy = scan_oldest_chart_idx + 1;
   if(bars_to_copy <= 0) return;
   
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
            st_OrderBlock &ob = g_bullishOrderBlocks[g_bullishOB_count];
            ob.startTime    = rates[i].time;
            ob.high         = rates[i].high;
            ob.low          = rates[i].low;
            ob.type         = POSITION_TYPE_BUY;
            ob.isMitigated  = false;
            string obj_name_part = TimeToString(ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_B" + (string)i;
            ob.objectName   = "BullOB_" + obj_name_part;
            ob.labelName    = "Lbl_BullOB_" + obj_name_part;
            
            Print(visual_comment_text," - Found Bullish OB at ",TimeToString(ob.startTime, TIME_DATE|TIME_SECONDS));
            if(visual_enabled && visual_order_blocks) DrawOrderBlock(ob);

            g_bullishOB_count++;
           }
        }
      else if(IsBearishOrderBlockCandidate(i, rates))
        {
         if(g_bearishOB_count < ArraySize(g_bearishOrderBlocks))
           {
            st_OrderBlock &ob = g_bearishOrderBlocks[g_bearishOB_count];
            ob.startTime    = rates[i].time;
            ob.high         = rates[i].high;
            ob.low          = rates[i].low;
            ob.type         = POSITION_TYPE_SELL;
            ob.isMitigated  = false;
            string obj_name_part = TimeToString(ob.startTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "_S" + (string)i;
            ob.objectName   = "BearOB_" + obj_name_part;
            ob.labelName    = "Lbl_BearOB_" + obj_name_part;
           
            Print(visual_comment_text," - Found Bearish OB at ",TimeToString(ob.startTime, TIME_DATE|TIME_SECONDS));
            if(visual_enabled && visual_order_blocks) DrawOrderBlock(ob);
            
            g_bearishOB_count++;
           }
        }
     }
   Print(visual_comment_text, " - OB scan finished. Bullish: ", g_bullishOB_count, ", Bearish: ", g_bearishOB_count);
   ChartRedraw();
  }

bool IsBullishOrderBlockCandidate(int bar_idx, const MqlRates &rates[])
  {
   if(bar_idx + ob_Lookback_Bars_For_Impulse >= ArraySize(rates)) return false; // Ensure enough data
   
   // 1. Candidate candle must be bearish.
   if(rates[bar_idx].close >= rates[bar_idx].open) return false;

   // 2. Check for bullish impulse move afterwards.
   double move_pips = 0;
   int impulse_end_idx = -1;
   for(int i = bar_idx - 1; i >= bar_idx - ob_Lookback_Bars_For_Impulse && i >= 0; i--)
     {
      // The move must break the high of the candidate candle.
      if(rates[i].high > rates[bar_idx].high)
        {
         move_pips = (rates[i].high - rates[bar_idx].high) / _Point;
         if(_Digits == 3 || _Digits == 5) move_pips /= 10.0;
         impulse_end_idx = i;
         break;
        }
     }
   if(move_pips < ob_MinMovePips) return false;
   
   // 3. Check that candles between the OB and the impulse break do not take the low of the OB.
   for(int i = bar_idx - 1; i > impulse_end_idx; i--)
     {
      if(rates[i].low < rates[bar_idx].low) return false;
     }

   return true;
  }

bool IsBearishOrderBlockCandidate(int bar_idx, const MqlRates &rates[])
  {
   if(bar_idx + ob_Lookback_Bars_For_Impulse >= ArraySize(rates)) return false; // Ensure enough data

   // 1. Candidate candle must be bullish.
   if(rates[bar_idx].close <= rates[bar_idx].open) return false;

   // 2. Check for bearish impulse move afterwards.
   double move_pips = 0;
   int impulse_end_idx = -1;
   for(int i = bar_idx - 1; i >= bar_idx - ob_Lookback_Bars_For_Impulse && i >= 0; i--)
     {
      // The move must break the low of the candidate candle.
      if(rates[i].low < rates[bar_idx].low)
        {
         move_pips = (rates[bar_idx].low - rates[i].low) / _Point;
         if(_Digits == 3 || _Digits == 5) move_pips /= 10.0;
         impulse_end_idx = i;
         break;
        }
     }
   if(move_pips < ob_MinMovePips) return false;
   
   // 3. Check that candles between the OB and the impulse break do not take the high of the OB.
   for(int i = bar_idx - 1; i > impulse_end_idx; i--)
     {
      if(rates[i].high > rates[bar_idx].high) return false;
     }
     
   return true;
  }

void UpdateMitigationStatus(int current_closed_bar_index)
  {
   if(g_bullishOB_count == 0 && g_bearishOB_count == 0) return;

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
            if(visual_enabled && visual_order_blocks) UpdateOrderBlockVisual(g_bullishOrderBlocks[i]);
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
            if(visual_enabled && visual_order_blocks) UpdateOrderBlockVisual(g_bearishOrderBlocks[i]);
           }
        }
     }
  }

bool YourBuyEntryConditionsMet(int closed_bar_index)
  {
   if(g_InitialBias != -1) return false; // We need a bearish bias to look for buys

   double current_high = iHigh(_Symbol, _Period, closed_bar_index);
   double current_low  = iLow(_Symbol, _Period, closed_bar_index);
   datetime current_time = iTime(_Symbol, _Period, closed_bar_index);

   for(int i = g_bullishOB_count - 1; i >= 0; i--)
     {
      st_OrderBlock &ob = g_bullishOrderBlocks[i];
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

bool YourSellEntryConditionsMet(int closed_bar_index)
  {
   if(g_InitialBias != 1) return false; // We need a bullish bias to look for sells

   double current_high = iHigh(_Symbol, _Period, closed_bar_index);
   double current_low  = iLow(_Symbol, _Period, closed_bar_index);
   datetime current_time = iTime(_Symbol, _Period, closed_bar_index);

   for(int i = g_bearishOB_count - 1; i >= 0; i--)
     {
      st_OrderBlock &ob = g_bearishOrderBlocks[i];
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
   double sl_price      = triggered_ob_ref.low - (sl_buffer_pips_input * _Point);
   double tp_price      = entry_price + (tp_pips_placeholder_input * _Point * (_Digits == 3 || _Digits == 5 ? 10 : 1));
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

void PlaceSellOrder(double risk_perc,double sl_buffer_pips_input,double tp_pips_placeholder_input,int bar_index,const st_OrderBlock &triggered_ob_ref)
  {
   double entry_price = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl_price    = triggered_ob_ref.high + (sl_buffer_pips_input * _Point);
   double tp_price    = entry_price - (tp_pips_placeholder_input * _Point * (_Digits == 3 || _Digits == 5 ? 10 : 1));
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

double CalculateLotSize(double risk_perc,double entry_price,double stop_loss_price)
  {
   if(risk_perc <= 0) return 0.0;
   double account_balance = AccountInfoDouble(ACCOUNT_EQUITY);
   if(account_balance <= 0) return 0.0;
   
   double risk_amount = account_balance * (risk_perc / 100.0);
   double sl_distance = MathAbs(entry_price - stop_loss_price);

   if (sl_distance < SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point)
     {
       Print(visual_comment_text, " - SL distance is too small. Cannot calculate lot size.");
       return 0.0;
     }

   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_size <= 0) return 0.0;

   double loss_per_lot = (sl_distance / tick_size) * tick_value;
   if(loss_per_lot <= 0) return 0.0;
   
   double volume = risk_amount / loss_per_lot;
   
   //--- Normalize and check against limits
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   volume = MathFloor(volume / volume_step) * volume_step;
   
   if(volume < min_volume) {
      Print(visual_comment_text, " - Calculated lot size ", DoubleToString(volume,2), " is below minimum. Cannot place trade with this risk.");
      return 0.0;
   }
   
   volume = MathMin(volume, max_volume);
   
   return(NormalizeDouble(volume, 2));
  }

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
void DrawTimeLine(datetime time,string text,color clr,ENUM_LINE_STYLE style=STYLE_SOLID,int width=1)
  {
   if(!visual_enabled) return;
   string name = "TimeLine_" + text + "_" + TimeToString(time,TIME_DATE);
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

void DrawTimeZone(datetime startTime,datetime endTime,string text,color clr)
  {
   if(!visual_enabled) return;
   string name = "Zone_" + text + "_" + TimeToString(startTime,TIME_DATE);
   ObjectDelete(0,name);
   if(ObjectCreate(0,name,OBJ_RECTANGLE,0,startTime,ChartGetDouble(0,CHART_PRICE_MAX,0),endTime,ChartGetDouble(0,CHART_PRICE_MIN,0)))
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
     }
  }

void DrawOrderBlock(const st_OrderBlock &ob)
  {
   if(!visual_enabled || !visual_order_blocks) return;
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

void UpdateOrderBlockVisual(const st_OrderBlock &ob)
{
    if (!visual_enabled || !visual_order_blocks) return;
    if (ObjectFind(0, ob.objectName) < 0) return; // Object not found

    ObjectSetInteger(0, ob.objectName, OBJPROP_COLOR, ob_mitigated_color);
    if (ObjectFind(0, ob.labelName) >= 0)
    {
        string newText = (ob.type == POSITION_TYPE_BUY ? "Bull" : "Bear") + string(" OB Mitigated");
        ObjectSetString(0, ob.labelName, OBJPROP_TEXT, newText);
        ObjectSetInteger(0, ob.labelName, OBJPROP_COLOR, clrGray);
    }
}
void RemoveAllVisuals()
  {
   ObjectsDeleteAll(0,0,-1); // Deletes all objects on the chart
   ChartRedraw();
  }
//+------------------------------------------------------------------+
