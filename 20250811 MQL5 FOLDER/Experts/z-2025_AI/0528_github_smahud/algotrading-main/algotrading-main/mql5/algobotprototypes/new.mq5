//+------------------------------------------------------------------+
//|                                  BollingerSqueezeReversal.mq5    |
//|                                       Copyright 2023, YourName   |
//|                                             https://www.yoursite |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property version   "1.00"
#property strict

//--- Trading constants for Ethereum
const double FIXED_LOT_SIZE = 0.20;
const string SYMBOL = "ETHUSDm";

// Input parameters
//input double   RiskPercent    = 1.0;     // Risk % per trade  //--- Removed RiskPercent input
input int      BBPeriod       = 20;      // Bollinger Bands period
input double   BBDeviation    = 1.0;     // Bands deviation
input int      RSIPeriod      = 14;      // RSI period
input int      VolumeLookback = 5;       // Volume comparison bars
input double   VolumeSpikeMultiplier = 1.5; // Volume spike threshold multiplier
input double   SqueezeThreshold   = 0.01;    // Bollinger Bands squeeze threshold (%)
input double   InitialSL_ATR_Multiplier = 0.5; // Initial Stop Loss ATR multiplier
input double   TrailingSL_ATR_Multiplier = 1.5; // Trailing Stop Loss ATR multiplier
input int      Slippage         = 5;       // Slippage for order execution

// Global variables
double lotSize;
int rsiHandle, bbHandle, atrHandle, ma50HandleDaily;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create indicator handles
   bbHandle = iBands(SYMBOL, PERIOD_H1, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   rsiHandle = iRSI(SYMBOL, PERIOD_H1, RSIPeriod, PRICE_CLOSE);
   atrHandle = iATR(SYMBOL, PERIOD_H1, 14);
   ma50HandleDaily = iMA(SYMBOL, PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE);

   if(bbHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || ma50HandleDaily == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Only process once per new H1 bar
   if(!IsNewBar()) return;

   // Get current close price for H1 bar
   double currentClose = iClose(SYMBOL, PERIOD_H1, 0);

   // Check existing positions; if any, run trailing stop and exit
   if(PositionsTotal() > 0)
   {
      TrailingStop();
      return;
   }

   //--- Retrieve indicator values
   double upperBand[], lowerBand[], rsi[], atr[], ma50Daily[];
   // Bollinger Bands: buffer 1 = upper, buffer 2 = lower
   if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0 ||
      CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0)
   {
      Print("Error copying Bollinger Bands buffers");
      return;
   }
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
   {
      Print("Error copying RSI buffer");
      return;
   }
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
   {
      Print("Error copying ATR buffer");
      return;
   }
   if(CopyBuffer(ma50HandleDaily, 0, 0, 1, ma50Daily) <= 0)
   {
      Print("Error copying Daily MA50 buffer");
      return;
   }

   //--- Get volume for the last VolumeLookback bars using iVolume()
   double volume[];
   ArrayResize(volume, VolumeLookback);
   for(int j=0; j < VolumeLookback; j++)
   {
      volume[j] = iVolume(SYMBOL, PERIOD_H1, j);
   }
   double volumeAvg = ArrayAverage(volume);
   bool volumeSpike = (volume[0] > (volumeAvg * VolumeSpikeMultiplier));

   //--- Check Bollinger Bands width (squeeze condition)
   double bandWidth = (upperBand[0] - lowerBand[0]) / upperBand[0];
   bool squeeze = bandWidth < SqueezeThreshold;

   //--- Higher timeframe trend filter (Daily MA50)
   bool bullishTrend = (currentClose > ma50Daily[0]);
   bool bearishTrend = (currentClose < ma50Daily[0]);

   //--- Long signal: price below lower band, RSI oversold, volume spike, squeeze, and bullish daily trend
   if(currentClose < lowerBand[0] && rsi[0] < 30 && volumeSpike && squeeze && bullishTrend)
   {
      double sl = lowerBand[0] - (atr[0] * InitialSL_ATR_Multiplier);
      double tp = currentClose + (3 * (currentClose - sl));
      OpenTrade(ORDER_TYPE_BUY, sl, tp);
   }

   //--- Short signal: price above upper band, RSI overbought, volume spike, squeeze, and bearish daily trend
   if(currentClose > upperBand[0] && rsi[0] > 70 && volumeSpike && squeeze && bearishTrend)
   {
      double sl = upperBand[0] + (atr[0] * InitialSL_ATR_Multiplier);
      double tp = currentClose - (3 * (sl - currentClose));
      OpenTrade(ORDER_TYPE_SELL, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| Custom trailing stop function                                    |
//+------------------------------------------------------------------+
void TrailingStop()
{
   for(int i=0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double currentSL = PositionGetDouble(POSITION_SL);
         double atrVal[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atrVal) <= 0)
         {
            Print("Error copying ATR buffer in TrailingStop");
            continue;
         }
         if(type == POSITION_TYPE_BUY)
         {
            double newSL = iHigh(SYMBOL, PERIOD_H1, 0) - (atrVal[0] * TrailingSL_ATR_Multiplier);
            if(newSL > currentSL)
            {
               PositionModify(SYMBOL, newSL, PositionGetDouble(POSITION_TP));
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double newSL = iLow(SYMBOL, PERIOD_H1, 0) + (atrVal[0] * TrailingSL_ATR_Multiplier);
            if(newSL < currentSL)
            {
               PositionModify(SYMBOL, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Risk-managed trade execution                                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double sl, double tp)
{
   //--- Use fixed lot size
   lotSize = FIXED_LOT_SIZE;

   MqlTradeRequest request = {0};
   MqlTradeResult  result = {0};
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = SYMBOL;
   request.volume   = lotSize;
   request.type     = type;
   request.price    = SymbolInfoDouble(SYMBOL, (type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID));
   request.sl       = sl;
   request.tp       = tp;
   request.deviation= Slippage;
   request.type_filling = ORDER_FILLING_FOK;

   if(!OrderSend(request, result))
   {
      Print("OrderSend failed: ", GetLastError());
      return;
   }
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      Print("OrderSend failed, retcode=", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| IsNewBar function                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(SYMBOL, PERIOD_H1, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return(true);
   }
   return(false);
}
