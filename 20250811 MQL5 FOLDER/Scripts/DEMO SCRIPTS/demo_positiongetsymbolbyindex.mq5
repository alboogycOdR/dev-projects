//+------------------------------------------------------------------+
//|                                Demo_PositionGetSymbolByIndex.mq5 |
//|                        Copyright 2010, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2010, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

input long my_magic=777;
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
//---
//--- total number of positions
   int positions=PositionsTotal();
//--- look all positions
   for(int i=0;i<positions;i++)
     {
      ResetLastError();
      //--- copying position by its index into the cache
      string symbol=PositionGetSymbol(i); //  get position symbol
      if(symbol!="") // position data is copied, work with it
        {
         long pos_id=PositionGetInteger(POSITION_IDENTIFIER);
         double price=PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         long pos_magic=PositionGetInteger(POSITION_MAGIC);
         string comment=PositionGetString(POSITION_COMMENT);
         if(pos_magic==my_magic)
           {
           //  processing of position with specified POSITION_MAGIC
           }
         PrintFormat("Position #%d по %s: POSITION_MAGIC=%d, price=%G, type=%s, comment=%s",
                     pos_id,symbol,pos_magic,price,EnumToString(type),comment);
        }
      else           // unsuccessful call of PositionGetSymbol() 
        {
         PrintFormat("Error in loading position with index %d. into the cache"+
                     " Error code: %d", i, GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
