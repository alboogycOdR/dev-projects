//+------------------------------------------------------------------+
//| CRT-Scanner-4.4-final.mq5  – multi symbol, 2-bar bias, Telegram  |
//+------------------------------------------------------------------+
/*
    VERSION HISTORY / CHANGELOG

    Update: Dynamic CRT Range Integration
    - WHY: To align with the core logic update, the scanner must use the dynamically-determined range from the H4 bias candle instead of a fixed H1 candle.
    - WHAT:
        - The call to `CRT_Bias` was updated to receive the `crt_high` and `crt_low` of the true range candle.
        - The redundant `CRT_Range()` function call was removed.
        - The M15 state machine (`M15_Step`) now begins monitoring immediately after a valid bias is formed, using the correct price levels.
*/

/*
Bias Calculation (CRT_Bias): This function determines the initial market bias based on the last two closed H4 candles.
It retrieves H4 data (CopyRates).
Identifies the "range" candle (second last closed) and the "sweep" candle (last closed).
Bullish Bias: Sweep candle's low is below the range candle's low, and the sweep candle's close is at or above the range candle's low.
Bearish Bias: Sweep candle's high is above the range candle's high, and the sweep candle's close is at or below the range candle's high.
Returns the determined ENUM_BIAS and outputs the range/sweep candle times and the range candle's high/low (stored in crt_high/crt_low).
State Machine (M15_Step): This function progresses the setup state for a given symbol based on M15 candle data, but only if a BULLISH or BEARISH bias is already established .
Retrieves M15 data.
For Bullish Bias:
IDLE: Waits for the latest M15 low to break below crt_low. Sets mss_level to that M15 low and transitions to SWEEP.
SWEEP: Waits for the latest M15 high to break above mss_level. Transitions to MSS.
MSS: Looks back through M15 candles (up to 25) to find a Bullish FVG (gap where m15[i-2].high < m15[i].low). Sets FVG levels and transitions to FVG.
FVG: Waits for the latest M15 low to break below the FVG's high (fvg_high). Transitions to ENTRY.
For Bearish Bias: Logic is mirrored (using highs/lows appropriately).
Uses Print statements for debugging state transitions.
-----
Key Observations and Considerations:

Bias Logic: The two-bar H4 bias relies on a specific close relative to the range candle's body/low/high. This is a clear, rule-based approach.
State Machine Trigger: The M15 state machine (M15_Step) only activates after a BULLISH or BEARISH bias is detected by CRT_Bias. This ensures the subsequent steps are contextually relevant.
FVG Detection: The loop in the MSS state (for(int i=2; i<ArraySize(m15); i++)) scans the last 25 M15 candles to find any qualifying FVG. This means it might pick up an older FVG rather than the most recent one after the MSS state was entered, depending on how the loop executes and the exact conditions. The break ensures it stops at the first one found (which, due to ArraySetAsSeries, is the oldest among the checked ones). This is a potential point of logic clarification or refinement. You might want it to look for the first FVG after the MSS condition was met, which would require storing the time of entering MSS and checking M15 bars formed after that time.
Timing:
The system relies on closed H4 candles for bias, ensuring the signal is based on confirmed price action.
The M15 state machine runs on timer updates (UpdateSec, default 180 seconds = 3 minutes). This means state transitions depend on when the timer fires relative to M15 bar closes.
The daily reset (Reset) ensures the system starts fresh each day, clearing old states.
Telegram Alerts: Core functionality is implemented using WebRequest. Ensure the platform's Allow WebRequest settings include https://api.telegram.org.
GMT Offset Input: Interestingly, the CRT_Hour and Broker_GMT_Offset inputs are defined but not actively used in the provided OnTimer logic for filtering checks to specific hours. The system runs continuously based on the timer. These might be remnants or intended for future use or a different version.
CRT-Trader-5.0-final.mq5: The content provided for this file is identical to CRT-Scanner-4.4-final.mq5. Based on the filename, one might expect actual trading logic here, but none is present in the provided code. It functions solely as the scanner.
Error Handling: Basic error checking exists in CRT_Bias (checking CopyRates return) and Telegram_Send (checking WebRequest return and HTTP status). More robust error handling could be added throughout.
*/
#property copyright "CRT-Scanner-4.4-final"
#property version   "4.40"
#property description "Multi-symbol CRT scanner – no trades, only alerts"

#include <Trade\Trade.mqh>
#include "CRT_Core.mqh"

//--- INPUTS ---------------------------------------------------------
input string Symbols_CSV = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURAUD,GBPJPY,GBPCHF,AUDJPY,CHFJPY,CADJPY";
input int    CRT_Hour=8;
input int    Broker_GMT_Offset=3;
input int    UpdateSec=180;
//input string TelegramToken="";   // fill in
//input string TelegramChatID="";  // fill in
input string                                   TelegramChatID="880001908";//TELEGRAM CHAT ID
input string                                TelegramToken="7388905164:AAF9DeExI0Jb5qAzDV16mlAhYOyMwo4EqbA";//TELEGRAM TOKEN

input bool   Alert_Bias=true;
input bool   Alert_Entry=true;

//--- GLOBALS --------------------------------------------------------
string    symbols[];
CRT_State state[];
int       total_symbols = 0;
datetime  last_day=0;

//+------------------------------------------------------------------+
int OnInit()
  {
   total_symbols = StringSplit(Symbols_CSV, ',', symbols);
   ArrayResize(state, total_symbols);
   Reset();

   EventSetTimer(UpdateSec);
   return INIT_SUCCEEDED;
  }
void OnDeinit(const int r) { EventKillTimer(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   Print(__FUNCTION__);
   datetime now=TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now,t);
   if(last_day!=t.day_of_year)
     {
      last_day=t.day_of_year;
      Reset();
     }
   Print("--------------LOG------------------------------");
   for(int i=0;i<total_symbols;i++)
     {
      string s=      symbols[i];
      ENUM_BIAS prev=state[i].bias;
      datetime range_time, sweep_time;
      state[i].bias= CRT_Bias(s, range_time, sweep_time, state[i].crt_high, state[i].crt_low);
      
      Print(s+" with bias:"+EnumToString(state[i].bias) +
            " | Range Candle: " + TimeToString(range_time) +
            " | Sweep Candle: " + TimeToString(sweep_time));

      if(Alert_Bias && prev!=NEUTRAL && state[i].bias!=prev)
        {
         string bias_emoji = (state[i].bias == BULLISH) ? "📈" : (state[i].bias == BEARISH) ? "📉" : "📊";
         string message = bias_emoji + " CRT-BIAS: " + s + " → " + EnumToString(state[i].bias);
         Telegram_Send(TelegramToken, TelegramChatID, message);
         Print("CRT-BIAS: "+s+" → "+EnumToString(state[i].bias));
        }

      if(state[i].bias!=NEUTRAL)
        {
         ENUM_SETUP_STATE prevState = (state[i].bias==BULLISH)?state[i].bull_state:state[i].bear_state;
         M15_Step(state[i]);
         ENUM_SETUP_STATE newState  = (state[i].bias==BULLISH)?state[i].bull_state:state[i].bear_state;
         if(Alert_Entry && newState==ENTRY && prevState!=ENTRY)
           {
            string entry_emoji = (state[i].bias == BULLISH) ? "🐂" : "🐻";
            string message = entry_emoji + " CRT-ENTRY: " + s + " " + EnumToString(state[i].bias) + " | FVG: " + DoubleToString(state[i].fvg_low, 5) + "-" + DoubleToString(state[i].fvg_high, 5) + " | Bid: " + DoubleToString(SymbolInfoDouble(s, SYMBOL_BID), 5);
            Telegram_Send(TelegramToken, TelegramChatID, message);
            Print("CRT-ENTRY: "+s+" → "+EnumToString(state[i].bias));
           }
        }
     }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Reset()
  {
   for(int i=0;i<total_symbols;i++)
     {
      ResetState(state[i], symbols[i]);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
