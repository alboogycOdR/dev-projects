//+------------------------------------------------------------------+
//| CRT_Core.mqh – v5.3 (Final Methodologically Corrected Version)   |
//+------------------------------------------------------------------+
#property library

//--- FEATURE TOGGLES & INPUTS --------------------------------------
// Note: These inputs are better placed in the main EA file.
// Kept here for structural integrity based on the original file.
input bool Use_FVG_SizeValidation = true;      // Validate FVG size
input double MinFVGSizePips = 5.0;           // Minimum FVG size in pips
input bool Use_EntryConfirmation = true;       // Require an engulfing candle at the FVG for entry

//--- ENUMS & STRUCT ------------------------------------------------
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY, INVALID };
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH };

// [v5.3 UPGRADE] Added mss_confirmed_time to track the precise bar of the MSS.
struct CRT_State
{
   string            symbol;
   ENUM_BIAS         bias;
   datetime          bias_time;
   double            crt_high;
   double            crt_low;
   double            sweep_high; // Price of the actual sweep high
   double            sweep_low;  // Price of the actual sweep low
   double            mss_level;
   datetime          mss_confirmed_time; // The time the MSS break occurred
   double            fvg_high;
   double            fvg_low;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
};

//--- HELPER FUNCTIONS -----------------------------------------------
// Function to find the last valid swing point (high or low) in a series of bars.
double FindLastSwing(const MqlRates &rates[], bool find_high, int &swing_idx)
{
    for(int i = ArraySize(rates) - 3; i >= 0; i--) // Iterate from recent past backwards
    {
        if(find_high && rates[i].high > rates[i+1].high && rates[i].high > rates[i-1].high)
        {
            swing_idx = i;
            return rates[i].high;
        }
        if(!find_high && rates[i].low < rates[i+1].low && rates[i].low < rates[i-1].low)
        {
            swing_idx = i;
            return rates[i].low;
        }
    }
    return 0;
}

// Function to find the most recent FVG formed AFTER a Market Structure Shift.
bool FindFVG(const MqlRates &rates[], CRT_State &s, bool find_bullish, int start_idx)
{
    for(int i = start_idx; i > 1; i--)
    {
        // Bullish FVG: Look for a gap where candle[i]'s low is above candle[i-2]'s high.
        if(find_bullish && rates[i].low > rates[i-2].high)
        {
            s.fvg_high = rates[i-2].high;
            s.fvg_low  = rates[i].low;
            // FVG Size Validation
            if(Use_FVG_SizeValidation)
            {
               double fvg_size_pips = (s.fvg_high - s.fvg_low) / (SymbolInfoDouble(s.symbol, SYMBOL_POINT) * 10);
               if(fvg_size_pips < MinFVGSizePips) return false;
            }
            return true;
        }
        // Bearish FVG: Look for a gap where candle[i]'s high is below candle[i-2]'s low.
        if(!find_bullish && rates[i].high < rates[i-2].low)
        {
            s.fvg_high = rates[i].high;
            s.fvg_low  = rates[i-2].low;
            // FVG Size Validation
            if(Use_FVG_SizeValidation)
            {
               double fvg_size_pips = (s.fvg_high - s.fvg_low) / (SymbolInfoDouble(s.symbol, SYMBOL_POINT) * 10);
               if(fvg_size_pips < MinFVGSizePips) return false;
            }
            return true;
        }
    }
    return false;
}

// Function to check for a bullish engulfing confirmation candle.
bool IsBullishEngulfing(const MqlRates &rates[]) 
{
   return(rates[0].open < rates[0].close && rates[1].open > rates[1].close && rates[0].close > rates[1].open);
}

// Function to check for a bearish engulfing confirmation candle.
bool IsBearishEngulfing(const MqlRates &rates[]) 
{
   return(rates[0].open > rates[0].close && rates[1].open < rates[1].close && rates[0].close < rates[1].open);
}

//+------------------------------------------------------------------+
//| [CORRECTED] M15 STATE STEP: Main execution logic                 |
//+------------------------------------------------------------------+
void M15_Step(CRT_State &s)
{
    if(s.bias != BULLISH && s.bias != BEARISH) return;

    MqlRates m15[];
    ArraySetAsSeries(m15, false); // Use standard array indexing (0 = oldest)
    if(CopyRates(s.symbol, PERIOD_M15, 0, 50, m15) < 20) return; // Get more bars for lookbacks

    int last_idx = ArraySize(m15) - 1;

    // --- BULLISH STATE MACHINE ---
    if(s.bias == BULLISH)
    {
        switch(s.bull_state)
        {
            case IDLE:
                if(m15[last_idx].low < s.crt_low)
                {
                    int swing_idx = -1;
                    // [FIX] Correctly find the last SWING HIGH to serve as the MSS level.
                    s.mss_level = FindLastSwing(m15, true, swing_idx);
                    if(s.mss_level > 0)
                    {
                       s.sweep_low = m15[last_idx].low; // Store the actual low of the sweep
                       s.bull_state = SWEEP;
                       Print(s.symbol, " | BULL | IDLE->SWEEP | MSS Level Target: ", s.mss_level);
                    }
                }
                break;

            case SWEEP:
                if(m15[last_idx].high > s.mss_level)
                {
                    s.mss_confirmed_time = m15[last_idx].time;
                    s.bull_state = MSS;
                    Print(s.symbol, " | BULL | SWEEP->MSS | Structure Broken.");
                }
                break;

            case MSS:
                // [FIX] Look for FVG *after* the MSS has been confirmed.
                if(FindFVG(m15, s, true, ArraySize(m15)-1))
                {
                   s.bull_state = FVG;
                   Print(s.symbol, " | BULL | MSS->FVG | Entry FVG found: ", s.fvg_low, "-", s.fvg_high);
                }
                break;
                
            case FVG:
                // If price pulls back into the identified FVG...
                if(m15[last_idx].low < s.fvg_high)
                {
                    // And we get the optional confirmation...
                    if(!Use_EntryConfirmation || IsBullishEngulfing(m15))
                    {
                       s.bull_state = ENTRY;
                       Print(s.symbol, " | BULL | FVG->ENTRY | ENTRY TRIGGERED!");
                    }
                }
                break;
        }
    }
    // --- BEARISH STATE MACHINE ---
    else if(s.bias == BEARISH)
    {
        switch(s.bear_state)
        {
            case IDLE:
                if(m15[last_idx].high > s.crt_high)
                {
                    int swing_idx = -1;
                    // [FIX] Correctly find the last SWING LOW to serve as the MSS level.
                    s.mss_level = FindLastSwing(m15, false, swing_idx);
                    if(s.mss_level > 0)
                    {
                       s.sweep_high = m15[last_idx].high; // Store the actual high of the sweep
                       s.bear_state = SWEEP;
                       Print(s.symbol, " | BEAR | IDLE->SWEEP | MSS Level Target: ", s.mss_level);
                    }
                }
                break;

            case SWEEP:
                if(m15[last_idx].low < s.mss_level)
                {
                    s.mss_confirmed_time = m15[last_idx].time;
                    s.bear_state = MSS;
                    Print(s.symbol, " | BEAR | SWEEP->MSS | Structure Broken.");
                }
                break;

            case MSS:
                // [FIX] Look for FVG *after* the MSS has been confirmed.
                if(FindFVG(m15, s, false, ArraySize(m15)-1))
                {
                   s.bear_state = FVG;
                   Print(s.symbol, " | BEAR | MSS->FVG | Entry FVG found: ", s.fvg_low, "-", s.fvg_high);
                }
                break;

            case FVG:
                // If price pulls back into the identified FVG...
                if(m15[last_idx].high > s.fvg_low)
                {
                    // And we get the optional confirmation...
                    if(!Use_EntryConfirmation || IsBearishEngulfing(m15))
                    {
                       s.bear_state = ENTRY;
                       Print(s.symbol, " | BEAR | FVG->ENTRY | ENTRY TRIGGERED!");
                    }
                }
                break;
        }
    }
}