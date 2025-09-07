

//=======================================================
//candle patterns
input group "PRICE ACTION SETTINGS"
//input group              "Candle Patterns to detect"
//input group              "_Individual Pattern Selection_"
input group "[ Bullish candles - Trade at Support Zones ]"
bool              DetectBullish=true;                           //[Detect Bullish Patterns][Buy Trades]
input bool              DetectMarubozuUp=false;                        //Marubozu Bullish
input bool              DetectHammer=false;                            //Hammer
input bool              DetectTweezerBottom=false;                     //Tweezer Bottom
input bool              DetectEngulfingBull=true;                     //Bullish Engulfing
input bool              DetectThreeWhiteSoldier=false;                 //Three White Soldiers
input bool              DetectThreeInsideUp=false;                     //Three Inside Up
input bool              DetectMorningStar=false;                       //Morning Star
input bool              DetectBullPiercing=false;                      //Bull Piercing
input bool              DetectBullishHaramiUp=false;                     //Bullish Harami
input bool              DetectBullCross=false; //Bull Cross

input group "[ Bearish candles - Trade at Resistance Zones ]"
bool              DetectBearish=true;                           //[Detect Bearish Patterns][Sell Trades]
input bool              DetectMarubozuDown=false;                      //Marubozu Bearish
input bool              DetectThreeInsideDown=false;                   //Three Inside Down
input bool              DetectTweezerTop=false;                        //Tweezer Top
input bool              DetectShootingStar=false;                      //Shooting Star
input bool              DetectEveningStar=false;                       //Evening Star
input bool              DetectEngulfingBear=true;                     //Bearish Engulfing
input bool              DetectThreeBlackCrows=false;                   //Three Black Crows
input bool              DetectBearishHaramiDown=false;                  //Bearish Harami
input bool              DetectDarkCloud=false;                        //Dark Cloud
input bool              DetectBearCross=false;                        //Bear Cross

//input group "___uncertain___"
bool                    DetectUncertain=false;                         //[Detect Uncertain Patterns]
bool                    DetectDojiNeutral=false;                       //Doji
bool                    DetectDojiDragonfly=false;                     //Doji Dragonfly
bool                    DetectDojiGravestone=false;                    //Doji Gravestone
bool                    DetectInvertedHammer=false;                    //Inverted Hammer
bool                    DetectHangingMan=false;                        //Hanging Man
bool                    DetectSpinningTopBull=false;                   //Spinning Top Bullish
bool                    DetectSpinningTopBear=false;                   //Spinning Top Bearish

input group             "[ Candle Options ]"
int               HISTORIC_CANDLES_TO_DRAW=600; // backlog candles
input bool             ShowCandleLables=false;//Draw Candle Pattern Lables
input bool             ShowCandleArrows=false;//Draw Candle Pattern Arrows
input int               FontSize=7;                                    //Font Size
input color             FontColorBullish=clrBlack;                   //Font Color Bullish Patterns
input color             FontColorBearish=clrBlack;                     //Font Color Bearish Patterns
color             FontColorUncertain=clrSilver;                 //Font Color Uncertain Patterns
bool                   EnableDrawHistoricCandles=false;//Draw Historic Candles

//input group "Alerts & Notifications"
 bool              EnableNotify=false;                          //Enable Notifications Feature
 bool              SendAlert=false;                              //Send Alert Notification
 bool              SendApp=false;                               //Send Notification to Mobile
 bool              SendEmail=false;                             //Send Notificatio