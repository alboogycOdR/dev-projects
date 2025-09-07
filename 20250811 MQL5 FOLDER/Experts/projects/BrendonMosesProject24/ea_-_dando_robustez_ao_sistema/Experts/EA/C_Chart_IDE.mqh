//+------------------------------------------------------------------+
//|                                                  C_Chart_IDE.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_SubWindow.mqh"
#include "C_IndicatorTradeView.mqh"
//+------------------------------------------------------------------+
class C_Chart_IDE : public C_SubWindow
{
	protected:
		enum eObjectsIDE {eRESULT, eLABEL_SYMBOL, eROOF_DIARY, eBTN_BUY, eBTN_SELL, eCHECK_DAYTRADE, eBTN_CANCEL, eEDIT_LEVERAGE, eEDIT_TAKE, eEDIT_STOP};
//+------------------------------------------------------------------+
#define def_HeaderMSG "IDE_"
#define def_MaxObject eEDIT_STOP + 32
//+------------------------------------------------------------------+
	private	:
		int 		m_fp,
					m_SubWindow,
					m_CountObject;
		string 	m_szLine,
					m_szValue;
		bool		m_IsFloating;
		struct st00
		{
			double 	Leverange,
						FinanceTake,
						FinanceStop;
			bool		IsDayTrade;
		}m_BaseFinance;
		struct st01
		{
			string	szName;
			int		iPosX,
						iPosY;
		}m_ArrObject[def_MaxObject];
//+------------------------------------------------------------------+
		bool FileReadLine(void)
			{
				int utf_16 = 0;
				bool b0 = false;
				m_szLine = m_szValue = "";
				for (int c0 = 0; c0 < 500; c0++)
				{
					utf_16 = FileReadInteger(m_fp, SHORT_VALUE);
					if (utf_16 == 0x000D) { FileReadInteger(m_fp, SHORT_VALUE); return true; } else
					if (utf_16 == 0x003D) b0 = true; else
					if (b0) m_szValue = StringFormat("%s%c", m_szValue, (char)utf_16); else m_szLine = StringFormat("%s%c", m_szLine, (char)utf_16);
					if (FileIsEnding(m_fp)) break;
				}
				return (utf_16 == 0x003E);
			}
//+------------------------------------------------------------------+
		bool LoopCreating(ENUM_OBJECT type)
			{
#define macro_SetInteger(A, B) ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[c0].szName, A, B)
#define macro_SetString(A, B) ObjectSetString(Terminal.Get_ID(), m_ArrObject[c0].szName, A, B)
				int c0;
				bool b0;
				string sz0 = m_szValue;
				while (m_szLine != "</object>") if (!FileReadLine()) return false; else
				{
					if (m_szLine == "name")
					{
						b0 = false;
						StringToUpper(m_szValue);
						for(c0 = eRESULT; (c0 <= eEDIT_STOP) && (!(b0 = (m_szValue == szMsgIDE[c0]))); c0++);
						if (!b0 && m_IsFloating) return true; else c0 = (b0 ? c0 : m_CountObject);
						m_ArrObject[c0].szName = StringFormat("%s%04s>%s", def_HeaderMSG, sz0, m_szValue);
						ObjectDelete(Terminal.Get_ID(), m_ArrObject[c0].szName);
						ObjectCreate(Terminal.Get_ID(), m_ArrObject[c0].szName, type, m_SubWindow, 0, 0);
					}
					if (m_szLine == "pos_x"			) m_ArrObject[c0].iPosX = (int) StringToInteger(m_szValue);
					if (m_szLine == "pos_y"			)
					{
						if (m_IsFloating) m_ArrObject[c0].iPosY = (int)StringToInteger(m_szValue); else macro_SetInteger(OBJPROP_YDISTANCE, StringToInteger(m_szValue));
					}
					if (m_szLine == "size_x"		) macro_SetInteger(OBJPROP_XSIZE		, StringToInteger(m_szValue));
					if (m_szLine == "size_y"		) macro_SetInteger(OBJPROP_YSIZE		, StringToInteger(m_szValue));
					if (m_szLine == "offset_x"		) macro_SetInteger(OBJPROP_XOFFSET	, StringToInteger(m_szValue));
					if (m_szLine == "offset_y"		) macro_SetInteger(OBJPROP_YOFFSET	, StringToInteger(m_szValue));
					if (m_szLine == "bgcolor"		) macro_SetInteger(OBJPROP_BGCOLOR	, StringToInteger(m_szValue));
					if (m_szLine == "color"			) macro_SetInteger(OBJPROP_COLOR		, StringToInteger(m_szValue));
					if (m_szLine == "bmpfile_on"	) ObjectSetString(Terminal.Get_ID()	, m_ArrObject[c0].szName, OBJPROP_BMPFILE, 0, m_szValue);
					if (m_szLine == "bmpfile_off"	) ObjectSetString(Terminal.Get_ID()	, m_ArrObject[c0].szName, OBJPROP_BMPFILE, 1, m_szValue);
					if (m_szLine == "fontsz"		) macro_SetInteger(OBJPROP_FONTSIZE	, StringToInteger(m_szValue));
					if (m_szLine == "fontnm"		) macro_SetString(OBJPROP_FONT		, m_szValue);
					if (m_szLine == "descr"			) macro_SetString(OBJPROP_TEXT		, m_szValue);
					if (m_szLine == "readonly"		) macro_SetInteger(OBJPROP_READONLY	, StringToInteger(m_szValue) == 1);
					if (m_szLine == "state"			) macro_SetInteger(OBJPROP_STATE		, StringToInteger(m_szValue) == 1);
					if (m_szLine == "border_type"	) macro_SetInteger(OBJPROP_BORDER_TYPE, StringToInteger(m_szValue));
				}
				if (type == OBJ_EDIT) macro_SetInteger(OBJPROP_ALIGN, ALIGN_CENTER);
				macro_SetInteger(OBJPROP_ZORDER, 2);
				m_CountObject += (b0 ? 0 : (m_CountObject < def_MaxObject ? 1 : 0));
				return true;
				
#undef macro_SetString
#undef macro_SetInteger
			}
//+------------------------------------------------------------------+
	public	:
		static const string szMsgIDE[];
//+------------------------------------------------------------------+
		C_Chart_IDE() : m_fp(INVALID_HANDLE), m_szLine(""), m_szValue(""), m_SubWindow(0), m_CountObject(0) 
			{
			}
//+------------------------------------------------------------------+
		~C_Chart_IDE()
			{
				for (int c0 = 0; c0 < m_CountObject; c0++)
					ObjectDelete(Terminal.Get_ID(), m_ArrObject[c0].szName);
				FileClose(m_fp);
			}
//+------------------------------------------------------------------+
		void InitilizeChartTrade(double leverange = 0, double FinanceTake = 0, double FinanceStop = 0, bool b1 = true)
			{
				if (leverange > 0)
				{
					if (m_CountObject < eEDIT_STOP) return;
					m_BaseFinance.FinanceTake = Terminal.AdjustBaseFinance(FinanceTake);
					m_BaseFinance.FinanceStop = Terminal.AdjustBaseFinance(FinanceStop);
					m_BaseFinance.Leverange = Terminal.AdjustBaseFinance(leverange / Terminal.GetVolumeMinimal());
					ObjectSetString(Terminal.Get_ID(), m_ArrObject[eEDIT_LEVERAGE].szName, OBJPROP_TEXT, Terminal.ViewDouble(m_BaseFinance.Leverange));
					ObjectSetString(Terminal.Get_ID(), m_ArrObject[eEDIT_TAKE].szName, OBJPROP_TEXT, Terminal.ViewDouble(m_BaseFinance.FinanceTake));
					ObjectSetString(Terminal.Get_ID(), m_ArrObject[eEDIT_STOP].szName, OBJPROP_TEXT, Terminal.ViewDouble(m_BaseFinance.FinanceStop));
				}
				ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[eCHECK_DAYTRADE].szName, OBJPROP_STATE, m_BaseFinance.IsDayTrade = b1);
			}
//+------------------------------------------------------------------+
		bool Create(bool bFloat)
			{
				m_CountObject = 0;
				if ((m_fp = FileOpen("Chart Trade\\IDE.tpl", FILE_BIN | FILE_READ)) == INVALID_HANDLE) return false;
				FileReadInteger(m_fp, SHORT_VALUE);
				
				for (m_CountObject = eRESULT; m_CountObject <= eEDIT_STOP; m_CountObject++) m_ArrObject[m_CountObject].szName = "";
				m_SubWindow = ((m_IsFloating = bFloat) ? 0 : GetIdSubWinEA());
				m_szLine = "";
				while (m_szLine != "</chart>")
				{
					if (!FileReadLine()) return false;
					if (m_szLine == "<object>")
					{
						if (!FileReadLine()) return false;
						if (m_szLine == "type")
						{
							if (m_szValue == "102") if (!LoopCreating(OBJ_LABEL)) return false;
							if (m_szValue == "103") if (!LoopCreating(OBJ_BUTTON)) return false;
							if (m_szValue == "106") if (!LoopCreating(OBJ_BITMAP_LABEL)) return false;
							if (m_szValue == "107") if (!LoopCreating(OBJ_EDIT)) return false;
							if (m_szValue == "110") if (!LoopCreating(OBJ_RECTANGLE_LABEL)) return false;
						}
					}
				}
				FileClose(m_fp);
				DispatchMessage(CHARTEVENT_CHART_CHANGE, 0, 0, szMsgIDE[eLABEL_SYMBOL]);
				return true;
			}
//+------------------------------------------------------------------+
		void Resize(int x)
			{	
				for (int c0 = 0; c0 < m_CountObject; c0++) if (m_IsFloating)
				{
					ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[c0].szName, OBJPROP_XDISTANCE, GetIDE_Struct().X + m_ArrObject[c0].iPosX + (GetIDE_Struct().IsMaximized ? 0 : Terminal.GetWidth()));
					ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[c0].szName, OBJPROP_YDISTANCE, GetIDE_Struct().Y + m_ArrObject[c0].iPosY + (GetIDE_Struct().IsMaximized ? 0 : Terminal.GetHeight()));
				}else	ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[c0].szName, OBJPROP_XDISTANCE, x + m_ArrObject[c0].iPosX);
			};
//+------------------------------------------------------------------+
inline bool GetBaseFinance(double &Leverange, double &FinanceTP, double &FinanceSL) const
			{
				Leverange = m_BaseFinance.Leverange * Terminal.GetVolumeMinimal();
				FinanceTP = m_BaseFinance.FinanceTake;
				FinanceSL = m_BaseFinance.FinanceStop;
				return m_BaseFinance.IsDayTrade;
			}
//+------------------------------------------------------------------+
		void DispatchMessage(int id, long lparam, double dparam, string sparam)
			{
				static double AccumulatedRoof = 0.0;
				bool 		b0;
				double 	d0;
				static int px = -1, py = -1;
				
				C_ChartFloating::DispatchMessage(id, lparam, dparam, sparam);
				if (m_CountObject < eEDIT_STOP) return;
				switch (id)
				{
					case CHARTEVENT_MOUSE_MOVE:
						if ((GetIDE_Struct().X != px) || (GetIDE_Struct().Y != py))
						{
							px = GetIDE_Struct().X;
							py = GetIDE_Struct().Y;
							Resize(-1);
						}
						break;
					case CHARTEVENT_CHART_CHANGE:
						if ((b0 = (sparam == szMsgIDE[eRESULT])) || (sparam == szMsgIDE[eROOF_DIARY]))
						{
							if (b0)
							{
								ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[eRESULT].szName, OBJPROP_BGCOLOR, (dparam < 0 ? clrLightCoral : clrLightGreen));
								ObjectSetString(Terminal.Get_ID(), m_ArrObject[eRESULT].szName, OBJPROP_TEXT, Terminal.ViewDouble(dparam));
							}else
							{
								AccumulatedRoof = dparam;
								dparam = 0;
							}
							d0 = AccumulatedRoof + dparam;
							ObjectSetString(Terminal.Get_ID(), m_ArrObject[eROOF_DIARY].szName, OBJPROP_TEXT, Terminal.ViewDouble(MathAbs(d0)));
							ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[eROOF_DIARY].szName, OBJPROP_BGCOLOR, (d0 >= 0 ? clrForestGreen : clrFireBrick));
						}else	if (sparam == szMsgIDE[eLABEL_SYMBOL])
						{
							ObjectSetString(Terminal.Get_ID(), m_ArrObject[eLABEL_SYMBOL].szName, OBJPROP_TEXT, Terminal.GetSymbol());
							ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[eLABEL_SYMBOL].szName, OBJPROP_ALIGN, ALIGN_CENTER);
						}else Resize(-1);
						break;
					case CHARTEVENT_OBJECT_CLICK:
						if (StringSubstr(sparam, 0, StringLen(def_HeaderMSG)) != def_HeaderMSG)
						{
							Resize(-1);
							return;
						}
						sparam = StringSubstr(sparam, 9, StringLen(sparam));
						StringToUpper(sparam);
						if ((sparam == szMsgIDE[eBTN_SELL]) || (sparam == szMsgIDE[eBTN_BUY]))
							TradeView.ExecuteOrderInMarket(m_BaseFinance.Leverange, m_BaseFinance.FinanceTake, m_BaseFinance.FinanceStop, sparam == szMsgIDE[eBTN_BUY], m_BaseFinance.IsDayTrade);
						if (sparam == szMsgIDE[eBTN_CANCEL])
						{
							TradeView.CloseAllsPosition();
							ObjectSetInteger(Terminal.Get_ID(), m_ArrObject[eBTN_CANCEL].szName, OBJPROP_STATE, false);
						}
						if (sparam == szMsgIDE[eCHECK_DAYTRADE]) InitilizeChartTrade(0, 0, 0, m_BaseFinance.IsDayTrade ? false : true);
						break;
					case CHARTEVENT_OBJECT_ENDEDIT:
						InitilizeChartTrade(
								StringToDouble(ObjectGetString(Terminal.Get_ID(), m_ArrObject[eEDIT_LEVERAGE].szName, OBJPROP_TEXT)) * Terminal.GetVolumeMinimal(),
								StringToDouble(ObjectGetString(Terminal.Get_ID(), m_ArrObject[eEDIT_TAKE].szName, OBJPROP_TEXT)),
								StringToDouble(ObjectGetString(Terminal.Get_ID(), m_ArrObject[eEDIT_STOP].szName, OBJPROP_TEXT)),
								m_BaseFinance.IsDayTrade);
						break;
				}
			}
//+------------------------------------------------------------------+
#undef def_HeaderMSG
};
//+------------------------------------------------------------------+
static const string C_Chart_IDE::szMsgIDE[] = {
																"MSG_RESULT",
																"MSG_NAME_SYMBOL",
																"MSG_ROOF_DIARY",
																"MSG_BUY_MARKET",
																"MSG_SELL_MARKET",
																"MSG_DAY_TRADE",
																"MSG_CLOSE_POSITION",
																"MSG_LEVERAGE_VALUE",
																"MSG_TAKE_VALUE",
																"MSG_STOP_VALUE"
															 };
//+------------------------------------------------------------------+
