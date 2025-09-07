//ea-helper-functions
bool isNewBar()
  {
//Print("NEW BAR CHECK ROUTINE");
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),PERIOD_M1,SERIES_LASTBAR_DATE);
//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }
//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }

void PrepareChartForBot(){
// Set chart properties
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);  // Set background to black
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);  // Set foreground to black
// Hide trade history
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);    // Hide trade levels (including history)
   ChartSetInteger(0, CHART_SHOW_GRID, false);            // Hide grid
   ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);        // Hide Ask line
   ChartSetInteger(0, CHART_SHOW_BID_LINE, false);        // Hide Bid line
   ChartSetInteger(0, CHART_SHOW_LAST_LINE, false);       // Hide Last price line
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);      // Hide period separators
   ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE); // Hide volumes
   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, false);    // Hide object descriptions
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);    // Hide trade levels
   ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);    // Hide trade history
// Hide quick trading buttons
   ChartSetInteger(0, CHART_SHOW_ONE_CLICK, false);       // Hide one-click trading panel
// Hide price chart
   ChartSetInteger(0, CHART_MODE, CHART_BARS);            // Set chart mode to bars
   ChartSetInteger(0, CHART_SCALE, 0);                    // Set minimum scale
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);     // Hide price scale
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);      // Hide date scale
// Set candle colors to black
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrBlack); // Set bullish candle color to black
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack); // Set bearish candle color to black
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);  // Set chart down color to black
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);    // Set chart up color to black
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrBlack);    // Set chart up color to black


}
  //+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//retreive a list of all tempaltes files in folders
//not working
string ListTemplates()
  {
   string templatesPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Profiles\\Templates\\";
   string fileList = "";
   int fileCount = 0;
   string fileName;
   long searchHandle = FileFindFirst(templatesPath + "*.tpl", fileName, 0);
   if(searchHandle != INVALID_HANDLE)
     {
      do
        {
         if(fileName == "." || fileName == "..")
            continue;
         fileList += StringFormat("%d. %s\n", ++fileCount, fileName);
        }
      while(FileFindNext(searchHandle, fileName));
      FileFindClose(searchHandle);
     }
   if(fileCount > 0)
      return StringFormat("Available templates (%d):\n%s", fileCount, fileList);
   else
      return "No template files found.";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int chart_print(string text,int identifier=-1,int x_pos=-1,int y_pos=-1,int fontsize=10,int linespace=15,color fontcolor=clrGray,string font="Impact",string label_prefix="chart_print_",long chart_id=0,int subwindow=0)
  {
    //https://www.mql5.com/en/forum/323918
    // set message identifier
    //       negative number:      set next identifier
    //       specific number >=0:  replace older messages with same identifier
   static int id=0;
   static int x_static=0;
   static int y_static=0;
   if(identifier>=0)
     {
      id=identifier;
     }
   else
     {
      id++;
     }
   ObjectsDeleteAll(0,label_prefix+IntegerToString(id));
   if(text!="")    //note: chart_print("",n) can be used to delete a specific message
     {
      // initialize or set cursor position
      //       keep last line feed position: set negative number for y_pos
      //       same x position as last message: set negative number for x_pos
      if(x_pos>=0)
        {
         x_static=x_pos;
        }
      if(y_pos>=0)
        {
         y_static=y_pos;
        }
      // get number of lines ('#' sign is used for line feed)
      int lines=1+MathMax(StringReplace(text,"#","#"),0);
      // get substrings
      string substring[];
      StringSplit(text,'#',substring);
      // print lines
      for(int l=1;l<=lines;l++)
        {
         string msg_label=label_prefix+IntegerToString(id)+", line "+IntegerToString(l);
         ObjectCreate(chart_id,msg_label,OBJ_LABEL,subwindow,0,0);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_XDISTANCE,x_static);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_YDISTANCE,y_static);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetString(chart_id,msg_label,OBJPROP_TEXT,substring[l-1]);
         ObjectSetString(chart_id,msg_label,OBJPROP_FONT,font);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_FONTSIZE,fontsize);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_COLOR,fontcolor);
         ObjectSetInteger(chart_id,msg_label,OBJPROP_BACK,false);
         // line feed
         y_static+=fontsize+linespace;
        }
     }
   return y_static;
  }