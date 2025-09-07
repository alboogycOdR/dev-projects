


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