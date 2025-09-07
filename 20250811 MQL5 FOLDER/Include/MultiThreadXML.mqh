//+------------------------------------------------------------------+
//|                                               MultiThreadXML.mqh |
//|                        Copyright 2013, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2013, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"

#include <XmlBase.mqh>
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>

///
/// Define caption for get function.
///
enum ENUM_QUOTES_INFO_DOUBLE
{
   QUOTE_ASK,
   QUOTE_BID
};

class CQuoteList
{
   private:
      ///
      /// Name interface for fast acces.
      ///
      class CName : CObject
      {
         private:
            string name;
         public:
            ///
            /// Constructor default.
            ///
            CName(){name = "";}
            ///
            /// Set Name.
            ///
            void Name(string Name){name = Name;}
            ///
            /// Get Name.
            ///
            string Name()const{return name;}
            ///
            /// Overide Compare function.
            ///
            virtual int Compare(const CObject* obj, const int mode = 0)
            {
               const CName* m_name = obj;
               if(m_name.Name() == name)return 0;
               if(m_name.Name() < name)return 1;
               else return -1;
            }
      };
      ///
      /// Broker.
      ///
      class CBroker : public CName
      {
         public:
            ///
            /// Array of quotes.
            ///
            CArrayObj QuotesList;
            ///
            /// Constructor by default.
            ///
            CBroker()
            {
               QuotesList.Sort(0);
            }
            
      };
      ///
      /// Quote.
      ///
      class CQuote : public CName
      {
         private:
            double ask;
            double bid;
            int digits;
         public:
            ///
            /// Constructor by default.
            ///
            CQuote()
            {
               ask = 0.0;
               bid = 0.0;
               digits = 0;
            }
            ///
            /// Set ask price.
            ///
            void Ask(double Ask){ask = Ask;}
            ///
            /// Get ask price.
            ///
            double Ask(){return ask;}
            ///
            /// Set bid price.
            ///
            void Bid(double Bid){bid = Bid;}
            ///
            /// Get bid price.
            ///
            double Bid(void){return bid;}
            ///
            /// Get Digits in quote.
            ///
            double Digits(){return digits;}
            ///
            /// Set Digits in quote.
            ///
            void Digits(int Digits){this.digits = Digits;}
      };
      ///
      /// Selected broker.
      ///
      CBroker* cBroker;
      ///
      /// Selected quote.
      ///
      CQuote* cQuote;
      ///
      /// Contein brokers array.
      ///
      CArrayObj brokers;
      
      ///
      /// Parse xml element.
      /// \return True if parse was successfully, otherwise false.
      ///
      bool ParseElement(CXmlElement* element);
      ///
      /// Refresh or add new quote.
      ///
      void RefreshQuote(string brokerName, string symbolName, double ask, double bid, long digits);
      ///
      /// Get string value for attribute by name 'attrName'.
      /// \param element  - XML node.
      /// \param attrName - Name of xml attribyte.
      /// \param attrValue - Set this value in attribute value.
      /// \return True if parsing and set attrValue was successfully, otherwise false.
      ///
      bool GetStringValue(CXmlElement* element, string attrName, string& attrValue);
      ///
      /// Get double value for attribute by name 'attrName'.
      /// \param element  - XML node.
      /// \param attrName - Name of xml attribyte.
      /// \param attrValue - Set this value in attribute value.
      /// \return True if parsing and set attrValue was successfully, otherwise false.
      ///
      bool GetDoubleValue(CXmlElement* element, string attrName, double& attrValue);
      ///
      /// Get long value for attribute by name 'attrName'.
      /// \param element  - XML node.
      /// \param attrName - Name of xml attribyte.
      /// \param attrValue - Set this value in attribute value.
      /// \return True if parsing and set attrValue was successfully, otherwise false.
      ///
      bool GetLongValue(CXmlElement *element,string attrName, long& attrValue);
      ///
      /// Try get handle of XML file with quotes.
      /// \return If file open successfully return handle of file, otherwise return INVALID_HANDLE.
      ///
      int TryGetHandle();
      ///
      /// Create Xml from base;
      ///
      void CreateXml(CXmlDocument* xmlOutput);
      ///
      /// Create XML attribute.
      ///
      CXmlAttribute* CreateAttribute(string name, string value);
      ///
      /// Create or refresh quotes for this expert.
      ///
      void CreateOrRefreshMyQuotes();
      ///
      /// Count of attampts.
      ///
      int att;
      ///
      /// Count access times.
      ///
      int count;
   public:
      ///
      /// Return count access.
      ///
      int CountAccess(){return count;}
      ///
      /// Return count of last attempts for file access.
      ///
      int GetAttemptsCount(){return att;}
      ///
      /// Load all quotes from XML common file.
      ///
      bool LoadQuotes(void);
      ///
      /// Default constructor.
      ///
      CQuoteList();
      ///
      /// Return broker name
      ///
      string BrokerName();
      ///
      /// Return Brokers total.
      ///
      int BrokersTotal(){return brokers.Total();}
      ///
      /// Select broker by index.
      /// \param index  - index nroker in list brokers.
      /// \return true if selected was successfully, otherwise false.
      ///
      bool BrokerSelect(const int index);
      ///
      /// Select broker by it name.
      /// \param brokerName  - broker name.
      /// \return true if selected was successfully, otherwise false.
      ///
      bool BrokerSelect(string brokerName);
      ///
      /// Return symbols total in selected broker.
      ///
      int SymbolsTotal();
      ///
      /// Select symbol by name 'symbol'.
      /// \param index - Index of symbol.
      /// \return True if symbol was selected successfully, otherwise false.
      ///
      bool SymbolSelect(const int index);
      ///
      /// Select symbol by name 'symbol'.
      /// \param symbol - Name of symbol.
      /// \return True if symbol was selected successfully, otherwise false.
      ///
      bool SymbolSelect(string symbol);
      ///
      /// Save quote in XML quotes file.
      ///
      void SaveQuote(void);
      ///
      /// Get value caption in seleted symbol.
      ///
      double QuoteInfoDouble(ENUM_QUOTES_INFO_DOUBLE caption);
};

CQuoteList::CQuoteList()
{
   brokers.Sort(0);
   att = 0;
   count = 0;
}

bool CQuoteList::LoadQuotes()
{
   //CXmlElement element;
   brokers.Clear();
   int handle = TryGetHandle();
   if(handle == INVALID_HANDLE)
      return false;   
   CXmlDocument xmlQuotes;
   string err = "";
   ulong size = FileSize(handle);
   if(size == 0)
   {
      CreateXml(GetPointer(xmlQuotes));
      if(!xmlQuotes.WriteDocument(handle, err))
         printf(err);
      FileClose(handle);
      return true;
   }
   bool res = xmlQuotes.ReadDocument(handle, err);
   //bool res = xmlQuotes.CreateFromFile("Quotes.xml", err);
   if(!res)
   {
      printf("Failed xml read. Reason: " + err);
      FileClose(handle);
      return false;
   }
   CXmlAttribute* attrCount = xmlQuotes.FDocumentElement.GetAttribute("Count");
   if(attrCount != NULL)
      count = (int)attrCount.GetValue();
   //»щим текущий xml-елемент, соответствующий позиции.
   for(int i = xmlQuotes.FDocumentElement.GetChildCount()-1; i >= 0 ; i--)
   {
      CXmlElement* element = xmlQuotes.FDocumentElement.GetChild(i);
      string name = element.GetName();
      if(element.GetName() == "Broker")
         ParseElement(element);
      else
         printf("Bad xml node name: " + element.GetName());
   }
   CreateXml(GetPointer(xmlQuotes));
   res = xmlQuotes.WriteDocument(handle, err);
   FileClose(handle);
   if(!res)
   {
      printf("Failed xml write. Reason: " + err);
      return false;
   }
   return true;
}

bool CQuoteList::ParseElement(CXmlElement* broker)
{
   string brokerName = "";
   if(!GetStringValue(broker, "Name", brokerName))
      return false;
   for(int i = broker.GetChildCount()-1; i >= 0 ; i--)
   {
      CXmlElement* element = broker.GetChild(i);
      string symbol = "";
      if(!GetStringValue(element, "Name", symbol))
         continue;
      double ask = 0.0;
      if(!GetDoubleValue(element, "Ask", ask))
         continue;
      double bid;
      if(!GetDoubleValue(element, "Bid", bid))
         continue;
      long digits = 0;
      if(!GetLongValue(element, "Digits", digits))
         continue;
      RefreshQuote(brokerName, symbol, ask, bid, digits);
   }
   return true;
   //RefreshQuote(brokerName, 
}

bool CQuoteList::GetStringValue(CXmlElement* element, string attrName, string& attrValue)
{
   CXmlAttribute* attr = element.GetAttribute(attrName);
   if(attr == NULL)
   {
      printf("Bad XML node" + attrName + ". Missing attribute " + attrName);
      return false;
   }
   string value = attr.GetValue();
   if(value == "")
   {
      printf("Value of attribute '" + attrName + "' must not be empty.");
      return false;
   }
   attrValue = value;
   return true;
}

bool CQuoteList::GetDoubleValue(CXmlElement *element,string attrName, double& attrValue)
{
   string strValue = "";
   if(!GetStringValue(element, attrName, strValue))
      return false;
   double value = StringToDouble(strValue);
   if(DoubleEquals(value, 0.0) || value < 0.0)
   {
      printf("Value" + attrName + " is not double. Check value.");
      return false;
   }
   attrValue = value;
   return true;
}

bool CQuoteList::GetLongValue(CXmlElement *element,string attrName, long& attrValue)
{
   string strValue = "";
   if(!GetStringValue(element, attrName, strValue))
      return false;
   long value = StringToInteger(strValue);
   attrValue = value;
   return true;
}

void CQuoteList::RefreshQuote(string brokerName,string symbolName,double ask, double bid, long digits)
{
   CName* FindThisName = new CName();
   FindThisName.Name(brokerName);
   int index = brokers.Search(FindThisName);
   CBroker* broker = NULL;
   if(index == -1)
   {
      broker = new CBroker();
      brokers.InsertSort(broker);
   }
   else
      broker = brokers.At(index);
   broker.Name(brokerName);
   FindThisName.Name(symbolName);
   index = broker.QuotesList.Search(FindThisName);
   CQuote* quote = NULL;
   if(index == -1)
   {
      quote = new CQuote();
      broker.QuotesList.InsertSort(quote);
   }
   else
      quote = broker.QuotesList.At(index);
   quote.Name(symbolName);
   quote.Ask(ask);
   quote.Bid(bid);
   quote.Digits((int)digits);
   delete FindThisName;
}

bool CQuoteList::BrokerSelect(const int index)
{
   if(index < 0 || index > brokers.Total())
   {
      printf("index from the range");
      return false;
   }
   cBroker = brokers.At(index);
   if(CheckPointer(cBroker)==POINTER_INVALID)
   {
      printf("selected broker is broken");
      cBroker = NULL;
      return false;
   }
   return true;
}

bool CQuoteList::BrokerSelect(string brokerName)
{
   CName* FindThisName = new CName();
   FindThisName.Name(brokerName);
   int index = brokers.Search(FindThisName);
   delete FindThisName;
   if(index == -1)
   {
      //printf("broker with name '" + brokerName + "' not find.");
      return false;
   }
   else
      return BrokerSelect(index);
}

int CQuoteList::SymbolsTotal(void)
{
   if(CheckPointer(cBroker) == POINTER_INVALID)
   {
      printf("Broker not selected. Selected broker with 'BrokerSelect' function");
      return -1;
   }
   return cBroker.QuotesList.Total();
}

bool CQuoteList::SymbolSelect(const int index)
{
   int total = this.SymbolsTotal();
   if(total == -1)
   {
      printf("Broker not selected. Selected broker with 'BrokerSelect' function");
      return false;
   }
   if(index < 0 || index >= total)
   {
      printf("index from the range");
      return false;
   }
   cQuote = cBroker.QuotesList.At(index);
   if(CheckPointer(cQuote) == POINTER_INVALID)
   {
      printf("selected quote is broken");
      cQuote = NULL;
      return false;
   }
   return true;
}

string CQuoteList::BrokerName(void)
{
   if(CheckPointer(cBroker) != POINTER_INVALID)
      return cBroker.Name();
   return "";
}

bool CQuoteList::SymbolSelect(string symbol)
{
   if(CheckPointer(cBroker) == POINTER_INVALID)
   {
      printf("Broker not selected. Selected broker with 'BrokerSelect' function");
      return false;
   }
   CName* FindThisName = new CName();
   FindThisName.Name(symbol);
   int index = cBroker.QuotesList.Search(FindThisName);
   delete FindThisName;
   if(index == -1)
   {
      //printf("symbol with name '" + symbol + "' not find.");
      return false;
   }
   else
      return this.SymbolSelect(index);
}

double CQuoteList::QuoteInfoDouble(ENUM_QUOTES_INFO_DOUBLE caption)
{
   switch(caption)
   {
      case QUOTE_ASK:
         return cQuote.Ask();
      case QUOTE_BID:
         return cQuote.Bid();
   }
   printf("Unknow caption.");
   return 0.0;
}


int CQuoteList::TryGetHandle(void)
{
   int attempts = 10;
   int handle = INVALID_HANDLE;
   // We try to open 'attemps' times
   for(att = 0; att < attempts; att++)
   {
      handle = FileOpen("Quotes.xml", FILE_WRITE|FILE_READ|FILE_BIN|FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         Sleep(15);
         continue;
      }
      break;
   }
   return handle;
}

void CQuoteList::CreateOrRefreshMyQuotes(void)
{
   string brokerName = AccountInfoString(ACCOUNT_COMPANY);
   string symbolName = Symbol();
   int digits = (int)SymbolInfoInteger(symbolName, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(symbolName, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbolName, SYMBOL_BID);
   ask = NormalizeDouble(ask, digits);
   bid = NormalizeDouble(bid, digits);
   if(!BrokerSelect(brokerName))
   {
      cBroker = new CBroker();
      cBroker.Name(brokerName);
      brokers.InsertSort(cBroker);
   }
   if(!this.SymbolSelect(symbolName))
   {
      cQuote = new CQuote();
      cQuote.Name(symbolName);
      //printf("Create new symbol: " + symbolName);
      cBroker.QuotesList.InsertSort(cQuote);     
   }
   cQuote.Ask(ask);
   cQuote.Bid(bid);
}

void CQuoteList::CreateXml(CXmlDocument *xmlOutput)
{
   xmlOutput.Clear();
   //xmlOutput
   CXmlElement* xmlBrokers = GetPointer(xmlOutput.FDocumentElement);
   xmlBrokers.SetName("Brokers");
   count++;
   string c = (string)(count);
   xmlBrokers.AttributeAdd(CreateAttribute("Count", c));
   CreateOrRefreshMyQuotes();
   for(int i = 0; i < brokers.Total(); i++)
   {
      CBroker* broker = brokers.At(i);
      CXmlElement* xmlBroker = new CXmlElement();
      xmlBroker.SetName("Broker");
      xmlBroker.AttributeAdd(CreateAttribute("Name", broker.Name()));
      for(int isymbol = 0; isymbol < broker.QuotesList.Total(); isymbol++)
      {
         CQuote* quote = broker.QuotesList.At(isymbol);
         CXmlElement* xmlSymbol = new CXmlElement();
         xmlSymbol.SetName("Symbol");
         xmlSymbol.AttributeAdd(CreateAttribute("Name", quote.Name()));
         int digits = (int)SymbolInfoInteger(quote.Name(), SYMBOL_DIGITS);
         string ask = DoubleToString(quote.Ask(), digits);
         string bid = DoubleToString(quote.Bid(), digits);
         xmlSymbol.AttributeAdd(CreateAttribute("Ask", ask));
         xmlSymbol.AttributeAdd(CreateAttribute("Bid", bid));
         xmlSymbol.AttributeAdd(CreateAttribute("Digits", (string)digits));
         xmlBroker.ChildAdd(xmlSymbol);
      }
      xmlBrokers.ChildAdd(xmlBroker);
   }
   //xmlOutput.FDocumentElement.ChildAdd(xmlBrokers);
}

CXmlAttribute* CQuoteList::CreateAttribute(string name,string value)
{
   CXmlAttribute* attr = new CXmlAttribute();
   attr.SetName(name);
   attr.SetValue(value);
   return attr;
}



//+------------------------------------------------------------------+
//| Compares two double numbers.                                     |
//| RESULT                                                           |
//|   True if two double numbers equal, otherwise false.             |
//+------------------------------------------------------------------+
bool DoubleEquals(const double a,const double b)
  {
//---
   return(fabs(a-b)<=16*DBL_EPSILON*fmax(fabs(a),fabs(b)));
//---
  }
//+------------------------------------------------------------------+