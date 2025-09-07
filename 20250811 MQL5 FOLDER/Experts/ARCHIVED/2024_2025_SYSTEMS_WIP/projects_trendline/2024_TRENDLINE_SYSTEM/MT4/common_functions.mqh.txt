//+------------------------------------------------------------------+
//|                                             common_functions.mq4 |
//|                                   Copyright © 2010, Bernd Kreuss |
//|                                             Version: 2010.6.11.1 |
//+------------------------------------------------------------------+

/**
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <stderror.mqh>
#include <stdlib.mqh>

#import "shell32.dll"
   int ShellExecuteA(int hWnd, string Verb, string File, string Parameter, string Path, int ShowCommand);
#import "kernel32.dll"
   void OutputDebugStringA(string msg);
#import

#define SW_SHOWNORMAL 1

static color CLR_BUY_ARROW = Blue;
static color CLR_SELL_ARROW = Red;
static color CLR_CROSSLINE_ACTIVE = Magenta;
static color CLR_CROSSLINE_TRIGGERED = Aqua;
static bool IS_ECN_BROKER = false;

/**
* start an external program but DON'T wait for it to finish
*/
void shell(string file, string parameters=""){
   ShellExecuteA(0, "open", file, parameters, NULL, SW_SHOWNORMAL);
}

/**
* send information to OutputDebugString() to be viewed and logged
* by SysInternals DebugView (free download from microsoft)
* This is ideal for debugging as an alternative to Print().
* The function will take up to 8 string (or numeric) arguments 
* to be concatenated into one debug message.
*/
void log(
   string s1, 
   string s2="", 
   string s3="", 
   string s4="", 
   string s5="", 
   string s6="", 
   string s7="", 
   string s8=""
){
   string out = StringTrimRight(StringConcatenate(
      WindowExpertName(), ".mq4 ", Symbol(), 
      " ", s1, 
      " ", s2, 
      " ", s3, 
      " ", s4, 
      " ", s5, 
      " ", s6, 
      " ", s7, 
      " ", s8
   ));
   OutputDebugStringA(out);
}

/**
* use the Comments() display to simulate the behaviour of
* the good old print command, useful for debugging.
* text will be appended as a new line on every call
* and if it has reached 20 lines it will start to scroll.
* if clear is set to True the buffer will be cleared. 
*/
void print(string text, bool clear=False){
   static string print_lines[20];
   static int print_line_position = 0;
   if (IsOptimization()){
      return(0);
   }
   string output="\n";
   string space = "                        ";
   int max_lines = 20;
   int i;
   if (clear){
      for (i=0; i<max_lines; i++){
         print_lines[i] = "";
         print_line_position = 0;
      }
   }
   
   if (print_line_position == max_lines){
      for (i=0; i<max_lines; i++){
         print_lines[i] = print_lines[i+1];
      }
      print_line_position--;
   }
   
   print_lines[print_line_position] = text;
   print_line_position++;
   
   for(i=0; i<print_line_position; i++){
      output = output + print_lines[i] + "\n";
   }
   
   output = stringReplace(output, "\n", "\n" + space);
   Comment(output);
}

/**
* search for the string needle in the string haystack and replace all
* occurrecnes with replace.
*/
string stringReplace(string haystack, string needle, string replace=""){
   string left, right;
   int start=0;
   int rlen = StringLen(replace);
   int nlen = StringLen(needle);
   while (start > -1){
      start = StringFind(haystack, needle, start);
      if (start > -1){
         if(start > 0){
            left = StringSubstr(haystack, 0, start);
         }else{
            left="";
         }
         right = StringSubstr(haystack, start + nlen);
         haystack = left + replace + right;
         start = start + rlen;
      }
   }
   return (haystack);  
}

/**
* create a positive integer for the use as a magic number.
*
* The function takes a string as argument and calculates
* an 31 bit hash value from it. The hash does certainly not 
* have the strength of a real cryptographic hash function 
* but it should be more than sufficient for generating a
* unique ID from a string and collissions should not occur.
*
* use it in your init() function like this: 
*    magic = makeMagicNumber(WindowExpertName() + Symbol() + Period());
*
* where name would be the name of your EA. Your EA will then
* get a unique magic number for each instrument and timeframe
* and this number will always be the same, whenever you put
* the same EA onto the same chart.
*
* Numbers generated during testing mode will differ from those
* numbers generated on a live chart.
*/
int makeMagicNumber(string key){
   int i, k;
   int h = 0;
   
   if (IsTesting()){
      key = "_" + key;
   }
   
   for (i=0; i<StringLen(key); i++){
      k = StringGetChar(key, i);
      h = h + k;
      h = bitRotate(h, 5); // rotate 5 bits
   }
   
   for (i=0; i<StringLen(key); i++){
      k = StringGetChar(key, i);
      h = h + k;
      // rotate depending on character value
      h = bitRotate(h, k & 0x0000000F);
   }
   
   // now we go backwards in our string
   for (i=StringLen(key); i>0; i--){   
      k = StringGetChar(key, i - 1);
      h = h + k;
      // rotate depending on the last 4 bits of h
      h = bitRotate(h, h & 0x0000000F); 
   }
   
   return(h & 0x7fffffff);
}

/**
* Rotate a 32 bit integer value bit-wise 
* the specified number of bits to the right.
* This function is needed for calculations
* in the hash function makeMacicNumber()
*/
int bitRotate(int value, int count){
   int i, tmp, mask;
   mask = (0x00000001 << count) - 1;
   tmp = value & mask;
   value = value >> count;
   value = value | (tmp << (32 - count));
   return(value);
}

/**
* place a market buy with stop loss, target, magic and Comment
* keeps trying in an infinite loop until the position is open.
*/
int buy(double lots, double sl, double tp, int magic=42, string comment=""){
   int ticket;
   if (!IS_ECN_BROKER){
      return(orderSendReliable(Symbol(), OP_BUY, lots, Ask, 100, sl, tp, comment, magic, 0, CLR_BUY_ARROW));
   }else{
      ticket = orderSendReliable(Symbol(), OP_BUY, lots, Ask, 100, 0, 0, comment, magic, 0, CLR_BUY_ARROW);
      if (sl + tp > 0){
         orderModifyReliable(ticket, 0, sl, tp, 0);
      }
      return(ticket);
   }
}

/**
* place a market sell with stop loss, target, magic and comment
* keeps trying in an infinite loop until the position is open.
*/
int sell(double lots, double sl, double tp, int magic=42, string comment=""){
   int ticket;
   if (!IS_ECN_BROKER){
      return(orderSendReliable(Symbol(), OP_SELL, lots, Bid, 100, sl, tp, comment, magic, 0, CLR_SELL_ARROW));
   }else{
      ticket = orderSendReliable(Symbol(), OP_SELL, lots, Bid, 100, 0, 0, comment, magic, 0, CLR_SELL_ARROW);
      if (sl + tp > 0){
         orderModifyReliable(ticket, 0, sl, tp, 0);
      }
      return(ticket);
   }
}

/**
* place a buy limit order
*/
int buyLimit(double lots, double price, double sl, double tp, int magic=42, string comment=""){
   return(orderSendReliable(Symbol(), OP_BUYLIMIT, lots, price, 1, sl, tp, comment, magic, 0, CLR_NONE));
}

/**
* place a sell limit order
*/
int sellLimit(double lots, double price, double sl, double tp, int magic=42, string comment=""){
   return(orderSendReliable(Symbol(), OP_SELLLIMIT, lots, price, 1, sl, tp, comment, magic, 0, CLR_NONE));
}

/**
* place a buy stop order
*/
int buyStop(double lots, double price, double sl, double tp, int magic=42, string comment=""){
   return(orderSendReliable(Symbol(), OP_BUYSTOP, lots, price, 1, sl, tp, comment, magic, 0, CLR_NONE));
}

/**
* place a sell stop order
*/
int sellStop(double lots, double price, double sl, double tp, int magic=42, string comment=""){
   return(orderSendReliable(Symbol(), OP_SELLSTOP, lots, price, 1, sl, tp, comment, magic, 0, CLR_NONE));
}


/**
* calculate unrealized P&L, belonging to all open trades with this magic number
*/
double getProfit(int magic){
   int cnt;
   double profit = 0;
   int total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderMagicNumber() == magic){
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   return (profit);
}

/**
* calculate realized P&L resulting from all closed trades with this magic number
*/
double getProfitRealized(int magic){
   int cnt;
   double profit = 0;
   int total=OrdersHistoryTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_HISTORY);
      if(OrderMagicNumber() == magic){
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }
   return (profit);
}

/**
* get the number of currently open trades of specified type
*/
int getNumOpenOrders(int type, int magic){
   int cnt;
   int num = 0;
   int total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if((magic == -1 || OrderMagicNumber() == magic) && (type == -1 || OrderType() == type)){
         num++;
      }
   }
   return (num);
}


/**
* trailTargets()
* will loop through all matching open positions and trail the target 
* towards price if the price moves AGAINST the trade direction (away 
* from the target). This may even trail the target into negative territory.
* 
* If trailtarget is 0 then nothing will be done, a positive number
* means the maximum distance between price and target.
* 
* If max_negative is set to -1 (default) the there is no limitation
* how far into negative territory the target can be trailed, if  
* max_negative is set to 0 then it will only trail down to break even
* and then stop at this point, if it is set to a positive number
* then it will use this number as a limit of how far into loss the
* target may be trailed.
*/
void trailTargets(double trailtarget, int magic, double max_negative=-1){
   int total, cnt, type;
   double op, tp, old_tp, dist;
   bool change;
   
   if (trailtarget != 0){
      total=OrdersTotal();
      for(cnt=0; cnt<total; cnt++){
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if(OrderMagicNumber() == magic){
            op = OrderOpenPrice();
            old_tp = OrderTakeProfit();
            type = OrderType();
            change = False;
            
            if (type == OP_BUY){
               tp = Bid + trailtarget;
               dist = tp - op;
               if (max_negative >= 0 && -dist > max_negative){
                  tp = op - max_negative;
               }
               if (tp < old_tp){
                  change = True;
               }
            }
            
            if (type == OP_SELL){
               tp = Ask - trailtarget;
               dist = op - tp;
               if (max_negative >= 0 && -dist > max_negative){
                  tp = op + max_negative;
               }
               if (tp > old_tp){
                  change = True;
               }
            }
            
            if (change){
               orderModifyReliable(
                  OrderTicket(),
                  op,
                  OrderStopLoss(),
                  tp,
                  OrderExpiration()
               );
            }
         }
      }
   }
}

/**
* trailStops()
* will loop through all matching open positions and trail their stops
*
* if trailstops is 0 then nothing will be done, a positive number is
* the maximum distance between price and stop, the distance at which
* the stop is trailed behind price.
*
* trailstop_slow is a factor that will increase trailing distance
* when the profit grows. default 1 is normal trailing stop behaviour
*/
void trailStops(double trailstop, int magic, double trailstop_slow=1){
   int total, cnt, type;
   double op, sl, old_sl;
   bool change;
   
   if (trailstop != 0){
      total=OrdersTotal();
      for(cnt=0; cnt<total; cnt++){
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if(OrderMagicNumber() == magic){
            op = OrderOpenPrice();
            old_sl = OrderStopLoss();
            type = OrderType();
            change = False;
            
            if (type == OP_BUY){
               sl = op + (Bid - trailstop - op) / trailstop_slow;
               if (sl > op && sl > old_sl){
                  change = True;
               }
            }
            
            if (type == OP_SELL){
               sl = op - (op - Ask - trailstop) / trailstop_slow;
               if (sl < op && (sl < old_sl || old_sl == 0)){
                  change = True;
               }
            }
            
            if (change){
               orderModifyReliable(
                  OrderTicket(),
                  op,
                  sl,
                  OrderTakeProfit(),
                  OrderExpiration()
               );
            }
         }
      }
   }
}

void lockProfit(double min_profit, int magic, double distance=0){
   int total, cnt, type;
   double op, sl, old_sl;
   bool change;
   
   total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderMagicNumber() == magic){
         old_sl = OrderStopLoss();
         op = OrderOpenPrice();
         type = OrderType();
         change = False;
         
         if (type==OP_BUY){
            sl = op + min_profit;
            if (Bid > sl + distance && sl > old_sl){
                  change = True;
            }
         }
         
         if (type==OP_SELL){
            sl = op - min_profit;
            if (Ask < sl - distance && (sl < old_sl || old_sl == 0)){
                  change = True;
            }
         }
         
         if (change){
            orderModifyReliable(
               OrderTicket(),
               op,
               sl,
               OrderTakeProfit(),
               OrderExpiration()
            );
         }
      }
   }   
}

bool isOrder(int type, double price, int magic){
   int cnt, num;
   int total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderMagicNumber() == magic && (type == -1 || OrderType() == type)){
         if(isEqualPrice(OrderOpenPrice(), price)){
            num++;
         }
      }
   }
   return (num > 0);
}

/** 
* will close all open orders or positions of specified type with our magic number
* this function won't return until all positions are closed
* type = -1 means all types, magic = -1 means all magic numbers
*/
void closeOpenOrders(int type, int magic){
   int total, cnt;
   double price;
   color clr;
   int order_type;
   
   Print ("closeOpenOrders(" + type + "," + magic + ")");
   
   while (getNumOpenOrders(type, magic) > 0){
      while (IsTradeContextBusy()){
         Print("closeOpenOrders(): waiting for trade context.");
         Sleep(MathRand()/10);
      }
      total=OrdersTotal();
      RefreshRates();
      if (type == OP_BUY){
         price = Bid;
         clr = CLR_SELL_ARROW;
      }else{
         price = Ask;
         clr = CLR_BUY_ARROW;
      }
      for(cnt=0; cnt<total; cnt++){
         OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
         if((type == -1 || OrderType() == type) && (magic == -1 || OrderMagicNumber() == magic)){
            if(IsTradeContextBusy()){
               break; // something else is trading too, back to the while loop.
            }
            order_type = OrderType();
            if (order_type == OP_BUYSTOP || order_type == OP_SELLSTOP || order_type == OP_BUYLIMIT || order_type == OP_SELLLIMIT){
               orderDeleteReliable(OrderTicket());
            }else{
               orderCloseReliable(OrderTicket(), OrderLots(), price, 999, clr);
            }
            break; // restart the loop from 0 (hello FIFO!)
         } 
      }
   }
}

/**
* scale out of a position the specified amounts of lots and return
* the number of lots that could *not* be cloed. (that need now to 
* be opened into the other direction)
*
* This function will try to close out the needed lots out of any
* combination of open orders, using partial closes or complete closes
* until there is nothing left to close or the needed lot size has been
* closed. It will start closing the oldest orders first (FIFO)
*
* This function is not yet fully tested and debugged. It may change
* in future releases, it may not work at all. Dont use it (yet)!
*/
double reducePosition(int type, double lots, int magic){
   int i;
   double price;
   int clr;
   bool loop_again = true;
   
   Print("reducePosition()");
   
   while(loop_again){
      RefreshRates();
      if (type == OP_BUY){
         price = Bid;
         clr = CLR_SELL_ARROW;
      }
      if (type == OP_SELL){
         price = Ask;
         clr = CLR_BUY_ARROW;
      }
      int total_orders = OrdersTotal();
      loop_again = false;
      for (i=0; i<total_orders; i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if (OrderMagicNumber() == magic){
            if (OrderType() == type){
               if (NormalizeDouble (OrderLots() - lots, 2) >= 0){
                  // found big enough order to do it in one step
                  Print("reducePosition(): now trying to close order");
                  if(orderCloseReliable(OrderTicket(), lots, price, 100, clr) == true){
                     Print("reducePosition(): success!");
                     return(0);
                  }else{
                     Print("reducePosition(): order found but failed to close: " + GetLastError());
                     // permanent error occured
                     return(lots);
                  }
               }else{
                  // order is smaller. close it comppetely
                  if(orderCloseReliable(OrderTicket(), OrderLots(), price, 100, clr) == true){
                     lots -= OrderLots();
                     Print("reducePosition(): closed " + OrderLots() + " remaining: " + lots);
                     loop_again = True; 
                     break; // number of orders has now changed, restart the for loop
                  }else{
                     Print("reducePosition(): order found but failed to close: " + GetLastError());
                     // permanent error occured
                     return(lots);
                  }
               }
            
               // are we already done?
               if(NormalizeDouble(lots, 2) == 0){
                  return(0);
               }  
            }
         }
      }//for (all orders)
      
      // whenever the for loop has completed
      // loop_again would indicate that an order has been closed
      // and we need to start the for loop again from 0
   
   }// while (loop_again)
   Print("reducePosition(): nothing more to close. " + lots + " could not be closed");
   return(lots);
}

void moveStop(int type, int magic, double stoploss=-1){
   int total, cnt;
   total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderType()==type && OrderMagicNumber() == magic){
         if (stoploss == -1){
            stoploss = OrderOpenPrice();
         }
         if (!isEqualPrice(stoploss, OrderStopLoss())){
            orderModifyReliable(
               OrderTicket(),
               OrderOpenPrice(),
               stoploss,
               OrderTakeProfit(),
               OrderExpiration()
            );
         }
      } 
   }
}

void moveOrder(int type, int magic, double price){
   int total, cnt;
   double d, sl, tp;
   total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderType()==type && OrderMagicNumber() == magic){
         if(!isEqualPrice(d, OrderOpenPrice())){
            d = price - OrderOpenPrice();
            if (OrderStopLoss() == 0){
               sl = 0;
            }else{
               sl = OrderStopLoss() + d;
            }
            if (OrderTakeProfit() == 0){
               tp = 0;
            }else{
               tp = OrderTakeProfit() + d;
            }
            orderModifyReliable(
               OrderTicket(),
               price,
               sl,
               tp,
               OrderExpiration()
            );
         }
      }
   }
}

void moveTarget(int type, int magic, double target){
   int total, cnt;
   total=OrdersTotal();
   for(cnt=0; cnt<total; cnt++){
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderType()==type && OrderMagicNumber() == magic){
         if (!isEqualPrice(target, OrderTakeProfit())){
            orderModifyReliable(
               OrderTicket(),
               OrderOpenPrice(),
               OrderStopLoss(),
               target,
               OrderExpiration()
            );
         }
      } 
   }
}

double getLotsOnTable(int magic){
   double total_lots = 0;
   int i;
   int total_orders = OrdersTotal();
   for (i=0; i<total_orders; i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber() == magic){
         if(OrderType() == OP_BUY){
            total_lots += OrderLots();
         }
         if(OrderType() == OP_SELL){
            total_lots -= OrderLots();
         }
      }
   }
   total_lots = MathAbs(total_lots);
   return(total_lots);
}

double getLotsOnTableSigned(int magic){
   double total_lots = 0;
   int i;
   int total_orders = OrdersTotal();
   for (i=0; i<total_orders; i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber() == magic){
         if(OrderType() == OP_BUY){
            total_lots += OrderLots();
         }
         if(OrderType() == OP_SELL){
            total_lots -= OrderLots();
         }
      }
   }
   return(total_lots);
}

double getAveragePositionPrice(int magic){
   double total_lots = getLotsOnTable(magic);
   double average_price = 0;
   int i;
   int total_orders = OrdersTotal();
   for (i=0; i<total_orders; i++){
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if (OrderMagicNumber() == magic){
         average_price += OrderOpenPrice()*OrderLots()/total_lots;
      }
   }
   return(average_price);
}

double getLastProfit(int magic){
   selectLastClosedTrade(magic);
   return(OrderProfit());
}

void selectLastClosedTrade(int magic){
   int total, cnt, type;
   total=OrdersHistoryTotal();
   for(cnt=total-1; cnt>=0; cnt--){
      OrderSelect(cnt, SELECT_BY_POS, MODE_HISTORY);
      type = OrderType();
      if(OrderMagicNumber() == magic && (type == OP_BUY || type == OP_SELL)){
         return(0);
      }
   }
}

/**
* plot the opening trade arrow
* This is part of a re-implementation of what metatrader does when dragging
* a trade from the history to the chart. Metatrader won't do this automatically
* for manual trading and for pending order fills so we have to do it ourselves.
* See also plotNewOpenTrades() and plotNewClosedTrades() defined below.
*/
void plotOpenedTradeArrow(int ticket){
   string name;
   color clr;
   if (IsOptimization()){
      return(0);
   }
   OrderSelect(ticket, SELECT_BY_TICKET);
   name = "#" + ticket + " ";
   if (OrderType() == OP_BUY){
      name = name + "buy ";
      clr = CLR_BUY_ARROW;
   }
   if (OrderType() == OP_SELL){
      name = name + "sell ";
      clr = CLR_SELL_ARROW;
   }
   name = name + DoubleToStr(OrderLots(), 2) + " ";
   name = name + OrderSymbol() + " ";
   name = name + "at " + DoubleToStr(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));
   ObjectCreate(name, OBJ_ARROW, 0, OrderOpenTime(), OrderOpenPrice());
   ObjectSet(name, OBJPROP_ARROWCODE, 1);
   ObjectSet(name, OBJPROP_COLOR, clr);
}

/**
* plot the closing trade arrow (needed for filled stoplosses and takeprofits)
* This is part of a re-implementation of what metatrader does when dragging
* a trade from the history to the chart. Metatrader won't do this automatically
* for manual trading and for pending order fills so we have to do it ourselves.
* See also plotNewOpenTrades() and plotNewClosedTrades() defined below.
*/
void plotClosedTradeArrow(int ticket){
   string name;
   color clr;
   if (IsOptimization()){
      return(0);
   }
   OrderSelect(ticket, SELECT_BY_TICKET);
   name = "#" + ticket + " ";
   if (OrderType() == OP_BUY){
      name = name + "buy ";
      clr = CLR_SELL_ARROW; // closing a buy is a sell, so make it red
   }
   if (OrderType() == OP_SELL){
      name = name + "sell ";
      clr = CLR_BUY_ARROW; // closing a sell is a buy, so make it blue
   }
   name = name + DoubleToStr(OrderLots(), 2) + " ";
   name = name + OrderSymbol() + " ";
   name = name + "at " + DoubleToStr(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS)) + " ";
   name = name + "close at " + DoubleToStr(OrderClosePrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));
   ObjectCreate(name, OBJ_ARROW, 0, OrderCloseTime(), OrderClosePrice());
   ObjectSet(name, OBJPROP_ARROWCODE, 3);
   ObjectSet(name, OBJPROP_COLOR, clr);
}

/**
* plot the line connecting open and close of a history trade
* This is part of a re-implementation of what metatrader does when dragging
* a trade from the history to the chart. Metatrader won't do this automatically
* for manual trading and for pending order fills so we have to do it ourselves.
* See also plotNewOpenTrades() and plotNewClosedTrades() defined below.
*/
void plotClosedTradeLine(int ticket){
   string name;
   color clr;
   if (IsOptimization()){
      return(0);
   }
   OrderSelect(ticket, SELECT_BY_TICKET);
   name = "#" + ticket + " ";
   if (OrderType() == OP_BUY){
      clr = CLR_BUY_ARROW;
   }
   if (OrderType() == OP_SELL){
      clr = CLR_SELL_ARROW;
   }
   name = name + DoubleToStr(OrderOpenPrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));
   name = name + " -> ";
   name = name + DoubleToStr(OrderClosePrice(), MarketInfo(OrderSymbol(), MODE_DIGITS));
   ObjectCreate(name, OBJ_TREND, 0, OrderOpenTime(), OrderOpenPrice(), OrderCloseTime(), OrderClosePrice());
   ObjectSet(name, OBJPROP_RAY, false);
   ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSet(name, OBJPROP_COLOR, clr);
}

/**
* check if the open trade list has changed and plot
* arrows for opened trades into the chart.
* Metatrader won't do this automatically for manual trading.
* Use this function for scanning for new trades and plotting them.
*/ 
void plotNewOpenTrades(int magic=-1){
   //static int last_ticket=0;
   int total, i;
   if (IsOptimization()){
      return(0);
   }
   
   total = OrdersTotal();
   //OrderSelect(total - 1, SELECT_BY_POS, MODE_TRADES);
   //if (OrderTicket() != last_ticket){
   //   last_ticket = OrderTicket();
      
      // FIXME! find something to detect changes as cheap as possible!
      
      // order list has changed, so plot all arrows
      for (i=0; i<total; i++){
         OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
         if((magic == -1 || OrderMagicNumber() == magic) && OrderSymbol() == Symbol()){
            if (OrderType() == OP_BUY || OrderType() == OP_SELL){
               plotOpenedTradeArrow(OrderTicket());
            }
         }
      }
   //}
}

/**
* check for changes in the trading history and plot the
* trades into the chart with arrows and lines connectimg them.
* Metatrader won't do this automatically for manual trading.
* Use this function for scanning for closed trades and plotting them.
*/
void plotNewClosedTrades(int magic=-1){
   static int last_ticket=0;
   int total, i;
   if (IsOptimization()){
      return(0);
   }
   
   total = OrdersHistoryTotal();
   OrderSelect(total - 1, SELECT_BY_POS, MODE_HISTORY);
   if (OrderTicket() != last_ticket){
      last_ticket = OrderTicket();
      
      // order list has changed, so plot all arrows
      for (i=0; i<total; i++){
         OrderSelect(i, SELECT_BY_POS, MODE_HISTORY);
         if((magic == -1 || OrderMagicNumber() == magic) && OrderSymbol() == Symbol()){
            if (OrderType() == OP_BUY || OrderType() == OP_SELL){
               plotOpenedTradeArrow(OrderTicket());
               plotClosedTradeArrow(OrderTicket());
               plotClosedTradeLine(OrderTicket());
            }
         }
      }
   }
}

/**
* create a line
*/
string line(string name, datetime t1, double p1, datetime t2, double p2, color clr=Red, string label="", bool ray=False){
   if (!IsOptimization()){
      if (name==""){
         name = "line_" + Time[0];
      }
      if (ObjectFind(name)==-1){
         ObjectCreate(name, OBJ_TREND,0,t1,p1,t2,p2);
      }
      ObjectSet(name, OBJPROP_RAY, ray);
      ObjectSet(name, OBJPROP_COLOR, clr);
      ObjectSet(name, OBJPROP_TIME1, t1);
      ObjectSet(name, OBJPROP_TIME2, t2);
      ObjectSet(name, OBJPROP_PRICE1, p1);
      ObjectSet(name, OBJPROP_PRICE2, p2);
      ObjectSetText(name, label);
   }
   return(name);
}

/**
* create a horizontal line
*/
string horizLine(string name, double price, color clr=Red, string label=""){
   if (!IsOptimization()){
      if (name==""){
         name = "line_" + Time[0];
      }
      if (ObjectFind(name)==-1){
         ObjectCreate(name, OBJ_HLINE, 0, 0, price);
      }else{
         ObjectSet(name, OBJPROP_PRICE1, price);
      }
      ObjectSet(name, OBJPROP_COLOR, clr);
      ObjectSetText(name, label);
   }
   return(name);
}

/**
* create a vertical line
*/
string vertLine(string name, datetime time, color clr=Red, string label=""){
   if (!IsOptimization()){
      if (name==""){
         name = "line_" + Time[0];
      }
      if (ObjectFind(name)==-1){
         ObjectCreate(name, OBJ_VLINE, 0, time, 0);
      }else{
         ObjectSet(name, OBJPROP_TIME1, time);
      }
      ObjectSet(name, OBJPROP_COLOR, clr);
      ObjectSetText(name, label);
   }
   return(name);
}

/**
* create a text object
*/
string text(string name, string text, datetime time=0, double price=0, color clr=Red, int size=8){
   if (time == 0){
      time = Time[0];
   }
   if (price == 0){
      price = Close[iBarShift(NULL, 0, time)];
   }
   if (name == ""){
      name = "text_" + time;
   }
   if (ObjectFind(name)==-1){
      ObjectCreate(name, OBJ_TEXT, 0, time, price);
   }
   ObjectSet(name, OBJPROP_TIME1, time);
   ObjectSet(name, OBJPROP_PRICE1, price);
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_FONTSIZE, size);
   ObjectSetText(name, text);
   return(name);
}

/**
* create a text label
*/
string label(string name, int x, int y, int corner, string text, color clr=Gray){
   if (!IsOptimization()){
      if (name==""){
         name = "label_" + Time[0];
      }   
      if (ObjectFind(name) == -1){
         ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
      }
      ObjectSet(name, OBJPROP_COLOR, clr);
      ObjectSet(name, OBJPROP_CORNER, corner);
      ObjectSet(name, OBJPROP_XDISTANCE, x);
      ObjectSet(name, OBJPROP_YDISTANCE, y);   
      ObjectSetText(name, text);
   }
   return(name);
}

/**
* emulate a button with a label that must be moved by the user.
* return true if the label has been moved and move it back.
* create it if it does not already exist.
*/
bool labelButton(string name, int x, int y, int corner, string text, color clr=Gray){
   if (IsOptimization()){
      return(false);
   }
   if (ObjectFind(name) != -1){
      if (ObjectGet(name, OBJPROP_XDISTANCE) != x || ObjectGet(name, OBJPROP_YDISTANCE) != y){
         ObjectDelete(name);
         return(true);
      }
   }
   label(name, x, y, corner, "[" + text + "]", clr);
   return(false);
}

/**
* return true if price (Bid) just has crossed a line with this comment string.
* if the parameter one_shot is true (default) it will add the word 
* "triggered" to the line so it can't be triggered a second time.
*/
bool crossedLine(string comment, bool one_shot=true, color clr_active=CLR_NONE, color clr_triggered=CLR_NONE){
   double last_bid; // see below!
   int i;
   double price;
   string name;
   int type;
   
   
   if (clr_active == CLR_NONE){
      clr_active = CLR_CROSSLINE_ACTIVE;
   }
   if (clr_triggered == CLR_NONE){
      clr_triggered = CLR_CROSSLINE_TRIGGERED;
   }
      
   for (i=0; i<ObjectsTotal(); i++){
      name = ObjectName(i);
      
      // is this an object without description (newly created by the user)?
      if (ObjectDescription(name) == ""){
         // Sometimes the user draws a new line and the default color is
         // accidentially the color and style of an active line. If we
         // simply reset all lines without decription but with the active
         // color and style we can almost completely eliminate this problem. 
         // The color does not influence the functionality in any way but 
         // we simply don't WANT to confuse the USER with lines that have 
         // the active color and style that are not active lines.
         if (ObjectGet(name, OBJPROP_COLOR) == clr_active && ObjectGet(name, OBJPROP_STYLE) == STYLE_DASH){
            ObjectSet(name, OBJPROP_COLOR, clr_triggered);
            ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
         }
      }
      
      // is this an object that matches our description field?  
      if (ObjectDescription(name) == comment){
         price = 0;
         type = ObjectType(name);
         
         // we only care about certain types of objects
         if (type == OBJ_HLINE){
            price = ObjectGet(name, OBJPROP_PRICE1);
         }
         if (type == OBJ_TREND){
            price = ObjectGetValueByShift(name, 0);
         }
         
         if (price > 0){ // we found a line
         
            // ATTENTION! DIRTY HACK! MAY BREAK IN FUTURE VERSIONS OF MT4
            // ==========================================================
            // We store the last bid price in the unused PRICE3 field
            // of every line, so we can call this function more than once
            // per tick for multiple lines. A static variable would not work here
            // since we could not call the functon a second time during the same tick
            last_bid = ObjectGet(name, OBJPROP_PRICE3);
         
            // visually mark the line as an active line
            ObjectSet(name, OBJPROP_COLOR, clr_active);
            ObjectSet(name, OBJPROP_STYLE, STYLE_DASH);
            
            // we have a last_bid value for this line
            if (last_bid > 0){
               
               // did price cross this line since the last time we checked this line?
               if ((Close[0] >= price && last_bid <= price) || (Close[0] <= price && last_bid >= price)){
                  if (one_shot){
                     ObjectSetText(name, comment + " triggered");
                     ObjectSet(name, OBJPROP_COLOR, clr_triggered);
                     ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSet(name, OBJPROP_PRICE3, 0);
                  }else{
                     ObjectSet(name, OBJPROP_PRICE3, Close[0]);
                  }
                  return(true);
               }
            }
            
            // store current price in the line itself
            ObjectSet(name, OBJPROP_PRICE3, Close[0]);
         }
      }
      
   }
   
   return(false);
}


/**
* orderModifyReliable() improved OrderModify()
*/
bool orderModifyReliable(
   int ticket,
   double price,
   double stoploss,
   double takeprofit,
   datetime expiration,
   color arrow_color=CLR_NONE
){
   bool success;
   int err;
   Print("OrderModifyReliable(" + ticket + "," + price + "," + stoploss + "," + takeprofit + "," + expiration + "," + arrow_color + ")");
   while (True){
      while (IsTradeContextBusy()){
         Print("OrderModifyReliable(): Waiting for trade context.");
         Sleep(MathRand()/10);
      }
      success = OrderModify(
          ticket,
          NormalizeDouble(price, Digits),
          NormalizeDouble(stoploss, Digits),
          NormalizeDouble(takeprofit, Digits),
          expiration,
          arrow_color);
      
      if (success){
         Print("OrderModifyReliable(): Success!");
         return(True);
      }
      
      err = GetLastError();
      if (isTemporaryError(err)){
         Print("orderModifyReliable(): Temporary Error: " + err + " " + ErrorDescription(err) + ". waiting.");
      }else{
         Print("orderModifyReliable(): Permanent Error: " + err + " " + ErrorDescription(err) + ". giving up.");
         return(false);
      }
      Sleep(MathRand()/10);
   }
}

int orderSendReliable(
   string symbol, 
   int cmd, 
   double volume, 
   double price, 
   int slippage, 
   double stoploss,
   double takeprofit,
   string comment="",
   int magic=0,
   datetime expiration=0,
   color arrow_color=CLR_NONE
){
   int ticket;
   int err;
   Print("orderSendReliable(" 
      + symbol + "," 
      + cmd + "," 
      + volume + "," 
      + price + "," 
      + slippage + "," 
      + stoploss + ","
      + takeprofit + ","
      + comment + ","
      + magic + ","
      + expiration + ","
      + arrow_color + ")");
      
   while(true){
      if (IsStopped()){
         Print("orderSendReliable(): Trading is stopped!");
         return(-1);
      }
      RefreshRates();
      if (cmd == OP_BUY){
         price = Ask;
      }
      if (cmd == OP_SELL){
         price = Bid;
      }
      if (!IsTradeContextBusy()){
         ticket = OrderSend(
            symbol,
            cmd,
            volume,
            NormalizeDouble(price, MarketInfo(symbol, MODE_DIGITS)), 
            slippage,
            NormalizeDouble(stoploss, MarketInfo(symbol, MODE_DIGITS)),
            NormalizeDouble(takeprofit, MarketInfo(symbol, MODE_DIGITS)),
            comment,
            magic,
            expiration,
            arrow_color
         );
         if (ticket > 0){
            Print("orderSendReliable(): Success! Ticket: " + ticket);
            return(ticket); // the normal exit
         }
      
         err = GetLastError();
         if (isTemporaryError(err)){
            Print("orderSendReliable(): Temporary Error: " + err + " " + ErrorDescription(err) + ". waiting.");
         }else{
            Print("orderSendReliable(): Permanent Error: " + err + " " + ErrorDescription(err) + ". giving up.");
            return(-1);
         }
      }else{
         Print("orderSendReliable(): Must wait for trade context");
      }
      Sleep(MathRand()/10);
   }
}

bool orderCloseReliable(
   int ticket, 
   double lots, 
   double price, 
   int slippage, 
   color arrow_color=CLR_NONE
){
   bool success;
   int err;
   Print("orderCloseReliable()");
   OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES);
   while(true){
      if (IsStopped()){
         Print("orderCloseReliable(): Trading is stopped!");
         return(false);
      }
      RefreshRates();
      if (OrderType() == OP_BUY){
         price = Bid; // close long at bid
      }
      if (OrderType() == OP_SELL){
         price = Ask; // close short at ask
      }
      if (!IsTradeContextBusy()){
         success = OrderClose(
            ticket,
            lots,
            NormalizeDouble(price, MarketInfo(OrderSymbol(), MODE_DIGITS)),
            slippage,
            arrow_color
         );
         if (success){
            Print("orderCloseReliable(): Success!");
            return(true); // the normal exit
         }
      
         err = GetLastError();
         if (isTemporaryError(err)){
            Print("orderCloseReliable(): Temporary Error: " + err + " " + ErrorDescription(err) + ". waiting.");
         }else{
            Print("orderCloseReliable(): Permanent Error: " + err + " " + ErrorDescription(err) + ". giving up.");
            return(false);
         }
      }else{
         Print("orderCloseReliable(): Must wait for trade context");
      }
      Sleep(MathRand()/10);
   }
}

bool orderDeleteReliable(int ticket){
   bool success;
   int err;
   Print("orderDeleteReliable(" + ticket + ")");
   while(true){
      while (IsTradeContextBusy()){
         Print("OrderDeleteReliable(): Waiting for trade context.");
         Sleep(MathRand()/10);
      }
      
      success = OrderDelete(ticket);
      
      if (success){
         Print("orderDeleteReliable(): success.");
         return(true);
      }
      
      err = GetLastError();
      if (isTemporaryError(err)){
         Print("orderDeleteReliable(): Temporary Error: " + err + " " + ErrorDescription(err) + ". waiting.");
      }else{
         Print("orderDeleteReliable(): Permanent Error: " + err + " " + ErrorDescription(err) + ". giving up.");
         return(false);
      }
      Sleep(MathRand()/10);
   }
}

bool isEqualPrice(double a, double b){
   return(NormalizeDouble(a, Digits) == NormalizeDouble(b, Digits));
}

bool isTemporaryError(int error){
   return(
      error == ERR_NO_ERROR ||
      error == ERR_COMMON_ERROR ||
      error == ERR_SERVER_BUSY ||
      error == ERR_NO_CONNECTION ||
      error == ERR_MARKET_CLOSED ||
      error == ERR_PRICE_CHANGED ||
      error == ERR_INVALID_PRICE ||  //happens sometimes
      error == ERR_OFF_QUOTES ||
      error == ERR_BROKER_BUSY ||
      error == ERR_REQUOTE ||
      error == ERR_TRADE_TIMEOUT ||
      error == ERR_TRADE_CONTEXT_BUSY
    );
}


/**
* return only the first 6 letters of Symbol()
* Some Brokers add their initials at the end
* of their symbol names and some of my EAs and
* indicators want a 6-character symbol name.
*/
string Symbol6(){
   return(StringSubstr(Symbol(), 0, 6));
}

/**
* determine the pip multiplier (1 or 10) depending on how many
* digits the EURUSD symbol has. This is done by first
* finding the exact name of this symbol in the symbols.raw
* file (it could be EURUSDm or EURUSDiam or any other stupid name
* the broker comes up with only to break other people's code) 
* and then usig MarketInfo() for determining the digits.
*/
double pointsPerPip(){
   int i;
   int digits;
   double ppp = 1;
   string symbol;
   int f = FileOpenHistory("symbols.raw", FILE_BIN | FILE_READ);
   int count = FileSize(f) / 1936;
   for (i=0; i<count; i++){ 
      symbol = FileReadString(f, 12);
      if (StringFind(symbol, "EURUSD") != -1){
         digits = MarketInfo(symbol, MODE_DIGITS);
         if (digits == 4){
            ppp = 1;
         }else{
            ppp = 10;
         }
         break;
      }
      FileSeek(f, 1924, SEEK_CUR);
   }
   FileClose(f);
   return (ppp);
}

