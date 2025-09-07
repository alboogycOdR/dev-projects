//+------------------------------------------------------------------+
//|                        StrategyConfig.mqh                        |
//|   Shared configuration for SmartGuard EA v2.0                    |
//+------------------------------------------------------------------+
#property strict

//--- Capital Protection
input double InitialDeposit        = 1000.0;
input double MaxDrawdownPercent   = 50.0;
input double InitialLockRatio     = 0.1;

//--- Entry Signal (EMA+RSI)
input int EMAFastPeriod           = 3;
input int EMASlowPeriod           = 7;
input int RSIPeriod               = 5;
input double RSIThreshold         = 45.0;
input ENUM_TIMEFRAMES Timeframe  = PERIOD_M5;
input bool UseEMAFilter           = true;

//--- HalfTrend Filters
input bool UseHalfTrendFilter     = true;
input int HalfTrendAmplitude      = 2;
input int HalfTrendDeviation      = 2;
input int HalfTrendATRPeriod      = 100;
input ENUM_TIMEFRAMES HTF_M5      = PERIOD_M5;
input ENUM_TIMEFRAMES HTF_M30     = PERIOD_M30;
input ENUM_TIMEFRAMES HTF_H1      = PERIOD_H1;

//--- FilterStack Controls
input double MaxAllowedSpread     = 100.0;
input bool UseSessionFilter       = false;
input int SessionStartHour        = 8;
input int SessionEndHour          = 17;
input bool UseVolatilityCheck     = false;
input double MinATR               = 0.0001;

//--- Risk Management
input double RiskPercentPerTrade  = 2.0;
input int ATRPeriod               = 14;
input ENUM_TIMEFRAMES ATRTimeframe = PERIOD_M5;
input double ATRMultiplierSL      = 1.0;

//--- TP/SL Configuration
input double ATRMultipliersTP1    = 1.0;
input double ATRMultipliersTP2    = 2.0;
input double ATRMultipliersTP3    = 3.0;
input double ATRMultiplierTP_T4   = 5.0;   // TP for runner trade (T4)
input bool UseBreakEvenTP_T4      = true;  // If true, SL set to BE for T4

//--- Execution Controls
input int MaxSlippage             = 5;
input int MagicNumber             = 2152025;

//--- Trade Cooldown Settings
input int TradeCooldownSeconds = 300;

//--- Trailing Configs
input double TrailingStartATRMultiplier = 1.5;
input double TrailingGapATRMultiplier   = 1.0;

//--- TP Multipliers
#define TP1_MULT 1.0
#define TP2_MULT 2.0
#define TP3_MULT 3.0
