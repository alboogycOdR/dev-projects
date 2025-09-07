//+------------------------------------------------------------------+
//|                                                FXHD_BOT_INCL.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"



//+------------------------------------------------------------------+
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



int SuperTrend_Handle;
bool CreateIndicatorsHandles()
  {
   SuperTrend_Handle
      = iCustom(_Symbol, HTF, SuperTrend_IndicatorName
                , SuperTrend_Period
                , SuperTrend_Multiplier
                , SuperTrend_Show_Filling
               );
   if(SuperTrend_Handle == INVALID_HANDLE)
     {
      //--- tell about the failure and output the error code
      PrintFormat("Failed to create handle of the %s indicator for the symbol %s/%s, error code %d",
                  SuperTrend_IndicatorName,
                  _Symbol,
                  EnumToString(HTF),
                  GetLastError());
      //--- the indicator is stopped early
      return(false);
     }
   return(true);
  }
void ClosePositions(string symbol, int pos_type=-1, string comment=NULL)
{   
   int total = PositionsTotal();
   for (int i = total-1; i >= 0; i--)
   {
   ulong ticket = PositionGetTicket(i);
   if (ticket > 0 
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

 
bool ClosePosition(ulong ticket, double Volume=0)
{
   if (!PositionSelectByTicket(ticket)) return(false);
   
   MqlTradeRequest trade_request; ZeroMemory(trade_request);
   MqlTradeResult  trade_result; ZeroMemory(trade_result);

   string position_symbol = PositionGetString(POSITION_SYMBOL);
   
   if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK) trade_request.type_filling = ORDER_FILLING_FOK;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC) trade_request.type_filling = ORDER_FILLING_IOC;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==0) trade_request.type_filling = ORDER_FILLING_RETURN;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)>2)
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
   if(!done || trade_result.retcode != TRADE_RETCODE_DONE) Alert("Error: positon #"+(string)ticket+" not closed, ErrorCode:"+(string)trade_result.retcode);
   else 
   {
      Print("Positon #"+(string)ticket+" closed!");
      return(true);
   }
   
   return(false);
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
  
   if (Description != NULL) ObjectSetString(chart_ID,name,OBJPROP_TEXT,Description);
   if (ToolTip != NULL) ObjectSetString(chart_ID,name,OBJPROP_TOOLTIP,ToolTip);
}

//+------------------------------------------------------------------+
//| Check expiration type of pending order                           |
//+------------------------------------------------------------------+
bool ExpirationCheck(const string symbol)
  {
   CSymbolInfo sym;
   MqlTradeRequest   m_request; ZeroMemory(m_request);
   MqlTradeResult    m_result; ZeroMemory(m_result);

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

//MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM\\
//+------------------------------------------------------------------+
//| Checks and corrects type of filling policy                       |
//+------------------------------------------------------------------+
uint FillingCheck(const string symbol)
{
   MqlTradeRequest   m_request; ZeroMemory(m_request);
   MqlTradeResult    m_result; ZeroMemory(m_result);

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

string OrderTypeToStr(ENUM_ORDER_TYPE type)
{
   if (type == ORDER_TYPE_BUY) return("Buy");
   if (type == ORDER_TYPE_SELL) return("Sell");
   if (type == ORDER_TYPE_BUY_LIMIT) return("Buy limit");
   if (type == ORDER_TYPE_SELL_LIMIT) return("Sell limit");
   if (type == ORDER_TYPE_BUY_STOP) return("Buy stop");
   if (type == ORDER_TYPE_SELL_STOP) return("Sell stop");
   
   return(NULL);
} 

bool DeleteOrder(ulong ticket)
{   
   int total = OrdersTotal();
   for (int i = total-1; i >= 0; i--)
   {
      if (OrderGetTicket(i) != ticket) continue;
   
      string order_symbol = OrderGetString(ORDER_SYMBOL);

      MqlTradeRequest trade_request; ZeroMemory(trade_request);
      MqlTradeResult  trade_result; ZeroMemory(trade_result);
         
      if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK) trade_request.type_filling = ORDER_FILLING_FOK;
      else if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC) trade_request.type_filling = ORDER_FILLING_IOC;
      else if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)==0) trade_request.type_filling = ORDER_FILLING_RETURN;
      else if((int) SymbolInfoInteger(order_symbol, SYMBOL_FILLING_MODE)>2)
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



double Lots(string f_symbol, int BuyOrSell, double price, double sl=0, double VolumeRatio=1)
{
   double f_volume = 0, margin = 0;
   if (LotType == UseFixedLot && FixedLot > 0) f_volume = FixedLot;
   else if (LotType == UseBalancePerLot && BalancePerLot > 0) f_volume = AccountInfoDouble(ACCOUNT_BALANCE)/BalancePerLot;
   else if (LotType == UseEquityPerLot && EquityPerLot > 0) f_volume = AccountInfoDouble(ACCOUNT_EQUITY)/EquityPerLot;
   else if (LotType == UseRiskPercentage && RiskPercentage > 0)
   {
      if (sl <= 0 || price <= 0)
      {
         Alert("Error: SL is zero while LotType is UseRiskPercentage!");
         return(0);
      }
      double point = SymbolInfoDouble(f_symbol,SYMBOL_POINT);
      double tick_value = SymbolInfoDouble(f_symbol,SYMBOL_TRADE_TICK_VALUE);
            
      double Fnc_Loss; 
      if (!OrderCalcProfit((BuyOrSell == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), f_symbol, 1, price, sl, Fnc_Loss) || Fnc_Loss >= 0) return(0);
      
      Fnc_Loss = -Fnc_Loss;
      double ExpectedLoss = AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100.0;
      
      f_volume = ExpectedLoss/Fnc_Loss;

      /*
      double SLInPips = MathAbs(sl - price)*PriceToPip(f_symbol);
      SLInPips += SymbolInfoInteger(f_symbol, SYMBOL_SPREAD)*SymbolInfoDouble(f_symbol, SYMBOL_POINT)*PriceToPip(f_symbol);
      double f_volume2 = (AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercentage/100.0)/((SLInPips)*_pipx(f_symbol)*SymbolInfoDouble(f_symbol,SYMBOL_TRADE_TICK_VALUE));    
      */
   }
   else if (LotType == UseFixedMargin && FixedMargin > 0 && OrderCalcMargin((BuyOrSell == 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), f_symbol, 1, price, margin))
   {
      f_volume = FixedMargin/margin;
   }
   
   if (MaxLot > 0 && f_volume > MaxLot) f_volume = MaxLot;
   
   return(CalcLot(f_symbol, VolumeRatio*f_volume));
}

double CalcLot(string f_symbol, double f_LotSize)
{
   if (f_LotSize < SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MIN)) f_LotSize = SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MIN);
   if (f_LotSize > SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MAX)) f_LotSize = SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_MAX);
   double f_value = MathMod(f_LotSize, SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP));
   if (!(MathAbs(f_value - 0) < 0.00001 || MathAbs(f_value - SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP)) < 0.00001))
   {
      f_LotSize = f_LotSize - f_value + SymbolInfoDouble(f_symbol, SYMBOL_VOLUME_STEP);
   }
   
   return (NormalizeDouble(f_LotSize, 2));
}

int SendOrder(const string sSymbol, const ENUM_ORDER_TYPE eType, const double fLot, double &prices, const uint nSlippage = 1000, const double fSL = 0, const double fTP = 0, const string nComment = "", const ulong nMagic = 0, datetime expiration=0)
{
	int RetVal = 0;

   string position_symbol = sSymbol;

	MqlTradeRequest trade_request; ZeroMemory(trade_request);
	MqlTradeResult	 trade_result; ZeroMemory(trade_result);
	
   if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_FOK) trade_request.type_filling = ORDER_FILLING_FOK;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==SYMBOL_FILLING_IOC) trade_request.type_filling = ORDER_FILLING_IOC;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)==0) trade_request.type_filling = ORDER_FILLING_RETURN;
   else if((int) SymbolInfoInteger(position_symbol, SYMBOL_FILLING_MODE)>2)
   {
      int FillingCheck_ = (int)FillingCheck(position_symbol);
      if(FillingCheck_ > 0) return(-FillingCheck_);
   }
	
	double fPoint = SymbolInfoDouble(sSymbol, SYMBOL_POINT);
	
	int nDigits	= (int) SymbolInfoInteger(sSymbol, SYMBOL_DIGITS);
	
   if(eType < 2) trade_request.action = TRADE_ACTION_DEAL;
   else trade_request.action =TRADE_ACTION_PENDING;
   
	trade_request.symbol		= sSymbol;
	trade_request.volume		= fLot;
	trade_request.stoplimit	= 0;
	trade_request.deviation	= nSlippage;
	trade_request.comment	= nComment;
	trade_request.type		= eType;
	trade_request.sl = NormalizeDouble(fSL, nDigits);
   trade_request.tp = NormalizeDouble(fTP, nDigits);
	trade_request.magic     = nMagic;
	if (expiration > 0)
	{
	   trade_request.type_time = ORDER_TIME_SPECIFIED;
	   trade_request.expiration = expiration;
	}
	if(eType == ORDER_TYPE_BUY) trade_request.price = NormalizeDouble(SymbolInfoDouble(sSymbol, SYMBOL_ASK), nDigits);
	else if(eType == ORDER_TYPE_SELL) trade_request.price = NormalizeDouble(SymbolInfoDouble(sSymbol, SYMBOL_BID), nDigits);
	else trade_request.price		= NormalizeDouble(prices, nDigits);
	          	
	MqlTradeCheckResult oCheckResult; ZeroMemory(oCheckResult);
	
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
   	      if (eType < 2 && PositionSelectByTicket(RetVal)) prices = PositionGetDouble(POSITION_PRICE_OPEN);
            else if (eType >= 2 && OrderSelect(RetVal)) prices = OrderGetDouble(ORDER_PRICE_OPEN);
            
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

void DeleteOrders(string symbol, int order_type=-1, string comment=NULL)
{   
   int total = OrdersTotal();
   for (int i = total-1; i >= 0; i--)
   {
   long ticket = (long)OrderGetTicket(i);
   if (ticket > 0 
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

bool OrderExist(string symbol, int order_type=-1, string comment=NULL, double price=0)
{   
   int total = OrdersTotal();
   for (int i = total-1; i >= 0; i--)
   {
   long ticket = (long)OrderGetTicket(i);
   if (ticket > 0 
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


bool PositionExist(string symbol, int pos_type=-1, string comment=NULL)
{   
   int total = PositionsTotal();
   for (int i = total-1; i >= 0; i--)
   {
   ulong ticket = PositionGetTicket(i);
   if (ticket > 0 
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
bool LastClosedPositionIsFromSameHTFFibo(string ThirdPart)
  {
   string result[];
   HistorySelect(0, TimeCurrent() + 1);
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong tick_out = HistoryDealGetTicket(i);
      if(tick_out <= 0 || HistoryDealGetString(tick_out, DEAL_SYMBOL) != _Symbol || HistoryDealGetInteger(tick_out, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      long PosID = HistoryDealGetInteger(tick_out, DEAL_POSITION_ID);
      bool MagicIsOkay = false;
      for(int j = i - 1; j >= 0; j--)
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) <= 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "N-HTF-") != 0 && StringFind(comment, "J-HTF-") != 0)
         continue;

      long LastType = PositionGetInteger(POSITION_TYPE);
      datetime LastPosTime = (datetime)PositionGetInteger(POSITION_TIME);

      for(int j = i - 1; j >= 0; j--)
        {
         if(PositionGetTicket(j) <= 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != MagicNumber|| LastType == PositionGetInteger(POSITION_TYPE))
            continue;
         ClosePosition(PositionGetTicket(j));
        }
      for(int j = OrdersTotal() - 1; j >= 0; j--)
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
void CheckToDeleteRelatedFiboIfPositionExist()
  {
   if(FiboHTF.Price1 > 0 && FiboHTF.Price2 > 0&&
      (PositionExist(_Symbol,-1,"N-HTF-" + DoubleToString(FiboHTF.Price1,_Digits) + "," + DoubleToString(FiboHTF.Price2,_Digits))
       ||
       PositionExist(_Symbol,-1,"J-HTF-" + DoubleToString(FiboHTF.Price1,_Digits) + "," + DoubleToString(FiboHTF.Price2,_Digits))
      ))
     {
      FiboHTF.Price1 = 0;
      FiboHTF.Price2 = 0;
      FiboHTF.Time1 = 0;
      FiboHTF.Time2 = 0;
      
      if(ShowFibo)
         ObjectDelete(0, ObjPref + "HTF_Fibo");
     }
   if(FiboLTF.Price1 > 0 && FiboLTF.Price2 > 0&&
      (PositionExist(_Symbol,-1,"N-LTF-" + DoubleToString(FiboLTF.Price1,_Digits) + "," + DoubleToString(FiboLTF.Price2,_Digits))
       ||
       PositionExist(_Symbol,-1,"J-LTF-" + DoubleToString(FiboLTF.Price1,_Digits) + "," + DoubleToString(FiboLTF.Price2,_Digits))
      )
     )
     {
      FiboLTF.Price1 = 0;
      FiboLTF.Price2 = 0;
      FiboLTF.Time1 = 0;
      FiboLTF.Time2 = 0;
      if(ShowFibo)
         ObjectDelete(0, ObjPref + "LTF_Fibo");
     }
  }
