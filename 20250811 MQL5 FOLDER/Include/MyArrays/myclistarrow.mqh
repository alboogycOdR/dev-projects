//+------------------------------------------------------------------+
//|                                                 MyCListArrow.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Класс реализует контейнер для хранения объектов Arrow и облег-   |
//| чает их использование, берет на себя всю функцию обслуживания    |
//| Arrow-объектов.                                                  |
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
#include <MyObjects\MyCArrow.mqh>
//+------------------------------------------------------------------+
//| класс MyCListArrow                                               |
//+------------------------------------------------------------------+
class MyCListArrow
  {
private:
   CList*            ListArrow;                                    // гл. укз. на список Arrow
public:
                     MyCListArrow();
                    ~MyCListArrow();
   //--- Методы Insert
   void              Insert(); // ввод Arrow
   void              Insert(double Price, datetime Times);         // ввод Arrow
   void              Insert(double Price, datetime Times, 
                            ENUM_OBJECT Type);                     // ввод Arrow
   bool              Insert(string Name, string Tip, double Price, 
                             datetime Times, ENUM_OBJECT Type);    // ввод Arrow
   //--- Методы Set
   bool              SetAtIndexName(int ind, string NewName);      // метод изм. имени
   bool              SetAtNameOfName(string Name, string NewName); // метод изм. имени
   bool              SetAtIndexTip(int ind, string NewTip);        // метод изм. описания
   bool              SetAtNameOfTip(string Name, string NewTip);   // метод изм. описания
   bool              SetAtIndexPrice(int ind, double NewPrice);    // метод изм. цены
   bool              SetAtNameOfPrice(string Name, double NewPrice);// метод изм. цены
   bool              SetAtIndexTime(int ind, datetime NewTime);    // метод изм. даты
   bool              SetAtNameOfTime(string Name, datetime NewTime);// метод изм. даты
   bool              SetAtIndexType(int ind, ENUM_OBJECT NewType); // метод изм. типа
   bool              SetAtNameOfType(string Name, ENUM_OBJECT NewType);// метод изм. типа
   bool              SetAtIndexCode(int ind, int NewCode);        // метод изм. доп. типа
   bool              SetAtNameOfCode(string Name, int NewCode);   // метод изм. доп. типа
   bool              SetAtIndexColor(int ind, color NewColor);     // метод изм. цвета
   bool              SetAtNameOfColor(string Name, color NewColor);// метод изм. цвета
   bool              SetAtIndexAnchor(int ind, ENUM_ARROW_ANCHOR ArrowAnchor);// метод изм. выравнивания
   bool              SetAtNameOfAnchor(string Name, ENUM_ARROW_ANCHOR ArrowAnchor);// метод изм. выравнивания
   //--- Mетоды Get
   int               GetSize();                                    // получение размера ListArrow
   string            GetLastArrowName();                           // получение последнего имени
   string            GetAtIndexName(int ind);                      // метод пол. имени
   int               GetAtNameOfIndex(string Name);                // метод пол. индекса
   string            GetAtIndexTip(int ind);                       // метод пол. описания
   string            GetAtNameOfTip(string Name);                  // метод пол. описания
   double            GetAtIndexPrice(int ind);                     // метод пол. цены
   double            GetAtNameOfPrice(string Name);                // метод пол. цены
   datetime          GetAtIndexTime(int ind);                      // метод пол. времени
   datetime          GetAtNameOfTime(string Name);                 // метод пол. времени
   ENUM_OBJECT       GetAtIndexType(int ind);                      // метод пол. типа
   ENUM_OBJECT       GetAtNameOfType(string Name);                 // метод пол. типа
   int               GetAtIndexCode(int ind);                      // метод пол. доп. типа
   int               GetAtNameOfCode(string Name);                 // метод пол. доп. типа
   color             GetAtIndexColor(int ind);                     // метод пол. цвета
   color             GetAtNameOfColor(string Name);                // метод пол. цвета
   ENUM_ARROW_ANCHOR GetAtIndexAnchor(int ind);                    // метод пол. выравнивания
   ENUM_ARROW_ANCHOR GetAtNameOfAnchor(string Name);               // метод пол. выравнивания
   //--- Методы Delet
   void              ClearAll();                                   // МОЧИМ ВСЕХ!!!
   bool              DeletAtIndex(int ind);                        // мочить строго по индексу
   bool              DeletAtName(string Name);                     // мочить по имени
   //--- Методы Find
private:
   //--- Методы Find
   bool              FindName(string Name);                        // поиск по имени Arrow
   int               iFindName(string Name);                       // поиск по имени Arrow
  };
//+------------------------------------------------------------------+
//| конструктор                                                      |
//+------------------------------------------------------------------+
MyCListArrow::MyCListArrow()
  {
   //--- создание списка
   ListArrow = new CList;
   //--- класс-список сам чистит память
   ListArrow.FreeMode(true);
  }
//+------------------------------------------------------------------+
//| деструктур                                                       |
//+------------------------------------------------------------------+
MyCListArrow::~MyCListArrow()
  {
   //---
   if(ListArrow.Total()>0)
     {
      ListArrow.Clear();
     }
   //---
   delete ListArrow;
  }
//+------------------------------------------------------------------+
//| получение размера ListArrow                                      |
//+------------------------------------------------------------------+
int MyCListArrow::GetSize(void)
  {
   return(ListArrow.Total());
  }
//+------------------------------------------------------------------+
//| ввод данных об Arrow                                             |
//+------------------------------------------------------------------+
bool MyCListArrow::Insert(string Name,string Tip,double Price,datetime Times,ENUM_OBJECT Type)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- поиск по имени объекта
   if(ListArrow.Total()>0)
     {
      //--- вызов метода поиска
      if(this.FindName(Name)) return(false); // есть совпадения по имени Arrow!
     }
   //---
   NewArrow = new MyCArrow(Name,Tip,Price,Times,Type);
   ListArrow.Add(NewArrow);
   //---
   return(true);
  }
//+------------------------------------------------------------------+
//| ввод данных об Arrow                                             |
//+------------------------------------------------------------------+
void MyCListArrow::Insert(double Price,datetime Times,ENUM_OBJECT Type)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //---
   NewArrow = new MyCArrow(Price,Times,Type);
   ListArrow.Add(NewArrow);
  }
//+------------------------------------------------------------------+
//| ввод данных об Arrow                                             |
//+------------------------------------------------------------------+
void MyCListArrow::Insert(double Price,datetime Times)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //---
   NewArrow = new MyCArrow(Price,Times);
   ListArrow.Add(NewArrow);
  }
//+------------------------------------------------------------------+
//| ввод данных об Arrow                                             |
//+------------------------------------------------------------------+
void MyCListArrow::Insert()
  {
   //--- переменные
   MyCArrow* NewArrow;
   //---
   NewArrow = new MyCArrow();
   ListArrow.Add(NewArrow);
  }
//+------------------------------------------------------------------+
//| метод Set изм. цвета по имени                                    |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfColor(string Name,color NewColor)
  {
   //---
   if(ListArrow.Total()>0)
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
//| метод Set изм. цвета по индексу                                  |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexColor(int ind,color NewColor)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetColor(NewColor));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. доп. индекса по индексу                           |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexCode(int ind,int NewCode)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetCode(NewCode));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. доп. индекса по имени                             |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfCode(string Name,int NewCode)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexCode(ind, NewCode));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. имени по индексу                                  |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexName(int ind,string NewName)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetName(NewName));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. имени по индексу                                  |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfName(string Name,string NewName)
  {
   //---
   if(ListArrow.Total()>0)
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
//| метод Set изм. описания по индексу                               |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexTip(int ind,string NewTip)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetTip(NewTip));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. описания по индексу                               |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfTip(string Name,string NewTip)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexTip(ind, NewTip));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. цены по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexPrice(int ind,double NewPrice)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetPrice(NewPrice));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. цены по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfPrice(string Name,double NewPrice)
  {
   //---
   if(ListArrow.Total()>0)
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
//| метод Set изм. даты по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexTime(int ind,datetime NewTime)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetTime(NewTime));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. даты по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfTime(string Name,datetime NewTime)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexTime(ind, NewTime));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. типа по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexType(int ind,ENUM_OBJECT NewType)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetType(NewType));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод Set изм. типа по индексу                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfType(string Name,ENUM_OBJECT NewType)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexType(ind, NewType));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. выравнивания                                          |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtIndexAnchor(int ind,ENUM_ARROW_ANCHOR ArrowAnchor)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.SetAnchor(ArrowAnchor));
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод изм. выравнивания                                          |
//+------------------------------------------------------------------+
bool MyCListArrow::SetAtNameOfAnchor(string Name,ENUM_ARROW_ANCHOR ArrowAnchor)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.SetAtIndexAnchor(ind, ArrowAnchor));
        }
     }
   //---
   return(false);
  }
//+------------------------------------------------------------------+
//| метод пол. имени                                                 |
//+------------------------------------------------------------------+
string MyCListArrow::GetAtIndexName(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| Получаем имя последнего элемента в списке                        |
//+------------------------------------------------------------------+
string MyCListArrow::GetLastArrowName(void)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>0)
     {
      //---
      NewArrow = ListArrow.GetLastNode();
      //---
      return(NewArrow.GetName());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол цвета по индексу                                       |
//+------------------------------------------------------------------+
color MyCListArrow::GetAtIndexColor(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetColor());
     }
   //--- Ошибка типа
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод получения цвета по имени                                   |
//+------------------------------------------------------------------+
color MyCListArrow::GetAtNameOfColor(string Name)
  {
   //---
   if(ListArrow.Total()>0)
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
//| метод пол. доп. типа по индексу                                  |
//+------------------------------------------------------------------+
int MyCListArrow::GetAtIndexCode(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetCode());
     }
   //--- Ошибка типа
   return(-1);
  }
//+------------------------------------------------------------------+
//| метод пол. доп. типа по имени                                    |
//+------------------------------------------------------------------+
int MyCListArrow::GetAtNameOfCode(string Name)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexCode(ind));
        }
     }
   //---Error
   return(-1);
  }
//+------------------------------------------------------------------+
//| метод пол. имени                                                 |
//+------------------------------------------------------------------+
int MyCListArrow::GetAtNameOfIndex(string Name)
  {
   return(this.iFindName(Name));
  }
//+------------------------------------------------------------------+
//| метод пол. описания                                              |
//+------------------------------------------------------------------+
string MyCListArrow::GetAtIndexTip(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetTip());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол. описания                                              |
//+------------------------------------------------------------------+
string MyCListArrow::GetAtNameOfTip(string Name)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexTip(ind));
        }
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол. цены                                                  |
//+------------------------------------------------------------------+
double MyCListArrow::GetAtIndexPrice(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetPrice());
     }
   //---
   return(-1.0);
  }
//+------------------------------------------------------------------+
//| метод пол. цены                                                  |
//+------------------------------------------------------------------+
double MyCListArrow::GetAtNameOfPrice(string Name)
  {
   //---
   if(ListArrow.Total()>0)
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
//| метод пол. времени                                               |
//+------------------------------------------------------------------+
datetime MyCListArrow::GetAtIndexTime(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetTime());
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| метод пол. времени                                               |
//+------------------------------------------------------------------+
datetime MyCListArrow::GetAtNameOfTime(string Name)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexTime(ind));
        }
     }
   //---
   return(NULL);// ошибочное время
  }
//+------------------------------------------------------------------+
//| метод пол. типа                                                  |
//+------------------------------------------------------------------+
ENUM_OBJECT MyCListArrow::GetAtIndexType(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetType());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол. типа                                                  |
//+------------------------------------------------------------------+
ENUM_OBJECT MyCListArrow::GetAtNameOfType(string Name)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexType(ind));
        }
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол. выравнивания                                          |
//+------------------------------------------------------------------+
ENUM_ARROW_ANCHOR MyCListArrow::GetAtIndexAnchor(int ind)
  {
   //--- переменные
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>ind)
     {
      //---
      NewArrow = ListArrow.GetNodeAtIndex(ind);
      //---
      return(NewArrow.GetAnchor());
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| метод пол. выравнивания                                          |
//+------------------------------------------------------------------+
ENUM_ARROW_ANCHOR MyCListArrow::GetAtNameOfAnchor(string Name)
  {
   //---
   if(ListArrow.Total()>0)
     {
      int ind = this.iFindName(Name);
      //---
      if(ind>-1)
        {
         return(this.GetAtIndexAnchor(ind));
        }
     }
   //---
   return(NULL);
  }
//+------------------------------------------------------------------+
//| поиск по имени Arrow                                             |
//+------------------------------------------------------------------+
bool MyCListArrow::FindName(string Name)
  {
   //--- переменные
   int ind = 0;
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListArrow.Total())
        {
         //--- получаем указатель на объект Arrow
         NewArrow = ListArrow.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewArrow.GetName())
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
int MyCListArrow::iFindName(string Name)
  {
   //---
   int ind = 0;
   int ret = -1;
   MyCArrow* NewArrow;
   //--- 
   if(ListArrow.Total()>0)
     {
      //--- поисковый цикл
      while(ind<ListArrow.Total())
        {
         //--- получаем указатель на объект Arrow
         NewArrow = ListArrow.GetNodeAtIndex(ind);
         //--- сравниваем две строки на равенство
         if(Name == NewArrow.GetName())
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
//| МОЧИМ ВСЕХ!!!                                                    |
//+------------------------------------------------------------------+
void MyCListArrow::ClearAll(void)
  {
   //---
   if(ListArrow.Total()>0)
     {
      ListArrow.Clear();
     }
  }
//+------------------------------------------------------------------+
//| МОЧИМ по индексу                                                 |
//+------------------------------------------------------------------+
bool MyCListArrow::DeletAtIndex(int ind)
  {
   //---
   if(ListArrow.Total()>ind)
     {
      return(ListArrow.Delete(ind));
     }
   //---
   return(false); // нет такого индекса!!!
  }
//+------------------------------------------------------------------+
//| Мочим по имени                                                   |
//+------------------------------------------------------------------+
bool MyCListArrow::DeletAtName(string Name)
  {
   //---
   if(ListArrow.Total()>0)
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