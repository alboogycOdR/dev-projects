//+------------------------------------------------------------------+
//|                     Gold Scalping Strategy                       |
//|                                                                  |
//| This EA is designed for scalping XAU/USD on a 5-minute chart.    |
//| It uses Keltner Channels, a 20-period SMA, and volume analysis.  |
//| Trades are entered when price crosses the Keltner Channels with  |
//| increasing volume. Multiple take profit levels are set using ATR.|
//+------------------------------------------------------------------+

#property version   "1.00"
#property strict
/*
sell conditions:
No open positions exist (PositionsTotal() == 0)
Price crosses below the Upper Keltner Channel:
Previous bar's close (closeArray[1]) was ABOVE the Upper Keltner Channel
Current bar's close (closeArray[0]) is BELOW the Upper Keltner Channel
Volume is increasing (Volume_Current > Volume_Previous)

*/
// Required includes
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/AccountInfo.mqh>

// Input parameters
input group "Trading Parameters"
input int      MagicNumber = 12345;       // Magic number for orders
input double   LotSize = 0.01;            // Lot size for trades
input int      Slippage = 3;              // Maximum slippage in points

input group "Indicator Settings"
input int      ATR_Period = 14;           // ATR period for TP calculation
input double   TP1_Multiplier = 1.5;      // TP1 multiplier for ATR
input double   TP2_Multiplier = 3.0;      // TP2 multiplier for ATR
input double   TP3_Multiplier = 4.5;      // TP3 multiplier for ATR
input int      Keltner_Period = 20;       // Keltner Channel period
input double   Keltner_Multiplier = 2.0;  // Keltner Channel multiplier
input int      SMA_Period = 20;           // SMA period

input group "Performance Tracking"
input bool     InpSavePerformanceStats = true;  // Save performance statistics
input bool     InpEnableDebug = false;          // Enable debug messages
// Add these to your input parameters section at the top of the file
input group "Volatility Settings"
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_CURRENT;  // ATR Timeframe
 int            InpATRPeriod    = ATR_Period;      // ATR Period for Volatility
// Global variables
double Keltner_Upper, Keltner_Lower, SMA;
double ATR;
double Volume_Current, Volume_Previous;
datetime statsLastSaved = 0;
datetime currentTradeDate = 0;
string statsFileName = "GoldScalper_Stats.csv";
double startDailyBalance = 0;
double highestDailyBalance = 0;
int totalTradesMade = 0;
int successfulTrades = 0;
int failedTrades = 0;

// Global indicator handles
int g_ATRHandle = INVALID_HANDLE;
int g_SMAHandle = INVALID_HANDLE;
int g_KeltnerHandle = INVALID_HANDLE;

// Global objects
CTrade trade;
CSymbolInfo symbolInfo;
CPositionInfo positionInfo;
CAccountInfo accountInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade settings
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.LogLevel(LOG_LEVEL_ERRORS);

   // Initialize symbol info
   if(!symbolInfo.Name(_Symbol))
   {
      Print("Failed to set symbol name: ", _Symbol);
      return INIT_FAILED;
   }
   
   if(!symbolInfo.RefreshRates())
   {
      Print("Failed to refresh symbol rates");
      return INIT_FAILED;
   }

   // Initialize indicators
   g_KeltnerHandle = iCustom(_Symbol, PERIOD_CURRENT, "Keltner_Channel", 
                            Keltner_Period, Keltner_Multiplier);
   g_SMAHandle = iMA(_Symbol, PERIOD_CURRENT, SMA_Period, 0, MODE_SMA, PRICE_CLOSE);
   g_ATRHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(g_KeltnerHandle == INVALID_HANDLE || g_SMAHandle == INVALID_HANDLE || 
      g_ATRHandle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators: ", GetLastError());
      return INIT_FAILED;
   }
   
   // Verify symbol
   if(_Symbol != "XAUUSD")
   {
      Alert("This EA is designed for XAUUSD only.");
      return(INIT_FAILED);
   }

   // Initialize performance tracking
   startDailyBalance = accountInfo.Balance();
   highestDailyBalance = startDailyBalance;
   currentTradeDate = TimeCurrent();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(g_ATRHandle != INVALID_HANDLE)
      IndicatorRelease(g_ATRHandle);
   if(g_SMAHandle != INVALID_HANDLE)
      IndicatorRelease(g_SMAHandle);
   if(g_KeltnerHandle != INVALID_HANDLE)
      IndicatorRelease(g_KeltnerHandle);
      
   // Save final statistics
   if(InpSavePerformanceStats)
      SavePerformanceStats();
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update symbol info
   if(!symbolInfo.RefreshRates())
      return;

   // Get current prices
   double Ask = symbolInfo.Ask();
   double Bid = symbolInfo.Bid();

   // Buffer arrays for data retrieval
   double keltnerBuffer[], smaBuffer[], atrBuffer[];
   long volumeBuffer[];
   
   // Set arrays as series
   ArraySetAsSeries(keltnerBuffer, true);
   ArraySetAsSeries(smaBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(volumeBuffer, true);
   
   // Copy data from indicators to buffers
   if(CopyBuffer(g_KeltnerHandle, 0, 0, 2, keltnerBuffer) <= 0)
   {
      Print("Error getting Keltner upper band: ", GetLastError());
      return;
   }
   Keltner_Upper = keltnerBuffer[1]; // Previous bar
   
   if(CopyBuffer(g_KeltnerHandle, 2, 0, 2, keltnerBuffer) <= 0)
   {
      Print("Error getting Keltner lower band: ", GetLastError());
      return;
   }
   Keltner_Lower = keltnerBuffer[1]; // Previous bar
   
   if(CopyBuffer(g_SMAHandle, 0, 0, 2, smaBuffer) <= 0)
   {
      Print("Error getting SMA values: ", GetLastError());
      return;
   }
   SMA = smaBuffer[1]; // Previous bar
   
   if(CopyBuffer(g_ATRHandle, 0, 0, 2, atrBuffer) <= 0)
   {
      Print("Error getting ATR values: ", GetLastError());
      return;
   }
   ATR = atrBuffer[1]; // Previous bar
   
   // Proper CopyTickVolume syntax
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 2, volumeBuffer) <= 0)
   {
      Print("Error getting volume data: ", GetLastError());
      return;
   }
   
   // Convert to double if needed for calculations
   Volume_Current = (double)volumeBuffer[0];
   Volume_Previous = (double)volumeBuffer[1];

   //--- Check if no open positions exist
   if(PositionsTotal() == 0)
   {
      //--- Get the latest prices
      symbolInfo.RefreshRates();
      double Ask = symbolInfo.Ask();
      double Bid = symbolInfo.Bid();
      
      //--- Buy signal: Price crosses above lower Keltner Channel with increasing volume
      double closeArray[];
      ArraySetAsSeries(closeArray, true);

      if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 2, closeArray) <= 0)
      {
         Print("Error getting close prices: ", GetLastError());
         return;
      }

      if(closeArray[1] < Keltner_Lower && closeArray[0] > Keltner_Lower && Volume_Current > Volume_Previous)
      {
         double entryPrice = Ask;
         double stopLoss = entryPrice - 200 * _Point;  // 10 pips SL
         double tp1 = entryPrice + TP1_Multiplier * ATR;
         double tp2 = entryPrice + TP2_Multiplier * ATR;
         double tp3 = entryPrice + TP3_Multiplier * ATR;

         //--- Place buy order using CTrade
         trade.SetExpertMagicNumber(MagicNumber);
         if(!trade.Buy(LotSize, _Symbol, entryPrice, stopLoss, tp1, "Buy Scalp"))
         {
            Print("OrderSend failed with error #", trade.ResultRetcode(), ": ", trade.ResultComment());
         }
      }

      //--- Sell signal: Price crosses below upper Keltner Channel with increasing volume
      if(closeArray[1] > Keltner_Upper && closeArray[0] < Keltner_Upper && Volume_Current > Volume_Previous)
      {
         double entryPrice = Bid;
         double stopLoss = entryPrice + 200 * _Point;  // 10 pips SL
         double tp1 = entryPrice - TP1_Multiplier * ATR;
         double tp2 = entryPrice - TP2_Multiplier * ATR;
         double tp3 = entryPrice - TP3_Multiplier * ATR;

         //--- Place sell order using CTrade
         trade.SetExpertMagicNumber(MagicNumber);
         if(!trade.Sell(LotSize, _Symbol, entryPrice, stopLoss, tp1, "Sell Scalp"))
         {
            Print("OrderSend failed with error #", trade.ResultRetcode(), ": ", trade.ResultComment());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Save performance statistics to file                              |
//+------------------------------------------------------------------+
void SavePerformanceStats()
{
   if(!InpSavePerformanceStats)
      return;
      
   // Only save once per hour to avoid too frequent writes
   if(TimeCurrent() - statsLastSaved < 3600)
      return;
      
   // Get latest account info
   double currentBalance = accountInfo.Balance();
   double dailyPL = currentBalance - startDailyBalance;
   double successRate = (totalTradesMade > 0) ? 100.0 * successfulTrades / totalTradesMade : 0;
   double maxDrawdown = 0;
   
   if(highestDailyBalance > 0)
      maxDrawdown = 100 * (highestDailyBalance - MathMin(currentBalance, highestDailyBalance)) / highestDailyBalance;
   
   MqlDateTime today;
   TimeCurrent(today);
   string dateStr = StringFormat("%04d.%02d.%02d", today.year, today.mon, today.day);
   
   // Modern MQL5 file handling
   int fileHandle = FileOpen(statsFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
   {
      // Move to the end of the file
      FileSeek(fileHandle, 0, SEEK_END);
      
      // Calculate hours active
      double hoursActive = (double)(TimeCurrent() - currentTradeDate) / 3600.0;
      
      // Write the statistics
      FileWrite(fileHandle, dateStr, 
               DoubleToString(startDailyBalance, 2),
               DoubleToString(currentBalance, 2),
               DoubleToString(dailyPL, 2),
               DoubleToString(maxDrawdown, 2),
               IntegerToString(totalTradesMade),
               IntegerToString(successfulTrades),
               IntegerToString(failedTrades),
               DoubleToString(successRate, 2),
               DoubleToString(GetATRVolatility(), 2),
               DoubleToString(hoursActive, 2));
      
      FileClose(fileHandle);
      statsLastSaved = TimeCurrent();
      
      if(InpEnableDebug)
         Print("Performance statistics saved to ", statsFileName);
   }
   else
   {
      Print("Failed to open statistics file: ", GetLastError());
   }
}

//+------------------------------------------------------------------+

double GetATRVolatility()
{
   double atrBuffer[];
   int atrHandle = iATR(Symbol(), InpATRTimeframe, InpATRPeriod);
   
   if(atrHandle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator: ", GetLastError());
      return 0;
   }
   
   ArraySetAsSeries(atrBuffer, true);
   int copied = CopyBuffer(atrHandle, 0, 0, 3, atrBuffer);
   
   IndicatorRelease(atrHandle);
   
   if(copied < 3)
   {
      Print("Error copying ATR data: ", GetLastError());
      return 0;
   }
   
   return atrBuffer[0] / Point();  // Convert to points
}

//+------------------------------------------------------------------+

// For buy orders (instead of OrderSend with OP_BUY)
void OpenBuyOrder(double lotSize, double stopLoss, double takeProfit)
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   if(!trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "Buy Scalp"))
   {
      Print("Buy order failed with error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
   else
   {
      Print("Buy order placed successfully. Ticket: ", trade.ResultOrder());
   }
}

// For sell orders (instead of OrderSend with OP_SELL)
void OpenSellOrder(double lotSize, double stopLoss, double takeProfit)
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   
   if(!trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "Sell Scalp"))
   {
      Print("Sell order failed with error: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
   else
   {
      Print("Sell order placed successfully. Ticket: ", trade.ResultOrder());
   }
}

//+------------------------------------------------------------------+