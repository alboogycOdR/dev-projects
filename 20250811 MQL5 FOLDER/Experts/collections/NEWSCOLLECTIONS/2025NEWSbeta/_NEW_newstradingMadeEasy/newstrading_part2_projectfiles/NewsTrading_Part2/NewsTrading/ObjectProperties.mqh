//+------------------------------------------------------------------+
//|                                                      NewsTrading |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                            https://www.mql5.com/en/users/kaaiblo |
//+------------------------------------------------------------------+
#include "ChartProperties.mqh"
//+------------------------------------------------------------------+
//|ObjectProperties class                                            |
//+------------------------------------------------------------------+
class CObjectProperties:public CChartProperties
  {
private:
   //Simple  chart objects structure
   struct ObjStruct
     {
      long           ChartId;
      string         Name;
     } Objects[];//ObjStruct variable array

   //-- Add chart object to Objects array
   void              AddObj(long chart_id,string name)
     {
      ArrayResize(Objects,Objects.Size()+1,Objects.Size()+2);
      Objects[Objects.Size()-1].ChartId=chart_id;
      Objects[Objects.Size()-1].Name=name;
     }

public:
                     CObjectProperties(void) {}//Class constructor

   //-- Create Rectangle chart object
   void              Square(long chart_ID,string name,int x_coord,int y_coord,int width,int height,ENUM_ANCHOR_POINT Anchor);

   //-- Create text chart object
   void              TextObj(long chartID,string name,string text,int x_coord,int y_coord,
                             ENUM_BASE_CORNER Corner=CORNER_LEFT_UPPER,int fontsize=10);

   //-- Create Event object
   void               EventObj(long chartID,string name,string description,datetime eventdate);

   //-- Class destructor removes all chart objects created previously
                    ~CObjectProperties(void)
     {
      for(uint i=0;i<Objects.Size();i++)
        {
         ObjectDelete(Objects[i].ChartId,Objects[i].Name);
        }
     }
  };

//+------------------------------------------------------------------+
//|Create Rectangle chart object                                     |
//+------------------------------------------------------------------+
void CObjectProperties::Square(long chart_ID,string name,int x_coord,int y_coord,int width,int height,ENUM_ANCHOR_POINT Anchor)
  {
   const int              sub_window=0;             // subwindow index
   const int              x=x_coord;                // X coordinate
   const int              y=y_coord;                // Y coordinate
   const color            back_clr=clrBlack;        // background color
   const ENUM_BORDER_TYPE border=BORDER_SUNKEN;     // border type
   const color            clr=clrRed;               // flat border color (Flat)
   const ENUM_LINE_STYLE  style=STYLE_SOLID;        // flat border style
   const int              line_width=0;             // flat border width
   const bool             back=false;               // in the background
   const bool             selection=false;          // highlight to move
   const bool             hidden=true;              // hidden in the object list

   ObjectDelete(chart_ID,name);//Delete previous object with the same name and chart id
   if(ObjectCreate(chart_ID,name,OBJ_RECTANGLE_LABEL,sub_window,0,0))//create rectangle object label
     {
      AddObj(chart_ID,name);//Add object to array
      ObjectSetInteger(chart_ID,name,OBJPROP_XDISTANCE,x);//Set x Distance/coordinate
      ObjectSetInteger(chart_ID,name,OBJPROP_YDISTANCE,y);//Set y Distance/coordinate
      ObjectSetInteger(chart_ID,name,OBJPROP_XSIZE,width);//Set object's width/x-size
      ObjectSetInteger(chart_ID,name,OBJPROP_YSIZE,height);//Set object's height/y-size
      ObjectSetInteger(chart_ID,name,OBJPROP_BGCOLOR,back_clr);//Set object's background color
      ObjectSetInteger(chart_ID,name,OBJPROP_BORDER_TYPE,border);//Set object's border type
      ObjectSetInteger(chart_ID,name,OBJPROP_ANCHOR,Anchor);//Set objects anchor point
      ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);//Set object's color
      ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);//Set object's style
      ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,line_width);//Set object's flat border width
      ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);//Set if object is in foreground or not
      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTABLE,selection);//Set if object is selectable/dragable
      ObjectSetInteger(chart_ID,name,OBJPROP_SELECTED,selection);//Set if object is Selected
      ObjectSetInteger(chart_ID,name,OBJPROP_HIDDEN,hidden);//Set if object is hidden in object list
      ChartRedraw(chart_ID);
     }
   else
     {
      Print("Failed to create object: ",name);
     }
  }

//+------------------------------------------------------------------+
//|Create text chart object                                          |
//+------------------------------------------------------------------+
void CObjectProperties::TextObj(long chartID,string name,string text,int x_coord,int y_coord,
                                ENUM_BASE_CORNER Corner=CORNER_LEFT_UPPER,int fontsize=10)
  {
   ObjectDelete(chartID,name);//Delete previous object with the same name and chart id
   if(ObjectCreate(chartID,name,OBJ_LABEL,0,0,0))//Create object label
     {
      AddObj(chartID,name);//Add object to array
      ObjectSetInteger(chartID,name,OBJPROP_XDISTANCE,x_coord);//Set x Distance/coordinate
      ObjectSetInteger(chartID,name,OBJPROP_YDISTANCE,y_coord);//Set y Distance/coordinate
      ObjectSetInteger(chartID,name,OBJPROP_CORNER,Corner);//Set object's corner anchor
      ObjectSetString(chartID,name,OBJPROP_TEXT,text);//Set object's text
      ObjectSetInteger(chartID,name,OBJPROP_COLOR,SymbolBackground());//Set object's color
      ObjectSetInteger(chartID,name,OBJPROP_FONTSIZE,fontsize);//Set object's font-size
     }
   else
     {
      Print("Failed to create object: ",name);
     }
  }

//+------------------------------------------------------------------+
//|Create Event object                                               |
//+------------------------------------------------------------------+
void CObjectProperties::EventObj(long chartID,string name,string description,datetime eventdate)
  {
   ObjectDelete(chartID,name);//Delete previous object with the same name and chart id
   if(ObjectCreate(chartID,name,OBJ_EVENT,0,eventdate,0))//Create object event
     {
      AddObj(chartID,name);//Add object to array
      ObjectSetString(chartID,name,OBJPROP_TEXT,description);//Set object's text
      ObjectSetInteger(chartID,name,OBJPROP_COLOR,clrBlack);//Set object's color
     }
   else
     {
      Print("Failed to create object: ",name);
     }
  }
//+------------------------------------------------------------------+
