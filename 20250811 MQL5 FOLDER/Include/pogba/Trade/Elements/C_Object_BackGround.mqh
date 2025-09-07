//+------------------------------------------------------------------+
//|                                                  C_BoxGround.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Object_Base.mqh"
//+------------------------------------------------------------------+
class C_Object_BackGround : public C_Object_Base
{
	public:
//+------------------------------------------------------------------+
		void Create(ulong ticket, string szObjectName, color cor)
			{
				C_Object_Base::Create(szObjectName, OBJ_RECTANGLE_LABEL, ticket);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
				this.SetColor(szObjectName, cor);
			}
//+------------------------------------------------------------------+
virtual void SetColor(string szObjectName, color cor)
			{
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_COLOR, cor);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_BGCOLOR, cor);
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
