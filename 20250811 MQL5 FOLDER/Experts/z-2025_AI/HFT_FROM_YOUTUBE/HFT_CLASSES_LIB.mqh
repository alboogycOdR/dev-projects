//+------------------------------------------------------------------+
//|                                                    HFT_CLASSES_LIB.mqh|
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
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