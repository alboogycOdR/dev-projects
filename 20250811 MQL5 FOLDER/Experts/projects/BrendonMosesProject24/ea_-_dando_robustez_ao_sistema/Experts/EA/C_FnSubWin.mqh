//+------------------------------------------------------------------+
//|                                                   C_FnSubWin.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Terminal.mqh"
//+------------------------------------------------------------------+
class C_FnSubWin
{
	private	:
		string 	m_szIndicator;
		int		m_SubWin;
//+------------------------------------------------------------------+
		void Create(const string szIndicator)
			{
				int i0;
				m_szIndicator = szIndicator;
				if ((i0 = ChartWindowFind(Terminal.Get_ID(), szIndicator)) == -1)
					ChartIndicatorAdd(Terminal.Get_ID(), i0 = (int)ChartGetInteger(Terminal.Get_ID(), CHART_WINDOWS_TOTAL), iCustom(NULL, 0, "::" + def_Resource, szIndicator));
				m_SubWin = i0;
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_FnSubWin()
			{
				m_szIndicator = NULL;
				m_SubWin = -1;
			}
//+------------------------------------------------------------------+
		~C_FnSubWin()
			{
				Close();
			}
//+------------------------------------------------------------------+
		void Close(void)
			{
				if (m_SubWin >= 0) ChartIndicatorDelete(Terminal.Get_ID(), m_SubWin, m_szIndicator);
				m_SubWin = -1;
			}
//+------------------------------------------------------------------+
inline int GetIdSubWinEA(const string szIndicator = NULL)
			{
				if ((szIndicator != NULL) && (m_SubWin < 0)) Create(szIndicator);
				return m_SubWin;
			}
//+------------------------------------------------------------------+
inline bool ExistSubWin(void) const { return m_SubWin >= 0; }
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
