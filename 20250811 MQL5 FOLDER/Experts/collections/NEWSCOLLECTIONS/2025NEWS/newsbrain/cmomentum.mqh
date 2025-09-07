//+------------------------------------------------------------------+
//|                                                    CMomentum.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CMomentum Class                                                  |
//+------------------------------------------------------------------+

class CMomentum
  {
protected:   
   int m_handler;
   double m_buffer[];
               
public:
   //--- Constructor and destructor methods
                           CMomentum(void);
                           ~CMomentum(void);
   //--- Getter methods
   int                     GetHandler(void);
   void                    GetBuffer(double &buffer[], int ammount);
   //--- Setter methods
   bool                    SetHandler(string symbol,ENUM_TIMEFRAMES period,int mom_period,ENUM_APPLIED_PRICE mom_applied_price);
   bool                    UpdateBuffer(int ammount);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+   
CMomentum::CMomentum(void)
  {
   ArraySetAsSeries(m_buffer, true);   
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+               
CMomentum::~CMomentum(void)
  {
   IndicatorRelease(m_handler);
   ArrayFree(m_buffer);
  }
//+------------------------------------------------------------------+
//| GetHandler                                                       |
//+------------------------------------------------------------------+        
int CMomentum::GetHandler(void)
  {
   return m_handler;
  }
//+------------------------------------------------------------------+
//| GetBuffer                                                        |
//+------------------------------------------------------------------+
void CMomentum::GetBuffer(double &buffer[], int ammount)
  {
   ArrayCopy(buffer, m_buffer, 0, 0, ammount);
  }
//+------------------------------------------------------------------+
//| SetHandler                                                       |
//+------------------------------------------------------------------+      
bool CMomentum::SetHandler(string symbol,ENUM_TIMEFRAMES period,int mom_period,ENUM_APPLIED_PRICE mom_applied_price)
  {   
   if((m_handler=iMomentum(symbol,period,mom_period,mom_applied_price))==INVALID_HANDLE)
   {
      printf("Error creating Momentum indicator");
      return false;
   }
   return true;
  }
//+------------------------------------------------------------------+
//| UpdateBuffer                                                     |
//+------------------------------------------------------------------+   
bool CMomentum::UpdateBuffer(int ammount)
  {   
   if(CopyBuffer(m_handler, 0, 0, ammount, m_buffer) < 0)
   { 
      Alert("Error copying Momentum buffers, error: " , GetLastError());
      return false;
   }
   return true;
  }
//+------------------------------------------------------------------+
