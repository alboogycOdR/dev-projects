//+------------------------------------------------------------------+
//|                                                C_WinTemplate.mqh |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#define def_BtnMaximize		"Images\\NanoEA-SIMD\\Maximize.bmp"
#define def_BtnMinimize		"Images\\NanoEA-SIMD\\Minimize.bmp"
#define def_Shift 			4
#define def_SizeBarCaption 26
#define def_BtnSize			20
#define def_MaxFloating		10
//+------------------------------------------------------------------+
#resource "\\" + def_BtnMaximize
#resource "\\" + def_BtnMinimize
//+------------------------------------------------------------------+
struct IDE_Struct
{
	int 	X,
			Y,
			Index;
	bool 	IsMaximized;
};
//+------------------------------------------------------------------+
class C_ChartFloating
{
#define macro_SetBtnMaxMinX(A) ObjectSetInteger(Terminal.Get_ID(), m_Win[A].szBtnMaxMin, OBJPROP_XDISTANCE, m_Win[A].PosX + m_Win[A].Width - def_BtnSize - def_Shift)
	private	:
		struct st00
		{
			bool					IsMaximized;
			int					MaxWidth,
									MaxHeight,
									Width,
									PosX_Maximized,
									PosY_Maximized,
									PosX_Minimized,
									PosY_Minimized,
									PosX,
									PosY,
									Scale;
			long					handle;
			string				szVLine,
									szBarTitle,
									szBtnMaxMin,
									szCaption,
									szRegionChart;
			ENUM_TIMEFRAMES 	TimeFrame;
		}m_Win[def_MaxFloating];
		int	m_LimitX,
				m_LimitY,
				m_MaxCounter;
		IDE_Struct m_IDEStruct;
//+------------------------------------------------------------------+
		void SwapMaxMin(const bool IsMax, const int c0)
			{
				m_Win[c0].IsMaximized = IsMax;
				SetDimension((m_Win[c0].IsMaximized ? m_Win[c0].MaxWidth : 100), (m_Win[c0].IsMaximized ? m_Win[c0].MaxHeight : 0), false, c0);
				SetPosition((m_Win[c0].IsMaximized ? m_Win[c0].PosX_Maximized : m_Win[c0].PosX_Minimized), (m_Win[c0].IsMaximized ? m_Win[c0].PosY_Maximized : m_Win[c0].PosY_Minimized), c0);
			}
//+------------------------------------------------------------------+
		void SetDimension(const int W, const int H, const bool bMode, const int c0)
			{
				m_Win[c0].MaxWidth = (bMode ? W : m_Win[c0].MaxWidth);
				m_Win[c0].MaxHeight = (bMode ? H : m_Win[c0].MaxHeight);
				m_Win[c0].Width = W;
				ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szBarTitle, OBJPROP_XSIZE, W);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szBarTitle, OBJPROP_YSIZE, def_SizeBarCaption);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_XSIZE, W);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_YSIZE, H);
				macro_SetBtnMaxMinX(c0);
			}
//+------------------------------------------------------------------+
		void SetPosition(const int X, const int Y, const int c0)
			{
				if ((m_Win[c0].PosX != X) && (X >= 0) && ((X + m_Win[c0].Width) < m_LimitX))
				{
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szBarTitle, OBJPROP_XDISTANCE, m_Win[c0].PosX = X);
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szCaption, OBJPROP_XDISTANCE, m_Win[c0].PosX + def_Shift);
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_XDISTANCE, m_Win[c0].PosX);
					macro_SetBtnMaxMinX(c0);
					if (m_Win[c0].IsMaximized) m_Win[c0].PosX_Maximized = X; else m_Win[c0].PosX_Minimized = X;
				}
				if ((m_Win[c0].PosY != Y) && (Y >= 0) && ((Y + def_SizeBarCaption) < m_LimitY))
				{
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szBarTitle, OBJPROP_YDISTANCE, m_Win[c0].PosY = Y);
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szCaption, OBJPROP_YDISTANCE, m_Win[c0].PosY + def_Shift);
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szBtnMaxMin, OBJPROP_YDISTANCE, m_Win[c0].PosY + def_Shift);
					ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_YDISTANCE, m_Win[c0].PosY + def_SizeBarCaption);
					if (m_Win[c0].IsMaximized) m_Win[c0].PosY_Maximized = Y; else m_Win[c0].PosY_Minimized = Y;
				}
				if (c0 == m_IDEStruct.Index)
				{
					m_IDEStruct.X = m_Win[c0].PosX + 3;
					m_IDEStruct.Y = m_Win[c0].PosY + def_SizeBarCaption + 3;
					m_IDEStruct.IsMaximized = m_Win[c0].IsMaximized;
				}
			}
//+------------------------------------------------------------------+
		void CreateBarTitle(void)
			{
				m_Win[m_MaxCounter].szBarTitle = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
				ObjectCreate(Terminal.Get_ID(), m_Win[m_MaxCounter].szBarTitle, OBJ_RECTANGLE_LABEL, 0, 0, 0);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szBarTitle, OBJPROP_ZORDER, 2);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szBarTitle, OBJPROP_BGCOLOR, clrDodgerBlue);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szBarTitle, OBJPROP_BORDER_TYPE, BORDER_RAISED);
			}
//+------------------------------------------------------------------+
		void CreateCaption(string sz0)
			{
				m_Win[m_MaxCounter].szCaption = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
				ObjectCreate(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJ_EDIT, 0, 0, 0);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_READONLY, true);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_XSIZE, 90);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_BORDER_COLOR, clrDodgerBlue);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_COLOR, clrBlack);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_BGCOLOR, clrDodgerBlue);
				ObjectSetString(Terminal.Get_ID(), m_Win[m_MaxCounter].szCaption, OBJPROP_TEXT, sz0);
			}
//+------------------------------------------------------------------+
		void CreateBtnMaxMin(void)
			{
				m_Win[m_MaxCounter].IsMaximized = true;
				m_Win[m_MaxCounter].szBtnMaxMin = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
				ObjectCreate(Terminal.Get_ID(), m_Win[m_MaxCounter].szBtnMaxMin, OBJ_BITMAP_LABEL, 0, 0, 0);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szBtnMaxMin, OBJPROP_ZORDER, 2);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szBtnMaxMin, OBJPROP_STATE, m_Win[m_MaxCounter].IsMaximized);
				ObjectSetString(Terminal.Get_ID(), m_Win[m_MaxCounter].szBtnMaxMin, OBJPROP_BMPFILE, 0, "::" + def_BtnMaximize);
				ObjectSetString(Terminal.Get_ID(), m_Win[m_MaxCounter].szBtnMaxMin, OBJPROP_BMPFILE, 1, "::" + def_BtnMinimize);
			}
//+------------------------------------------------------------------+
		void CreateRegion(ENUM_TIMEFRAMES TimeFrame, int Scale)
			{
				m_Win[m_MaxCounter].szRegionChart = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
				ObjectCreate(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJ_CHART, 0, 0, 0);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJPROP_DATE_SCALE, false);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJPROP_PRICE_SCALE, false);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJPROP_PERIOD, m_Win[m_MaxCounter].TimeFrame = TimeFrame);
				ObjectSetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJPROP_CHART_SCALE, m_Win[m_MaxCounter].Scale = Scale);
			}
//+------------------------------------------------------------------+
		bool StageLocal01(string sz0, ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT, int Scale = -1)
			{
				m_LimitX = (int)ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS);
				m_LimitY = (int)ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS);
				if (m_MaxCounter >= def_MaxFloating) return false;
				CreateBarTitle();
				CreateCaption(sz0);
				CreateBtnMaxMin();
				CreateRegion(TimeFrame, Scale);
				m_Win[m_MaxCounter].handle = ObjectGetInteger(Terminal.Get_ID(), m_Win[m_MaxCounter].szRegionChart, OBJPROP_CHART_ID);
				
				return true;
			}
//+------------------------------------------------------------------+
		void StageLocal02(int x, int y, int w, int h)
			{
				y = (y < 0 ? m_MaxCounter * def_SizeBarCaption : y);				
				m_Win[m_MaxCounter].PosX	= -1;
				m_Win[m_MaxCounter].PosY	= -1;
				m_Win[m_MaxCounter].PosX_Minimized = m_Win[m_MaxCounter].PosX_Maximized = x;
				m_Win[m_MaxCounter].PosY_Minimized = m_Win[m_MaxCounter].PosY_Maximized = y;
				SetDimension(w, h, true, m_MaxCounter);
				SetPosition(x, y, m_MaxCounter);
				ChartRedraw(m_Win[m_MaxCounter].handle);
				m_MaxCounter++;
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_ChartFloating()
			{
				m_MaxCounter = 0;
			 	ChartSetInteger(Terminal.Get_ID(), CHART_EVENT_MOUSE_MOVE, true);
			};
//+------------------------------------------------------------------+
		~C_ChartFloating()
			{
				CloseAlls();
			}
//+------------------------------------------------------------------+
		void CloseAlls(void)
			{
				for (int c0 = 0; c0 < m_MaxCounter; c0++)
				{
					ObjectDelete(Terminal.Get_ID(), m_Win[c0].szBarTitle);
					ObjectDelete(Terminal.Get_ID(), m_Win[c0].szBtnMaxMin);
					ObjectDelete(Terminal.Get_ID(), m_Win[c0].szCaption);
					ObjectDelete(Terminal.Get_ID(), m_Win[c0].szRegionChart);
				}
				m_MaxCounter = 0;
				ChartRedraw();
			}
//+------------------------------------------------------------------+
		void ClearObjectChart(long handle)
			{
				ChartSetInteger(handle, CHART_COLOR_BID, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_ASK, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_VOLUME, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_CANDLE_BEAR, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_CANDLE_BULL, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_CHART_LINE, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_CHART_DOWN, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_CHART_UP, clrNONE);
				ChartSetInteger(handle, CHART_COLOR_STOP_LEVEL, clrNONE);
				ChartSetInteger(handle, CHART_SHOW_ASK_LINE, false);
				ChartSetInteger(handle, CHART_SHOW_BID_LINE, false);
				ChartSetInteger(handle, CHART_SHOW_OHLC, false);
				ChartSetInteger(handle, CHART_SHOW_TICKER, false);
				ChartSetInteger(handle, CHART_SHOW_LAST_LINE, false);
				ChartSetInteger(handle, CHART_SHOW_TRADE_LEVELS, false);
			}
//+------------------------------------------------------------------+
inline IDE_Struct GetIDE_Struct(void) const { return m_IDEStruct; }
//+------------------------------------------------------------------+
		bool Add_RAD_IDE(string sz0, int x, int y, int w, int h)
			{
				if ((w <= 0) || (h <= 0)) return false;
				if (!StageLocal01(sz0, PERIOD_CURRENT, -1)) return false;
				ChartApplyTemplate(m_Win[m_MaxCounter].handle, "\\Files\\Chart Trade\\IDE.tpl");
				m_IDEStruct.Index = m_MaxCounter;
				StageLocal02(x, y, w, h);
				return true;
			}
//+------------------------------------------------------------------+
		bool AddIndicator(string sz0, int x = 0, int y = -1, int w = 300, int h = 200, ENUM_TIMEFRAMES TimeFrame = PERIOD_CURRENT, int Scale = -1)
			{
				if (!StageLocal01(sz0, TimeFrame, Scale)) return false;
								
				ChartApplyTemplate(m_Win[m_MaxCounter].handle, sz0 + ".tpl");	
						
				m_Win[m_MaxCounter].szVLine = (string)ObjectsTotal(Terminal.Get_ID(), -1, -1) + (string)MathRand();
				ObjectCreate(m_Win[m_MaxCounter].handle, m_Win[m_MaxCounter].szVLine, OBJ_VLINE, 0, 0, 0);
				ObjectSetInteger(m_Win[m_MaxCounter].handle, m_Win[m_MaxCounter].szVLine, OBJPROP_COLOR, clrBlack);
				
				StageLocal02(x, y, w, h);

				return true;
			}
//+------------------------------------------------------------------+
		void DispatchMessage(int id, long lparam, double dparam, string sparam)
			{
				int mx, my;
				datetime dt;
				double p;
				static int six = -1, siy = -1, sic = -1;
				
				switch (id)
				{
					case CHARTEVENT_MOUSE_MOVE:
						Mouse.GetPositionXY(mx, my);
						if ((Mouse.GetButtonStatus() & 0x01) == 1)
						{
							if (sic == -1)	for (int c0 = m_MaxCounter - 1; (sic < 0) && (c0 >= 0); c0--)
								sic = (((mx > m_Win[c0].PosX) && (mx < (m_Win[c0].PosX + m_Win[c0].Width)) && (my > m_Win[c0].PosY) && (my < (m_Win[c0].PosY + def_SizeBarCaption))) ? c0 : -1);
							if (sic >= 0)
							{
								if (six < 0) ChartSetInteger(Terminal.Get_ID(), CHART_MOUSE_SCROLL, false);
								six = (six < 0 ? mx - m_Win[sic].PosX : six);
								siy = (siy < 0 ? my - m_Win[sic].PosY : siy);
								SetPosition(mx - six, my - siy, sic);
							}
						}else
						{
							if (six > 0) ChartSetInteger(Terminal.Get_ID(), CHART_MOUSE_SCROLL, true);
							six = siy = sic = -1;
						}
						ChartXYToTimePrice(Terminal.Get_ID(), mx, my, my, dt, p);
						for (int c0 = 0; c0 < m_MaxCounter; c0++)
							ObjectMove(m_Win[c0].handle, m_Win[c0].szVLine, 0, dt, 0);
						break;
					case CHARTEVENT_OBJECT_CLICK:
						for (int c0 = 0; c0 < m_MaxCounter; c0++) if (sparam == m_Win[c0].szBtnMaxMin)
						{
							SwapMaxMin((bool)ObjectGetInteger(Terminal.Get_ID(), m_Win[c0].szBtnMaxMin, OBJPROP_STATE), c0);
							break;
						}
						break;
					case CHARTEVENT_CHART_CHANGE:
						for(int c0 = 0; c0 < m_MaxCounter; c0++)
						{
							ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_PERIOD, m_Win[c0].TimeFrame);
							ObjectSetInteger(Terminal.Get_ID(), m_Win[c0].szRegionChart, OBJPROP_CHART_SCALE, (m_Win[c0].Scale < 0 ? ChartGetInteger(Terminal.Get_ID(), CHART_SCALE) : m_Win[c0].Scale));
						}
						m_LimitX = (int)ChartGetInteger(Terminal.Get_ID(), CHART_WIDTH_IN_PIXELS);
						m_LimitY = (int)ChartGetInteger(Terminal.Get_ID(), CHART_HEIGHT_IN_PIXELS);
						break;
				}
				for (int c0 = 0; c0 < m_MaxCounter; c0++)
					ChartRedraw(m_Win[c0].handle);
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
#undef macro_SetBtnMaxMinX
#undef def_BtnSize
#undef def_SizeBarCaption
#undef def_Shift
//+------------------------------------------------------------------+
