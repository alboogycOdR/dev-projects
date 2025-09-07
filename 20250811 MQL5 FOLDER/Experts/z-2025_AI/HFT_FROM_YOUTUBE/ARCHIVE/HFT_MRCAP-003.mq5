//+------------------------------------------------------------------+
//|                                                    HFT_MRCAP.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "3.00"
/*

ea info

The EA primarily relies on its dynamic trailing stop loss to close profitable trades. For losing trades, the initial calculated stop loss is the main exit. Additionally, partial profit taking can reduce position size, and a time-based exit acts as a failsafe to prevent positions from staying open indefinitely.
The absence of a fixed TakeProfit encourages letting profits run as far as the trailing stop will allow, which is a common strategy for capturing trends.


TODO:
String Operations in Hot Path: The extensive use of PrintFormat() for debugging, even when conditions aren't met, creates unnecessary string formatting overhead. Consider implementing a debug level system that completely bypasses string formatting when debugging is disabled.
Single-Direction Bias: The EA places both buy and sell orders but doesn't appear to implement any directional bias based on market conditions. Consider incorporating a trend filter that biases order placement in the direction of the larger timeframe trend, potentially improving win rates.
Session-Based Optimization: While the EA adjusts parameters for different trading sessions, it doesn't account for session-specific volatility patterns. Consider implementing session-specific volatility multipliers, particularly for the Asian session where the current parameters may be too aggressive.


*/
#include <Trade\Trade.mqh>

// Forward declarations
class PerformanceMonitor;
class RiskManager;
class ErrorHandler;
class ConfigManager;

//+------------------------------------------------------------------+
//| CircularBuffer Class                                             |
//+------------------------------------------------------------------+
class CircularBuffer
{
private:
   double         m_data[];       // Dynamic array to store buffer elements
   int            m_size;         // Maximum size of the buffer
   int            m_head;         // Index for the next element to be added
   int            m_count;        // Current number of elements in the buffer

public:
   // Constructor
   CircularBuffer(int bufferSize)
   {
      m_size = bufferSize;
      if(m_size > 0)
         ArrayResize(m_data, m_size);
      else
         ArrayResize(m_data, 0); // Handle zero or negative size
      m_head = 0;
      m_count = 0;
   }

   // Adds an element to the buffer
   void Add(double value)
   {
      if(m_size <= 0) return; // Do nothing if buffer size is not positive

      m_data[m_head] = value;
      m_head = (m_head + 1) % m_size;
      if(m_count < m_size)
         m_count++;
   }

   // Calculates the average of elements in the buffer
   double GetAverage()
   {
      if(m_count == 0) return 0.0;

      double sum = 0.0;
      for(int i = 0; i < m_count; i++)
      {
         // Correctly iterate through elements in a circular buffer manner
         // The oldest element is at m_head if m_count == m_size
         // or data[0] if m_head > m_count
         int index = (m_head - m_count + i + m_size) % m_size;
         sum += m_data[index];
      }
      return sum / m_count;
   }
   
   // Method to clear the buffer
   void Clear()
   {
      m_head = 0;
      m_count = 0;
      // Optionally, clear the array data if needed, though not strictly necessary
      // for functionality as new data will overwrite old.
      // if(m_size > 0) ArrayInitialize(m_data, 0.0);
   }
};
//+------------------------------------------------------------------+
//| RiskManager Class                                                |
//+------------------------------------------------------------------+
class RiskManager
{
private:
   double   m_dailyMaxRiskPercent; // Max daily risk as a percentage (e.g., 2.0 for 2%)
   double   m_dailyCurrentRiskAmount; // Current accumulated risk for the day (in account currency)
   int      m_consecutiveLossLimit;
   int      m_consecutiveLosses;
   datetime m_lastRiskResetTime;   // Tracks the start of the current trading day for risk calculation
   string   m_eaSymbol; // Store the symbol this risk manager instance is for

public:
   RiskManager(double maxRiskPercent, int maxConsecutiveLosses, string symbol)
   {
      m_dailyMaxRiskPercent = maxRiskPercent / 100.0; // Store as fraction
      m_dailyCurrentRiskAmount = 0;
      m_consecutiveLossLimit = maxConsecutiveLosses;
      m_consecutiveLosses = 0;
      m_lastRiskResetTime = 0; // Will be set on first check or trade
      m_eaSymbol = symbol;     // Store symbol for relevant history/deal checks
      ResetDailyRiskIfNeeded(); // Initial check
   }

   void ResetDailyRiskIfNeeded()
   {
      datetime currentTime = TimeCurrent();
      MqlDateTime dtCurrent, dtLastReset;
      TimeToStruct(currentTime, dtCurrent);
      TimeToStruct(m_lastRiskResetTime, dtLastReset);

      // Reset if it's a new day or if it hasn't been set yet (m_lastRiskResetTime == 0)
      if (m_lastRiskResetTime == 0 || dtCurrent.day != dtLastReset.day || dtCurrent.mon != dtLastReset.mon || dtCurrent.year != dtLastReset.year)
      {
         m_dailyCurrentRiskAmount = 0;
         // m_consecutiveLosses = 0; // Consecutive losses usually don't reset daily, but on a win. EA can reset it if desired.
         m_lastRiskResetTime = currentTime;
         PrintFormat("%s RiskManager: Daily risk reset. Current Day: %04d.%02d.%02d", m_eaSymbol, dtCurrent.year, dtCurrent.mon, dtCurrent.day);
      }
   }

   // Calculates risk amount for a potential trade
   double CalculateTradeRiskAmount(double lotSize, double stopLossPips)
   {
      if (stopLossPips <= 0) return 0; // Cannot calculate risk without SL

      double tickSize = SymbolInfoDouble(m_eaSymbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(m_eaSymbol, SYMBOL_TRADE_TICK_VALUE);
      if (tickSize == 0) return 0; // Avoid division by zero

      // stopLossPips is in traditional pips (0.0001 for EURUSD, 0.01 for USDJPY)
      // Convert to price units by multiplying by pip size
      double pipSize = (_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point;
      double stopLossPriceUnits = stopLossPips * pipSize;
      double riskAmount = (stopLossPriceUnits / tickSize) * tickValue * lotSize;
      
      // Debug logging for first few calculations
      static int debugCount = 0;
      if(debugCount < 3) {
         PrintFormat("%s RiskCalc DEBUG: SLPips=%.1f, PipSize=%.5f, SLPriceUnits=%.5f, TickSize=%.5f, TickValue=%.2f, LotSize=%.2f, RiskAmount=%.2f", 
                     m_eaSymbol, stopLossPips, pipSize, stopLossPriceUnits, tickSize, tickValue, lotSize, MathAbs(riskAmount));
         debugCount++;
      }
      
      return MathAbs(riskAmount); // Risk is always positive
   }

   bool IsTradeAllowed(double lotSize, double stopLossPips) // stopLossPips is in pips, not points
   {
      ResetDailyRiskIfNeeded();

      double potentialRiskAmount = CalculateTradeRiskAmount(lotSize, stopLossPips); // stopLossPips should already be in pips
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double maxAllowedDailyRiskAmount = accountBalance * m_dailyMaxRiskPercent;

      if (m_dailyCurrentRiskAmount + potentialRiskAmount > maxAllowedDailyRiskAmount)
      {
         PrintFormat("%s RiskManager: Daily risk limit would be exceeded. Current: %.2f, Potential: %.2f, Max: %.2f", 
                     m_eaSymbol, m_dailyCurrentRiskAmount, potentialRiskAmount, maxAllowedDailyRiskAmount);
         return false;
      }
      if (m_consecutiveLosses >= m_consecutiveLossLimit)
      {
         PrintFormat("%s RiskManager: Consecutive loss limit reached (%d). No new trades allowed until reset.", m_eaSymbol, m_consecutiveLosses);
         return false;
      }
      return true;
   }

   void RegisterTradeRisk(double lotSize, double stopLossPips)
   {
      ResetDailyRiskIfNeeded(); // Ensure daily tracking is current
      double riskAmount = CalculateTradeRiskAmount(lotSize, stopLossPips);
      m_dailyCurrentRiskAmount += riskAmount;
      PrintFormat("%s RiskManager: Trade risk registered. Amount: %.2f, Daily Total: %.2f", m_eaSymbol, riskAmount, m_dailyCurrentRiskAmount);
   }

   void RegisterTradeResult(bool isProfit)
   {
      if (isProfit)
      {
         if(m_consecutiveLosses > 0)
            PrintFormat("%s RiskManager: Consecutive loss streak broken at %d losses.", m_eaSymbol, m_consecutiveLosses);
         m_consecutiveLosses = 0;
      }
      else
      {
         m_consecutiveLosses++;
         PrintFormat("%s RiskManager: Loss registered. Consecutive losses: %d (Limit: %d)", m_eaSymbol, m_consecutiveLosses, m_consecutiveLossLimit);
      }
   }
   
   // Helper to determine point scale (e.g. 3 or 5 digit brokers)
   double PointScaleFactor()
   {
        if(_Digits == 3 || _Digits == 5) return 10.0;
        return 1.0;
   }
};

//+------------------------------------------------------------------+
//| ErrorHandler Class                                               |
//+------------------------------------------------------------------+
class ErrorHandler {
private:
    struct ErrorRecord {
        int         code;
        string      context;
        string      message;
        datetime    time;
    };
    ErrorRecord m_errorLog[];
    int m_errorCount;
    int m_currentIndex;
    
public:
    ErrorHandler() {
        m_errorCount = 0;
        m_currentIndex = 0;
        ArrayResize(m_errorLog, 100);
        // Initialize array elements individually
        for(int i = 0; i < ArraySize(m_errorLog); i++) {
            m_errorLog[i].code = 0;
            m_errorLog[i].context = "";
            m_errorLog[i].message = "";
            m_errorLog[i].time = 0;
        }
    }
    
    void LogError(int errorCode, string context) {
        m_errorLog[m_currentIndex].code = errorCode;
        m_errorLog[m_currentIndex].context = context;
        m_errorLog[m_currentIndex].message = GetErrorDescription(errorCode);
        m_errorLog[m_currentIndex].time = TimeCurrent();
        
        PrintFormat("ERROR logged by ErrorHandler: Code %d, Context: %s, Message: %s", 
                   errorCode, context, m_errorLog[m_currentIndex].message);
        
        m_currentIndex = (m_currentIndex + 1) % ArraySize(m_errorLog);
        if(m_errorCount < ArraySize(m_errorLog))
            m_errorCount++;
    }
    
    bool ShouldRetry(int errorCode) {
        // Determine if error is transient and should be retried
        switch(errorCode) {
            case TRADE_RETCODE_TIMEOUT:          // 10026
            case TRADE_RETCODE_CONNECTION:       // 10018
            case TRADE_RETCODE_PRICE_OFF:        // 10016
            case TRADE_RETCODE_REQUOTE:          // 10004
                return true;
        }
        return false;
    }
    
    string GetErrorDescription(int errorCode) {
        // Custom error descriptions for common trade return codes
        switch(errorCode) {
            case TRADE_RETCODE_DONE: return "Request completed";
            case TRADE_RETCODE_TIMEOUT: return "Request timeout";
            case TRADE_RETCODE_CONNECTION: return "No connection";
            case TRADE_RETCODE_PRICE_OFF: return "Price off";
            case TRADE_RETCODE_REQUOTE: return "Requote";
            case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
            case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
            case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
            case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
            case TRADE_RETCODE_NO_MONEY: return "No money";
            case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
            case TRADE_RETCODE_REJECT: return "Request rejected";
            case TRADE_RETCODE_CANCEL: return "Request canceled";
            case TRADE_RETCODE_PLACED: return "Order placed";
            case TRADE_RETCODE_DONE_PARTIAL: return "Request completed partially";
            case TRADE_RETCODE_ERROR: return "Common error";
            case TRADE_RETCODE_INVALID_ORDER: return "Invalid order";
            case TRADE_RETCODE_INVALID_FILL: return "Invalid fill";
            case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
            case TRADE_RETCODE_ORDER_CHANGED: return "Order changed";
            case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
            case TRADE_RETCODE_NO_CHANGES: return "No changes";
            case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
            case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
            case TRADE_RETCODE_LOCKED: return "Request locked";
            case TRADE_RETCODE_FROZEN: return "Order or position frozen";
            case TRADE_RETCODE_HEDGE_PROHIBITED: return "Hedging prohibited";
            default: return "Unknown error code: " + IntegerToString(errorCode);
        }
    }
    
    bool HasRecentError(int errorCode, int secondsWindow) {
        datetime currentTime = TimeCurrent();
        int logSize = ArraySize(m_errorLog);
        for (int i = 0; i < m_errorCount; i++) {
            int actualIndex = (m_currentIndex - 1 - i + logSize) % logSize;
            if (m_errorLog[actualIndex].code == errorCode && (currentTime - m_errorLog[actualIndex].time) < secondsWindow) {
                return true;
            }
        }
        return false;
    }
};

//+------------------------------------------------------------------+
//| PerformanceMonitor Class                                         |
//+------------------------------------------------------------------+
class PerformanceMonitor {
private:
    struct TickProcessingRecord {
        datetime time;        // Time of tick processing start
        uint     start_ms;    // Start microsecond count
        uint     duration_ms; // Duration in microseconds
    };
    
    TickProcessingRecord m_tickRecords[1000]; // Store last 1000 tick processing times
    int m_tickRecordCount;
    int m_tickCurrentIndex;
    
    datetime m_startTime;      // EA start time or last daily reset
    long     m_totalTickCount; // Total ticks processed since last reset
    long     m_totalTradeCount;// Total trades executed since last reset
    datetime m_lastDayLogged;  // To ensure daily stats are logged once per day

public:
    PerformanceMonitor() {
        m_tickRecordCount = 0;
        m_tickCurrentIndex = 0;
        // Initialize struct array elements individually
        for(int i = 0; i < ArraySize(m_tickRecords); i++) {
            m_tickRecords[i].time = 0;
            m_tickRecords[i].start_ms = 0;
            m_tickRecords[i].duration_ms = 0;
        }
        
        m_startTime = TimeCurrent();
        m_totalTickCount = 0;
        m_totalTradeCount = 0;
        m_lastDayLogged = 0; // Will be set on first daily log
    }
    
    void StartTickMeasurement() {
        m_tickRecords[m_tickCurrentIndex].time = TimeCurrent();
        m_tickRecords[m_tickCurrentIndex].start_ms = (uint)GetMicrosecondCount();
    }
    
    void EndTickMeasurement() {
        uint endMicroseconds = (uint)GetMicrosecondCount();
        uint duration = endMicroseconds - m_tickRecords[m_tickCurrentIndex].start_ms;
        m_tickRecords[m_tickCurrentIndex].duration_ms = duration;
        
        // Log if processing took too long (e.g., > 1000 microseconds = 1ms)
        if (duration > 1000) { 
            PrintFormat("PERF_WARN: Tick processing at %s took %u microseconds.", 
                        TimeToString(m_tickRecords[m_tickCurrentIndex].time), duration);
        }
        
        m_tickCurrentIndex = (m_tickCurrentIndex + 1) % ArraySize(m_tickRecords);
        if (m_tickRecordCount < ArraySize(m_tickRecords))
            m_tickRecordCount++;
            
        m_totalTickCount++;
    }
    
    void LogTradeExecution() { // Renamed from LogTrade to be more specific
        m_totalTradeCount++;
    }
    
    double GetAverageProcessingTimeMicroseconds() {
        if (m_tickRecordCount == 0) return 0.0;
        
        ulong totalDuration = 0; // Use ulong for sum of uints
        int count = 0;
        for (int i = 0; i < m_tickRecordCount; i++) {
            // Iterate backwards from current index to get recent records if log hasn't filled yet
            // int actualIndex = (m_tickCurrentIndex - 1 - i + ArrayRange(m_tickRecords,0)) % ArrayRange(m_tickRecords,0);
            // Simpler: just average the records we have, up to m_tickRecordCount
            totalDuration += m_tickRecords[i].duration_ms;
            count++;
        }
        if(count == 0) return 0.0;
        return (double)totalDuration / count;
    }
    
    void LogDailyStatisticsIfNeeded() {
        datetime currentTime = TimeCurrent();
        MqlDateTime dtCurrent, dtLastLogged;
        TimeToStruct(currentTime, dtCurrent);
        TimeToStruct(m_lastDayLogged, dtLastLogged);
        
        // Log daily statistics if it's a new day or if never logged before (m_lastDayLogged == 0)
        if (m_lastDayLogged == 0 || dtCurrent.day != dtLastLogged.day || dtCurrent.mon != dtLastLogged.mon || dtCurrent.year != dtLastLogged.year) {
            long secondsRunning = (long)(currentTime - m_startTime);
            if (secondsRunning == 0) return; // Avoid division by zero if timer fires too quickly after init

            double ticksPerSecond = (double)m_totalTickCount / secondsRunning;
            double tradesPerHour = (m_totalTradeCount > 0) ? ((double)m_totalTradeCount / secondsRunning * 3600.0) : 0.0;
            double avgProcTime = GetAverageProcessingTimeMicroseconds();
            
            PrintFormat("PERF_DAILY_STATS for %04d.%02d.%02d: Runtime: %d s, Ticks/sec: %.2f, Trades/hour: %.2f, Avg Tick Proc Time: %.0f µs, Total Trades: %d, Total Ticks: %d",
                        dtCurrent.year, dtCurrent.mon, dtCurrent.day,
                        secondsRunning, ticksPerSecond, tradesPerHour, avgProcTime, m_totalTradeCount, m_totalTickCount);
            
            // Reset daily counters
            m_startTime = currentTime;
            m_totalTickCount = 0;
            m_totalTradeCount = 0;
            // m_tickRecordCount = 0; // Optionally reset tick records too, or let them cycle
            // m_tickCurrentIndex = 0;
            m_lastDayLogged = currentTime;
        }
    }
};

//+------------------------------------------------------------------+
//| ConfigManager Class                                              |
//+------------------------------------------------------------------+
class ConfigManager {
private:
    string configFilename;
    
public:
    ConfigManager(string filename) {
        configFilename = filename;
    }
    
    bool SaveConfiguration() {
        int fileHandle = FileOpen(configFilename, FILE_WRITE|FILE_TXT);
        if (fileHandle == INVALID_HANDLE) {
            Print("Failed to save configuration: ", GetLastError());
            return false;
        }
        
        FileWriteString(fileHandle, "InpMagic=" + IntegerToString(workingMagic) + "\n");
        FileWriteString(fileHandle, "StartHour=" + IntegerToString(workingStartHour) + "\n");
        FileWriteString(fileHandle, "EndHour=" + IntegerToString(workingEndHour) + "\n");
        FileWriteString(fileHandle, "LotType=" + IntegerToString(workingLotType) + "\n");
        FileWriteString(fileHandle, "FixedLot=" + DoubleToString(workingFixedLot) + "\n");
        FileWriteString(fileHandle, "RiskPercent=" + DoubleToString(workingRiskPercent) + "\n");
        FileWriteString(fileHandle, "Delta=" + DoubleToString(workingDelta) + "\n");
        FileWriteString(fileHandle, "MaxDistance=" + DoubleToString(workingMaxDistance) + "\n");
        FileWriteString(fileHandle, "Stop=" + DoubleToString(workingStop) + "\n");
        FileWriteString(fileHandle, "MaxTrailing=" + DoubleToString(workingMaxTrailing) + "\n");
        FileWriteString(fileHandle, "MaxSpread=" + IntegerToString(workingMaxSpread) + "\n");
        FileWriteString(fileHandle, "InpMinPriceMovementFactor=" + DoubleToString(workingMinPriceMovementFactor) + "\n");
        FileWriteString(fileHandle, "InpMinTimeInterval=" + IntegerToString(InpMinTimeInterval) + "\n");
        FileWriteString(fileHandle, "InpDailyMaxRiskPercent=" + DoubleToString(InpDailyMaxRiskPercent) + "\n");
        FileWriteString(fileHandle, "InpMaxConsecutiveLosses=" + IntegerToString(workingMaxConsecutiveLosses) + "\n");
        FileWriteString(fileHandle, "VolatilityPeriod=" + IntegerToString(VolatilityPeriod) + "\n");
        FileWriteString(fileHandle, "InpUseOrderBookImbalance=" + (string)workingUseOrderBookImbalance + "\n"); // Save working variable
        
        // Save Take Profit settings
        FileWriteString(fileHandle, "InpTakeProfitType=" + IntegerToString(workingTakeProfitType) + "\n");
        FileWriteString(fileHandle, "InpTakeProfitAtrMultiple=" + DoubleToString(workingTakeProfitAtrMultiple) + "\n");
        FileWriteString(fileHandle, "InpTakeProfitAtrPeriod=" + IntegerToString(workingTakeProfitAtrPeriod) + "\n");
        FileWriteString(fileHandle, "InpTakeProfitFixedPoints=" + DoubleToString(workingTakeProfitFixedPoints) + "\n");
        
        FileClose(fileHandle);
        Print("Configuration saved to: " + configFilename);
        return true;
    }
    
    bool LoadConfiguration() {
        if (!FileIsExist(configFilename)) {
            Print("Configuration file not found: " + configFilename);
            return false;
        }
        
        int fileHandle = FileOpen(configFilename, FILE_READ|FILE_TXT);
        if (fileHandle == INVALID_HANDLE) {
            Print("Failed to load configuration: ", GetLastError());
            return false;
        }
        
        while (!FileIsEnding(fileHandle)) {
            string line = FileReadString(fileHandle);
            string parts[];
            if (StringSplit(line, '=', parts) == 2) {
                string key = parts[0];
                string value = parts[1];
                
                // Remove leading/trailing spaces manually
                StringReplace(key, " ", "");
                StringReplace(value, " ", "");

                if (key == "InpMagic") workingMagic = (int)StringToInteger(value);
                else if (key == "StartHour") workingStartHour = (int)StringToInteger(value);
                else if (key == "EndHour") workingEndHour = (int)StringToInteger(value);
                else if (key == "LotType") workingLotType = (enumLotType)StringToInteger(value);
                else if (key == "FixedLot") workingFixedLot = StringToDouble(value);
                else if (key == "RiskPercent") workingRiskPercent = StringToDouble(value);
                else if (key == "Delta") workingDelta = StringToDouble(value);
                else if (key == "MaxDistance") workingMaxDistance = StringToDouble(value);
                else if (key == "Stop") workingStop = StringToDouble(value);
                else if (key == "MaxTrailing") workingMaxTrailing = StringToDouble(value);
                else if (key == "MaxSpread") workingMaxSpread = (int)StringToInteger(value);
                else if (key == "InpMinPriceMovementFactor") workingMinPriceMovementFactor = StringToDouble(value);
                else if (key == "InpMaxConsecutiveLosses") workingMaxConsecutiveLosses = (int)StringToInteger(value);
                else if (key == "InpUseOrderBookImbalance") workingUseOrderBookImbalance = (bool)StringToInteger(value); // Load to working variable
                // Load Take Profit settings
                else if (key == "InpTakeProfitType") workingTakeProfitType = (ENUM_TAKE_PROFIT_TYPE)StringToInteger(value);
                else if (key == "InpTakeProfitAtrMultiple") workingTakeProfitAtrMultiple = StringToDouble(value);
                else if (key == "InpTakeProfitAtrPeriod") workingTakeProfitAtrPeriod = (int)StringToInteger(value);
                else if (key == "InpTakeProfitFixedPoints") workingTakeProfitFixedPoints = StringToDouble(value);
            }
        }
        
        FileClose(fileHandle);
        Print("Configuration loaded from: " + configFilename);
        return true;
    }
};

// Now all other global variables, enums, etc can follow
CTrade trade;
CPositionInfo posinfo;
COrderInfo ordinfo;
CHistoryOrderInfo hisinfo;
CDealInfo dealinfo;

enum enumLotType {Fixed_Lots=0, Pct_of_Balance=1, Pct_of_Equity=2, Pct_of_Free_Margin=3};

// New Enum for Take Profit Types
enum ENUM_TAKE_PROFIT_TYPE {
    TP_NONE,            // No explicit take profit, relies on trailing stop or other exits
    TP_ATR_MULTIPLE,    // Take profit based on ATR multiple
    TP_FIXED_POINTS     // Take profit based on fixed points from entry
};

input group "GENERAL SETTINGS"; // General Settings

input int InpMagic = 12345; // Magic Number
input int Slippage = 1;

input group "TIME SETTINGS";
input int StartHour = 6; // START TRADING HOUR
input int EndHour = 22; // END TRADING HOUR
input int Secs = 60; // ORDER MODIFICATIONS (Should be same as TF)

input group "TICK FILTER SETTINGS"; // New settings for tick filtering
input double InpMinPriceMovementFactor = 0.1; // Factor of Point for min price movement (0.1 = 10% of a point)
input int InpMinTimeInterval = 1;          // Minimum time interval in seconds for processing a tick

input group "MONEY MANAGEMENT"; // MONEY MANAGEMENT

input enumLotType LotType = 0; // Type of Lotsize calculation
input double FixedLot = 0.01; // Fixed Lots 0.0 = MM
input double RiskPercent=0.5; // Risk MM%
input bool InpUseOrderBookImbalance = true; // Use Order Book Imbalance for Entry

input group "TAKE PROFIT SETTINGS"; // New Take Profit Settings
input ENUM_TAKE_PROFIT_TYPE InpTakeProfitType = TP_NONE;                // Take Profit Strategy Type
input double InpTakeProfitAtrMultiple = 2.0;   // ATR Multiplier for TP (e.g., 2.0 for TP = Entry + 2*ATR)
input int    InpTakeProfitAtrPeriod   = 14;    // ATR Period for TP calculation
input double InpTakeProfitFixedPoints = 100;   // Fixed Points for TP from entry price

input group "TRADE SETTING IN POINTS"; // TRADE SETTINGS

input double Delta = 2; // ORDER DISTANCE (def 0.5)
input double MaxDistance = 15; // THETA (Max order distance - def: 7)
input double Stop = 30; // Stop Loss size (def 10)
input double MaxTrailing = 8; // COS (Start of Trailing Stop) def 4
input int  MaxSpread = 5555; // Max Spread Limit
/*
settings for btcusd
Why MaxTrailing = 8.0:
Profit Buffer: With Delta = 2.0, positions need to move at least 8.0 points (4x Delta) in profit before trailing starts
Volatility Cushion: BTCUSD can have quick 5-10 point retracements, so 8.0 provides adequate buffer
Risk/Reward Balance: Allows 8 points of profit capture while protecting against 30-point losses
Proportional Scaling: Maintains the same ratio as your other increased parameters (roughly 2x the original)
*/

double DeltaX = Delta;

double MinOrderDistance=0.5;
double MaxTrailingLimit=7.5;
double OrderModificationFactor=3;
int TickCounter=0;
double PriceToPipRatio=0;


double BaseTrailingStop=0;
double TrailingStopBuffer=0;
double TrailingStopIncrement=0;
double TrailingStopThreshold=0;
long AccountLeverageValue=0;

double LotStepSize=0;
double MaxLotSize=0;
double MinLotSize=0;
double MarginPerMinLot=0;
double MinStopDistance=0;


int BrokerStopLevel=0;
double MinFreezeDistance=0;
int BrokerFreezeLevel=0;
double CurrentSpread=0;
double AverageSpread=0;

int EAModeFlag=0;
int SpreadArraySize=0;
int DefaultSpreadPeriod=30;
double MaxAllowedSpread=0;
double CalculatedLotSize=0;

double CommissionPerPip=0;
int SpreadMultiplier=0;
double AdjustedOrderDistance=0;
double MinOrderModification=0;
double TrailingStopActive=0;

double TrailingStopMax=0;
double MaxOrderPlacementDistance=0;
double OrderPlacementStep=0;
double CalculatedStopLoss=0;
bool AllowBuyOrders=false;

bool AllowSellOrders=false;
bool SpreadAcceptable=false;
int LastOrderTimeDiff=0;
int LastOrderTime=0;
int MinOrderInterval=0;

double CurrentBuySL=0;
string OrderCommentText="HFT2025";
int LastBuyOrderTime=0;
bool TradeAllowed=false;
double CurrentSellSL=0;

int LastSellOrderTime=0;
int OrderCheckFrequency=2;
int SpreadCalculationMethod=1;
bool EnableTrading=false;
CircularBuffer *spreadHistory = NULL; // Pointer for CircularBuffer

// Static variables for IsSignificantTick
static double lastProcessedPrice_static = 0; // Renamed to avoid conflict if a global is also named lastProcessedPrice
static datetime lastProcessedTime_static = 0; // Renamed for clarity

// Market Regime
enum MARKET_REGIME {
    REGIME_TRENDING,
    REGIME_RANGING,
    REGIME_VOLATILE,
    REGIME_QUIET,
    REGIME_UNDEFINED // Added for default/initial state
};
MARKET_REGIME currentMarketRegime = REGIME_UNDEFINED;

// Baseline parameters that might be adjusted by regime or volatility
double BaseOrderDistance = 0; // Will be initialized from Delta
double BaseTrailingStopValue = 0; // Will be initialized from MaxTrailing

// Placeholder for Volatility Moving Average (e.g., using another CircularBuffer)
CircularBuffer* volatilityHistory = NULL; // For ScaleParametersByVolatility
int VolatilityPeriod = 20; // Example period

// Risk Management Globals
input double InpDailyMaxRiskPercent = 2.0; // Daily Max Risk Percentage
input int InpMaxConsecutiveLosses = 3;  // Max Consecutive Losses Allowed
RiskManager* riskManager = NULL;

double BaseStopLoss = 0; // To be initialized from input Stop
double BaseMaxDistance = 0; // To be initialized from input MaxDistance

ErrorHandler* errorHandler = NULL; // Global instance for ErrorHandler
PerformanceMonitor* perfMonitor = NULL; // Global instance for PerformanceMonitor

// Configuration file name
string configFileName = "HFT_MRCAP_Config_" + _Symbol + ".ini";
ConfigManager* configManager = NULL; // Global instance for ConfigManager
ulong partiallyClosedTickets[]; // Array to store tickets of partially closed positions

// Add corresponding working variables
int workingMagic;
int workingStartHour;
int workingEndHour;
enumLotType workingLotType;
double workingFixedLot;
double workingRiskPercent;
double workingDelta;
double workingMaxDistance;
double workingStop;
double workingMaxTrailing;
int workingMaxSpread;
int workingSlippage;
double workingMinPriceMovementFactor;
int workingMaxConsecutiveLosses;
bool workingUseOrderBookImbalance; // Added working variable

// Working variables for Take Profit settings
ENUM_TAKE_PROFIT_TYPE workingTakeProfitType;
double workingTakeProfitAtrMultiple;
int    workingTakeProfitAtrPeriod;
double workingTakeProfitFixedPoints;

// Function Prototypes for helper functions
void UpdateMarketAndTradeParameters();
// ... existing code ...

// Function Prototypes for Priority 2 Enhancements
MARKET_REGIME DetectMarketRegime();
void AdaptParametersToRegime(MARKET_REGIME regime);
void ScaleParametersByVolatility();
void AdjustParametersForSession();
double CalculateOptimalEntryPoint(ENUM_ORDER_TYPE orderType);
void ManageExitStrategy(ulong ticket, double entryPrice, ENUM_POSITION_TYPE posType);

// Function prototypes for Priority 3
double CalculateOptimalLotSize(double stopLossPoints); // stopLossPoints = SL distance in points
double CalculatePerformanceFactor(); // Placeholder
double CalculateVolatilityFactor(); // Placeholder

// Placeholder functions for deeper analysis (to be implemented or connected)
// double CalculateVolatility(int period) { /* Placeholder */ return AverageSpread > 0 ? AverageSpread / _Point : 0.5; } // Example placeholder, use average spread in pips
// Updated CalculateVolatility using ATR with proper error handling
double CalculateVolatility(int period) {
    if (period <= 0) {
        PrintFormat("CalculateVolatility: Invalid period %d. Returning fallback.", period);
        return AverageSpread > 0 ? AverageSpread : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    }
    
    // Create ATR handle if not exists (static to persist between calls)
    static int atrHandle = INVALID_HANDLE;
    if (atrHandle == INVALID_HANDLE) {
        atrHandle = iATR(_Symbol, Period(), period);
        if (atrHandle == INVALID_HANDLE) {
            // PrintFormat("CalculateVolatility: Failed to create ATR handle. Error: %d", GetLastError());
            return AverageSpread > 0 ? AverageSpread : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
        }
    }
    
    double atrValues[];
    ArraySetAsSeries(atrValues, true);
    
    // Try to copy ATR data with error handling for insufficient data
    int copied = CopyBuffer(atrHandle, 0, 0, 1, atrValues);
    if (copied <= 0) {
        int error = GetLastError();
        // Error 4806 = Requested data not found (insufficient history)
        // Error 4401 = Indicator cannot be created
        if (error == 4806) {
            // Insufficient historical data - use fallback without logging (common in backtest start)
            return AverageSpread > 0 ? AverageSpread : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
        } else {
            // Other errors - log once per session to avoid spam
            static bool errorLogged = false;
            if (!errorLogged) {
                PrintFormat("CalculateVolatility: ATR buffer copy failed. Error: %d. Using fallback.", error);
                errorLogged = true;
            }
            return AverageSpread > 0 ? AverageSpread : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
        }
    }
    
    // Validate ATR value
    if (atrValues[0] <= 0 || atrValues[0] != atrValues[0]) { // Check for NaN
        return AverageSpread > 0 ? AverageSpread : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    }
    
    return atrValues[0]; 
}

// double CalculateTrendStrength() { /* Placeholder */ return 0.5; } // Example placeholder
// Updated CalculateTrendStrength using ADX with proper error handling
double CalculateTrendStrength(int period=14) { // Default period for ADX is often 14
    if (period <= 0) {
        return 0.5; // Return neutral trend strength
    }
    
    // Create ADX handle if not exists (static to persist between calls)
    static int adxHandle = INVALID_HANDLE;
    if (adxHandle == INVALID_HANDLE) {
        adxHandle = iADX(_Symbol, Period(), period);
        if (adxHandle == INVALID_HANDLE) {
            return 0.5; // Return neutral trend strength
        }
    }
    
    double adxValues[];
    ArraySetAsSeries(adxValues, true);
    
    // Try to copy ADX data with error handling for insufficient data
    int copied = CopyBuffer(adxHandle, MAIN_LINE, 0, 1, adxValues);
    if (copied <= 0) {
        int error = GetLastError();
        if (error == 4806) {
            // Insufficient historical data - return neutral without logging
            return 0.5;
        } else {
            // Other errors - log once per session to avoid spam
            static bool errorLogged = false;
            if (!errorLogged) {
                PrintFormat("CalculateTrendStrength: ADX buffer copy failed. Error: %d. Using neutral.", error);
                errorLogged = true;
            }
            return 0.5;
        }
    }
    
    // Validate ADX value
    if (adxValues[0] < 0 || adxValues[0] != adxValues[0]) { // Check for NaN or negative
        return 0.5;
    }
    
    // ADX values typically range from 0 to 100.
    // Normalize to 0-1 range for trend strength
    return MathMin(adxValues[0] / 100.0, 1.0);
}

// Updated CalculateOrderBookImbalance using top-of-book volumes
double CalculateOrderBookImbalance() {
    MqlBookInfo bookInfo[];
    if (!MarketBookGet(_Symbol, bookInfo)) {
        // PrintFormat("CalculateOrderBookImbalance: MarketBookGet() failed for %s. Error: %d", _Symbol, GetLastError());
        return 0.0; // Return neutral if book info is unavailable
    }

    double totalBidVolume = 0;
    double totalAskVolume = 0;

    double bestBidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double bestAskPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    for (int i = 0; i < ArraySize(bookInfo); i++) {
        if (bookInfo[i].type == BOOK_TYPE_BUY && bookInfo[i].price >= bestBidPrice) {
            totalBidVolume += bookInfo[i].volume;
        }
        if (bookInfo[i].type == BOOK_TYPE_SELL && bookInfo[i].price <= bestAskPrice) {
            totalAskVolume += bookInfo[i].volume;
        }
    }
    
    // Fallback: use basic volume data if order book data is not available
    if(totalBidVolume == 0 && totalAskVolume == 0) {
        // Use tick volume as a proxy for order flow imbalance
        long tickVolumeRaw = SymbolInfoInteger(_Symbol, SYMBOL_VOLUME);
        double tickVolume = (double)tickVolumeRaw;
        if(tickVolume > 0) {
            // Simple heuristic: if price is rising, assume more buy pressure
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            static double lastPrice = 0;
            if(lastPrice == 0) lastPrice = currentPrice;
            
            if(currentPrice > lastPrice) {
                totalBidVolume = tickVolume * 0.6; // Assume 60% buy pressure
                totalAskVolume = tickVolume * 0.4; // Assume 40% sell pressure
            } else if(currentPrice < lastPrice) {
                totalBidVolume = tickVolume * 0.4; // Assume 40% buy pressure
                totalAskVolume = tickVolume * 0.6; // Assume 60% sell pressure
            } else {
                totalBidVolume = tickVolume * 0.5; // Neutral
                totalAskVolume = tickVolume * 0.5;
            }
            lastPrice = currentPrice;
        }
    }

    if (totalBidVolume + totalAskVolume == 0) {
        return 0.0; // Avoid division by zero, return neutral
    }

    // Calculate imbalance: (bid_volume - ask_volume) / (bid_volume + ask_volume)
    double imbalance = (totalBidVolume - totalAskVolume) / (totalBidVolume + totalAskVolume);
    return imbalance;
}

// double CalculateDynamicTrailingStop(double priceMove) { /* Placeholder */ return TrailingStopActive; } // Use existing for now -- Will be removed

// Implementation for IsPartialClosed
bool IsPartialClosed(ulong ticket) {
    for (int i = 0; i < ArraySize(partiallyClosedTickets); i++) {
        if (partiallyClosedTickets[i] == ticket) {
            return true;
        }
    }
    return false;
}

// Implementation for ClosePartialPosition
void ClosePartialPosition(ulong ticket, double partToClose) {
    if (partToClose <= 0 || partToClose >= 1.0) { // Ensure part is fractional and valid
        PrintFormat("ClosePartialPosition: Invalid partToClose %.2f for ticket #%I64u. Must be > 0 and < 1.", partToClose, ticket);
        return;
    }

    CPositionInfo posInfo; // Use local CPositionInfo
    if (!posInfo.SelectByTicket(ticket)) {
        PrintFormat("ClosePartialPosition: Failed to select position by ticket #%I64u.", ticket);
        return;
    }

    double currentVolume = posInfo.Volume();
    double volumeToClose = currentVolume * partToClose;
    
    // Normalize volume to close according to symbol's volume step
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if (lotStep > 0) {
        volumeToClose = MathRound(volumeToClose / lotStep) * lotStep;
    }
    else {
        volumeToClose = NormalizeDouble(volumeToClose, 2); // Default to 2 decimal places if lot step is 0
    }

    // Ensure volume to close is not zero after normalization and is less than current volume
    if (volumeToClose <= 0 || volumeToClose >= currentVolume) {
        PrintFormat("ClosePartialPosition: Invalid volumeToClose %.2f (normalized from %.2f * %.2f) for ticket #%I64u. CurrentVol: %.2f", 
                    volumeToClose, currentVolume, partToClose, ticket, currentVolume);
        return;
    }
    
    // Min lot check for the closing part (though PositionClosePartial might handle it, good to be aware)
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if (volumeToClose < minLot && currentVolume - volumeToClose < minLot && currentVolume > minLot) {
        // If closing this part leaves a remaining volume smaller than minLot, 
        // and the part itself is smaller than minLot, it might be better to close the whole position.
        // For now, proceed as per request, but this is a consideration.
        PrintFormat("ClosePartialPosition: volumeToClose %.2f or remaining volume might be < MinLot %.2f for ticket #%I64u. Proceeding.", 
                    volumeToClose, minLot, ticket);
    }
    
    if (!trade.PositionClosePartial(ticket, volumeToClose)) {
        if(CheckPointer(errorHandler) == POINTER_DYNAMIC) {
            errorHandler.LogError(trade.ResultRetcode(), "ClosePartialPosition failed for ticket #" + (string)ticket + ", VolToClose: " + DoubleToString(volumeToClose,2));
        }
    } else {
        PrintFormat("ClosePartialPosition: Successfully closed %.2f lot(s) of position #%I64u.", volumeToClose, ticket);
        // Mark as partially closed
        bool found = false;
        for (int i = 0; i < ArraySize(partiallyClosedTickets); i++) {
            if (partiallyClosedTickets[i] == ticket) {
                found = true;
                break;
            }
        }
        if (!found) {
            int currentSize = ArraySize(partiallyClosedTickets);
            ArrayResize(partiallyClosedTickets, currentSize + 1);
            partiallyClosedTickets[currentSize] = ticket;
        }
    }
}

// Implementation for ClosePosition
void ClosePosition(ulong ticket) {
    if (!trade.PositionClose(ticket)) {
        if(CheckPointer(errorHandler) == POINTER_DYNAMIC) {
            errorHandler.LogError(trade.ResultRetcode(), "ClosePosition failed for ticket #" + (string)ticket);
        }
    } else {
        PrintFormat("ClosePosition: Successfully closed position #%I64u.", ticket);
    }
}

// Function prototype for SafeOrderSend
bool SafeOrderSend(string symbol, ENUM_ORDER_TYPE orderType, double volume, double price, double sl, double tp, string comment);

// Function to check if order is safe to modify
bool IsOrderSafeToModify(ulong ticket, double newPrice) 
{
    COrderInfo orderInfo; // Create local instance
    
    // Find the order by looping through all orders
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(!orderInfo.SelectByIndex(i)) continue;
        if(orderInfo.Ticket() != ticket) continue;
        
        // Found the order, now check if it's safe to modify
        double currentPrice = (orderInfo.OrderType() == ORDER_TYPE_BUY_STOP) ? 
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                             SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        double orderPrice = orderInfo.PriceOpen();
        double minDistance = MathMax(MinFreezeDistance, 50 * _Point);
        
        // Check if current order is too close to market
        if(orderInfo.OrderType() == ORDER_TYPE_BUY_STOP) {
            if(orderPrice - currentPrice <= minDistance) return false;
            if(newPrice - currentPrice <= minDistance) return false;
        } else {
            if(currentPrice - orderPrice <= minDistance) return false;
            if(currentPrice - newPrice <= minDistance) return false;
        }
        
        return true; // Order found and is safe to modify
    }
    
    return false; // Order not found
}

#ifdef STRESS_TEST
// Function prototypes for testing (only compiled if STRESS_TEST is defined)
void StressTestEA();
void BenchmarkCriticalFunctionsEA();

// Simulation helpers for stress test (can be expanded)
void SimulateMarketDataUpdate(double newSpread) {
    if(CheckPointer(spreadHistory) == POINTER_DYNAMIC) spreadHistory.Add(newSpread);
    // This is a simplified simulation; a real one might alter Ask/Bid prices directly if possible
    // For now, primarily tests the spread buffer and dependent calculations in UpdateMarketAndTradeParameters()
    UpdateMarketAndTradeParameters(); 
}

void SimulateOrderExecution() {
    // Simulate placing a BUY_STOP order, it might get auto-deleted or modified
    // This tests parts of OnTick logic for order placement and modification
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double slPips = CalculatedStopLoss / riskManager.PointScaleFactor(); 
    
    if(CheckPointer(riskManager) == POINTER_DYNAMIC && riskManager.IsTradeAllowed(MinLotSize, slPips)){
        SafeOrderSend(_Symbol, ORDER_TYPE_BUY_STOP, MinLotSize, ask + AdjustedOrderDistance * 2, ask + AdjustedOrderDistance - CalculatedStopLoss, 0, "StressTestOrder");
        if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) perfMonitor.LogTradeExecution();
    }
}

void SimulateErrorCondition(int errorCodeToSimulate) {
    // This is tricky as we can't directly cause server errors.
    // We can simulate logging them to test ErrorHandler's logging and retry logic if it were adapted.
    // For now, just log it via ErrorHandler.
    if(CheckPointer(errorHandler) == POINTER_DYNAMIC) {
        errorHandler.LogError(errorCodeToSimulate, "Simulated Error Condition for Stress Test");
    }
}
#endif

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // Initialize ConfigManager first
   if(configManager == NULL) configManager = new ConfigManager(configFileName);
   // Attempt to load configuration (optional: could be tied to an input bool LoadSettingsOnStart = true;)
   // For now, let's assume we always try to load if file exists.
   if(configManager.LoadConfiguration()) {
       Print("Configuration successfully loaded. Parameters may have been overridden.");
   } else {
       Print("No existing configuration file found or failed to load. Using default input parameters.");
   }

   // Initialize partially closed tickets array
   ArrayResize(partiallyClosedTickets, 0);

   // Initialize working variables from inputs
   workingMagic = InpMagic;
   workingStartHour = StartHour;
   workingEndHour = EndHour;
   workingLotType = LotType;
   workingFixedLot = FixedLot;
   workingRiskPercent = RiskPercent;
   workingDelta = Delta;
   workingMaxDistance = MaxDistance;
   workingStop = Stop;
   workingMaxTrailing = MaxTrailing;
   workingMaxSpread = MaxSpread;
   workingSlippage = Slippage;
   workingMinPriceMovementFactor = InpMinPriceMovementFactor;
   workingMaxConsecutiveLosses = InpMaxConsecutiveLosses;
   workingUseOrderBookImbalance = InpUseOrderBookImbalance; // Initialize working variable

   // Initialize Take Profit working variables
   workingTakeProfitType = InpTakeProfitType;
   workingTakeProfitAtrMultiple = InpTakeProfitAtrMultiple;
   workingTakeProfitAtrPeriod = InpTakeProfitAtrPeriod;
   workingTakeProfitFixedPoints = InpTakeProfitFixedPoints;

   trade.SetExpertMagicNumber(InpMagic);
   BaseOrderDistance = Delta; // Initialize base parameter
   BaseTrailingStopValue = MaxTrailing; // Initialize base parameter for trailing stop logic
   BaseStopLoss = Stop; // Initialize from input for dynamic SL calculations
   BaseMaxDistance = MaxDistance; // Initialize from input for dynamic distance calculations

   ChartSetInteger(0,CHART_SHOW_GRID, false);
// ... existing code ...
   if(CheckPointer(spreadHistory) == POINTER_DYNAMIC && SpreadArraySize > 0) // Add initial spread
      spreadHistory.Add(CurrentSpread);

// In OnInit, after creating spreadHistory
SpreadArraySize = DefaultSpreadPeriod;
if(spreadHistory != NULL) delete spreadHistory;
spreadHistory = new CircularBuffer(SpreadArraySize);

// Initialize broker-specific values with proper minimum distances for BTCUSD
MinStopDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
BrokerStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
MinFreezeDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
BrokerFreezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

// For BTCUSD, ensure minimum distances are adequate
if(MinStopDistance < 50 * _Point) MinStopDistance = 50 * _Point; // Minimum 50 points for BTCUSD
if(MinFreezeDistance < 30 * _Point) MinFreezeDistance = 30 * _Point; // Minimum 30 points for BTCUSD

// Initialize lot size constraints
LotStepSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
MaxLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
MinLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

// Initialize spread calculation values
SpreadMultiplier = 10; // This should ideally be an input parameter

// Initialize critical trading parameters that were missing
double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
CurrentSpread = NormalizeDouble(Ask - Bid, _Digits);
AverageSpread = CurrentSpread;

// Initialize order modification parameters
MinOrderModification = MathMax(AverageSpread * MinOrderDistance, MinFreezeDistance);
OrderPlacementStep = MinOrderModification / OrderModificationFactor;
MaxOrderPlacementDistance = AverageSpread * workingMaxDistance;

// Initialize calculated parameters
UpdateMarketAndTradeParameters(); // This will set AdjustedOrderDistance and CalculatedStopLoss

   // Initialize Volatility History Buffer
   if(volatilityHistory != NULL) delete volatilityHistory;
   volatilityHistory = new CircularBuffer(VolatilityPeriod);
   // Initialize with some dummy values or current volatility if available
   for(int i=0; i<VolatilityPeriod; i++) {
      if(CheckPointer(volatilityHistory) == POINTER_DYNAMIC)
         volatilityHistory.Add(CalculateVolatility(VolatilityPeriod)); // Initial fill
   }

   MaxAllowedSpread = NormalizeDouble((MaxSpread * _Point), _Digits);
// ... existing code ...
   // Initialize Risk Manager
   if(riskManager != NULL) delete riskManager;
   riskManager = new RiskManager(InpDailyMaxRiskPercent, InpMaxConsecutiveLosses, _Symbol);

   // Initialize Error Handler
   if(errorHandler != NULL) delete errorHandler;
   errorHandler = new ErrorHandler();

   // Initialize Performance Monitor
   if(perfMonitor != NULL) delete perfMonitor;
   perfMonitor = new PerformanceMonitor();

   MaxAllowedSpread = NormalizeDouble((MaxSpread * _Point), _Digits);
   TesterHideIndicators(true);
   
   UpdateMarketAndTradeParameters(); // Initial call to set parameters

   EventSetTimer(1); // Set timer for 1 second interval

#ifdef STRESS_TEST
   Print("STRESS_TEST macro is defined. EA will run stress tests and benchmarks on init.");
   // StressTestEA(); // It might be better to not run these automatically if config is also loaded.
   // BenchmarkCriticalFunctionsEA(); // Could be triggered by an input bool instead.
   Print("STRESS_TEST: Tests would run here but are commented out in OnInit for now when ConfigManager is active.");
#endif

       // After loading config (if any) and before other initializations that use parameters.
   if(!ValidateInputParameters()) {
      Print("CRITICAL: Input parameter validation failed. EA initialization aborted.");
      return INIT_PARAMETERS_INCORRECT; // Signal initialization failure
   }
   
   // Special validation for BTCUSD
   if(StringFind(_Symbol, "BTC") >= 0) {
      Print("BTCUSD detected - applying crypto-specific settings");
      // Ensure minimum parameters are suitable for crypto volatility
      if(workingDelta < 1.0) {
         Print("WARNING: Delta too small for BTCUSD. Adjusting to 1.0");
         workingDelta = 1.0;
         BaseOrderDistance = 1.0;
      }
      if(workingStop < 20.0) {
         Print("WARNING: Stop Loss too small for BTCUSD. Adjusting to 20.0");
         workingStop = 20.0;
         BaseStopLoss = 20.0;
      }
   }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   // Optionally save configuration on deinit
   // if(CheckPointer(configManager) == POINTER_DYNAMIC) {
   //    configManager.SaveConfiguration(); 
   // }

   EventKillTimer(); // Kill the timer
   
   // Release indicator handles to prevent memory leaks
   // These are static variables in the functions, so we need to access them indirectly
   // The handles will be automatically released when the EA is removed, but it's good practice
   
   if(CheckPointer(spreadHistory) == POINTER_DYNAMIC)
     {
      delete spreadHistory; // Delete the CircularBuffer object
      spreadHistory = NULL;
     }
   if(CheckPointer(volatilityHistory) == POINTER_DYNAMIC)
     {
      delete volatilityHistory; // Delete the Volatility CircularBuffer object
      volatilityHistory = NULL;
     }
   if(CheckPointer(riskManager) == POINTER_DYNAMIC)
     {
      delete riskManager;
      riskManager = NULL;
     }
   if(CheckPointer(errorHandler) == POINTER_DYNAMIC)
     {
      delete errorHandler;
      errorHandler = NULL;
     }
   if(CheckPointer(perfMonitor) == POINTER_DYNAMIC)
     {
      delete perfMonitor;
      perfMonitor = NULL;
     }
   if(CheckPointer(configManager) == POINTER_DYNAMIC) // Cleanup ConfigManager
     {
      delete configManager;
      configManager = NULL;
     }
  }
//+------------------------------------------------------------------+
//| IsSignificantTick function                                       |
//+------------------------------------------------------------------+
bool IsSignificantTick()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID); // Using BID as per plan example
   datetime currentTime = TimeCurrent();

   double minPriceMovementValue = InpMinPriceMovementFactor * _Point;

   bool significantPriceMove = MathAbs(currentPrice - lastProcessedPrice_static) >= minPriceMovementValue;
   bool timeIntervalElapsed = (currentTime - lastProcessedTime_static) >= InpMinTimeInterval;

   if(significantPriceMove || timeIntervalElapsed)
   {
      lastProcessedPrice_static = currentPrice;
      lastProcessedTime_static = currentTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| UpdateMarketAndTradeParameters function                          |
//+------------------------------------------------------------------+
void UpdateMarketAndTradeParameters()
{
   double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double newSpread = NormalizeDouble(Ask - Bid, _Digits);

   if(CheckPointer(spreadHistory) == POINTER_DYNAMIC)
   {
      spreadHistory.Add(newSpread);
      CurrentSpread = spreadHistory.GetAverage(); // CurrentSpread now holds the average spread
   }
   else
   {
      // Fallback or error log if spreadHistory is not initialized
      CurrentSpread = newSpread;
      // It might be good to Print an error here or try to reinitialize
   }

   // Calculate average spread including commission
   AverageSpread = MathMax(SpreadMultiplier * _Point, CurrentSpread + CommissionPerPip);

   // Calculate order distances and other parameters using working variables
   AdjustedOrderDistance = MathMax(AverageSpread * workingDelta, MinStopDistance);
   MinOrderModification = MathMax(AverageSpread * MinOrderDistance, MinFreezeDistance);
   TrailingStopActive = AverageSpread * workingMaxTrailing;
   TrailingStopMax = AverageSpread * MaxTrailingLimit;
   MaxOrderPlacementDistance = AverageSpread * workingMaxDistance;
   OrderPlacementStep = MinOrderModification / OrderModificationFactor;
   CalculatedStopLoss = MathMax(AverageSpread * workingStop, MinStopDistance);
}

//+------------------------------------------------------------------+
//| ManageOpenPositions function                                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Get current market prices once for this function
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posinfo.SelectByIndex(i))
         continue;
      if(posinfo.Symbol() != _Symbol || posinfo.Magic() != InpMagic)
         continue;

      ulong ticket = posinfo.Ticket();
      ENUM_POSITION_TYPE type = posinfo.PositionType();
      double openPrice = posinfo.PriceOpen();
      // double sl = posinfo.StopLoss(); // sl will be determined by ManageExitStrategy or trailing logic
      // double tp = posinfo.TakeProfit(); // tp can also be managed dynamically if needed

      ManageExitStrategy(ticket, openPrice, type); // Use the new comprehensive exit strategy manager

      // The existing trailing stop logic can be a part of ManageExitStrategy or a fallback
      // For now, let's keep the original trailing logic here as a fallback or if ManageExitStrategy doesn't fully cover it
      // Original Trailing Stop Logic (can be integrated into ManageExitStrategy later)
      double sl = posinfo.StopLoss();
      double tp = posinfo.TakeProfit();

      if(type == POSITION_TYPE_BUY)
      {
         double priceMove = MathMax(currentBid - openPrice + CommissionPerPip, 0);
         double trailDist = CalculateTrailingStop(priceMove, MinStopDistance, TrailingStopActive, BaseTrailingStop, TrailingStopMax);
         double modifiedSL = NormalizeDouble(currentBid - trailDist, _Digits);
         double triggerLevel = openPrice + CommissionPerPip + TrailingStopIncrement;

         if((currentBid > triggerLevel) &&
            (sl == 0 || (currentBid - sl) > trailDist || modifiedSL > sl) &&
             modifiedSL != sl && (currentBid - modifiedSL) >= MinStopDistance)
         {
            trade.PositionModify(ticket, modifiedSL, tp);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double priceMove = MathMax(openPrice - currentAsk - CommissionPerPip, 0);
         double trailDist = CalculateTrailingStop(priceMove, MinStopDistance, TrailingStopActive, BaseTrailingStop, TrailingStopMax);
         double modifiedSL = NormalizeDouble(currentAsk + trailDist, _Digits);
         double triggerLevel = openPrice - CommissionPerPip - TrailingStopIncrement;

         if((currentAsk < triggerLevel) &&
            (sl == 0 || (sl - currentAsk) > trailDist || modifiedSL < sl) &&
            modifiedSL != sl && (modifiedSL - currentAsk) >= MinStopDistance)
         {
            trade.PositionModify(ticket, modifiedSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert OnTimer function                                          |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Calculate PriceToPipRatio asynchronously (moved from OnTick)
   CalculatePriceToPipRatioAsync();
   
   // Update market data, average spread, and dependent parameters
   UpdateMarketAndTradeParameters();

   // Detect market regime and adapt parameters
   currentMarketRegime = DetectMarketRegime();
   AdaptParametersToRegime(currentMarketRegime);
   
   // Scale parameters by volatility
   ScaleParametersByVolatility();
   
   // Adjust parameters for current session
   AdjustParametersForSession();

   // Manage open positions (e.g., trailing stops, dynamic exits)
   ManageOpenPositions();

   // Log daily statistics if needed (Performance Monitor)
   if(CheckPointer(perfMonitor) == POINTER_DYNAMIC)
      perfMonitor.LogDailyStatisticsIfNeeded();
      
   // Periodically cleanup partiallyClosedTickets array
   static datetime lastPartialCleanupTime = 0;
   if(TimeCurrent() - lastPartialCleanupTime >= 300) { // Every 5 minutes, for example
       CleanupPartiallyClosedTickets();
       lastPartialCleanupTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Expert OnTrade function (Placeholder)                            |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Handle trade events specifically in the future
   // e.g., ReconcilePositions(); UpdateTradeStatistics();
   // For RiskManager, we need to detect deal closures to call RegisterTradeResult

   // This is a simplified way to check for closed deals on OnTrade event.
   // A more robust solution would involve checking specific transaction types (TRADE_TRANSACTION_DEAL_ADD)
   // and deal properties (DEAL_ENTRY == DEAL_ENTRY_OUT).

   static ulong lastCheckedDealTicket = 0;
   HistorySelect(0, TimeCurrent()); // Select all history up to now
   int dealsTotal = HistoryDealsTotal();

   for(int i = dealsTotal - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= lastCheckedDealTicket) // Process only new deals
         break; 

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagic && 
         HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
         HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
      {
         if(CheckPointer(riskManager) == POINTER_DYNAMIC) {
            // Get the current position's profit
            double profit = 0;
            if(posinfo.SelectByTicket(dealTicket)) {
               profit = posinfo.Profit();
            }
            riskManager.RegisterTradeResult(profit >= 0);
         }
      }
      if(i == dealsTotal -1) // Store the newest processed deal ticket
        lastCheckedDealTicket = dealTicket;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function (REMOVED - using optimized version below)  |
//+------------------------------------------------------------------+ 









//+------------------------------------------------------------------+
//| CalculateTrailingStop (existing helper function)                 |
//+------------------------------------------------------------------+
double CalculateTrailingStop(double priceMove, double minDist, double activeDist, double baseDist, double maxDist)
  {
   if(maxDist == 0)
      return MathMax(activeDist, minDist);

   double ratio = priceMove / maxDist;
   double dynamicDist = (activeDist - baseDist) * ratio + baseDist;
   return MathMax(MathMin(dynamicDist, activeDist), minDist);

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
double calcLots(double slPoints)
  {
   double lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double EquityBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   double FreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   double risk = 0;
   switch(LotType)
     {
      case 0:
         lots = FixedLot;
         return lots;
      case 1:
         risk = AccountBalance * RiskPercent / 100;
         break;
      case 2:
         risk = EquityBalance * RiskPercent / 100;
         break;
      case 3:
         risk = FreeMargin * RiskPercent / 100;
         break;
     }

   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
   lots = MathFloor(risk / moneyPerLotstep) * lotstep;

   double minvolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxvolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumelimit = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);

   if(volumelimit != 0)
      lots = MathMin(lots, volumelimit);
   if(maxvolume != 0)
      lots = MathMin(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   if(minvolume != 0)
      lots = MathMax(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lots = NormalizeDouble(lots, 2);
   return lots;
  }

//+------------------------------------------------------------------+
//| Priority 2: Trading Logic Enhancements                           |
//+------------------------------------------------------------------+

// Add market regime detection
MARKET_REGIME DetectMarketRegime() {
    static datetime lastRegimeCalculationTime = 0;
    static MARKET_REGIME cachedMarketRegime = REGIME_UNDEFINED;
    static bool firstRun = true;

    if (firstRun || (TimeCurrent() - lastRegimeCalculationTime >= 60)) {
        // Calculate short-term volatility
        double shortTermVol = CalculateVolatility(20);
        if(CheckPointer(volatilityHistory) == POINTER_DYNAMIC) // Update volatility history
            volatilityHistory.Add(shortTermVol);

        // Calculate longer-term volatility
        double longTermVol = CalculateVolatility(50); // This could use a different buffer or method
        
        // Calculate trend strength
        double trendStrength = CalculateTrendStrength();
        
        // Determine regime based on volatility and trend metrics
        if (trendStrength > 0.7) cachedMarketRegime = REGIME_TRENDING;
        else if (shortTermVol > 1.5 * longTermVol && longTermVol > 0) cachedMarketRegime = REGIME_VOLATILE; // ensure longTermVol is not zero
        else if (longTermVol > 0 && shortTermVol < 0.5 * longTermVol) cachedMarketRegime = REGIME_QUIET; // ensure longTermVol is not zero
        else cachedMarketRegime = REGIME_RANGING;
        
        lastRegimeCalculationTime = TimeCurrent();
        firstRun = false;
        // PrintFormat("DetectMarketRegime: Recalculated regime to %s at %s", EnumToString(cachedMarketRegime), TimeToString(lastRegimeCalculationTime));
    } else {
        // PrintFormat("DetectMarketRegime: Using cached regime %s", EnumToString(cachedMarketRegime));
    }
    
    return cachedMarketRegime;
}

// Adapt parameters based on market regime
void AdaptParametersToRegime(MARKET_REGIME regime) {
    // BaseOrderDistance and BaseTrailingStopValue should be set in OnInit from input parameters
    // These are then used as the basis for adjustments.
    AdjustedOrderDistance = BaseOrderDistance; // Reset to base before applying regime logic
    TrailingStopActive = BaseTrailingStopValue * AverageSpread; // Reset to base spread-adjusted value

    switch(regime) {
        case REGIME_TRENDING:
            AdjustedOrderDistance = BaseOrderDistance * 1.2;
            TrailingStopActive = (BaseTrailingStopValue * 1.5) * AverageSpread;
            break;
        case REGIME_RANGING:
            AdjustedOrderDistance = BaseOrderDistance * 0.8;
            TrailingStopActive = (BaseTrailingStopValue * 0.7) * AverageSpread;
            break;
        case REGIME_VOLATILE:
            AdjustedOrderDistance = BaseOrderDistance * 1.5;
            TrailingStopActive = (BaseTrailingStopValue * 2.0) * AverageSpread;
            break;
        case REGIME_QUIET:
            AdjustedOrderDistance = BaseOrderDistance * 0.6;
            TrailingStopActive = (BaseTrailingStopValue * 0.5) * AverageSpread;
            break;
        case REGIME_UNDEFINED: // Fallback to base if undefined
        default:
            // Parameters remain at their base (or last calculated from UpdateMarketAndTradeParameters)
            break;
    }
    // Ensure minimum distances are respected after adaptation
    AdjustedOrderDistance = MathMax(AdjustedOrderDistance, MinStopDistance);
    TrailingStopActive = MathMax(TrailingStopActive, MinStopDistance); 
}

// Add volatility-based parameter scaling
void ScaleParametersByVolatility() {
    if(CheckPointer(volatilityHistory) == POINTER_INVALID || volatilityHistory.GetAverage() == 0)
        return;
        
    double currentVolatility = CalculateVolatility(VolatilityPeriod); // Use the same period as the history
    double baselineVolatility = volatilityHistory.GetAverage();
    
    if (baselineVolatility == 0) return;
    
    double volatilityRatio = currentVolatility / baselineVolatility;
    
    // Scale parameters based on volatility
    double scaleFactor = MathMin(MathMax(volatilityRatio, 0.5), 2.0);
    
    // Apply scaling to relevant parameters - DeltaX is not used, AdjustedOrderDistance is primary
    AdjustedOrderDistance *= scaleFactor; // Scale the already regime-adjusted distance
    CalculatedStopLoss = BaseStopLoss * scaleFactor; // Assuming BaseStopLoss is initialized from input Stop
    MaxOrderPlacementDistance = BaseMaxDistance * scaleFactor; // Assuming BaseMaxDistance from input MaxDistance

    // Ensure minimums
    AdjustedOrderDistance = MathMax(AdjustedOrderDistance, MinStopDistance);
    CalculatedStopLoss = MathMax(CalculatedStopLoss, MinStopDistance);
    MaxOrderPlacementDistance = MathMax(MaxOrderPlacementDistance, AdjustedOrderDistance);
}

// Add time-based parameter sets
void AdjustParametersForSession() {
    MqlDateTime dt;
    TimeCurrent(dt);
    
    // Store original values before session adjustment if needed, or adjust from a base
    // For MinOrderInterval and OrderModificationFactor, direct modification is shown as per plan

    if (dt.hour >= 8 && dt.hour < 12) { // European session opening
        MinOrderInterval = 5; // Example: Original MinOrderInterval could be an input
        OrderModificationFactor = 2.5;
    }
    else if (dt.hour >= 12 && dt.hour < 16) { // European/US overlap
        MinOrderInterval = 3;
        OrderModificationFactor = 2.0;
    }
    else if (dt.hour >= 16 && dt.hour < 20) { // US session (original EA's typical time)
        MinOrderInterval = 4; // Let's assume default MinOrderInterval comes from an input or a #define
        OrderModificationFactor = 2.2;
    }
    else { // Asian/quiet session
        MinOrderInterval = 8;
        OrderModificationFactor = 3.0;
    }
    // Ensure OrderModificationFactor is at least 1
    if(OrderModificationFactor < 1) OrderModificationFactor = 1;
}

// Implement smart order placement
double CalculateOptimalEntryPoint(ENUM_ORDER_TYPE orderType) {
    double basePrice = (orderType == ORDER_TYPE_BUY_STOP) ? 
                      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                      SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Validate base price
    if (basePrice <= 0) {
        return 0; // Return 0 to trigger fallback logic
    }
    
    // Calculate optimal distance based on recent price action
    double recentVolatility = CalculateVolatility(10);
    
    // Ensure we have a minimum viable distance
    double fallbackDistance = MathMax(MinStopDistance, _Point * 10); // At least 10 points
    double spreadBasedDistance = AverageSpread > 0 ? AverageSpread * workingDelta : fallbackDistance;
    
    double optimalDistance = MathMax(recentVolatility * 0.5, spreadBasedDistance);
    optimalDistance = MathMax(optimalDistance, MinStopDistance);
    
    // Adjust based on order book imbalance if available
    if(workingUseOrderBookImbalance) { // Check the input parameter
        double orderBookImbalance = CalculateOrderBookImbalance(); // Returns -1 to 1 typically
        if (MathAbs(orderBookImbalance) < 1.0) { // Validate imbalance is reasonable
            optimalDistance *= (1.0 + orderBookImbalance * 0.2); // Adjust distance by up to 20%
        }
    }
    
    // Ensure minimum distance
    optimalDistance = MathMax(optimalDistance, MinStopDistance);
    
    // Calculate final price
    double entryPrice = (orderType == ORDER_TYPE_BUY_STOP) ? 
                       basePrice + optimalDistance : 
                       basePrice - optimalDistance;
    
    // Validate entry price
    if (entryPrice <= 0) {
        return 0; // Return 0 to trigger fallback logic
    }
                       
    return NormalizeDouble(entryPrice, _Digits);
}

// Implement advanced exit strategies
void ManageExitStrategy(ulong ticket, double entryPrice, ENUM_POSITION_TYPE posType) {
    double currentPriceBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentPriceAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double relevantPriceForSL = (posType == POSITION_TYPE_BUY) ? currentPriceBid : currentPriceAsk;
    
    double priceMovePoints = 0; 
    if (posType == POSITION_TYPE_BUY) {
        priceMovePoints = (currentPriceBid - entryPrice) - (CommissionPerPip);
    } else { 
        priceMovePoints = (entryPrice - currentPriceAsk) - (CommissionPerPip);
    }

    double currentSL = posinfo.StopLoss(); // Fetched via posinfo in ManageOpenPositions before calling this
    double currentTP = posinfo.TakeProfit(); // Fetched via posinfo

    double slToSet = currentSL;
    double tpToSet = currentTP;
    bool modifyOrder = false;

    // 1. Dynamic Trailing Stop (existing logic)
    double positivePriceMovePoints = MathMax(0, priceMovePoints);
    double trailDistancePoints = CalculateTrailingStop(positivePriceMovePoints, MinStopDistance, TrailingStopActive, BaseTrailingStop, TrailingStopMax);
    trailDistancePoints = MathMax(trailDistancePoints, MinStopDistance); 

    double newTrailingSL = 0;
    if (posType == POSITION_TYPE_BUY) {
        newTrailingSL = NormalizeDouble(relevantPriceForSL - trailDistancePoints, _Digits);
        if (newTrailingSL > entryPrice && (newTrailingSL > currentSL || currentSL == 0) && newTrailingSL != currentSL && (relevantPriceForSL - newTrailingSL) >= MinStopDistance) {
            slToSet = newTrailingSL;
            modifyOrder = true;
        }
    } else { 
        newTrailingSL = NormalizeDouble(relevantPriceForSL + trailDistancePoints, _Digits);
        if (newTrailingSL < entryPrice && (newTrailingSL < currentSL || currentSL == 0) && newTrailingSL != currentSL && (newTrailingSL - relevantPriceForSL) >= MinStopDistance) {
            slToSet = newTrailingSL;
            modifyOrder = true;
        }
    }

    // 2. Calculate Dynamic Take Profit
    double newDynamicTP = 0;
    if (workingTakeProfitType != TP_NONE) {
        if (workingTakeProfitType == TP_ATR_MULTIPLE && workingTakeProfitAtrPeriod > 1 && workingTakeProfitAtrMultiple > 0) {
            double atrValueForTP = CalculateVolatility(workingTakeProfitAtrPeriod); // This returns price units
            if (atrValueForTP > 0) {
                if (posType == POSITION_TYPE_BUY) {
                    newDynamicTP = NormalizeDouble(entryPrice + (atrValueForTP * workingTakeProfitAtrMultiple), _Digits);
                } else { // POSITION_TYPE_SELL
                    newDynamicTP = NormalizeDouble(entryPrice - (atrValueForTP * workingTakeProfitAtrMultiple), _Digits);
                }
            }
        } else if (workingTakeProfitType == TP_FIXED_POINTS && workingTakeProfitFixedPoints > 0) {
            if (posType == POSITION_TYPE_BUY) {
                newDynamicTP = NormalizeDouble(entryPrice + (workingTakeProfitFixedPoints * _Point), _Digits);
            } else { // POSITION_TYPE_SELL
                newDynamicTP = NormalizeDouble(entryPrice - (workingTakeProfitFixedPoints * _Point), _Digits);
            }
        }

        // Validate and set newDynamicTP
        if (newDynamicTP > 0) {
            bool tpIsValid = false;
            if (posType == POSITION_TYPE_BUY && newDynamicTP > currentPriceAsk + MinStopDistance) {
                tpIsValid = true;
            } else if (posType == POSITION_TYPE_SELL && newDynamicTP < currentPriceBid - MinStopDistance && newDynamicTP > 0) { // ensure TP > 0 for sell
                tpIsValid = true;
            }

            if (tpIsValid && newDynamicTP != currentTP) {
                tpToSet = newDynamicTP;
                modifyOrder = true;
            }
        }
    }

    // 3. Modify Position if SL or TP changed
    if (modifyOrder) {
        if (!trade.PositionModify(ticket, slToSet, tpToSet)) {
            if(CheckPointer(errorHandler)) errorHandler.LogError(trade.ResultRetcode(), "ManageExitStrategy: PositionModify SL/TP failed for #" + (string)ticket + " SL: "+DoubleToString(slToSet,_Digits)+" TP: "+DoubleToString(tpToSet,_Digits));
        }
    }

    // 4. Partial profit taking (existing logic, now after SL/TP modification)
    double actualStopLossPoints = CalculatedStopLoss > 0 ? CalculatedStopLoss : Stop * AverageSpread; // Fallback
    actualStopLossPoints = MathMax(actualStopLossPoints, MinStopDistance);

    if (priceMovePoints > actualStopLossPoints * 0.5 && !IsPartialClosed(ticket) && actualStopLossPoints > 0) {
        double currentVolume = PositionGetDouble(POSITION_VOLUME);
        if (currentVolume >= 2 * MinLotSize && MinLotSize > 0) { // Ensure MinLotSize is positive
            ClosePartialPosition(ticket, 0.5); 
        }
    }
    
    // 5. Time-based exit (existing logic, now after SL/TP modification)
    int MaxHoldingTime = 4 * 3600; // Example: 4 hours, make this an EA input if desired
    if (GetPositionHoldingTime(ticket) > MaxHoldingTime && MaxHoldingTime > 0) { // ensure MaxHoldingTime is positive
        ClosePosition(ticket); 
    }
}

//+------------------------------------------------------------------+
//| Priority 3: Risk Management Function Implementations             |
//+------------------------------------------------------------------+

// Add volatility-adjusted position sizing
double CalculateOptimalLotSize(double stopLossPoints) { // stopLossPoints = SL distance in points (e.g., value from CalculatedStopLoss)
    // Base calculation on account risk percentage (from input via LotType)
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equityBalance = AccountInfoDouble(ACCOUNT_EQUITY);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double riskCapital = 0;

    switch(LotType)
    {
        case Fixed_Lots: {
            // This case should ideally not be reached if LotType > 0 is checked before calling.
            // However, as a fallback, use FixedLot, ensuring it respects min/max.
            double baseLot = FixedLot > 0 ? FixedLot : MinLotSize;
            // Ensure lot step for fixed lot too
            if (LotStepSize > 0) baseLot = MathRound(baseLot / LotStepSize) * LotStepSize;
            else baseLot = NormalizeDouble(baseLot,2); // Default normalization if lot step is zero
            return MathMax(MathMin(baseLot, MaxLotSize), MinLotSize);
        }
        case Pct_of_Balance:
            riskCapital = accountBalance * (RiskPercent / 100.0);
            break;
        case Pct_of_Equity:
            riskCapital = equityBalance * (RiskPercent / 100.0);
            break;
        case Pct_of_Free_Margin:
            riskCapital = freeMargin * (RiskPercent / 100.0);
            break;
        default: // Should not happen
            PrintFormat("CalculateOptimalLotSize: Unknown LotType %d. Returning MinLotSize.", LotType);
            return MinLotSize;
    }
    
    // If stopLossPoints is zero or negative, it means SL is not defined or invalid for calculation.
    // In such cases, risk cannot be determined, so fall back to MinLotSize.
    if (stopLossPoints <= 1e-9) { // Use a small epsilon to check for effectively zero SL
        PrintFormat("CalculateOptimalLotSize: stopLossPoints is zero or negative (%.5f). Cannot calculate dynamic lot size. Returning MinLotSize: %.2f", stopLossPoints, MinLotSize);
        return MinLotSize; 
    }

    // Calculate tick value and size for the current symbol
    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_POINT); // Value of 1 point
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    if (point_value == 0 || tickSize == 0 || tickValue == 0) {
        PrintFormat("CalculateOptimalLotSize: point (%.5f), tickSize (%.5f) or tickValue (%.5f) is zero for %s. Returning MinLotSize: %.2f", 
                     point_value, tickSize, tickValue, _Symbol, MinLotSize);
        return MinLotSize; 
    }

    // Monetary loss for 1 lot for the given stopLossPoints.
    // stopLossPoints is the SL distance in absolute price units (e.g., 0.00150).
    // Number of ticks in SL = stopLossPoints / tickSize.
    // Monetary loss for 1 lot = (Number of ticks in SL) * tickValue.
    double lossPerLot = (stopLossPoints / tickSize) * tickValue; 

    if (lossPerLot <= 1e-9) { // Use a smaller epsilon for very small lossPerLot
        PrintFormat("CalculateOptimalLotSize: lossPerLot is too small or zero (%.10f) for SL=%.5f price units. RiskCap=%.2f. Returning MinLotSize: %.2f", 
                     lossPerLot, stopLossPoints, riskCapital, MinLotSize);
        return MinLotSize; 
    }
    
    // Calculate raw lot size based on risk capital and loss per lot
    double rawLotSize = riskCapital / lossPerLot;
    
    // Adjust based on recent performance factor
    double perfFactor = CalculatePerformanceFactor();
    rawLotSize *= perfFactor;
    
    // Adjust based on volatility factor
    double volFactor = CalculateVolatilityFactor();
    rawLotSize *= volFactor;
    
    // Normalize to lot step
    // LotStepSize is initialized in OnInit
    if(LotStepSize <= 0) LotStepSize = 0.01; // Fallback lotstep if not properly initialized or zero
    double normalizedLotSize = MathRound(rawLotSize / LotStepSize) * LotStepSize; // Use MathRound for closer normalization
    
    // Apply min/max lot constraints
    // MinLotSize and MaxLotSize are initialized in OnInit
    double finalLotSize = normalizedLotSize;
    if (MaxLotSize > 0) finalLotSize = MathMin(finalLotSize, MaxLotSize);
    finalLotSize = MathMax(finalLotSize, MinLotSize);
        
    // Final check to ensure the lot size is not zero if MinLot is non-zero, and is properly normalized
    if (finalLotSize < MinLotSize && MinLotSize > 0) finalLotSize = MinLotSize;
    if (finalLotSize == 0 && MinLotSize > 0) finalLotSize = MinLotSize; // If calculation results in 0, use minLot

    // Ensure final lot size is a multiple of lot step if it somehow got misaligned
    if (LotStepSize > 0) finalLotSize = MathRound(finalLotSize / LotStepSize) * LotStepSize;
    else finalLotSize = NormalizeDouble(finalLotSize,2); // Default normalization

    // Prevent lots smaller than min lot after all calculations
    finalLotSize = MathMax(finalLotSize, MinLotSize);

    /* // Debug Print
    PrintFormat("CalcOptLot: SLPriceUnits=%.5f, RiskCap=%.2f, LossPerLot=%.5f, RawLot=%.4f, PerfF=%.2f, VolF=%.2f, NormLot=%.4f, FinalLot=%.4f (Min:%.2f Max:%.2f Step:%.2f)", 
        stopLossPoints, riskCapital, lossPerLot, rawLotSize, perfFactor, volFactor, normalizedLotSize, finalLotSize, MinLotSize, MaxLotSize, LotStepSize);
    */
    return finalLotSize;
}

// Calculate performance factor based on recent trades (Placeholder based on plan)
double CalculatePerformanceFactor() {
    // Example: Analyze recent trades to adjust aggressiveness.
    // This requires history analysis, which can be complex.
    // For now, return 1.0 (no adjustment).
    int totalTrades = 0;
    int profitTrades = 0;
    datetime weekAgo = TimeCurrent() - 7 * 24 * 60 * 60;

    HistorySelect(weekAgo, TimeCurrent());
    for (int i = 0; i < HistoryDealsTotal(); i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if (HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        if (HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
        if (HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
        
        totalTrades++;
        if (HistoryDealGetDouble(ticket, DEAL_PROFIT) > 0) profitTrades++;
    }
    
    if (totalTrades < 5) return 1.0; // Not enough data, neutral factor
    
    double winRate = (double)profitTrades / totalTrades;
    
    if (winRate > 0.65) return 1.2; // Good performance, slightly more aggressive
    if (winRate < 0.45) return 0.8; // Poor performance, slightly less aggressive
    return 1.0; // Neutral
}

// Calculate volatility factor (Placeholder based on plan)
double CalculateVolatilityFactor() {
    if(CheckPointer(volatilityHistory) == POINTER_INVALID || volatilityHistory.GetAverage() == 0) {
        // Print("CalculateVolatilityFactor: Volatility history not available or average is zero. Returning 1.0");
        return 1.0;
    }

    // CalculateVolatility is expected to return a value like average spread in points or similar volatility metric.
    // For consistency, ensure currentVol and averageVol are comparable (e.g., both are pip-like values or point-like values).
    // currentVol from CalculateVolatility(VolatilityPeriod) is based on AverageSpread/_Point, so it's pip-like.
    // volatilityHistory.GetAverage() stores these pip-like values.
    double currentVol = CalculateVolatility(VolatilityPeriod); 
    double averageVol = volatilityHistory.GetAverage(); 

    if(averageVol <= 1e-9) { // Avoid division by zero or very small numbers
        // PrintFormat("CalculateVolatilityFactor: Average volatility (%.5f) is too small. Returning 1.0", averageVol);
        return 1.0;
    }

    double volRatio = currentVol / averageVol;

    // Adjust lot size based on volatility ratio (as per plan example)
    double factor = 1.0;
    if(volRatio > 1.5) factor = 0.8; // Higher current volatility than average, reduce lot size
    else if(volRatio < 0.7) factor = 1.2; // Lower current volatility, can slightly increase
    
    // PrintFormat("CalculateVolatilityFactor: CurrentVol: %.5f, AvgVol: %.5f, Ratio: %.2f, Factor: %.2f", currentVol, averageVol, volRatio, factor);
    return factor;
}

//+------------------------------------------------------------------+
//| SafeOrderSend Function                                           |
//+------------------------------------------------------------------+
bool SafeOrderSend(string symbol, ENUM_ORDER_TYPE orderType, double volume, double price, double sl, double tp, string comment)
{
    if(CheckPointer(errorHandler) == POINTER_INVALID) {
        Print("SafeOrderSend: ErrorHandler not initialized! Attempting direct send.");
        // Attempt direct send without retry logic if ErrorHandler is missing
        if (orderType == ORDER_TYPE_BUY_STOP) {
            return trade.BuyStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
        } else if (orderType == ORDER_TYPE_SELL_STOP) {
            return trade.SellStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
        } else {
            return trade.OrderOpen(symbol, orderType, volume, price, 0, sl, tp, ORDER_TIME_GTC, 0, comment);
        }
    }

    int maxRetries = 3;
    int retryDelayBase = 100; // milliseconds, base delay for first retry
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
        // CTrade object should have magic number set via trade.SetExpertMagicNumber(InpMagic) in OnInit

        // Debug: Log the parameters being sent to CTrade
        PrintFormat("DEBUG: Sending order - Symbol: %s, Type: %s, Volume: %.2f, Price: %.5f, SL: %.5f, TP: %.5f", 
                   symbol, EnumToString(orderType), volume, price, sl, tp);
        
        // For STOP orders, we need to use the correct CTrade method
        bool result = false;
        if (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
            // Use BuyStop or SellStop methods for stop orders
            if (orderType == ORDER_TYPE_BUY_STOP) {
                result = trade.BuyStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
            } else {
                result = trade.SellStop(volume, price, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
            }
        } else {
            // Use OrderOpen for market orders
            result = trade.OrderOpen(symbol, orderType, volume, price, 0, sl, tp, ORDER_TIME_GTC, 0, comment);
        }
        
        if (result) {
            // PrintFormat("SafeOrderSend: Attempt %d successful for %s order at %.5f", attempt, EnumToString(orderType), price);
            return true;
        }
        
        int lastError = trade.ResultRetcode(); // Use trade.ResultRetcode() after a CTrade operation
                                             // GetLastError() is more general system errors.
        string context = "SafeOrderSend attempt " + IntegerToString(attempt) + " for " + EnumToString(orderType) + ", Sym: " + symbol + ", Vol: " + DoubleToString(volume,2) + ", P: " + DoubleToString(price,_Digits);
        errorHandler.LogError(lastError, context);
        
        if (!errorHandler.ShouldRetry(lastError)) {
            PrintFormat("SafeOrderSend: Non-retriable error %d occurred. Aborting.", lastError);
            return false; // Non-retriable error
        }
        
        // If it's the last attempt and still failing with a retriable error
        if (attempt == maxRetries) {
            PrintFormat("SafeOrderSend: Max retries (%d) reached for retriable error %d. Aborting.", maxRetries, lastError);
            return false;
        }
        
        Sleep(retryDelayBase * attempt); // Linear increase in delay as per plan example
    }
    
    return false; // Should ideally not be reached if logic is correct, but as a fallback.
}

//+------------------------------------------------------------------+

#ifdef STRESS_TEST
//+------------------------------------------------------------------+
//| Stress Testing Capabilities                                      |
//+------------------------------------------------------------------+
void StressTestEA() {
    Print("Starting EA Stress Test...");
    if(CheckPointer(errorHandler) == POINTER_INVALID || CheckPointer(riskManager) == POINTER_INVALID || CheckPointer(perfMonitor) == POINTER_INVALID) {
        Print("StressTestEA: One or more required components (ErrorHandler, RiskManager, PerfMonitor) are not initialized. Aborting stress test.");
        return;
    }

    // Test rapid market data updates (simulating spread changes)
    Print("Stress Test: Simulating 1000 market data updates (spread changes).");
    for (int i = 0; i < 1000; i++) {
        double randomSpreadPoints = (MathRand() % 50 + 5) * _Point; // Random spread between 0.5 and 5.5 pips (approx)
        SimulateMarketDataUpdate(randomSpreadPoints);
        if (i % 100 == 0) Sleep(10); // Brief pause to allow some processing
    }
    Print("Stress Test: Market data updates simulation finished.");

    // Test order execution under load (simulating placing orders)
    Print("Stress Test: Simulating 100 order executions.");
    for (int i = 0; i < 100; i++) {
        SimulateOrderExecution(); // This will try to place an order
        Sleep(50); // Small delay between simulated order attempts to mimic some market flow
    }
    Print("Stress Test: Order execution simulation finished.");

    // Test error handling simulation (simulating some common errors)
    Print("Stress Test: Simulating error conditions.");
    SimulateErrorCondition(TRADE_RETCODE_TIMEOUT);        // Simulate a timeout
    Sleep(10);
    SimulateErrorCondition(TRADE_RETCODE_SERVER_BUSY);    // Simulate server busy
    Sleep(10);
    SimulateErrorCondition(TRADE_RETCODE_INVALID_PRICE);  // Simulate an invalid price error
    Print("Stress Test: Error condition simulation finished.");

    Print("EA Stress Test Completed.");
}

//+------------------------------------------------------------------+
//| Performance Benchmarking                                         |
//+------------------------------------------------------------------+
void BenchmarkCriticalFunctionsEA() {
    Print("Starting Performance Benchmark for Critical Functions...");
    if(CheckPointer(spreadHistory) == POINTER_INVALID || CheckPointer(volatilityHistory) == POINTER_INVALID || CheckPointer(riskManager) == POINTER_INVALID) {
        Print("BenchmarkCriticalFunctionsEA: One or more required components are not initialized. Aborting benchmark.");
        return;
    }

    uint startMicroseconds, durationMicroseconds;
    int iterations = 10000; // Number of iterations for benchmarking loops

    // --- Benchmark UpdateMarketAndTradeParameters --- 
    startMicroseconds = (uint)GetMicrosecondCount();
    for (int i = 0; i < iterations; i++) {
        UpdateMarketAndTradeParameters();
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: UpdateMarketAndTradeParameters() avg: %.2f µs/op (over %d ops)", (double)durationMicroseconds / iterations, iterations);

    // --- Benchmark DetectMarketRegime & AdaptParametersToRegime --- 
    startMicroseconds = (uint)GetMicrosecondCount();
    for (int i = 0; i < iterations; i++) {
        currentMarketRegime = DetectMarketRegime();
        AdaptParametersToRegime(currentMarketRegime);
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: DetectMarketRegime()+AdaptParametersToRegime() avg: %.2f µs/op (over %d ops)", (double)durationMicroseconds / iterations, iterations);

    // --- Benchmark ScaleParametersByVolatility --- 
    startMicroseconds = (uint)GetMicrosecondCount();
    for (int i = 0; i < iterations; i++) {
        ScaleParametersByVolatility();
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: ScaleParametersByVolatility() avg: %.2f µs/op (over %d ops)", (double)durationMicroseconds / iterations, iterations);

    // --- Benchmark CalculateOptimalLotSize (assuming a typical SL) ---
    double typicalSLPoints = BaseStopLoss * AverageSpread; // A dynamic SL for testing
    if(typicalSLPoints <=0) typicalSLPoints = Stop * _Point * 10; // fallback if avg spread is 0
    startMicroseconds = (uint)GetMicrosecondCount();
    for (int i = 0; i < iterations; i++) {
        CalculateOptimalLotSize(typicalSLPoints);
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: CalculateOptimalLotSize() avg: %.2f µs/op (over %d ops, SL: %.5f)", (double)durationMicroseconds / iterations, iterations, typicalSLPoints);
    
    // --- Benchmark IsSignificantTick (simulating some price changes) ---
    double testPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    startMicroseconds = (uint)GetMicrosecondCount();
    for (int i = 0; i < iterations; i++) {
        // Simulate minor price changes to toggle IsSignificantTick
        lastProcessedPrice_static = testPrice + ((i % 2 == 0) ? _Point : -_Point);
        IsSignificantTick();
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: IsSignificantTick() avg: %.2f µs/op (over %d ops)", (double)durationMicroseconds / iterations, iterations);
    
    // --- Benchmark Counting Open Positions and Orders (simplified from OnTick) ---
    startMicroseconds = (uint)GetMicrosecondCount();
    int reducedIterations = iterations / 10;
    for (int i = 0; i < reducedIterations; i++) { // Fewer iterations as it involves more loops
        int tempOpenBuy = 0, tempOpenSell = 0, tempPendingBuy = 0, tempPendingSell = 0;
        for(int k = PositionsTotal()-1; k >= 0; k--) { if(posinfo.SelectByIndex(k) && posinfo.Magic() == InpMagic) { if(posinfo.PositionType() == POSITION_TYPE_BUY) tempOpenBuy++; else tempOpenSell++; }} 
        for(int k = OrdersTotal()-1; k >= 0; k--) { if(ordinfo.SelectByIndex(k) && ordinfo.Magic() == InpMagic) { if(ordinfo.OrderType() == ORDER_TYPE_BUY_STOP) tempPendingBuy++; else if(ordinfo.OrderType() == ORDER_TYPE_SELL_STOP) tempPendingSell++; }}
    }
    durationMicroseconds = (uint)GetMicrosecondCount() - startMicroseconds;
    PrintFormat("Benchmark: Position/Order Counting Loops avg: %.2f µs/op (over %d ops)", (double)durationMicroseconds / reducedIterations, reducedIterations);

    Print("Performance Benchmark Completed.");
}
#endif

//+------------------------------------------------------------------+
//| ValidateInputParameters Function                                 |
//+------------------------------------------------------------------+
bool ValidateInputParameters() {
    bool isValid = true;
    string validationMessage = "Parameter Validation:\n";

    // General Settings
    if (InpMagic <= 0) {
        validationMessage += "ERROR: Magic Number (InpMagic) must be positive.\n";
        isValid = false;
    }
    if (Slippage < 0) {
        validationMessage += "WARNING: Slippage is negative. Using 0.\n";
        workingSlippage = 0; // Auto-correct using working variable
    }

    // Time Settings
    if (StartHour < 0 || StartHour > 23 || EndHour < 0 || EndHour > 23) {
        validationMessage += "ERROR: Invalid trading hours (StartHour/EndHour). Must be between 0-23.\n";
        isValid = false;
    }
    if (StartHour == EndHour) {
        validationMessage += "WARNING: StartHour is the same as EndHour. EA will not trade if this implies no duration.\n";
    }
    if (Secs <= 0) {
        validationMessage += "ERROR: Order Modification interval (Secs) must be positive.\n";
        isValid = false;
    }

    // Tick Filter Settings
    if (InpMinPriceMovementFactor < 0) {
        validationMessage += "WARNING: MinPriceMovementFactor is negative. Using 0.1 as default.\n";
        workingMinPriceMovementFactor = 0.1; 
    }
    if (InpMinTimeInterval <= 0) {
        validationMessage += "ERROR: MinTimeInterval for ticks must be positive.\n";
        isValid = false;
    }

    // Money Management
    if (LotType < Fixed_Lots || LotType > Pct_of_Free_Margin) {
        validationMessage += "ERROR: Invalid LotType selected.\n";
        isValid = false;
    }
    if (LotType == Fixed_Lots && FixedLot <= 0) {
        validationMessage += "ERROR: For Fixed_Lots, FixedLot must be positive. Or set LotType to a MM option.\n";
    }
    if ((LotType == Pct_of_Balance || LotType == Pct_of_Equity || LotType == Pct_of_Free_Margin) && (RiskPercent <= 0 || RiskPercent > 20)) {
        validationMessage += "WARNING: RiskPercent is outside recommended range (0-20%). Current: " + DoubleToString(RiskPercent,2) + "%.\n";
    }

    // Trade Setting in Points
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (Delta <= 0) {
        validationMessage += "ERROR: Order Distance (Delta) must be positive (relative to spread).\n";
        isValid = false;
    }
    if (MaxDistance <= Delta) {
        validationMessage += "ERROR: Max Order Distance (MaxDistance) must be greater than Delta.\n";
        isValid = false;
    }
    if (Stop <= 0) {
        validationMessage += "ERROR: Stop Loss size (Stop) must be positive (relative to spread).\n";
        isValid = false;
    }
    double minStopLevelPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    if (minStopLevelPoints > 0 && (Stop * point) < (minStopLevelPoints * point) && AverageSpread < point*minStopLevelPoints ) {
         validationMessage += "WARNING: Stop multiplier might be too small relative to broker's minimum stop level (" + DoubleToString(minStopLevelPoints,0) + " points). Ensure CalculatedStopLoss respects this.\n";
    }
    if (MaxTrailing <= 0) {
        validationMessage += "WARNING: MaxTrailing (for Trailing Stop start) is not positive. Trailing might not activate as intended.\n";
    }
    if (MaxSpread <= 0) {
        validationMessage += "ERROR: MaxSpread limit must be positive.\n";
        isValid = false;
    }

    // Risk Management Globals
    if (InpDailyMaxRiskPercent <= 0 || InpDailyMaxRiskPercent > 20) {
        validationMessage += "WARNING: DailyMaxRiskPercent is outside recommended range (0-20%). Current: " + DoubleToString(InpDailyMaxRiskPercent,2) + "%.\n";
    }
    if (InpMaxConsecutiveLosses <= 0) {
        validationMessage += "WARNING: MaxConsecutiveLosses is not positive. Setting to 3 as default.\n";
        workingMaxConsecutiveLosses = 3;
    }
    
    // VolatilityPeriod
    if (VolatilityPeriod <= 1) {
        validationMessage += "ERROR: VolatilityPeriod must be greater than 1.\n";
        isValid = false;
    }

    // Take Profit Settings Validation
    if (workingTakeProfitType < TP_NONE || workingTakeProfitType > TP_FIXED_POINTS) {
        validationMessage += "ERROR: Invalid TakeProfitType selected.\n";
        isValid = false;
    }
    if (workingTakeProfitType == TP_ATR_MULTIPLE) {
        if (workingTakeProfitAtrMultiple <= 0) {
            validationMessage += "ERROR: TakeProfitAtrMultiple must be positive for ATR TP type.\n";
            isValid = false;
        }
        if (workingTakeProfitAtrPeriod <= 1) {
            validationMessage += "ERROR: TakeProfitAtrPeriod must be greater than 1 for ATR TP type.\n";
            isValid = false;
        }
    }
    if (workingTakeProfitType == TP_FIXED_POINTS && workingTakeProfitFixedPoints <= 0) {
        validationMessage += "ERROR: TakeProfitFixedPoints must be positive for Fixed Points TP type.\n";
        isValid = false;
    }

    Print(validationMessage);
    return isValid;
}

//+------------------------------------------------------------------+

// Implementation for GetPositionHoldingTime
long GetPositionHoldingTime(ulong ticket) {
    CPositionInfo posInfo; // Use local CPositionInfo
    if (!posInfo.SelectByTicket(ticket)) {
        // PrintFormat("GetPositionHoldingTime: Failed to select position by ticket #%I64u.", ticket);
        return -1; // Return -1 or 0 to indicate error or position not found
    }
    
    datetime openTime = (datetime)posInfo.Time();
    if (openTime == 0) {
        // PrintFormat("GetPositionHoldingTime: Position #%I64u has an open time of 0.", ticket);
        return -1; // Invalid open time
    }
    
    return TimeCurrent() - openTime; // Duration in seconds
}

// Helper function to cleanup partiallyClosedTickets array
void CleanupPartiallyClosedTickets() {
    if (ArraySize(partiallyClosedTickets) == 0) return;

    CPositionInfo posInfo_local; // Use a local CPositionInfo instance
    int validTicketsCount = 0;
    ulong tempValidTickets[]; 
    // Initialize tempValidTickets with a reasonable starting size or current size
    // To be safe, make it at least the current size of partiallyClosedTickets
    int currentSize = ArraySize(partiallyClosedTickets);
    if (currentSize == 0) return; // Double check, though covered by first line
    ArrayResize(tempValidTickets, currentSize); 

    for (int i = 0; i < currentSize; i++) {
        if (partiallyClosedTickets[i] == 0) continue; 

        if (posInfo_local.SelectByTicket(partiallyClosedTickets[i])) {
            tempValidTickets[validTicketsCount] = partiallyClosedTickets[i];
            validTicketsCount++;
        } else {
            // Position does not exist (fully closed)
            // PrintFormat("Cleanup: Ticket #%I64u (fully closed) removed from partially closed list.", partiallyClosedTickets[i]);
        }
    }

    ArrayResize(partiallyClosedTickets, validTicketsCount);
    if (validTicketsCount > 0) {
        ArrayCopy(partiallyClosedTickets, tempValidTickets, 0, 0, validTicketsCount);
    }
     // else: partiallyClosedTickets is now correctly sized to 0 if no valid tickets were found.
    // PrintFormat("Cleanup: partiallyClosedTickets array now has %d elements.", validTicketsCount);
}

//+------------------------------------------------------------------+
//| Global variables for performance optimization                    |
//+------------------------------------------------------------------+
static double g_cachedAsk = 0;
static double g_cachedBid = 0;
static datetime g_lastPriceUpdate = 0;
static bool g_priceToPipRatioCalculated = false;
static int g_priceToPipRatioAttempts = 0;
static datetime g_lastHistoryCheck = 0;

// Cached position/order counts to avoid recalculation
static int g_cachedOpenBuyCount = 0;
static int g_cachedOpenSellCount = 0;
static int g_cachedPendingBuyCount = 0;
static int g_cachedPendingSellCount = 0;
static datetime g_lastCountUpdate = 0;

// Additional variables needed for optimized OnTick
static int MaxOpenBuy = 1;
static int MaxOpenSell = 1;

//+------------------------------------------------------------------+
//| Optimized price caching function                                 |
//+------------------------------------------------------------------+
void UpdateCachedPrices()
{
   datetime currentTime = TimeCurrent();
   if(currentTime != g_lastPriceUpdate) {
      g_cachedAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      g_cachedBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_lastPriceUpdate = currentTime;
   }
}

//+------------------------------------------------------------------+
//| Fast position/order counting with caching                        |
//+------------------------------------------------------------------+
void UpdateCachedCounts()
{
   datetime currentTime = TimeCurrent();
   if(currentTime == g_lastCountUpdate) return; // Use cached values
   
   g_cachedOpenBuyCount = 0;
   g_cachedOpenSellCount = 0;
   g_cachedPendingBuyCount = 0;
   g_cachedPendingSellCount = 0;
   
   // Single loop for positions
   int totalPositions = PositionsTotal();
   for(int i = 0; i < totalPositions; i++) {
      if(posinfo.SelectByIndex(i) && posinfo.Symbol() == _Symbol && posinfo.Magic() == workingMagic) {
         if(posinfo.PositionType() == POSITION_TYPE_BUY) g_cachedOpenBuyCount++;
         else g_cachedOpenSellCount++;
      }
   }
   
   // Single loop for orders
   int totalOrders = OrdersTotal();
   for(int i = 0; i < totalOrders; i++) {
      if(ordinfo.SelectByIndex(i) && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == workingMagic) {
         if(ordinfo.OrderType() == ORDER_TYPE_BUY_STOP) g_cachedPendingBuyCount++;
         else if(ordinfo.OrderType() == ORDER_TYPE_SELL_STOP) g_cachedPendingSellCount++;
      }
   }
   
   g_lastCountUpdate = currentTime;
}

//+------------------------------------------------------------------+
//| Move PriceToPipRatio calculation to OnTimer                      |
//+------------------------------------------------------------------+
void CalculatePriceToPipRatioAsync()
{
   if(g_priceToPipRatioCalculated || g_priceToPipRatioAttempts >= 5) return;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastHistoryCheck < 60) return; // Check only once per minute
   
   g_lastHistoryCheck = currentTime;
   
   if(HistorySelect(currentTime - 86400, currentTime)) { // Last 24 hours only
      int totalDeals = HistoryDealsTotal();
      for(int k = MathMax(0, totalDeals - 100); k < totalDeals; k++) { // Check last 100 deals only
         ulong dealTicket = HistoryDealGetTicket(k);
         if(dealTicket == 0) continue;
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetDouble(dealTicket, DEAL_PROFIT) == 0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         
         ulong posID = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posID == 0) continue;
         
         if(HistoryDealSelect(posID)) {
            double entryPrice = HistoryDealGetDouble(posID, DEAL_PRICE);
            double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            
            if(MathAbs(exitPrice - entryPrice) > _Point) {
               PriceToPipRatio = MathAbs(profit / (exitPrice - entryPrice));
               CommissionPerPip = -commission / PriceToPipRatio;
               g_priceToPipRatioCalculated = true;
               Print("PriceToPipRatio calculated: ", DoubleToString(PriceToPipRatio, 5));
               return;
            }
         }
      }
   }
   g_priceToPipRatioAttempts++;
}

//+------------------------------------------------------------------+
//| Optimized OnTick function                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // Performance monitoring start
   if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
      perfMonitor.StartTickMeasurement();
   }

   // Tick filtering - exit early if not significant
   if(!IsSignificantTick()) {
      if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
         perfMonitor.EndTickMeasurement();
      }
      return;
   }

   // Cache prices once per tick
   UpdateCachedPrices();
   
   // Use cached prices throughout
   double Ask = g_cachedAsk;
   double Bid = g_cachedBid;
   
   // Quick market parameter update (moved heavy calculations to OnTimer)
   if(AverageSpread <= 0) {
      AverageSpread = Ask - Bid;
   } else {
      AverageSpread = (AverageSpread * 0.9) + ((Ask - Bid) * 0.1); // Simple EMA
   }
   
   // Update cached counts
   UpdateCachedCounts();
   
   // Use cached counts
   int OpenBuyCount = g_cachedOpenBuyCount;
   int OpenSellCount = g_cachedOpenSellCount;
   int PendingBuyCount = g_cachedPendingBuyCount;
   int PendingSellCount = g_cachedPendingSellCount;

   TickCounter++;
   int CurrentTime = (int)TimeCurrent();
   
   // Quick trading hour check
   MqlDateTime BrokerTime;
   TimeCurrent(BrokerTime);
   bool allowTrade = (BrokerTime.hour >= workingStartHour && BrokerTime.hour <= workingEndHour);
   
   if(!allowTrade || AverageSpread > MaxAllowedSpread) {
      if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
         perfMonitor.EndTickMeasurement();
      }
      return;
   }

   // Simplified order management - only modify if really needed
   bool needsBuyOrder = (PendingBuyCount == 0 && OpenBuyCount < MaxOpenBuy);
   bool needsSellOrder = (PendingSellCount == 0 && OpenSellCount < MaxOpenSell);
   
   // Quick order placement logic
   if(needsBuyOrder && (CurrentTime - LastBuyOrderTime) > MinOrderInterval) {
      double entryPrice = Ask + AdjustedOrderDistance;
      double stopLoss = entryPrice - CalculatedStopLoss;
      
      if(entryPrice > Ask + MinStopDistance && stopLoss > 0) {
         double lotSize = CalculateOptimalLotSize(CalculatedStopLoss);
         if(lotSize >= MinLotSize && CheckPointer(riskManager) == POINTER_DYNAMIC) {
            // Convert CalculatedStopLoss (price units) to traditional pips
            double stopLossPips = CalculatedStopLoss / ((_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point);
            if(riskManager.IsTradeAllowed(lotSize, stopLossPips)) {
               if(trade.BuyStop(lotSize, entryPrice, _Symbol, stopLoss, 0, 0, "HFT_BUY")) {
                  riskManager.RegisterTradeRisk(lotSize, stopLossPips);
                  LastBuyOrderTime = CurrentTime;
                  if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
                     perfMonitor.LogTradeExecution();
                  }
               }
            }
         }
      }
   }
   
   if(needsSellOrder && (CurrentTime - LastSellOrderTime) > MinOrderInterval) {
      double entryPrice = Bid - AdjustedOrderDistance;
      double stopLoss = entryPrice + CalculatedStopLoss;
      
      if(entryPrice < Bid - MinStopDistance && stopLoss > 0) {
         double lotSize = CalculateOptimalLotSize(CalculatedStopLoss);
         if(lotSize >= MinLotSize && CheckPointer(riskManager) == POINTER_DYNAMIC) {
            // Convert CalculatedStopLoss (price units) to traditional pips
            double stopLossPips = CalculatedStopLoss / ((_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point);
            if(riskManager.IsTradeAllowed(lotSize, stopLossPips)) {
               if(trade.SellStop(lotSize, entryPrice, _Symbol, stopLoss, 0, 0, "HFT_SELL")) {
                  riskManager.RegisterTradeRisk(lotSize, stopLossPips);
                  LastSellOrderTime = CurrentTime;
                  if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
                     perfMonitor.LogTradeExecution();
                  }
               }
            }
         }
      }
   }

   // Performance monitoring end
   if(CheckPointer(perfMonitor) == POINTER_DYNAMIC) {
      perfMonitor.EndTickMeasurement();
   }
}