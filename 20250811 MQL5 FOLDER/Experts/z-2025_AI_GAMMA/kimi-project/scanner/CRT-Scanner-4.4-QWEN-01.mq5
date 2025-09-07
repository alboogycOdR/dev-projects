//+------------------------------------------------------------------+
//| CRT-Scanner-4.4-QWEN-01.mq5 – MQL5 Compliant Version             |
//+------------------------------------------------------------------+

#include "crt_core2.mqh"
/*Changes :

Added configurable timeframes
Exposed Use_EntryConfirmation
Enforced repainting prevention*/
//+------------------------------------------------------------------+
//| CRT-Scanner.mq5                                                 |
//+------------------------------------------------------------------+
#property strict


//--- INPUT PARAMETERS -----------------------------------------------
enum ENUM_SYMBOL_SOURCE
  {
   CSV,              // Symbols from CSV list
   MARKET_WATCH      // Symbols from Market Watch
  };

input ENUM_SYMBOL_SOURCE SymbolSource = CSV; // Symbol source selection
input string Symbols_CSV = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,EURCHF,EURAUD,GBPJPY,GBPCHF,AUDJPY,CHFJPY,CADJPY";

input int    UpdateSec = 600;//PollingPeriod
 
input group "Alerts"
input bool   Alert_Bias = true;
input bool   Alert_Entry = true;
string TelegramToken = "7388905164:AAF9DeExI0Jb5qAzDV16mlAhYOyMwo4EqbA";
string TelegramChatID = "880001908";



//--- CONFIGURABLE INPUTS -------------------------------------------
input ENUM_TIMEFRAMES H4_Timeframe = PERIOD_H4;
input ENUM_TIMEFRAMES M15_Timeframe = PERIOD_M15;
input int             FVG_CheckRange = 25;
input bool            Use_EntryConfirmation = true;

//--- GLOBALS ------------------------------------------------------
string    symbols[];
CRT_State states[];
int       total_symbols = 0;
datetime  last_day = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
    // Check for Telegram credentials if alerts are enabled
   if(Alert_Bias || Alert_Entry)
     {
      if(TelegramToken == "" || TelegramChatID == "")
        {
         Print("Warning: Telegram alerts are enabled, but the Telegram Token or Chat ID is missing. Notifications will not be sent.");
        }
     }

   if(SymbolSource == CSV)
     {
      total_symbols = StringSplit(Symbols_CSV, ',', symbols);
     }
   else // MARKET_WATCH
     {
      total_symbols = SymbolsTotal(true);
      ArrayResize(symbols, total_symbols);
      for(int i = 0; i < total_symbols; i++)
        {
         symbols[i] = SymbolName(i, true);
        }
     }

   ArrayResize(states, total_symbols);

   for(int i = 0; i < total_symbols; i++)
     {
      if(!SymbolSelect(symbols[i], true))
         continue;
      ResetState(states[i], symbols[i]);
     }

   Print("CRT Scanner initialized with ", total_symbols, " symbols. Monitoring for setups...");

   EventSetTimer(UpdateSec);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);
   if(last_day != t.day_of_year)
     {
      last_day = t.day_of_year;
      for(int i = 0; i < total_symbols; i++) ResetState(states[i], symbols[i]);
     }

   for(int i = 0; i < total_symbols; i++)
     {
      ENUM_BIAS prev_bias = states[i].bias;
      datetime range_time, sweep_time;
      states[i].bias = CRT_Bias(states[i].symbol, range_time, sweep_time, states[i].crt_high, states[i].crt_low);
      //---
      Print(states[i].symbol + " with bias:" + EnumToString(states[i].bias) +
            " | Range Candle: " + TimeToString(range_time) +
            " | Sweep Candle: " + TimeToString(sweep_time));
      //---
      if(Alert_Bias && prev_bias != NEUTRAL && states[i].bias != prev_bias)
        {
         string bias_emoji = (states[i].bias == BULLISH) ? "📈" : "📉";
         string message = bias_emoji + " CRT-BIAS: " + states[i].symbol + " → " + EnumToString(states[i].bias);
         Telegram_Send(TelegramToken, TelegramChatID, message);
         Print("CRT-BIAS: "+states[i].symbol+" → "+EnumToString(states[i].bias));
        }
      //---

      if(states[i].bias != NEUTRAL)
        {
           // The M15_Step function orchestrates the core trade entry logic by managing a state machine
           // for both bullish and bearish scenarios. It transitions through the following stages:
           // 1. SWEEP: Identifies a liquidity sweep below a recent low (for bullish bias) or above a
           //    recent high (for bearish bias).
           // 2. MSS (Market Structure Shift): 
           //    Confirms a change in market structure after the sweep.
           // 3. FVG (Fair Value Gap): 
           //    Detects a price imbalance (FVG) that serves as a potential entry zone.
           // 4. ENTRY: 
           //    Triggers an entry signal when the price interacts with the FVG, optionally
           //    requiring an engulfing candle pattern for confirmation.

           M15_Step(states[i], H4_Timeframe, M15_Timeframe, FVG_CheckRange, Use_EntryConfirmation);

            // --- Debugging Output ---
            string state_str = "IDLE";
            if(states[i].bias == BULLISH)
              {
               state_str = EnumToString(states[i].bull_state);
              }
            else if(states[i].bias == BEARISH)
              {
               state_str = EnumToString(states[i].bear_state);
              }
            PrintFormat("[     LOWER TF STATE:]: %s | %s | %s", states[i].symbol, EnumToString(states[i].bias), state_str);
            // --- End Debugging ---


           if(states[i].bias == BULLISH && states[i].bull_state == ENTRY ||
            states[i].bias == BEARISH && states[i].bear_state == ENTRY)
           {
            string entry_emoji = (states[i].bias == BULLISH) ? "🐂" : "🐻";
            string message = entry_emoji + " CRT-ENTRY: " + states[i].symbol + " " +
                             EnumToString(states[i].bias) + " | FVG: " +
                             DoubleToString(states[i].fvg_low, 5) + "-" + DoubleToString(states[i].fvg_high, 5);
            Telegram_Send(TelegramToken, TelegramChatID, message);
            Print("CRT-ENTRY: "+states[i].symbol+" → "+EnumToString(states[i].bias));

           }
           
        }
        
     }
      Print("================");
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
