//+------------------------------------------------------------------+
//|                                                RAPID FIRE EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024, MetaQuotes Ltd."   // Set the copyright property for the Expert Advisor
#property link      "https://www.mql5.com"              // Set the link property for the Expert Advisor
#property version   "1.00"                              // Set the version of the Expert Advisor
/*
The rapid-fire is basically a trend trading strategy. So, we will be applying the strategy on the pullback of a major trend. The strategy combines two trend indicators, SMA 60 and Parabolic SAR, with the appropriate setting. The SMA is used to identify the major trend of the market. This means we look to buy the currency pair when the price is above the SMA, and similarly, we look to short the pair when the below the SMA.

The Parabolic SAR is used to give the exact entry signal after identifying the market direction and pattern. Once we identify the direction, when the price moves above or below the parabolic SAR, we take a trade based on the current position of the price. Let us understand this in detail.

Trade Setup
In order to explain the step by step procedure of the strategy, we have considered the EUR/USD currency pair where we will be applying the strategy on the 1-minute time frame chart. It is advised not to switch to a time frame any lower than 1 minute as it is very hectic.

Since it is a trend trading strategy, the first step is to identify the major trend of the market and wait for a retracement. If the retracement comes close to the SMA, it is the ideal case of a pullback. The longer the price remains above or below the SMA, the stronger is the trend.

In our example, we see the market is in an uptrend, as shown in the below image, where the price is well above the SMA for a long time.
*/
#include <Trade/Trade.mqh>   // Include the MQL5 standard library for trading operations
CTrade obj_Trade;            // Create an instance of the CTrade class to handle trade operations

int handleSMA = INVALID_HANDLE, handleSAR = INVALID_HANDLE;  // Initialize handles for SMA and SAR indicators
double sma_data[], sar_data[];  // Arrays to store SMA and SAR indicator data

input int sl_points = 15; // Stoploss points
input int tp_points = 10; // Takeprofit points

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   // OnInit is called when the EA is initialized on the chart

   handleSMA = iMA(_Symbol,PERIOD_M1,60,0,MODE_SMA,PRICE_CLOSE);  // Create an SMA (Simple Moving Average) indicator handle for the M1 timeframe
   handleSAR = iSAR(_Symbol,PERIOD_M1,0.02,0.2);                  // Create a SAR (Parabolic SAR) indicator handle for the M1 timeframe
   
   Print("SMA Handle = ",handleSMA);
   Print("SAR Handle = ",handleSAR);
   
   // Check if the handles for either the SMA or SAR are invalid (indicating failure)
   if (handleSMA == INVALID_HANDLE || handleSAR == INVALID_HANDLE){
      Print("ERROR: FAILED TO CREATE SMA/SAR HANDLE. REVERTING NOW");  // Print error message in case of failure
      return (INIT_FAILED);  // Return failure code, stopping the EA from running
   }

   // Configure the SMA and SAR data arrays to work as series, with the newest data at index 0
   ArraySetAsSeries(sma_data,true);
   ArraySetAsSeries(sar_data,true);
   
   return(INIT_SUCCEEDED);  // Return success code to indicate successful initialization
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   // OnDeinit is called when the EA is removed from the chart or terminated

   // Release the indicator handles to free up resources
   IndicatorRelease(handleSMA);
   IndicatorRelease(handleSAR);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   // OnTick is called whenever there is a new market tick (price update)

   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);  // Get and normalize the Ask price
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);  // Get and normalize the Bid price

   // Retrieve the last 3 values of the SMA indicator into the sma_data array
   if (CopyBuffer(handleSMA,0,0,3,sma_data) < 3){
      Print("ERROR: NOT ENOUGH DATA FROM SMA FOR FURTHER ANALYSIS. REVERTING");  // Print error if insufficient SMA data
      return;  // Exit the function if not enough data is available
   }

   // Retrieve the last 3 values of the SAR indicator into the sar_data array
   if (CopyBuffer(handleSAR,0,0,3,sar_data) < 3){
      Print("ERROR: NOT ENOUGH DATA FROM SAR FOR FURTHER ANALYSIS. REVERTING");  // Print error if insufficient SAR data
      return;  // Exit the function if not enough data is available
   }
   
   //ArrayPrint(sma_data,_Digits," , ");
   //ArrayPrint(sar_data,_Digits," , ");
   
   // Get the low prices for the current and previous bars on the M1 timeframe
   double low0 = iLow(_Symbol,PERIOD_M1,0);  // Low of the current bar
   double low1 = iLow(_Symbol,PERIOD_M1,1);  // Low of the previous bar

   // Get the high prices for the current and previous bars on the M1 timeframe
   double high0 = iHigh(_Symbol,PERIOD_M1,0);  // High of the current bar
   double high1 = iHigh(_Symbol,PERIOD_M1,1);  // High of the previous bar
   
   //Print("High bar 0 = ",high0,", High bar 1 = ",high1);
   //Print("Low bar 0 = ",low0,", Low bar 1 = ",low1);
   
   // Define a static variable to track the last time a signal was generated
   static datetime signalTime = 0;
   datetime currTime0 = iTime(_Symbol,PERIOD_M1,0);  // Get the time of the current bar

   // Check for BUY signal conditions:
   // - Current SAR is below the current low (bullish)
   // - Previous SAR was above the previous high (bullish reversal)
   // - SMA is below the current Ask price (indicating upward momentum)
   // - No other positions are currently open (PositionsTotal() == 0)
   // - The signal hasn't already been generated on the current bar
   if (sar_data[0] < low0 && sar_data[1] > high1 && signalTime != currTime0
      && sma_data[0] < Ask && PositionsTotal() == 0)
      {
      Print("BUY SIGNAL @ ",TimeCurrent());  // Print buy signal with timestamp
      signalTime = currTime0;  // Update the signal time to the current bar time
      obj_Trade.Buy(0.01,_Symbol,Ask,Ask-sl_points*_Point,Ask+tp_points*_Point);  // Execute a buy order with a lot size of 0.01, stop loss and take profit
   }

   // Check for SELL signal conditions:
   // - Current SAR is above the current high (bearish)
   // - Previous SAR was below the previous low (bearish reversal)
   // - SMA is above the current Bid price (indicating downward momentum)
   // - No other positions are currently open (PositionsTotal() == 0)
   // - The signal hasn't already been generated on the current bar
   else if (sar_data[0] > high0 && sar_data[1] < low1 && signalTime != currTime0
      && sma_data[0] > Bid && PositionsTotal() == 0){
      Print("SELL SIGNAL @ ",TimeCurrent());  // Print sell signal with timestamp
      signalTime = currTime0;  // Update the signal time to the current bar time
      obj_Trade.Sell(0.01,_Symbol,Bid,Bid+sl_points*_Point,Bid-tp_points*_Point);  // Execute a sell order with a lot size of 0.01, stop loss and take profit
   }
}
//+------------------------------------------------------------------+
