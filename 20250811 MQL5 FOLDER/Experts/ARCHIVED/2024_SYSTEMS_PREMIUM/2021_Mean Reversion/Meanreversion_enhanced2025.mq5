//+------------------------------------------------------------------+
//|                                      Mean Reversion Enhanced.mq5 |
//|                        Copyright 2023, Your Name/Company         |
//|                                     Original by MetaQuotes 2019  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
//#include <Indicators\Indicator.h> // Base class for indicator wrappers if needed

#define NO_VALUE      INT_MAX                      // invalid value of Signal/Trend
#define MIN_ATR_FOR_LOT 0.00001 // Minimum ATR value to prevent division by zero in lot calc

//--- Indicator Parameters
input group           "Indicators"
input int             InpBBPeriod         = 20;           // BBands period
input double          InpBBDeviation      = 2.0;          // BBands deviation
input int             InpFastEMAPeriod    = 12;           // Fast EMA period
input int             InpSlowEMAPeriod    = 26;           // Slow EMA period
input int             InpATRPeriod        = 14;           // ATR period (used for range, SL/TP, Trail)
input int             InpADXPeriod        = 14;           // ADX Period
input double          InpADXThreshold     = 20.0;         // ADX level to confirm trend

//--- Entry & Filter Parameters
input group           "Entry & Filters"
input double          InpATRCoeffRange    = 1.0;          // ATR coefficient to detect flat range
input bool            InpWaitForReversal  = true;         // Wait for close back inside BBands
input int             InpMaxSpreadPoints  = 20;           // Max allowed spread in points (0=disabled)
input uint            InpAllowedSlippage  = 3;            // Allowed slippage in points

//--- Money Management
input group           "Money Management"
input double          InpRiskPercent      = 1.0;          // Risk per trade in % of Equity
input double          InpFixedLot         = 0.0;          // Fixed lot size (if > 0, overrides InpRiskPercent)
input double          InpSL_ATR_Multiplier= 1.5;          // Stop Loss ATR Multiplier
input double          InpTP_ATR_Multiplier= 2.0;          // Take Profit ATR Multiplier

//--- Trailing Stop Parameters
input group           "Trailing Stop"
input bool            InpUseTrailingStop  = true;         // Enable ATR Trailing Stop
input double          InpTrailATRMultiplier= 1.5;         // Trailing Stop ATR Multiplier
input double          InpTrailActivationATR = 1.0;        // ATRs in profit before trailing starts (0 = immediate)
input uint            InpTrailStepPoints  = 1;            // Minimum step in points for trailing (1 = trail every point)

//--- Timeframe Parameters
input group           "Timeframes"
input ENUM_TIMEFRAMES InpBBTF             = PERIOD_M15;   // BBands & Entry Signal Timeframe
input ENUM_TIMEFRAMES InpTrendTF          = PERIOD_M15;   // Trend Detection (MA, ATR, ADX) Timeframe

//--- EA Identification
input group           "EA Settings"
input long            InpMagicNumber      = 245601;       // Magic Number

//--- Indicator Handles
int    ExtBBHandle     = INVALID_HANDLE;
int    ExtFastMAHandle = INVALID_HANDLE;
int    ExtSlowMAHandle = INVALID_HANDLE;
int    ExtATRHandle    = INVALID_HANDLE;
int    ExtADXHandle    = INVALID_HANDLE;

//--- Indicator Buffers & Values (updated each bar)
double ExtUpChannel[];      // Index 0 = current bar (if available), 1 = previous, etc.
double ExtMidChannel[];
double ExtLowChannel[];
double ExtFastMA[];
double ExtSlowMA[];
double ExtATR[];
double ExtADXMain[];
double ExtADXPlusDI[];
double ExtADXMinusDI[];

double ExtBBWidth       = 0; // Width on the previous closed bar
double ExtATRValue      = 0; // ATR on the previous closed bar

int    ExtTrend         = 0; // Current trend (1=Up, -1=Down, 0=None/Flat)
datetime ExtLastTrendTime = 0; // Time of the last bar processed on InpTrendTF

//--- Service objects
CTrade        ExtTrade;
CPositionInfo ExtPositionInfo;
CSymbolInfo   ExtSymbolInfo;

//--- Symbol Properties
double ExtPoint;
double ExtTickValue;
double ExtTickSize;
double ExtContractSize;
double ExtMinLot;
double ExtMaxLot;
double ExtLotStep;
int    ExtDigits;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Get Symbol Properties
    if(!ExtSymbolInfo.Name(Symbol())) return(INIT_FAILED);
    ExtSymbolInfo.Refresh();
    ExtPoint = ExtSymbolInfo.Point();
    ExtTickValue = ExtSymbolInfo.TickValue();
    ExtTickSize = ExtSymbolInfo.TickSize();
    ExtContractSize = ExtSymbolInfo.ContractSize();
    //ExtMinLot = ExtSymbolInfo.VolumeMin();
    //ExtMaxLot = ExtSymbolInfo.VolumeMax();
    //ExtLotStep = ExtSymbolInfo.VolumeStep();
    
    ExtMinLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    ExtMaxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    ExtLotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    
    ExtDigits = (int)ExtSymbolInfo.Digits();

    //--- Create Bollinger Bands indicator handle on BB Timeframe
    ExtBBHandle = iBands(Symbol(), InpBBTF, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    if(ExtBBHandle == INVALID_HANDLE)
    {
        Print("Failed to create indicator iBands on ", EnumToString(InpBBTF));
        return(INIT_FAILED);
    }

    //--- Create Fast EMA indicator handle on Trend Timeframe
    ExtFastMAHandle = iMA(Symbol(), InpTrendTF, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(ExtFastMAHandle == INVALID_HANDLE)
    {
        Print("Failed to create Fast MA indicator on ", EnumToString(InpTrendTF));
        return(INIT_FAILED);
    }

    //--- Create Slow EMA indicator handle on Trend Timeframe
    ExtSlowMAHandle = iMA(Symbol(), InpTrendTF, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(ExtSlowMAHandle == INVALID_HANDLE)
    {
        Print("Failed to create Slow MA indicator on ", EnumToString(InpTrendTF));
        return(INIT_FAILED);
    }

    //--- Create ATR indicator handle on Trend Timeframe
    ExtATRHandle = iATR(Symbol(), InpTrendTF, InpATRPeriod);
    if(ExtATRHandle == INVALID_HANDLE)
    {
        Print("Failed to create ATR indicator on ", EnumToString(InpTrendTF));
        return(INIT_FAILED);
    }

    //--- Create ADX indicator handle on Trend Timeframe
    ExtADXHandle = iADX(Symbol(), InpTrendTF, InpADXPeriod);
    if(ExtADXHandle == INVALID_HANDLE)
    {
        Print("Failed to create ADX indicator on ", EnumToString(InpTrendTF));
        return(INIT_FAILED);
    }

    //--- Check timeframes (Trend TF should ideally be >= BB TF for this logic)
    if(PeriodSeconds(InpBBTF) > PeriodSeconds(InpTrendTF))
    {
        Print("Warning! BB Timeframe (", EnumToString(InpBBTF), ") is higher than Trend Timeframe (", EnumToString(InpTrendTF), "). Logic might be suboptimal.");
        // Allow continuation but warn user.
    }

    //--- Setup Trade object
    ExtTrade.SetExpertMagicNumber(InpMagicNumber);
    ExtTrade.SetDeviationInPoints(InpAllowedSlippage);
    ExtTrade.SetTypeFillingBySymbol(Symbol()); // Important for execution

    //--- Set buffer sizes (more than needed, just in case)
    ArraySetAsSeries(ExtUpChannel, true);
    ArraySetAsSeries(ExtMidChannel, true);
    ArraySetAsSeries(ExtLowChannel, true);
    ArraySetAsSeries(ExtFastMA, true);
    ArraySetAsSeries(ExtSlowMA, true);
    ArraySetAsSeries(ExtATR, true);
    ArraySetAsSeries(ExtADXMain, true);
    ArraySetAsSeries(ExtADXPlusDI, true);
    ArraySetAsSeries(ExtADXMinusDI, true);

    //--- Success
    Print("Mean Reversion Enhanced EA Initialized Successfully.");
    Print("Symbol: ", Symbol());
    Print("Trend TF: ", EnumToString(InpTrendTF), ", BB TF: ", EnumToString(InpBBTF));
    Print("Risk Management: ", InpFixedLot > 0 ? "Fixed Lot "+DoubleToString(InpFixedLot,2) : "Risk "+DoubleToString(InpRiskPercent,2)+"%");

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    IndicatorRelease(ExtBBHandle);
    IndicatorRelease(ExtFastMAHandle);
    IndicatorRelease(ExtSlowMAHandle);
    IndicatorRelease(ExtATRHandle);
    IndicatorRelease(ExtADXHandle);
    Print("Mean Reversion Enhanced EA Deinitialized. Reason: ", reason);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Update symbol info (rates)
    ExtSymbolInfo.RefreshRates();

    //--- Check if a new bar has started on the Trend Timeframe
    if(IsNewTrendBar()) // This function also updates Trend and Indicators
    {
        //--- Check for trading signal only if no position is open
        if(!PositionExist())
        {
           CheckTradingSignal();
        }
    }

    //--- Manage open positions (Trailing Stop)
    if(InpUseTrailingStop && PositionExist())
    {
        ManageTrailingStop();
    }
}

//+------------------------------------------------------------------+
//| Check for new bar on Trend TF and update indicators/trend        |
//+------------------------------------------------------------------+
bool IsNewTrendBar()
{
    //--- Get the opening time of the last bar on the Trend Timeframe
    datetime currentTrendTime = (datetime)SeriesInfoInteger(Symbol(), InpTrendTF, SERIES_LASTBAR_DATE);

    //--- If time hasn't changed, it's not a new bar
    if(currentTrendTime == ExtLastTrendTime)
        return(false);

    //--- New bar detected, update last time
    ExtLastTrendTime = currentTrendTime;

    //--- Update all indicator data for the PREVIOUS completed bar (index 1)
    if(!UpdateIndicatorData())
    {
        Print("Failed to update indicator data on new bar.");
        return(false); // Don't proceed if data is stale
    }

    //--- Calculate the current trend based on updated data
    ExtTrend = TrendCalculate();

    return(true);
}
//+------------------------------------------------------------------+
//| Update indicator buffers                                         |
//+------------------------------------------------------------------+
bool UpdateIndicatorData()
{
   //--- Need at least 3 bars of data for reversal checks
   int bars_needed = 3;
   int trend_bars_copied = 0;
   int bb_bars_copied = 0;

   //--- Copy data from Trend TF indicators (EMA, ATR, ADX)
   trend_bars_copied = CopyBuffer(ExtFastMAHandle, 0, 0, bars_needed, ExtFastMA);
   if(trend_bars_copied < bars_needed) return(false);
   trend_bars_copied = CopyBuffer(ExtSlowMAHandle, 0, 0, bars_needed, ExtSlowMA);
   if(trend_bars_copied < bars_needed) return(false);
   trend_bars_copied = CopyBuffer(ExtATRHandle, 0, 0, bars_needed, ExtATR);
   if(trend_bars_copied < bars_needed) return(false);
   trend_bars_copied = CopyBuffer(ExtADXHandle, 0, 0, bars_needed, ExtADXMain); // Main ADX line
   if(trend_bars_copied < bars_needed) return(false);
   trend_bars_copied = CopyBuffer(ExtADXHandle, 1, 0, bars_needed, ExtADXPlusDI); // +DI
   if(trend_bars_copied < bars_needed) return(false);
   trend_bars_copied = CopyBuffer(ExtADXHandle, 2, 0, bars_needed, ExtADXMinusDI); // -DI
   if(trend_bars_copied < bars_needed) return(false);

   //--- Store ATR value from the last closed bar
   ExtATRValue = ExtATR[1];
   if(ExtATRValue <= 0) // Basic check for valid ATR
   {
        Print("Invalid ATR value: ", ExtATRValue);
        return false;
   }


   //--- Copy data from BB TF indicator
   bb_bars_copied = CopyBuffer(ExtBBHandle, 0, 0, bars_needed, ExtMidChannel); // Middle Band
   if(bb_bars_copied < bars_needed) return(false);
   bb_bars_copied = CopyBuffer(ExtBBHandle, 1, 0, bars_needed, ExtUpChannel); // Upper Band
   if(bb_bars_copied < bars_needed) return(false);
   bb_bars_copied = CopyBuffer(ExtBBHandle, 2, 0, bars_needed, ExtLowChannel); // Lower Band
   if(bb_bars_copied < bars_needed) return(false);

   //--- Calculate BB Width from the last closed bar
   ExtBBWidth = ExtUpChannel[1] - ExtLowChannel[1];
    if(ExtBBWidth <= 0) // Basic check for valid width
   {
        Print("Invalid BB Width value: ", ExtBBWidth);
        return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Trend based on MA crossover and ADX filter             |
//| Returns 1 for UpTrend, -1 for DownTrend, 0 for None/Flat      |
//+------------------------------------------------------------------+
int TrendCalculate()
{
    //--- Check for flat market based on BB width vs ATR
    if(ExtBBWidth < InpATRCoeffRange * ExtATRValue)
    {
       // Print("Range detected: BB Width ", DoubleToString(ExtBBWidth, ExtDigits), " < ", InpATRCoeffRange, " * ATR ", DoubleToString(ExtATRValue, ExtDigits));
       return(0); // Flat market
    }


    //--- Check ADX strength on the last closed bar (index 1)
    bool adx_strong = ExtADXMain[1] > InpADXThreshold;

    //--- Check MA crossover on the last closed bar (index 1)
    bool fast_above_slow = ExtFastMA[1] > ExtSlowMA[1];
    bool fast_below_slow = ExtFastMA[1] < ExtSlowMA[1];

    //--- Check DI lines direction on the last closed bar (index 1)
    bool di_positive = ExtADXPlusDI[1] > ExtADXMinusDI[1];
    bool di_negative = ExtADXMinusDI[1] > ExtADXPlusDI[1];

    //--- Determine Trend
    int trend = 0;
    if(adx_strong && fast_above_slow && di_positive)
        trend = 1; // Confirmed Uptrend
    else if(adx_strong && fast_below_slow && di_negative)
        trend = -1; // Confirmed Downtrend

    // PrintFormat("Trend Calc: ADX=%.2f (Str=%s), FastMA=%.5f, SlowMA=%.5f, +DI=%.2f, -DI=%.2f -> Trend=%d",
    //             ExtADXMain[1], BoolToString(adx_strong), ExtFastMA[1], ExtSlowMA[1], ExtADXPlusDI[1], ExtADXMinusDI[1], trend);

    return(trend);
}

//+------------------------------------------------------------------+
//| Check for entry signal based on trend and BB reversal            |
//+------------------------------------------------------------------+
void CheckTradingSignal()
{
    //--- No trend, no signal
    if(ExtTrend == 0)
        return;

    //--- Check Spread Limit
    if(InpMaxSpreadPoints > 0)
    {
        double current_spread = ExtSymbolInfo.Spread() * ExtPoint; // Spread in quote currency units
        // Direct point comparison is simpler:
        int current_spread_points = ExtSymbolInfo.Spread();
        if(current_spread_points > InpMaxSpreadPoints)
        {
           // PrintFormat("Spread too high: %d points (Max: %d)", current_spread_points, InpMaxSpreadPoints);
           return;
        }
    }

    //--- Get required price data from BB Timeframe
    MqlRates ratesBBTF[];
    int rates_copied = CopyRates(Symbol(), InpBBTF, 0, 3, ratesBBTF); // Need 3 bars for lookback
    if(rates_copied < 3)
    {
        Print("Could not copy rates for BB TF: ", EnumToString(InpBBTF));
        return;
    }
    // ratesBBTF[0] = current incomplete bar, [1] = first closed, [2] = second closed

    //--- Check for Buy Signal (Uptrend)
    if(ExtTrend == 1)
    {
        bool touched_lower_prev = ratesBBTF[2].low <= ExtLowChannel[2] || ratesBBTF[2].close <= ExtLowChannel[2];
        bool closed_inside_last = ratesBBTF[1].close > ExtLowChannel[1];

        if( (InpWaitForReversal && touched_lower_prev && closed_inside_last) ||
            (!InpWaitForReversal && ratesBBTF[1].low <= ExtLowChannel[1]) ) // Original logic: touched on last closed bar
        {
             PrintFormat("BUY Signal: Trend=%d. Reversal Criteria Met.", ExtTrend);
             OpenTrade(ORDER_TYPE_BUY);
        }
    }
    //--- Check for Sell Signal (Downtrend)
    else if(ExtTrend == -1)
    {
        bool touched_upper_prev = ratesBBTF[2].high >= ExtUpChannel[2] || ratesBBTF[2].close >= ExtUpChannel[2];
        bool closed_inside_last = ratesBBTF[1].close < ExtUpChannel[1];

        if( (InpWaitForReversal && touched_upper_prev && closed_inside_last) ||
            (!InpWaitForReversal && ratesBBTF[1].high >= ExtUpChannel[1]) ) // Original logic: touched on last closed bar
        {
             PrintFormat("SELL Signal: Trend=%d. Reversal Criteria Met.", ExtTrend);
             OpenTrade(ORDER_TYPE_SELL);
        }
    }
}

//+------------------------------------------------------------------+
//| Opens a market order                                             |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE order_type)
{
    //--- Calculate Stop Loss distance based on ATR
    double sl_distance = InpSL_ATR_Multiplier * ExtATRValue;
    if(sl_distance <= 0)
    {
       Print("Invalid SL distance calculated: ", sl_distance);
       return false;
    }

    //--- Calculate Take Profit distance based on ATR
    double tp_distance = InpTP_ATR_Multiplier * ExtATRValue;
    if(tp_distance <= 0)
    {
       Print("Invalid TP distance calculated: ", tp_distance);
       return false; // TP must be positive
    }


    //--- Calculate Lot Size
    double lots = CalculateLotSize(sl_distance);
    if(lots <= 0)
    {
        Print("Invalid Lot Size calculated: ", lots);
        return false; // Calculation failed or result is zero/negative
    }

    //--- Calculate SL and TP prices
    double price = (order_type == ORDER_TYPE_BUY) ? ExtSymbolInfo.Ask() : ExtSymbolInfo.Bid();
    double stoploss = 0;
    double takeprofit = 0;

    if(order_type == ORDER_TYPE_BUY)
    {
        stoploss = price - sl_distance;
        takeprofit = price + tp_distance;
    }
    else // ORDER_TYPE_SELL
    {
        stoploss = price + sl_distance;
        takeprofit = price - tp_distance;
    }

    //--- Normalize SL/TP prices
    stoploss = NormalizeDouble(stoploss, ExtDigits);
    takeprofit = NormalizeDouble(takeprofit, ExtDigits);

    //--- Ensure SL/TP are valid distances from market
    double min_stop_level = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL) * ExtPoint;  
    
    if(order_type == ORDER_TYPE_BUY)
    {
        if(stoploss >= price - min_stop_level) // SL too close
        {
            Print("Calculated SL ", DoubleToString(stoploss, ExtDigits)," too close for BUY. Adjusting. MinStop: ", min_stop_level);
            stoploss = NormalizeDouble(price - min_stop_level - ExtPoint, ExtDigits); // Adjust slightly further
             if(stoploss <= 0) { Print("Cannot set valid SL for BUY."); return false;}
        }
         if(takeprofit <= price + min_stop_level) // TP too close
        {
            Print("Calculated TP ", DoubleToString(takeprofit, ExtDigits)," too close for BUY. Disabling TP.");
            takeprofit = 0; // Disable TP if too close
        }
    }
    else // SELL
    {
         if(stoploss <= price + min_stop_level) // SL too close
        {
            Print("Calculated SL ", DoubleToString(stoploss, ExtDigits)," too close for SELL. Adjusting. MinStop: ", min_stop_level);
            stoploss = NormalizeDouble(price + min_stop_level + ExtPoint, ExtDigits); // Adjust slightly further
        }
         if(takeprofit >= price - min_stop_level || takeprofit <=0) // TP too close or zero/negative
        {
            Print("Calculated TP ", DoubleToString(takeprofit, ExtDigits)," too close or invalid for SELL. Disabling TP.");
            takeprofit = 0; // Disable TP if too close or invalid
        }
    }


    //--- Send the order
    bool result = false;
    string type_str = (order_type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
    PrintFormat("Attempting %s: Lot=%.2f, Price=%.*f, SL=%.*f, TP=%.*f",
                 type_str, lots, ExtDigits, price, ExtDigits, stoploss, ExtDigits, takeprofit);

    if(order_type == ORDER_TYPE_BUY)
        result = ExtTrade.Buy(lots, Symbol(), price, stoploss, takeprofit, "Mean Reversion Enhanced Buy");
    else
        result = ExtTrade.Sell(lots, Symbol(), price, stoploss, takeprofit, "Mean Reversion Enhanced Sell");

    //--- Check result
    if(result)
    {
        PrintFormat("%s order placed successfully. Ticket: %d. Result code: %d (%s)",
                    type_str, ExtTrade.ResultOrder(), ExtTrade.ResultRetcode(), ExtTrade.ResultRetcodeDescription());
    }
    else
    {
        PrintFormat("Failed to place %s order. Error code: %d (%s)",
                    type_str, ExtTrade.ResultRetcode(), ExtTrade.ResultRetcodeDescription());
    }

    return result;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk % and SL Distance               |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
    //--- Use fixed lot if specified
    if(InpFixedLot > 0)
    {
        if(InpFixedLot >= ExtMinLot && InpFixedLot <= ExtMaxLot)
           return(NormalizeLot(InpFixedLot));
        else
           {
             Print("Fixed lot ", InpFixedLot, " is outside valid range [", ExtMinLot, "-", ExtMaxLot, "]. Using Min Lot.");
             return ExtMinLot;
           }
    }

    //--- Use Risk %
    if(InpRiskPercent <= 0)
    {
        Print("Risk Percent is zero or negative. Using Min Lot.");
        return ExtMinLot;
    }

    //--- Validate SL distance
    if(stopLossDistance <= 0)
    {
        Print("Cannot calculate lot size: Stop Loss distance is zero or negative (", stopLossDistance, ")");
        return 0.0;
    }

    //--- Get Account Equity
    double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(accountEquity <= 0)
    {
        Print("Cannot calculate lot size: Invalid Account Equity (", accountEquity, ")");
        return 0.0;
    }

    //--- Calculate Risk Amount
    double riskAmount = accountEquity * (InpRiskPercent / 100.0);

    //--- Calculate Value of 1 Lot Loss for the given SL distance
    // Formula: LotValue = ContractSize * StopLossDistance * TickValue / TickSize
    // Simplified if TickValue already accounts for TickSize (common, but check specific broker/symbol)
    // Let's use the robust formula, ensuring TickValue/TickSize is handled correctly.
    double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0) {
        Print("Cannot calculate lot size: Invalid Tick Size (", tickSize, ")");
        return 0.0;
    }

    // Value per point (pip) might need adjustment based on quote currency.
    // MQL5's TickValue usually handles this, but verify.
    double lossPerLot = ExtContractSize * stopLossDistance * (tickValue / tickSize) ;

    if(lossPerLot <= 0)
    {
        Print("Cannot calculate lot size: Calculated loss per lot is zero or negative (", lossPerLot, ")");
        return 0.0;
    }

    //--- Calculate Preliminary Lot Size
    double calculatedLot = riskAmount / lossPerLot;

    //--- Normalize and Clamp Lot Size
    return NormalizeLot(calculatedLot);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size according to symbol requirements              |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
    // Clamp between Min and Max Lot
    lot = MathMax(lot, ExtMinLot);
    lot = MathMin(lot, ExtMaxLot);

    // Adjust to Lot Step
    if(ExtLotStep > 0)
    {
        lot = MathRound(lot / ExtLotStep) * ExtLotStep;
        // Re-clamp after rounding, just in case
        lot = MathMax(lot, ExtMinLot);
        lot = MathMin(lot, ExtMaxLot);
    }

    // Ensure minimum precision (e.g., 0.01 for most)
    int lot_digits = 0;
    if(ExtLotStep > 0 && ExtLotStep < 1)
    {
      lot_digits = (int)MathAbs(MathLog10(ExtLotStep));
      if(lot_digits < 2) lot_digits = 2; // Default to 2 decimal places if step is >= 0.01
    } else {
      lot_digits = 2; // Default
    }


    return NormalizeDouble(lot, lot_digits);
}

//+------------------------------------------------------------------+
//| Check if position exists for this EA                           |
//+------------------------------------------------------------------+
bool PositionExist()
{
    return(PositionSelect(Symbol())); // Check if *any* position exists for the current symbol first
    // If you want *only* the EA's position:
    /*
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(ExtPositionInfo.SelectByIndex(i))
        {
            if(ExtPositionInfo.Symbol() == Symbol() && ExtPositionInfo.Magic() == InpMagicNumber)
            {
                return true;
            }
        }
    }
    return false;
    */
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop for Open Positions                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    //--- Get current ATR for trailing (use Trend TF for consistency or add separate input)
    //--- We reuse ExtATRValue which is updated on the Trend TF bar close
    if(ExtATRValue <= 0) {
       // Print("Trailing Stop: Invalid ATR value.");
       return; // Cannot trail without valid ATR
    }

    //--- Iterate through all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!ExtPositionInfo.SelectByIndex(i))
            continue;

        //--- Filter by symbol and magic number
        if(ExtPositionInfo.Symbol() == Symbol() && ExtPositionInfo.Magic() == InpMagicNumber)
        {
            double currentSL = ExtPositionInfo.StopLoss();
            double openPrice = ExtPositionInfo.PriceOpen();
            long ticket = ExtPositionInfo.Ticket();
            ENUM_POSITION_TYPE type = ExtPositionInfo.PositionType();

            //--- Calculate trailing distance
            double trailDistance = InpTrailATRMultiplier * ExtATRValue;

            //--- Calculate activation price
            double activationPrice = 0;
            double activationDistance = InpTrailActivationATR * ExtATRValue;

            if(type == POSITION_TYPE_BUY)
                activationPrice = openPrice + activationDistance;
            else // POSITION_TYPE_SELL
                activationPrice = openPrice - activationDistance;


            //--- Calculate potential new Stop Loss
            double newSL = 0;
            if(type == POSITION_TYPE_BUY)
            {
                //--- Check activation
                if(ExtSymbolInfo.Bid() < activationPrice)
                    continue; // Not enough profit to start trailing

                newSL = ExtSymbolInfo.Bid() - trailDistance;
                //--- Ensure SL doesn't move backwards and provides minimum profit (optional: break-even)
                newSL = MathMax(newSL, currentSL); // Don't move SL backward
                // Optional: Ensure break-even or minimal profit lock
                // newSL = MathMax(newSL, openPrice + ExtPoint); // Ensure at least break-even + 1 point

                 //--- Check if the proposed SL is valid (not too close to market)
                double min_stop_level_points = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL); 
                if(newSL > ExtSymbolInfo.Bid() - min_stop_level_points * ExtPoint) {
                  // Print("Trailing BUY SL ", NormalizeDouble(newSL, ExtDigits), " too close to Bid ", ExtSymbolInfo.Bid());
                   continue; // Cannot set this SL level right now
                }

            }
            else // POSITION_TYPE_SELL
            {
                 //--- Check activation
                if(ExtSymbolInfo.Ask() > activationPrice)
                     continue; // Not enough profit to start trailing

                newSL = ExtSymbolInfo.Ask() + trailDistance;
                //--- Ensure SL doesn't move backwards and provides minimum profit
                newSL = MathMin(newSL, currentSL); // Don't move SL backward
                // Optional: Ensure break-even or minimal profit lock
                // newSL = MathMin(newSL, openPrice - ExtPoint); // Ensure at least break-even + 1 point

                //--- Check if the proposed SL is valid (not too close to market)
                double min_stop_level_points = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL); 
                if(newSL < ExtSymbolInfo.Ask() + min_stop_level_points * ExtPoint) {
                  // Print("Trailing SELL SL ", NormalizeDouble(newSL, ExtDigits), " too close to Ask ", ExtSymbolInfo.Ask());
                   continue; // Cannot set this SL level right now
                }
            }

            //--- Normalize the new SL
            newSL = NormalizeDouble(newSL, ExtDigits);

            //--- Check if modification is needed (significant change respecting TrailStep)
            if(MathAbs(newSL - currentSL) >= InpTrailStepPoints * ExtPoint && newSL != currentSL )
            {
                 // PrintFormat("Trailing SL for ticket %d: Old=%.*f, New=%.*f", ticket, ExtDigits, currentSL, ExtDigits, newSL);
                if(!ExtTrade.PositionModify(ticket, newSL, ExtPositionInfo.TakeProfit())) // Keep original TP
                {
                    PrintFormat("Failed to modify SL for ticket %d. Error: %d (%s)",
                                ticket, ExtTrade.ResultRetcode(), ExtTrade.ResultRetcodeDescription());
                } else {
                     PrintFormat("Successfully trailed SL for ticket %d to %.*f", ticket, ExtDigits, newSL);
                }
            }
        }
    }
} 