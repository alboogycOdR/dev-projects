//+------------------------------------------------------------------+
//|                                                    WallPaper.mq5 |
//|                                                      Daniel Jose |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property indicator_chart_window
#property indicator_plots 0
//+------------------------------------------------------------------+
#include "C_Wallpaper2.mqh"
//+------------------------------------------------------------------+
input group "WallPaper"
input string 						user10 = "Lates_Logo";			//BitMap a ser usado
input char							user11 = 60;							//Transparencia (0 a 100)
input C_WallPaper::eTypeImage	user12 = C_WallPaper::IMAGEM;		//Tipo de imagem de fundo
//+------------------------------------------------------------------+
C_Terminal	Terminal;
C_WallPaper WallPaper;
//+------------------------------------------------------------------+
int OnInit()
{
	IndicatorSetString(INDICATOR_SHORTNAME, "WallPaper");
	Terminal.Init();
	WallPaper.Init(user10, user12, user11);

	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	return rates_total;
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	switch (id)
	{
		case CHARTEVENT_CHART_CHANGE:
			Terminal.Resize();
			WallPaper.Resize();
      	break;
	}
	ChartRedraw();
}
//+------------------------------------------------------------------+
