//+------------------------------------------------------------------+
//|                                                     SlaveEA.mq5  |
//|  Opens opposite trades based on instructions from MasterEA       |
//+------------------------------------------------------------------+
#property copyright ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Files/File.mqh>
#include <Dashboard.mqh>

CTrade trade;

input string SignalFile = "hedge_signal.txt";  // shared signal file

// last time processed
datetime lastSignalTime=0;

int OnInit()
  {
   DashboardInit();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   DashboardShutdown();
  }

// parse a line from the signal file
bool ParseSignal(string line,string &direction,double &lots,double &sl,double &tp)
  {
   string parts[];
   int count=StringSplit(line,',',parts);
   if(count<5) return(false);
   datetime t=StringToTime(parts[0]);
   if(t<=lastSignalTime) return(false);
   lastSignalTime=t;
   direction=parts[1];
   lots=StringToDouble(parts[2]);
   sl=StringToDouble(parts[3]);
   tp=StringToDouble(parts[4]);
   return(true);
  }

void CheckSignals()
  {
   int file=FileOpen(SignalFile,FILE_READ|FILE_TXT|FILE_COMMON);
   if(file==INVALID_HANDLE) return;
   while(!FileIsEnding(file))
     {
      string line=FileReadString(file);
      if(line=="" || StringFind(line,"ADJ")>=0) continue; // ignore adjustments
      string dir; double lots,sl,tp;
      if(ParseSignal(line,dir,lots,sl,tp))
        {
         if(dir=="BUY" && !PositionSelect(_Symbol))
            trade.Buy(lots,_Symbol,0,sl,tp);
         else if(dir=="SELL" && !PositionSelect(_Symbol))
            trade.Sell(lots,_Symbol,0,sl,tp);

        }
     }
   FileClose(file);
  }


void OnTick()
  {
   DashboardOnTick();
   CheckSignals();
  }
//+------------------------------------------------------------------+
