#include <Trade\Trade.mqh>
CTrade trade;
#define TOP 0
#define LOW 1

input string _LICENCE_KEY ="XXX-XXX-XXX-XXX";
input string Note_="put zero lotsize for pair lowest lotsize";
input double Lot_size = 0;
input int NUM_TRADES_AT_A_TIME = 1;
input string inf = "_______Zig Zag Values________";
input int Depth = 24, Deviation = 10, Steps = 6;

double Lot_Size;
ulong _MAGIC ;
double curr_ball = AccountInfoDouble(ACCOUNT_BALANCE);
double total_profit = 0;
string eaa = "Elevator Robot PV1.0";
string name =eaa+"__";

int OnInit()
{
   string url = "https://license.vix75-king.com/";
   string phone ="+27 66 291 7141";
   //login(url,eaa,_LICENCE_KEY,phone);
   
   _MAGIC = 111222333;
   if(Lot_size == 0)Lot_Size=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   else
      Lot_Size = Lot_size;
   ObjectsDeleteAll(0,-1,-1);
   return(INIT_SUCCEEDED);
}
 
 
void OnDeinit(const int reason)
  {
      ObjectsDeleteAll(0,-1,-1);
  }


void OnTick()
{
   int bot_total_pos = 0;
      
   for(int p =0;p<PositionsTotal();p++)
   {
      if(PositionGetInteger(POSITION_MAGIC) == _MAGIC) bot_total_pos++;
   }
   if(cntrol()== "BUY" &&  bot_total_pos < NUM_TRADES_AT_A_TIME == 0 && CheckMA() == "BUY")
   {
      trade.SetExpertMagicNumber(_MAGIC);
      double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
      bool orderBuy = trade.Buy(Lot_Size,NULL,Ask,0,0,"EA_BUY");
   }
   if(cntrol()== "SELL" &&  bot_total_pos < NUM_TRADES_AT_A_TIME && CheckMA() == "SELL")
   {
      trade.SetExpertMagicNumber(_MAGIC);
      double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
      bool orderSell = trade.Sell(Lot_Size,NULL,Bid,0,0,"EA_SELL");
   }
   
   if(PositionsTotal() > 0 && cntrol() != "HOLD")
   {
      for(int i = 0;i<PositionsTotal();i++)
      {
         int tktt = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && cntrol()== "SELL" &&  PositionGetInteger(POSITION_MAGIC) == _MAGIC)
          {
            trade.PositionClose(tktt); 
          }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && cntrol()== "BUY" &&  PositionGetInteger(POSITION_MAGIC) == _MAGIC)
          {
            trade.PositionClose(tktt); 
          }
      }
   }
   total_profit = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE)-curr_ball,2);
   drawLabel();
}
string cntrol()
{
   int high1 = ZigZag(0,TOP),low1 = ZigZag(0,LOW);
   if(iLow(_Symbol,_Period,0) == iLow(_Symbol,_Period, low1))
   {
       return "BUY";
   }
   if(iHigh(_Symbol,_Period,0) == iHigh(_Symbol,_Period, high1))
   {
       return "SELL";
   }
   return "HOLD";
}
string CheckMA()
 {
   double MA[],MA2[];
   int MA_Definition = iMA(_Symbol,_Period,150,0,MODE_SMA,PRICE_MEDIAN);
   int MA2_Definition = iMA(_Symbol,_Period,50,0,MODE_SMA,PRICE_MEDIAN);

   ArraySetAsSeries(MA,true);
   ArraySetAsSeries(MA2,true);
   
   CopyBuffer(MA_Definition,0,0,5,MA);
   CopyBuffer(MA2_Definition,0,0,5,MA2);

   if(iHigh(_Symbol,_Period,0) < MA[0] && MA2[0] < MA[0])
   {
      return "SELL";
   }
   if(iLow(_Symbol,_Period,0) > MA[0] && MA2[0] > MA[0])
   {
      return "BUY";
   }
   return "HOLD" ;
 }
int ZigZag(int pos,int buffer)
{
   double arr[];
   double candle[2];
   int j=0;
   int zig = iCustom(_Symbol,_Period,"Examples/ZigZagColor.ex5",Depth,Deviation,Steps);

   ArraySetAsSeries(arr,true);
   CopyBuffer(zig,buffer,0,1000,arr);
   
   for(int i = 0; i<1000 ; i++)
   {
      if(arr[i] != 0)
      {
         if(pos == j)
         {
            return i;
         }
         j++;
      }
      
   }

   
   return -1;
}
void drawLabel()
{
   color clr = clrAqua;
   if(AccountInfoDouble(ACCOUNT_PROFIT) >0 ) clr = clrLime;
   if(AccountInfoDouble(ACCOUNT_PROFIT) < 0) clr = clrRed;
   ChartSetInteger(0,CHART_FOREGROUND,0,false);
   
   static color topclr = clrWhite;
   if(topclr == clrWhite)topclr = clrAliceBlue;
   else if(topclr == clrAliceBlue)topclr = clrRed;
   else if(topclr == clrRed)topclr = clrGreen;
   else if(topclr == clrGreen)topclr = clrLime;
   else if(topclr == clrLime)topclr = clrBlueViolet;
   else if(topclr == clrBlueViolet)topclr = clrPurple;
   else if(topclr == clrPurple)topclr = clrPink;
   else if(topclr == clrPink)topclr = clrBrown;
   else if(topclr == clrBrown)topclr = clrBlue;
   else if(topclr == clrBlue)topclr = clrWhite;
   
   ObjectCreate(0,"HEADER2",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"HEADER2",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"HEADER2",OBJPROP_XDISTANCE,445);
   ObjectSetInteger(0,"HEADER2",OBJPROP_YDISTANCE,110);
   ObjectSetInteger(0,"HEADER2",OBJPROP_XSIZE,510);
   ObjectSetInteger(0,"HEADER2",OBJPROP_YSIZE,10);
   ObjectSetInteger(0,"HEADER2",OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,"HEADER2",OBJPROP_BORDER_COLOR,clrAliceBlue);
   ObjectSetInteger(0,"HEADER2",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"HEADER2",OBJPROP_BGCOLOR,clrBlueViolet);
   
   ObjectCreate(0,"HEADER3",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"HEADER3",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"HEADER3",OBJPROP_XDISTANCE,955);
   ObjectSetInteger(0,"HEADER3",OBJPROP_YDISTANCE,110);
   ObjectSetInteger(0,"HEADER3",OBJPROP_XSIZE,5);
   ObjectSetInteger(0,"HEADER3",OBJPROP_YSIZE,110);
   ObjectSetInteger(0,"HEADER3",OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,"HEADER3",OBJPROP_BORDER_COLOR,clrAliceBlue);
   ObjectSetInteger(0,"HEADER3",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"HEADER3",OBJPROP_BGCOLOR,topclr);
   
   ObjectCreate(0,"HEADER1",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"HEADER1",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"HEADER1",OBJPROP_XDISTANCE,440);
   ObjectSetInteger(0,"HEADER1",OBJPROP_YDISTANCE,110);
   ObjectSetInteger(0,"HEADER1",OBJPROP_XSIZE,5);
   ObjectSetInteger(0,"HEADER1",OBJPROP_YSIZE,110);
   ObjectSetInteger(0,"HEADER1",OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,"HEADER1",OBJPROP_BORDER_COLOR,clrAliceBlue);
   ObjectSetInteger(0,"HEADER1",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"HEADER1",OBJPROP_BGCOLOR,topclr);
   
   ObjectCreate(0,"HEADER",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"HEADER",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"HEADER",OBJPROP_XDISTANCE,450);
   ObjectSetInteger(0,"HEADER",OBJPROP_YDISTANCE,100);
   ObjectSetInteger(0,"HEADER",OBJPROP_XSIZE,500);
   ObjectSetInteger(0,"HEADER",OBJPROP_YSIZE,100);
   ObjectSetInteger(0,"HEADER",OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,"HEADER",OBJPROP_BORDER_COLOR,clrAliceBlue);
   ObjectSetInteger(0,"HEADER",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"HEADER",OBJPROP_BGCOLOR,clrAqua);

   
   ObjectCreate(0,"infoname",OBJ_LABEL,0,0,0);
   //ObjectSetString(0,"infoname",name,OBJ_TEXT,15,"Impact",topclr);
   ObjectSetString(0,"infoname",OBJPROP_TEXT,name);
   ObjectSetString(0,"infoname",OBJPROP_FONT,"Impact");
   ObjectSetInteger(0,"infoname",OBJPROP_FONTSIZE,30);
   ObjectSetInteger(0,"infoname",OBJPROP_COLOR,topclr);
   ObjectSetInteger(0,"infoname",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"infoname",OBJPROP_XDISTANCE,530);
   ObjectSetInteger(0,"infoname",OBJPROP_YDISTANCE,80);
   
   ObjectCreate(0,"infocop",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"infocop",OBJPROP_TEXT,"This is e bot by vix75_king. Coppt Right Act 2021.");
   ObjectSetString(0,"infocop",OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,"infocop",OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,"infocop",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"infocop",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"infocop",OBJPROP_XDISTANCE,480);
   ObjectSetInteger(0,"infocop",OBJPROP_YDISTANCE,22);
   
   ObjectCreate(0,"infodes",OBJ_LABEL,0,0,0);
   ObjectSetString(0,"infodes",OBJPROP_TEXT,"coded by Peace TheeCoder");
   ObjectSetString(0,"infodes",OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,"infodes",OBJPROP_FONTSIZE,5);
   ObjectSetInteger(0,"infodes",OBJPROP_COLOR,clrBlack);
   ObjectSetInteger(0,"infodes",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"infodes",OBJPROP_XDISTANCE,850);
   ObjectSetInteger(0,"infodes",OBJPROP_YDISTANCE,15);
   
   //Main Panel  
   ObjectCreate(0,"MAIN",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"MAIN",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"MAIN",OBJPROP_XDISTANCE,5);
   ObjectSetInteger(0,"MAIN",OBJPROP_YDISTANCE,300);
   ObjectSetInteger(0,"MAIN",OBJPROP_XSIZE,200);
   ObjectSetInteger(0,"MAIN",OBJPROP_YSIZE,250);
   ObjectSetInteger(0,"MAIN",OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,"MAIN",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"MAIN",OBJPROP_BGCOLOR,clrBlueViolet);
   
   ObjectCreate(0,"MAIN2",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"MAIN2",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,"MAIN2",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"MAIN2",OBJPROP_YDISTANCE,320);
   ObjectSetInteger(0,"MAIN2",OBJPROP_XSIZE,190);
   ObjectSetInteger(0,"MAIN2",OBJPROP_YSIZE,220);
   ObjectSetInteger(0,"MAIN2",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,"MAIN2",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"MAIN2",OBJPROP_BGCOLOR,clr);
   
   color yy = clrWhite;
   if(total_profit > 0)yy = clrGreen;
   if(total_profit < 0)yy = clrRed;
   
   ObjectDelete(1,"Profit");
   ObjectCreate(0,"Profit",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"Profit",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetString(0,"Profit",OBJPROP_TEXT,"TOTAL PROFIT : ");
   ObjectSetString(0,"Profit",OBJPROP_FONT,"Impact");
   ObjectSetInteger(0,"Profit",OBJPROP_FONTSIZE,12);
   ObjectSetInteger(0,"Profit",OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,"Profit",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"Profit",OBJPROP_YDISTANCE,87);
   
   ObjectDelete(1,"Profit1");
   ObjectCreate(0,"Profit1",OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,"Profit1",OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetString(0,"Profit1",OBJPROP_TEXT,(string)total_profit);
   ObjectSetString(0,"Profit1",OBJPROP_FONT,"Impact");
   ObjectSetInteger(0,"Profit1",OBJPROP_FONTSIZE,12);
   ObjectSetInteger(0,"Profit1",OBJPROP_COLOR,yy);
   ObjectSetInteger(0,"Profit1",OBJPROP_XDISTANCE,110);
   ObjectSetInteger(0,"Profit1",OBJPROP_YDISTANCE,87);
   
   make_detail("licence", "LICENSE--------------> "+_LICENCE_KEY,315,clrWhiteSmoke);
   make_detail("lot",     "LOT_SIZE---------------> "+(string)Lot_Size,295,clrWhiteSmoke);
   make_detail("trades",  "MAX TRADES-------------> "+(string)NUM_TRADES_AT_A_TIME,275,clrWhiteSmoke);
   //make_detail("mating",  "ALLOW MARTINGALE-------> "+(string)allow_martingale,255,clrWhiteSmoke);
   //make_detail("trail",   "ALLOW TRAILING SL------> "+(string)allow_trailing_sl,235,clrWhiteSmoke);
   
   make_detail("balinel",    "__________________________ ",185,clrBlueViolet);
   make_detail("bal",    "BALLANCE----------------> "+(string)NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE),2),165,clrWhite);
   make_detail("opp",    "OPEN POSITIONS----------> "+(string)PositionsTotal(),145,clrWhite);
   make_detail("prof",    "ACCOUNT PROFIT----------> "+(string)NormalizeDouble(AccountInfoDouble(ACCOUNT_PROFIT),2),125,clrWhite);
   

}
void make_detail(string name,string txt,int y,color clr)
{

   ObjectDelete(1,name);
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
  ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_FONT,"Impact");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,14);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
}


