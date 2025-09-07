//+------------------------------------------------------------------+
//|                                        TickMomentumScalperEA.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                              https://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.example.com"
#property version   "1.30" // Incremented version
#property description "High-Frequency Tick Momentum Scalper for XAUUSD / USD Pairs"
#property description "Includes optional DXY Daily Bias Filter, Market Open check, enhanced Risk Management."
#property description "Uses Martingale Grid or Fixed Lot. NO STOP LOSS."
#property description "EXTREMELY HIGH RISK STRATEGY."

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

// --- Assumed Global Variables (Must be defined in the main EA scope) ---
CTrade         trade;          // Trading object
CSymbolInfo    symbolInfo;     // Symbol properties object
CPositionInfo  positionInfo;   // Position information object
CAccountInfo   accountInfo;    // Account information object

// Tick storage
double         tickPrices[];   // Array for recent prices
int            tickIndex;      // Current index for tickPrices
int            ticksStored;    // Counter for initial ticks stored

// Position tracking (updated by AnalyzeOpenPositions)
int            buyPositionsCount;
int            sellPositionsCount;
double         highestBuyPrice;
double         lowestSellPrice;
double         totalBuyProfit;
double         totalSellProfit;
double         nextBuyLot;
double         nextSellLot;
double         totalBuyLots;
double         totalSellLots;

// Grid price tracking
double         lastBuyGridPrice;
double         lastSellGridPrice;

// Risk Management Globals
double         peakEquity;
bool           accountStopped;
bool           isPaused;
datetime       pauseEndTime;

// --- Assumed Input Parameters (Must be defined as inputs in the main EA) ---
// Example inputs needed by these functions:
input double         MaxAccountDrawdownPercent = 30.0;
input bool           StopTradingAfterAccountSL = true;
input bool           PauseAfterLoss            = true;
input int            PauseDurationMinutes      = 60;
input double         MinMarginLevelPercent     = 150.0;
//input string         _Symbol                   = "XAUUSD"; // Or get from ChartSymbol()
input ENUM_DAY_OF_WEEK  StartDay               = MONDAY;
input int            StartHour                 = 0;
input int            StartMinute               = 0;
input ENUM_DAY_OF_WEEK  EndDay                 = FRIDAY;
input int            EndHour                   = 23;
input int            EndMinute                 = 59;
input int            MaxAllowedSpread          = 30;
input double         BasketProfitTarget_USD    = 1.50;
input bool           CloseBasketOnMaxDD        = true;
input double         MaxBasketDrawdownUSD      = 50.0;
input bool           UseMartingale             = true;
input double         MartingaleMultiplier      = 1.6;
input double         InitialLotSize            = 0.01;
input ulong          MagicNumber               = 123456;
input string         EaComment                 = "TickScalperDXY";
input uint           Slippage                  = 3;
input double         MaxAllowedLotSize         = 5.0;
input int            TickCheckPeriod           = 2; // Needed by StoreTickPrice logic

// Parameters for Dynamic TP (if used in CheckCloseBaskets)
input bool           UseDynamicBasketTP        = false;
 

// Trade Logic
input group             "Trade Logic Settings"
input int               MinMovePoints        = 10;       // Minimum points price must move for initial entry
 
// Risk Management
input group             "Risk Management Settings"
 //input double            InitialLotSize       = 0.01;     // Initial Lot Size (or Fixed Lot Size if UseMartingale=false)
//input double            MartingaleMultiplier = 1.6;      // Lot multiplier for grid steps (if UseMartingale=true)
input int               GridStepPoints       = 50;       // Points in drawdown before adding next grid trade
input int               MaxTrades            = 10;       // Maximum total open trades allowed



// DXY Daily Bias Filter << NEW SECTION >>
input group             "DXY Daily Bias Filter Settings"
input bool              UseDxyBiasFilter     = true;     // Enable the DXY bias filter?
input string            DxySymbolName        = "USDX";   // !!! IMPORTANT: Change to your Broker's DXY Symbol !!!
input ENUM_TIMEFRAMES   DxyBiasTimeframe     = PERIOD_D1;// Timeframe for bias calculation (usually D1)
// -- Bias Calculation Method Parameters --
// Example: Price vs MA
input int               DxyMaPeriod          = 20;       // MA Period for DXY bias calculation
input ENUM_MA_METHOD    DxyMaMethod          = MODE_SMA; // MA Method (SMA, EMA, etc.)
input ENUM_APPLIED_PRICE DxyMaAppliedPrice   = PRICE_CLOSE; // Price to apply MA to

 
input bool              UseTimeFilter        = true;     // Enable Time Filter?

// Profitability & Efficiency
input group             "Profitability & Efficiency"
input bool              UseDynamicGridStep        = false;   // Use ATR for grid step?
input int               AtrPeriodGrid             = 14;      // ATR Period for dynamic grid step (e.g., on M1/M5)
input double            AtrMultiplierGrid         = 0.5;     // ATR Multiplier for dynamic grid step
input ENUM_TIMEFRAMES   AtrTimeframeGrid          = PERIOD_M5; // Timeframe for ATR Grid Calc
//input bool              UseDynamicBasketTP        = false;   // Use ATR or Lot Size for basket TP?
input int               AtrPeriodTP               = 14;      // ATR Period for dynamic TP (e.g., on M1/M5)
input double            AtrMultiplierTP           = 0.3;     // ATR Multiplier for dynamic TP
input ENUM_TIMEFRAMES   AtrTimeframeTP            = PERIOD_M5; // Timeframe for ATR TP Calc
input double            BasketTPPerLot            = 0.0;     // Alternative Dynamic TP: Target USD per total Lot size in basket (0 = disabled, overrides ATR TP if > 0)
input int               MinSecondsBetweenEntries  = 3;       // Minimum seconds between INITIAL entries (0=disabled)


// EA Identification & Execution
input group             "EA Identification & Execution"
 
 
// Risk Management Globals
double         startBalance = 0;
 

// Timing Globals
datetime       lastInitialBuyTime = 0;
datetime       lastInitialSellTime = 0;

// DXY Bias Globals << NEW >>
enum ENUM_DAILY_BIAS
{
   BIAS_NEUTRAL, // Bias couldn't be determined or filter disabled
   BIAS_BULLISH, // Expecting USD Strength
   BIAS_BEARISH  // Expecting USD Weakness
};
ENUM_DAILY_BIAS dailyUSDBias = BIAS_NEUTRAL;
datetime       lastBiasCheckTime = 0;       // Timestamp of the last bias calculation
string         cachedDxySymbol = "";        // Store validated DXY symbol name
bool           dxySymbolAvailable = false;  // Flag if DXY symbol exists

// Pair Type Global << NEW >>
enum ENUM_PAIR_TYPE
{
   PAIR_TYPE_UNKNOWN,
   PAIR_TYPE_XXXUSD,  // Base currency is NOT USD (e.g., EURUSD, GBPUSD)
   PAIR_TYPE_USDXXX,  // Base currency IS USD (e.g., USDJPY, USDCAD)
   PAIR_TYPE_XAUUSD   // Specific handling for Gold
};
ENUM_PAIR_TYPE currentPairType = PAIR_TYPE_UNKNOWN;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize standard objects
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFillingBySymbol(_Symbol);
   if(!symbolInfo.Name(_Symbol)) return(INIT_FAILED);
   //if(!accountInfo.Select()) return(INIT_FAILED);
   positionInfo.SelectByMagic(_Symbol, MagicNumber);

   //--- Initialize Tick Array
   if(TickCheckPeriod <= 0) return(INIT_FAILED);
   ArrayResize(tickPrices, TickCheckPeriod + 1); ArrayInitialize(tickPrices, 0.0);
   tickIndex = 0; ticksStored = 0;

   //--- Initialize Risk Management
   startBalance = accountInfo.Balance(); peakEquity = MathMax(accountInfo.Equity(), startBalance);
   accountStopped = false; isPaused = false; pauseEndTime = 0;

   //--- Validate Standard Inputs
   if(MaxTrades <= 0) return(INIT_FAILED);
   if(UseMartingale && MartingaleMultiplier <= 1.0) return(INIT_FAILED);
   if(MaxAllowedLotSize > 0 && InitialLotSize > MaxAllowedLotSize) return(INIT_FAILED);

   //--- Initialize DXY Bias Filter << NEW >>
   dailyUSDBias = BIAS_NEUTRAL; // Start neutral
   lastBiasCheckTime = 0;       // Ensure calculation runs on first tick
   cachedDxySymbol = DxySymbolName;
   dxySymbolAvailable = SymbolSelect(cachedDxySymbol, true); // Check if symbol exists and subscribe
   if(!dxySymbolAvailable)
     {
      Print("Warning: DXY Symbol '", cachedDxySymbol, "' not found or available from broker. Bias filter will be disabled.");
      // Optionally force UseDxyBiasFilter to false here
      // UseDxyBiasFilter = false;
     }
   else
     {
      Print("DXY Symbol '", cachedDxySymbol, "' found. Bias filter enabled: ", UseDxyBiasFilter);
     }

   //--- Determine Current Pair Type << NEW >>
   currentPairType = GetPairType(_Symbol);
   if(currentPairType == PAIR_TYPE_UNKNOWN)
     {
      Print("Warning: Could not determine pair type for ", _Symbol, ". Bias filter might not work correctly.");
     }

   Print("TickMomentumScalperEA Initialized Successfully (v", DoubleToString(_Digits), ").");
   // ... Add more print statements for key settings ...

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Unsubscribe from DXY symbol if it was subscribed
   if(dxySymbolAvailable)
     {
      SymbolSelect(cachedDxySymbol, false);
     }
   Print("TickMomentumScalperEA Deinitialized. Reason: ", reason);
   ArrayFree(tickPrices);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Standard Checks First
   if(accountStopped) return;
   
   //if(!accountInfo.Refresh()) return;
   
   peakEquity = MathMax(peakEquity, accountInfo.Equity());
   if(CheckAccountStopLoss()) return;
   if(isPaused) { if(TimeCurrent() >= pauseEndTime) isPaused = false; else return; }
   if(!symbolInfo.RefreshRates()) return;
   if(UseTimeFilter && !CheckTimeFilter()) return;
   if(!IsMarketOpenForSymbol()) return;
   if(!CheckSpreadFilter()) return;
   if(!CheckMarginLevelFilter()) return;

   //--- Update DXY Daily Bias (runs once per day) << NEW >>
   UpdateDailyBias();

   //--- Store tick price & check history
   double currentMidPrice = (symbolInfo.Ask() + symbolInfo.Bid()) / 2.0;
   StoreTickPrice(currentMidPrice);
   if(ticksStored <= TickCheckPeriod) return;

   //--- Analyze positions & Check for Basket Closures
   int totalOpenPositions = AnalyzeOpenPositions();
   CheckCloseBaskets();

   //--- Logic for Opening New Trades (Filtered by DXY Bias) << MODIFIED >>
   if(totalOpenPositions < MaxTrades)
     {
      // Calculate momentum
      double previousPrice = tickPrices[(tickIndex - TickCheckPeriod + ArraySize(tickPrices)) % ArraySize(tickPrices)];
      double priceMove = currentMidPrice - previousPrice;
      double priceMovePoints = priceMove / symbolInfo.Point();

      // Calculate dynamic grid step if enabled
      int currentGridStepPoints = GridStepPoints;
      if(UseDynamicGridStep) { /* ... calculation ... */ } // Keep dynamic grid logic if needed

      // --- Initial Entry Logic (Filtered) ---
      if(totalOpenPositions == 0)
        {
         bool canEnterBuy = (MinSecondsBetweenEntries <= 0 || TimeCurrent() >= lastInitialBuyTime + MinSecondsBetweenEntries);
         bool canEnterSell = (MinSecondsBetweenEntries <= 0 || TimeCurrent() >= lastInitialSellTime + MinSecondsBetweenEntries);

         // Check Buy Entry + DXY Filter
         if(priceMovePoints >= MinMovePoints && canEnterBuy && IsTradeDirectionAllowed(ORDER_TYPE_BUY)) // << DXY Filter Check
           {
            if(OpenBuyPosition(InitialLotSize)) lastInitialBuyTime = TimeCurrent();
           }
         // Check Sell Entry + DXY Filter
         else if(priceMovePoints <= -MinMovePoints && canEnterSell && IsTradeDirectionAllowed(ORDER_TYPE_SELL)) // << DXY Filter Check
           {
            if(OpenSellPosition(InitialLotSize)) lastInitialSellTime = TimeCurrent();
           }
        }
      // --- Grid Entry Logic (Filtered) ---
      else if(totalOpenPositions > 0)
        {
         double currentBid = symbolInfo.Bid();
         double currentAsk = symbolInfo.Ask();

         // Buy Grid + DXY Filter
         if(buyPositionsCount > 0 && currentBid < highestBuyPrice - (currentGridStepPoints * symbolInfo.Point()))
           {
            if(IsTradeDirectionAllowed(ORDER_TYPE_BUY)) // << DXY Filter Check
              {
               if(NormalizeDouble(currentBid, symbolInfo.Digits()) != NormalizeDouble(lastBuyGridPrice, symbolInfo.Digits()))
                 {
                  double lotToUse = UseMartingale ? nextBuyLot : InitialLotSize;
                  if(OpenBuyPosition(lotToUse)) lastBuyGridPrice = currentBid;
                 }
              }
           }
         // Sell Grid + DXY Filter
         else if(sellPositionsCount > 0 && currentAsk > lowestSellPrice + (currentGridStepPoints * symbolInfo.Point()))
           {
            if(IsTradeDirectionAllowed(ORDER_TYPE_SELL)) // << DXY Filter Check
              {
               if(NormalizeDouble(currentAsk, symbolInfo.Digits()) != NormalizeDouble(lastSellGridPrice, symbolInfo.Digits()))
                 {
                  double lotToUse = UseMartingale ? nextSellLot : InitialLotSize;
                  if(OpenSellPosition(lotToUse)) lastSellGridPrice = currentAsk;
                 }
              }
           }
        } // End Grid Entry Logic
     } // End if(totalOpenPositions < MaxTrades)
}

//+------------------------------------------------------------------+
//| Determine Pair Type relative to USD                              |
//+------------------------------------------------------------------+
ENUM_PAIR_TYPE GetPairType(string symbol)
{
   string baseCurrency = StringSubstr(symbol, 0, 3);
   string quoteCurrency = StringSubstr(symbol, 3, 3); // Assumes standard 6-char symbols

   if(StringLen(symbol) == 6) // Basic check for Forex pairs
     {
      if(baseCurrency == "USD")
        {
         return PAIR_TYPE_USDXXX;
        }
      else if(quoteCurrency == "USD")
        {
         return PAIR_TYPE_XXXUSD;
        }
     }
   else if(symbol == "XAUUSD") // Specific check for Gold
     {
      return PAIR_TYPE_XAUUSD;
     }

   return PAIR_TYPE_UNKNOWN; // Default if not recognized
}

//+------------------------------------------------------------------+
//| Check if Trade Direction is Allowed based on DXY Bias            |
//+------------------------------------------------------------------+
bool IsTradeDirectionAllowed(ENUM_ORDER_TYPE direction)
{
   // If filter is disabled, always allow
   if(!UseDxyBiasFilter || !dxySymbolAvailable) return true;

   // If bias is neutral, allow both directions (or could choose to block all)
   if(dailyUSDBias == BIAS_NEUTRAL) return true;

   // Determine allowed direction based on bias and pair type
   switch(currentPairType)
     {
      case PAIR_TYPE_XXXUSD: // e.g., EURUSD, GBPUSD
         // If DXY Bullish (USD Strong), only allow SELL XXXUSD
         // If DXY Bearish (USD Weak), only allow BUY XXXUSD
         if(dailyUSDBias == BIAS_BULLISH && direction == ORDER_TYPE_SELL) return true;
         if(dailyUSDBias == BIAS_BEARISH && direction == ORDER_TYPE_BUY) return true;
         break;

      case PAIR_TYPE_USDXXX: // e.g., USDJPY, USDCAD
         // If DXY Bullish (USD Strong), only allow BUY USDXXX
         // If DXY Bearish (USD Weak), only allow SELL USDXXX
         if(dailyUSDBias == BIAS_BULLISH && direction == ORDER_TYPE_BUY) return true;
         if(dailyUSDBias == BIAS_BEARISH && direction == ORDER_TYPE_SELL) return true;
         break;

      case PAIR_TYPE_XAUUSD: // Gold (moves inversely to USD strength)
         // If DXY Bullish (USD Strong), only allow SELL XAUUSD
         // If DXY Bearish (USD Weak), only allow BUY XAUUSD
         if(dailyUSDBias == BIAS_BULLISH && direction == ORDER_TYPE_SELL) return true;
         if(dailyUSDBias == BIAS_BEARISH && direction == ORDER_TYPE_BUY) return true;
         break;

      default: // PAIR_TYPE_UNKNOWN
         return true; // Allow if pair type is unknown to avoid blocking unnecessarily
     }

   // If we reach here, the direction is not allowed by the filter
   // Print("Trade blocked by DXY Bias. Bias: ", EnumToString(dailyUSDBias), ", Direction: ", EnumToString(direction), ", PairType: ", EnumToString(currentPairType)); // Optional debug print
   return false;
}

//+------------------------------------------------------------------+
//| Update DXY Daily Bias (runs once per day)                        |
//+------------------------------------------------------------------+
void UpdateDailyBias()
{
   // Check if filter enabled and symbol available
   if(!UseDxyBiasFilter || !dxySymbolAvailable)
     {
      dailyUSDBias = BIAS_NEUTRAL; // Ensure neutral if disabled
      return;
     }

   // Check if it's time to recalculate (only once per day, e.g., after midnight)
   datetime currentTime = TimeCurrent();
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0); // Get timestamp of the current day's start

   // Only update if the current time is past the start of today AND we haven't checked today yet
   if(currentTime >= startOfDay && lastBiasCheckTime < startOfDay)
     {
      ENUM_DAILY_BIAS calculatedBias = BIAS_NEUTRAL; // Default to neutral

      // --- Method: Price vs MA (Example) ---
      MqlRates dxyRates[2];
      if(CopyRates(cachedDxySymbol, DxyBiasTimeframe, 0, 2, dxyRates) == 2) // Get price data
        {
         double dxyClose[2];
         dxyClose[0] = dxyRates[0].close;
         dxyClose[1] = dxyRates[1].close;

         if(dxyClose[0] > 0 && dxyClose[1] > 0) // Check if both prices are valid
           {
            // Initialize variables
            double maValue = 0.0;
            
            // Create MA indicator handle
            int maHandle = iMA(cachedDxySymbol, DxyBiasTimeframe, DxyMaPeriod, 0, DxyMaMethod, DxyMaAppliedPrice);
            
            if(maHandle != INVALID_HANDLE)
              {
               // Set up buffer to receive MA values
               double maBuffer[];
               ArraySetAsSeries(maBuffer, true);
               
               // Copy MA values into buffer (1 value from position 1 - previous bar)
               if(CopyBuffer(maHandle, 0, 1, 1, maBuffer) > 0)
                 {
                  maValue = maBuffer[0];  // Get MA value for the previous bar
                 }
               // Release indicator handle to prevent resource leaks
               IndicatorRelease(maHandle);
               
               // Process the MA value
               if(maValue > 0) // Ensure valid MA value
                 {
                  // Compare previous close price to the MA
                  if(dxyClose[0] > maValue)
                    {
                     calculatedBias = BIAS_BULLISH;
                    }
                  else if(dxyClose[0] < maValue)
                    {
                     calculatedBias = BIAS_BEARISH;
                    }
                  Print("DXY Bias Updated (Price vs MA). DXY Close[1]: ", dxyClose[0], ", MA(", DxyMaPeriod, ")[1]: ", maValue, ", Bias: ", EnumToString(calculatedBias));
                 }
               else
                 {
                  Print("Warning: Invalid MA value for DXY. Setting Bias to Neutral.");
                  calculatedBias = BIAS_NEUTRAL;
                 }
              }
            else
              {
               Print("Warning: Could not create MA indicator handle. Setting Bias to Neutral.");
               calculatedBias = BIAS_NEUTRAL;
              }
           }
         else
           {
            Print("Warning: Invalid DXY price data. Setting Bias to Neutral.");
            calculatedBias = BIAS_NEUTRAL;
           }
        }
      else
        {
         Print("Warning: Could not copy DXY rates. Setting Bias to Neutral.");
         calculatedBias = BIAS_NEUTRAL;
        }

      // --- Add other calculation methods here using 'else if (BiasCalculationMethod == ...)' ---
      // Example Placeholder: MA Crossover
      /*
      else if (BiasCalculationMethod == METHOD_MA_CROSS) {
          // Would need similar pattern to create indicator handles, copy buffers, etc.
          // Would need properly defined FastMaPeriod, SlowMaPeriod constants
          Print("DXY Bias Updated (MA Cross). Bias: ", EnumToString(calculatedBias));
      }
      */

      // Update the global bias and timestamp
      dailyUSDBias = calculatedBias;
      lastBiasCheckTime = currentTime; // Store the time we performed the check

     } // End if time to recalculate
}



//+------------------------------------------------------------------+
//| Check Account Stop Loss based on Peak Equity Drawdown            |
//+------------------------------------------------------------------+
bool CheckAccountStopLoss()
{
   // Check if the feature is enabled
   if(MaxAccountDrawdownPercent <= 0)
      return false; // Disabled

   double currentEquity = accountInfo.Equity();
   // Calculate the equity level that triggers the stop loss
   double drawdownThreshold = peakEquity * (1.0 - MaxAccountDrawdownPercent / 100.0);

   // Check if current equity has fallen below the threshold
   if(currentEquity <= drawdownThreshold)
     {
      Print("ACCOUNT STOP LOSS HIT!");
      Print("Peak Equity: ", DoubleToString(peakEquity, 2));
      Print("Current Equity: ", DoubleToString(currentEquity, 2));
      Print("Drawdown Threshold (", MaxAccountDrawdownPercent, "%): ", DoubleToString(drawdownThreshold, 2));
      Print("Closing all positions...");

      // Close all positions managed by this EA instance
      CloseAllBuys();
      CloseAllSells();

      // Decide whether to stop permanently or pause
      if(StopTradingAfterAccountSL)
        {
         Print("Permanently stopping EA activity for this chart.");
         accountStopped = true; // Set flag to stop OnTick processing
         // ExpertRemove();        // Optionally remove the EA from the chart completely
        }
      else if(PauseAfterLoss) // If not stopping permanently, check if pausing
        {
         isPaused = true;
         pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
         Print("EA paused for ", PauseDurationMinutes, " minutes due to Account SL hit.");
        }
      return true; // Indicate SL was hit and handled
     }
   return false; // SL not hit
}

//+------------------------------------------------------------------+
//| Check Margin Level Filter                                        |
//+------------------------------------------------------------------+
bool CheckMarginLevelFilter()
{
   // Check if the feature is enabled
   if(MinMarginLevelPercent <= 0)
      return true; // Filter disabled

   // Get the current account margin level percentage
   double currentMarginLevel = accountInfo.MarginLevel();

   // Check if the margin level is below the required minimum
   if(currentMarginLevel < MinMarginLevelPercent)
     {
      // Optional Print (uncomment for debugging, prints max once per minute)
      /*
      static datetime last_margin_print = 0;
      if(TimeCurrent() > last_margin_print + 60) {
         Print("Margin Level ", DoubleToString(currentMarginLevel, 1), "% is below threshold ", MinMarginLevelPercent, "%. No new trades allowed.");
         last_margin_print = TimeCurrent();
      }
      */
      return false; // Margin too low, prevent opening new trades
     }
   return true; // Margin level is sufficient
}

//+------------------------------------------------------------------+
//| Check if Market Session is Open for the EA's Symbol              |
//+------------------------------------------------------------------+
bool IsMarketOpenForSymbol()
{
   MqlDateTime current_time_struct;
   datetime current_server_time = TimeCurrent(); // Get current server time once
   TimeToStruct(current_server_time, current_time_struct);

   // Get session times for the current day of the week for the chart symbol
   datetime session_start_dt = 0;
   datetime session_end_dt = 0;

   // Try to get the first trading session (index 0) for the current day
   // Note: More complex logic might be needed if symbols have multiple sessions per day or cross midnight weirdly
   if(!SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)current_time_struct.day_of_week, 0, session_start_dt, session_end_dt))
     {
      // Could not get session info, assume closed for safety or print warning
      // static datetime last_session_error_print = 0;
      // if(TimeCurrent() > last_session_error_print + 300) {
      //     Print("Warning: Could not retrieve trading session info for ", _Symbol, " on day ", EnumToString((ENUM_DAY_OF_WEEK)current_time_struct.day_of_week));
      //     last_session_error_print = TimeCurrent();
      // }
      return false;
     }

   // Check if the current server time is within the retrieved session interval
   // Note the check is >= start and < end. Usually sessions end exactly at the start of the next period.
   if(current_server_time >= session_start_dt && current_server_time < session_end_dt)
     {
      return true; // Market is open
     }

   // Market is closed if not within the session interval
   return false;
}

//+------------------------------------------------------------------+
//| Store Tick Price in a Circular Buffer                            |
//+------------------------------------------------------------------+
void StoreTickPrice(double price)
{
   // Check if the array is initialized (should be in OnInit)
   if(ArraySize(tickPrices) <= 0) return;

   // Store the price at the current index
   tickPrices[tickIndex] = price;
   // Move index to the next position, wrapping around if needed
   tickIndex = (tickIndex + 1) % ArraySize(tickPrices);

   // Increment the counter of stored ticks, but cap it at the array size
   if(ticksStored < ArraySize(tickPrices)) // Use ArraySize to know when buffer is full
     {
      ticksStored++;
     }
}

//+------------------------------------------------------------------+
//| Check Time Filter based on Inputs                               |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   MqlDateTime current_time_struct;
   TimeCurrent(current_time_struct); // Get current server time structure

   // Convert start, end, and current times to minutes since Sunday 00:00 for easy comparison
   int start_total_minutes = (int)StartDay * 24 * 60 + StartHour * 60 + StartMinute;
   int end_total_minutes = (int)EndDay * 24 * 60 + EndHour * 60 + EndMinute;
   int current_total_minutes = current_time_struct.day_of_week * 24 * 60 + current_time_struct.hour * 60 + current_time_struct.min;

   // Handle week-wrap scenario (e.g., trading ends Friday early and starts Sunday late)
   if(start_total_minutes <= end_total_minutes)
     {
      // Normal case: Start and end within the same logical week span (e.g., Mon 9:00 to Fri 17:00)
      if(current_total_minutes >= start_total_minutes && current_total_minutes <= end_total_minutes)
         return true; // Within allowed time
     }
   else // Wrap-around case: End time is earlier in the week than start time (e.g., Sun 22:00 to Fri 21:00)
     {
      if(current_total_minutes >= start_total_minutes || current_total_minutes <= end_total_minutes)
         return true; // Within allowed time (either after start OR before end)
     }

   // If none of the conditions were met, we are outside the allowed trading time
   return false;
}

//+------------------------------------------------------------------+
//| Check Spread Filter                                              |
//+------------------------------------------------------------------+
bool CheckSpreadFilter()
{
   // Check if the filter is enabled
   if(MaxAllowedSpread <= 0)
      return true; // Filter disabled

   // Refresh symbol rates to get the latest spread
   symbolInfo.RefreshRates();
   long currentSpread = symbolInfo.Spread(); // Spread in points

   // Check if the current spread exceeds the maximum allowed
   if(currentSpread > MaxAllowedSpread)
     {
      // Optional Print (uncomment for debugging, prints max once per minute)
      /*
      static datetime last_spread_print = 0;
      if(TimeCurrent() > last_spread_print + 60) {
         Print("Spread too high: ", currentSpread, " > ", MaxAllowedSpread, ". Trading paused.");
         last_spread_print = TimeCurrent();
      }
      */
      return false; // Spread too high
     }
   return true; // Spread is acceptable
}

//+------------------------------------------------------------------+
//| Analyze Open Positions for the EA                                |
//+------------------------------------------------------------------+
int AnalyzeOpenPositions()
{
   // --- Reset global counters and accumulators ---
   buyPositionsCount = 0;
   sellPositionsCount = 0;
   totalBuyProfit = 0.0;
   totalSellProfit = 0.0;
   totalBuyLots = 0.0;
   totalSellLots = 0.0;
   highestBuyPrice = 0.0;        // Use 0 as initial high for buys
   lowestSellPrice = DBL_MAX;    // Use maximum double value as initial low for sells
   double lastBuyLotSize = 0.0;  // Lot size of the most recent buy trade
   double lastSellLotSize = 0.0; // Lot size of the most recent sell trade
   datetime lastBuyTime = 0;     // Timestamp of the most recent buy trade
   datetime lastSellTime = 0;    // Timestamp of the most recent sell trade

   int totalPositionsOnAccount = (int)PositionsTotal(); // Total positions on the account
   int eaPositionsCount = 0;                          // Counter for positions matching EA's symbol and magic

   // --- Loop through all open positions on the account ---
   for(int i = totalPositionsOnAccount - 1; i >= 0; i--) // Loop backwards is safer when closing
     {
      ulong ticket = PositionGetTicket(i); // Get ticket of the position at index i
      if(PositionSelectByTicket(ticket))   // Select the position to access its properties
        {
         // --- Filter positions by Symbol and Magic Number ---
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            eaPositionsCount++; // Increment count for this EA's positions

            // --- Get position details ---
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP); // Include swap
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentLot = PositionGetDouble(POSITION_VOLUME);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

            // --- Aggregate data based on position type ---
            if(type == POSITION_TYPE_BUY)
              {
               buyPositionsCount++;
               totalBuyProfit += profit;
               totalBuyLots += currentLot;
               if(openPrice > highestBuyPrice) highestBuyPrice = openPrice; // Update highest buy price
               // Track the most recent buy trade's lot size
               if(openTime > lastBuyTime) { lastBuyTime = openTime; lastBuyLotSize = currentLot; }
              }
            else if(type == POSITION_TYPE_SELL)
              {
               sellPositionsCount++;
               totalSellProfit += profit;
               totalSellLots += currentLot;
               if(openPrice < lowestSellPrice) lowestSellPrice = openPrice; // Update lowest sell price
               // Track the most recent sell trade's lot size
               if(openTime > lastSellTime) { lastSellTime = openTime; lastSellLotSize = currentLot; }
              }
           } // End if match symbol & magic
        } // End if PositionSelectByTicket
      else
        {
         // Handle error if position couldn't be selected (rare)
         Print("Error selecting position by ticket ", ticket, " in AnalyzeOpenPositions. Error code: ", GetLastError());
        }
     } // End for loop

   // --- Calculate next lot sizes based on Martingale setting ---
   if(UseMartingale)
     {
      // If buys exist, next buy lot is multiplier * last buy lot, otherwise it's the initial lot
      nextBuyLot = NormalizeLotWithCap(buyPositionsCount > 0 ? lastBuyLotSize * MartingaleMultiplier : InitialLotSize);
      // If sells exist, next sell lot is multiplier * last sell lot, otherwise it's the initial lot
      nextSellLot = NormalizeLotWithCap(sellPositionsCount > 0 ? lastSellLotSize * MartingaleMultiplier : InitialLotSize);
     }
   else // Fixed Lot
     {
      nextBuyLot = NormalizeLotWithCap(InitialLotSize);
      nextSellLot = NormalizeLotWithCap(InitialLotSize);
     }

   // --- Reset grid price trackers if no positions of that type exist ---
   if(buyPositionsCount == 0) lastBuyGridPrice = 0.0;
   if(sellPositionsCount == 0) lastSellGridPrice = 0.0;
   // Reset lowest sell price if no sells (to avoid using DBL_MAX incorrectly later)
   if(sellPositionsCount == 0) lowestSellPrice = 0.0;


   // --- Return the count of positions managed by this EA ---
   return eaPositionsCount;
}

//+------------------------------------------------------------------+
//| Check and Close Baskets (Profit Target or Max DD)                |
//+------------------------------------------------------------------+
void CheckCloseBaskets()
{
   bool closedDueToDD = false;

   // --- 1. Check Max Basket Drawdown FIRST ---
   if(CloseBasketOnMaxDD && MaxBasketDrawdownUSD > 0)
     {
      // Check Buys for Max Drawdown
      if(buyPositionsCount > 0 && totalBuyProfit < -MaxBasketDrawdownUSD)
        {
         Print("Max Basket Drawdown HIT for BUYS! Profit: ", DoubleToString(totalBuyProfit, 2), ", Threshold: -", DoubleToString(MaxBasketDrawdownUSD, 2), ". Closing Buy Basket.");
         CloseAllBuys(); // Close the losing buy basket
         closedDueToDD = true; // Flag that we closed due to DD
         // Handle pausing if enabled
         if(PauseAfterLoss)
           {
            isPaused = true;
            pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
            Print("EA paused for ", PauseDurationMinutes, " minutes due to Buy Basket Max DD hit.");
           }
        }
      // Check Sells for Max Drawdown (only if buys weren't closed this tick)
      if(!closedDueToDD && sellPositionsCount > 0 && totalSellProfit < -MaxBasketDrawdownUSD)
        {
         Print("Max Basket Drawdown HIT for SELLS! Profit: ", DoubleToString(totalSellProfit, 2), ", Threshold: -", DoubleToString(MaxBasketDrawdownUSD, 2), ". Closing Sell Basket.");
         CloseAllSells(); // Close the losing sell basket
         closedDueToDD = true; // Flag that we closed due to DD
         // Handle pausing if enabled
         if(PauseAfterLoss)
           {
            isPaused = true;
            pauseEndTime = TimeCurrent() + PauseDurationMinutes * 60;
            Print("EA paused for ", PauseDurationMinutes, " minutes due to Sell Basket Max DD hit.");
           }
        }

      // If we closed a basket due to Drawdown, exit this function for this tick
      // This prevents potentially closing the *other* basket for profit immediately after
      if(closedDueToDD)
         return;
     } // End Max DD Check

   // --- 2. Check Basket Profit Target ---
   double targetBuyProfit = BasketProfitTarget_USD;
   double targetSellProfit = BasketProfitTarget_USD;

   // --- Calculate Dynamic TP if enabled ---
   if(BasketTPPerLot > 0 && totalBuyLots > 0) // Per Lot takes precedence for Buys
     {
      targetBuyProfit = MathMax(BasketProfitTarget_USD, totalBuyLots * BasketTPPerLot);
     }
   // Add ATR logic here if needed for Buys as an 'else if'

   if(BasketTPPerLot > 0 && totalSellLots > 0) // Per Lot takes precedence for Sells
     {
      targetSellProfit = MathMax(BasketProfitTarget_USD, totalSellLots * BasketTPPerLot);
     }
    // Add ATR logic here if needed for Sells as an 'else if'


   // --- Check and Close Buys on Profit Target ---
   if(buyPositionsCount > 0 && totalBuyProfit >= targetBuyProfit)
     {
      Print("Closing Buy Basket on Profit. Profit: ", DoubleToString(totalBuyProfit, 2), " >= Target: ", DoubleToString(targetBuyProfit, 2));
      CloseAllBuys();
      // Don't exit early here, allow checking sells too in the same tick if needed
     }

   // --- Check and Close Sells on Profit Target ---
   if(sellPositionsCount > 0 && totalSellProfit >= targetSellProfit)
     {
      Print("Closing Sell Basket on Profit. Profit: ", DoubleToString(totalSellProfit, 2), " >= Target: ", DoubleToString(targetSellProfit, 2));
      CloseAllSells();
     }
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                |
//+------------------------------------------------------------------+
bool OpenBuyPosition(double lotSize)
{
   // Normalize lot size, applying step, min/max, and user cap
   double useLot = NormalizeLotWithCap(lotSize);
   if(useLot <= 0) // Ensure lot is valid after normalization
     {
      Print("Invalid lot size calculated for Buy: ", lotSize, " -> ", useLot);
      return false;
     }

   // Reset grid price tracker only if this is the *first* buy in a potential sequence
   if(buyPositionsCount == 0)
     {
      lastBuyGridPrice = 0.0; // Reset when opening the first buy
     }

   // Prepare the trade request
   MqlTradeRequest request = {}; // Initialize structure to zeros
   MqlTradeResult result = {};   // Initialize structure to zeros

   request.action = TRADE_ACTION_DEAL;                     // Immediate execution
   request.symbol = _Symbol;                               // Symbol from the chart
   request.volume = useLot;                                // Normalized lot size
   request.type = ORDER_TYPE_BUY;                          // Buy order type
   request.price = symbolInfo.Ask();                       // Current Ask price for Buy
   request.deviation = Slippage;                           // Allowed slippage in points
   request.magic = MagicNumber;                            // EA's magic number
   request.comment = EaComment;                            // Order comment
   request.type_filling = ORDER_FILLING_FOK;             // Filling policy from CTrade object (usually FOK or IOC)
   request.type_time = ORDER_TIME_GTC;                     // Good 'Til Canceled (standard for market orders)
   // --- SL / TP Parameters ---
   // request.sl = price - StopLossPoints * _Point; // Example if SL was used
   // request.tp = price + TakeProfitPoints * _Point; // Example if TP was used

   // Send the order
   if(!OrderSend(request, result))
     {
      Print("Error Opening Buy (OrderSend failed): ", GetLastError(), ", Result Retcode: ", result.retcode, ", Price: ", request.price, ", Lots: ", useLot);
      // Additional error details might be in result.comment
      return false;
     }

   // Check execution result code (though OrderSend returning true usually means success for market orders)
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) // Check for success codes
     {
      Print("Buy Order Sent Successfully: ", useLot, " lots at ", SymbolInfoDouble(_Symbol, SYMBOL_ASK), ", Ticket: ", result.order); // Use current Ask for confirmation print
      // Optional: Small delay after opening a trade if broker needs it, but generally avoid for scalping
      // Sleep(100);
      return true;
     }
   else
     {
      Print("Error Opening Buy (Unexpected Result Retcode): ", result.retcode, ", Comment: ", result.comment);
      return false;
     }
}

//+------------------------------------------------------------------+
//| Open Sell Position                                               |
//+------------------------------------------------------------------+
bool OpenSellPosition(double lotSize)
{
   // Normalize lot size, applying step, min/max, and user cap
   double useLot = NormalizeLotWithCap(lotSize);
   if(useLot <= 0) // Ensure lot is valid after normalization
     {
      Print("Invalid lot size calculated for Sell: ", lotSize, " -> ", useLot);
      return false;
     }

   // Reset grid price tracker only if this is the *first* sell in a potential sequence
   if(sellPositionsCount == 0)
     {
      lastSellGridPrice = 0.0; // Reset when opening the first sell
     }

   // Prepare the trade request
   MqlTradeRequest request = {}; // Initialize structure to zeros
   MqlTradeResult result = {};   // Initialize structure to zeros

   request.action = TRADE_ACTION_DEAL;                     // Immediate execution
   request.symbol = _Symbol;                               // Symbol from the chart
   request.volume = useLot;                                // Normalized lot size
   request.type = ORDER_TYPE_SELL;                         // Sell order type
   request.price = symbolInfo.Bid();                       // Current Bid price for Sell
   request.deviation = Slippage;                           // Allowed slippage in points
   request.magic = MagicNumber;                            // EA's magic number
   request.comment = EaComment;                            // Order comment
   request.type_filling = ORDER_FILLING_FOK;              // Filling policy from CTrade object
   request.type_time = ORDER_TIME_GTC;                     // Good 'Til Canceled
   // --- SL / TP Parameters ---
   // request.sl = price + StopLossPoints * _Point; // Example if SL was used
   // request.tp = price - TakeProfitPoints * _Point; // Example if TP was used

   // Send the order
   if(!OrderSend(request, result))
     {
      Print("Error Opening Sell (OrderSend failed): ", GetLastError(), ", Result Retcode: ", result.retcode, ", Price: ", request.price, ", Lots: ", useLot);
      return false;
     }

   // Check execution result code
   if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
     {
      Print("Sell Order Sent Successfully: ", useLot, " lots at ", SymbolInfoDouble(_Symbol, SYMBOL_BID), ", Ticket: ", result.order); // Use current Bid for confirmation print
      // Optional: Small delay
      // Sleep(100);
      return true;
     }
   else
     {
      Print("Error Opening Sell (Unexpected Result Retcode): ", result.retcode, ", Comment: ", result.comment);
      return false;
     }
}

//+------------------------------------------------------------------+
//| Close All Buy Positions for this EA instance                     |
//+------------------------------------------------------------------+
void CloseAllBuys()
{
   int total = (int)PositionsTotal();
   bool closed_any = false;
   int attempts = 0;
   int max_attempts = 5; // Limit retry attempts to prevent infinite loops

   Print("Attempting to close all BUY positions...");
   // Loop until no more relevant buy positions are found or max attempts reached
   while(attempts < max_attempts)
     {
      bool found_buy_to_close = false;
      total = (int)PositionsTotal(); // Re-check total as positions get closed

      // Loop backwards through open positions
      for(int i = total - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            // Filter for the correct symbol, magic number, and position type
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
              {
               found_buy_to_close = true; // Found one to close
               if(!trade.PositionClose(ticket, Slippage))
                 {
                  Print("Error closing BUY ticket ", ticket, ": ", GetLastError(), ", RetCode: ", trade.ResultRetcode(), ". Attempt ", attempts + 1);
                  // Optional: Add a small delay before retrying if error persists
                  // Sleep(200);
                 }
               else
                 {
                  Print("Closed BUY ticket ", ticket);
                  closed_any = true;
                  // Short pause after successful close might help terminal update state
                  Sleep(50);
                 }
               // Since we closed one, break the inner loop and re-scan from the end
               // This handles the collection changing size more reliably
               break;
              } // End if matches criteria
           } // End if PositionSelect
        } // End for loop

      // If we looped through all positions and didn't find a buy to close, we're done
      if(!found_buy_to_close)
        {
         break; // Exit the while loop
        }

      attempts++;
      if(attempts >= max_attempts)
        {
         Print("Warning: Reached max attempts trying to close all BUY positions.");
        }
      Sleep(100); // Small delay before next attempt cycle
     } // End while loop

   // Reset grid price tracker only if positions were actually closed
   if(closed_any)
     {
      lastBuyGridPrice = 0.0; // Reset grid price after closing basket
      Print("Finished closing BUY positions.");
      // Small delay might be needed for terminal to update fully after mass close
      Sleep(250);
     }
   else
     {
      Print("No open BUY positions found to close.");
     }
}

//+------------------------------------------------------------------+
//| Close All Sell Positions for this EA instance                    |
//+------------------------------------------------------------------+
void CloseAllSells()
{
   int total = (int)PositionsTotal();
   bool closed_any = false;
   int attempts = 0;
   int max_attempts = 5;

   Print("Attempting to close all SELL positions...");
   while(attempts < max_attempts)
     {
      bool found_sell_to_close = false;
      total = (int)PositionsTotal(); // Re-check total

      for(int i = total - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
           {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
               (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               found_sell_to_close = true;
               if(!trade.PositionClose(ticket, Slippage))
                 {
                  Print("Error closing SELL ticket ", ticket, ": ", GetLastError(), ", RetCode: ", trade.ResultRetcode(), ". Attempt ", attempts + 1);
                  // Sleep(200);
                 }
               else
                 {
                  Print("Closed SELL ticket ", ticket);
                  closed_any = true;
                  Sleep(50);
                 }
               break; // Re-scan after closing
              }
           }
        }

      if(!found_sell_to_close)
        {
         break; // Exit while loop
        }

      attempts++;
      if(attempts >= max_attempts)
        {
         Print("Warning: Reached max attempts trying to close all SELL positions.");
        }
       Sleep(100); // Small delay before next attempt cycle
     } // End while

   if(closed_any)
     {
      lastSellGridPrice = 0.0; // Reset grid price after closing basket
      Print("Finished closing SELL positions.");
      Sleep(250); // Allow terminal to update
     }
   else
     {
      Print("No open SELL positions found to close.");
     }
}


//+------------------------------------------------------------------+
//| Normalize Lot Size according to symbol rules & User Max Cap      |
//+------------------------------------------------------------------+
double NormalizeLotWithCap(double lot)
{
   // Get symbol specific lot rules
   double min_lot = symbolInfo.LotsMin();
   double max_lot_symbol = symbolInfo.LotsMax(); // Max allowed by symbol/broker rules
   double lot_step = symbolInfo.LotsStep();

   // Determine the effective maximum lot size, considering user input
   double effective_max_lot = max_lot_symbol;
   // If user defined a MaxAllowedLotSize AND it's smaller than the broker's max (or broker has no max defined)
   if(MaxAllowedLotSize > 0) // Check if user cap is enabled
     {
      // If broker has a max_lot defined, take the smaller of user's cap and broker's max
      if(max_lot_symbol > 0)
         effective_max_lot = MathMin(max_lot_symbol, MaxAllowedLotSize);
      else // Broker doesn't define a max, just use user's cap
         effective_max_lot = MaxAllowedLotSize;
     }

   // 1. Ensure minimum lot size
   if(lot < min_lot)
      lot = min_lot;

   // 2. Adjust to lot step (use MathRound for potentially better rounding)
   if(lot_step > 0) // Avoid division by zero if step is not defined
     {
      lot = MathRound(lot / lot_step) * lot_step;
     }

   // 3. Ensure within effective maximum lot limits (only if max is defined > 0)
   if(effective_max_lot > 0 && lot > effective_max_lot)
     {
      lot = effective_max_lot;
      // Print("Lot size capped at MaxAllowedLotSize: ", effective_max_lot); // Optional debug
     }

   // 4. Final check against min_lot after rounding/capping
   if(lot < min_lot)
      lot = min_lot;

   // Return normalized lot, typically to 2 decimal places for standard lots
   return NormalizeDouble(lot, 2);
}

