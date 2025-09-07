//+------------------------------------------------------------------+
//|                                  Demo_PositionSelectBySymbol.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//--- the position will be selected by symbol of the current chart
   string symbol=Symbol();
//--- select position by symbol
   bool selected=PositionSelect(symbol);
   if(selected) // position has been selected
     {
      long pos_id=PositionGetInteger(POSITION_IDENTIFIER);
      double price=PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      long pos_magic=PositionGetInteger(POSITION_MAGIC);
      string comment=PositionGetString(POSITION_COMMENT);
      PrintFormat("Position #%d on %s: POSITION_MAGIC=%d, price=%G, type=%s, comment=%s",
                  pos_id, symbol, pos_magic, price,EnumToString(type), comment);
     }
   else        // error in position select 
     {
      PrintFormat("Position select error, symbol %s. Error",symbol,GetLastError());
     }
  }
//+------------------------------------------------------------------+
