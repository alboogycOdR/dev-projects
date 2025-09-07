//+------------------------------------------------------------------+
//| Pivot based SL/TP helper                                         |
//+------------------------------------------------------------------+
#ifndef __PIVOTS_MQH__
#define __PIVOTS_MQH__

// Settings
struct PivotSettings
  {
   int    lookback;     // bars to look back
   int    leftLen;      // pivot left length
   int    rightLen;     // pivot right length
   bool   drawZigZag;   // draw zigzag lines
  };

// internal storage for zigzag
static datetime lastPivotTime=0;
static double   lastPivotPrice=0;
static int      zigzagIndex=0;

// simple helper to check pivot high
inline bool IsPivotHigh(int shift,int leftLen,int rightLen)
  {
   double val=High[shift];
   for(int i=1;i<=leftLen;i++)
      if(High[shift+i]>=val)
         return(false);
   for(int i=1;i<=rightLen;i++)
      if(High[shift-i]>val)
         return(false);
   return(true);
  }

inline bool IsPivotLow(int shift,int leftLen,int rightLen)
  {
   double val=Low[shift];
   for(int i=1;i<=leftLen;i++)
      if(Low[shift+i]<=val)
         return(false);
   for(int i=1;i<=rightLen;i++)
      if(Low[shift-i]<val)
         return(false);
   return(true);
  }

// find deepest pivot low below current close
inline double FindPivotLowBelowClose(const PivotSettings &p,int &shiftOut)
  {
   double best=EMPTY_VALUE;
   shiftOut=-1;
   int start=p.rightLen;
   int end=p.lookback+p.rightLen;
   for(int i=start;i<=end && i<Bars(_Symbol,_Period);i++)
     {
      if(IsPivotLow(i,p.leftLen,p.rightLen) && Low[i]<Close[0])
        {
         if(best==EMPTY_VALUE || Low[i]<best)
           { best=Low[i]; shiftOut=i; }
        }
     }
   return(best);
  }

// find highest pivot high above current close
inline double FindPivotHighAboveClose(const PivotSettings &p,int &shiftOut)
  {
   double best=EMPTY_VALUE;
   shiftOut=-1;
   int start=p.rightLen;
   int end=p.lookback+p.rightLen;
   for(int i=start;i<=end && i<Bars(_Symbol,_Period);i++)
     {
      if(IsPivotHigh(i,p.leftLen,p.rightLen) && High[i]>Close[0])
        {
         if(best==EMPTY_VALUE || High[i]>best)
           { best=High[i]; shiftOut=i; }
        }
     }
   return(best);
  }

// draw zigzag line when new pivot found
inline void UpdateZigZag(bool isHigh,int shift,const PivotSettings &p)
  {
   if(!p.drawZigZag || shift<0) return;
   datetime t=Time[shift];
   double   price=isHigh?High[shift]:Low[shift];
   if(lastPivotTime!=0)
     {
      string name="zz"+IntegerToString(zigzagIndex++);
      ObjectCreate(0,name,OBJ_TREND,0,lastPivotTime,lastPivotPrice,t,price);
      ObjectSetInteger(0,name,OBJPROP_COLOR,isHigh?clrRed:clrGreen);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
     }
   lastPivotTime=t;
   lastPivotPrice=price;
  }

#endif // __PIVOTS_MQH__
