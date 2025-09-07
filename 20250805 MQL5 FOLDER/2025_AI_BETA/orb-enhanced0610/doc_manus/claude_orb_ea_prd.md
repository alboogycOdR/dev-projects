# Open Range Breakout EA v2.0 - Technical Product Requirements Document

## Document Information
- **Version**: 2.0.0
- **Language**: MQL5
- **Platform**: MetaTrader 5
- **Strategy**: Open Range Breakout with Advanced Features
- **Last Updated**: 2025-06-10

## 1. Project Overview

### 1.1 Objective
Refactor and enhance the existing Open Range Breakout Expert Advisor to improve reliability, performance, and profitability through modern software architecture and advanced trading features.

### 1.2 Scope
- Complete code refactoring using object-oriented design
- Enhanced error handling and input validation
- Advanced risk management system
- Market condition filtering
- Performance optimization
- Comprehensive logging and monitoring

## 2. Technical Architecture Requirements

### 2.1 Core Architecture

#### 2.1.1 Main EA Class Structure
```mql5
class COpenRangeBreakoutEA
{
private:
    CRangeManager* m_rangeManager;
    CRiskManager* m_riskManager;
    CPositionManager* m_positionManager;
    CMarketFilter* m_marketFilter;
    CNewsFilter* m_newsFilter;
    CLogger* m_logger;
    CSettings* m_settings;
    
public:
    bool Initialize();
    void OnTick();
    void OnDeinit();
    bool ValidateInputs();
};
```

#### 2.1.2 Required Classes
1. **CRangeManager** - Range calculation and validation
2. **CRiskManager** - Risk calculations and limits
3. **CPositionManager** - Trade execution and management
4. **CMarketFilter** - Market condition analysis
5. **CNewsFilter** - News-based trading restrictions
6. **CLogger** - Logging and monitoring
7. **CSettings** - Configuration management
8. **CInputValidator** - Input parameter validation

### 2.2 Data Structures

#### 2.2.1 Range Data Structure
```mql5
struct SRangeData
{
    datetime startTime;
    datetime endTime;
    double high;
    double low;
    double openPrice;
    double rangeWidth;
    bool calculated;
    bool valid;
    bool tradePlaced;
    int validationReasonCode;
};
```

#### 2.2.2 Settings Structure
```mql5
struct STradeSettings
{
    // Range settings
    int rangeStartHour;
    int rangeStartMinute;
    int rangeDurationMinutes;
    double minRangePoints;
    double maxRangePoints;
    
    // Risk settings
    ENUM_LOT_SIZE_MODE lotSizeMode;
    double fixedLotSize;
    double riskPercent;
    double maxLotSize;
    double maxDailyLossPercent;
    int maxTradesPerDay;
    
    // Stop loss settings
    ENUM_SL_MODE slMode;
    double fixedSLPercent;
    double slBufferPercent;
    
    // Position management
    bool enableBreakeven;
    double beActivationPercent;
    bool enableTrailingStop;
    double trailingActivationPercent;
    double trailingStopPercent;
    bool enablePartialProfits;
    
    // Filters
    bool enableVolumeFilter;
    double minVolumeMultiplier;
    bool enableVolatilityFilter;
    double minATRMultiplier;
    double maxATRMultiplier;
    bool enableSpreadFilter;
    double maxSpreadMultiplier;
    
    // Day and time filters
    bool dayFilters[7]; // Mon-Sun
    int endOfDayHour;
    int endOfDayMinute;
    
    // News filter
    bool enableNewsFilter;
    string newsKeywords;
    string newsCurrencies;
    int newsLookupDays;
};
```

## 3. Functional Requirements

### 3.1 Input Validation (Priority: HIGH)

#### 3.1.1 Requirements
- Validate all input parameters on initialization
- Provide clear error messages for invalid inputs
- Prevent EA startup with invalid configuration
- Support parameter ranges and dependencies

#### 3.1.2 Implementation Specifications
```mql5
class CInputValidator
{
public:
    struct SValidationResult
    {
        bool isValid;
        string errorMessage;
        int errorCode;
    };
    
    static SValidationResult ValidateTimeSettings(int hour, int minute, int duration);
    static SValidationResult ValidateRiskSettings(double riskPercent, double maxLot);
    static SValidationResult ValidateRangeSettings(double minRange, double maxRange);
    static SValidationResult ValidateFilterSettings(const STradeSettings& settings);
    static SValidationResult ValidateAll(const STradeSettings& settings);
};
```

#### 3.1.3 Validation Rules
- **Time Settings**: Hour (0-23), Minute (0-59), Duration (1-1440 minutes)
- **Risk Settings**: Risk % (0.1-50%), Max lot within broker limits
- **Range Settings**: Min range < Max range, both > 0
- **Filter Settings**: Multipliers > 0, valid currency codes

### 3.2 Enhanced Error Handling (Priority: HIGH)

#### 3.2.1 Requirements
- Implement retry logic for all trading operations
- Handle network failures and broker disconnections
- Graceful degradation when services are unavailable
- Detailed error logging with categorization

#### 3.2.2 Error Categories
```mql5
enum ENUM_ERROR_CATEGORY
{
    ERROR_CATEGORY_TRADE,
    ERROR_CATEGORY_DATA,
    ERROR_CATEGORY_NETWORK,
    ERROR_CATEGORY_VALIDATION,
    ERROR_CATEGORY_SYSTEM
};

struct SErrorInfo
{
    ENUM_ERROR_CATEGORY category;
    int errorCode;
    string description;
    datetime timestamp;
    bool isCritical;
};
```

#### 3.2.3 Trading Operation Error Handling
```mql5
class CTradeExecutor
{
private:
    struct SRetryConfig
    {
        int maxRetries;
        int retryDelayMs;
        bool exponentialBackoff;
    };
    
public:
    enum ENUM_TRADE_RESULT
    {
        TRADE_SUCCESS,
        TRADE_ERROR_RETRIABLE,
        TRADE_ERROR_FATAL,
        TRADE_ERROR_MARGIN,
        TRADE_ERROR_INVALID_PARAMS
    };
    
    ENUM_TRADE_RESULT ExecuteMarketOrder(ENUM_ORDER_TYPE orderType, double volume, 
                                        double sl, double tp, const SRetryConfig& config);
    ENUM_TRADE_RESULT ModifyPosition(ulong ticket, double sl, double tp, 
                                   const SRetryConfig& config);
    ENUM_TRADE_RESULT ClosePosition(ulong ticket, const SRetryConfig& config);
};
```

### 3.3 Advanced Risk Management (Priority: HIGH)

#### 3.3.1 Requirements
- Daily loss limits with automatic shutdown
- Maximum trades per day limits
- Position sizing based on account equity
- Correlation-based risk adjustment
- Real-time risk monitoring

#### 3.3.2 Implementation Specifications
```mql5
class CAdvancedRiskManager
{
private:
    struct SDailyRiskStats
    {
        datetime date;
        int tradesCount;
        double realizedPnL;
        double unrealizedPnL;
        double maxDrawdown;
        double peakEquity;
    };
    
    struct SRiskLimits
    {
        double maxDailyLossPercent;
        double maxDailyLossAmount;
        int maxTradesPerDay;
        double maxRiskPerTrade;
        double maxTotalRisk;
    };
    
public:
    bool CheckDailyLimits();
    double CalculateOptimalLotSize(double entryPrice, double stopLoss, double riskPercent);
    bool ValidateTradeRisk(double lotSize, double stopDistance);
    void UpdateRiskStats(double pnl);
    SRiskLimits GetCurrentLimits();
    SDailyRiskStats GetDailyStats();
};
```

#### 3.3.3 Risk Calculation Rules
- **Position Sizing**: Kelly Criterion or Fixed Fractional based on stop loss
- **Daily Limits**: Configurable % of account balance
- **Maximum Risk**: Total portfolio risk should not exceed threshold
- **Correlation Adjustment**: Reduce size if multiple correlated positions exist

### 3.4 Market Condition Filtering (Priority: MEDIUM)

#### 3.4.1 Requirements
- Volatility-based trade filtering using ATR
- Spread condition monitoring
- Trading session awareness
- Market hours validation
- Liquidity assessment

#### 3.4.2 Implementation Specifications
```mql5
class CMarketConditionFilter
{
private:
    struct SMarketConditions
    {
        double currentATR;
        double avgATR;
        double currentSpread;
        double avgSpread;
        bool isLiquidSession;
        bool isVolatilityAppropriate;
        bool isSpreadAcceptable;
        ENUM_MARKET_SESSION currentSession;
    };
    
public:
    enum ENUM_MARKET_SESSION
    {
        SESSION_ASIAN,
        SESSION_LONDON,
        SESSION_NEW_YORK,
        SESSION_OVERLAP_LONDON_NY,
        SESSION_QUIET
    };
    
    bool UpdateMarketConditions();
    bool IsConditionsSuitableForTrading();
    SMarketConditions GetCurrentConditions();
    bool IsVolatilityInRange(double minMultiplier, double maxMultiplier);
    bool IsSpreadAcceptable(double maxMultiplier);
    ENUM_MARKET_SESSION GetCurrentSession();
};
```

#### 3.4.3 Filter Criteria
- **ATR Filter**: Current ATR within 0.5x to 2.0x of 20-period average
- **Spread Filter**: Current spread < 2x average spread
- **Session Filter**: Active during major trading sessions
- **Volume Filter**: Minimum volume requirements met

### 3.5 Advanced Position Management (Priority: MEDIUM)

#### 3.5.1 Requirements
- Multi-level partial profit taking
- Dynamic trailing stop adjustment
- Breakeven management with buffer
- Position scaling capabilities
- Time-based position management

#### 3.5.2 Implementation Specifications
```mql5
class CAdvancedPositionManager
{
private:
    struct SProfitLevel
    {
        double triggerPrice;
        double partialClosePercent;
        double trailingStopDistance;
        bool executed;
        datetime executionTime;
    };
    
    struct SPositionData
    {
        ulong ticket;
        double entryPrice;
        double currentSL;
        double currentTP;
        double rangeWidth;
        SProfitLevel profitLevels[5];
        bool breakEvenSet;
        bool trailingActive;
    };
    
public:
    bool InitializePosition(ulong ticket, double rangeWidth);
    void ManageActivePosition();
    bool ExecutePartialClose(double percentage);
    bool UpdateTrailingStop(double newStopLevel);
    bool MoveToBreakEven(double buffer = 0);
    SPositionData GetPositionInfo();
};
```

#### 3.5.3 Position Management Rules
- **Level 1**: Close 25% at 1x range profit, move SL to breakeven
- **Level 2**: Close 50% at 2x range profit, trail at 1x range distance
- **Level 3**: Close 25% at 3x range profit, trail at 0.5x range distance
- **Final Position**: Trail remaining position with tight stops

### 3.6 Performance Optimization (Priority: MEDIUM)

#### 3.6.1 Requirements
- Cache frequently calculated values
- Minimize indicator recalculations
- Optimize memory usage
- Reduce computational complexity
- Implement lazy loading for non-critical features

#### 3.6.2 Caching Strategy
```mql5
class CDataCache
{
private:
    struct SCachedData
    {
        datetime lastUpdate;
        double value;
        bool isValid;
        int barCount;
    };
    
    SCachedData m_atrCache;
    SCachedData m_volumeCache;
    SCachedData m_spreadCache;
    
public:
    bool UpdateATRCache(int period, ENUM_TIMEFRAMES timeframe);
    bool UpdateVolumeCache(int lookbackBars, ENUM_TIMEFRAMES timeframe);
    bool UpdateSpreadCache();
    
    double GetCachedATR() { return m_atrCache.value; }
    double GetCachedAvgVolume() { return m_volumeCache.value; }
    double GetCachedAvgSpread() { return m_spreadCache.value; }
    
    void InvalidateCache();
    bool IsCacheValid(datetime currentTime, int maxAgeSeconds = 300);
};
```

### 3.7 Logging and Monitoring (Priority: LOW)

#### 3.7.1 Requirements
- Structured logging with multiple levels
- Trade execution logging
- Performance metrics tracking
- Error categorization and reporting
- Historical data retention

#### 3.7.2 Implementation Specifications
```mql5
enum ENUM_LOG_LEVEL
{
    LOG_LEVEL_FATAL,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_WARN,
    LOG_LEVEL_INFO,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_TRACE
};

class CLogger
{
private:
    struct SLogEntry
    {
        datetime timestamp;
        ENUM_LOG_LEVEL level;
        string category;
        string message;
        string context;
    };
    
    ENUM_LOG_LEVEL m_logLevel;
    int m_fileHandle;
    bool m_consoleOutput;
    string m_logFile;
    
public:
    bool Initialize(ENUM_LOG_LEVEL level, const string& filename, bool console = true);
    void Log(ENUM_LOG_LEVEL level, const string& category, const string& message, 
             const string& context = "");
    void LogTrade(const string& action, double price, double volume, double sl, double tp);
    void LogError(const SErrorInfo& error);
    void LogPerformance(const string& operation, int executionTimeMs);
    void Flush();
    void Cleanup();
};
```

## 4. Implementation Guidelines

 
1. Create base class structure
2. Implement input validation
3. Add basic error handling
4. Set up logging system

####  Core Features  
1. Refactor range management
2. Implement advanced risk management
3. Add market condition filters
4. Enhance position management

####  Optimization 
1. Implement caching system
2. Performance optimization
3. Memory usage optimization
4. Testing and validation

####  Advanced Features 
1. Multi-level profit taking
2. Advanced trailing stops
3. Correlation analysis
4. Final testing and documentation

### 4.2 Code Standards

#### 4.2.1 Naming Conventions
- **Classes**: PascalCase with 'C' prefix (e.g., `CRiskManager`)
- **Structures**: PascalCase with 'S' prefix (e.g., `STradeSettings`)
- **Enums**: UPPER_CASE with prefix (e.g., `ENUM_LOG_LEVEL`)
- **Member Variables**: camelCase with 'm_' prefix (e.g., `m_riskManager`)
- **Methods**: PascalCase (e.g., `CalculateLotSize`)
- **Constants**: UPPER_CASE (e.g., `MAX_RETRY_ATTEMPTS`)

#### 4.2.2 Error Handling
- Always check return values of MQL5 functions
- Use structured error handling with specific error codes
- Implement graceful degradation where possible
- Log all errors with appropriate context

#### 4.2.3 Performance Guidelines
- Cache expensive calculations
- Use appropriate data types
- Minimize memory allocations
- Avoid unnecessary loops in OnTick()

 

## 6. Acceptance Criteria

### 6.1 Functional Criteria
- [ ] All input parameters properly validated
- [ ] Error handling covers all trading operations
- [ ] Risk limits properly enforced
- [ ] Market condition filters working correctly
- [ ] Position management executing as designed
- [ ] Logging system capturing all required data

### 6.2 Performance Criteria
- [ ] OnTick() execution time < 10ms average
- [ ] Memory usage stable over extended periods
- [ ] No memory leaks detected
- [ ] Cache hit rate > 90% for frequently accessed data

### 6.3 Quality Criteria
- [ ] Code coverage > 80%
- [ ] No critical bugs in strategy testing
- [ ] Documentation complete and accurate
- [ ] Code review completed and approved

## 7. Dependencies and Constraints

### 7.1 Technical Dependencies
- MetaTrader 5 platform (build 3850+)
- MQL5 Standard Library
- Calendar API for news filtering
- Sufficient broker API rate limits

### 7.2 Constraints
- Maximum 10ms execution time per OnTick()
- Memory usage < 50MB
- File I/O operations minimized
- Network operations should be asynchronous where possible

 