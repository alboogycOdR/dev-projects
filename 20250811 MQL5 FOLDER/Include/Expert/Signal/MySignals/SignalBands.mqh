//+------------------------------------------------------------------+
//|                                                  SignalBands.mqh |
//|                                                             meta |
//|                                             https://sphacker.com |
//+------------------------------------------------------------------+
#property copyright "meta"
#property link      "https://sphacker.com"
#property version   "1.00"
#include <Expert\ExpertSignal.mqh>
// wizard description start
//+------------------------------------------------------------------+
//| Description of the class                                         |
//| Title=Signals of indicator 'BollingerBands'                      |
//| Type=SignalAdvanced                                              |
//| Name=BollingerBands                                              |
//| ShortName=Bands                                                  |
//| Class=CSignalBands                                               |
//| Page=                                                            |
//| Parameter=PeriodBands,int,20,Period of calculation               |
//| Parameter=Shift,int,0,Time shift                                 |
//| Parameter=Deviation,double,2.0,Deviation                         |
//| Parameter=Applied,ENUM_APPLIED_PRICE,PRICE_CLOSE,Prices series   |
//+------------------------------------------------------------------+
// wizard description end
//+------------------------------------------------------------------+
//| Class CSignalBands .                                             |
//| Purpose: Class of generator of trade signals based on            |
//|          the 'BollingerBands' indicator.                         |
//| Is derived from the CExpertSignal class.                         |
//+------------------------------------------------------------------+
class CSignalBands : public CExpertSignal
  {
protected:
   CiBands           m_bands;          // object-indicator
   //--- adjusted parameters
   int               m_bands_period;   // the "period of calculation" parameter of the indicator
   int               m_shift;          // the "time shift" parameter of the indicator
   double            m_deviation;      // the "deviation" parameter of the indicator
   ENUM_APPLIED_PRICE m_applied;       // the "price series" parameter of the oscillator

   //--- "weights" of market models (0-100)
   int               m_pattern_0;      // model 0 "price is near the necessary border of the bands"
   int               m_pattern_1;      // model 1 "price crossed a border of the bands"

public:
                     CSignalBands(void);
                    ~CSignalBands(void);
   //--- methods of setting adjustable parameters
   void              PeriodBands(int value)              { m_bands_period=value;     }
   void              Shift(int value)                    { m_shift=value;            }
   void              Deviation(double value)             { m_deviation=value;        }
   void              Applied(ENUM_APPLIED_PRICE value)   { m_applied=value;          }
   //--- methods of adjusting "weights" of market models
   void              Pattern_0(int value)                { m_pattern_0=value;        }
   void              Pattern_1(int value)                { m_pattern_1=value;        }
   //--- method of verification of settings
   virtual bool      ValidationSettings(void);
   //--- method of creating the indicator and timeseries
   virtual bool      InitIndicators(CIndicators *indicators);
   //--- methods of checking if the market models are formed
   virtual int       LongCondition(void);
   virtual int       ShortCondition(void);

protected:
   //--- method of initialization of the indicator
   bool              InitBands(CIndicators *indicators);
   //--- methods of getting data
   double            Base(int ind)                       { return(m_bands.Base(ind));  }
   double            Upper(int ind)                      { return(m_bands.Upper(ind)); }
   double            Lower(int ind)                      { return(m_bands.Lower(ind)); }

   double            DiffOpenLower(int ind)              { return(Close(ind+1)-Lower(ind+1)); }
   double            DiffCloseLower(int ind)             { return(Close(ind)-Lower(ind));     }
   double            DiffOpenUpper(int ind)              { return(Close(ind+1)-Upper(ind+1)); }
   double            DiffCloseUpper(int ind)             { return(Close(ind)-Upper(ind));     }

  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalBands::CSignalBands(void) : m_bands_period(20),
                                   m_shift(0),
                                   m_deviation(2.0),
                                   m_applied(PRICE_CLOSE),
                                   m_pattern_0(90),
                                   m_pattern_1(70)
  {
//--- initialization of protected data
   m_used_series=USE_SERIES_OPEN+USE_SERIES_HIGH+USE_SERIES_LOW+USE_SERIES_CLOSE;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalBands::~CSignalBands()
  {
  }
//+------------------------------------------------------------------+
//| Validation settings protected data.                              |
//+------------------------------------------------------------------+
bool CSignalBands::ValidationSettings(void)
  {
//--- validation settings of additional filters
   if(!CExpertSignal::ValidationSettings())
      return(false);
//--- initial data checks
   if(m_bands_period<=0)
     {
      printf(__FUNCTION__+": period Bands must be greater than 0");
      return(false);
     }
   if(m_deviation<=0)
     {
      printf(__FUNCTION__+": deviation must be greater than 0");
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Create indicators.                                               |
//+------------------------------------------------------------------+
bool CSignalBands::InitIndicators(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL)
      return(false);
//--- initialization of indicators and timeseries of additional filters
   if(!CExpertSignal::InitIndicators(indicators))
      return(false);
//--- create and initialize Bands indicator
   if(!InitBands(indicators))
      return(false);
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialize Bands indicators.                                     |
//+------------------------------------------------------------------+
bool CSignalBands::InitBands(CIndicators *indicators)
  {
//--- check pointer
   if(indicators==NULL)
      return(false);
//--- add object to collection
   if(!indicators.Add(GetPointer(m_bands)))
     {
      printf(__FUNCTION__+": error adding object");
      return(false);
     }
//--- initialize object
   if(!m_bands.Create(m_symbol.Name(),m_period,m_bands_period,m_shift,m_deviation,m_applied))
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
int CSignalBands::LongCondition(void)
  {
   int result=0;
   int idx   =StartIndex();
   double close=Close(idx);
   double upper=Upper(idx);
   double base=Base(idx);
   double lower=Lower(idx);
   double width=upper-lower;
//--- if the model 0 is used and the open price is below the lower indicator and close price is above the lower indicator
   if(IS_PATTERN_USAGE(0) && DiffOpenLower(idx)<0.0 && DiffCloseLower(idx)>0.0)
      result=m_pattern_0;
//--- if the model 1 is used and the open price is below the upper indicator and close price is above the upper indicator
   if(IS_PATTERN_USAGE(1) && DiffOpenUpper(idx)<0.0 && DiffCloseUpper(idx)>0.0)
      result=m_pattern_1;
//--- return the result
   return(result);
  }
//+------------------------------------------------------------------+
//| "Voting" that price will fall.                                   |
//+------------------------------------------------------------------+
int CSignalBands::ShortCondition(void)
  {
   int result  =0;
   int idx     =StartIndex();
   double close=Close(idx);
   double upper=Upper(idx);
   double base=Base(idx);
   double lower=Lower(idx);
   double width=upper-lower;
//--- if the model 0 is used and the open price is above the upper indicator and close price is below the upper indicator
   if(IS_PATTERN_USAGE(0) && DiffOpenUpper(idx)>0.0 && DiffCloseUpper(idx)<0.0)
      result=m_pattern_0;
//--- if the model 1 is used and the open price is above the lower indicator and close price is below the lower indicator
   if(IS_PATTERN_USAGE(1) && DiffOpenLower(idx)>0.0 && DiffCloseLower(idx)<0.0)
      result=m_pattern_1;
//--- return the result
   return(result);
  }
//+------------------------------------------------------------------+
