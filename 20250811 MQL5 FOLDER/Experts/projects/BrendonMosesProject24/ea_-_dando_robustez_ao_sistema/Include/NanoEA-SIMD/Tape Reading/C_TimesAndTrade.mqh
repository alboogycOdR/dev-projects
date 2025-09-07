//+------------------------------------------------------------------+
//|                                              C_TimesAndTrade.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include <NanoEA-SIMD\Auxiliar\C_Canvas.mqh>
#ifdef def_INTEGRATION_WITH_EA

	#include <NanoEA-SIMD\Auxiliar\C_FnSubWin.mqh>

class C_TimesAndTrade : private C_FnSubWin

#else

class C_TimesAndTrade

#endif
{
//+------------------------------------------------------------------+
#define def_SizeBuff 2048
#define macro_Limits(A) (A & 0xFF)
#define def_MaxInfos 257
#define def_ObjectName "TimesAndTrade"
//+------------------------------------------------------------------+
	private	:
		string	m_szCustomSymbol;
		char		m_ConnectionStatus;
		datetime	m_LastTime;
		ulong		m_MemTickTime;
		int		m_CountStrings;
		struct st0
		{
			string 	szTime;
			int		flag;
		}m_InfoTrades[def_MaxInfos];
		struct st1
		{
			C_Canvas Canvas;
			int		WidthRegion,
						PosXRegion,
						MaxY;
			string	szNameCanvas;
		}m_InfoCanvas;
//+------------------------------------------------------------------+
inline void CreateCustomSymbol(void)
			{
				m_szCustomSymbol = "_" + Terminal.GetFullSymbol();
				SymbolSelect(Terminal.GetFullSymbol(), true);
				SymbolSelect(m_szCustomSymbol, false);
				CustomSymbolDelete(m_szCustomSymbol);
				CustomSymbolCreate(m_szCustomSymbol, StringFormat("Custom\\Robot\\%s", m_szCustomSymbol), Terminal.GetFullSymbol());
				CustomRatesDelete(m_szCustomSymbol, 0, LONG_MAX);
				CustomTicksDelete(m_szCustomSymbol, 0, LONG_MAX);
				SymbolSelect(m_szCustomSymbol, true);
			};
//+------------------------------------------------------------------+
inline void CreateChart(void)
			{
#define macro_SetInteger(A, B) ObjectSetInteger(Terminal.Get_ID(), def_ObjectName, A, B)
				long handle;
#ifdef def_INTEGRATION_WITH_EA
				ObjectCreate(Terminal.Get_ID(), def_ObjectName, OBJ_CHART, GetIdSubWinEA("Time&TradeSupport"), 0, 0);
				m_InfoCanvas.PosXRegion =(int) ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS, GetIdSubWinEA()) - m_InfoCanvas.WidthRegion;
				macro_SetInteger(OBJPROP_YSIZE, ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, GetIdSubWinEA()));
#else
				ObjectCreate(Terminal.Get_ID(), def_ObjectName, OBJ_CHART, SubWin, 0, 0);
				m_InfoCanvas.PosXRegion =(int) ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS, SubWin) - m_InfoCanvas.WidthRegion;
				macro_SetInteger(OBJPROP_YSIZE, ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, SubWin));
#endif
				ObjectSetString(Terminal.Get_ID(), def_ObjectName, OBJPROP_SYMBOL, m_szCustomSymbol);
				macro_SetInteger(OBJPROP_CORNER, CORNER_LEFT_UPPER);
				macro_SetInteger(OBJPROP_XDISTANCE, 0);
				macro_SetInteger(OBJPROP_YDISTANCE, 0);
				macro_SetInteger(OBJPROP_XSIZE, m_InfoCanvas.PosXRegion);
				macro_SetInteger(OBJPROP_DATE_SCALE, false);
				macro_SetInteger(OBJPROP_PRICE_SCALE, false);
				macro_SetInteger(OBJPROP_PERIOD, PERIOD_M1);
				handle = ObjectGetInteger(Terminal.Get_ID(), def_ObjectName, OBJPROP_CHART_ID);
				ChartApplyTemplate(handle, "Times&Trade.tpl");
				ChartRedraw(handle);				
#undef macro_SetInteger
			};
//+------------------------------------------------------------------+
		void PrintTimeTrade(void)
			{
				int ui1;
	
				m_InfoCanvas.Canvas.Erase(clrBlack, 220);
				for (int c0 = 0, c1 = m_CountStrings - 1, y = 2; (c0 <= 255) && (y < m_InfoCanvas.MaxY); c0++, c1--, y += m_InfoCanvas.Canvas.TextHeight())
				if (m_InfoTrades[macro_Limits(c1)].szTime == NULL) break; else
				{
					ui1 = m_InfoTrades[macro_Limits(c1)].flag;
					m_InfoCanvas.Canvas.TextOutFast(2, y, m_InfoTrades[macro_Limits(c1)].szTime, macroColorRGBA((ui1 == 0 ? clrLightSkyBlue : (ui1 > 0 ? clrForestGreen : clrFireBrick)), 220));
				}
				m_InfoCanvas.Canvas.Update();
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_TimesAndTrade() : m_ConnectionStatus(-1)
			{
				m_szCustomSymbol = NULL;
				for (int c0 = 0; c0 < def_MaxInfos; c0++) m_InfoTrades[c0].szTime = NULL;
				m_CountStrings = 0;
				m_InfoCanvas.szNameCanvas = def_ObjectName + (string)MathRand();
			}
//+------------------------------------------------------------------+
		~C_TimesAndTrade()
			{
				SymbolSelect(m_szCustomSymbol, false);
				CustomSymbolDelete(m_szCustomSymbol);
				ObjectsDeleteAll(Terminal.Get_ID(), def_ObjectName);
#ifdef def_INTEGRATION_WITH_EA
				Close();
#endif
			}
//+------------------------------------------------------------------+
		void Init(const int iScale = 2)
			{
#ifdef def_INTEGRATION_WITH_EA
				if (!ExistSubWin())
#endif 
				{
					m_InfoCanvas.Canvas.FontSet("Lucida Console", 13);
					m_InfoCanvas.WidthRegion = (18 * m_InfoCanvas.Canvas.TextWidth()) + 4;
					CreateCustomSymbol();
					CreateChart();
#ifdef def_INTEGRATION_WITH_EA
					m_InfoCanvas.Canvas.Create(m_InfoCanvas.szNameCanvas, m_InfoCanvas.PosXRegion, 0, m_InfoCanvas.WidthRegion, TerminalInfoInteger(TERMINAL_SCREEN_HEIGHT), GetIdSubWinEA());
#else
					m_InfoCanvas.Canvas.Create(m_InfoCanvas.szNameCanvas, m_InfoCanvas.PosXRegion, 0, m_InfoCanvas.WidthRegion, TerminalInfoInteger(TERMINAL_SCREEN_HEIGHT), SubWin);
#endif 
					Resize();
					m_ConnectionStatus = 0;
				}
				ObjectSetInteger(Terminal.Get_ID(), def_ObjectName, OBJPROP_CHART_SCALE, (iScale > 5 ? 5 : (iScale < 0 ? 0 : iScale)));
			}
//+------------------------------------------------------------------+
inline bool Connect(void)
			{
				switch (m_ConnectionStatus)
				{
					case 0:
						if (!TerminalInfoInteger(TERMINAL_CONNECTED)) return false; else m_ConnectionStatus = 1;
					case 1:
						if (!SymbolIsSynchronized(Terminal.GetFullSymbol())) return false; else m_ConnectionStatus = 2;
					case 2:
						m_LastTime = TimeLocal();
						m_MemTickTime = macroMinusMinutes(60, m_LastTime) * 1000;
						m_ConnectionStatus = 3;
						return true;
					default:
						break;
				}
				return false;
			}	
//+------------------------------------------------------------------+
inline void Update(void)
			{
				MqlTick Tick[];
				MqlRates Rates[def_SizeBuff];
				int i0, p1, p2 = 0;
				int iflag;
				long lg1;
				static int nSwap = 0;
				static long lTime = 0;

				if (m_ConnectionStatus < 3) return;
				if ((i0 = CopyTicks(Terminal.GetFullSymbol(), Tick, COPY_TICKS_ALL, m_MemTickTime, def_SizeBuff)) > 0)
				{
					for (p1 = 0, p2 = 0; (p1 < i0) && (Tick[p1].time_msc == m_MemTickTime); p1++);
					for (int c0 = p1, c1 = 0; c0 < i0; c0++)
					{
						lg1 = Tick[c0].time_msc - lTime;
						nSwap++;
						if (Tick[c0].volume == 0) continue;
						iflag = 0;
						iflag += ((Tick[c0].flags & TICK_FLAG_BUY) == TICK_FLAG_BUY ? 1 : 0);
						iflag -= ((Tick[c0].flags & TICK_FLAG_SELL) == TICK_FLAG_SELL ? 1 : 0);
						if (iflag == 0) continue;
						Rates[c1].high = Tick[c0].ask;
						Rates[c1].low = Tick[c0].bid;
						Rates[c1].open = Tick[c0].last;
						Rates[c1].close = Tick[c0].last + ((Tick[c0].volume > 200 ? 200 : Tick[c0].volume) * (Terminal.GetTypeSymbol() == C_Terminal::WDO ? 0.02 : 1.0) * iflag);
						Rates[c1].time = m_LastTime;
						m_InfoTrades[macro_Limits(m_CountStrings)].szTime = StringFormat("%02.d.%03d ~ %02.d <>%04.d", ((lg1 - (lg1 % 1000)) / 1000) % 60 , lg1 % 1000, nSwap, Tick[c0].volume);
						m_InfoTrades[macro_Limits(m_CountStrings)].flag = iflag;
						m_CountStrings++;
						nSwap = 0;					
						lTime = Tick[c0].time_msc;
						p2++;
						c1++;
						m_LastTime += 60;
					}
					CustomRatesUpdate(m_szCustomSymbol, Rates, p2);
					m_MemTickTime = Tick[i0 - 1].time_msc;
				}
				PrintTimeTrade();
			}
//+------------------------------------------------------------------+
		void Resize(void)
			{
				static int MaxX = 0;
#ifdef def_INTEGRATION_WITH_EA
				int x = (int) ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS, GetIdSubWinEA());	
				m_InfoCanvas.MaxY = (int) ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, GetIdSubWinEA());
#else 
				int x = (int) ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS, SubWin);	
				m_InfoCanvas.MaxY = (int) ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS, SubWin);
#endif 
				ObjectSetInteger(Terminal.Get_ID(), def_ObjectName, OBJPROP_YSIZE, m_InfoCanvas.MaxY);
				if (MaxX != x)
				{
					MaxX = x;
					x -= m_InfoCanvas.WidthRegion;
	  				ObjectSetInteger(Terminal.Get_ID(), def_ObjectName, OBJPROP_XSIZE, x);
	  				ObjectSetInteger(Terminal.Get_ID(), m_InfoCanvas.szNameCanvas, OBJPROP_XDISTANCE, x);
				}
				PrintTimeTrade();
			}
//+------------------------------------------------------------------+
#undef def_SizeBuff
#undef macro_Limits
#undef def_ObjectName
};
//+------------------------------------------------------------------+
