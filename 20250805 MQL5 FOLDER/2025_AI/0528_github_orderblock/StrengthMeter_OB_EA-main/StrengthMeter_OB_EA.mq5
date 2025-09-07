//+------------------------------------------------------------------+
//|                                        StrengthMeter_OB_EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Strength Meter + Order Block EA with Dashboard"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Input parameters
input group "=== TRADING SETTINGS ==="
input double   RiskPercent = 1.0;           // Risk per trade (% of balance)
input double   RiskReward = 2.0;            // Risk to Reward ratio
input int      StopLossPips = 10;           // Stop Loss in pips beyond OB
input int      MaxTradesPerPair = 2;        // Max trades per pair per day
input bool     AutoTradingInput = true;     // Auto Trading ON/OFF (initial setting)

input group "=== STRENGTH METER SETTINGS ==="
input double   MinStrengthDiff = 5.0;       // Minimum strength difference
input int      StrengthPeriod = 14;         // Period for strength calculation

input group "=== ORDER BLOCK SETTINGS ==="
input int      OB_LookbackBars = 50;        // Lookback bars for OB detection
input int      BOS_LookbackBars = 20;       // Lookback bars for BOS detection
input double   OB_MinSize = 10.0;           // Minimum OB size in pips

input group "=== DASHBOARD SETTINGS ==="
input int      DashboardX = 20;             // Dashboard X position
input int      DashboardY = 50;             // Dashboard Y position
input color    PanelColor = clrDarkSlateGray; // Panel background color
input color    TextColor = clrWhite;        // Text color

//--- Global variables
CTrade trade;
CPositionInfo position;
COrderInfo order;

// Runtime variables (can be modified)
bool AutoTrading = true;                     // Current auto trading state

string Symbols[] = {"XAUUSD.iux", "EURUSD.iux", "GBPUSD.iux", "USDJPY.iux", "GBPJPY.iux", "EURJPY.iux", "NAS100.iux", "US30.iux"};

// Updated symbol list with .iux suffix for this broker
string AllPairs[] = {"EURUSD.iux", "GBPUSD.iux", "USDCHF.iux", "USDJPY.iux", "USDCAD.iux", "AUDUSD.iux", "NZDUSD.iux",
                     "EURGBP.iux", "EURJPY.iux", "EURCHF.iux", "EURCAD.iux", "EURAUD.iux", "EURNZD.iux",
                     "GBPJPY.iux", "GBPCHF.iux", "GBPCAD.iux", "GBPAUD.iux", "GBPNZD.iux",
                     "CHFJPY.iux", "CADJPY.iux", "AUDJPY.iux", "NZDJPY.iux",
                     "AUDCAD.iux", "AUDCHF.iux", "AUDNZD.iux",
                     "CADCHF.iux", "NZDCAD.iux", "NZDCHF.iux",
                     // Alternative naming conventions
                     "EURUSDm", "GBPUSDm", "USDCHFm", "USDJPYm", "USDCADm", "AUDUSDm", "NZDUSDm",
                     "EURGBPm", "EURJPYm", "EURCHFm", "EURCADm", "EURAUDm", "EURNZDm",
                     "GBPJPYm", "GBPCHFm", "GBPCADm", "GBPAUDm", "GBPNZDm",
                     "CHFJPYm", "CADJPYm", "AUDJPYm", "NZDJPYm",
                     "AUDCADm", "AUDCHFm", "AUDNZDm",
                     "CADCHFm", "NZDCADm", "NZDCHFm"};

// Available symbols for strength calculation
string AvailableSymbols[];
int AvailableSymbolsCount = 0;

struct StrengthData
{
   double USD, EUR, GBP, JPY, CHF, CAD, AUD, NZD;
};

struct OrderBlock
{
   double high;
   double low;
   datetime time;
   bool is_bullish;
   bool valid;
};

struct TradeSignal
{
   string symbol;
   int signal_type; // 1 = BUY, -1 = SELL, 0 = NONE
   double entry_price;
   double stop_loss;
   double take_profit;
   string reason;
};

StrengthData CurrentStrength;
OrderBlock OBData[];
TradeSignal Signals[];
int DailyTrades[][2]; // [symbol_index][0=buys, 1=sells]

//--- Dashboard objects
string PanelName = "StrengthOB_Panel";
string ButtonAutoTrade = "AutoTradeBtn";
string ButtonExportLogs = "ExportLogsBtn";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize runtime variables from inputs
   AutoTrading = AutoTradingInput;
   
   //--- Detect available symbols
   DetectAvailableSymbols();
   
   //--- Initialize arrays
   ArrayResize(OBData, ArraySize(Symbols));
   ArrayResize(Signals, ArraySize(Symbols));
   ArrayResize(DailyTrades, ArraySize(Symbols));
   
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      DailyTrades[i][0] = 0;
      DailyTrades[i][1] = 0;
   }
   
   //--- Create dashboard
   CreateDashboard();
   
   //--- Set timer for updates
   EventSetTimer(1);
   
   Print("Strength Meter + OB EA initialized successfully");
   Print("Available symbols for strength calculation: ", AvailableSymbolsCount);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Detect available symbols for strength calculation               |
//+------------------------------------------------------------------+
void DetectAvailableSymbols()
{
   ArrayResize(AvailableSymbols, ArraySize(AllPairs));
   AvailableSymbolsCount = 0;
   
   for(int i = 0; i < ArraySize(AllPairs); i++)
   {
      string symbol = AllPairs[i];
      
      // Try to select the symbol
      if(SymbolSelect(symbol, true))
      {
         // Check if symbol has data
         if(SymbolInfoDouble(symbol, SYMBOL_BID) > 0)
         {
            AvailableSymbols[AvailableSymbolsCount] = symbol;
            AvailableSymbolsCount++;
            Print("Available symbol: ", symbol);
         }
      }
   }
   
   // Resize array to actual count
   ArrayResize(AvailableSymbols, AvailableSymbolsCount);
   
   if(AvailableSymbolsCount < 10)
   {
      Print("WARNING: Only ", AvailableSymbolsCount, " symbols available. Currency strength calculation may be inaccurate.");
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remove dashboard
   RemoveDashboard();
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update strength meter
   CalculateCurrencyStrength();
   
   //--- Scan for signals
   ScanForSignals();
   
   //--- Update dashboard
   UpdateDashboard();
   
   //--- Execute trades if auto trading is enabled
   if(AutoTrading)
   {
      ExecuteSignals();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Reset daily trade counters at midnight
   static datetime last_day = 0;
   datetime current_day = TimeCurrent() - (TimeCurrent() % 86400);
   
   if(current_day != last_day)
   {
      for(int i = 0; i < ArraySize(Symbols); i++)
      {
         DailyTrades[i][0] = 0;
         DailyTrades[i][1] = 0;
      }
      last_day = current_day;
   }
}

//+------------------------------------------------------------------+
//| Chart event function                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == ButtonAutoTrade)
      {
         AutoTrading = !AutoTrading;
         ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_STATE, false);
         UpdateDashboard();
      }
      else if(sparam == ButtonExportLogs)
      {
         ExportTradeLogs();
         ObjectSetInteger(0, ButtonExportLogs, OBJPROP_STATE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate currency strength                                      |
//+------------------------------------------------------------------+
void CalculateCurrencyStrength()
{
   double usd=0, eur=0, gbp=0, jpy=0, chf=0, cad=0, aud=0, nzd=0;
   int count = 0;
   
   // Use only available symbols
   for(int i = 0; i < AvailableSymbolsCount; i++)
   {
      string symbol = AvailableSymbols[i];
      
      double price_change = GetPriceChange(symbol, StrengthPeriod);
      if(price_change == 0) continue;
      
      string base = StringSubstr(symbol, 0, 3);
      string quote = StringSubstr(symbol, 3, 3);
      
      // Add to base currency strength
      if(base == "USD") usd += price_change;
      else if(base == "EUR") eur += price_change;
      else if(base == "GBP") gbp += price_change;
      else if(base == "JPY") jpy += price_change;
      else if(base == "CHF") chf += price_change;
      else if(base == "CAD") cad += price_change;
      else if(base == "AUD") aud += price_change;
      else if(base == "NZD") nzd += price_change;
      
      // Subtract from quote currency strength
      if(quote == "USD") usd -= price_change;
      else if(quote == "EUR") eur -= price_change;
      else if(quote == "GBP") gbp -= price_change;
      else if(quote == "JPY") jpy -= price_change;
      else if(quote == "CHF") chf -= price_change;
      else if(quote == "CAD") cad -= price_change;
      else if(quote == "AUD") aud -= price_change;
      else if(quote == "NZD") nzd -= price_change;
      
      count++;
   }
   
   if(count > 0)
   {
      CurrentStrength.USD = usd / count * 100;
      CurrentStrength.EUR = eur / count * 100;
      CurrentStrength.GBP = gbp / count * 100;
      CurrentStrength.JPY = jpy / count * 100;
      CurrentStrength.CHF = chf / count * 100;
      CurrentStrength.CAD = cad / count * 100;
      CurrentStrength.AUD = aud / count * 100;
      CurrentStrength.NZD = nzd / count * 100;
   }
   else
   {
      // If no symbols available, set all to zero
      CurrentStrength.USD = 0;
      CurrentStrength.EUR = 0;
      CurrentStrength.GBP = 0;
      CurrentStrength.JPY = 0;
      CurrentStrength.CHF = 0;
      CurrentStrength.CAD = 0;
      CurrentStrength.AUD = 0;
      CurrentStrength.NZD = 0;
   }
}

//+------------------------------------------------------------------+
//| Get price change percentage                                      |
//+------------------------------------------------------------------+
double GetPriceChange(string symbol, int period)
{
   double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double past_price = iClose(symbol, PERIOD_H1, period);
   
   if(past_price == 0) return 0;
   
   return (current_price - past_price) / past_price * 100;
}

//+------------------------------------------------------------------+
//| Get currency strength                                            |
//+------------------------------------------------------------------+
double GetCurrencyStrength(string currency)
{
   if(currency == "USD") return CurrentStrength.USD;
   else if(currency == "EUR") return CurrentStrength.EUR;
   else if(currency == "GBP") return CurrentStrength.GBP;
   else if(currency == "JPY") return CurrentStrength.JPY;
   else if(currency == "CHF") return CurrentStrength.CHF;
   else if(currency == "CAD") return CurrentStrength.CAD;
   else if(currency == "AUD") return CurrentStrength.AUD;
   else if(currency == "NZD") return CurrentStrength.NZD;
   return 0;
}

//+------------------------------------------------------------------+
//| Scan for trading signals                                         |
//+------------------------------------------------------------------+
void ScanForSignals()
{
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      string symbol = Symbols[i];
      if(!SymbolSelect(symbol, true)) continue;
      
      // Reset signal
      Signals[i].symbol = symbol;
      Signals[i].signal_type = 0;
      Signals[i].reason = "";
      
      // Check if we've reached max trades for today
      if(DailyTrades[i][0] + DailyTrades[i][1] >= MaxTradesPerPair) continue;
      
      // Get currency strengths
      string base = GetBaseCurrency(symbol);
      string quote = GetQuoteCurrency(symbol);
      
      if(base == "" || quote == "") continue;
      
      double base_strength = GetCurrencyStrength(base);
      double quote_strength = GetCurrencyStrength(quote);
      double strength_diff = base_strength - quote_strength;
      
      // Check strength condition
      if(MathAbs(strength_diff) < MinStrengthDiff) continue;
      
      // Detect order blocks
      OrderBlock ob = DetectOrderBlock(symbol);
      if(!ob.valid) continue;
      
      // Check for valid entry
      double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      // BUY signal: Strong base, weak quote, price at bullish OB
      if(strength_diff >= MinStrengthDiff && ob.is_bullish && 
         current_price >= ob.low && current_price <= ob.high)
      {
         if(DailyTrades[i][0] < MaxTradesPerPair)
         {
            Signals[i].signal_type = 1;
            Signals[i].entry_price = SymbolInfoDouble(symbol, SYMBOL_ASK);
            Signals[i].stop_loss = ob.low - StopLossPips * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
            Signals[i].take_profit = Signals[i].entry_price + (Signals[i].entry_price - Signals[i].stop_loss) * RiskReward;
            Signals[i].reason = StringFormat("Strong %s (%.1f), Weak %s (%.1f), Bullish OB", 
                                           base, base_strength, quote, quote_strength);
         }
      }
      // SELL signal: Weak base, strong quote, price at bearish OB
      else if(strength_diff <= -MinStrengthDiff && !ob.is_bullish && 
              current_price >= ob.low && current_price <= ob.high)
      {
         if(DailyTrades[i][1] < MaxTradesPerPair)
         {
            Signals[i].signal_type = -1;
            Signals[i].entry_price = SymbolInfoDouble(symbol, SYMBOL_BID);
            Signals[i].stop_loss = ob.high + StopLossPips * SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
            Signals[i].take_profit = Signals[i].entry_price - (Signals[i].stop_loss - Signals[i].entry_price) * RiskReward;
            Signals[i].reason = StringFormat("Weak %s (%.1f), Strong %s (%.1f), Bearish OB", 
                                           base, base_strength, quote, quote_strength);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect order block                                               |
//+------------------------------------------------------------------+
OrderBlock DetectOrderBlock(string symbol)
{
   OrderBlock ob;
   ob.valid = false;
   
   // Check M5 timeframe first, then M15
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15};
   
   for(int tf = 0; tf < 2; tf++)
   {
      ENUM_TIMEFRAMES timeframe = timeframes[tf];
      
      // Check for Break of Structure first
      if(!HasBreakOfStructure(symbol, timeframe)) continue;
      
      // Look for order blocks after BOS
      for(int i = 1; i < OB_LookbackBars; i++)
      {
         double high = iHigh(symbol, timeframe, i);
         double low = iLow(symbol, timeframe, i);
         double open = iOpen(symbol, timeframe, i);
         double close = iClose(symbol, timeframe, i);
         
         // Check if it's a significant candle
         double candle_size = MathAbs(high - low) / SymbolInfoDouble(symbol, SYMBOL_POINT) / 10;
         if(candle_size < OB_MinSize) continue;
         
         // Bullish OB: Strong bullish candle followed by pullback
         if(close > open && IsPullbackAfterBullishCandle(symbol, timeframe, i))
         {
            ob.high = high;
            ob.low = low;
            ob.time = iTime(symbol, timeframe, i);
            ob.is_bullish = true;
            ob.valid = true;
            return ob;
         }
         
         // Bearish OB: Strong bearish candle followed by pullback
         if(close < open && IsPullbackAfterBearishCandle(symbol, timeframe, i))
         {
            ob.high = high;
            ob.low = low;
            ob.time = iTime(symbol, timeframe, i);
            ob.is_bullish = false;
            ob.valid = true;
            return ob;
         }
      }
   }
   
   return ob;
}

//+------------------------------------------------------------------+
//| Check for Break of Structure                                     |
//+------------------------------------------------------------------+
bool HasBreakOfStructure(string symbol, ENUM_TIMEFRAMES timeframe)
{
   double recent_high = 0, recent_low = DBL_MAX;
   
   // Find recent high and low
   for(int i = 1; i <= BOS_LookbackBars; i++)
   {
      double high = iHigh(symbol, timeframe, i);
      double low = iLow(symbol, timeframe, i);
      
      if(high > recent_high) recent_high = high;
      if(low < recent_low) recent_low = low;
   }
   
   double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // BOS: Current price breaks above recent high or below recent low
   return (current_price > recent_high || current_price < recent_low);
}

//+------------------------------------------------------------------+
//| Check pullback after bullish candle                             |
//+------------------------------------------------------------------+
bool IsPullbackAfterBullishCandle(string symbol, ENUM_TIMEFRAMES timeframe, int candle_index)
{
   // Check if price pulled back to this level recently
   for(int i = 0; i < candle_index; i++)
   {
      double low = iLow(symbol, timeframe, i);
      double high = iHigh(symbol, timeframe, i);
      double ob_low = iLow(symbol, timeframe, candle_index);
      double ob_high = iHigh(symbol, timeframe, candle_index);
      
      if(low <= ob_high && high >= ob_low) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check pullback after bearish candle                             |
//+------------------------------------------------------------------+
bool IsPullbackAfterBearishCandle(string symbol, ENUM_TIMEFRAMES timeframe, int candle_index)
{
   // Check if price pulled back to this level recently
   for(int i = 0; i < candle_index; i++)
   {
      double low = iLow(symbol, timeframe, i);
      double high = iHigh(symbol, timeframe, i);
      double ob_low = iLow(symbol, timeframe, candle_index);
      double ob_high = iHigh(symbol, timeframe, candle_index);
      
      if(low <= ob_high && high >= ob_low) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Execute trading signals                                          |
//+------------------------------------------------------------------+
void ExecuteSignals()
{
   for(int i = 0; i < ArraySize(Signals); i++)
   {
      if(Signals[i].signal_type == 0) continue;
      
      string symbol = Signals[i].symbol;
      
      // Check M1 confirmation
      if(!HasM1Confirmation(symbol, Signals[i].signal_type)) continue;
      
      // Calculate position size based on risk
      double lot_size = CalculatePositionSize(symbol, Signals[i].entry_price, Signals[i].stop_loss);
      
      if(lot_size <= 0) continue;
      
      // Execute trade
      bool success = false;
      if(Signals[i].signal_type == 1) // BUY
      {
         success = trade.Buy(lot_size, symbol, Signals[i].entry_price, Signals[i].stop_loss, Signals[i].take_profit, 
                           "StrengthOB_BUY: " + Signals[i].reason);
         if(success) DailyTrades[i][0]++;
      }
      else if(Signals[i].signal_type == -1) // SELL
      {
         success = trade.Sell(lot_size, symbol, Signals[i].entry_price, Signals[i].stop_loss, Signals[i].take_profit, 
                            "StrengthOB_SELL: " + Signals[i].reason);
         if(success) DailyTrades[i][1]++;
      }
      
      if(success)
      {
         Print(StringFormat("Trade executed: %s %s %.2f lots at %.5f", 
                          (Signals[i].signal_type == 1 ? "BUY" : "SELL"), 
                          symbol, lot_size, Signals[i].entry_price));
      }
   }
}

//+------------------------------------------------------------------+
//| Check M1 confirmation                                            |
//+------------------------------------------------------------------+
bool HasM1Confirmation(string symbol, int signal_type)
{
   double open1 = iOpen(symbol, PERIOD_M1, 1);
   double close1 = iClose(symbol, PERIOD_M1, 1);
   double open2 = iOpen(symbol, PERIOD_M1, 2);
   double close2 = iClose(symbol, PERIOD_M1, 2);
   
   if(signal_type == 1) // BUY confirmation
   {
      // Look for bullish engulfing or rejection
      return (close1 > open1 && close1 > close2) || // Bullish candle after bearish
             (open1 < close2 && close1 > open2);     // Engulfing pattern
   }
   else if(signal_type == -1) // SELL confirmation
   {
      // Look for bearish engulfing or rejection
      return (close1 < open1 && close1 < close2) || // Bearish candle after bullish
             (open1 > close2 && close1 < open2);     // Engulfing pattern
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                           |
//+------------------------------------------------------------------+
double CalculatePositionSize(string symbol, double entry_price, double stop_loss)
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * RiskPercent / 100.0;
   
   double pip_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double pip_size = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   
   double stop_distance = MathAbs(entry_price - stop_loss);
   double stop_pips = stop_distance / pip_size;
   
   if(stop_pips <= 0) return 0;
   
   double lot_size = risk_amount / (stop_pips * pip_value);
   
   // Normalize lot size
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathMax(min_lot, MathMin(max_lot, MathRound(lot_size / lot_step) * lot_step));
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Get base currency                                                |
//+------------------------------------------------------------------+
string GetBaseCurrency(string symbol)
{
   // Remove .iux suffix if present
   string clean_symbol = symbol;
   if(StringFind(symbol, ".iux") >= 0)
      clean_symbol = StringSubstr(symbol, 0, StringFind(symbol, ".iux"));
   
   if(StringLen(clean_symbol) >= 6)
      return StringSubstr(clean_symbol, 0, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Get quote currency                                               |
//+------------------------------------------------------------------+
string GetQuoteCurrency(string symbol)
{
   // Remove .iux suffix if present
   string clean_symbol = symbol;
   if(StringFind(symbol, ".iux") >= 0)
      clean_symbol = StringSubstr(symbol, 0, StringFind(symbol, ".iux"));
   
   if(StringLen(clean_symbol) >= 6)
      return StringSubstr(clean_symbol, 3, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Create dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int panel_width = 400;
   int panel_height = 600;
   
   // Main panel
   ObjectCreate(0, PanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, PanelName, OBJPROP_XDISTANCE, DashboardX);
   ObjectSetInteger(0, PanelName, OBJPROP_YDISTANCE, DashboardY);
   ObjectSetInteger(0, PanelName, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, PanelName, OBJPROP_YSIZE, panel_height);
   ObjectSetInteger(0, PanelName, OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, PanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, PanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, PanelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, PanelName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, PanelName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, PanelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, PanelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, PanelName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, PanelName, OBJPROP_HIDDEN, true);
   
   // Title
   ObjectCreate(0, "Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Title", OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, "Title", OBJPROP_YDISTANCE, DashboardY + 10);
   ObjectSetInteger(0, "Title", OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, "Title", OBJPROP_FONTSIZE, 14);
   ObjectSetString(0, "Title", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, "Title", OBJPROP_TEXT, "Strength Meter + OB EA");
   
   // Auto Trade button
   ObjectCreate(0, ButtonAutoTrade, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_YDISTANCE, DashboardY + 40);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ButtonAutoTrade, OBJPROP_TEXT, AutoTrading ? "Auto: ON" : "Auto: OFF");
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_BGCOLOR, AutoTrading ? clrGreen : clrRed);
   
   // Export Logs button
   ObjectCreate(0, ButtonExportLogs, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_XDISTANCE, DashboardX + 140);
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_YDISTANCE, DashboardY + 40);
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ButtonExportLogs, OBJPROP_TEXT, "Export Logs");
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, ButtonExportLogs, OBJPROP_BGCOLOR, clrBlue);
   
   // Create labels for currency strengths and signals
   CreateDashboardLabels();
}

//+------------------------------------------------------------------+
//| Create dashboard labels                                          |
//+------------------------------------------------------------------+
void CreateDashboardLabels()
{
   int y_offset = 80;
   
   // Currency strength section
   ObjectCreate(0, "StrengthTitle", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "StrengthTitle", OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, "StrengthTitle", OBJPROP_YDISTANCE, DashboardY + y_offset);
   ObjectSetInteger(0, "StrengthTitle", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "StrengthTitle", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, "StrengthTitle", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, "StrengthTitle", OBJPROP_TEXT, "Currency Strength:");
   
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"};
   for(int i = 0; i < 8; i++)
   {
      ObjectCreate(0, "Strength_" + currencies[i], OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Strength_" + currencies[i], OBJPROP_XDISTANCE, DashboardX + 10 + (i % 4) * 90);
      ObjectSetInteger(0, "Strength_" + currencies[i], OBJPROP_YDISTANCE, DashboardY + y_offset + 25 + (i / 4) * 20);
      ObjectSetInteger(0, "Strength_" + currencies[i], OBJPROP_COLOR, TextColor);
      ObjectSetInteger(0, "Strength_" + currencies[i], OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "Strength_" + currencies[i], OBJPROP_FONT, "Arial");
   }
   
   // Signals section
   y_offset += 90;
   ObjectCreate(0, "SignalsTitle", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SignalsTitle", OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, "SignalsTitle", OBJPROP_YDISTANCE, DashboardY + y_offset);
   ObjectSetInteger(0, "SignalsTitle", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "SignalsTitle", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, "SignalsTitle", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, "SignalsTitle", OBJPROP_TEXT, "Active Signals:");
   
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      ObjectCreate(0, "Signal_" + IntegerToString(i), OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Signal_" + IntegerToString(i), OBJPROP_XDISTANCE, DashboardX + 10);
      ObjectSetInteger(0, "Signal_" + IntegerToString(i), OBJPROP_YDISTANCE, DashboardY + y_offset + 25 + i * 20);
      ObjectSetInteger(0, "Signal_" + IntegerToString(i), OBJPROP_COLOR, TextColor);
      ObjectSetInteger(0, "Signal_" + IntegerToString(i), OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "Signal_" + IntegerToString(i), OBJPROP_FONT, "Arial");
   }
   
   // Statistics section
   y_offset += 25 + ArraySize(Symbols) * 20 + 20;
   ObjectCreate(0, "StatsTitle", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "StatsTitle", OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, "StatsTitle", OBJPROP_YDISTANCE, DashboardY + y_offset);
   ObjectSetInteger(0, "StatsTitle", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "StatsTitle", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, "StatsTitle", OBJPROP_FONT, "Arial Bold");
   ObjectSetString(0, "StatsTitle", OBJPROP_TEXT, "Daily Trade Count:");
   
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      ObjectCreate(0, "Stats_" + IntegerToString(i), OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "Stats_" + IntegerToString(i), OBJPROP_XDISTANCE, DashboardX + 10);
      ObjectSetInteger(0, "Stats_" + IntegerToString(i), OBJPROP_YDISTANCE, DashboardY + y_offset + 25 + i * 15);
      ObjectSetInteger(0, "Stats_" + IntegerToString(i), OBJPROP_COLOR, TextColor);
      ObjectSetInteger(0, "Stats_" + IntegerToString(i), OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "Stats_" + IntegerToString(i), OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Update auto trade button
   ObjectSetString(0, ButtonAutoTrade, OBJPROP_TEXT, AutoTrading ? "Auto: ON" : "Auto: OFF");
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_BGCOLOR, AutoTrading ? clrGreen : clrRed);
   
   // Update currency strengths
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"};
   double strengths[] = {CurrentStrength.USD, CurrentStrength.EUR, CurrentStrength.GBP, CurrentStrength.JPY,
                        CurrentStrength.CHF, CurrentStrength.CAD, CurrentStrength.AUD, CurrentStrength.NZD};
   
   for(int i = 0; i < 8; i++)
   {
      string text = StringFormat("%s: %.1f", currencies[i], strengths[i]);
      ObjectSetString(0, "Strength_" + currencies[i], OBJPROP_TEXT, text);
      
      // Color coding
      color strength_color = clrWhite;
      if(strengths[i] > 3) strength_color = clrLime;
      else if(strengths[i] < -3) strength_color = clrRed;
      ObjectSetInteger(0, "Strength_" + currencies[i], OBJPROP_COLOR, strength_color);
   }
   
   // Update signals
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      string signal_text = Symbols[i] + ": ";
      color signal_color = clrWhite;
      
      if(Signals[i].signal_type == 1)
      {
         signal_text += "BUY - " + Signals[i].reason;
         signal_color = clrLime;
      }
      else if(Signals[i].signal_type == -1)
      {
         signal_text += "SELL - " + Signals[i].reason;
         signal_color = clrRed;
      }
      else
      {
         signal_text += "No Signal";
         signal_color = clrGray;
      }
      
      ObjectSetString(0, "Signal_" + IntegerToString(i), OBJPROP_TEXT, signal_text);
      ObjectSetInteger(0, "Signal_" + IntegerToString(i), OBJPROP_COLOR, signal_color);
   }
   
   // Update statistics
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      string stats_text = StringFormat("%s: %d/%d trades", Symbols[i], 
                                      DailyTrades[i][0] + DailyTrades[i][1], MaxTradesPerPair);
      ObjectSetString(0, "Stats_" + IntegerToString(i), OBJPROP_TEXT, stats_text);
   }
}

//+------------------------------------------------------------------+
//| Remove dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard()
{
   ObjectDelete(0, PanelName);
   ObjectDelete(0, "Title");
   ObjectDelete(0, ButtonAutoTrade);
   ObjectDelete(0, ButtonExportLogs);
   ObjectDelete(0, "StrengthTitle");
   ObjectDelete(0, "SignalsTitle");
   ObjectDelete(0, "StatsTitle");
   
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"};
   for(int i = 0; i < 8; i++)
   {
      ObjectDelete(0, "Strength_" + currencies[i]);
   }
   
   for(int i = 0; i < ArraySize(Symbols); i++)
   {
      ObjectDelete(0, "Signal_" + IntegerToString(i));
      ObjectDelete(0, "Stats_" + IntegerToString(i));
   }
}

//+------------------------------------------------------------------+
//| Export trade logs                                                |
//+------------------------------------------------------------------+
void ExportTradeLogs()
{
   string filename = "StrengthOB_TradeLogs_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
   int file_handle = FileOpen(filename, FILE_WRITE | FILE_CSV);
   
   if(file_handle != INVALID_HANDLE)
   {
      // Write header
      FileWrite(file_handle, "Time", "Symbol", "Type", "Volume", "Price", "SL", "TP", "Profit", "Comment");
      
      // Write trade history
      HistorySelect(TimeCurrent() - 86400, TimeCurrent()); // Last 24 hours
      
      for(int i = 0; i < HistoryDealsTotal(); i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
            double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            
            if(StringFind(comment, "StrengthOB") >= 0)
            {
               FileWrite(file_handle, TimeToString(time), symbol, EnumToString(type), 
                        volume, price, "", "", profit, comment);
            }
         }
      }
      
      FileClose(file_handle);
      Print("Trade logs exported to: ", filename);
   }
   else
   {
      Print("Failed to create export file");
   }
} 