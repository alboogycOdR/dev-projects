//+------------------------------------------------------------------+
//|                                                        Price.mqh |
//|                                                     Andrew Young |
//|                                 http://www.expertadvisorbook.com |
//+------------------------------------------------------------------+

#property copyright "Andrew Young"
#property link      "http://www.expertadvisorbook.com"

/*
 Creative Commons Attribution-NonCommercial 3.0 Unported
 http://creativecommons.org/licenses/by-nc/3.0/

 You may use this file in your own personal projects. You
 may modify it if necessary. You may even share it, provided
 the copyright above is present. No commercial use permitted. 
*/


#define MAX_BARS 100			// Max bars of rate data to retrieve


//+------------------------------------------------------------------+
//| Bar Data (OHLC, Volume, Time)                                    |
//+------------------------------------------------------------------+

class CBars
{
	public:
		CBars(void);
		MqlRates bar[];
		void Update(string pSymbol, ENUM_TIMEFRAMES pPeriod);
		double Close(int pShift);
		double High(int pShift);
		double Low(int pShift);
		double Open(int pShift);
		datetime Time(int pShift);
		long TickVolume(int pShift);
		long Volume(int pShift);
};


CBars::CBars(void)
{
	ArraySetAsSeries(bar,true);
}


void CBars::Update(string pSymbol,ENUM_TIMEFRAMES pPeriod)
{
	CopyRates(pSymbol,pPeriod,0,MAX_BARS,bar);
}


double CBars::Close(int pShift=0)
{
	return(bar[pShift].close);
}


double CBars::High(int pShift=0)
{
	return(bar[pShift].high);
}


double CBars::Low(int pShift=0)
{
	return(bar[pShift].low);
}


double CBars::Open(int pShift=0)
{
	return(bar[pShift].open);
}


long CBars::TickVolume(int pShift=0)
{
	return(bar[pShift].tick_volume);
}


datetime CBars::Time(int pShift=0)
{
	return(bar[pShift].time);
}


long CBars::Volume(int pShift=0)
{
	return(bar[pShift].real_volume);
}


//+------------------------------------------------------------------+
//| Current Price Information                                                                |
//+------------------------------------------------------------------+

double Ask(string pSymbol=NULL)
{
	if(pSymbol == NULL) pSymbol = _Symbol;
	return(SymbolInfoDouble(pSymbol,SYMBOL_ASK));
}


double Bid(string pSymbol=NULL)
{
	if(pSymbol == NULL) pSymbol = _Symbol;
	return(SymbolInfoDouble(pSymbol,SYMBOL_BID));
}


long Spread(string pSymbol=NULL)
{
	if(pSymbol == NULL) pSymbol = _Symbol;
	return(SymbolInfoInteger(pSymbol,SYMBOL_SPREAD));
}


long StopLevel(string pSymbol=NULL)
{
	if(pSymbol == NULL) pSymbol = _Symbol;
	long stopLevel = SymbolInfoInteger(pSymbol,SYMBOL_TRADE_STOPS_LEVEL);
	return(stopLevel);
}


//+------------------------------------------------------------------+
//| Highest High & Lowest Low                                        |
//+------------------------------------------------------------------+

double HighestHigh(string pSymbol, ENUM_TIMEFRAMES pPeriod, int pBars, int pStart = 0)
{
	double high[];
	ArraySetAsSeries(high,true);
	
	int copied = CopyHigh(pSymbol,pPeriod,pStart,pBars,high);
	if(copied == -1) return(copied);
	
	int maxIdx = ArrayMaximum(high);
	double highest = high[maxIdx];
	
	return(highest);
}


double LowestLow(string pSymbol, ENUM_TIMEFRAMES pPeriod, int pBars, int pStart = 0)
{
	double low[];
	ArraySetAsSeries(low,true);
	
	int copied = CopyLow(pSymbol,pPeriod,pStart,pBars,low);
	if(copied == -1) return(copied);
	
	int minIdx = ArrayMinimum(low);
	double lowest = low[minIdx];
	
	return(lowest);
}