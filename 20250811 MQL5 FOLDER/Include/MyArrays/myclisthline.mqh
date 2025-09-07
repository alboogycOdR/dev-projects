//+------------------------------------------------------------------+
//|                                                 MyCListHLine.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Класс реализует контейнер для хранения объектов HLine и облег-   |
//| чает их использование, берет на себя всю функцию обслуживания    |
//| HLine-объектов.                                                  |
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
#include <MyObjects\MyCHLine.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MyCListHLine
  {
private:
   CList*            ListHLine;                                    // гл. укз. на список HLine
public:
                     MyCListHLine();
                    ~MyCListHLine();
   //--- Методы Insert
   void              Insert(void);                                 // ввод HLine
   void              Insert(double Price);                         // ввод HLine + координаты
   void              Insert(double Price, ENUM_LINE_STYLE Style);  // ввод HLine + координаты + style
   bool              Insert(string Name, double Price, 
                            ENUM_LINE_STYLE Style);                // ввод HLine + координаты + style + name   
   //--- Методы Set
   bool              SetAtIndexName(int ind, string NewName);      // метод изм. имени
   bool              SetAtNameOfName(string Name, string NewName); // метод изм. имени
   bool              SetAtIndexPrice(int ind, double NewPrice);    // метод изм. цены 
   bool              SetAtNameOfPrice(string Name, double NewPrice);//метод изм. цены 
   bool              SetAtIndexColor(int ind, color NewColor);     // метод изм. цвета
   bool              SetAtNameOfColor(string Name, color NewColor);// метод изм. цвета
   bool              SetAtIndexStyle(int ind, ENUM_LINE_STYLE style);// метод изм. стиля
   bool              SetAtNameOfStyle(string Name, ENUM_LINE_STYLE style);// метод изм. стиля
   bool              SetAtIndexWidth(int ind, int width);          // метод изм. толщины
   bool              SetAtNameOfWidth(string Name, int width);     // метод изм. толщины
   bool              SetAtIndexBack(int ind, bool back);           // метод изм. "задний план"
   bool              SetAtNameOfBack(string Name, bool back);      // метод изм. "задний план"
   bool              SetAtIndexHidden(int ind, bool hidden);       // метод изм. "скрыть в списке"
   bool              SetAtNameOfHidden(string Name, bool hidden);  // метод изм. "скрыть в списке"   
   //--- Mетоды Get
   int               GetSize();                                    // получение размера ListTrendLine
   string            GetAtIndexName(int ind);                      // метод пол. имени
   string            GetLastHLineName();                           // получение последнего имени
   string            GetLastName(){return(GetLastHLineName());};   // получение последнего имени
   int               GetAtNameOfIndex(string Name);                // метод пол. индекса
   double            GetAtIndexPrice(int ind);                     // метод пол. цены  по инексу объекта
   double            GetAtNameOfPrice(string Name);                // метод пол. цены  по имени  объекта
   color             GetAtIndexColor(int ind);                     // метод пол. цвета по индексу
   color             GetAtNameOfColor(string Name);                // метод пол. цвета по имени
   ENUM_LINE_STYLE   GetAtIndexStyle(int ind);                     // метод пол. типа по индексу
   ENUM_LINE_STYLE   GetAtNameOfStyle(string Name);                // метод пол. типа по имени
   int               GetAtIndexWidth(int ind);                     // метод пол. толщины линии по индексу
   int               GetAtNameOfWidth(string Name);                // метод пол. толщины линии по имени
   bool              GetAtIndexBack(int ind);                      // метод пол. "задний план" линии по индексу
   bool              GetAtNameOfBack(string Name);                 // метод пол. "задний план" линии по имени
   bool              GetAtIndexHidden(int ind);                    // метод пол. "скрыть в списке" линии по индексу
   bool              GetAtNameOfHidden(string Name);               // метод пол. "скрыть в списке" линии по имени
   //--- Методы Delet
   void              ClearAll();                                   // МОЧИМ ВСЕХ!!!
   bool              DeletAtIndex(int ind);                        // мочить строго по индексу
   bool              DeletAtName(string Name);                     // мочить по имени
private:
   //--- Методы Find
   bool              FindName(string Name);                        // поиск по имени HLine
   int               iFindName(string Name);                       // поиск по имени HLine
  };
//+------------------------------------------------------------------+
//| конструктор                                                      |
//+------------------------------------------------------------------+
MyCListHLine::MyCListHLine()
  {
   //--- создание списка
   ListHLine = new CList;
   //--- класс-список сам чистит память
   ListHLine.FreeMode(true);
  }
//+------------------------------------------------------------------+
//| деструктур                                                       |
//+------------------------------------------------------------------+
MyCListHLine::~MyCListHLine()
  {
   //---
   if(ListHLine.Total()>0)
     {
      ListHLine.Clear();
     }
   //---
   delete ListHLine;
  }
//+------------------------------------------------------------------+
//| Insert методы                                                    |
//+------------------------------------------------------------------+
//| Базовый Insert                                                   |
//+------------------------------------------------------------------+
void MyCListHLine::Insert(void)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //---
   NewHLine = new MyCHLine();
   ListHLine.Add(NewHLine);
  }
//+------------------------------------------------------------------+
//| Insert + координаты                                              |
//+------------------------------------------------------------------+
void MyCListHLine::Insert(double Price)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //---
   NewHLine = new MyCHLine(Price);
   ListHLine.Add(NewHLine);
  }
//+------------------------------------------------------------------+
//| Insert + координаты + style                                      |
//+------------------------------------------------------------------+
void MyCListHLine::Insert(double Price,ENUM_LINE_STYLE Style)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //---
   NewHLine = new MyCHLine(Price,Style);
   ListHLine.Add(NewHLine);
  }
//+------------------------------------------------------------------+
//| Insert + координаты + style + name                               |
//+------------------------------------------------------------------+
bool MyCListHLine::Insert(string Name,double Price,ENUM_LINE_STYLE Style)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- поиск по имени объекта
   if(ListHLine.Total()>0)
     {
      //--- вызов метода поиска
      if(this.FindName(Name)) return(false); // есть совпадения по имени HLine
     }
   //---
   NewHLine = new MyCHLine(Name,Price,Style);
   ListHLine.Add(NewHLine);
   //---
   return(true);
  }
//+------------------------------------------------------------------+
//| ПОДГРУППА SET...                                                 |
//+------------------------------------------------------------------+
//| Метод изм. имени                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtIndexName(int ind,string NewName)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetName(NewName));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод изм. имени                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfName(string Name,string NewName)
  {
   //---
   if(ListHLine.Total()>0)
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
//| метод изм. цены                                                  |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtIndexPrice(int ind,double NewPrice)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetPrice(NewPrice));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цены                                                  |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfPrice(string Name,double NewPrice)
  {
   //---
   if(ListHLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexPrice(ind, NewPrice));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цвета                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtIndexColor(int ind,color NewColor)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetColor(NewColor));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. цвета                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfColor(string Name,color NewColor)
  {
   //---
   if(ListHLine.Total()>0)
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
bool MyCListHLine::SetAtIndexStyle(int ind,ENUM_LINE_STYLE style)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetStyle(style));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. стиля                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfStyle(string Name,ENUM_LINE_STYLE style)
  {
   //---
   if(ListHLine.Total()>0)
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
bool MyCListHLine::SetAtIndexWidth(int ind,int width)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetWidth(width));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. толщины                                               |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfWidth(string Name,int width)
  {
   //---
   if(ListHLine.Total()>0)
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
bool MyCListHLine::SetAtIndexBack(int ind,bool back)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetBack(back));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "задний план"                                         |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfBack(string Name,bool back)
  {
   //---
   if(ListHLine.Total()>0)
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
//| метод изм. "скрыть в списке"                                     |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtIndexHidden(int ind,bool hidden)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.SetHidden(hidden));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. "скрыть в списке"                                     |
//+------------------------------------------------------------------+
bool MyCListHLine::SetAtNameOfHidden(string Name,bool hidden)
  {
   //---
   if(ListHLine.Total()>0)
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
//| получение размера ListHLine                                      |
//+------------------------------------------------------------------+
int MyCListHLine::GetSize(void)
  {
   return(ListHLine.Total());
  }
//+------------------------------------------------------------------+
//| Метод пол. имени по индексу                                      |
//+------------------------------------------------------------------+
string MyCListHLine::GetAtIndexName(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Получение последнего имени в списке                              |
//+------------------------------------------------------------------+
string MyCListHLine::GetLastHLineName(void)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>0)
     {
      //---
      NewHLine = ListHLine.GetLastNode();
      //---
      return(NewHLine.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. индекса по имени(общедоступный)                       |
//+------------------------------------------------------------------+
int MyCListHLine::GetAtNameOfIndex(string Name)
  {
   return(this.iFindName(Name));
  }
//+------------------------------------------------------------------+
//| Метод пол. цены   по инексу                                      |
//+------------------------------------------------------------------+
double MyCListHLine::GetAtIndexPrice(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetPrice());
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. цены   по имени  объекта                              |
//+------------------------------------------------------------------+
double MyCListHLine::GetAtNameOfPrice(string Name)
  {
   //---
   if(ListHLine.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexPrice(ind));
        }
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| Метод пол. цвета по индексу                                      |
//+------------------------------------------------------------------+
color MyCListHLine::GetAtIndexColor(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetColor());
     }
   //--- Ошибка типа
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. цвета по имени                                        |
//+------------------------------------------------------------------+
color MyCListHLine::GetAtNameOfColor(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
ENUM_LINE_STYLE MyCListHLine::GetAtIndexStyle(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetStyle());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Метод пол. стиля по имени                                        |
//+------------------------------------------------------------------+
ENUM_LINE_STYLE MyCListHLine::GetAtNameOfStyle(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
int MyCListHLine::GetAtIndexWidth(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetWidth());
     }
   //---
   return(-1);
  }
//+------------------------------------------------------------------+
//| Метод пол. толщины линии по имени                                |
//+------------------------------------------------------------------+
int MyCListHLine::GetAtNameOfWidth(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
bool MyCListHLine::GetAtIndexBack(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetBack());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "задний план" линии по имени                          |
//+------------------------------------------------------------------+
bool MyCListHLine::GetAtNameOfBack(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
//| Метод пол. "скрыть в списке" линии по индексу                    |
//+------------------------------------------------------------------+
bool MyCListHLine::GetAtIndexHidden(int ind)
  {
   //--- переменные
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>ind)
     {
      //---
      NewHLine = ListHLine.GetNodeAtIndex(ind);
      //---
      return(NewHLine.GetHidden());
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| Метод пол. "скрыть в списке" линии по имени                      |
//+------------------------------------------------------------------+
bool MyCListHLine::GetAtNameOfHidden(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
void MyCListHLine::ClearAll(void)
  {
   //---
   if(ListHLine.Total()>0)
     {
      ListHLine.Clear();
     }
  }
//+------------------------------------------------------------------+
//| МОЧИМ по индексу                                                 |
//+------------------------------------------------------------------+
bool MyCListHLine::DeletAtIndex(int ind)
  {
   //---
   if(ListHLine.Total()>ind)
     {
      return(ListHLine.Delete(ind));
     }
   //---
   return(false); // нет такого индекса!!!
  }
//+------------------------------------------------------------------+
//| Мочим по имени                                                   |
//+------------------------------------------------------------------+
bool MyCListHLine::DeletAtName(string Name)
  {
   //---
   if(ListHLine.Total()>0)
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
//| поиск по имени HLine                                             |
//+------------------------------------------------------------------+
bool MyCListHLine::FindName(string Name)
  {
   //--- переменные
   int ind = 0;
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListHLine.Total())
        {
         //--- получаем указатель на объект HLine
         NewHLine = ListHLine.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewHLine.GetName())
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
int MyCListHLine::iFindName(string Name)
  {
   //---
   int ind = 0;
   int ret = -1;
   MyCHLine* NewHLine;
   //--- 
   if(ListHLine.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListHLine.Total())
        {
         //--- получаем указатель на объект HLine
         NewHLine = ListHLine.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewHLine.GetName())
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