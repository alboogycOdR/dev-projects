//+------------------------------------------------------------------+
//|         Open Range Breakout EA with Advanced Features            |
//|                                                                  |
//| Description:                                                     |
//|  - Determines the highest and lowest price in a defined          |
//|    open range period (with a specified start time and            |
//|    duration).                                                    |
//|  - After the range period, the EA validates the range against    |
//|    minimum and maximum values (in points) set by the user.       |
//|  - If the range is within the boundaries, the EA waits for a     |
//|    breakout (price moves above range high or below range low).   |
//|  - Upon breakout, a market order is immediately placed.          |
//|  - Two SL modes are available: fixed stop loss (as a             |
//|    percentage of the range) or range-based stop loss (with       |
//|    an additional buffer).                                        |
//|  - If enabled, a trailing stop is applied once the profit        |
//|    exceeds a certain percentage of the range.                    |
//|  - If enabled, a breakeven function moves SL to entry price      |
//|    once profit reaches specified percentage of range.            |
//|  - At the end of the trading day, all open positions are         |
//|    closed.                                                       |
//|  - Day filter allows trading only on selected days of the week.  |
//|  - Risk management allows setting either fixed lots or risk      |
//|    percentage of account balance.                                |
//|  - News filter disables trading for entire days when important   |
//|    news is scheduled.                                            |
//|  - Volume filter ensures minimum volume requirements are met     |
//|    before executing breakout trades.                             |
//+------------------------------------------------------------------+

#include <Trade\Trade.mqh>
CTrade trade;

//---------------------------------------------------------------------
// Input Groups & Parameters
//---------------------------------------------------------------------

//------ Open Range Settings ------
input group "------ Open Range Settings ------";
input int    RangeStartHour           = 16;       // Start hour for the open range period
input int    RangeStartMinute         = 30;       // Start minute for the open range period
input int    RangeDurationMinutes     = 25;       // Duration(in minutes)of the open range period(15High-25LowRisk)
input double MinRangePoints           = 2000.0;   // Minimum range in points
input double MaxRangePoints           = 13000.0;  // Maximum range in points

//------ Day Filter Settings ------
input group "------ Day Filter Settings ------";
input bool   MondayEnabled            = false;    // Enable trading on Monday
input bool   TuesdayEnabled           = true;     // Enable trading on Tuesday
input bool   WednesdayEnabled         = false;    // Enable trading on Wednesday
input bool   ThursdayEnabled          = true;     // Enable trading on Thursday
input bool   FridayEnabled            = true;     // Enable trading on Friday
input bool   SaturdayEnabled          = false;    // Enable trading on Saturday
input bool   SundayEnabled            = false;    // Enable trading on Sunday

//------ Volume Filter Settings ------
input group "------ Volume Filter ------";
input bool   UseVolumeFilter          = true;     // Enable volume filter for breakout confirmation
input ENUM_TIMEFRAMES VolumeTimeframe = PERIOD_H1; // Timeframe for volume calculations
input int    VolumeLookbackBars       = 24;       // Number of bars to look back for volume average
input double MinVolumeMultiplier      = 1.2;      // Minimum volume as multiplier of average volume

//------ Stop Loss Settings ------
enum SLModeEnum { FIXED_SL = 0, RANGE_SL = 1 };
input group       "------ Stop Loss Settings ------";
input SLModeEnum SLMode              = RANGE_SL;  // FIXED_SL: fixed percentage; RANGE_SL: based on opposite range side with buffer
input double FixedSLPercent          = 100;       // For FIXED_SL: SL distance as % of range width
input double SLBufferPercent         = 5;         // For RANGE_SL: extra buffer as % of range width

//------ Risk Management Settings ------
enum LotSizeModeEnum { FIXED_LOTS = 0, RISK_PERCENT = 1 };
input group "------ Risk Management Settings ------";
input LotSizeModeEnum LotSizeMode    = RISK_PERCENT; // Lot size mode: fixed lots or risk percentage
input double FixedLotSize            = 0.1;       // Fixed lot size (when LotSizeMode = FIXED_LOTS)
input double RiskPercent             = 2.0;       // Risk percentage of balance (when LotSizeMode = RISK_PERCENT)
input double MaxLotSize              = 1.0;       // Maximum lot size allowed
input bool   RoundToMinLot           = true;      // Round down lot size to the nearest minimum lot

//------ Breakeven Settings ------
input group  "------ Breakeven Settings ------";
input bool   EnableBreakeven         = false;     // Enable/disable breakeven stop loss
input double BEActivationPercent     = 200;       // Profit (as % of range) at which breakeven is activated

//------ Trailing Stop Settings ------
input group  "------ Trailing Stop Settings ------";
input bool   EnableTrailingStop      = true;      // Enable/disable trailing stop loss
input double TrailingActivationProfitPercent = 200; // Profit (in % of range) at which trailing is activated
input double TrailingStopPercent     = 200;       // Distance of trailing stop as % of range

//------ End-of-Day Settings ------
input group "------ End-of-Day Settings ------";
input int    EndOfDayCloseHour       = 22;        // Hour at which positions are closed
input int    EndOfDayCloseMinute     = 45;        // Minute at which positions are closed

//------ General Settings ------
input group "------ General Settings ------";
input long   MagicNumber              = 123456;   // EA Magic Number to identify its own trades

//------ News Filter Settings ------
input group "------ News Filter Settings ------";
input bool   NewsFilterOn            = true;      // Filter for News?
enum SeparatorEnum {COMMA=0, SEMICOLON=1};
input SeparatorEnum Separator        = COMMA;     // Separator to separate news keywords
input string KeyNews                 = "BCB,NFP,JOLTS,Nonfarm,PMI,Retail,GDP,Confidence,Interest Rate"; // Keywords in News to avoid
input string NewsCurrencies          = "USD,GBP,EUR,JPY"; // Currencies for News LookUp
input int    DaysNewsLookup          = 100;       // No of Days to look up news

//---------------------------------------------------------------------
// Global Variables
//---------------------------------------------------------------------
datetime g_rangeStartTime     = 0;
datetime g_rangeEndTime       = 0;
double   g_openRangeHigh      = 0.0;
double   g_openRangeLow       = 0.0;
bool     g_rangeCalculated    = false;
bool     g_rangeValid         = false;  // New flag to track if range is valid
bool     g_tradePlaced        = false;
double   g_openPrice          = 0.0;    // Price at the beginning of the range period
bool     g_breakEvenSet       = false;  // Flag to track if breakeven has been applied

// News filter variables
string     g_newsToAvoid[];
bool       g_disabledDueToNews = false;
datetime   g_newsDate = 0;
string     g_newsDescription = "";

//---------------------------------------------------------------------
// Helper: Check if volume confirms a breakout signal
//---------------------------------------------------------------------
bool VolumeConfirmsBreakout()
{
   if(!UseVolumeFilter) return true;
   
   // Get recent volume data
   long volumes[];
   ArraySetAsSeries(volumes, true);
   int copied = CopyTickVolume(_Symbol, VolumeTimeframe, 0, VolumeLookbackBars + 1, volumes);
   
   if(copied <= 0)
   {
      Print("Error getting volume data for volume filter calculation");
      return false;
   }
   
   // Calculate the average volume of the lookback period (excluding current bar)
   long totalVolume = 0;  // Changed from double to long to avoid type conversion warning
   for(int i=1; i<=VolumeLookbackBars; i++)
   {
      totalVolume += volumes[i];
   }
   
   double averageVolume = (double)totalVolume / VolumeLookbackBars;  // Explicit cast to double only for division
   
   // Check if current volume is high enough to confirm breakout
   if(volumes[0] >= averageVolume * MinVolumeMultiplier)
   {
      Print("Volume filter passed: Current volume (", volumes[0], 
            ") >= Average volume (", averageVolume, ") * Multiplier (", MinVolumeMultiplier, ")");
      return true;
   }
   else
   {
      Print("Volume filter failed: Current volume (", volumes[0], 
            ") < Average volume (", averageVolume, ") * Multiplier (", MinVolumeMultiplier, ")");
      return false;
   }
}

//---------------------------------------------------------------------
// Helper: Reset daily parameters (with day-of-month comparison)
//---------------------------------------------------------------------
void ResetDailyParameters(datetime currentTime)
{
   // Determine range start/end time based on current day
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   dt.hour = RangeStartHour;
   dt.min  = RangeStartMinute;
   dt.sec  = 0;
   g_rangeStartTime = StructToTime(dt);
   g_rangeEndTime   = g_rangeStartTime + RangeDurationMinutes * 60;
   
   g_openRangeHigh   = 0.0;
   g_openRangeLow    = 0.0;
   g_rangeCalculated = false;
   g_rangeValid      = false;  // Reset range validity flag
   g_tradePlaced     = false;
   g_openPrice       = 0.0;
   g_breakEvenSet    = false;
   
   // Remove previous chart objects
   ObjectDelete(0, "OpenRangeHigh");
   ObjectDelete(0, "OpenRangeLow");
}

//---------------------------------------------------------------------
// Helper: Draw the open range (high and low lines)
//---------------------------------------------------------------------
void DrawRange()
{
   string highObjName = "OpenRangeHigh";
   string lowObjName  = "OpenRangeLow";
   
   if(ObjectFind(0, highObjName) == -1)
   {
      ObjectCreate(0, highObjName, OBJ_HLINE, 0, 0, g_openRangeHigh);
      ObjectSetInteger(0, highObjName, OBJPROP_COLOR, clrBlue);
   }
   else
   {
      ObjectSetDouble(0, highObjName, OBJPROP_PRICE, g_openRangeHigh);
   }
   
   if(ObjectFind(0, lowObjName) == -1)
   {
      ObjectCreate(0, lowObjName, OBJ_HLINE, 0, 0, g_openRangeLow);
      ObjectSetInteger(0, lowObjName, OBJPROP_COLOR, clrRed);
   }
   else
   {
      ObjectSetDouble(0, lowObjName, OBJPROP_PRICE, g_openRangeLow);
   }

   // Add comment to chart showing range size
   double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double measuredRangePoints = (g_openRangeHigh - g_openRangeLow) / pointVal;
   Comment("Range size: ", measuredRangePoints, " points (Min: ", MinRangePoints, ", Max: ", MaxRangePoints, ")");
}

//---------------------------------------------------------------------
// Helper: Check if trading is allowed today based on day filter
//---------------------------------------------------------------------
bool IsTradingAllowedToday()
{
   // First check if there's news today that should disable trading
   if(g_disabledDueToNews) {
      Comment("Trading disabled due to news: ", g_newsDescription, " on ", TimeToString(g_newsDate, TIME_DATE));
      return false;
   }
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   switch(dt.day_of_week)
   {
      case 0: return SundayEnabled;    // Sunday
      case 1: return MondayEnabled;    // Monday
      case 2: return TuesdayEnabled;   // Tuesday
      case 3: return WednesdayEnabled; // Wednesday
      case 4: return ThursdayEnabled;  // Thursday
      case 5: return FridayEnabled;    // Friday
      case 6: return SaturdayEnabled;  // Saturday
      default: return false;
   }
}

//---------------------------------------------------------------------
// Helper: Calculate lot size based on risk percentage and stop loss
//---------------------------------------------------------------------
double CalculateLotSize(double entryPrice, double stopLossPrice)
{
   if(LotSizeMode == FIXED_LOTS)
      return FixedLotSize;
      
   // For RISK_PERCENT mode
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   // Calculate risk amount in account currency
   double riskAmount = accountBalance * (RiskPercent / 100.0);
   
   // Calculate price difference between entry and stop loss (in points)
   double priceDiff = MathAbs(entryPrice - stopLossPrice);
   
   // Calculate number of ticks in our stop loss
   double tickCount = priceDiff / tickSize;
   
   // Calculate potential loss per lot
   double lossPerLot = tickCount * tickValue;
   
   // Add a safety check to prevent division by zero
   if (lossPerLot <= 0)
   {
      PrintFormat("Invalid Loss Per Lot calculated (%f). Cannot determine lot size. Trade aborted.", lossPerLot);
      return 0.0; // Return zero lot size to prevent trade execution
   }
   
   // Calculate appropriate lot size based on risk
   double calculatedLotSize = riskAmount / lossPerLot;
   
   // Apply maximum lot size limit
   calculatedLotSize = MathMin(calculatedLotSize, MaxLotSize);
   
   // Round to appropriate lot step if needed
   if(RoundToMinLot)
   {
      calculatedLotSize = MathFloor(calculatedLotSize / lotStep) * lotStep;
      calculatedLotSize = MathMax(calculatedLotSize, minLot); // Ensure at least minimum lot
   }
   
   return calculatedLotSize;
}

//---------------------------------------------------------------------
// News filter function: Check for upcoming news
//---------------------------------------------------------------------
void CheckUpcomingNews()
{
   if(!NewsFilterOn) return;

   // Reset previous news flag
   g_disabledDueToNews = false;
   g_newsDate = 0;
   g_newsDescription = "";
   
   // Parse the keywords to avoid
   string sep;
   if(Separator == COMMA) sep = ",";
   else sep = ";";
   
   ushort sep_code = StringGetCharacter(sep, 0); // Use a local variable
   int numKeywords = StringSplit(KeyNews, sep_code, g_newsToAvoid);
   
   // Split the news currencies string into an array for accurate matching
   string newsCurrencyArray[];
   StringSplit(NewsCurrencies, sep_code, newsCurrencyArray);
   
   // Get calendar values from current time to specified days in future
   MqlCalendarValue values[];
   datetime starttime = TimeCurrent();
   datetime endtime = starttime + PeriodSeconds(PERIOD_D1) * DaysNewsLookup;
   
   CalendarValueHistory(values, starttime, endtime, NULL, NULL);
   
   // Loop through calendar events
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   int currentDay = today.day;
   int currentMonth = today.mon;
   int currentYear = today.year;
   
   for(int i = 0; i < ArraySize(values); i++)
   {
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);
      
      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);
      
      // Check if the news currency is in our list of currencies to watch
      bool currencyMatch = false;
      for(int k = 0; k < ArraySize(newsCurrencyArray); k++)
      {
         // Use Trim() to remove any whitespace from the input string
         string currency_to_check = newsCurrencyArray[k];
         StringTrimLeft(currency_to_check);
         StringTrimRight(currency_to_check);
         if(StringCompare(country.currency, currency_to_check) == 0)
         {
             currencyMatch = true;
             break;
         }
      }
      if(!currencyMatch) continue;
      
      // Check if event matches any keywords
      for(int j = 0; j < numKeywords; j++)
      {
         string currentKeyword = g_newsToAvoid[j];
         string currentEventName = event.name;
         
         if(StringFind(currentEventName, currentKeyword) < 0) continue;
         
         // Check if news is today
         MqlDateTime newsTime;
         TimeToStruct(values[i].time, newsTime);
         
         if(newsTime.year == currentYear && newsTime.mon == currentMonth && newsTime.day == currentDay)
         {
            g_disabledDueToNews = true;
            g_newsDate = values[i].time;
            g_newsDescription = currentEventName;
            
            Print("Important news found today: ", country.currency, ": ", event.name, " -> ", TimeToString(values[i].time));
            return;
         }
      }
   }
}

//---------------------------------------------------------------------
// Expert Initialization
//---------------------------------------------------------------------
int OnInit()
{
   datetime now = TimeCurrent();
   ResetDailyParameters(now);
   
   // Set magic number for trade identification
   trade.SetExpertMagicNumber(MagicNumber);
   
   // Initial news check
   CheckUpcomingNews();
   
   return(INIT_SUCCEEDED);
}

//---------------------------------------------------------------------
// Expert Deinitialization
//---------------------------------------------------------------------
void OnDeinit(const int reason)
{
   ObjectDelete(0, "OpenRangeHigh");
   ObjectDelete(0, "OpenRangeLow");
}

//---------------------------------------------------------------------
// Expert Tick Function
//---------------------------------------------------------------------
void OnTick()
{
   datetime now = TimeCurrent();
   static int lastDay = -1;
   MqlDateTime dtNow;
   TimeToStruct(now, dtNow);
   if(lastDay != dtNow.day)
   {
      lastDay = dtNow.day;
      ResetDailyParameters(now);
      // Check for news at the start of each new day
      CheckUpcomingNews();
   }
   
   // Check if trading is allowed today based on day filter and news filter
   if(!IsTradingAllowedToday())
   {
      // If position is open and trading is not allowed today, close position
      if(PositionSelect(_Symbol))
      {
         CloseOpenPositions();
         Print("Position closed: Trading not allowed today.");
      }
      return; // Skip further processing on non-trading days
   }
   
   // During the open range period: update range high/low using the BID price
   if(now >= g_rangeStartTime && now <= g_rangeEndTime && !g_rangeCalculated)
   {
      MqlTick current_tick;
      if(!SymbolInfoTick(_Symbol, current_tick))
      {
         // Could not get tick, skip this iteration
         return;
      }

      if(g_openRangeHigh == 0.0) // First tick within the range period
      {
         g_openRangeHigh = current_tick.ask; // Start high with Ask
         g_openRangeLow  = current_tick.bid; // Start low with Bid
         g_openPrice     = current_tick.bid;
      }
      else
      {
         // Highest price is the highest Ask
         if(current_tick.ask > g_openRangeHigh)
            g_openRangeHigh = current_tick.ask;
         // Lowest price is the lowest Bid
         if(current_tick.bid < g_openRangeLow)
            g_openRangeLow = current_tick.bid;
      }
      DrawRange();
   }
   
   // Once the range period is over, finalize and validate the range
   if(now > g_rangeEndTime && !g_rangeCalculated)
   {
      g_rangeCalculated = true;
      double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double measuredRangePoints = (g_openRangeHigh - g_openRangeLow) / pointVal;
      
      // Check if the range is valid based on min/max criteria
      if(measuredRangePoints >= MinRangePoints && measuredRangePoints <= MaxRangePoints)
      {
         g_rangeValid = true;
         Print("Measured range (", measuredRangePoints, " points) is valid.");
         Comment("Range size: ", measuredRangePoints, " points - VALID (Min: ", MinRangePoints, ", Max: ", MaxRangePoints, ")");
      }
      else
      {
         g_rangeValid = false;
         Print("Measured range (", measuredRangePoints, " points) is outside the allowed bounds.");
         Comment("Range size: ", measuredRangePoints, " points - INVALID (Min: ", MinRangePoints, ", Max: ", MaxRangePoints, ")");
      }
   }
   
   // If range is established, valid, and no trade has been placed yet, check for breakout
   if(g_rangeCalculated && g_rangeValid && !g_tradePlaced)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // On upward breakout (price above range high): place a BUY order
      if(bid > g_openRangeHigh)
      {
         // Check volume confirmation
         bool volumeConfirmed = VolumeConfirmsBreakout();
         
         // Only place trade if volume confirms the bullish move
         if(volumeConfirmed)
         {
            if(OpenBuyOrder())
            {
               g_tradePlaced = true;
               Print("BUY breakout confirmed by Volume");
            }
         }
         else
         {
            Print("BUY breakout detected but NOT confirmed by Volume");
         }
      }
      // On downward breakout (price below range low): place a SELL order
      else if(bid < g_openRangeLow)
      {
         // Check volume confirmation
         bool volumeConfirmed = VolumeConfirmsBreakout();
         
         // Only place trade if volume confirms the bearish move
         if(volumeConfirmed)
         {
            if(OpenSellOrder())
            {
               g_tradePlaced = true;
               Print("SELL breakout confirmed by Volume");
            }
         }
         else
         {
            Print("SELL breakout detected but NOT confirmed by Volume");
         }
      }
   }
   
   // Manage breakeven stop loss (if enabled and trade placed)
   if(EnableBreakeven && g_tradePlaced && !g_breakEvenSet)
      ManageBreakeven();
   
   // Manage trailing stop loss (if enabled and trade placed)
   if(EnableTrailingStop && g_tradePlaced)
      ManageTrailingStop();
      
   // End-of-Day: Close positions at the set time
   if(IsTimeToClose(now))
      CloseOpenPositions();
}

//---------------------------------------------------------------------
// Place a market BUY order
//---------------------------------------------------------------------
bool OpenBuyOrder()
{
   double rangeWidth = g_openRangeHigh - g_openRangeLow;
   double sl = 0.0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(SLMode == FIXED_SL)
   {
      // For BUY: stop loss = entry price - (FixedSLPercent% of range)
      sl = ask - (FixedSLPercent / 100.0) * rangeWidth;
   }
   else // RANGE_SL: stop loss based on the range low with a buffer
   {
      sl = g_openRangeLow - (SLBufferPercent / 100.0) * rangeWidth;
   }
   
   // Calculate appropriate lot size based on risk management settings
   double lotSize = CalculateLotSize(ask, sl);
   
   // Place a market BUY order (price=0 causes immediate execution)
   if(trade.Buy(lotSize, _Symbol, 0, sl, 0, "OpenRange Buy"))
   {
      Print("BUY order opened with lot size: ", lotSize, ", SL: ", sl);
      return true;
   }
   else
   {
      Print("BUY order failed: ", trade.ResultRetcodeDescription());
      return false;
   }
}


//---------------------------------------------------------------------
// Place a market SELL order
//---------------------------------------------------------------------
bool OpenSellOrder()
{
   double rangeWidth = g_openRangeHigh - g_openRangeLow;
   double sl = 0.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(SLMode == FIXED_SL)
   {
      // For SELL: stop loss = entry price + (FixedSLPercent% of range)
      sl = bid + (FixedSLPercent / 100.0) * rangeWidth;
   }
   else // RANGE_SL: stop loss based on the range high with a buffer
   {
      sl = g_openRangeHigh + (SLBufferPercent / 100.0) * rangeWidth;
   }
   
   // Calculate appropriate lot size based on risk management settings
   double lotSize = CalculateLotSize(bid, sl);
   
   if(trade.Sell(lotSize, _Symbol, 0, sl, 0, "OpenRange Sell"))
   {
      Print("SELL order opened with lot size: ", lotSize, ", SL: ", sl);
      return true;
   }
   else
   {
      Print("SELL order failed: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//---------------------------------------------------------------------
// Manage Breakeven Stop Loss
//---------------------------------------------------------------------
void ManageBreakeven()
{
   if(PositionSelect(_Symbol))
   {
      double rangeWidth = g_openRangeHigh - g_openRangeLow;
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = PositionGetDouble(POSITION_SL);
      int posType       = (int)PositionGetInteger(POSITION_TYPE);
      
      // For BUY positions
      if(posType == POSITION_TYPE_BUY)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = currentBid - entryPrice;
         if(profit >= (BEActivationPercent / 100.0) * rangeWidth)
         {
            // Move stop loss to entry price (breakeven)
            if(trade.PositionModify(PositionGetInteger(POSITION_TICKET), entryPrice, PositionGetDouble(POSITION_TP)))
            {
               Print("Breakeven stop for BUY set at: ", entryPrice);
               g_breakEvenSet = true;
            }
         }
      }
      // For SELL positions
      else if(posType == POSITION_TYPE_SELL)
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = entryPrice - currentAsk;
         if(profit >= (BEActivationPercent / 100.0) * rangeWidth)
         {
            // Move stop loss to entry price (breakeven)
            if(trade.PositionModify(PositionGetInteger(POSITION_TICKET), entryPrice, PositionGetDouble(POSITION_TP)))
            {
               Print("Breakeven stop for SELL set at: ", entryPrice);
               g_breakEvenSet = true;
            }
         }
      }
   }
}

//---------------------------------------------------------------------
// Manage Trailing Stop Loss
//---------------------------------------------------------------------
void ManageTrailingStop()
{
   // Don't adjust trailing stop if breakeven hasn't been hit yet
   if(EnableBreakeven && !g_breakEvenSet)
      return;
      
   if(PositionSelect(_Symbol))
   {
      double rangeWidth = g_openRangeHigh - g_openRangeLow;
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = PositionGetDouble(POSITION_SL);
      int posType       = (int)PositionGetInteger(POSITION_TYPE);
      
      // For BUY positions
      if(posType == POSITION_TYPE_BUY)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double profit = currentBid - entryPrice;
         if(profit >= (TrailingActivationProfitPercent / 100.0) * rangeWidth)
         {
            double newSL = currentBid - (TrailingStopPercent / 100.0) * rangeWidth;
            // For BUY the new SL must be higher than current SL
            if(newSL > currentSL)
            {
               if(trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP)))
                  Print("Trailing stop for BUY adjusted to: ", newSL);
            }
         }
      }
      // For SELL positions
      else if(posType == POSITION_TYPE_SELL)
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit = entryPrice - currentAsk;
         if(profit >= (TrailingActivationProfitPercent / 100.0) * rangeWidth)
         {
            double newSL = currentAsk + (TrailingStopPercent / 100.0) * rangeWidth;
            // For SELL the new SL must be lower than current SL (or not set yet)
            if(currentSL == 0 || newSL < currentSL)
            {
               if(trade.PositionModify(PositionGetInteger(POSITION_TICKET), newSL, PositionGetDouble(POSITION_TP)))
                  Print("Trailing stop for SELL adjusted to: ", newSL);
            }
         }
      }
   }
}

//---------------------------------------------------------------------
// Check if it's time to close positions (End-of-Day)
//---------------------------------------------------------------------
bool IsTimeToClose(datetime currentTime)
{
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   if(dt.hour > EndOfDayCloseHour || (dt.hour == EndOfDayCloseHour && dt.min >= EndOfDayCloseMinute))
      return true;
   return false;
}

//---------------------------------------------------------------------
// Close all open positions
//---------------------------------------------------------------------
void CloseOpenPositions()
{
   if(PositionSelect(_Symbol))
   {
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(trade.PositionClose(ticket))
         Print("Position successfully closed.");
      else
         Print("Failed to close position: ", trade.ResultRetcodeDescription());
   }
}