//+------------------------------------------------------------------+
//|                                             MyCListTrendLine.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Класс реализует контейнер для хранения объектов Trend и облег-   |
//| чает их использование, берет на себя всю функцию обслуживания    |
//| Trend-объектов.                                                  |
//| Версия: молчун - без обработки ошибок!                           |
//| Версия без обработки системных событий:                          |
//| CHARTEVENT_OBJECT_CLICK,  CHARTEVENT_OBJECT_DRAG                 |
//| CHARTEVENT_OBJECT_CHANGE, CHARTEVENT_OBJECT_DELETE               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <Arrays\List.mqh>
#include <MyObjects\MyCTrendLine.mqh>
//+------------------------------------------------------------------+
//| класс MyCListTrendLine                                           |
//+------------------------------------------------------------------+
class MyCListTrendLine
  {
private:
   CList*            ListTrendLine;                                // гл. укз. на список Trend
public:
                     MyCListTrendLine();
                    ~MyCListTrendLine();
   //--- Методы Insert
   void              Insert();                                     // ввод Trend
   void              Insert(double Price1, datetime Time1,
                            double Price2, datetime Time2);        // ввод Trend + координаты
   void              Insert(double Price1, datetime Time1, double Price2, 
                            datetime Time2, ENUM_LINE_STYLE Style);// ввод Trend + координаты + style
   bool              Insert(string Name, double Price1, datetime Time1, double Price2, 
                            datetime Time2, ENUM_LINE_STYLE Style);// ввод Trend+координаты+style+name   
   //--- Методы Set
   bool              SetAtIndexName(int ind, string NewName);      // метод изм. имени
   bool              SetAtNameOfName(string Name, string NewName); // метод изм. имени
   bool              SetAtIndexPrice1(int ind, double NewPrice);   // метод изм. цены 1
   bool              SetAtIndexPrice2(int ind, double NewPrice);   // метод изм. цены 2
   bool              SetAtNameOfPrice1(string Name, double NewPrice);// метод изм. цены 1
   bool              SetAtNameOfPrice2(string Name, double NewPrice);// метод изм. цены 2
   bool              SetAtIndexTime1(int ind, datetime NewTime);   // метод изм. даты 1
   bool              SetAtIndexTime2(int ind, datetime NewTime);   // метод изм. даты 2
   bool              SetAtNameOfTime1(string Name, datetime NewTime);// метод изм. даты 1
   bool              SetAtNameOfTime2(string Name, datetime NewTime);// метод изм. даты 2
   bool              SetAtIndexColor(int ind, color NewColor);     // метод изм. цвета
   bool              SetAtNameOfColor(string Name, color NewColor);// метод изм. цвета
   bool              SetAtIndexStyle(int ind, ENUM_LINE_STYLE style);// метод изм. стиля
   bool              SetAtNameOfStyle(string Name, ENUM_LINE_STYLE style);// метод изм. стиля
   bool              SetAtIndexWidth(int ind, int width);          // метод изм. толщины
   bool              SetAtNameOfWidth(string Name, int width);     // метод изм. толщины
   bool              SetAtIndexBack(int ind, bool back);           // метод изм. "задний план"
   bool              SetAtNameOfBack(string Name, bool back);      // метод изм. "задний план"
   bool              SetAtIndexRayLeft(int ind, bool left);        // метод изм. "луч влево"
   bool              SetAtNameOfRayLeft(string Name, bool left);   // метод изм. "луч влево"
   bool              SetAtIndexRayRight(int ind, bool right);      // метод изм. "луч вправо"
   bool              SetAtNameOfRayRight(string Name, bool rigth); // метод изм. "луч вправо"
   bool              SetAtIndexHidden(int ind, bool hidden);       // метод изм. "скрыть в списке"
   bool              SetAtNameOfHidden(string Name, bool hidden);  // метод изм. "скрыть в списке"
   //--- Mетоды Get
   int               GetSize();                                    // получение размера ListTrendLine
   string            GetAtIndexName(int ind);                      // метод пол. имени
   string            GetLastTrendName();                           // получение последнего имени
   string            GetLastName(){return(GetLastTrendName());};   // получение последнего имени
   int               GetAtNameOfIndex(string Name);                // метод пол. индекса
   double            GetAtIndexPrice1(int ind);                    // метод пол. цены 1 по инексу объекта
   double            GetAtIndexPrice2(int ind);                    // метод пол. цены 2 по инексу объекта
   double            GetAtNameOfPrice1(string Name);               // метод пол. цены 1 по имени  объекта
   double            GetAtNameOfPrice2(string Name);               // метод пол. цены 2 по имени  объекта
   datetime          GetAtIndexTime1(int ind);                     // метод пол. времени 1 по индексу
   datetime          GetAtIndexTime2(int ind);                     // метод пол. времени 2 по индексу
   datetime          GetAtNameOfTime1(string Name);                // метод пол. времени 1 по имени
   datetime          GetAtNameOfTime2(string Name);                // метод пол. времени 2 по имени
   color             GetAtIndexColor(int ind);                     // метод пол. цвета по индексу
   color             GetAtNameOfColor(string Name);                // метод пол. цвета по имени
   ENUM_LINE_STYLE   GetAtIndexStyle(int ind);                     // метод пол. типа по индексу
   ENUM_LINE_STYLE   GetAtNameOfStyle(string Name);                // метод пол. типа по имени
   int               GetAtIndexWidth(int ind);                     // метод пол. толщины линии по индексу
   int               GetAtNameOfWidth(string Name);                // метод пол. толщины линии по имени
   bool              GetAtIndexBack(int ind);                      // метод пол. "задний план" линии по индексу
   bool              GetAtNameOfBack(string Name);                 // метод пол. "задний план" линии по имени
   bool              GetAtIndexRayLeft(int ind);                   // метод пол. "луч влево" линии по индексу
   bool              GetAtNameOfRayLeft(string Name);              // метод пол. "луч влево" линии по имени
   bool              GetAtIndexRayRight(int ind);                  // метод пол. "луч вправо" линии по индексу
   bool              GetAtNameOfRayRight(string Name);             // метод пол. "луч вправо" линии по имени
   bool              GetAtIndexHidden(int ind);                    // метод пол. "скрыть в списке" лин. по индексу
   bool              GetAtNameOfHidden(string Name);               // метод пол. "скрыть в списке" лин. по имени
   //--- Методы Delet
   void              ClearAll();                                   // МОЧИМ ВСЕХ!!!
   bool              DeletAtIndex(int ind);                        // мочить строго по индексу
   bool              DeletAtName(string Name);                     // мочить по имени
private:
   //--- Методы Find
   bool              FindName(string Name);                        // поиск по имени Trend
   int               iFindName(string Name);                       // поиск по имени Trend
  };
//+------------------------------------------------------------------+
//| конструктор                                                      |
//+------------------------------------------------------------------+
MyCListTrendLine::MyCListTrendLine()
  {
   //--- создание списка
   ListTrendLine = new CList;
   //--- класс-список сам чистит память
   ListTrendLine.FreeMode(true);
  }
//+------------------------------------------------------------------+
//| деструктур                                                       |
//+------------------------------------------------------------------+
MyCListTrendLine::~MyCListTrendLine()
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      ListTrendLine.Clear();
     }
   //---
   delete ListTrendLine;
  }
//+------------------------------------------------------------------+
//| Insert методы                                                    |
//+------------------------------------------------------------------+
//| Базовый Insert                                                   |
//+------------------------------------------------------------------+
void MyCListTrendLine::Insert(void)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //---
   NewTrend = new MyCTrendLine();
   ListTrendLine.Add(NewTrend);
  }
//+------------------------------------------------------------------+
//| Insert + координаты                                              |
//+------------------------------------------------------------------+
void MyCListTrendLine::Insert(double Price1,datetime Time1,double Price2,datetime Time2)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //---
   NewTrend = new MyCTrendLine(Price1, Time1, Price2, Time2);
   //---
   ListTrendLine.Add(NewTrend);
  }
//+------------------------------------------------------------------+
//| Insert + координаты + style                                      |
//+------------------------------------------------------------------+
void MyCListTrendLine::Insert(double Price1,datetime Time1,
                              double Price2,datetime Time2,ENUM_LINE_STYLE Style)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //---
   NewTrend = new MyCTrendLine(Price1, Time1, Price2, Time2, Style);
   //---
   ListTrendLine.Add(NewTrend);
  }
//+------------------------------------------------------------------+
//| Insert + координаты + style + name                               |
//+------------------------------------------------------------------+
bool MyCListTrendLine::Insert(string Name,double Price1,datetime Time1,
                              double Price2,datetime Time2,ENUM_LINE_STYLE Style)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- поиск по имени объекта
   if(ListTrendLine.Total()>0)
     {
      //--- вызов метода поиска
      if(this.FindName(Name)) return(false); // есть совпадения по имени Trend!
     }
   //---
   NewTrend = new MyCTrendLine(Name, Price1, Time1, Price2, Time2, Style);
   //---
   ListTrendLine.Add(NewTrend);
   //---
   return(true);
  }
//+------------------------------------------------------------------+
//| ПУБЛИЧНЫЕ МЕТОДЫ КЛАССА                                          |
//+------------------------------------------------------------------+
//| ПОДГРУППА SET...                                                 |
//+------------------------------------------------------------------+
//| Метод изм. имени                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexName(int ind,string NewName)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetName(NewName));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод изм. имени                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfName(string Name,string NewName)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexName(ind, NewName));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цены 1                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexPrice1(int ind,double NewPrice)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetPrice1(NewPrice));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод изм. цены 2                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexPrice2(int ind,double NewPrice)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetPrice2(NewPrice));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цены 1                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfPrice1(string Name,double NewPrice)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexPrice1(ind, NewPrice));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод изм. цены 2                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfPrice2(string Name,double NewPrice)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexPrice2(ind, NewPrice));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. даты 1                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexTime1(int ind,datetime NewTime)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetTime1(NewTime));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. даты 2                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexTime2(int ind,datetime NewTime)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetTime2(NewTime));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. даты 1                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfTime1(string Name,datetime NewTime)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexTime1(ind, NewTime));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. даты 2                                                |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfTime2(string Name,datetime NewTime)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexTime2(ind, NewTime));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цвета                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexColor(int ind,color NewColor)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetColor(NewColor));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цвета                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfColor(string Name,color NewColor)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexColor(ind, NewColor));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. стиля                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexStyle(int ind,ENUM_LINE_STYLE style)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetStyle(style));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. стиля                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfStyle(string Name,ENUM_LINE_STYLE style)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexStyle(ind,style));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. толщины                                               |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexWidth(int ind,int width)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetWidth(width));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. толщины                                               |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfWidth(string Name,int width)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexWidth(ind,width));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "задний план"                                         |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexBack(int ind,bool back)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetBack(back));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "задний план"                                         |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfBack(string Name,bool back)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexBack(ind,back));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "луч влево"                                           |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexRayLeft(int ind,bool left)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetRayLeft(left));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "луч влево"                                           |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfRayLeft(string Name,bool left)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexRayLeft(ind,left));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "луч вправо"                                          |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexRayRight(int ind,bool right)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetRayRight(right));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "луч вправо"                                          |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfRayRight(string Name,bool rigth)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexRayRight(ind,rigth));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "скрыть в списке"                                     |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtIndexHidden(int ind,bool hidden)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.SetHidden(hidden));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "скрыть в списке"                                     |
//+------------------------------------------------------------------+
bool MyCListTrendLine::SetAtNameOfHidden(string Name,bool hidden)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexHidden(ind,hidden));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| ПОДГРУППА GET...                                                 |
//+------------------------------------------------------------------+
//| получение размера ListTrend                                      |
//+------------------------------------------------------------------+
int MyCListTrendLine::GetSize(void)
  {
   return(ListTrendLine.Total());
  }
//+------------------------------------------------------------------+
//| Метод пол. имени по индексу                                      |
//+------------------------------------------------------------------+
string MyCListTrendLine::GetAtIndexName(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Получение последнего имени в списке                              |
//+------------------------------------------------------------------+
string MyCListTrendLine::GetLastTrendName(void)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>0)
     {
      //---
      NewTrend = ListTrendLine.GetLastNode();
      //---
      return(NewTrend.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. индекса по имени(общедоступный)                       |
//+------------------------------------------------------------------+
int MyCListTrendLine::GetAtNameOfIndex(string Name)
  {
   return(this.iFindName(Name));
  }
//+------------------------------------------------------------------+
//| Метод пол. цены 1 по инексу                                      |
//+------------------------------------------------------------------+
double MyCListTrendLine::GetAtIndexPrice1(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetPrice1());
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. цены 2 по инексу                                      |
//+------------------------------------------------------------------+
double MyCListTrendLine::GetAtIndexPrice2(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetPrice2());
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. цены 1 по имени  объекта                              |
//+------------------------------------------------------------------+
double MyCListTrendLine::GetAtNameOfPrice1(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexPrice1(ind));
        }
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. цены 2 по имени  объекта                              |
//+------------------------------------------------------------------+
double MyCListTrendLine::GetAtNameOfPrice2(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexPrice2(ind));
        }
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. времени 1 по индексу                                  |
//+------------------------------------------------------------------+
datetime MyCListTrendLine::GetAtIndexTime1(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetTime1());
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| Метод пол. времени 2 по индексу                                  |
//+------------------------------------------------------------------+
datetime MyCListTrendLine::GetAtIndexTime2(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetTime2());
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| Метод пол. времени 1 по имени                                    |
//+------------------------------------------------------------------+
datetime MyCListTrendLine::GetAtNameOfTime1(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexTime1(ind));
        }
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| Метод пол. времени 2 по имени                                    |
//+------------------------------------------------------------------+
datetime MyCListTrendLine::GetAtNameOfTime2(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexTime2(ind));
        }
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| Метод пол. цвета по индексу                                      |
//+------------------------------------------------------------------+
color MyCListTrendLine::GetAtIndexColor(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetColor());
     }
   //--- Ошибка типа
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. цвета по имени                                        |
//+------------------------------------------------------------------+
color MyCListTrendLine::GetAtNameOfColor(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexColor(ind));
        }
     }
   //---Error
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. стиля по индексу                                      |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE MyCListTrendLine::GetAtIndexStyle(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetStyle());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. стиля по имени                                        |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE MyCListTrendLine::GetAtNameOfStyle(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexStyle(ind));
        }
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. толщины линии по индексу                              |
//+------------------------------------------------------------------+
int MyCListTrendLine::GetAtIndexWidth(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetWidth());
     }
   //---
   return(-1);
  }
//+------------------------------------------------------------------+
//| Метод пол. толщины линии по имени                                |
//+------------------------------------------------------------------+
int MyCListTrendLine::GetAtNameOfWidth(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexWidth(ind));
        }
     }
   //---
   return(-1);
  }
//+------------------------------------------------------------------+
//| Метод пол. "задний план" линии по индексу                        |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtIndexBack(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetBack());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "задний план" линии по имени                          |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtNameOfBack(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexBack(ind));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "луч влево" линии по индексу                          |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtIndexRayLeft(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetRayLeft());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "луч влево" линии по имени                            |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtNameOfRayLeft(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexRayLeft(ind));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "луч вправо" линии по индексу                         |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtIndexRayRight(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetRayRight());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "луч вправо" линии по имени                           |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtNameOfRayRight(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexRayRight(ind));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "скрыть в списке" линии по индексу                    |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtIndexHidden(int ind)
  {
   //--- переменные
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>ind)
     {
      //---
      NewTrend = ListTrendLine.GetNodeAtIndex(ind);
      //---
      return(NewTrend.GetHidden());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "скрыть в списке" линии по имени                      |
//+------------------------------------------------------------------+
bool MyCListTrendLine::GetAtNameOfHidden(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexHidden(ind));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| ПОДГРУППА Delet...                                               |
//+------------------------------------------------------------------+
//| МОЧИМ ВСЕХ!!!                                                    |
//+------------------------------------------------------------------+
void MyCListTrendLine::ClearAll(void)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      ListTrendLine.Clear();
     }
  }
//+------------------------------------------------------------------+
//| МОЧИМ по индексу                                                 |
//+------------------------------------------------------------------+
bool MyCListTrendLine::DeletAtIndex(int ind)
  {
   //---
   if(ListTrendLine.Total()>ind)
     {
      return(ListTrendLine.Delete(ind));
     }
   //---
   return(false); // нет такого индекса!!!
  }
//+------------------------------------------------------------------+
//| Мочим по имени                                                   |
//+------------------------------------------------------------------+
bool MyCListTrendLine::DeletAtName(string Name)
  {
   //---
   if(ListTrendLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.DeletAtIndex(ind));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| ЗАЩИЩЕННЫЕ МЕТОДЫ КЛАССА                                         |
//+------------------------------------------------------------------+
//| поиск по имени Trend                                             |
//+------------------------------------------------------------------+
bool MyCListTrendLine::FindName(string Name)
  {
   //--- переменные
   int ind = 0;
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListTrendLine.Total())
        {
         //--- получаем указатель на объект Arrow
         NewTrend = ListTrendLine.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewTrend.GetName())
           {
            //--- найдено сопадение
            return(true);
           }
         //--- инкремент индекса
         ind++;
        }
     }
   //--- сопадений не найдено
   return(false);
  }
//+------------------------------------------------------------------+
//| Поиск имени, возрат индекса                                      |
//+------------------------------------------------------------------+
//| ret > -1, - индекс записи, иниче ошибка                          |
//+------------------------------------------------------------------+
int MyCListTrendLine::iFindName(string Name)
  {
   //---
   int ind = 0;
   int ret = -1;
   MyCTrendLine* NewTrend;
   //--- 
   if(ListTrendLine.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListTrendLine.Total())
        {
         //--- получаем указатель на объект Arrow
         NewTrend = ListTrendLine.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewTrend.GetName())
           {
            //--- найдено сопадение
            ret = ind;
            break;
           }
         //--- инкремент индекса
         ind++;
        }
     }
   //--- отправить ответ
   return(ret);
  }
//+------------------------------------------------------------------+