//+------------------------------------------------------------------+//
//|             Liquidity Trap EA v1.5                               |//
//|                      Copyright 2025, MetaQuote Software Corp.    |//
//|                 Improved and Consolidated by AI Assistant        |//
//|        (Version 1.5 - Configurable Pause/Adaptive, CSV Export)   |//
//+------------------------------------------------------------------+//
#property strict
#property version   "1.50" // Incremented version
#property description "Exploits liquidity traps near swing points. v1.5: Configurable Pause/Adaptive Logic, Enhanced CSV Export, Ranging Filter."

#include <Trade\Trade.mqh>         // Trading class
#include <Arrays\ArrayObj.mqh>     // Dynamic array of objects (for trade history)
#include <Arrays\ArrayDouble.mqh>  // Dynamic array of doubles (for performance calc)
#include <Indicators\Trend.mqh>    // Includes MA, ADX definitions
#include <Math\Stat\Math.mqh>      // Math functions
#include <stdlibErr.mqh>           // For error descriptions and WRONG_VALUE
#include <Custom\String.mqh>       // For string manipulation (parsing hours)

//--- Input Parameters for Liquidity Detection
input group "Liquidity Detection"
input int    SwingLookback = 20;       // Lookback period for swing points
input double WickRatio = 0.5;       // Wick-to-body ratio for trap detection candle
input double BodyRatio = 0.3;       // Minimum body size ratio relative to average bar size

//--- Input Parameters for Risk Management
input group "Risk Management"
input double RiskPercent = 1.0;     // Base Risk per trade (% of account balance)
input int    MaxTrades = 3;            // Maximum number of open trades
input double Multiplier = 0.5;      // Multiplier for stop-loss filter (ATR * Multiplier)
input double RiskReward = 2.0;      // Risk-reward ratio for take-profit
input bool   UseTrailingStop = true;  // Enable trailing stop for winning trades
input double TrailStart = 1.0;      // Trail start (as multiplier of Initial Risk Distance)
input double TrailStep = 0.5;       // Trail step in ATR units

//--- Input Parameters for Indicators
input group "Indicators"
input int    ATRPeriod = 14;           // Period for ATR calculation
input int    MAPeriod = 50;            // Period for trend MA
input int    ADXPeriod = 14;           // Period for ADX trend strength
input int    RSIPeriod = 14;           // Period for RSI
input double ADXThreshold = 25;     // Base Threshold for ADX trend strength
input double RsiOversoldThreshold = 35; // Default Oversold Threshold
input double RsiOverboughtThreshold = 65; // Default Overbought Threshold

//--- Input Parameters for Timeframe Analysis
input group "Multi-Timeframe"
input bool   UseMultiTimeframe = true;// Enable multi-timeframe confirmation
input ENUM_TIMEFRAMES HigherTF = PERIOD_H4; // Higher timeframe for trend confirmation

//--- Input Parameters for Self-Optimization & Pause (v1.5 Revamp)
input group "Adaptive Behavior & Pause"
// v1.5: Optional Pause Logic
input bool   EnableLossPause = true;     // Enable pausing trading after consecutive losses
input int    PauseConsecutiveLosses = 3; // Number of consecutive losses to trigger pause
input int    PauseResetBars = 100;     // Bars after which loss-based pause resets automatically (if not reset by win/10 losses first)
// v1.5: Revised Adaptive Logic (Triggered by Losses, Optional Adjustments)
input bool   AdaptiveRisk = true;     // Enable adaptive risk management based on consecutive losses
input int    AdaptiveConsecutiveLosses = 2; // Consecutive losses to trigger adaptive changes (Risk/Filters)
input bool   EnableAdaptiveADX = true;  // Tighten ADX threshold during adaptive state?
input double AdaptiveADXIncrease = 5.0; // Amount to increase ADX threshold by
input bool   EnableAdaptiveRSI = true;  // Tighten RSI thresholds during adaptive state?
input double AdaptiveRSITightenAmount = 5.0; // Amount to tighten RSI thresholds inwards (e.g., 35->40, 65->60)

//--- Input Parameters for Filtering
input group "Trade Filters"
input bool   AllowTradeOnRange = true; // v1.5: Allow opening trades if market regime is Ranging?
input bool   AvoidHighImpactNews = true; // Avoid trading during high impact news (Requires external data source)
input int    NewsBuffer = 60;          // Buffer time in minutes before/after news
input bool   TradeMonday    = true;     // Allow trading on Monday
input bool   TradeTuesday   = true;     // Allow trading on Tuesday
input bool   TradeWednesday = true;     // Allow trading on Wednesday
input bool   TradeThursday  = true;     // Allow trading on Thursday
input bool   TradeFriday    = true;     // Allow trading on Friday
// input bool   TradeSaturday  = false;    // Usually false
// input bool   TradeSunday    = false;    // Usually false
input bool   EnableHourFilter = false;   // Enable trading only during specific hours
input string AllowedHours = "8,9,10,14,15,16"; // Allowed hours (Broker Time, 24h format). Use comma separation or ranges ("8-11,15-17")

//--- Global Variables
CTrade trade;                       // Trading object
ulong m_magic_number = 123459;      // Magic number for EA trades (incremented version slightly)
int   g_deviation_points = 10;      // Slippage stored globally
ENUM_ORDER_TYPE_FILLING g_filling_type; // Filling type stored globally
int atrHandle;                      // Handle for ATR indicator
int maHandle;                       // Handle for Moving Average indicator
int adxHandle;                      // Handle for ADX indicator
int rsiHandle;                      // Handle for RSI indicator
int maHandleHigher;                 // Handle for higher timeframe MA
int barsSincePauseStart = 0;    // Counter for bars since pause started

// Arrays for indicator values
double atrValues[];
double maValues[];
double adxValues[];
double adxPlusDI[];
double adxMinusDI[];
double rsiValues[];
double maHigherValues[];

// Market variables
double lastATR;                     // Last calculated ATR value
int marketRegime = 0;               // 0 = ranging, 1 = uptrend, -1 = downtrend
int marketVolatility = 0;           // 0 = normal, 1 = high, -1 = low

// Dynamic parameters
double currentRiskPercent;          // Dynamic risk percentage (based on consecutive losses)
double avgBarSize;                  // Average bar size for calculations
// v1.5: Current dynamic thresholds based on adaptive state
double currentAdxThreshold;
double currentRsiOversoldThreshold;
double currentRsiOverboughtThreshold;

// Trade tracking
ulong openTickets[];                // Array to track open trade tickets
int openTradesCount = 0;            // Count of currently open trades

//+------------------------------------------------------------------+//
//| Custom Trade Record class (v1.5: Added fields for CSV)           |//
//+------------------------------------------------------------------+//
class CTradeRecord : public CObject
{
public:
   ulong             ticket;
   datetime          openTime;
   datetime          closeTime;
   ENUM_ORDER_TYPE   orderType;
   double            entryPrice;
   double            sl; // Initial SL
   double            tp; // Initial TP
   double            lots;
   double            profit;
   double            pips;
   // --- v1.5: Fields for enhanced CSV export ---
   int               marketRegimeOnOpen;   // Market regime at the time of trade open
   double            riskPercentOnOpen;    // Risk % used for this trade
   bool              wasTrailingActive;    // Was the trailing stop activated for this trade?
   int               adaptiveStateOnOpen;  // 0=Normal, 1=Reduced Risk 1 (e.g., 50%), 2=Reduced Risk 2 (e.g., 25%)
   double            closePrice;           // Price at which the trade was closed
   bool              slHit;                // Was the trade closed by SL? (Inferred)
   bool              tpHit;                // Was the trade closed by TP? (Inferred)
   double            lastKnownSL;          // Last known SL price (updated by trailing stop)

   // Constructor
   CTradeRecord(const ulong _ticket, const datetime _openTime, const ENUM_ORDER_TYPE _orderType,
                const double _entryPrice, const double _sl, const double _tp, const double _lots,
                const int _marketRegime, const double _riskPercent, const int _adaptiveState) // v1.5: Added params
   {
      ticket = _ticket;
      openTime = _openTime;
      orderType = _orderType;
      entryPrice = _entryPrice;
      sl = _sl; // Store initial SL
      tp = _tp; // Store initial TP
      lots = _lots;
      marketRegimeOnOpen = _marketRegime; // v1.5
      riskPercentOnOpen = _riskPercent;   // v1.5
      adaptiveStateOnOpen = _adaptiveState; // v1.5
      // Initialize other fields
      profit = 0;
      closeTime = 0;
      pips = 0;
      wasTrailingActive = false; // v1.5
      closePrice = 0;            // v1.5
      slHit = false;             // v1.5
      tpHit = false;             // v1.5
      lastKnownSL = _sl;         // v1.5: Initialize with initial SL
   }

   // Default constructor for array usage
   CTradeRecord()
   {
      ticket = 0;
      openTime = 0;
      closeTime = 0;
      orderType = (ENUM_ORDER_TYPE)WRONG_VALUE;
      entryPrice = 0;
      sl = 0;
      tp = 0;
      lots = 0;
      profit = 0;
      pips = 0;
      marketRegimeOnOpen = WRONG_VALUE; // v1.5
      riskPercentOnOpen = 0;            // v1.5
      wasTrailingActive = false;        // v1.5
      adaptiveStateOnOpen = 0;          // v1.5
      closePrice = 0;                   // v1.5
      slHit = false;                    // v1.5
      tpHit = false;                    // v1.5
      lastKnownSL = 0;                  // v1.5
   }

   // Update trade result (v1.5: Added close price)
   void UpdateResult(const datetime _closeTime, const double _profit, const double _pips, const double _closePrice)
   {
      closeTime = _closeTime;
      profit = _profit;
      pips = _pips;
      closePrice = _closePrice; // v1.5
      // Infer SL/TP hit (basic inference)
      InferSLTPHit();
   }

   // v1.5: Update last known SL (e.g., when trailed)
   void UpdateLastKnownSL(double newSL)
   {
       lastKnownSL = newSL;
       wasTrailingActive = true; // Mark trailing as active if SL is updated
   }

   // v1.5: Infer SL/TP hit based on close price and initial/last known levels
   void InferSLTPHit()
   {
       if (closeTime == 0 || closePrice == 0 || (sl == 0 && tp == 0)) return; // Not closed or no levels

       double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
       double spread = SymbolInfoDouble(_Symbol, SYMBOL_SPREAD) * point;
       double tolerance = MathMax(point * 5, spread * 1.5); // Tolerance for comparison

       // Check TP Hit
       if (tp > 0)
       {
           if (orderType == ORDER_TYPE_BUY && MathAbs(closePrice - tp) <= tolerance) tpHit = true;
           if (orderType == ORDER_TYPE_SELL && MathAbs(closePrice - tp) <= tolerance) tpHit = true;
       }

       // Check SL Hit (use lastKnownSL which includes trailed stops)
       if (lastKnownSL > 0 && !tpHit) // Don't mark SL hit if TP was likely hit
       {
           if (orderType == ORDER_TYPE_BUY && MathAbs(closePrice - lastKnownSL) <= tolerance) slHit = true;
           if (orderType == ORDER_TYPE_SELL && MathAbs(closePrice - lastKnownSL) <= tolerance) slHit = true;
       }

       // Refinement: If profit is significantly negative and TP wasn't hit, likely SL
       if (!tpHit && !slHit && profit < 0 && lastKnownSL > 0) {
           if (orderType == ORDER_TYPE_BUY && closePrice <= lastKnownSL + tolerance) slHit = true;
           if (orderType == ORDER_TYPE_SELL && closePrice >= lastKnownSL - tolerance) slHit = true;
       }
       // Refinement: If profit is significantly positive and SL wasn't hit, likely TP
       if (!tpHit && !slHit && profit > 0 && tp > 0) {
           if (orderType == ORDER_TYPE_BUY && closePrice >= tp - tolerance) tpHit = true;
           if (orderType == ORDER_TYPE_SELL && closePrice <= tp + tolerance) tpHit = true;
       }
   }


   // For sorting if needed
   virtual int Compare(const CObject* node, const int mode = 0) const override
   {
      const CTradeRecord* other = (const CTradeRecord*)node;
      if(ticket < other.ticket) return -1;
      if(ticket > other.ticket) return 1;
      return 0;
   }
};

CArrayObj tradeHistory;             // Trade history as an array of objects
int tradeCount = 0;                 // Total closed trades counted for evaluation
int consecutiveLosses = 0;          // Track consecutive losing trades
int consecutiveWins = 0;            // Track consecutive winning trades

// Performance metrics (for reporting only)
double winRate = 0;                 // Win rate
double profitFactor = 0;            // Profit factor
double sharpeRatio = 0;             // Sharpe ratio estimation
double maxDrawdown = 0;             // Maximum drawdown percentage
double averageWin = 0;              // Average winning trade amount
double averageLoss = 0;             // Average losing trade amount
double recoveryFactor = 0;          // Recovery factor (Total Profit / Max Drawdown Amount)

// Time management
datetime nextEvaluationTime = 0;    // Next time to evaluate performance
datetime lastBarTime = 0;           // Last processed bar time
int tickCounter = 0;                // Counter for periodic UI updates

//+------------------------------------------------------------------+//
//| Expert initialization function                                   |//
//+------------------------------------------------------------------+//
int OnInit()
{
   Print("Initializing Enhanced Liquidity Trap EA v1.5 (Configurable Pause/Adaptive, CSV Export)...");

   // Initialize new globals for pause logic
   barsSincePauseStart = 0;

   // Initialize trade object
   trade.SetExpertMagicNumber(m_magic_number);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(g_deviation_points);

   // Store filling type globally
   g_filling_type = trade.RequestTypeFilling();
   Print("Using Filling Type: ", EnumToString(g_filling_type));
   Print("Using Deviation: ", g_deviation_points, " points");

   // Initialize indicator handles
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   maHandle = iMA(_Symbol, PERIOD_CURRENT, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   if (UseMultiTimeframe)
      maHandleHigher = iMA(_Symbol, HigherTF, MAPeriod, 0, MODE_SMA, PRICE_CLOSE);

   // Check indicator handles
   if (atrHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE ||
       adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE ||
       (UseMultiTimeframe && maHandleHigher == INVALID_HANDLE))
   {
      Print("Error: Failed to create one or more indicator handles. Check parameters.");
      return(INIT_FAILED);
   }
   Print("Indicator handles created successfully.");

   // Initialize arrays
   ArrayResize(atrValues, 2);
   ArrayResize(maValues, 2);
   ArrayResize(adxValues, 2);
   ArrayResize(adxPlusDI, 2);
   ArrayResize(adxMinusDI, 2);
   ArrayResize(rsiValues, 2);
   if(UseMultiTimeframe) ArrayResize(maHigherValues, 2);
   ArrayResize(openTickets, 0);

   // Set initial dynamic parameters
   currentRiskPercent = RiskPercent;     // Initialize with base risk
   // v1.5: Initialize dynamic thresholds to base values
   currentAdxThreshold = ADXThreshold;
   currentRsiOversoldThreshold = RsiOversoldThreshold;
   currentRsiOverboughtThreshold = RsiOverboughtThreshold;

   // Set up trade history
   tradeHistory.Clear();
   tradeHistory.FreeMode(false); // Ensure objects are deleted when removed

   // Calculate initial average bar size
   CalculateAverageBarSize();
   if(avgBarSize <= 0)
   {
      Print("Warning: Could not calculate initial average bar size. Check chart data.");
      avgBarSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100; // Arbitrary fallback
      if(avgBarSize <= 0)
      {
         Print("Error: Cannot determine average bar size or fallback. Initialization failed.");
         return(INIT_FAILED);
      }
   }

   // Schedule first evaluation
   nextEvaluationTime = TimeCurrent() + 3600; // First evaluation after 1 hour

   // Load open positions managed by this EA instance
   LoadOpenPositions();

   Print("EA Initialized Successfully: Enhanced Liquidity Trap Exploitation Strategy v1.5");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+//
//| Expert deinitialization function                                 |//
//+------------------------------------------------------------------+//
void OnDeinit(const int reason)
{
   Print("Deinitializing EA v1.5. Reason code: ", reason);

   // Release indicator handles
   IndicatorRelease(atrHandle);
   IndicatorRelease(maHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(rsiHandle);
   if (UseMultiTimeframe && maHandleHigher != INVALID_HANDLE)
      IndicatorRelease(maHandleHigher);

   // Clean up chart objects
   ObjectsDeleteAll(0, "ELTEA_");

   // v1.5: Export final stats to CSV
   ExportStatsToFile();

   // Clear trade history object array
   tradeHistory.Clear();
   Print("EA Deinitialized.");
}

//+------------------------------------------------------------------+//
//| Expert tick function                                             |//
//+------------------------------------------------------------------+//
void OnTick()
{
   // Update trade tracking on every tick (check for closed positions)
   CheckOpenPositions();

   // Trail stops on open positions if enabled
   if (UseTrailingStop && openTradesCount > 0)
      TrailStops();

   // Visual dashboard update (every 10 ticks to save resources)
   tickCounter++;
   if (tickCounter % 10 == 0)
   {
      UpdateVisualDashboard();
      tickCounter = 0; // Reset counter
   }

   // Process bar open logic
   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE);
   if (currentBarTime != lastBarTime)
   {
      if(OnNewBar())
      {
         lastBarTime = currentBarTime;
      }
      else
      {
         Print("Warning: OnNewBar failed to process. Will retry on next bar.");
      }
   }

   // Periodic evaluation (for reporting purposes mainly now)
   if (TimeCurrent() >= nextEvaluationTime)
   {
      EvaluatePerformance(); // Runs calculations, no parameter adjustment
      nextEvaluationTime = TimeCurrent() + 3600; // Schedule next evaluation in 1 hour
   }
}

//+------------------------------------------------------------------+//
//| Process logic on new bar. Returns true on success.              |//
//+------------------------------------------------------------------+//
bool OnNewBar()
{
   // Check Day/Hour/News filters first
   if (ShouldAvoidTrading() || IsHighImpactNewsTime())
   {
      return true; // Successfully processed (by skipping)
   }

   // Update indicators
   if (!UpdateIndicators())
   {
      Print("OnNewBar: Failed to update indicators.");
      return false; // Indicate failure
   }

   // Check for market anomalies that might warrant pausing
   if (DetectMarketAnomalies())
   {
      Print("Trading paused due to detected market anomalies.");
      return true; // Successfully processed (by pausing)
   }

   // Update market regime/volatility, AND apply revised adaptive risk/thresholds
   AnalyzeMarketConditions(); // Contains revised risk/threshold logic

   // Update average bar size periodically
   CalculateAverageBarSize();
   if(avgBarSize <= 0)
   {
      Print("Warning: Average bar size calculation failed.");
      if(lastATR > 0) avgBarSize = lastATR * 1.5; // Fallback based on ATR
      else return false; // Cannot proceed without bar size context
   }

   // Identify liquidity zones (swing points)
   double swingHigh, swingLow;
   if (!IdentifyLiquidityZones(swingHigh, swingLow))
   {
      Print("OnNewBar: Failed to identify liquidity zones.");
      return false; // Indicate failure
   }

   // Calculate volume profile for enhanced liquidity detection
   double highVolumeLevel, lowVolumeLevel;
   CalculateVolumeProfile(highVolumeLevel, lowVolumeLevel);

   // Adjust liquidity zones based on volume profile (optional refinement)
   if (highVolumeLevel > 0 && MathAbs(swingHigh - highVolumeLevel) < lastATR * 1.5)
      swingHigh = (swingHigh * 0.7 + highVolumeLevel * 0.3);
   if (lowVolumeLevel > 0 && MathAbs(swingLow - lowVolumeLevel) < lastATR * 1.5)
      swingLow = (swingLow * 0.7 + lowVolumeLevel * 0.3);

   // Draw liquidity zones on chart
   DrawLiquidityZones(swingHigh, swingLow);

   // Check for potential false breakouts near the identified zones
   bool falseHighBreakout = IsFalseBreakout(swingHigh, true);
   bool falseLowBreakout = IsFalseBreakout(swingLow, false);
   // if (falseHighBreakout || falseLowBreakout) Print("Potential false breakout detected near liquidity zone."); // Less noisy

   // Detect trap setup and manage trades if conditions allow
   // v1.5: CheckEntryConditions now includes optional pause logic
   if (CheckEntryConditions())
   {
      ManageTrading(swingHigh, swingLow);
   }

   // Generate and log statistics report periodically (to Journal)
   if ( (TimeCurrent() / 3600) != ((TimeCurrent() - (int)PeriodSeconds()) / 3600) )
   {
      string statsReport = GenerateStatsReport();
      Print(statsReport);
   }
   return true; // Successfully processed the new bar
}

//+------------------------------------------------------------------+//
//| Calculate average bar size for the last 50 bars                  |//
//+------------------------------------------------------------------+//
void CalculateAverageBarSize()
{
   MqlRates rates[];
   int count = 50;
   ResetLastError();
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, count, rates);
   if (copied < count * 0.8)
   {
      // PrintFormat("Error: Not enough bars (%d) to calculate average bar size. Error code: %d", copied, GetLastError()); // Less noisy
      return;
   }

   double sum = 0;
   for (int i = 0; i < copied; i++)
   {
      sum += (rates[i].high - rates[i].low);
   }
   avgBarSize = (copied > 0) ? sum / copied : 0;
}

//+------------------------------------------------------------------+//
//| Helper function to check if current hour is allowed              |//
//+------------------------------------------------------------------+//
bool IsHourAllowed(int currentHour, string allowedHoursString)
{
   if(allowedHoursString == "") return true; // If string is empty, allow all

   string parts[];
   int count = StringSplit(allowedHoursString, ',', parts);

   for(int i = 0; i < count; i++)
   {
      string part = parts[i];
      StringTrimLeft(part);
      StringTrimRight(part);
      // Check for range (e.g., "8-11")
      int dashPos = StringFind(part, "-");
      if(dashPos > 0) // Found a dash, potential range
      {
         string startStr = StringSubstr(part, 0, dashPos);
         string endStr = StringSubstr(part, dashPos + 1);
         int startHour = (int)StringToInteger(startStr);
         int endHour = (int)StringToInteger(endStr);

         // Basic validation of range
         if(startHour >= 0 && startHour <= 23 && endHour >= 0 && endHour <= 23 && startHour <= endHour)
         {
            if(currentHour >= startHour && currentHour <= endHour)
            {
               return true; // Hour is within the allowed range
            }
         }
         else
         {
            Print("Warning: Invalid hour range format '", part, "' in AllowedHours input. Ignoring.");
         }
      }
      else // Check for single hour
      {
         int allowedHour = (int)StringToInteger(part);
         if(allowedHour >= 0 && allowedHour <= 23) // Basic validation
         {
             if (currentHour == allowedHour)
             {
                return true; // Hour matches an allowed single hour
             }
         }
         else
         {
             Print("Warning: Invalid single hour format '", part, "' in AllowedHours input. Ignoring.");
         }
      }
   }

   return false; // Hour not found in any allowed parts or ranges
}


//+------------------------------------------------------------------+//
//| Check if trading should be avoided at the current time           |//
//+------------------------------------------------------------------+//
bool ShouldAvoidTrading()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Check Day Filter
   bool dayAllowed = false;
   switch(dt.day_of_week)
   {
      case SUNDAY:    dayAllowed = false; break; // TradeSunday; break;
      case MONDAY:    dayAllowed = TradeMonday; break;
      case TUESDAY:   dayAllowed = TradeTuesday; break;
      case WEDNESDAY: dayAllowed = TradeWednesday; break;
      case THURSDAY:  dayAllowed = TradeThursday; break;
      case FRIDAY:    dayAllowed = TradeFriday; break;
      case SATURDAY:  dayAllowed = false; break; // TradeSaturday; break;
      default:        dayAllowed = false; break;
   }
   if (!dayAllowed)
   {
      return true;
   }

   // Check Hour Filter
   if (EnableHourFilter)
   {
      if (!IsHourAllowed(dt.hour, AllowedHours))
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+//
//| Check for news events around current time (Placeholder)          |//
//+------------------------------------------------------------------+//
bool IsHighImpactNewsTime()
{
   // This function requires an external news feed source or manual input.
   // Returning false allows trading. Implement actual check if data is available.
   if (!AvoidHighImpactNews)
      return false;

   datetime currentTime = TimeCurrent();
   bool newsEventNearby = false;

   // --- Placeholder Logic ---
   // Example: Check against MqlCalendarValue or an external source
   // MqlCalendarValue calendar[];
   // int count = CalendarValueHistory(_Symbol, currentTime - NewsBuffer * 60, currentTime + NewsBuffer * 60, calendar);
   // for(int i=0; i<count; i++) {
   //    if(calendar[i].importance == CALENDAR_IMPORTANCE_HIGH) {
   //       newsEventNearby = true;
   //       break;
   //    }
   // }
   // --- End Placeholder ---

   if (newsEventNearby)
   {
      // Print("Trading avoided: High impact news filter active."); // Optional debug
   }
   return newsEventNearby;
}

//+------------------------------------------------------------------+//
//| Update all indicator values                                      |//
//+------------------------------------------------------------------+//
bool UpdateIndicators()
{
   ResetLastError();
   // Copy ATR values
   if (CopyBuffer(atrHandle, 0, 0, 2, atrValues) < 2) { Print("Error: Failed to copy ATR data (", GetLastError(), ")"); return false; }
   ArraySetAsSeries(atrValues, true);
   lastATR = atrValues[0];
   if(lastATR <= 0) {
      Print("Error: Invalid ATR value calculated (", lastATR, ")");
      if(ArraySize(atrValues) > 1 && atrValues[1] > 0) { lastATR = atrValues[1]; Print("Warning: Using previous ATR value."); }
      else { return false; }
   }

   ResetLastError();
   // Copy MA values
   if (CopyBuffer(maHandle, 0, 0, 2, maValues) < 2) { Print("Error: Failed to copy MA data (", GetLastError(), ")"); return false; }
   ArraySetAsSeries(maValues, true);

   ResetLastError();
   // Copy ADX values
   if (CopyBuffer(adxHandle, 0, 0, 2, adxValues) < 2 || CopyBuffer(adxHandle, 1, 0, 2, adxPlusDI) < 2 || CopyBuffer(adxHandle, 2, 0, 2, adxMinusDI) < 2) { Print("Error: Failed to copy ADX data (", GetLastError(), ")"); return false; }
   ArraySetAsSeries(adxValues, true); ArraySetAsSeries(adxPlusDI, true); ArraySetAsSeries(adxMinusDI, true);

   ResetLastError();
   // Copy RSI values
   if (CopyBuffer(rsiHandle, 0, 0, 2, rsiValues) < 2) { Print("Error: Failed to copy RSI data (", GetLastError(), ")"); return false; }
   ArraySetAsSeries(rsiValues, true);

   // Copy higher timeframe MA values if enabled
   if (UseMultiTimeframe) {
      ResetLastError();
      if (CopyBuffer(maHandleHigher, 0, 0, 2, maHigherValues) < 2) {
         Print("Error: Failed to copy higher timeframe MA data (", GetLastError(), ")");
         if(ArraySize(maValues) > 0) { maHigherValues[0] = maValues[0]; maHigherValues[1] = maValues[1]; Print("Warning: Using current TF MA as fallback for HTF MA."); }
         else { Print("Error: Cannot use fallback HTF MA as current TF MA is also invalid."); return false; }
      }
      ArraySetAsSeries(maHigherValues, true);
   }
   return true;
}

//+------------------------------------------------------------------+//
//| Analyze current market conditions                                |//
//| v1.5: Revised Adaptive Risk/Threshold logic based on inputs      |//
//+------------------------------------------------------------------+//
void AnalyzeMarketConditions()
{
   // Determine market volatility based on ATR relative to previous ATR
   double currentATR = atrValues[0];
   double prevATR = atrValues[1];
   if (prevATR > 0) {
       if (currentATR > prevATR * 1.5) marketVolatility = 1; // High volatility
       else if (currentATR < prevATR * 0.7) marketVolatility = -1; // Low volatility
       else marketVolatility = 0; // Normal volatility
   } else {
       marketVolatility = 0; // Cannot determine change, assume normal
   }

   // --- v1.5: Revised Adaptive Logic ---
   bool isAdaptiveState = (AdaptiveRisk && consecutiveLosses >= AdaptiveConsecutiveLosses);

   // 1. Adjust Risk Percentage
   if (AdaptiveRisk) {
      double baseRisk = RiskPercent;
      // Determine reduction level based on consecutive losses
      if (consecutiveLosses >= PauseConsecutiveLosses && PauseConsecutiveLosses > AdaptiveConsecutiveLosses) { // Use deeper reduction if pause level is higher
         currentRiskPercent = baseRisk * 0.25; // Reduce risk by 75% (Level 2)
         // Print("Adaptive Risk: ", consecutiveLosses, " losses (>= Pause level). Reducing risk to ", DoubleToString(currentRiskPercent, 2), "%.");
      } else if (isAdaptiveState) { // Reached adaptive threshold but not necessarily pause threshold
         currentRiskPercent = baseRisk * 0.50; // Reduce risk by 50% (Level 1)
         // Print("Adaptive Risk: ", consecutiveLosses, " losses (>= Adaptive level). Reducing risk to ", DoubleToString(currentRiskPercent, 2), "%.");
      } else { // Below adaptive threshold
         currentRiskPercent = baseRisk; // Use base risk
      }
      // Ensure risk doesn't go below a minimum sensible level (e.g., 0.1%)
      currentRiskPercent = MathMax(0.1, currentRiskPercent);
   } else {
       currentRiskPercent = RiskPercent; // Use fixed base risk if AdaptiveRisk is off
   }

   // 2. Adjust Indicator Thresholds
   if (isAdaptiveState) {
      // ADX Threshold
      if (EnableAdaptiveADX) {
         currentAdxThreshold = ADXThreshold + AdaptiveADXIncrease;
      } else {
         currentAdxThreshold = ADXThreshold; // Use base if ADX adaptation disabled
      }
      // RSI Thresholds
      if (EnableAdaptiveRSI) {
         currentRsiOversoldThreshold = MathMin(50.0 - AdaptiveRSITightenAmount, RsiOversoldThreshold + AdaptiveRSITightenAmount); // Tighten inwards, cap below 50
         currentRsiOverboughtThreshold = MathMax(50.0 + AdaptiveRSITightenAmount, RsiOverboughtThreshold - AdaptiveRSITightenAmount); // Tighten inwards, cap above 50
         // Ensure they don't cross
         if (currentRsiOversoldThreshold >= currentRsiOverboughtThreshold) {
             currentRsiOversoldThreshold = RsiOversoldThreshold; // Revert if cross
             currentRsiOverboughtThreshold = RsiOverboughtThreshold;
             Print("Warning: Adaptive RSI thresholds crossed, reverting to base values.");
         }
      } else {
         currentRsiOversoldThreshold = RsiOversoldThreshold; // Use base if RSI adaptation disabled
         currentRsiOverboughtThreshold = RsiOverboughtThreshold;
      }
      // Print("Adaptive Filters Activated: ADX Thresh=", currentAdxThreshold, ", RSI Zone=", currentRsiOversoldThreshold, "-", currentRsiOverboughtThreshold); // Optional debug
   } else {
      // Not in adaptive state, use base thresholds
      currentAdxThreshold = ADXThreshold;
      currentRsiOversoldThreshold = RsiOversoldThreshold;
      currentRsiOverboughtThreshold = RsiOverboughtThreshold;
      // Print("Adaptive Filters Deactivated: Using default thresholds."); // Optional debug
   }

   // Determine market regime based on indicators using current thresholds
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double maValue = maValues[0];
   double adxValue = adxValues[0];
   double plusDI = adxPlusDI[0];
   double minusDI = adxMinusDI[0];
   double higherMA = UseMultiTimeframe ? maHigherValues[0] : maValue;

   // Determine trend direction
   marketRegime = 0; // Default to ranging
   if (adxValue > currentAdxThreshold) {
      // Strong trend detected by ADX
      if (plusDI > minusDI && currentPrice > maValue && (!UseMultiTimeframe || currentPrice > higherMA))
         marketRegime = 1; // Uptrend
      else if (minusDI > plusDI && currentPrice < maValue && (!UseMultiTimeframe || currentPrice < higherMA))
         marketRegime = -1; // Downtrend
      // else: Conflicting signals despite high ADX -> treat as ranging
   }
   // else: ADX below threshold -> Ranging or weak trend
}

//+------------------------------------------------------------------+//
//| Check if general entry conditions are met for new trades         |//
//| v1.5: Optional pause logic                                       |//
//+------------------------------------------------------------------+//
bool CheckEntryConditions()
{
   // Reset consecutive loss counter if it reaches 10 (hard reset)
   if (consecutiveLosses >= 10)
   {
       PrintFormat("Hard Reset: Reached %d consecutive losses. Resetting counter.", consecutiveLosses);
       consecutiveLosses = 0;
       barsSincePauseStart = 0;
       // Risk and thresholds will reset on the *next* call to AnalyzeMarketConditions
   }

   // --- v1.5: Handle Optional Consecutive Loss Pause ---
   if (EnableLossPause && consecutiveLosses >= PauseConsecutiveLosses) // Check if pause enabled and triggered
   {
       barsSincePauseStart++; // Increment counter only when paused

       // Check for automatic bar-based reset
       if (PauseResetBars > 0 && barsSincePauseStart >= PauseResetBars)
       {
           PrintFormat("Pause reset after %d bars (automatic safety). Resetting consecutive loss counter.", PauseResetBars);
           consecutiveLosses = 0;
           barsSincePauseStart = 0;
           // Allow trading checks to proceed now that pause is lifted
       }
       else
       {
           // Pause is active and bar limit not reached
           // Print("Entry check failed: Paused due to ", consecutiveLosses, " consecutive losses. Bars waited: ", barsSincePauseStart); // Optional debug
           return false; // Remain paused
       }
   }
   else // Not paused (or pause disabled, or just reset)
   {
       barsSincePauseStart = 0; // Reset counter if not paused
   }

   // --- Proceed with other checks only if not paused (or just unpaused) ---
   // Check for maximum open trades
   if (openTradesCount >= MaxTrades)
   {
      return false;
   }

   // Avoid trading in extremely high volatility relative to average bar size
   if (marketVolatility == 1 && lastATR > avgBarSize * 3.0 && avgBarSize > 0)
   {
       // Print("Entry check failed: Extreme volatility detected (ATR > 3 * AvgBarSize)."); // Optional debug
       return false;
   }

   return true; // All checks passed (or pause was just lifted/disabled)
}

//+------------------------------------------------------------------+//
//| Identify swing high and low as potential liquidity zones         |//
//+------------------------------------------------------------------+//
bool IdentifyLiquidityZones(double &swingHigh, double &swingLow)
{
   MqlRates rates[];
   int lookback = SwingLookback; // Use fixed input value
   int barsToCopy = lookback + 5;
   ResetLastError();
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, barsToCopy, rates);
   if (copied < lookback + 2)
   {
      // PrintFormat("Error: Not enough bars (%d) to identify liquidity zones for lookback %d. Error: %d", copied, lookback, GetLastError()); // Less noisy
      return false;
   }
   ArraySetAsSeries(rates, true);

   int highIndex = -1;
   double highestHigh = 0;
   int lowIndex = -1;
   double lowestLow = DBL_MAX;

   // Simple fractal detection (adjust lookback if needed)
   for (int i = 2; i < MathMin(copied - 2, lookback + 2); i++)
   {
       if (rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high &&
           rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high)
       {
          if (rates[i].high > highestHigh) { highestHigh = rates[i].high; highIndex = i; }
       }
       if (rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low &&
           rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low)
       {
          if (rates[i].low < lowestLow) { lowestLow = rates[i].low; lowIndex = i; }
       }
   }

   // Fallback: Use highest high / lowest low in lookback period if no fractal found
   if (highIndex == -1)
   {
      highestHigh = 0;
      for(int i=1; i<=lookback && i<copied; i++) { if(rates[i].high > highestHigh) highestHigh = rates[i].high; }
      if (highestHigh <= 0) { Print("Error: Could not find highest high in lookback period."); return false; }
      // Print("Warning: No fractal swing high found, using highest high in lookback period."); // Less noisy
   }
   if (lowIndex == -1)
   {
       lowestLow = DBL_MAX;
       for(int i=1; i<=lookback && i<copied; i++) { if(rates[i].low < lowestLow) lowestLow = rates[i].low; }
       if (lowestLow == DBL_MAX) { Print("Error: Could not find lowest low in lookback period."); return false; }
       // Print("Warning: No fractal swing low found, using lowest low in lookback period."); // Less noisy
   }

   if (highestHigh <= 0 || lowestLow == DBL_MAX || lowestLow >= highestHigh)
   {
       Print("Error: Invalid swing high/low levels identified (High=", highestHigh, ", Low=", lowestLow, ")");
       return false;
   }
   swingHigh = highestHigh;
   swingLow = lowestLow;
   return true;
}

//+------------------------------------------------------------------+//
//| Manage trading logic: detect setups and open trades             |//
//| v1.5: Uses dynamic RSI thresholds & optional ranging filter      |//
//+------------------------------------------------------------------+//
void ManageTrading(double swingHigh, double swingLow)
{
   MqlRates rates[];
   ResetLastError();
   if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3) { Print("Error: Failed to copy recent price data for trade management. Error: ", GetLastError()); return; }
   ArraySetAsSeries(rates, true);

   double lastHigh = rates[1].high;
   double lastLow = rates[1].low;
   double lastClose = rates[1].close;
   double lastOpen = rates[1].open;

   double body = MathAbs(lastClose - lastOpen);
   double upperWick = lastHigh - MathMax(lastOpen, lastClose);
   double lowerWick = MathMin(lastOpen, lastClose) - lastLow;
   double barRange = lastHigh - lastLow;

   if (barRange <= 0 || avgBarSize <= 0) { Print("Warning: Invalid bar data or avgBarSize for ManageTrading."); return; }

   bool significantBody = (body > avgBarSize * BodyRatio);
   bool shortSetup = false;
   bool longSetup = false;

   // Ensure RSI value is available
   if(ArraySize(rsiValues) < 2) { Print("Warning: RSI values not available for trade signal check."); return; }
   double rsiSignalBar = rsiValues[1]; // Use RSI of the completed signal bar

   // --- Short Setup Criteria (Bearish Trap) ---
   if (lastHigh > swingHigh && lastClose < swingHigh && upperWick > WickRatio * body && significantBody)
   {
      // Additional confirmations:
      // - Market regime is bearish OR (ranging AND AllowTradeOnRange is true).
      // - Avoid shorting into oversold conditions (using dynamic threshold).
      bool regimeOK = (marketRegime == -1 || (marketRegime == 0 && AllowTradeOnRange));
      bool rsiOK = !(marketRegime == 0 && rsiSignalBar < currentRsiOversoldThreshold); // Check if RSI NOT oversold in range

      if (regimeOK && rsiOK)
      {
         shortSetup = true;
         Print("Short Setup Detected: Bar Time=", TimeToString(rates[1].time));
      }
   }

   // --- Long Setup Criteria (Bullish Trap) ---
   if (lastLow < swingLow && lastClose > swingLow && lowerWick > WickRatio * body && significantBody)
   {
      // Additional confirmations:
      // - Market regime is bullish OR (ranging AND AllowTradeOnRange is true).
      // - Avoid buying into overbought conditions (using dynamic threshold).
      bool regimeOK = (marketRegime == 1 || (marketRegime == 0 && AllowTradeOnRange));
      bool rsiOK = !(marketRegime == 0 && rsiSignalBar > currentRsiOverboughtThreshold); // Check if RSI NOT overbought in range

      if (regimeOK && rsiOK)
      {
         longSetup = true;
         Print("Long Setup Detected: Bar Time=", TimeToString(rates[1].time));
      }
   }

   // Execute trades if setup detected and entry conditions met
   if (shortSetup)
   {
      OpenShortTrade(lastHigh, swingHigh);
   }
   else if (longSetup)
   {
      OpenLongTrade(lastLow, swingLow);
   }
}

//+------------------------------------------------------------------+//
//| Open a short trade                                               |//
//| v1.5: Captures state for CSV export                              |//
//+------------------------------------------------------------------+//
void OpenShortTrade(double signalBarHigh, double swingHigh)
{
   if(lastATR <= 0) { Print("Error: Cannot open short trade, invalid ATR."); return; }
   double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double filter = lastATR * Multiplier;
   double sl = MathMax(signalBarHigh, swingHigh) + filter;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDistPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistPrice = minDistPoints * point;

   if (sl <= entry + minDistPrice) {
      sl = entry + minDistPrice + point;
      if (sl > MathMax(signalBarHigh, swingHigh) + lastATR * 3) { Print("Error: Adjusted SL too far (> 3*ATR buffer), aborting short trade."); return; }
   }

   double riskDistance = sl - entry;
   if (riskDistance <= 0) { Print("Error: Invalid risk distance for short trade (<= 0). SL=", sl, ", Entry=", entry); return; }
   double tp = entry - RiskReward * riskDistance;

   if (tp >= entry - minDistPrice) {
       tp = entry - minDistPrice - point;
       if(tp <= 0) { Print("Error: Adjusted TP is zero or negative, aborting short trade."); return; }
   }

   // Uses currentRiskPercent (dynamically adjusted based on losses)
   double lotSize = CalculateLotSize(entry, sl);
   if (lotSize <= 0) { Print("Error: Calculated lot size is zero or negative for short trade."); return; }

   // v1.5: Determine adaptive state for logging
   int adaptiveState = 0;
   if (AdaptiveRisk && currentRiskPercent < RiskPercent * 0.9) { // Check if risk is reduced
       if (currentRiskPercent < RiskPercent * 0.4) adaptiveState = 2; // Approx 75% reduction
       else adaptiveState = 1; // Approx 50% reduction
   }

   string comment = "ELT Short v1.5";
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request); ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Market order
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = g_deviation_points;
   request.magic = m_magic_number;
   request.comment = comment;
   request.type_filling = g_filling_type;
   request.type_time = ORDER_TIME_GTC;

   if (!OrderSend(request, result)) {
      PrintFormat("Error opening short trade: %d - %s", result.retcode, result.comment);
   } else {
      if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL) {
         ulong position_ticket = result.deal; // Use deal ticket as position ID in MT5
         if(position_ticket == 0) {
             PrintFormat("Warning: Short trade executed (RetCode=%d) but Deal Ticket is 0. Trying Order Ticket %d for position lookup.", result.retcode, result.order);
             // Attempt to find position by order ticket if deal ticket is 0 (less reliable)
             if(PositionSelectByTicket(result.order)) {
                 position_ticket = result.order; // Use order ticket if position found by it
             } else {
                 Print("Error: Cannot reliably track position after short trade execution.");
                 return; // Exit if we can't get a valid ticket
             }
         }

         // Verify position exists with the ticket
         if (PositionSelectByTicket(position_ticket)) {
            int size = ArraySize(openTickets);
            ArrayResize(openTickets, size + 1);
            openTickets[size] = position_ticket;
            openTradesCount++;

            double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN); // Get actual entry from position
            double actualSL = PositionGetDouble(POSITION_SL);
            double actualTP = PositionGetDouble(POSITION_TP);

            // v1.5: Create trade record with captured state
            CTradeRecord* newTrade = new CTradeRecord(position_ticket, (datetime)PositionGetInteger(POSITION_TIME), ORDER_TYPE_SELL,
                                                      actualEntry, actualSL, actualTP, lotSize,
                                                      marketRegime, currentRiskPercent, adaptiveState);
            if(!tradeHistory.Add(newTrade)) {
                Print("Error: Failed to add trade record to history for ticket ", position_ticket);
                delete newTrade; // Clean up if add fails
            }
            PrintFormat("Short Trade Opened: Ticket=%d, Entry=%.*f, SL=%.*f, TP=%.*f, Lots=%.2f, Risk=%.2f%%, AdaptState=%d",
                        position_ticket, _Digits, actualEntry, _Digits, actualSL, _Digits, actualTP, lotSize, currentRiskPercent, adaptiveState);
            consecutiveWins = 0; // Reset win streak on new trade
         } else {
             PrintFormat("Error: Position not found immediately after opening short trade with ticket %d (Deal/Order).", position_ticket);
         }
      } else {
         PrintFormat("Short trade order failed: %d - %s", result.retcode, result.comment);
      }
   }
}

//+------------------------------------------------------------------+//
//| Open a long trade                                                |//
//| v1.5: Captures state for CSV export                              |//
//+------------------------------------------------------------------+//
void OpenLongTrade(double signalBarLow, double swingLow)
{
    if(lastATR <= 0) { Print("Error: Cannot open long trade, invalid ATR."); return; }
    double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double filter = lastATR * Multiplier;
    double sl = MathMin(signalBarLow, swingLow) - filter;

    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double minDistPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistPrice = minDistPoints * point;

    if (sl >= entry - minDistPrice) {
       sl = entry - minDistPrice - point;
       if (sl < MathMin(signalBarLow, swingLow) - lastATR * 3) { Print("Error: Adjusted SL too far (> 3*ATR buffer), aborting long trade."); return; }
       if(sl <= 0) { Print("Error: Adjusted SL is zero or negative, aborting long trade."); return; }
    }

    double riskDistance = entry - sl;
    if (riskDistance <= 0) { Print("Error: Invalid risk distance for long trade (<= 0). SL=", sl, ", Entry=", entry); return; }
    double tp = entry + RiskReward * riskDistance;

    if (tp <= entry + minDistPrice) {
        tp = entry + minDistPrice + point;
    }

    // Uses currentRiskPercent (dynamically adjusted based on losses)
    double lotSize = CalculateLotSize(entry, sl);
    if (lotSize <= 0) { Print("Error: Calculated lot size is zero or negative for long trade."); return; }

    // v1.5: Determine adaptive state for logging
    int adaptiveState = 0;
    if (AdaptiveRisk && currentRiskPercent < RiskPercent * 0.9) { // Check if risk is reduced
        if (currentRiskPercent < RiskPercent * 0.4) adaptiveState = 2; // Approx 75% reduction
        else adaptiveState = 1; // Approx 50% reduction
    }

    string comment = "ELT Long v1.5";
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request); ZeroMemory(result);
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // Market order
    request.sl = NormalizeDouble(sl, _Digits);
    request.tp = NormalizeDouble(tp, _Digits);
    request.deviation = g_deviation_points;
    request.magic = m_magic_number;
    request.comment = comment;
    request.type_filling = g_filling_type;
    request.type_time = ORDER_TIME_GTC;

    if (!OrderSend(request, result)) {
       PrintFormat("Error opening long trade: %d - %s", result.retcode, result.comment);
    } else {
       if (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL) {
          ulong position_ticket = result.deal; // Use deal ticket as position ID in MT5
          if(position_ticket == 0) {
              PrintFormat("Warning: Long trade executed (RetCode=%d) but Deal Ticket is 0. Trying Order Ticket %d for position lookup.", result.retcode, result.order);
              if(PositionSelectByTicket(result.order)) {
                  position_ticket = result.order;
              } else {
                  Print("Error: Cannot reliably track position after long trade execution.");
                  return;
              }
          }

          // Verify position exists with the ticket
          if (PositionSelectByTicket(position_ticket)) {
             int size = ArraySize(openTickets);
             ArrayResize(openTickets, size + 1);
             openTickets[size] = position_ticket;
             openTradesCount++;

             double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
             double actualSL = PositionGetDouble(POSITION_SL);
             double actualTP = PositionGetDouble(POSITION_TP);

             // v1.5: Create trade record with captured state
             CTradeRecord* newTrade = new CTradeRecord(position_ticket, (datetime)PositionGetInteger(POSITION_TIME), ORDER_TYPE_BUY,
                                                       actualEntry, actualSL, actualTP, lotSize,
                                                       marketRegime, currentRiskPercent, adaptiveState);
             if(!tradeHistory.Add(newTrade)) {
                 Print("Error: Failed to add trade record to history for ticket ", position_ticket);
                 delete newTrade;
             }
             PrintFormat("Long Trade Opened: Ticket=%d, Entry=%.*f, SL=%.*f, TP=%.*f, Lots=%.2f, Risk=%.2f%%, AdaptState=%d",
                         position_ticket, _Digits, actualEntry, _Digits, actualSL, _Digits, actualTP, lotSize, currentRiskPercent, adaptiveState);
             consecutiveWins = 0; // Reset win streak on new trade
          } else {
              PrintFormat("Error: Position not found immediately after opening long trade with ticket %d (Deal/Order).", position_ticket);
          }
       } else {
          PrintFormat("Long trade order failed: %d - %s", result.retcode, result.comment);
       }
    }
}

//+------------------------------------------------------------------+//
//| Calculate lot size based on risk                                 |//
//| v1.5: Uses currentRiskPercent set by adaptive logic              |//
//+------------------------------------------------------------------+//
double CalculateLotSize(double entry, double sl)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (balance <= 0) { Print("Error: Cannot calculate lot size, account balance is zero or negative."); return 0; }

   // Use the dynamically adjusted risk percentage (currentRiskPercent)
   double riskAmount = balance * currentRiskPercent / 100.0;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if (riskAmount > freeMargin * 0.5 && freeMargin > 0) {
       // Print("Warning: Calculated risk amount (", riskAmount, ") exceeds 50% of free margin (", freeMargin, "). Reducing risk amount."); // Less noisy
       riskAmount = freeMargin * 0.5;
   }
   if (riskAmount <= 0) { Print("Error: Risk amount is zero or negative after margin check."); return 0; }

   double riskDistancePrice = MathAbs(entry - sl);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if (riskDistancePrice <= point) { Print("Error: Risk distance too small for lot calculation (", riskDistancePrice, ")"); return 0; }

   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if (tickSize <= 0 || contractSize <= 0 || tickValue <= 0) {
       PrintFormat("Error: Invalid symbol properties for lot calculation. TickSize=%.*f, ContractSize=%.2f, TickValue=%.*f", _Digits, tickSize, contractSize, _Digits, tickValue);
       return 0;
   }

   double lossPerLot = 0;
   string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   string symbolProfitCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   string symbolBaseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string symbolMarginCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_MARGIN);

   // Calculate value of 1 tick per lot in account currency
   double tickValueInAccountCurrency = 0;
   if(tickValue > 0) { // Standard calculation if tick value is provided
       if (accountCurrency == symbolProfitCurrency) {
           tickValueInAccountCurrency = tickValue;
       } else {
           double conversionRate = GetConversionRate(symbolProfitCurrency, accountCurrency);
           if (conversionRate <= 0) {
               PrintFormat("Error: Cannot get conversion rate from %s to %s for tick value conversion.", symbolProfitCurrency, accountCurrency);
               return 0;
           }
           tickValueInAccountCurrency = tickValue * conversionRate;
       }
   } else { // Fallback for symbols where tick value might be 0 (e.g., some CFDs/Futures) - Requires careful checking
       Print("Warning: SYMBOL_TRADE_TICK_VALUE is zero. Attempting alternative calculation (may be inaccurate).");
       // This part is complex and depends on the instrument type (Forex, CFD, etc.)
       // For Forex: Value of 1 point = ContractSize * PointSize * QuoteToBaseRate (if needed) * BaseToAccountRate (if needed)
       // For CFDs: Often simpler, e.g., ContractSize * PointSize * QuoteToAccountRate
       // This fallback is highly broker/symbol dependent and often unreliable.
       // A simplified Forex example (assuming Quote currency needs conversion):
       if (accountCurrency == symbolMarginCurrency) { // Often the case for Forex
           lossPerLot = riskDistancePrice * contractSize; // If margin currency = account currency
           // Need conversion if quote currency != account currency
           if(symbolProfitCurrency != accountCurrency) {
                double quoteToAccountRate = GetConversionRate(symbolProfitCurrency, accountCurrency);
                if(quoteToAccountRate > 0) lossPerLot *= quoteToAccountRate;
                else return 0; // Cannot convert
           }
       } else {
           Print("Error: Cannot reliably calculate loss per lot due to zero tick value and complex currency setup.");
           return 0;
       }
   }

   // Calculate loss per lot using tick value if available
   if(tickValueInAccountCurrency > 0 && tickSize > 0) {
       lossPerLot = (riskDistancePrice / tickSize) * tickValueInAccountCurrency;
   } else if (lossPerLot <= 0) { // If fallback calculation also failed or wasn't used
       Print("Error: Could not determine loss per lot.");
       return 0;
   }


   if (lossPerLot <= 0) { Print("Error: Invalid loss per lot calculation (", lossPerLot, "). Check symbol properties and currency conversion."); return 0; }

   double lotSize = riskAmount / lossPerLot;
   return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+//
//| Get conversion rate between two currencies                       |//
//+------------------------------------------------------------------+//
double GetConversionRate(const string currencyFrom, const string currencyTo)
{
   if (currencyFrom == currencyTo) return 1.0;

   string pair1 = currencyFrom + currencyTo;
   string pair2 = currencyTo + currencyFrom;
   double rate = 0;
   bool inverted = false;
   bool selected1 = false;
   bool selected2 = false;

   // Check if pair1 exists and get its price
   if (SymbolInfoInteger(pair1, SYMBOL_EXIST)) {
       if(SymbolSelect(pair1, true)) {
           selected1 = true;
           MqlTick tick;
           if(SymbolInfoTick(pair1, tick)) {
               rate = (tick.ask + tick.bid) / 2.0; // Use midpoint
               if(rate <= 0) rate = tick.last; // Fallback to last if midpoint is bad
               if(rate <= 0) rate = tick.bid; // Fallback to bid
               if(rate <= 0) rate = tick.ask; // Fallback to ask
           }
       } else Print("Warning: Could not select symbol ", pair1, " for conversion rate.");
   }

   // If pair1 not found or rate is zero, check pair2
   if (rate <= 0 && SymbolInfoInteger(pair2, SYMBOL_EXIST)) {
       if(SymbolSelect(pair2, true)) {
           selected2 = true;
           MqlTick tick;
           if(SymbolInfoTick(pair2, tick)) {
               rate = (tick.ask + tick.bid) / 2.0; // Use midpoint
               if(rate <= 0) rate = tick.last;
               if(rate <= 0) rate = tick.bid;
               if(rate <= 0) rate = tick.ask;
               if(rate > 0) inverted = true;
           }
       } else Print("Warning: Could not select symbol ", pair2, " for conversion rate.");
   }

   // Deselect symbols if they were selected
   if(selected1) SymbolSelect(pair1, false);
   if(selected2) SymbolSelect(pair2, false);

   // If still no rate, try via USD as intermediary
   if (rate <= 0 && currencyFrom != "USD" && currencyTo != "USD") {
       // Print("Warning: Trying conversion via USD for ", currencyFrom, " to ", currencyTo); // Less noisy
       double rateFromUSD = GetConversionRate(currencyFrom, "USD");
       double rateUSDTo = GetConversionRate("USD", currencyTo);
       if (rateFromUSD > 0 && rateUSDTo > 0) {
           rate = rateFromUSD * rateUSDTo;
           inverted = false; // Rate is already direct
       }
   }

   if (rate <= 0) { PrintFormat("Error: Could not find conversion rate for %s to %s", currencyFrom, currencyTo); return 0.0; }
   return inverted ? (1.0 / rate) : rate;
}

//+------------------------------------------------------------------+//
//| Normalize lot size according to symbol specifications            |//
//+------------------------------------------------------------------+//
double NormalizeLotSize(double lotSize)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Ensure lot size is within min/max bounds
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   // Adjust to volume step
   if (step > 0) {
      lotSize = MathFloor(lotSize / step + 1e-10) * step; // Add small epsilon for precision issues
      // Determine digits based on step
      int digits = 0;
      string step_str = DoubleToString(step, 8);
      int pos = StringFind(step_str, ".");
      if(pos >= 0) digits = StringLen(step_str) - pos - 1;
      else digits = 0;
      // Remove trailing zeros for normalization digits
      while(digits > 0 && StringSubstr(step_str, StringLen(step_str)-1, 1) == "0") {
          digits--;
          step_str = StringSubstr(step_str, 0, StringLen(step_str)-1);
      }
      lotSize = NormalizeDouble(lotSize, digits);
   } else {
       lotSize = NormalizeDouble(lotSize, 2); // Default to 2 decimal places if step is 0
   }

   // Final check against minLot after normalization
   lotSize = MathMax(minLot, lotSize);
   return lotSize;
}

//+------------------------------------------------------------------+//
//| Apply trailing stops to open positions if criteria met           |//
//| v1.5: Updates lastKnownSL in CTradeRecord                        |//
//+------------------------------------------------------------------+//
void TrailStops()
{
   if (!UseTrailingStop || openTradesCount == 0 || lastATR <= 0) return;

   for (int i = openTradesCount - 1; i >= 0; i--) {
      ulong ticket = openTickets[i];
      if (!PositionSelectByTicket(ticket)) continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Find the corresponding trade record
      CTradeRecord *tradeRec = NULL;
      for(int j=0; j<tradeHistory.Total(); j++) {
          CObject *obj = tradeHistory.At(j);
          if(obj == NULL) continue;
          CTradeRecord *rec = (CTradeRecord*)obj;
          if(rec.ticket == ticket && rec.closeTime == 0) { // Ensure it's the correct open trade
              tradeRec = rec;
              break;
          }
      }

      if(tradeRec == NULL) {
          // Print("Warning: Could not find open trade record for trailing stop, ticket ", ticket); // Less noisy
          continue; // Cannot proceed without the record
      }

      // Use initial SL from the record to calculate risk distance
      double initialRiskDistance = 0;
      if (posType == POSITION_TYPE_BUY) initialRiskDistance = entryPrice - tradeRec.sl;
      else initialRiskDistance = tradeRec.sl - entryPrice;

      if(initialRiskDistance <= 0) {
          // Print("Warning: Invalid initial risk distance for trailing stop, ticket ", ticket); // Less noisy
          continue;
      }

      double profitDistance = 0;
      if (posType == POSITION_TYPE_BUY) profitDistance = currentPrice - entryPrice;
      else profitDistance = entryPrice - currentPrice;

      double trailTriggerDistance = initialRiskDistance * TrailStart;

      // Check if profit exceeds trigger distance
      if (profitDistance >= trailTriggerDistance) {
         double newSL = 0;
         double trailAmount = lastATR * TrailStep;
         if(trailAmount <= 0) continue; // Invalid trail amount

         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double minDistPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minDistPrice = minDistPoints * point;

         // Calculate potential new SL
         if (posType == POSITION_TYPE_BUY) newSL = currentPrice - trailAmount;
         else newSL = currentPrice + trailAmount; // POSITION_TYPE_SELL

         // Normalize the potential new SL
         newSL = NormalizeDouble(newSL, _Digits);

         // Check if new SL is valid and an improvement
         bool isValidSL = false;
         if (posType == POSITION_TYPE_BUY && newSL > currentSL && currentPrice - newSL >= minDistPrice) isValidSL = true;
         if (posType == POSITION_TYPE_SELL && newSL < currentSL && newSL - currentPrice >= minDistPrice) isValidSL = true; // Check distance for sell

         if (isValidSL) {
            // Attempt to modify the position
            if (trade.PositionModify(ticket, newSL, currentTP)) {
               Print("Trailing stop updated for position #", ticket, ": New SL=", NormalizeDouble(newSL, _Digits));
               // v1.5: Update the last known SL in the trade record
               tradeRec.UpdateLastKnownSL(newSL);
            } else {
               PrintFormat("Error modifying trailing stop for #%d: %d - %s", ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+//
//| Check open positions and update tracking                         |//
//+------------------------------------------------------------------+//
void CheckOpenPositions()
{
   bool changed = false;
   for (int i = ArraySize(openTickets) - 1; i >= 0; i--) {
      ulong ticket = openTickets[i];
      if (ticket == 0) continue;

      // Check if position still exists by ticket
      if (!PositionSelectByTicket(ticket)) {
         // Position is closed, process it from history
         ProcessClosedTrade(ticket);
         // Remove from array efficiently
         if (i < ArraySize(openTickets) - 1) {
             openTickets[i] = openTickets[ArraySize(openTickets) - 1]; // Move last element to current spot
         }
         if(ArraySize(openTickets) > 0)
             ArrayResize(openTickets, ArraySize(openTickets) - 1); // Decrease size
         openTradesCount--;
         changed = true;
      }
   }
   // Sanity check
   if(openTradesCount != ArraySize(openTickets)) {
       Print("Warning: Mismatch between openTradesCount (", openTradesCount, ") and openTickets array size (", ArraySize(openTickets), "). Recounting...");
       openTradesCount = ArraySize(openTickets);
   }
   // if(changed) UpdateVisualDashboard(); // Optional immediate update
}

//+------------------------------------------------------------------+//
//| Process closed trade results from history                        |//
//| v1.5: Reset loss counter ONLY on win                             |//
//+------------------------------------------------------------------+//
void ProcessClosedTrade(ulong ticket)
{
   CTradeRecord *tradeRec = NULL;
   int tradeRecIndex = -1;
   // Find the trade record in our history
   for(int i=0; i<tradeHistory.Total(); i++) {
       CObject *obj = tradeHistory.At(i);
       if(obj == NULL) continue;
       CTradeRecord *rec = (CTradeRecord*)obj;
       if(rec.ticket == ticket) {
           // Check if already processed
           if(rec.closeTime > 0) return;
           tradeRec = rec;
           tradeRecIndex = i;
           break;
       }
   }
   if(tradeRec == NULL) {
       Print("Error: Could not find trade record in history for closed ticket ", ticket);
       // Attempt to reconstruct basic info if possible (less ideal)
       // ... logic to query history deals directly ...
       return; // Exit if no record found
   }

   // Select history for the specific position ID (deal ticket in MT5 often matches position ID)
   datetime startTime = tradeRec.openTime - 1; // Start slightly before open
   datetime endTime = TimeCurrent() + 3600; // End well after now
   ResetLastError();
   if (!HistorySelectByPosition(ticket)) {
      Print("Warning: Failed to select history by position ID ", ticket, ". Trying time range. (", GetLastError(), ")");
      if (!HistorySelect(startTime, endTime)) {
          Print("Error: Failed to select history by time range either for ticket ", ticket, " (", GetLastError(), ")");
          return;
      }
   }

   double totalProfit = 0;
   double totalPips = 0;
   datetime closeTime = 0;
   int dealCount = 0;
   double totalClosedVolume = 0;
   double lastClosePrice = 0;

   int deals = HistoryDealsTotal();
   for (int j = 0; j < deals; j++) {
      ulong dealTicket = HistoryDealGetTicket(j);
      // Filter deals related to our position ticket/ID
      if (HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket) {
         totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT); // Includes commission and swap
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         if(dealTime > closeTime) {
             closeTime = dealTime;
             lastClosePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE); // Get price of the last deal
         }

         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         // Calculate pips based on closing deals
         if (dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT) {
             double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
             double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
             totalClosedVolume += dealVolume;
             double pipsForDeal = 0;
             double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
             if (pointSize > 0) {
                 if (tradeRec.orderType == ORDER_TYPE_BUY) pipsForDeal = (closePrice - tradeRec.entryPrice) / pointSize;
                 else if (tradeRec.orderType == ORDER_TYPE_SELL) pipsForDeal = (tradeRec.entryPrice - closePrice) / pointSize;
                 // Weight pips by volume if partial closes occurred
                 if(tradeRec.lots > 0) totalPips += pipsForDeal * (dealVolume / tradeRec.lots);
                 else totalPips += pipsForDeal; // Assume full close if initial lots unknown
             }
         }
         dealCount++;
      }
   }

   if (dealCount == 0) {
       Print("Warning: No deals found in history for closed ticket ", ticket);
       // Mark as closed with zero profit? Or leave unprocessed?
       // Let's mark it closed to avoid reprocessing, but log warning.
       tradeRec.UpdateResult(TimeCurrent(), 0, 0, 0); // Mark processed with no data
       return;
   }

   // Update the trade record with final results
   tradeRec.UpdateResult(closeTime, totalProfit, totalPips, lastClosePrice);
   tradeCount++; // Increment total closed trades counter

   // Update consecutive win/loss count
   if (totalProfit > 0) {
      consecutiveWins++;
      // Reset loss counter and pause timer ONLY on a win
      if (consecutiveLosses > 0) {
        Print("Winning trade closed. Resetting consecutive losses from ", consecutiveLosses);
        consecutiveLosses = 0;
        barsSincePauseStart = 0; // Reset pause bar counter
      }
   } else if (totalProfit < 0) {
      consecutiveWins = 0;
      consecutiveLosses++;
      Print("Losing trade closed. Consecutive losses: ", consecutiveLosses);
      // Pause logic is handled in CheckEntryConditions based on this counter
      // Adaptive logic (risk/thresholds) is handled in AnalyzeMarketConditions
   }
   // else: Break-even trade, don't change counters

   Print("Trade Closed & Processed: Ticket=", ticket, ", Net Profit=", totalProfit, ", Pips=", NormalizeDouble(totalPips,1), ", ClosePrice=", lastClosePrice);
}

//+------------------------------------------------------------------+//
//| Load all current open positions managed by this EA               |//
//+------------------------------------------------------------------+//
void LoadOpenPositions()
{
   openTradesCount = 0;
   ArrayResize(openTickets, 0);
   int totalPositions = PositionsTotal();
   int loadedCount = 0;
   Print("Loading open positions...");
   for (int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
          if(PositionSelectByTicket(ticket)) {
              if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
                 PositionGetInteger(POSITION_MAGIC) == m_magic_number)
              {
                 // Add to open tickets list
                 int size = ArraySize(openTickets);
                 ArrayResize(openTickets, size + 1);
                 openTickets[size] = ticket;
                 openTradesCount++;
                 loadedCount++;

                 // Check if already in history (e.g., from previous run)
                 bool exists = false;
                 for (int j = 0; j < tradeHistory.Total(); j++) {
                    CObject* obj = tradeHistory.At(j);
                    if(obj == NULL) continue;
                    CTradeRecord* rec = (CTradeRecord*)obj;
                    if (rec.ticket == ticket) {
                       exists = true;
                       // Ensure it's marked as open if loaded previously as closed
                       if(rec.closeTime != 0) {
                           Print("Correcting state for loaded open position ", ticket);
                           rec.closeTime = 0; rec.profit = 0; rec.pips = 0; rec.closePrice = 0; rec.slHit = false; rec.tpHit = false;
                           // Re-initialize lastKnownSL from current position SL
                           rec.lastKnownSL = PositionGetDouble(POSITION_SL);
                       }
                       break;
                    }
                 }
                 // If not in history, create a new record
                 if (!exists) {
                    double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                    double sl = PositionGetDouble(POSITION_SL);
                    double tp = PositionGetDouble(POSITION_TP);
                    double lots = PositionGetDouble(POSITION_VOLUME);
                    datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                    ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                    // Cannot know initial market regime, risk%, adaptive state accurately
                    // Use current values as placeholders or defaults
                    int adaptiveState = 0; // Assume normal state on load
                    CTradeRecord* newTrade = new CTradeRecord(ticket, openTime, orderType, entryPrice, sl, tp, lots,
                                                              marketRegime, RiskPercent, adaptiveState); // Use defaults
                    newTrade.lastKnownSL = sl; // Set last known SL to current SL

                    if(!tradeHistory.Add(newTrade)) {
                        Print("Error: Failed to add loaded position ", ticket, " to history.");
                        delete newTrade;
                    } else {
                        Print("Loaded existing open position (new record): Ticket=", ticket);
                    }
                 }
              }
          } else {
              Print("Warning: Could not select position with ticket ", ticket, " during loading.");
          }
      }
   }
   Print("Finished loading. Found ", loadedCount, " open positions managed by this EA. Total tracked: ", openTradesCount);
   if(openTradesCount != ArraySize(openTickets)) {
       Print("Error during loading: Mismatch between openTradesCount (", openTradesCount, ") and openTickets array size (", ArraySize(openTickets), "). Correcting count.");
       openTradesCount = ArraySize(openTickets);
   }
}

//+------------------------------------------------------------------+//
//| Evaluate trading performance (Reporting Only)                    |//
//+------------------------------------------------------------------+//
void EvaluatePerformance()
{
   int closedTradeCount = 0;
   for(int i=0; i<tradeHistory.Total(); i++) {
       CObject *obj = tradeHistory.At(i);
       if(obj != NULL && ((CTradeRecord*)obj).closeTime > 0) closedTradeCount++;
   }
   // Use a smaller EvalPeriod for reporting if fewer trades exist
   int evalPeriodUsed = MathMin(closedTradeCount, 20); // Use fixed 20 for reporting consistency
   if (evalPeriodUsed < 5) return; // Not enough data for meaningful report

   Print("--- Performance Evaluation (Last ", evalPeriodUsed, " Trades) ---");
   if(CalculatePerformanceMetrics(evalPeriodUsed)) { // Pass the number of trades to use
       Print("Win Rate: ", DoubleToString(winRate * 100, 1), "%");
       Print("Profit Factor: ", DoubleToString(profitFactor, 2));
       Print("Avg Win: ", DoubleToString(averageWin, 2));
       Print("Avg Loss: ", DoubleToString(averageLoss, 2));
       Print("Sharpe Ratio (Est): ", DoubleToString(sharpeRatio, 2));
       Print("Max Drawdown (Est): ", DoubleToString(maxDrawdown, 2), "%");
       Print("Recovery Factor (Est): ", DoubleToString(recoveryFactor, 2));
   } else {
       Print("Evaluation failed: Could not calculate performance metrics.");
   }
   Print("------------------------------------------------------");
}

//+------------------------------------------------------------------+//
//| Calculate key performance metrics over the last N trades         |//
//+------------------------------------------------------------------+//
bool CalculatePerformanceMetrics(int tradesToEvaluate)
{
   if (tradesToEvaluate <= 0) return false;

   CArrayObj recentTrades; // Store pointers to avoid copying large objects
   recentTrades.FreeMode(false); // We are storing pointers, don't delete objects when clearing array
   int count = 0;
   // Iterate backwards through history to get the most recent *closed* trades
   for(int i = tradeHistory.Total() - 1; i >= 0 && count < tradesToEvaluate; i--) {
       CObject *obj = tradeHistory.At(i);
       if(obj == NULL) continue;
       CTradeRecord *rec = (CTradeRecord*)obj;
       if(rec.closeTime > 0) { // Only consider closed trades
           if(!recentTrades.Add(rec)) { Print("Error adding trade record pointer to recentTrades array."); return false; }
           count++;
       }
   }

   int numTrades = recentTrades.Total();
   if (numTrades == 0) {
       winRate = 0; profitFactor = 0; averageWin = 0; averageLoss = 0;
       sharpeRatio = 0; maxDrawdown = 0; recoveryFactor = 0;
       recentTrades.Clear(); // Clear the array of pointers
       return false;
   }

   int wins = 0;
   double grossProfit = 0;
   double grossLoss = 0;
   double sumReturns = 0;
   double sumSquaredReturns = 0;
   double peakBalance = 0;
   double maxDrawdownAmount = 0;
   double winSum = 0;
   double lossSum = 0;
   int winCount = 0;
   int lossCount = 0;
   CArrayDouble returnsArray; // For Sharpe Ratio calculation

   // Estimate starting balance for drawdown (simplified: current balance minus recent profits/losses)
   double runningBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   for(int i=0; i<numTrades; i++) {
       CTradeRecord *tradeRec = (CTradeRecord*)recentTrades.At(i); // Get pointer
       if(tradeRec == NULL) continue;
       runningBalance -= tradeRec.profit; // Subtract profit to get balance before this trade
   }
   peakBalance = runningBalance; // Starting balance is the initial peak

   // Loop through recent trades (oldest first for drawdown calculation)
   // Need to iterate recentTrades in reverse order (0 is the most recent, numTrades-1 is the oldest of the recent set)
   for (int i = numTrades - 1; i >= 0; i--) {
      CTradeRecord* tradeRec = (CTradeRecord*)recentTrades.At(i); // Get pointer
      if(tradeRec == NULL) continue;
      double profit = tradeRec.profit;
      if(!returnsArray.Add(profit)) {} // Add return for Sharpe calculation

      runningBalance += profit; // Update balance after this trade
      // Update peak and drawdown
      if (runningBalance > peakBalance) {
          peakBalance = runningBalance;
          // Drawdown amount resets when a new peak is reached relative to the start of this period
          // maxDrawdownAmount = 0; // This is incorrect for overall max drawdown
      }
      // Calculate current drawdown from the period's peak
      double currentDrawdownAmount = peakBalance - runningBalance;
      if (currentDrawdownAmount > maxDrawdownAmount) {
          maxDrawdownAmount = currentDrawdownAmount;
      }


      // Accumulate stats
      if (profit > 0) { wins++; grossProfit += profit; winSum += profit; winCount++; }
      else if (profit < 0) { grossLoss += MathAbs(profit); lossSum += MathAbs(profit); lossCount++; }

      sumReturns += profit;
      sumSquaredReturns += profit * profit;
   }

   // Calculate final metrics
   winRate = (numTrades > 0) ? (double)wins / numTrades : 0;
   profitFactor = (grossLoss > 0) ? grossProfit / grossLoss : (grossProfit > 0 ? 99999.0 : 0.0); // Avoid division by zero
   // Calculate Max Drawdown Percentage relative to the peak balance *during the evaluation period*
   maxDrawdown = (peakBalance > 0 && maxDrawdownAmount > 0) ? (maxDrawdownAmount / peakBalance) * 100.0 : 0.0;
   averageWin = (winCount > 0) ? winSum / winCount : 0;
   averageLoss = (lossCount > 0) ? lossSum / lossCount : 0; // Store as positive value

   // Calculate Sharpe Ratio (simplified, assumes risk-free rate = 0)
   if (numTrades > 1) {
       double avgReturn = sumReturns / numTrades;
       // Calculate variance: Var = E[X^2] - (E[X])^2
       double variance = (sumSquaredReturns / numTrades) - (avgReturn * avgReturn);
       if (variance > 1e-10) { // Check for non-zero variance
           double stdDev = MathSqrt(variance);
           sharpeRatio = (stdDev > 1e-10) ? avgReturn / stdDev : 0.0; // Avoid division by zero/small number
       } else { sharpeRatio = 0.0; } // Zero variance means zero Sharpe
   } else { sharpeRatio = 0.0; } // Cannot calculate Sharpe for 0 or 1 trade

   // Calculate Recovery Factor (Total Profit / Max Drawdown Amount)
   recoveryFactor = (maxDrawdownAmount > 0) ? grossProfit / maxDrawdownAmount : (grossProfit > 0 ? 99999.0 : 0.0);

   recentTrades.Clear(); // Clear the array of pointers
   returnsArray.Clear();
   return true;
}


//+------------------------------------------------------------------+//
//| Generate statistics report string (for Journal)                  |//
//+------------------------------------------------------------------+//
string GenerateStatsReport()
{
   string report = StringFormat("===== ELT EA v1.5 Stats [%s | %s] =====",
                                _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()));
   report += "\nBalance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) +
             " | Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   report += "\nOpen Trades: " + IntegerToString(openTradesCount) + "/" + IntegerToString(MaxTrades);

   string regimeStr = "Ranging";
   if (marketRegime == 1) regimeStr = "Uptrend";
   else if (marketRegime == -1) regimeStr = "Downtrend";
   string volatilityStr = "Normal";
   if (marketVolatility == 1) volatilityStr = "High";
   else if (marketVolatility == -1) volatilityStr = "Low";

   string adxStr = (ArraySize(adxValues) > 0) ? DoubleToString(adxValues[0], 1) : "N/A";
   string rsiStr = (ArraySize(rsiValues) > 0) ? DoubleToString(rsiValues[0], 1) : "N/A";
   string atrStr = (lastATR > 0) ? DoubleToString(lastATR, _Digits) : "N/A";

   report += "\nMarket: " + regimeStr + " | Vol: " + volatilityStr +
             " | ADX: " + adxStr + " (Th: " + DoubleToString(currentAdxThreshold, 1) + ")" +
             " | RSI: " + rsiStr + " (Zone: " + DoubleToString(currentRsiOversoldThreshold, 0) + "-" + DoubleToString(currentRsiOverboughtThreshold, 0) + ")";
   report += "\nATR: " + atrStr;

   // Dynamic parameters & State
   string adaptStateStr = "OFF";
   if(AdaptiveRisk) {
       if(consecutiveLosses >= AdaptiveConsecutiveLosses) adaptStateStr = "ON (L" + IntegerToString(consecutiveLosses) + ")";
       else adaptStateStr = "Ready";
   }
   string pauseStateStr = "OFF";
   if(EnableLossPause) {
       if(consecutiveLosses >= PauseConsecutiveLosses) pauseStateStr = "ON (L" + IntegerToString(consecutiveLosses) + ", Bar " + IntegerToString(barsSincePauseStart)+")";
       else pauseStateStr = "Ready";
   }

   report += "\nRisk: " + DoubleToString(currentRiskPercent, 2) + "%" +
             " | Adapt: " + adaptStateStr +
             " | Pause: " + pauseStateStr;
   report += "\nConsec Losses: " + IntegerToString(consecutiveLosses);


   // Performance metrics (Last EvalPeriod trades)
   int closedTradeCount = 0;
   for(int i=0; i<tradeHistory.Total(); i++) {
       CObject *obj = tradeHistory.At(i);
       if(obj != NULL && ((CTradeRecord*)obj).closeTime > 0) closedTradeCount++;
   }
   int evalPeriodUsed = MathMin(closedTradeCount, 20); // Use fixed 20 for reporting consistency
   if (evalPeriodUsed > 0) {
      report += "\n--- Performance (Last " + IntegerToString(evalPeriodUsed) + " Trades) ---";
      report += "\nWin Rate: " + DoubleToString(winRate * 100, 1) + "%" +
                " | Profit Factor: " + DoubleToString(profitFactor, 2);
      report += "\nSharpe (Est): " + DoubleToString(sharpeRatio, 2) +
                " | Recovery (Est): " + DoubleToString(recoveryFactor, 2);
      report += "\nAvg Win: " + DoubleToString(averageWin, 2) +
                " | Avg Loss: " + DoubleToString(averageLoss, 2);
      report += "\nMax Drawdown: " + DoubleToString(maxDrawdown, 1) + "%";
   } else {
      report += "\n--- Performance: No closed trades in evaluation period yet. ---";
   }
   report += "\n==============================================";
   return report;
}

//+------------------------------------------------------------------+//
//| Draw visual dashboard on chart                                    |//
//+------------------------------------------------------------------+//
void UpdateVisualDashboard()
{
   long chartID = ChartID();
   string prefix = "ELTEA_DASH_";

   // --- Background Panel ---
   string bgName = prefix + "BG";
   if (ObjectFind(chartID, bgName) < 0) {
      ObjectCreate(chartID, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(chartID, bgName, OBJPROP_XDISTANCE, 10); ObjectSetInteger(chartID, bgName, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(chartID, bgName, OBJPROP_XSIZE, 280); ObjectSetInteger(chartID, bgName, OBJPROP_YSIZE, 195); // Increased size slightly
      ObjectSetInteger(chartID, bgName, OBJPROP_COLOR, clrDimGray); ObjectSetInteger(chartID, bgName, OBJPROP_BGCOLOR, C'20,20,20');
      ObjectSetInteger(chartID, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(chartID, bgName, OBJPROP_BACK, true);
      ObjectSetInteger(chartID, bgName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, bgName, OBJPROP_HIDDEN, true);
   }

   // --- Title ---
   string titleName = prefix + "Title";
   string titleText = "ELT EA v1.5 [" + _Symbol + "|" + EnumToString((ENUM_TIMEFRAMES)Period()) + "]";
   if (ObjectFind(chartID, titleName) < 0) { /* Create */ ObjectCreate(chartID, titleName, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, titleName, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, titleName, OBJPROP_YDISTANCE, 40); ObjectSetInteger(chartID, titleName, OBJPROP_COLOR, clrWhite); ObjectSetInteger(chartID, titleName, OBJPROP_FONTSIZE, 10); ObjectSetString(chartID, titleName, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, titleName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, titleName, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, titleName, OBJPROP_TEXT, titleText);

   // --- Market Status Line ---
   string statusName = prefix + "Status";
   string regimeStr = marketRegime == 1 ? "UP" : (marketRegime == -1 ? "DOWN" : "RANGE");
   color regimeColor = marketRegime == 1 ? clrLime : (marketRegime == -1 ? clrRed : clrYellow);
   string volStr = marketVolatility == 1 ? "HIGH" : (marketVolatility == -1 ? "LOW" : "NORM");
   string adxStr = (ArraySize(adxValues) > 0) ? DoubleToString(adxValues[0],0) : "N/A";
   string adxThStr = DoubleToString(currentAdxThreshold, 0);
   string statusText = "Mkt: " + regimeStr + " | Vol: " + volStr + " | ADX: " + adxStr + " ("+adxThStr+")";
   if (ObjectFind(chartID, statusName) < 0) { /* Create */ ObjectCreate(chartID, statusName, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, statusName, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, statusName, OBJPROP_YDISTANCE, 60); ObjectSetInteger(chartID, statusName, OBJPROP_COLOR, clrWhite); ObjectSetInteger(chartID, statusName, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, statusName, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, statusName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, statusName, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, statusName, OBJPROP_TEXT, statusText);
   // ObjectSetInteger(chartID, statusName, OBJPROP_COLOR, regimeColor); // Optional: Color the whole line

   // --- Trade Status Line ---
   string tradeStatusName = prefix + "TradeStatus";
   string riskStr = DoubleToString(currentRiskPercent, 1) + "%";
   string lossStr = IntegerToString(consecutiveLosses);
   string adaptStr = "";
   string pauseStr = "";
   color statusColor = clrWhite;

   if(AdaptiveRisk && consecutiveLosses >= AdaptiveConsecutiveLosses) {
       adaptStr = " Adapt";
       statusColor = clrOrange;
   }
   if(EnableLossPause && consecutiveLosses >= PauseConsecutiveLosses) {
       pauseStr = " PAUSED";
       statusColor = clrRed; // Pause overrides adapt color
   }

   string tradeStatusText = "Trades: " + IntegerToString(openTradesCount) + "/" + IntegerToString(MaxTrades) +
                            " | Risk: " + riskStr +
                            " | ConL: " + lossStr + adaptStr + pauseStr;
   if (ObjectFind(chartID, tradeStatusName) < 0) { /* Create */ ObjectCreate(chartID, tradeStatusName, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, tradeStatusName, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, tradeStatusName, OBJPROP_YDISTANCE, 80); ObjectSetInteger(chartID, tradeStatusName, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, tradeStatusName, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, tradeStatusName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, tradeStatusName, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, tradeStatusName, OBJPROP_TEXT, tradeStatusText);
   ObjectSetInteger(chartID, tradeStatusName, OBJPROP_COLOR, statusColor); // Update color based on state

   // --- Performance Lines ---
   string perf1Name = prefix + "Perf1";
   string perf1Text = "Win%: " + DoubleToString(winRate * 100, 1) +
                      " | PF: " + DoubleToString(profitFactor, 2);
   if (ObjectFind(chartID, perf1Name) < 0) { /* Create */ ObjectCreate(chartID, perf1Name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, perf1Name, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, perf1Name, OBJPROP_YDISTANCE, 100); ObjectSetInteger(chartID, perf1Name, OBJPROP_COLOR, clrLightGray); ObjectSetInteger(chartID, perf1Name, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, perf1Name, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, perf1Name, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, perf1Name, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, perf1Name, OBJPROP_TEXT, perf1Text);

   string perf2Name = prefix + "Perf2";
   string perf2Text = "Avg W/L: " + DoubleToString(averageWin, 1) + "/" + DoubleToString(averageLoss, 1);
   if (ObjectFind(chartID, perf2Name) < 0) { /* Create */ ObjectCreate(chartID, perf2Name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, perf2Name, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, perf2Name, OBJPROP_YDISTANCE, 120); ObjectSetInteger(chartID, perf2Name, OBJPROP_COLOR, clrLightGray); ObjectSetInteger(chartID, perf2Name, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, perf2Name, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, perf2Name, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, perf2Name, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, perf2Name, OBJPROP_TEXT, perf2Text);

   string perf3Name = prefix + "Perf3";
   string perf3Text = "Max DD: " + DoubleToString(maxDrawdown, 1) + "%" +
                      " | Recov: " + DoubleToString(recoveryFactor, 1);
   if (ObjectFind(chartID, perf3Name) < 0) { /* Create */ ObjectCreate(chartID, perf3Name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, perf3Name, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, perf3Name, OBJPROP_YDISTANCE, 140); ObjectSetInteger(chartID, perf3Name, OBJPROP_COLOR, clrLightGray); ObjectSetInteger(chartID, perf3Name, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, perf3Name, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, perf3Name, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, perf3Name, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, perf3Name, OBJPROP_TEXT, perf3Text);

   // --- Last Trade Line ---
   string lastTradeName = prefix + "LastTrade";
   string lastTradeText = "Last Trade: ---";
   color lastTradeColor = clrWhite;
   int totalHistory = tradeHistory.Total();
   if(totalHistory > 0) {
       // Find the last trade record (could be open or closed)
       CObject *obj = tradeHistory.At(totalHistory - 1);
       if(obj != NULL) {
           CTradeRecord *lastTradeRec = (CTradeRecord*)obj;
           string type = (lastTradeRec.orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
           if(lastTradeRec.closeTime > 0) { // Last trade is closed
               lastTradeColor = (lastTradeRec.profit >= 0) ? clrLimeGreen : clrOrangeRed;
               string outcome = "";
               if(lastTradeRec.slHit) outcome = " (SL)";
               else if(lastTradeRec.tpHit) outcome = " (TP)";
               lastTradeText = StringFormat("Last Closed: %s %.2f%s", type, lastTradeRec.profit, outcome);
           } else { // Last trade is still open
               lastTradeText = StringFormat("Last Open: %s @ %.*f", type, _Digits, lastTradeRec.entryPrice);
               lastTradeColor = clrLightBlue;
           }
       }
   }
   if (ObjectFind(chartID, lastTradeName) < 0) { /* Create */ ObjectCreate(chartID, lastTradeName, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, lastTradeName, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, lastTradeName, OBJPROP_YDISTANCE, 160); ObjectSetInteger(chartID, lastTradeName, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, lastTradeName, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, lastTradeName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, lastTradeName, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, lastTradeName, OBJPROP_TEXT, lastTradeText);
   ObjectSetInteger(chartID, lastTradeName, OBJPROP_COLOR, lastTradeColor);

   // --- Filter Status Line (New) ---
   string filterStatusName = prefix + "FilterStatus";
   string dayFilterStr = ""; // Build string of allowed days
   if(TradeMonday) dayFilterStr += "M"; if(TradeTuesday) dayFilterStr += "T"; if(TradeWednesday) dayFilterStr += "W"; if(TradeThursday) dayFilterStr += "T"; if(TradeFriday) dayFilterStr += "F";
   if(dayFilterStr == "") dayFilterStr = "NONE";
   string hourFilterStr = EnableHourFilter ? (" H:"+AllowedHours) : "";
   string rangeFilterStr = AllowTradeOnRange ? "" : " NoRange";
   string filterStatusText = "Filters: D:" + dayFilterStr + hourFilterStr + rangeFilterStr;
   if (ObjectFind(chartID, filterStatusName) < 0) { /* Create */ ObjectCreate(chartID, filterStatusName, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(chartID, filterStatusName, OBJPROP_XDISTANCE, 20); ObjectSetInteger(chartID, filterStatusName, OBJPROP_YDISTANCE, 180); ObjectSetInteger(chartID, filterStatusName, OBJPROP_COLOR, clrGray); ObjectSetInteger(chartID, filterStatusName, OBJPROP_FONTSIZE, 8); ObjectSetString(chartID, filterStatusName, OBJPROP_FONT, "Calibri"); ObjectSetInteger(chartID, filterStatusName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, filterStatusName, OBJPROP_HIDDEN, true); }
   ObjectSetString(chartID, filterStatusName, OBJPROP_TEXT, filterStatusText);


   ChartRedraw(chartID);
}

//+------------------------------------------------------------------+//
//| Draw liquidity zones on chart                                     |//
//+------------------------------------------------------------------+//
void DrawLiquidityZones(double swingHigh, double swingLow)
{
   long chartID = ChartID();
   string prefix = "ELTEA_ZONE_";
   color colorHigh = C'100,0,0,180'; // Semi-transparent Red
   color colorLow = C'0,100,0,180';  // Semi-transparent Green
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double zoneHeight = MathMax(lastATR * 0.1, point * 5);
   if(zoneHeight <= 0) zoneHeight = point * 5;

   string highName = prefix + "HIGH";
   datetime time1 = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_FIRSTDATE);
   datetime time2 = TimeCurrent() + (datetime)PeriodSeconds() * 20; // Extend slightly into future
   double price1_h = swingHigh - zoneHeight;
   double price2_h = swingHigh + zoneHeight;
   if (ObjectFind(chartID, highName) < 0) { /* Create */ ObjectCreate(chartID, highName, OBJ_RECTANGLE, 0, time1, price1_h, time2, price2_h); ObjectSetInteger(chartID, highName, OBJPROP_COLOR, clrRed); ObjectSetInteger(chartID, highName, OBJPROP_STYLE, STYLE_DOT); ObjectSetInteger(chartID, highName, OBJPROP_WIDTH, 1); ObjectSetInteger(chartID, highName, OBJPROP_FILL, true); ObjectSetInteger(chartID, highName, OBJPROP_BACK, true); ObjectSetInteger(chartID, highName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, highName, OBJPROP_HIDDEN, true); }
   ObjectSetInteger(chartID, highName, OBJPROP_TIME, 0, time1); ObjectSetDouble(chartID, highName, OBJPROP_PRICE, 0, price1_h);
   ObjectSetInteger(chartID, highName, OBJPROP_TIME, 1, time2); ObjectSetDouble(chartID, highName, OBJPROP_PRICE, 1, price2_h);
   ObjectSetInteger(chartID, highName, OBJPROP_BGCOLOR, colorHigh);

   string lowName = prefix + "LOW";
   double price1_l = swingLow - zoneHeight;
   double price2_l = swingLow + zoneHeight;
   if (ObjectFind(chartID, lowName) < 0) { /* Create */ ObjectCreate(chartID, lowName, OBJ_RECTANGLE, 0, time1, price1_l, time2, price2_l); ObjectSetInteger(chartID, lowName, OBJPROP_COLOR, clrGreen); ObjectSetInteger(chartID, lowName, OBJPROP_STYLE, STYLE_DOT); ObjectSetInteger(chartID, lowName, OBJPROP_WIDTH, 1); ObjectSetInteger(chartID, lowName, OBJPROP_FILL, true); ObjectSetInteger(chartID, lowName, OBJPROP_BACK, true); ObjectSetInteger(chartID, lowName, OBJPROP_SELECTABLE, false); ObjectSetInteger(chartID, lowName, OBJPROP_HIDDEN, true); }
   ObjectSetInteger(chartID, lowName, OBJPROP_TIME, 0, time1); ObjectSetDouble(chartID, lowName, OBJPROP_PRICE, 0, price1_l);
   ObjectSetInteger(chartID, lowName, OBJPROP_TIME, 1, time2); ObjectSetDouble(chartID, lowName, OBJPROP_PRICE, 1, price2_l);
   ObjectSetInteger(chartID, lowName, OBJPROP_BGCOLOR, colorLow);

   // ChartRedraw handled by dashboard update
}

//+------------------------------------------------------------------+//
//| Detect market anomalies that might indicate unstable conditions   |//
//+------------------------------------------------------------------+//
bool DetectMarketAnomalies()
{
   // Extreme volatility spike
   if (lastATR > avgBarSize * 4.0 && avgBarSize > 0) {
      Print("Anomaly Warning: Extreme volatility spike detected. ATR = ", lastATR, " vs AvgBar = ", avgBarSize);
      return true;
   }
   // Large price gaps
   MqlRates rates[];
   ResetLastError();
   if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) >= 3) {
       ArraySetAsSeries(rates, true);
       double gap1 = MathAbs(rates[0].open - rates[1].close);
       double gap2 = MathAbs(rates[1].open - rates[2].close);
       if (lastATR > 0 && (gap1 > lastATR * 1.5 || gap2 > lastATR * 1.5)) {
          Print("Anomaly Warning: Large price gap detected. Gap1=", gap1, ", Gap2=", gap2, ", ATR=", lastATR);
          return true;
       }
   }
   // Persisting extreme RSI
   if (ArraySize(rsiValues) >= 2) {
       if ((rsiValues[0] > 90 && rsiValues[1] > 85) || (rsiValues[0] < 10 && rsiValues[1] < 15)) {
          Print("Anomaly Warning: Persisting extreme RSI value: ", rsiValues[0]);
          return true;
       }
   }
   return false;
}

//+------------------------------------------------------------------+//
//| Check for potential false breakouts of liquidity zones           |//
//+------------------------------------------------------------------+//
bool IsFalseBreakout(double level, bool isHighLevel)
{
   MqlRates rates[];
   ResetLastError();
   if (CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return false;
   ArraySetAsSeries(rates, true);

   double barHigh = rates[1].high; double barLow = rates[1].low;
   double barClose = rates[1].close; double barOpen = rates[1].open;
   if(lastATR <= 0) return false;

   if (isHighLevel) {
      if (barHigh > level + lastATR * 0.1 && barClose < level) {
         double bodySize = MathAbs(barOpen - barClose);
         double upperWick = barHigh - MathMax(barOpen, barClose);
         if (bodySize > 0 && upperWick > bodySize * 1.5) return true;
      }
   } else { // Low level
      if (barLow < level - lastATR * 0.1 && barClose > level) {
         double bodySize = MathAbs(barOpen - barClose);
         double lowerWick = MathMin(barOpen, barClose) - barLow;
         if (bodySize > 0 && lowerWick > bodySize * 1.5) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+//
//| Calculate simple volume profile to find high/low volume nodes    |//
//+------------------------------------------------------------------+//
void CalculateVolumeProfile(double &highVolumeLevel, double &lowVolumeLevel)
{
   int barsToAnalyze = 200;
   int priceLevels = 30;
   highVolumeLevel = 0; lowVolumeLevel = 0;

   MqlRates rates[];
   ResetLastError();
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, barsToAnalyze, rates);
   if (copied < barsToAnalyze * 0.8) return;

   double minPrice = 0, maxPrice = 0;
   if(copied > 0) { minPrice = rates[0].low; maxPrice = rates[0].high; } else return;
   for(int i=1; i<copied; i++) {
       if(rates[i].low < minPrice) minPrice = rates[i].low;
       if(rates[i].high > maxPrice) maxPrice = rates[i].high;
   }
   double priceRange = maxPrice - minPrice;
   if (priceRange <= 0 || priceLevels <= 0) return;
   double levelHeight = priceRange / priceLevels;
   if (levelHeight <= 0) return;

   double levelVolumes[]; ArrayResize(levelVolumes, priceLevels); ArrayInitialize(levelVolumes, 0.0);

   for (int i = 0; i < copied; i++) {
      double high = rates[i].high; double low = rates[i].low;
      long volume_long = rates[i].tick_volume; // Use tick volume for profile
      if(volume_long <= 0) continue;
      double volume = (double)volume_long;
      // Distribute volume across price levels touched by the bar
      int startLevel = (int)MathFloor((low - minPrice) / levelHeight);
      int endLevel = (int)MathFloor((high - minPrice) / levelHeight);
      startLevel = MathMax(0, MathMin(priceLevels - 1, startLevel));
      endLevel = MathMax(0, MathMin(priceLevels - 1, endLevel));
      int levelsTouched = endLevel - startLevel + 1;
      if (levelsTouched > 0) {
          double volPerLevel = volume / levelsTouched;
          for (int j = startLevel; j <= endLevel; j++) {
             if(j >= 0 && j < priceLevels) { levelVolumes[j] += volPerLevel; }
          }
      }
   }

   int highVolumeIndex = -1; double maxVol = -1.0;
   int lowVolumeIndex = -1; double minVol = DBL_MAX;
   for(int i=0; i<priceLevels; i++) {
       if(levelVolumes[i] > maxVol) { maxVol = levelVolumes[i]; highVolumeIndex = i; }
       // Find lowest volume *above zero* if possible
       if(levelVolumes[i] > 1e-10 && levelVolumes[i] < minVol) { minVol = levelVolumes[i]; lowVolumeIndex = i; }
   }
   // Fallback for low volume index if all were zero or very low
   if(lowVolumeIndex < 0 && priceLevels > 0) lowVolumeIndex = 0;

   if(highVolumeIndex < 0 || lowVolumeIndex < 0) return;
   // Calculate the center price of the high/low volume levels
   highVolumeLevel = minPrice + (highVolumeIndex + 0.5) * levelHeight;
   lowVolumeLevel = minPrice + (lowVolumeIndex + 0.5) * levelHeight;
}


//+------------------------------------------------------------------+//
//| Export trading statistics to CSV file (v1.5 Enhanced Format)     |//
//+------------------------------------------------------------------+//
void ExportStatsToFile()
{
   // Generate filename: eaname_ver_symbol_tf_timestamp.csv
   string eaName = MQLInfoString(MQL_PROGRAM_NAME);
   string eaVersion = MQLInfoString(MQL_PROGRAM_VERSION);
   string symbol = _Symbol;
   string timeframe = EnumToString((ENUM_TIMEFRAMES)Period());
   string timestamp = TimeToString(TimeCurrent(), "yyyyMMdd_HHmmss");
   string fileName = eaName + "_v" + eaVersion + "_" + symbol + "_" + timeframe + "_" + timestamp + ".csv";

   string commonDataPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH);
   string filePath = commonDataPath + "\\Files\\" + fileName; // Use Common\Files

   Print("Attempting to export trade history to: ", filePath);

   ResetLastError();
   // Use FILE_ANSI for better Excel compatibility with commas/special chars if needed, but UTF-8 (default) is generally better
   int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON);

   if (fileHandle != INVALID_HANDLE) {
      Print("File opened successfully for writing.");
      // Write Header Row (v1.5)
      FileWrite(fileHandle,
                "Timestamp",          // Close time
                "Entry Price",
                "Type",               // Buy/Sell
                "Market Regime",      // Trend/Range at open
                "Risk %",             // Risk % used
                "Close Price",
                "SL Hit",             // 1 if SL hit, 0 otherwise
                "TP Hit",             // 1 if TP hit, 0 otherwise
                "Profit USD",         // Positive profit
                "Loss USD",           // Positive loss
                "Trailing Active",    // 1 if trailing was used, 0 otherwise
                "Adaptive Risk 1",    // 1 if 50% risk reduction active
                "Adaptive Risk 2"     // 1 if 75% risk reduction active
               );

      int closedCount = 0;
      // Write Data Rows
      for (int i = 0; i < tradeHistory.Total(); i++) {
         CObject* obj = tradeHistory.At(i);
         if(obj == NULL) continue;
         CTradeRecord* tradeRec = (CTradeRecord*)obj;

         // Only write closed trades
         if(tradeRec.closeTime > 0) {
             closedCount++;
             string tradeType = (tradeRec.orderType == ORDER_TYPE_BUY) ? "Buy" : "Sell";
             string regimeStr = "Range";
             if(tradeRec.marketRegimeOnOpen == 1) regimeStr = "Up";
             else if(tradeRec.marketRegimeOnOpen == -1) regimeStr = "Down";

             FileWrite(fileHandle,
                       TimeToString(tradeRec.closeTime, "yyyy.MM.dd HH:mm:ss"), // Timestamp
                       DoubleToString(tradeRec.entryPrice, _Digits),           // Entry Price
                       tradeType,                                               // Type
                       regimeStr,                                               // Market Regime
                       DoubleToString(tradeRec.riskPercentOnOpen, 2),           // Risk %
                       DoubleToString(tradeRec.closePrice, _Digits),            // Close Price
                       (string)tradeRec.slHit,                                  // SL Hit (1 or 0)
                       (string)tradeRec.tpHit,                                  // TP Hit (1 or 0)
                       DoubleToString(tradeRec.profit > 0 ? tradeRec.profit : 0.0, 2), // Profit USD
                       DoubleToString(tradeRec.profit < 0 ? MathAbs(tradeRec.profit) : 0.0, 2), // Loss USD
                       (string)tradeRec.wasTrailingActive,                      // Trailing Active (1 or 0)
                       (tradeRec.adaptiveStateOnOpen == 1 ? "1" : "0"),         // Adaptive Risk 1
                       (tradeRec.adaptiveStateOnOpen == 2 ? "1" : "0")          // Adaptive Risk 2
                      );
         }
      }
      FileClose(fileHandle);
      Print("Trade history export complete. ", closedCount, " closed trades written to ", fileName);
   } else {
      PrintFormat("Error: Failed to open file '%s' for stats export (%d). Check permissions for Common\\Files directory.", fileName, GetLastError());
      Print("In Strategy Tester, ensure 'Allow FileWrite' is enabled in EA properties -> Common tab.");
   }
}
//+------------------------------------------------------------------+
