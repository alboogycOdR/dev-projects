//+------------------------------------------------------------------+
//|  	                                   	  MultiCurrencyExample.mq5 |
//|                                                    Andriy Moraru |
//|                                        https://www.earnforex.com |
//|            							                       2010-2021 |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2021"
#property link      "https://www.earnforex.com/creating-multi-currency-expert-advisor-for-metatrader-5/"
#property version   "1.01"
#property description "A fully scalable and flexible class-based multi-currency expert advisor example."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Trading instruments:
input string CurrencyPair1 = "EURUSD";
input string CurrencyPair2 = "GBPUSD";
input string CurrencyPair3 = "USDJPY";
input string CurrencyPair4 = "";

// Timeframes:
input ENUM_TIMEFRAMES TimeFrame1 = PERIOD_M15;
input ENUM_TIMEFRAMES TimeFrame2 = PERIOD_M30;
input ENUM_TIMEFRAMES TimeFrame3 = PERIOD_H1;
input ENUM_TIMEFRAMES TimeFrame4 = PERIOD_M1;

// Period to hold the position open:
input int PeriodToHold1 = 1;
input int PeriodToHold2 = 2;
input int PeriodToHold3 = 3;
input int PeriodToHold4 = 4;

// Basic position size:
input double Lots1 = 1;
input double Lots2 = 1;
input double Lots3 = 1;
input double Lots4 = 1;

// Tolerated slippage in points:
input int Slippage1 = 50; 	
input int Slippage2 = 50;
input int Slippage3 = 50;
input int Slippage4 = 50;

// Text strings:
input string OrderComment = "MultiCurrencyExample";

// Main trading objects
CTrade *Trade;
CPositionInfo PositionInfo;

class CMultiCurrencyExample
{
   private:
      bool              HaveLongPosition;
      bool              HaveShortPosition;
      int               LastBars;
      int               HoldPeriod;
      int               PeriodToHold;
      bool              Initialized;
      void              GetPositionStates();
      void              ClosePrevious(ENUM_ORDER_TYPE order_direction);
      void              OpenPosition(ENUM_ORDER_TYPE order_direction);
   
   protected:
      string            symbol;                    // Currency pair to trade.
      ENUM_TIMEFRAMES   timeframe;                 // Timeframe.
      long              digits;                    // Number of decimal places.
      double            lots;                      // Position size.
      CTrade            Trade;                     // Trading object.
      CPositionInfo     PositionInfo;              // Position Info object.
   
   public:
                        CMultiCurrencyExample();               // Constructor.
                       ~CMultiCurrencyExample() { Deinit(); }  // Destructor.
      bool              Init(string Pair, ENUM_TIMEFRAMES Timeframe, int PerTH, double PositionSize, int Slippage);
      void              Deinit();
      bool              Validated();
      void              CheckEntry();                          // Main trading function.
};

//+------------------------------------------------------------------+
//| Constructor                                                     |
//+------------------------------------------------------------------+
CMultiCurrencyExample::CMultiCurrencyExample()
{
   Initialized = false;
}

//+------------------------------------------------------------------+
//| Performs object initialization                                   |
//+------------------------------------------------------------------+
bool CMultiCurrencyExample::Init(string Pair, ENUM_TIMEFRAMES Timeframe, int PerTH, double PositionSize, int Slippage)
{
   symbol = Pair;
   timeframe = Timeframe;
   digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   lots = PositionSize;
   
   Trade.SetDeviationInPoints(Slippage);

   PeriodToHold = PerTH;
   HoldPeriod = 0;

   LastBars = 0;
   
   Initialized = true;
  
   Print(symbol, " initialized.");

   return(true);
}

//+------------------------------------------------------------------+
//| Object deinitialization                                          |
//+------------------------------------------------------------------+
void CMultiCurrencyExample::Deinit()
{
   Initialized = false;
   
   Print(symbol, " deinitialized.");
}

//+------------------------------------------------------------------+
//| Checks if everything initialized successfully                    |
//+------------------------------------------------------------------+
bool CMultiCurrencyExample::Validated()
{
   return (Initialized);
}

//+------------------------------------------------------------------+
//| Checks for entry to a trade - Exits previous trade also          |
//+------------------------------------------------------------------+
void CMultiCurrencyExample::CheckEntry()
{
   // Trade on new bars only.
   if (LastBars != Bars(symbol, timeframe)) LastBars = Bars(symbol, timeframe);
   else return;

	MqlRates rates[];
	ArraySetAsSeries(rates, true);
	int copied = CopyRates(symbol, timeframe, 1, 1, rates);
	if (copied <= 0) Print("Error copying price data: ", GetLastError());
		
	// Period counter for open positions.
   if (HoldPeriod > 0) HoldPeriod--;
	
	// Check which position is currently open.
	GetPositionStates();

	// PeriodToHold position has passed, it should be closed.
  	if (HoldPeriod == 0)
  	{
     	if (HaveShortPosition) ClosePrevious(ORDER_TYPE_BUY);
      else if (HaveLongPosition) ClosePrevious(ORDER_TYPE_SELL);
   }
   
	// Checking the previous candle.
	if (rates[0].close > rates[0].open) // Bullish.
	{
  		if (HaveShortPosition) ClosePrevious(ORDER_TYPE_BUY);
  		if (!HaveLongPosition) OpenPosition(ORDER_TYPE_BUY);
  		else HoldPeriod = PeriodToHold;
	}
	else if (rates[0].close < rates[0].open) // Bearish.
	{
  		if (HaveLongPosition) ClosePrevious(ORDER_TYPE_SELL);
  		if (!HaveShortPosition) OpenPosition(ORDER_TYPE_SELL);
  		else HoldPeriod = PeriodToHold;
	}
}

//+------------------------------------------------------------------+
//| Check What Position is Currently Open										|
//+------------------------------------------------------------------+
void CMultiCurrencyExample::GetPositionStates()
{
	// Is there a position on this currency pair?
	if (PositionInfo.Select(symbol))
	{
		if (PositionInfo.PositionType() == POSITION_TYPE_BUY)
		{
  			HaveLongPosition = true;
  			HaveShortPosition = false;
		}
		else if (PositionInfo.PositionType() == POSITION_TYPE_SELL)
		{ 
  			HaveLongPosition = false;
  			HaveShortPosition = true;
		}
	}
	else
	{
		HaveLongPosition = false;
		HaveShortPosition = false;
	}
}

//+------------------------------------------------------------------+
//| Close Open Position																|
//| Gets direction for CLOSING, not	of the current position.   		|
//+------------------------------------------------------------------+
void CMultiCurrencyExample::ClosePrevious(ENUM_ORDER_TYPE order_direction)
{
	if (PositionInfo.Select(symbol))
	{
     	double Price = -1;
     	if (order_direction == ORDER_TYPE_BUY) Price = SymbolInfoDouble(symbol, SYMBOL_ASK);
  		else if (order_direction == ORDER_TYPE_SELL) Price = SymbolInfoDouble(symbol, SYMBOL_BID);
		Trade.PositionOpen(symbol, order_direction, lots, Price, 0, 0, OrderComment + symbol);
  		if ((Trade.ResultRetcode() != 10008) && (Trade.ResultRetcode() != 10009) && (Trade.ResultRetcode() != 10010))
  			Print("Position Close Return Code: ", Trade.ResultRetcodeDescription());
  		else
  		{
  		   HaveLongPosition = false;
  		   HaveShortPosition = false;
     	   HoldPeriod = 0;
     	}
	}
}

//+------------------------------------------------------------------+
//| Open Position																      |
//+------------------------------------------------------------------+
void CMultiCurrencyExample::OpenPosition(ENUM_ORDER_TYPE order_direction)
{
  	double Price = -1;
  	if (order_direction == ORDER_TYPE_BUY) Price = SymbolInfoDouble(symbol, SYMBOL_ASK);
	else if (order_direction == ORDER_TYPE_SELL) Price = SymbolInfoDouble(symbol, SYMBOL_BID);
   Trade.PositionOpen(symbol, order_direction, lots, Price, 0, 0, OrderComment + symbol);
   if ((Trade.ResultRetcode() != 10008) && (Trade.ResultRetcode() != 10009) && (Trade.ResultRetcode() != 10010))
      Print("Position Open Return Code: ", Trade.ResultRetcodeDescription());
   else
      HoldPeriod = PeriodToHold;
}

// Global variables
CMultiCurrencyExample TradeObject1, TradeObject2, TradeObject3, TradeObject4;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	// Initialize all objects
   if (CurrencyPair1 != "")
      if (!TradeObject1.Init(CurrencyPair1, TimeFrame1, PeriodToHold1, Lots1, Slippage1))
      {
         TradeObject1.Deinit();
         return(-1);
      }
   if (CurrencyPair2 != "")
      if (!TradeObject2.Init(CurrencyPair2, TimeFrame2, PeriodToHold2, Lots2, Slippage2))
      {
         TradeObject2.Deinit();
         return(-1);
      }
   if (CurrencyPair3 != "")
      if (!TradeObject3.Init(CurrencyPair3, TimeFrame3, PeriodToHold3, Lots3, Slippage3))
      {
         TradeObject3.Deinit();
         return(-1);
      }
   if (CurrencyPair4 != "")
      if (!TradeObject4.Init(CurrencyPair4, TimeFrame4, PeriodToHold4, Lots4, Slippage4))
      {
         TradeObject4.Deinit();
         return(-1);
      }

   return(0);
}

//+------------------------------------------------------------------+
//| Expert Every Tick Function                                       |
//+------------------------------------------------------------------+
void OnTick()
{
	// Is trade allowed?
	if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return;
	if (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == false) return;
   
   // Trade objects initialized?
   if ((CurrencyPair1 != "") && (!TradeObject1.Validated())) return;
   if ((CurrencyPair2 != "") && (!TradeObject2.Validated())) return;
   if ((CurrencyPair3 != "") && (!TradeObject3.Validated())) return;
   if ((CurrencyPair4 != "") && (!TradeObject4.Validated())) return;
   
   if (CurrencyPair1 != "") TradeObject1.CheckEntry();
   if (CurrencyPair2 != "") TradeObject2.CheckEntry();
   if (CurrencyPair3 != "") TradeObject3.CheckEntry();
   if (CurrencyPair4 != "") TradeObject4.CheckEntry();
}
//+------------------------------------------------------------------+