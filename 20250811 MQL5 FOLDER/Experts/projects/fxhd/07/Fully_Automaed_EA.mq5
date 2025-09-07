//+------------------------------------------------------------------+
//|                                     Quantz Fully Automaed EA.mq5 |
//|                                      Copyright 2024, FxHDAcademy |
//|                         https://www.mql5.com/en/users/brendonren |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, FxHDAcademy"
#property link      "https://www.mql5.com/en/users/brendonren"
#property version   "1.00"
/*
https://www.mql5.com/en/articles/261

resources
*/


//#resource "SubFolder\\EmbeddedIndicator.ex5"
#resource "\\Indicators\\Supertrend.ex5"
int SuperTrend_Handle;



bool ShowFibo = true;
bool ShowHTFFibo = false;


#include <Trade/SymbolInfo.mqh>

input ENUM_TIMEFRAMES HTF = PERIOD_W1;
color HTF_Fibo_Color = clrGreen;
input ENUM_TIMEFRAMES LTF = PERIOD_M5;
input color LTF_Fibo_Color = clrBlack;


input int LookHL_XBars = 200;

input double RetraceBreak_XLevel = 30.9;

string SuperTrend_Settings = "================ SuperTrend Properties ================";
string SuperTrend_IndicatorName = "Supertrend";
int SuperTrend_Period = 10;
double SuperTrend_Multiplier = 3;
const bool SuperTrend_Show_Filling = true;

input string Trade_Properties = "================ Trade Properties ================";
double MinorBreakLimitOrderPrice_XLevel = 39;
double MajorBreakLimitOrderPrice_XLevel = 66.4;
double TakeProfit_XLevel = 161.8;
double StopLoss_XLevel = 27.2;
double MinorBreakLimitOrderPrice_XLevel_BOS = 11.5;
double MajorBreakLimitOrderPrice_XLevel_BOS = 11.8;
double TakeProfit_XLevel_BOS = -61.8;
double StopLoss_XLevel_BOS = 127.2;
input int MagicNumber = 1234;
input int MaxSlippage = 9999;


input string MoneyManagement = "================ Money Management Properties ================";
enum EnumPosLotType
  {
   UseFixedLot=0, //Use Fixed Lot
   UseBalancePerLot=1, //Use Balance Per Lot
   UseEquityPerLot=2, //Use Equity Per Lot
   UseRiskPercentage=3, //Use Risk Percentage
   UseFixedMargin=4, //Use Fixed Margin
  };
input EnumPosLotType LotType = UseFixedLot;
input double FixedLot = 0.05;// Fixed Lot
input double BalancePerLot=10000; //Balance per Lot
input double EquityPerLot=10000; //Equity per Lot
input double RiskPercentage = 30; //Risk Percentage
input double FixedMargin=1000; //Fixed Margin

input double MaxLot = 0; //MaxLot (0 or negative means no limit)

bool NewFibo = false;

struct STRUCT_Fibo
  {
   datetime          Time1;
   datetime          Time2;
   double            Price1;
   double            Price2;
  };
STRUCT_Fibo FiboHTF, FiboLTF;

int LastUpOrDown = -1;

int Button_UpOrDown = -1;

const string ObjPref = "FiboEA-";


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(ShowHTFFibo)
     {
      if(ObjectFind(0, ObjPref + "HTF_Fibo") == 0)
        {
         FiboHTF.Time1 = (datetime)ObjectGetInteger(0, ObjPref + "HTF_Fibo", OBJPROP_TIME, 0);
         FiboHTF.Price1 = ObjectGetDouble(0, ObjPref + "HTF_Fibo", OBJPROP_PRICE, 0);

         FiboHTF.Time2 = (datetime)ObjectGetInteger(0, ObjPref + "HTF_Fibo", OBJPROP_TIME, 1);
         FiboHTF.Price2 = ObjectGetDouble(0, ObjPref + "HTF_Fibo", OBJPROP_PRICE, 1);
        }
     }

   if(ShowFibo)
     {
      if(ObjectFind(0, ObjPref + "LTF_Fibo") == 0)
        {
         FiboLTF.Time1 = (datetime)ObjectGetInteger(0, ObjPref + "LTF_Fibo", OBJPROP_TIME, 0);
         FiboLTF.Price1 = ObjectGetDouble(0, ObjPref + "LTF_Fibo", OBJPROP_PRICE, 0);

         FiboLTF.Time2 = (datetime)ObjectGetInteger(0, ObjPref + "LTF_Fibo", OBJPROP_TIME, 1);
         FiboLTF.Price2 = ObjectGetDouble(0, ObjPref + "LTF_Fibo", OBJPROP_PRICE, 1);
        }
     }

 
   SuperTrend_Handle = iCustom(_Symbol
                               , HTF
                               , "::Indicators\\Supertrend.ex5"
                               , SuperTrend_Period
                               , SuperTrend_Multiplier
                               , SuperTrend_Show_Filling
                              );

   if(SuperTrend_Handle == INVALID_HANDLE)
     {
      Print("Expert: iCustom call: Error code=",GetLastError());
      PrintFormat("Failed to create handle of the %s indicator for the symbol %s/%s, error code %d",
                  SuperTrend_IndicatorName,
                  _Symbol,
                  EnumToString(HTF),
                  GetLastError());

      return INIT_FAILED;
     }


//if(!CreateIndicatorsHandles())
//   return (INIT_FAILED);

   return (INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(SuperTrend_Handle != INVALID_HANDLE)
      IndicatorRelease(SuperTrend_Handle);

  }





//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckToDeleteRelatedFiboIfPositionExist();
   if(TimeCurrent() >= D'2023.4.3 21:15')
     {
      int a = 0;
     }
   //--Check SuperTrend
   Check_HTF();


   static datetime LastTime_HTF = 0;
   bool IsNewCandle_HTF = LastTime_HTF != iTime(NULL,HTF,0);
   if(IsNewCandle_HTF)
      LastTime_HTF = iTime(NULL,HTF,0);

   static datetime LastTime_LTF = 0;
   bool IsNewCandle_LTF = LastTime_LTF != iTime(NULL,LTF,0);
   if(IsNewCandle_LTF)
      LastTime_LTF = iTime(NULL,LTF,0);

   IsNewCandle_HTF = IsNewCandle_HTF || NewFibo;
   IsNewCandle_LTF = IsNewCandle_LTF || NewFibo;

   //if (IsNewCandle_LTF && FiboHTF.Time1 > 0 && !OrderExist(_Symbol) && !PositionExist(_Symbol) )
   if(IsNewCandle_LTF && FiboHTF.Time1 > 0 && !PositionExist(_Symbol))
     {
      Check_LTF();
     }


//---------------------Break of Fibo_level0----------------------------///


     {
      if(!PositionExist(_Symbol))
        {
         // Check break
         double Fibo_Level100_Price = 0, Fibo_Level0_Price = 0;
         datetime Fibo_Time2 = 0;
         ENUM_TIMEFRAMES TF = 0;
         if(FiboLTF.Time1 > 0)
           {
            if(IsNewCandle_LTF)
              {
               Fibo_Level100_Price = FiboLTF.Price1;
               Fibo_Level0_Price = FiboLTF.Price2;
               Fibo_Time2 = (datetime)MathMax(FiboLTF.Time1, FiboLTF.Time2);
               TF = LTF;
              }
           }

         double Fibo_HTF_Level100_Price = FiboHTF.Price1;
         double Fibo_HTF_Level0_Price = FiboHTF.Price2;




         if(Fibo_Level0_Price > 0 && Fibo_Level100_Price > 0 && Fibo_Level0_Price != Fibo_Level100_Price
            && Fibo_HTF_Level0_Price > 0 && Fibo_HTF_Level100_Price > 0 && Fibo_HTF_Level0_Price != Fibo_HTF_Level100_Price
           )
           {
            int UpOrDown = (Fibo_Level0_Price > Fibo_Level100_Price ? 0 : 1);
            int bars = iBars(NULL,TF);

            //-- Check Break
            int BreakType = 0;

            int NumOfBars_Major= 0, NumOfBars_Minor = 0;
            for(int i = 1; i < bars && BreakType == 0; i++)
              {
               if(iTime(NULL,TF,i) < Fibo_Time2)
                  break;

               // Major
               if(UpOrDown == 0
                  ? iClose(NULL,TF,i) > iOpen(NULL,TF,i) && iClose(NULL,TF,i) < Fibo_Level0_Price
                  : iClose(NULL,TF,i) < iOpen(NULL,TF,i) && iClose(NULL,TF,i) > Fibo_Level0_Price
                 )
                 {
                  NumOfBars_Major++;
                 }
               else
                  NumOfBars_Major = 0;

               if(NumOfBars_Major == 3)
                 {
                  BreakType = 1;
                  break;
                 }

               // Minor
               if(UpOrDown == 0
                  ? (NumOfBars_Minor == 0 || iClose(NULL,TF,i) > iOpen(NULL,TF,i)) && iClose(NULL,TF,i) < Fibo_Level0_Price
                  : (NumOfBars_Minor == 0 || iClose(NULL,TF,i) < iOpen(NULL,TF,i)) && iClose(NULL,TF,i) > Fibo_Level0_Price
                 )
                 {
                  NumOfBars_Minor++;
                 }
               else
                  if(NumOfBars_Minor == 2)
                    {
                     BreakType = 1;
                     break;
                    }
                  else
                     NumOfBars_Minor = 0;
              }

            if(BreakType > 0)
              {
               double LimitOrderPrice;
               if(BreakType == 1)  // means minor break
                 {
                  LimitOrderPrice= Fibo_Level0_Price + MinorBreakLimitOrderPrice_XLevel_BOS * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
                 }
               else // means major break
                 {
                  LimitOrderPrice = Fibo_Level0_Price + MajorBreakLimitOrderPrice_XLevel_BOS * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
                 }

               LimitOrderPrice = NormalizeDouble(LimitOrderPrice, _Digits);

               ENUM_ORDER_TYPE type = (UpOrDown == 0 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);

               string comment = (BreakType == 1 ? "Minor Break-" : "Major Break-")+(TF == HTF ? "HTF" : "LTF");

               // if (!OrderExist(_Symbol, type, comment) && !OrderExist(_Symbol, type, "Major Break"))
                 {
                  DeleteOrders(_Symbol);

                  string symbol = _Symbol;
                  int digits = _Digits;
                  double price = LimitOrderPrice;

                  double tp = Fibo_Level0_Price + TakeProfit_XLevel_BOS * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
                  double sl = Fibo_Level0_Price + StopLoss_XLevel_BOS * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
                  double lot = Lots(symbol, UpOrDown, price, sl);


                  int ticket = SendOrder(symbol, type, lot, price, MaxSlippage, sl, tp, comment, MagicNumber);
                  if(ticket <= 0 && -ticket != TRADE_RETCODE_INVALID_STOPS && - ticket != TRADE_RETCODE_INVALID_PRICE)
                     Alert("Error: Order not opened, ErrorCode: "+(string)(-ticket) + " :: " + symbol + " "+OrderTypeToStr(type)+" " + DoubleToString(lot, 2) + " lots @ "+ DoubleToString(price, digits) + " SL: " + DoubleToString(sl, digits) + " TP: " + DoubleToString(tp, digits) + " Comment: "+comment);
                  else
                     if(ticket > 0)
                       {
                        Print("Order opened: "+ symbol + " "+OrderTypeToStr(type)+" " + DoubleToString(lot, 2) + " lots @ "+ DoubleToString(price, digits) + " SL: " + DoubleToString(sl, digits) + " TP: " + DoubleToString(tp, digits) + " Comment: "+comment);
                       }
                 }
              }
           }
        }
     }

//---------------------Break of Fibo_level100----------------------------///

   if(!PositionExist(_Symbol))
     {
      //check break
      double Fibo_Level100_Price = 0, Fibo_Level0_Price = 0;
      datetime Fibo_Time2 = 0;
      ENUM_TIMEFRAMES TF = 0;
      if(FiboLTF.Time1 > 0)
        {
         if(IsNewCandle_LTF)
           {
            Fibo_Level100_Price = FiboLTF.Price1;
            Fibo_Level0_Price = FiboLTF.Price2;
            Fibo_Time2 = (datetime)MathMax(FiboLTF.Time1, FiboLTF.Time2);
            TF = LTF;
           }
        }

      double Fibo_HTF_Level100_Price = FiboHTF.Price1;
      double Fibo_HTF_Level0_Price = FiboHTF.Price2;

      if(Fibo_Level100_Price > 0 && Fibo_Level0_Price > 0 && Fibo_Level100_Price != Fibo_Level0_Price
         && Fibo_HTF_Level100_Price > 0 && Fibo_HTF_Level0_Price > 0 && Fibo_HTF_Level100_Price != Fibo_HTF_Level0_Price
        )
        {
         int UpOrDown = (Fibo_Level100_Price > Fibo_Level0_Price ? 0 : 1);
         int bars = iBars(NULL,TF);

         //-- Check Break
         int BreakType = 0;

         int NumOfBars_Major = 0, NumOfBars_Minor = 0;
         for(int i = 1; i < bars && BreakType == 0; i++)
           {
            if(iTime(NULL,TF,i) < Fibo_Time2)
               break;

            //Major
            if(UpOrDown == 0
               ? iClose(NULL,TF,i) > iOpen(NULL,TF,i) && iClose(NULL,TF,i) > Fibo_Level100_Price
               : iClose(NULL,TF,i) < iOpen(NULL,TF,i) && iClose(NULL,TF,i) < Fibo_Level100_Price
              )
              {
               NumOfBars_Major++;
              }
            else
               NumOfBars_Major = 0;

            if(NumOfBars_Major == 3)
              {
               BreakType = 1;
               break;
              }

            //Minor
            if(UpOrDown == 0
               ? (NumOfBars_Minor == 0 || iClose(NULL,TF,i) > iOpen(NULL,TF,i)) && iClose(NULL,TF,i) > Fibo_Level100_Price
               : (NumOfBars_Minor == 0 || iClose(NULL,TF,i) < iOpen(NULL,TF,i)) && iClose(NULL,TF,i) < Fibo_Level100_Price
              )
              {
               NumOfBars_Minor++;
              }
            else
               if(NumOfBars_Minor == 2)
                 {
                  BreakType = 1;
                  break;
                 }
               else
                  NumOfBars_Minor = 0;
           }

         if(BreakType > 0)
           {
            double LimitOrderPrice;
            if(BreakType == 1)  //means minor break
              {
               LimitOrderPrice = Fibo_Level0_Price + MinorBreakLimitOrderPrice_XLevel*0.01*(Fibo_Level100_Price - Fibo_Level0_Price);
              }
            else //means major break
              {
               LimitOrderPrice = Fibo_Level0_Price + MajorBreakLimitOrderPrice_XLevel*0.01*(Fibo_Level100_Price - Fibo_Level0_Price);
              }

            LimitOrderPrice = NormalizeDouble(LimitOrderPrice, _Digits);

            ENUM_ORDER_TYPE type = (UpOrDown == 0 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);

            string comment = (BreakType == 1 ? "Minor Break-" : "Major Break-")+(TF == HTF ? "HTF" : "LTF");

            //     if (!OrderExist(_Symbol, type, comment) && !OrderExist(_Symbol, type, "Major Break"))
              {
               DeleteOrders(_Symbol);

               string symbol = _Symbol;
               int digits = _Digits;
               double price = LimitOrderPrice;


               double tpLTF = Fibo_Level0_Price + TakeProfit_XLevel *0.01*(Fibo_Level100_Price - Fibo_Level0_Price);
               double slLTF = Fibo_Level0_Price - StopLoss_XLevel *0.01*(Fibo_Level100_Price - Fibo_Level0_Price);

               double tpHTF = Fibo_HTF_Level0_Price + TakeProfit_XLevel *0.01*(Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);
               double slHTF = Fibo_HTF_Level0_Price - StopLoss_XLevel *0.01*(Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);
               double lot = Lots(symbol, UpOrDown, price, slLTF);


               int ticket = SendOrder(symbol, type, lot, price, MaxSlippage, slLTF, tpLTF, comment, MagicNumber);
               if(ticket <= 0 && -ticket != TRADE_RETCODE_INVALID_STOPS && - ticket != TRADE_RETCODE_INVALID_PRICE)
                  Alert("Error: Order not opened, ErrorCode: "+(string)(-ticket) + " :: " + symbol + " "+OrderTypeToStr(type)+" " + DoubleToString(lot, 2) + " lots @ "+ DoubleToString(price, digits) + " SL: " + DoubleToString(slLTF, digits) + " TP: " + DoubleToString(tpLTF, digits) + " Comment: "+comment);
               else
                  if(ticket > 0)
                    {
                     Print("Order opened: "+ symbol + " "+OrderTypeToStr(type)+" " + DoubleToString(lot, 2) + " lots @ "+ DoubleToString(price, digits) + " SL: " + DoubleToString(slLTF, digits) + " TP: " + DoubleToString(tpLTF, digits) + " Comment: "+comment);
                    }
              }
           }
        }

     }
   NewFibo = false;
   CheckToCloseOppositeTradesOnHTFTrigger();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,       // event ID
                  const long& lparam,   // long type event parameter
                  const double& dparam,   // double type event parameter
                  const string& sparam    // string type event parameter
                 )
  {
  }

//+------------------------------------------------------------------+
//| Create Fibonacci Retracement by the given coordinates            |
//+------------------------------------------------------------------+
void FiboLevelsCreate(const long            chart_ID=0,        // chart's ID
                      const string          name="FiboLevels", // object name
                      const int             sub_window=0,      // subwindow index
                      datetime              time1=0,           // first point time
                      double                price1=0,          // first point price
                      datetime              time2=0,           // second point time
                      double                price2=0,          // second point price
                      const color           clr=clrRed,        // object color
                      const ENUM_LINE_STYLE style=STYLE_SOLID, // object line style
                      const int             width=1,           // object line width
                      const bool            back=false,        // in the background
                      const bool            selection=true,    // highlight to move
                      const bool            ray_left=false,    // object's continuation to the left
                      const bool            ray_right=false,   // object's continuation to the right
                      const bool            hidden=true,       // hidden in the object list
                      const long            z_order=0)         // priority for mouse click


  {
//--- Create Fibonacci Retracement by the given coordinates
   ObjectDelete(chart_ID,name);
   ObjectCreate(chart_ID,name,OBJ_FIBO,sub_window,time1,price1,time2,price2);
//--- set color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of highlighting the channel for moving
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- enable (true) or disable (false) the mode of continuation of the object's display to the left
   ObjectSetInteger(chart_ID,name,OBJPROP_RAY_LEFT,ray_left);
//--- enable (true) or disable (false) the mode of continuation of the object's display to the right
   ObjectSetInteger(chart_ID,name,OBJPROP_RAY_RIGHT,ray_right);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Check_LTF()
  {
   double Fibo_HTF_Level100 = FiboHTF.Price1;
   double Fibo_HTF_Level0 = FiboHTF.Price2;

   datetime Fibo_HTF_Time2;
   double Fibo_HTF_Price2;
   if(FiboHTF.Time1 > FiboHTF.Time2)
     {
      Fibo_HTF_Time2 = (datetime)FiboHTF.Time1;
      Fibo_HTF_Price2 = FiboHTF.Price1;
      if(FiboHTF.Price2 > Fibo_HTF_Price2)
         Fibo_HTF_Price2 *= -1;
     }
   else
     {
      Fibo_HTF_Time2 = (datetime)FiboHTF.Time2;
      Fibo_HTF_Price2 = FiboHTF.Price2;
      if(FiboHTF.Price1 > Fibo_HTF_Price2)
         Fibo_HTF_Price2 *= -1;
     }

   if(Fibo_HTF_Level100 != Fibo_HTF_Level0 && Fibo_HTF_Level0 > 0 && Fibo_HTF_Level100 > 0)
     {
      if(Fibo_HTF_Level100 > Fibo_HTF_Level0
         ? iClose(NULL,LTF,1) > Fibo_HTF_Level100 || iClose(NULL,LTF,1) < Fibo_HTF_Level0
         : iClose(NULL,LTF,1) < Fibo_HTF_Level100 || iClose(NULL,LTF,1) > Fibo_HTF_Level0
        )
        {
         FiboLTF.Time1 = 0;
         FiboLTF.Price1 = 0;

         FiboLTF.Time2 = 0;
         FiboLTF.Price2 = 0;

         //--- Create LTF_Fibo
         if(ShowFibo)
           {
            ObjectDelete(0, ObjPref+"LTF_Fibo");
           }

         return;
        }

      int BuyOrSell;
      if(Fibo_HTF_Level0 > Fibo_HTF_Level100)
         BuyOrSell = 1;
      else
         BuyOrSell = 0;

      double Fibo_HTF_Level38 = Fibo_HTF_Level0 + RetraceBreak_XLevel*0.01*(Fibo_HTF_Level100 - Fibo_HTF_Level0);

      int StartBar = iBarShift(NULL, LTF, Fibo_HTF_Time2);
      while(StartBar > 0 &&
            (Fibo_HTF_Price2 > 0
             ? iHigh(NULL, LTF, StartBar) < Fibo_HTF_Price2
             : iLow(NULL, LTF, StartBar) > -Fibo_HTF_Price2
            )
           )
         StartBar--;

      StartBar--;
      if(StartBar <= 0)
         return;

      datetime Fibo_LTF_Level0_Time = 0, Fibo_LTF_Level100_Time = 0;
      double Fibo_LTF_Level0_Price = 0, Fibo_LTF_Level100_Price = 0, Fibo_LTF_Level38 = 0;

      int ImpulseBars = 0, RetraceBars = 0;
      double ImpulseStartPrice = 0, ImpulseEndPrice = 0, RetraceStartPrice = 0, RetraceEndPrice = 0;
      datetime ImpulseStartTime = 0, ImpulseEndTime = 0, RetraceStartTime = 0, RetraceEndTime = 0;

      bool RetraceClosedOverLevel38 = false;

      for(int i = StartBar; i > 0; i--)
        {
         if(RetraceBars < 2 || !RetraceClosedOverLevel38)
           {
            if(BuyOrSell == 0)
              {
               if(iClose(NULL,LTF,i) > iOpen(NULL,LTF,i)
                  && (ImpulseBars == 0 || iHigh(NULL,LTF,i) > ImpulseEndPrice)
                 )
                 {
                  if(ImpulseBars == 0)
                    {
                     ImpulseStartPrice = iLow(NULL,LTF,i);
                     ImpulseStartTime = iTime(NULL,LTF,i);
                    }
                  ImpulseEndPrice = iHigh(NULL,LTF,i);
                  ImpulseEndTime = iTime(NULL,LTF,i);
                  ImpulseBars++;
                  RetraceBars = 0;
                 }
              }
            else
              {
               if(iClose(NULL,LTF,i) < iOpen(NULL,LTF,i)
                  && (ImpulseBars == 0 || iLow(NULL,LTF,i) < ImpulseEndPrice)
                 )
                 {
                  if(iTime(NULL,0,i) == D'2023.2.9 15:9')
                    {
                     int a  =0;
                    }
                  if(ImpulseBars == 0)
                    {
                     ImpulseStartPrice = iHigh(NULL,LTF,i);
                     ImpulseStartTime = iTime(NULL,LTF,i);
                    }
                  ImpulseEndPrice = iLow(NULL,LTF,i);
                  ImpulseEndTime = iTime(NULL,LTF,i);
                  ImpulseBars++;
                  RetraceBars = 0;
                 }
              }
           }
         //-- Retrace
           {
            if(BuyOrSell == 0)
              {
               if(iClose(NULL,LTF,i) < iOpen(NULL,LTF,i)
                  && (RetraceBars == 0 || iLow(NULL,LTF,i) < RetraceEndPrice)
                 )
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                       {
                        RetraceStartPrice = iHigh(NULL,LTF,i);
                        RetraceStartTime = iTime(NULL,LTF,i);
                        RetraceClosedOverLevel38 = false;
                       }
                     RetraceEndPrice = iLow(NULL,LTF,i);
                     RetraceEndTime = iTime(NULL,LTF,i);
                     RetraceBars++;
                     if(RetraceBars >= 2)
                       {
                        Fibo_LTF_Level0_Price = ImpulseEndPrice;
                        Fibo_LTF_Level0_Time = ImpulseEndTime;

                        Fibo_LTF_Level100_Price = ImpulseStartPrice;
                        Fibo_LTF_Level100_Time = ImpulseStartTime;

                        Fibo_LTF_Level38 = Fibo_LTF_Level0_Price + RetraceBreak_XLevel*0.01*(Fibo_LTF_Level100_Price - Fibo_LTF_Level0_Price);

                        if(iClose(NULL,LTF,i) < Fibo_LTF_Level38 && iClose(NULL,LTF,i+1) < Fibo_LTF_Level38)
                          {
                           RetraceBars = 0;
                           ImpulseBars = 0;
                           RetraceClosedOverLevel38 = true;
                          }
                       }
                    }
                  else
                     ImpulseBars = 0;
                 }
              }
            else
              {
               if(iClose(NULL,LTF,i) > iOpen(NULL,LTF,i)
                  && (RetraceBars == 0 || iHigh(NULL,LTF,i) > RetraceEndPrice)
                 )
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                       {
                        RetraceStartPrice = iLow(NULL,LTF,i);
                        RetraceStartTime = iTime(NULL,LTF,i);
                        RetraceClosedOverLevel38 = false;
                       }
                     RetraceEndPrice = iHigh(NULL,LTF,i);
                     RetraceEndTime = iTime(NULL,LTF,i);
                     RetraceBars++;
                     if(RetraceBars >= 2)
                       {
                        Fibo_LTF_Level0_Price = ImpulseEndPrice;
                        Fibo_LTF_Level0_Time = ImpulseEndTime;

                        Fibo_LTF_Level100_Price = ImpulseStartPrice;
                        Fibo_LTF_Level100_Time = ImpulseStartTime;

                        Fibo_LTF_Level38 = Fibo_LTF_Level0_Price + RetraceBreak_XLevel*0.01*(Fibo_LTF_Level100_Price - Fibo_LTF_Level0_Price);

                        if(iClose(NULL,LTF,i) > Fibo_LTF_Level38 && iClose(NULL,LTF,i+1) > Fibo_LTF_Level38)
                          {
                           RetraceBars = 0;
                           ImpulseBars = 0;
                           RetraceClosedOverLevel38 = true;
                          }
                       }
                    }
                  else
                     ImpulseBars = 0;
                 }
              }
           }
        }

      if(Fibo_LTF_Level0_Time > 0 && Fibo_LTF_Level100_Time > 0)
        {
         //--- Create LTF_Fibo
         if(ShowFibo)
           {
            const long            chart_ID=0;        // chart's ID
            const string          name=ObjPref+"LTF_Fibo"; // object name
            const int             sub_window=0;      // subwindow index
            datetime              time1=Fibo_LTF_Level100_Time;           // first point time
            double                price1=Fibo_LTF_Level100_Price;          // first point price
            datetime              time2=Fibo_LTF_Level0_Time;           // second point time
            double                price2=Fibo_LTF_Level0_Price;          // second point price
            const color           clr=LTF_Fibo_Color;        // object color
            const ENUM_LINE_STYLE style=STYLE_DASH; // object line style
            const int             width=1;           // object line width
            const bool            back=false;        // in the background
            const bool            selection=false;    // highlight to move
            const bool            ray_left=false;    // object's continuation to the left
            const bool            ray_right=true;   // object's continuation to the right
            const bool            hidden=true;       // hidden in the object list
            const long            z_order=0;

            FiboLevelsCreate(chart_ID, name, sub_window, time1, price1, time2, price2, clr, style, width, back, selection, ray_left, ray_right, hidden, z_order);


            int levels = 3;
            double values[3] = {0, RetraceBreak_XLevel*0.01, 1};

            ObjectSetInteger(chart_ID,name,OBJPROP_LEVELS,levels);
            //--- set the properties of levels in the loop
            for(int i=0;i<levels;i++)
              {
               //--- level value
               ObjectSetDouble(chart_ID,name,OBJPROP_LEVELVALUE,i,values[i]);
               //--- level color
               ObjectSetInteger(chart_ID,name,OBJPROP_LEVELCOLOR,i,LTF_Fibo_Color);
               //--- level style
               ObjectSetInteger(chart_ID,name,OBJPROP_LEVELSTYLE,i,STYLE_SOLID);
               //--- level width
               ObjectSetInteger(chart_ID,name,OBJPROP_LEVELWIDTH,i,1);
               //--- level description
               ObjectSetString(chart_ID,name,OBJPROP_LEVELTEXT,i,DoubleToString(100*values[i],1));
              }

            ChartRedraw();

           }

         //else
           {
            FiboLTF.Time1 = Fibo_LTF_Level100_Time;
            FiboLTF.Price1 = Fibo_LTF_Level100_Price;

            FiboLTF.Time2 = Fibo_LTF_Level0_Time;
            FiboLTF.Price2 = Fibo_LTF_Level0_Price;
           }
         NewFibo = true;

        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PositionExist(string symbol, int pos_type=-1, string comment=NULL)
  {
   int total = PositionsTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0
         && PositionGetString(POSITION_SYMBOL) == symbol
         && (PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         && (pos_type == -1 || PositionGetInteger(POSITION_TYPE) == pos_type)
         && (comment == NULL || StringFind(PositionGetString(POSITION_COMMENT), comment) == 0)
        )
        {
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool OrderExist(string symbol, int order_type=-1, string comment=NULL, double price=0)
  {
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--)
     {
      long ticket = (long)OrderGetTicket(i);
      if(ticket > 0
         && OrderGetString(ORDER_SYMBOL) == symbol
         && (OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         && (order_type == -1 || OrderGetInteger(ORDER_TYPE) == order_type)
         && (comment == NULL || StringFind(OrderGetString(ORDER_COMMENT), comment) == 0)
         && (price <= 0 || MathAbs(price - OrderGetDouble(ORDER_PRICE_OPEN)) < SymbolInfoDouble(OrderGetString(ORDER_SYMBOL), SYMBOL_POINT))
        )
        {
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOrders(string symbol, int order_type=-1, string comment=NULL)
  {
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--)
     {
      long ticket = (long)OrderGetTicket(i);
      if(ticket > 0
         && (symbol == NULL || OrderGetString(ORDER_SYMBOL) == symbol)
         && (OrderGetInteger(ORDER_MAGIC) == MagicNumber)
         && (order_type == -1 || OrderGetInteger(ORDER_TYPE) == order_type)
         && (comment == NULL || StringFind(OrderGetString(ORDER_COMMENT), comment) == 0)
        )
        {
         DeleteOrder(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Lots(string f_symbol, int BuyOrSell, double price, double sl=0, double VolumeRatio=1)
  {
   double f_volume = 0, margin = 0;
   if(LotType == UseFixedLot && FixedLot > 0)
      f_volume = FixedLot;
   else
      if(LotType == UseBalancePerLot && BalancePerLot > 0)
         f_volume = AccountInfoDouble(ACCOUNT_BALANCE)/BalancePerLot;
      else
         if(LotType == UseEquityPerLot && EquityPerLot > 0)
            f_volume = AccountInfoDouble(ACCOUNT_EQUITY)/EquityPerLot;
         else
            if(LotType == UseRiskPercentage && RiskPercentage > 0)
              {
               if(sl <= 0 || price <= 0)
                 {
                  Alert("Error: SL is zero while LotType is UseRiskPercentage!");
                  return(0);
                 }
               double point = SymbolInfoDouble(f_symbol,SYMBOL_POINT);
               double tick_value = SymbolInfoDouble(f_symbol,SYMBOL_TRADE_TICK_VALUE);

               double Fnc_Loss;
               if(!OrderCalcProfit((BuyOrSell == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), f_symbol, 1, price, sl, Fnc_Loss) || Fnc_Loss >= 0)
                  return(0);

               Fnc_Loss = -Fnc_Loss;
               double ExpectedLoss = AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100.0;

               f_volume = ExpectedLoss/Fnc_Loss;

               /*
               double SLInPips = MathAbs(sl - price)*PriceToPip(f_symbol);
               SLInPips += SymbolInfoInteger(f_symbol, SYMBOL_SPREAD)*SymbolInfoDouble(f_symbol, SYMBOL_POINT)*PriceToPip(f_symbol);
               double f_volume2 = (AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100.0)/((SLInPips)*_pipx(f_symbol)*SymbolInfoDouble(f_symbol,SYMBOL_TRADE_TICK_VALUE));
               */
              }
            else
               if(LotType == UseFixedMargin && FixedMargin > 0 && OrderCalcMargin((BuyOrSell == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), f_symbol, 1, price, margin))
                 {
                  f_volume = FixedMargin/margin;
                 }

   if(MaxLot > 0 && f_volume > MaxLot)
      f_volume = MaxLot;

   return(CalcLot(f_symbol, VolumeRatio*f_volume));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLot(string f_symbol, double f_LotSize)
  {
   if(f_LotSize < SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MIN))
      f_LotSize = SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MIN);
   if(f_LotSize > SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MAX))
      f_LotSize = SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MAX);
   double f_value = MathMod(f_LotSize, SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP));
   if(!(MathAbs(f_value - 0) < 0.00001 || MathAbs(f_value - SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP)) < 0.00001))
     {
      f_LotSize = f_LotSize - f_value + SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP);
     }

   return (NormalizeDouble(f_LotSize, 2));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SendOrder(const string sSymbol, const ENUM_ORDER_TYPE eType, const double fLot, double &prices, const uint nSlippage = 1000, const double fSL = 0, const double fTP = 0, const string nComment = "", const ulong nMagic = 0, datetime expiration=0)
  {
   int RetVal = 0;

   string position_symbol = sSymbol;

   MqlTradeRequest trade_request;
   ZeroMemory(trade_request);
   MqlTradeResult  trade_result;
   ZeroMemory(trade_result);

   if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK)
      trade_request.type_filling = ORDER_FILLING_FOK;
   else
      if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC)
         trade_request.type_filling = ORDER_FILLING_IOC;
      else
         if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==0)
            trade_request.type_filling = ORDER_FILLING_RETURN;
         else
            if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)>2)
              {
               int FillingCheck_ = (int)FillingCheck(position_symbol);
               if(FillingCheck_ > 0)
                  return(-FillingCheck_);
              }

   double fPoint = SymbolInfoDouble(sSymbol, SYMBOL_POINT);

   int nDigits = (int) SymbolInfoInteger(sSymbol, SYMBOL_DIGITS);

   if(eType < 2)
      trade_request.action = TRADE_ACTION_DEAL;
   else
      trade_request.action =TRADE_ACTION_PENDING;

   trade_request.symbol  = sSymbol;
   trade_request.volume  = fLot;
   trade_request.stoplimit = 0;
   trade_request.deviation = nSlippage;
   trade_request.comment = nComment;
   trade_request.type  = eType;
   trade_request.sl = NormalizeDouble(fSL, nDigits);
   trade_request.tp = NormalizeDouble(fTP, nDigits);
   trade_request.magic     = nMagic;
   if(expiration > 0)
     {
      trade_request.type_time = ORDER_TIME_SPECIFIED;
      trade_request.expiration = expiration;
     }
   if(eType == ORDER_TYPE_BUY)
      trade_request.price = NormalizeDouble(SymbolInfoDouble(sSymbol, SYMBOL_ASK), nDigits);
   else
      if(eType == ORDER_TYPE_SELL)
         trade_request.price = NormalizeDouble(SymbolInfoDouble(sSymbol, SYMBOL_BID), nDigits);
      else
         trade_request.price  = NormalizeDouble(prices, nDigits);

   MqlTradeCheckResult oCheckResult;
   ZeroMemory(oCheckResult);

   bool bCheck = OrderCheck(trade_request, oCheckResult);

   if(bCheck == true && oCheckResult.retcode == 0)
     {
      bool bResult = false;

      for(int k = 0; k < 5; k++)
        {
         bResult = OrderSend(trade_request, trade_result);

         if(bResult == true && (trade_result.retcode == TRADE_RETCODE_DONE || trade_result.retcode == TRADE_RETCODE_PLACED))
           {
            RetVal = (int)trade_result.order;
            if(eType < 2 && PositionSelectByTicket(RetVal))
               prices = PositionGetDouble(POSITION_PRICE_OPEN);
            else
               if(eType >= 2 && OrderSelect(RetVal))
                  prices = OrderGetDouble(ORDER_PRICE_OPEN);

            break;
           }
         if(k == 4)
           {
            RetVal = -(int)trade_result.retcode;
            break;
           }
         Sleep(1000);
        }
     }
   else
     {
      RetVal = -(int)oCheckResult.retcode;
      if(oCheckResult.retcode == TRADE_RETCODE_NO_MONEY)
        {
         Print("Exper Removed due to not enough money!");
         ExpertRemove();
        }
     }

   return(RetVal);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderTypeToStr(ENUM_ORDER_TYPE type)
  {
   if(type == ORDER_TYPE_BUY)
      return("Buy");
   if(type == ORDER_TYPE_SELL)
      return("Sell");
   if(type == ORDER_TYPE_BUY_LIMIT)
      return("Buy limit");
   if(type == ORDER_TYPE_SELL_LIMIT)
      return("Sell limit");
   if(type == ORDER_TYPE_BUY_STOP)
      return("Buy stop");
   if(type == ORDER_TYPE_SELL_STOP)
      return("Sell stop");

   return(NULL);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DeleteOrder(ulong ticket)
  {
   int total = OrdersTotal();
   for(int i = total-1; i >= 0; i--)
     {
      if(OrderGetTicket(i) != ticket)
         continue;

      string order_symbol = OrderGetString(ORDER_SYMBOL);

      MqlTradeRequest trade_request;
      ZeroMemory(trade_request);
      MqlTradeResult  trade_result;
      ZeroMemory(trade_result);

      if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK)
         trade_request.type_filling = ORDER_FILLING_FOK;
      else
         if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC)
            trade_request.type_filling = ORDER_FILLING_IOC;
         else
            if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==0)
               trade_request.type_filling = ORDER_FILLING_RETURN;
            else
               if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)>2)
                 {
                  uint FillingCheck = FillingCheck(order_symbol);
                  if(FillingCheck > 0)
                    {
                     Print("Error in removing order #"+(string)ticket+", ErrorCode: "+(string)FillingCheck);
                     return(false);
                    }
                 }

      trade_request.action=TRADE_ACTION_REMOVE;
      trade_request.order = ticket;

      bool done = OrderSend(trade_request,trade_result);
      if(!done || trade_result.retcode != TRADE_RETCODE_DONE)
        {
         Alert("Error: order #"+(string)ticket+" not removed, ErrorCode:"+(string)trade_result.retcode);
         return(false);
        }
      else
        {
         Print("Order #"+(string)ticket+" removed!");
         return(true);
        }
      break;
     }

   return(false);
  }

//MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM\\
//+------------------------------------------------------------------+
//| Checks and corrects type of filling policy                       |
//+------------------------------------------------------------------+
uint FillingCheck(const string symbol)
  {
   MqlTradeRequest   m_request;
   ZeroMemory(m_request);
   MqlTradeResult    m_result;
   ZeroMemory(m_result);

   ENUM_ORDER_TYPE_FILLING m_type_filling=0;
//--- get execution mode of orders by symbol
   ENUM_SYMBOL_TRADE_EXECUTION exec=(ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
//--- check execution mode
   if(exec==SYMBOL_TRADE_EXECUTION_REQUEST || exec==SYMBOL_TRADE_EXECUTION_INSTANT)
     {
      //--- neccessary filling type will be placed automatically
      return(m_result.retcode);
     }
//--- get possible filling policy types by symbol
   uint filling=(uint)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- check execution mode again
   if(exec==SYMBOL_TRADE_EXECUTION_MARKET)
     {
      //--- for the MARKET execution mode
      //--- analyze order
      if(m_request.action!=TRADE_ACTION_PENDING)
        {
         //--- in case of instant execution order
         //--- if the required filling policy is supported, add it to the request
         if(m_type_filling==ORDER_FILLING_FOK && (filling & SYMBOL_FILLING_FOK)!=0)
           {
            m_request.type_filling=m_type_filling;
            return(m_result.retcode);
           }
         if(m_type_filling==ORDER_FILLING_IOC && (filling & SYMBOL_FILLING_IOC)!=0)
           {
            m_request.type_filling=m_type_filling;
            return(m_result.retcode);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(m_result.retcode);
        }
      return(m_result.retcode);
     }
//--- EXCHANGE execution mode
   switch(m_type_filling)
     {
      case ORDER_FILLING_FOK:
         //--- analyze order
         if(m_request.action==TRADE_ACTION_PENDING)
           {
            //--- in case of pending order
            //--- add the expiration mode to the request
            if(!ExpirationCheck(symbol))
               m_request.type_time=ORDER_TIME_DAY;
            //--- stop order?
            if(m_request.type==ORDER_TYPE_BUY_STOP || m_request.type==ORDER_TYPE_SELL_STOP)
              {
               //--- in case of stop order
               //--- add the corresponding filling policy to the request
               m_request.type_filling=ORDER_FILLING_RETURN;
               return(m_result.retcode);
              }
           }
         //--- in case of limit order or instant execution order
         //--- if the required filling policy is supported, add it to the request
         if((filling & SYMBOL_FILLING_FOK)!=0)
           {
            m_request.type_filling=m_type_filling;
            return(m_result.retcode);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(m_result.retcode);
      case ORDER_FILLING_IOC:
         //--- analyze order
         if(m_request.action==TRADE_ACTION_PENDING)
           {
            //--- in case of pending order
            //--- add the expiration mode to the request
            if(!ExpirationCheck(symbol))
               m_request.type_time=ORDER_TIME_DAY;
            //--- stop order?
            if(m_request.type==ORDER_TYPE_BUY_STOP || m_request.type==ORDER_TYPE_SELL_STOP)
              {
               //--- in case of stop order
               //--- add the corresponding filling policy to the request
               m_request.type_filling=ORDER_FILLING_RETURN;
               return(m_result.retcode);
              }
           }
         //--- in case of limit order or instant execution order
         //--- if the required filling policy is supported, add it to the request
         if((filling & SYMBOL_FILLING_IOC)!=0)
           {
            m_request.type_filling=m_type_filling;
            return(m_result.retcode);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(m_result.retcode);
      case ORDER_FILLING_RETURN:
         //--- add filling policy to the request
         m_request.type_filling=m_type_filling;
         return(m_result.retcode);
     }
//--- unknown execution mode, set error code
   m_result.retcode=TRADE_RETCODE_ERROR;
   return(m_result.retcode);
  }
//MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM\\  
//+------------------------------------------------------------------+
//| Check expiration type of pending order                           |
//+------------------------------------------------------------------+
bool ExpirationCheck(const string symbol)
  {
   CSymbolInfo sym;
   MqlTradeRequest   m_request;
   ZeroMemory(m_request);
   MqlTradeResult    m_result;
   ZeroMemory(m_result);

//--- check symbol
   if(!sym.Name((symbol==NULL)?Symbol():symbol))
      return(false);
//--- get flags
   int flags=sym.TradeTimeFlags();
//--- check type
   switch(m_request.type_time)
     {
      case ORDER_TIME_GTC:
         if((flags&SYMBOL_EXPIRATION_GTC)!=0)
            return(true);
         break;
      case ORDER_TIME_DAY:
         if((flags&SYMBOL_EXPIRATION_DAY)!=0)
            return(true);
         break;
      case ORDER_TIME_SPECIFIED:
         if((flags&SYMBOL_EXPIRATION_SPECIFIED)!=0)
            return(true);
         break;
      case ORDER_TIME_SPECIFIED_DAY:
         if((flags&SYMBOL_EXPIRATION_SPECIFIED_DAY)!=0)
            return(true);
         break;
      default:
         Print(__FUNCTION__+": Unknown expiration type");
         break;
     }
//--- failed
   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Check_HTF()
  {
//if (OrderExist(_Symbol) || PositionExist(_Symbol)) return;

   static datetime LastTime = 0;
   if(LastTime == iTime(NULL,HTF,1))
      return;
   LastTime = iTime(NULL,HTF,1);

//-- UpOrDown
   if(Button_UpOrDown < 0)
     {
      double Filling1 = GetBufferValue(SuperTrend_Handle, 0, 1);
      double Filling2 = GetBufferValue(SuperTrend_Handle, 1, 1);
      if(Filling1 == EMPTY_VALUE || Filling1 <= 0 || Filling2 == EMPTY_VALUE || Filling2 <= 0 || Filling1 == Filling2)
         return;
      Button_UpOrDown = (Filling1 < Filling2 ? 0 : 1);
     }
   /*else if (FiboHTF.Price1 > 0 && FiboHTF.Price2 > 0)
   {
      if (FiboHTF.Price1 > FiboHTF.Price2
          ? iClose(NULL,HTF,1) > FiboHTF.Price1
          : iClose(NULL,HTF,1) < FiboHTF.Price1
         )
      {
         Button_UpOrDown = (FiboHTF.Price1 > FiboHTF.Price2 ? 0 : 1);
      }
   }*/

   Check_HTF_Fibo();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetBufferValue(int handle, int Buffer, int shift)
  {
   double buffer[];
   CopyBuffer(handle, Buffer, shift, 1, buffer);
   if(ArraySize(buffer) != 1)
     {
      return(EMPTY_VALUE);
     }

   return (buffer[0]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Check_HTF_Fibo()
  {
//-- Find HigherLine_Price/HigherLine_Time/LowerLine_Price/LowerLine_Time
   int HighestPriceIndex = iHighest(NULL, HTF, MODE_HIGH, LookHL_XBars, 1);
   double HigherLine_Price = iHigh(NULL, HTF, HighestPriceIndex);
   datetime HigherLine_Time = iTime(NULL, HTF, HighestPriceIndex);

   int LowestPriceIndex = iLowest(NULL, HTF, MODE_LOW, LookHL_XBars, 1);
   double LowerLine_Price = iLow(NULL, HTF, LowestPriceIndex);
   datetime LowerLine_Time = iTime(NULL, HTF, LowestPriceIndex);

//--- Create HLine
     {
      long chart_ID=0;        // chart's ID
      int sub_window=0;      // subwindow index
      color clr=clrRed;        // line color
      ENUM_LINE_STYLE style=STYLE_SOLID; // line style
      int width=1;           // line width
      bool back=false;        // in the background
      bool selectable=false;    // selectable
      bool selected=false;    // highlight to move
      bool hidden=true;       // hidden in the object list
      long z_order=0;         // priority for mouse click
      string Description=NULL;  // Description

      string name=ObjPref+"HigherLine";      // line name
      string ToolTip="Higher Line";
      double price=HigherLine_Price;            // line price
      HLineCreate(chart_ID, name, sub_window, price, clr, style, width, back, selectable, selected, hidden, z_order, Description, ToolTip);

      name=ObjPref+"LowerLine";      // line name
      ToolTip="Lower Line";
      price=LowerLine_Price;            // line price
      HLineCreate(chart_ID, name, sub_window, price, clr, style, width, back, selectable, selected, hidden, z_order, Description, ToolTip);
     }

   double HL_Level0_Price, HL_Level100_Price;
   datetime HL_Level0_Time, HL_Level100_Time;
   if(Button_UpOrDown == 0)
     {
      HL_Level0_Price = HigherLine_Price;
      HL_Level0_Time = HigherLine_Time;

      HL_Level100_Price = LowerLine_Price;
      HL_Level100_Time = LowerLine_Time;
     }
   else
     {
      HL_Level100_Price = HigherLine_Price;
      HL_Level100_Time = HigherLine_Time;

      HL_Level0_Price = LowerLine_Price;
      HL_Level0_Time = LowerLine_Time;
     }
   if(TimeCurrent() >= D'2023.3.1 17:15')
     {
      int a =0;
     }

   datetime HL_Time1;
   double HL_Price1;
   if(HigherLine_Time < LowerLine_Time)
     {
      HL_Time1 = HigherLine_Time;
      HL_Price1 = HigherLine_Price;
      if(LowerLine_Price > HL_Price1)
         HL_Price1 *= -1;
     }
   else
     {
      HL_Time1 = LowerLine_Time;
      HL_Price1 = LowerLine_Price;
      if(HigherLine_Price > HL_Price1)
         HL_Price1 *= -1;
     }

   if(HL_Level100_Price != HL_Level0_Price && HL_Level0_Price > 0 && HL_Level100_Price > 0)
     {
      int BuyOrSell;
      if(HL_Level0_Price > HL_Level100_Price)
         BuyOrSell = 1;
      else
         BuyOrSell = 0;

      double HL_Level38 = HL_Level0_Price + RetraceBreak_XLevel*0.01*(HL_Level100_Price - HL_Level0_Price);

      int StartBar = iBarShift(NULL, HTF, HL_Time1);
      while(StartBar > 0 &&
            (HL_Price1 > 0
             ? iHigh(NULL, HTF, StartBar) < HL_Price1
             : iLow(NULL, HTF, StartBar) > -HL_Price1
            )
           )
         StartBar--;

      StartBar--;
      if(StartBar < 0)
         return;

      datetime Fibo_HTF_Level0_Time = 0, Fibo_HTF_Level100_Time = 0;
      double Fibo_HTF_Level0_Price = 0, Fibo_HTF_Level100_Price = 0, Fibo_HTF_Level38 = 0;

      int ImpulseBars = 0, RetraceBars = 0;
      double ImpulseStartPrice = 0, ImpulseEndPrice = 0, RetraceStartPrice = 0, RetraceEndPrice = 0;
      datetime ImpulseStartTime = 0, ImpulseEndTime = 0, RetraceStartTime = 0, RetraceEndTime = 0;

      bool RetraceClosedOverLevel38 = false;

      for(int i = StartBar; i > 0; i--)
        {
         if(RetraceBars < 2 || !RetraceClosedOverLevel38)
           {
            if(BuyOrSell == 0)
              {
               if(iClose(NULL,HTF,i) > iOpen(NULL,HTF,i)
                  && (ImpulseBars == 0 || iHigh(NULL,HTF,i) > ImpulseEndPrice)
                 )
                 {
                  if(ImpulseBars == 0)
                    {
                     ImpulseStartPrice = iLow(NULL,HTF,i);
                     ImpulseStartTime = iTime(NULL,HTF,i);
                    }
                  ImpulseEndPrice = iHigh(NULL,HTF,i);
                  ImpulseEndTime = iTime(NULL,HTF,i);
                  ImpulseBars++;
                  RetraceBars = 0;
                 }
              }
            else
              {
               if(iClose(NULL,HTF,i) < iOpen(NULL,HTF,i)
                  && (ImpulseBars == 0 || iLow(NULL,HTF,i) < ImpulseEndPrice)
                 )
                 {
                  if(iTime(NULL,0,i) == D'2023.2.9 15:9')
                    {
                     int a  =0;
                    }
                  if(ImpulseBars == 0)
                    {
                     ImpulseStartPrice = iHigh(NULL,HTF,i);
                     ImpulseStartTime = iTime(NULL,HTF,i);
                    }
                  ImpulseEndPrice = iLow(NULL,HTF,i);
                  ImpulseEndTime = iTime(NULL,HTF,i);
                  ImpulseBars++;
                  RetraceBars = 0;
                 }
              }
           }
         //-- Retrace
           {
            if(BuyOrSell == 0)
              {
               if(iClose(NULL,HTF,i) < iOpen(NULL,HTF,i)
                  && (RetraceBars == 0 || iLow(NULL,HTF,i) < RetraceEndPrice)
                 )
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                       {
                        RetraceStartPrice = iHigh(NULL,HTF,i);
                        RetraceStartTime = iTime(NULL,HTF,i);
                        RetraceClosedOverLevel38 = false;
                       }
                     RetraceEndPrice = iLow(NULL,HTF,i);
                     RetraceEndTime = iTime(NULL,HTF,i);
                     RetraceBars++;
                     if(RetraceBars >= 2)
                       {
                        Fibo_HTF_Level0_Price = ImpulseEndPrice;
                        Fibo_HTF_Level0_Time = ImpulseEndTime;

                        Fibo_HTF_Level100_Price = ImpulseStartPrice;
                        Fibo_HTF_Level100_Time = ImpulseStartTime;

                        Fibo_HTF_Level38 = Fibo_HTF_Level0_Price + RetraceBreak_XLevel*0.01*(Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);

                        if(iClose(NULL,HTF,i) < Fibo_HTF_Level38 && iClose(NULL,HTF,i+1) < Fibo_HTF_Level38)
                          {
                           RetraceBars = 0;
                           ImpulseBars = 0;
                           RetraceClosedOverLevel38 = true;
                          }
                       }
                    }
                  else
                     ImpulseBars = 0;
                 }
              }
            else
              {
               if(iClose(NULL,HTF,i) > iOpen(NULL,HTF,i)
                  && (RetraceBars == 0 || iHigh(NULL,HTF,i) > RetraceEndPrice)
                 )
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                       {
                        RetraceStartPrice = iLow(NULL,HTF,i);
                        RetraceStartTime = iTime(NULL,HTF,i);
                        RetraceClosedOverLevel38 = false;
                       }
                     RetraceEndPrice = iHigh(NULL,HTF,i);
                     RetraceEndTime = iTime(NULL,HTF,i);
                     RetraceBars++;
                     if(RetraceBars >= 2)
                       {
                        Fibo_HTF_Level0_Price = ImpulseEndPrice;
                        Fibo_HTF_Level0_Time = ImpulseEndTime;

                        Fibo_HTF_Level100_Price = ImpulseStartPrice;
                        Fibo_HTF_Level100_Time = ImpulseStartTime;

                        Fibo_HTF_Level38 = Fibo_HTF_Level0_Price + RetraceBreak_XLevel*0.01*(Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);

                        if(iClose(NULL,HTF,i) > Fibo_HTF_Level38 && iClose(NULL,HTF,i+1) > Fibo_HTF_Level38)
                          {
                           RetraceBars = 0;
                           ImpulseBars = 0;
                           RetraceClosedOverLevel38 = true;
                          }
                       }
                    }
                  else
                     ImpulseBars = 0;
                 }
              }
           }
        }
      if(TimeCurrent() >= D'2023.1.2 2:30')
        {
         int a = 0;
        }
      if(Fibo_HTF_Level0_Time > 0 && Fibo_HTF_Level100_Time > 0)
        {
         static double Fibo_HTF_Level100_Price_LastBreak = 0;

         if(Fibo_HTF_Level100_Price_LastBreak > 0
            && Fibo_HTF_Level100_Price_LastBreak != Fibo_HTF_Level100_Price
           )
           {
            Fibo_HTF_Level100_Price_LastBreak = 0;

            datetime Level0_Time = Fibo_HTF_Level0_Time, Level100_Time = Fibo_HTF_Level100_Time;
            double Level0_Price = Fibo_HTF_Level0_Price, Level100_Price = Fibo_HTF_Level100_Price;
            Button_UpOrDown = 1-Button_UpOrDown;
            //if (Button_UpOrDown == 1)
              {
               Fibo_HTF_Level0_Price = Level100_Price;
               Fibo_HTF_Level0_Time = Level100_Time;

               Fibo_HTF_Level100_Price = Level0_Price;
               Fibo_HTF_Level100_Time = Level0_Time;
              }
            /*else
            {
               Fibo_HTF_Level100_Price = Level0_Price;
               Fibo_HTF_Level100_Time = Level0_Time;

               Fibo_HTF_Level0_Price = Level100_Price;
               Fibo_HTF_Level0_Time = Level100_Time;
            }  */
            if(ObjectFind(0,ObjPref+"HTF_Fibo") == 0
               &&
               !(ObjectGetInteger(0,ObjPref+"HTF_Fibo",OBJPROP_TIME,0) == Fibo_HTF_Level100_Time
                 && ObjectGetInteger(0,ObjPref+"HTF_Fibo",OBJPROP_TIME,1) == Fibo_HTF_Level0_Time
                )
              )
              {
               int a = 0;
              }

           }

         //-- change direction if close of HTF candle is over level100
         if(Fibo_HTF_Level100_Price_LastBreak != Fibo_HTF_Level100_Price
            && (Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price ? iClose(NULL,HTF,1) > Fibo_HTF_Level100_Price : iClose(NULL,HTF,1) < Fibo_HTF_Level100_Price)
           )
           {
            Fibo_HTF_Level100_Price_LastBreak = Fibo_HTF_Level100_Price;
            /*
            FiboLTF.Time1 = 0;
            FiboLTF.Price1 = 0;

            FiboLTF.Time2 = 0;
            FiboLTF.Price2 = 0;

            if (ShowFibo) ObjectDelete(0, ObjPref+"LTF_Fibo");

            DeleteOrders(_Symbol);*/
           }
         /* if (Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price
              ? iClose(NULL,HTF,0) < Fibo_HTF_Level100_Price
              : iClose(NULL,HTF,0) > Fibo_HTF_Level100_Price
             )*/
           {
            //--- Create HTF_Fibo
            if(ShowHTFFibo)
              {
               const long            chart_ID=0;        // chart's ID
               const string          name=ObjPref+"HTF_Fibo"; // object name
               const int             sub_window=0;      // subwindow index
               datetime              time1=Fibo_HTF_Level100_Time;           // first point time
               double                price1=Fibo_HTF_Level100_Price;          // first point price
               datetime              time2=Fibo_HTF_Level0_Time;           // second point time
               double                price2=Fibo_HTF_Level0_Price;          // second point price
               const color           clr=HTF_Fibo_Color;        // object color
               const ENUM_LINE_STYLE style=STYLE_DASH; // object line style
               const int             width=1;           // object line width
               const bool            back=false;        // in the background
               const bool            selection=false;    // highlight to move
               const bool            ray_left=false;    // object's continuation to the left
               const bool            ray_right=true;   // object's continuation to the right
               const bool            hidden=true;       // hidden in the object list
               const long            z_order=0;

               FiboLevelsCreate(chart_ID, name, sub_window, time1, price1, time2, price2, clr, style, width, back, selection, ray_left, ray_right, hidden, z_order);


               int levels = 3;
               double values[3] = {0, RetraceBreak_XLevel*0.01, 1};

               ObjectSetInteger(chart_ID,name,OBJPROP_LEVELS,levels);
               //--- set the properties of levels in the loop
               for(int i=0;i<levels;i++)
                 {
                  //--- level value
                  ObjectSetDouble(chart_ID,name,OBJPROP_LEVELVALUE,i,values[i]);
                  //--- level color
                  ObjectSetInteger(chart_ID,name,OBJPROP_LEVELCOLOR,i,HTF_Fibo_Color);
                  //--- level style
                  ObjectSetInteger(chart_ID,name,OBJPROP_LEVELSTYLE,i,STYLE_SOLID);
                  //--- level width
                  ObjectSetInteger(chart_ID,name,OBJPROP_LEVELWIDTH,i,1);
                  //--- level description
                  ObjectSetString(chart_ID,name,OBJPROP_LEVELTEXT,i,DoubleToString(100*values[i],1));
                 }

               ChartRedraw();

              }
            bool IsHTF_Fibo_Updated = MathAbs(FiboHTF.Price1 - Fibo_HTF_Level100_Price) > 0
                                      || MathAbs(FiboHTF.Price2 - Fibo_HTF_Level0_Price) > 0;
            if(IsHTF_Fibo_Updated)
              {
               DeleteOrders(_Symbol, -1, "N-LTF-");
               DeleteOrders(_Symbol, -1, "J-LTF-");

               FiboLTF.Time1 = 0;
               FiboLTF.Price1 = 0;

               FiboLTF.Time2 = 0;
               FiboLTF.Price2 = 0;

               if(ShowFibo)
                  ObjectDelete(0, ObjPref+"LTF_Fibo");

              }
            //else
              {
               FiboHTF.Time1 = Fibo_HTF_Level100_Time;
               FiboHTF.Price1 = Fibo_HTF_Level100_Price;

               FiboHTF.Time2 = Fibo_HTF_Level0_Time;
               FiboHTF.Price2 = Fibo_HTF_Level0_Price;
              }
            NewFibo = true;
            if(IsHTF_Fibo_Updated || (!PositionExist(_Symbol)))
               Check_LTF();
            //if (IsHTF_Fibo_Updated || (!OrderExist(_Symbol) && !PositionExist(_Symbol))) Check_LTF();
           }
        }
      else
        {
         FiboHTF.Time1 = 0;
         FiboHTF.Price1 = 0;

         FiboHTF.Time2 = 0;
         FiboHTF.Price2 = 0;

         if(ShowFibo)
            ObjectDelete(0, ObjPref+"HTF_Fibo");
        }
     }
  }

//int SuperTrend_Handle;
//bool CreateIndicatorsHandles()
//  {
//   SuperTrend_Handle
//      = iCustom(_Symbol, HTF, SuperTrend_IndicatorName
//                , SuperTrend_Period
//                , SuperTrend_Multiplier
//                , SuperTrend_Show_Filling
//               );
//
//   if(SuperTrend_Handle==INVALID_HANDLE)
//     {
//      //--- tell about the failure and output the error code
//      PrintFormat("Failed to create handle of the %s indicator for the symbol %s/%s, error code %d",
//                  SuperTrend_IndicatorName,
//                  _Symbol,
//                  EnumToString(HTF),
//                  GetLastError());
//      //--- the indicator is stopped early
//      return(false);
//     }
//
//   return(true);
//  }

//+------------------------------------------------------------------+
//| Create the horizontal line                                         |
//+------------------------------------------------------------------+
void HLineCreate(const long            chart_ID=0,        // chart's ID
                 const string          name="HLine",      // line name
                 const int             sub_window=0,      // subwindow index
                 double                price=0,            // line price
                 const color           clr=clrRed,        // line color
                 const ENUM_LINE_STYLE style=STYLE_SOLID, // line style
                 const int             width=1,           // line width
                 const bool            back=false,        // in the background
                 const bool            selectable=true,    // selectable
                 const bool            selected=false,    // highlight to move
                 const bool            hidden=true,       // hidden in the object list
                 const long            z_order=0,         // priority for mouse click
                 const string          Description=NULL,  // Description
                 const string          ToolTip=NULL)      // ToolTip
  {
//--- create a vertical line
   ObjectCreate(chart_ID,name,OBJ_HLINE,sub_window,0,price);
   ObjectSetDouble(chart_ID,name,OBJPROP_PRICE,0,price);
//--- set line color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set line display style
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set line width
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of moving the line by mouse
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selectable);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selected);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);

   if(Description != NULL)
      ObjectSetString(chart_ID,name,OBJPROP_TEXT,Description);
   if(ToolTip != NULL)
      ObjectSetString(chart_ID,name,OBJPROP_TOOLTIP,ToolTip);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool LastClosedPositionIsFromSameHTFFibo(string ThirdPart)
  {
   string result[];

   HistorySelect(0, TimeCurrent()+1);
   for(int i = HistoryDealsTotal()-1; i >= 0; i--)
     {
      ulong tick_out = HistoryDealGetTicket(i);
      if(tick_out <= 0 || HistoryDealGetString(tick_out, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tick_out, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      long PosID = HistoryDealGetInteger(tick_out, DEAL_POSITION_ID);

      bool MagicIsOkay = false;
      for(int j = i-1; j >= 0; j--)
        {
         ulong tick_in = HistoryDealGetTicket(j);
         if(tick_in <= 0 || HistoryDealGetString(tick_in, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tick_in, DEAL_ENTRY) != DEAL_ENTRY_IN || PosID != HistoryDealGetInteger(tick_in, DEAL_POSITION_ID))
            continue;

         MagicIsOkay = StringSplit(HistoryDealGetString(tick_in, DEAL_COMMENT), '-', result) == 3 && HistoryDealGetInteger(tick_in, DEAL_MAGIC) == MagicNumber;

         if(MagicIsOkay)
           {
            return(result[2] == ThirdPart);
           }

         break;
        }
      if(!MagicIsOkay)
         continue;

      break;
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckToCloseOppositeTradesOnHTFTrigger()
  {
   for(int i = PositionsTotal()-1; i >= 0; i--)
     {
      if(PositionGetTicket(i) <= 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "N-HTF-") != 0 && StringFind(comment, "J-HTF-") != 0)
         continue;


      long LastType = PositionGetInteger(POSITION_TYPE);
      datetime LastPosTime = (datetime)PositionGetInteger(POSITION_TIME);

      for(int j = i-1; j >= 0; j--)
        {
         if(PositionGetTicket(j) <= 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber
            || LastType == PositionGetInteger(POSITION_TYPE)
           )
            continue;

         ClosePosition(PositionGetTicket(j));
        }

      for(int j = OrdersTotal()-1; j >= 0; j--)
        {

         if(OrderGetTicket(j) <= 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || OrderGetInteger(ORDER_MAGIC) != MagicNumber
            || (OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_BUY_LIMIT && OrderGetInteger(ORDER_TYPE) != ORDER_TYPE_SELL_LIMIT)
            || LastType == (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT ? 0 : 1)
            || OrderGetInteger(ORDER_TIME_SETUP) > LastPosTime
           )
            continue;

         DeleteOrder(OrderGetTicket(j));
        }

      break;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket, double Volume=0)
  {
   if(!PositionSelectByTicket(ticket))
      return(false);

   MqlTradeRequest trade_request;
   ZeroMemory(trade_request);
   MqlTradeResult  trade_result;
   ZeroMemory(trade_result);

   string position_symbol = PositionGetString(POSITION_SYMBOL);

   if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK)
      trade_request.type_filling = ORDER_FILLING_FOK;
   else
      if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC)
         trade_request.type_filling = ORDER_FILLING_IOC;
      else
         if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==0)
            trade_request.type_filling = ORDER_FILLING_RETURN;
         else
            if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)>2)
              {
               uint FillingCheck = FillingCheck(position_symbol);
               if(FillingCheck > 0)
                 {
                  Alert("Error in closing position #"+(string)ticket+", ErrorCode: "+(string)FillingCheck);
                  return(false);
                 }
              }

   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);    // type of the position

   trade_request.action   =TRADE_ACTION_DEAL;        // type of trade operation
   trade_request.position =ticket;          // ticket of the position
   trade_request.symbol   =PositionGetString(POSITION_SYMBOL);          // symbol
   trade_request.volume   =(Volume <= 0 ? PositionGetDouble(POSITION_VOLUME) : Volume);                   // volume of the position
   trade_request.deviation=MaxSlippage;                        // allowed deviation from the price

//--- set the price and order type depending on the position type
   if(type==POSITION_TYPE_BUY)
     {
      trade_request.price=SymbolInfoDouble(trade_request.symbol,SYMBOL_BID);
      trade_request.type =ORDER_TYPE_SELL;
     }
   else
     {
      trade_request.price=SymbolInfoDouble(trade_request.symbol,SYMBOL_ASK);
      trade_request.type =ORDER_TYPE_BUY;
     }

   bool done = OrderSend(trade_request,trade_result);
   if(!done || trade_result.retcode != TRADE_RETCODE_DONE)
      Alert("Error: positon #"+(string)ticket+" not closed, ErrorCode:"+(string)trade_result.retcode);
   else
     {
      Print("Positon #"+(string)ticket+" closed!");
      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckToDeleteRelatedFiboIfPositionExist()
  {
   if(FiboHTF.Price1 > 0 && FiboHTF.Price2 > 0
      &&
      (PositionExist(_Symbol,-1,"N-HTF-"+DoubleToString(FiboHTF.Price1,_Digits)+","+DoubleToString(FiboHTF.Price2,_Digits))
       ||
       PositionExist(_Symbol,-1,"J-HTF-"+DoubleToString(FiboHTF.Price1,_Digits)+","+DoubleToString(FiboHTF.Price2,_Digits))
      )
     )
     {
      FiboHTF.Price1 = 0;
      FiboHTF.Price2 = 0;
      FiboHTF.Time1 = 0;
      FiboHTF.Time2 = 0;

      if(ShowHTFFibo)
         ObjectDelete(0, ObjPref+"HTF_Fibo");
     }

   if(FiboLTF.Price1 > 0 && FiboLTF.Price2 > 0
      &&
      (PositionExist(_Symbol,-1,"N-LTF-"+DoubleToString(FiboLTF.Price1,_Digits)+","+DoubleToString(FiboLTF.Price2,_Digits))
       ||
       PositionExist(_Symbol,-1,"J-LTF-"+DoubleToString(FiboLTF.Price1,_Digits)+","+DoubleToString(FiboLTF.Price2,_Digits))
      )
     )
     {
      FiboLTF.Price1 = 0;
      FiboLTF.Price2 = 0;
      FiboLTF.Time1 = 0;
      FiboLTF.Time2 = 0;

      if(ShowFibo)
         ObjectDelete(0, ObjPref+"LTF_Fibo");
     }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePositions(string symbol, int pos_type=-1, string comment=NULL)
  {
   int total = PositionsTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0
         && (symbol == NULL || PositionGetString(POSITION_SYMBOL) == symbol)
         && (PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         && (pos_type == -1 || PositionGetInteger(POSITION_TYPE) == pos_type)
         && (comment == NULL || StringFind(PositionGetString(POSITION_COMMENT), comment) == 0)
        )
        {
         ClosePosition(ticket);
        }
     }
  }

//+------------------------------------------------------------------+
