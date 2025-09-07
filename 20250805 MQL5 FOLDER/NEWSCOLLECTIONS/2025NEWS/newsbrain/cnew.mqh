//+------------------------------------------------------------------+
//|                                                         CNew.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//| CNew Class                                                       |
//+------------------------------------------------------------------+
class CNew : public CObject
  {
protected:
   string            m_country;           // The country's name
   datetime          m_time_release;      // The date and time of the news
   string            m_name;              // The name of the news
   
public:
   //--- Constructor and destructor methods
                     CNew(string country,datetime time_release,string name);
                    ~CNew(void);
   //--- Getter methods
   string            GetCountry(void);
   datetime          GetTimeRelease(void);
   string            GetName(void);
   //--- Setter methods
   void              SetCountry(string country);
   void              SetTimeRelease(datetime time_release);
   void              SetName(string name);
   //--- CNew specific methods
   bool              Init();
   void              Deinit(void);
  };
//+------------------------------------------------------------------+
//| Constuctor                                                       |
//+------------------------------------------------------------------+
CNew::CNew(string country,datetime time_release,string name)
  {
   m_country=country;
   m_time_release=time_release;
   m_name=name;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNew::~CNew(void)
  {
   Deinit();
  }
//+------------------------------------------------------------------+
//| GetCountry                                                       |
//+------------------------------------------------------------------+
string CNew::GetCountry(void)
  {
   return m_country;
  }  
//+------------------------------------------------------------------+
//| GetTimeRelease                                                   |
//+------------------------------------------------------------------+
datetime CNew::GetTimeRelease(void)
  {
   return m_time_release;
  }
//+------------------------------------------------------------------+
//| GetName                                                          |
//+------------------------------------------------------------------+
string CNew::GetName(void)
  {
   return m_name;
  }
//+------------------------------------------------------------------+
//| SetCountry                                                       |
//+------------------------------------------------------------------+
void CNew::SetCountry(string country)
  {
   m_country=country;
  }
//+------------------------------------------------------------------+
//| SetTimeRelease                                                   |
//+------------------------------------------------------------------+
void CNew::SetTimeRelease(datetime timeRelease)
  {
   m_time_release=timeRelease;
  }
//+------------------------------------------------------------------+
//| SetName                                                          |
//+------------------------------------------------------------------+
void CNew::SetName(string name)
  {
   m_name=name;
  }
//+------------------------------------------------------------------+
//| CNew initialization                                              |
//+------------------------------------------------------------------+
bool CNew::Init(void)
  {
//--- initialization logic here...
   return true;
  }
//+------------------------------------------------------------------+
//| CNew deinitialization                                            |
//+------------------------------------------------------------------+
void CNew::Deinit(void)
  {
//--- deinitialization logic here...
   Print("CNew deinitialization performed!");
  }
//+------------------------------------------------------------------+
