//+------------------------------------------------------------------+
//|                                                C_Object_Edit.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Object_Base.mqh"
//+------------------------------------------------------------------+
class C_Object_Edit : public C_Object_Base
{
//+------------------------------------------------------------------+
#define def_ColorNegative		clrCoral
#define def_ColoPositive		clrPaleGreen
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		void Create(ulong ticket, string szObjectName, color cor, double InfoValue)
			{
				C_Object_Base::Create(szObjectName, OBJ_EDIT, ticket);
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_FONT, "Lucida Console");
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_FONTSIZE, 10);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_ALIGN, ALIGN_CENTER);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_COLOR, clrBlack);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_BORDER_COLOR, clrBlack);
				SetOnlyRead(szObjectName, true);
				SetTextValue(szObjectName, InfoValue, cor);
			};
//+------------------------------------------------------------------+
		void SetTextValue(string szObjectName, double InfoValue, color cor = clrNONE)
			{
				color clr;
				clr = (cor != clrNONE ? cor : (InfoValue < 0 ? def_ColorNegative : def_ColoPositive));
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_TEXT, Terminal.ViewDouble(InfoValue < 0 ? -(InfoValue) : InfoValue));
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_BGCOLOR, clr);
			};
//+------------------------------------------------------------------+
		long GetTextValue(string szObjectName) const
			{
				return (StringToInteger(ObjectGetString(Terminal.Get_ID(), szObjectName, OBJPROP_TEXT)) * 
								(ObjectGetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_BGCOLOR) == def_ColorNegative ? -1 : 1));
			};
//+------------------------------------------------------------------+
inline void SetOnlyRead(string szObjectName, bool OnlyRead)
			{
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_READONLY, OnlyRead);
			}
//+------------------------------------------------------------------+
#undef def_ColoPositive
#undef def_ColorNegative
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
