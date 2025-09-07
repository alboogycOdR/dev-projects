//+------------------------------------------------------------------+
//|                                                      SMC_RSI.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade/Trade.mqh>
//10 July 2024
//+------------------------------------------------------------------+
//|                 Global Variables and inputs                      |
//+------------------------------------------------------------------+
long MagicNumber = 76543;
double lotsize = 0.01;
input int RSIperiod = 8;
input int RSIlevels = 70;
int stopLoss = 500;
int takeProfit = 1000;
bool closeSignal = false;

//+------------------------------------------------------------------+
//|                          RSI Vars                                |
//+------------------------------------------------------------------+
int handle;
double buffer[];
MqlTick currentTick;
CTrade trade;
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){

   if(RSIperiod <= 1){
      Alert("RSI period <= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(RSIlevels >= 100 || RSIlevels <= 50){
      Alert("RSI level >= 100 or <= 50");
      return INIT_PARAMETERS_INCORRECT;
   }
   // set magic number to trade object
   trade.SetExpertMagicNumber(MagicNumber);
   
   // create rsi handle 
   handle = iRSI(_Symbol, PERIOD_CURRENT, RSIperiod, PRICE_CLOSE);
   if(handle == INVALID_HANDLE){
      Alert("Failed to create indicator handle");
      return INIT_FAILED;
   }
   
   // set buffer as series
   ArraySetAsSeries(buffer, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   // release indicator
   if(handle != INVALID_HANDLE){IndicatorRelease(handle);}
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
   
// Declare static variables to retain values across function calls
static bool isNewBar = false;
static int prevBars = 0;

// Get the current number of bars
int newbar = iBars(_Symbol, _Period);

// Check if the number of bars has changed
if (prevBars == newbar) {
    // No new bar
    isNewBar = false;
} else {
    // New bar detected
    isNewBar = true;
    // Update previous bars count to current
    prevBars = newbar;
}


const int swing_Length = 10;
int r_index, l_index;
int curr_bar = swing_Length;
bool isSwingHigh = true, isSwingLow = true;
static double marked_swing_H = -1.0, marked_swing_L = -1.0;

double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

// Check for new bar and swing high/low
if (isNewBar) {
    for (int a = 1; a <= swing_Length; a++) {
        r_index = curr_bar - a;
        l_index = curr_bar + a;

        if ((getHigh(curr_bar) <= getHigh(r_index)) || (getHigh(curr_bar) < getHigh(l_index))) {
            isSwingHigh = false;
        }
        if ((getLow(curr_bar) >= getLow(r_index)) || (getLow(curr_bar) > getLow(l_index))) {
            isSwingLow = false;
        }
    }

    if (isSwingHigh) {
        marked_swing_H = getHigh(curr_bar);
        markswing(TimeToString(getTime(curr_bar)), getTime(curr_bar), getHigh(curr_bar), 32, clrBlue, -1);
    }
    if (isSwingLow) {
        marked_swing_L = getLow(curr_bar);
        markswing(TimeToString(getTime(curr_bar)), getTime(curr_bar), getLow(curr_bar), 32, clrBlue, +1);
    }
}

 

 

// Get RSI value
int values = CopyBuffer(handle, 0, 0, 2, buffer);
if (values != 2) {
    Print("Failed to get indicator values");
    return;
}

Comment("Buffer[0]: ", buffer[0],
        "\nBuffer[1]: ", buffer[1]);

// Count open positions
int cntBuy = 0, cntSell = 0;
if (!countOpenPositions(cntBuy, cntSell)) {
    return;
}

// Check for sell signal
if (marked_swing_H > 0 && Ask > marked_swing_H && buffer[0] >= 70) {
    Print("Sell Signal: Market is above previous high and RSI >= 70");
    int marked_swing_H_index = 0;
    for (int i = 0; i <= swing_Length * 2 + 1000; i++) {
        //double high_sel = high(i);
        if (getHigh(i) == marked_swing_H) {
            marked_swing_H_index = i;
            break;
        }
    }
    Mrk_break_L(TimeToString(getTime(0)), getTime(marked_swing_H_index), getHigh(marked_swing_H_index), getTime(0), getHigh(marked_swing_H_index), clrRed, -1);

    // Execute sell trade
    if (cntSell == 0) {
        // Get ask price
        double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),Digits());
        double sl = Bid + stopLoss * _Point;
        double tp = Bid - takeProfit * _Point;
        //NormalizeDouble(sl, _Digits);
        //NormalizeDouble(tp, _Digits);

        trade.PositionOpen(_Symbol, ORDER_TYPE_SELL, lotsize, currentTick.bid, sl, tp, "RSI EA");
    }

    marked_swing_H = -1.0; // Reset swing high
    return;
}

// Check for buy signal
if (marked_swing_L > 0 && Bid < marked_swing_L && buffer[0] <= 30) {
    Print("Buy Signal: Market is below previous low and RSI <= 30");
    int marked_swing_L_index = 0;
    for (int i = 0; i <= swing_Length * 2 + 1000; i++) {
        if (getLow(i) == marked_swing_L) {
            marked_swing_L_index = i;
            break;
        }
    }
    Mrk_break_L(TimeToString(getTime(0)), getTime(marked_swing_L_index), getLow(marked_swing_L_index), getTime(0), getLow(marked_swing_L_index), clrBlue, +1);

    // Execute buy trade
    if (cntBuy == 0) {
        // Get ask price
        double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),Digits());
        double sl =  Ask - stopLoss * _Point;
        double tp =  Ask + takeProfit * _Point;
        //if (!NormalizePrice(sl)) return;
        //if (!NormalizePrice(tp)) return;

        trade.PositionOpen(_Symbol, ORDER_TYPE_BUY, lotsize, currentTick.ask, sl, tp, "RSI EA");
    }

    marked_swing_L = -1.0; // Reset swing low
    return;
}

   
}

//+------------------------------------------------------------------+
//|                       Custom Functions                           |
//+------------------------------------------------------------------+

// Custom functions to get high, low, and time of a given index for the current symbol and period
double getHigh(int index) {
    return iHigh(_Symbol, _Period, index);
}

double getLow(int index) {
    return iLow(_Symbol, _Period, index);
}

datetime getTime(int index) {
    return iTime(_Symbol, _Period, index);
}

// Function to mark swing points with an arrow and optional text
void markswing(string objectName, datetime eventTime, double eventPrice, int arrowCode, color arrowColor, int dir) {
    // Check if the object already exists
    if (ObjectFind(0, objectName) < 0) {
        // Create an arrow object at the given time and price
        ObjectCreate(0, objectName, OBJ_ARROW, 0, eventTime, eventPrice);
        ObjectSetInteger(0, objectName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, objectName, OBJPROP_FONTSIZE, 10);

        // Set anchor based on dir
        if (dir > 0) {
            ObjectSetInteger(0, objectName, OBJPROP_ANCHOR, ANCHOR_TOP);
        } else if (dir < 0) {
            ObjectSetInteger(0, objectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        }

        // Create a text label for the arrow
        string labelName = objectName + "_Label";
        ObjectCreate(0, labelName, OBJ_TEXT, 0, eventTime, eventPrice);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);

        // Set text and anchor based on dir
        if (dir > 0) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "  ");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
        } else if (dir < 0) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "  ");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
        }
    }
    // Redraw the chart to show the changes
    ChartRedraw(0);
}

// Function to draw break levels with an arrowed line and optional text
void Mrk_break_L(string objectName, datetime timeStart, double priceStart, datetime timeEnd, double priceEnd, color lineColor, int dir) {
    // Check if the object already exists
    if (ObjectFind(0, objectName) < 0) {
        // Create an arrowed line object between the start and end points
        ObjectCreate(0, objectName, OBJ_TREND, 0, timeStart, priceStart, timeEnd, priceEnd);
        ObjectSetInteger(0, objectName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);

        // Create a text label for the break level
        string labelName = objectName + "_Break";
        ObjectCreate(0, labelName, OBJ_TEXT, 0, timeEnd, priceEnd);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);

        // Set text and anchor based on dir
        if (dir > 0) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "Break  ");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
        } else if (dir < 0) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "Break  ");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
        }
    }
    // Redraw the chart to show the changes
    ChartRedraw(0);
}


// count open positions
bool countOpenPositions(int &cntBuy, int &cntSell){
   cntBuy = 0;
   cntSell = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0){Print("Failed to get position ticket"); return false;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select position");return false;}
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic number"); return false;}
      if(magic == MagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)){Print("Failed to get position type"); return false;}
         if(type == POSITION_TYPE_BUY){cntBuy++;}
         if(type == POSITION_TYPE_SELL){cntSell++;}
      }
   }
   
   return true;
}

// close positions
bool closePositions(int all_pos){

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0){Print("Failed to get position ticket"); return false;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select position");return false;}
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC, magic)){Print("Failed to get position magic number"); return false;}
      if(magic == MagicNumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE, type)){Print("Failed to get position type"); return false;}
         if(all_pos == 1 && type == POSITION_TYPE_SELL){continue;}
         if(all_pos == 2 && type == POSITION_TYPE_BUY){continue;}
         trade.PositionClose(ticket);
         if(trade.ResultRetcode() != TRADE_RETCODE_DONE){
            Print("Failed to close position. ticket: ",(string)ticket, " result:", (string)trade.ResultRetcode(), ":", trade.CheckResultRetcodeDescription());
            return false;
         }
      }
   }
   
   return true;
}
