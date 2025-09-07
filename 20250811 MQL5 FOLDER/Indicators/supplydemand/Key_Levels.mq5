#property indicator_chart_window
#property version "2.0"
#property strict
//https://www.perfecttrendsystem.com/blog_mt5_2/en/key-levels-indicator-for-mt5
input string H=" --- Mode_Settings ---";
input bool Show_00_50_Levels=true;
input bool Show_20_80_Levels=true;
input color Level_00_Color=clrLime;
input color Level_50_Color=clrGray;
input color Level_20_Color=clrRed;
input color Level_80_Color=clrGreen;

double dXPoint=1;
double Div=0;
double i=0;
double HighPrice= 0;
double LowPrice = 0;
int iDigits;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   iDigits=_Digits;
   if(_Digits==5 || _Digits==3) dXPoint=10;
   if(_Digits==3) iDigits=2;
   if(_Digits==5) iDigits=4;

   Div=0.1/(_Point*dXPoint);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnCalculate(
                const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
   ArraySetAsSeries(high,true); ArraySetAsSeries(low,true); ArraySetAsSeries(time,true);
   int ih=ArrayMaximum(high, 2); if(ih<0) return rates_total;
   int il=ArrayMinimum(low, 2); if(il<0) return rates_total;
   HighPrice= MathRound((high[ih]+1)*Div);
   LowPrice = MathRound((low[il]-1)*Div);
   if(Show_00_50_Levels)
     {
      for(i=LowPrice; i<=HighPrice; i++)
        {
         if(MathMod(i,5)==0.0)
           {
            string name="RoundPrice "+DoubleToString(i,0);
            if(ObjectFind(0,name)!=0)
              {
               ObjectCreate(0,name,OBJ_HLINE,0,time[1],i/Div);
               ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
               if(MathMod(i,10)==0.0) ObjectSetInteger(0,name,OBJPROP_COLOR,Level_00_Color);
               else ObjectSetInteger(0,name,OBJPROP_COLOR,Level_50_Color);
              }
           }
        }

     }

   if(Show_20_80_Levels)
     {
      for(i=LowPrice; i<=HighPrice; i++)
        {
         if(StringSubstr(DoubleToString(i/Div,iDigits),StringLen(DoubleToString(i/Div,iDigits))-2,2)=="20")
           {
            string name="RoundPrice "+DoubleToString(i,0);
            if(ObjectFind(0,name)!=0)
              {
               ObjectCreate(0,name,OBJ_HLINE,0,time[1],i/Div);
               ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
               ObjectSetInteger(0,name,OBJPROP_COLOR,Level_20_Color);
              }
           }
         if(StringSubstr(DoubleToString(i/Div,iDigits),StringLen(DoubleToString(i/Div,iDigits))-2,2)=="80")
           {
            string name="RoundPrice "+DoubleToString(i,0);
            if(ObjectFind(0,name)!=0)
              {
               ObjectCreate(0,name,OBJ_HLINE,0,time[1],i/Div);
               ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
               ObjectSetInteger(0,name,OBJPROP_COLOR,Level_80_Color);
              }
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
   ObjectsDeleteAll(0,"Round");
  }
//+------------------------------------------------------------------+
