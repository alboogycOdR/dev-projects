//+------------------------------------------------------------------+
//|                                                      StatsEA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\SymbolInfo.mqh>
#include <Comment.mqh>
CComment smartcomment;
CSymbolInfo       m_symbol;
#include "..\includes\\tradestats\\CTradeStatistics2020.mqh"

static CTradeStatistics stat_global; // Static object declaration

static CTradeStatistics stat_priceaction_ea; // Static object declaration

bool              showdashboard=true;         //Show Dashboard
input ulong       m_magic=22324; //Magic Number
bool              enableTradingStatistics=true;//EA Performance Stats
input int               DAYS_OF_STATS =90; // Days to calc performance on EA
#define           COLOR_BACK      clrBlack
#define           COLOR_BORDER    clrDimGray
#define           COLOR_CAPTION   clrDodgerBlue
#define           COLOR_TEXT      clrLightGray
#define           COLOR_WIN       clrLimeGreen
#define           COLOR_LOSS      clrOrangeRed
bool              InpAutoColors=false;//Comment Auto Colors
bool              InpGraphMode=true;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!m_symbol.Name(Symbol()))
      return(INIT_FAILED);
   stat_priceaction_ea.SetMagicNumber(m_magic); // Set the magic number
   stat_priceaction_ea.Calculate();
   stat_global.CalculateGlobal();
//==
   if(showdashboard)
      SetupSmartComment();
//--- create timer
   EventSetTimer(60);
   OnTimer();
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- destroy timer
   EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   stat_priceaction_ea.Calculate();
   stat_global.Calculate();
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   stat_priceaction_ea.Calculate();
   stat_global.Calculate();
   smartcomment.SetText(0,"MAGIC :   "+StringFormat("%d",m_magic),COLOR_TEXT);/*          */
   smartcomment.SetText(1,"HISTORY (days) :   "+StringFormat("%d",DAYS_OF_STATS),COLOR_TEXT);/*          */
   smartcomment.SetText(2,"CONSEC. LOSS GLOBAL:   "+StringFormat("%.2f",stat_global.ConLossMax()),COLOR_WIN);/*          */
   smartcomment.SetText(3,"CONSEC. LOSS SYMBOL:   "+StringFormat("%.2f",stat_priceaction_ea.ConLossMax()),COLOR_WIN);/*          */
//--=
   smartcomment.SetText(4,"PROFIT FACTOR GLOBAL:   "+StringFormat("%.2f",stat_global.ProfitFactor()),COLOR_WIN);/*         total net profit */
   smartcomment.SetText(5,"PROFIT FACTOR MAGIC:   "+StringFormat("%.2f",stat_priceaction_ea.ProfitFactor()),COLOR_WIN);/*         total net profit */
//--=
   smartcomment.SetText(6,"RECOVERY FACTOR GLOBAL :   "+StringFormat("%d",stat_global.RecoveryFactor()),COLOR_WIN);/*         TOTAL TRADES */
   smartcomment.SetText(7,"RECOVERY FACTOR MAGIC:   "+StringFormat("%d",stat_priceaction_ea.RecoveryFactor()),COLOR_WIN);/*         TOTAL TRADES */
//--=
   smartcomment.SetText(8,"EQUITY LOSS% GLOBAL:   "+StringFormat("%.2f",stat_global.EquityDDPercent()),COLOR_WIN);/*      LARGEST PROFIT TRADE*/
   smartcomment.SetText(9,"EQUITY LOSS% MAGIC :   "+StringFormat("%.2f",stat_priceaction_ea.EquityDDPercent()),COLOR_WIN);/*      LARGEST PROFIT TRADE*/
//--=
   smartcomment.SetText(10,"WIN RATE GLOBAL:   "+StringFormat("%.2f",stat_global.MaxConWins()),COLOR_WIN);/* LARGEST LOSS TRADE*/
   smartcomment.SetText(11,"WIN RATE MAGIC:   "+StringFormat("%.2f",stat_priceaction_ea.MaxConWins()),COLOR_WIN);/* LARGEST LOSS TRADE*/
//--=
   smartcomment.Show();
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
//---
}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
//---
}
//+------------------------------------------------------------------+
void SetupSmartComment()
{
//--- panel position
   int y=30;
   if(ChartGetInteger(0,CHART_SHOW_ONE_CLICK))
      y=120;
//--- panel name
   srand(GetTickCount());
   string name="SMARTPANEL_"+IntegerToString(MathRand());
   smartcomment.Create(name,20,y);
   smartcomment.SetAutoColors(InpAutoColors);//InpAutoColors
   smartcomment.SetGraphMode(true);
   smartcomment.SetColor(COLOR_BORDER,COLOR_BACK,255);
   smartcomment.SetFont("Lucida Console",13,false,1.7);
//_______________________________________________________________________________________________
   smartcomment.SetText(0,"MAGIC :   "+StringFormat("%d",m_magic),COLOR_TEXT);/*          */
   smartcomment.SetText(1,"HISTORY (days) :   "+StringFormat("%d",DAYS_OF_STATS),COLOR_TEXT);/*          */
   smartcomment.SetText(2,"CONSEC. LOSS GLOBAL:   "+StringFormat("%.2f",stat_global.ConLossMax()),COLOR_WIN);/*          */
   smartcomment.SetText(3,"CONSEC. LOSS SYMBOL:   "+StringFormat("%.2f",stat_priceaction_ea.ConLossMax()),COLOR_WIN);/*          */
//--=
   smartcomment.SetText(4,"PROFIT FACTOR GLOBAL:   "+StringFormat("%.2f",stat_global.ProfitFactor()),COLOR_WIN);/*         total net profit */
   smartcomment.SetText(5,"PROFIT FACTOR MAGIC:   "+StringFormat("%.2f",stat_priceaction_ea.ProfitFactor()),COLOR_WIN);/*         total net profit */
//--=
   smartcomment.SetText(6,"RECOVERY FACTOR GLOBAL :   "+StringFormat("%d",stat_global.RecoveryFactor()),COLOR_WIN);/*         TOTAL TRADES */
   smartcomment.SetText(7,"RECOVERY FACTOR MAGIC:   "+StringFormat("%d",stat_priceaction_ea.RecoveryFactor()),COLOR_WIN);/*         TOTAL TRADES */
//--=
   smartcomment.SetText(8,"EQUITY LOSS% GLOBAL:   "+StringFormat("%.2f",stat_global.EquityDDPercent()),COLOR_WIN);/*      LARGEST PROFIT TRADE*/
   smartcomment.SetText(9,"EQUITY LOSS% MAGIC :   "+StringFormat("%.2f",stat_priceaction_ea.EquityDDPercent()),COLOR_WIN);/*      LARGEST PROFIT TRADE*/
//--=
   smartcomment.SetText(10,"WIN RATE GLOBAL:   "+StringFormat("%.2f",stat_global.MaxConWins()),COLOR_WIN);/* LARGEST LOSS TRADE*/
   smartcomment.SetText(11,"WIN RATE MAGIC:   "+StringFormat("%.2f",stat_priceaction_ea.MaxConWins()),COLOR_WIN);/* LARGEST LOSS TRADE*/
//--=
   smartcomment.Show();
}
//+------------------------------------------------------------------+
