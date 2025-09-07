//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


//===INTEGRATE CONTROLS TO MANAGE METATRADER
//      IN RESPONSE TO NEWS

#include <WinAPI\winapi.mqh>
#define MT_WMCMD_EXPERTS   32851
#define WM_COMMAND 0x0111
#define GA_ROOT    2

//+------------------------------------------------------------------+
//|  Counts the number of pending orders for a specific symbol or all symbols.                                                                |
//+------------------------------------------------------------------+
int PlacedPendings(string pair)
  {
   int c = 0;
   for(int i = 0 ; i < PositionsTotal() ; i++)
     {
      if(PositionGetTicket(i)>0)
        {
         if(PositionGetSymbol(i) == pair || pair == "all")
           {
            if(PositionGetInteger(POSITION_TYPE) > POSITION_TYPE_SELL)
              {
               c++;
              }
           }
        }
     }
   return c;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TitleSelected(string title)
  {
   if(!use_title)
     {
      return true;
     }
   else
     {
      string titles = title_phrase;
      string keywords[];
      if(StringGetCharacter(titles, 0) == 44)
         titles = StringSubstr(titles,1,StringLen(titles)-1);
      if(StringGetCharacter(titles, StringLen(titles)-1) == 44)
         titles = StringSubstr(titles,0,StringLen(titles)-2);
      if(StringFind(titles,",")!=-1)
        {
         string sep=",";
         ushort u_sep;
         u_sep=StringGetCharacter(sep,0);
         int k=StringSplit(titles,u_sep,keywords);
         ArrayResize(keywords,k,k);
         if(k>0)
           {
            for(int i=0;i<k;i++)
              {
               if(StringFind(title,keywords[i]) != -1)
                  return true;
              }
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CurrencySelected(string curr)
  {
   if(StringFind(sybmols_list,curr) != -1)
      return true;
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawNews()
  {
   string newsobjname;
   for(int i = ObjectsTotal(0,0,-1) -1 ;i >= 0; i--)
     {
      newsobjname = ObjectName(0,i,0);
      if(StringFind(newsobjname, "_NEWS_", 0) > -1)
        {
         ObjectDelete(0,newsobjname);
        }
     }
   ChartRedraw(0);

   /*



   */
   if(draw_news_lines)
     {
      for(int c = 0; c<100; c++)
        {
         if((news_events[c].currency != "") && (news_events[c].event_time !=0))
           {
            datetime t1=((news_events[c].event_time+(datetime)time_offset_newsea));
            string NAME=news_events[c].currency+" : "+news_events[c].event_title+" - Impact: "+news_events[c].event_impact;
            string RandString=IntegerToString(MathRand());
            string NAMEOBJ=NAME+"_NEWS_"+RandString;

            //----
            //string NAMEOBJLBL=NAME+"_NEWS_"+"lbl"+RandString;
            string NAMEOBJLBL= "_NEWSTEXT_"+(string)t1;
            string NAMEOBJLBL2= "_NEWSTEXT_"+(string)t1+RandString;

            /*



            */
            ChartRedraw(0);

            if(ObjectFind(0,NAMEOBJ)<0)
              {
               // Print(__LINE__);
               ObjectCreate(0,NAMEOBJ,OBJ_VLINE,0,t1,0);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_SELECTABLE,false);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_SELECTED,false);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_HIDDEN,true);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_BACK,false);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_COLOR,Line_Color);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_STYLE,Line_Style);
               ObjectSetInteger(0,NAMEOBJ,OBJPROP_WIDTH,Line_Width);
               ObjectSetString(0,NAMEOBJ,OBJPROP_TEXT,NAME);
               // 1. Get Vertical Line Properties
               //long vline_time = ObjectGetInteger(0, "VLine", OBJPROP_TIME1);
               // 2. Create Text Label
               
              }
            if(ObjectFind(0,NAMEOBJLBL)<0)
              {
               //Print(__LINE__);
               ResetLastError();
               double maxPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
               /*



               */
               bool success=ObjectCreate(0,NAMEOBJLBL, OBJ_TEXT, 0,t1, maxPrice);
               //Print("lbl create was: "+success+" err: "+GetLastError());
               //ObjectCreate(0, NAMEOBJ, OBJ_TEXT, 0, t1,0);
               ObjectSetString(0, NAMEOBJLBL, OBJPROP_TEXT, NAME);
               ObjectSetDouble(0,NAMEOBJLBL,OBJPROP_ANGLE,-90);
               ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_CORNER, CORNER_LEFT_UPPER);
               //ObjectSetInteger(0, NAMEOBJ, OBJPROP_XDISTANCE, 5); // Adjust for positioning
               //if(c % 2 == 0)
               //  {
               ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_YDISTANCE, 20);
               //  }
               //else
               //  {
               //   ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_YDISTANCE, 150);
               //  }
               ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_COLOR, clrRed); // Or your preferred color
               ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_FONTSIZE, 7);  // Adjust for font size
              }
              
            if(ObjectFind(0,NAMEOBJLBL)==0)
              {
               //Print(__LINE__);
               ResetLastError();
               double maxPrice = ChartGetDouble(0, CHART_PRICE_MAX, 0);
               /*



               */
               bool success=ObjectCreate(0,NAMEOBJLBL2, OBJ_TEXT, 0,t1, maxPrice);
               //Print("lbl create was: "+success+" err: "+GetLastError());
               //ObjectCreate(0, NAMEOBJ, OBJ_TEXT, 0, t1,0);
               ObjectSetString(0, NAMEOBJLBL2, OBJPROP_TEXT, NAME);
               ObjectSetDouble(0,NAMEOBJLBL2,OBJPROP_ANGLE,-90);
               //ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_CORNER, CORNER_LEFT_UPPER);
               ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_XDISTANCE, 5); // Adjust for positioning
               ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_ANCHOR, ALIGN_LEFT); // Adjust for positioning
               //if(c % 2 == 0)
               //  {
               ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_YDISTANCE, 600);
               //  }
               //else
               //  {
               //   ObjectSetInteger(0, NAMEOBJLBL, OBJPROP_YDISTANCE, 150);
               //  }
               ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_COLOR, clrOrange); // Or your preferred color
               ObjectSetInteger(0, NAMEOBJLBL2, OBJPROP_FONTSIZE, 7);  // Adjust for font size
               
               
              }
              
              
              ChartRedraw(0);
           }
        }
     }
  }
//=======================news functions below


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NewsUpdate()
  {
   string cookie=NULL,referer=NULL,headers;
   char post[],result[];
   string sUrl="https://nfs.faireconomy.media/ff_calendar_thisweek.xml";
   ResetLastError();
   int res = WebRequest("GET",sUrl,cookie,referer,5000,post,sizeof(post),result,headers);
   if(res==-1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      if(ArraySize(result)<=0)
        {
         int er=GetLastError();
         ResetLastError();
         Print("ERROR_TXT IN WebRequest");
         if(er==4060)
            MessageBox("Please add the address '"+"https://nfs.faireconomy.media/"+"' in the list of allowed URLs in the 'Advisers' tab ","ERROR_TXT ",MB_ICONINFORMATION);
         return ;
        }
      Sleep(5000);
     }
   else //request successfull
     {
      string info = CharArrayToString(result,0,WHOLE_ARRAY,CP_UTF8);
      int start_pos = StringFind(info,"<weeklyevents>",0);
      int finish_pos = StringFind(info,"</weeklyevents>",0);
      info = StringSubstr(info,start_pos,finish_pos-start_pos);
      for(int i=0; i<500; i++)
        {
         news_events[i].currency = "";
         news_events[i].event_title = "";
         news_events[i].event_time = 0;
         news_events[i].event_impact = "";
        }
      if(StringFind(info,"No Events Scheduled") != -1)
        {
         event_count =0;
        }
      else
        {
         int c =0;
         while(StringFind(info,"<event>") != -1)
           {
            int start_event = StringFind(info,"<event>",0);
            int finish_event = StringFind(info,"</event>",start_event);
            int curr_start = StringFind(info,"<country>",start_event)+9;
            int curr_finish = StringFind(info,"</country>",start_event);
            int title_start = StringFind(info,"<title>",start_event)+7;
            int title_finish = StringFind(info,"</title>",start_event);
            int date_start = StringFind(info,"<date><![CDATA[",start_event)+15;
            int date_finish = StringFind(info, "]]></date>",start_event);
            int time_start = StringFind(info, "<time><![CDATA[",start_event)+15;
            int time_finish = StringFind(info,"]]></time>",start_event);
            int impact_start = StringFind(info,"<impact><![CDATA[",start_event)+17;
            int impact_finish = StringFind(info,"]]></impact>",start_event);
            string ev_curr = StringSubstr(info,curr_start,curr_finish-curr_start);
            string ev_title = StringSubstr(info,title_start,title_finish-title_start);
            string ev_date = StringSubstr(info,date_start,date_finish-date_start);
            string ev_time = StringSubstr(info,time_start,time_finish-time_start);
            string ev_impact = StringSubstr(info,impact_start,impact_finish-impact_start);
            info = StringSubstr(info,finish_event+8);
            if(CurrencySelected(ev_curr) && TitleSelected(ev_title) && ImpactSelected(ev_impact))
              {
               news_events[c].currency = ev_curr;
               news_events[c].event_title = ev_title;
               news_events[c].event_time = StringToTime(MakeDateTime(ev_date,ev_time));
               news_events[c].event_impact = ev_impact;
               //Print(news_events[c].currency+" "+(string)news_events[c].event_time);
               c++;
              }
           }
         event_count = c;
        }
     }
   if(debug) Print("News Events Updated!");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MakeDateTime(string strDate,string strTime)
  {
//---
   int n1stDash=StringFind(strDate, "-");
   int n2ndDash=StringFind(strDate, "-", n1stDash+1);
   string strMonth=StringSubstr(strDate,0,2);
   string strDay=StringSubstr(strDate,3,2);
   string strYear=StringSubstr(strDate,6,4);
   int nTimeColonPos=StringFind(strTime,":");
   string strHour=StringSubstr(strTime,0,nTimeColonPos);
   string strMinute=StringSubstr(strTime,nTimeColonPos+1,2);
   string strAM_PM=StringSubstr(strTime,StringLen(strTime)-2);
   long nHour24=StringToInteger(strHour);
   if((strAM_PM=="pm" || strAM_PM=="PM") && nHour24!=12)
      nHour24+=12;
   if((strAM_PM=="am" || strAM_PM=="AM") && nHour24==12)
      nHour24=0;
   string strHourPad="";
   if(nHour24<10)
      strHourPad="0";
   string result;
   int ch = StringConcatenate(result,strYear, ".", strMonth, ".", strDay, " ", strHourPad, nHour24, ":", strMinute);
   return result;
//---
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ImpactSelected(string impact)
  {
   if(include_high && (StringFind(impact,"High") != -1))
      return true;
   if(include_medium && (StringFind(impact,"Medium") != -1))
      return true;
   if(include_low && (StringFind(impact,"Low") != -1))
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AtNews()
  {
   for(int c = 0; c<ArraySize(news_events); c++)
     {
      if((news_events[c].currency != "") && (news_events[c].event_time !=0))
        {
         if(StringFind(sybmols_list,news_events[c].currency) != -1)
           {
            if((TimeGMT() <= (news_events[c].event_time + (min_after*60))) && (TimeGMT() >= (news_events[c].event_time - (min_before*60))))
               return news_events[c].currency;
           }
        }
     }
   return "No News";
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string BeforeNewsForZeroProfit()
  {
   for(int c = 0; c<ArraySize(news_events); c++)
     {
      if((news_events[c].currency != "") && (news_events[c].event_time !=0))
        {
         if(StringFind(sybmols_list,news_events[c].currency) != -1)
           {
            if((TimeGMT() <= (news_events[c].event_time)) && (TimeGMT() >= (news_events[c].event_time - (min_before_zero*60))))
               return news_events[c].currency;
           }
        }
     }
   return "No News";
  }




//+------------------------------------------------------------------+
//|   This function counts the number of open trades for a specific symbol or all symbols.                                                               |
//+------------------------------------------------------------------+
int OpenTrades(string pair)
  {
   int c = 0;
   for(int i = 0 ; i < PositionsTotal() ; i++)
     {
      if(PositionGetTicket(i)>0)
        {
         if(PositionGetSymbol(i) == pair || pair == "all")
           {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
              {
               c++;
              }
           }
        }
     }
   return c;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteAllPendings(string pair)
  {
   for(int j = OrdersTotal()-1; j>=0; j--)
     {
      if(OrderGetTicket(j)>0)
        {
         if(OrderGetString(ORDER_SYMBOL) == pair || pair == "all")
           {
            if(MarketOpen(OrderGetString(ORDER_SYMBOL)) && OrderGetDouble(ORDER_VOLUME_CURRENT) > 0)
              {
               trade.SetTypeFillingBySymbol(OrderGetString(ORDER_SYMBOL));
               trade.SetDeviationInPoints(slippage);
               bool res = trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
               if(!res)
                  Print("close error ",GetLastError());
               Sleep(200);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAll(string pair)
  {
   for(int i=PositionsTotal() -1; i>=0; i--)
     {
      if(PositionGetTicket(i)>0)
        {
         if(PositionGetSymbol(i)== pair || pair == "all")
           {
            if((PositionGetInteger(POSITION_TYPE)==1 || PositionGetInteger(POSITION_TYPE)==0))
              {
               if(MarketOpen(PositionGetSymbol(i)))
                 {
                  trade.SetTypeFillingBySymbol(PositionGetString(POSITION_SYMBOL));
                  trade.SetDeviationInPoints(5);
                  bool res = trade.PositionClose(PositionGetInteger(POSITION_TICKET));
                  if(!res)
                     Print("close error ",GetLastError());
                  Sleep(200);
                 }
              }
           }
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void HANDLE_NEWS_EVENTS()
  {
   if(close_zero)
     {
      if(BeforeNewsForZeroProfit() != "No News" && allow_trade)
        {
         if(AccountInfoDouble(ACCOUNT_PROFIT)>=close_profit)
           {
            string msg1="[NEWS!] ";
            string _pair ="";
            if(close_only_news_pair)
              {
               _pair = BeforeNewsForZeroProfit();
              }
            else
              {
               _pair = "all";
              }
            if(close_charts)
              {
               for(long ch=ChartFirst();ch >= 0;ch=ChartNext(ch))
                 {
                  bool chart_symbol =true;
                  if(_pair != "all")
                    {
                     if(StringFind(ChartSymbol(ch), _pair) != -1)
                       {
                        chart_symbol = true;
                       }
                     else
                       {
                        chart_symbol = false;
                       }
                    }
                  if(ch!=ChartID() && chart_symbol)
                     ChartClose(ch);
                 }
               msg1 +="All charts are Closed. ";
              }
            CloseAll(_pair);
            if(OpenTrades(_pair)>0)
              {
               Sleep(delay*1000);
               return;
              }
            msg1 +="Closed all trades with zero profit. ";
            if(close_pending)
              {
               DeleteAllPendings(_pair);
               if(PlacedPendings(_pair)>0)
                 {
                  Sleep(delay*1000);
                  return;
                 }
               msg1 +="All pendings are Deleted. ";
              }
            if(stop_algo)
              {
               if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
                 {
                  AlgoTradingStatus(false);
                 }
               msg1 +="Auto trading is Disabled. ";
              }
            Print(msg1);
            if(send_notif)
               SendNotification(msg1);
            if(send_alert)
               Alert(msg1);
            allow_trade = false;
           }
        }
     }
   if(AtNews() != "No News" && allow_trade)
     {
      string msg1="[NEWS!] ";
      string _pair ="";
      if(close_only_news_pair)
        {
         _pair = AtNews();
        }
      else
        {
         _pair = "all";
        }
      if(close_charts)
        {
         for(long ch=ChartFirst();ch >= 0;ch=ChartNext(ch))
           {
            bool chart_symbol =true;
            if(_pair != "all")
              {
               if(StringFind(ChartSymbol(ch), _pair) != -1)
                 {
                  chart_symbol = true;
                 }
               else
                 {
                  chart_symbol = false;
                 }
              }
            if(ch!=ChartID() && chart_symbol)
               ChartClose(ch);
           }
         msg1 +="All charts are Closed. ";
        }
      if(close_open)
        {
         CloseAll(_pair);
         if(OpenTrades(_pair)>0)
           {
            Sleep(delay*1000);
            return;
           }
         msg1 +="All trades are Closed. ";
        }
      if(close_pending)
        {
         DeleteAllPendings(_pair);
         if(PlacedPendings(_pair)>0)
           {
            Sleep(delay*1000);
            return;
           }
         msg1 +="All pendings are Deleted. ";
        }
      if(stop_algo)
        {
         if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
           {
            AlgoTradingStatus(false);
           }
         msg1 +="Auto trading is Disabled. ";
        }
      Print(msg1);
      if(send_notif)
         SendNotification(msg1);
      if(send_alert)
         Alert(msg1);
      allow_trade = false;
     }
   else
      if(AtNews() == "No News" && !allow_trade)
        {
         if(stop_algo)
           {
            if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
              {
               AlgoTradingStatus(true);
              }
           }
         allow_trade = true;
        }
//Comment("\n\n     Current GMT time:               "+(string)TimeGMT()
//        +"\n     Count of Open positions:         "+(string)OpenTrades("all")
//        +"\n     Currently at news ?               "+((AtNews()!="No News")?("True ("+AtNews()+")"):(AtNews()))
//        +"\n     Time to Close with Profit ?     "+((BeforeNewsForZeroProfit()!="No News")?("True ("+BeforeNewsForZeroProfit()+")"):("False")));
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MarketOpen(string pair)
  {
   datetime begin=0;
   datetime end=0;
   datetime now=TimeTradeServer();
   uint session_index=0;
   MqlDateTime today;
   TimeToStruct(now,today);
   if(SymbolInfoSessionTrade(pair,(ENUM_DAY_OF_WEEK) today.day_of_week,session_index,begin,end)==true)
     {
      string snow=TimeToString(now,TIME_MINUTES|TIME_SECONDS);
      string sbegin=TimeToString(begin,TIME_MINUTES|TIME_SECONDS);
      string send=TimeToString(end-1,TIME_MINUTES|TIME_SECONDS);
      now=StringToTime(snow);
      begin=StringToTime(sbegin);
      end=StringToTime(send);
      if(now>=begin && now<=end)
         return true;
     }
   return false;
  }








//+------------------------------------------------------------------+
//|AlgoTradingStatus - DEPENDENCY ON USER32.DLL                                                                  |
//+------------------------------------------------------------------+
void AlgoTradingStatus(bool Enable)
  {
   bool Status = (bool) TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
   if((Enable && Status) || (!Enable && !Status))
      return;
   HANDLE
   hChart      = (HANDLE) ChartGetInteger(ChartID(), CHART_WINDOW_HANDLE),
   hMetaTrader = GetAncestor(hChart, GA_ROOT);
   PostMessageW(hMetaTrader, WM_COMMAND, MT_WMCMD_EXPERTS, 0);
  }
//+------------------------------------------------------------------+
