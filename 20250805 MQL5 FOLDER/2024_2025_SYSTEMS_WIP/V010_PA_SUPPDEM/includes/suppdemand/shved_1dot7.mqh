//+------------------------------------------------------------------+
//|                                          everycandleincludes.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

/*
readme

Indicator uses fractals and ATR indicator to find and draw support resistance zones on price chart. Types of zones are:

weak: important high and low points in trend
untested: major turning points in price chart that price still didn't touch the again
verified: strong zones, price touched them before but couldn't break them
proven: verified zone that at least four time price couldn't break it
broken: zones that price breaks them (not applied for weak zones)



*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//bool NewbarForSuppDem()
//  {
//   static datetime LastTime;
//   if(iTime(Symbol(),timeframeglobal,0)+time_offset!=LastTime)
//     {
//      LastTime=iTime(Symbol(),timeframeglobal,0)+time_offset;
//      Print("NEW BAR - SUPP "+timeframeglobal);
//      return (true);
//     }
//   else
//      return (false);
//  }
//+------------------------------------------------------------------+
//|      called from oninit                                                            |
//+------------------------------------------------------------------+
void Prepare_SNR_ARRAYS()
{
ArrayResize(SlowDnPts, 50000);
   ArraySetAsSeries(SlowDnPts,true);
   ArrayResize(SlowUpPts, 50000);
   ArraySetAsSeries(SlowUpPts,true);
   ArrayResize(zone_hi, 50000);
   ArraySetAsSeries(zone_hi,true);
   ArrayResize(zone_lo, 50000);
   ArraySetAsSeries(zone_lo,true);
   ArrayResize(zone_start, 50000);
   ArraySetAsSeries(zone_start,true);
   ArrayResize(zone_hits, 50000);
   ArraySetAsSeries(zone_hits,true);
   ArrayResize(zone_type, 50000);
   ArraySetAsSeries(zone_type,true);
   ArrayResize(zone_strength, 50000);
   ArraySetAsSeries(zone_strength,true);
   ArrayResize(FastDnPts, 50000);
   ArraySetAsSeries(FastDnPts, true);
   ArrayResize(FastUpPts, 50000);
   ArraySetAsSeries(FastUpPts, true);
   ArrayResize(ner_lo_zone_P1, 50000);
   ArraySetAsSeries(FastDnPts, true);
   ArrayResize(ner_lo_zone_P2, 50000);
   ArraySetAsSeries(ner_lo_zone_P2, true);
   ArrayResize(ner_hi_zone_P1, 50000);
   ArraySetAsSeries(ner_hi_zone_P1, true);
   ArrayResize(zone_turn, 1000);
   ArraySetAsSeries(zone_turn, true);
   ArrayResize(ner_hi_zone_P2, 50000);
   ArraySetAsSeries(ner_hi_zone_P2, true);
   ArrayResize(ner_hi_zone_strength, 50000);
   ArraySetAsSeries(ner_hi_zone_strength, true);
   ArrayResize(ner_lo_zone_strength, 50000);
   ArraySetAsSeries(ner_lo_zone_strength, true);
   ArrayResize(ner_price_inside_zone, 50000);
   ArraySetAsSeries(ner_price_inside_zone, true);
}
bool NewbarForSuppDem()
  {
   static datetime last_time=0;

   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),timeframeglobal,SERIES_LASTBAR_DATE);

   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      //  Print(".... NewBar .... ",last_time);
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }



input group "SNR ZONES"
input bool        suppdemandshow = true;      //Draw SNR Zones on Chart
input             ENUM_TIMEFRAMES Timeframe  = PERIOD_CURRENT;   // Timeframe for SupplyDemand Zones


bool              showVerifiedOnly=true;
 int         BackLimit=1000;                          // Back Limit
bool        HistoryMode=false;                      // History Mode (with double click)





input group "[ zone settings ]";
input bool zone_show_weak=false;             // Show Weak Zones
input bool zone_show_untested = true;        // Show Untested Zones
input bool zone_show_turncoat = true;        // Show Broken Zones
double zone_fuzzfactor=0.75;           // Zone ATR Factor
bool zone_merge=true;                  // Zone Merge
bool zone_extend=true;                 // Zone Extend
//input group "_group2";
input double fractal_fast_factor = 3.0;      // Fractal Fast Factor
input double fractal_slow_factor = 6.0;      // Fractal Slow Factor
bool SetGlobals=false;                 // Set terminal global variables
//input group "_group3";
input bool zone_solid=true;                  // Fill zone with color
int zone_linewidth=1;                  // Zone border width
ENUM_LINE_STYLE zone_style=STYLE_DASHDOTDOT;    // Zone border style
bool zone_show_info=true;              // Show info labels
int zone_label_shift=10;               // Info label shift
//input group "_group4 alerts";
bool zone_show_alerts  = false;        // Trigger alert when entering a zone
bool zone_alert_popups = false;         // Show alert window
bool zone_alert_sounds = false;         // Play alert sound
bool zone_send_notification = false;   // Send notification when entering a zone
int zone_alert_waitseconds=300;        // Delay between alerts (seconds)
//input group               "--- Drawing Settings ---";
string               string_prefix = "SRRR"; // Change prefix to add multiple indicators to chart
//input group "_group5";
string sup_name = "Sup";               // Support Name
string res_name = "Res";               // Resistance Name
string test_name= "Retests";           // Test Name
int Text_size=8;                       // Text Size
string Text_font = "Arial";      // Text Font
input color Text_color = clrBlack;           // Text Color
input color color_support_weak     = clrGreenYellow;         // Color for weak support zone
input color color_support_untested = clrGreenYellow;              // Color for untested support zone
input color color_support_verified = clrGreenYellow;                 // Color for verified support zone
input color color_support_proven   = clrGreenYellow;             // Color for proven support zone
input color color_support_turncoat = clrGreenYellow;             // Color for turncoat(broken) support zone
input color color_resist_weak      = clrCoral;                // Color for weak resistance zone
input color color_resist_untested  = clrCoral;                // Color for untested resistance zone
input color color_resist_verified  = clrCoral;               // Color for verified resistance zone
input color color_resist_proven    = clrCoral;                   // Color for proven resistance zone
input color color_resist_turncoat  = clrCoral;            // Color for broken resistance zone

//zonelevels
double FastDnPts[],FastUpPts[];
double SlowDnPts[],SlowUpPts[];
double zone_hi[],zone_lo[];
int    zone_start[]
,zone_hits[]
,zone_type[]
,zone_strength[]
,zone_count=0;

bool   zone_turn[];
int time_offset=0;
double ner_lo_zone_P1[];
double ner_lo_zone_P2[];
double ner_hi_zone_P1[];
double ner_hi_zone_P2[];

double ner_hi_zone_strength[];/*new*/
double ner_lo_zone_strength[];/*new*/
double ner_price_inside_zone[];/*new*/



#define ZONE_SUPPORT 1
#define ZONE_RESIST  2
#define ZONE_WEAK      0
#define ZONE_TURNCOAT  1
#define ZONE_UNTESTED  2
#define ZONE_VERIFIED  3
#define ZONE_PROVEN    4
#define UP_POINT 1
#define DN_POINT -1





int iATR_handle;
double ATR[];//,ATR15[],ATR60[],ATR240[];
int cnt=0;
bool try_again=false;
//string comment="Updating Chart...";
double last_sup,last_res;
string prefix;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SUPPORT_DEMAND_ROUTINE()
  {
   // Print(__FUNCTION__);
   // Print("refreshing zones");

   int old_zone_count=zone_count;
   FastFractals();
   SlowFractals();
   DeleteZones();
   FindZones();
   if(suppdemandshow)
     {
      DrawZones();
      showLabels();
     }
   CheckAlerts();

  }
  
  
  
bool CheckEntryAlerts()
  {
   Print(__FUNCTION__);
   double Close[];
   ArraySetAsSeries(Close,true);
   CopyClose(Symbol(),timeframeglobal,0,1,Close);

// check for entries
   for(int i=0; i<zone_count; i++)
     {
      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
         continue;
      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
         continue;
      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
         continue;

      if(Close[0]>=zone_lo[i] && Close[0]<zone_hi[i])
        {
         if(zone_show_alerts==true)
           {
            if(zone_alert_popups==true)
              {
               if(zone_type[i]==ZONE_SUPPORT)
                  Alert(Symbol()+" "+TFTS(timeframeglobal)+": Support Zone Entered.");
               else
                  Alert(Symbol()+" "+TFTS(timeframeglobal)+": Resistance Zone Entered.");
              }
            if(zone_alert_sounds==true)
               PlaySound("alert.wav");
           }
         if(zone_send_notification==true)
           {
            if(zone_type[i]==ZONE_SUPPORT)
               SendNotification(Symbol()+" "+TFTS(timeframeglobal)+": Support Zone Entered.");
            else
               SendNotification(Symbol()+" "+TFTS(timeframeglobal)+": Resistance Zone Entered.");
           }

         return(true);
        }
     }
   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAlerts()
  {
   //Print(__FUNCTION__);
   if(zone_show_alerts==false && zone_send_notification==false)
      return;

   datetime Time[];

   if(CopyTime(Symbol(),timeframeglobal,0,1,Time)==-1)
      return;

   ArraySetAsSeries(Time,true);

   static int lastalert;

   if(Time[0]-lastalert>zone_alert_waitseconds)
      if(CheckEntryAlerts()==true)
         lastalert=int(Time[0]);
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewBarSupplyDemand()
  {
   static datetime LastTime;
   if(iTime(Symbol(),timeframeglobal,0)+time_offset!=LastTime)
     {
      LastTime=iTime(Symbol(),timeframeglobal,0)+time_offset;
      return (true);
     }
   else
      return (false);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// void DeleteGlobalVars()
//   {
//    if(SetGlobals==false)
//       return;

//    GlobalVariableDel("SSSR_Count_"+Symbol()+TFTS(timeframeglobal));
//    GlobalVariableDel("SSSR_Updated_"+Symbol()+TFTS(timeframeglobal));

//    int old_count=zone_count;
//    zone_count=0;
//    DeleteOldGlobalVars(old_count);
//   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// void DeleteOldGlobalVars(int old_count)
//   {
//    if(SetGlobals==false)
//       return;

//    for(int i=zone_count; i<old_count; i++)
//      {
//       GlobalVariableDel("SSSR_HI_"+Symbol()+TFTS(timeframeglobal)+string(i));
//       GlobalVariableDel("SSSR_LO_"+Symbol()+TFTS(timeframeglobal)+string(i));
//       GlobalVariableDel("SSSR_HITS_"+Symbol()+TFTS(timeframeglobal)+string(i));
//       GlobalVariableDel("SSSR_STRENGTH_"+Symbol()+TFTS(timeframeglobal)+string(i));
//       GlobalVariableDel("SSSR_AGE_"+Symbol()+TFTS(timeframeglobal)+string(i));
//      }
//   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FindZones()
  {
   int i,j,shift,bustcount=0,testcount=0;
   double hival,loval;
   bool turned=false,hasturned=false;

   double temp_hi[1000],temp_lo[1000];
   int    temp_start[1000],temp_hits[1000]
   ,temp_strength[1000],temp_count=0;

   bool   temp_turn[1000],temp_merge[1000];
   int merge1[1000],merge2[1000],merge_count=0;

// iterate through zones from oldest to youngest (ignore recent 5 bars),
// finding those that have survived through to the present___
   shift=MathMin(Bars(Symbol(),timeframeglobal)-1,BackLimit+cnt);
   shift=MathMin(shift,ArraySize(FastUpPts)-1);/*new*/

   double Close[],High[],Low[];
   ArraySetAsSeries(Close,true);
   CopyClose(Symbol(),timeframeglobal,0,shift+1,Close);
   ArraySetAsSeries(High,true);
   CopyHigh(Symbol(),timeframeglobal,0,shift+1,High);
   ArraySetAsSeries(Low,true);
   CopyLow(Symbol(),timeframeglobal,0,shift+1,Low);


   ArraySetAsSeries(ATR,true);
   if(CopyBuffer(iATR_handle,0,0,shift+1,ATR)==-1)
     {
      try_again=true;
      //Comment(comment_on_chart);
      return;
     }
   else
     {
      //if(StringFind(ChartGetString(0,CHART_COMMENT),comment_on_chart)>=0){}
      //Comment("");
      try_again=false;
     }

   for(int ii=shift; ii>cnt+5; ii--)
     {
      double atr=ATR[ii];

      double fu = atr/2 * zone_fuzzfactor;

      bool isWeak;
      bool touchOk= false;
      bool isBust = false;

      if(FastUpPts[ii]>0.001)
        {
         // a zigzag high point
         isWeak=true;
         if(SlowUpPts[ii]>0.001)
            isWeak=false;

         hival=High[ii];
         if(zone_extend==true)
            hival+=fu;

         loval=MathMax(MathMin(Close[ii],High[ii]-fu),High[ii]-fu*2);

         turned=false;
         hasturned=false;
         isBust=false;

         bustcount = 0;
         testcount = 0;

         for(i=ii-1; i>=cnt+0; i--)
           {
            if((turned==false && FastUpPts[i]>=loval && FastUpPts[i]<=hival) ||
               (turned==true && FastDnPts[i]<=hival && FastDnPts[i]>=loval))
              {
               // Potential touch, just make sure its been 10+candles since the prev one
               touchOk=true;
               for(j=i+1; j<i+11; j++)
                 {
                  if((turned==false && FastUpPts[j]>=loval && FastUpPts[j]<=hival) ||
                     (turned==true && FastDnPts[j]<=hival && FastDnPts[j]>=loval))
                    {
                     touchOk=false;
                     break;
                    }
                 }

               if(touchOk==true)
                 {
                  // we have a touch_  If its been busted once, remove bustcount
                  // as we know this level is still valid & has just switched sides
                  bustcount=0;
                  testcount++;
                 }
              }

            if((turned==false && High[i]>hival) ||
               (turned==true && Low[i]<loval))
              {
               // this level has been busted at least once
               bustcount++;

               if(bustcount>1 || isWeak==true)
                 {
                  // busted twice or more
                  isBust=true;
                  break;
                 }

               if(turned == true)
                  turned = false;
               else
                  if(turned==false)
                     turned=true;

               hasturned=true;

               // forget previous hits
               testcount=0;
              }
           }

         if(isBust==false)
           {
            // level is still valid, add to our list
            temp_hi[temp_count] = hival;
            temp_lo[temp_count] = loval;
            temp_turn[temp_count] = hasturned;
            temp_hits[temp_count] = testcount;
            temp_start[temp_count] = ii;
            temp_merge[temp_count] = false;

            if(testcount>3)
               temp_strength[temp_count]=ZONE_PROVEN;
            else
               if(testcount>0)
                  temp_strength[temp_count]=ZONE_VERIFIED;
               else
                  if(hasturned==true)
                     temp_strength[temp_count]=ZONE_TURNCOAT;
                  else
                     if(isWeak==false)
                        temp_strength[temp_count]=ZONE_UNTESTED;
                     else
                        temp_strength[temp_count]=ZONE_WEAK;

            temp_count++;
           }
        }
      else
         if(FastDnPts[ii]>0.001)
           {
            // a zigzag low point
            isWeak=true;
            if(SlowDnPts[ii]>0.001)
               isWeak=false;

            loval=Low[ii];
            if(zone_extend==true)
               loval-=fu;

            hival=MathMin(MathMax(Close[ii],Low[ii]+fu),Low[ii]+fu*2);
            turned=false;
            hasturned=false;

            bustcount = 0;
            testcount = 0;
            isBust=false;

            for(i=ii-1; i>=cnt+0; i--)
              {
               if((turned==true && FastUpPts[i]>=loval && FastUpPts[i]<=hival) ||
                  (turned==false && FastDnPts[i]<=hival && FastDnPts[i]>=loval))
                 {
                  // Potential touch, just make sure its been 10+candles since the prev one
                  touchOk=true;
                  for(j=i+1; j<i+11; j++)
                    {
                     if((turned==true && FastUpPts[j]>=loval && FastUpPts[j]<=hival) ||
                        (turned==false && FastDnPts[j]<=hival && FastDnPts[j]>=loval))
                       {
                        touchOk=false;
                        break;
                       }
                    }

                  if(touchOk==true)
                    {
                     // we have a touch_  If its been busted once, remove bustcount
                     // as we know this level is still valid & has just switched sides
                     bustcount=0;
                     testcount++;
                    }
                 }

               if((turned==true && High[i]>hival) ||
                  (turned==false && Low[i]<loval))
                 {
                  // this level has been busted at least once
                  bustcount++;

                  if(bustcount>1 || isWeak==true)
                    {
                     // busted twice or more
                     isBust=true;
                     break;
                    }

                  if(turned == true)
                     turned = false;
                  else
                     if(turned==false)
                        turned=true;

                  hasturned=true;

                  // forget previous hits
                  testcount=0;
                 }
              }

            if(isBust==false)
              {
               // level is still valid, add to our list
               temp_hi[temp_count] = hival;
               temp_lo[temp_count] = loval;
               temp_turn[temp_count] = hasturned;
               temp_hits[temp_count] = testcount;
               temp_start[temp_count] = ii;
               temp_merge[temp_count] = false;

               if(testcount>3)
                  temp_strength[temp_count]=ZONE_PROVEN;
               else
                  if(testcount>0)
                     temp_strength[temp_count]=ZONE_VERIFIED;
                  else
                     if(hasturned==true)
                        temp_strength[temp_count]=ZONE_TURNCOAT;
                     else
                        if(isWeak==false)
                           temp_strength[temp_count]=ZONE_UNTESTED;
                        else
                           temp_strength[temp_count]=ZONE_WEAK;

               temp_count++;
              }
           }
     }

// look for overlapping zones___
   if(zone_merge==true)
     {
      merge_count=1;
      int iterations=0;
      while(merge_count>0 && iterations<3)
        {
         merge_count=0;
         iterations++;

         for(i=0; i<temp_count; i++)
            temp_merge[i]=false;

         for(i=0; i<temp_count-1; i++)
           {
            if(temp_hits[i]==-1 || temp_merge[i]==true)
               continue;

            for(j=i+1; j<temp_count; j++)
              {
               if(temp_hits[j]==-1 || temp_merge[j]==true)
                  continue;

               if((temp_hi[i]>=temp_lo[j] && temp_hi[i]<=temp_hi[j]) ||
                  (temp_lo[i] <= temp_hi[j] && temp_lo[i] >= temp_lo[j]) ||
                  (temp_hi[j] >= temp_lo[i] && temp_hi[j] <= temp_hi[i]) ||
                  (temp_lo[j] <= temp_hi[i] && temp_lo[j] >= temp_lo[i]))
                 {
                  merge1[merge_count] = i;
                  merge2[merge_count] = j;
                  temp_merge[i] = true;
                  temp_merge[j] = true;
                  merge_count++;
                 }
              }
           }

         // ___ and merge them ___
         for(i=0; i<merge_count; i++)
           {
            int target = merge1[i];
            int source = merge2[i];

            temp_hi[target] = MathMax(temp_hi[target], temp_hi[source]);
            temp_lo[target] = MathMin(temp_lo[target], temp_lo[source]);
            temp_hits[target] += temp_hits[source];
            temp_start[target] = MathMax(temp_start[target], temp_start[source]);
            temp_strength[target]=MathMax(temp_strength[target],temp_strength[source]);
            if(temp_hits[target]>3)
               temp_strength[target]=ZONE_PROVEN;

            if(temp_hits[target]==0 && temp_turn[target]==false)
              {
               temp_hits[target]=1;
               if(temp_strength[target]<ZONE_VERIFIED)
                  temp_strength[target]=ZONE_VERIFIED;
              }

            if(temp_turn[target] == false || temp_turn[source] == false)
               temp_turn[target] = false;
            if(temp_turn[target] == true)
               temp_hits[target] = 0;

            temp_hits[source]=-1;
           }
        }
     }

// copy the remaining list into our official zones arrays
   zone_count=0;
   for(i=0; i<temp_count; i++)
     {
      if(temp_hits[i]>=0 && zone_count<1000)
        {
         zone_hi[zone_count]       = temp_hi[i];
         zone_lo[zone_count]       = temp_lo[i];
         zone_hits[zone_count]     = temp_hits[i];
         zone_turn[zone_count]     = temp_turn[i];
         zone_start[zone_count]    = temp_start[i];
         zone_strength[zone_count] = temp_strength[i];


         if(zone_hi[zone_count]<Close[cnt+4])
            zone_type[zone_count]=ZONE_SUPPORT;
         else
            if(zone_lo[zone_count]>Close[cnt+4])
               zone_type[zone_count]=ZONE_RESIST;
            else
              {
               int  sh=MathMin(Bars(Symbol(),timeframeglobal)-1,BackLimit+cnt);
               for(j=cnt+5; j<sh; j++)
                 {
                  if(Close[j]<zone_lo[zone_count])
                    {
                     zone_type[zone_count]=ZONE_RESIST;
                     break;
                    }
                  else
                     if(Close[j]>zone_hi[zone_count])
                       {
                        zone_type[zone_count]=ZONE_SUPPORT;
                        break;
                       }
                 }

               if(j==sh)
                  zone_type[zone_count]=ZONE_SUPPORT;
              }
         zone_count++;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawZones()
  {
   double lower_nerest_zone_P1=0;
   double lower_nerest_zone_P2=0;
   double higher_nerest_zone_P1=99999;
   double higher_nerest_zone_P2=99999;

   double higher_zone_type=0;
   double higher_zone_strength=0;
   double lower_zone_type=0;
   double lower_zone_strength=0;



//todo: removed in version1.7
// if(SetGlobals==true)
//   {
//    GlobalVariableSet("SSSR_Count_"+Symbol()+TFTS(timeframeglobal),zone_count);
//    GlobalVariableSet("SSSR_Updated_"+Symbol()+TFTS(timeframeglobal),TimeCurrent());
//   }

   for(int i=0; i<zone_count; i++)
     {
      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
         continue;

      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
         continue;

      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
         continue;

      //name sup
      string s;
      if(zone_type[i]==ZONE_SUPPORT)
         s=prefix+"S"+string(i)+" Strength=";
      else
         //name res
         s=prefix+"R"+string(i)+" Strength=";

      if(zone_strength[i]==ZONE_PROVEN)
         s=s+"Proven, Test Count="+string(zone_hits[i]);
      else
         if(zone_strength[i]==ZONE_VERIFIED)
            s=s+"Verified, Test Count="+string(zone_hits[i]);
         else
            if(zone_strength[i]==ZONE_UNTESTED)
               s=s+"Untested";
            else
               if(zone_strength[i]==ZONE_TURNCOAT)
                  s=s+"Turncoat";
               else
                  s=s+"Weak";


      datetime Time[];
      if(CopyTime(Symbol(),timeframeglobal,0,zone_start[i]+1,Time)==-1)
        {
         //Comment(comment_on_chart);
         return;
        }
      else
        {
         //if(StringFind(ChartGetString(0,CHART_COMMENT),comment_on_chart)>=0)
         //   Comment("");
        }


      ArraySetAsSeries(Time,true);
      datetime current_time,start_time;
      if(cnt==0)
         current_time=iTime(NULL,0,0);
      else
         current_time=Time[cnt+0];


      if(iTime(NULL,0,TerminalInfoInteger(TERMINAL_MAXBARS)-1)>Time[zone_start[i]])
        {
         start_time=iTime(NULL,0,TerminalInfoInteger(TERMINAL_MAXBARS)-1);
        }
      else
         start_time=Time[zone_start[i]];

      ObjectCreate(0,s,OBJ_RECTANGLE,0,0,0,0,0);
      ObjectSetInteger(0,s,OBJPROP_TIME,0,start_time);
      ObjectSetInteger(0,s,OBJPROP_TIME,1,current_time);
      ObjectSetDouble(0,s,OBJPROP_PRICE,0,zone_hi[i]);
      ObjectSetDouble(0,s,OBJPROP_PRICE,1,zone_lo[i]);
      ObjectSetInteger(0,s,OBJPROP_BACK,true);
      ObjectSetInteger(0,s,OBJPROP_FILL,zone_solid);
      ObjectSetInteger(0,s,OBJPROP_WIDTH,zone_linewidth);
      ObjectSetInteger(0,s,OBJPROP_STYLE,zone_style);

      if(zone_type[i]==ZONE_SUPPORT)
        {
         // support zone
         if(zone_strength[i]==ZONE_TURNCOAT)
            ObjectSetInteger(0,s,OBJPROP_COLOR,color_support_turncoat);
         else
            if(zone_strength[i]==ZONE_PROVEN)
               ObjectSetInteger(0,s,OBJPROP_COLOR,color_support_proven);
            else
               if(zone_strength[i]==ZONE_VERIFIED)
                  ObjectSetInteger(0,s,OBJPROP_COLOR,color_support_verified);
               else
                  if(zone_strength[i]==ZONE_UNTESTED)
                     ObjectSetInteger(0,s,OBJPROP_COLOR,color_support_untested);
                  else
                     ObjectSetInteger(0,s,OBJPROP_COLOR,color_support_weak);
        }
      else
        {
         // resistance zone
         if(zone_strength[i]==ZONE_TURNCOAT)
            ObjectSetInteger(0,s,OBJPROP_COLOR,color_resist_turncoat);
         else
            if(zone_strength[i]==ZONE_PROVEN)
               ObjectSetInteger(0,s,OBJPROP_COLOR,color_resist_proven);
            else
               if(zone_strength[i]==ZONE_VERIFIED)
                  ObjectSetInteger(0,s,OBJPROP_COLOR,color_resist_verified);
               else
                  if(zone_strength[i]==ZONE_UNTESTED)
                     ObjectSetInteger(0,s,OBJPROP_COLOR,color_resist_untested);
                  else
                     ObjectSetInteger(0,s,OBJPROP_COLOR,color_resist_weak);
        }
      //globals removed in v1.7
      //todo
      //new
      // if(SetGlobals==true)
      //   {
      //    GlobalVariableSet("SSSR_HI_"+Symbol()+TFTS(timeframeglobal)+string(i),zone_hi[i]);
      //    GlobalVariableSet("SSSR_LO_"+Symbol()+TFTS(timeframeglobal)+string(i),zone_lo[i]);
      //    GlobalVariableSet("SSSR_HITS_"+Symbol()+TFTS(timeframeglobal)+string(i),zone_hits[i]);
      //    GlobalVariableSet("SSSR_STRENGTH_"+Symbol()+TFTS(timeframeglobal)+string(i),zone_strength[i]);
      //    GlobalVariableSet("SSSR_AGE_"+Symbol()+TFTS(timeframeglobal)+string(i),zone_start[i]);
      //   }

      //nearest zones
      double price=SymbolInfoDouble(Symbol(),SYMBOL_BID);
      if(zone_lo[i]>lower_nerest_zone_P2 && price>zone_lo[i])
        {
         lower_nerest_zone_P1=zone_hi[i];
         lower_nerest_zone_P2=zone_lo[i];
         higher_zone_type=zone_type[i];/*new  todo*/
         lower_zone_strength=zone_strength[i];/*new  todo*/
        }
      if(zone_hi[i]<higher_nerest_zone_P1 && price<zone_hi[i])
        {
         higher_nerest_zone_P1=zone_hi[i];
         higher_nerest_zone_P2=zone_lo[i];
         lower_zone_type=zone_type[i];/*new  todo*/
         higher_zone_strength=zone_strength[i];/*new  todo*/
        }
     }
   ner_hi_zone_P1[0]=higher_nerest_zone_P1;
   ner_hi_zone_P2[0]=higher_nerest_zone_P2;
   ner_lo_zone_P1[0]=lower_nerest_zone_P1;
   ner_lo_zone_P2[0]=lower_nerest_zone_P2;

   ner_hi_zone_strength[0]=higher_zone_strength;/*new*/
   ner_lo_zone_strength[0]=lower_zone_strength;/*new*/
   if(ner_hi_zone_P1[0]==ner_lo_zone_P1[0])/*new*/
      ner_price_inside_zone[0]=higher_zone_type;
   else
      ner_price_inside_zone[0]=0;

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Fractal(int M,int P,int shift)
  {
   if(timeframeglobal>P)
      P=timeframeglobal;

   P=int(P/int(timeframeglobal)*2+MathCeil(P/timeframeglobal/2));

   if(shift<P)
      return(false);

   if(shift>Bars(Symbol(),timeframeglobal)-P-1)
      return(false);

   double High[],Low[];
   ArraySetAsSeries(High,true);
   CopyHigh(Symbol(),timeframeglobal,0,shift+P+1,High);
   ArraySetAsSeries(Low,true);
   CopyLow(Symbol(),timeframeglobal,0,shift+P+1,Low);

   for(int i=1; i<=P; i++)
     {
      if(M==UP_POINT)
        {
         if(High[shift+i]>High[shift])
            return(false);
         if(High[shift-i]>=High[shift])
            return(false);
        }
      if(M==DN_POINT)
        {
         if(Low[shift+i]<Low[shift])
            return(false);
         if(Low[shift-i]<=Low[shift])
            return(false);
        }
     }
   return(true);
  }
//+------------------------------------------------------------------+
void showLabels()
  {
   datetime Time=iTime(NULL,timeframeglobal,cnt);
//  CopyTime(Symbol(),timeframe,cnt,1,Time);
//  ArraySetAsSeries(Time,true);
   for(int i=0; i<zone_count; i++)
     {
      string lbl;
      if(zone_strength[i]==ZONE_PROVEN)
         lbl="Proven";
      else
         if(zone_strength[i]==ZONE_VERIFIED)
            lbl="Verified";
         else
            if(zone_strength[i]==ZONE_UNTESTED)
               lbl="Untested";
            else
               if(zone_strength[i]==ZONE_TURNCOAT)
                  lbl="Turncoat";
               else
                  lbl="Weak";

      if(zone_type[i]==ZONE_SUPPORT)
         lbl=lbl+" "+sup_name;
      else
         lbl=lbl+" "+res_name;

      if(zone_hits[i]>0 && zone_strength[i]>ZONE_UNTESTED)
        {
         if(zone_hits[i]==1)
            lbl=lbl+", "+test_name+"="+string(zone_hits[i]);
         else
            lbl=lbl+", "+test_name+"="+string(zone_hits[i]);
        }

      int adjust_hpos;
      long wbpc=ChartGetInteger(0,CHART_VISIBLE_BARS);
      int k=PeriodSeconds(timeframeglobal)/10+(StringLen(lbl));

      if(wbpc<80)
         adjust_hpos=int(Time)+k*1;
      else
         if(wbpc<125)
            adjust_hpos=int(Time)+k*2;
         else
            if(wbpc<250)
               adjust_hpos=int(Time)+k*4;
            else
               if(wbpc<480)
                  adjust_hpos=int(Time)+k*8;
               else
                  if(wbpc<950)
                     adjust_hpos=int(Time)+k*16;
                  else
                     adjust_hpos=int(Time)+k*32;

      int shift=k*zone_label_shift;
      double vpos=zone_hi[i]-(zone_hi[i]-zone_lo[i])/3;

      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
         continue;
      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
         continue;
      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
         continue;

      string s=prefix+string(i)+"LBL";
      ObjectCreate(0,s,OBJ_TEXT,0,0,0);
      ObjectSetInteger(0,s,OBJPROP_TIME,adjust_hpos+shift);
      ObjectSetDouble(0,s,OBJPROP_PRICE,vpos);
      ObjectSetString(0,s,OBJPROP_TEXT,lbl);
      ObjectSetString(0,s,OBJPROP_FONT,Text_font);
      ObjectSetInteger(0,s,OBJPROP_FONTSIZE,Text_size);
      ObjectSetInteger(0,s,OBJPROP_COLOR,Text_color);
     }
  }
//+------------------------------------------------------------------+
void DeleteZones()
  {
//int len=5;
   int len=StringLen(prefix);/*new*/

   int i=0;

   while(i<ObjectsTotal(0,0,-1))
     {
      string objName=ObjectName(0,i,0,-1);
      if(StringSubstr(objName,0,len)!=prefix)
        {
         i++;
         continue;
        }
      ObjectDelete(0,objName);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TFTS(int tf) //--- Timeframe to string
  {
   string tfs;

   switch(tf)
     {
      case PERIOD_M1:
         tfs="M1";
         break;
      case PERIOD_M2:
         tfs="M2";
         break;
      case PERIOD_M3:
         tfs="M3";
         break;
      case PERIOD_M4:
         tfs="M4";
         break;
      case PERIOD_M5:
         tfs="M5";
         break;
      case PERIOD_M6:
         tfs="M6";
         break;
      case PERIOD_M10:
         tfs="M10";
         break;
      case PERIOD_M12:
         tfs="M12";
         break;
      case PERIOD_M15:
         tfs="M15";
         break;
      case PERIOD_M20:
         tfs="M20";
         break;
      case PERIOD_M30:
         tfs="M30";
         break;
      case PERIOD_H1:
         tfs="H1";
         break;
      case PERIOD_H2:
         tfs="H2";
         break;
      case PERIOD_H3:
         tfs="H3";
         break;
      case PERIOD_H4:
         tfs="H4";
         break;
      case PERIOD_H6:
         tfs="H6";
         break;
      case PERIOD_H8:
         tfs="H8";
         break;
      case PERIOD_H12:
         tfs="H12";
         break;
      case PERIOD_D1:
         tfs="D1";
         break;
      case PERIOD_W1:
         tfs="W1";
         break;
      case PERIOD_MN1:
         tfs="MN1";
         break;
     }
   return(tfs);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void FastFractals()
  {
//--- FastFractals
   int shift;

   int limit=MathMin(Bars(Symbol(),timeframeglobal)-1,BackLimit+cnt);
   limit=MathMin(limit,ArraySize(FastUpPts)-1); /*new*/ /*todo check*/
   int P1=int(timeframeglobal*fractal_fast_factor);
   double High[],Low[];

   ArraySetAsSeries(High,true);
   CopyHigh(Symbol(),timeframeglobal,0,limit+1,High);
   ArraySetAsSeries(Low,true);
   CopyLow(Symbol(),timeframeglobal,0,limit+1,Low);

   FastUpPts[0] = 0.0;
   FastUpPts[1] = 0.0;
   FastDnPts[0] = 0.0;
   FastDnPts[1] = 0.0;

   for(shift=limit; shift>cnt+1; shift--)
     {
      if(Fractal(UP_POINT,P1,shift)==true)
         FastUpPts[shift]=High[shift];
      else
         FastUpPts[shift]=0.0;

      if(Fractal(DN_POINT,P1,shift)==true)
         FastDnPts[shift]=Low[shift];
      else
         FastDnPts[shift]=0.0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SlowFractals()
  {
//--- SlowFractals
   int shift;
   int limit=MathMin(Bars(Symbol(),timeframeglobal)-1,BackLimit+cnt);
   limit=MathMin(limit,ArraySize(SlowUpPts)-1);/*new*/ /*todo check*/

   int P2=int(timeframeglobal*fractal_slow_factor);
   double High[],Low[];
   ArraySetAsSeries(High,true);
   CopyHigh(Symbol(),timeframeglobal,0,limit+1,High);
   ArraySetAsSeries(Low,true);
   CopyLow(Symbol(),timeframeglobal,0,limit+1,Low);
   SlowUpPts[0] = 0.0;
   SlowUpPts[1] = 0.0;
   SlowDnPts[0] = 0.0;
   SlowDnPts[1] = 0.0;

   for(shift=limit; shift>cnt+1; shift--)
     {
      if(Fractal(UP_POINT,P2,shift)==true)
         SlowUpPts[shift]=High[shift];
      else
         SlowUpPts[shift]=0.0;

      if(Fractal(DN_POINT,P2,shift)==true)
         SlowDnPts[shift]=Low[shift];
      else
         SlowDnPts[shift]=0.0;

      //Print(shift);
      ner_hi_zone_P1[shift]=0;
      ner_hi_zone_P2[shift]=0;
      ner_lo_zone_P1[shift]=0;
      ner_lo_zone_P2[shift]=0;
      //Print(shift);
      ner_hi_zone_strength[shift]=0;
      ner_lo_zone_strength[shift]=0;
      ner_price_inside_zone[shift]=0;


     }
  }
//+------------------------------------------------------------------+
