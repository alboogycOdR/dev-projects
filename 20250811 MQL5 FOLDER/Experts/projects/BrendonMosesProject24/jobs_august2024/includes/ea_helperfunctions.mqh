//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,       // event ID
                  const long& lparam,   // long type event parameter
                  const double& dparam,   // double type event parameter
                  const string& sparam    // string type event parameter
                 )
  {
   if(id == CHARTEVENT_CHART_CHANGE)
      WallPaper.Resize();
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
                      const long            z_order=100)         // priority for mouse click


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
bool PositionExist(string symbol, int pos_type=-1, string comment=NULL)
  {
   int total = PositionsTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0
         && PositionGetString(POSITION_SYMBOL) == symbol
         && (PositionGetInteger(POSITION_MAGIC) == _MAGIC_)
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
         && (OrderGetInteger(ORDER_MAGIC) == _MAGIC_)
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
      
      //======================
      Print("ordercomment : "+OrderGetString(ORDER_COMMENT));
      Print("comment : " +comment);
      
      if(ticket > 0  && (symbol == NULL || OrderGetString(ORDER_SYMBOL) == symbol)
         && (OrderGetInteger(ORDER_MAGIC) == _MAGIC_)
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
int SendOrder(const string sSymbol
, const ENUM_ORDER_TYPE eType
, const double fLot
, double &prices
, const uint nSlippage = 1000
, const double fSL = 0
, const double fTP = 0
, const string nComment = ""
, const ulong nMagic = 0
, datetime expiration=0)
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
         Print("Expert Removed due to not enough money!");
         ExpertRemove();
        }
     }

   return(RetVal);
  }

int PlaceOrder(const string symbol
 , const ENUM_ORDER_TYPE eType
 , const double fLot
 , double &prices
 , const uint nSlippage = 1000
 , const double fSL = 0
 , const double fTP = 0
 , const string nComment = ""
 , const ulong nMagic = 0
 , datetime expiration=0)
  {

    int         digit=int(SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   double      point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double      price=SymbolInfoDouble(symbol, SYMBOL_ASK);
   datetime    time=TimeCurrent();

   double fPoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int nDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);


//----
   if(!digit || !point || !price || !time) return(TRADE_RETCODE_ERROR);      
   if(!expiration)  time=0;
  //-----
   int RetVal = 0;
   string position_symbol = symbol;
//-----
   MqlTradeRequest trade_request;   
   MqlTradeResult  trade_result;
   MqlTradeCheckResult check;
   ZeroMemory(trade_request);ZeroMemory(trade_result);ZeroMemory(check);
//-----

   trade_request.type  = eType;
//-----
   if(expiration > 0)
     {
      trade_request.type_time = ORDER_TIME_SPECIFIED;
      trade_request.expiration = time + expiration*3600;
     }
     if(expiration == 0)
     {
      trade_request.type_time=ORDER_TIME_DAY;
     }
   //if(eType == ORDER_TYPE_BUY) trade_request.price = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), nDigits);
   //else if(eType == ORDER_TYPE_SELL) trade_request.price = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), nDigits);
   //else 
   trade_request.price  = NormalizeDouble(prices, nDigits);
   trade_request.action =TRADE_ACTION_PENDING;
   trade_request.symbol  = symbol;
   trade_request.volume  = fLot;
   //=======
   trade_request.sl = NormalizeDouble(fSL, nDigits);

   trade_request.tp = NormalizeDouble(fTP, nDigits);
   //=======
   trade_request.deviation = nSlippage;
   //-------filling
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

   
   // if(eType < 2)
   //    trade_request.action = TRADE_ACTION_DEAL;
   // else
   
   trade_request.stoplimit = 0;
   trade_request.comment   = nComment;
   trade_request.magic     = nMagic;
   
   MqlTradeCheckResult oCheckResult;
   ZeroMemory(oCheckResult);
   bool bCheck = OrderCheck(trade_request, oCheckResult);
   if(bCheck == true && oCheckResult.retcode == 0)
   {
      bool bResult = false;
      for(int k = 0; k < 5; k++)
        {
         bResult = OrderSend(trade_request, trade_result);
         Print((string)bResult+" - ordersend at:"+(string)TimeCurrent());
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
         Print("Expert Removed due to not enough money!");
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
   Print(__FUNCTION__);

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
                     Alert("Error in removing order #"+(string)ticket+", ErrorCode: "+(string)FillingCheck);
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
         Alert("Order #"+(string)ticket+" removed!");
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
                 const long            z_order=100,         // priority for mouse click
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
//| Function to close a position by its ticket number.               |
//| This function sends a request to close a position. If the volume  |
//| is not specified, it closes the entire position. It handles      |
//| different filling modes based on the symbol's characteristics.   |
//| Returns true if the position is successfully closed, false otherwise. |
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
//| Function to close all positions for a specified symbol and type  |
//| optionally filtering by a comment.                              |
//| This function iterates through all positions and closes those    |
//| matching the specified criteria.                                |
//+------------------------------------------------------------------+
void ClosePositions(string symbol, int pos_type=-1, string comment=NULL)
  {
   int total = PositionsTotal();
   for(int i = total-1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0
         && (symbol == NULL || PositionGetString(POSITION_SYMBOL) == symbol)
         && (PositionGetInteger(POSITION_MAGIC) == _MAGIC_)
         && (pos_type == -1 || PositionGetInteger(POSITION_TYPE) == pos_type)
         && (comment == NULL || StringFind(PositionGetString(POSITION_COMMENT), comment) == 0)
        )
        {
         ClosePosition(ticket);
        }
     }
  }



// int SuperTrend_Handle;
// bool CreateIndicatorsHandles()
// {
//    SuperTrend_Handle
//          = iCustom(_Symbol, HTF, SuperTrend_IndicatorName
//                    , SuperTrend_Period
//                    , SuperTrend_Multiplier
//                    , SuperTrend_Show_Filling
//                );

//    if(SuperTrend_Handle==INVALID_HANDLE)
//    {
//       //--- tell about the failure and output the error code
//       PrintFormat("Failed to create handle of the %s indicator for the symbol %s/%s, error code %d",
//                   SuperTrend_IndicatorName,
//                   _Symbol,
//                   EnumToString(HTF),
//                   GetLastError());
//       //--- the indicator is stopped early
//       return(false);
//    }

//    return(true);
// }


//================= Function to check if the EA has expired=============
bool isExpired()
  {
   datetime current_time = TimeCurrent();
   datetime expiration_time = EXPIRATION_DATE;

// Check if the current time is past the expiration time
   if(current_time > expiration_time)
     {
      return true;
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| correction of a pending order size to an acceptable value        |
//+------------------------------------------------------------------+
bool StopCorrect(string symbol,int &Stop)
  {
//----
   int Extrem_Stop=int(SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL));
   if(!Extrem_Stop)
      return(false);
   if(Stop<Extrem_Stop)
      Stop=Extrem_Stop;
//----
   return(true);
  }
//+------------------------------------------------------------------+
//| LotCorrect() function                                            |
//+------------------------------------------------------------------+
bool LotCorrect
(
   string symbol,
   double &Lot,
   ENUM_ORDER_TYPE order_type,
   double price
)
//LotCorrect(string symbol, double& Lot, ENUM_ORDER_TYPE order_type, double price)
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
  {

   double LOTSTEP=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   double maximumLOT=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double MinLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   if(!LOTSTEP || !maximumLOT || !MinLot)
      return false;

//---- normalizing the lot size to the nearest standard value
   Lot=LOTSTEP*MathFloor(Lot/LOTSTEP);

//---- checking the lot for the minimum allowable value
   if(Lot<MinLot)
      Lot=MinLot;
//---- checking the lot for the maximum allowable value
   if(Lot>maximumLOT)
      Lot=maximumLOT;

//---- checking the funds sufficiency
   if(!LotFreeMarginCorrect(symbol,Lot,order_type,price))
      return(false);
//----
   return(true);
  }
//+------------------------------------------------------------------+
//| LotFreeMarginCorrect() function                                  |
//+------------------------------------------------------------------+
bool LotFreeMarginCorrect
(
   string symbol,
   double &Lot,
   ENUM_ORDER_TYPE order_type,
   double price
)
//(string symbol, double& Lot, ENUM_ORDER_TYPE order_type, double price)
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
  {
//----
//---- checking the funds sufficiency
   double freemargin=AccountInfoDouble(ACCOUNT_FREEMARGIN);
   if(freemargin<=0)
      return(false);
   double LOTSTEP=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   double MinLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   if(!LOTSTEP || !MinLot)
      return false;
   double maximumLOT=GetLotForOpeningPos(symbol,order_type,freemargin,price);
//---- normalizing the lot size to the nearest standard value
   maximumLOT=LOTSTEP*MathFloor(maximumLOT/LOTSTEP);
   if(maximumLOT<MinLot)
      return(false);
   if(Lot>maximumLOT)
      Lot=maximumLOT;
//----
   return(true);
  }
//+------------------------------------------------------------------+
//| Lot size calculation for opening a position with lot_margin      |
//+------------------------------------------------------------------+
double GetLotForOpeningPos(string symbol,ENUM_ORDER_TYPE order_type,double lot_margin,double price)
  {
//----
   double n_margin;
   if(!OrderCalcMargin(order_type,symbol,1,price,n_margin) || !n_margin)
      return(0);
   double lot=lot_margin/n_margin;

//---- get trade constants
   double LOTSTEP=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   double maximumLOT=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double MinLot=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   if(!LOTSTEP || !maximumLOT || !MinLot)
      return(0);

//---- normalizing the lot size to the nearest standard value
   lot=LOTSTEP*MathFloor(lot/LOTSTEP);

//---- checking the lot for the minimum allowable value
   if(lot<MinLot)
      lot=0;
//---- checking the lot for the maximum allowable value
   if(lot>maximumLOT)
      lot=maximumLOT;
//----
   return(lot);
  }
//+------------------------------------------------------------------+
//| Returning a string result of a trading operation by its code     |
//+------------------------------------------------------------------+
string ResultRetcodeDescription(int retcode)
  {
   string str;
//----
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE:
         str="Requote";
         break;
      case TRADE_RETCODE_REJECT:
         str="Request rejected";
         break;
      case TRADE_RETCODE_CANCEL:
         str="Request cancelled by trader";
         break;
      case TRADE_RETCODE_PLACED:
         str="Order is placed";
         break;
      case TRADE_RETCODE_DONE:
         str="Request is executed";
         break;
      case TRADE_RETCODE_DONE_PARTIAL:
         str="Request is executed partially";
         break;
      case TRADE_RETCODE_ERROR:
         str="Request processing error";
         break;
      case TRADE_RETCODE_TIMEOUT:
         str="Request is cancelled because of a time out";
         break;
      case TRADE_RETCODE_INVALID:
         str="Invalid request";
         break;
      case TRADE_RETCODE_INVALID_VOLUME:
         str="Invalid request volume";
         break;
      case TRADE_RETCODE_INVALID_PRICE:
         str="Invalid request price";
         break;
      case TRADE_RETCODE_INVALID_STOPS:
         str="Invalid request stops";
         break;
      case TRADE_RETCODE_TRADE_DISABLED:
         str="Trading is forbidden";
         break;
      case TRADE_RETCODE_MARKET_CLOSED:
         str="Market is closed";
         break;
      case TRADE_RETCODE_NO_MONEY:
         str="Insufficient funds for request execution";
         break;
      case TRADE_RETCODE_PRICE_CHANGED:
         str="Prices have changed";
         break;
      case TRADE_RETCODE_PRICE_OFF:
         str="No quotes for request processing";
         break;
      case TRADE_RETCODE_INVALID_EXPIRATION:
         str="Invalid order expiration date in the request";
         break;
      case TRADE_RETCODE_ORDER_CHANGED:
         str="Order state has changed";
         break;
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         str="Too many requests";
         break;
      case TRADE_RETCODE_NO_CHANGES:
         str="No changes in the request";
         break;
      case TRADE_RETCODE_SERVER_DISABLES_AT:
         str="Autotrading is disabled by the server";
         break;
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
         str="Autotrading is disabled by the client terminal";
         break;
      case TRADE_RETCODE_LOCKED:
         str="Request is blocked for processing";
         break;
      case TRADE_RETCODE_FROZEN:
         str="Order or position has been frozen";
         break;
      case TRADE_RETCODE_INVALID_FILL:
         str="Unsupported type of order execution for the balance is specified ";
         break;
      case TRADE_RETCODE_CONNECTION:
         str="No connection with trade server";
         break;
      case TRADE_RETCODE_ONLY_REAL:
         str="Operation is allowed only for real accounts";
         break;
      case TRADE_RETCODE_LIMIT_ORDERS:
         str="Limit for the number of pending orders has been reached";
         break;
      case TRADE_RETCODE_LIMIT_VOLUME:
         str="Limit for orders and positions volume for this symbol has been reached";
         break;
      default:
         str="Unknown result";
     }
//----
   return(str);
  }
//+------------------------------------------------------------------+
//| returning the result of a trading operation to repeat the        |
//| transaction                                                      |
//+------------------------------------------------------------------+
bool ResultRetcodeCheck(int retcode)
  {
   string str;
//----
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE: /*Requote*/
         return(false);
         break;
      case TRADE_RETCODE_REJECT: /*Request rejected*/
         return(false);
         break;
      case TRADE_RETCODE_CANCEL: /*Request cancelled by trader*/
         return(true);
         break;
      case TRADE_RETCODE_PLACED: /*Order is placed*/
         return(true);
         break;
      case TRADE_RETCODE_DONE: /*Request is executed*/
         return(true);
         break;
      case TRADE_RETCODE_DONE_PARTIAL: /*Request is executed partially*/
         return(true);
         break;
      case TRADE_RETCODE_ERROR: /*Request processing error*/
         return(false);
         break;
      case TRADE_RETCODE_TIMEOUT: /*Request is cancelled because of a time out*/
         return(false);
         break;
      case TRADE_RETCODE_INVALID: /*Invalid request*/
         return(true);
         break;
      case TRADE_RETCODE_INVALID_VOLUME: /*Invalid request volume*/
         return(true);
         break;
      case TRADE_RETCODE_INVALID_PRICE: /*Invalid request price*/
         return(true);
         break;
      case TRADE_RETCODE_INVALID_STOPS: /*Invalid request stops*/
         return(true);
         break;
      case TRADE_RETCODE_TRADE_DISABLED: /*Trading is forbidden*/
         return(true);
         break;
      case TRADE_RETCODE_MARKET_CLOSED: /*Market is closed*/
         return(true);
         break;
      case TRADE_RETCODE_NO_MONEY: /*Insufficient funds for request execution*/
         return(true);
         break;
      case TRADE_RETCODE_PRICE_CHANGED: /*Prices have changed*/
         return(false);
         return(true);
         break;
      case TRADE_RETCODE_PRICE_OFF: /*No quotes for request processing*/
         return(true);
         break;
      case TRADE_RETCODE_INVALID_EXPIRATION: /*Invalid order expiration date in the request*/
         return(true);
         break;
      case TRADE_RETCODE_ORDER_CHANGED: /*Order state has changed*/
         return(true);
         break;
      case TRADE_RETCODE_TOO_MANY_REQUESTS: /*Too many requests*/
         return(false);
         break;
      case TRADE_RETCODE_NO_CHANGES: /*No changes in the request*/
         return(false);
         break;
      case TRADE_RETCODE_SERVER_DISABLES_AT: /*Autotrading is disabled by the server*/
         return(true);
         break;
      case TRADE_RETCODE_CLIENT_DISABLES_AT: /*Autotrading is disabled by the client terminal*/
         return(true);
         break;
      case TRADE_RETCODE_LOCKED: /*Request is blocked for processing*/
         return(true);
         break;
      case TRADE_RETCODE_FROZEN: /*Order or position has been frozen*/
         return(true);
         break;
      case TRADE_RETCODE_INVALID_FILL: /*Unsupported type of order execution for the balance is specified */
         return(true);
         break;
      case TRADE_RETCODE_CONNECTION: /*No connection with trade server*/
         return(true);
         break;
      case TRADE_RETCODE_ONLY_REAL: /*Operation is allowed only for real accounts*/
         return(true);
         break;
      case TRADE_RETCODE_LIMIT_ORDERS: /*Limit for the number of pending orders has been reached*/
         return(true);
         break;
      case TRADE_RETCODE_LIMIT_VOLUME: /*Limit for orders and positions volume for this symbol has been reached*/
         return(true);
         break;
      default: /*Unknown result*/
         return(false);
     }
//----
   return(true);
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Lot size calculation for opening a long position                 |
//+------------------------------------------------------------------+
double LotCount
(
   string symbol,
   double Money_Management,
   ENUM_ORDER_TYPE order_type,
   double price
)
// (string symbol, double Money_Management, double price)
//+ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -+
  {
//----
   double margin,Lot;

//---- Lot calculation considering account balance
   margin=AccountInfoDouble(ACCOUNT_BALANCE)*Money_Management;
   if(!margin)
      return(-1);

   Lot=GetLotForOpeningPos(symbol,order_type,margin,price);

//---- normalizing the lot size to the nearest standard value
   if(!LotCorrect(symbol,Lot,order_type,price))
      return(-1);
//----
   return(Lot);
  }
  
  //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long makeMagicNumber(string key)
  {
   int i, k;
   long h = 0;

//if (IsTesting()) {
//  key = "_" + key;
//}

   for(i = 0; i < StringLen(key); i++)
     {
      //k = StringGetChar(key, i);
      k= StringGetCharacter(key,i);
      h = h + k;
      h = bitRotate(h, 5); // rotate 5 bits
     }

   for(i = 0; i < StringLen(key); i++)
     {
      //k = StringGetChar(key, i);
      k= StringGetCharacter(key,i);
      h = h + k;
      // rotate depending on character value
      h = bitRotate(h, k & 0x0000000F);
     }

// now we go backwards in our string
   for(i = StringLen(key); i > 0; i--)
     {
      //k = StringGetChar(key, i - 1);
      k= StringGetCharacter(key,i-1);
      h = h + k;
      // rotate depending on the last 4 bits of h
      h = bitRotate(h, h & 0x0000000F);
     }

   return(h & 0x7fffffff);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long bitRotate(long value, long count)
  {
   long  tmp, mask;
   mask = (0x00000001 << count) - 1;
   tmp = value & mask;
   value = value >> count;
   value = value | (tmp << (32 - count));
   return(value);
  }
  
   //+------------------------------------------------------------------+
//| Function to display user information messages on the chart.      |
//| This function creates and sets up label objects on the chart to   |
//| display three lines of text with specific formatting.            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void DrawMessageUserInfo(const string message1,const string message2,const string message3)
  {

   int coord_y=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)/2;


   if(ObjectFind(0,name5)<0)
      ObjectCreate(0,name5,OBJ_LABEL,0,0,0);
   if(ObjectFind(0,name6)<0)
      ObjectCreate(0,name6,OBJ_LABEL,0,0,0);
   if(ObjectFind(0,name7)<0)
      ObjectCreate(0,name7,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name5,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name5,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name5,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name5,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name5,OBJPROP_XDISTANCE,10);

   ObjectSetInteger(0,name5,OBJPROP_YDISTANCE,coord_y);//50);

   ObjectSetInteger(0,name5,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name5,OBJPROP_COLOR,CHART_TEXT_COLOR);
   ObjectSetString(0,name5,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name5,OBJPROP_TEXT,message1);
//----
   ObjectSetInteger(0,name6,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name6,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name6,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name6,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name6,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name6,OBJPROP_YDISTANCE,(coord_y-10));//40);
   ObjectSetInteger(0,name6,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name6,OBJPROP_COLOR,clrBlack);
   ObjectSetString(0,name6,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name6,OBJPROP_TEXT,message2);

   ObjectSetInteger(0,name7,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name7,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name7,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name7,OBJPROP_ANCHOR,ANCHOR_LEFT);
   ObjectSetInteger(0,name7,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name7,OBJPROP_YDISTANCE,(coord_y-20));//30);
   ObjectSetInteger(0,name7,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name7,OBJPROP_COLOR,CHART_TEXT_COLOR);
   ObjectSetString(0,name7,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name7,OBJPROP_TEXT,message3);


   ChartRedraw();
  }

//+------------------------------------------------------------------+
void DrawMessageLeftBottom(const string message1,const string message2,const string message3,const string message4)
  {
//int coord_x=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)/2;

//int coord_y=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS)/2;


   if(ObjectFind(0,name11)<0)
      ObjectCreate(0,name11,OBJ_LABEL,0,0,0);
   if(ObjectFind(0,name12)<0)
      ObjectCreate(0,name12,OBJ_LABEL,0,0,0);
   if(ObjectFind(0,name13)<0)
      ObjectCreate(0,name13,OBJ_LABEL,0,0,0);
   if(ObjectFind(0,name14)<0)
      ObjectCreate(0,name14,OBJ_LABEL,0,0,0);
//---
   ObjectSetInteger(0,name11,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name11,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name11,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name11,OBJPROP_ANCHOR,ANCHOR_LEFT);

   ObjectSetInteger(0,name11,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name11,OBJPROP_YDISTANCE,50);

   ObjectSetInteger(0,name11,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name11,OBJPROP_COLOR,CHART_TEXT_COLOR);
   ObjectSetString(0,name11,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name11,OBJPROP_TEXT,message1);
//----
   ObjectSetInteger(0,name12,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name12,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name12,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name12,OBJPROP_ANCHOR,ANCHOR_LEFT);

   ObjectSetInteger(0,name12,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name12,OBJPROP_YDISTANCE,40);

   ObjectSetInteger(0,name12,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name12,OBJPROP_COLOR,clrBlack);
   ObjectSetString(0,name12,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name12,OBJPROP_TEXT,message2);

   ObjectSetInteger(0,name13,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name13,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name13,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name13,OBJPROP_ANCHOR,ANCHOR_LEFT);

   ObjectSetInteger(0,name13,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name13,OBJPROP_YDISTANCE,30);

   ObjectSetInteger(0,name13,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name13,OBJPROP_COLOR,CHART_TEXT_COLOR);
   ObjectSetString(0,name13,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name13,OBJPROP_TEXT,message3);

   ObjectSetInteger(0,name14,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name14,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name14,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name14,OBJPROP_ANCHOR,ANCHOR_LEFT);

   ObjectSetInteger(0,name14,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name14,OBJPROP_YDISTANCE,20);

   ObjectSetInteger(0,name14,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name14,OBJPROP_COLOR,CHART_TEXT_COLOR);
   ObjectSetString(0,name14,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name14,OBJPROP_TEXT,message4);


   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawMessage(const string message1,const string message2)
  {
//int coord_x=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)/2;
   if(ObjectFind(0,name1)<0)
      ObjectCreate(0,name1,OBJ_LABEL,0,0,0);
   //if(ObjectFind(0,name2)<0)
   //   ObjectCreate(0,name2,OBJ_LABEL,0,0,0);
//---
   ObjectSetInteger(0,name1,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name1,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name1,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
   ObjectSetInteger(0,name1,OBJPROP_ANCHOR,ANCHOR_RIGHT);
   ObjectSetInteger(0,name1,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name1,OBJPROP_YDISTANCE,30);
   ObjectSetInteger(0,name1,OBJPROP_FONTSIZE,18);
   ObjectSetInteger(0,name1,OBJPROP_COLOR,clrBlack);
   ObjectSetString(0,name1,OBJPROP_FONT,"Calibri");
   ObjectSetString(0,name1,OBJPROP_TEXT,message1);

   ChartRedraw();
  }


//+------------------------------------------------------------------+
void ShowObjects(double PercChange,
                 string PerChg,
                 string text_obj,
                 string arrow_obj,
                 ENUM_BASE_CORNER corner_pos_text,
                 int x_pos_text,
                 int y_pos_text,
                 ENUM_BASE_CORNER corner_pos_arrow,
                 int x_pos_arrow,
                 int y_pos_arrow)
  {

   string Arrow = "";
   color Obj_Color = No_Mvt_Color;
   if(PercChange > 0)
     {
      Arrow = Up_Arrow;
      Obj_Color = Up_Color;
     }
   else
      if(PercChange < 0)
        {
         Arrow = Down_Arrow;
         Obj_Color = Down_Color;
        }

   if(ObjectFind(0, text_obj) < 0)
     {
      ObjectCreate(0, text_obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, text_obj, OBJPROP_CORNER, corner_pos_text);
      ObjectSetInteger(0, text_obj, OBJPROP_XDISTANCE, x_pos_text);
      ObjectSetInteger(0,text_obj,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0, text_obj, OBJPROP_YDISTANCE, y_pos_text);//y_pos_text);
      ObjectSetInteger(0, text_obj, OBJPROP_FONTSIZE, Font_Size);
      ObjectSetString(0, text_obj, OBJPROP_FONT, "Verdana");
     }

   ObjectSetInteger(0, text_obj, OBJPROP_COLOR, Obj_Color);
   ObjectSetString(0, text_obj, OBJPROP_TEXT, PerChg);

   if(ObjectFind(0, arrow_obj) < 0)
     {
      ObjectCreate(0, arrow_obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, arrow_obj, OBJPROP_CORNER, corner_pos_arrow);
      ObjectSetInteger(0, arrow_obj, OBJPROP_XDISTANCE, x_pos_arrow);
      ObjectSetInteger(0,arrow_obj,OBJPROP_ANCHOR,ANCHOR_RIGHT);
      ObjectSetInteger(0, arrow_obj, OBJPROP_YDISTANCE, y_pos_arrow);//y_pos_arrow);
      ObjectSetInteger(0, arrow_obj, OBJPROP_FONTSIZE, Font_Size);
      ObjectSetString(0, arrow_obj, OBJPROP_FONT, "Wingdings 3");
     }

   ObjectSetInteger(0, arrow_obj, OBJPROP_COLOR, Obj_Color);
   ObjectSetString(0, arrow_obj, OBJPROP_TEXT, Arrow);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetCountAllTransactions()
  {
// Variables to store the total count of pending orders and open positions
   int total_open_positions = 0;
   int total_pending_orders = 0;
// Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol() || PositionGetInteger(POSITION_MAGIC) != _MAGIC_)
         continue;
      total_open_positions++;
     }
//PrintFormat("Total Open Positions: %d", total_open_positions);
// Loop through all pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket))
         continue;
      if(m_order.Symbol() != Symbol() || OrderGetInteger(ORDER_MAGIC) != _MAGIC_)
         continue;
      // Increment the count of pending orders
      total_pending_orders++;
     }
//PrintFormat("Total Pending Orders: %d", total_pending_orders);
   return (total_open_positions+total_pending_orders);
  }
void CloseProfitPositions()
  {
//---
   for(int i=PositionsTotal()-1; i>=0; i--) // returns the number of current positions
      if(m_position.SelectByIndex(i))   // selects the position by index for further access to its properties
        {
         double profit=m_position.Commission()+m_position.Swap()+m_position.Profit();
         if(profit>=InpMinProfit)
           {
            trade.PositionClose(m_position.Ticket());
            if(debug)
               Print("Profitable position closed with $"+(string)profit);
           }
        }
  }
  
  
// Function to calculate the distance in pips
int CalculateDistanceInPips(double openPrice, double takeProfitPrice)
  {
// Get the tick size of the current symbol
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
// Calculate the difference in prices
   double priceDifference = MathAbs(takeProfitPrice - openPrice);
// Convert the price difference to pips
   double distanceInPips = priceDifference / tickSize;
   return (int)distanceInPips;
  }

// Function to retrieve pending order details and calculate the distance in pips
double GetPendingOrderDistanceInPips(int ticket)
  {
   if(OrderSelect(ticket))
     {
      double openPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double takeProfitPrice = OrderGetDouble(ORDER_TP);
      return CalculateDistanceInPips(openPrice, takeProfitPrice);
     }
   else
     {
      Print("Failed to select order with ticket: ", ticket);
      return -1; // Indicate an error
     }
  }
// Function to retrieve pending order details and calculate the distance in pips
double GetPendingOrderDistanceInPipsSL(int ticket)
  {
   if(OrderSelect(ticket))
     {
      double openPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double SLPrice = OrderGetDouble(ORDER_SL);
      return CalculateDistanceInPips(openPrice, SLPrice);
     }
   else
     {
      Print("Failed to select order with ticket: ", ticket);
      return -1; // Indicate an error
     }
  }
 
  //+------------------------------------------------------------------+
//| Returns true if a new bar has appeared for a symbol/period pair  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
//--- memorize the time of opening of the last bar in the static variable
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
//|    not used                                                      |
//+------------------------------------------------------------------+
  // bool LastClosedPositionIsFromSameHTFFibo(string ThirdPart)
  //   {
  //    string result[];
  //    HistorySelect(0, TimeCurrent()+1);
  //    for(int i = HistoryDealsTotal()-1; i >= 0; i--)
  //      {
  //       ulong tick_out = HistoryDealGetTicket(i);
  //       if(tick_out <= 0 || HistoryDealGetString(tick_out, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tick_out, DEAL_ENTRY) != DEAL_ENTRY_OUT)
  //          continue;
  //       long PosID = HistoryDealGetInteger(tick_out, DEAL_POSITION_ID);
  //       bool MagicIsOkay = false;
  //       for(int j = i-1; j >= 0; j--)
  //         {
  //          ulong tick_in = HistoryDealGetTicket(j);
  //          if(tick_in <= 0 || HistoryDealGetString(tick_in, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tick_in, DEAL_ENTRY) != DEAL_ENTRY_IN || PosID != HistoryDealGetInteger(tick_in, DEAL_POSITION_ID))
  //             continue;
  //          MagicIsOkay = StringSplit(HistoryDealGetString(tick_in, DEAL_COMMENT), '-', result) == 3 && HistoryDealGetInteger(tick_in, DEAL_MAGIC) == _MAGIC_;
  //          if(MagicIsOkay)
  //            {
  //             return(result[2] == ThirdPart);
  //            }
  //          break;
  //         }
  //       if(!MagicIsOkay)
  //          continue;
  //       break;
  //      }
  //    return(false);
  //   } 