//+------------------------------------------------------------------+
//|                                                   MyCComment.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Базовый класс для хранения объекта "комментарий".                |
//| Класс обеспечивает:                                              |
//| 1. Хранение 32-х строк.                                          |
//| 2. Вывод на график строк.                                        |
//+------------------------------------------------------------------+
//| Особенности использования:                                       |
//| Скрипт, индикатор, советник - создает экземпляр данного класса,  |
//| и передает другим подклассам указатель на этот класс.            |
//| Нумерация строк от 1 до 32, другие значения игнорируются!        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <Object.mqh>
//+------------------------------------------------------------------+
//| Мой тип класса для хранения графического объекта "комметарий"    |
//+------------------------------------------------------------------+
class MyCComment : public CObject
  {
private:
   string            st0;
   string            st1,  st2,  st3,  st4,  st5,  st6,  st7,  st8; // Строки от 1 до 32
   string            st9,  st10, st11, st12, st13, st14, st15, st16;
   string            st17, st18, st19, st20, st21, st22, st23, st24;
   string            st25, st26, st27, st28, st29, st30, st31, st32;
public:
                     MyCComment();
                    ~MyCComment();
   //--- Функции Add - добавление строк:
   void              AddLines(string s1,string s2=NULL,string s3=NULL,string s4=NULL,
                              string s5=NULL,string s6=NULL,string s7=NULL,string s8=NULL,
                              string s9=NULL,string s10=NULL,string s11=NULL,string s12=NULL,
                              string s13=NULL,string s14=NULL,string s15=NULL,string s16=NULL,
                              string s17=NULL,string s18=NULL,string s19=NULL,string s20=NULL,
                              string s21=NULL,string s22=NULL,string s23=NULL,string s24=NULL,
                              string s25=NULL,string s26=NULL,string s27=NULL,string s28=NULL,
                              string s29=NULL,string s30=NULL,string s31=NULL,string s32=NULL);
   void              AddLineOfIndex(int ind, string st);          // Добавление строки по индексу
   //--- Функции Get:
   string            GetLineOfIndex(int ind, string st);          // Получение строки по индексу
   //--- Функции Clear:
   void              ClearAll(void);                              // Удаляем все
   //--- Прочие функции:
   void              Update(void){PrintComment();};
private:
   void              PrintComment(void);
  };
//+------------------------------------------------------------------+
//| Конструктор без параметров                                       |
//+------------------------------------------------------------------+
MyCComment::MyCComment()
  {
   //---
   st0  = "\r\n";
   //--- мочим все коменнты
   ClearAll();
  }
//+------------------------------------------------------------------+
//| деконструктор                                                    |
//+------------------------------------------------------------------+
MyCComment::~MyCComment()
  {
   //--- мочим все коменнты
   ClearAll();
  }
//+------------------------------------------------------------------+
//| ПУБЛИЧНЫЕ МЕТОДЫ КЛАССА                                          |
//+------------------------------------------------------------------+
//| Функция добавляет новые строки комментария                       |
//+------------------------------------------------------------------+
void MyCComment::AddLines(string s1,string s2=NULL,string s3=NULL,string s4=NULL,
                          string s5=NULL,string s6=NULL,string s7=NULL,string s8=NULL,
                          string s9=NULL,string s10=NULL,string s11=NULL,string s12=NULL,
                          string s13=NULL,string s14=NULL,string s15=NULL,string s16=NULL,
                          string s17=NULL,string s18=NULL,string s19=NULL,string s20=NULL,
                          string s21=NULL,string s22=NULL,string s23=NULL,string s24=NULL,
                          string s25=NULL,string s26=NULL,string s27=NULL,string s28=NULL,
                          string s29=NULL,string s30=NULL,string s31=NULL,string s32=NULL)
  {
   //--- вставляем новые данные
   if(s1 != NULL) st1  =s1; 
   if(s2 != NULL) st2  =s2; 
   if(s3 != NULL) st3  =s3; 
   if(s4 != NULL) st4  =s4; 
   if(s5 != NULL) st5  =s5; 
   if(s6 != NULL) st6  =s6; 
   if(s7 != NULL) st7  =s7; 
   if(s8 != NULL) st8  =s8; 
   if(s9 != NULL) st9  =s9; 
   if(s10!= NULL) st10 =s10;
   if(s11!= NULL) st11 =s11;
   if(s12!= NULL) st12 =s12;
   if(s13!= NULL) st13 =s13;
   if(s14!= NULL) st14 =s14;
   if(s15!= NULL) st15 =s15;
   if(s16!= NULL) st16 =s16;
   if(s17!= NULL) st17 =s17;
   if(s18!= NULL) st18 =s18;
   if(s19!= NULL) st19 =s19;
   if(s20!= NULL) st20 =s20;
   if(s21!= NULL) st21 =s21;
   if(s22!= NULL) st22 =s22;
   if(s23!= NULL) st23 =s23;
   if(s24!= NULL) st24 =s24;
   if(s25!= NULL) st25 =s25;
   if(s26!= NULL) st26 =s26;
   if(s27!= NULL) st27 =s27;
   if(s28!= NULL) st28 =s28;
   if(s29!= NULL) st29 =s29;
   if(s30!= NULL) st30 =s30;
   if(s31!= NULL) st31 =s31;
   if(s32!= NULL) st32 =s32;
   //--- Вывод на график коммента...
   PrintComment();
  }
//+------------------------------------------------------------------+
//| Функция добавляет новую строку комментария по индексу            |
//+------------------------------------------------------------------+
void MyCComment::AddLineOfIndex(int ind,string st)
  {
   //---
   switch(ind)
     {
      case 1:
        st1  =st; 
        break;
      case 2:
        st2  =st; 
        break;
      case 3:
        st3  =st; 
        break;
      case 4:
        st4  =st; 
        break;
      case 5:
        st5  =st; 
        break;
      case 6:
        st6  =st; 
        break;
      case 7:
        st7  =st; 
        break;
      case 8:
        st8  =st; 
        break;
      case 9:
        st9  =st; 
        break;
      case 10:
        st10 =st; 
        break;
      case 11:
        st11 =st; 
        break;
      case 12:
        st12 =st; 
        break;
      case 13:
        st13 =st; 
        break;
      case 14:
        st14 =st; 
        break;
      case 15:
        st15 =st; 
        break;
      case 16:
        st16 =st; 
        break;
      case 17:
        st17 =st; 
        break;
      case 18:
        st18 =st; 
        break;
      case 19:
        st19 =st; 
        break;
      case 20:
        st20 =st; 
        break;
      case 21:
        st21 =st; 
        break;
      case 22:
        st22 =st; 
        break;
      case 23:
        st23 =st; 
        break;
      case 24:
        st24 =st; 
        break;
      case 25:
        st25 =st; 
        break;
      case 26:
        st26 =st; 
        break;
      case 27:
        st27 =st; 
        break;
      case 28:
        st28 =st; 
        break;
      case 29:
        st29 =st; 
        break;
      case 30:
        st30 =st; 
        break;
      case 31:
        st31 =st; 
        break;
      case 32:
        st32 =st; 
        break;
      default:
        //--- Exit...
        return;
        break;
     }
   //--- Вывод на график коммента...
   PrintComment();   
  }
//+------------------------------------------------------------------+
//| Функция получает строку комментария по индексу                   |
//+------------------------------------------------------------------+
string MyCComment::GetLineOfIndex(int ind,string st)
  {
   //---
   switch(ind)
     {
      case 1:
        return(st1);     
        break;
      case 2:
        return(st2);     
        break;
      case 3:
        return(st3);     
        break;
      case 4:
        return(st4);     
        break;
      case 5:
        return(st5);    
        break;
      case 6:
        return(st6);     
        break;
      case 7:
        return(st7);     
        break;
      case 8:
        return(st8);     
        break;
      case 9:
        return(st9);     
        break;
      case 10:
        return(st10);    
        break;
      case 11:
        return(st11);    
        break;
      case 12:
        return(st12);    
        break;
      case 13:
        return(st13);    
        break;
      case 14:
        return(st14);    
        break;
      case 15:
        return(st15);    
        break;
      case 16:
        return(st16);    
        break;
      case 17:
        return(st17);    
        break;
      case 18:
        return(st18);    
        break;
      case 19:
        return(st19);    
        break;
      case 20:
        return(st20);    
        break;
      case 21:
        return(st21);    
        break;
      case 22:
        return(st22);    
        break;
      case 23:
        return(st23);    
        break;
      case 24:
        return(st24);    
        break;
      case 25:
        return(st25);    
        break;
      case 26:
        return(st26);    
        break;
      case 27:
        return(st27);    
        break;
      case 28:
        return(st28);    
        break;
      case 29:
        return(st29);    
        break;
      case 30:
        return(st30);    
        break;
      case 31:
        return(st31);    
        break;
      case 32:
        return(st32);    
        break;
      default:
        //--- Exit...
        return(NULL);
        break;
     }
   //---
   return(NULL);  
  }
//+------------------------------------------------------------------+
//| Функция очистки                                                  |
//+------------------------------------------------------------------+
void MyCComment::ClearAll(void)
  {
   //---
   st1 =NULL;st2 =NULL;st3 =NULL;st4 =NULL;st5 =NULL;st6 =NULL;st7 =NULL;st8 =NULL;
   st9 =NULL;st10=NULL;st11=NULL;st12=NULL;st13=NULL;st14=NULL;st15=NULL;st16=NULL;
   st17=NULL;st18=NULL;st19=NULL;st20=NULL;st21=NULL;st22=NULL;st23=NULL;st24=NULL;
   st25=NULL;st26=NULL;st27=NULL;st28=NULL;st29=NULL;st30=NULL;st31=NULL;st32=NULL;
   //--- Вывод на график коммента...
   PrintComment();   
  }
//+------------------------------------------------------------------+
//| ЗАЩИЩЕННЫЕ МЕТОДЫ КЛАССА                                         |
//+------------------------------------------------------------------+
//| Вывод на график коммента                                         |
//+------------------------------------------------------------------+
void MyCComment::PrintComment(void)
  {
   //---
   Comment(st1,  st0,  st2,  st0, st3,  st0, st4,  st0, st5,  st0, st6,  st0, st7,  st0, st8,  st0, 
           st9,  st0,  st10, st0, st11, st0, st12, st0, st13, st0, st14, st0, st15, st0, st16, st0,
           st17, st0,  st18, st0, st19, st0, st20, st0, st21, st0, st22, st0, st23, st0, st24, st0,
           st25, st0,  st26, st0, st27, st0, st28, st0, st29, st0, st30, st0, st31, st0, st32);
  }
//+------------------------------------------------------------------+
