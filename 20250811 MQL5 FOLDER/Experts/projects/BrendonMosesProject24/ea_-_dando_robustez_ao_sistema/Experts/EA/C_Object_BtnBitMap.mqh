//+------------------------------------------------------------------+
//|                                           C_Object_BtnBitMap.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Object_Base.mqh"
//+------------------------------------------------------------------+
#define def_BtnClose	"Images\\NanoEA-SIMD\\Btn_Close.bmp"
//+------------------------------------------------------------------+
#resource "\\" + def_BtnClose
//+------------------------------------------------------------------+
class C_Object_BtnBitMap : public C_Object_Base
{
	public	:
//+------------------------------------------------------------------+
		void Create(ulong ticket, string szObjectName, string szResource1, string szResource2 = NULL)
			{
				C_Object_Base::Create(szObjectName, OBJ_BITMAP_LABEL, ticket);
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_BMPFILE, 0, "::" + szResource1);
				ObjectSetString(Terminal.Get_ID(), szObjectName, OBJPROP_BMPFILE, 1, "::" + (szResource2 == NULL ? szResource1 : szResource2));
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_STATE, false);
			};
//+------------------------------------------------------------------+
		bool GetStateButton(string szObjectName) const
			{
				return (bool) ObjectGetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_STATE);
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
