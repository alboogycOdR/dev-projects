//+------------------------------------------------------------------+
//|                                                       Levels.mq5 |
//|                                    Copyright © 2007, Maks aka ug |
//|                                                                  |
//+------------------------------------------------------------------+
//---- Copyright
#property copyright "Copyright © 2007, Maks aka ug"
//---- link to the website of the author
#property link      ""
//---- Indicator version number
#property version   "1.00"
//---- drawing the indicator in the main window
#property indicator_chart_window 
//---- no buffers used for the calculation and drawing of the indicator
#property indicator_buffers 0
//---- 0 graphical plots are used
#property indicator_plots   0
//+-----------------------------------+
//|  Declaration of enumeration       |
//+-----------------------------------+
enum Number
  {
   Number_0,
   Number_1,
   Number_2,
   Number_3
  };
//+-----------------------------------+
//|  Declaration of enumeration       |
//+-----------------------------------+  
enum Width
  {
   Width_1=1, //1
   Width_2,   //2
   Width_3,   //3
   Width_4,   //4
   Width_5    //5
  };
//+-----------------------------------+
//|  Declaration of enumeration       |
//+-----------------------------------+
enum STYLE
  {
   SOLID_,//Solid line
   DASH_,//Dashed line
   DOT_,//Dotted line
   DASHDOT_,//Dot-dash line
   DASHDOTDOT_   // Dot-dash line with double dots
  };
//+----------------------------------------------+
//| Indicator input parameters                   |
//+----------------------------------------------+
input ENUM_TIMEFRAMES TimeFrame=PERIOD_D1; //Chart period
input int high_diap = 2000;                //Maximum range
input int low_diap = 500;                  //Minimum range
//----
input color  Color_R5 = clrDodgerBlue; //Color of the R5 level
input color  Color_R4 = clrDodgerBlue; //Color of the R4 level
input color  Color_R3 = clrDodgerBlue; //Color of the R3 level
input color  Color_R2 = clrDodgerBlue; //Color of the R2 level
input color  Color_R1 = clrDodgerBlue; //Color of the R1 level
input color  Color_S1 = clrMagenta;    //Color of the S1 level
input color  Color_S2 = clrMagenta;    //Color of the S2 level
input color  Color_S3 = clrMagenta;    //Color of the S3 level
input color  Color_S4 = clrMagenta;    //Color of the S4 level
input color  Color_S5 = clrMagenta;    //Color of the S5 level
//----
input STYLE  Style_R5 = SOLID_;         //Line style of the R5 level
input STYLE  Style_R4 = SOLID_;         //Line style of the R4 level
input STYLE  Style_R3 = SOLID_;         //Line style of the R3 level
input STYLE  Style_R2 = SOLID_;         //Line style of the R2 level
input STYLE  Style_R1 = SOLID_;         //Line style of the R1 level
input STYLE  Style_S1 = SOLID_;         //Line style of the S1 level
input STYLE  Style_S2 = SOLID_;         //Line style of the S2 level
input STYLE  Style_S3 = SOLID_;         //Line style of the S3 level
input STYLE  Style_S4 = SOLID_;         //Line style of the S4 level
input STYLE  Style_S5 = SOLID_;         //Line style of the S5 level
//----
input Width  Width_R5 = Width_2;        //The width of the R5 level
input Width  Width_R4 = Width_2;        //The width of the R4 level
input Width  Width_R3 = Width_2;        //The width of the R3 level
input Width  Width_R2 = Width_2;        //The width of the R2 level
input Width  Width_R1 = Width_2;        //The width of the R1 level
input Width  Width_S1 = Width_2;        //The width of the S1 level
input Width  Width_S2 = Width_2;        //The width of the S2 level
input Width  Width_S3 = Width_2;        //The width of the S3 level
input Width  Width_S4 = Width_2;        //The width of the S4 level
input Width  Width_S5 = Width_2;        //The width of the S5 level
//----
input uint TextSize=8;
//+----------------------------------------------+
//---- Declaration of integer variables of data starting point
int min_rates_total;
//+------------------------------------------------------------------+
//|  creating a text label                                           |
//+------------------------------------------------------------------+
void CreateText(long chart_id,// chart ID
                string   name,              // object name
                int      nwin,              // window index
                datetime time,              // price level time
                double   price,             // price level
                string   text,              // Labels text
                color    Color,             // Text color
                string   Font,              // Text font
                int      Size,              // Text size
                ENUM_ANCHOR_POINT point     // The chart corner to Which the text is attached
                )
//---- 
  {
//----
   ObjectCreate(chart_id,name,OBJ_TEXT,nwin,time,price);
   ObjectSetString(chart_id,name,OBJPROP_TEXT,text);
   ObjectSetInteger(chart_id,name,OBJPROP_COLOR,Color);
   ObjectSetString(chart_id,name,OBJPROP_FONT,Font);
   ObjectSetInteger(chart_id,name,OBJPROP_FONTSIZE,Size);
   ObjectSetInteger(chart_id,name,OBJPROP_BACK,false);
   ObjectSetInteger(chart_id,name,OBJPROP_ANCHOR,point);
//----
  }
//+------------------------------------------------------------------+
//|  changing a text label                                           |
//+------------------------------------------------------------------+
void SetText(long chart_id,// chart ID
             string   name,              // object name
             int      nwin,              // window index
             datetime time,              // price level time
             double   price,             // price level
             string   text,              // Labels text
             color    Color,             // Text color
             string   Font,              // Text font
             int      Size,              // Text size
             ENUM_ANCHOR_POINT point     // The chart corner to Which the text is attached
             )
//---- 
  {
//----
   if(ObjectFind(chart_id,name)==-1) CreateText(chart_id,name,nwin,time,price,text,Color,Font,Size,point);
   else
     {
      ObjectSetString(chart_id,name,OBJPROP_TEXT,text);
      ObjectMove(chart_id,name,0,time,price);
     }
//----
  }
//+------------------------------------------------------------------+
//|  Creating horizontal price level                                 |
//+------------------------------------------------------------------+
void CreateHline
(
 long   chart_id,      // chart ID
 string name,          // object name
 int    nwin,          // window index
 double price,         // price level
 color  Color,         // line color
 int    style,         // line style
 int    width,         // line width
 string text           // text
 )
//---- 
  {
//----
   ObjectCreate(chart_id,name,OBJ_HLINE,0,0,price);
   ObjectSetInteger(chart_id,name,OBJPROP_COLOR,Color);
   ObjectSetInteger(chart_id,name,OBJPROP_STYLE,style);
   ObjectSetInteger(chart_id,name,OBJPROP_WIDTH,width);
   ObjectSetString(chart_id,name,OBJPROP_TEXT,text);
   ObjectSetString(chart_id,name,OBJPROP_TOOLTIP,name);
   ObjectSetInteger(chart_id,name,OBJPROP_BACK,true);
//----
  }
//+------------------------------------------------------------------+
//|  Resetting the horizontal price level                            |
//+------------------------------------------------------------------+
void SetHline
(
 long   chart_id,      // chart ID
 string name,          // object name
 int    nwin,          // window index
 double price,         // price level
 color  Color,         // line color
 int    style,         // line style
 int    width,         // line width
 string text           // text
 )
//---- 
  {
//----
   if(ObjectFind(chart_id,name)==-1) CreateHline(chart_id,name,nwin,price,Color,style,width,text);
   else
     {
      //ObjectSetDouble(chart_id,name,OBJPROP_PRICE,price);
      ObjectSetString(chart_id,name,OBJPROP_TEXT,text);
      ObjectMove(chart_id,name,0,0,price);
     }
//----
  }
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+  
void OnInit()
  {
//---- Initialization of variables of the start of data calculation
   min_rates_total=int(5*PeriodSeconds(TimeFrame)/PeriodSeconds(PERIOD_CURRENT))+1;

//---- Checking correctness of the chart periods
   if(TimeFrame<Period() && TimeFrame!=PERIOD_CURRENT)
     {
      Print("Chart period for the indicator cannot be less than the current chart period");
      return;
     }

//---- Set accuracy of displaying for the indicator values
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
//---- Creating labels for displaying in DataWindow and the name for displaying in a separate sub-window and in a tooltip
   IndicatorSetString(INDICATOR_SHORTNAME,"Levels");
//----
  }
//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+    
void OnDeinit(const int reason)
  {
//----
   ObjectDelete(0,"R5_Line");
   ObjectDelete(0,"R4_Line");
   ObjectDelete(0,"R3_Line");
   ObjectDelete(0,"R2_Line");
   ObjectDelete(0,"R1_Line");
   ObjectDelete(0,"S1_Line");
   ObjectDelete(0,"S2_Line");
   ObjectDelete(0,"S3_Line");
   ObjectDelete(0,"S4_Line");
   ObjectDelete(0,"S5_Line");
//---- 
   ObjectDelete(0,"R5_Lable");
   ObjectDelete(0,"R4_Lable");
   ObjectDelete(0,"R3_Lable");
   ObjectDelete(0,"R2_Lable");
   ObjectDelete(0,"R1_Lable");
   ObjectDelete(0,"S1_Lable");
   ObjectDelete(0,"S2_Lable");
   ObjectDelete(0,"S3_Lable");
   ObjectDelete(0,"S4_Lable");
   ObjectDelete(0,"S5_Lable");

   Comment("");
//----
   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(
                const int rates_total,    // amount of history in bars at the current tick
                const int prev_calculated,// amount of history in bars at the previous tick
                const datetime &time[],
                const double &open[],
                const double& high[],     // price array of maximums of price for the calculation of indicator
                const double& low[],      // price array of price lows for the indicator calculation
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]
                )
  {
//---- 
   if(_Period>=TimeFrame) return(0);

//---- declarations of static variables   
   static double S1,R1,S2,R2,S3,R3,S4,R4,S5,R5;

   if(prev_calculated!=rates_total)
     {  
      int copy=1;
      double iHigh[1],iLow[1],iClose[1];
      if(CopyClose(NULL,TimeFrame,1,copy,iClose)<copy) return(0);
      if(CopyHigh(NULL,TimeFrame,1,copy,iHigh)<copy) return(0);
      if(CopyLow(NULL,TimeFrame,1,copy,iLow)<copy) return(0);

      int diap=0;
      double Range=iHigh[0]-iLow[0];
      
      if(Range>high_diap) diap=1;
      if(Range<low_diap) diap=2;
      
      switch(diap)
        {
         case 0: //Normal
           {
            S1 = iClose[0] - Range*0.236/2;
            R1 = Range*0.236/2 + iClose[0];
            R2 = Range*0.382+R1;
            R3 = R1+2*Range*0.382;
            R4 = R3 + (R1 - S1);
            R5 = R4 + Range*0.382;
            S2 = S1 - Range*0.382;
            S3 = S1-2*Range*0.382;
            S4 = S3 - (R1 - S1);
            S5 = S4 - Range*0.382;
           }
         break;

         case 1: //Reduced
           {
            S1 = iClose[0] - Range*0.146/2;
            R1 = Range*0.146/2 + iClose[0];
            R2 = Range*0.236+R1;
            R3 = R1+2*Range*0.236;
            R4 = R3 + (R1 - S1);
            R5 = R4 + Range*0.236;
            S2 = S1 - Range*0.236;
            S3 = S1 - Range*0.236*2;
            S4 = S3 - (R1 - S1);
            S5 = S4 - Range*0.236;
           }
         break;

         case 2: //Extended
           {
            S1 = iClose[0] - Range*0.382/2;
            R1 = Range*0.382/2 + iClose[0];
            R2 = Range*0.618+R1;
            R3 = R1+2*Range*0.618;
            R4 = R3 + (R1 - S1);
            R5 = R4 + Range*0.618;
            S2 = S1 - Range*0.618;
            S3 = S1-2*Range*0.618;
            S4 = S3 - (R1 - S1);
            S5 = S4- Range*0.618;
           }
        }
     }

   SetHline(0,"R5_Line",0,R5,Color_R5,Style_R5,Width_R5,"Pivot "+DoubleToString(R5,_Digits));
   SetHline(0,"R4_Line",0,R4,Color_R4,Style_R4,Width_R4,"Pivot "+DoubleToString(R4,_Digits));
   SetHline(0,"R3_Line",0,R3,Color_R3,Style_R3,Width_R3,"Pivot "+DoubleToString(R3,_Digits));
   SetHline(0,"R2_Line",0,R2,Color_R2,Style_R2,Width_R2,"Pivot "+DoubleToString(R2,_Digits));
   SetHline(0,"R1_Line",0,R1,Color_R1,Style_R1,Width_R1,"Pivot "+DoubleToString(R1,_Digits));

   SetHline(0,"S1_Line",0,S1,Color_S1,Style_S1,Width_S1,"Pivot "+DoubleToString(S1,_Digits));
   SetHline(0,"S2_Line",0,S2,Color_S2,Style_S2,Width_S2,"Pivot "+DoubleToString(S2,_Digits));
   SetHline(0,"S3_Line",0,S3,Color_S3,Style_S3,Width_S3,"Pivot "+DoubleToString(S3,_Digits));
   SetHline(0,"S4_Line",0,S4,Color_S4,Style_S4,Width_S4,"Pivot "+DoubleToString(S4,_Digits));
   SetHline(0,"S5_Line",0,S5,Color_S5,Style_S5,Width_S5,"Pivot "+DoubleToString(S5,_Digits));

   datetime TextTime=time[rates_total-1]+PeriodSeconds();

   SetText(0,"R5_Lable",0,TextTime,R5,"Resistance 5",Color_R5,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"R4_Lable",0,TextTime,R4,"Resistance 4",Color_R4,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"R3_Lable",0,TextTime,R3,"Resistance 3",Color_R3,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"R2_Lable",0,TextTime,R2,"Resistance 2",Color_R2,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"R1_Lable",0,TextTime,R1,"Resistance 1",Color_R1,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);

   SetText(0,"S1_Lable",0,TextTime,S1,"Support 1",Color_S1,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"S2_Lable",0,TextTime,S2,"Support 2",Color_S2,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"S3_Lable",0,TextTime,S3,"Support 3",Color_S3,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"S4_Lable",0,TextTime,S4,"Support 4",Color_S4,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);
   SetText(0,"S5_Lable",0,TextTime,S5,"Support 5",Color_S5,"Times New Roman",TextSize,ANCHOR_LEFT_LOWER);

//----
   ChartRedraw(0);  
   return(rates_total);
  }
//+------------------------------------------------------------------+
