//+------------------------------------------------------------------+
//|                                                incl_keylevel.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
uint sendOrder(ENUM_ORDER_TYPE orderType,double Price,double iSL,double iTP,double Volume,string comment,string lvl)
  {

//if( orderType==ORDER_TYPE_BUY_STOP)
//{
//trade.BuyStop(Volume,Price,NULL,iSL,iTP,ORDER_TIME_GTC,0,comment);
//}



//--- prepare a request
   MqlTradeRequest request= {};
   request.action=TRADE_ACTION_PENDING;
   request.type=orderType;
   request.magic=InpMagic;
   request.symbol=_Symbol;
   request.volume=Volume;
   request.sl=NormalizeDouble(iSL,_Digits);
   request.tp=NormalizeDouble(iTP,_Digits);
   request.deviation=slippage;
   request.comment=comment;
//  request.type_filling=GetFilling(request.symbol);
   request.price=NormalizeDouble(Price,_Digits);
   request.expiration=TimeCurrent()+PeriodSeconds(PERIOD_CURRENT)*10;
//--- send a trade request
   MqlTradeResult result= {0};
   bool success=OrderSend(request,result);
   if(!success)
     {
      if(debug)
        {
         //Alert(_Symbol," Error in order send: ",orderType," ",result.retcode," lots= ",Volume," Price= ",Price," SL= ",SL," request.type= ",request.type," TP= ",TP);
         Print(_Symbol," Error in order send: ",orderType," ",result.retcode," lots= ",Volume," Price= ",Price," SL= ",SL," request.type= ",request.type," TP= ",TP);

        }
     }


//--- return code of the trade server reply
   return result.retcode;



  }
  
  //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void deletePendingOrder(ulong ticket)
  {
//--- declare and initialize the trade request and result of trade request
   MqlTradeRequest request= {};
   MqlTradeResult  result= {};
   int total=OrdersTotal(); // total number of placed pending orders
//--- iterate over all placed pending orders
   for(int i=total-1; i>=0; i--)
     {
      ulong  order_ticket=OrderGetTicket(i);                   // order ticket
      ulong  exmagic=OrderGetInteger(ORDER_MAGIC);
      string order_symbol=OrderGetString(ORDER_SYMBOL);              // MagicNumber of the order
      //--- if the MagicNumber matches
      if(exmagic==InpMagic && order_symbol==Symbol() && (order_ticket==ticket || ticket==0))
        {
         //--- zeroing the request and result values
         ZeroMemory(request);
         ZeroMemory(result);
         //--- setting the operation parameters
         request.action=TRADE_ACTION_REMOVE;                   // type of trade operation
         request.order = order_ticket;                         // order ticket
         //--- send the request
         if(!OrderSend(request,result))
            PrintFormat("deletePOrderSend error %d",GetLastError());  // if unable to send the request, output the error code
         //--- information about the operation
         PrintFormat("deletePretcode=%u  deal=%I64u  order=%I64u",result.retcode,result.deal,result.order);
        }
     }
  }
  
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawRectangle(const string name, const double price1, const double price2, const color colour)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, 0, 0);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, D'1970.01.01');
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, D'3000.12.31');
   ObjectSetInteger(0, name, OBJPROP_COLOR, colour);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
  }
//LEVELS-DRAWLINE
void DrawLine(const string name, const double price)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, 0);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, LineColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
  }
  
  
//+------------------------------------------------------------------+
//| Create rectangle by the given coordinates                        |
//+------------------------------------------------------------------+
bool RectangleCreate(const long            chart_ID=0,        // chart's ID
                     const string          name="Rectangle",  // rectangle name
                     const int             sub_window=0,      // subwindow index
                     datetime              time1=0,           // first point time
                     double                price1=0,          // first point price
                     datetime              time2=0,           // second point time
                     double                price2=0,          // second point price
                     const color           clr=clrRed,        // rectangle color
                     const ENUM_LINE_STYLE style=STYLE_SOLID, // style of rectangle lines
                     const int             width=1,           // width of rectangle lines
                     const bool            fill=false,        // filling rectangle with color
                     const bool            back=false,        // in the background
                     const bool            selection=true,    // highlight to move
                     const bool            hidden=true,       // hidden in the object list
                     const long            z_order=0)         // priority for mouse click
  {
//--- set anchor points' coordinates if they are not set
   ChangeRectangleEmptyPoints(time1,price1,time2,price2);
//--- reset the error value
   ResetLastError();
//--- create a rectangle by the given coordinates
   if(!ObjectCreate(chart_ID,name,OBJ_RECTANGLE,sub_window,time1,price1,time2,price2))
     {
      Print(__FUNCTION__,
            ": failed to create a rectangle! Error code = ",GetLastError());
      return(false);
     }
//--- set rectangle color
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
//--- set the style of rectangle lines
   ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
//--- set width of the rectangle lines
   ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
//--- enable (true) or disable (false) the mode of filling the rectangle
   ObjectSetInteger(chart_ID,name,OBJPROP_FILL,fill);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
//--- enable (true) or disable (false) the mode of highlighting the rectangle for moving
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);
   ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chart_ID,name,OBJPROP_ZORDER,z_order);
//--- successful execution
   return(true);
  }
  
  //+------------------------------------------------------------------+
//| convert numeric response codes to string mnemonics               |
//+------------------------------------------------------------------+
string GetRetcodeID(int retcode)
  {
   switch(retcode)
     {
      case 10004:
         return("TRADE_RETCODE_REQUOTE");
         break;
      case 10006:
         return("TRADE_RETCODE_REJECT");
         break;
      case 10007:
         return("TRADE_RETCODE_CANCEL");
         break;
      case 10008:
         return("TRADE_RETCODE_PLACED");
         break;
      case 10009:
         return("TRADE_RETCODE_DONE");
         break;
      case 10010:
         return("TRADE_RETCODE_DONE_PARTIAL");
         break;
      case 10011:
         return("TRADE_RETCODE_ERROR");
         break;
      case 10012:
         return("TRADE_RETCODE_TIMEOUT");
         break;
      case 10013:
         return("TRADE_RETCODE_INVALID");
         break;
      case 10014:
         return("TRADE_RETCODE_INVALID_VOLUME");
         break;
      case 10015:
         return("TRADE_RETCODE_INVALID_PRICE");
         break;
      case 10016:
         return("TRADE_RETCODE_INVALID_STOPS");
         break;
      case 10017:
         return("TRADE_RETCODE_TRADE_DISABLED");
         break;
      case 10018:
         return("TRADE_RETCODE_MARKET_CLOSED");
         break;
      case 10019:
         return("TRADE_RETCODE_NO_MONEY");
         break;
      case 10020:
         return("TRADE_RETCODE_PRICE_CHANGED");
         break;
      case 10021:
         return("TRADE_RETCODE_PRICE_OFF");
         break;
      case 10022:
         return("TRADE_RETCODE_INVALID_EXPIRATION");
         break;
      case 10023:
         return("TRADE_RETCODE_ORDER_CHANGED");
         break;
      case 10024:
         return("TRADE_RETCODE_TOO_MANY_REQUESTS");
         break;
      case 10025:
         return("TRADE_RETCODE_NO_CHANGES");
         break;
      case 10026:
         return("TRADE_RETCODE_SERVER_DISABLES_AT");
         break;
      case 10027:
         return("TRADE_RETCODE_CLIENT_DISABLES_AT");
         break;
      case 10028:
         return("TRADE_RETCODE_LOCKED");
         break;
      case 10029:
         return("TRADE_RETCODE_FROZEN");
         break;
      case 10030:
         return("TRADE_RETCODE_INVALID_FILL");
         break;
      case 10031:
         return("TRADE_RETCODE_CONNECTION");
         break;
      case 10032:
         return("TRADE_RETCODE_ONLY_REAL");
         break;
      case 10033:
         return("TRADE_RETCODE_LIMIT_ORDERS");
         break;
      case 10034:
         return("TRADE_RETCODE_LIMIT_VOLUME");
         break;
      case 10035:
         return("TRADE_RETCODE_INVALID_ORDER");
         break;
      case 10036:
         return("TRADE_RETCODE_POSITION_CLOSED");
         break;
      default:
         return("TRADE_RETCODE_UNKNOWN="+IntegerToString(retcode));
         break;
     }
//---
  }

//+------------------------------------------------------------------+
//| Deletes limit orders                                             |
//+------------------------------------------------------------------+
bool DeleteLimitOrders(void)
  {
//--- go through the list of all orders
   int orders=OrdersTotal();
   for(int i=0; i<orders; i++)
     {
      if(!m_order.SelectByIndex(i))
        {
         PrintFormat("OrderSelect() failed: Error=", GetLastError());
         return(false);
        }
      //--- get the name of the symbol and the position id (magic)
      string symbol=m_order.Symbol();
      long   magic =m_order.Magic();
      ulong  ticket=m_order.Ticket();
      //--- if they correspond to our values
      if(symbol==Symbol() && magic==InpMagic)
        {
         if(trade.OrderDelete(ticket))
           {   Print(trade.ResultRetcodeDescription());}
         else
           {   Print("OrderDelete() failed! ", trade.ResultRetcodeDescription());}
         return(false);
        }
     }
//---
   return(true);
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawArrow(const datetime time, double price, const uchar code, const color clr, string comment)
  {

   static int s_id = 0;    // to make unique string
   const string name = StringFormat("Arrow_%2d %s", s_id++, comment);

   if(!ObjectCreate(CHART_ID, name, OBJ_ARROW, SUB_WINDOW, time, price))
     {
      PrintFormat("%s(): Failed to create OBJ_TEXT. Error code: [%d]", __FUNCTION__, GetLastError());
      return;
     }

   ObjectSetInteger(CHART_ID, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(CHART_ID, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(CHART_ID, name, OBJPROP_WIDTH, 3);
  }

//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(string symbol,int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes
   int filling=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- Return true, if mode fill_type is allowed
   return((filling & fill_type)==fill_type);
  }

//+------------------------------------------------------------------+
//| Move the rectangle anchor point                                  |
//+------------------------------------------------------------------+
bool RectanglePointChange(const long   chart_ID=0,       // chart's ID
                          const string name="Rectangle", // rectangle name
                          const int    point_index=0,    // anchor point index
                          datetime     time=0,           // anchor point time coordinate
                          double       price=0)          // anchor point price coordinate
  {
//--- if point position is not set, move it to the current bar having Bid price
   if(!time)
      time=TimeCurrent();
   if(!price)
      price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- reset the error value
   ResetLastError();
//--- move the anchor point
   if(!ObjectMove(chart_ID,name,point_index,time,price))
     {
      Print(__FUNCTION__,
            ": failed to move the anchor point! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the values of rectangle's anchor points and set default    |
//| values for empty ones                                            |
//+------------------------------------------------------------------+
void ChangeRectangleEmptyPoints(datetime &time1,double &price1,
                                datetime &time2,double &price2)
  {
//--- if the first point's time is not set, it will be on the current bar
   if(!time1)
      time1=TimeCurrent();
//--- if the first point's price is not set, it will have Bid value
   if(!price1)
      price1=SymbolInfoDouble(Symbol(),SYMBOL_BID);
//--- if the second point's time is not set, it is located 9 bars left from the second one
   if(!time2)
     {
      //--- array for receiving the open time of the last 10 bars
      datetime temp[10];
      CopyTime(Symbol(),Period(),time1,10,temp);
      //--- set the second point 9 bars left from the first one
      time2=temp[0];
     }
//--- if the second point's price is not set, move it 300 points lower than the first one
   if(!price2)
      price2=price1-300*SymbolInfoDouble(Symbol(),SYMBOL_POINT);
  }
//+------------------------------------------------------------------+
//| Delete the rectangle                                             |
//+------------------------------------------------------------------+
bool RectangleDelete(const long   chart_ID=0,       // chart's ID
                     const string name="Rectangle") // rectangle name
  {
//--- reset the error value
   ResetLastError();
//--- delete rectangle
   if(!ObjectDelete(chart_ID,name))
     {
      Print(__FUNCTION__,
            ": failed to delete rectangle! Error code = ",GetLastError());
      return(false);
     }
//--- successful execution
   return(true);
  }
  //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {

   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      if(debug)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
     {
      if(debug)
         Print(__FILE__," ",__FUNCTION__,", ERROR: ","Ask == 0.0 OR Bid == 0.0");
      return(false);
     }
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Check Pending Orders                                             |
//+------------------------------------------------------------------+
bool CheckPendingOrders(ENUM_ORDER_TYPE type, double price)
  {
//---

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(m_order.SelectByIndex(i) &&
         m_order.Symbol() == _Symbol &&
         m_order.Magic() == InpMagic &&
         m_order.OrderType() == type &&
         m_order.PriceOpen() == price)
        {
         return(true);
        }
     }

//---
   return(false);
  }