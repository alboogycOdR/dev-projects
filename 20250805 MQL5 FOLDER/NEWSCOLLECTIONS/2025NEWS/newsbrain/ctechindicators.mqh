//+------------------------------------------------------------------+
//|                                              CTechIndicators.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+
#include <..\Experts\NewsWatcher\CMomentum.mqh>
//+------------------------------------------------------------------+
//| CTechIndicators Class                                            |
//+------------------------------------------------------------------+
class CTechIndicators
  {
protected:
   CMomentum               *m_momentum;
                  
public:
   //--- Constructor and destructor methods
                           CTechIndicators(void);
                           ~CTechIndicators(void);
   //--- Getter methods
   CMomentum               *GetMomentum(void);
   //--- CTechIndicators specific methods
   bool                 Init();
   void                 Deinit(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+   
CTechIndicators::CTechIndicators(void)
  {
   m_momentum = new CMomentum; 
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+               
CTechIndicators::~CTechIndicators(void)
  {
   Deinit();
  }
//+------------------------------------------------------------------+
//| GetMomentum                                                      |
//+------------------------------------------------------------------+        
CMomentum* CTechIndicators::GetMomentum(void)
  {
   return m_momentum;
  }
//+------------------------------------------------------------------+
//| CTechIndicators initialization                                   |
//+------------------------------------------------------------------+
bool CTechIndicators::Init(void)
  {
// Initialization logic here...
   return true;
  }
//+------------------------------------------------------------------+
//| CTechIndicators deinitialization                                 |
//+------------------------------------------------------------------+
void CTechIndicators::Deinit(void)
  {
   delete(m_momentum);
   Print("CTechIndicators deinitialization performed!");
  }
//+------------------------------------------------------------------+
