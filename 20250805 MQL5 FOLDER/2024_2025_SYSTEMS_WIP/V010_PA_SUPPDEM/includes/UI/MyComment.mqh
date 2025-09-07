//+------------------------------------------------------------------+
//|                                                    MyComment.mqh |
//|                                                      nicholishen |
//|                                   www.reddit.com/u/nicholishenFX |
//+------------------------------------------------------------------+
#property copyright "nicholishen"
#property link      "www.reddit.com/u/nicholishenFX"
#property version   "1.00"
#property strict

#define COLOR_BACK      clrBlack
#define COLOR_BORDER    clrDimGray
#define COLOR_CAPTION   clrDodgerBlue
#define COLOR_TEXT      clrLightGray
#define COLOR_WIN       clrLimeGreen
#define COLOR_LOSS      clrOrangeRed

#include "Comment010.mqh"

struct XYXY {int x1;int y1;int x2;int y2;};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MyComment : public CComment
{
protected:
   string            my_name;
   XYXY              my_pos;
public:
   void              Init(string,int,int);
   void              Show();
   void              Hide();
   bool              Zone(int,int);
   int               OnChartEvent(  const int      id,
                                    const long     lparam,
                                    const double   dparam,
                                    const string   sparam);
protected:
   void              Zone();
};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MyComment::Init(string name,int x,int y)
{
   my_name=name;
   my_pos.x1=x;
   my_pos.y1=y;
   Create(my_name,x,y);
   Zone();
   Destroy();
}
//+------------------------------------------------------------------+
void MyComment::Show(void)
{
   Create(my_name,my_pos.x1,my_pos.y1);
   SetAutoColors(true);
   SetColor(COLOR_BORDER,COLOR_BACK,255);
   SetFont("Lucida Console",13,false,1.7);
   CComment::Show();
}
//+------------------------------------------------------------------+
void MyComment::Hide(void)
{
   Zone();
   Destroy();
}
//+------------------------------------------------------------------+
void MyComment::Zone(void)
{
   if(ObjectFind(0,my_name)<0)
      return;
   my_pos.x1 = (int)ObjectGetInteger(0,my_name,OBJPROP_XDISTANCE);
   my_pos.y1 = (int)ObjectGetInteger(0,my_name,OBJPROP_YDISTANCE);
   my_pos.x2 = my_pos.x1+(int)ObjectGetInteger(0,my_name,OBJPROP_XSIZE);
   my_pos.y2 = my_pos.y1+(int)ObjectGetInteger(0,my_name,OBJPROP_YSIZE);
}
//+------------------------------------------------------------------+
bool MyComment::Zone(int x,int y)
{
   Zone();
   if(y>=my_pos.y1 && y<=my_pos.y2 && x>=my_pos.x1 && x<=my_pos.x2)
      return true;
   return false;
}
//+------------------------------------------------------------------+
int MyComment::OnChartEvent(const int id,const long lparam,const double dparam,const string sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE && ObjectFind(0,my_name)>=0)
   {
      Zone();
      int xd = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
      int yd = (int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
      int xs = (int)ObjectGetInteger(0,my_name,OBJPROP_XSIZE);
      int ys = (int)ObjectGetInteger(0,my_name,OBJPROP_YSIZE);
      if(my_pos.x2 > xd)
         my_pos.x1 = xd-xs;
      if(my_pos.y2 > yd)
         my_pos.y1 = yd-ys;
      ObjectSetInteger(0,my_name,OBJPROP_XDISTANCE,my_pos.x1 < 0 ? 0 : my_pos.x1);
      ObjectSetInteger(0,my_name,OBJPROP_YDISTANCE,my_pos.y1 < 0 ? 0 : my_pos.y1);
      
   }
   return CComment::OnChartEvent(id,lparam,dparam,sparam);
}
//+------------------------------------------------------------------+