//+------------------------------------------------------------------+
//|                                   GoldDomination_v1.06.mq5       |
//|            Enhanced with Smart Loss Management System            |
//|                                   © 2025, Wayne Ovenstone        |
//+------------------------------------------------------------------+
#property copyright "Wayne Ovenstone"
#property link      "https://www.myfxbook.com/members/WayneO"
#property version   "1.06"
#property description "Gold Domination: Smart Loss Management System"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+

input group "=== BASIC TRADE SETTINGS ==="
input double InpLotSize = 0.02;                    // Base Lot Size
input int    InpMagicNumber = 12000;               // Magic Number
input int    InpBaseStopLoss = 250;                // Base Stop Loss (pips)
input int    InpBaseTakeProfit = 200;              // Base Take Profit (pips)
input int    InpSlippage = 10;                     // Slippage (points)
input int    InpMaxPositions = 1;                  // Maximum Concurrent Positions

input group "=== CORE INDICATORS ==="
input int    InpCCI_Period = 14;                   // CCI Period
input int    InpWilliamsR_Period = 14;             // Williams %R Period
input int    InpADX_Period = 14;                   // ADX Period
input double InpADX_Threshold = 25.0;              // ADX Trending Threshold
input int    InpATR_Period = 14;                   // ATR Period
input double InpATR_Multiplier = 2.0;              // ATR Volatility Filter

input group "=== ENTRY OPTIMIZATION ==="
input bool   InpUseVolumeFilter = true;            // Use Tick Volume Filter
input int    InpVolumeThreshold = 100;             // Minimum Tick Volume
input bool   InpUseFibLevels = true;               // Use Fibonacci Confluence
input bool   InpUsePriceAction = true;             // Use Price Action Patterns
input double InpCCI_Extreme = 100.0;               // CCI Extreme Level (+/-)
input double InpWR_Oversold = -80.0;               // Williams %R Oversold
input double InpWR_Overbought = -20.0;             // Williams %R Overbought

input group "=== INTERMARKET ANALYSIS ==="
input bool   InpUseDXY = true;                     // Use DXY Correlation
input string InpDXY_Symbol = "DXY";                // DXY Symbol
input bool   InpUseVIX = true;                     // Use VIX Fear Index
input string InpVIX_Symbol = "VIX";                // VIX Symbol
input double InpVIX_Low = 15.0;                    // VIX Low Threshold
input double InpVIX_High = 20.0;                   // VIX High Threshold

input group "=== POSITION MANAGEMENT ==="
input bool   InpUseConfidenceSizing = true;        // Confidence-Based Position Sizing
input double InpMinSizeFactor = 0.5;               // Minimum Size Factor (50%)
input double InpMaxSizeFactor = 1.5;               // Maximum Size Factor (150%)
input bool   InpUsePyramiding = true;              // Enable Position Pyramiding
input int    InpMinConfidence = 7;                 // Minimum Confidence Threshold (6-10)

input group "=== PROFIT MANAGEMENT ==="
input bool   InpUseTrailingStop = true;            // Use Trailing Stop
input int    InpTrailingStart = 100;               // Trailing Start (pips)
input int    InpTrailingStep = 30;                 // Trailing Step (pips)
input bool   InpUseVolatilityTP = true;            // Volatility-Adjusted TP
input bool   InpUsePartialClose = true;            // Use Partial Profit Taking
input double InpPartialPercent1 = 0.25;            // First Partial Close %
input int    InpPartialPips1 = 100;                // First Partial Close (pips)

input group "=== HYBRID SCALE-OUT + DYNAMIC SYSTEM ==="
input bool   InpUseHybridSystem = true;            // Enable Hybrid Scale-Out + Dynamic
input int    InpScaleOutTimeHours = 1;             // Hours Before Scale-Out
input int    InpDynamicExitPips = 30;              // Additional Pips for Range Exit
input double InpTrendThreshold = 25.0;             // ADX Threshold for Trend Detection
input double InpHighVolMultiplier = 1.5;           // High Volatility Multiplier
input double InpLowVolMultiplier = 0.8;            // Low Volatility Multiplier

input group "=== RISK MANAGEMENT ==="
input bool   InpUseNewsFilter = true;              // Avoid News Events
input int    InpMaxLosses = 3;                     // Max Consecutive Losses
input double InpRiskReductionFactor = 0.5;         // Risk Reduction After Losses
input bool   InpUseTimeDecay = false;              // Time-Based Profit Taking (Disabled for Hybrid)
input int    InpTimeDecayHours = 8;                // Hours Until Time Decay

//+------------------------------------------------------------------+
//| NEW: SMART LOSS MANAGEMENT SYSTEM                                |
//+------------------------------------------------------------------+
input group "=== SMART LOSS MANAGEMENT ==="
input bool   InpUseSmartLossManagement = true;     // Enable Smart Loss Management System
input int    InpEarlyDetectionHours = 3;           // Initial monitoring period (hours)
input double InpEarlyExitThreshold = 50.0;         // % of SL before early exit (40-60% recommended)
input bool   InpUseMarketStructureValidation = true; // Validate with market structure
input bool   InpUseDynamicSLPlacement = true;      // Dynamic initial SL placement
input double InpMinSLMultiplier = 0.7;             // Minimum SL multiplier (% of base)
input double InpMaxSLMultiplier = 1.2;             // Maximum SL multiplier (% of base)
input int    InpPriceLevelsToTrack = 5;            // Price swing levels to track
input int    InpRSI_Period = 14;                   // RSI period for momentum check
input double InpRSIThreshold = 45.0;               // RSI threshold for momentum shift

input group "=== SESSION MANAGEMENT ==="
input bool   InpUseLondonBreakout = true;          // London Breakout Strategy
input bool   InpUseNYOverlap = true;               // NY Overlap Strategy
input bool   InpUseAsianRange = true;              // Asian Range Strategy
input bool   InpTradeWeekends = false;             // Trade During Weekends

input group "=== ENHANCED LOGGING SYSTEM ==="
input bool   InpDebugMode = true;                  // Enable Debug Logging
input bool   InpSaveDetailedLogs = true;           // Save Detailed Log Files
input bool   InpExportCSV = true;                  // Export Trade Data to CSV
input bool   InpAnalyzePatterns = true;            // Enable Pattern Analysis
input bool   InpCreateSummaryReports = true;       // Create Summary Reports

//+------------------------------------------------------------------+
//| ENHANCED STRUCTURES FOR PATTERN ANALYSIS                        |
//+------------------------------------------------------------------+

enum TRADE_SETUP_TYPE
{
   SETUP_STRONG_TREND,        // ADX > 30, aligned signals
   SETUP_MODERATE_TREND,      // ADX 20-30, mostly aligned
   SETUP_WEAK_TREND,          // ADX < 20, mixed signals
   SETUP_COUNTER_TREND,       // Against HA direction
   SETUP_BREAKOUT,            // High volatility + momentum
   SETUP_RANGE_REVERSAL       // Range-bound + oscillator extremes
};

enum SESSION_TYPE
{
   SESSION_LONDON,
   SESSION_NY,
   SESSION_OVERLAP,
   SESSION_ASIAN,
   SESSION_OFF_HOURS
};

// NEW: Define early exit reasons
enum EARLY_EXIT_REASON
{
   EXIT_MOMENTUM_SHIFT,       // RSI indicates momentum shift
   EXIT_MARKET_STRUCTURE,     // Key level broken
   EXIT_DRAWDOWN_THRESHOLD,   // Reached drawdown threshold
   EXIT_CONFLUENCE            // Multiple factors
};

struct MarketData
{
   double ha_open, ha_close;
   double cci_current;
   double wr_current;
   double adx_current;
   double atr_current, atr_average;
   double price_current;
   double volume_current;
   double dxy_current;
   double vix_current;
   bool   isValid;
   
   // Enhanced analysis
   double volatilityRatio;     // ATR current vs average
   SESSION_TYPE activeSession;
   bool isHighVolatility;
   bool isTrendingMarket;
   
   // NEW: Smart Loss Management data
   double rsi_current;
   double swing_high;
   double swing_low;
   bool momentumShift;
   bool structureBreak;
};

struct SignalData
{
   int bullishScore;
   int bearishScore;
   string description;
   
   // Individual confirmations
   bool haConfirmation;
   bool cciConfirmation;
   bool wrConfirmation;
   bool adxConfirmation;
   bool atrConfirmation;
   bool intermarketConfirmation;
   bool sessionConfirmation;
   bool volumeConfirmation;
   
   // Risk analysis
   string riskFactors;
   TRADE_SETUP_TYPE setupType;
   int oscillatorConflicts;
   bool isCounterTrend;
   double signalStrength;      // 0-1 scale
};

struct TradePattern
{
   ulong ticket;
   datetime openTime;
   datetime closeTime;
   bool isLong;
   int confidence;
   TRADE_SETUP_TYPE setupType;
   SESSION_TYPE session;
   double volatilityRatio;
   string riskFactors;
   double entry;
   double exit;
   double pnl;
   int durationHours;
   string exitReason;
   
   // Market context
   double adx;
   double cci;
   double wr;
   bool hadHA;
   bool hadOscillator;
   bool hadIntermarket;
   bool hadSession;
   
   // Hybrid system tracking
   bool isScaledOut;
   datetime scaleOutTime;
   double scaleOutPrice;
   double remainingLots;
   
   // NEW: Smart Loss Management data
   bool wasEarlyExit;
   EARLY_EXIT_REASON earlyExitReason;
   double maxDrawdown;
   double slDistance;         // Original SL distance
   double capitalSaved;       // Estimated capital saved
};

// NEW: Structure to track price levels for market structure
struct PriceLevel
{
   double price;
   datetime time;
   bool isHigh;
   bool broken;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

// Trading objects
CTrade         tradeManager;
CPositionInfo  positionInfo;
CSymbolInfo    symbolInfo;

// Indicator handles
int handleHA, handleCCI, handleWR, handleADX, handleATR;
int handleDXY, handleVIX;
int handleRSI; // NEW: RSI handle for momentum detection

// System variables
datetime lastBarTime;
datetime lastPositionCheckTime = 0;
bool isInitialized;
int consecutiveLosses;
double currentRiskFactor;
int totalTrades;
int profitableTrades;

// Enhanced tracking
double totalPnL = 0.0;
int winStreak = 0;
int maxWinStreak = 0;
int rejectedSignalsCount = 0;

// Pattern analysis
TradePattern tradeHistory[];
int tradeHistorySize = 0;

// NEW: Smart Loss Management variables
PriceLevel recentLevels[];
int earlyExitCount = 0;
double capitalSaved = 0.0;

// Session management
struct MarketSession {
   int startHour;
   int endHour;
   bool isActive;
};
MarketSession londonSession, nySession, asianSession;

//+------------------------------------------------------------------+
//| ENHANCED LOGGING SYSTEM - GUARANTEED TO WORK                    |
//+------------------------------------------------------------------+

// Global logging variables
string g_MainLogFile, g_TradeLogFile, g_SignalLogFile, g_AnalysisCSV, g_ReportFile;
bool g_LoggingInitialized = false;
int g_LogCounter = 0;

//+------------------------------------------------------------------+
//| Initialize Logging System - WRITES TO MAIN MQL5\FILES FOLDER   |
//+------------------------------------------------------------------+
bool InitializeLoggingSystem()
{
   Print("=== INITIALIZING ENHANCED LOGGING SYSTEM ===");
   
   // Force files to main MQL5\Files folder (not Strategy Tester folder)
   Print("Files will be created in main MQL5\\Files folder for easy access");
   
   // Create timestamp for unique file names
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   string timestamp = StringFormat("%04d%02d%02d_%02d%02d%02d", 
                                  dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec);
   
   // Initialize file names - NO PATH PREFIX (files go to default MQL5\Files)
   g_MainLogFile = StringFormat("GoldDom_%d_MainLog_%s.txt", InpMagicNumber, timestamp);
   g_TradeLogFile = StringFormat("GoldDom_%d_Trades_%s.txt", InpMagicNumber, timestamp);
   g_SignalLogFile = StringFormat("GoldDom_%d_Signals_%s.txt", InpMagicNumber, timestamp);
   g_AnalysisCSV = StringFormat("GoldDom_%d_Analysis_%s.csv", InpMagicNumber, timestamp);
   g_ReportFile = StringFormat("GoldDom_%d_Report_%s.txt", InpMagicNumber, timestamp);
   
   Print("Creating log files in main MQL5\\Files folder:");
   Print("1. Main Log: " + g_MainLogFile);
   Print("2. Trade Log: " + g_TradeLogFile);
   Print("3. Signal Log: " + g_SignalLogFile);
   Print("4. Analysis CSV: " + g_AnalysisCSV);
   Print("5. Report: " + g_ReportFile);
   
   // Test file creation
   if(!CreateLogFiles())
   {
      Print("CRITICAL ERROR: Failed to create log files!");
      return false;
   }
   
   g_LoggingInitialized = true;
   WriteLogHeaders();
   
   Print("=== LOGGING SYSTEM SUCCESSFULLY INITIALIZED ===");
   Print("Files are now accessible in: File -> Open Data Folder -> MQL5 -> Files");
   return true;
}

//+------------------------------------------------------------------+
//| Create All Log Files                                             |
//+------------------------------------------------------------------+
bool CreateLogFiles()
{
   // Test main log file
   int handle = FileOpen(g_MainLogFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create main log file: " + g_MainLogFile);
      Print("Last Error: " + IntegerToString(GetLastError()));
      return false;
   }
   FileWriteString(handle, "=== GOLD DOMINATION MAIN LOG CREATED ===\r\n");
   FileFlush(handle);
   FileClose(handle);
   Print("✓ Main log file created successfully");
   
   // Test trade log file
   handle = FileOpen(g_TradeLogFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create trade log file: " + g_TradeLogFile);
      return false;
   }
   FileWriteString(handle, "=== GOLD DOMINATION TRADE LOG CREATED ===\r\n");
   FileFlush(handle);
   FileClose(handle);
   Print("✓ Trade log file created successfully");
   
   // Test signal log file
   handle = FileOpen(g_SignalLogFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create signal log file: " + g_SignalLogFile);
      return false;
   }
   FileWriteString(handle, "=== GOLD DOMINATION SIGNAL LOG CREATED ===\r\n");
   FileFlush(handle);
   FileClose(handle);
   Print("✓ Signal log file created successfully");
   
   // MODIFIED: Try CSV creation with better error handling
   // Print("DEBUG: Attempting to create CSV: " + g_AnalysisCSV);
   handle = FileOpen(g_AnalysisCSV, FILE_WRITE|FILE_TXT|FILE_ANSI);  // Changed from FILE_CSV to FILE_TXT
   if(handle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("ERROR: Cannot create analysis CSV file: " + g_AnalysisCSV);
      Print("Error code: " + IntegerToString(error));
      
      // Try alternative CSV name
      g_AnalysisCSV = StringSubstr(g_AnalysisCSV, 0, StringLen(g_AnalysisCSV) - 4) + ".txt";  // Change .csv to .txt
      // Print("DEBUG: Trying alternative file: " + g_AnalysisCSV);
      handle = FileOpen(g_AnalysisCSV, FILE_WRITE|FILE_TXT|FILE_ANSI);
      
      if(handle == INVALID_HANDLE)
      {
         Print("ERROR: Cannot create alternative CSV file either");
         // Don't return false - continue without CSV
         Print("WARNING: Continuing without CSV export");
         // Note: CSV export disabled due to file creation error
      }
      else
      {
         FileWriteString(handle, "DateTime,Type,Message,Price,Confidence,Setup,PnL,Balance\r\n");
         FileFlush(handle);
         FileClose(handle);
         Print("✓ Analysis CSV file created successfully (as .txt)");
      }
   }
   else
   {
      FileWriteString(handle, "DateTime,Type,Message,Price,Confidence,Setup,PnL,Balance\r\n");
      FileFlush(handle);
      FileClose(handle);
      Print("✓ Analysis CSV file created successfully");
   }
   
   // Test report file
   handle = FileOpen(g_ReportFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot create report file: " + g_ReportFile);
      return false;
   }
   FileWriteString(handle, "=== GOLD DOMINATION REPORT CREATED ===\r\n");
   FileFlush(handle);
   FileClose(handle);
   Print("✓ Report file created successfully");
   
   return true;
}

//+------------------------------------------------------------------+
//| Write Headers to All Log Files                                   |
//+------------------------------------------------------------------+
void WriteLogHeaders()
{
   string header = StringFormat(
      "===== GOLD DOMINATION v1.06 ENHANCED LOG =====\r\n"
      "Start Time: %s\r\n"
      "Account: %d - %s\r\n"
      "Symbol: %s\r\n"
      "Balance: %.2f\r\n"
      "Magic Number: %d\r\n"
      "Version: Enhanced with Smart Loss Management System\r\n"
      "==========================================\r\n\r\n",
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      (int)AccountInfoInteger(ACCOUNT_LOGIN),
      AccountInfoString(ACCOUNT_COMPANY),
      _Symbol,
      AccountInfoDouble(ACCOUNT_BALANCE),
      InpMagicNumber
   );
   
   // Write to all text files
   WriteToLogFile(g_MainLogFile, header);
   WriteToLogFile(g_TradeLogFile, header);
   WriteToLogFile(g_SignalLogFile, header);
   WriteToLogFile(g_ReportFile, header);
   
   // Initialize global variables for tracking
   GlobalVariableSet("GD_LogCount", 0);
   GlobalVariableSet("GD_TradeCount", 0);
   GlobalVariableSet("GD_WinCount", 0);
   GlobalVariableSet("GD_TotalPnL", 0);
   GlobalVariableSet("GD_StartTime", TimeCurrent());
   
   // NEW: Add Smart Loss Management tracking
   GlobalVariableSet("GD_EarlyExitCount", 0);
   GlobalVariableSet("GD_CapitalSaved", 0);
}

//+------------------------------------------------------------------+
//| Enhanced Logging Function                                        |
//+------------------------------------------------------------------+
void EnhancedLog(string message, string category = "INFO")
{
   g_LogCounter++;
   
   // Create timestamped entry
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logEntry = StringFormat("[%s] [%s] [#%d] %s\r\n", timestamp, category, g_LogCounter, message);
   
   // Method 1: Always print to Journal (visible immediately)
   Print(StringFormat("[%s] %s", category, message));
   
   // Method 2: Write to main log file
   if(g_LoggingInitialized)
   {
      WriteToLogFile(g_MainLogFile, logEntry);
   }
   
   // Method 3: Add to CSV for analysis
   if(g_LoggingInitialized && InpExportCSV)
   {
      AddToAnalysisCSV(timestamp, category, message, 0, 0, "", 0);
   }
   
   // Method 4: Update chart comment
   UpdateChartDisplay(category, message);
   
   // Method 5: Store in global variables for OnTester()
   GlobalVariableSet("GD_LogCount", g_LogCounter);
   if(category == "ERROR" || category == "TRADE")
   {
      GlobalVariableSet("GD_LastLogTime", TimeCurrent());
   }
}

//+------------------------------------------------------------------+
//| Enhanced Trade Logging                                           |
//+------------------------------------------------------------------+
void EnhancedLogTrade(string action, ulong ticket, string details, double pnl = 0, int confidence = 0)
{
   string tradeMessage = StringFormat("%s - Ticket:%d - %s", action, (int)ticket, details);
   if(pnl != 0) tradeMessage += StringFormat(" - PnL:%.2f", pnl);
   if(confidence > 0) tradeMessage += StringFormat(" - Conf:%d/10", confidence);
   
   // Log to main system
   EnhancedLog(tradeMessage, "TRADE");
   
   // Log to dedicated trade file
   if(g_LoggingInitialized)
   {
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string tradeEntry = StringFormat("[%s] %s\r\n", timestamp, tradeMessage);
      WriteToLogFile(g_TradeLogFile, tradeEntry);
   }
   
   // Update CSV with trade data
   if(g_LoggingInitialized && InpExportCSV)
   {
      AddToAnalysisCSV(TimeToString(TimeCurrent()), "TRADE", tradeMessage, 
                      SymbolInfoDouble(_Symbol, SYMBOL_BID), confidence, "", pnl);
   }
   
   // Update statistics
   if(StringFind(action, "EXECUTED") >= 0)
   {
      GlobalVariableSet("GD_TradeCount", GlobalVariableGet("GD_TradeCount") + 1);
   }
   if(pnl > 0)
   {
      GlobalVariableSet("GD_WinCount", GlobalVariableGet("GD_WinCount") + 1);
   }
   GlobalVariableSet("GD_TotalPnL", GlobalVariableGet("GD_TotalPnL") + pnl);
}

//+------------------------------------------------------------------+
//| Enhanced Signal Logging                                          |
//+------------------------------------------------------------------+
void EnhancedLogSignal(string signalType, int confidence, string details, string setup = "", string risks = "")
{
   string signalMessage = StringFormat("%s Signal - Conf:%d/10 - %s", signalType, confidence, details);
   if(setup != "") signalMessage += " - Setup:" + setup;
   if(risks != "") signalMessage += " - Risks:" + risks;
   
   // Log to main system
   EnhancedLog(signalMessage, "SIGNAL");
   
   // Log to dedicated signal file
   if(g_LoggingInitialized)
   {
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string signalEntry = StringFormat("[%s] %s\r\n", timestamp, signalMessage);
      WriteToLogFile(g_SignalLogFile, signalEntry);
   }
   
   // Update CSV with signal data
   if(g_LoggingInitialized && InpExportCSV)
   {
      AddToAnalysisCSV(TimeToString(TimeCurrent()), "SIGNAL", signalMessage,
                      SymbolInfoDouble(_Symbol, SYMBOL_BID), confidence, setup, 0);
   }
}

//+------------------------------------------------------------------+
//| NEW: Smart Loss Management Log Function                          |
//+------------------------------------------------------------------+
void LogSmartLossManagement(string action, ulong ticket, string details, double savedAmount = 0)
{
   string slmMessage = StringFormat("%s - Ticket:%d - %s", action, (int)ticket, details);
   if(savedAmount > 0) slmMessage += StringFormat(" - Saved:%.2f", savedAmount);
   
   // Log to main system
   EnhancedLog(slmMessage, "SLM");
   
   // Log to dedicated trade file
   if(g_LoggingInitialized)
   {
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string slmEntry = StringFormat("[%s] %s\r\n", timestamp, slmMessage);
      WriteToLogFile(g_TradeLogFile, slmEntry);
   }
   
   // Update statistics if early exit
   if(StringFind(action, "EARLY EXIT") >= 0)
   {
      earlyExitCount++;
      capitalSaved += savedAmount;
      GlobalVariableSet("GD_EarlyExitCount", earlyExitCount);
      GlobalVariableSet("GD_CapitalSaved", capitalSaved);
   }
}

//+------------------------------------------------------------------+
//| Write to Log File Safely                                         |
//+------------------------------------------------------------------+
bool WriteToLogFile(string filename, string content)
{
   if(!g_LoggingInitialized) return false;
   
   int handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot write to " + filename + " - Error: " + IntegerToString(GetLastError()));
      return false;
   }
   
   // Move to end of file
   FileSeek(handle, 0, SEEK_END);
   
   // Write content and force flush
   FileWriteString(handle, content);
   FileFlush(handle);
   FileClose(handle);
   
   return true;
}

//+------------------------------------------------------------------+
//| Add Entry to Analysis CSV                                        |
//+------------------------------------------------------------------+
void AddToAnalysisCSV(string datetimeStr, string type, string message, double price, int confidence, string setup, double pnl)
{
   if(!g_LoggingInitialized)
   {
      // Print("DEBUG: CSV not initialized when trying to write: " + type);
      return;
   }
   
   if(g_AnalysisCSV == "")
   {
      // Print("DEBUG: CSV filename is empty!");
      return;
   }
   
   // Print("DEBUG: Attempting to write to CSV: " + g_AnalysisCSV);
   
   int handle = FileOpen(g_AnalysisCSV, FILE_WRITE|FILE_READ|FILE_CSV);
   if(handle == INVALID_HANDLE)
   {
      int error = GetLastError();
      Print("ERROR: Cannot open CSV file: " + g_AnalysisCSV + " - Error: " + IntegerToString(error));
      return;
   }
   
   // Print("DEBUG: CSV file opened successfully, writing data...");
   
   FileSeek(handle, 0, SEEK_END);
   FileWrite(handle, datetimeStr, type, message, DoubleToString(price, 5), 
             IntegerToString(confidence), setup, DoubleToString(pnl, 2), 
             DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   FileFlush(handle);
   FileClose(handle);
   
   // Print("DEBUG: CSV write completed successfully");
}

//+------------------------------------------------------------------+
//| Update Chart Display                                             |
//+------------------------------------------------------------------+
void UpdateChartDisplay(string category, string message)
{
   static string displayMessages = "";
   static int displayCounter = 0;
   
   displayCounter++;
   
   // Add new message at the top
   string newMessage = StringFormat("%d. [%s] %s", displayCounter, category, message);
   displayMessages = newMessage + "\n" + displayMessages;
   
   // Keep only last 15 messages to prevent overflow
   int lineCount = 0;
   for(int i = 0; i < StringLen(displayMessages); i++)
   {
      if(StringGetCharacter(displayMessages, i) == '\n')
      {
         lineCount++;
         if(lineCount >= 15)
         {
            displayMessages = StringSubstr(displayMessages, 0, i);
            break;
         }
      }
   }
   
   // Create comprehensive comment
   string comment = StringFormat(
      "=== GOLD DOMINATION v1.06 ===\n"
      "Time: %s\n"
      "Account: %d\n"
      "Balance: %.2f | Equity: %.2f\n"
      "Active Positions: %d\n"
      "Logs Created: %d\n"
      "Smart Loss Management: %s\n"
      "Early Exits: %d (Saved: %.2f)\n"
      "Files: %s\n"
      "========================\n"
      "Recent Activity:\n%s",
      TimeToString(TimeCurrent(), TIME_MINUTES),
      (int)AccountInfoInteger(ACCOUNT_LOGIN),
      AccountInfoDouble(ACCOUNT_BALANCE),
      AccountInfoDouble(ACCOUNT_EQUITY),
      PositionsTotal(),
      g_LogCounter,
      InpUseSmartLossManagement ? "ENABLED" : "DISABLED",
      earlyExitCount,
      capitalSaved,
      g_MainLogFile,
      displayMessages
   );
   
   Comment(comment);
}

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== GOLD DOMINATION v1.06 STARTING ===");
   
   // Initialize enhanced logging system FIRST
   if(!InitializeLoggingSystem())
   {
      Print("CRITICAL ERROR: Logging system initialization failed!");
      Alert("CRITICAL ERROR: Logging system initialization failed!");
      return INIT_FAILED;
   }
   
   EnhancedLog("=== GOLD DOMINATION v1.06 INITIALIZATION ===", "SYSTEM");
   EnhancedLog("Enhanced with Smart Loss Management System", "SYSTEM");
   EnhancedLog("Account: " + IntegerToString((int)AccountInfoInteger(ACCOUNT_LOGIN)), "SYSTEM");
   EnhancedLog("Company: " + AccountInfoString(ACCOUNT_COMPANY), "SYSTEM");
   EnhancedLog("Symbol: " + _Symbol, "SYSTEM");
   EnhancedLog("Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), "SYSTEM");
   
   // Initialize symbol info
   if(!symbolInfo.Name(_Symbol) || !symbolInfo.Select())
   {
      EnhancedLog("ERROR: Failed to initialize symbol: " + _Symbol, "ERROR");
      return INIT_FAILED;
   }
   EnhancedLog("✓ Symbol initialized: " + _Symbol, "SYSTEM");
   
   // Configure trade manager
   tradeManager.SetExpertMagicNumber(InpMagicNumber);
   tradeManager.SetDeviationInPoints(InpSlippage);
   tradeManager.SetTypeFilling(ORDER_FILLING_IOC);
   tradeManager.SetAsyncMode(false);
   EnhancedLog("✓ Trade manager configured - Magic: " + IntegerToString(InpMagicNumber), "SYSTEM");
   
   // Initialize indicators
   if(!InitializeIndicators())
   {
      EnhancedLog("ERROR: Failed to initialize indicators", "ERROR");
      return INIT_FAILED;
   }
   EnhancedLog("✓ All indicators initialized successfully", "SYSTEM");
   
   // Initialize sessions
   InitializeSessions();
   EnhancedLog("✓ Trading sessions configured", "SYSTEM");
   
   // Initialize system variables
   isInitialized = true;
   lastBarTime = 0;
   consecutiveLosses = 0;
   currentRiskFactor = 1.0;
   totalTrades = 0;
   profitableTrades = 0;
   winStreak = 0;
   maxWinStreak = 0;
   rejectedSignalsCount = 0;
   
   // Resize trade history array
   ArrayResize(tradeHistory, 1000);
   tradeHistorySize = 0;
   
   // NEW: Initialize price level tracking
   ArrayResize(recentLevels, InpPriceLevelsToTrack);
   
   // Log configuration
   EnhancedLog("===== CONFIGURATION =====", "CONFIG");
   EnhancedLog("Lot Size: " + DoubleToString(InpLotSize, 2), "CONFIG");
   EnhancedLog("SL/TP: " + IntegerToString(InpBaseStopLoss) + "/" + IntegerToString(InpBaseTakeProfit) + " pips", "CONFIG");
   EnhancedLog("Max Positions: " + IntegerToString(InpMaxPositions), "CONFIG");
   EnhancedLog("Minimum Confidence: " + IntegerToString(InpMinConfidence), "CONFIG");
   EnhancedLog("Confidence Sizing: " + BoolToString(InpUseConfidenceSizing), "CONFIG");
   EnhancedLog("Hybrid System: " + BoolToString(InpUseHybridSystem), "CONFIG");
   
   // NEW: Log Smart Loss Management configuration
   if(InpUseSmartLossManagement)
   {
      EnhancedLog("===== SMART LOSS MANAGEMENT =====", "CONFIG");
      EnhancedLog("Early Detection Period: " + IntegerToString(InpEarlyDetectionHours) + " hours", "CONFIG");
      EnhancedLog("Early Exit Threshold: " + DoubleToString(InpEarlyExitThreshold, 1) + "%", "CONFIG");
      EnhancedLog("Market Structure Validation: " + BoolToString(InpUseMarketStructureValidation), "CONFIG");
      EnhancedLog("Dynamic SL Placement: " + BoolToString(InpUseDynamicSLPlacement), "CONFIG");
      EnhancedLog("SL Multiplier Range: " + DoubleToString(InpMinSLMultiplier, 1) + "-" + DoubleToString(InpMaxSLMultiplier, 1), "CONFIG");
      EnhancedLog("RSI Period: " + IntegerToString(InpRSI_Period), "CONFIG");
      EnhancedLog("Price Levels Tracked: " + IntegerToString(InpPriceLevelsToTrack), "CONFIG");
   }
   
   if(InpUseHybridSystem)
   {
      EnhancedLog("Scale-Out Time: " + IntegerToString(InpScaleOutTimeHours) + " hours", "CONFIG");
      EnhancedLog("Trend Threshold: " + DoubleToString(InpTrendThreshold, 1), "CONFIG");
      EnhancedLog("High Vol Multiplier: " + DoubleToString(InpHighVolMultiplier, 1), "CONFIG");
      EnhancedLog("Low Vol Multiplier: " + DoubleToString(InpLowVolMultiplier, 1), "CONFIG");
   }
   EnhancedLog("Intermarket: DXY=" + BoolToString(InpUseDXY) + " VIX=" + BoolToString(InpUseVIX), "CONFIG");
   EnhancedLog("Enhanced Logging: ENABLED", "CONFIG");
   EnhancedLog("===== INITIALIZATION COMPLETED =====", "SYSTEM");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EnhancedLog("===== SYSTEM SHUTDOWN =====", "SYSTEM");
   EnhancedLog("Reason Code: " + IntegerToString(reason), "SYSTEM");
   EnhancedLog("Shutdown Time: " + TimeToString(TimeCurrent()), "SYSTEM");
   
   // Log final statistics
   EnhancedLog("===== FINAL STATISTICS =====", "STATS");
   EnhancedLog("Total Trades: " + IntegerToString(totalTrades), "STATS");
   EnhancedLog("Profitable: " + IntegerToString(profitableTrades), "STATS");
   EnhancedLog("Total P&L: " + DoubleToString(totalPnL, 2), "STATS");
   EnhancedLog("Signals Rejected: " + IntegerToString(rejectedSignalsCount), "STATS");
   EnhancedLog("Log Entries Created: " + IntegerToString(g_LogCounter), "STATS");
   
   // NEW: Smart Loss Management stats
   if(InpUseSmartLossManagement)
   {
      EnhancedLog("Early Exits: " + IntegerToString(earlyExitCount), "STATS");
      EnhancedLog("Estimated Capital Saved: " + DoubleToString(capitalSaved, 2), "STATS");
   }
   
   if(totalTrades > 0)
   {
      double winRate = (double)profitableTrades / totalTrades * 100;
      EnhancedLog("Win Rate: " + DoubleToString(winRate, 1) + "%", "STATS");
      EnhancedLog("Average P&L: " + DoubleToString(totalPnL / totalTrades, 2), "STATS");
   }
   
   // Generate final report
   if(InpCreateSummaryReports)
   {
      GenerateFinalReport();
      EnhancedLog("Final report generated: " + g_ReportFile, "SYSTEM");
   }
   
   // Export pattern analysis
   if(InpAnalyzePatterns && tradeHistorySize > 0)
   {
      ExportPatternAnalysis();
      EnhancedLog("Pattern analysis exported", "SYSTEM");
   }
   
   // Release indicators
   ReleaseIndicators();
   
   EnhancedLog("===== SHUTDOWN COMPLETED =====", "SYSTEM");
   
   // Final status update
   Comment("Gold Domination v1.06 - SHUTDOWN COMPLETE\n" +
           "Check log files in MQL5\\Files folder:\n" +
           "1. " + g_MainLogFile + "\n" +
           "2. " + g_TradeLogFile + "\n" +
           "3. " + g_SignalLogFile + "\n" +
           "4. " + g_AnalysisCSV + "\n" +
           "5. " + g_ReportFile);
}

//+------------------------------------------------------------------+
//| ON TESTER - FINAL RESULTS OUTPUT                                |
//+------------------------------------------------------------------+
double OnTester()
{
   // Output critical information for Strategy Tester
   Print("===== GOLD DOMINATION v1.06 - STRATEGY TESTER RESULTS =====");
   Print("Test Duration: " + TimeToString((datetime)GlobalVariableGet("GD_StartTime")) + " to " + TimeToString(TimeCurrent()));
   Print("Total Trades: " + IntegerToString((int)GlobalVariableGet("GD_TradeCount")));
   Print("Winning Trades: " + IntegerToString((int)GlobalVariableGet("GD_WinCount")));
   Print("Total P&L: " + DoubleToString(GlobalVariableGet("GD_TotalPnL"), 2));
   Print("Log Entries Created: " + IntegerToString((int)GlobalVariableGet("GD_LogCount")));
   Print("Start Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE) - GlobalVariableGet("GD_TotalPnL"), 2));
   Print("Final Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   
   // NEW: Smart Loss Management stats
   Print("Early Exits: " + IntegerToString((int)GlobalVariableGet("GD_EarlyExitCount")));
   Print("Estimated Capital Saved: " + DoubleToString(GlobalVariableGet("GD_CapitalSaved"), 2));
   
   if(GlobalVariableGet("GD_TradeCount") > 0)
   {
      double winRate = GlobalVariableGet("GD_WinCount") / GlobalVariableGet("GD_TradeCount") * 100;
      Print("Win Rate: " + DoubleToString(winRate, 1) + "%");
   }
   
   Print("=== LOG FILES CREATED ===");
   Print("Main Log: " + g_MainLogFile);
   Print("Trade Log: " + g_TradeLogFile);
   Print("Signal Log: " + g_SignalLogFile);
   Print("Analysis CSV: " + g_AnalysisCSV);
   Print("Report: " + g_ReportFile);
   Print("===== CHECK MQL5\\Files FOLDER FOR ALL LOGS =====");
   
   // Return total P&L for optimization
   return GlobalVariableGet("GD_TotalPnL");
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!isInitialized) return;
   
   // Track position changes in real-time
   static int lastPositionCount = -1;
   int currentPositions = CountPositions();
   
   if(currentPositions != lastPositionCount)
   {
      EnhancedLogTrade("POSITION CHANGE", 0, 
                      StringFormat("Count changed from %d to %d", lastPositionCount, currentPositions));
      lastPositionCount = currentPositions;
   }
   
   // NEW: Update price swing points for market structure analysis
   if(InpUseSmartLossManagement && InpUseMarketStructureValidation)
   {
      UpdateMarketStructureLevels();
   }
   
   // IMPROVED: Position management timing
   datetime currentTime = TimeCurrent();
   
   // Check positions more frequently with Smart Loss Management enabled
   if(InpUseSmartLossManagement && currentTime - lastPositionCheckTime >= 60) // Every minute
   {
      ManageExistingPositions();
      lastPositionCheckTime = currentTime;
   }
   // Standard check for hybrid system (every 5 minutes)
   else if(!InpUseSmartLossManagement && currentTime - lastPositionCheckTime >= 300)
   {
      bool hasOldPositions = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(positionInfo.SelectByIndex(i) && 
            positionInfo.Magic() == InpMagicNumber && 
            positionInfo.Symbol() == _Symbol)
         {
            datetime openTime = positionInfo.Time();
            int minutesOpen = (int)((currentTime - openTime) / 60);
            if(minutesOpen >= InpScaleOutTimeHours * 60) // At least 1 hour old
            {
               hasOldPositions = true;
               break;
            }
         }
      }
      
      // Only run position management every 5 minutes if we have positions older than 1 hour
      if(hasOldPositions)
      {
         ManageExistingPositions();
         lastPositionCheckTime = currentTime;
      }
   }
   
   // Check for new bar - Properly declare array with size
   datetime currentBarTime[1];
   if(CopyTime(_Symbol, PERIOD_H1, 0, 1, currentBarTime) != 1) return;
   
   if(currentBarTime[0] == lastBarTime) return;
   lastBarTime = currentBarTime[0];
   
   // NEW BAR PROCESSING
   EnhancedLog("===== NEW H1 BAR: " + TimeToString(currentBarTime[0], TIME_DATE|TIME_MINUTES) + " =====", "BAR");
   
   // Update sessions
   UpdateSessionStatus();
   
   // Check trading conditions
   if(!IsTradingAllowed())
   {
      EnhancedLog("Trading not allowed - Reason: " + GetTradingRestrictionReason(), "INFO");
      return;
   }
   
   // Evaluate new entries
   if(currentPositions < InpMaxPositions)
   {
      EvaluateEntryOpportunities();
   }
   else
   {
      EnhancedLog("Max positions reached: " + IntegerToString(currentPositions), "INFO");
   }
   
   // Periodic summary
   static int barCount = 0;
   barCount++;
   if(barCount % 24 == 0) // Daily summary
   {
      EnhancedLog("=== DAILY SUMMARY (Bar " + IntegerToString(barCount) + ") ===", "SUMMARY");
      EnhancedLog("Active Positions: " + IntegerToString(currentPositions), "SUMMARY");
      EnhancedLog("Total Trades: " + IntegerToString(totalTrades), "SUMMARY");
      EnhancedLog("Running P&L: " + DoubleToString(totalPnL, 2), "SUMMARY");
      if(totalTrades > 0)
         EnhancedLog("Running Win Rate: " + DoubleToString((double)profitableTrades/totalTrades*100, 1) + "%", "SUMMARY");
      
      // NEW: Smart Loss Management summary
      if(InpUseSmartLossManagement)
      {
         EnhancedLog("Early Exits: " + IntegerToString(earlyExitCount), "SUMMARY");
         EnhancedLog("Estimated Capital Saved: " + DoubleToString(capitalSaved, 2), "SUMMARY");
      }
   }
}

//+------------------------------------------------------------------+
//| INITIALIZE INDICATORS                                            |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // Try Heiken Ashi first, fallback to regular if not available
   handleHA = iCustom(_Symbol, PERIOD_H1, "Examples\\Heiken_Ashi");
   if(handleHA == INVALID_HANDLE)
   {
      EnhancedLog("WARNING: Heiken Ashi not available, using fallback", "WARNING");
      handleHA = iMA(_Symbol, PERIOD_H1, 1, 0, MODE_SMA, PRICE_OPEN);
   }
   
   handleCCI = iCCI(_Symbol, PERIOD_H1, InpCCI_Period, PRICE_TYPICAL);
   handleWR = iWPR(_Symbol, PERIOD_H1, InpWilliamsR_Period);
   handleADX = iADX(_Symbol, PERIOD_H1, InpADX_Period);
   handleATR = iATR(_Symbol, PERIOD_H1, InpATR_Period);
   
   // NEW: Initialize RSI for momentum detection
   if(InpUseSmartLossManagement)
   {
      handleRSI = iRSI(_Symbol, PERIOD_H1, InpRSI_Period, PRICE_CLOSE);
      if(handleRSI == INVALID_HANDLE)
      {
         EnhancedLog("WARNING: RSI indicator failed to initialize", "WARNING");
      }
   }
   
   // Intermarket indicators
   if(InpUseDXY)
      handleDXY = iMA(InpDXY_Symbol, PERIOD_H1, 1, 0, MODE_SMA, PRICE_CLOSE);
   if(InpUseVIX)
      handleVIX = iMA(InpVIX_Symbol, PERIOD_H1, 1, 0, MODE_SMA, PRICE_CLOSE);
   
   // Log indicator status
   EnhancedLog("Indicator Status:", "SYSTEM");
   EnhancedLog("- HA: " + (handleHA != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   EnhancedLog("- CCI: " + (handleCCI != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   EnhancedLog("- Williams %R: " + (handleWR != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   EnhancedLog("- ADX: " + (handleADX != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   EnhancedLog("- ATR: " + (handleATR != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   
   if(InpUseSmartLossManagement)
      EnhancedLog("- RSI: " + (handleRSI != INVALID_HANDLE ? "✓ OK" : "✗ FAILED"), "SYSTEM");
   
   if(InpUseDXY) 
      EnhancedLog("- DXY: " + (handleDXY != INVALID_HANDLE ? "✓ OK" : "✗ NOT AVAILABLE"), "SYSTEM");
   if(InpUseVIX) 
      EnhancedLog("- VIX: " + (handleVIX != INVALID_HANDLE ? "✓ OK" : "✗ NOT AVAILABLE"), "SYSTEM");
   
   // Check critical indicators
   if(handleCCI == INVALID_HANDLE || handleWR == INVALID_HANDLE || 
      handleADX == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      EnhancedLog("ERROR: Critical indicators failed to initialize", "ERROR");
      return false;
   }
   
   // Check if Smart Loss Management indicators are available
   if(InpUseSmartLossManagement && handleRSI == INVALID_HANDLE)
   {
      EnhancedLog("WARNING: Smart Loss Management enabled but RSI unavailable - Partial functionality", "WARNING");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| INITIALIZE SESSIONS                                              |
//+------------------------------------------------------------------+
void InitializeSessions()
{
   londonSession.startHour = 8;
   londonSession.endHour = 17;
   nySession.startHour = 13;
   nySession.endHour = 22;
   asianSession.startHour = 23;
   asianSession.endHour = 8;
   
   EnhancedLog("Sessions configured: London(8-17) NY(13-22) Asian(23-8)", "SYSTEM");
}

//+------------------------------------------------------------------+
//| UPDATE SESSION STATUS                                            |
//+------------------------------------------------------------------+
void UpdateSessionStatus()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   int currentHour = timeStruct.hour;
   
   londonSession.isActive = (currentHour >= londonSession.startHour && 
                            currentHour < londonSession.endHour);
   nySession.isActive = (currentHour >= nySession.startHour && 
                        currentHour < nySession.endHour);
   asianSession.isActive = (currentHour >= asianSession.startHour || 
                           currentHour < asianSession.endHour);
}

//+------------------------------------------------------------------+
//| GET CURRENT SESSION TYPE                                         |
//+------------------------------------------------------------------+
SESSION_TYPE GetCurrentSession()
{
   if(londonSession.isActive && nySession.isActive) return SESSION_OVERLAP;
   if(londonSession.isActive) return SESSION_LONDON;
   if(nySession.isActive) return SESSION_NY;
   if(asianSession.isActive) return SESSION_ASIAN;
   return SESSION_OFF_HOURS;
}

//+------------------------------------------------------------------+
//| CHECK IF TRADING IS ALLOWED                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   if(!InpTradeWeekends)
   {
      MqlDateTime timeStruct;
      TimeToStruct(TimeCurrent(), timeStruct);
      if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
         return false;
   }
   
   if(consecutiveLosses >= InpMaxLosses)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| GET TRADING RESTRICTION REASON                                   |
//+------------------------------------------------------------------+
string GetTradingRestrictionReason()
{
   if(!InpTradeWeekends)
   {
      MqlDateTime timeStruct;
      TimeToStruct(TimeCurrent(), timeStruct);
      if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
         return "Weekend trading disabled";
   }
   
   if(consecutiveLosses >= InpMaxLosses)
      return "Max consecutive losses reached (" + IntegerToString(consecutiveLosses) + ")";
   
   return "Unknown restriction";
}

//+------------------------------------------------------------------+
//| NEW: UPDATE MARKET STRUCTURE LEVELS                             |
//+------------------------------------------------------------------+
void UpdateMarketStructureLevels()
{
   // Get recent price data
   int bars = 50; // Look back period
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, high) != bars) return;
   if(CopyLow(_Symbol, PERIOD_H1, 0, bars, low) != bars) return;
   
   // Find potential swing highs and lows
   for(int i = 1; i < bars - 1; i++)
   {
      // Swing high: current high is higher than previous and next
      if(high[i] > high[i+1] && high[i] > high[i-1])
      {
         AddPriceLevel(high[i], true); // true = high
      }
      
      // Swing low: current low is lower than previous and next
      if(low[i] < low[i+1] && low[i] < low[i-1])
      {
         AddPriceLevel(low[i], false); // false = low
      }
   }
   
   // Check if current price has broken any levels
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double currentPrice = (tick.bid + tick.ask) / 2;
   
   // Update broken status for levels
   for(int i = 0; i < ArraySize(recentLevels); i++)
   {
      // Skip empty or already broken levels
      if(recentLevels[i].price == 0 || recentLevels[i].broken) continue;
      
      if(recentLevels[i].isHigh && currentPrice > recentLevels[i].price)
      {
         recentLevels[i].broken = true;
         EnhancedLog("Market Structure: Resistance level " + DoubleToString(recentLevels[i].price, 5) + " broken", "STRUCTURE");
      }
      else if(!recentLevels[i].isHigh && currentPrice < recentLevels[i].price)
      {
         recentLevels[i].broken = true;
         EnhancedLog("Market Structure: Support level " + DoubleToString(recentLevels[i].price, 5) + " broken", "STRUCTURE");
      }
   }
}

//+------------------------------------------------------------------+
//| NEW: ADD PRICE LEVEL TO TRACKED LEVELS                          |
//+------------------------------------------------------------------+
void AddPriceLevel(double price, bool isHigh)
{
   // Don't add duplicates (within small range)
   for(int i = 0; i < ArraySize(recentLevels); i++)
   {
      if(recentLevels[i].price == 0) continue; // Skip empty slots
      
      double diff = MathAbs(recentLevels[i].price - price);
      if(diff < 0.00010) // Within 1 pip for gold
      {
         return; // Too close to existing level
      }
   }
   
   // Shift array to make room for new level
   for(int i = ArraySize(recentLevels) - 1; i > 0; i--)
   {
      recentLevels[i] = recentLevels[i-1];
   }
   
   // Add new level at index 0
   recentLevels[0].price = price;
   recentLevels[0].time = TimeCurrent();
   recentLevels[0].isHigh = isHigh;
   recentLevels[0].broken = false;
}

//+------------------------------------------------------------------+
//| GET MARKET DATA WITH ENHANCED ANALYSIS                          |
//+------------------------------------------------------------------+
bool GetMarketData(MarketData &data)
{
   ZeroMemory(data);
   data.isValid = false;
   
   // Get current price - Properly declare array with size
   double close[1];
   if(CopyClose(_Symbol, PERIOD_H1, 0, 1, close) != 1) return false;
   data.price_current = close[0];
   
   // Get Heiken Ashi data
   if(handleHA != INVALID_HANDLE)
   {
      double ha_open[1], ha_close[1];
      if(CopyBuffer(handleHA, 0, 1, 1, ha_open) == 1 && 
         CopyBuffer(handleHA, 3, 1, 1, ha_close) == 1)
      {
         data.ha_open = ha_open[0];
         data.ha_close = ha_close[0];
      }
      else
      {
         double open[1];
         if(CopyOpen(_Symbol, PERIOD_H1, 1, 1, open) == 1)
         {
            data.ha_open = open[0];
            data.ha_close = close[0];
         }
      }
   }
   
   // Get other indicators - All array declarations properly sized
   if(handleCCI != INVALID_HANDLE)
   {
      double cci[1];
      if(CopyBuffer(handleCCI, 0, 0, 1, cci) == 1)
         data.cci_current = cci[0];
   }
   
   if(handleWR != INVALID_HANDLE)
   {
      double wr[1];
      if(CopyBuffer(handleWR, 0, 0, 1, wr) == 1)
         data.wr_current = wr[0];
   }
   
   if(handleADX != INVALID_HANDLE)
   {
      double adx[1];
      if(CopyBuffer(handleADX, 0, 0, 1, adx) == 1)
         data.adx_current = adx[0];
   }
   
   if(handleATR != INVALID_HANDLE)
   {
      double atr[5];
      if(CopyBuffer(handleATR, 0, 0, 5, atr) == 5)
      {
         data.atr_current = atr[0];
         data.atr_average = (atr[1] + atr[2] + atr[3] + atr[4]) / 4.0;
         data.volatilityRatio = data.atr_average > 0 ? data.atr_current / data.atr_average : 1.0;
         data.isHighVolatility = data.volatilityRatio > 1.5;
      }
   }
   
   // NEW: Get RSI for Smart Loss Management
   if(InpUseSmartLossManagement && handleRSI != INVALID_HANDLE)
   {
      double rsi[2];
      if(CopyBuffer(handleRSI, 0, 0, 2, rsi) == 2)
      {
         data.rsi_current = rsi[0];
         data.momentumShift = false;
         
         // Check for bearish momentum shift (falling RSI)
         if(rsi[0] < rsi[1] && rsi[0] < InpRSIThreshold)
            data.momentumShift = true;
         
         // Check for bullish momentum shift (rising RSI)
         if(rsi[0] > rsi[1] && rsi[0] > 100 - InpRSIThreshold)
            data.momentumShift = true;
      }
   }
   
   // Get volume
   long volume[1];
   if(CopyTickVolume(_Symbol, PERIOD_H1, 0, 1, volume) == 1)
      data.volume_current = (double)volume[0];
   
   // Get intermarket data
   if(handleDXY != INVALID_HANDLE)
   {
      double dxy[1];
      if(CopyBuffer(handleDXY, 0, 0, 1, dxy) == 1)
         data.dxy_current = dxy[0];
   }
   
   if(handleVIX != INVALID_HANDLE)
   {
      double vix[1];
      if(CopyBuffer(handleVIX, 0, 0, 1, vix) == 1)
         data.vix_current = vix[0];
   }
   
   // Enhanced analysis
   data.activeSession = GetCurrentSession();
   data.isTrendingMarket = data.adx_current >= InpADX_Threshold;
   
   // NEW: Add market structure data for Smart Loss Management
   if(InpUseSmartLossManagement && InpUseMarketStructureValidation)
   {
      data.structureBreak = false;
      
      // Check for recent structure breaks (within last 3 bars)
      for(int i = 0; i < ArraySize(recentLevels); i++)
      {
         if(recentLevels[i].broken && 
            TimeCurrent() - recentLevels[i].time < 3 * 3600) // 3 hours
         {
            data.structureBreak = true;
            if(recentLevels[i].isHigh)
               data.swing_high = recentLevels[i].price;
            else
               data.swing_low = recentLevels[i].price;
            break;
         }
      }
   }
   
   data.isValid = true;
   return true;
}

//+------------------------------------------------------------------+
//| ANALYZE SIGNAL RISKS AND CLASSIFY SETUP                        |
//+------------------------------------------------------------------+
void AnalyzeSignalRisks(MarketData &data, SignalData &signal)
{
   signal.riskFactors = "";
   signal.oscillatorConflicts = 0;
   
   // Risk Factor 1: High volatility
   if(data.isHighVolatility)
      signal.riskFactors += "HIGH_VOL ";
   
   // Risk Factor 2: Weak trend
   if(data.adx_current < 20)
      signal.riskFactors += "WEAK_TREND ";
   
   // Risk Factor 3: Off-hours trading
   if(data.activeSession == SESSION_OFF_HOURS || data.activeSession == SESSION_ASIAN)
      signal.riskFactors += "OFF_HOURS ";
   
   // Risk Factor 4: Oscillator conflicts
   bool cciSignal = MathAbs(data.cci_current) > InpCCI_Extreme;
   bool wrSignal = (data.wr_current <= InpWR_Oversold || data.wr_current >= InpWR_Overbought);
   
   if(cciSignal && wrSignal)
   {
      // Check if they agree
      bool cciBullish = data.cci_current < -InpCCI_Extreme;
      bool wrBullish = data.wr_current <= InpWR_Oversold;
      if(cciBullish != wrBullish)
      {
         signal.oscillatorConflicts++;
         signal.riskFactors += "OSC_CONFLICT ";
      }
   }
   
   // Risk Factor 5: Counter-trend setup
   signal.isCounterTrend = false;
   if(signal.haConfirmation)
   {
      bool haBullish = data.ha_close > data.ha_open;
      if((signal.bearishScore > signal.bullishScore && haBullish) ||
         (signal.bullishScore > signal.bearishScore && !haBullish))
      {
         signal.isCounterTrend = true;
         signal.riskFactors += "COUNTER_TREND ";
      }
   }
   
   // Risk Factor 6: Intermarket divergence
   if(InpUseDXY && handleDXY != INVALID_HANDLE && !signal.intermarketConfirmation)
      signal.riskFactors += "DXY_DIVERGE ";
   
   // Risk Factor 7: Low volume
   if(InpUseVolumeFilter && !signal.volumeConfirmation)
      signal.riskFactors += "LOW_VOLUME ";
   
   // NEW: Risk Factor 8: Momentum or structure risks for Smart Loss Management
   if(InpUseSmartLossManagement)
   {
      if(data.momentumShift)
         signal.riskFactors += "MOMENTUM_SHIFT ";
      
      if(data.structureBreak)
         signal.riskFactors += "STRUCTURE_BREAK ";
   }
   
   // Classify setup type
   if(data.adx_current >= 30 && signal.haConfirmation && !signal.isCounterTrend)
      signal.setupType = SETUP_STRONG_TREND;
   else if(data.adx_current >= 20 && data.adx_current < 30)
      signal.setupType = SETUP_MODERATE_TREND;
   else if(data.adx_current < 20)
      signal.setupType = SETUP_WEAK_TREND;
   else if(signal.isCounterTrend)
      signal.setupType = SETUP_COUNTER_TREND;
   else if(data.isHighVolatility)
      signal.setupType = SETUP_BREAKOUT;
   else
      signal.setupType = SETUP_RANGE_REVERSAL;
   
   // Calculate signal strength (0-1 scale)
   int confirmations = (signal.haConfirmation ? 1 : 0) +
                      (signal.cciConfirmation ? 1 : 0) +
                      (signal.wrConfirmation ? 1 : 0) +
                      (signal.adxConfirmation ? 1 : 0) +
                      (signal.atrConfirmation ? 1 : 0) +
                      (signal.intermarketConfirmation ? 1 : 0) +
                      (signal.sessionConfirmation ? 1 : 0) +
                      (signal.volumeConfirmation ? 1 : 0);
   
   signal.signalStrength = (double)confirmations / 8.0;
}

//+------------------------------------------------------------------+
//| CALCULATE SIGNAL CONFIDENCE WITH ENHANCED ANALYSIS             |
//+------------------------------------------------------------------+
int CalculateSignalConfidence(MarketData &data, SignalData &signal)
{
   ZeroMemory(signal);
   signal.description = "";
   
   int totalPoints = 0;
   int earnedPoints = 0;
   
   // 1. Heiken Ashi Analysis (2 points)
   if(handleHA != INVALID_HANDLE)
   {
      totalPoints += 2;
      bool haBullish = data.ha_close > data.ha_open;
      if(haBullish)
      {
         signal.bullishScore += 2;
         earnedPoints += 2;
         signal.description += "HA:BULL(+2) ";
      }
      else
      {
         signal.bearishScore += 2;
         earnedPoints += 2;
         signal.description += "HA:BEAR(+2) ";
      }
      signal.haConfirmation = true;
   }
   
   // 2. CCI Analysis (1 point)
   if(handleCCI != INVALID_HANDLE)
   {
      totalPoints += 1;
      if(MathAbs(data.cci_current) > InpCCI_Extreme)
      {
         if(data.cci_current > InpCCI_Extreme)
         {
            signal.bearishScore += 1;
            signal.description += "CCI:OB(-1) ";
         }
         else
         {
            signal.bullishScore += 1;
            signal.description += "CCI:OS(+1) ";
         }
         earnedPoints += 1;
         signal.cciConfirmation = true;
      }
      else
      {
         signal.description += "CCI:NEUTRAL ";
      }
   }
   
   // 3. Williams %R Analysis (1 point)
   if(handleWR != INVALID_HANDLE)
   {
      totalPoints += 1;
      if(data.wr_current <= InpWR_Oversold)
      {
         signal.bullishScore += 1;
         earnedPoints += 1;
         signal.description += "WR:OS(+1) ";
         signal.wrConfirmation = true;
      }
      else if(data.wr_current >= InpWR_Overbought)
      {
         signal.bearishScore += 1;
         earnedPoints += 1;
         signal.description += "WR:OB(-1) ";
         signal.wrConfirmation = true;
      }
      else
      {
         signal.description += "WR:NEUTRAL ";
      }
   }
   
   // 4. ADX Trend Strength (1 point)
   if(handleADX != INVALID_HANDLE)
   {
      totalPoints += 1;
      if(data.adx_current >= InpADX_Threshold)
      {
         earnedPoints += 1;
         signal.description += "ADX:TREND(+1) ";
         signal.adxConfirmation = true;
      }
      else
      {
         signal.description += "ADX:WEAK ";
      }
   }
   
   // 5. ATR Volatility Filter (1 point)
   if(handleATR != INVALID_HANDLE && data.atr_average > 0)
   {
      totalPoints += 1;
      if(data.atr_current <= InpATR_Multiplier * data.atr_average)
      {
         earnedPoints += 1;
         signal.description += "ATR:OK(+1) ";
         signal.atrConfirmation = true;
      }
      else
      {
         signal.description += "ATR:HIGH ";
      }
   }
   
   // 6. Volume Confirmation (1 point)
   if(InpUseVolumeFilter)
   {
      totalPoints += 1;
      if(data.volume_current >= InpVolumeThreshold)
      {
         earnedPoints += 1;
         signal.description += "VOL:HIGH(+1) ";
         signal.volumeConfirmation = true;
      }
      else
      {
         signal.description += "VOL:LOW ";
      }
   }
   
   // 7. Intermarket Analysis (1 point each)
   if(InpUseDXY && handleDXY != INVALID_HANDLE)
   {
      totalPoints += 1;
      double dxy_prev[1];
      if(CopyBuffer(handleDXY, 0, 1, 1, dxy_prev) == 1)
      {
         if(data.dxy_current < dxy_prev[0])
         {
            signal.bullishScore += 1;
            earnedPoints += 1;
            signal.description += "DXY:DOWN(+1) ";
            signal.intermarketConfirmation = true;
         }
         else if(data.dxy_current > dxy_prev[0])
         {
            signal.bearishScore += 1;
            earnedPoints += 1;
            signal.description += "DXY:UP(-1) ";
            signal.intermarketConfirmation = true;
         }
      }
   }
   
   if(InpUseVIX && handleVIX != INVALID_HANDLE)
   {
      totalPoints += 1;
      if(data.vix_current >= InpVIX_High)
      {
         signal.bullishScore += 1;
         earnedPoints += 1;
         signal.description += "VIX:HIGH(+1) ";
         signal.intermarketConfirmation = true;
      }
      else if(data.vix_current <= InpVIX_Low)
      {
         signal.bearishScore += 1;
         earnedPoints += 1;
         signal.description += "VIX:LOW(-1) ";
         signal.intermarketConfirmation = true;
      }
   }
   
   // 8. Session Bias (1 point)
   totalPoints += 1;
   if(data.activeSession == SESSION_LONDON && InpUseLondonBreakout)
   {
      earnedPoints += 1;
      signal.description += "LONDON(+1) ";
      signal.sessionConfirmation = true;
   }
   else if(data.activeSession == SESSION_NY && InpUseNYOverlap)
   {
      earnedPoints += 1;
      signal.description += "NY(+1) ";
      signal.sessionConfirmation = true;
   }
   else if(data.activeSession == SESSION_OVERLAP)
   {
      earnedPoints += 1;
      signal.description += "OVERLAP(+1) ";
      signal.sessionConfirmation = true;
   }
   else if(data.activeSession == SESSION_ASIAN && InpUseAsianRange)
   {
      if(handleCCI != INVALID_HANDLE && MathAbs(data.cci_current) > InpCCI_Extreme)
      {
         earnedPoints += 1;
         signal.description += "ASIAN-REV(+1) ";
         signal.sessionConfirmation = true;
      }
   }
   
   // Calculate confidence and analyze risks
   int confidence = totalPoints > 0 ? (int)MathRound((double)earnedPoints / totalPoints * 10) : 0;
   AnalyzeSignalRisks(data, signal);
   
   return confidence;
}

//+------------------------------------------------------------------+
//| EVALUATE ENTRY OPPORTUNITIES                                     |
//+------------------------------------------------------------------+
void EvaluateEntryOpportunities()
{
   EnhancedLog("--- Evaluating Entry Opportunities ---", "ENTRY");
   
   // Get market data
   MarketData marketData;
   if(!GetMarketData(marketData))
   {
      EnhancedLog("ERROR: Failed to get market data", "ERROR");
      return;
   }
   
   // Log market conditions
   LogMarketConditions(marketData);
   
   // Calculate signal confidence
   SignalData signalData;
   int confidence = CalculateSignalConfidence(marketData, signalData);
   
   // Log detailed signal analysis
   LogDetailedSignalAnalysis(signalData, confidence, marketData);
   
   // Check confidence threshold - Uses new minimum confidence parameter
   if(confidence < InpMinConfidence)
   {
      LogRejectedSignal(confidence, signalData, marketData);
      rejectedSignalsCount++;
      return;
   }
   
   // Execute trades based on signal
   if(signalData.bullishScore > signalData.bearishScore)
   {
      EnhancedLogSignal("BULLISH", confidence, 
                       signalData.description,
                       GetSetupTypeString(signalData.setupType),
                       signalData.riskFactors);
      
      if(ExecuteBuyOrder(confidence, marketData, signalData))
      {
         totalTrades++;
         GlobalVariableSet("GD_TotalTrades", totalTrades);
      }
   }
   else if(signalData.bearishScore > signalData.bullishScore)
   {
      EnhancedLogSignal("BEARISH", confidence,
                       signalData.description,
                       GetSetupTypeString(signalData.setupType),
                       signalData.riskFactors);
      
      if(ExecuteSellOrder(confidence, marketData, signalData))
      {
         totalTrades++;
         GlobalVariableSet("GD_TotalTrades", totalTrades);
      }
   }
   else
   {
      EnhancedLog("NEUTRAL SIGNAL - No clear direction", "SIGNAL");
   }
}

//+------------------------------------------------------------------+
//| LOG MARKET CONDITIONS                                            |
//+------------------------------------------------------------------+
void LogMarketConditions(MarketData &data)
{
   EnhancedLog("=== MARKET CONDITIONS ===", "MARKET");
   EnhancedLog("Price: " + DoubleToString(data.price_current, 5), "MARKET");
   EnhancedLog("HA: Open=" + DoubleToString(data.ha_open, 5) + " Close=" + DoubleToString(data.ha_close, 5) + 
              " [" + (data.ha_close > data.ha_open ? "BULLISH" : "BEARISH") + "]", "MARKET");
   EnhancedLog("CCI: " + DoubleToString(data.cci_current, 2) + 
              (MathAbs(data.cci_current) > InpCCI_Extreme ? 
              (data.cci_current > 0 ? " (OVERBOUGHT)" : " (OVERSOLD)") : " (NEUTRAL)"), "MARKET");
   EnhancedLog("Williams %R: " + DoubleToString(data.wr_current, 2) + 
              (data.wr_current <= InpWR_Oversold ? " (OVERSOLD)" : 
              (data.wr_current >= InpWR_Overbought ? " (OVERBOUGHT)" : " (NEUTRAL)")), "MARKET");
   EnhancedLog("ADX: " + DoubleToString(data.adx_current, 2) + 
              (data.adx_current >= InpADX_Threshold ? " (TRENDING)" : " (RANGING)"), "MARKET");
   EnhancedLog("ATR: Current=" + DoubleToString(data.atr_current, 5) + 
              " Average=" + DoubleToString(data.atr_average, 5) + 
              " Ratio=" + DoubleToString(data.volatilityRatio, 2) +
              (data.isHighVolatility ? " (HIGH)" : " (NORMAL)"), "MARKET");
   EnhancedLog("Volume: " + DoubleToString(data.volume_current, 0) + 
              (data.volume_current >= InpVolumeThreshold ? " (HIGH)" : " (LOW)"), "MARKET");
   EnhancedLog("Session: " + GetSessionString(data.activeSession), "MARKET");
   
   // NEW: Log Smart Loss Management data
   if(InpUseSmartLossManagement)
   {
      EnhancedLog("RSI: " + DoubleToString(data.rsi_current, 2) + 
                 (data.momentumShift ? " (MOMENTUM SHIFT)" : ""), "MARKET");
      
      if(data.structureBreak)
         EnhancedLog("Market Structure: Recent break detected", "MARKET");
   }
   
   if(InpUseDXY && handleDXY != INVALID_HANDLE)
      EnhancedLog("DXY: " + DoubleToString(data.dxy_current, 5), "MARKET");
   if(InpUseVIX && handleVIX != INVALID_HANDLE)
      EnhancedLog("VIX: " + DoubleToString(data.vix_current, 2), "MARKET");
}

//+------------------------------------------------------------------+
//| LOG DETAILED SIGNAL ANALYSIS                                     |
//+------------------------------------------------------------------+
void LogDetailedSignalAnalysis(SignalData &signal, int confidence, MarketData &data)
{
   EnhancedLog("=== SIGNAL ANALYSIS ===", "SIGNAL");
   EnhancedLog("Confidence: " + IntegerToString(confidence) + "/10", "SIGNAL");
   EnhancedLog("Bull Score: " + IntegerToString(signal.bullishScore) + " | Bear Score: " + IntegerToString(signal.bearishScore), "SIGNAL");
   EnhancedLog("Setup Type: " + GetSetupTypeString(signal.setupType), "SIGNAL");
   EnhancedLog("Signal Strength: " + DoubleToString(signal.signalStrength * 100, 1) + "%", "SIGNAL");
   EnhancedLog("Risk Factors: " + (signal.riskFactors == "" ? "NONE" : signal.riskFactors), "SIGNAL");
   EnhancedLog("Components: " + signal.description, "SIGNAL");
   EnhancedLog("Confirmations: HA=" + BoolToString(signal.haConfirmation) + 
              " CCI=" + BoolToString(signal.cciConfirmation) + 
              " WR=" + BoolToString(signal.wrConfirmation) + 
              " ADX=" + BoolToString(signal.adxConfirmation) + 
              " ATR=" + BoolToString(signal.atrConfirmation) + 
              " Vol=" + BoolToString(signal.volumeConfirmation) + 
              " Inter=" + BoolToString(signal.intermarketConfirmation) + 
              " Sess=" + BoolToString(signal.sessionConfirmation), "SIGNAL");
   if(signal.isCounterTrend) EnhancedLog("WARNING: Counter-trend setup detected!", "WARNING");
   if(signal.oscillatorConflicts > 0) EnhancedLog("WARNING: Oscillator conflicts: " + IntegerToString(signal.oscillatorConflicts), "WARNING");
}

//+------------------------------------------------------------------+
//| LOG REJECTED SIGNAL                                             |
//+------------------------------------------------------------------+
void LogRejectedSignal(int confidence, SignalData &signal, MarketData &data)
{
   EnhancedLog("=== SIGNAL REJECTED ===", "REJECT");
   EnhancedLog("Confidence: " + IntegerToString(confidence) + "/10 (Below " + IntegerToString(InpMinConfidence) + ")", "REJECT");
   EnhancedLog("Setup: " + GetSetupTypeString(signal.setupType), "REJECT");
   EnhancedLog("Risks: " + signal.riskFactors, "REJECT");
   EnhancedLog("Session: " + GetSessionString(data.activeSession), "REJECT");
   EnhancedLog("Details: " + signal.description, "REJECT");
   
   EnhancedLogSignal("REJECTED", confidence, 
                    signal.description,
                    GetSetupTypeString(signal.setupType),
                    signal.riskFactors);
}

//+------------------------------------------------------------------+
//| NEW: CALCULATE DYNAMIC STOP LOSS DISTANCE                        |
//+------------------------------------------------------------------+
double CalculateDynamicSLDistance(int confidence, MarketData &data, SignalData &signal)
{
   if(!InpUseSmartLossManagement || !InpUseDynamicSLPlacement)
   {
      // Use standard fixed distance
      return InpBaseStopLoss * 0.01 * 10.0; // 0.01 * 10.0 - corrected from original
   }
   
   // Start with base distance
   double pipValue = 0.01;
   double baseDistance = InpBaseStopLoss * pipValue;
   
   // 1. Adjust by volatility (larger SL for higher volatility)
   double volatilityFactor = MathMin(data.volatilityRatio, 1.5); // Cap at 1.5x
   volatilityFactor = MathMax(volatilityFactor, 0.8); // Floor at 0.8x
   double adjustedDistance = baseDistance * volatilityFactor;
   
   // 2. Adjust by confidence (higher confidence = tighter SL)
   double confidenceAdjustment = 1.2 - ((confidence - 7) * 0.1); // Each point above 7 reduces SL by 10%
   confidenceAdjustment = MathMax(confidenceAdjustment, InpMinSLMultiplier);
   confidenceAdjustment = MathMin(confidenceAdjustment, InpMaxSLMultiplier);
   adjustedDistance *= confidenceAdjustment;
   
   // 3. Adjust by setup type 
   switch(signal.setupType)
   {
      case SETUP_STRONG_TREND:
         adjustedDistance *= 0.9; // Tighter SL for strong trends
         break;
      case SETUP_BREAKOUT:
         adjustedDistance *= 1.1; // Wider SL for breakouts
         break;
      case SETUP_COUNTER_TREND:
         adjustedDistance *= 0.8; // Tighter SL for counter-trend (high risk)
         break;
      default:
         // No additional adjustment
         break;
   }
   
   // 4. Adjust for session (wider during volatile sessions)
   if(data.activeSession == SESSION_OVERLAP)
      adjustedDistance *= 1.1;
   else if(data.activeSession == SESSION_ASIAN)
      adjustedDistance *= 0.9;
   
   // Log the SL distance adjustment
   EnhancedLog("Dynamic SL: Base=" + DoubleToString(baseDistance, 5) + 
              " Final=" + DoubleToString(adjustedDistance, 5) + 
              " (Vol:" + DoubleToString(volatilityFactor, 2) + 
              " Conf:" + DoubleToString(confidenceAdjustment, 2) + ")", "SLM");
   
   return adjustedDistance * 10.0; // Multiply by 10 to restore original scale
}

//+------------------------------------------------------------------+
//| CALCULATE POSITION SIZE - ENSURES EVEN LOTS FOR SCALE-OUT      |
//+------------------------------------------------------------------+
double CalculatePositionSize(int confidence)
{
   double baseLotSize = InpLotSize * currentRiskFactor;
   
   if(InpUseConfidenceSizing)
   {
      double confidenceFactor = InpMinSizeFactor + 
         (InpMaxSizeFactor - InpMinSizeFactor) * (confidence / 10.0);
      baseLotSize *= confidenceFactor;
   }
   
   // NEW: Ensure divisible by 2 for hybrid scale-out system
   if(InpUseHybridSystem)
   {
      double lotStep = symbolInfo.LotsStep();
      
      // Round down to nearest even lot size (divisible by 2)
      baseLotSize = MathFloor(baseLotSize / (2 * lotStep)) * (2 * lotStep);
      
      // Ensure minimum is at least 0.02 (or 2 * broker's minimum)
      double minEvenLot = MathMax(0.02, 2 * symbolInfo.LotsMin());
      baseLotSize = MathMax(baseLotSize, minEvenLot);
      
      EnhancedLog("Hybrid System: Adjusted lot size to " + DoubleToString(baseLotSize, 2) + 
                 " (divisible by 2)", "SYSTEM");
   }
   
   // Apply broker limits
   double maxLot = symbolInfo.LotsMax();
   baseLotSize = MathMin(baseLotSize, maxLot);
   
   return baseLotSize;
}

//+------------------------------------------------------------------+
//| CALCULATE STOP LOSS AND TAKE PROFIT                             |
//+------------------------------------------------------------------+
void CalculateStopLossAndTakeProfit(bool isBuy, MarketData &data, SignalData &signal, int confidence, double &stopLoss, double &takeProfit)
{
   // NEW: Use dynamic SL calculation with Smart Loss Management
   double slDistance = CalculateDynamicSLDistance(confidence, data, signal);
   double tpDistance = InpBaseTakeProfit * 0.01 * 10.0; // Standard TP distance with correction
   
   if(InpUseVolatilityTP && data.atr_current > 0 && data.atr_average > 0)
   {
      double volatilityFactor = data.atr_current / data.atr_average;
      tpDistance *= volatilityFactor;
   }
   
   MqlTick tick;
   SymbolInfoTick(_Symbol, tick);
   
   if(isBuy)
   {
      stopLoss = NormalizeDouble(tick.bid - slDistance, symbolInfo.Digits());
      takeProfit = NormalizeDouble(tick.bid + tpDistance, symbolInfo.Digits());
   }
   else
   {
      stopLoss = NormalizeDouble(tick.ask + slDistance, symbolInfo.Digits());
      takeProfit = NormalizeDouble(tick.ask - tpDistance, symbolInfo.Digits());
   }
   
   // Log the Stop Loss and Take Profit calculations
   EnhancedLog("SL/TP Calculation - SL Distance: " + DoubleToString(slDistance, 5) + 
              " TP Distance: " + DoubleToString(tpDistance, 5), "TRADE");
}

//+------------------------------------------------------------------+
//| EXECUTE BUY ORDER WITH PATTERN TRACKING                         |
//+------------------------------------------------------------------+
bool ExecuteBuyOrder(int confidence, MarketData &data, SignalData &signal)
{
   EnhancedLog("--- Executing BUY Order ---", "TRADE");
   
   double lotSize = CalculatePositionSize(confidence);
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      EnhancedLog("ERROR: Failed to get current tick", "ERROR");
      return false;
   }
   
   double stopLoss, takeProfit;
   CalculateStopLossAndTakeProfit(true, data, signal, confidence, stopLoss, takeProfit);
   
   string comment = StringFormat("GoldDom_BUY_C%d_%d", confidence, totalTrades + 1);
   
   EnhancedLog("BUY Order Details:", "TRADE");
   EnhancedLog("- Lot Size: " + DoubleToString(lotSize, 2), "TRADE");
   EnhancedLog("- Entry: " + DoubleToString(tick.ask, 5), "TRADE");
   EnhancedLog("- Stop Loss: " + DoubleToString(stopLoss, 5) + " (" + 
              DoubleToString((tick.ask - stopLoss) / 0.01, 0) + " pips)", "TRADE");
   EnhancedLog("- Take Profit: " + DoubleToString(takeProfit, 5) + " (" + 
              DoubleToString((takeProfit - tick.ask) / 0.01, 0) + " pips)", "TRADE");
   EnhancedLog("- Setup: " + GetSetupTypeString(signal.setupType), "TRADE");
   EnhancedLog("- Risk Factors: " + signal.riskFactors, "TRADE");
   
   if(tradeManager.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, comment))
   {
      ulong ticket = tradeManager.ResultOrder();
      EnhancedLogTrade("BUY EXECUTED", ticket,
                      StringFormat("Lots:%.2f Entry:%.5f Conf:%d Setup:%s", 
                                  lotSize, tick.ask, confidence, GetSetupTypeString(signal.setupType)),
                      0, confidence);
      
      // Store trade pattern for analysis
      StoreTradePattern(ticket, true, confidence, signal, data, tick.ask, stopLoss, takeProfit);
      
      return true;
   }
   else
   {
      EnhancedLog("BUY order failed - Error: " + IntegerToString(tradeManager.ResultRetcode()) + 
                 " - " + tradeManager.ResultComment(), "ERROR");
      return false;
   }
}

//+------------------------------------------------------------------+
//| EXECUTE SELL ORDER WITH PATTERN TRACKING                        |
//+------------------------------------------------------------------+
bool ExecuteSellOrder(int confidence, MarketData &data, SignalData &signal)
{
   EnhancedLog("--- Executing SELL Order ---", "TRADE");
   
   double lotSize = CalculatePositionSize(confidence);
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      EnhancedLog("ERROR: Failed to get current tick", "ERROR");
      return false;
   }
   
   double stopLoss, takeProfit;
   CalculateStopLossAndTakeProfit(false, data, signal, confidence, stopLoss, takeProfit);
   
   string comment = StringFormat("GoldDom_SELL_C%d_%d", confidence, totalTrades + 1);
   
   EnhancedLog("SELL Order Details:", "TRADE");
   EnhancedLog("- Lot Size: " + DoubleToString(lotSize, 2), "TRADE");
   EnhancedLog("- Entry: " + DoubleToString(tick.bid, 5), "TRADE");
   EnhancedLog("- Stop Loss: " + DoubleToString(stopLoss, 5) + " (" + 
              DoubleToString((stopLoss - tick.bid) / 0.01, 0) + " pips)", "TRADE");
   EnhancedLog("- Take Profit: " + DoubleToString(takeProfit, 5) + " (" + 
              DoubleToString((tick.bid - takeProfit) / 0.01, 0) + " pips)", "TRADE");
   EnhancedLog("- Setup: " + GetSetupTypeString(signal.setupType), "TRADE");
   EnhancedLog("- Risk Factors: " + signal.riskFactors, "TRADE");
   
   if(tradeManager.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, comment))
   {
      ulong ticket = tradeManager.ResultOrder();
      EnhancedLogTrade("SELL EXECUTED", ticket,
                      StringFormat("Lots:%.2f Entry:%.5f Conf:%d Setup:%s",
                                  lotSize, tick.bid, confidence, GetSetupTypeString(signal.setupType)),
                      0, confidence);
      
      // Store trade pattern for analysis
      StoreTradePattern(ticket, false, confidence, signal, data, tick.bid, stopLoss, takeProfit);
      
      return true;
   }
   else
   {
      EnhancedLog("SELL order failed - Error: " + IntegerToString(tradeManager.ResultRetcode()) + 
                 " - " + tradeManager.ResultComment(), "ERROR");
      return false;
   }
}

//+------------------------------------------------------------------+
//| STORE TRADE PATTERN FOR ANALYSIS                                |
//+------------------------------------------------------------------+
void StoreTradePattern(ulong ticket, bool isLong, int confidence, SignalData &signal, 
                      MarketData &data, double entry, double sl, double tp)
{
   if(tradeHistorySize >= ArraySize(tradeHistory))
   {
      ArrayResize(tradeHistory, ArraySize(tradeHistory) + 500);
   }
   
   TradePattern pattern;
   ZeroMemory(pattern);
   
   pattern.ticket = ticket;
   pattern.openTime = TimeCurrent();
   pattern.isLong = isLong;
   pattern.confidence = confidence;
   pattern.setupType = signal.setupType;
   pattern.session = data.activeSession;
   pattern.volatilityRatio = data.volatilityRatio;
   pattern.riskFactors = signal.riskFactors;
   pattern.entry = entry;
   
   // NEW: Store SL distance for Smart Loss Management
   pattern.slDistance = MathAbs(entry - sl);
   
   // Store market context
   pattern.adx = data.adx_current;
   pattern.cci = data.cci_current;
   pattern.wr = data.wr_current;
   pattern.hadHA = signal.haConfirmation;
   pattern.hadOscillator = signal.cciConfirmation || signal.wrConfirmation;
   pattern.hadIntermarket = signal.intermarketConfirmation;
   pattern.hadSession = signal.sessionConfirmation;
   
   // Initialize hybrid system tracking
   pattern.isScaledOut = false;
   pattern.remainingLots = CalculatePositionSize(confidence);
   
   // Initialize Smart Loss Management tracking
   pattern.wasEarlyExit = false;
   pattern.maxDrawdown = 0;
   pattern.capitalSaved = 0;
   
   tradeHistory[tradeHistorySize] = pattern;
   tradeHistorySize++;
}

//+------------------------------------------------------------------+
//| NEW: CALCULATE CURRENT DRAWDOWN PERCENTAGE                       |
//+------------------------------------------------------------------+
double CalculateDrawdownPercent(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return 0;
   
   double openPrice = positionInfo.PriceOpen();
   double currentPrice = positionInfo.PriceCurrent();
   double stopLoss = positionInfo.StopLoss();
   
   // Handle case where SL is not set
   if(stopLoss == 0) return 0;
   
   double drawdownPips = 0;
   double slDistancePips = 0;
   
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      drawdownPips = openPrice - currentPrice;
      slDistancePips = openPrice - stopLoss;
   }
   else
   {
      drawdownPips = currentPrice - openPrice;
      slDistancePips = stopLoss - openPrice;
   }
   
   // Calculate as percentage of stop loss distance
   if(slDistancePips <= 0) return 0;
   
   double drawdownPercent = (drawdownPips / slDistancePips) * 100.0;
   return MathMax(0, drawdownPercent); // Ensure non-negative
}

//+------------------------------------------------------------------+
//| NEW: CHECK EARLY LOSS CONDITIONS                                 |
//+------------------------------------------------------------------+
bool CheckEarlyLossConditions(ulong ticket)
{
   if(!InpUseSmartLossManagement) return false;
   if(!positionInfo.SelectByTicket(ticket)) return false;
   
   // Get position details
   datetime openTime = positionInfo.Time();
   datetime currentTime = TimeCurrent();
   int minutesOpen = (int)((currentTime - openTime) / 60);
   double profit = positionInfo.Profit();
   
   // Skip positions in profit or already scaled out
   if(profit >= 0) return false;
   string comment = positionInfo.Comment();
   if(StringFind(comment, "_SCALED") >= 0) return false;
   
   // Skip positions outside early detection window (older than monitoring period)
   if(minutesOpen > InpEarlyDetectionHours * 60)
   {
      // Only perform early detection during specified hours
      return false;
   }
   
   // Calculate drawdown as % of SL distance
   double drawdownPercent = CalculateDrawdownPercent(ticket);
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   
   // Get current market conditions for analysis
   MarketData data;
   if(!GetMarketData(data)) return false;
   
   // Track reason for early exit if it occurs
   EARLY_EXIT_REASON exitReason = EXIT_DRAWDOWN_THRESHOLD;
   bool shouldExit = false;
   string exitDetails = "";
   
   // Condition 1: Drawdown threshold reached
   if(drawdownPercent >= InpEarlyExitThreshold)
   {
      shouldExit = true;
      exitReason = EXIT_DRAWDOWN_THRESHOLD;
      exitDetails = "Drawdown reached " + DoubleToString(drawdownPercent, 1) + "% of SL distance";
   }
   
   // Condition 2: Momentum shift against position
   if(data.momentumShift)
   {
      bool isMomentumAgainstPosition = false;
      
      if(posType == POSITION_TYPE_BUY && data.rsi_current < InpRSIThreshold)
         isMomentumAgainstPosition = true;
      else if(posType == POSITION_TYPE_SELL && data.rsi_current > (100 - InpRSIThreshold))
         isMomentumAgainstPosition = true;
      
      if(isMomentumAgainstPosition && drawdownPercent >= InpEarlyExitThreshold * 0.7)
      {
         shouldExit = true;
         exitReason = EXIT_MOMENTUM_SHIFT;
         exitDetails = "Momentum shift against position (RSI: " + DoubleToString(data.rsi_current, 1) + 
                     ") with " + DoubleToString(drawdownPercent, 1) + "% drawdown";
      }
   }
   
   // Condition 3: Market structure break
   if(InpUseMarketStructureValidation && data.structureBreak)
   {
      bool isStructureBreakAgainstPosition = false;
      
      if(posType == POSITION_TYPE_BUY && data.swing_low > 0)
         isStructureBreakAgainstPosition = true;
      else if(posType == POSITION_TYPE_SELL && data.swing_high > 0)
         isStructureBreakAgainstPosition = true;
      
      if(isStructureBreakAgainstPosition && drawdownPercent >= InpEarlyExitThreshold * 0.8)
      {
         shouldExit = true;
         exitReason = EXIT_MARKET_STRUCTURE;
         exitDetails = "Market structure break with " + DoubleToString(drawdownPercent, 1) + "% drawdown";
      }
   }
   
   // Execute early exit if conditions met
   if(shouldExit)
   {
      double currentLots = positionInfo.Volume();
      double fullSLLoss = CalculateFullSLLoss(ticket);
      double savedAmount = fullSLLoss - MathAbs(profit);
      
      // Update comment to reflect early exit
      string newComment = comment + "_EARLY_EXIT";
      if(!tradeManager.PositionModify(ticket, 0, 0))
      {
         EnhancedLog("Failed to modify position before early exit", "ERROR");
      }
      
      if(tradeManager.PositionClose(ticket))
      {
         LogSmartLossManagement("EARLY EXIT", ticket, exitDetails, savedAmount);
         
         EnhancedLogTrade("EARLY EXIT", ticket,
                        StringFormat("Closed %.2f lots - %s - After %d minutes - Saved %.2f", 
                                    currentLots, GetExitReasonString(exitReason), minutesOpen, savedAmount),
                        profit);
         
         // Record in trade history
         for(int i = 0; i < tradeHistorySize; i++)
         {
            if(tradeHistory[i].ticket == ticket)
            {
               tradeHistory[i].wasEarlyExit = true;
               tradeHistory[i].earlyExitReason = exitReason;
               tradeHistory[i].capitalSaved = savedAmount;
               break;
            }
         }
         
         return true;
      }
      else
      {
         EnhancedLog("Failed to close position for early exit - Error: " + 
                   IntegerToString(tradeManager.ResultRetcode()), "ERROR");
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| NEW: CALCULATE POTENTIAL FULL STOP LOSS VALUE                    |
//+------------------------------------------------------------------+
double CalculateFullSLLoss(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return 0;
   
   double volume = positionInfo.Volume();
   double openPrice = positionInfo.PriceOpen();
   double stopLoss = positionInfo.StopLoss();
   
   // If no SL set, estimate from history
   if(stopLoss == 0)
   {
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].ticket == ticket && tradeHistory[i].slDistance > 0)
         {
            double estimatedSL;
            if(positionInfo.PositionType() == POSITION_TYPE_BUY)
               estimatedSL = openPrice - tradeHistory[i].slDistance;
            else
               estimatedSL = openPrice + tradeHistory[i].slDistance;
            
            stopLoss = estimatedSL;
            break;
         }
      }
      
      // If still no SL, use default base SL
      if(stopLoss == 0)
      {
         double pipValue = 0.01;
         double slDistance = InpBaseStopLoss * pipValue * 10.0;
         
         if(positionInfo.PositionType() == POSITION_TYPE_BUY)
            stopLoss = openPrice - slDistance;
         else
            stopLoss = openPrice + slDistance;
      }
   }
   
   // Calculate pip value and potential loss
   double tickSize = symbolInfo.TickSize();
   double tickValue = symbolInfo.TickValue();
   double points = MathAbs(openPrice - stopLoss) / tickSize;
   double potentialLoss = points * tickValue * volume;
   
   return potentialLoss;
}

//+------------------------------------------------------------------+
//| NEW: GET EXIT REASON STRING                                      |
//+------------------------------------------------------------------+
string GetExitReasonString(EARLY_EXIT_REASON reason)
{
   switch(reason)
   {
      case EXIT_MOMENTUM_SHIFT: return "MOMENTUM_SHIFT";
      case EXIT_MARKET_STRUCTURE: return "MARKET_STRUCTURE";
      case EXIT_DRAWDOWN_THRESHOLD: return "DRAWDOWN_THRESHOLD";
      case EXIT_CONFLUENCE: return "CONFLUENCE";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| CHECK FOR HYBRID SCALE-OUT OPPORTUNITY - ENHANCED VERSION       |
//+------------------------------------------------------------------+
void CheckHybridScaleOut(ulong ticket)
{
   if(!InpUseHybridSystem) return;
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   datetime openTime = positionInfo.Time();
   datetime currentTime = TimeCurrent();
   int hoursOpen = (int)((currentTime - openTime) / 3600);
   
   // Check if enough time has passed
   if(hoursOpen < InpScaleOutTimeHours) return;
   
   // Get current profit
   double profit = positionInfo.Profit();
   
   // Check if already scaled out
   string comment = positionInfo.Comment();
   if(StringFind(comment, "_SCALED") >= 0) return;
   
   if(profit > 0)
   {
      // Trade is profitable - check if we can split
      double currentLots = positionInfo.Volume();
      double minLotForSplit = symbolInfo.LotsStep() * 2; // Need at least 2x lot step to split
      
      if(currentLots >= minLotForSplit)
      {
         // Normal scale-out (50%)
         double scaleOutLots = currentLots / 2.0;
         
         if(tradeManager.PositionClosePartial(ticket, scaleOutLots))
         {
            EnhancedLogTrade("HYBRID SCALE-OUT", ticket,
                           StringFormat("Closed 50%% (%.2f lots) after %d hours - Profit secured", 
                                       scaleOutLots, hoursOpen),
                           profit / 2.0);
            
            // Update the comment to mark as scaled
            if(!tradeManager.PositionModify(ticket, positionInfo.StopLoss(), positionInfo.TakeProfit(), comment + "_SCALED"))
            {
               EnhancedLog("Failed to update position comment after scale-out", "WARNING");
            }
            
            UpdateTradePatternScaleOut(ticket, scaleOutLots);
         }
         else
         {
            EnhancedLog("Failed to scale out position " + IntegerToString((int)ticket), "ERROR");
         }
      }
      else
      {
         // Can't split - close entire position to secure profit
         if(tradeManager.PositionClose(ticket))
         {
            EnhancedLogTrade("HYBRID FULL CLOSE", ticket,
                           StringFormat("Closed entire position (%.2f lots) - Too small to split after %d hours", 
                                       currentLots, hoursOpen),
                           profit);
         }
         else
         {
            EnhancedLog("Failed to close small position " + IntegerToString((int)ticket), "ERROR");
         }
      }
   }
   else
   {
      // Trade not profitable after scale-out hours - apply strict exit
      ApplyStrictExitForUnprofitable(ticket);
   }
}

//+------------------------------------------------------------------+
//| APPLY STRICT EXIT FOR UNPROFITABLE TRADES AFTER HOURS           |
//+------------------------------------------------------------------+
void ApplyStrictExitForUnprofitable(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double openPrice = positionInfo.PriceOpen();
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double pipValue = 0.01;
   double currentPips = 0;
   
   if(posType == POSITION_TYPE_BUY)
      currentPips = (tick.bid - openPrice) / pipValue;
   else
      currentPips = (openPrice - tick.ask) / pipValue;
   
   // Very strict criteria for unprofitable trades after scale-out hours
   // Close if it gets even 5 pips in profit
   if(currentPips >= 5)
   {
      if(tradeManager.PositionClose(ticket))
      {
         EnhancedLogTrade("STRICT EXIT", ticket,
                         StringFormat("Closed at %.1f pips - Unprofitable trade secured small profit", 
                                     currentPips),
                         positionInfo.Profit());
                         
         EnhancedLog("Applied strict exit to unprofitable trade after scale-out time", "HYBRID");
      }
      else
      {
         EnhancedLog("Failed to apply strict exit to position " + IntegerToString((int)ticket), "ERROR");
      }
   }
}

//+------------------------------------------------------------------+
//| MANAGE REMAINING POSITION DYNAMICALLY                           |
//+------------------------------------------------------------------+
void ManageRemainingPosition(ulong ticket)
{
   if(!InpUseHybridSystem) return;
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   string comment = positionInfo.Comment();
   if(StringFind(comment, "_SCALED") < 0) return; // Not scaled out yet
   
   // Get market data for dynamic decision
   MarketData marketData;
   if(!GetMarketData(marketData)) return;
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double openPrice = positionInfo.PriceOpen();
   double currentProfit = positionInfo.Profit();
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double pipValue = 0.01;
   double currentPips = 0;
   
   if(posType == POSITION_TYPE_BUY)
      currentPips = (tick.bid - openPrice) / pipValue;
   else
      currentPips = (openPrice - tick.ask) / pipValue;
   
   // Analyze market conditions for dynamic exit
   bool isStrongTrend = (marketData.adx_current >= InpTrendThreshold);
   bool isHighVol = (marketData.volatilityRatio >= InpHighVolMultiplier);
   bool isLowVol = (marketData.volatilityRatio <= InpLowVolMultiplier);
   bool isWeakTrend = (marketData.adx_current < 20);
   
   string exitReason = "";
   bool shouldExit = false;
   
   // Decision logic for remaining 50%
   if(isStrongTrend && isHighVol)
   {
      // Let it run with trailing stop - best conditions
      UpdateTrailingStop(ticket);
      EnhancedLog("Remaining position: Strong trend + high vol - letting run with trailing stop", "HYBRID");
   }
   else if(isWeakTrend && isLowVol)
   {
      // Exit on next 30 pips or any profit over 20 pips
      if(currentPips >= InpDynamicExitPips)
      {
         shouldExit = true;
         exitReason = "Weak trend + low volatility - took quick profit";
      }
   }
   else if(isWeakTrend || isLowVol)
   {
      // Mixed conditions - moderate exit strategy
      if(currentPips >= InpDynamicExitPips * 1.5) // 45 pips
      {
         shouldExit = true;
         exitReason = "Mixed conditions - moderate profit target hit";
      }
   }
   else
   {
      // Default management with trailing stop
      UpdateTrailingStop(ticket);
   }
   
   // Execute exit if determined
   if(shouldExit && currentProfit > 0)
   {
      if(tradeManager.PositionClose(ticket))
      {
         EnhancedLogTrade("HYBRID DYNAMIC EXIT", ticket,
                         StringFormat("Remaining 50%% closed - %s - Pips: %.1f", 
                                     exitReason, currentPips),
                         currentProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| UPDATE TRADE PATTERN FOR SCALE-OUT                              |
//+------------------------------------------------------------------+
void UpdateTradePatternScaleOut(ulong ticket, double scaledLots)
{
   // Find the trade pattern and update it
   for(int i = 0; i < tradeHistorySize; i++)
   {
      if(tradeHistory[i].ticket == ticket)
      {
         tradeHistory[i].isScaledOut = true;
         tradeHistory[i].scaleOutTime = TimeCurrent();
         tradeHistory[i].remainingLots = tradeHistory[i].remainingLots - scaledLots;
         
         MqlTick tick;
         if(SymbolInfoTick(_Symbol, tick))
         {
            tradeHistory[i].scaleOutPrice = tradeHistory[i].isLong ? tick.bid : tick.ask;
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| MANAGE EXISTING POSITIONS - ENHANCED WITH SMART LOSS MANAGEMENT  |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   int managed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!positionInfo.SelectByIndex(i)) continue;
      if(positionInfo.Magic() != InpMagicNumber || positionInfo.Symbol() != _Symbol) continue;
      
      managed++;
      ulong ticket = positionInfo.Ticket();
      
      // NEW: Apply Smart Loss Management first (if enabled)
      if(InpUseSmartLossManagement)
      {
         // Check for early loss exit conditions
         if(CheckEarlyLossConditions(ticket))
         {
            // Position was closed by early exit, continue to next
            continue;
         }
      }
      
      // HYBRID SYSTEM: Check for scale-out opportunity
      if(InpUseHybridSystem)
      {
         CheckHybridScaleOut(ticket);
         ManageRemainingPosition(ticket);
      }
      else
      {
         // Original management for non-hybrid mode
         if(InpUseTrailingStop)
            UpdateTrailingStop(ticket);
         
         if(InpUsePartialClose)
            CheckPartialClose(ticket);
         
         if(InpUseTimeDecay)
            CheckTimeDecayExit(ticket);
      }
   }
   
   if(managed > 0)
   {
      string managementMethod = "";
      if(InpUseSmartLossManagement && InpUseHybridSystem)
         managementMethod = "Smart Loss + Hybrid System";
      else if(InpUseSmartLossManagement)
         managementMethod = "Smart Loss Management";
      else if(InpUseHybridSystem)
         managementMethod = "Hybrid Mode";
      else
         managementMethod = "Standard Mode";
         
      EnhancedLog("Managing " + IntegerToString(managed) + " active positions (" + 
                 managementMethod + ")", "MANAGE");
   }
}

//+------------------------------------------------------------------+
//| UPDATE TRAILING STOP                                            |
//+------------------------------------------------------------------+
void UpdateTrailingStop(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double openPrice = positionInfo.PriceOpen();
   double currentSL = positionInfo.StopLoss();
   double currentTP = positionInfo.TakeProfit();
   
   double pipValue = 0.01;
   double trailingStart = InpTrailingStart * pipValue;
   double trailingStep = InpTrailingStep * pipValue;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   if(posType == POSITION_TYPE_BUY)
   {
      double profit = tick.bid - openPrice;
      if(profit >= trailingStart)
      {
         double newSL = NormalizeDouble(tick.bid - trailingStep, symbolInfo.Digits());
         if(newSL > currentSL)
         {
            if(tradeManager.PositionModify(ticket, newSL, currentTP))
            {
               EnhancedLogTrade("TRAILING STOP", ticket,
                               StringFormat("Updated SL to %.5f (Profit: %.1f pips)", 
                                          newSL, profit / pipValue));
            }
         }
      }
   }
   else
   {
      double profit = openPrice - tick.ask;
      if(profit >= trailingStart)
      {
         double newSL = NormalizeDouble(tick.ask + trailingStep, symbolInfo.Digits());
         if(newSL < currentSL || currentSL == 0)
         {
            if(tradeManager.PositionModify(ticket, newSL, currentTP))
            {
               EnhancedLogTrade("TRAILING STOP", ticket,
                               StringFormat("Updated SL to %.5f (Profit: %.1f pips)",
                                          newSL, profit / pipValue));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CHECK PARTIAL CLOSE                                             |
//+------------------------------------------------------------------+
void CheckPartialClose(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return;
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double openPrice = positionInfo.PriceOpen();
   string comment = positionInfo.Comment();
   
   double pipValue = 0.01;
   double partialLevel = InpPartialPips1 * pipValue;
   
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   
   double currentProfit = (posType == POSITION_TYPE_BUY) ? 
                         (tick.bid - openPrice) : 
                         (openPrice - tick.ask);
   
   if(currentProfit >= partialLevel && StringFind(comment, "Partial") == -1)
   {
      double partialVolume = positionInfo.Volume() * InpPartialPercent1;
      if(tradeManager.PositionClosePartial(ticket, partialVolume))
      {
         EnhancedLogTrade("PARTIAL CLOSE", ticket,
                         StringFormat("Closed %.2f lots at %.1f pips profit",
                                    partialVolume, currentProfit / pipValue));
      }
   }
}

//+------------------------------------------------------------------+
//| CHECK TIME DECAY EXIT                                           |
//+------------------------------------------------------------------+
void CheckTimeDecayExit(ulong ticket)
{
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   datetime currentTime = TimeCurrent();
   int hoursOpen = (int)((currentTime - openTime) / 3600);
   
   if(hoursOpen >= InpTimeDecayHours)
   {
      if(tradeManager.PositionClose(ticket))
      {
         EnhancedLogTrade("TIME DECAY EXIT", ticket,
                         StringFormat("Closed after %d hours", hoursOpen));
      }
   }
}

//+------------------------------------------------------------------+
//| TRADE TRANSACTION EVENT                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   
   if(trans.deal_type == DEAL_TYPE_SELL) // Exit deal
   {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
      {
         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(magic == InpMagicNumber)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
            ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
            
            // Find the trade pattern and complete it
            CompleteTradePattern(positionId, profit, closeTime, dealComment);
            
            // NEW: Handle early exit differently for consecutive loss counting
            bool isEarlyExit = (StringFind(dealComment, "EARLY_EXIT") >= 0);
            
            // Update statistics
            totalPnL += profit;
            GlobalVariableSet("GD_TotalPnL", totalPnL);
            
            if(profit > 0)
            {
               profitableTrades++;
               GlobalVariableSet("GD_WinCount", profitableTrades);
               winStreak++;
               maxWinStreak = MathMax(maxWinStreak, winStreak);
               consecutiveLosses = 0;
            }
            else if(profit < 0)
            {
               // NEW: Weight losses differently for early exits
               if(isEarlyExit)
               {
                  // Count early exits as partial losses for risk reduction
                  double fullLoss = CalculateFullSLLoss(positionId);
                  if(fullLoss > 0)
                  {
                     double lossRatio = MathAbs(profit) / fullLoss;
                     consecutiveLosses += lossRatio;
                     EnhancedLog("Early exit: Counted as " + DoubleToString(lossRatio, 2) + 
                               " of a loss (saved " + DoubleToString(1.0 - lossRatio, 2) + 
                               " of potential loss)", "SLM");
                  }
                  else
                  {
                     consecutiveLosses += 0.5; // Default to half a loss if can't calculate
                  }
               }
               else
               {
                  // Full loss
                  consecutiveLosses++;
               }
               
               winStreak = 0;
               currentRiskFactor = MathMax(InpRiskReductionFactor, 
                                          1.0 - (consecutiveLosses * (1.0 - InpRiskReductionFactor)));
            }
            
            EnhancedLogTrade("TRADE COMPLETED", positionId,
                            StringFormat("PnL:%.2f Result:%s Duration:%d min",
                                       profit, profit > 0 ? "WIN" : "LOSS",
                                       (int)((closeTime - (datetime)PositionGetInteger(POSITION_TIME)) / 60)),
                            profit);
            
            EnhancedLog("Updated Stats: Total=" + IntegerToString(totalTrades) + 
                       " Winners=" + IntegerToString(profitableTrades) + 
                       " TotalPnL=" + DoubleToString(totalPnL, 2) + 
                       " ConsecLosses=" + DoubleToString(consecutiveLosses, 2), "STATS");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| COMPLETE TRADE PATTERN ANALYSIS                                 |
//+------------------------------------------------------------------+
void CompleteTradePattern(ulong positionId, double profit, datetime closeTime, string comment = "")
{
   // Find the corresponding trade pattern
   for(int i = 0; i < tradeHistorySize; i++)
   {
      if(tradeHistory[i].ticket == positionId)
      {
         tradeHistory[i].closeTime = closeTime;
         tradeHistory[i].pnl = profit;
         tradeHistory[i].durationHours = (int)((closeTime - tradeHistory[i].openTime) / 3600);
         
         // Determine exit reason
         if(StringFind(comment, "EARLY_EXIT") >= 0)
            tradeHistory[i].exitReason = "EARLY_EXIT";
         else if(profit > 0)
            tradeHistory[i].exitReason = "PROFIT";
         else
            tradeHistory[i].exitReason = "LOSS";
         
         // Export to pattern CSV
         if(InpExportCSV && InpAnalyzePatterns)
         {
            ExportTradePatternToCSV(tradeHistory[i]);
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| EXPORT TRADE PATTERN TO CSV                                     |
//+------------------------------------------------------------------+
void ExportTradePatternToCSV(TradePattern &pattern)
{
   string patternFile = StringSubstr(g_AnalysisCSV, 0, StringLen(g_AnalysisCSV) - 4) + "_patterns.csv";
   
   // Create header if file doesn't exist
   if(!FileIsExist(patternFile))
   {
      int handle = FileOpen(patternFile, FILE_WRITE|FILE_CSV);
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, "Ticket", "Type", "Confidence", "Setup", "Session", 
                  "VolatilityRatio", "RiskFactors", "ADX", "CCI", "WR", 
                  "HA_Conf", "OSC_Conf", "Inter_Conf", "Sess_Conf", "PnL", "Result", "Duration", 
                  "ScaledOut", "EarlyExit", "ExitReason", "CapitalSaved");
         FileClose(handle);
      }
   }
   
   int handle = FileOpen(patternFile, FILE_WRITE|FILE_READ|FILE_CSV);
   if(handle != INVALID_HANDLE)
   {
      FileSeek(handle, 0, SEEK_END);
      FileWrite(handle, 
                IntegerToString((int)pattern.ticket),
                pattern.isLong ? "BUY" : "SELL",
                IntegerToString(pattern.confidence),
                GetSetupTypeString(pattern.setupType),
                GetSessionString(pattern.session),
                DoubleToString(pattern.volatilityRatio, 2),
                pattern.riskFactors,
                DoubleToString(pattern.adx, 2),
                DoubleToString(pattern.cci, 2),
                DoubleToString(pattern.wr, 2),
                BoolToString(pattern.hadHA),
                BoolToString(pattern.hadOscillator),
                BoolToString(pattern.hadIntermarket),
                BoolToString(pattern.hadSession),
                DoubleToString(pattern.pnl, 2),
                pattern.pnl > 0 ? "WIN" : "LOSS",
                IntegerToString(pattern.durationHours),
                BoolToString(pattern.isScaledOut),
                BoolToString(pattern.wasEarlyExit),
                pattern.exitReason,
                DoubleToString(pattern.capitalSaved, 2));
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| EXPORT PATTERN ANALYSIS                                         |
//+------------------------------------------------------------------+
void ExportPatternAnalysis()
{
   if(tradeHistorySize == 0) return;
   
   string analysisFile = StringSubstr(g_ReportFile, 0, StringLen(g_ReportFile) - 4) + "_analysis.txt";
   int handle = FileOpen(analysisFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   
   FileWriteString(handle, "===== GOLD DOMINATION PATTERN ANALYSIS =====\r\n");
   FileWriteString(handle, "Generated: " + TimeToString(TimeCurrent()) + "\r\n");
   FileWriteString(handle, "Total Patterns Analyzed: " + IntegerToString(tradeHistorySize) + "\r\n\r\n");
   
   // Analyze by setup type
   FileWriteString(handle, "=== ANALYSIS BY SETUP TYPE ===\r\n");
   for(int setupType = 0; setupType <= 5; setupType++)
   {
      int setupWins = 0, setupLosses = 0;
      double setupPnL = 0;
      
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].setupType == setupType)
         {
            setupPnL += tradeHistory[i].pnl;
            if(tradeHistory[i].pnl > 0) setupWins++;
            else setupLosses++;
         }
      }
      
      if(setupWins + setupLosses > 0)
      {
         FileWriteString(handle, GetSetupTypeString((TRADE_SETUP_TYPE)setupType) + 
                       ": " + IntegerToString(setupWins) + "W/" + IntegerToString(setupLosses) + "L " +
                       "(" + DoubleToString((double)setupWins/(setupWins+setupLosses)*100, 1) + "%) " +
                       "PnL: " + DoubleToString(setupPnL, 2) + "\r\n");
      }
   }
   
   // Analyze by confidence level
   FileWriteString(handle, "\r\n=== ANALYSIS BY CONFIDENCE LEVEL ===\r\n");
   for(int conf = 6; conf <= 10; conf++)
   {
      int confWins = 0, confLosses = 0;
      double confPnL = 0;
      
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].confidence == conf)
         {
            confPnL += tradeHistory[i].pnl;
            if(tradeHistory[i].pnl > 0) confWins++;
            else confLosses++;
         }
      }
      
      if(confWins + confLosses > 0)
      {
         FileWriteString(handle, "Confidence " + IntegerToString(conf) + "/10: " + 
                       IntegerToString(confWins) + "W/" + IntegerToString(confLosses) + "L " +
                       "(" + DoubleToString((double)confWins/(confWins+confLosses)*100, 1) + "%) " +
                       "PnL: " + DoubleToString(confPnL, 2) + "\r\n");
      }
   }
   
   // NEW: Smart Loss Management Analysis
   if(InpUseSmartLossManagement)
   {
      FileWriteString(handle, "\r\n=== SMART LOSS MANAGEMENT ANALYSIS ===\r\n");
      int earlyExitTrades = 0;
      double totalSaved = 0;
      
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].wasEarlyExit)
         {
            earlyExitTrades++;
            totalSaved += tradeHistory[i].capitalSaved;
         }
      }
      
      FileWriteString(handle, "Early Exits: " + IntegerToString(earlyExitTrades) + 
                    " (" + DoubleToString((double)earlyExitTrades/tradeHistorySize*100, 1) + "%)\r\n");
      FileWriteString(handle, "Estimated Capital Saved: " + DoubleToString(totalSaved, 2) + "\r\n");
      
      // Analyze by exit reason
      int momentumShiftExits = 0;
      int marketStructureExits = 0;
      int drawdownExits = 0;
      int confluenceExits = 0;
      
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].wasEarlyExit)
         {
            switch(tradeHistory[i].earlyExitReason)
            {
               case EXIT_MOMENTUM_SHIFT: momentumShiftExits++; break;
               case EXIT_MARKET_STRUCTURE: marketStructureExits++; break;
               case EXIT_DRAWDOWN_THRESHOLD: drawdownExits++; break;
               case EXIT_CONFLUENCE: confluenceExits++; break;
            }
         }
      }
      
      if(earlyExitTrades > 0)
      {
         FileWriteString(handle, "\nExit Reasons:\r\n");
         FileWriteString(handle, "- Momentum Shift: " + IntegerToString(momentumShiftExits) + 
                       " (" + DoubleToString((double)momentumShiftExits/earlyExitTrades*100, 1) + "%)\r\n");
         FileWriteString(handle, "- Market Structure: " + IntegerToString(marketStructureExits) + 
                       " (" + DoubleToString((double)marketStructureExits/earlyExitTrades*100, 1) + "%)\r\n");
         FileWriteString(handle, "- Drawdown Threshold: " + IntegerToString(drawdownExits) + 
                       " (" + DoubleToString((double)drawdownExits/earlyExitTrades*100, 1) + "%)\r\n");
         FileWriteString(handle, "- Confluence: " + IntegerToString(confluenceExits) + 
                       " (" + DoubleToString((double)confluenceExits/earlyExitTrades*100, 1) + "%)\r\n");
      }
   }
   
   // Analyze hybrid system performance
   if(InpUseHybridSystem)
   {
      FileWriteString(handle, "\r\n=== HYBRID SYSTEM ANALYSIS ===\r\n");
      int scaledOutTrades = 0;
      for(int i = 0; i < tradeHistorySize; i++)
      {
         if(tradeHistory[i].isScaledOut) scaledOutTrades++;
      }
      FileWriteString(handle, "Trades with scale-out: " + IntegerToString(scaledOutTrades) + 
                    " (" + DoubleToString((double)scaledOutTrades/tradeHistorySize*100, 1) + "%)\r\n");
   }
   
   FileWriteString(handle, "\r\n===== ANALYSIS COMPLETE =====\r\n");
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| GENERATE FINAL REPORT                                           |
//+------------------------------------------------------------------+
void GenerateFinalReport()
{
   int handle = FileOpen(g_ReportFile, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   
   // Move to end to append final summary
   FileSeek(handle, 0, SEEK_END);
   
   string finalReport = StringFormat(
      "\r\n\r\n===== FINAL PERFORMANCE SUMMARY =====\r\n"
      "Test Duration: %s to %s\r\n"
      "Initial Balance: %.2f\r\n"
      "Final Balance: %.2f\r\n"
      "Total P&L: %.2f\r\n"
      "Total Return: %.2f%%\r\n\r\n"
      "=== TRADING STATISTICS ===\r\n"
      "Total Trades Executed: %d\r\n"
      "Signals Rejected: %d\r\n"
      "Signal Acceptance Rate: %.1f%%\r\n"
      "Profitable Trades: %d (%.1f%%)\r\n"
      "Average P&L per Trade: %.2f\r\n"
      "Max Win Streak: %d\r\n"
      "Max Consecutive Losses: %d\r\n"
      "Current Risk Factor: %.2f\r\n"
      "Hybrid System: %s\r\n",
      TimeToString((datetime)GlobalVariableGet("GD_StartTime"), TIME_DATE|TIME_MINUTES),
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
      AccountInfoDouble(ACCOUNT_BALANCE) - totalPnL,
      AccountInfoDouble(ACCOUNT_BALANCE),
      totalPnL,
      totalPnL / (AccountInfoDouble(ACCOUNT_BALANCE) - totalPnL) * 100,
      totalTrades,
      rejectedSignalsCount,
      totalTrades + rejectedSignalsCount > 0 ? (double)totalTrades/(totalTrades + rejectedSignalsCount)*100 : 0,
      profitableTrades,
      totalTrades > 0 ? (double)profitableTrades/totalTrades*100 : 0,
      totalTrades > 0 ? totalPnL/totalTrades : 0,
      maxWinStreak,
      (int)consecutiveLosses, // Cast to int for display
      currentRiskFactor,
      InpUseHybridSystem ? "ENABLED" : "DISABLED"
   );
   
   // NEW: Add Smart Loss Management stats
   if(InpUseSmartLossManagement)
   {
      finalReport += StringFormat(
         "\r\n=== SMART LOSS MANAGEMENT STATISTICS ===\r\n"
         "Early Exits: %d\r\n"
         "Estimated Capital Saved: %.2f\r\n"
         "Average Savings per Early Exit: %.2f\r\n",
         earlyExitCount,
         capitalSaved,
         earlyExitCount > 0 ? capitalSaved / earlyExitCount : 0
      );
   }
   
   finalReport += StringFormat(
      "\r\n=== LOG FILES CREATED ===\r\n"
      "Main Log: %s\r\n"
      "Trade Log: %s\r\n"
      "Signal Log: %s\r\n"
      "Analysis CSV: %s\r\n"
      "Final Report: %s\r\n"
      "Total Log Entries: %d\r\n\r\n"
      "===== REPORT COMPLETED =====\r\n",
      g_MainLogFile,
      g_TradeLogFile,
      g_SignalLogFile,
      g_AnalysisCSV,
      g_ReportFile,
      g_LogCounter
   );
   
   FileWriteString(handle, finalReport);
   FileFlush(handle);
   FileClose(handle);
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                               |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && 
         positionInfo.Magic() == InpMagicNumber && 
         positionInfo.Symbol() == _Symbol)
         count++;
   }
   return count;
}

void ReleaseIndicators()
{
   if(handleHA != INVALID_HANDLE) IndicatorRelease(handleHA);
   if(handleCCI != INVALID_HANDLE) IndicatorRelease(handleCCI);
   if(handleWR != INVALID_HANDLE) IndicatorRelease(handleWR);
   if(handleADX != INVALID_HANDLE) IndicatorRelease(handleADX);
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleDXY != INVALID_HANDLE) IndicatorRelease(handleDXY);
   if(handleVIX != INVALID_HANDLE) IndicatorRelease(handleVIX);
   
   // NEW: Release Smart Loss Management indicators
   if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
   
   EnhancedLog("All indicators released", "SYSTEM");
}

string GetSetupTypeString(TRADE_SETUP_TYPE setupType)
{
   switch(setupType)
   {
      case SETUP_STRONG_TREND: return "STRONG_TREND";
      case SETUP_MODERATE_TREND: return "MODERATE_TREND";
      case SETUP_WEAK_TREND: return "WEAK_TREND";
      case SETUP_COUNTER_TREND: return "COUNTER_TREND";
      case SETUP_BREAKOUT: return "BREAKOUT";
      case SETUP_RANGE_REVERSAL: return "RANGE_REVERSAL";
      default: return "UNKNOWN";
   }
}

string GetSessionString(SESSION_TYPE session)
{
   switch(session)
   {
      case SESSION_LONDON: return "LONDON";
      case SESSION_NY: return "NY";
      case SESSION_OVERLAP: return "OVERLAP";
      case SESSION_ASIAN: return "ASIAN";
      case SESSION_OFF_HOURS: return "OFF_HOURS";
      default: return "UNKNOWN";
   }
}

string BoolToString(bool value)
{
   return value ? "true" : "false";
}
//+------------------------------------------------------------------+
