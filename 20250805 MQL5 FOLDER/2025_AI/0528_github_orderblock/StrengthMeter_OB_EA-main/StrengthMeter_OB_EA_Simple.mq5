//+------------------------------------------------------------------+
//|                                   StrengthMeter_OB_EA_Simple.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property description "Simplified Strength Meter + Order Block EA"

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

// Simplified symbol lists - only commonly available symbols
string Symbols[] = {"EURUSD.iux", "GBPUSD.iux", "USDJPY.iux"};  // Only major pairs for trading
string BasicPairs[] = {"EURUSD.iux", "GBPUSD.iux", "USDJPY.iux", "USDCHF.iux"};  // Minimal set for strength

struct StrengthData
{
   double USD, EUR, GBP, JPY, CHF;
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
   
   Print("Simplified Strength Meter + OB EA initialized successfully");
   return(INIT_SUCCEEDED);
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
//| Calculate currency strength (simplified)                        |
//+------------------------------------------------------------------+
void CalculateCurrencyStrength()
{
   double usd=0, eur=0, gbp=0, jpy=0, chf=0;
   int count = 0;
   
   for(int i = 0; i < ArraySize(BasicPairs); i++)
   {
      string symbol = BasicPairs[i];
      
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
      
      // Subtract from quote currency strength
      if(quote == "USD") usd -= price_change;
      else if(quote == "EUR") eur -= price_change;
      else if(quote == "GBP") gbp -= price_change;
      else if(quote == "JPY") jpy -= price_change;
      else if(quote == "CHF") chf -= price_change;
      
      count++;
   }
   
   if(count > 0)
   {
      CurrentStrength.USD = usd / count * 100;
      CurrentStrength.EUR = eur / count * 100;
      CurrentStrength.GBP = gbp / count * 100;
      CurrentStrength.JPY = jpy / count * 100;
      CurrentStrength.CHF = chf / count * 100;
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
   return 0;
}

//+------------------------------------------------------------------+
//| Create dashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int panel_width = 350;
   int panel_height = 400;
   
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
   ObjectSetString(0, "Title", OBJPROP_TEXT, "Simple Strength + OB EA");
   
   // Auto Trade button
   ObjectCreate(0, ButtonAutoTrade, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_XDISTANCE, DashboardX + 10);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_YDISTANCE, DashboardY + 40);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_YSIZE, 30);
   ObjectSetString(0, ButtonAutoTrade, OBJPROP_TEXT, AutoTrading ? "Auto: ON" : "Auto: OFF");
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_COLOR, TextColor);
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_BGCOLOR, AutoTrading ? clrGreen : clrRed);
}

//+------------------------------------------------------------------+
//| Update dashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Update auto trade button
   ObjectSetString(0, ButtonAutoTrade, OBJPROP_TEXT, AutoTrading ? "Auto: ON" : "Auto: OFF");
   ObjectSetInteger(0, ButtonAutoTrade, OBJPROP_BGCOLOR, AutoTrading ? clrGreen : clrRed);
}

//+------------------------------------------------------------------+
//| Remove dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard()
{
   ObjectDelete(0, PanelName);
   ObjectDelete(0, "Title");
   ObjectDelete(0, ButtonAutoTrade);
}

// Add other necessary functions here (simplified versions)
void ScanForSignals() { /* Simplified implementation */ }
void ExecuteSignals() { /* Simplified implementation */ }

string GetBaseCurrency(string symbol) 
{ 
   // Remove .iux suffix if present
   string clean_symbol = symbol;
   if(StringFind(symbol, ".iux") >= 0)
      clean_symbol = StringSubstr(symbol, 0, StringFind(symbol, ".iux"));
   
   return StringSubstr(clean_symbol, 0, 3); 
}

string GetQuoteCurrency(string symbol) 
{ 
   // Remove .iux suffix if present
   string clean_symbol = symbol;
   if(StringFind(symbol, ".iux") >= 0)
      clean_symbol = StringSubstr(symbol, 0, StringFind(symbol, ".iux"));
   
   return StringSubstr(clean_symbol, 3, 3); 
} 