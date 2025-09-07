//+------------------------------------------------------------------+
//|                                                   SweetSpots.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright Shimodax"
#property link      "http://www.strategybuilderfx.com"

#property indicator_chart_window


extern int LinesAboveBelow= 10;
extern color LineColorMain= LightGray;
extern color LineColorSub= Gray;

double dPt;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
{
   dPt = Point;
   if(Digits==3||Digits==5){
      dPt=dPt*10;
   } 
   return(0);
}

int deinit()
{
   int obj_total= ObjectsTotal();
   
   for (int i= obj_total; i>=0; i--) {
      string name= ObjectName(i);
    
      if (StringSubstr(name,0,11)=="[SweetSpot]") 
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
   static datetime lasttimeframe= 0;
   
    
   // no need to update these buggers too often   
   if (CurTime()-timelastupdate < 600 && Period()==lasttimeframe)
      return (0);
      
   int i, ssp1, style, ssp;
   double ds1;
   color linecolor;
   
   ssp1= Bid / dPt;
   ssp1= ssp1 - ssp1%50;

   for (i= -LinesAboveBelow; i<LinesAboveBelow; i++) {
      ssp= ssp1+(i*50); 
      
      if (ssp%100==0) {
         style= STYLE_SOLID;
         linecolor= LineColorMain;
      }
      else {
         style= STYLE_DOT;
         linecolor= LineColorSub;
      }
      
      ds1= ssp*dPt;
      SetLevel(DoubleToStr(ds1,Digits), ds1,  linecolor, style, Time[10]);
   }

   return(0);
}


//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
void SetLevel(string text, double level, color col1, int linestyle, datetime startofday)
{
   int digits= Digits;
   string linename= "[SweetSpot] " + text + " Line",
          pricelabel; 

   // create or move the horizontal line   
   if (ObjectFind(linename) != 0) {
      ObjectCreate(linename, OBJ_HLINE, 0, 0, level);
      ObjectSet(linename, OBJPROP_STYLE, linestyle);
      ObjectSet(linename, OBJPROP_COLOR, col1);
      ObjectSet(linename, OBJPROP_WIDTH, 0);
   }
   else {
      ObjectMove(linename, 0, Time[0], level);
   }
}
      