//+------------------------------------------------------------------+
//|                                               C_Object_Label.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Object_Edit.mqh"
//+------------------------------------------------------------------+
class C_Object_Label : public C_Object_Edit
{
	public	:
//+------------------------------------------------------------------+
		void Create(ulong ticket, string szObjectName, string Font = "Lucida Console", string szTxt = "", int FontSize = 10, color cor = clrBlack)
			{
				C_Object_Base::Create(szObjectName, OBJ_LABEL, ticket);
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_FONT, Font);
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_TEXT, szTxt);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_FONTSIZE, FontSize);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_COLOR, cor);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_ANCHOR, ANCHOR_LEFT);
			};
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
