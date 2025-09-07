//+------------------------------------------------------------------+
//|                                     ictsilverbullet_includes.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CPoint                                                     |
//+------------------------------------------------------------------+
class CPoint
  {
private:
   double            price;
   datetime          time;
public:
                     CPoint();
                     CPoint(const double p, const datetime t);
                    ~CPoint() {};
   void              setPoint(const double p, const datetime t);
   bool              operator==(const CPoint &other) const;
   bool              operator!=(const CPoint &other) const;
   void              operator=(const CPoint &other);
   double            getPrice() const;
   datetime          getTime() const;
  };
//---
CPoint::CPoint(void)
  {
   price = 0;
   time = 0;
  }
//---
CPoint::CPoint(const double p, const datetime t)
  {
   price = p;
   time = t;
  }
//---
void CPoint::setPoint(const double p, const datetime t)
  {
   price = p;
   time = t;
  }
//---
bool CPoint::operator==(const CPoint &other) const
  {
   return price == other.price && time == other.time;
  }
//---
bool CPoint::operator!=(const CPoint &other) const
  {
   return !operator==(other);
  }
//---
void CPoint::operator=(const CPoint &other)
  {
   price = other.price;
   time = other.time;
  }
//---
double CPoint::getPrice(void) const
  {
   return(price);
  }
//---
datetime CPoint::getTime(void) const
  {
   return(time);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CFairValueGap : public CObject
  {
public:
   int               direction; //up or dn
   datetime          time;
   double            high;
   double            low;
   void              draw(datetime timeStart, datetime timeEnd)
     {
      string objFvg = "SB FVG " + TimeToString(time);
      ObjectCreate(0,objFvg,OBJ_RECTANGLE,0,time, low, timeStart,high);
      ObjectSetInteger(0,objFvg,OBJPROP_FILL, true);
      ObjectSetInteger(0,objFvg, OBJPROP_COLOR, clrLightGray);
      string objTrade = "SB Trade " + TimeToString(time);
      ObjectCreate(0,objTrade,OBJ_RECTANGLE, 0, timeStart, low, timeEnd,high);
      ObjectSetInteger(0,objTrade,OBJPROP_FILL,true);
      ObjectSetInteger(0, objTrade, OBJPROP_COLOR, clrGray);
     }
   void              drawTradeLevels(double tp, double sl, datetime timeStart, datetime timeEnd)
     {
      string objTp = "SB TP " + TimeToString(time);
      ObjectCreate(0,objTp,OBJ_RECTANGLE,0, timeStart, (direction > 0 ? high : low), timeEnd, tp);
      ObjectSetInteger(0,objTp,OBJPROP_FILL, true);
      ObjectSetInteger(0,objTp,OBJPROP_COLOR, clrLightGreen);
      string objsl = "SB SL " + TimeToString(time);
      ObjectCreate(0,objsl,OBJ_RECTANGLE,0, timeStart, (direction > 0 ? high : low), timeEnd, sl);
      ObjectSetInteger(0,objsl, OBJPROP_FILL, true);
      ObjectSetInteger(0,objsl, OBJPROP_COLOR, clrOrange);
     }
  };