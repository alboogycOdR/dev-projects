//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2010, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#define timeout 10           // chart refresh timeout
#define Picture1_width 800   // max width of balance chart in report
#define Picture2_width 800   // width of price chart in report
#define Picture2_height 600  // height of price chart in report
#define Axis_Width 59        // width of vertical axis (in pixels)
#property script_show_inputs // request input parameters
//+------------------------------------------------------------------+
// report periods enumeration
//+------------------------------------------------------------------+
enum report_periods
  {
   All_periods,
   Last_day,
   Last_week,
   Last_month,
   Last_year
  };
// ask for report period
input report_periods ReportPeriod=0;

//+------------------------------------------------------------------+
//|  Start() function                                                 |
//+------------------------------------------------------------------+
void OnStart()
  {
   datetime StartTime=0;             // beginning of report period
   datetime EndTime=TimeCurrent();   // end of report period

                                     // calculating the beginning of report period
   switch(ReportPeriod)
     {
      case 1:
         StartTime=EndTime-86400;    // day
         break;
      case 2:
         StartTime=EndTime-604800;   // week
         break;
      case 3:
         StartTime=EndTime-2592000;  // month
         break;
      case 4:
         StartTime=EndTime-31536000; // year
         break;
     }
// if none of the options is executed, then StartTime=0 (entire period)

   int total_deals_number;  // number of deals for history data
   int file_handle;         // file handle
   int i,j;                 // loop counters 
   int symb_total;          // number of instruments, that were traded
   int symb_pointer;        // pointer to current instrument
   char deal_status[];      // state of deal (processed/not processed)
   ulong ticket;            // ticket of deal
   long hChart;             // chart id

   double balance;           // current balance value
   double balance_prev;      // previous balance value
   double lot_current;       // volume of current deal
   double lots_list[];       // list of open volumes by instruments
   double current_swap;      // swap of current deal
   double current_profit;    // profit of current deal
   double max_val,min_val;   // maximal and minimal value

   string symb_list[];       // list of instruments, that were traded
   string in_table_volume;   // volume of entering position
   string in_table_time;     // time of entering position
   string in_table_price;    // price of entering position
   string out_table_volume;  // volume of exiting position
   string out_table_time;    // time of exiting position
   string out_table_price;   // price of exiting position
   string out_table_swap;    // swap of exiting position
   string out_table_profit;  // profit of exiting position

   bool symb_flag;           // flag that instrument is in the list

   datetime time_prev;           // previous value of time 
   datetime time_curr;           // current value of time
   datetime position_StartTime;  // time of first enter to position
   datetime position_EndTime;    // time of last exit from position

   ENUM_TIMEFRAMES Picture1_period;  // period of balance chart

                                     // open a new chart and set its properties
   hChart=ChartOpen(Symbol(),0);
   ChartSetInteger(hChart,CHART_MODE,CHART_BARS);            // bars chart
   ChartSetInteger(hChart,CHART_AUTOSCROLL,true);            // autoscroll enabled
   ChartSetInteger(hChart,CHART_COLOR_BACKGROUND,White);     // white background
   ChartSetInteger(hChart,CHART_COLOR_FOREGROUND,Black);     // axes and labels are black
   ChartSetInteger(hChart,CHART_SHOW_OHLC,false);            // OHLC are not shown
   ChartSetInteger(hChart,CHART_SHOW_BID_LINE,true);         // show BID line
   ChartSetInteger(hChart,CHART_SHOW_ASK_LINE,false);        // hide ASK line
   ChartSetInteger(hChart,CHART_SHOW_LAST_LINE,false);       // hide LAST line
   ChartSetInteger(hChart,CHART_SHOW_GRID,true);             // show grid
   ChartSetInteger(hChart,CHART_SHOW_PERIOD_SEP,true);       // show period separators
   ChartSetInteger(hChart,CHART_COLOR_GRID,LightGray);       // grid is light-gray
   ChartSetInteger(hChart,CHART_COLOR_CHART_LINE,Black);     // chart lines are black
   ChartSetInteger(hChart,CHART_COLOR_CHART_UP,Black);       // up bars are black
   ChartSetInteger(hChart,CHART_COLOR_CHART_DOWN,Black);     // down bars are black
   ChartSetInteger(hChart,CHART_COLOR_BID,Gray);             // BID line is gray
   ChartSetInteger(hChart,CHART_COLOR_VOLUME,Green);         // volumes and orders levels are green
   ChartSetInteger(hChart,CHART_COLOR_STOP_LEVEL,Red);       // SL and TP levels are red
   ChartSetString(hChart,CHART_COMMENT,ChartSymbol(hChart)); // comment contains instrument
   ChartScreenShot(hChart,"picture2.gif",Picture2_width,Picture2_height); // save chart as image file

// request deals history for entire period
   HistorySelect(0,TimeCurrent());

// open report file
   file_handle=FileOpen("report.html",FILE_WRITE|FILE_ANSI);

// write the beginning of HTML
   FileWrite(file_handle,"<html>"+
                           "<head>"+
                              "<title>Expert Trade Report</title>"+
                           "</head>"+
                              "<body bgcolor='#EFEFEF'>"+
                              "<center>"+
                              "<h2>Trade Report</h2>"+
                              "<table align='center' border='1' bgcolor='#FFFFFF' bordercolor='#7F7FFF' cellspacing='0' cellpadding='0'>"+
                                 "<tr>"+
                                    "<th rowspan=2>SYMBOL</th>"+
                                    "<th rowspan=2>Direction</th>"+
                                    "<th colspan=3>Open</th>"+
                                    "<th colspan=3>Close</th>"+
                                    "<th rowspan=2>Swap</th>"+
                                    "<th rowspan=2>Profit</th>"+
                                 "</tr>"+
                                 "<tr>"+
                                    "<th>Volume</th>"+
                                    "<th>Time</th>"+
                                    "<th>Price</th>"+
                                    "<th>Volume</th>"+
                                    "<th>Time</th>"+
                                    "<th>Price</th>"+
                                 "</tr>");

// number of deals in history
   total_deals_number=HistoryDealsTotal();

// setting dimensions for the instruments list, the volumes list and the deals state arrays
   ArrayResize(symb_list,total_deals_number);
   ArrayResize(lots_list,total_deals_number);
   ArrayResize(deal_status,total_deals_number);

// setting all elements of array with value 0 - deals are not processed
   ArrayInitialize(deal_status,0);

   balance=0;       // initial balance
   balance_prev=0;  // previous balance
   symb_total=0;    // number of instruments in the list

                    // processing all deals in history
   for(i=0;i<total_deals_number;i++)
     {
      // select deal, get ticket
      ticket=HistoryDealGetTicket(i);
      // changing balance
      balance+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
      // reading the time of deal
      time_curr=HistoryDealGetInteger(ticket,DEAL_TIME);
      // if this is not the first deal
      if(i==0)
        {
         // if the report period starts before the first deal,
         // then the report period will start from the first deal
         if(StartTime<time_curr) StartTime=time_curr;
         // if report period ends before the current time,
         // then the end of report period corresponds to the current time
         if(EndTime>TimeCurrent()) EndTime=TimeCurrent();
         // initial values of maximal and minimal balances
         // are equal to the current balance
         max_val=balance;
         min_val=balance;
         // calculating the period of balance chart depending on the duration of 
         // report period
         Picture1_period=PERIOD_M1;
         if(EndTime-StartTime>(Picture1_width-Axis_Width))        Picture1_period=PERIOD_M2;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*120)    Picture1_period=PERIOD_M3;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*180)    Picture1_period=PERIOD_M4;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*240)    Picture1_period=PERIOD_M5;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*300)    Picture1_period=PERIOD_M6;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*360)    Picture1_period=PERIOD_M10;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*600)    Picture1_period=PERIOD_M12;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*720)    Picture1_period=PERIOD_M15;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*900)    Picture1_period=PERIOD_M20;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*1200)   Picture1_period=PERIOD_M30;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*1800)   Picture1_period=PERIOD_H1;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*3600)   Picture1_period=PERIOD_H2;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*7200)   Picture1_period=PERIOD_H3;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*10800)  Picture1_period=PERIOD_H4;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*14400)  Picture1_period=PERIOD_H6;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*21600)  Picture1_period=PERIOD_H8;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*28800)  Picture1_period=PERIOD_H12;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*43200)  Picture1_period=PERIOD_D1;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*86400)  Picture1_period=PERIOD_W1;
         if(EndTime-StartTime>(Picture1_width-Axis_Width)*604800) Picture1_period=PERIOD_MN1;
         // changing the period of opened chart
         ChartSetSymbolPeriod(hChart,Symbol(),Picture1_period);
        }
      else
      // if this is not the first deal
        {
         // plotting the balance line, if the deal is in the report period,
         // and setting properties of the balance line
         if(time_curr>=StartTime && time_prev<=EndTime)
           {
            ObjectCreate(hChart,IntegerToString(i),OBJ_TREND,0,time_prev,balance_prev,time_curr,balance);
            ObjectSetInteger(hChart,IntegerToString(i),OBJPROP_COLOR,Green);
            // if both ends of line are in the report period,
            // it will be "thick"
            if(time_prev>=StartTime && time_curr<=EndTime) ObjectSetInteger(hChart,IntegerToString(i),OBJPROP_WIDTH,2);
           }
         // if new value of balance exceeds the range
         // of minimal and maximal values, it must be adjusted
         if(balance<min_val) min_val=balance;
         if(balance>max_val) max_val=balance;
        }
      // changing the previous time value
      time_prev=time_curr;

      // if the deal has not been processed yet
      if(deal_status[i]<127)
        {
         // if this deal is balance charge
         if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BALANCE)
           {
            // if it's in the report period - write the corresponding string to report.
            if(time_curr>=StartTime && time_curr<=EndTime) 
            FileWrite(file_handle,"<tr><td colspan='9'>Balance:</td><td align='right'>",HistoryDealGetDouble(ticket,DEAL_PROFIT),"</td></tr>");
            // mark deal as processed
            deal_status[i]=127;
           }
         // if this deal is buy or sell
         if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BUY || HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_SELL)
           {
            // check if there is instrument of this deal in the list
            symb_flag=false;
            for(j=0;j<symb_total;j++)
              {
               if(symb_list[j]==HistoryDealGetString(ticket,DEAL_SYMBOL))
                 {
                  symb_flag=true;
                  symb_pointer=j;
                 }
              }
            // if there is no instrument of this deal in the list
            if(symb_flag==false)
              {
               symb_list[symb_total]=HistoryDealGetString(ticket,DEAL_SYMBOL);
               lots_list[symb_total]=0;
               symb_pointer=symb_total;
               symb_total++;
              }
            // set the initial value for the beginning time of deal
            position_StartTime=time_curr;
            // set the initial value for the end time of deal
            position_EndTime=time_curr;
            // creating the string in report - instrument, position direction, beginning of table for volumes to enter the market
            if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BUY)
               StringConcatenate(in_table_volume,"<tr><td align='left'>",symb_list[symb_pointer],
               "</td><td align='center'><img src='buy.gif'></td><td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>");

            if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_SELL)
               StringConcatenate(in_table_volume,"<tr><td align='left'>",symb_list[symb_pointer],
               "</td><td align='center'><img src='sell.gif'></td><td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>");
            // creating the beginning of time table to enter the market
            in_table_time="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of price table to enter the market
            in_table_price="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of volume table to exit the market
            out_table_volume="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of time table to exit the market
            out_table_time="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of price table to exit the market
            out_table_price="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of swap table to exit the market
            out_table_swap="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // creating the beginning of profit table to exit the market
            out_table_profit="<td><table border='1' width='100%' bgcolor='#FFFFFF' bordercolor='#DFDFFF'>";
            // process all deals for this position starting with the current(until position is closed)
            for(j=i;j<total_deals_number;j++)
              {
               // if the deal has not been processed yet - process it
               if(deal_status[j]<127)
                 {
                  // select deal, get ticket
                  ticket=HistoryDealGetTicket(j);
                  // if the instrument of deal matches the instrument of position, that is processed
                  if(symb_list[symb_pointer]==HistoryDealGetString(ticket,DEAL_SYMBOL))
                    {
                     // get the deal time
                     time_curr=HistoryDealGetInteger(ticket,DEAL_TIME);
                     // If the deal time goes beyond the range of position time
                     // - extend position time
                     if(time_curr<position_StartTime) position_StartTime=time_curr;
                     if(time_curr>position_EndTime) position_EndTime=time_curr;
                     // get the volume of deal
                     lot_current=HistoryDealGetDouble(ticket,DEAL_VOLUME);
                     // if this deal is buy
                     if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_BUY)
                       {
                        // if position has been already opened for sell - this will be the exit from market
                        if(NormalizeDouble(lots_list[symb_pointer],2)<0)
                          {
                           // if buy volume is greater than volume of opened short position - then this is in/out
                           if(NormalizeDouble(lot_current+lots_list[symb_pointer],2)>0)
                             {
                              // creating table of volumes to exit the market - indicate only volume of opened short position
                              StringConcatenate(out_table_volume,out_table_volume,
                              "<tr><td align=right>",DoubleToString(-lots_list[symb_pointer],2),"</td></tr>");
                              // mark position as partially processed
                              deal_status[j]=1;
                             }
                           else
                             {
                              // if buy volume is equal or less than volume of opened short position - then this is partial or full close
                              // creating the volume table to exit the market
                              StringConcatenate(out_table_volume,out_table_volume,"<tr><td align='right'>",DoubleToString(lot_current,2),"</td></tr>");
                              // mark deal as processed
                              deal_status[j]=127;
                             }
                           // creating the time table to exit the market
                           StringConcatenate(out_table_time,out_table_time,"<tr><td align='center'>",
                           TimeToString(time_curr,TIME_DATE|TIME_SECONDS),"</td></tr>");
                           // creating the price table to exit the market
                           StringConcatenate(out_table_price,out_table_price,"<tr><td align='center'>",
                           DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),
                           (int)SymbolInfoInteger(symb_list[symb_pointer],SYMBOL_DIGITS)),
                           "</td></tr>");
                           // get the swap of current deal
                           current_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
                           // if swap is equal to zero - create empty string of the swap table to exit the market
                           if(NormalizeDouble(current_swap,2)==0) StringConcatenate(out_table_swap,out_table_swap,"<tr></tr>");
                           // else create the swap string in the swap table to exit the market
                           else StringConcatenate(out_table_swap,out_table_swap,"<tr><td align='right'>",DoubleToString(current_swap,2),"</td></tr>");
                           // get the profit of current deal
                           current_profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
                           // if profit is negative (loss) - it is displayed as red in the profit table to exit the market
                           if(NormalizeDouble(current_profit,2)<0) StringConcatenate(out_table_profit,out_table_profit,
                           "<tr><td align='right'><SPAN style='COLOR: #EF0000'>",DoubleToString(current_profit,2),"</SPAN></td></tr>");
                           // else - it is displayed as green
                           else StringConcatenate(out_table_profit,out_table_profit,
                           "<tr><td align=right><SPAN style='COLOR: #00EF00'>",DoubleToString(current_profit,2),"</SPAN></td></tr>");
                          }
                        else
                        // if position is opened for buy - this will be the enter to the market
                          {
                           // if this deal has been already partially processed (in/out)
                           if(deal_status[j]==1)
                             {
                              // create the volume table of entering the market (volume, formed after in/out, is put here)
                              StringConcatenate(in_table_volume,in_table_volume,
                              "<tr><td align=right>",DoubleToString(lots_list[symb_pointer],2),"</td></tr>");
                              // indemnity of volume change, which will be produced (the volume of this deal is already taken into account)
                              lots_list[symb_pointer]-=lot_current;
                             }
                           // if this deal has not been processed yet, create the volume table to enter the market
                           else StringConcatenate(in_table_volume,in_table_volume,"<tr><td align='right'>",
                                DoubleToString(lot_current,2),"</td></tr>");
                           // creating the time table of entering the market
                           StringConcatenate(in_table_time,in_table_time,"<tr><td align='center'>",
                           TimeToString(time_curr,TIME_DATE|TIME_SECONDS),"</td></tr>");
                           // creating the price table of entering the market
                           StringConcatenate(in_table_price,in_table_price,"<tr><td align='center'>",
                           DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),
                           (int)SymbolInfoInteger(symb_list[symb_pointer],SYMBOL_DIGITS)),"</td></tr>");
                           // mark deal as processed
                           deal_status[j]=127;
                          }
                        // change of position volume by the current instrument, taking into account the volume of current deal
                        lots_list[symb_pointer]+=lot_current;
                        // if the volume of opened position by the current instrument became equal to zero - position is closed
                        if(NormalizeDouble(lots_list[symb_pointer],2)==0 || deal_status[j]==1) break;
                       }
                     // if this deal is sell
                     if(HistoryDealGetInteger(ticket,DEAL_TYPE)==DEAL_TYPE_SELL)
                       {
                        // if position has been already opened for buy - this will be the exit from market
                        if(NormalizeDouble(lots_list[symb_pointer],2)>0)
                          {
                           // if sell volume is greater than volume of opened long position - then this is in/out
                           if(NormalizeDouble(lot_current-lots_list[symb_pointer],2)>0)
                             {
                              // creating table of volumes to exit the market - indicate only volume of opened long position
                              StringConcatenate(out_table_volume,out_table_volume,
                              "<tr><td align='right'>",DoubleToString(lots_list[symb_pointer],2),"</td></tr>");
                              // mark position as partially processed
                              deal_status[j]=1;
                             }
                           else
                             {
                              // if sell volume is equal or greater than volume of opened short position - then this is partial or full close
                              // creating the volume table to exit the market
                              StringConcatenate(out_table_volume,out_table_volume,"<tr><td align='right'>",DoubleToString(lot_current,2),"</td></tr>");
                              // mark deal as processed
                              deal_status[j]=127;
                             }
                           // creating the time table to exit the market
                           StringConcatenate(out_table_time,out_table_time,
                           "<tr><td align='center'>",TimeToString(time_curr,TIME_DATE|TIME_SECONDS),"</td></tr>");
                           // creating the price table to exit the market
                           StringConcatenate(out_table_price,out_table_price,
                           "<tr><td align=center>",
                           DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),
                           (int)SymbolInfoInteger(symb_list[symb_pointer],SYMBOL_DIGITS)),"</td></tr>");
                           // get the swap of current deal
                           current_swap=HistoryDealGetDouble(ticket,DEAL_SWAP);
                           // if swap is equal to zero - create empty string of the swap table to exit the market
                           if(NormalizeDouble(current_swap,2)==0) StringConcatenate(out_table_swap,out_table_swap,"<tr></tr>");
                           // else create the swap string in the swap table to exit the market
                           else StringConcatenate(out_table_swap,out_table_swap,"<tr><td align='right'>",DoubleToString(current_swap,2),"</td></tr>");
                           // get the profit of current deal
                           current_profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
                           // if profit is negative (loss) - it is displayed as red in the profit table to exit the market
                           if(NormalizeDouble(current_profit,2)<0) StringConcatenate(out_table_profit,out_table_profit,
                           "<tr><td align=right><SPAN style='COLOR: #EF0000'>",
                           DoubleToString(current_profit,2),"</SPAN></td></tr>");
                           // else - it is displayed as green
                           else StringConcatenate(out_table_profit,out_table_profit,
                           "<tr><td align=right><SPAN style='COLOR: #00EF00'>",DoubleToString(current_profit,2),"</SPAN></td></tr>");
                          }
                        else
                        // if position is opened for sell - this will be the enter to the market
                          {
                           // if this deal has been already partially processed (in/out)
                           if(deal_status[j]==1)
                             {
                              // create the volume table of entering the market (volume, formed after in/out, is put here)
                              StringConcatenate(in_table_volume,in_table_volume,
                              "<tr><td align='right'>",DoubleToString(-lots_list[symb_pointer],2),"</td></tr>");
                              // indemnity of volume change, which will be produced (the volume of this deal is already taken into account)
                              lots_list[symb_pointer]+=lot_current;
                             }
                           // if this deal has not been processed yet, create the volume table to enter the market
                           else StringConcatenate(in_table_volume,in_table_volume,
                           "<tr><td align='right'>",DoubleToString(lot_current,2),"</td></tr>");
                           // creating the time table of entering the market
                           StringConcatenate(in_table_time,in_table_time,
                           "<tr><td align='center'>",
                           TimeToString(time_curr,TIME_DATE|TIME_SECONDS),
                           "</td></tr>");
                           // creating the price table of entering the market
                           StringConcatenate(in_table_price,in_table_price,
                           "<tr><td align='center'>",
                           DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),
                           (int)SymbolInfoInteger(symb_list[symb_pointer],SYMBOL_DIGITS)),"</td></tr>");
                           // mark deal as processed
                           deal_status[j]=127;
                          }
                        // change of position volume by the current instrument, taking into account the volume of current deal
                        lots_list[symb_pointer]-=lot_current;
                        // if the volume of opened position by the current instrument became equal to zero - position is closed
                        if(NormalizeDouble(lots_list[symb_pointer],2)==0 || deal_status[j]==1) break;
                       }
                    }
                 }
              }
            // if the position period is in the the report period - the position is printed to report
            if(position_EndTime>=StartTime && position_StartTime<=EndTime) FileWrite(file_handle,
            in_table_volume,"</table></td>",
            in_table_time,"</table></td>",
            in_table_price,"</table></td>",
            out_table_volume,"</table></td>",
            out_table_time,"</table></td>",
            out_table_price,"</table></td>",
            out_table_swap,"</table></td>",
            out_table_profit,"</table></td></tr>");
           }
        }
      // changing balance
      balance_prev=balance;
     }
// create the end of html-file
   FileWrite(file_handle,
         "</table><br><br>"+
            "<h2>Balance Chart</h2><img src='picture1.gif'><br><br><br>"+
            "<h2>Price Chart</h2><img src='picture2.gif'>"+
         "</center>"+
         "</body>"+
   "</html>");
// close file
   FileClose(file_handle);

// get current time
   time_curr=TimeCurrent();
// waiting for chart update
   while(SeriesInfoInteger(Symbol(),Picture1_period,SERIES_BARS_COUNT)==0 && TimeCurrent()-time_curr<timeout) Sleep(1000);
// setting maximal and minimal values for the balance chart (10% indent from upper and lower boundaries)
   ChartSetDouble(hChart,CHART_FIXED_MAX,max_val+(max_val-min_val)/10);
   ChartSetDouble(hChart,CHART_FIXED_MIN,min_val-(max_val-min_val)/10);
// setting properties of the balance chart
   ChartSetInteger(hChart,CHART_MODE,CHART_LINE);                 // chart as line
   ChartSetInteger(hChart,CHART_FOREGROUND,false);                // chart on foreground
   ChartSetInteger(hChart,CHART_SHOW_BID_LINE,false);             // hide BID line
   ChartSetInteger(hChart,CHART_COLOR_VOLUME,White);              // volumes and orders levels are white
   ChartSetInteger(hChart,CHART_COLOR_STOP_LEVEL,White);          // SL and TP levels are white
   ChartSetInteger(hChart,CHART_SHOW_GRID,true);                  // show grid
   ChartSetInteger(hChart,CHART_COLOR_GRID,LightGray);            // grid is light-gray
   ChartSetInteger(hChart,CHART_SHOW_PERIOD_SEP,false);           // hide period separators
   ChartSetInteger(hChart,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);  // hide volumes
   ChartSetInteger(hChart,CHART_COLOR_CHART_LINE,White);          // chart is white
   ChartSetInteger(hChart,CHART_SCALE,0);                         // minimal scale
   ChartSetInteger(hChart,CHART_SCALEFIX,true);                   // fixed scale on vertical axis
   ChartSetInteger(hChart,CHART_SHIFT,false);                     // no chart shift
   ChartSetInteger(hChart,CHART_AUTOSCROLL,true);                 // autoscroll enabled
   ChartSetString(hChart,CHART_COMMENT,"BALANCE");                // comment on chart
   ChartRedraw(hChart);                                           // redrawing the balance chart
   Sleep(8000);
// save chart as image file
   ChartScreenShot(hChart,"picture1.gif",
   (int)(EndTime-StartTime)/PeriodSeconds(Picture1_period),
   (int)(EndTime-StartTime)/PeriodSeconds(Picture1_period)/2,
   ALIGN_RIGHT);
// delete all objects from the balance chart
   ObjectsDeleteAll(hChart);
// close chart
   ChartClose(hChart);
// if report publication is enabled - send via FTP
// HTML-file and two images - price chart and balance chart
   if(TerminalInfoInteger(TERMINAL_FTP_ENABLED))
     {
      SendFTP("report.html");
      SendFTP("picture1.gif");
      SendFTP("picture2.gif");
     }
  }
//+------------------------------------------------------------------+
