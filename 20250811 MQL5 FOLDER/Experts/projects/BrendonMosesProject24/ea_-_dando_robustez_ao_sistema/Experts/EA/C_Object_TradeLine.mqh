//+------------------------------------------------------------------+
//|                                           C_Object_LineTrade.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#include "C_Object_BackGround.mqh"
//+------------------------------------------------------------------+
class C_Object_TradeLine : public C_Object_BackGround
{
	private	:
		static string m_MemNameObj;
	public	:
//+------------------------------------------------------------------+
		void Create(ulong ticket, string szObjectName, color cor)
			{
				C_Object_BackGround::Create(ticket, szObjectName, cor);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_XSIZE, TerminalInfoInteger(TERMINAL_SCREEN_WIDTH));
				SpotLight(szObjectName);
				SpotLight();
			};
//+------------------------------------------------------------------+
		void SpotLight(string szObjectName = NULL)
			{
				if (m_MemNameObj != NULL) ObjectSetInteger(Terminal.Get_ID(), m_MemNameObj, OBJPROP_YSIZE, 3);
				if (szObjectName != NULL) ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_YSIZE, (szObjectName != NULL ? 4 : 3));
				m_MemNameObj = szObjectName;
			};
//+------------------------------------------------------------------+
virtual void PositionAxleY(string szObjectName, int Y)
			{
				int desly = (m_MemNameObj == szObjectName ? 2 : 1);
				ObjectSetInteger(Terminal.Get_ID(), szObjectName, OBJPROP_YDISTANCE, Y - desly);
			};
//+------------------------------------------------------------------+
		string GetObjectSelected(void) const { return m_MemNameObj; }
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
string C_Object_TradeLine::m_MemNameObj = NULL;
//+------------------------------------------------------------------+
