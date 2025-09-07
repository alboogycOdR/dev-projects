//+---------------------------------------------------------------------+
//|                                                    CNewsWatcher.mqh |
//|                                  Copyright © 2013, Jordi Bassagañas |
//+---------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Mine\Enums.mqh>
#include <..\Experts\NewsWatcher\CBrain.mqh>
#include <..\Experts\NewsWatcher\CEvolution.mqh>
#include <..\Experts\NewsWatcher\CTechIndicators.mqh>
//+---------------------------------------------------------------------+
//| CNewsWatcher Class                                                  |
//+---------------------------------------------------------------------+
class CNewsWatcher
  {
protected:
   //--- Custom types
   CBrain               *m_brain;
   CEvolution           *m_evolution;
   CTechIndicators      *m_techIndicators; 
   //--- MQL5 types
   CTrade               *m_trade;
   CPositionInfo        *m_positionInfo;
public:
   //--- Constructor and destructor methods
                        CNewsWatcher(int stop_loss,int take_profit,double lot_size,string csv_file);
                        ~CNewsWatcher(void);
   //--- Getter methods
   CBrain               *GetBrain(void);
   CEvolution           *GetEvolution(void);
   CTechIndicators      *GetTechIndicators(void);
   CTrade               *GetTrade(void);
   CPositionInfo        *GetPositionInfo(void);
   //--- CNewsWatcher methods
   bool                 Init();
   void                 Deinit(void);
   void                 OnTick(double ask,double bid);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CNewsWatcher::CNewsWatcher(int stop_loss,int take_profit,double lot_size, string csv_file)
  {
   m_brain=new CBrain(stop_loss,take_profit,lot_size,csv_file);
   m_evolution=new CEvolution(DO_NOTHING);
   m_techIndicators=new CTechIndicators;
   m_trade=new CTrade();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsWatcher::~CNewsWatcher(void)
  {
   Deinit();
  }
//+------------------------------------------------------------------+
//| GetBrain                                                         |
//+------------------------------------------------------------------+
CBrain *CNewsWatcher::GetBrain(void)
  {
   return m_brain;
  }
//+------------------------------------------------------------------+
//| GetEvolution                                                     |
//+------------------------------------------------------------------+
CEvolution *CNewsWatcher::GetEvolution(void)
  {
   return m_evolution;
  }
//+------------------------------------------------------------------+
//| GetTechIndicators                                                |
//+------------------------------------------------------------------+
CTechIndicators *CNewsWatcher::GetTechIndicators(void)
  {
   return m_techIndicators;
  }  
//+------------------------------------------------------------------+
//| GetTrade                                                         |
//+------------------------------------------------------------------+
CTrade *CNewsWatcher::GetTrade(void)
  {
   return m_trade;
  }
//+------------------------------------------------------------------+
//| GetPositionInfo                                                  |
//+------------------------------------------------------------------+
CPositionInfo *CNewsWatcher::GetPositionInfo(void)
  {
   return m_positionInfo;
  }
//+------------------------------------------------------------------------+
//| CNewsWatcher OnTick                                                    |
//| Checks momentum's turbulences around the time of the news release      |
//+------------------------------------------------------------------------+
void CNewsWatcher::OnTick(double ask,double bid)
  {
//--- are there some news to process?  
   if(GetBrain().GetNewsContainer().GetCurrentIndex() < GetBrain().GetNewsContainer().GetTotal())
   {     
      double momentumBuffer[];
      
      GetTechIndicators().GetMomentum().GetBuffer(momentumBuffer, 2);
      
      //--- Number of seconds before the news releases. GMT +- timeWindow is the real time from which the robot starts 
      //--- listening to the market. For instance, if there is a news release programmed at 13:00 GMT you can set TimeWindow 
      //--- to 900 seconds so that the EA starts listening to the market fifteen minutes before that news release. 
      int timeWindow=600;
      
      CNew *currentNew = GetBrain().GetNewsContainer().GetCurrentNew();      
      int indexCurrentNew = GetBrain().GetNewsContainer().GetCurrentIndex();
            
      if(TimeGMT() >= currentNew.GetTimeRelease() + timeWindow)
      {
         GetBrain().GetNewsContainer().SetCurrentIndex(indexCurrentNew+1);
         return;
      }
      
      //--- is there any open position?
      if(!m_positionInfo.Select(_Symbol))
      {
         //--- if there is no open position, we try to open one
         bool timeHasCome = TimeGMT() >= currentNew.GetTimeRelease() - timeWindow && TimeGMT() <= currentNew.GetTimeRelease() + timeWindow;
             
         if(timeHasCome && momentumBuffer[0] > 100.10)
         {
            GetEvolution().SetStatus(SELL);
            GetBrain().GetNewsContainer().SetCurrentIndex(indexCurrentNew+1);
         }
         else if(timeHasCome && momentumBuffer[0] < 99.90)
         {
            GetEvolution().SetStatus(BUY);
            GetBrain().GetNewsContainer().SetCurrentIndex(indexCurrentNew+1);
         }
      }
      //--- if there is an open position, we let it work the mathematical expectation
      else 
      {
         GetEvolution().SetStatus(DO_NOTHING);         
      }  
      
      double tp;
      double sl; 

      switch(GetEvolution().GetStatus())
      {      
         case BUY:
            tp = ask + m_brain.GetTakeProfit() * _Point;
            sl = bid - m_brain.GetStopLoss() * _Point;
            GetTrade().PositionOpen(_Symbol,ORDER_TYPE_BUY,m_brain.GetSize(),ask,sl,tp);
            break;

         case SELL:
            sl = ask + m_brain.GetStopLoss() * _Point;
            tp = bid - m_brain.GetTakeProfit() * _Point;
            GetTrade().PositionOpen(_Symbol,ORDER_TYPE_SELL,m_brain.GetSize(),bid,sl,tp);
            break;

         case DO_NOTHING:
            // Nothing...
            break;
      }
   }   
//--- we exit when all the container's news have been processed
   else return;
  }
//+------------------------------------------------------------------+
//| CNewsWatcher initialization                                      |
//+------------------------------------------------------------------+
bool CNewsWatcher::Init(void)
  {
// Initialization logic here...
   return true;
  }
//+------------------------------------------------------------------+
//| CNewsWatcher deinitialization                                    |
//+------------------------------------------------------------------+
void CNewsWatcher::Deinit(void)
  {
   delete(m_brain);
   delete(m_evolution);
   delete(m_techIndicators);
   delete(m_trade);
   Print("CNewsWatcher deinitialization performed!");
   Print("Thank you for using this EA.");
  }
//+------------------------------------------------------------------+
