//+------------------------------------------------------------------+
//|                                         CSignalPullBackCandle.mqh |
//|                                                             meta |
//|                                             https://sphacker.com |
//+------------------------------------------------------------------+
#property copyright "meta"
#property link      "https://sphacker.com"
#property version   "1.00"
#include "aCandlePatterns.mqh"
// wizard description start
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Signals based on 'PullBack And Candle'                     |
//| Type=SignalAdvanced                                              |
//| Name=PullBackCandle                                              |
//| Class=CSignalPullBackCandle                                       |
//| Page=                                                            |
//| Parameter=LongRSI,int,10,Threshold of RSI long                   |
//| Parameter=ShortRSI,int,90,Threshold of RSI short                 |
//| Parameter=LimitSpread,int,20,Threshold of Spread                 |
//+------------------------------------------------------------------+
// wizard description end
//+------------------------------------------------------------------+
//| PullBackCandle Class.                                            |
//| Purpose: Trading signals class, based on Pull Back               |
//| Derived from CCandlePattern class.                               |
//+------------------------------------------------------------------+
class CSignalPullBackCandle : public CCandlePattern
  {
protected:
   CiRSI             m_rsi;            // object-rsi
   //--- adjusted parameters
   int               m_periodRSI;      // the "period of calculation" parameter of the oscillator
   ENUM_APPLIED_PRICE m_applied;       // the "prices series" parameter of the oscillator
   double            m_rsi_long;       // the "rsi_long" is condition of long
   double            m_rsi_short;      // the "rsi_short" is condition of short
   double            m_limit_spread;   // the "limit_spread" is determines the threshold of spread
public:
                     CSignalPullBackCandle();
                    ~CSignalPullBackCandle();
   //--- methods of setting adjustable parameters
   void              PeriodRSI(int value)              { m_periodRSI=value;     }
   void              PeriodMA(int value)               { m_ma_period=value;     }
   void              Applied(ENUM_APPLIED_PRICE value) { m_applied=value;       }
   void              LongRSI(double value)             { m_rsi_long=value;      }
   void              ShortRSI(double value)            { m_rsi_short=value;     }
   void              LimitSpread(double value)         { m_limit_spread=value;  }
   //--- method of verification of settings
   virtual bool      ValidationSettings();
   //--- method of creating the indicator and timeseries
   virtual bool      InitIndicators(CIndicators *indicators);
   //--- methods of checking if the market models are formed
   virtual int       LongCondition();
   virtual int       ShortCondition();

protected:
   //--- method of initialization of the oscillator
   bool              InitRSI(CIndicators *indicators);
   //--- methods of getting data
   double            RSI(int ind) { return(m_rsi.Main(ind));     }
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalPullBackCandle::CSignalPullBackCandle()
  {
//--- initialization of protected data
   m_used_series=USE_SERIES_OPEN+USE_SERIES_HIGH+USE_SERIES_LOW+USE_SERIES_CLOSE+USE_SERIES_SPREAD;
//--- setting default values for the indicator parameters
   m_periodRSI=2;
   m_ma_period=100;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalPullBackCandle::~CSignalPullBackCandle()
  {
  }
//+------------------------------------------------------------------+
//| Validation settings protected data.                              |
//+------------------------------------------------------------------+
bool CSignalPullBackCandle::ValidationSettings()
  {
//--- validation settings of additional filters
   if(!CCandlePattern::ValidationSettings()) return(false);
//--- initial data checks
   if(m_periodRSI<=0)
     {
      printf(__FUNCTION__+": period of the RSI oscillator must be greater than 0");
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Create indicators.                                               |
//+------------------------------------------------------------------+
bool CSignalPullBackCandle::InitIndicators(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL) return(false);
//--- initialization of indicators and timeseries of additional filters
   if(!CCandlePattern::InitIndicators(indicators)) return(false);
//--- create and initialize RSI oscillator
   if(!InitRSI(indicators)) return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialize RSI oscillators.                                      |
//+------------------------------------------------------------------+
bool CSignalPullBackCandle::InitRSI(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL) return(false);
//--- add object to collection
   if(!indicators.Add(GetPointer(m_rsi)))
     {
      printf(__FUNCTION__+": error adding object");
      return(false);
     }
//--- initialize object
   if(!m_rsi.Create(m_symbol.Name(),m_period,m_periodRSI,m_applied))
     {
      printf(__FUNCTION__+": error initializing object");
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| "Voting" that price will grow.                                   |
//+------------------------------------------------------------------+
int CSignalPullBackCandle::LongCondition()
  {
   int result=0;
   int idx   =StartIndex();
//--- check formation
   if(CheckPatternAllBearish() && 
      Close(idx)>MA(idx) && 
      RSI(idx)<m_rsi_long)
     {
      if(Spread(0)<m_limit_spread || m_limit_spread==0)
        {
         result=90;
        }
      else
        {
         Print("[Long] Since spread exceeds the threshold value, it does not enter."+DoubleToString(Spread(0)));
        }
     }
//--- check conditions of short position closing
   if(RSI(idx)<m_rsi_long && result==0)
      result=40;
//--- return the result
   return(result);
  }
//+------------------------------------------------------------------+
//| "Voting" that price will fall.                                   |
//+------------------------------------------------------------------+
int CSignalPullBackCandle::ShortCondition()
  {
   int result=0;
   int idx   =StartIndex();
//--- check formation
   if(CheckPatternAllBullish() && 
      Close(idx)<MA(idx) && 
      RSI(idx)>m_rsi_short)
      if(Spread(0)<m_limit_spread || m_limit_spread==0)
        {
         result=90;
        }
   else
     {
      Print("[Short] Since spread exceeds the threshold value, it does not enter."+DoubleToString(Spread(0)));
     }
//--- check conditions of long position closing
   if(RSI(idx)>m_rsi_short && result==0)
      result=40;
//--- return the result
   return(result);
  }
//+------------------------------------------------------------------+
