//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//bool isInSupportZone()
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),timeframeglobal,0,3,Close);
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      if(Close[1]>=zone_lo[i] && Close[1]<zone_hi[i])
//        {
//         if(!showVerifiedOnly)
//           {
//            if(zone_type[i]==ZONE_SUPPORT)
//              {
//               if(zone_strength[i]==ZONE_WEAK)
//                 {
//                  Print("WEAK");
//                 }
//               if(zone_strength[i]==ZONE_UNTESTED)
//                 {
//                  Print("UNTESTED");
//                 }
//               if(zone_strength[i]==ZONE_TURNCOAT)
//                 {
//                  Print("TURNCOAT");
//                 }
//               if(zone_strength[i]==ZONE_PROVEN)
//                 {
//                  Print("PROVEN");
//                 }
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("VERIFIED");
//                 }
//               return true;
//              }//if zone==support
//           }//if !showverified
//
//         if(showVerifiedOnly)
//           {
//            if(zone_type[i]==ZONE_SUPPORT)
//              {
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("IN VERIFIED SUPPORT");
//                  return true;
//                 }
//              }
//           }
//
//        }//if close
//     }//for loop
//   return(false);
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool BreakfromSUPPORT_BullishEngulf(double &dynamicTP,double &dynamicSL)
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//   double Low[];
//   ArraySetAsSeries(Low,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,Low);
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//   double High[];
//   ArraySetAsSeries(High,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,High);
//// -------------------
//   bool bullengulf=false;
//   bullengulf=IsBullishEngulfing(Symbol(),PERIOD_CURRENT,1);
//   bool candlestructurecorrect=false;
//// -------------------
//
////---
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//
//      double c1=NormalizeDouble(Close[1],Digits());
//      double l1=NormalizeDouble(Low[1],Digits());
//      double o1=NormalizeDouble(Open[1],Digits());
//
//      if(zone_type[i]==ZONE_SUPPORT)//if (zone_strength[i]==ZONE_VERIFIED)
//        {
//         if((c1 > zone_hi[i])&& (l1<zone_hi[i]  || o1 < zone_hi[i]))
//           {
//            dynamicSL=zone_lo[i];
//            candlestructurecorrect=true;
//            break;
//           }
//        }
//     }//for loop
//
//   if(candlestructurecorrect&&bullengulf)
//     {
//      return true;
//     }
//
//   return false;
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool BreakfromRESISTENCE_BearishEngulf(double &dynamicTP,double &dynamicSL)
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//
//   double Low[];
//   ArraySetAsSeries(Low,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,Low);
//
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//
//   double High[];
//   ArraySetAsSeries(High,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,High);
//// -------------------
//   bool bearengulf=false;
//   bearengulf=IsBearishEngulfing(Symbol(),PERIOD_CURRENT,1);
//   bool candlestructurecorrect=false;
//// -------------------
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//
//      double c1=NormalizeDouble(Close[1],Digits());
//      double l1=NormalizeDouble(Low[1],Digits());
//      double o1=NormalizeDouble(Open[1],Digits());
//      double h1=NormalizeDouble(High[1],Digits());
//
//      if(zone_type[i]==ZONE_RESIST)//if (zone_strength[i]==ZONE_VERIFIED)
//        {
//         if((c1 < zone_lo[i])&& (l1>zone_lo[i]  || o1 > zone_lo[i]))
//           {
//            dynamicSL=zone_hi[i];
//            candlestructurecorrect=true;
//            break;
//           }
//        }
//     }//for loop
//
//   if(candlestructurecorrect&&bearengulf)
//     {
//      return true;
//     }
//   return false;
//
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool ExitSupportZone(double &dynamicTP,double &dynamicSL)
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//
//   double Low[];
//   ArraySetAsSeries(Low,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,Low);
//
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//      Close[2]=NormalizeDouble(Close[2],Digits());
//
//      /*debug*/
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED))
//        {
//         //Print("zone high:" +zone_hi[i] );Print("zone low:" + zone_lo[i]);
//        }
//      /*condition#1*/
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) && (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] > zone_hi[i]))
//        {
//         //Print("Condition 1 -dip in and out");
//         //Print("zone high:" +zone_hi[i]);
//         //Print("zone low:" + zone_lo[i]);
//         //Print("Close[2]:" +Close[2]);
//         //Print("Close[1]:" +Close[1]);
//        }
//
//
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED)&&(Open[2] > Close[2])
//         && (Close[2] >= zone_hi[i])
//         && (Low[2] <=zone_hi[i])
//         && (Open[1] < Close[1])
//         && (Open[1] >= zone_hi[i])
//         && (Low[1] <=zone_hi[i]))
//        {
//         // Print("Condition 2 - LOWS touch and go");
//        }
//
//
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED)
//         /*&&(IsDojiDragonfly(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//         || IsDojiNeutral(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//         ||IsDojiGravestone(Symbol(),PERIOD_CURRENT,1,zone_hi[i])*/)
//        {
//         // Print("Condition 3 - doji condition");
//        }
//
//
//
//      if(
//         /*condition#1*/((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) && (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] > zone_hi[i]))
//         ||
//         /*condition#2*/((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) &&(Open[2] > Close[2])
//                         && (Close[2] >= zone_hi[i])
//                         && (Low[2] <=zone_hi[i])
//                         && (Open[1] < Close[1])
//                         && (Open[1] >= zone_hi[i])
//                         && (Low[1] <=zone_hi[i]))
//         ||
//         /*condition#3*/
//         ((zone_type[i]==ZONE_SUPPORT)
//          &&(zone_strength[i]==ZONE_VERIFIED)
//          /*&&IsDojiDragonfly(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//          || IsDojiNeutral(Symbol(),PERIOD_CURRENT,1,zone_hi[i])*/
//          /*||IsDojiGravestone(Symbol(),PERIOD_CURRENT,1,zone_hi[i]*/))
//        {
//         if(!showVerifiedOnly)
//           {
//            if(zone_type[i]==ZONE_SUPPORT)
//              {
//               if(zone_strength[i]==ZONE_WEAK)
//                 {
//                  Print("WEAK");
//                 }
//               if(zone_strength[i]==ZONE_UNTESTED)
//                 {
//                  Print("UNTESTED");
//                 }
//               if(zone_strength[i]==ZONE_TURNCOAT)
//                 {
//                  Print("TURNCOAT");
//                 }
//               if(zone_strength[i]==ZONE_PROVEN)
//                 {
//                  Print("PROVEN");
//                 }
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("VERIFIED");
//                 }
//               return true;
//              }//if zone==support
//           }//if !showverified
//
//         if(showVerifiedOnly)
//           {
//            if(zone_type[i]==ZONE_SUPPORT)
//              {
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print(__FUNCTION__+"VERIFIED SUPPORT EXIT"+__LINE__);
//                  Print("__________________________");
//                  dynamicSL=zone_lo[i];
//                  return true;
//                 }
//              }
//           }
//
//
//
//        }//if close
//     }//for loop
//   return(false);
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool ExitSupportZone()
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//
//   double Low[];
//   ArraySetAsSeries(Low,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,Low);
//
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//      Close[2]=NormalizeDouble(Close[2],Digits());
//
//      /*debug*/
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED))
//        {
//         //Print("zone high:" +zone_hi[i] );Print("zone low:" + zone_lo[i]);
//        }
//      /*condition#1*/
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) 
//&& (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] > zone_hi[i]))
//        {
//         //Print("Condition 1 -dip in and out");
//         //Print("zone high:" +zone_hi[i]);
//         //Print("zone low:" + zone_lo[i]);
//         //Print("Close[2]:" +Close[2]);
//         //Print("Close[1]:" +Close[1]);
//        }
//
//
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED)&&(Open[2] > Close[2])
//         && (Close[2] >= zone_hi[i])
//         && (Low[2] <=zone_hi[i])
//         && (Open[1] < Close[1])
//         && (Open[1] >= zone_hi[i])
//         && (Low[1] <=zone_hi[i]))
//        {
//         // Print("Condition 2 - LOWS touch and go");
//        }
//
//
//      if((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED)
//         /*&&(IsDojiDragonfly(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//         || IsDojiNeutral(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//         ||IsDojiGravestone(Symbol(),PERIOD_CURRENT,1,zone_hi[i])*/)
//        {
//         // Print("Condition 3 - doji condition");
//        }
//
//
//
//      if(
//         /*condition#1*/((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) && (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] > zone_hi[i]))
//         ||
//         /*condition#2*/((zone_type[i]==ZONE_SUPPORT)&&(zone_strength[i]==ZONE_VERIFIED) &&(Open[2] > Close[2])
//                         && (Close[2] >= zone_hi[i])
//                         && (Low[2] <=zone_hi[i])
//                         && (Open[1] < Close[1])
//                         && (Open[1] >= zone_hi[i])
//                         && (Low[1] <=zone_hi[i]))    ||
//         /*condition#3*/
//         ((zone_type[i]==ZONE_SUPPORT)     &&(zone_strength[i]==ZONE_VERIFIED)
//          /*&&IsDojiDragonfly(Symbol(),PERIOD_CURRENT,1,zone_hi[i])
//          || IsDojiNeutral(Symbol(),PERIOD_CURRENT,1,zone_hi[i])*/
//          /*||IsDojiGravestone(Symbol(),PERIOD_CURRENT,1,zone_hi[i]*/))
//        {
//         if(showVerifiedOnly)
//           {
//            if(zone_type[i]==ZONE_SUPPORT)
//              {
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  //Print(__FUNCTION__+"VERIFIED SUPPORT EXIT "+__LINE__);
//                  //Print("__________________________");
//
//                  return true;
//                 }
//              }
//           }
//
//
//
//        }//if close
//     }//for loop
//   return(false);
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool ExitResistenceZone(double &dynamicTP,double &dynamicSL)
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//
//   double High[];
//   ArraySetAsSeries(High,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,High);
//
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//      Close[2]=NormalizeDouble(Close[2],Digits());
//      Close[1]=NormalizeDouble(Close[1],Digits());
//      High[2]=NormalizeDouble(High[2],Digits());
//      High[1]=NormalizeDouble(High[1],Digits());
//
//      /*condition#1*/
//      if((zone_type[i]==ZONE_RESIST)
//         &&(zone_strength[i]==ZONE_VERIFIED)
//         &&
//         (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] < zone_lo[i]))
//        {
//         //Print("Condition 1 -dip in and out");
//         //Print("zone high:" +zone_hi[i]);
//         //Print("zone low:" + zone_lo[i]);
//         //Print("Close[2]:" +Close[2]);
//         //Print("Close[1]:" +Close[1]);
//        }
//      if((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//         &&(Open[2] < Close[2])
//         && (Close[2] <= zone_lo[i])
//         && (High[2] >=zone_lo[i])
//         && (Open[1] > Close[1])
//         && (Open[1] <= zone_lo[i])
//         && (High[1] >=zone_lo[i]))
//        {
//         //Print("Condition 2 - HIGHS touch and go");
//        }
//      if((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//         &&
//         (IsDojiDragonflyR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//          ||
//          IsDojiNeutralR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//          ||
//          IsDojiGravestoneR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])))
//        {
//         //Print("Condition 3 - doji condition");
//        }
//
//
//
//      if(((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)&&
//          (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i])&& (Close[1] < zone_lo[i]))
//         || ((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)&&
//             (Open[2] < Close[2])&& (Close[2] <= zone_lo[i])&& (High[2] >=zone_lo[i])&& (Open[1] > Close[1])&& (Open[1] <= zone_lo[i])&& (High[1] >=zone_lo[i]))
//         ||
//         (
//            (zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//            &&(
//               IsDojiDragonflyR(Symbol(),PERIOD_CURRENT,1,zone_lo[i]) ||
//               IsDojiNeutralR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])||
//               IsDojiGravestoneR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//            )
//         )
//        )
//        {
//         if(!showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST)
//              {
//               if(zone_strength[i]==ZONE_WEAK)
//                 {
//                  Print("WEAK");
//                 }
//               if(zone_strength[i]==ZONE_UNTESTED)
//                 {
//                  Print("UNTESTED");
//                 }
//               if(zone_strength[i]==ZONE_TURNCOAT)
//                 {
//                  Print("TURNCOAT");
//                 }
//               if(zone_strength[i]==ZONE_PROVEN)
//                 {
//                  Print("PROVEN");
//                 }
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("VERIFIED");
//                 }
//               return true;
//              }
//
//
//
//         if(showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST&&zone_strength[i]==ZONE_VERIFIED)
//              {
//               Print("VERIFIED RESISTENCE EXIT");
//               Print("__________________________");
//               dynamicSL=zone_hi[i];
//               return true;
//              }
//        }//if close
//     }//for loop
//   return(false);
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool ExitResistenceZone()
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),PERIOD_CURRENT,0,3,Close);
//
//   double High[];
//   ArraySetAsSeries(High,true);
//   CopyLow(Symbol(),PERIOD_CURRENT,0,3,High);
//
//   double Open[];
//   ArraySetAsSeries(Open,true);
//   CopyOpen(Symbol(),PERIOD_CURRENT,0,3,Open);
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      zone_hi[i]=NormalizeDouble(zone_hi[i],Digits());
//      zone_lo[i]=NormalizeDouble(zone_lo[i],Digits());
//      Close[2]=NormalizeDouble(Close[2],Digits());
//      Close[1]=NormalizeDouble(Close[1],Digits());
//      High[2]=NormalizeDouble(High[2],Digits());
//      High[1]=NormalizeDouble(High[1],Digits());
//
//      /*condition#1*/
//      if((zone_type[i]==ZONE_RESIST)
//         &&(zone_strength[i]==ZONE_VERIFIED)
//         &&
//         (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i]) && (Close[1] < zone_lo[i]))
//        {
//         //Print("Condition 1 -dip in and out");
//         //Print("zone high:" +zone_hi[i]);
//         //Print("zone low:" + zone_lo[i]);
//         //Print("Close[2]:" +Close[2]);
//         //Print("Close[1]:" +Close[1]);
//        }
//      if((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//         &&(Open[2] < Close[2])
//         && (Close[2] <= zone_lo[i])
//         && (High[2] >=zone_lo[i])
//         && (Open[1] > Close[1])
//         && (Open[1] <= zone_lo[i])
//         && (High[1] >=zone_lo[i]))
//        {
//         //Print("Condition 2 - HIGHS touch and go");
//        }
//      if((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//         &&
//         (IsDojiDragonflyR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//          ||
//          IsDojiNeutralR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//          ||
//          IsDojiGravestoneR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])))
//        {
//         //Print("Condition 3 - doji condition");
//        }
//
//
//
//      if(((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)&&
//          (Close[2]>=zone_lo[i] && Close[2]<zone_hi[i])&& (Close[1] < zone_lo[i]))
//         || ((zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)&&
//             (Open[2] < Close[2])&& (Close[2] <= zone_lo[i])&& (High[2] >=zone_lo[i])&& (Open[1] > Close[1])&& (Open[1] <= zone_lo[i])&& (High[1] >=zone_lo[i]))
//         ||
//         (
//            (zone_type[i]==ZONE_RESIST)&&(zone_strength[i]==ZONE_VERIFIED)
//            &&(
//               IsDojiDragonflyR(Symbol(),PERIOD_CURRENT,1,zone_lo[i]) ||
//               IsDojiNeutralR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])||
//               IsDojiGravestoneR(Symbol(),PERIOD_CURRENT,1,zone_lo[i])
//            )
//         )
//        )
//        {
//         if(!showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST)
//              {
//               if(zone_strength[i]==ZONE_WEAK)
//                 {
//                  Print("WEAK");
//                 }
//               if(zone_strength[i]==ZONE_UNTESTED)
//                 {
//                  Print("UNTESTED");
//                 }
//               if(zone_strength[i]==ZONE_TURNCOAT)
//                 {
//                  Print("TURNCOAT");
//                 }
//               if(zone_strength[i]==ZONE_PROVEN)
//                 {
//                  Print("PROVEN");
//                 }
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("VERIFIED");
//                 }
//               return true;
//              }
//
//
//
//         if(showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST&&zone_strength[i]==ZONE_VERIFIED)
//              {
//               Print("VERIFIED RESISTENCE EXIT");
//               Print("__________________________");
//               //dynamicSL=zone_hi[i];
//               return true;
//              }
//        }//if close
//     }//for loop
//   return(false);
//  }
//
////+------------------------------------------------------------------+
////|                                                                  |
////+------------------------------------------------------------------+
//bool isInResistenceZone()
//  {
//   double Close[];
//   ArraySetAsSeries(Close,true);
//   CopyClose(Symbol(),timeframeglobal,0,3,Close);
//
//   for(int i=0; i<zone_count; i++)
//     {
//      if(zone_strength[i]==ZONE_WEAK && zone_show_weak==false)
//         continue;
//      if(zone_strength[i]==ZONE_UNTESTED && zone_show_untested==false)
//         continue;
//      if(zone_strength[i]==ZONE_TURNCOAT && zone_show_turncoat==false)
//         continue;
//
//      if(Close[0]>=zone_lo[i] && Close[0]<zone_hi[i])
//        {
//         if(!showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST)
//              {
//               if(zone_strength[i]==ZONE_WEAK)
//                 {
//                  Print("WEAK");
//                 }
//               if(zone_strength[i]==ZONE_UNTESTED)
//                 {
//                  Print("UNTESTED");
//                 }
//               if(zone_strength[i]==ZONE_TURNCOAT)
//                 {
//                  Print("TURNCOAT");
//                 }
//               if(zone_strength[i]==ZONE_PROVEN)
//                 {
//                  Print("PROVEN");
//                 }
//               if(zone_strength[i]==ZONE_VERIFIED)
//                 {
//                  Print("VERIFIED");
//                 }
//               return true;
//              }
//         if(showVerifiedOnly)
//            if(zone_type[i]==ZONE_RESIST&&zone_strength[i]==ZONE_VERIFIED)
//              {
//               Print("VERIFIED RESISTENCE ZONE");
//               return true;
//              }
//        }//if close
//     }//for loop
//   return(false);
//  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
