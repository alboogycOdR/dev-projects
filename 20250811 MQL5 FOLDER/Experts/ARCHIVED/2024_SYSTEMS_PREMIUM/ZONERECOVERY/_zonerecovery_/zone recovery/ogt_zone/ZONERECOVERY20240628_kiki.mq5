//+------------------------------------------------------------------+
//|                                                MARTINGALE EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

//    https://www.mql5.com/en/articles/15067

#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//--- Include trade instance class

#include <Trade/Trade.mqh>     // Include the trade class for trading functions
CTrade obj_trade;              // Create an instance of the CTrade class for trading operations
//--- Define utility variables for later use

//respective levels in our system
   #define ZONE_H "ZH"            // Define a constant for the high zone line name
   #define ZONE_L "ZL"            // Define a constant for the low zone line name
   #define ZONE_T_H "ZTH"         // Define a constant for the target high zone line name
   #define ZONE_T_L "ZTL"         // Define a constant for the target low zone line name

//--- Declare variables to hold indicator data
   input double INITIAL_VOLUME = 0.6;  //Volume
   input uint ZONETARGET=200;          //Zone Target (points)
   input uint ZONERANGE=200;           //Recovery Zone Range (points)
   input uint RECOVERY_COEFF=2;        //LotMultiplierFactor
   double zoneHigh = 0;                // Variable to store the high zone price
   double zoneLow = 0;                 // Variable to store the low zone price
   double zoneTargetHigh = 0;          // Variable to store the target high zone price
   double zoneTargetLow = 0;           // Variable to store the target low zone price

//core indicator
   int rsi_handle;                // Handle for the RSI indicator
   double rsiData[];              // Array to store RSI data
   int totalBars = 0;             // Variable to keep track of the total number of bars
   double overBoughtLevel = 70.0; // Overbought level for RSI
   double overSoldLevel = 30.0;   // Oversold level for RSI
//-------------


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Initialize the RSI indicator
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   //--- Return initialization result
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Remove RSI indicator from memory
   IndicatorRelease(rsi_handle);
   ArrayFree(rsiData); // Free the RSI data array
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //zonerec init
      //--- Retrieve the current Ask and Bid prices
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double zoneRange = ZONERANGE * _Point;       // Define the range for the zones
      double zoneTarget = ZONETARGET * _Point;      // Define the target range for the zones
      
      //--- Variables to track trading status
      static int lastDirection = 0;          // -1 = sell, 1 = buy
      static double recovery_lot = 0.0;      // Lot size for recovery trades
      static bool isBuyDone = false, isSellDone = false; // Flags to track trade completion
      
   //--- Close all positions if the bid price is outside target zones
   if (zoneTargetHigh > 0 && zoneTargetLow > 0) {
      if (bid > zoneTargetHigh || bid < zoneTargetLow) {
         obj_trade.PositionClose(_Symbol); // Close the current position
         zonerecover_deleteZoneLevels();               // Delete all drawn zone levels
         for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket > 0) {
               if (PositionSelectByTicket(ticket)) {
                  obj_trade.PositionClose(ticket); // Close positions by ticket
               }
            }
         }
         //--- Reset all zone and direction variables
         zoneHigh = 0;
         zoneLow = 0;
         zoneTargetHigh = 0;
         zoneTargetLow = 0;
         lastDirection = 0;
         recovery_lot = 0;
      }
   }//CLOSING OF POSITIONS

   //--- Check if price is within defined zones and take action
   if (zoneHigh > 0 && zoneLow > 0) 
   {   
      double lots_Rec = NormalizeDouble(recovery_lot, 2); // Normalize the recovery lot size to 2 decimal places
      if (bid > zoneHigh) {
         if (isBuyDone == false || lastDirection < 0) {
            obj_trade.Buy(lots_Rec); // Open a buy trade
            
            lastDirection = 1;       // Set the last direction to buy
            recovery_lot = recovery_lot * RECOVERY_COEFF; // Double the recovery lot size
            isBuyDone = true;        // Mark buy trade as done
            isSellDone = false;      // Reset sell trade flag
         }
      } else if (bid < zoneLow) {
         if (isSellDone == false || lastDirection > 0) {
            obj_trade.Sell(lots_Rec); // Open a sell trade
            
            lastDirection = -1;      // Set the last direction to sell
            recovery_lot = recovery_lot * RECOVERY_COEFF; // Double the recovery lot size
            isBuyDone = false;       // Reset buy trade flag
            isSellDone = true;       // Mark sell trade as done
         }
      }
   }
   
   //--- Update bars and check for new bars
   int bars = iBars(_Symbol, PERIOD_CURRENT);
   if (totalBars == bars) return; // Exit if no new bars
   totalBars = bars; // Update the total number of bars
   
   //--- Exit if there are open positions
   if (PositionsTotal() > 0) return;
   
   //--- Copy RSI data and check for oversold/overbought conditions
   if (!CopyBuffer(rsi_handle, 0, 1, 2, rsiData)) return;
   
   //--- Check for oversold condition and open a buy position
   if (rsiData[1] < overSoldLevel && rsiData[0] > overSoldLevel) 
   {
      obj_trade.Buy(INITIAL_VOLUME); // Open a buy trade with 0.01 lots
      //----------------------------------------------------------------
      ulong pos_ticket = obj_trade.ResultOrder();
      if (pos_ticket > 0) {
         if (PositionSelectByTicket(pos_ticket)) {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            zoneHigh = NormalizeDouble(openPrice, _Digits); // Set the high zone price
            zoneLow = NormalizeDouble(zoneHigh - zoneRange, _Digits); // Set the low zone price
            zoneTargetHigh = NormalizeDouble(zoneHigh + zoneTarget, _Digits); // Set the target high zone price
            zoneTargetLow = NormalizeDouble(zoneLow - zoneTarget, _Digits); // Set the target low zone price
            zonerecover_drawZoneLevel(ZONE_H, zoneHigh, clrGreen, 2); // Draw the high zone line
            zonerecover_drawZoneLevel(ZONE_L, zoneLow, clrRed, 2); // Draw the low zone line
            zonerecover_drawZoneLevel(ZONE_T_H, zoneTargetHigh, clrBlue, 3); // Draw the target high zone line
            zonerecover_drawZoneLevel(ZONE_T_L, zoneTargetLow, clrBlue, 3); // Draw the target low zone line
            
            lastDirection = 1;       // Set the last direction to buy
            recovery_lot = INITIAL_VOLUME * 2; // Set the initial recovery lot size
            isBuyDone = true;        // Mark buy trade as done
            isSellDone = false;      // Reset sell trade flag
         }
      }
   }//BUYTRIGGER and BUY OPERATION(FIRST TIME)
   //--- Check for overbought condition and open a sell position
   else if (rsiData[1] > overBoughtLevel && rsiData[0] < overBoughtLevel) 
   {
      obj_trade.Sell(INITIAL_VOLUME); // Open a sell trade with 0.01 lots
      ulong pos_ticket = obj_trade.ResultOrder();
      if (pos_ticket > 0) {
         if (PositionSelectByTicket(pos_ticket)) {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            zoneLow = NormalizeDouble(openPrice, _Digits); // Set the low zone price
            zoneHigh = NormalizeDouble(zoneLow + zoneRange, _Digits); // Set the high zone price
            zoneTargetHigh = NormalizeDouble(zoneHigh + zoneTarget, _Digits); // Set the target high zone price
            zoneTargetLow = NormalizeDouble(zoneLow - zoneTarget, _Digits); // Set the target low zone price
            zonerecover_drawZoneLevel(ZONE_H, zoneHigh, clrGreen, 2); // Draw the high zone line
            zonerecover_drawZoneLevel(ZONE_L, zoneLow, clrRed, 2); // Draw the low zone line
            zonerecover_drawZoneLevel(ZONE_T_H, zoneTargetHigh, clrBlue, 3); // Draw the target high zone line
            zonerecover_drawZoneLevel(ZONE_T_L, zoneTargetLow, clrBlue, 3); // Draw the target low zone line
            
            lastDirection = -1;      // Set the last direction to sell
            recovery_lot = INITIAL_VOLUME * 2; // Set the initial recovery lot size
            isBuyDone = false;       // Reset buy trade flag
            isSellDone = true;       // Mark sell trade as done
         }
      }
   }//SELLTRIGGER and SELL OPERATION(FIRST TIME)
}

//+------------------------------------------------------------------+
//|      FUNCTION TO DRAW HORIZONTAL ZONE LINES                      |
//+------------------------------------------------------------------+
void zonerecover_drawZoneLevel(string levelName, double price, color clr, int width) {
   ObjectCreate(0, levelName, OBJ_HLINE, 0, TimeCurrent(), price); // Create a horizontal line object
   ObjectSetInteger(0, levelName, OBJPROP_COLOR, clr); // Set the line color
   ObjectSetInteger(0, levelName, OBJPROP_WIDTH, width); // Set the line width
}
//+------------------------------------------------------------------+
//|       FUNCTION TO DELETE DRAWN ZONE LINES                        |
//+------------------------------------------------------------------+
void zonerecover_deleteZoneLevels() {
   ObjectDelete(0, ZONE_H); // Delete the high zone line
   ObjectDelete(0, ZONE_L); // Delete the low zone line
   ObjectDelete(0, ZONE_T_H); // Delete the target high zone line
   ObjectDelete(0, ZONE_T_L); // Delete the target low zone line
}
