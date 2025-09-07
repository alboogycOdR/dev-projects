//+------------------------------------------------------------------+
//|                                               CNewsContainer.mqh |
//|                               Copyright © 2013, Jordi Bassagañas |
//+------------------------------------------------------------------+
#include <Files\FileTxt.mqh>
#include <Arrays\ArrayObj.mqh>
#include <..\Experts\NewsWatcher\CNew.mqh>
//+------------------------------------------------------------------+
//| CNewsContainer Class                                             |
//+------------------------------------------------------------------+
class CNewsContainer
  {
protected:
   string               m_csv;                  // The name of the csv file
   CFileTxt             m_fileTxt;              // MQL5 file functionality
   int                  m_currentIndex;         // The index of the next news to be processed in the container
   int                  m_total;                // The total number of news to be processed
   CArrayObj            *m_news;                // News list in the computer's memory, loaded from the csv file

public:
   //--- Constructor and destructor methods
                        CNewsContainer(string csv);
                        ~CNewsContainer(void);
   //--- Getter methods
   int                  GetCurrentIndex(void);
   int                  GetTotal(void);
   CNew                 *GetCurrentNew();
   CArrayObj            *GetNews(void);
   //--- Setter methods
   void                 SetCurrentIndex(int index);
   void                 SetTotal(int total);
   void                 SetNews(void);
   //--- CNewsContainer methods
   bool                 Init();
   void                 Deinit(void);
  };
//+------------------------------------------------------------------+
//| Constuctor                                                       |
//+------------------------------------------------------------------+
CNewsContainer::CNewsContainer(string csv)
  {
   m_csv=csv;
   m_news=new CArrayObj;
   SetNews();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CNewsContainer::~CNewsContainer(void)
  {
   Deinit();
  }
//+------------------------------------------------------------------+
//| GetCurrentIndex                                                  |
//+------------------------------------------------------------------+
int CNewsContainer::GetCurrentIndex(void)
  {   
   return m_currentIndex;
  }
//+------------------------------------------------------------------+
//| GetTotal                                                         |
//+------------------------------------------------------------------+
int CNewsContainer::GetTotal(void)
  {   
   return m_total;
  }
//+------------------------------------------------------------------+
//| GetNews                                                          |
//+------------------------------------------------------------------+
CArrayObj *CNewsContainer::GetNews(void)
  {   
   return m_news;
  }
//+------------------------------------------------------------------+
//| GetCurrentNew                                                    |
//+------------------------------------------------------------------+
CNew *CNewsContainer::GetCurrentNew(void)
  {   
   return m_news.At(m_currentIndex);
  }
//+------------------------------------------------------------------+
//| SetCurrentIndex                                                  |
//+------------------------------------------------------------------+
void CNewsContainer::SetCurrentIndex(int index)
  {
   m_currentIndex=index;
  }
//+------------------------------------------------------------------+
//| SetTotal                                                         |
//+------------------------------------------------------------------+
void CNewsContainer::SetTotal(int total)
  {
   m_total=total;
  }
//+------------------------------------------------------------------+
//| SetNews                                                          |
//+------------------------------------------------------------------+
void CNewsContainer::SetNews(void)
  {
   //--- let's first init some vars!
   SetCurrentIndex(0);
   string sep= ";";
   ushort u_sep;
   string substrings[];   
   u_sep=StringGetCharacter(sep,0);   
   //--- then open and process the CSV file
   int file_handle=m_fileTxt.Open(m_csv, FILE_READ|FILE_CSV);
   if(file_handle!=INVALID_HANDLE)
   {
      while(!FileIsEnding(file_handle))
      {               
         string line = FileReadString(file_handle);         
         int k = StringSplit(line,u_sep,substrings);         
         CNew *current = new CNew(substrings[0],(datetime)substrings[1],substrings[2]);         
         m_news.Add(current);
      }
      FileClose(file_handle);
      //--- and finally refine and count the news
      m_news.Delete(0); // --- here we delete the CSV's header!
      SetTotal(m_news.Total());
   }
   else
   {
      Print("Failed to open the file ",m_csv);
      Print("Error code ",GetLastError());
   }   
  }
//+------------------------------------------------------------------+
//| CNewsContainer initialization                                    |
//+------------------------------------------------------------------+
bool CNewsContainer::Init(void)
  {
// Initialization logic here...
   return true;
  }
//+------------------------------------------------------------------+
//| CNewsContainer deinitialization                                  |
//+------------------------------------------------------------------+
void CNewsContainer::Deinit(void)
  {
   m_news.DeleteRange(0, m_total-1);
   delete(m_news);
   Print("CNewsContainer deinitialization performed!");
  }
//+------------------------------------------------------------------+
