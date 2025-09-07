//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "SymbolProperties.mqh"
//+------------------------------------------------------------------+
//|ChartProperties class                                             |
//+------------------------------------------------------------------+
class CChartProperties : public CSymbolProperties
  {
private:
   struct ChartFormat
     {
      ulong             CHART_MODE;//Chart Candle Mode
      ulong             CHART_COLOR_BACKGROUND;//Chart Background Color
      ulong             CHART_COLOR_FOREGROUND;//Chart Foreground Color
      ulong             CHART_COLOR_CHART_LINE;//Chart Line Color
      ulong             CHART_COLOR_CANDLE_BEAR;//Chart Bear Candle Color
      ulong             CHART_COLOR_CHART_DOWN;//Chart Down Candle Color
      ulong             CHART_COLOR_CANDLE_BULL;//Chart Bull Candle Color
      ulong             CHART_COLOR_CHART_UP;//Chart Up Candle Color
      ulong             CHART_COLOR_ASK;//Chart Ask Color
      ulong             CHART_COLOR_BID;//Chart Bid Color
      ulong             CHART_COLOR_STOP_LEVEL;//Chart Stoplevel Color
      ulong             CHART_SHOW_PERIOD_SEP;//Chart Show Period Separator
      ulong             CHART_SCALE;//Chart Scale
      ulong             CHART_FOREGROUND;//Chart Show Foreground
      ulong             CHART_SHOW_ASK_LINE;//Chart Show Ask Line
      ulong             CHART_SHOW_BID_LINE;//Chart Show Bid Line
      ulong             CHART_SHOW_TRADE_LEVELS;//Chart Show Trade Levels
      ulong             CHART_SHOW_OHLC;//Chart Show Open-High-Low-Close
      ulong             CHART_SHOW_GRID;//Chart Show Grid
      ulong             CHART_SHOW_VOLUMES;//Chart Show Volumes
      ulong             CHART_AUTOSCROLL;//Chart Auto Scroll
      double            CHART_SHIFT_SIZE;//Chart Shift Size
      ulong             CHART_SHIFT;//Chart Shift
      ulong             CHART_SHOW_ONE_CLICK;//Chart One Click Trading
     };
   ulong             ChartConfig[65];//Array To Store Chart Properties
   void              ChartSet();//Apply Chart format
   void              ChartConfigure();//Set Chart Values
   ChartFormat       Chart;//Variable of type ChartFormat

public:
                     CChartProperties(void);//Constructor
                    ~CChartProperties(void);//Destructor
   void              ChartRefresh() {ChartConfigure();}
  };

//+------------------------------------------------------------------+
//|Constructor                                                       |
//+------------------------------------------------------------------+
CChartProperties::CChartProperties(void)
  {
   for(int i=0;i<65;i++)//Iterating through ENUM_CHART_PROPERTY_INTEGER Elements
     {
      ChartGetInteger(0,(ENUM_CHART_PROPERTY_INTEGER)i,0,ChartConfig[i]);//Storing Chart values into ChartConfig array
     }
   ChartConfigure();
  }

//+------------------------------------------------------------------+
//|Destructor                                                        |
//+------------------------------------------------------------------+
CChartProperties::~CChartProperties(void)
  {
   for(int i=0;i<65;i++)//Iterating through ENUM_CHART_PROPERTY_INTEGER Elements
     {
      ChartSetInteger(0,(ENUM_CHART_PROPERTY_INTEGER)i,0,ChartConfig[i]);//Restoring Chart values from ChartConfig array
     }
  }

//+------------------------------------------------------------------+
//|Set Chart Properties                                              |
//+------------------------------------------------------------------+
void CChartProperties::ChartSet()
  {
   ChartSetInteger(0,CHART_MODE,Chart.CHART_MODE);//Set Chart Candle Mode
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,Chart.CHART_COLOR_BACKGROUND);//Set Chart Background Color
   ChartSetInteger(0,CHART_COLOR_FOREGROUND,Chart.CHART_COLOR_FOREGROUND);//Set Chart Foreground Color
   ChartSetInteger(0,CHART_COLOR_CHART_LINE,Chart.CHART_COLOR_CHART_LINE);//Set Chart Line Color
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,Chart.CHART_COLOR_CANDLE_BEAR);//Set Chart Bear Candle Color
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,Chart.CHART_COLOR_CHART_DOWN);//Set Chart Down Candle Color
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,Chart.CHART_COLOR_CANDLE_BULL);//Set Chart Bull Candle Color
   ChartSetInteger(0,CHART_COLOR_CHART_UP,Chart.CHART_COLOR_CHART_UP);//Set Chart Up Candle Color
   ChartSetInteger(0,CHART_COLOR_ASK,Chart.CHART_COLOR_ASK);//Set Chart Ask Color
   ChartSetInteger(0,CHART_COLOR_BID,Chart.CHART_COLOR_BID);//Set Chart Bid Color
   ChartSetInteger(0,CHART_COLOR_STOP_LEVEL,Chart.CHART_COLOR_STOP_LEVEL);//Set Chart Stop Level Color
   ChartSetInteger(0,CHART_FOREGROUND,Chart.CHART_FOREGROUND);//Set if Chart is in Foreground Visibility
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,Chart.CHART_SHOW_ASK_LINE);//Set Chart Ask Line Visibility
   ChartSetInteger(0,CHART_SHOW_BID_LINE,Chart.CHART_SHOW_BID_LINE);//Set Chart Bid Line Visibility
   ChartSetInteger(0,CHART_SHOW_PERIOD_SEP,Chart.CHART_SHOW_PERIOD_SEP);//Set Chart Period Separator Visibility
   ChartSetInteger(0,CHART_SHOW_TRADE_LEVELS,Chart.CHART_SHOW_TRADE_LEVELS);//Set Chart Trade Levels Visibility
   ChartSetInteger(0,CHART_SHOW_OHLC,Chart.CHART_SHOW_OHLC);//Set Chart Open-High-Low-Close Visibility
   ChartSetInteger(0,CHART_SHOW_GRID,Chart.CHART_SHOW_GRID);//Set Chart Grid Visibility
   ChartSetInteger(0,CHART_SHOW_VOLUMES,Chart.CHART_SHOW_VOLUMES);//Set Chart Volumes Visibility
   ChartSetInteger(0,CHART_SCALE,Chart.CHART_SCALE);//Set Chart Scale Value
   ChartSetInteger(0,CHART_AUTOSCROLL,Chart.CHART_AUTOSCROLL);//Set Chart Auto Scroll Option
   ChartSetDouble(0,CHART_SHIFT_SIZE,Chart.CHART_SHIFT_SIZE);//Set Chart Shift Size Value
   ChartSetInteger(0,CHART_SHIFT,Chart.CHART_SHIFT);//Set Chart Shift Option
   ChartSetInteger(0,CHART_SHOW_ONE_CLICK,Chart.CHART_SHOW_ONE_CLICK);//Set Chart One Click Trading
  }

//+------------------------------------------------------------------+
//|Initialize Chart Properties                                       |
//+------------------------------------------------------------------+
void CChartProperties::ChartConfigure(void)
  {
   Chart.CHART_MODE=(ulong)CHART_CANDLES;//Assigning Chart Mode of CHART_CANDLES
   Chart.CHART_COLOR_BACKGROUND=ulong(SymbolBackground());//Assigning Chart Background Color of Symbol's Background color
   Chart.CHART_COLOR_FOREGROUND=(ulong)clrBlack;//Assigning Chart Foreground Color of clrBalck(Black color)
   Chart.CHART_COLOR_CHART_LINE=(ulong)clrBlack;//Assigning Chart Line Color of clrBlack(Black color)
   Chart.CHART_COLOR_CANDLE_BEAR=(ulong)clrBlack;//Assigning Chart Bear Candle Color of clrBlack(Black color)
   Chart.CHART_COLOR_CHART_DOWN=(ulong)clrBlack;//Assigning Chart Down Candle Color of clrBlack(Black color)
   Chart.CHART_COLOR_CANDLE_BULL=(ulong)clrWhite;//Assigning Chart Bull Candle Color of clrWhite(White color)
   Chart.CHART_COLOR_CHART_UP=(ulong)clrBlack;//Assigning Chart Up Candle Color of clrBlack(Black color)
   Chart.CHART_COLOR_ASK=(ulong)clrBlack;//Assigning Chart Ask Color of clrBlack(Black color)
   Chart.CHART_COLOR_BID=(ulong)clrBlack;//Assigning Chart Bid Color of clrBlack(Black color)
   Chart.CHART_COLOR_STOP_LEVEL=(ulong)clrBlack;//Assigning Chart Stop Level Color of clrBlack(Black color)
   Chart.CHART_FOREGROUND=(ulong)false;//Assigning Chart Foreground Boolean Value of 'false'
   Chart.CHART_SHOW_ASK_LINE=(ulong)true;//Assigning Chart Ask Line Boolean Value of 'true'
   Chart.CHART_SHOW_BID_LINE=(ulong)true;//Assigning Chart Bid Line Boolean Value of 'true'
   Chart.CHART_SHOW_PERIOD_SEP=(ulong)true;//Assigning Chart Period Separator Boolean Value of 'true'
   Chart.CHART_SHOW_TRADE_LEVELS=(ulong)true;//Assigning Chart Trade Levels Boolean Value of 'true'
   Chart.CHART_SHOW_OHLC=(ulong)false;//Assigning Chart Open-High-Low-Close Boolean Value of 'false'
   Chart.CHART_SHOW_GRID=(ulong)false;//Assigning Chart Grid Boolean Value of 'false'
   Chart.CHART_SHOW_VOLUMES=(ulong)false;//Assigning Chart Volumes Boolean Value of 'false'
   Chart.CHART_SCALE=(ulong)3;//Assigning Chart Scale Boolean Value of '3'
   Chart.CHART_AUTOSCROLL=(ulong)true;//Assigning Chart Auto Scroll Boolean Value of 'true'
   Chart.CHART_SHIFT_SIZE=30;//Assigning Chart Shift Size Value of '30'
   Chart.CHART_SHIFT=(ulong)true;//Assigning Chart Shift Boolean Value of 'true'
   Chart.CHART_SHOW_ONE_CLICK=ulong(false);//Assigning Chart One Click Trading a value of 'false'
   ChartSet();//Calling Function to set chart format
  }
//+------------------------------------------------------------------+
