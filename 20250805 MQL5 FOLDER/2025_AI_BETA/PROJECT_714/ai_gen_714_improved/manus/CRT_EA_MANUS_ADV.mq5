//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Get current time
   MqlDateTime current_time;
   TimeCurrent(current_time);

//--- Determine Daily Bias (can be done once per day or on demand)
   static int prev_day = -1;
   if (current_time.day != prev_day)
     {
      string daily_bias = DetermineDailyBias();
      Comment("Daily Bias: " + daily_bias);
      prev_day = current_time.day;
     }

//--- Check if it\"s 8:00 AM NY (ET) and CRT range is not set for today
   if (current_time.hour == 8 && current_time.min == 0 && !CRT_Range_Set)
     {
      //--- Get 8 AM H1 candle data
      MqlRates rates[];
      if(CopyRates(Symbol(), InpCRTTimeframe, 0, 1, rates) > 0)
        {
         CRT_High = rates[0].high;
         CRT_Low = rates[0].low;
         CRT_Range_Set = true; // Mark as set for today

         //--- Draw CRT lines
         ObjectSetDouble(0, "CRT_High_Line", OBJPROP_PRICE, CRT_High);
         ObjectSetDouble(0, "CRT_Low_Line", OBJPROP_PRICE, CRT_Low);
         ObjectSetInteger(0, "CRT_High_Line", OBJPROP_TIME, rates[0].time);
         ObjectSetInteger(0, "CRT_Low_Line", OBJPROP_TIME, rates[0].time);
        }
     }

//--- Reset CRT_Range_Set at the start of a new day
   if (current_time.hour == 0 && current_time.min == 0 && current_time.sec == 0)
     {
      CRT_Range_Set = false;
     }

//--- Check if current time is within NY Killzone
   bool in_killzone = false;
   if (current_time.hour > InpNYKillzoneStartHour || (current_time.hour == InpNYKillzoneStartHour && current_time.min >= InpNYKillzoneStartMinute))
     {
      if (current_time.hour < InpNYKillzoneEndHour || (current_time.hour == InpNYKillzoneEndHour && current_time.min <= InpNYKillzoneEndMinute))
        {
         in_killzone = true;
        }
     }

   if (in_killzone && CRT_Range_Set)
     {
      //--- Call entry logic functions based on operational mode
      if (InpOperationalMode == MODE_FULLY_AUTOMATED)
        {
         CheckConfirmationEntry();
         CheckAggressiveEntry();
         CheckThreeCandlePatternEntry();
        }
      else if (InpOperationalMode == MODE_SIGNALS_ONLY)
        {
         // Generate alerts without placing trades
         if (CheckConfirmationEntry()) Print("Signal: Confirmation Entry possible!");
         if (CheckAggressiveEntry()) Print("Signal: Aggressive Entry possible!");
         if (CheckThreeCandlePatternEntry()) Print("Signal: 3-Candle Pattern Entry possible!");
         if (InpEnableSoundAlerts) Alert("CRT EA: Potential Trade Setup!");
        }
      else if (InpOperationalMode == MODE_MANUAL)
        {
         // Display trade panel for manual execution (handled by dashboard)
        }
     }

   // Update dashboard
   UpdateDashboard();

//---
  }
//+------------------------------------------------------------------+


