//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


enum ENUM_CANDLESTICK_PATTERN
  {
   PATTERN_IS_NONE=0,
   PATTERN_IS_DOJI=2,
   PATTERN_IS_DRAGONFLY=3,
   PATTERN_IS_GRAVESTONE=4,
   PATTERN_IS_SPINNINGTOPBULLISH=5,
   PATTERN_IS_SPINNINGTOPBEARISH=6,
   PATTERN_IS_MARUBOZUUP=7,
   PATTERN_IS_MARUBOZUDOWN=8,
   PATTERN_IS_HAMMER=9,
   PATTERN_IS_HANGINMAN=10,
   PATTERN_IS_INVERTEDHAMMER=11,
   PATTERN_IS_SHOOTINGSTAR=12,
   PATTERN_IS_BULLISHENGULFING=13,
   PATTERN_IS_BEARISHENGULFING=14,
   PATTERN_IS_TWEEZERTOP=15,
   PATTERN_IS_TWEEZERBOTTOM=16,
   PATTERN_IS_THREEWHITESOLDIERS=17,
   PATTERN_IS_THREECROWS=18,
   PATTERN_IS_THREEINSIDEUP=19,
   PATTERN_IS_THREEINSIDEDOWN=20,
   PATTERN_IS_MORNINGSTAR=21,
   PATTERN_IS_EVENINGSTAR=22,
   PATTERN_IS_HARAMIDOWN=23,
   PATTERN_IS_BULLPIERCING=24,
   PATTERN_IS_DARKCLOUD=25,
   PATTERN_IS_HARAMIUP=26,
   PATTERN_IS_BULLCROSS=27,
   PATTERN_IS_BEARCROSS=28
  };
enum ENUM_TYPE_OF_PATTERN
  {
   UNCERTAIN=0,      //UNCERTAIN
   BULLISH=1,        //BULLISH
   BEARISH=-1,        //BEARISH
  };



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isBullCross(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   datetime time=iTime(Instrument,TimeFrame,1);
   double open=iOpen(Instrument,TimeFrame,1);
   double high=iHigh(Instrument,TimeFrame,1);
   double low=iLow(Instrument,TimeFrame,1);
   double close1=iClose(Instrument,TimeFrame,1);
   double open2=iOpen(Instrument,TimeFrame,2);
   double high2=iHigh(Instrument,TimeFrame,2);
   double low2=iLow(Instrument,TimeFrame,2);
   double close2=iClose(Instrument,TimeFrame,2);
   double candleSize2=high2-low2;
   double candleMidPoint2=high2-(candleSize2/2);

//if((open<close1)&&(open2>close2)&&(open<low2)&&(close1>candleMidPoint2)&&(close1<high2))
//  {
//   //Print("Piercing");
//   return true;
//  }
//else
//  {
//   return false;
//  }

   if(
      (open2>close2) &&
      (open>close2) &&
      (open<open2)&&
      (close1>open2))
     {
      return true;
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isBearCross(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   datetime time=iTime(Instrument,TimeFrame,1);
   double open=iOpen(Instrument,TimeFrame,1);
   double high=iHigh(Instrument,TimeFrame,1);
   double low=iLow(Instrument,TimeFrame,1);
   double close1=iClose(Instrument,TimeFrame,1);
   double open2=iOpen(Instrument,TimeFrame,2);
   double high2=iHigh(Instrument,TimeFrame,2);
   double low2=iLow(Instrument,TimeFrame,2);
   double close2=iClose(Instrument,TimeFrame,2);
   double candleSize2=high2-low2;
   double candleMidPoint2=high2-(candleSize2/2);

//if((open<close1)&&(open2>close2)&&(open<low2)&&(close1>candleMidPoint2)&&(close1<high2))
//  {
//   //Print("Piercing");
//   return true;
//  }
//else
//  {
//   return false;
//  }

   if(
      (open2<close2) &&
      (open<close2) &&
      (open>open2)&&
      (close1<open2))
     {
      return true;
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isBullPiercing(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   datetime time=iTime(Instrument,TimeFrame,1);
   double open=iOpen(Instrument,TimeFrame,1);
   double high=iHigh(Instrument,TimeFrame,1);
   double low=iLow(Instrument,TimeFrame,1);
   double close1=iClose(Instrument,TimeFrame,1);
   double open2=iOpen(Instrument,TimeFrame,2);
   double high2=iHigh(Instrument,TimeFrame,2);
   double low2=iLow(Instrument,TimeFrame,2);
   double close2=iClose(Instrument,TimeFrame,2);
   double candleSize2=high2-low2;
   double candleMidPoint2=high2-(candleSize2/2);

//if((open<close1)&&
//   (open2>close2)&&
//   (open<low2)&&
//   (close1>candleMidPoint2)&&
//   (close1<high2))
//  {
//   return true;
//  }
//else
//  {
//   return false;
//  }
   if((close1-open>AvgBody(1)) && // long white
      (open2-close2>AvgBody(1)) && // long black
      (close1>close2)           && // close1 inside previous body
      (close1<open2)            &&
      (MidOpenClose(2)<CloseAvg(2)) && // downtrend
      (open<low2))                // open lower than previous low
      return(true);
//---
   return(false);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MidOpenClose(int index)
  {
   return((iOpen(Symbol(),PERIOD_CURRENT,index)+iClose(Symbol(),PERIOD_CURRENT,index))/2.);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isDarkCloud(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   datetime time=iTime(Instrument,TimeFrame,1);
   double open=iOpen(Instrument,TimeFrame,1);
   double high=iHigh(Instrument,TimeFrame,1);
   double low=iLow(Instrument,TimeFrame,1);
   double close1=iClose(Instrument,TimeFrame,1);
   double open2=iOpen(Instrument,TimeFrame,2);
   double high2=iHigh(Instrument,TimeFrame,2);
   double low2=iLow(Instrument,TimeFrame,2);
   double close2=iClose(Instrument,TimeFrame,2);
   double candleSize2=high2-low2;
   double candleMidPoint2=high2-(candleSize2/2);


//Close[shift2]>Open[shift2])
//&& ((Open[shift1]>Close[shift2])
//&&
//   (Close[shift1]<Close[shift2]-((Close[shift2]-Open[shift2])/2)))

   if((close2-open2>AvgBody(1))  && // long body of the white candlestick (long white)
      (close1<close2)            && // followed by a black candlestick
      (close1>open2)             && // close1 within the previous candlestick body (white)
      (MidOpenClose(2)>CloseAvg(2))  && // uptrend
      (open>high2))                // open above the previous day's High price (open at new high)
     {
      return true;
     }
   else
     {
      return false;
     }

  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDojiNeutral(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(Body<Shadow*0.05 && !IsDojiGravestone(Instrument,TimeFrame,Shift) && !IsDojyDragonfly(Instrument,TimeFrame,Shift))
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDojyDragonfly(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(Body<Shadow*0.05 && iClose(Instrument,TimeFrame,Shift)>iHigh(Instrument,TimeFrame,Shift)-Shadow*0.05)
      return true;
   else
      return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
//double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
//if(Body<Shadow*0.05 && iClose(Instrument,TimeFrame,Shift)<iLow(Instrument,TimeFrame,Shift)+Shadow*0.05)
//   return true;
//else
//   return false;

// last completed bar is bearish (black day)
// the previous candle is bullish, its body is greater than average (long white)
// close1 price of the bearish candle is higher than open price of the bullish candle
// open price of the bearish candle is lower than close1 price of the bullish candle

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishHarami(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {


   if((iClose(Instrument,TimeFrame,1)<iOpen(Instrument,TimeFrame,1))               &&
      ((iClose(Instrument,TimeFrame,2)-iOpen(Instrument,TimeFrame,2))>AvgBody(1))  &&
      (iClose(Instrument,TimeFrame,1)>iOpen(Instrument,TimeFrame,2))               &&
      (iOpen(Instrument,TimeFrame,1)<iClose(Instrument,TimeFrame,2))               &&
      (MidPoint(2)>CloseAvg(2)))
     {
      return true;
     }
   else
     {
      return false;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishHarami(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {


   if((iClose(Instrument,TimeFrame,1)>iOpen(Instrument,TimeFrame,1))               &&
      ((iOpen(Instrument,TimeFrame,2)-iClose(Instrument,TimeFrame,2))>AvgBody(1))  &&
      (iClose(Instrument,TimeFrame,1)<iOpen(Instrument,TimeFrame,2))               &&
      (iOpen(Instrument,TimeFrame,1)>iClose(Instrument,TimeFrame,2))               &&
      (MidPoint(2)<CloseAvg(2)))
     {
      return true;
     }
   else
     {
      return false;
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDojiGravestone(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(Body<Shadow*0.05 && iClose(Instrument,TimeFrame,Shift)<iLow(Instrument,TimeFrame,Shift)+Shadow*0.05)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSpinningTopBullish(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)<iClose(Instrument,TimeFrame,Shift) && iClose(Instrument,TimeFrame,Shift)<iHigh(Instrument,TimeFrame,Shift)-Shadow*0.30 && iOpen(Instrument,TimeFrame,Shift)>iLow(Instrument,TimeFrame,Shift)+Shadow*0.30 && Body<Shadow*0.4 && Body>Shadow*0.05)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSpinningTopBearish(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)>iClose(Instrument,TimeFrame,Shift) && iOpen(Instrument,TimeFrame,Shift)<iHigh(Instrument,TimeFrame,Shift)-Shadow*0.30 && iClose(Instrument,TimeFrame,Shift)>iLow(Instrument,TimeFrame,Shift)+Shadow*0.30 && Body<Shadow*0.4 && Body>Shadow*0.05)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsMarubozuUp(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)<iClose(Instrument,TimeFrame,Shift) && iClose(Instrument,TimeFrame,Shift)>iHigh(Instrument,TimeFrame,Shift)-Shadow*0.02 && iOpen(Instrument,TimeFrame,Shift)<iLow(Instrument,TimeFrame,Shift)+Shadow*0.02 && Body>Shadow*0.95)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsMarubozuDown(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)>iClose(Instrument,TimeFrame,Shift) && iClose(Instrument,TimeFrame,Shift)<iHigh(Instrument,TimeFrame,Shift)+Shadow*0.02 && iOpen(Instrument,TimeFrame,Shift)>iLow(Instrument,TimeFrame,Shift)-Shadow*0.02 && Body>Shadow*0.95)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHammer(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)<iClose(Instrument,TimeFrame,Shift) && iClose(Instrument,TimeFrame,Shift)>iHigh(Instrument,TimeFrame,Shift)-Shadow*0.05 && Body<Shadow*0.4 && Body>Shadow*0.1)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHangingMan(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)>iClose(Instrument,TimeFrame,Shift) && iOpen(Instrument,TimeFrame,Shift)>iHigh(Instrument,TimeFrame,Shift)-Shadow*0.05 && Body<Shadow*0.4 && Body>Shadow*0.1)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsInvertedHammer(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)<iClose(Instrument,TimeFrame,Shift) && iOpen(Instrument,TimeFrame,Shift)<iLow(Instrument,TimeFrame,Shift)+Shadow*0.05 && Body<Shadow*0.4 && Body>Shadow*0.1)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsShootingStar(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   double Shadow=iHigh(Instrument,TimeFrame,Shift)-iLow(Instrument,TimeFrame,Shift);
   double Body=MathAbs(iClose(Instrument,TimeFrame,Shift)-iOpen(Instrument,TimeFrame,Shift));
   if(iOpen(Instrument,TimeFrame,Shift)>iClose(Instrument,TimeFrame,Shift) && iClose(Instrument,TimeFrame,Shift)<iLow(Instrument,TimeFrame,Shift)+Shadow*0.05 && Body<Shadow*0.4 && Body>Shadow*0.1)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   double ShadowPrev=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double BodyCurr=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   if(IsDojiNeutral(Instrument,TimeFrame,j))
      return false;
   if(iClose(Instrument,TimeFrame,j)<iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,i)>iHigh(Instrument,TimeFrame,j) && BodyCurr>ShadowPrev)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   double ShadowPrev=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double BodyCurr=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   if(IsDojiNeutral(Instrument,TimeFrame,j))
      return false;
   if(iClose(Instrument,TimeFrame,j)>iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,i)<iLow(Instrument,TimeFrame,j) && BodyCurr>ShadowPrev)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTweezerTop(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   double ShadowPrev=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double BodyCurr=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   if(IsInvertedHammer(Instrument,TimeFrame,j) && IsShootingStar(Instrument,TimeFrame,i) &&
      ((iHigh(Instrument,TimeFrame,j)<iHigh(Instrument,TimeFrame,i)*1.05 && iHigh(Instrument,TimeFrame,j)>iHigh(Instrument,TimeFrame,i)*0.95) ||
       (iHigh(Instrument,TimeFrame,i)<iHigh(Instrument,TimeFrame,j)*1.05 && iHigh(Instrument,TimeFrame,i)>iHigh(Instrument,TimeFrame,j)*0.95)) &&
      ((iOpen(Instrument,TimeFrame,j)<iClose(Instrument,TimeFrame,i)*1.05 && iOpen(Instrument,TimeFrame,j)>iClose(Instrument,TimeFrame,i)*0.95) ||
       (iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,j)*1.05 && iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,j)*0.95))
     )
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTweezerBottom(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   double ShadowPrev=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double BodyCurr=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   if(IsHangingMan(Instrument,TimeFrame,j) && IsHammer(Instrument,TimeFrame,i) &&
      ((iLow(Instrument,TimeFrame,j)<iLow(Instrument,TimeFrame,i)*1.05 && iLow(Instrument,TimeFrame,j)>iLow(Instrument,TimeFrame,i)*0.95) ||
       (iLow(Instrument,TimeFrame,i)<iLow(Instrument,TimeFrame,j)*1.05 && iLow(Instrument,TimeFrame,i)>iLow(Instrument,TimeFrame,j)*0.95)) &&
      ((iOpen(Instrument,TimeFrame,j)<iClose(Instrument,TimeFrame,i)*1.05 && iOpen(Instrument,TimeFrame,j)>iClose(Instrument,TimeFrame,i)*0.95) ||
       (iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,j)*1.05 && iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,j)*0.95))
     )
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsThreeWhiteSoldiers(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,j)>iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,k)>iOpen(Instrument,TimeFrame,k) && BodyI>ShadowI*0.5 && BodyJ>ShadowJ*0.5 && BodyK>ShadowK*0.5 && BodyJ<BodyI && BodyK<BodyJ)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsThreeCrows(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,j)<iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,k)<iOpen(Instrument,TimeFrame,k) && BodyI>ShadowI*0.5 && BodyJ>ShadowJ*0.5 && BodyK>ShadowK*0.5 && BodyJ<BodyI && BodyK<BodyJ)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsThreeInsideUp(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,j)>iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,k)<iOpen(Instrument,TimeFrame,k) &&
      iClose(Instrument,TimeFrame,j)<iOpen(Instrument,TimeFrame,k) && iClose(Instrument,TimeFrame,j)>iClose(Instrument,TimeFrame,k)+BodyK/4 && iClose(Instrument,TimeFrame,i)>iHigh(Instrument,TimeFrame,k) &&
      BodyI>ShadowI/2 && BodyJ>ShadowJ/2 && BodyK>ShadowK/2)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsThreeInsideDown(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,j)<iOpen(Instrument,TimeFrame,j) && iClose(Instrument,TimeFrame,k)>iOpen(Instrument,TimeFrame,k) &&
      iClose(Instrument,TimeFrame,j)>iOpen(Instrument,TimeFrame,k) && iClose(Instrument,TimeFrame,j)<iClose(Instrument,TimeFrame,k)-BodyK/4 && iClose(Instrument,TimeFrame,i)<iLow(Instrument,TimeFrame,k) &&
      BodyI>ShadowI/2 && BodyJ>ShadowJ/2 && BodyK>ShadowK/2)
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsMorningStar(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,k)<iOpen(Instrument,TimeFrame,k) && iClose(Instrument,TimeFrame,i)>iOpen(Instrument,TimeFrame,k)-BodyK/2 &&
      (IsDojiNeutral(Instrument,TimeFrame,j) || IsSpinningTopBullish(Instrument,TimeFrame,j)) && !IsDojiNeutral(Instrument,TimeFrame,k))
      return true;
   else
      return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsEveningStar(string Instrument, ENUM_TIMEFRAMES TimeFrame, int Shift=0)
  {
   int i=Shift;
   int j=i+1;
   int k=j+1;
   double ShadowI=iHigh(Instrument,TimeFrame,i)-iLow(Instrument,TimeFrame,i);
   double ShadowJ=iHigh(Instrument,TimeFrame,j)-iLow(Instrument,TimeFrame,j);
   double ShadowK=iHigh(Instrument,TimeFrame,k)-iLow(Instrument,TimeFrame,k);
   double BodyI=MathAbs(iClose(Instrument,TimeFrame,i)-iOpen(Instrument,TimeFrame,i));
   double BodyJ=MathAbs(iClose(Instrument,TimeFrame,j)-iOpen(Instrument,TimeFrame,j));
   double BodyK=MathAbs(iClose(Instrument,TimeFrame,k)-iOpen(Instrument,TimeFrame,k));
   if(iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,i) && iClose(Instrument,TimeFrame,k)>iOpen(Instrument,TimeFrame,k) && iClose(Instrument,TimeFrame,i)<iOpen(Instrument,TimeFrame,k)+BodyK/2 &&
      (IsDojiNeutral(Instrument,TimeFrame,j) || IsSpinningTopBearish(Instrument,TimeFrame,j)) && !IsDojiNeutral(Instrument,TimeFrame,k))
      return true;
   else
      return false;
  }
//+------------------------------------------------------------------+
//| Returns the average candlestick body size for the specified bar  |
//+------------------------------------------------------------------+
double AvgBody(int index)
  {
   double sum=0;
   for(int i=index; i<index+ExtAvgBodyPeriod; i++)
     {
      sum+=MathAbs(iOpen(_Symbol,_Period,i)-iClose(_Symbol,_Period,i));
     }
   return(sum/ExtAvgBodyPeriod);
  }
//+------------------------------------------------------------------+
//| Returns the middle body price for the specified bar              |
//+------------------------------------------------------------------+
double MidPoint(int index)
  {
   return(iHigh(_Symbol,_Period,index)+iLow(_Symbol,_Period,index))/2.;
  }
//+------------------------------------------------------------------+
//| SMA value at the specified bar                                   |
//+------------------------------------------------------------------+
double CloseAvg(int index)
  {
   double indicator_values[];
   if(CopyBuffer(ExtTrendMAHandle, 0, index, 1, indicator_values)<0)
     {
      //--- if the copying fails, report the error code
      PrintFormat("Failed to copy data from the Simple Moving Average indicator, error code %d", GetLastError());
      return(EMPTY_VALUE);
     }
   return(indicator_values[0]);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLabel(int Index, string Label, ENUM_TYPE_OF_PATTERN Type)
  {
//if(iCustomMode)
//   return;
   if(Type==BULLISH && !DetectBullish)
      return;
   if(Type==BEARISH && !DetectBearish)
      return;
   if(Type==UNCERTAIN && !DetectUncertain)
      return;


   string LabelName="";
   string ArrowName="";
   ENUM_OBJECT ArrowType=-1;
   color Color=clrNONE;
   int TextAnchor=0;
   int ArrowAnchor=0;

   datetime CandleTime=iTime(Symbol(),PERIOD_CURRENT,Index);
   double PriceLabel=0;
   double PriceArrow=0;
   int ArrowWidth=0;
   if(FontSize>=10)
      ArrowWidth=2;
   else
      ArrowWidth=1;
   double PriceOffsetTmp[];
   int c=CopyBuffer(ATRHandleCndls,0,0,1,PriceOffsetTmp);
   double PriceOffset=PriceOffsetTmp[0]/1.5;

   if(Type==UNCERTAIN)
     {
      Color=FontColorUncertain;
      TextAnchor=ANCHOR_LEFT;
      PriceLabel=iHigh(Symbol(),PERIOD_CURRENT,Index)+PriceOffset;
      ArrowAnchor=ANCHOR_BOTTOM;
      PriceArrow=iHigh(Symbol(),PERIOD_CURRENT,Index);
      ArrowType=OBJ_ARROW_DOWN;
     }
   if(Type==BULLISH)
     {
      Color=FontColorBullish;
      TextAnchor=ANCHOR_RIGHT;
      ArrowAnchor=ANCHOR_TOP;
      PriceLabel=iLow(Symbol(),PERIOD_CURRENT,Index)-PriceOffset;
      PriceArrow=iLow(Symbol(),PERIOD_CURRENT,Index);
      ArrowType=OBJ_ARROW_UP;
     }
   if(Type==BEARISH)
     {
      Color=FontColorBearish;
      TextAnchor=ANCHOR_LEFT;
      PriceLabel=iHigh(Symbol(),PERIOD_CURRENT,Index)+PriceOffset;
      ArrowAnchor=ANCHOR_BOTTOM;
      PriceArrow=iHigh(Symbol(),PERIOD_CURRENT,Index);
      ArrowType=OBJ_ARROW_DOWN;
     }

   LabelName=(string)iTime(Symbol(),PERIOD_CURRENT,Index)+"-CANDLE-LBL-"+IntegerToString(CandleTime);
   ArrowName=(string)iTime(Symbol(),PERIOD_CURRENT,Index)+"-CANDLE-ARR-"+IntegerToString(CandleTime);

 
      if(ShowCandleLables) 
      {
      ObjectCreate(0,LabelName,OBJ_TEXT,0,CandleTime,PriceLabel);
      ObjectSetDouble(0,LabelName,OBJPROP_ANGLE,90);
      ObjectSetInteger(0,LabelName,OBJPROP_ANCHOR,TextAnchor);
      ObjectSetInteger(0,LabelName,OBJPROP_BACK,true);
      ObjectSetInteger(0,LabelName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,LabelName,OBJPROP_FONTSIZE,FontSize);
      ObjectSetString(0,LabelName,OBJPROP_FONT,Font);
      ObjectSetString(0,LabelName,OBJPROP_TEXT,Label);
      ObjectSetInteger(0,LabelName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,LabelName,OBJPROP_COLOR,Color);
      }
 
if(ShowCandleArrows) 
      {
   ObjectCreate(0,ArrowName,ArrowType,0,CandleTime,PriceArrow);
   ObjectSetInteger(0,ArrowName,OBJPROP_ANCHOR,ArrowAnchor);
   ObjectSetInteger(0,ArrowName,OBJPROP_BACK,true);
   ObjectSetInteger(0,ArrowName,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,ArrowName,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,ArrowName,OBJPROP_WIDTH,ArrowWidth);
   ObjectSetString(0,ArrowName,OBJPROP_TEXT,Label);
   ObjectSetInteger(0,ArrowName,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,ArrowName,OBJPROP_COLOR,Color);
   }

   //if(EnableNotify && !NotifiedThisCandle)
     // NotifyPattern(Label);

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CleanChart()
  {
   //Print(__FUNCTION__);
   int Window=0;
   for(int i=ObjectsTotal(ChartID(),Window,-1)-1; i>=0; i--)
     {
      //if(StringFind(ObjectName(0,i),IndicatorName,0)>=0){
      ObjectDelete(0,ObjectName(0,i));
      //}
     }
   ObjectsDeleteAll(0,0,OBJ_TEXT);
   ObjectsDeleteAll(0,0,OBJ_ARROW);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetLastErrorText(int Error)
  {
   string Text="";
//Print(Error);
   if(Error==ERR_SUCCESS)
      Text="The operation completed successfully";
   if(Error==ERR_INTERNAL_ERROR)
      Text="Unexpected internal error";
   if(Error==ERR_WRONG_INTERNAL_PARAMETER)
      Text="Wrong parameter in the inner call of the client terminal function";
   if(Error==ERR_INVALID_PARAMETER)
      Text="Wrong parameter when calling the system function";
   if(Error==ERR_NOT_ENOUGH_MEMORY)
      Text="Not enough memory to perform the system function";
   if(Error==ERR_STRUCT_WITHOBJECTS_ORCLASS)
      Text="The structure contains objects of strings and/or dynamic arrays and/or structure of such objects and/or classes";
   if(Error==ERR_INVALID_ARRAY)
      Text="Array of a wrong type, wrong size, or a damaged object of a dynamic array";
   if(Error==ERR_ARRAY_RESIZE_ERROR)
      Text="Not enough memory for the relocation of an array, or an attempt to change the size of a static array";
   if(Error==ERR_STRING_RESIZE_ERROR)
      Text="Not enough memory for the relocation of string";
   if(Error==ERR_NOTINITIALIZED_STRING)
      Text="Not initialized string";
   if(Error==ERR_INVALID_DATETIME)
      Text="Invalid date and/or time";
   if(Error==ERR_ARRAY_BAD_SIZE)
      Text="Requested array size exceeds 2 GB";
   if(Error==ERR_INVALID_POINTER)
      Text="Wrong pointer";
   if(Error==ERR_INVALID_POINTER_TYPE)
      Text="Wrong type of pointer";
   if(Error==ERR_FUNCTION_NOT_ALLOWED)
      Text="Function is not allowed for call";
   if(Error==ERR_RESOURCE_NAME_DUPLICATED)
      Text="The names of the dynamic and the static resource match";
   if(Error==ERR_RESOURCE_NOT_FOUND)
      Text="Resource with this name has not been found in EX5";
   if(Error==ERR_RESOURCE_UNSUPPORTED_TYPE)
      Text="Unsupported resource type or its size exceeds 16 Mb";
   if(Error==ERR_RESOURCE_NAME_IS_TOO_LONG)
      Text="The resource name exceeds 63 characters";
   if(Error==ERR_MATH_OVERFLOW)
      Text="Overflow occurred when calculating math function";
   if(Error==ERR_CHART_WRONG_ID)
      Text="Wrong chart ID";
   if(Error==ERR_CHART_NO_REPLY)
      Text="Chart does not respond";
   if(Error==ERR_CHART_NOT_FOUND)
      Text="Chart not found";
   if(Error==ERR_CHART_NO_EXPERT)
      Text="No Expert Advisor in the chart that could handle the event";
   if(Error==ERR_CHART_CANNOT_OPEN)
      Text="Chart opening error";
   if(Error==ERR_CHART_CANNOT_CHANGE)
      Text="Failed to change chart symbol and period";
   if(Error==ERR_CHART_WRONG_PARAMETER)
      Text="Error value of the parameter for the function of working with charts";
   if(Error==ERR_CHART_CANNOT_CREATE_TIMER)
      Text="Failed to create timer";
   if(Error==ERR_CHART_WRONG_PROPERTY)
      Text="Wrong chart property ID";
   if(Error==ERR_CHART_SCREENSHOT_FAILED)
      Text="Error creating screenshots";
   if(Error==ERR_CHART_NAVIGATE_FAILED)
      Text="Error navigating through chart";
   if(Error==ERR_CHART_TEMPLATE_FAILED)
      Text="Error applying template";
   if(Error==ERR_CHART_WINDOW_NOT_FOUND)
      Text="Subwindow containing the indicator was not found";
   if(Error==ERR_CHART_INDICATOR_CANNOT_ADD)
      Text="Error adding an indicator to chart";
   if(Error==ERR_CHART_INDICATOR_CANNOT_DEL)
      Text="Error deleting an indicator from the chart";
   if(Error==ERR_CHART_INDICATOR_NOT_FOUND)
      Text="Indicator not found on the specified chart";
   if(Error==ERR_OBJECT_ERROR)
      Text="Error working with a graphical object";
   if(Error==ERR_OBJECT_NOT_FOUND)
      Text="Graphical object was not found";
   if(Error==ERR_OBJECT_WRONG_PROPERTY)
      Text="Wrong ID of a graphical object property";
   if(Error==ERR_OBJECT_GETDATE_FAILED)
      Text="Unable to get date corresponding to the value";
   if(Error==ERR_OBJECT_GETVALUE_FAILED)
      Text="Unable to get value corresponding to the date";
   if(Error==ERR_MARKET_UNKNOWN_SYMBOL)
      Text="Unknown symbol";
   if(Error==ERR_MARKET_NOT_SELECTED)
      Text="Symbol is not selected in MarketWatch";
   if(Error==ERR_MARKET_WRONG_PROPERTY)
      Text="Wrong identifier of a symbol property";
   if(Error==ERR_MARKET_LASTTIME_UNKNOWN)
      Text="Time of the last tick is not known (no ticks)";
   if(Error==ERR_MARKET_SELECT_ERROR)
      Text="Error adding or deleting a symbol in MarketWatch";
   if(Error==ERR_HISTORY_NOT_FOUND)
      Text="Requested history not found";
   if(Error==ERR_HISTORY_WRONG_PROPERTY)
      Text="Wrong ID of the history property";
   if(Error==ERR_HISTORY_TIMEOUT)
      Text="Exceeded history request timeout";
   if(Error==ERR_HISTORY_BARS_LIMIT)
      Text="Number of requested bars limited by terminal settings";
   if(Error==ERR_HISTORY_LOAD_ERRORS)
      Text="Multiple errors when loading history";
   if(Error==ERR_HISTORY_SMALL_BUFFER)
      Text="Receiving array is too small to store all requested data";
   if(Error==ERR_GLOBALVARIABLE_NOT_FOUND)
      Text="Global variable of the client terminal is not found";
   if(Error==ERR_GLOBALVARIABLE_EXISTS)
      Text="Global variable of the client terminal with the same name already exists";
   if(Error==ERR_GLOBALVARIABLE_NOT_MODIFIED)
      Text="Global variables were not modified";
   if(Error==ERR_GLOBALVARIABLE_CANNOTREAD)
      Text="Cannot read file with global variable values";
   if(Error==ERR_GLOBALVARIABLE_CANNOTWRITE)
      Text="Cannot write file with global variable values";
   if(Error==ERR_MAIL_SEND_FAILED)
      Text="Email sending failed";
   if(Error==ERR_PLAY_SOUND_FAILED)
      Text="Sound playing failed";
   if(Error==ERR_MQL5_WRONG_PROPERTY)
      Text="Wrong identifier of the program property";
   if(Error==ERR_TERMINAL_WRONG_PROPERTY)
      Text="Wrong identifier of the terminal property";
   if(Error==ERR_FTP_SEND_FAILED)
      Text="File sending via ftp failed";
   if(Error==ERR_NOTIFICATION_SEND_FAILED)
      Text="Failed to send a notification";
   if(Error==ERR_NOTIFICATION_WRONG_PARAMETER)
      Text="Invalid parameter for sending a notification – an empty string or NULL has been passed to the SendNotification() function";
   if(Error==ERR_NOTIFICATION_WRONG_SETTINGS)
      Text="Wrong settings of notifications in the terminal (ID is not specified or permission is not set)";
   if(Error==ERR_NOTIFICATION_TOO_FREQUENT)
      Text="Too frequent sending of notifications";
   if(Error==ERR_FTP_NOSERVER)
      Text="FTP server is not specified";
   if(Error==ERR_FTP_NOLOGIN)
      Text="FTP login is not specified";
   if(Error==ERR_FTP_FILE_ERROR)
      Text="File not found in the MQL5\\Files directory to send on FTP server";
   if(Error==ERR_FTP_CONNECT_FAILED)
      Text="FTP connection failed";
   if(Error==ERR_FTP_CHANGEDIR)
      Text="FTP path not found on server";
   if(Error==ERR_BUFFERS_NO_MEMORY)
      Text="Not enough memory for the distribution of indicator buffers";
   if(Error==ERR_BUFFERS_WRONG_INDEX)
      Text="Wrong indicator buffer index";
   if(Error==ERR_CUSTOM_WRONG_PROPERTY)
      Text="Wrong ID of the custom indicator property";
   if(Error==ERR_ACCOUNT_WRONG_PROPERTY)
      Text="Wrong account property ID";
   if(Error==ERR_TRADE_WRONG_PROPERTY)
      Text="Wrong trade property ID";
   if(Error==ERR_TRADE_DISABLED)
      Text="Trading by Expert Advisors prohibited";
   if(Error==ERR_TRADE_POSITION_NOT_FOUND)
      Text="Position not found";
   if(Error==ERR_TRADE_ORDER_NOT_FOUND)
      Text="Order not found";
   if(Error==ERR_TRADE_DEAL_NOT_FOUND)
      Text="Deal not found";
   if(Error==ERR_TRADE_SEND_FAILED)
      Text="Trade request sending failed";
   if(Error==ERR_TRADE_CALC_FAILED)
      Text="Failed to calculate profit or margin";
   if(Error==ERR_INDICATOR_UNKNOWN_SYMBOL)
      Text="Unknown symbol";
   if(Error==ERR_INDICATOR_CANNOT_CREATE)
      Text="Indicator cannot be created";
   if(Error==ERR_INDICATOR_NO_MEMORY)
      Text="Not enough memory to add the indicator";
   if(Error==ERR_INDICATOR_CANNOT_APPLY)
      Text="The indicator cannot be applied to another indicator";
   if(Error==ERR_INDICATOR_CANNOT_ADD)
      Text="Error applying an indicator to chart";
   if(Error==ERR_INDICATOR_DATA_NOT_FOUND)
      Text="Requested data not found";
   if(Error==ERR_INDICATOR_WRONG_HANDLE)
      Text="Wrong indicator handle";
   if(Error==ERR_INDICATOR_WRONG_PARAMETERS)
      Text="Wrong number of parameters when creating an indicator";
   if(Error==ERR_INDICATOR_PARAMETERS_MISSING)
      Text="No parameters when creating an indicator";
   if(Error==ERR_INDICATOR_CUSTOM_NAME)
      Text="The first parameter in the array must be the name of the custom indicator";
   if(Error==ERR_INDICATOR_PARAMETER_TYPE)
      Text="Invalid parameter type in the array when creating an indicator";
   if(Error==ERR_INDICATOR_WRONG_INDEX)
      Text="Wrong index of the requested indicator buffer";
   if(Error==ERR_BOOKS_CANNOT_ADD)
      Text="Depth Of Market can not be added";
   if(Error==ERR_BOOKS_CANNOT_DELETE)
      Text="Depth Of Market can not be removed";
   if(Error==ERR_BOOKS_CANNOT_GET)
      Text="The data from Depth Of Market can not be obtained";
   if(Error==ERR_BOOKS_CANNOT_SUBSCRIBE)
      Text="Error in subscribing to receive new data from Depth Of Market";
   if(Error==ERR_TOO_MANY_FILES)
      Text="More than 64 files cannot be opened at the same time";
   if(Error==ERR_WRONG_FILENAME)
      Text="Invalid file name";
   if(Error==ERR_TOO_LONG_FILENAME)
      Text="Too long file name";
   if(Error==ERR_CANNOT_OPEN_FILE)
      Text="File opening error";
   if(Error==ERR_FILE_CACHEBUFFER_ERROR)
      Text="Not enough memory for cache to read";
   if(Error==ERR_CANNOT_DELETE_FILE)
      Text="File deleting error";
   if(Error==ERR_INVALID_FILEHANDLE)
      Text="A file with this handle was closed, or was not opening at all";
   if(Error==ERR_WRONG_FILEHANDLE)
      Text="Wrong file handle";
   if(Error==ERR_FILE_NOTTOWRITE)
      Text="The file must be opened for writing";
   if(Error==ERR_FILE_NOTTOREAD)
      Text="The file must be opened for reading";
   if(Error==ERR_FILE_NOTBIN)
      Text="The file must be opened as a binary one";
   if(Error==ERR_FILE_NOTTXT)
      Text="The file must be opened as a text";
   if(Error==ERR_FILE_NOTTXTORCSV)
      Text="The file must be opened as a text or CSV";
   if(Error==ERR_FILE_NOTCSV)
      Text="The file must be opened as CSV";
   if(Error==ERR_FILE_READERROR)
      Text="File reading error";
   if(Error==ERR_FILE_BINSTRINGSIZE)
      Text="String size must be specified, because the file is opened as binary";
   if(Error==ERR_INCOMPATIBLE_FILE)
      Text="A text file must be for string arrays, for other arrays - binary";
   if(Error==ERR_FILE_IS_DIRECTORY)
      Text="This is not a file, this is a directory";
   if(Error==ERR_FILE_NOT_EXIST)
      Text="File does not exist";
   if(Error==ERR_FILE_CANNOT_REWRITE)
      Text="File can not be rewritten";
   if(Error==ERR_WRONG_DIRECTORYNAME)
      Text="Wrong directory name";
   if(Error==ERR_DIRECTORY_NOT_EXIST)
      Text="Directory does not exist";
   if(Error==ERR_FILE_ISNOT_DIRECTORY)
      Text="This is a file, not a directory";
   if(Error==ERR_CANNOT_DELETE_DIRECTORY)
      Text="The directory cannot be removed";
   if(Error==ERR_CANNOT_CLEAN_DIRECTORY)
      Text="Failed to clear the directory (probably one or more files are blocked and removal operation failed)";
   if(Error==ERR_FILE_WRITEERROR)
      Text="Failed to write a resource to a file";
   if(Error==ERR_FILE_ENDOFFILE)
      Text="Unable to read the next piece of data from a CSV file (FileReadString, FileReadNumber, FileReadDatetime, FileReadBool), since the end of file is reached";
   if(Error==ERR_NO_STRING_DATE)
      Text="No date in the string";
   if(Error==ERR_WRONG_STRING_DATE)
      Text="Wrong date in the string";
   if(Error==ERR_WRONG_STRING_TIME)
      Text="Wrong time in the string";
   if(Error==ERR_STRING_TIME_ERROR)
      Text="Error converting string to date";
   if(Error==ERR_STRING_OUT_OF_MEMORY)
      Text="Not enough memory for the string";
   if(Error==ERR_STRING_SMALL_LEN)
      Text="The string length is less than expected";
   if(Error==ERR_STRING_TOO_BIGNUMBER)
      Text="Too large number, more than ULONG_MAX";
   if(Error==ERR_WRONG_FORMATSTRING)
      Text="Invalid format string";
   if(Error==ERR_TOO_MANY_FORMATTERS)
      Text="Amount of format specifiers more than the parameters";
   if(Error==ERR_TOO_MANY_PARAMETERS)
      Text="Amount of parameters more than the format specifiers";
   if(Error==ERR_WRONG_STRING_PARAMETER)
      Text="Damaged parameter of string type";
   if(Error==ERR_STRINGPOS_OUTOFRANGE)
      Text="Position outside the string";
   if(Error==ERR_STRING_ZEROADDED)
      Text="0 added to the string end, a useless operation";
   if(Error==ERR_STRING_UNKNOWNTYPE)
      Text="Unknown data type when converting to a string";
   if(Error==ERR_WRONG_STRING_OBJECT)
      Text="Damaged string object";
   if(Error==ERR_INCOMPATIBLE_ARRAYS)
      Text="Copying incompatible arrays. String array can be copied only to a string array, and a numeric array - in numeric array only";
   if(Error==ERR_SMALL_ASSERIES_ARRAY)
      Text="The receiving array is declared as AS_SERIES, and it is of insufficient size";
   if(Error==ERR_SMALL_ARRAY)
      Text="Too small array, the starting position is outside the array";
   if(Error==ERR_ZEROSIZE_ARRAY)
      Text="An array of zero length";
   if(Error==ERR_NUMBER_ARRAYS_ONLY)
      Text="Must be a numeric array";
   if(Error==ERR_ONEDIM_ARRAYS_ONLY)
      Text="Must be a one-dimensional array";
   if(Error==ERR_SERIES_ARRAY)
      Text="Timeseries cannot be used";
   if(Error==ERR_DOUBLE_ARRAY_ONLY)
      Text="Must be an array of type double";
   if(Error==ERR_FLOAT_ARRAY_ONLY)
      Text="Must be an array of type float";
   if(Error==ERR_LONG_ARRAY_ONLY)
      Text="Must be an array of type long";
   if(Error==ERR_INT_ARRAY_ONLY)
      Text="Must be an array of type int";
   if(Error==ERR_SHORT_ARRAY_ONLY)
      Text="Must be an array of type short";
   if(Error==ERR_CHAR_ARRAY_ONLY)
      Text="Must be an array of type char";
   if(Error==ERR_STRING_ARRAY_ONLY)
      Text="String array only";
   if(Error==ERR_OPENCL_NOT_SUPPORTED)
      Text="OpenCL functions are not supported on this computer";
   if(Error==ERR_OPENCL_INTERNAL)
      Text="Internal error occurred when running OpenCL";
   if(Error==ERR_OPENCL_INVALID_HANDLE)
      Text="Invalid OpenCL handle";
   if(Error==ERR_OPENCL_CONTEXT_CREATE)
      Text="Error creating the OpenCL context";
   if(Error==ERR_OPENCL_QUEUE_CREATE)
      Text="Failed to create a run queue in OpenCL";
   if(Error==ERR_OPENCL_PROGRAM_CREATE)
      Text="Error occurred when compiling an OpenCL program";
   if(Error==ERR_OPENCL_TOO_LONG_KERNEL_NAME)
      Text="Too long kernel name (OpenCL kernel)";
   if(Error==ERR_OPENCL_KERNEL_CREATE)
      Text="Error creating an OpenCL kernel";
   if(Error==ERR_OPENCL_SET_KERNEL_PARAMETER)
      Text="Error occurred when setting parameters for the OpenCL kernel";
   if(Error==ERR_OPENCL_EXECUTE)
      Text="OpenCL program runtime error";
   if(Error==ERR_OPENCL_WRONG_BUFFER_SIZE)
      Text="Invalid size of the OpenCL buffer";
   if(Error==ERR_OPENCL_WRONG_BUFFER_OFFSET)
      Text="Invalid offset in the OpenCL buffer";
   if(Error==ERR_OPENCL_BUFFER_CREATE)
      Text="Failed to create an OpenCL buffer";
   if(Error==ERR_OPENCL_TOO_MANY_OBJECTS)
      Text="Too many OpenCL objects";
   if(Error==ERR_OPENCL_SELECTDEVICE)
      Text="OpenCL device selection error";
   if(Error==ERR_WEBREQUEST_INVALID_ADDRESS)
      Text="Invalid URL";
   if(Error==ERR_WEBREQUEST_CONNECT_FAILED)
      Text="Failed to connect to specified URL";
   if(Error==ERR_WEBREQUEST_TIMEOUT)
      Text="Timeout exceeded";
   if(Error==ERR_WEBREQUEST_REQUEST_FAILED)
      Text="HTTP request failed";
   if(Error==ERR_NOT_CUSTOM_SYMBOL)
      Text="A custom symbol must be specified";
   if(Error==ERR_CUSTOM_SYMBOL_WRONG_NAME)
      Text="The name of the custom symbol is invalid. The symbol name can only contain Latin letters without punctuation, spaces or special characters (may only contain '.', '_', '&' and '#'). It is not recommended to use characters <, >, :, ', /,\\, |, ?, *.";
   if(Error==ERR_CUSTOM_SYMBOL_NAME_LONG)
      Text="The name of the custom symbol is too long. The length of the symbol name must not exceed 32 characters including the ending 0 character";
   if(Error==ERR_CUSTOM_SYMBOL_PATH_LONG)
      Text="The path of the custom symbol is too long. The path length should not exceed 128 characters including 'Custom', the symbol name, group separators and the ending 0";
   if(Error==ERR_CUSTOM_SYMBOL_EXIST)
      Text="A custom symbol with the same name already exists";
   if(Error==ERR_CUSTOM_SYMBOL_ERROR)
      Text="Error occurred while creating, deleting or changing the custom symbol";
   if(Error==ERR_CUSTOM_SYMBOL_SELECTED)
      Text="You are trying to delete a custom symbol selected in Market Watch";
   if(Error==ERR_CUSTOM_SYMBOL_PROPERTY_WRONG)
      Text="An invalid custom symbol property";
   if(Error==ERR_CUSTOM_SYMBOL_PARAMETER_ERROR)
      Text="A wrong parameter while setting the property of a custom symbol";
   if(Error==ERR_CUSTOM_SYMBOL_PARAMETER_LONG)
      Text="A too long string parameter while setting the property of a custom symbol";
   if(Error==ERR_CUSTOM_TICKS_WRONG_ORDER)
      Text="Ticks in the array are not arranged in the order of time";

   return Text;
  }
//constants
//#define OP_BUY 0           //Buy 
//#define OP_SELL 1          //Sell 
//#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
//#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
//#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
//#define OP_SELLSTOP 5      //Pending order of SELL STOP type 
//---
#define MODE_OPEN 0
#define MODE_CLOSE 3
#define MODE_VOLUME 4
#define MODE_REAL_VOLUME 5
#define MODE_TRADES 0
#define MODE_HISTORY 1
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
//---
#define DOUBLE_VALUE 0
#define FLOAT_VALUE 1
#define LONG_VALUE INT_VALUE
//---
#define CHART_BAR 0
#define CHART_CANDLE 1
//---
#define MODE_ASCEND 0
#define MODE_DESCEND 1
//---
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_TIME 5
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_DIGITS 12
#define MODE_SPREAD 13
#define MODE_STOPLEVEL 14
#define MODE_LOTSIZE 15
#define MODE_TICKVALUE 16
#define MODE_TICKSIZE 17
#define MODE_SWAPLONG 18
#define MODE_SWAPSHORT 19
#define MODE_STARTING 20
#define MODE_EXPIRATION 21
#define MODE_TRADEALLOWED 22
#define MODE_MINLOT 23
#define MODE_LOTSTEP 24
#define MODE_MAXLOT 25
#define MODE_SWAPTYPE 26
#define MODE_PROFITCALCMODE 27
#define MODE_MARGINCALCMODE 28
#define MODE_MARGININIT 29
#define MODE_MARGINMAINTENANCE 30
#define MODE_MARGINHEDGED 31
#define MODE_MARGINREQUIRED 32

enum ENUM_HOUR
  {
   h00=00,     //00:00
   h01=01,     //01:00
   h02=02,     //02:00
   h03=03,     //03:00
   h04=04,     //04:00
   h05=05,     //05:00
   h06=06,     //06:00
   h07=07,     //07:00
   h08=08,     //08:00
   h09=09,     //09:00
   h10=10,     //10:00
   h11=11,     //11:00
   h12=12,     //12:00
   h13=13,     //13:00
   h14=14,     //14:00
   h15=15,     //15:00
   h16=16,     //16:00
   h17=17,     //17:00
   h18=18,     //18:00
   h19=19,     //19:00
   h20=20,     //20:00
   h21=21,     //21:00
   h22=22,     //22:00
   h23=23,     //23:00
  };

ENUM_TIMEFRAMES TimeFrames[]=
  {
   PERIOD_M1,
   PERIOD_M2,
   PERIOD_M3,
   PERIOD_M4,
   PERIOD_M5,
   PERIOD_M6,
   PERIOD_M10,
   PERIOD_M12,
   PERIOD_M15,
   PERIOD_M20,
   PERIOD_M30,
   PERIOD_H1,
   PERIOD_H2,
   PERIOD_H3,
   PERIOD_H4,
   PERIOD_H6,
   PERIOD_H8,
   PERIOD_H12,
   PERIOD_D1,
   PERIOD_W1,
   PERIOD_MN1
  };


//Return the index of the requested time frame in the array TimeFrames
int TimeFrameIndex(ENUM_TIMEFRAMES TimeFrame)
  {
   int j=0;
   if(TimeFrame==PERIOD_CURRENT)
      TimeFrame=Period();
   for(int i=0; i<ArraySize(TimeFrames); i++)
     {
      if(TimeFrame==TimeFrames[i])
         return i;
     }
   return j;
  }

//Check if the current time is within the period
bool IsCurrentTimeInInterval(ENUM_HOUR Start,ENUM_HOUR End)
  {
   if(Start==End && Hour()==Start)
      return true;
   if(Start<End && Hour()>=Start && Hour()<=End)
      return true;
   if(Start>End && ((Hour()>=Start && Hour()<=23) || (Hour()<=End && Hour()>=0)))
      return true;
   return false;
  }

//Draw an edit box with the specified parameters
void DrawEdit(string Name,
              int XStart,
              int YStart,
              int Width,
              int Height,
              bool ReadOnly,
              int EditFontSize,
              string Tooltip,
              int Align,
              string EditFont,
              string Text,
              bool Selectable,
              color TextColor=clrBlack,
              color BGColor=clrWhiteSmoke,
              color BDColor=clrBlack
             )
  {
   ObjectCreate(0,Name,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,Name,OBJPROP_XDISTANCE,XStart);
   ObjectSetInteger(0,Name,OBJPROP_YDISTANCE,YStart);
   ObjectSetInteger(0,Name,OBJPROP_XSIZE,Width);
   ObjectSetInteger(0,Name,OBJPROP_YSIZE,Height);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,Name,OBJPROP_STATE,false);
   ObjectSetInteger(0,Name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,Name,OBJPROP_READONLY,ReadOnly);
   ObjectSetInteger(0,Name,OBJPROP_FONTSIZE,EditFontSize);
   ObjectSetString(0,Name,OBJPROP_TOOLTIP,Tooltip);
   ObjectSetInteger(0,Name,OBJPROP_ALIGN,Align);
   ObjectSetString(0,Name,OBJPROP_FONT,EditFont);
   ObjectSetString(0,Name,OBJPROP_TEXT,Text);
   ObjectSetInteger(0,Name,OBJPROP_SELECTABLE,Selectable);
   ObjectSetInteger(0,Name,OBJPROP_COLOR,TextColor);
   ObjectSetInteger(0,Name,OBJPROP_BGCOLOR,BGColor);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_COLOR,BDColor);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AccountCompany()
  {
   return AccountInfoString(ACCOUNT_COMPANY);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AccountName()
  {
   return AccountInfoString(ACCOUNT_NAME);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long AccountNumber()
  {
   return AccountInfoInteger(ACCOUNT_LOGIN);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AccountCurrency()
  {
   return AccountInfoString(ACCOUNT_CURRENCY);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AccountBalance()
  {
   return AccountInfoDouble(ACCOUNT_BALANCE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AccountEquity()
  {
   return AccountInfoDouble(ACCOUNT_EQUITY);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double AccountFreeMargin()
  {
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int WindowFind(string Name)
  {
   return ChartWindowFind(0,Name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeFrameDescription(int TimeFrame)
  {
   string PeriodDesc="";
   switch(TimeFrame)
     {
      case PERIOD_M1:
         PeriodDesc="M1";
         break;
      case PERIOD_M2:
         PeriodDesc="M2";
         break;
      case PERIOD_M3:
         PeriodDesc="M3";
         break;
      case PERIOD_M4:
         PeriodDesc="M4";
         break;
      case PERIOD_M5:
         PeriodDesc="M5";
         break;
      case PERIOD_M6:
         PeriodDesc="M6";
         break;
      case PERIOD_M10:
         PeriodDesc="M10";
         break;
      case PERIOD_M12:
         PeriodDesc="M12";
         break;
      case PERIOD_M15:
         PeriodDesc="M15";
         break;
      case PERIOD_M20:
         PeriodDesc="M20";
         break;
      case PERIOD_M30:
         PeriodDesc="M30";
         break;
      case PERIOD_H1:
         PeriodDesc="H1";
         break;
      case PERIOD_H2:
         PeriodDesc="H2";
         break;
      case PERIOD_H3:
         PeriodDesc="H3";
         break;
      case PERIOD_H4:
         PeriodDesc="H4";
         break;
      case PERIOD_H6:
         PeriodDesc="H6";
         break;
      case PERIOD_H8:
         PeriodDesc="H8";
         break;
      case PERIOD_H12:
         PeriodDesc="H12";
         break;
      case PERIOD_D1:
         PeriodDesc="D1";
         break;
      case PERIOD_W1:
         PeriodDesc="W1";
         break;
      case PERIOD_MN1:
         PeriodDesc="MN1";
         break;
     }
   return PeriodDesc;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*string OrderSymbol()
  {
   return OrderGetString(ORDER_SYMBOL);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderMagicNumber()
  {
   return OrderGetInteger(ORDER_MAGIC);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderStopLoss()
  {
   return OrderGetDouble(ORDER_SL);
  }*/
/*
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderTakeProfit()
  {
   return OrderGetDouble(ORDER_TP);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE OrderType()
  {
   return (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderTicket()
  {
   return OrderGetInteger(ORDER_TICKET);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
long OrderOpenTime()
  {
   return OrderGetInteger(ORDER_TIME_DONE);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OrderOpenPrice()
  {
   return OrderGetDouble(ORDER_PRICE_OPEN);
  }*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//double OrderLots()
//  {
//   return OrderGetDouble(ORDER_VOLUME_CURRENT);
//  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Hour()
  {
   MqlDateTime mTime;
   TimeCurrent(mTime);
   return(mTime.hour);
  }
//+------------------------------------------------------------------+


/*
CANDLE DETECTION SUBSYSTEM
*/

//+------------------------------------------------------------------+
//|  returns pattern type to caller from ONTICK - inorder to buy or sell                                                                |
//+------------------------------------------------------------------+
void DetectPattern(ENUM_TYPE_OF_PATTERN &TypeRef,ENUM_CANDLESTICK_PATTERN &PatternRef)
  {

   NotifiedThisCandle=false;


   string Label="";

   ENUM_TYPE_OF_PATTERN Type;
   ENUM_CANDLESTICK_PATTERN Pattern=PATTERN_IS_NONE;

   if(DetectMorningStar && IsMorningStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MORNING STAR";
      Type=BULLISH;
      Pattern=PATTERN_IS_MORNINGSTAR;

      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;

      TypeRef=Type;
      PatternRef=Pattern;

      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);//}
      return;

     }
   if(DetectEveningStar && IsEveningStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="EVENING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_EVENINGSTAR;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectThreeInsideUp && IsThreeInsideUp(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE INSIDE UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectThreeInsideDown && IsThreeInsideDown(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE INSIDE DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectThreeWhiteSoldier && IsThreeWhiteSoldiers(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE WHITE SOLDIER";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEWHITESOLDIERS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
     //}
      return;
     }
   if(DetectThreeBlackCrows && IsThreeCrows(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE BLACK CROWS";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREECROWS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectEngulfingBull && IsBullishEngulfing(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BULLISH ENGULFING";
      Type=BULLISH;
      Pattern=PATTERN_IS_BULLISHENGULFING;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectEngulfingBear && IsBearishEngulfing(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BEARISH ENGULFING";
      Type=BEARISH;
      Pattern=PATTERN_IS_BEARISHENGULFING;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectTweezerTop && IsTweezerTop(Symbol(),PERIOD_CURRENT,1))
     {
      Label="TWEEZER TOP";
      Type=BEARISH;
      Pattern=PATTERN_IS_TWEEZERTOP;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectTweezerBottom && IsTweezerBottom(Symbol(),PERIOD_CURRENT,1))
     {
      Label="TWEEZER BOTTOM";
      Type=BULLISH;
      Pattern=PATTERN_IS_TWEEZERBOTTOM;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectInvertedHammer && IsInvertedHammer(Symbol(),PERIOD_CURRENT,1))
     {
      Label="INVERTED HAMMER";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_INVERTEDHAMMER;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
     // }
      return;
     }
   if(DetectShootingStar && IsShootingStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SHOOTING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_SHOOTINGSTAR;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectHammer && IsHammer(Symbol(),PERIOD_CURRENT,1))
     {
      Label="HAMMER";
      Type=BULLISH;
      Pattern=PATTERN_IS_HAMMER;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectHangingMan && IsHangingMan(Symbol(),PERIOD_CURRENT,1))
     {
      Label="HANGING MAN";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_HANGINMAN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectMarubozuUp && IsMarubozuUp(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MARUBOZU UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_MARUBOZUUP;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectBearishHaramiDown && IsBearishHarami(Symbol(),PERIOD_CURRENT,1))
     {
      Label="HARAMI DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_HARAMIDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectBullishHaramiUp && IsBullishHarami(Symbol(),PERIOD_CURRENT,1))
     {
      Label="HARAMI UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_HARAMIUP;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }

   if(DetectMarubozuDown && IsMarubozuDown(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MARUBOZU DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_MARUBOZUDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      
     // }
      return;
     }


   if(DetectSpinningTopBull && IsSpinningTopBullish(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SPINNING TOP BULLISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBULLISH;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectSpinningTopBear && IsSpinningTopBearish(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SPINNING TOP BEARISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBEARISH;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectDojiDragonfly && IsDojyDragonfly(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI DRAGONFLY";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DRAGONFLY;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
     // if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectDojiGravestone && IsDojiGravestone(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI GRAVESTONE";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_GRAVESTONE;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
   if(DetectDojiNeutral && IsDojiNeutral(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DOJI;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }

   if(DetectBullPiercing && isBullPiercing(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BULLPIERCING";
      Type=BULLISH;
      Pattern=PATTERN_IS_BULLPIERCING;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }

   if(DetectDarkCloud && isDarkCloud(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DARKCLOUD";
      Type=BEARISH;
      Pattern=PATTERN_IS_DARKCLOUD;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }

   if(DetectBullCross && isBullCross(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BULLCROSS";
      Type=BULLISH;
      Pattern=PATTERN_IS_BULLCROSS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
     // }
      return;
     }

   if(DetectBearCross && isBearCross(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BEARCROSS";
      Type=BEARISH;
      Pattern=PATTERN_IS_BEARCROSS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      TypeRef=Type;
      PatternRef=Pattern;
      //if(ShowCandleLables) {
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      //}
      return;
     }
  }

//+------------------------------------------------------------------+
void NotifyPattern(string Pattern)
  {

   if(!SendAlert && !SendApp && !SendEmail)
      return;

   string EmailSubject="PATTRN_DETECTOR"+" "+Symbol()+" Notification ";
   string EmailBody="\r\n"+AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+"\r\n\r\n"+"PATTRN_DETECTOR"+" Notification for "+Symbol()+"\r\n\r\n";
   EmailBody+="Detected pattern : "+Pattern+"\r\n\r\n";
   string AlertText="PATTRN_DETECTOR"+" - "+Symbol()+" Notification\r\n";
   AlertText+="Detected pattern : "+Pattern+"\r\n";
   string AppText=AccountCompany()+" - "+AccountName()+" - "+IntegerToString(AccountNumber())+" - "+"PATTRN_DETECTOR"+" - "+Symbol()+" - ";
   AppText+="Detected pattern : "+Pattern+"";

   if(SendAlert)
      Alert(AlertText);
   if(SendEmail)
     {
      if(!SendMail(EmailSubject,EmailBody))
         Print("Error sending email "+IntegerToString(GetLastError()));
     }
   if(SendApp)
     {
      if(!SendNotification(AppText))
         Print("Error sending notification "+IntegerToString(GetLastError()));
     }

   NotifiedThisCandle=true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DetectPattern()
  {

   NotifiedThisCandle=false;


   string Label="";

   ENUM_TYPE_OF_PATTERN Type;
   ENUM_CANDLESTICK_PATTERN Pattern=PATTERN_IS_NONE;

   if(DetectMorningStar && IsMorningStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MORNING STAR";
      Type=BULLISH;
      Pattern=PATTERN_IS_MORNINGSTAR;

      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;

      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;

     }
   if(DetectEveningStar && IsEveningStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="EVENING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_EVENINGSTAR;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectThreeInsideUp && IsThreeInsideUp(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE INSIDE UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
     DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectThreeInsideDown && IsThreeInsideDown(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE INSIDE DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectThreeWhiteSoldier && IsThreeWhiteSoldiers(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE WHITE SOLDIER";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEWHITESOLDIERS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectThreeBlackCrows && IsThreeCrows(Symbol(),PERIOD_CURRENT,1))
     {
      Label="THREE BLACK CROWS";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREECROWS;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectEngulfingBull && IsBullishEngulfing(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BULLISH ENGULFING";
      Type=BULLISH;
      Pattern=PATTERN_IS_BULLISHENGULFING;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectEngulfingBear && IsBearishEngulfing(Symbol(),PERIOD_CURRENT,1))
     {
      Label="BEARISH ENGULFING";
      Type=BEARISH;
      Pattern=PATTERN_IS_BEARISHENGULFING;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectTweezerTop && IsTweezerTop(Symbol(),PERIOD_CURRENT,1))
     {
      Label="TWEEZER TOP";
      Type=BEARISH;
      Pattern=PATTERN_IS_TWEEZERTOP;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectTweezerBottom && IsTweezerBottom(Symbol(),PERIOD_CURRENT,1))
     {
      Label="TWEEZER BOTTOM";
      Type=BULLISH;
      Pattern=PATTERN_IS_TWEEZERBOTTOM;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectInvertedHammer && IsInvertedHammer(Symbol(),PERIOD_CURRENT,1))
     {
      Label="INVERTED HAMMER";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_INVERTEDHAMMER;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectShootingStar && IsShootingStar(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SHOOTING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_SHOOTINGSTAR;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectHammer && IsHammer(Symbol(),PERIOD_CURRENT,1))
     {
      Label="HAMMER";
      Type=BULLISH;
      Pattern=PATTERN_IS_HAMMER;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
    //if(DetectHangingMan && IsHangingMan(Symbol(),PERIOD_CURRENT,1))
    //  {
    //   Label="HANGING MAN";
    //   Type=UNCERTAIN;
    //   Pattern=PATTERN_IS_HANGINMAN;
    //   //PatternDetected[1]=Pattern;
    //   //PatternDirection[1]=Type;
    //   DrawLabel(1,Label,Type);
    //   ChartRedraw(0);
    //   return;
    //  }
   if(DetectMarubozuUp && IsMarubozuUp(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MARUBOZU UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_MARUBOZUUP;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
     DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectMarubozuDown && IsMarubozuDown(Symbol(),PERIOD_CURRENT,1))
     {
      Label="MARUBOZU DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_MARUBOZUDOWN;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectSpinningTopBull && IsSpinningTopBullish(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SPINNING TOP BULLISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBULLISH;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectSpinningTopBear && IsSpinningTopBearish(Symbol(),PERIOD_CURRENT,1))
     {
      Label="SPINNING TOP BEARISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBEARISH;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectDojiDragonfly && IsDojyDragonfly(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI DRAGONFLY";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DRAGONFLY;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectDojiGravestone && IsDojiGravestone(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI GRAVESTONE";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_GRAVESTONE;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
   if(DetectDojiNeutral && IsDojiNeutral(Symbol(),PERIOD_CURRENT,1))
     {
      Label="DOJI";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DOJI;
      //PatternDetected[1]=Pattern;
      //PatternDirection[1]=Type;
      DrawLabel(1,Label,Type);    ChartRedraw(0);
      return;
     }
  }
//---
//+------------------------------------------------------------------+
//|   draw historic patterns on the chart                                                               |
//+------------------------------------------------------------------+
void DetectPattern(int i)
  {



    //for(int i=1;i<=MaxBars;i++){

    //if(PreviousDrawn && i>1) continue;
    //if(i==MaxBars) PreviousDrawn=true;
    //if(i>1)
    //NotifiedThisCandle=true;


   string Label="";

   ENUM_TYPE_OF_PATTERN Type;
   ENUM_CANDLESTICK_PATTERN Pattern=PATTERN_IS_NONE;

   if(DetectMorningStar && IsMorningStar(Symbol(),PERIOD_CURRENT,i))
     {
      Label="MORNING STAR";
      Type=BULLISH;
      Pattern=PATTERN_IS_MORNINGSTAR;

      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;

      DrawLabel(i,Label,Type);

     }
   if(DetectEveningStar && IsEveningStar(Symbol(),PERIOD_CURRENT,i))
     {
      Label="EVENING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_EVENINGSTAR;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectThreeInsideUp && IsThreeInsideUp(Symbol(),PERIOD_CURRENT,i))
     {
      Label="THREE INSIDE UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectThreeInsideDown && IsThreeInsideDown(Symbol(),PERIOD_CURRENT,i))
     {
      Label="THREE INSIDE DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREEINSIDEDOWN;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectThreeWhiteSoldier && IsThreeWhiteSoldiers(Symbol(),PERIOD_CURRENT,i))
     {
      Label="THREE WHITE SOLDIER";
      Type=BULLISH;
      Pattern=PATTERN_IS_THREEWHITESOLDIERS;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectThreeBlackCrows && IsThreeCrows(Symbol(),PERIOD_CURRENT,i))
     {
      Label="THREE BLACK CROWS";
      Type=BEARISH;
      Pattern=PATTERN_IS_THREECROWS;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectEngulfingBull && IsBullishEngulfing(Symbol(),PERIOD_CURRENT,i))
     {
      Label="BULLISH ENGULFING";
      Type=BULLISH;
      Pattern=PATTERN_IS_BULLISHENGULFING;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectEngulfingBear && IsBearishEngulfing(Symbol(),PERIOD_CURRENT,i))
     {
      Label="BEARISH ENGULFING";
      Type=BEARISH;
      Pattern=PATTERN_IS_BEARISHENGULFING;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectTweezerTop && IsTweezerTop(Symbol(),PERIOD_CURRENT,i))
     {
      Label="TWEEZER TOP";
      Type=BEARISH;
      Pattern=PATTERN_IS_TWEEZERTOP;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectTweezerBottom && IsTweezerBottom(Symbol(),PERIOD_CURRENT,i))
     {
      Label="TWEEZER BOTTOM";
      Type=BULLISH;
      Pattern=PATTERN_IS_TWEEZERBOTTOM;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectInvertedHammer && IsInvertedHammer(Symbol(),PERIOD_CURRENT,i))
     {
      Label="INVERTED HAMMER";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_INVERTEDHAMMER;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectShootingStar && IsShootingStar(Symbol(),PERIOD_CURRENT,i))
     {
      Label="SHOOTING STAR";
      Type=BEARISH;
      Pattern=PATTERN_IS_SHOOTINGSTAR;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectHammer && IsHammer(Symbol(),PERIOD_CURRENT,i))
     {
      Label="HAMMER";
      Type=BULLISH;
      Pattern=PATTERN_IS_HAMMER;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
    //   if(DetectHangingMan && IsHangingMan(Symbol(),PERIOD_CURRENT,i))
    //     {
    //      Label="HANGING MAN";
    //      Type=UNCERTAIN;
    //      Pattern=PATTERN_IS_HANGINMAN;
    //      //PatternDetected[i]=Pattern;
    //      //PatternDirection[i]=Type;
    //      DrawLabel(i,Label,Type);
    //
    //     }
   if(DetectMarubozuUp && IsMarubozuUp(Symbol(),PERIOD_CURRENT,i))
     {
      Label="MARUBOZU UP";
      Type=BULLISH;
      Pattern=PATTERN_IS_MARUBOZUUP;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectMarubozuDown && IsMarubozuDown(Symbol(),PERIOD_CURRENT,i))
     {
      Label="MARUBOZU DOWN";
      Type=BEARISH;
      Pattern=PATTERN_IS_MARUBOZUDOWN;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectSpinningTopBull && IsSpinningTopBullish(Symbol(),PERIOD_CURRENT,i))
     {
      Label="SPINNING TOP BULLISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBULLISH;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectSpinningTopBear && IsSpinningTopBearish(Symbol(),PERIOD_CURRENT,i))
     {
      Label="SPINNING TOP BEARISH";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_SPINNINGTOPBEARISH;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectDojiDragonfly && IsDojyDragonfly(Symbol(),PERIOD_CURRENT,i))
     {
      Label="DOJI DRAGONFLY";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DRAGONFLY;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectDojiGravestone && IsDojiGravestone(Symbol(),PERIOD_CURRENT,i))
     {
      Label="DOJI GRAVESTONE";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_GRAVESTONE;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);

     }
   if(DetectDojiNeutral && IsDojiNeutral(Symbol(),PERIOD_CURRENT,i))
     {
      Label="DOJI";
      Type=UNCERTAIN;
      Pattern=PATTERN_IS_DOJI;
      //PatternDetected[i]=Pattern;
      //PatternDirection[i]=Type;
      DrawLabel(i,Label,Type);
     }
  }