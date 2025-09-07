//+------------------------------------------------------------------+
//|  	                                   	  MultiCurrencyExample.mq5 |
//|                                                    Andriy Moraru |
//|                                        https://www.earnforex.com |
//|            							                       2010-2021 |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2021"
#property link      "https://www.earnforex.com/creating-multi-currency-expert-advisor-for-metatrader-5/"
#property version   "1.01"
#property description "A fully scalable and flexible class-based multi-currency expert advisor example."

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

// Trading instruments:
input string CurrencyPair1 = "EURUSD";
input string CurrencyPair2 = "GBPUSD";
input string CurrencyPair3 = "USDJPY";
input string CurrencyPair4 = "EURCAD";

// Timeframes:
input ENUM_TIMEFRAMES TimeFrame1 = PERIOD_M15;
input ENUM_TIMEFRAMES TimeFrame2 = PERIOD_M30;
input ENUM_TIMEFRAMES TimeFrame3 = PERIOD_H1;
input ENUM_TIMEFRAMES TimeFrame4 = PERIOD_M1;

// Period to hold the position open:
input int PeriodToHold1 = 1;
input int PeriodToHold2 = 2;
input int PeriodToHold3 = 3;
input int PeriodToHold4 = 4;

// Basic position size:
input double Lots1 = 1;
input double Lots2 = 1;
input double Lots3 = 1;
input double Lots4 = 1;

// Tolerated slippage in points:
input int Slippage1 = 50; 	
input int Slippage2 = 50;
input int Slippage3 = 50;
input int Slippage4 = 50;

// Text strings:
input string OrderComment = "MultiCurrencyExample";

// Main trading objects
CTrade *Trade;
CPositionInfo PositionInfo;

#include "multicurrencyInclude.mqh"

// Global variables
CMultiCurrencyExample TradeObject1, TradeObject2, TradeObject3, TradeObject4;

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
	// Initialize all objects
   if (CurrencyPair1 != "")
      if (!TradeObject1.Init(CurrencyPair1, TimeFrame1, PeriodToHold1, Lots1, Slippage1))
      {
         TradeObject1.Deinit();
         return(-1);
      }
   if (CurrencyPair2 != "")
      if (!TradeObject2.Init(CurrencyPair2, TimeFrame2, PeriodToHold2, Lots2, Slippage2))
      {
         TradeObject2.Deinit();
         return(-1);
      }
   if (CurrencyPair3 != "")
      if (!TradeObject3.Init(CurrencyPair3, TimeFrame3, PeriodToHold3, Lots3, Slippage3))
      {
         TradeObject3.Deinit();
         return(-1);
      }
   if (CurrencyPair4 != "")
      if (!TradeObject4.Init(CurrencyPair4, TimeFrame4, PeriodToHold4, Lots4, Slippage4))
      {
         TradeObject4.Deinit();
         return(-1);
      }

   return(0);
}

//+------------------------------------------------------------------+
//| Expert Every Tick Function                                       |
//+------------------------------------------------------------------+
void OnTick()
{
	// Is trade allowed?
	if (!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return;
	if (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == false) return;
   
   // Trade objects initialized?
   if ((CurrencyPair1 != "") && (!TradeObject1.Validated())) return;
   if ((CurrencyPair2 != "") && (!TradeObject2.Validated())) return;
   if ((CurrencyPair3 != "") && (!TradeObject3.Validated())) return;
   if ((CurrencyPair4 != "") && (!TradeObject4.Validated())) return;
   
   if (CurrencyPair1 != "") TradeObject1.CheckEntry();
   if (CurrencyPair2 != "") TradeObject2.CheckEntry();
   if (CurrencyPair3 != "") TradeObject3.CheckEntry();
   if (CurrencyPair4 != "") TradeObject4.CheckEntry();
}
//+------------------------------------------------------------------+