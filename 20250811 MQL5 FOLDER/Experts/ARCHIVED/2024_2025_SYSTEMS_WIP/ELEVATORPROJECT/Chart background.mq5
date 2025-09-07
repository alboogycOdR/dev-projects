//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#property description "!!! Images .BMP must be in MQL4/Images"
#property copyright "eevviill"
#property link "http://volli7.blogspot.com/"
#property version   "3.41"
//#property icon "\\Files\\evi.ico"
#property strict
#property indicator_chart_window


bool comment_chart_resolution = false;
int X_shift = 0;
int Y_shift = 0;

string emp1 = "///////////////////////////////////////";
bool use_main_window_image = true;
string Name_bmp_image_MW = "Wallpaper_01";


bool use_sub_window_image = false;
string Name_bmp_image_SW = "gree3";

string emp2 = "///////////////////////////////////////";
bool show_periods_separator = false;
color separator_period_color = clrGray;
int separator_period_width = 0;
ENUM_LINE_STYLE separator_period_style = STYLE_DOT;


string label_name="sfscr7qw";
string separ_line_name="dfdfh6r";
int separator_period;
int prevbars;





////////////////////////////////////////////////
int OnInit()
  {
   string del_name="";
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     {
      del_name=ObjectName(0,i);
      if(StringFind(del_name,label_name)!=-1 || StringFind(del_name,separ_line_name)!=-1)
         ObjectDelete(0,del_name);
     }


   Comment("");




   if(comment_chart_resolution)
     {
      long main_chart_width_pix=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
      long main_chart_height_pix=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
      //string com=StringConcatenate("Chart width:",string(main_chart_width_pix),"\nChart height:",string(main_chart_height_pix),"");

      //Comment(com);
     }


////create
   string name_create=Name_bmp_image_MW;
   string lab_name_plus_str="sdljgbhjdlgh";

//for(int i=0;i<WindowsTotal();i++)
//  {
//   if(!use_main_window_image && i==0)
//      continue;
//   if(!use_sub_window_image && i>0)
//      break;
//   if(i>0)
//      name_create=Name_bmp_image_SW;
//   lab_name_plus_str=label_name+string(i);
//

   //double dValue = ((cView > 100 ? 100 : (cView < 0 ? 0 : cView)) * 2.55) / 255.0;

   //m_Id = ChartID();




   ObjectCreate(0,lab_name_plus_str,OBJ_BITMAP_LABEL,0,0,0);
   ObjectSetString(0,lab_name_plus_str,OBJPROP_BMPFILE,"//Images//"+name_create+".bmp");


//ObjectSetInteger(0,lab_name_plus_str,OBJPROP_CORNER,CORNER_LEFT_UPPER);
//ObjectSetInteger(0,lab_name_plus_str,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_XDISTANCE,0);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_YDISTANCE,0);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_XSIZE,CHART_HEIGHT_IN_PIXELS);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_YSIZE,CHART_WIDTH_IN_PIXELS);
//ObjectSetInteger(0,lab_name_plus_str,OBJPROP_XOFFSET,200);
//ObjectSetInteger(0,lab_name_plus_str,OBJPROP_YOFFSET,200);

   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_BACK,true);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,lab_name_plus_str,OBJPROP_ZORDER,false);
//}


//separator
//if(show_periods_separator)
//  {
//   separator_period=PERIOD_D1;
//   if(Period()==PERIOD_H4)
//      separator_period=PERIOD_W1;
//   if(Period()==PERIOD_D1)
//      separator_period=PERIOD_MN1;
//   if(Period()==PERIOD_W1)
//      separator_period=PERIOD_MN1;
//  }

   return(INIT_SUCCEEDED);
  }

//////////////////////////////////////////////////
void OnDeinit(const int reason)
  {
   string del_name="";
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
     {
      del_name=ObjectName(0,i);
      if(StringFind(del_name,label_name)!=-1 || StringFind(del_name,separ_line_name)!=-1)
         ObjectDelete(0,del_name);
     }


   Comment("");
  }

//////////////////////////////////////////////////
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {

//
//   if(show_periods_separator && Period()!=PERIOD_MN1)
//     {
//      //new bar
//      if(iBars(Symbol(),separator_period)==prevbars)
//         return(rates_total);
//      prevbars=iBars(Symbol(),separator_period);
//
//      //del
//      string del_name="";
//      for(int i=ObjectsTotal()-1;i>=0;i--)
//        {
//         del_name=ObjectName(i);
//         if(StringFind(del_name,separ_line_name)!=-1)
//            ObjectDelete(del_name);
//        }
//
//
//      //create
//      string name;
//      for(int i=0;i<=iBars(Symbol(),separator_period)-4;i++)
//        {
//         name=separ_line_name+string(iTime(Symbol(),separator_period,i));
//         if(ObjectFind(name)==-1)
//           {
//            ObjectCreate(name,OBJ_VLINE,0,iTime(Symbol(),separator_period,i),0);
//            ObjectSet(name,OBJPROP_COLOR,separator_period_color);
//            ObjectSet(name,OBJPROP_WIDTH,separator_period_width);
//            ObjectSet(name,OBJPROP_STYLE,separator_period_style);
//            ObjectSet(name,OBJPROP_BACK,true);
//            ObjectSet(name,OBJPROP_HIDDEN,true);
//            ObjectSet(name,OBJPROP_SELECTABLE,false);
//            ObjectSetInteger(0,name,OBJPROP_ZORDER,false);
//           }
//        }

// }



   return(rates_total);
  }

//+------------------------------------------------------------------+
