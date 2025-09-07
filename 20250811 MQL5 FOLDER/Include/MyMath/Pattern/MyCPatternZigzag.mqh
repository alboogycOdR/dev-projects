//+------------------------------------------------------------------+
//|                                             MyCPatternZigzag.mqh |
//|                                     Copyright 2014, A. Emelyanov |
//|                                        A.Emelyanov2010@yandex.ru |
//+------------------------------------------------------------------+
//| Производный класс MyCPattern. Дополняет базовый класс наличием:  |
//| 1. Метод поиска экстремумов(алгоритм клас.Zigzag);               |
//| 2. Метод прогноза движения цены: level_0, level_1(тест режим)    |
//| 3. Метод взаимодействия с классом MyCComment(комментарий графика)|
//+------------------------------------------------------------------+
//|+ 07/06/2014: Добавлен корректор идеальных пропорций эвол/мутаций |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, A. Emelyanov"
#property link      "A.Emelyanov2010@yandex.ru"
#property version   "1.04"
//+------------------------------------------------------------------+
//| Подключаемые библиотеки                                          |
//+------------------------------------------------------------------+
#include <MyMath\Pattern\MyCPattern.mqh>
#include <MyMath\Extremum\MyCExtremum.mqh>
#include <MyObjects\MyCComment.mqh>
//+------------------------------------------------------------------+
//| ГЛОБАЛЬНЫЕ КОНСТАНТЫ БИБЛИОТЕКИ                                  |
//+------------------------------------------------------------------+
#define PATTERN_ZIG_RESERVE 50
//+------------------------------------------------------------------+
//| класс MyCPatternZigzag потомок MyCPattern                        |
//+------------------------------------------------------------------+
class MyCPatternZigzag : public MyCPattern
  {
protected:
   //--- ПЕРЕМЕННЫЕ, УКАЗАТЕЛИ ДЛЯ ПРИВАТНОГО ПОЛЬЗОВАНИЯ
   int               Depth;                                       // Окно поиска отклонений
   int               Deviation;                                   // Колебание цены в пунктах
   int               Backstep;                                    // Минимальный шаг
   int               SizeBuffers;                                 // Размер буферов
   int               NumberLineComment;                           // Номер строки "коммента"
   double            pE;                                          // прогноз: точка "эволюции level_0"
   double            pM;                                          // прогноз: точка "мутации  level_0"
   double            pEv1;                                        // прогноз: точка "эволюции level_1"
   double            pM1;                                         // прогноз: точка "мутации  level_1"
   datetime          tA;                                          // время  точки A
   datetime          tB;                                          // время  точки B
   datetime          tC;                                          // время  точки C
   datetime          tD;                                          // время  точки D
   datetime          tE;                                          // время  точки E
   datetime          tEv;                                         // время  точки "эволюции"
   datetime          tM;                                          // время  точки "мутации"
   int               iA;                                          // индекс точки А
   int               iB;                                          // индекс точки B
   int               iC;                                          // индекс точки C 
   int               iD;                                          // индекс точки D 
   int               iE;                                          // индекс точки E 
   int               iEv;                                         // прогноз: индекс точки "эволюции"
   int               iM;                                          // прогноз: индекс точки "мутации"
   int               countEvolution;                              // счетчик эволюций
   int               countMutation;                               // счетчик мутаций
   int               countError;                                  // счетчик "ошибок модели"
   MyCExtremum*      Extremum;                                    // класс экстремум(Zigzag)
   MyCComment*       MyComment;                                   // класс "коммента"
public:
   //--- Конструктора
                     MyCPatternZigzag();
                    ~MyCPatternZigzag();
   //--- методы Set параметры
   void              SetDepth(int depth){Depth = depth;};         // Установка "Окно поиска отклонений"
   void              SetDeviation(int dev){Deviation=dev;};       // Установка "Колебание цены в пунктах"
   void              SetBackstep(int back){Backstep = back;};     // Установка "Минимальный шаг"
   void              SetSizeBuffers(int size){SizeBuffers = size;};//Установка "Размер буферов"
   void              SetNumberLineComment(int NL){if(NL>0&&NL<31){NumberLineComment = NL;
                                                    }else NumberLineComment = 1;};//Установка номера строки "коммента"
   //--- методы Get параметры
   int               GetDepth(){return(Depth);};                  // Окно поиска отклонений
   int               GetDeviation(){return(Deviation);};          // Колебание цены в пунктах
   int               GetBackstep(){return(Backstep);};            // 
   int               GetSizeBuffers(){return(SizeBuffers);};      // Размер буферов
   int               GetNumberLineComment(){return(NumberLineComment);};//Номер строки "коммента"
   int               GetCountLineComment();                       // Возвращает кол-во строк "комментария"
   //--- методы Get расчеты...
   string            GetNamePattern(double &high[],double &low[],datetime &time[]);// Вычислить текущий паттерн
   string            GetNameLastPattern(void){
                       return(EnumToString(GetLastPattern()));};  // Получить без вычислений последний паттерн
   string            GetNamePrevPattern(void){
                       return(EnumToString(GetPrevPattern()));};  // Получить имя предыдущий паттерн
   string            GetNameEvolution(void);                      // Получить следующий паттерн(метод эволюции волны)
   string            GetNameMutation(void);                       // Получить следующий паттерн(метод мутации волны)
   double            GetSumModel(void);                           // Получить сумму модели(Отношение эволюций к общем. кол-ву)
   //--- Общие функции
   void              PrintComment(void);                          // Вывод на экран коммента
   double            GetPointEvolution(){return(pE);};            // Получить значение точки "эволюции level_0"
   double            GetPointMutation(){return(pM);};             // Получить значение точки "мутации  level_0"
   double            GetPointEvolutionLevel1(){return(pEv1);};    // Получить значение точки "эволюции level_1"
   double            GetPointMutationLevel1(){return(pM1);};      // Получить значение точки "мутации  level_1"
   datetime          GetTimeA(){return(tA);};                     // Получить время точки A
   datetime          GetTimeB(){return(tB);};                     // Получить время точки B
   datetime          GetTimeC(){return(tC);};                     // Получить время точки C
   datetime          GetTimeD(){return(tD);};                     // Получить время точки D
   datetime          GetTimeE(){return(tE);};                     // Получить время точки E
   datetime          GetTimeEvolution(){return(tEv);};            // Получить время точки "эволюции"
   datetime          GetTimeMutation(){return(tM);};              // Получить время точки "мутации"
   int               GetIndexA(){return(iA);};                    // Получить индекс точки A
   int               GetIndexB(){return(iB);};                    // Получить индекс точки B
   int               GetIndexC(){return(iC);};                    // Получить индекс точки C
   int               GetIndexD(){return(iD);};                    // Получить индекс точки D
   int               GetIndexE(){return(iE);};                    // Получить индекс точки E
   int               GetIndexEvolution(){return(iEv);};           // Получить индекс точки "эволюции"
   int               GetIndexMutation(){return(iM);};             // Получить индекс точки "мутации"
   //--- Прочие методы
   void              AddPointerCommet(MyCComment* pComment);      // добавляем указатель на "комментарий"
private:
   //--- Внутренние функции
   bool              SeachParams(double &high[],double &low[],datetime &time[]);// поиск параметров паттерн-системы
   void              CalcModelCount(void);                        // расчитать счетчик модели 
   void              CalcPrognozPoint(void);                      // расчитать прогноз. точки(эволюции/мутации)
   void              CalcPrognozLevel1(void);                     // расчитать прогноз. level_1
   double            CalcRegress(int nLast, double &a, int nA, double &b, int nB, 
                                 double c = 0.0, int nC = 0);     // Вычислить лин. регрессию
   void              MyCRegressia(double &fMassX[], double &fMassY[], double &fB0, double &fB1);
  };
//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
MyCPatternZigzag::MyCPatternZigzag()
  {
   //+---------------------------------------------------------------+
   //| "Золототая середина" - параметры по умолчанию                 |
   //+---------------------------------------------------------------+
   Depth      = 24;                                   // Окно поиска отклонений
   Deviation  = 12;                                   // Колебание цены в пунктах
   Backstep   = 9;                                    // Минимальный шаг
   SizeBuffers= 500;                                  // Размер буферов
   //+---------------------------------------------------------------+
   //| создаем класс экстремумов                                     |
   //+---------------------------------------------------------------+
   Extremum = new MyCExtremum;
   //--- обнуляем дату для проверки корректности значений
   tA = NULL;                                         // время точки A
   tB = NULL;                                         // время точки B
   tC = NULL;                                         // время точки C
   tD = NULL;                                         // время точки D
   tE = NULL;                                         // время точки E
   //---
   iA = 0;                                            // индекс точки А
   iB = 0;                                            // индекс точки B
   iC = 0;                                            // индекс точки C 
   iD = 0;                                            // индекс точки D 
   iE = 0;                                            // индекс точки E 
   //--- парметры для "комментов"
   MyComment = NULL;
   NumberLineComment = 2;
   //--- обнуляем счетчики
   countEvolution = 0;                                // счетчик эволюций
   countMutation  = 0;                                // счетчик мутаций
   countError     = 0;                                // счетчик "ошибок модели"
   //--- обнуляем точки прогноза
   pE  = 0.0;                                         //
   pM  = 0.0;                                         //
   pEv1= 0.0;                                         // прогноз: индекс точки "эволюции level_1"
   pM1 = 0.0;                                         // прогноз: индекс точки "мутации  level_1"
   iEv = 0;                                           //
   iM  = 0;                                           //
  }
//+------------------------------------------------------------------+
//| Деконструктор                                                    |
//+------------------------------------------------------------------+
MyCPatternZigzag::~MyCPatternZigzag()
  {
   //+---------------------------------------------------------------+
   //| удаляем класс экстремумов                                     |
   //+---------------------------------------------------------------+
   delete Extremum;
  }
//+------------------------------------------------------------------+
//| ПУБЛИЧНЫЕ МЕТОДЫ КЛАССА                                          |
//+------------------------------------------------------------------+
//| Возвращает кол-во строк "комментария"                            |
//+------------------------------------------------------------------+
int MyCPatternZigzag::GetCountLineComment(void)
  {
   if(MQL5InfoInteger(MQL5_TESTER))
     {
      return(5);
     }
   return(4);
  }
//+------------------------------------------------------------------+
//| Получение нового паттрена                                        |
//+------------------------------------------------------------------+
string MyCPatternZigzag::GetNamePattern(double &high[],double &low[],datetime &time[])
  {
   //--- 
   if(SeachParams(high,low,time))
     {
      //--- вычисляем & устанавливаем паттерн в коммент
      Get();                                          // текущий паттерн модели
      //--- если т. E "вычислительная" то корректируем индекс и время
      if(IsPointENotReal())
        {
         iE = SizeBuffers-1;
         tE = time[SizeBuffers-1];
        }
      //---
      CalcModelCount();                               // счетчик модели
      CalcPrognozPoint();                             // прогноз модели
      //--- возращаем имя паттерна пользователю
      return(EnumToString(GetLastPattern()));
     } 
   //--- все плохо...
   return("ERROR");   
  }
//+------------------------------------------------------------------+
//| Получить следующий паттерн(метод эволюции волны)                 |
//|Внимание: вызывать функцию после вызова Get()!                    |
//+------------------------------------------------------------------+
//|out: string - прогноз появления паттерна                          |
//+------------------------------------------------------------------+
string MyCPatternZigzag::GetNameEvolution(void)
  {
   //--- вызываем метод базового класса и переводим в строку
   return(EnumToString(this.GetNextEvolution()));
  }
//+------------------------------------------------------------------+
//| Получить слудующий паттерн(метод мутации волны)                  |
//|Внимание: вызывать функцию после вызова Get()!                    |
//+------------------------------------------------------------------+
//|out: string - прогноз появления паттерна                          |
//+------------------------------------------------------------------+
string MyCPatternZigzag::GetNameMutation(void)
  {
   //--- вызываем метод базового класса и переводим в строку
   return(EnumToString(this.GetNextMutation()));
  }
//+------------------------------------------------------------------+
//| ВНИМАНИЕ: ДАННЫЙ КЛАСС НЕ ВПРАВЕ СОЗДОВАТЬ ОБЪЕКТ-КОММЕНТАРИЙ!   |
//| Добавляем указатель на "комментарий"                             |
//+------------------------------------------------------------------+
void MyCPatternZigzag::AddPointerCommet(MyCComment* pComment)
  {
   if(pComment != NULL)
     {
      MyComment = pComment;
     }
  }
//+------------------------------------------------------------------+
//| Вывод на экран коммента                                          |
//+------------------------------------------------------------------+
void MyCPatternZigzag::PrintComment(void)
  {
      //--- если есть указаетль на коммент...
      if(MyComment != NULL)
        {
         MyComment.AddLineOfIndex(NumberLineComment,  "Now is pattern: "+EnumToString(GetLastPattern()));
         MyComment.AddLineOfIndex(NumberLineComment+1,"Next pattern(Evolution): "+GetNameEvolution()+
                                  ", price = "+DoubleToString(GetPointEvolution(),_Digits));
         MyComment.AddLineOfIndex(NumberLineComment+2,"Next pattern(Mutation ): "+GetNameMutation()+
                                  ", price = "+DoubleToString(GetPointMutation(),_Digits));
         if(countEvolution + countMutation + countError < 10)
           {
            MyComment.AddLineOfIndex(NumberLineComment+3,"No counter calculation.");
           }else
              {
               int    nSumModel = countEvolution+countMutation+countError;
               string sout  = "Evolution: " + DoubleToString(100*countEvolution/nSumModel,2)+
                              "% Mutation: "+ DoubleToString(100*countMutation/nSumModel,2)+
                              "% Error: "   + DoubleToString(100*countError/nSumModel,2)+"%"; 
               MyComment.AddLineOfIndex(NumberLineComment+3,sout);
              }
         //+---------------------------------------------------------+
         //| Для DEBUG_MODE: проверка работы счетчика.               |
         //+---------------------------------------------------------+
         if(MQL5InfoInteger(MQL5_TESTER))
           {
            string sout  = "DEBUG_MODE: countEvolution= " + IntegerToString(countEvolution)+
                           "; countMutation= "+ IntegerToString(countMutation)+
                           "; countError= "   + IntegerToString(countError)+
                           "; oldPattern= "   + EnumToString(oldPattern); 
            MyComment.AddLineOfIndex(NumberLineComment+4,sout);
           }
        }
  }
//+------------------------------------------------------------------+
//| Получить сумму модели (отношение эволюций к общем. кол-ву)       |
//| ret = кол-во_эвол/(кол-во_эвол+кол-во_мут)                       |
//+------------------------------------------------------------------+
double MyCPatternZigzag::GetSumModel(void)
  {
   double ret = (double)(countEvolution + countMutation);
   if(ret != 0)
     {
      ret = countEvolution/ret;
      return(ret);
     }
   //--- возврат нуля без деления
   return(0);
  }
//+------------------------------------------------------------------+
//| ЗАЩИЩЕННЫЕ МЕТОДЫ КЛАССА                                         |
//+------------------------------------------------------------------+
//| Поиск параметров паттерной системы: A, B, C, D, E                |
//| С Анти-флэтовой защитой.                                         |
//+------------------------------------------------------------------+
bool MyCPatternZigzag::SeachParams(double &high[], double &low[], datetime &time[])
  {
   //--- переменные для расчетов
   int ret =-1, ind=0, indD = 0;
   //--- ПРОВЕРКА ВХОДНЫХ БУФЕРОВ
   if(ArrayRange(high,0) < SizeBuffers) return false;
   if(ArrayRange(low,0)  < SizeBuffers) return false;
   if(ArrayRange(time,0) < SizeBuffers) return false;   
   //--- а теперь получили Zigzag
   ret = Extremum.GetClassicZigzag(high, low, Depth, Deviation, Backstep);
   //+---------------------------------------------------------------+
   //| циклы выборки A, B, C, D, E                                   |
   //+---------------------------------------------------------------+
   if(ret>0)
     {
      for(ind=ret-1;ind>0;ind--)
        {
         //--- Возможно ищем D, но это может быть E!
         double mD  = Extremum.ZigzagBuffer[ind];
         if(mD!=0) 
           {
            tD = time[ind];
            SetD(mD);
            indD = ind;                               // запомнили индекс точки D!
            iD   = ind;
            break;
           }
        }
      //+------------------------------------------------------------+
      //| Простая проверка на "вшивость" данных: если ближе Backstep,|
      //| то это не D а E! И поэтому возобновляем поиск D.           |
      //+------------------------------------------------------------+
      if(ind > ret-Backstep)
        {
         tE = tD;
         iE = iD;
         SetE(GetD());
         indD = -1;                                   // признак обнаруженной E!
         for(ind=ind-1;ind>0;ind--)
           {
            //--- Ну теперь уж точно ищем D!
            double mD  = Extremum.ZigzagBuffer[ind];
            if(mD!=0) 
              {
               tD = time[ind];
               SetD(mD);
               iD = ind;
               break;
              }
           }
        }      
      //--- продолжаем поиск оставшихся точек
      for(ind=ind-1;ind>0;ind--)
        {
         //--- Ищем C
         double mC = Extremum.ZigzagBuffer[ind]; 
         if(mC!=0)
           {
            SetC(mC);
            tC = time[ind];
            iC = ind;
            break;
           }
        }
      for(ind=ind-1;ind>0;ind--)
        {
         //--- Ищем B
         double mB = Extremum.ZigzagBuffer[ind];
         if(mB!=0)
           {
            SetB(mB);
            tB = time[ind];
            iB = ind;
            break;
           }
        }
      for(ind=ind-1;ind>0;ind--)
        {
         //--- Ищем A
         double mA = Extremum.ZigzagBuffer[ind];
         if(mA!=0)
           {
            SetA(mA);
            tA = time[ind];
            iA = ind;
            break;
           }
        }
     }else
        {
         //--- нет данных для анализа
         return(false);
        }
   //--- проверка: нужно ли искать E
   if(indD < 0) return(true);
   //--- получаем Е
   if(GetC() > GetD())
     {
      //--- ищем максимумы
      ind = ArrayMaximum(high,indD+1,SizeBuffers-indD-1);
      //---
      if(ind > 0)
        {
         SetE(high[ind]);
         tE = time[ind];
         iE = ind;
        }else
           {
            SetE(high[SizeBuffers-2]);
            tE = time[SizeBuffers-2];
            iE = SizeBuffers-2;
           }
     }else
        {
         //--- ищем минимумы
         ind = ArrayMinimum(low,indD+1,SizeBuffers-indD-1);
         //---
         if(ind > 0)
           {
            SetE(low[ind]);
            tE = time[ind];
            iE = ind;
           }else
             {
              SetE(low[SizeBuffers-2]);
              tE = time[SizeBuffers-2];
              iE = SizeBuffers-2;
             }
        }
   //+------------------------------------------------------------+
   //|                    АНТИ-ФЛЭТ                               |
   //+------------------------------------------------------------+
   double deltaED = MathAbs(GetE()-GetD());        // разница по модулю
   int       dnED = (int)(deltaED/_Point);         // кол-во пунктов
   //--- Если разница между E & D меньше Deviation, то E найдено не верно(попали во "флэт")
   if(dnED < Deviation)
     {//--- мы нашли не правильно E & D! Мы попали во "флэт"
      //--- Новая точка E:
      SetE(GetD());
      tE = tD;
      iE = iD;
      //--- Новая точка D:
      SetD(GetC());
      tD = tC;
      iD = iC;
      //--- Новая точка C:
      SetC(GetB());
      tC = tB;
      iC = iB;
      //--- Новая точка B:
      SetB(GetA());
      tB = tA;
      iB = iA;
      //--- Вычисляем точку A:
      ind= iB;
      for(ind=ind-1;ind>0;ind--)
        {
         //--- Ищем A
         double mA = Extremum.ZigzagBuffer[ind];
         if(mA!=0)
           {
            SetA(mA);
            tA = time[ind];
            iA = ind;
            break;
           }
        }      
     }
   //---
   return(true);
  }
//+------------------------------------------------------------------+
//| Функция подсчитывает кол-во: эволюций, мутаций, ошибок модели.   |
//| Меняет значения в переменных:                                    |
//| countEvolution, countMutation, countError                        |
//+------------------------------------------------------------------+
void MyCPatternZigzag::CalcModelCount(void)
  {
   //--- Это начало расчетов? Да - выход....
   if((countEvolution == 0)&&(countMutation == 0)&&(countError == 0)&&(oldPattern == NOPATTERN)) return;
   //--- Не было смены паттерна - выход...
   if(oldPattern == pattern) return;
   //--- Явная ошибка!
   if(pattern == NOPATTERN)
     {
      countError++;                                // счетчик "ошибок модели"
      return;
     }
   //--- А это не ошибка! Иначе будет "двойной учет ошибок"
   if(oldPattern == NOPATTERN) return;
   //--- Была эволюция?
   if(IsRightEvolution() == 1)
     {
      countEvolution++;                         // счетчик эволюций
      return;
     }
   //--- Была мутация?
   if(IsRightMutation() == 1)
     {
      countMutation++;                          // счетчик мутаций
      return;
     }
   //--- Значит "ошибка модели"
   countError++;                                // счетчик "ошибок модели"
   return;
  }
//+------------------------------------------------------------------+
//| Функция вычисляет линейную регрессию:                            |
//| y = b*bar+a;                                                     |
//+------------+-----------------------------------------------------+
//| ПЕРЕМЕННАЯ | НАЗНАЧЕНИЕ                                          |
//+------------+-----------------------------------------------------+
//| OUT        | ТЕКУЩЕЕ ЗНАЧЕНИЕ(РАСЧИТАННОЕ) ФУНКЦИИ (DOUBLE)      |
//| nLast      | НОМЕР ПОСЛЕДНЕГО БАРА (INT)                         |
//| a          | ПЕРВОЕ ЧИСЛЕННОЕ ЗНАЧЕНИЕ (DOUBLE), расчетный a     |
//| nA         | НОМЕР БАРА ПЕРВОГО ЧИСЛЕННОГО ЗНАЧЕНИЯ (INT)        |
//| b          | ВТОРОЕ ЧИСЛЕННОЕ ЗНАЧЕНИЕ (DOUBLE), расчетный b     |
//| nB         | НОМЕР БАРА ВТОРОГО ЧИСЛЕННОГО ЗНАЧЕНИЯ (INT)        |
//| c          | ТРЕТЬЕ ЧИСЛЕННОЕ ЗНАЧЕНИЕ (DOUBLE)                  |
//| nC         | НОМЕР БАРА ТРЕТЬЕГО ЧИСЛЕННОГО ЗНАЧЕНИЯ (INT)       |
//+------------+-----------------------------------------------------+
double MyCPatternZigzag::CalcRegress(int nLast, double &a,      int nA,    double &b, 
                                     int nB,    double c = 0.0, int nC = 0)
  {
   //--- переменные
   double dA              = 0;                        // коэффиценты функции линии
   double dB              = 0;                        // коэффиценты функции линии
   double ret             = -1;                       // вычисленное значение
   double ArDataX[];                                  // класс матрицы входов
   double ArDataY[];                                  // класс матрицы входов
   //--- 1. Создание векторов
   if(nC>0)
     {
      ArrayResize(ArDataX,3);
      ArrayResize(ArDataY,3);
     }else
        {
         ArrayResize(ArDataX,2);
         ArrayResize(ArDataY,2);
        }
   //--- 
   ArDataX[0] = nA;                                   // input 1
   ArDataY[0] = a;                                
   ArDataX[1] = nB;                                   // input 2
   ArDataY[1] = b;
   if(nC > 0)
     {
      ArDataX[2] = nC;                                // input 3
      ArDataY[2] = c;                                    
     }  
   //--- 3. Расчет регрессионных параметров функции
   MyCRegressia(ArDataX, ArDataY, dA, dB);
   //--- 4. Расчет регрессионного значения от функции
   ret = dB*nLast+dA;
   a   = dA;
   b   = dB; 
   //--- 5. выход
   return(ret);
  }
//+------------------------------------------------------------------+
//| ФУНКЦИЯ: РЕГРЕССИЯ линейная                                      |
//| y(x) = b1*x+b0                                                   |
//|fMass        -       МАССИВ ЗНАЧЕНИЙ                              |
//|nMassSize    -       РАЗМЕР МАССИВА ЗНАЧЕНИЙ                      |
//|fB0          -       указатель на коэффицент b0                   |
//|fB1          -       указатель на коэффицент b1                   |
//+------------------------------------------------------------------+
void MyCPatternZigzag::MyCRegressia(double &fMassX[], double &fMassY[], double &fB0, double &fB1)
  {
   //---
   int i;
   double a=0, b=0, c=0, d=0;
   //---
   for(i = 0; i<ArrayRange(fMassX,0); i++)
     {
      a += fMassX[i];
      b += fMassY[i];
      c += MathPow(fMassX[i], 2);
      d += fMassX[i]*fMassY[i];
     }
   fB1 = (a*b-i*d)/(MathPow(a, 2)-i*c);
   fB0 = (b-fB1*a)/i;
  }
//+------------------------------------------------------------------+
//| Функция расчета прогноз. точек(эволюции/мутации)                 |
//| in : нет (главное наличие текущего паттерна)                     |
//| out: нет (меняет double pE, double pM, int iE, int iM)           |
//+------------------------------------------------------------------+
//| Таблица "Идеальных пропорций" ("Золотое сечение" версия 1):      |
//|   №    (D-E)/(D-C)   "ЗС версия1" №  (E-D)/(C-D)   "ЗС версия1"  |
//|   M1    2             1.618       W1  0.3334        0.3819       |
//|   M2    0.5           0.5         W2  0.6667        0.618        |
//|   M3    1.5           1.2720      W3  1.5           1.2720       |
//|   M4    0.6667	     0.618       W4  0.5           0.5          |
//|   M5    1.3334        1.2720      W5  2             1.618        |
//|   M6    0.75          0.618       W6  0.25          0.25         |
//|   M7    3             3.0000      W7  0.5           0.5          |
//|   M8    0.3334        0.3819      W8  2             1.618        |
//|   M9    2             1.618       W9  0.3334        0.3819       |
//|   M10   0.5           0.5         W10 3             3.0000       |
//|   M11   0.25          0.25        W11 0.75          0.618        |
//|   M12   2             1.618       W12 1.3334        1.2720       |
//|   M13   0.5           0.5         W13 0.6667        0.618        |
//|   M14   1.5           1.2720      W14 1.5           1.2720       |
//|   M15   0.6667        0.618       W15 0.5           0.5          |
//|   M16   0.3334        0.3819      W16 2             1.618        |
//+------------------------------------------------------------------+
void MyCPatternZigzag::CalcPrognozPoint(void)
  {
   //--- ПРОВЕРКА НАЛИЧИЯ ТЕКУЩЕГО ПАТТЕРНА
   if(pattern == NOPATTERN)
     {
      pE = 0.0; pM = 0.0; iEv = 0; iM = 0;            // НЕТ ПРОГНОЗА
      CalcPrognozLevel1();
      return;                                         // НЕТ ПАТТЕРНА - ВЫХОД
     } 
   //+---------------------------------------------------------------+
   //|   ПРИБЛИЗИТЕЛЬНОЕ ЗНАЧЕНИЕ ИНДЕКСА ДЛЯ ПРОГНОЗ.ВОЛНЫ          |
   //+---------------------------------------------------------------+
   int iTemp = 0;
   if(((iE - iA)/5 < 3)&&((iE - iA)/5 > Backstep*2))
     {
      iTemp  = iE + (iE - iA)/5;
     }else
        {
         iTemp  = iE + Backstep*2;
        }
   //--- Вычисляем дату прогноза:
   tEv = (iTemp-iE)*PeriodSeconds()+GetTimeE();
   tM  = (iTemp-iE)*PeriodSeconds()+GetTimeE();
   double rA = 0, rB = 0;
   //+---------------------------------------------------------------+
   //| РАСЧЕТ ТОЧЕК ПРОГНОЗА                                         |
   //+---------------------------------------------------------------+
   switch(pattern)
     {
      case  M1:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M1 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> нет= 0                                  |
      //| Точка "мутации" => W1 = 0.3819 * (D - E) + E               |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0.0; iEv = 0;
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M2:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M2 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M1 = D - 1.618 * (D - C)                |
      //| Точка "мутации" => W4 = 0.5 * (D - E) + E                  |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 1.618 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M3:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M3 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> нет= 0                                  |
      //| Точка "мутации" => W1 = 0.3819 * (D - E) + E               |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0.0; iEv = 0;
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M4:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M4 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M3 = D - 1.272 * (D - C)                |
      //| Точка "мутации" => W4 = 0.5 * (D - E) + E                  |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 1.272 * (D - C),_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M5:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M5 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> нет = 0                                 |
      //| Точка "мутации" => W6  = 0.25 * (D - E) + E                |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0.0; iEv = 0;
        //---
        pM = NormalizeDouble(0.25 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M6:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M6 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M5 = D - 1.272 * (D - C)                |
      //| Точка "мутации" => W9 = 0.3819 * (D - E) + E               |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 1.272 * (D - C),_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M7:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M7 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> нет = 0                                 |
      //| Точка "мутации" => W1  = 0.3819 * (D - E) + E              |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0.0; iEv = 0;
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M8:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M8 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M4 = D - 0.618 * (D - C)                |
      //| Точка "мутации" => W4 = 0.5 * (D - E) + E                  |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 0.618 * (D - C),_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M9:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M9 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> нет = 0                                 |
      //| Точка "мутации" => W6  = 0.25 * (D - E) + E                |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0.0; iEv = 0;
        //---
        pM = NormalizeDouble(0.25 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M10:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M10 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M6 = D - 0.618 * (D - C)                |
      //| Точка "мутации" => W9 = 0.3819 * (D - E) + E               |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 0.618 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M11:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M11 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M10 = D - 0.5 * (D - C)                 |
      //| Точка "мутации" => W15 = 0.5 * (D - E) + E                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 0.5 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M12:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M12 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M7 = D - 3.0000 * (D - C)               |
      //| Точка "мутации" => W1 = 0.3819 * (D - E) + E               |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 3.0000 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.3819 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M13:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M13 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M12 = D - 1.618 * (D - C)               |
      //| Точка "мутации" => W4  = 0.5 * (D - E) + E                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 1.618 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M14:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M14 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M9 = D - 1.618 * (D - C)                |
      //| Точка "мутации" => W6 = 0.25 * (D - E) + E                 |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(D - 1.618 * (D - C),_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(0.25 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M15:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M15 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M14 = D - 1.272 * (D - C)               |
      //| Точка "мутации" => W9  = 0.3819 * (D - E) + E              |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(C-(C-A)/1.618,_Digits);
        iEv= iTemp;
        //---
        pM = NormalizeDouble(E+(B-E)/1.618,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  M16:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M16 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> M15 = D - 0.618 * (D - C)               |
      //| Точка "мутации" => W15 = 0.5 * (D - E) + E                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(D - 0.618 * (D - C),_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(0.5 * (D - E) + E,_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W1:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W1 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W2  = 0.618 * (C - D) + D               |
      //| Точка "мутации" => M2  = E - 0.5 * (E - D)                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(0.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W2:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W2 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W3  = 1.272 * (C - D) + D               |
      //| Точка "мутации" => M8  = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(1.272 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W3:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W3 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W8  = 1.618 * (C - D) + D               |
      //| Точка "мутации" => M11 = E - 0.25 * (E - D)                |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(1.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.25 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W4:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W4 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W5  = 1.618 * (C - D) + D               |
      //| Точка "мутации" => M13 = E - 0.5 * (E - D)                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(1.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W5:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W5 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W10 = 3.0000 * (C - D) + D              |
      //| Точка "мутации" => M16 = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(3.0000 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W6:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W6 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W7 = 0.5 * (C - D) + D                  |
      //| Точка "мутации" => M2 = E - 0.5 * (E - D)                  |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(0.5 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W7:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W7 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W11 = 0.618 * (C - D) + D               |
      //| Точка "мутации" => M8  = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(0.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W8:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W8 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => M11 = E - 0.25 * (E - D)                |
      //+------------------------------------------------------------+
        pE = 0; iEv= 0;        
        //---
        pM = NormalizeDouble(E - 0.25 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W9:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W9 +++                                            |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W13 = 0.618 * (C - D) + D               |
      //| Точка "мутации" => M13 = E - 0.5 * (E - D)                 |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(0.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W10:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W10 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => M16 = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        pE = 0; iEv= 0;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;        
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W11:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W11 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W12 = 1.272 * (C - D) + D               |
      //| Точка "мутации" => M8  = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        pE = NormalizeDouble(1.272 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W12:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W12 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => M11 = E - 0.25 * (E - D)                |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0; iEv= 0;        
        //---
        pM = NormalizeDouble(E - 0.25 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W13:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W13 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W14 = 1.272 * (C - D) + D               |
      //| Точка "мутации" => M13 = E - 0.5 * (E - D)                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(1.272 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W14:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W14 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => M16 = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0; iEv= 0;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W15:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W15 +++                                           |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> W16 = 1.618 * (C - D) + D               |
      //| Точка "мутации" => M13 = E - 0.5 * (E - D)                 |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = NormalizeDouble(1.618 * (C - D) + D,_Digits);
        iEv= iTemp;        
        //---
        pM = NormalizeDouble(E - 0.5 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      case  W16:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W16 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => M16 = E - 0.3819 * (E - D)              |
      //+------------------------------------------------------------+
        //--- level_0:
        pE = 0; iEv= 0;        
        //---
        pM = NormalizeDouble(E - 0.3819 * (E - D),_Digits);
        iM = iTemp;
        //--- level_1:
        CalcPrognozLevel1();
        break;
      default:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: ERROR                                             |
      //| Точка "эволюции"=> НЕТ = 0                                 |
      //| Точка "мутации" => НЕТ = 0                                 |
      //+------------------------------------------------------------+
        pE = 0.0; pM = 0.0; iEv = 0; iM = 0; 
        //--- level_1:
        CalcPrognozLevel1();
        break;
     }
  }
//+------------------------------------------------------------------+
//| Расчитать прогноз. level_1                                       |
//+------------------------------------------------------------------+
void MyCPatternZigzag::CalcPrognozLevel1(void)
  {
   double rA = 0.0, rB = 0.0;
   //---
   switch(pattern)
     {
      case  M1:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M1 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = нет точки                               |
      //| Точка "мутации"  = E+(B-D)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = 0.0;
        //---
        pM1  = NormalizeDouble(E+(B-D)*1.618,_Digits);
        break;
      case  M3:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M3 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = нет точки                               |
      //| Точка "мутации"  = E+(B-D)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = 0;
        //---
        pM1  = NormalizeDouble(E+(B-D)*1.618,_Digits);
        break;
      case  M5:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M5 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = нет                                     |
      //| Точка "мутации"  = regress(B, D)                           |
      //+------------------------------------------------------------+
        pEv1 = 0;
        //---
        rA   = B; rB = D;
        pM1  = NormalizeDouble(CalcRegress(iM, rA, iB, rB, iD),_Digits);
        break;
      case  M13:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M13 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = E-(B-A)*0.618                           |
      //| Точка "мутации"  = E+(B-A)*0.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(E-(B-A)*0.618,_Digits);
        //---
        pM1  = NormalizeDouble(E+(B-A)*0.618,_Digits);
        break;
      case  M15:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M15 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = E-(D-E)*1.618                           |
      //| Точка "мутации"  = E+(D-E)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(E-(D-E)*1.618,_Digits);
        //---
        pM1  = NormalizeDouble(E+(D-E)*1.618,_Digits);
        break;
      case  M16:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: M16 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = A-(B-A)*0.618                           |
      //| Точка "мутации"  = E+(D-E)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(A-(B-A)*0.618,_Digits);
        //---
        pM1  = NormalizeDouble(E+(D-E)*1.618,_Digits);
        break;
      case  W1:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W1 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = E+(A-B)*1.618                           |
      //| Точка "мутации"  = E-(C-D)*0.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(E+(A-B)*1.618,_Digits);
        //---
        pM1  = NormalizeDouble(E-(C-D)*0.618,_Digits);
        break;
      case  W2:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W2 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = E+(E-D)*1.618                           |
      //| Точка "мутации"  = E-(E-D)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(E+(E-D)*1.618,_Digits);
        //---
        pM1  = NormalizeDouble(E-(E-D)*1.618,_Digits);
        break;
      case  W4:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W4 +                                              |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = E+(B-A)*0.618                           |
      //| Точка "мутации"  = E-(B-A)*0.618                           |
      //+------------------------------------------------------------+
        pEv1 = NormalizeDouble(E+(B-A)*0.618,_Digits);
        //---
        pM1  = NormalizeDouble(E-(B-A)*0.618,_Digits);
        break;
      case  W12:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W12 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = НЕТ                                     |
      //| Точка "мутации"  = regress(B, D)                           |
      //+------------------------------------------------------------+
        pEv1 = 0;        
        //---
        rA   = B; rB = D;
        pM1  = NormalizeDouble(CalcRegress(iM, rA, iB, rB, iD),_Digits);
        break;
      case  W14:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W14 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = НЕТ                                     |
      //| Точка "мутации"  = E-(C-B)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = 0;        
        //---
        pM1  = NormalizeDouble(E-(C-B)*1.618,_Digits);
        break;
      case  W16:
      //+------------------------------------------------------------+
      //| ПАТТЕРН: W16 +                                             |
      //| Вычисление точек прогноза:                                 |
      //| Точка "эволюции" = НЕТ                                     |
      //| Точка "мутации"  = E-(C-B)*1.618                           |
      //+------------------------------------------------------------+
        pEv1 = 0;        
        //---
        pM1  = NormalizeDouble(E-(C-B)*1.618,_Digits);
        break;
      default:
        //--- нет расчета...
        pEv1 = 0.0;                                   // прогноз: индекс точки "эволюции level_1"
        pM1  = 0.0;                                   // прогноз: индекс точки "мутации  level_1"
        break;
     }
  }
//+------------------------------------------------------------------+