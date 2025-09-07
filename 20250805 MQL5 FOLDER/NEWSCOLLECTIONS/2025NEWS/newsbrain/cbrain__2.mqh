//+------------------------------------------------------------------+
//|                                                       CBrain.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+
#include <..\Experts\NewsWatcher\CNewsContainer.mqh>
//+------------------------------------------------------------------+
//| CBrain Class                                                     |
//+------------------------------------------------------------------+
class CBrain
  {
protected:
   double               m_size;                 // The size of the positions
   int                  m_stopLoss;             // Stop loss
   int                  m_takeProfit;           // Take profit
   CNewsContainer       *m_news_container;      // The news container

public:
   //--- Constructor and destructor methods
                        CBrain(int stopLoss,int takeProfit,double size,string csv);
                        ~CBrain(void);
   //--- Getter methods
   double               GetSize(void);
   int                  GetStopLoss(void);
   int                  GetTakeProfit(void);
   CNewsContainer       *GetNewsContainer(void);
   //--- Setter methods
   void                 SetSize(double size);
   void                 SetStopLoss(int stopLoss);
   void                 SetTakeProfit(int takeProfit);
   //--- CBrain specific methods
   bool                 Init();
   void                 Deinit(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBrain::CBrain(int stopLoss,int takeProfit,double size,string csv)
  {
   m_size=size;
   m_stopLoss=stopLoss;
   m_takeProfit=takeProfit;
   m_news_container=new CNewsContainer(csv);   
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBrain::~CBrain(void)
  {
   Deinit();
  }
//+------------------------------------------------------------------+
//| GetSize                                                          |
//+------------------------------------------------------------------+
double CBrain::GetSize(void)
  {
   return m_size;
  }
//+------------------------------------------------------------------+
//| GetStopLoss                                                      |
//+------------------------------------------------------------------+
int CBrain::GetStopLoss(void)
  {
   return m_stopLoss;
  }
//+------------------------------------------------------------------+
//| GetTakeProfit                                                    |
//+------------------------------------------------------------------+
int CBrain::GetTakeProfit(void)
  {
   return m_takeProfit;
  }
//+------------------------------------------------------------------+
//| GetNewsContainer                                                 |
//+------------------------------------------------------------------+
CNewsContainer *CBrain::GetNewsContainer(void)
  {
   return m_news_container;
  }
//+------------------------------------------------------------------+
//| SetSize                                                          |
//+------------------------------------------------------------------+
void CBrain::SetSize(double size)
  {
   m_size=size;
  }
//+------------------------------------------------------------------+
//| SetStopLoss                                                      |
//+------------------------------------------------------------------+
void CBrain::SetStopLoss(int stopLoss)
  {
   m_stopLoss=stopLoss;
  }
//+------------------------------------------------------------------+
//| SetTakeProfit                                                    |
//+------------------------------------------------------------------+
void CBrain::SetTakeProfit(int takeProfit)
  {
   m_takeProfit=takeProfit;
  }
//+------------------------------------------------------------------+
//| CBrain initialization                                            |
//+------------------------------------------------------------------+
bool CBrain::Init(void)
  {
// Initialization logic here...
   return true;
  }
//+------------------------------------------------------------------+
//| CBrain deinitialization                                          |
//+------------------------------------------------------------------+
void CBrain::Deinit(void)
  {
   delete(m_news_container);
   Print("CBrain deinitialization performed!");
  }
//+------------------------------------------------------------------+
