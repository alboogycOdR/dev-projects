
//+------------------------------------------------------------------+
//|  ADR 1.00.mq4                                                    |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

#property indicator_chart_window


extern int TimeZoneOfData= 0;       // chart time zone (from GMT)
extern int TimeZoneOfSession= 0;   // dest time zone (from GMT) 

int ADROpenHour= 0;         // start time for range calculation (LEAVE AT 0. PROGRAM DOESN'T WORK PROPERLY OTHERWISE.)
int ADRCloseHour= 24;        // end time for range calculation  (LEAVE AT 24. PROGRAM DOESN'T WORK PROPERLY OTHERWISE.)

int ATRTimeFrame= PERIOD_D1; // timeframe for ATR (LEAVE AT PERIOD_D1)
extern int ATRPeriod= 5;           // period for ATR

extern bool UseManualADR= false;    // allows use of manual value for range
extern int ManualADRValuePips= 0;   // manual value for range

extern int LineStyle= 2;
extern int LineThickness1= 1;       // normal thickness
extern color LineColor1= Orange;    // normal color
extern int LineThickness2= 2;       // thickness for range reached state
extern color LineColor2= Blue;       // color for range reached state


bool ShowLevelPrices= true;         // show prices on h-lines
extern int BarForLabels= -10;       // number of bars from right, where lines labels will be shown

extern bool DebugLogger = false;

//used for new adr calculation
extern int First_av = 5;
extern int Second_av = 10;
extern int Third_av = 20;

double mPoint;




//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
   Print("Period= ", Period());
   Print("Point= ", Point);
   
//   bool jpy= StringFind(Symbol(), "JPY")!=-1;
   
// if ((jpy && Point!=0.01) || (!jpy && Point!=0.0001)) {
//     Alert("[DailyADR] Internal Error: Incorrect Pip Size for " + Symbol() + " ("+ DoubleToStr(Point,4)+")");
// }

  if(Point==0.00001) {mPoint=0.0001;}//Alpari
  else if(Point==0.001) {mPoint=0.01;}
  else {mPoint = Point;}//InterBankFX  
   
  if (First_av == 0 || Second_av == 0 || Third_av == 0)
      Alert("(First/Second/Third)_av inputs must not equal zero. Indicator will not run.");
   
   return(0);
}


int deinit()
{
   int obj_total= ObjectsTotal();
   
   for (int i= obj_total; i>=0; i--) {
      string name= ObjectName(i);
    
      if (StringSubstr(name,0,5)=="[ADR]") 
         ObjectDelete(name);
   }
   
   return(0);
}
  
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
{
   static datetime timelastupdate= 0;
   static int lasttimeframe= 0,
              lastfirstbar= -1;
   
   int idxfirstbaroftoday= 0,
       idxfirstbarofyesterday= 0,
       idxlastbarofyesterday= 0;

   
   //---- exit if period is greater than daily charts
   if(Period() > 1440) {
      Alert("Error - Chart period is greater than 1 day.");
      return(-1); // then exit
   }

   if (DebugLogger) {
      Print("Local time current bar:", TimeToStr(Time[0]));
      Print("Dest  time current bar: ", TimeToStr(Time[0]- (TimeZoneOfData - TimeZoneOfSession)*3600), ", tzdiff= ", TimeZoneOfData - TimeZoneOfSession);
   }


   // let's find out which hour bars make today and yesterday
   ComputeDayIndices(TimeZoneOfData, TimeZoneOfSession, idxfirstbaroftoday, idxfirstbarofyesterday, idxlastbarofyesterday);


   // no need to update these buggers too often (the code below is a bit tricky, usually just the 
   // timelastupdate would be sufficient, but when turning on MT after the night there is just
   // the newest bar while the rest of the day is missing and updated a bit later).  Don't mess
   // with this unless you are absolutely sure you know what you're doing.
   if (Time[0]==timelastupdate && Period()==lasttimeframe && lastfirstbar==idxfirstbaroftoday) {
   //    return (0);
   }
      
      
   lasttimeframe= Period();
   timelastupdate= Time[0];
   lastfirstbar= idxfirstbaroftoday;
   


   //
   // okay, now we know where the days start and end
   //
      
      
   int tzdiff= TimeZoneOfData + TimeZoneOfSession,
       tzdiffsec= tzdiff*3600;


   datetime startofday= Time[idxfirstbaroftoday];  // datetime (x-value) for labes on horizontal bars

   //double adr= iATR(NULL, ATRTimeFrame, ATRPeriod, 1);
   double adr;
   if (UseManualADR)
      adr = ManualADRValuePips*Point;
   else
   {
      int R1=0,R5=0,R10=0,R20=0, i;

      R1 =  (iHigh(NULL,PERIOD_D1,1)-iLow(NULL,PERIOD_D1,1))/mPoint;
      for(i=1;i<=First_av;i++)
      R5    =    R5  +  (iHigh(NULL,PERIOD_D1,i)-iLow(NULL,PERIOD_D1,i))/mPoint;
      for(i=1;i<=Second_av;i++)
      R10   =    R10 +  (iHigh(NULL,PERIOD_D1,i)-iLow(NULL,PERIOD_D1,i))/mPoint;
      for(i=1;i<=Third_av;i++)
      R20   =    R20 +  (iHigh(NULL,PERIOD_D1,i)-iLow(NULL,PERIOD_D1,i))/mPoint;

      R5 = R5/First_av;
      R10 = R10/Second_av;
      R20 = R20/Third_av;
      adr  =  (R1+R5+R10+R20)/4;
      adr = adr * mPoint; //this indicator expects adr in Points not Pips
   }   

   // 
   // walk forward through today and collect high/lows within the same day
   //
   double today_high,
          today_low,
          today_open= 0,
          today_range,
          lasthigh, lastlow,last,
          to_long_adr= 0,
          to_short_adr= 0,
          adr_high= 0,
          adr_low= 0;
   bool adr_reached= false, lastreached;

   // new-start
   for (int j= idxfirstbaroftoday; j>=0; j--) {
      
      datetime bartime= Time[j]-tzdiffsec;
      
      if (TimeHour(bartime)>=ADROpenHour && TimeHour(bartime)<ADRCloseHour) {
      
         if (today_open==0) {
            today_open= Open[idxfirstbaroftoday];  // should be open of today start trading hour
            adr_high= today_open + adr;
            adr_low= today_open - adr;
            today_high= today_open;
            today_low= today_open;

         }

         for (int k= 0; k<3; k++) {
      
            double price;
         
            switch (k) {
               case 0: price= Low[j]; break;
               case 1: price= High[j]; break;
               case 2: price= Close[j]; break;
            }

            lasthigh= today_high;
            lastlow= today_low;
            lastreached= adr_reached;
                  
            today_high= MathMax(today_high, price);
            today_low= MathMin(today_low, price);
         
            today_range= today_high - today_low;
            adr_reached= today_range >= adr - Point/2;   // "Point/2" to avoid rounding problems (double variables)
         
         
            // adr-high
            if (!lastreached && !adr_reached) {
               adr_high= today_low + adr;
            }
            else
            if (!lastreached && adr_reached && price>=lasthigh) {
               adr_high= today_low + adr;
            }
            else
            if (!lastreached && adr_reached && price<lasthigh) {
               adr_high= lasthigh;
            }
            else {
               adr_high= adr_high;
            }
         

            // adr-low
            if (!lastreached && !adr_reached) {
               if (DebugLogger) {
                  Print("#: ", j, " ", "adr_low= today_high-adr ", today_high, "-", adr, "= ", today_high-adr);
               }
               adr_low= today_high - adr;
            }
            else
            if (!lastreached && adr_reached && price>=lastlow) {
               if (DebugLogger) {
                  Print("#: ", j, " ", "adr_low= today_low", today_low);
               }
               adr_low= today_low;
            }
            else
            if (!lastreached && adr_reached && price<lastlow) {
               if (DebugLogger) {
                  Print("#: ", j, " ", "adr_low= lasthigh-adr ", lasthigh, "-", adr, "= ", lasthigh-adr);
               }
               adr_low= lasthigh - adr;
            }
            else {
               if (DebugLogger) {
                  Print("#: ", j, " ", "adr_low= adr_low ", adr_low);
               }
               adr_low= adr_low;
            }

            to_long_adr= adr_high - Close[j];
            to_short_adr= Close[j] - adr_low;
         
            if (DebugLogger) {
               Print("#:", j, " ", TimeToStr(bartime, TIME_MINUTES), " High-Low/adr-Reached ", today_high-today_low, "/", adr_reached);
            
               Print("#: ", j, " ", " Price= ", price, " (k= ", k, " [0=low, 1=high, 2=close]])");
         
               Print("#: ", j, " ", "ADR= ", adr, ", O= ", today_high, ", P= ", today_low, 
                              ", Q= ", today_high-today_low, ", R= ", adr_reached, 
                              ", S= ", adr_high, ", T= ", adr_low, ", U= ", to_long_adr, ", V= ", to_short_adr);
            }
         }
      }
   }
   // new-end
   
   if (DebugLogger) 
      Print("Timezoned values: t-open= ", today_open, ", t-high =", today_high, ", t-low= ", today_low);
      

      
   // draw the vertical bars that marks the time span
   SetTimeLine("today start", "ADR Start", idxfirstbaroftoday, CadetBlue, Low[idxfirstbaroftoday]- 10*Point);
   
   color col= LineColor1;
   int thickness= LineThickness1;
   
   if (adr_reached) {
      col= LineColor2;
      thickness= LineThickness2;
   }
   
   SetLevel("ADR High", adr_high, col, LineStyle, thickness, startofday);
   SetLevel("ADR Low", adr_low, col, LineStyle, thickness, startofday);
   
   
   string reached_str= "Yes";
   if (!adr_reached)
      reached_str= "No";
      
      

   string comment=
          
            
            "ADR " + DoubleToStr(MathRound((adr/Point)),0) + 
                           "  Today " + DoubleToStr(MathRound(((today_high-today_low)/Point)),0) ;
                           


   /*if (GlobalVariableCheck(Symbol()+"[PIVOT]YesterdayHigh")) {
      double 
         yesterday_high= GlobalVariableGet(Symbol()+"[PIVOT]YesterdayHigh"),
         yesterday_low= GlobalVariableGet(Symbol()+"[PIVOT]YesterdayLow"),
         yesterday_close= GlobalVariableGet(Symbol()+"[PIVOT]YesterdayClose");
      
      comment= comment + "TzPivots Yesterday: High= "+DoubleToStr(yesterday_high,Digits) +
                              ", Low= "+DoubleToStr(yesterday_low,Digits) +
                              ", Close= "+DoubleToStr(yesterday_close,Digits) + 
                              "\n";
   }*/                           
   
   Comment(comment);


   return(0);
}

 
//+------------------------------------------------------------------+
//| Compute index of first/last bar of yesterday and today           |
//+------------------------------------------------------------------+
void ComputeDayIndices(int tzlocal, int tzdest, int &idxfirstbaroftoday, int &idxfirstbarofyesterday, int &idxlastbarofyesterday)
{     
   int tzdiff= tzlocal + tzdest,
       tzdiffsec= tzdiff*3600,
       dayminutes= 24 * 60,
       barsperday= dayminutes/Period();
   
   int dayofweektoday= TimeDayOfWeek(Time[0] - tzdiffsec),  // what day is today in the dest timezone?
       dayofweektofind= -1; 

   //
   // due to gaps in the data, and shift of time around weekends (due 
   // to time zone) it is not as easy as to just look back for a bar 
   // with 00:00 time
   //
   
   idxfirstbaroftoday= 0;
   idxfirstbarofyesterday= 0;
   idxlastbarofyesterday= 0;
       
   switch (dayofweektoday) {
      case 6: // sat
      case 0: // sun
      case 1: // mon
            dayofweektofind= 5; // yesterday in terms of trading was previous friday
            break;
            
      default:
            dayofweektofind= dayofweektoday -1; 
            break;
   }
   
   if (DebugLogger) {
      Print("Dayofweektoday= ", dayofweektoday);
      Print("Dayofweekyesterday= ", dayofweektofind);
   }
       
       
   // search  backwards for the last occrrence (backwards) of the day today (today's first bar)
   for (int i= 0; i<=barsperday+1; i++) {
      datetime timet= Time[i] - tzdiffsec;
      // Print(Symbol(), " DayofWeek[", i, ,"]= ", TimeDayOfWeek(timet), " (", dayofweektoday, ") ", TimeToStr(timet));
      if (TimeDayOfWeek(timet)!=dayofweektoday) {
         idxfirstbaroftoday= i-1;
         break;
      }
   }
   

   // Print(Symbol(), " idxfirstoftoday ", idxfirstbaroftoday);

   // search  backwards for the first occrrence (backwards) of the weekday we are looking for (yesterday's last bar)
   for (int j= 0; j<=2*barsperday+1; j++) {
      datetime timey= Time[i+j] - tzdiffsec;
      if (TimeDayOfWeek(timey)==dayofweektofind) {  // ignore saturdays (a Sa may happen due to TZ conversion)
         idxlastbarofyesterday= i+j;
         break;
      }
   }


   // search  backwards for the first occurrence of weekday before yesterday (to determine yesterday's first bar)
   for (j= 1; j<=barsperday; j++) {
      datetime timey2= Time[idxlastbarofyesterday+j] - tzdiffsec;
      if (TimeDayOfWeek(timey2)!=dayofweektofind) {  // ignore saturdays (a Sa may happen due to TZ conversion)
         idxfirstbarofyesterday= idxlastbarofyesterday+j-1;
         break;
      }
   }


   if (DebugLogger) {
      Print("Dest time zone\'s current day starts:", TimeToStr(Time[idxfirstbaroftoday]), 
                                                      " (local time), idxbar= ", idxfirstbaroftoday);

      Print("Dest time zone\'s previous day starts:", TimeToStr(Time[idxfirstbarofyesterday]), 
                                                      " (local time), idxbar= ", idxfirstbarofyesterday);
      Print("Dest time zone\'s previous day ends:", TimeToStr(Time[idxlastbarofyesterday]), 
                                                      " (local time), idxbar= ", idxlastbarofyesterday);
   }
}


//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
void SetLevel(string text, double level, color col1, int linestyle, int thickness, datetime startofday)
{
   int digits= Digits;
   string labelname= "[ADR] " + text + " Label",
          linename= "[ADR] " + text + " Line",
          pricelabel; 

   // create or move the horizontal line   
   if (ObjectFind(linename) != 0) {
      ObjectCreate(linename, OBJ_TREND, 0, startofday, level, Time[0],level);
   }

   ObjectSet(linename, OBJPROP_BACK, true);
   ObjectSet(linename, OBJPROP_STYLE, linestyle);
   ObjectSet(linename, OBJPROP_COLOR, col1);
   ObjectSet(linename, OBJPROP_WIDTH, thickness);
   ObjectMove(linename, 1, Time[0],level);
   ObjectMove(linename, 0, startofday, level);

   

   // put a label on the line   
   if (ObjectFind(labelname) != 0) 
      ObjectCreate(labelname, OBJ_TEXT, 0, Time[0]/* MathMin(Time[BarForLabels], startofday + 2*Period()*60)*/, level);

   ObjectMove(labelname, 0, Time[0] - BarForLabels*Period()*60, level);

   pricelabel= " " + text;
   if (ShowLevelPrices && StrToInteger(text)==0) 
      pricelabel= pricelabel + ": "+DoubleToStr(level, Digits);
   
   ObjectSetText(labelname, pricelabel, 8, "Arial", col1);
}
      

//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
void SetTimeLine(string objname, string text, int idx, color col1, double vleveltext) 
{
   string name= "[ADR] " + objname;
   int x= Time[idx];

   if (ObjectFind(name) != 0) 
      ObjectCreate(name, OBJ_TREND, 0, x, 0, x, 100);

   ObjectMove(name, 0, x, 0);
   ObjectMove(name, 1, x, 100);
   ObjectSet(name, OBJPROP_BACK, true);
   ObjectSet(name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSet(name, OBJPROP_COLOR, DarkGray);
   
   if (ObjectFind(name + " Label") != 0) 
      ObjectCreate(name + " Label", OBJ_TEXT, 0, x, vleveltext);

   ObjectMove(name + " Label", 0, x, vleveltext);
   ObjectSetText(name + " Label", text, 8, "Arial", col1);
}