//+------------------------------------------------------------------+
//|                                              C_TemplateChart.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Chart_IDE.mqh"
//+------------------------------------------------------------------+
class C_TemplateChart : public C_Chart_IDE
{
#define def_MaxTemplates		8
#define def_NameTemplateRAD	"IDE"
//+------------------------------------------------------------------+
	private	:
//+------------------------------------------------------------------+
	enum eParameter {TEMPLATE = 0, PERIOD, SCALE, WIDTH, HEIGHT};
//+------------------------------------------------------------------+
		struct st
		{
			string				szObjName,
									szSymbol,
									szTemplate,
									szVLine;
			int					width,
									scale;
			ENUM_TIMEFRAMES	timeframe;
			long					handle;
		}m_Info[def_MaxTemplates];
		int	m_Counter,
				m_CPre,
				m_Aggregate;
		struct st00
		{
			int		counter;
			string 	Param[HEIGHT + 1];
		}m_Params;
//+------------------------------------------------------------------+
		int GetCommand(int iArg, const string szArg)
			{
				for (int c0 = TEMPLATE; c0 <= HEIGHT; c0++) m_Params.Param[c0] = "";
				m_Params.counter = 0;
				for (int c1 = iArg, c2 = 0; szArg[iArg] != 0x00; iArg++) switch (szArg[iArg])
				{
					case ')':
					case ';':
						m_Params.Param[m_Params.counter++] = StringSubstr(szArg, c1, c2);
						for (; (szArg[iArg] != 0x00) && (szArg[iArg] != ';'); iArg++);
						return iArg + 1;
					case ' ':
						c2 += (c1 == iArg ? 0 : 1);
						c1 = (c1 == iArg ? iArg + 1 : c1);
						break;
					case '(':
					case ',':
						if (m_Params.counter == HEIGHT) return StringLen(szArg) + 1;
						c2 = (m_Params.counter == SCALE ? (c2 >= 1 ? 1 : c2) : c2);
						m_Params.Param[m_Params.counter++] = StringSubstr(szArg, c1, c2);
						c2 = 0;
						c1 = iArg + 1;
						break;
					default:
						c2++;
						break;
				}
				return -1;
			}
//+------------------------------------------------------------------+
		void SetBase(string szTemplate, string szSymbol, ENUM_TIMEFRAMES timeframe, int scale, int w)
			{
#define macro_SetInteger(A, B) ObjectSetInteger(Terminal.Get_ID(), m_Info[m_Counter].szObjName, A, B)		
				m_Info[m_Counter].szObjName = (string) ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string) MathRand();
				m_Info[m_Counter].szTemplate = szTemplate;
				ObjectCreate(Terminal.Get_ID(), m_Info[m_Counter].szObjName, OBJ_CHART, GetIdSubWinEA(), 0, 0);
				ObjectSetString(Terminal.Get_ID(), m_Info[m_Counter].szObjName, OBJPROP_SYMBOL, (m_Info[m_Counter].szSymbol = szSymbol));
				macro_SetInteger(OBJPROP_CHART_SCALE, m_Info[m_Counter].scale = scale);
				macro_SetInteger(OBJPROP_CORNER, CORNER_LEFT_UPPER);
				macro_SetInteger(OBJPROP_XDISTANCE, 0);
				macro_SetInteger(OBJPROP_YDISTANCE, 0);
				macro_SetInteger(OBJPROP_XSIZE, ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS, GetIdSubWinEA()));
				macro_SetInteger(OBJPROP_YSIZE, ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, GetIdSubWinEA()));
				macro_SetInteger(OBJPROP_DATE_SCALE, false);
				macro_SetInteger(OBJPROP_PRICE_SCALE, false);
				macro_SetInteger(OBJPROP_PERIOD, m_Info[m_Counter].timeframe = timeframe);
				m_Info[m_Counter].handle = ObjectGetInteger(Terminal.Get_ID(), m_Info[m_Counter].szObjName, OBJPROP_CHART_ID);
				if (szTemplate == def_NameTemplateRAD) ClearObjectChart(m_Info[m_Counter].handle);
				m_Aggregate += w;
				m_Info[m_Counter].width = w;
				m_CPre += (w > 0 ? 1 : 0);
				m_Counter++;
#undef macro_SetInteger
			};
//+------------------------------------------------------------------+
		void AddTemplate(void)
			{
				ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT;
				string sz0 = m_Params.Param[PERIOD];
				int w, h, i;
				bool bIsSymbol;

				if (sz0 == "1M") timeframe = PERIOD_M1; else
				if (sz0 == "2M") timeframe = PERIOD_M2; else
				if (sz0 == "3M") timeframe = PERIOD_M3; else
				if (sz0 == "4M") timeframe = PERIOD_M4; else
				if (sz0 == "5M") timeframe = PERIOD_M5; else
				if (sz0 == "6M") timeframe = PERIOD_M6; else
				if (sz0 == "10M") timeframe = PERIOD_M10; else
				if (sz0 == "12M") timeframe = PERIOD_M12; else
				if (sz0 == "15M") timeframe = PERIOD_M15; else
				if (sz0 == "20M") timeframe = PERIOD_M20; else
				if (sz0 == "30M") timeframe = PERIOD_M30; else
				if (sz0 == "1H") timeframe = PERIOD_H1; else
				if (sz0 == "2H") timeframe = PERIOD_H2; else
				if (sz0 == "3H") timeframe = PERIOD_H3; else
				if (sz0 == "4H") timeframe = PERIOD_H4; else
				if (sz0 == "6H") timeframe = PERIOD_H6; else
				if (sz0 == "8H") timeframe = PERIOD_H8; else
				if (sz0 == "12H") timeframe = PERIOD_H12; else
				if (sz0 == "1D") timeframe = PERIOD_D1; else
				if (sz0 == "1S") timeframe = PERIOD_W1; else
				if (sz0 == "1MES") timeframe = PERIOD_MN1;
				if ((m_Counter >= def_MaxTemplates) || (m_Params.Param[TEMPLATE] == "")) return;
				bIsSymbol = SymbolSelect(m_Params.Param[TEMPLATE], true);
				w = (m_Params.Param[WIDTH] != "" ? (int)StringToInteger(m_Params.Param[WIDTH]) : 0);
				h = (m_Params.Param[HEIGHT] != "" ? (int)StringToInteger(m_Params.Param[HEIGHT]) : 0);
				i = (m_Params.Param[SCALE] != "" ? (int)StringToInteger(m_Params.Param[SCALE]) : -1);
				i = (i > 5 || i < 0 ? -1 : i);
				if (h == 0)
				{
					SetBase(m_Params.Param[TEMPLATE], (bIsSymbol ? m_Params.Param[TEMPLATE] : _Symbol), timeframe, i, w);
					if (!ChartApplyTemplate(m_Info[m_Counter - 1].handle, m_Params.Param[TEMPLATE] + ".tpl")) if (bIsSymbol) ChartApplyTemplate(m_Info[m_Counter - 1].handle, "Default.tpl");
				}
				if (m_Params.Param[TEMPLATE] == def_NameTemplateRAD)
				{
					C_Chart_IDE::Create(Add_RAD_IDE(m_Params.Param[TEMPLATE], 0, -1, w, h));
					if (h == 0) m_Info[m_Counter - 1].szVLine = "";
				}else
				{
					if ((w > 0) && (h > 0)) AddIndicator(m_Params.Param[TEMPLATE], 0, -1, w, h, timeframe, i); else
					{
						m_Info[m_Counter - 1].szVLine = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
						ObjectCreate(m_Info[m_Counter - 1].handle, m_Info[m_Counter - 1].szVLine, OBJ_VLINE, 0, 0, 0);
						ObjectSetInteger(m_Info[m_Counter - 1].handle, m_Info[m_Counter - 1].szVLine, OBJPROP_COLOR, clrBlack);
					}
				}
			}
//+------------------------------------------------------------------+
		void Resize(void)
			{
#define macro_SetInteger(A, B) ObjectSetInteger(Terminal.Get_ID(), m_Info[c0].szObjName, A, B)
				int x0, x1, y;
				if (!ExistSubWin()) return;
				x0 = 0;
				y = (int)(ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, GetIdSubWinEA()));
				x1 = (int)((Terminal.GetWidth() - m_Aggregate) / (m_Counter > 0 ? (m_CPre == m_Counter ? m_Counter : (m_Counter - m_CPre)) : 1));
				for (char c0 = 0; c0 < m_Counter; x0 += (m_Info[c0].width > 0 ? m_Info[c0].width : x1), c0++)
				{
					macro_SetInteger(OBJPROP_XDISTANCE, x0);
					macro_SetInteger(OBJPROP_XSIZE, (m_Info[c0].width > 0 ? m_Info[c0].width : x1));
					macro_SetInteger(OBJPROP_YSIZE, y);
					if (m_Info[c0].szTemplate == "IDE")
					{
						ChartRedraw(m_Info[c0].handle);
						C_Chart_IDE::Resize(x0);
					}
				}
				ChartRedraw();
#undef macro_SetInteger
			}
//+------------------------------------------------------------------+
	public	:
		C_TemplateChart() : m_Counter(0), m_CPre(0) {};
//+------------------------------------------------------------------+
		~C_TemplateChart() 
			{
				ClearTemplateChart();
			}
//+------------------------------------------------------------------+
		void ClearTemplateChart(void)
			{
				for (char c0 = 0; c0 < m_Counter; c0++)
				{
					ObjectDelete(Terminal.Get_ID(), m_Info[c0].szObjName);
					SymbolSelect(m_Info[c0].szSymbol, false);
				}
				m_CPre = 0;
				m_Counter = 0;
				m_Aggregate = 0;
				C_SubWindow::Close();
			}
//+------------------------------------------------------------------+
		void AddThese(string szArg)
			{
				int i0, i1;
				StringToUpper(szArg);
				if (StringLen(szArg) == 0) return;
				StringAdd(szArg, ";");
				i0 = 0;
				while ((i1 = GetCommand(i0, szArg)) > 0)
				{
					AddTemplate();
					i0 = i1;
				}
			}
//+------------------------------------------------------------------+
		void DispatchMessage(int id, long lparam, double dparam, string sparam)
			{
				datetime dt;
				double p;

				C_Chart_IDE::DispatchMessage(id, lparam, dparam, sparam);
				switch (id)
				{
					case CHARTEVENT_MOUSE_MOVE:
						Mouse.GetPositionDP(dt, p);
						for (int c0 = 0; c0 < m_Counter; c0++)	if (m_Info[c0].szVLine != "")
						{
							ObjectMove(m_Info[c0].handle, m_Info[c0].szVLine, 0, dt, 0);
							ChartRedraw(m_Info[c0].handle);
						}
						break;
					case CHARTEVENT_CHART_CHANGE:
						Resize();
						for (int c0 = 0; c0 < m_Counter; c0++)
						{
							ObjectSetInteger(Terminal.Get_ID(), m_Info[c0].szObjName, OBJPROP_PERIOD, m_Info[c0].timeframe);
							ObjectSetInteger(Terminal.Get_ID(), m_Info[c0].szObjName, OBJPROP_CHART_SCALE, (m_Info[c0].scale < 0 ? ChartGetInteger(Terminal.Get_ID(), CHART_SCALE) : m_Info[c0].scale));
						}
						break;
				}
			}
//+------------------------------------------------------------------+
#undef def_MaxTemplates
#undef def_NameTemplateRAD
};
//+------------------------------------------------------------------+
