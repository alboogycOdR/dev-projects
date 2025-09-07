//+------------------------------------------------------------------+
//| Hedge engine helper functions                                   |
//+------------------------------------------------------------------+
#ifndef __HEDGE_ENGINE_MQH__
#define __HEDGE_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include <Files/File.mqh>

class CHedgeEngine
  {
private:
   string  m_signalFile;
   double  m_hedgeFactor;
   bool    m_bleedDone;
   double  m_stageTarget;
   double  m_startEquity;
   double  m_dailyDDCap;
   long    m_chart;

public:
   void Init(string signalFile,double challengeFee,double maxDD,double slipBuffer,
             double stageTarget,double dailyDD)
     {
      m_signalFile = signalFile;
      m_hedgeFactor = MathMin(1.0,(challengeFee*(1.0+slipBuffer))/maxDD);
      m_bleedDone   = false;
      m_stageTarget = stageTarget;
      m_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dailyDDCap  = dailyDD;
      m_chart       = ChartID();
     }

   // Reset daily equity at start of new day
   void UpdateDailyEquity()
     {
      datetime curDay = TimeDay(TimeCurrent());
      static int lastDay = -1;
      if(lastDay != curDay)
        {
         lastDay = curDay;
         m_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
        }
     }

   // Check if daily drawdown exceeded
   bool DailyDDExceeded()
     {
      double loss = m_startEquity - AccountInfoDouble(ACCOUNT_EQUITY);
      return(loss >= m_dailyDDCap);
     }

   // Send hedge instruction
   void SendSignal(string cmd,double lots,double sl,double tp)
     {
      int file = FileOpen(m_signalFile,FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_READ);
      if(file==INVALID_HANDLE) return;
      string line = StringFormat("%s,%s,%.2f,%.5f,%.5f",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),cmd,lots,sl,tp);
      FileSeek(file,0,SEEK_END);
      FileWriteString(file,line+"\n");
      FileClose(file);
     }

   double HedgeLots(double entryLots)
     {
      return(NormalizeDouble(entryLots*m_hedgeFactor,2));
     }

   // Check if profit reached 70% of stage target then bleed half hedge
   void CheckBleed(double currentProfit,double hedgeLots)
     {
      if(!m_bleedDone && currentProfit>=m_stageTarget*0.70)
        {
         m_bleedDone=true;
         SendSignal("BLEED",hedgeLots/2.0,0,0);
        }
     }
  };

#endif
