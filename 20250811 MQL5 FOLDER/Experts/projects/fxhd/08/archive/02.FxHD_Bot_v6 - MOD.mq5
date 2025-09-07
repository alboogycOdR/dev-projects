//+------------------------------------------------------------------+
//|                                                 FxHD Bot v6.mq5  |
//|                                     Copyright 2023, FxHDAcademy. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, FxHDAcademy."
#property link      "https://www.mql5.com"
#property version   "1.00"

bool ShowFibo = true;

#include <Trade/SymbolInfo.mqh>

input group "================ Fibonacci Properties ================"
   input ENUM_TIMEFRAMES HTF = PERIOD_H1;
   input color HTF_Fibo_Color = clrOrange;
   input ENUM_TIMEFRAMES LTF = PERIOD_M5;
   input color LTF_Fibo_Color = clrBlue;
   input double MinorBreakLimitOrderPrice_XLevel = 0.0;
   input double MajorBreakLimitOrderPrice_XLevel = 100.0;
   input int LookHL_XBars = 200;
   input double RetraceBreak_XLevel = 30.9;
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
   
input group "================ SuperTrend Properties ================"
   //input string SuperTrend_Settings = "================ SuperTrend Properties ================";
   input string SuperTrend_IndicatorName = "SuperTrend";
   input int SuperTrend_Period = 10;
   input double SuperTrend_Multiplier = 3;
   const bool SuperTrend_Show_Filling = true;

input group "================ Trade Properties ================"
   //input string Trade_Properties = "================ Trade Properties ================"; //====================
   input double TakeProfit_XLevel_HTF = 161.8;
   input double TakeProfit_XLevelOfFiboHTF_LTF = 0;
   input double StopLoss_XLevel_Distance_HTF = 70.0;
   input double StopLoss_XLevel_Distance_LTF = 70.0;
   input int MagicNumber = 1234;
   input int MaxSlippage = 9999;

input group "================ Money Management Properties ================"
  //input string MoneyManagement = "================ Money Management Properties ================";
  enum EnumPosLotType
    {
    UseFixedLot = 0, //Use Fixed Lot
    UseBalancePerLot = 1, //Use Balance Per Lot
    UseEquityPerLot = 2, //Use Equity Per Lot
    UseRiskPercentage = 3, //Use Risk Percentage
    UseFixedMargin = 4, //Use Fixed Margin
    };
  input EnumPosLotType LotType = UseFixedLot;
  input double FixedLot = 0.1;// Fixed Lot
  input double BalancePerLot = 10000; //Balance per Lot
  input double EquityPerLot = 10000; //Equity per Lot
  input double RiskPercentage = 3; //Risk Percentage
  input double FixedMargin = 1000; //Fixed Margin
  input double MaxLot = 0; //MaxLot (0 or negative means no limit)




#include "FXHD_BOT_INCL.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(ShowFibo)
     {
      if(ObjectFind(0, ObjPref + "HTF_Fibo") == 0)
        {
         FiboHTF.Time1 = (datetime)ObjectGetInteger(0, ObjPref + "HTF_Fibo", OBJPROP_TIME, 0);
         FiboHTF.Price1 = ObjectGetDouble(0, ObjPref + "HTF_Fibo", OBJPROP_PRICE, 0);
         FiboHTF.Time2 = (datetime)ObjectGetInteger(0, ObjPref + "HTF_Fibo", OBJPROP_TIME, 1);
         FiboHTF.Price2 = ObjectGetDouble(0, ObjPref + "HTF_Fibo", OBJPROP_PRICE, 1);
        }
      if(ObjectFind(0, ObjPref + "LTF_Fibo") == 0)
        {
         FiboLTF.Time1 = (datetime)ObjectGetInteger(0, ObjPref + "LTF_Fibo", OBJPROP_TIME, 0);
         FiboLTF.Price1 = ObjectGetDouble(0, ObjPref + "LTF_Fibo", OBJPROP_PRICE, 0);
         FiboLTF.Time2 = (datetime)ObjectGetInteger(0, ObjPref + "LTF_Fibo", OBJPROP_TIME, 1);
         FiboLTF.Price2 = ObjectGetDouble(0, ObjPref + "LTF_Fibo", OBJPROP_PRICE, 1);
        }
     }
     
   //instantiate supertrend indicator
   if(!CreateIndicatorsHandles())
      return(INIT_FAILED);
  //---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
//todo - alister
//free memory of indicator
//remove objects on chart
ObjectDelete(0, ObjPref + "LTF_Fibo");
ObjectDelete(0, ObjPref + "HTF_Fibo");

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
   //reset fibo if position exist
   CheckToDeleteRelatedFiboIfPositionExist();

  //  if(TimeCurrent() >= D'2023.4.3 21:15'){int a = 0;}


   //--Check SuperTrend
   Check_HTF();
   
   
   /*
      static bool IsInitial = true;

      datetime t = TimeCurrent();
      //if (t < D'2023.2.10 20:6') return;
      if (IsInitial)
      {
         IsInitial = false;

         ObjectCreate(0, "HLine_Up", OBJ_HLINE, 0, 0, 1825.06);
         ObjectCreate(0, "HLine_Dn", OBJ_HLINE, 0, 0, 1819.80);

         long lparam=0;
         double dparam=0;
         string sparam = ObjPref+"Up-Button";
         OnChartEvent(CHARTEVENT_OBJECT_CLICK, lparam,dparam,sparam );
      }
      if (t >= D'2023.2.24 14:30')
      {
         int a  = 0;
      }
   */


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

     //if (!PositionExist(_Symbol))
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
      else
         if(FiboHTF.Time1 > 0)
           {
            if(IsNewCandle_HTF)
              {
               Fibo_Level100_Price = FiboHTF.Price1;
               Fibo_Level0_Price = FiboHTF.Price2;
               Fibo_Time2 = (datetime)MathMax(FiboHTF.Time1, FiboHTF.Time2);
               TF = HTF;
              }
           }
      
      /*  
      
      
      */
      double Fibo_HTF_Level100_Price = FiboHTF.Price1;
      double Fibo_HTF_Level0_Price = FiboHTF.Price2;

      if(Fibo_Level100_Price > 0 && 
           Fibo_Level0_Price > 0 && 
             Fibo_Level100_Price != Fibo_Level0_Price && 
               Fibo_HTF_Level100_Price > 0 && 
                 Fibo_HTF_Level0_Price > 0 && 
                   Fibo_HTF_Level100_Price != Fibo_HTF_Level0_Price)
        {
         int UpOrDown = (Fibo_Level100_Price > Fibo_Level0_Price ? 0 : 1);
         int bars = iBars(NULL,TF);
         int NumOfBars = 0;

         for(int i = 1; i < bars; i++)
           {
            if(iTime(NULL,TF,i) < Fibo_Time2)
               break;
            if(UpOrDown == 0
               ? iClose(NULL,TF,i) > iOpen(NULL,TF,i) && iClose(NULL,TF,i) > Fibo_Level100_Price
               : iClose(NULL,TF,i) < iOpen(NULL,TF,i) && iClose(NULL,TF,i) < Fibo_Level100_Price)
              {
               NumOfBars++;
              }
            else
               if(NumOfBars == 2)
                  break;
               else
                  NumOfBars = 0;
            if(NumOfBars == 3)
               break;
           }
         if(NumOfBars > 1)
           {
            double LimitOrderPrice;

            /*MINOR BREAK

            */

            if(NumOfBars == 2)  //means minor break
              {
               LimitOrderPrice = Fibo_Level0_Price + MinorBreakLimitOrderPrice_XLevel * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
              }

            /*MAJOR BREAK

            */
            else //means major break
              {
               LimitOrderPrice = Fibo_Level0_Price + MajorBreakLimitOrderPrice_XLevel * 0.01 * (Fibo_Level100_Price - Fibo_Level0_Price);
              }
            LimitOrderPrice = NormalizeDouble(LimitOrderPrice, _Digits);
            ENUM_ORDER_TYPE type = (UpOrDown == 0 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);
            /*
            
            
            */
            string comment = (NumOfBars == 2 ? "N-" : "J-") 
            + (TF == HTF ? "HTF-" : "LTF-") 
            + DoubleToString(FiboHTF.Price1,_Digits) 
            + "," + DoubleToString(FiboHTF.Price2,_Digits);

            string comment_other = (NumOfBars == 2 ? "J-" : "N-") 
            + (TF == HTF ? "HTF-" : "LTF-") 
            + DoubleToString(FiboHTF.Price1,_Digits) + "," 
            + DoubleToString(FiboHTF.Price2,_Digits);

            if(!OrderExist(_Symbol, type, comment) && !OrderExist(_Symbol, type, comment_other)
               && !PositionExist(_Symbol, UpOrDown, comment)
               && !PositionExist(_Symbol, UpOrDown, comment_other)
               && !LastClosedPositionIsFromSameHTFFibo(DoubleToString(FiboHTF.Price1,_Digits) + "," + DoubleToString(FiboHTF.Price2,_Digits)))
              {
               DeleteOrders(_Symbol);
               string symbol = _Symbol;
               int digits = _Digits;
               double price = LimitOrderPrice;
               double tp = Fibo_HTF_Level0_Price + (TF == HTF ? TakeProfit_XLevel_HTF : TakeProfit_XLevelOfFiboHTF_LTF) * 0.01 * (Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);
               double StopLoss_XLevel_Distance = (TF == HTF ? StopLoss_XLevel_Distance_HTF : StopLoss_XLevel_Distance_LTF);
               double sl = StopLoss_XLevel_Distance * 0.01 * MathAbs(Fibo_Level100_Price - Fibo_Level0_Price);
               sl = price - (UpOrDown == 0 ? 1 : -1) * sl;
               double lot = Lots(symbol, UpOrDown, price, sl);
               //&& -ticket != TRADE_RETCODE_INVALID_STOPS && -ticket != TRADE_RETCODE_INVALID_PRICE
               int ticket = SendOrder(symbol, type, lot, price, MaxSlippage, sl, tp, comment, MagicNumber);
               if(ticket <= 0)
                  Alert("Error: Order not opened, ErrorCode: " + (string)(-ticket) + " :: " + symbol + " " + OrderTypeToStr(type) + " " + DoubleToString(lot, 2) + " lots @ " + DoubleToString(price, digits) + " SL: " + DoubleToString(sl, digits) + " TP: " + DoubleToString(tp, digits) + " Comment: " + comment);
               else
                  if(ticket > 0)
                    {
                     Print("Order opened: " + symbol + " " + OrderTypeToStr(type) + " " + DoubleToString(lot, 2) + " lots @ " + DoubleToString(price, digits) + " SL: " + DoubleToString(sl, digits) + " TP: " + DoubleToString(tp, digits) + " Comment: " + comment);
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
   /*
     if (id == CHARTEVENT_OBJECT_CLICK
         && (sparam == ObjPref+"Up-Button" || sparam == ObjPref+"Down-Button")
         && !OrderExist(_Symbol)
         && !PositionExist(_Symbol)
        )
     {
        int UpOrDown = (sparam == ObjPref+"Up-Button" ? 0 : 1);

        ObjectSetInteger(0, sparam, OBJPROP_STATE, true);
        ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, (UpOrDown == 0 ? clrLimeGreen : clrRed));

        string OtherButtonName = (UpOrDown == 0 ? ObjPref+"Down-Button" : ObjPref+"Up-Button");
        ObjectSetInteger(0, OtherButtonName, OBJPROP_STATE, false);
        ObjectSetInteger(0, OtherButtonName, OBJPROP_BGCOLOR, clrBlack);

        double HigherLinePrice = 0, LowerLinePrice = 0;
        for (int i = ObjectsTotal(0,0,OBJ_HLINE)-1; i >= 0; i--)
        {
           string ObjName = ObjectName(0, i, 0, OBJ_HLINE);
           double Price = ObjectGetDouble(0, ObjName, OBJPROP_PRICE, 0);
           if (HigherLinePrice == 0 || HigherLinePrice < Price) HigherLinePrice = Price;
           if (LowerLinePrice == 0 || LowerLinePrice > Price) LowerLinePrice = Price;
        }
        if (HigherLinePrice > LowerLinePrice && LowerLinePrice > 0)
        {
           int LastOrFirst = 1;
           int UpOrDownTrend = -1;
           double TrendPrices_HTF[2] = {0, 0};
           datetime TrendTimes_HTF[2] = {0, 0};

           int bars = iBars(NULL, HTF);
           for (int i = 1; i < bars; i++)
           {
              if (UpOrDownTrend != 0 && iHigh(NULL,HTF,i) >= HigherLinePrice)
              {
                 if (LastOrFirst == 1) UpOrDownTrend = 0;
                 LastOrFirst--;
              }
              if (LastOrFirst >= 0 && UpOrDownTrend != 1 && iLow(NULL,HTF,i) <= LowerLinePrice)
              {
                 if (LastOrFirst == 1) UpOrDownTrend = 1;
                 LastOrFirst--;
              }

              if (UpOrDownTrend >= 0)
              {
              if (UpOrDownTrend == 0
                  ? iClose(NULL,HTF,i) > iOpen(NULL,HTF,i)
                  : iClose(NULL,HTF,i) < iOpen(NULL,HTF,i)
                 )
              {
                 if (TrendPrices_HTF[1] == 0)
                 {
                    TrendPrices_HTF[1] = (UpOrDownTrend == 0 ? iHigh(NULL, HTF, i) : iLow(NULL, HTF, i));
                    TrendTimes_HTF[1] = iTime(NULL, HTF, i);
                 }
                 TrendPrices_HTF[0] = (UpOrDownTrend == 0 ? iLow(NULL, HTF, i) : iHigh(NULL, HTF, i));
                 TrendTimes_HTF[0] = iTime(NULL, HTF, i);
              }
              }

              if (LastOrFirst < 0) break;
           }

           double Fibo_HTF_Level0_Price = 0, Fibo_HTF_Level100_Price = 0;
           datetime Fibo_HTF_Level0_Time = 0, Fibo_HTF_Level100_Time = 0;

           if (UpOrDown == 0 ? TrendPrices_HTF[0] > TrendPrices_HTF[1] : TrendPrices_HTF[0] < TrendPrices_HTF[1])
           {
              Fibo_HTF_Level0_Price = TrendPrices_HTF[0];
              Fibo_HTF_Level0_Time = TrendTimes_HTF[0];

              Fibo_HTF_Level100_Price = TrendPrices_HTF[1];
              Fibo_HTF_Level100_Time = TrendTimes_HTF[1];
           }
           else
           {
              Fibo_HTF_Level0_Price = TrendPrices_HTF[1];
              Fibo_HTF_Level0_Time = TrendTimes_HTF[1];

              Fibo_HTF_Level100_Price = TrendPrices_HTF[0];
              Fibo_HTF_Level100_Time = TrendTimes_HTF[0];
           }

           //--- Create HTF_Fibo
           if (ShowFibo)
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

           //else
           {
              FiboHTF.Time1 = Fibo_HTF_Level100_Time;
              FiboHTF.Price1 = Fibo_HTF_Level100_Price;

              FiboHTF.Time2 = Fibo_HTF_Level0_Time;
              FiboHTF.Price2 = Fibo_HTF_Level0_Price;
           }

           NewFibo = true;
           Check_LTF();


        }
     }*/
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
            ObjectDelete(0, ObjPref + "LTF_Fibo");
           }
         return;
        }
      int BuyOrSell;
      if(Fibo_HTF_Level0 > Fibo_HTF_Level100)
         BuyOrSell = 1;
      else
         BuyOrSell = 0;
      double Fibo_HTF_Level38 = Fibo_HTF_Level0 + RetraceBreak_XLevel * 0.01 * (Fibo_HTF_Level100 - Fibo_HTF_Level0);
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
                  // if(iTime(NULL,0,i) == D'2023.2.9 15:9')
                  //   {
                  //    int a  = 0;
                  //   }
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
                        Fibo_LTF_Level38 = Fibo_LTF_Level0_Price + RetraceBreak_XLevel * 0.01 * (Fibo_LTF_Level100_Price - Fibo_LTF_Level0_Price);
                        if(iClose(NULL,LTF,i) < Fibo_LTF_Level38 && iClose(NULL,LTF,i + 1) < Fibo_LTF_Level38)
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
                        Fibo_LTF_Level38 = Fibo_LTF_Level0_Price + RetraceBreak_XLevel * 0.01 * (Fibo_LTF_Level100_Price - Fibo_LTF_Level0_Price);
                        if(iClose(NULL,LTF,i) > Fibo_LTF_Level38 && iClose(NULL,LTF,i + 1) > Fibo_LTF_Level38)
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
            const long            chart_ID = 0;      // chart's ID
            const string          name = ObjPref + "LTF_Fibo"; // object name
            const int             sub_window = 0;    // subwindow index
            datetime              time1 = Fibo_LTF_Level100_Time;         // first point time
            double                price1 = Fibo_LTF_Level100_Price;        // first point price
            datetime              time2 = Fibo_LTF_Level0_Time;         // second point time
            double                price2 = Fibo_LTF_Level0_Price;        // second point price
            const color           clr = LTF_Fibo_Color;      // object color
            const ENUM_LINE_STYLE style = STYLE_DASH; // object line style
            const int             width = 1;         // object line width
            const bool            back = false;      // in the background
            const bool            selection = false;  // highlight to move
            const bool            ray_left = false;  // object's continuation to the left
            const bool            ray_right = true; // object's continuation to the right
            const bool            hidden = true;     // hidden in the object list
            const long            z_order = 0;
            FiboLevelsCreate(chart_ID, name, sub_window, time1, price1, time2, price2, clr, style, width, back, selection, ray_left, ray_right, hidden, z_order);
            int levels = 3;
            double values[3] = {0, RetraceBreak_XLevel * 0.01, 1};
            ObjectSetInteger(chart_ID,name,OBJPROP_LEVELS,levels);
            //--- set the properties of levels in the loop
            for(int i = 0; i < levels; i++)
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
               ObjectSetString(chart_ID,name,OBJPROP_LEVELTEXT,i,DoubleToString(100 * values[i],1));
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
//check supertrend indicator
//result
//   Button_UpOrDown becomes either 0 or 1
//      or stays default value of -1
void Check_HTF()
  {
    //if (OrderExist(_Symbol) || PositionExist(_Symbol)) return;

   static datetime LastTime = 0;
   if(LastTime == iTime(NULL,HTF,1))
      return;
   LastTime = iTime(NULL,HTF,1);

   //-- UpOrDown
   if(Button_UpOrDown < 0) //default value is -1
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
   }
   */

   Check_HTF_Fibo();

  }

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
     //{
    long chart_ID = 0;      // chart's ID
    int sub_window = 0;    // subwindow index
    color clr = clrRed;      // line color
    ENUM_LINE_STYLE style = STYLE_SOLID; // line style
    int width = 1;         // line width
    bool back = false;      // in the background
    bool selectable = false;  // selectable
    bool selected = false;  // highlight to move
    bool hidden = true;     // hidden in the object list
    long z_order = 0;       // priority for mouse click
    string Description = NULL; // Description
    string name = ObjPref + "HigherLine";  // line name
    string ToolTip = "Higher Line";
    double price = HigherLine_Price;          // line price
    HLineCreate(chart_ID, name, sub_window, price, clr, style, width, back, selectable, selected, hidden, z_order, Description, ToolTip);
    name = ObjPref + "LowerLine";  // line name
    ToolTip = "Lower Line";
    price = LowerLine_Price;          // line price
    HLineCreate(chart_ID, name, sub_window, price, clr, style, width, back, selectable, selected, hidden, z_order, Description, ToolTip);
    //}
     /*
     
     */
   double HL_Level0_Price, HL_Level100_Price;
   datetime HL_Level0_Time, HL_Level100_Time;
   /*
   
   */
   //Button_UpOrDown ==0==DOWNTREND
   if(Button_UpOrDown == 0)
     {
      HL_Level0_Price = HigherLine_Price;
      HL_Level0_Time = HigherLine_Time;
      HL_Level100_Price = LowerLine_Price;
      HL_Level100_Time = LowerLine_Time;
     }
   //Button_UpOrDown ==1==UPTREND
   else
     {
      HL_Level100_Price = HigherLine_Price;
      HL_Level100_Time = HigherLine_Time;
      HL_Level0_Price = LowerLine_Price;
      HL_Level0_Time = LowerLine_Time;
     }
  //  if(TimeCurrent() >= D'2023.3.1 17:15')
  //    {
  //     int a = 0;
  //    }

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
      double HL_Level38 = HL_Level0_Price + RetraceBreak_XLevel * 0.01 * (HL_Level100_Price - HL_Level0_Price);
      
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
         /*
         
         
         
         */
      datetime Fibo_HTF_Level0_Time = 0, Fibo_HTF_Level100_Time = 0;
      double Fibo_HTF_Level0_Price = 0, Fibo_HTF_Level100_Price = 0, Fibo_HTF_Level38 = 0;
      int ImpulseBars = 0, RetraceBars = 0;
      double ImpulseStartPrice = 0, ImpulseEndPrice = 0, RetraceStartPrice = 0, RetraceEndPrice = 0;
      datetime ImpulseStartTime = 0, ImpulseEndTime = 0, RetraceStartTime = 0, RetraceEndTime = 0;
      bool RetraceClosedOverLevel38 = false;
      //---------------
      for(int i = StartBar; i > 0; i--)
        {
         if(RetraceBars < 2 || !RetraceClosedOverLevel38)
           {
            if(BuyOrSell == 0)
              {
               if(iClose(NULL,HTF,i) > iOpen(NULL,HTF,i) && (ImpulseBars == 0 || iHigh(NULL,HTF,i) > ImpulseEndPrice))
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
               if(iClose(NULL,HTF,i) < iOpen(NULL,HTF,i) && (ImpulseBars == 0 || iLow(NULL,HTF,i) < ImpulseEndPrice))
                 {
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
               if(iClose(NULL,HTF,i) < iOpen(NULL,HTF,i) && (RetraceBars == 0 || iLow(NULL,HTF,i) < RetraceEndPrice))
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                      {
                      RetraceStartPrice = iHigh(NULL,HTF,i);
                      RetraceStartTime = iTime(NULL,HTF,i);
                      RetraceClosedOverLevel38 = false;
                      }
                     //---------------
                     RetraceEndPrice = iLow(NULL,HTF,i);
                     RetraceEndTime = iTime(NULL,HTF,i);
                     RetraceBars++;
                     //--------------
                     if(RetraceBars >= 2)
                      {
                        Fibo_HTF_Level0_Price = ImpulseEndPrice;
                        Fibo_HTF_Level0_Time = ImpulseEndTime;
                        Fibo_HTF_Level100_Price = ImpulseStartPrice;
                        Fibo_HTF_Level100_Time = ImpulseStartTime;
                        Fibo_HTF_Level38 = Fibo_HTF_Level0_Price + RetraceBreak_XLevel * 0.01 * (Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);
                        if(iClose(NULL,HTF,i) < Fibo_HTF_Level38 && iClose(NULL,HTF,i + 1) < Fibo_HTF_Level38)
                        {
                          RetraceBars = 0;
                          ImpulseBars = 0;
                          RetraceClosedOverLevel38 = true;
                        }
                      }
                    }
                  else
                  {   
                    ImpulseBars = 0;
                  }
                 }
              }
            else
              {
               if(iClose(NULL,HTF,i) > iOpen(NULL,HTF,i) && (RetraceBars == 0 || iHigh(NULL,HTF,i) > RetraceEndPrice))
                 {
                  if(ImpulseBars >= 2)
                    {
                     if(RetraceBars == 0)
                     {
                      RetraceStartPrice = iLow(NULL,HTF,i);
                      RetraceStartTime = iTime(NULL,HTF,i);
                      RetraceClosedOverLevel38 = false;
                     }
                     //============
                     RetraceEndPrice = iHigh(NULL,HTF,i);
                     RetraceEndTime = iTime(NULL,HTF,i);
                     RetraceBars++;
                     //-------------
                     if(RetraceBars >= 2)
                      {
                        Fibo_HTF_Level0_Price = ImpulseEndPrice;
                        Fibo_HTF_Level0_Time = ImpulseEndTime;
                        Fibo_HTF_Level100_Price = ImpulseStartPrice;
                        Fibo_HTF_Level100_Time = ImpulseStartTime;
                        Fibo_HTF_Level38 = Fibo_HTF_Level0_Price + RetraceBreak_XLevel * 0.01 * (Fibo_HTF_Level100_Price - Fibo_HTF_Level0_Price);
                        if(iClose(NULL,HTF,i) > Fibo_HTF_Level38 && iClose(NULL,HTF,i + 1) > Fibo_HTF_Level38)
                        {
                          RetraceBars = 0;
                          ImpulseBars = 0;
                          RetraceClosedOverLevel38 = true;
                        }
                      }
                    }
                  else
                  {
                     ImpulseBars = 0;
                  }
                 }
              }
           }
        }


      if(Fibo_HTF_Level0_Time > 0 && Fibo_HTF_Level100_Time > 0)
        {
         static double Fibo_HTF_Level100_Price_LastBreak = 0;
         if(Fibo_HTF_Level100_Price_LastBreak > 0 && Fibo_HTF_Level100_Price_LastBreak != Fibo_HTF_Level100_Price)
           {
            Fibo_HTF_Level100_Price_LastBreak = 0;
            datetime Level0_Time = Fibo_HTF_Level0_Time, Level100_Time = Fibo_HTF_Level100_Time;
            double Level0_Price = Fibo_HTF_Level0_Price, Level100_Price = Fibo_HTF_Level100_Price;
            Button_UpOrDown = 1 - Button_UpOrDown;


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
            }  
            */


            if(ObjectFind(0,ObjPref + "HTF_Fibo") == 0
               &&
               !(ObjectGetInteger(0,ObjPref + "HTF_Fibo",OBJPROP_TIME,0) == Fibo_HTF_Level100_Time
                 && ObjectGetInteger(0,ObjPref + "HTF_Fibo",OBJPROP_TIME,1) == Fibo_HTF_Level0_Time
                )
              )
              {
               int a = 0;
              }
           }

         //-- change direction if close of HTF candle is over level100
         /*if(Fibo_HTF_Level100_Price_LastBreak != Fibo_HTF_Level100_Price 
            && 
           (Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price ? iClose(NULL,HTF,1) > Fibo_HTF_Level100_Price : iClose(NULL,HTF,1) < Fibo_HTF_Level100_Price))
           {
            Fibo_HTF_Level100_Price_LastBreak = Fibo_HTF_Level100_Price;
            /*
            FiboLTF.Time1 = 0;
            FiboLTF.Price1 = 0;

            FiboLTF.Time2 = 0;
            FiboLTF.Price2 = 0;

            if (ShowFibo) ObjectDelete(0, ObjPref+"LTF_Fibo");

            DeleteOrders(_Symbol);
            */
          // }

         //replaced by below

          if (Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price) {
              if (iClose(NULL, HTF, 1) > Fibo_HTF_Level100_Price) {
                Fibo_HTF_Level100_Price_LastBreak = Fibo_HTF_Level100_Price;   // Your code here
                Print("__");Print("Condition: Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price, iClose(NULL, HTF, 1) > Fibo_HTF_Level100_Price at  "+TimeCurrent());Print("__");
              }

          } else {
              if (iClose(NULL, HTF, 1) < Fibo_HTF_Level100_Price) {
                  // Your code here
                  Print("__");
                  Print("Condition: Fibo_HTF_Level100_Price < Fibo_HTF_Level0_Price, iClose(NULL, HTF, 1) < Fibo_HTF_Level100_Price at  "+TimeCurrent());Print("__");
              }
          }







          /* if (Fibo_HTF_Level100_Price > Fibo_HTF_Level0_Price
                ? iClose(NULL,HTF,0) < Fibo_HTF_Level100_Price
                : iClose(NULL,HTF,0) > Fibo_HTF_Level100_Price
              )
          */
           {
            //--- Create HTF_Fibo
            if(ShowFibo)
              {
                const long            chart_ID = 0;      // chart's ID
                const string          name = ObjPref + "HTF_Fibo"; // object name
                const int             sub_window = 0;    // subwindow index
                datetime              time1 = Fibo_HTF_Level100_Time;         // first point time
                double                price1 = Fibo_HTF_Level100_Price;        // first point price
                datetime              time2 = Fibo_HTF_Level0_Time;         // second point time
                double                price2 = Fibo_HTF_Level0_Price;        // second point price
                const color           clr = HTF_Fibo_Color;      // object color
                const ENUM_LINE_STYLE style = STYLE_DASH; // object line style
                const int             width = 1;         // object line width
                const bool            back = false;      // in the background
                const bool            selection = false;  // highlight to move
                const bool            ray_left = false;  // object's continuation to the left
                const bool            ray_right = true; // object's continuation to the right
                const bool            hidden = true;     // hidden in the object list
                const long            z_order = 0;
                FiboLevelsCreate(chart_ID, name, sub_window, time1, price1, time2, price2, clr, style, width, back, selection, ray_left, ray_right, hidden, z_order);
                int levels = 3;
                double values[3] = {0, RetraceBreak_XLevel * 0.01, 1};
                ObjectSetInteger(chart_ID,name,OBJPROP_LEVELS,levels);
                //--- set the properties of levels in the loop
                for(int i = 0; i < levels; i++)
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
                    ObjectSetString(chart_ID,name,OBJPROP_LEVELTEXT,i,DoubleToString(100 * values[i],1));
                  }
                ChartRedraw();
              }
            
            bool IsHTF_Fibo_Updated = MathAbs(FiboHTF.Price1 - Fibo_HTF_Level100_Price) > 0 || MathAbs(FiboHTF.Price2 - Fibo_HTF_Level0_Price) > 0;
            if(IsHTF_Fibo_Updated)
              {
               DeleteOrders(_Symbol, -1, "N-LTF-");
               DeleteOrders(_Symbol, -1, "J-LTF-");
               FiboLTF.Time1 = 0;
               FiboLTF.Price1 = 0;
               FiboLTF.Time2 = 0;
               FiboLTF.Price2 = 0;
               if(ShowFibo)
                  ObjectDelete(0, ObjPref + "LTF_Fibo");
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
            ObjectDelete(0, ObjPref + "HTF_Fibo");
        }
     }
  }
