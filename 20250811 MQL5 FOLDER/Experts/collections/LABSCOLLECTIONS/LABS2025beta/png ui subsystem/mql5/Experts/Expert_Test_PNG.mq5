//+------------------------------------------------------------------+
//|                                              Expert_Test_PNG.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "png.mqh"
#include "iCanvas_CB.mqh" // https://www.mql5.com/ru/code/22164

//==========================


//#resource "//Images//icons.png" as uchar png_data[]

#resource "//Images//tgram03.png" as uchar png_data[]
//==============================
//+------------------------------------------------------------------+
CPng png1(png_data);
// Get the PNG from the resource, unpack it into a bitmap
//array bmp[] and don't create the canvas yet

//=======================================================================
CPng png2("tgram01.png",
          false,//create a canvas wallpaper[yes/no]
          200,
          200); // Get PNG from a file,
//                create a canvas and display it on the screen at coordinates (X=0, Y=100)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int chart_print(string text,int identifier=-1,int x_pos=-1,int y_pos=-1,int fontsize=10,int linespace=15,color fontcolor=clrGray,string font="Calibri",string label_prefix="chart_print_",long chart_id=0,int subwindow=0)
{
   //https://www.mql5.com/en/forum/323918
   // set message identifier
   //       negative number:      set next identifier
   //       specific number >=0:  replace older messages with same identifier
   static int id=0;
   static int x_static=0;
   static int y_static=0;
   if (identifier>=0) {
      id=identifier;
   }
   else {
      id++;
   }
   ObjectsDeleteAll(0,label_prefix+IntegerToString(id));
   if (text!="") { //note: chart_print("",n) can be used to delete a specific message
      // initialize or set cursor position
      //       keep last line feed position: set negative number for y_pos
      //       same x position as last message: set negative number for x_pos
      if (x_pos>=0) {
         x_static=x_pos;
      }
      if (y_pos>=0) {
         y_static=y_pos;
      }
      // get number of lines ('#' sign is used for line feed)
      int lines=1+MathMax(StringReplace(text,"#","#"),0);
      // get substrings
      string substring[];
      StringSplit(text,'#',substring);
      // print lines
      for (int l=1;l<=lines;l++) {
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
//+------------------------------------------------------------------+
int OnInit()
{
   //=============================================
   png1.Resize(512);
   png1._CreateCanvas(350,100);
   //png1.Resize(W.Width/6);
   png1.BmpArrayFree();
   //png2.Resize(220);
   //png2._CreateCanvas(W.MouseX, W.MouseY);
   png2.Resize(80);
   png2._CreateCanvas(W.MouseX, W.MouseY);
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
   
   //text#2ndlinetext
   //coordinates 0,10
   chart_print("Hello, World!#Updated line 2",     0, 10, 300, 12, 5, clrGold);
   Sleep(2000);
   chart_print("Hello, universe!#Updated line 20", 0, 10, 300, 12, 5, clrGold);
   Sleep(2000);
   chart_print("Hello, mars!#Updated line 200",    0, 10, 300, 12, 5, clrGold);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0,0,OBJ_LABEL);
}
//+------------------------------------------------------------------+
void OnTick()
{
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if (id == CHARTEVENT_MOUSE_MOVE) {
      png2._MoveCanvas(W.MouseX, W.MouseY);//move the icon next to mouse
      //png2.MoveCanvas(W.MouseX/10, 100+W.MouseY/10);//move the larger wallpaper
      //=====
      //png1._MoveCanvas(700+W.MouseX/16, 150+W.MouseY/16);
   }
}
//+------------------------------------------------------------------+
