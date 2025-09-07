//+------------------------------------------------------------------+
//|                                                   CEvolution.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+
#include <Indicators\Indicators.mqh>
#include <Mine\Enums.mqh>
//+------------------------------------------------------------------+
//| CEvolution Class                                                 |
//+------------------------------------------------------------------+
class CEvolution
  {
protected:
   ENUM_STATUS_EA    m_status;            // The current EA's status

public:
   //--- Constructor and destructor methods
                     CEvolution(ENUM_STATUS_EA status);
                    ~CEvolution(void);
   //--- Getter methods
   ENUM_STATUS_EA    GetStatus(void);
   //--- Setter methods
   void              SetStatus(ENUM_STATUS_EA status);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEvolution::CEvolution(ENUM_STATUS_EA status)
  {
   m_status=status;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEvolution::~CEvolution(void)
  {
  }
//+------------------------------------------------------------------+
//| GetStatus                                                        |
//+------------------------------------------------------------------+
ENUM_STATUS_EA CEvolution::GetStatus(void)
  {
   return m_status;
  }
//+------------------------------------------------------------------+
//| SetStatus                                                        |
//+------------------------------------------------------------------+
void CEvolution::SetStatus(ENUM_STATUS_EA status)
  {
   m_status=status;
  }