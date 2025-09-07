// ---

// **1. Main EA File**

// *   **Path:** `...\MQL5\Experts\ScalpEA.mq5`
// *   **Filename:** `ScalpEA.mq5`

// ```mql5
//+------------------------------------------------------------------+
//|                                                      ScalpEA.mq5 |
//| Scalp EA - AI-Powered Gold Scalping Expert Advisor               |
//| Copyright 2025                                                   |
//| https://www.example.com                                          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.example.com"
#property version   "1.10" // Version updated
#property strict
#property description "AI-Powered Gold Scalping EA for XAUUSD on H1."
//#property icon      "\\Images\\ScalpEA_icon.ico" // Add an icon path (optional)


//--- Include required standard libraries ---
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>
#include <Arrays/ArrayString.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Arrays/ArrayDouble.mqh>
#include <Trade/AccountInfo.mqh> // For Account related info
#include <Trade/SymbolInfo.mqh>  // For symbol information
// Other Objects
CAccountInfo AccountInfo;         // Account Information Object
CTrade Trade;                     // Main trade object (Handle copied to modules)
CPositionInfo PositionInfo;       // To query positions easily
COrderInfo OrderInfo;             // To query orders easily
CSymbolInfo m_symbol;             // Symbol information object
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates()
  {
//--- Initialize symbol if not already done
   if(m_symbol.Name() == "")
      m_symbol.Name(_Symbol);
//--- refresh rates
   if(!m_symbol.RefreshRates())
      return(false);
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }

//--- Include Scalp EA custom modules ---
// Ensure these .mqh files are in MQL5/Include/ScalpEA/
#include "ScalpEA_AIIntegration.mqh"         // Path relative to MQL5/Include/
#include "ScalpEA_StrategyExecution.mqh"
#include "ScalpEA_StopLossManager.mqh"
#include "ScalpEA_MarketDataProcessor.mqh"
#include "ScalpEA_UIManager.mqh"
#include "ScalpEA_BacktestManager.mqh"        // Include for OnTester


//--- Input parameters: AI Configuration ---
input group "AI Configuration"
input string Inp_AIModel = "GPT-4o-Plus";             // AI Model (GPT-4o-Plus/Mini/Free, gpt-4o, o1-Mini, claude-3-haiku-20240307)
input string Inp_APIKey = "";                         // API Key (stored securely - leave blank for simulation/tester)
input int    Inp_MaxTokens = 256;                     // Max response tokens (e.g., 100-500)
input double Inp_Temperature = 0.2;                   // Temperature (0.0-1.0 or 0.0-2.0 depending on model)
input int    Inp_RetryCount = 3;                      // API retry count on failure (1-10)
input int    Inp_APITimeoutMS = 5000;                 // API timeout in milliseconds (e.g., 2000-10000)
input int    Inp_AIValidationIntervalSec = 10;        // How often AI validates SL (seconds, >= 5)

//--- Input parameters: Trading Configuration ---
input group "Trading Configuration"
input double Inp_RiskPercent = 1.0;                   // Risk per trade as % of Equity (e.g., 0.5 - 5.0)
input int    Inp_MaxTrades = 3;                       // Max concurrent trades (e.g., 1-10)
input string Inp_Mode = "Full AI";                    // Operation Mode ("Full AI", "Hybrid", "Manual")
input bool   Inp_UseMarketOrders = true;              // Use market orders (false = pending stop orders)
input int    Inp_PendingOrderDistance = 15;           // Distance for pending orders (points, > 0)
input int    Inp_MaxSpread = 30;                      // Maximum allowed spread (points, 0 to disable)
input ulong  Inp_MagicNumber = 123456;                // EA Magic Number
input bool   Inp_FridayExit = true;                   // Close all positions on Friday EOD
input int    Inp_FridayExitHour = 20;                 // Hour to exit on Friday (server time, 0-23)
input int    Inp_MinSignalIntervalSec = 60;           // Minimum time between new AI entry signals (seconds)

//--- Input parameters: Risk Management ---
input group "Risk Management"
input double Inp_MaxDailyLoss = 5.0;                  // Max daily loss % (0 to disable)
input double Inp_MinProfitToRisk = 1.5;               // Minimum profit-to-risk ratio for TP calc (e.g., 1.0 - 5.0)
input double Inp_InitialSLPips = 50;                  // Initial stop-loss (pips, > 0)
input double Inp_TrailingSLPips = 0;                  // Trailing stop-loss (pips, 0 to disable)
input double Inp_BreakevenPips = 0;                   // Pips in profit to move SL to BreakEven + 1 pip (0 to disable)
input bool   Inp_UseEmergencyShutdown = true;         // Enable emergency shutdown on consecutive errors
input int    Inp_ErrorThreshold = 10;                 // Error threshold for emergency shutdown (e.g., 5-20)

//--- Input parameters: Data Collection ---
input group "Data Collection"
input int    Inp_DataBars = 50;                       // Number of history bars for AI analysis (e.g., 20-200)
input ENUM_TIMEFRAMES Inp_DataTimeframe = PERIOD_H1;  // Timeframe for data collection (fixed to H1 in OnInit check for now)
input bool   Inp_IncludeIndicators = true;            // Include standard indicators in AI data context
input bool   Inp_IncludeOrderBook = false;            // Include order book depth in AI data context (broker dependent)

//--- Global variables ---
// EA State
bool IsInitialized = false;       // Overall initialization flag
bool IsTradingAllowed = true;     // Flag to halt trading (e.g., daily loss hit)
int ErrorCount = 0;               // Consecutive error counter
string EA_Symbol = "";            // Symbol the EA is running on
ENUM_TIMEFRAMES EA_Timeframe;     // Timeframe the EA is running on

// Timers and Limits
datetime LastSignalTime = 0;      // Time of the last AI signal request
datetime LastTickTime = 0;        // To prevent processing same tick multiple times
datetime LastStopCheckTime = 0;   // Last time OnTimer logic ran

// Daily Loss Tracking
double DailyStartEquity = 0;      // Equity at the start of the trading day
datetime StartOfDay = 0;          // Timestamp for the start of the current trading day


// Module Instances (Pointers to allow proper cleanup)
CAIIntegration*       AI = NULL;
CStrategyExecution*   Strategy = NULL;
CStopLossManager*     StopLoss = NULL;
CMarketDataProcessor* DataProcessor = NULL;
CUIManager*           UI = NULL;





//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Initializing ScalpEA v", _Digits, ".", __MQL5BUILD__, " (", __DATE__, ")..."); // Use __MQL5BUILD__
   m_symbol.Name(Symbol()); 
   
   IsInitialized = false;
   IsTradingAllowed = true; // Allow trading by default
   ErrorCount = 0;
   EA_Symbol = _Symbol; // Store symbol EA is attached to
   EA_Timeframe = _Period; // Store timeframe EA is attached to
//--- Initial Validations ---
// Validate symbol (XAUUSD recommended)
   if(StringFind(EA_Symbol, "XAUUSD", 0) < 0)    // Use StringFind for flexibility (e.g., XAUUSDm)
     {
      Print("Warning: Scalp EA is primarily designed for XAUUSD. Current symbol: ", EA_Symbol);
     }
// Validate timeframe (H1 required by design, potentially changeable via Inp_DataTimeframe for AI context)
   if(EA_Timeframe != PERIOD_H1)
     {
      Print("Warning: Scalp EA's core logic expects H1 chart timeframe for optimal OnTick processing. Current timeframe: ", EnumToString(EA_Timeframe));
     }
   if(Inp_DataTimeframe != PERIOD_H1)
     {
      Print("Warning: AI Data Timeframe (Inp_DataTimeframe: ", EnumToString(Inp_DataTimeframe), ") differs from Chart Timeframe.");
     }
// Validate AI Stop-Loss validation interval
   int timerInterval = Inp_AIValidationIntervalSec;
   if(timerInterval < 5)
     {
      Print("Error: AI Validation Interval cannot be less than 5 seconds. Setting timer to 5.");
      timerInterval = 5;
     }
   EventSetTimer(timerInterval);
   Print("AI Stop-Loss validation timer set to ", timerInterval, " seconds.");
// Check Trade permissions
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Print("Error: Automated trading is disabled in Terminal settings (Tools -> Options -> Expert Advisors).");
      return INIT_FAILED;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      Print("Error: Trading is not allowed for this account or expert.");
      return INIT_FAILED;
     }
//--- Initialize Trade Object ---
   Trade.SetExpertMagicNumber(Inp_MagicNumber);
   Trade.SetDeviationInPoints(5);                   // Example slippage tolerance (points)
   Trade.SetTypeFillingBySymbol(EA_Symbol);         // Use default filling type for the symbol
   Trade.LogLevel(LOG_LEVEL_ERRORS);               // Log only trade execution errors
//--- Initialize Modules ---
   Print("Initializing Modules...");
   bool modulesOk = true;
   AI = new CAIIntegration();
   if(AI == NULL || !AI.Initialize(Inp_AIModel, Inp_APIKey, Inp_MaxTokens, Inp_Temperature,
                                   Inp_RetryCount, Inp_APITimeoutMS, Inp_InitialSLPips, Inp_MinProfitToRisk))
     {
      Print("FATAL: Failed to initialize AI Integration module!");
      modulesOk = false;
     }
   if(modulesOk)
     {
      Strategy = new CStrategyExecution();
      if(Strategy == NULL || !Strategy.Initialize(Inp_RiskPercent, Inp_MaxTrades, Inp_UseMarketOrders,
            Inp_PendingOrderDistance, Inp_MaxSpread, Inp_MagicNumber, EA_Symbol))
        {
         Print("FATAL: Failed to initialize Strategy Execution module!");
         modulesOk = false;
        }
     }
   if(modulesOk)
     {
      StopLoss = new CStopLossManager();
      // Pass breakeven pips from input
      if(StopLoss == NULL || !StopLoss.Initialize(Inp_InitialSLPips, Inp_TrailingSLPips, Inp_MinProfitToRisk,
            Inp_BreakevenPips, Inp_MagicNumber, EA_Symbol))
        {
         Print("FATAL: Failed to initialize Stop Loss Manager module!");
         modulesOk = false;
        }
     }
   if(modulesOk)
     {
      DataProcessor = new CMarketDataProcessor();
      if(DataProcessor == NULL || !DataProcessor.Initialize(EA_Symbol, Inp_DataBars, Inp_DataTimeframe,
            Inp_IncludeIndicators, Inp_IncludeOrderBook))
        {
         Print("FATAL: Failed to initialize Market Data Processor module!");
         modulesOk = false;
        }
     }
   if(modulesOk)
     {
      UI = new CUIManager();
      if(UI == NULL || !UI.Initialize())
        {
         Print("FATAL: Failed to initialize UI Manager module!");
         modulesOk = false;
        }
     }
// Cleanup if any module failed
   if(!modulesOk)
     {
      Print("One or more modules failed to initialize. Shutting down EA.");
      CleanupModules(); // Call cleanup function
      return INIT_FAILED;
     }
//--- Final Setup ---
   RefreshRates(); // Get current account info
   DailyStartEquity = AccountInfo.Equity();
   StartOfDay = iTime(_Symbol, PERIOD_D1, 0); // Get timestamp for start of current day
   LastSignalTime = 0; // Reset signal timer
   LastTickTime = 0;   // Reset tick timer
   IsInitialized = true;
   Print("Scalp EA initialized successfully on ", EA_Symbol, "/", EnumToString(EA_Timeframe)); // Use version property
   if(AI != NULL)
      Print("Mode:", Inp_Mode, " | AI Model:", AI.GetActiveModelName(), " | Magic:", Inp_MagicNumber);
   if(UI != NULL)
      UI.LogTradeAction("EA Initialized: "+ EA_Symbol +"/"+ EnumToString(EA_Timeframe), false); // Log to UI panel only
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   string reasonText = GetDeinitReasonText(reason);
   Print("Scalp EA deinitializing... Reason: ", reason, " (", reasonText, ")");
   EventKillTimer();
   CleanupModules(); // Handles UI cleanup as well
   Print("Scalp EA deinitialized.");
// Tester finish actions
   if(MQLInfoInteger(MQL_TESTER))
     {
      Print("Tester run finished. Final statistics available through standard report.");
      // If you wanted custom reporting using BacktestManager, you would need
      // a way to aggregate trade history from the tester environment here.
      // Example:
      // CBacktestResult results = AggregateTesterHistory();
      // results.SaveResults("ScalpEA_TesterRun");
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function (main logic loop)                           |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Basic Checks ---
   if(!IsInitialized || IsStopped())
      return;
   datetime now = TimeCurrent();
   if(now == LastTickTime)
      return; // Avoid processing same tick multiple times
   LastTickTime = now;
   if(!IsTradingAllowed)
     {
      if(UI != NULL)
         UI.UpdateDashboard(Inp_Mode + " (SUSPENDED)", AI.GetActiveModelName(), Strategy.CountOpenTrades(), Inp_MaxTrades, AccountInfo.Profit(), ErrorCount);
      return; // Skip if trading is globally suspended
     }
//--- Context Checks ---
   RefreshRates();
   if(!CheckTradingConditions())
      return; // Check connection, permissions, spread
// Emergency shutdown Check
   if(Inp_UseEmergencyShutdown && ErrorCount >= Inp_ErrorThreshold)
     {
      Print("EMERGENCY SHUTDOWN triggered! Error threshold (", Inp_ErrorThreshold, ") reached. Removing EA.");
      if(UI != NULL)
         UI.LogTradeAction("!!! EMERGENCY SHUTDOWN !!! Error threshold reached.", true);
      IsTradingAllowed = false;
      Strategy.CloseAllTrades("Emergency Shutdown"); // Close trades before removing
      Strategy.CancelAllPendingOrders("Emergency Shutdown");
      ExpertRemove();
      return;
     }
// Friday exit Check
   if(Inp_FridayExit && TimeToExitOnFriday())
     {
      if(Strategy.CountOpenTrades() > 0 || Strategy.CountPendingOrders() > 0)
        {
         Print("Friday exit time (", Inp_FridayExitHour, ":00 server time) reached. Closing/cancelling trades/orders...");
         if(UI != NULL)
            UI.LogTradeAction("Friday exit triggered. Closing positions/orders.", true);
         Strategy.CloseAllTrades("Friday Exit");
         Strategy.CancelAllPendingOrders("Friday Exit");
         // IsTradingAllowed = false; // Decide if suspension is needed until Monday
        }
      // Always return after check if it's exit time, even if no trades, to prevent new ones
      return;
     }
// Daily loss limit Check
   if(CheckDailyLossExceeded())
     {
      if(IsTradingAllowed)
        {
         Print("Daily loss limit of ", Inp_MaxDailyLoss, "% reached. Closing positions and suspending trading for today.");
         if(UI != NULL)
            UI.LogTradeAction("Daily Loss Limit Reached! Trading Suspended.", true);
         Strategy.CloseAllTrades("Daily Loss Limit");
         Strategy.CancelAllPendingOrders("Daily Loss Limit");
         IsTradingAllowed = false;
        }
      return;
     }
   else
      if(!IsTradingAllowed && DailyStartEquity > 0)    // Check if we should re-enable on new day
        {
         MqlDateTime dtCurrent;
         TimeCurrent(dtCurrent);
         datetime currentDayStart = StringToTime(StringFormat("%04d.%02d.%02d", dtCurrent.year, dtCurrent.mon, dtCurrent.day));
         if(currentDayStart > StartOfDay)  // New day check passed in CheckDailyLossExceeded
           {
            Print("New trading day started. Resuming trading.");
            if(UI != NULL)
               UI.LogTradeAction("Trading Resumed.", true);
            IsTradingAllowed = true;
            ErrorCount = 0; // Reset errors on new day? Maybe.
           }
        }
//--- Stop Loss Management (Processing Existing Trades) ---
   StopLoss.ProcessAllStops(); // Handles trailing and breakeven
//--- Market Data Collection ---
   if(DataProcessor == NULL || AI == NULL || Strategy == NULL || StopLoss == NULL || UI == NULL)
     {
      Print("Critical Error: Core module is NULL in OnTick!"); // Should not happen if OnInit succeeded
      ErrorCount = Inp_ErrorThreshold; // Trigger emergency shutdown
      return;
     }
   string marketDataJson = DataProcessor.CollectMarketData();
   if(marketDataJson == "")
     {
      ErrorCount++;
      Print("Error: Failed to collect market data this tick. ErrorCount: ", ErrorCount);
      return;
     }
//--- Process Based on Operation Mode (Potential New Trades) ---
   bool canRequestSignal = (TimeCurrent() - LastSignalTime >= Inp_MinSignalIntervalSec);
   int openTrades = Strategy.CountOpenTrades();
   bool allowNewTrade = (openTrades < Inp_MaxTrades && IsTradingAllowed); // Only allow if under limit AND not suspended
   if(Inp_Mode == "Full AI")
     {
      if(allowNewTrade && canRequestSignal)
         ProcessFullAIMode(marketDataJson);
     }
   else
      if(Inp_Mode == "Hybrid")
        {
         if(canRequestSignal)
            ProcessHybridMode(marketDataJson, allowNewTrade);
        }
      else
         if(Inp_Mode == "Manual")
           {
            if(canRequestSignal)
               ProcessManualMode(marketDataJson);
           }
         else
           {
            ErrorCount++;
            Print("Unknown operation mode in OnTick: ", Inp_Mode);
           }
//--- Update UI ---
   UI.UpdateDashboard(Inp_Mode + (IsTradingAllowed ? "" : " (SUSPENDED)"),
                      AI.GetActiveModelName(),
                      openTrades,
                      Inp_MaxTrades,
                      AccountInfo.Profit(),
                      ErrorCount);
  }

//+------------------------------------------------------------------+
//| Timer function for periodic tasks (AI Stop-Loss validation)      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!IsInitialized || !IsTradingAllowed || AI == NULL || DataProcessor == NULL || StopLoss == NULL || UI == NULL)
      return; // Core checks
   datetime now = TimeCurrent();
   int intervalSec = Inp_AIValidationIntervalSec;
   if(intervalSec < 5)
      intervalSec = 5; // Ensure minimum interval
   if(now - LastStopCheckTime < (intervalSec - 1))
      return; // Add 1s buffer
   LastStopCheckTime = now;
   int totalOpenPositions = Strategy.CountOpenTrades();
   if(totalOpenPositions == 0)
      return; // No positions to check
// Iterate through open positions managed by this EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionInfo.SelectByTicket(ticket))
        {
         if(PositionInfo.Symbol() == EA_Symbol && PositionInfo.Magic() == Inp_MagicNumber)
           {
            string tradeDataJson = DataProcessor.CollectTradeData(ticket);
            if(tradeDataJson == "")
              {
               Print("Warning: Failed collecting data for #", ticket, " in OnTimer.");
               continue;
              }
            string validation = AI.ValidateStopLoss(tradeDataJson); // Handles rate limiting inside
            if(validation == "")
               continue; // Rate limited or failed API call inside
            bool levelModified = false;
            if(validation == "CLOSE")
              {
               Print("AI Validation for #", ticket, ": CLOSE received.");
               if(StopLoss.CloseTrade(ticket, "AI Validation: Close"))
                 {
                  UI.LogTradeAction("AI Validation: Closed #" + (string)ticket, true);
                  UI.RemoveTradeLevels(ticket);
                 }
              }
            else
               if(validation == "ADJUST_UP" || validation == "ADJUST_DOWN")
                 {
                  Print("AI Validation for #", ticket, ": ", validation, " received.");
                  if(StopLoss.AdjustStopLossAI(ticket, validation))
                    {
                     UI.LogTradeAction("AI Validation: Adjusted SL #" + (string)ticket + " ("+validation+")", true);
                     levelModified = true;
                    }
                 } // VALID requires no action here
            // Re-draw levels if modified successfully
            if(levelModified)
              {
               if(PositionInfo.SelectByTicket(ticket))  // Check if still exists and refresh
                 {
                  UI.DrawTradeLevels(ticket, PositionInfo.PriceOpen(), PositionInfo.StopLoss(), PositionInfo.TakeProfit());
                 }
              }
            // Reset error count on successful validation cycle?
            // ErrorCount = 0;
           }
        }
      // Check for Stop Request from terminal to prevent long loops holding up deinit
      if(IsStopped())
         break;
     }
  }

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(UI != NULL)
     {
      UI.ProcessChartEvent(id, lparam, dparam, sparam);
     }
  }

//+------------------------------------------------------------------+
//| Tester function - Called at the end of a test/optimization pass  |
//+------------------------------------------------------------------+
double OnTester()
  {
   double criterion = 0.0;
// Retrieve standard tester statistics
   double netProfit = TesterStatistics(STAT_GROSS_PROFIT) - TesterStatistics(STAT_GROSS_LOSS);
   double maxDDPercent = MathMax(TesterStatistics(STAT_BALANCE_DDREL_PERCENT), TesterStatistics(STAT_EQUITY_DDREL_PERCENT));
   double totalTrades = TesterStatistics(STAT_TRADES);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double winRate = (totalTrades > 0) ? TesterStatistics(STAT_PROFIT_TRADES) / totalTrades * 100.0 : 0.0;
   double recoveryFactor = TesterStatistics(STAT_RECOVERY_FACTOR);
   Print("--- OnTester Results ---");
   PrintFormat("Net Profit: %.2f", netProfit);
   PrintFormat("Total Trades: %.0f", totalTrades);
   PrintFormat("Profit Factor: %.2f", profitFactor);
   PrintFormat("Win Rate: %.2f%%", winRate);
   PrintFormat("Max Drawdown %%: %.2f%%", maxDDPercent);
   PrintFormat("Recovery Factor: %.2f", recoveryFactor);
   Print("-----------------------");
// Example Custom Criterion: Return Profit Factor, but penalize heavily for high drawdown
   if(maxDDPercent > 50.0)    // Example: High penalty above 50% DD
     {
      criterion = profitFactor * 0.1;
     }
   else
      if(maxDDPercent > 25.0)    // Moderate penalty
        {
         criterion = profitFactor * 0.5;
        }
      else
        {
         criterion = profitFactor; // No penalty for low DD
        }
// Or simply return Net Profit / Max DD%
// if(maxDDPercent > 0.1) criterion = netProfit / maxDDPercent;
// else if(netProfit > 0) criterion = netProfit * 100; // High reward for low DD
// Return Profit Factor as default optimization criterion
   criterion = profitFactor;
// Return the calculated criterion for optimization ranking
   return(criterion);
  }


//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+

//--- Cleanup allocated module memory ---
void CleanupModules()
  {
   Print("Cleaning up EA modules...");
// Use if(...) checks before delete for safety
   if(UI != NULL)
     {
      delete UI;
      UI = NULL;
     }
   if(DataProcessor != NULL)
     {
      delete DataProcessor;
      DataProcessor = NULL;
     }
   if(StopLoss != NULL)
     {
      delete StopLoss;
      StopLoss = NULL;
     }
   if(Strategy != NULL)
     {
      delete Strategy;
      Strategy = NULL;
     }
   if(AI != NULL)
     {
      delete AI;
      AI = NULL;
     }
   IsInitialized = false;
   Print("Module cleanup complete.");
  }

//--- Check basic trading conditions ---
bool CheckTradingConditions()
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
   if(Inp_MaxSpread > 0)
     {
      SymbolInfoTick(_Symbol, NULL); // Refresh tick
      if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > Inp_MaxSpread)
         return false;
     }
   return true;
  }

//--- Check for Friday exit time ---
bool TimeToExitOnFriday()
  {
   MqlDateTime dt;
   TimeCurrent(dt);
   return (dt.day_of_week == 5 && dt.hour >= Inp_FridayExitHour); // Use 5 for Friday (0-6, where 5 is Friday)
  }

//--- Check if daily loss limit is exceeded ---
bool CheckDailyLossExceeded()
  {
   if(Inp_MaxDailyLoss <= 0)
      return false;
   MqlDateTime dtCurrent;
   TimeCurrent(dtCurrent);
   datetime currentDayStart = StringToTime(StringFormat("%04d.%02d.%02d", dtCurrent.year, dtCurrent.mon, dtCurrent.day));
   if(currentDayStart > StartOfDay)
     {
      RefreshRates(); // Get current account info
      DailyStartEquity = AccountInfo.Equity();
      StartOfDay = currentDayStart;
      // Print("New Day Started. Daily Start Equity: ", DailyStartEquity); // Only log if needed
      // Re-enable trading automatically here if it was suspended
      if(!IsTradingAllowed)
         IsTradingAllowed = true;
      return false;
     }
   AccountInfo.Refresh();
   double currentEquity = AccountInfo.Equity();
   double lossForTheDay = DailyStartEquity - currentEquity;
   double lossPercent = (DailyStartEquity > 0) ? (lossForTheDay / DailyStartEquity * 100.0) : 0.0;
   return (lossPercent >= Inp_MaxDailyLoss);
  }

//--- Process logic for Full AI mode ---
void ProcessFullAIMode(string marketDataJson)
  {
// Print("Processing Full AI Mode..."); // Optional log
   string signal = AI.GetTradingSignal(marketDataJson);
   LastSignalTime = TimeCurrent();
   if(signal == "")
     {
      ErrorCount++;   // Failed API call
      return;
     }
   if(StringFind(signal, "NO_TRADE") >= 0) { /* Print("Full AI: NO_TRADE signal."); */ return; }
   ErrorCount = 0; // Reset error on successful signal
   string direction;
   double entry, sl, tp;
   if(AI.ParseSignal(signal, direction, entry, sl, tp))
     {
      string logMsg = StringFormat("AI Signal: %s E:%.4f SL:%.4f TP:%.4f", direction, entry, sl, tp);
      Print(logMsg);
      UI.LogTradeAction(logMsg, false);
      ulong ticket = Strategy.ExecuteTrade(direction, entry, sl, tp); // Returns ticket or 0
      if(ticket > 0)
        {
         UI.LogTradeAction("Opened " + direction + " #" + (string)ticket, true);
         UI.DrawSignal(direction, entry);
         UI.DrawTradeLevels(ticket, entry, sl, tp);
        }
      else
        {
         ErrorCount++;
         UI.LogTradeAction("Trade Exec FAILED: " + direction, true);
        }
     }
   else
     {
      ErrorCount++;
      Print("Full AI: Failed parsing signal '", StringSubstr(signal,0,60), "'");
      UI.LogTradeAction("Signal Parse FAILED", true);
     }
  }

//--- Process logic for Hybrid mode ---
void ProcessHybridMode(string marketDataJson, bool allowNewTrade)
  {
// Print("Processing Hybrid Mode..."); // Optional log
   string analysis = AI.GetMarketAnalysis(marketDataJson);
   if(analysis == "")
     {
      ErrorCount++;
      UI.DisplayAIAnalysis("Error: AI analysis failed.");
      return;
     }
   ErrorCount = 0; // Reset error
   UI.DisplayAIAnalysis(analysis);
   if(allowNewTrade)
     {
      string direction;
      double entry, sl, tp;
      if(AI.ParseSignal(analysis, direction, entry, sl, tp))    // Try parsing from analysis
        {
         string logMsg = StringFormat("AI Suggestion: %s E:%.4f SL:%.4f TP:%.4f", direction, entry, sl, tp);
         Print(logMsg);
         UI.LogTradeAction("Suggestion: " + direction, false);
         if(UI.ConfirmTrade(direction, entry, sl, tp))    // Simulated confirmation
           {
            Print("Hybrid: Confirmed. Executing trade...");
            ulong ticket = Strategy.ExecuteTrade(direction, entry, sl, tp);
            if(ticket > 0)
              {
               UI.LogTradeAction("Opened " + direction + " #" + (string)ticket + " (Hybrid)", true);
               UI.DrawSignal(direction, entry);
               UI.DrawTradeLevels(ticket, entry, sl, tp);
              }
            else
              {
               ErrorCount++;
               UI.LogTradeAction("Hybrid Exec FAILED!", true);
              }
           }
         else
           {
            UI.LogTradeAction("Suggestion Ignored.", false);
           }
        }
     }
  }

//--- Process logic for Manual mode ---
void ProcessManualMode(string marketDataJson)
  {
// Print("Processing Manual Mode..."); // Optional log
   string analysis = AI.GetMarketAnalysis(marketDataJson);
   if(analysis == "")
     {
      ErrorCount++;
      UI.DisplayAIAnalysis("Error: AI analysis failed.");
      return;
     }
   ErrorCount = 0; // Reset
   UI.DisplayAIAnalysis(analysis);
   UI.LogTradeAction("Manual: Analysis Updated.", false);
  }

//--- Get text representation of deinitialization reason ---
string GetDeinitReasonText(int reasonCode)
  {
   switch(reasonCode) // Switch requires constants
     {
      // Standard Reasons
      case REASON_PROGRAM :
         return "Program"; // ExpertRemove called
      case REASON_REMOVE :
         return "Remove"; // EA removed from chart
      case REASON_RECOMPILE :
         return "Recompile"; // EA recompiled
      case REASON_CHARTCHANGE :
         return "Chart Change"; // Symbol or timeframe changed
      case REASON_CHARTCLOSE :
         return "Chart Close"; // Chart closed
      case REASON_PARAMETERS :
         return "Parameters"; // Input parameters changed
      case REASON_ACCOUNT :
         return "Account"; // Account changed/properties changed
      case REASON_TEMPLATE :
         return "Template"; // Template applied
      case REASON_INITFAILED :
         return "Init Failed"; // OnInit returned non-zero
      case REASON_CLOSE :
         return "Terminal Close"; // Terminal closed
      // Non-standard but documented / observed reasons (might need includes?)
      case REASON_PROFILE_CHANGE :
         return "Profile Change";
      // case REASON_PROFILE : return "Profile Change (alt)"; // Comment out duplicates
      // case REASON_TIMEFRAME_CHANGE: return "Timeframe Change (alt)";
      // case REASON_SYMBOL_CHANGE : return "Symbol Change (alt)";
      case REASON_LOAD :
         return "Load Chart"; // Loading chart with EA
      case REASON_TIMEOUT :
         return "Timeout"; // Initialization timeout
      case REASON_CONNECT :
         return "Connect"; // Terminal connected to server (not usually deinit reason)
      case REASON_DISCONNECT :
         return "Disconnect"; // Terminal disconnected
      case REASON_TRADE :
         return "Trade Request"; // Before trade request (rarely deinit reason)
      case REASON_USER :
         return "User Request"; // Via external command? (rare)
      default :
         return "Unknown ("+(string)reasonCode+")";
     }
  }
//+------------------------------------------------------------------+
