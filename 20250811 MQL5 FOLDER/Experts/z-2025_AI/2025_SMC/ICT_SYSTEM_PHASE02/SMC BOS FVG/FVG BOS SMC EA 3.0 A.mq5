//+------------------------------------------------------------------+
//|                                                   FVG SMC EA.mq5 |
//|      Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader. |
//|                           https://youtube.com/@ForexAlgo-Trader? |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, ALLAN MUNENE MUTIIRIA. #@Forex Algo-Trader"
#property link      "https://youtube.com/@ForexAlgo-Trader?"
#property version   "3.01"
/*
2024-01-30
 cross ref with nonfarm payrolls_validimir.mq5
 
 
added the trading of BMS into the codebase by 
using the free market indicator

Market\\Market Structures MT5
---TODO---------------------------------------
 GET BROADER UNDERSTANDING OF SILVERBULLET AND KILLZONES
 WORK IN NONFARMPAYROLL MECHANISMS fileref:nonfarm payrolls_validimir.mq5

--todo---
RESTRICT 1 ORDER BY DAY


if timer is off , adjust expiry time of the pending orders


change the amount of pending orders or open orders

when break of structure or change of character, adjust trades for FVG


*/

/*  reference: https://www.forexfactory.com/thread/1226510-13-ict-strategy-that-lets-you-work-and
incorporate fractal HIGHS and LOWS on the 4H
 TO INDICATE PREMIUM AND DISCOUNT
 guideline: only sell in premium and buy in discount

*/
#define FVG_Prefix "FVG REC "
#define CLR_UP clrLime
#define CLR_DOWN clrRed

//+------------------------------------------------------------------+
//| Enum Lor or Risk                                                 |
//+------------------------------------------------------------------+
enum ENUM_LOT_OR_RISK {
   lot = 0, // Constant lot
   risk = 1, // Risk in percent for a deal
};

#include <Trade/Trade.mqh>
CTrade obj_Trade;
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Expert\Money\MoneyFixedMargin.mqh>
CPositionInfo  m_position;                   // trade position object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
CDealInfo      m_deal;                       // deals object
COrderInfo     m_order;                      // pending orders object
CMoneyFixedMargin *m_money;
input group
"==========Strategies=========="
input bool tradeBoS = false; //Enable BOS Trade
 bool tradeFVG = true; //Enable FVG Trade
input bool tradeFVG_Market = false; //Enable Market Orders
input bool tradeFVG_Pending = true; //Enable Pending Orders
input group
"==========Settings control=========="
input group
"fvg"
input int minPts = 100;
input int FVG_Rec_Ext_Bars = 10;
input group
"pending orders"
bool     InpUseBuyStop           = true;        // Use Buy stop
input ushort   InpStopLossBuyStop      = 50;          // Stop Loss Buy stop, in pips (1.00045-1.00055=1 pips)
input ushort   InpTakeProfitBuyStop    = 800;         // Take Profit Buy stop, in pips (1.00045-1.00055=1 pips)
bool     InpUseSellStop          = true;        // Use Sell stop
input ushort   InpStopLossSellStop     = 50;          // Stop Loss Sell stop, in pips (1.00045-1.00055=1 pips)
input ushort   InpTakeProfitSellStop   = 800;         // Take Profit Sell stop, in pips (1.00045-1.00055=1 pips)
input group
"money management"
input ENUM_LOT_OR_RISK IntLotOrRisk    = risk;        // Money management: Lot OR Risk
input double   InpVolumeLotOrRisk      = 1.0;         // The value for "Money management"


input group
"==========Time control=========="
// sets the open hours for trading
input bool     InpTimeControl       = true;       // Use time control
input uchar    InpStartHour         = 14;          // Start Hour
input uchar    InpStartMinute       = 30;          // Start Minute
input uchar    InpEndHour           = 17;          // End Hour
input uchar    InpEndMinute         = 00;          // End Minute
ulong magicnumber = 8826736;
int Slippage = 4;

input group
"==========Other=========="
input bool     InpPrintLog             = true;       // Print log
input ushort   InpDistance = 30;     // Distance, in pips (1.00045-1.00055=1 pips)
input uchar    InpAllowableSpread       = 250;          // Allowable spread, in points (1.00045-1.00055=10 points)
input ushort   InpTrailingStop         = 30;          // Trailing Stop (min distance from price to Stop Loss, in pips
input ushort   InpTrailingStep         = 5;           // Trailing Step, in pips (1.00045-1.00055=1 pips)
input bool     isDebugging = false;

string totalFVGs[];
int barINDICES[];
datetime barTIMEs[];
bool signalFVGs[];
double minVolume;
//--market structure fields
int handleSMC_MS;
double UPBorder[];
double DOWNBorder[];
datetime openTimeUpBorder = 0;
datetime openTimeBuy = 0;
bool isNewBuySignal = false;
double openPriceUpBorder = 0;
datetime openTimeDOWNBorder = 0;
datetime openTimeSell = 0;
bool isNewSellSignal = false;
double openPriceDOWNBorder = 0;

double ExtIndentBuyStop       = 0.0;   // Indent Buy stop         -> double
double ExtStopLossBuyStop     = 0.0;   // Stop Loss Buy stop      -> double
double ExtTakeProfitBuyStop   = 0.0;   // Take Profit Buy stop    -> double
double ExtIndentSellStop      = 0.0;   // Indent Sell stop        -> double
double ExtStopLossSellStop    = 0.0;   // Stop Loss Sell stop     -> double
double ExtTakeProfitSellStop  = 0.0;   // Take Profit Sell stop   -> double
double ExtTrailingStop  = 0.0;               // Trailing Stop -> double
double ExtTrailingStep  = 0.0;               // Trailing Step -> double
double ExtDistance = 0.0;             // Distance      -> double
double m_adjusted_point;                     // point value adjusted for 3 or 5 points
bool   m_need_open_buy_stop      = false;
bool   m_need_open_sell_stop     = false;
bool   m_need_delete_all_stop    = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {

   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);
   RefreshRates();

   minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   //--- tuning for 3 or 5 digits
   int digits_adjust = 1;
   if(m_symbol.Digits() == 3 || m_symbol.Digits() == 5)
      digits_adjust = 10;
   m_adjusted_point = m_symbol.Point() * digits_adjust;
   ExtStopLossBuyStop      = InpStopLossBuyStop       * m_adjusted_point;
   ExtTakeProfitBuyStop    = InpTakeProfitBuyStop     * m_adjusted_point;

   ExtStopLossSellStop     = InpStopLossSellStop      * m_adjusted_point;
   ExtTakeProfitSellStop   = InpTakeProfitSellStop    * m_adjusted_point;

   ExtTrailingStop         = InpTrailingStop          * m_adjusted_point;
   ExtTrailingStep         = InpTrailingStep          * m_adjusted_point;

   ExtDistance = InpDistance             * m_adjusted_point;
   if(isDebugging) Print("Total visible bars on chart = ", visibleBars);
   if(ObjectsTotal(0, 0, OBJ_RECTANGLE) == 0) {
      Print("No FVGs Found, Resizing storage arrays to 0 now!!!");
      ArrayResize(totalFVGs, 0);
      ArrayResize(barINDICES, 0);
      ArrayResize(signalFVGs, 0);
   }
   ObjectsDeleteAll(0, FVG_Prefix);
   for(int i = 0; i <= visibleBars; i++) {
      //Print("Bar Index = ",i);
      double low0 = iLow(_Symbol, _Period, i);
      double high2 = iHigh(_Symbol, _Period, i + 2);
      double gap_L0_H2 = NormalizeDouble((low0 - high2) / _Point, _Digits);
      double high0 = iHigh(_Symbol, _Period, i);
      double low2 = iLow(_Symbol, _Period, i + 2);
      double gap_H0_L2 = NormalizeDouble((low2 - high0) / _Point, _Digits);
      bool FVG_UP = low0 > high2 && gap_L0_H2 > minPts;
      bool FVG_DOWN = low2 > high0 && gap_H0_L2 > minPts;

      if(FVG_UP || FVG_DOWN) {
         Print("Bar Index with FVG = ", i + 1);
         datetime time1 = iTime(_Symbol, _Period, i + 1);
         double price1 = FVG_UP ? high2 : high0;
         datetime time2 = time1 + PeriodSeconds(_Period) * FVG_Rec_Ext_Bars;
         double price2 = FVG_UP ? low0 : low2;
         string fvgNAME = FVG_Prefix + "(" + TimeToString(time1) + ")";
         color fvgClr = FVG_UP ? CLR_UP : CLR_DOWN;
         CreateRec(fvgNAME, time1, price1, time2, price2, fvgClr);
         if(isDebugging) Print("Old ArraySize = ", ArraySize(totalFVGs));
         ArrayResize(totalFVGs, ArraySize(totalFVGs) + 1);
         ArrayResize(barINDICES, ArraySize(barINDICES) + 1);
         if(isDebugging) Print("New ArraySize = ", ArraySize(totalFVGs));
         totalFVGs[ArraySize(totalFVGs) - 1] = fvgNAME;
         barINDICES[ArraySize(barINDICES) - 1] = i + 1;
         if(isDebugging) ArrayPrint(totalFVGs);
         if(isDebugging) ArrayPrint(barINDICES);
      }
   }
   for(int i = ArraySize(totalFVGs) - 1; i >= 0; i--) {
      string objName = totalFVGs[i];
      string fvgNAME = ObjectGetString(0, objName, OBJPROP_NAME);
      int barIndex = barINDICES[i];
      datetime timeSTART = (datetime)ObjectGetInteger(0, fvgNAME, OBJPROP_TIME, 0);
      datetime timeEND = (datetime)ObjectGetInteger(0, fvgNAME, OBJPROP_TIME, 1);
      double fvgLOW = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 0);
      double fvgHIGH = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 1);
      color fvgColor = (color)ObjectGetInteger(0, fvgNAME, OBJPROP_COLOR);
      if(isDebugging) Print("FVG NAME = ", fvgNAME, " >No: ", barIndex, " TS: ", timeSTART, " TE: ",
                               timeEND, " LOW: ", fvgLOW, " HIGH: ", fvgHIGH, " CLR = ", fvgColor);
      for(int k = barIndex - 1; k >= (barIndex - FVG_Rec_Ext_Bars); k--) {
         datetime barTime = iTime(_Symbol, _Period, k);
         double barLow = iLow(_Symbol, _Period, k);
         double barHigh = iHigh(_Symbol, _Period, k);
         //Print("Bar No: ",k," >Time: ",barTime," >H: ",barHigh," >L: ",barLow);
         if(k == 0) {
            if(isDebugging) Print("OverFlow Detected @ fvg ", fvgNAME);
            UpdateRec(fvgNAME, timeSTART, fvgLOW, barTime, fvgHIGH);
            break;
         }
         if((fvgColor == CLR_DOWN && barHigh > fvgHIGH) ||
               (fvgColor == CLR_UP && barLow < fvgLOW)
           ) {
            if(isDebugging) Print("Cut Off @ bar no: ", k, " of Time: ", barTime);
            UpdateRec(fvgNAME, timeSTART, fvgLOW, barTime, fvgHIGH);
            break;
         }
      }
   }
   ArrayResize(totalFVGs, 0);
   ArrayResize(barINDICES, 0);

   if(tradeBoS) {
      handleSMC_MS = iCustom(_Symbol, _Period, "Market\\Market Structures MT5");
      if (handleSMC_MS == INVALID_HANDLE) return (INIT_FAILED);
      ArraySetAsSeries(UPBorder, true);
      ArraySetAsSeries(DOWNBorder, true);
   }



   obj_Trade.SetExpertMagicNumber(magicnumber);
   obj_Trade.SetDeviationInPoints(Slippage);
   if(IsFillingTypeAllowed(m_symbol.Name(), SYMBOL_FILLING_FOK))
      obj_Trade.SetTypeFilling(ORDER_FILLING_FOK);
   else {
      if(IsFillingTypeAllowed(m_symbol.Name(), SYMBOL_FILLING_IOC))
         obj_Trade.SetTypeFilling(ORDER_FILLING_IOC);
      else
         obj_Trade.SetTypeFilling(ORDER_FILLING_RETURN);
   }
//--- check the input parameter "Lots"
   string err_text = "";
   if(IntLotOrRisk == lot) {
      if(!CheckVolumeValue(InpVolumeLotOrRisk, err_text)) {
         //--- when testing, we will only output to the log about incorrect input parameters
         if(MQLInfoInteger(MQL_TESTER)) {
            Print(__FUNCTION__, ", ERROR: ", err_text);
            return(INIT_FAILED);
         } else { // if the Expert Advisor is run on the chart, tell the user about the error
            Alert(__FUNCTION__, ", ERROR: ", err_text);
            return(INIT_PARAMETERS_INCORRECT);
         }
      }
   } else {
      if(m_money != NULL)
         delete m_money;
      m_money = new CMoneyFixedMargin;
      if(m_money != NULL) {
         if(!m_money.Init(GetPointer(m_symbol), Period(), m_symbol.Point()*digits_adjust))
            return(INIT_FAILED);
         m_money.Percent(InpVolumeLotOrRisk);
      } else {
         Print(__FUNCTION__, ", ERROR: Object CMoneyFixedMargin is NULL");
         return(INIT_FAILED);
      }
   }

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   IndicatorRelease(handleSMC_MS);
   if(m_money != NULL)
      delete m_money;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar() {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time = 0;
//--- current time
   datetime lastbar_time = (datetime)SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time == 0) {
      //--- set the time and exit
      last_time = lastbar_time;
      return(false);
   }

//--- if the time differs
   if(last_time != lastbar_time) {
      //--- memorize the time and return true
      last_time = lastbar_time;
      return(true);
   }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   if(!isNewBar())
      return;
   if(!TimeControlHourMinute()) {
      Comment(" *trading paused* waiting on " + (string)InpStartHour + ":" + (string)InpStartMinute);
      return;
   } else {
      Comment("");
   }
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   //dummy code to identify orderblock    20240207
   //if(highs[PERIOD_CURRENT] > highs[d0]) 
   //{
   //   datetime t = iBarShift(_Symbol, PERIOD_CURRENT, iTime(_Symbol, PERIOD_CURRENT, 0));
   //   drawLine(0, "BOS" + TimeToString(TimeCurrent()), OBJ_TREND, 0, bartime[d0], highs[d0], bartime[PERIOD_CURRENT] - 1, highs[d0], clrRed);
   //   break;
   //}
   
   if(tradeBoS) {
      CopyBuffer(handleSMC_MS, 0, 0, 6, UPBorder);
      CopyBuffer(handleSMC_MS, 1, 0, 6, DOWNBorder);

      if (UPBorder[5] > 0 &&
            openTimeUpBorder != iTime(_Symbol, _Period, 5)) {
         if(isDebugging) Print("__________NEW UP BORDER ARROW FORMED_______");
         openTimeUpBorder = iTime(_Symbol, _Period, 5);
         openPriceUpBorder = UPBorder[5];
         if(isDebugging) Print("UP BORDER TIME = ", openTimeUpBorder, ", PRICE = ", openPriceUpBorder);
         isNewBuySignal = true;
      } else if (DOWNBorder[5] > 0 && openTimeDOWNBorder != iTime(_Symbol, _Period, 5)) {
         if(isDebugging) Print("__________NEW DOWN BORDER ARROW FORMED_______");
         openTimeDOWNBorder = iTime(_Symbol, _Period, 5);
         openPriceDOWNBorder = DOWNBorder[5];
         if(isDebugging) Print("DOWN BORDER TIME = ", openTimeDOWNBorder, ", PRICE = ", openPriceDOWNBorder);
         isNewSellSignal = true;
      }
   }

   //FVG ONLY
   for(int i = 0; i <= FVG_Rec_Ext_Bars; i++) {


      double low0 = iLow(_Symbol, _Period, i + 1);
      double high2 = iHigh(_Symbol, _Period, i + 2 + 1);
      double gap_L0_H2 = NormalizeDouble((low0 - high2) / _Point, _Digits);
      double high0 = iHigh(_Symbol, _Period, i + 1);
      double low2 = iLow(_Symbol, _Period, i + 2 + 1);
      double gap_H0_L2 = NormalizeDouble((low2 - high0) / _Point, _Digits);
      bool FVG_UP = low0 > high2 && gap_L0_H2 > minPts;
      bool FVG_DOWN = low2 > high0 && gap_H0_L2 > minPts;


      if(FVG_UP || FVG_DOWN) {
         datetime time1 = iTime(_Symbol, _Period, i + 1 + 1);
         double price1 = FVG_UP ? high2 : high0;
         datetime time2 = time1 + PeriodSeconds(_Period) * FVG_Rec_Ext_Bars;
         double price2 = FVG_UP ? low0 : low2;
         string fvgNAME = FVG_Prefix + "(" + TimeToString(time1) + ")";
         color fvgClr = FVG_UP ? CLR_UP : CLR_DOWN;


         if(ObjectFind(0, fvgNAME) < 0) {
            CreateRec(fvgNAME, time1, price1, time2, price2, fvgClr);
            if(isDebugging) Print("Old ArraySize = ", ArraySize(totalFVGs));
            ArrayResize(totalFVGs, ArraySize(totalFVGs) + 1);
            ArrayResize(barTIMEs, ArraySize(barTIMEs) + 1);
            ArrayResize(signalFVGs, ArraySize(signalFVGs) + 1);
            if(isDebugging) Print("New ArraySize = ", ArraySize(totalFVGs));
            totalFVGs[ArraySize(totalFVGs) - 1] = fvgNAME;
            barTIMEs[ArraySize(barTIMEs) - 1] = time1;
            signalFVGs[ArraySize(signalFVGs) - 1] = false;
            if(isDebugging) ArrayPrint(totalFVGs);
            if(isDebugging) ArrayPrint(barTIMEs);
            if(isDebugging) ArrayPrint(signalFVGs);
         }
      }
   }
   for(int j = ArraySize(totalFVGs) - 1; j >= 0; j--) {
      bool fvgExist = false;
      string objName = totalFVGs[j];
      string fvgNAME = ObjectGetString(0, objName, OBJPROP_NAME);
      double fvgLow = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 0);
      double fvgHigh = ObjectGetDouble(0, fvgNAME, OBJPROP_PRICE, 1);
      color fvgColor = (color)ObjectGetInteger(0, fvgNAME, OBJPROP_COLOR);


      for(int k = 1; k <= FVG_Rec_Ext_Bars; k++) {
         double barLow = iLow(_Symbol, _Period, k);
         double barHigh = iHigh(_Symbol, _Period, k);
         if(barHigh == fvgLow || barLow == fvgLow) {
            //Print("Found: ",fvgNAME," @ bar ",k);
            fvgExist = true;
            break;
         }
      }
      //Print("Existence of ",fvgNAME," = ",fvgExist);

      //bearish fair value gap
      if(fvgColor == CLR_DOWN && tradeFVG_Market && Bid > fvgHigh && !signalFVGs[j]) {
         if(isDebugging) Print("SELL SIGNAL For (", fvgNAME, ") Now @ ", Bid);
         
         //if(tradeFVG_Market) {
            PerformTrade(ORDER_TYPE_SELL, Bid, fvgHigh, fvgLow,"FVG_MARKETSELL");//obj_Trade.Sell(minVolume, _Symbol, Bid, 0, fvgLow);
         //}
         signalFVGs[j] = true;
         if(isDebugging) ArrayPrint(totalFVGs, _Digits, " [< >] ");
         if(isDebugging) ArrayPrint(signalFVGs, _Digits, " [< >] ");
         //bullish fair value gap
      } else if(fvgColor == CLR_UP && tradeFVG_Market && Ask < fvgLow && !signalFVGs[j]) {
         if(isDebugging) Print("BUY SIGNAL For (", fvgNAME, ") Now @ ", Ask);
         //if(tradeFVG_Market) {
            PerformTrade(ORDER_TYPE_BUY, Ask, fvgLow, fvgHigh,"FVG_MARKETBUY");//obj_Trade.Buy(minVolume, _Symbol, Ask, 0, fvgHigh);
         //}
         signalFVGs[j] = true;
         if(isDebugging) ArrayPrint(totalFVGs, _Digits, " [< >] ");
         if(isDebugging) ArrayPrint(signalFVGs, _Digits, " [< >] ");
      } else if(fvgColor == CLR_UP && tradeFVG_Pending && !signalFVGs[j]) {
         if(isDebugging) Print("BUY SIGNAL For (", fvgNAME, ") Now @ ", Ask);
         //if(tradeFVG) {
            PerformTrade(ORDER_TYPE_BUY_LIMIT
                         , fvgHigh//PRICE
                         , fvgLow//SL
                         , fvgHigh + ExtTakeProfitBuyStop,"FVG_PENDINGBUY" );//TP 
                         //obj_Trade.Buy(minVolume, _Symbol, Ask, 0, fvgHigh);
         //}
         signalFVGs[j] = true;
         if(isDebugging) ArrayPrint(totalFVGs, _Digits, " [< >] ");
         if(isDebugging) ArrayPrint(signalFVGs, _Digits, " [< >] ");
      } else if(fvgColor == CLR_DOWN && tradeFVG_Pending && !signalFVGs[j]) {
         if(isDebugging) Print("SELL SIGNAL For (", fvgNAME, ") Now @ ", Bid);
         //if(tradeFVG) {
            PerformTrade(ORDER_TYPE_SELL_LIMIT
                         , fvgLow  //PRICE
                         , fvgHigh //SL
                         , fvgLow - ExtTakeProfitSellStop,"FVG_PENDINGSELL");//TP
                         //obj_Trade.Sell(minVolume, _Symbol, Bid, 0, fvgLow);
         //}
         signalFVGs[j] = true;
         if(isDebugging) ArrayPrint(totalFVGs, _Digits, " [< >] ");
         if(isDebugging) ArrayPrint(signalFVGs, _Digits, " [< >] ");
         //bullish fair value gap
      }


      if(fvgExist == false) {
         bool removeName = ArrayRemove(totalFVGs, 0, 1);
         bool removeTime = ArrayRemove(barTIMEs, 0, 1);
         bool removeSignal = ArrayRemove(signalFVGs, 0, 1);
         if(removeName && removeTime && removeSignal) {
            if(isDebugging) Print("Success removing the FVG DATA from the arrays. New Data as Below:");
            if(isDebugging) Print("FVGs: ", ArraySize(totalFVGs), " TIMEs: ", ArraySize(barTIMEs),
                                     " SIGNALs: ", ArraySize(signalFVGs));
            if(isDebugging) ArrayPrint(totalFVGs);
            if(isDebugging) ArrayPrint(barTIMEs);
            if(isDebugging) ArrayPrint(signalFVGs);
         }
      }
   }
   //BOS ONLY
   if (openPriceUpBorder > 0 && Bid >= openPriceUpBorder && openTimeBuy != iTime(_Symbol, _Period, 0) && isNewBuySignal) {
      if(isDebugging) Print(" >>>>>>>>>>>>>>> (BOS) BUY NOW <<<<<<<<<<<<<");
      if(tradeBoS) {
         //obj_Trade.Buy(minVolume, _Symbol, Ask, 0, Bid + 100 * _Point);
         PerformTrade(ORDER_TYPE_BUY, Ask, 0, Bid + 100 * _Point,"BOS_BUY");
      }
      openTimeBuy = iTime(_Symbol, _Period, 0);
      isNewBuySignal = false;
   } else if (openPriceDOWNBorder > 0 && Ask <= openPriceDOWNBorder && openTimeSell != iTime(_Symbol, _Period, 0) && isNewSellSignal) {
      if(isDebugging) Print(" >>>>>>>>>>>>>>> (BOS) SELL NOW <<<<<<<<<<<<<");
      if(tradeBoS) {
         //obj_Trade.Sell(minVolume, _Symbol, Bid, 0, Ask - 100 * _Point);
         PerformTrade(ORDER_TYPE_SELL, Bid, 0, Ask - 100 * _Point,"BOS_SELL");
      }
      openTimeSell = iTime(_Symbol, _Period, 0);
      isNewSellSignal = false;
   }

}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateRec(string objName, datetime time1, double price1,
               datetime time2, double price2, color clr) {
   if(ObjectFind(0, objName) < 0) {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateRec(string objName, datetime time1, double price1,
               datetime time2, double price2) {
   if(ObjectFind(0, objName) >= 0) {
      ObjectSetInteger(0, objName, OBJPROP_TIME, 0, time1);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, price1);
      ObjectSetInteger(0, objName, OBJPROP_TIME, 1, time2);
      ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, price2);
      ChartRedraw(0);
   }
}
//+------------------------------------------------------------------+
bool TimeControlHourMinute(void) {
   if(!InpTimeControl)
      return(true);

   MqlDateTime STimeCurrent;
   datetime time_current = TimeCurrent();
   if(time_current == D'1970.01.01 00:00')
      return(false);
   TimeToStruct(time_current, STimeCurrent);
   if((InpStartHour * 60 * 60 + InpStartMinute * 60) < (InpEndHour * 60 * 60 + InpEndMinute * 60)) { // intraday time interval
      /*
      Example:
      input uchar    InpStartHour      = 5;        // Start hour
      input uchar    InpEndHour        = 10;       // End hour
      0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
      _  _  _  _  _  +  +  +  +  +  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  +  +  +  +  +  _  _  _  _  _  _
      */
      if((STimeCurrent.hour * 60 * 60 + STimeCurrent.min * 60 >= InpStartHour * 60 * 60 + InpStartMinute * 60) &&
            (STimeCurrent.hour * 60 * 60 + STimeCurrent.min * 60 < InpEndHour * 60 * 60 + InpEndMinute * 60))
         return(true);
   } else if((InpStartHour * 60 * 60 + InpStartMinute * 60) > (InpEndHour * 60 * 60 + InpEndMinute * 60)) { // time interval with the transition in a day
      /*
      Example:
      input uchar    InpStartHour      = 10;       // Start hour
      input uchar    InpEndHour        = 5;        // End hour
      0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21 22 23 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
      _  _  _  _  _  _  _  _  _  _  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  +  _  _  _  _  _  +  +  +  +  +  +
      */
      if(STimeCurrent.hour * 60 * 60 + STimeCurrent.min * 60 >= InpStartHour * 60 * 60 + InpStartMinute * 60 ||
            STimeCurrent.hour * 60 * 60 + STimeCurrent.min * 60 < InpEndHour * 60 * 60 + InpEndMinute * 60)
         return(true);
   } else
      return(false);
//---
   return(false);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(string symbol, int fill_type) {
//--- Obtain the value of the property that describes allowed filling modes
   int filling = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed
   return((filling & fill_type) == fill_type);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check the correctness of the position volume                     |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume, string &error_description) {
//--- minimal allowed volume for trade operations
   double min_volume = m_symbol.LotsMin();
   if(volume < min_volume) {
      if(TerminalInfoString(TERMINAL_LANGUAGE) == "Russian")
         error_description = StringFormat("Объем меньше минимально допустимого SYMBOL_VOLUME_MIN=%.2f", min_volume);
      else
         error_description = StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f", min_volume);
      return(false);
   }
//--- maximal allowed volume of trade operations
   double max_volume = m_symbol.LotsMax();
   if(volume > max_volume) {
      if(TerminalInfoString(TERMINAL_LANGUAGE) == "Russian")
         error_description = StringFormat("Объем больше максимально допустимого SYMBOL_VOLUME_MAX=%.2f", max_volume);
      else
         error_description = StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f", max_volume);
      return(false);
   }
//--- get minimal step of volume changing
   double volume_step = m_symbol.LotsStep();
   int ratio = (int)MathRound(volume / volume_step);
   if(MathAbs(ratio * volume_step - volume) > 0.0000001) {
      if(TerminalInfoString(TERMINAL_LANGUAGE) == "Russian")
         error_description = StringFormat("Объем не кратен минимальному шагу SYMBOL_VOLUME_STEP=%.2f, ближайший правильный объем %.2f",
                                          volume_step, ratio * volume_step);
      else
         error_description = StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                          volume_step, ratio * volume_step);
      return(false);
   }
   error_description = "Correct volume value";
   return(true);
}

//+------------------------------------------------------------------+
//| Check Freeze and Stops levels                                    |
//+------------------------------------------------------------------+
bool FreezeStopsLevels(double &level) {
//--- check Freeze and Stops levels
   /*
      Type of order/position  |  Activation price  |  Check
      ------------------------|--------------------|--------------------------------------------
      Buy Limit order         |  Ask               |  Ask-OpenPrice  >= SYMBOL_TRADE_FREEZE_LEVEL
      Buy Stop order          |  Ask             |  OpenPrice-Ask  >= SYMBOL_TRADE_FREEZE_LEVEL
      Sell Limit order        |  Bid             |  OpenPrice-Bid  >= SYMBOL_TRADE_FREEZE_LEVEL
      Sell Stop order       |  Bid             |  Bid-OpenPrice  >= SYMBOL_TRADE_FREEZE_LEVEL
      Buy position            |  Bid             |  TakeProfit-Bid >= SYMBOL_TRADE_FREEZE_LEVEL
                              |                    |  Bid-StopLoss   >= SYMBOL_TRADE_FREEZE_LEVEL
      Sell position           |  Ask             |  Ask-TakeProfit >= SYMBOL_TRADE_FREEZE_LEVEL
                              |                    |  StopLoss-Ask   >= SYMBOL_TRADE_FREEZE_LEVEL

      Buying is done at the Ask price                 |  Selling is done at the Bid price
      ------------------------------------------------|----------------------------------
      TakeProfit        >= Bid                        |  TakeProfit        <= Ask
      StopLoss          <= Bid                      |  StopLoss          >= Ask
      TakeProfit - Bid  >= SYMBOL_TRADE_STOPS_LEVEL   |  Ask - TakeProfit  >= SYMBOL_TRADE_STOPS_LEVEL
      Bid - StopLoss    >= SYMBOL_TRADE_STOPS_LEVEL   |  StopLoss - Ask    >= SYMBOL_TRADE_STOPS_LEVEL
   */
   if(!RefreshRates() || !m_symbol.Refresh())
      return(false);
//--- FreezeLevel -> for pending order and modification
   double freeze_level = m_symbol.FreezeLevel() * m_symbol.Point();
   if(freeze_level == 0.0)
      freeze_level = (m_symbol.Ask() - m_symbol.Bid()) * 3.0;
   freeze_level *= 1.1;
//--- StopsLevel -> for TakeProfit and StopLoss
   double stop_level = m_symbol.StopsLevel() * m_symbol.Point();
   if(stop_level == 0.0)
      stop_level = (m_symbol.Ask() - m_symbol.Bid()) * 3.0;
   stop_level *= 1.1;

   if(freeze_level <= 0.0 || stop_level <= 0.0)
      return(false);

   level = (freeze_level > stop_level) ? freeze_level : stop_level;
//---
   return(true);
}

////+------------------------------------------------------------------+
////| Place Orders                                                     |
////+------------------------------------------------------------------+
//void PlaceOrders(const ENUM_ORDER_TYPE order_type, const double level) {
//   if(m_symbol.Ask() - m_symbol.Bid() > InpAllowableSpread * m_symbol.Point())
//      return;
////--- check Freeze and Stops levels
//   /*
//      Type of order/position  |  Activation price  |  Check
//      ------------------------|--------------------|--------------------------------------------
//      Buy Limit order         |  Ask               |  Ask-OpenPrice  >= SYMBOL_TRADE_FREEZE_LEVEL
//      Buy Stop order          |  Ask             |  OpenPrice-Ask  >= SYMBOL_TRADE_FREEZE_LEVEL
//      Sell Limit order        |  Bid             |  OpenPrice-Bid  >= SYMBOL_TRADE_FREEZE_LEVEL
//      Sell Stop order       |  Bid             |  Bid-OpenPrice  >= SYMBOL_TRADE_FREEZE_LEVEL
//      Buy position            |  Bid             |  TakeProfit-Bid >= SYMBOL_TRADE_FREEZE_LEVEL
//                              |                    |  Bid-StopLoss   >= SYMBOL_TRADE_FREEZE_LEVEL
//      Sell position           |  Ask             |  Ask-TakeProfit >= SYMBOL_TRADE_FREEZE_LEVEL
//                              |                    |  StopLoss-Ask   >= SYMBOL_TRADE_FREEZE_LEVEL
//
//      Buying is done at the Ask price                 |  Selling is done at the Bid price
//      ------------------------------------------------|----------------------------------
//      TakeProfit        >= Bid                        |  TakeProfit        <= Ask
//      StopLoss          <= Bid                      |  StopLoss          >= Ask
//      TakeProfit - Bid  >= SYMBOL_TRADE_STOPS_LEVEL   |  Ask - TakeProfit  >= SYMBOL_TRADE_STOPS_LEVEL
//      Bid - StopLoss    >= SYMBOL_TRADE_STOPS_LEVEL   |  StopLoss - Ask    >= SYMBOL_TRADE_STOPS_LEVEL
//   */
////--- buy stop
//   if(order_type == ORDER_TYPE_BUY_STOP) {
//
//      double price = m_symbol.Ask() + ExtDistance;
//      if(price - m_symbol.Ask() < level) // check price
//         price = m_symbol.Ask() + level;
//
//      double sl = (ExtStopLossBuyStop == 0) ? 0.0 : price - ExtStopLossBuyStop;
//      if(sl != 0.0 && ExtStopLossBuyStop < level) // check sl
//         sl = price - level;
//
//      double tp = (ExtTakeProfitBuyStop == 0) ? 0.0 : price + ExtTakeProfitBuyStop;
//      if(tp != 0.0 && ExtTakeProfitBuyStop < level) // check price
//         tp = price + level;
//
//      PendingOrder(ORDER_TYPE_BUY_STOP, price, sl, tp);
//   }
////--- sell stop
//   if(order_type == ORDER_TYPE_SELL_STOP) {
//      double price = m_symbol.Bid() - ExtDistance;
//      if(m_symbol.Bid() - price < level) // check price
//         price = m_symbol.Bid() - level;
//
//      double sl = (ExtStopLossSellStop == 0) ? 0.0 : price + ExtStopLossSellStop;
//      if(sl != 0.0 && ExtStopLossSellStop < level) // check sl
//         sl = price + level;
//
//      double tp = (ExtTakeProfitSellStop == 0) ? 0.0 : price - ExtTakeProfitSellStop;
//      if(tp != 0.0 && ExtTakeProfitSellStop < level) // check tp
//         tp = price - level;
//
//      PendingOrder(ORDER_TYPE_SELL_STOP, price, sl, tp);
//   }
//}
//+------------------------------------------------------------------+
//| Pending order                                                    |
//+------------------------------------------------------------------+
bool PendingOrder(ENUM_ORDER_TYPE order_type, double price, double sl, double tp) {
   sl = m_symbol.NormalizePrice(sl);
   tp = m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   ENUM_ORDER_TYPE check_order_type = -1;
   switch(order_type) {
   case  ORDER_TYPE_BUY:
      check_order_type = ORDER_TYPE_BUY;
      break;
   case ORDER_TYPE_SELL:
      check_order_type = ORDER_TYPE_SELL;
      break;
   case ORDER_TYPE_BUY_LIMIT:
      check_order_type = ORDER_TYPE_BUY_LIMIT;
      break;
   case ORDER_TYPE_SELL_LIMIT:
      check_order_type = ORDER_TYPE_SELL_LIMIT;
      break;
   case ORDER_TYPE_BUY_STOP:
      check_order_type = ORDER_TYPE_BUY_STOP;
      break;
   case ORDER_TYPE_SELL_STOP:
      check_order_type = ORDER_TYPE_SELL_STOP;
      break;
   default:
      return(false);
      break;
   }
//---
   double long_lot = 0.0;
   double short_lot = 0.0;
   if(IntLotOrRisk == risk) {
      bool error = false;
      long_lot = m_money.CheckOpenLong(m_symbol.Ask(), sl);
      if(InpPrintLog)
         Print("sl=", DoubleToString(sl, m_symbol.Digits()),
               ", CheckOpenLong: ", DoubleToString(long_lot, 2),
               ", Balance: ",    DoubleToString(m_account.Balance(), 2),
               ", Equity: ",     DoubleToString(m_account.Equity(), 2),
               ", FreeMargin: ", DoubleToString(m_account.FreeMargin(), 2));
      if(long_lot == 0.0) {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CheckOpenLong returned the value of \"0.0\"");
         error = true;
      }
      //---
      short_lot = m_money.CheckOpenShort(m_symbol.Bid(), sl);
      if(InpPrintLog)
         Print("sl=", DoubleToString(sl, m_symbol.Digits()),
               ", CheckOpenLong: ", DoubleToString(short_lot, 2),
               ", Balance: ",    DoubleToString(m_account.Balance(), 2),
               ", Equity: ",     DoubleToString(m_account.Equity(), 2),
               ", FreeMargin: ", DoubleToString(m_account.FreeMargin(), 2));
      if(short_lot == 0.0) {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CheckOpenShort returned the value of \"0.0\"");
         error = true;
      }
      //---
      if(error)
         return(false);
   } else if(IntLotOrRisk == lot) {
      long_lot = InpVolumeLotOrRisk;
      short_lot = InpVolumeLotOrRisk;
   } else
      return(false);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   double check_price = 0;
   double check_lot = 0;
   if(check_order_type == ORDER_TYPE_BUY) {
      check_price = m_symbol.Ask();
      check_lot = long_lot;
   } else if(check_order_type == ORDER_TYPE_SELL) {
      check_price = m_symbol.Bid();
      check_lot = short_lot;
   }
//---
   if(m_symbol.LotsLimit() > 0.0) {
      double volume_buys        = 0.0;
      double volume_sells       = 0.0;
      double volume_buy_limits  = 0.0;
      double volume_sell_limits = 0.0;
      double volume_buy_stops   = 0.0;
      double volume_sell_stops  = 0.0;
      CalculateAllVolumes(volume_buys, volume_sells,
                          volume_buy_limits, volume_sell_limits,
                          volume_buy_stops, volume_sell_stops);
      if(volume_buys + volume_sells + volume_buy_limits + volume_sell_limits + volume_buy_stops + volume_sell_stops + check_lot > m_symbol.LotsLimit()) {
         if(InpPrintLog)
            Print("#0 ,", EnumToString(order_type), ", ",
                  "Volume Buy's (", DoubleToString(volume_buys, 2), ")",
                  "Volume Sell's (", DoubleToString(volume_sells, 2), ")",
                  "Volume Buy limit's (", DoubleToString(volume_buy_limits, 2), ")",
                  "Volume Sell limit's (", DoubleToString(volume_sell_limits, 2), ")",
                  "Volume Buy stops's (", DoubleToString(volume_buy_stops, 2), ")",
                  "Volume Sell stops's (", DoubleToString(volume_sell_stops, 2), ")",
                  "Check lot (", DoubleToString(check_lot, 2), ")",
                  " > Lots Limit (", DoubleToString(m_symbol.LotsLimit(), 2), ")");
         return(false);
      }
   }
//---
   double free_margin_check = m_account.FreeMarginCheck(m_symbol.Name(), check_order_type, check_lot, check_price);
   if(free_margin_check > 0.0) {
      if(obj_Trade.OrderOpen(m_symbol.Name(), order_type, check_lot, 0.0, m_symbol.NormalizePrice(price), m_symbol.NormalizePrice(sl), m_symbol.NormalizePrice(tp), ORDER_TIME_GTC)) {
         if(obj_Trade.ResultOrder() == 0) {
            if(InpPrintLog)
               Print("#1 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(),
                     ", description of result: ", obj_Trade.ResultRetcodeDescription());
            if(InpPrintLog)
               PrintResultTrade(obj_Trade, m_symbol);
            return(false);
         } else {
            if(InpPrintLog)
               Print("#2 ", EnumToString(order_type), " -> true. Result Retcode: ", obj_Trade.ResultRetcode(),
                     ", description of result: ", obj_Trade.ResultRetcodeDescription());
            if(InpPrintLog)
               PrintResultTrade(obj_Trade, m_symbol);
            return(true);
         }
      } else {
         if(InpPrintLog)
            Print("#3 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(),
                  ", description of result: ", obj_Trade.ResultRetcodeDescription());
         if(InpPrintLog)
            PrintResultTrade(obj_Trade, m_symbol);
         return(false);
      }
   } else {
      if(InpPrintLog)
         Print(__FUNCTION__, ", ERROR: method CAccountInfo::FreeMarginCheck returned the value ", DoubleToString(free_margin_check, 2));
      return(false);
   }
//---
   return(false);
}

//+------------------------------------------------------------------+
//| Pending order                                                    |
//+------------------------------------------------------------------+
bool PerformTrade(ENUM_ORDER_TYPE order_type, double price, double sl, double tp,string TRADECOMMENT) {
   Print("_____________________________");
   Print("try to perform");
   Print("_____________________________");
   sl = m_symbol.NormalizePrice(sl);
   tp = m_symbol.NormalizePrice(tp);
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   ENUM_ORDER_TYPE check_order_type = -1;
   switch(order_type) {
   case  ORDER_TYPE_BUY:
      check_order_type = ORDER_TYPE_BUY;
      break;
   case ORDER_TYPE_SELL:
      check_order_type = ORDER_TYPE_SELL;
      break;
   case ORDER_TYPE_BUY_LIMIT:
      check_order_type = ORDER_TYPE_BUY_LIMIT;
      break;
   case ORDER_TYPE_SELL_LIMIT:
      check_order_type = ORDER_TYPE_SELL_LIMIT;
      break;
   case ORDER_TYPE_BUY_STOP:
      check_order_type = ORDER_TYPE_BUY_STOP;
      break;
   case ORDER_TYPE_SELL_STOP:
      check_order_type = ORDER_TYPE_SELL_STOP;
      break;
   default:
      return(false);
      break;
   }
//---
   double long_lot = 0.0;
   double short_lot = 0.0;

   Print("testing lotorrisk is RISK");
   if(IntLotOrRisk == risk) {
      bool error = false;
      long_lot = m_money.CheckOpenLong(m_symbol.Ask(), sl);
      if(InpPrintLog)
         Print("sl=", DoubleToString(sl, m_symbol.Digits()),
               ", CheckOpenLong: ", DoubleToString(long_lot, 2),
               ", Balance: ",    DoubleToString(m_account.Balance(), 2),
               ", Equity: ",     DoubleToString(m_account.Equity(), 2),
               ", FreeMargin: ", DoubleToString(m_account.FreeMargin(), 2));
      if(long_lot == 0.0) {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CheckOpenLong returned the value of \"0.0\"");
         error = true;
      }
      //---
      short_lot = m_money.CheckOpenShort(m_symbol.Bid(), sl);
      if(InpPrintLog)
         Print("sl=", DoubleToString(sl, m_symbol.Digits()),
               ", CheckOpenLong: ", DoubleToString(short_lot, 2),
               ", Balance: ",    DoubleToString(m_account.Balance(), 2),
               ", Equity: ",     DoubleToString(m_account.Equity(), 2),
               ", FreeMargin: ", DoubleToString(m_account.FreeMargin(), 2));
      if(short_lot == 0.0) {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CheckOpenShort returned the value of \"0.0\"");
         error = true;
      }
      //---
      if(error)
         return(false);
   } else if(IntLotOrRisk == lot) {
      Print("IntLotOrRisk == lot");
      long_lot = InpVolumeLotOrRisk;
      short_lot = InpVolumeLotOrRisk;
   } else {
      Print("RETURNING FALSE");
      return(false);
   }

   if((check_order_type == ORDER_TYPE_BUY) || (check_order_type == ORDER_TYPE_SELL)) {
      //--- check volume before OrderSend to avoid "not enough money" error (CTrade)
      double check_price = 0;
      double check_lot = 0;

      Print("BEFORE CHECKING FOR BUY");
      if(check_order_type == ORDER_TYPE_BUY) {
         check_price = m_symbol.Ask();
         check_lot = long_lot;
      } else if(check_order_type == ORDER_TYPE_SELL) {
         check_price = m_symbol.Bid();
         check_lot = short_lot;
      }

      if(m_symbol.LotsLimit() > 0.0) {
         Print("m_symbol.LotsLimit() > 0.0");
         double volume_buys        = 0.0;
         double volume_sells       = 0.0;
         double volume_buy_limits  = 0.0;
         double volume_sell_limits = 0.0;
         double volume_buy_stops   = 0.0;
         double volume_sell_stops  = 0.0;
         CalculateAllVolumes(volume_buys, volume_sells, volume_buy_limits, volume_sell_limits, volume_buy_stops, volume_sell_stops);
         if(volume_buys + volume_sells + volume_buy_limits + volume_sell_limits + volume_buy_stops + volume_sell_stops + check_lot > m_symbol.LotsLimit()) {
            if(InpPrintLog)
               Print("#0 ,", EnumToString(order_type), ", ",               "Volume Buy's (", DoubleToString(volume_buys, 2), ")",                  "Volume Sell's (", DoubleToString(volume_sells, 2), ")",                  "Volume Buy limit's (", DoubleToString(volume_buy_limits, 2), ")",  "Volume Sell limit's (", DoubleToString(volume_sell_limits, 2), ")",                  "Volume Buy stops's (", DoubleToString(volume_buy_stops, 2), ")",   "Volume Sell stops's (", DoubleToString(volume_sell_stops, 2), ")",                  "Check lot (", DoubleToString(check_lot, 2), ")",                  " > Lots Limit (", DoubleToString(m_symbol.LotsLimit(), 2), ")");
            return(false);
         }
      }

      double free_margin_check = m_account.FreeMarginCheck(m_symbol.Name(), check_order_type, check_lot, check_price);
      if(free_margin_check > 0.0) {
         Print("free_margin_check > 0.0");
         if(obj_Trade.PositionOpen(m_symbol.Name(), order_type, check_lot, m_symbol.NormalizePrice(price), m_symbol.NormalizePrice(sl), m_symbol.NormalizePrice(tp),TRADECOMMENT)) {
            if(obj_Trade.ResultOrder() == 0) {
               if(InpPrintLog)
                  Print("#1 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
               if(InpPrintLog)
                  PrintResultTrade(obj_Trade, m_symbol);
               return(false);
            } else {
               if(InpPrintLog)
                  Print("#2 ", EnumToString(order_type), " -> true. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
               if(InpPrintLog)
                  PrintResultTrade(obj_Trade, m_symbol);
               return(true);
            }
         } else {
            if(InpPrintLog)
               Print("#3 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
            if(InpPrintLog)
               PrintResultTrade(obj_Trade, m_symbol);
            return(false);
         }
      } else {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CAccountInfo::FreeMarginCheck returned the value ", DoubleToString(free_margin_check, 2));
         return(false);
      }
   }//(check_order_type == ORDER_TYPE_BUY) || (check_order_type == ORDER_TYPE_SELL)


   //routines for pending orders   TODO
   if((check_order_type == ORDER_TYPE_BUY_LIMIT) || (check_order_type == ORDER_TYPE_SELL_LIMIT) || (check_order_type == ORDER_TYPE_BUY_STOP) || (check_order_type == ORDER_TYPE_SELL_STOP)) {
      //--- check volume before OrderSend to avoid "not enough money" error (CTrade)
      double check_price = 0;
      double check_lot = 0;


      if((check_order_type == ORDER_TYPE_BUY_LIMIT) || (check_order_type == ORDER_TYPE_BUY_STOP)) {
         check_price = m_symbol.NormalizePrice(price); //FVGHIGH
         check_lot = long_lot;
      } else if((check_order_type == ORDER_TYPE_SELL_LIMIT) || (check_order_type == ORDER_TYPE_SELL_STOP)) {
         check_price = m_symbol.NormalizePrice(price);//FVGLOW
         check_lot = short_lot;
      }

      if(m_symbol.LotsLimit() > 0.0) {
         Print("m_symbol.LotsLimit() > 0.0");
         double volume_buys        = 0.0;
         double volume_sells       = 0.0;
         double volume_buy_limits  = 0.0;
         double volume_sell_limits = 0.0;
         double volume_buy_stops   = 0.0;
         double volume_sell_stops  = 0.0;
         CalculateAllVolumes(volume_buys, volume_sells, volume_buy_limits, volume_sell_limits, volume_buy_stops, volume_sell_stops);
         if(volume_buys + volume_sells + volume_buy_limits + volume_sell_limits + volume_buy_stops + volume_sell_stops + check_lot > m_symbol.LotsLimit()) {
            if(InpPrintLog)
               Print("#0 ,", EnumToString(order_type), ", ",               "Volume Buy's (", DoubleToString(volume_buys, 2), ")",                  "Volume Sell's (", DoubleToString(volume_sells, 2), ")",                  "Volume Buy limit's (", DoubleToString(volume_buy_limits, 2), ")",  "Volume Sell limit's (", DoubleToString(volume_sell_limits, 2), ")",                  "Volume Buy stops's (", DoubleToString(volume_buy_stops, 2), ")",   "Volume Sell stops's (", DoubleToString(volume_sell_stops, 2), ")",                  "Check lot (", DoubleToString(check_lot, 2), ")",                  " > Lots Limit (", DoubleToString(m_symbol.LotsLimit(), 2), ")");
            return(false);
         }
      }
      MqlDateTime str1;
      TimeToStruct(TimeCurrent(), str1);
      MqlDateTime SValidity = str1;
      SValidity.hour = InpEndHour;
      SValidity.min = InpEndMinute;
      datetime validity = StructToTime(SValidity);

      double free_margin_check = m_account.FreeMarginCheck(m_symbol.Name(), check_order_type, check_lot, check_price);
      if(free_margin_check > 0.0) {
         Print("free_margin_check > 0.0");
         if(obj_Trade.OrderOpen(m_symbol.Name(), order_type, check_lot, 0.0, m_symbol.NormalizePrice(price)
                                , m_symbol.NormalizePrice(sl)
                                , m_symbol.NormalizePrice(tp),
                                ORDER_TIME_SPECIFIED, validity,TRADECOMMENT)) {
            if(obj_Trade.ResultOrder() == 0) {
               if(InpPrintLog)
                  Print("#1 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
               if(InpPrintLog)
                  PrintResultTrade(obj_Trade, m_symbol);
               return(false);
            } else {
               if(InpPrintLog)
                  Print("#2 ", EnumToString(order_type), " -> true. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
               if(InpPrintLog)
                  PrintResultTrade(obj_Trade, m_symbol);
               return(true);
            }
         } else {
            if(InpPrintLog)
               Print("#3 ", EnumToString(order_type), " -> false. Result Retcode: ", obj_Trade.ResultRetcode(), ", description of result: ", obj_Trade.ResultRetcodeDescription());
            if(InpPrintLog)
               PrintResultTrade(obj_Trade, m_symbol);
            return(false);
         }
      } else {
         if(InpPrintLog)
            Print(__FUNCTION__, ", ERROR: method CAccountInfo::FreeMarginCheck returned the value ", DoubleToString(free_margin_check, 2));
         return(false);
      }
   }


   return(false);
}


//

//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultTrade(CTrade &trade, CSymbolInfo &symbol) {
   Print("File: ", __FILE__, ", symbol: ", symbol.Name());
   Print("Code of request result: " + IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: " + trade.ResultRetcodeDescription());
   Print("Deal ticket: " + IntegerToString(trade.ResultDeal()));
   Print("Order ticket: " + IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: " + DoubleToString(trade.ResultVolume(), 2));
   Print("Price, confirmed by broker: " + DoubleToString(trade.ResultPrice(), symbol.Digits()));
   Print("Current bid price: " + DoubleToString(symbol.Bid(), symbol.Digits()) + " (the requote): " + DoubleToString(trade.ResultBid(), symbol.Digits()));
   Print("Current ask price: " + DoubleToString(symbol.Ask(), symbol.Digits()) + " (the requote): " + DoubleToString(trade.ResultAsk(), symbol.Digits()));
   Print("Broker comment: " + trade.ResultComment());
   int d = 0;
}

//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResultModify(CTrade &trade, CSymbolInfo &symbol, CPositionInfo &position) {
   Print("File: ", __FILE__, ", symbol: ", m_symbol.Name());
   Print("Code of request result: " + IntegerToString(trade.ResultRetcode()));
   Print("code of request result as a string: " + trade.ResultRetcodeDescription());
   Print("Deal ticket: " + IntegerToString(trade.ResultDeal()));
   Print("Order ticket: " + IntegerToString(trade.ResultOrder()));
   Print("Volume of deal or order: " + DoubleToString(trade.ResultVolume(), 2));
   Print("Price, confirmed by broker: " + DoubleToString(trade.ResultPrice(), symbol.Digits()));
   Print("Current bid price: " + DoubleToString(symbol.Bid(), symbol.Digits()) + " (the requote): " + DoubleToString(trade.ResultBid(), symbol.Digits()));
   Print("Current ask price: " + DoubleToString(symbol.Ask(), symbol.Digits()) + " (the requote): " + DoubleToString(trade.ResultAsk(), symbol.Digits()));
   Print("Broker comment: " + trade.ResultComment());
   Print("Freeze Level: " + DoubleToString(m_symbol.FreezeLevel(), 0), ", Stops Level: " + DoubleToString(m_symbol.StopsLevel(), 0));
   Print("Price of position opening: " + DoubleToString(position.PriceOpen(), symbol.Digits()));
   Print("Price of position's Stop Loss: " + DoubleToString(position.StopLoss(), symbol.Digits()));
   Print("Price of position's Take Profit: " + DoubleToString(position.TakeProfit(), symbol.Digits()));
   Print("Current price by position: " + DoubleToString(position.PriceCurrent(), symbol.Digits()));
   int d = 0;
}

//+------------------------------------------------------------------+
//| Close positions                                                  |
//+------------------------------------------------------------------+
void ClosePositions(const ENUM_POSITION_TYPE pos_type) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))     // selects the position by index for further access to its properties
         if(m_position.Symbol() == m_symbol.Name() && m_position.Magic() == magicnumber)
            if(m_position.PositionType() == pos_type) // gets the position type
               obj_Trade.PositionClose(m_position.Ticket()); // close a position by the specified symbol
}

//+------------------------------------------------------------------+
//| Calculate all pending orders                                     |
//+------------------------------------------------------------------+
void CalculateAllPendingOrders(int &count_buy_stops, int &count_buy_limits, int &count_sell_stops, int &count_sell_limits) {
   count_buy_stops   = 0;
   count_buy_limits  = 0;
   count_sell_stops  = 0;
   count_sell_limits = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if(m_order.SelectByIndex(i))     // selects the pending order by index for further access to its properties
         if(m_order.Symbol() == m_symbol.Name() && m_order.Magic() == magicnumber) {
            if(m_order.OrderType() == ORDER_TYPE_BUY_STOP)
               count_buy_stops++;
            else if(m_order.OrderType() == ORDER_TYPE_BUY_LIMIT)
               count_buy_limits++;
            else if(m_order.OrderType() == ORDER_TYPE_SELL_STOP)
               count_sell_stops++;
            else if(m_order.OrderType() == ORDER_TYPE_SELL_LIMIT)
               count_sell_limits++;
         }
}

//+------------------------------------------------------------------+
//| Is pendinf orders exists                                         |
//+------------------------------------------------------------------+
bool IsPendingOrdersExists(void) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if(m_order.SelectByIndex(i))     // selects the pending order by index for further access to its properties
         if(m_order.Symbol() == m_symbol.Name() && m_order.Magic() == magicnumber)
            return(true);
//---
   return(false);
}

//+------------------------------------------------------------------+
//| Delete all pending orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders(const double level) {
   for(int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if(m_order.SelectByIndex(i))     // selects the pending order by index for further access to its properties
         if(m_order.Symbol() == m_symbol.Name() && m_order.Magic() == magicnumber) {
            if(m_order.OrderType() == ORDER_TYPE_BUY_LIMIT) {
               if(m_symbol.Ask() - m_order.PriceOpen() >= level)
                  obj_Trade.OrderDelete(m_order.Ticket());
               continue;
            }
            if(m_order.OrderType() == ORDER_TYPE_BUY_STOP) {
               if(m_order.PriceOpen() - m_symbol.Ask() >= level)
                  obj_Trade.OrderDelete(m_order.Ticket());
               continue;
            }
            if(m_order.OrderType() == ORDER_TYPE_SELL_LIMIT) {
               if(m_order.PriceOpen() - m_symbol.Bid() >= level)
                  obj_Trade.OrderDelete(m_order.Ticket());
               continue;
            }
            if(m_order.OrderType() == ORDER_TYPE_SELL_STOP) {
               if(m_symbol.Bid() - m_order.PriceOpen() >= level)
                  obj_Trade.OrderDelete(m_order.Ticket());
               continue;
            }
         }
}

//+------------------------------------------------------------------+
//| Is position exists                                               |
//+------------------------------------------------------------------+
bool IsPositionExists(void) {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol() == m_symbol.Name() && m_position.Magic() == magicnumber)
            return(true);
//---
   return(false);
}
//+------------------------------------------------------------------+
//| Calculate all volumes                                            |
//+------------------------------------------------------------------+
void CalculateAllVolumes(double &volumne_buys, double &volumne_sells,
                         double &volumne_buy_limits, double &volumne_sell_limits,
                         double &volumne_buy_stops, double &volumne_sell_stops) {
   volumne_buys         = 0.0;
   volumne_sells        = 0.0;
   volumne_buy_limits   = 0.0;
   volumne_sell_limits  = 0.0;
   volumne_buy_stops    = 0.0;
   volumne_sell_stops   = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(m_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         if(m_position.Symbol() == m_symbol.Name()) {
            if(m_position.PositionType() == POSITION_TYPE_BUY)
               volumne_buys += m_position.Volume();
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
               volumne_sells += m_position.Volume();
         }

   for(int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if(m_order.SelectByIndex(i)) // selects the pending order by index for further access to its properties
         if(m_order.Symbol() == m_symbol.Name()) {
            if(m_order.OrderType() == ORDER_TYPE_BUY_LIMIT)
               volumne_buy_limits += m_order.VolumeInitial();
            else if(m_order.OrderType() == ORDER_TYPE_SELL_LIMIT)
               volumne_sell_limits += m_order.VolumeInitial();
            else if(m_order.OrderType() == ORDER_TYPE_BUY_STOP)
               volumne_buy_stops += m_order.VolumeInitial();
            else if(m_order.OrderType() == ORDER_TYPE_SELL_STOP)
               volumne_sell_stops += m_order.VolumeInitial();
         }
}

//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void) {
//--- refresh rates
   if(!m_symbol.RefreshRates()) {
      Print("RefreshRates error");
      return(false);
   }
//--- protection against the return value of "zero"
   if(m_symbol.Ask() == 0 || m_symbol.Bid() == 0)
      return(false);
//---
   return(true);
}

//+------------------------------------------------------------------+
//| Trailing                                                         |
//|   InpTrailingStop: min distance from price to Stop Loss          |
//+------------------------------------------------------------------+
void Trailing(const double stop_level) {
   /*
        Buying is done at the Ask price                 |  Selling is done at the Bid price
      ------------------------------------------------|----------------------------------
      TakeProfit        >= Bid                        |  TakeProfit        <= Ask
      StopLoss          <= Bid                      |  StopLoss          >= Ask
      TakeProfit - Bid  >= SYMBOL_TRADE_STOPS_LEVEL   |  Ask - TakeProfit  >= SYMBOL_TRADE_STOPS_LEVEL
      Bid - StopLoss    >= SYMBOL_TRADE_STOPS_LEVEL   |  StopLoss - Ask    >= SYMBOL_TRADE_STOPS_LEVEL
   */
   if(InpTrailingStop == 0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; i--) // returns the number of open positions
      if(m_position.SelectByIndex(i))
         if(m_position.Symbol() == m_symbol.Name() && m_position.Magic() == magicnumber) {
            if(m_position.PositionType() == POSITION_TYPE_BUY) {
               if(m_position.PriceCurrent() - m_position.PriceOpen() > ExtTrailingStop + ExtTrailingStep)
                  if(m_position.StopLoss() < m_position.PriceCurrent() - (ExtTrailingStop + ExtTrailingStep))
                     if(ExtTrailingStop >= stop_level) {
                        if(!obj_Trade.PositionModify(m_position.Ticket(),
                                                     m_symbol.NormalizePrice(m_position.PriceCurrent() - ExtTrailingStop),
                                                     m_position.TakeProfit()))
                           Print("Modify ", m_position.Ticket(),
                                 " Position -> false. Result Retcode: ", obj_Trade.ResultRetcode(),
                                 ", description of result: ", obj_Trade.ResultRetcodeDescription());
                        RefreshRates();
                        m_position.SelectByIndex(i);
                        PrintResultModify(obj_Trade, m_symbol, m_position);
                        continue;
                     }
            } else {
               if(m_position.PriceOpen() - m_position.PriceCurrent() > ExtTrailingStop + ExtTrailingStep)
                  if((m_position.StopLoss() > (m_position.PriceCurrent() + (ExtTrailingStop + ExtTrailingStep))) ||
                        (m_position.StopLoss() == 0))
                     if(ExtTrailingStop >= stop_level) {
                        if(!obj_Trade.PositionModify(m_position.Ticket(),
                                                     m_symbol.NormalizePrice(m_position.PriceCurrent() + ExtTrailingStop),
                                                     m_position.TakeProfit()))
                           Print("Modify ", m_position.Ticket(),
                                 " Position -> false. Result Retcode: ", obj_Trade.ResultRetcode(),
                                 ", description of result: ", obj_Trade.ResultRetcodeDescription());
                        RefreshRates();
                        m_position.SelectByIndex(i);
                        PrintResultModify(obj_Trade, m_symbol, m_position);
                     }
            }

         }
}
//+------------------------------------------------------------------+
