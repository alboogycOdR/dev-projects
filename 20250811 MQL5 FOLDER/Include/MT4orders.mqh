
#ifdef __MQL5__
#ifndef __MT4ORDERS__

// #define MT4ORDERS_BYPASS_MAXTIME 1000000 // Максимальное время (в мкс.) на ожидание синхронизации торгового окружения

#ifdef MT4ORDERS_BYPASS_MAXTIME
  #include <fxsaber\TradesID\ByPass.mqh> // https://www.mql5.com/ru/code/34173
#endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

// #define MT4ORDERS_BENCHMARK_MINTIME 1000 // Минимальное время срабатывания Алерта-производительности.

#ifdef MT4ORDERS_BENCHMARK_MINTIME
  #include <fxsaber\Benchmark\Benchmark.mqh> // https://www.mql5.com/ru/code/31279

  #define _B2(A) _B(A, MT4ORDERS_BENCHMARK_MINTIME)
  #define _B3(A) _B(A, 1)
  #define _BV2(A) _BV(A, MT4ORDERS_BENCHMARK_MINTIME)
#else // MT4ORDERS_BENCHMARK_MINTIME
  #define _B2(A) (A)
  #define _B3(A) (A)
  #define _BV2(A) { A; }
#endif // MT4ORDERS_BENCHMARK_MINTIME

#define __MT4ORDERS__ "2022.07.20"
// #define MT4ORDERS_TESTER_SELECT_BY_TICKET // Принуждает SELECT_BY_TICKET работать в Тестере только через OrderTicketID().

#ifdef MT4_TICKET_TYPE
  #define TICKET_TYPE int
  #define MAGIC_TYPE  int

  #undef MT4_TICKET_TYPE
#else // MT4_TICKET_TYPE
  #define TICKET_TYPE long // Нужны и отрицательные значения для OrderSelectByTicket.
  #define MAGIC_TYPE  long
#endif // MT4_TICKET_TYPE

struct MT4_ORDER
{
  long Ticket;
  int Type;

  long TicketOpen;
  long TicketID;

  double Lots;

  string Symbol;
  string Comment;

  double OpenPriceRequest;
  double OpenPrice;

  long OpenTimeMsc;
  datetime OpenTime;

  ENUM_DEAL_REASON OpenReason;

  double StopLoss;
  double TakeProfit;

  double ClosePriceRequest;
  double ClosePrice;

  long CloseTimeMsc;
  datetime CloseTime;

  ENUM_DEAL_REASON CloseReason;

  ENUM_ORDER_STATE State;

  datetime Expiration;

  long MagicNumber;

  double Profit;

  double Commission;
  double Swap;

  int DealsAmount;

  double LotsOpen;

#define POSITION_SELECT (-1)
#define ORDER_SELECT (-2)

  static int GetDigits( double Price )
  {
    int Res = 0;

    while ((bool)(Price = ::NormalizeDouble(Price - (int)Price, 8)))
    {
      Price *= 10;

      Res++;
    }

    return(Res);
  }

  static string DoubleToString( const double Num, const int digits )
  {
    return(::DoubleToString(Num, ::MathMax(digits, MT4_ORDER::GetDigits(Num))));
  }

  static string TimeToString( const long time )
  {
    return((string)(datetime)(time / 1000) + "." + ::IntegerToString(time % 1000, 3, '0'));
  }

  static const MT4_ORDER GetPositionData( void )
  {
    MT4_ORDER Res = {}; // Обнуление полей.

    Res.Ticket = ::PositionGetInteger(POSITION_TICKET);
    Res.Type = (int)::PositionGetInteger(POSITION_TYPE);

    Res.Lots = ::PositionGetDouble(POSITION_VOLUME);

    Res.Symbol = ::PositionGetString(POSITION_SYMBOL);
//    Res.Comment = NULL; // MT4ORDERS::CheckPositionCommissionComment();

    Res.OpenPrice = ::PositionGetDouble(POSITION_PRICE_OPEN);
    Res.OpenTimeMsc = (datetime)::PositionGetInteger(POSITION_TIME_MSC);

    Res.StopLoss = ::PositionGetDouble(POSITION_SL);
    Res.TakeProfit = ::PositionGetDouble(POSITION_TP);

    Res.ClosePrice = ::PositionGetDouble(POSITION_PRICE_CURRENT);

    Res.MagicNumber = ::PositionGetInteger(POSITION_MAGIC);

    Res.Profit = ::PositionGetDouble(POSITION_PROFIT);

    Res.Swap = ::PositionGetDouble(POSITION_SWAP);

//    Res.Commission = UNKNOWN_COMMISSION; // MT4ORDERS::CheckPositionCommissionComment();

    return(Res);
  }

  static const MT4_ORDER GetOrderData( void )
  {
    MT4_ORDER Res = {}; // Обнуление полей.

    Res.Ticket = ::OrderGetInteger(ORDER_TICKET);
    Res.Type = (int)::OrderGetInteger(ORDER_TYPE);

    Res.Lots = ::OrderGetDouble(ORDER_VOLUME_CURRENT);

    Res.Symbol = ::OrderGetString(ORDER_SYMBOL);
    Res.Comment = ::OrderGetString(ORDER_COMMENT);

    Res.OpenPrice = ::OrderGetDouble(ORDER_PRICE_OPEN);
    Res.OpenTimeMsc = (datetime)::OrderGetInteger(ORDER_TIME_SETUP_MSC);

    Res.StopLoss = ::OrderGetDouble(ORDER_SL);
    Res.TakeProfit = ::OrderGetDouble(ORDER_TP);

    Res.ClosePrice = ::OrderGetDouble(ORDER_PRICE_CURRENT);

    Res.Expiration = (datetime)::OrderGetInteger(ORDER_TIME_EXPIRATION);

    Res.MagicNumber = ::OrderGetInteger(ORDER_MAGIC);

    if (!Res.OpenPrice)
      Res.OpenPrice = Res.ClosePrice;

    return(Res);
  }

  static string GetAddType( const int Type, const bool FlagOrder )
  {
    ::ResetLastError();

    string Str = FlagOrder ? ::EnumToString((ENUM_ORDER_TYPE)Type) : ::EnumToString((ENUM_DEAL_TYPE)Type);

    if (!::_LastError && ::StringToLower(Str))
    {
      Str = FlagOrder ? ::StringSubstr(Str, 11) // "order_type_"
                      : (!::StringFind(Str, "deal_type_") ? ::StringSubstr(Str, 10) // "deal_type_"
                                                          : (!::StringFind(Str, "deal_") ? ::StringSubstr(Str, 5) // "deal_"
                                                                                         : Str));

      ::StringReplace(Str, "_", " ");
    }
    else
      Str = "unknown(" + (string)Type + ")";

    return(Str);
  }

  string ToString( void ) const
  {
    static const string Types[] = {"buy", "sell", "buy limit", "sell limit", "buy stop", "sell stop", "balance"};
    const int digits = (int)::SymbolInfoInteger(this.Symbol, SYMBOL_DIGITS);

    MT4_ORDER TmpOrder = {};

    if (this.Ticket == POSITION_SELECT)
    {
      TmpOrder = MT4_ORDER::GetPositionData();

      TmpOrder.Comment = this.Comment;
      TmpOrder.Commission = this.Commission;
    }
    else if (this.Ticket == ORDER_SELECT)
      TmpOrder = MT4_ORDER::GetOrderData();

    return(((this.Ticket == POSITION_SELECT) || (this.Ticket == ORDER_SELECT)) ? TmpOrder.ToString() :
           ("#" + (string)this.Ticket + " " +
            MT4_ORDER::TimeToString(this.OpenTimeMsc) + " " +
            (((this.Type < ::ArraySize(Types)) &&
              ((this.Type <= ORDER_TYPE_SELL_STOP) || !this.OpenPrice)) ? Types[this.Type] : MT4_ORDER::GetAddType(this.Type, this.OpenPrice)) + " " +
            MT4_ORDER::DoubleToString(this.Lots, 2) + " " +
            (::StringLen(this.Symbol) ? this.Symbol + " " : NULL) +
            MT4_ORDER::DoubleToString(this.OpenPrice, digits) + " " +
            MT4_ORDER::DoubleToString(this.StopLoss, digits) + " " +
            MT4_ORDER::DoubleToString(this.TakeProfit, digits) + " " +
            ((this.CloseTimeMsc > 0) ? (MT4_ORDER::TimeToString(this.CloseTimeMsc) + " ") : "") +
            MT4_ORDER::DoubleToString(this.ClosePrice, digits) + " " +
            MT4_ORDER::DoubleToString(::NormalizeDouble(this.Commission, 3), 2) + " " + // Больше трех цифр после запятой не выводим.
            MT4_ORDER::DoubleToString(this.Swap, 2) + " " +
            MT4_ORDER::DoubleToString(this.Profit, 2) + " " +
            ((this.Comment == "") ? "" : (this.Comment + " ")) +
            (string)this.MagicNumber +
            (((this.Expiration > 0) ? (" expiration " + (string)this.Expiration): ""))));
  }
};

#define RESERVE_SIZE 1000
#define DAY (24 * 3600)
#define HISTORY_PAUSE (MT4HISTORY::IsTester ? 0 : 5)
#define END_TIME D'31.12.3000 23:59:59'
#define THOUSAND 1000
#define LASTTIME(A)                                          \
  if (Time##A >= LastTimeMsc)                                \
  {                                                          \
    const datetime TmpTime = (datetime)(Time##A / THOUSAND); \
                                                             \
    if (TmpTime > this.LastTime)                             \
    {                                                        \
      this.LastTotalOrders = 0;                              \
      this.LastTotalDeals = 0;                               \
                                                             \
      this.LastTime = TmpTime;                               \
      LastTimeMsc = this.LastTime * THOUSAND;                \
    }                                                        \
                                                             \
    this.LastTotal##A##s++;                                  \
  }

#ifndef MT4ORDERS_FASTHISTORY_OFF
  #include <Generic\HashMap.mqh>
#endif // MT4ORDERS_FASTHISTORY_OFF

class MT4HISTORY
{
private:
  static const bool MT4HISTORY::IsTester;
//  static long MT4HISTORY::AccountNumber;

#ifndef MT4ORDERS_FASTHISTORY_OFF
  CHashMap<ulong, ulong> DealsIn;  // По PositionID возвращает DealIn.
  CHashMap<ulong, ulong> DealsOut; // По PositionID возвращает DealOut.
#endif // MT4ORDERS_FASTHISTORY_OFF

  long Tickets[];
  uint Amount;

  int LastTotalDeals;
  int LastTotalOrders;

  bool TicketValid;
  double TicketCommission;
  double TicketPrice;
  double TicketLots;
  int TicketDeals;

#ifdef MT4ORDERS_HISTORY_OLD

  datetime LastTime;
  datetime LastInitTime;

  int PrevDealsTotal;
  int PrevOrdersTotal;

  // https://www.mql5.com/ru/forum/93352/page50#comment_18040243
  bool IsChangeHistory( void )
  {
    bool Res = !_B2(::HistorySelect(0, INT_MAX));

    if (!Res)
    {
      const int iDealsTotal = ::HistoryDealsTotal();
      const int iOrdersTotal = ::HistoryOrdersTotal();

      if (Res = (iDealsTotal != this.PrevDealsTotal) || (iOrdersTotal != this.PrevOrdersTotal))
      {
        this.PrevDealsTotal = iDealsTotal;
        this.PrevOrdersTotal = iOrdersTotal;
      }
    }

    return(Res);
  }

  bool RefreshHistory( void )
  {
    bool Res = !MT4HISTORY::IsChangeHistory();

    if (!Res)
    {
      const datetime LastTimeCurrent = ::TimeCurrent();

      if (!MT4HISTORY::IsTester && ((LastTimeCurrent >= this.LastInitTime + DAY)/* || (MT4HISTORY::AccountNumber != ::AccountInfoInteger(ACCOUNT_LOGIN))*/))
      {
      //  MT4HISTORY::AccountNumber = ::AccountInfoInteger(ACCOUNT_LOGIN);

        this.LastTime = 0;

        this.LastTotalOrders = 0;
        this.LastTotalDeals = 0;

        this.Amount = 0;

        ::ArrayResize(this.Tickets, this.Amount, RESERVE_SIZE);

        this.LastInitTime = LastTimeCurrent;

      #ifndef MT4ORDERS_FASTHISTORY_OFF
        this.DealsIn.Clear();
        this.DealsOut.Clear();
      #endif // MT4ORDERS_FASTHISTORY_OFF
      }

      const datetime LastTimeCurrentLeft = LastTimeCurrent - HISTORY_PAUSE;

      // Если LastTime равен нулю, то HistorySelect уже сделан в MT4HISTORY::IsChangeHistory().
      if (!this.LastTime || _B2(::HistorySelect(this.LastTime, END_TIME))) // https://www.mql5.com/ru/forum/285631/page79#comment_9884935
  //    if (_B2(::HistorySelect(this.LastTime, INT_MAX))) // Возможно, INT_MAX быстрее END_TIME
      {
        const int TotalOrders = ::HistoryOrdersTotal();
        const int TotalDeals = ::HistoryDealsTotal();

        Res = ((TotalOrders > this.LastTotalOrders) || (TotalDeals > this.LastTotalDeals));

        if (Res)
        {
          int iOrder = this.LastTotalOrders;
          int iDeal = this.LastTotalDeals;

          ulong TicketOrder = 0;
          ulong TicketDeal = 0;

          long TimeOrder = (iOrder < TotalOrders) ? ::HistoryOrderGetInteger((TicketOrder = ::HistoryOrderGetTicket(iOrder)), ORDER_TIME_DONE_MSC) : LONG_MAX;
          long TimeDeal = (iDeal < TotalDeals) ? ::HistoryDealGetInteger((TicketDeal = ::HistoryDealGetTicket(iDeal)), DEAL_TIME_MSC) : LONG_MAX;

          if (this.LastTime < LastTimeCurrentLeft)
          {
            this.LastTotalOrders = 0;
            this.LastTotalDeals = 0;

            this.LastTime = LastTimeCurrentLeft;
          }

          long LastTimeMsc = this.LastTime * THOUSAND;

          while ((iDeal < TotalDeals) || (iOrder < TotalOrders))
            if (TimeOrder < TimeDeal)
            {
              LASTTIME(Order)

              if (MT4HISTORY::IsMT4Order(TicketOrder))
              {
                this.Amount = ::ArrayResize(this.Tickets, this.Amount + 1, RESERVE_SIZE);

                this.Tickets[this.Amount - 1] = -(long)TicketOrder;
              }

              iOrder++;

              TimeOrder = (iOrder < TotalOrders) ? ::HistoryOrderGetInteger((TicketOrder = ::HistoryOrderGetTicket(iOrder)), ORDER_TIME_DONE_MSC) : LONG_MAX;
            }
            else
            {
              LASTTIME(Deal)

              if (MT4HISTORY::IsMT4Deal(TicketDeal))
              {
                this.Amount = ::ArrayResize(this.Tickets, this.Amount + 1, RESERVE_SIZE);

                this.Tickets[this.Amount - 1] = (long)TicketDeal;

              #ifndef MT4ORDERS_FASTHISTORY_OFF
                _B2(this.DealsOut.Add(::HistoryDealGetInteger(TicketDeal, DEAL_POSITION_ID), TicketDeal)); // Запомнится только первая OUT-сделка.
              #endif // MT4ORDERS_FASTHISTORY_OFF
              }
            #ifndef MT4ORDERS_FASTHISTORY_OFF
              else if ((ENUM_DEAL_ENTRY)::HistoryDealGetInteger(TicketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
                _B2(this.DealsIn.Add(::HistoryDealGetInteger(TicketDeal, DEAL_POSITION_ID), TicketDeal));
            #endif // MT4ORDERS_FASTHISTORY_OFF

              iDeal++;

              TimeDeal = (iDeal < TotalDeals) ? ::HistoryDealGetInteger((TicketDeal = ::HistoryDealGetTicket(iDeal)), DEAL_TIME_MSC) : LONG_MAX;
            }
        }
        else if (LastTimeCurrentLeft > this.LastTime)
        {
          this.LastTime = LastTimeCurrentLeft;

          this.LastTotalOrders = 0;
          this.LastTotalDeals = 0;
        }
      }
    }

    return(Res);
  }

#else // #ifdef MT4ORDERS_HISTORY_OLD
  bool RefreshHistory( void )
  {
    if (_B2(::HistorySelect(0, INT_MAX)))
    {
      const int TotalOrders = ::HistoryOrdersTotal();
      const int TotalDeals = ::HistoryDealsTotal();

      if ((TotalOrders > this.LastTotalOrders) || (TotalDeals > this.LastTotalDeals))
      {
        ulong TicketOrder = 0;
        ulong TicketDeal = 0;

        long TimeOrder = (this.LastTotalOrders < TotalOrders) ?
                           ::HistoryOrderGetInteger((TicketOrder = ::HistoryOrderGetTicket(this.LastTotalOrders)), ORDER_TIME_DONE_MSC) : LONG_MAX;
        long TimeDeal = (this.LastTotalDeals < TotalDeals) ?
                          ::HistoryDealGetInteger((TicketDeal = ::HistoryDealGetTicket(this.LastTotalDeals)), DEAL_TIME_MSC) : LONG_MAX;

        while ((this.LastTotalDeals < TotalDeals) || (this.LastTotalOrders < TotalOrders))
          if (TimeOrder < TimeDeal)
          {
            if (MT4HISTORY::IsMT4Order(TicketOrder))
            {
              this.Amount = ::ArrayResize(this.Tickets, this.Amount + 1, RESERVE_SIZE);

              this.Tickets[this.Amount - 1] = -(long)TicketOrder;
            }

            this.LastTotalOrders++;

            TimeOrder = (this.LastTotalOrders < TotalOrders) ?
                          ::HistoryOrderGetInteger((TicketOrder = ::HistoryOrderGetTicket(this.LastTotalOrders)), ORDER_TIME_DONE_MSC) : LONG_MAX;
          }
          else
          {
            if (MT4HISTORY::IsMT4Deal(TicketDeal))
            {
              this.Amount = ::ArrayResize(this.Tickets, this.Amount + 1, RESERVE_SIZE);

              this.Tickets[this.Amount - 1] = (long)TicketDeal;

              _B2(this.DealsOut.Add(::HistoryDealGetInteger(TicketDeal, DEAL_POSITION_ID), TicketDeal));
            }
            else if ((ENUM_DEAL_ENTRY)::HistoryDealGetInteger(TicketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
              _B2(this.DealsIn.Add(::HistoryDealGetInteger(TicketDeal, DEAL_POSITION_ID), TicketDeal));

            this.LastTotalDeals++;

            TimeDeal = (this.LastTotalDeals < TotalDeals) ?
                         ::HistoryDealGetInteger((TicketDeal = ::HistoryDealGetTicket(this.LastTotalDeals)), DEAL_TIME_MSC) : LONG_MAX;
          }
      }
    }

    return(true);
  }

  ulong GetPositionDealIn2( const ulong PositionID, const ulong DealStop = LONG_MAX )
  {
    ulong Ticket = 0; // UNKNOWN_TICKET

  #ifdef MT4ORDERS_BYPASS_MAXTIME
    static TRADESID TradesID;

    ulong Deals[];
    const int Size = _B2(TradesID.GetDealsByID(PositionID, Deals)); // Будет выполнен HistorySelect(0, INT_MAX)

    this.TicketValid = (DealStop == LONG_MAX) ? (Size >= 2) : (Size > 2);

    if (this.TicketValid)
    {
      this.TicketCommission = 0;
      this.TicketPrice = 0;
      this.TicketLots = 0;

      for (int i = 0; (i < Size) && (Deals[i] < DealStop); i++)
      {
        const ulong DealTicket = Deals[i];
        const ENUM_DEAL_ENTRY Entry = (ENUM_DEAL_ENTRY)::HistoryDealGetInteger(DealTicket, DEAL_ENTRY);
        const double Commission = ::HistoryDealGetDouble(DealTicket, DEAL_COMMISSION);
        const double Volume = ::HistoryDealGetDouble(DealTicket, DEAL_VOLUME);

        if (this.TicketLots < 1e-8)
        {
          Ticket = DealTicket;

          this.TicketLots = 0;
          this.TicketDeals = 0;
        }

        if (Entry == DEAL_ENTRY_IN)
        {
          this.TicketPrice = (this.TicketPrice * this.TicketLots + ::HistoryDealGetDouble(DealTicket, DEAL_PRICE) * Volume) / (this.TicketLots + Volume);
          this.TicketCommission += Commission;

          this.TicketLots += Volume;
        }
        else
        {
          this.TicketCommission -= this.TicketCommission * Volume / this.TicketLots;

          this.TicketLots -= Volume;
        }

        this.TicketDeals++;
      }
    }
    else if (Size)
      Ticket = Deals[0];

    return(Ticket);
  #else // #ifdef MT4ORDERS_BYPASS_MAXTIME
    return((_B2(this.DealsIn.TryGetValue(PositionID, Ticket)) ||
            _B2(this.RefreshHistory() && this.DealsIn.TryGetValue(PositionID, Ticket))) ? Ticket : 0);
  #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME #else
  }

#endif // #ifdef MT4ORDERS_HISTORY_OLD #else
public:
  static bool IsMT4Deal( const ulong &Ticket )
  {
    const ENUM_DEAL_TYPE DealType = (ENUM_DEAL_TYPE)::HistoryDealGetInteger(Ticket, DEAL_TYPE);
    const ENUM_DEAL_ENTRY DealEntry = (ENUM_DEAL_ENTRY)::HistoryDealGetInteger(Ticket, DEAL_ENTRY);

    return(((DealType != DEAL_TYPE_BUY) && (DealType != DEAL_TYPE_SELL)) ||      // не торговая сделка
           ((DealEntry == DEAL_ENTRY_OUT) || (DealEntry == DEAL_ENTRY_OUT_BY))); // торговая
  }

  static bool IsMT4Order( const ulong &Ticket )
  {
    // Если отложенный ордер исполнился, его ORDER_POSITION_ID заполняется.
    // https://www.mql5.com/ru/forum/170952/page70#comment_6543162
    // https://www.mql5.com/ru/forum/93352/page19#comment_6646726
    // Второе условие: когда лимитный ордер был частично исполнен, а затем удален.
    // Маркет-ордер может быть отменен и не иметь ORDER_POSITION_ID.
    return((::HistoryOrderGetInteger(Ticket, ORDER_TYPE) > ORDER_TYPE_SELL) &&(!::HistoryOrderGetInteger(Ticket, ORDER_POSITION_ID) ||
                                                                               ::HistoryOrderGetDouble(Ticket, ORDER_VOLUME_CURRENT)));
  }

  MT4HISTORY( void ) : Amount(::ArrayResize(this.Tickets, 0, RESERVE_SIZE)),
                       LastTotalDeals(0), LastTotalOrders(0),
                       TicketValid(false), TicketCommission(0), TicketPrice(0), TicketLots(0), TicketDeals(0)
                     #ifdef MT4ORDERS_HISTORY_OLD
                       , LastTime(0), LastInitTime(0), PrevDealsTotal(0), PrevOrdersTotal(0)
                     #endif // #ifdef MT4ORDERS_HISTORY_OLD
  {
//    this.RefreshHistory(); // Если история не используется, незачем забивать ресурсы.
  }

  ulong GetPositionDealIn( const ulong PositionIdentifier = -1, const ulong DealOutTicket = LONG_MAX ) // ID = 0 - нельзя, т.к. балансовая сделка тестера имеет ноль
  {
    ulong Ticket = 0;

    this.TicketValid = false;

    if (PositionIdentifier == -1)
    {
      const ulong MyPositionIdentifier = ::PositionGetInteger(POSITION_IDENTIFIER);

    #ifndef MT4ORDERS_FASTHISTORY_OFF
      if (!(Ticket = this.GetPositionDealIn2(MyPositionIdentifier)))
    #endif // MT4ORDERS_FASTHISTORY_OFF
      {
        const datetime PosTime = (datetime)::PositionGetInteger(POSITION_TIME);

        if (_B3(::HistorySelect(PosTime, PosTime)))
        {
          const int Total = ::HistoryDealsTotal();

          for (int i = 0; i < Total; i++)
          {
            const ulong TicketDeal = ::HistoryDealGetTicket(i);

            if ((::HistoryDealGetInteger(TicketDeal, DEAL_POSITION_ID) == MyPositionIdentifier) /*&&
                ((ENUM_DEAL_ENTRY)::HistoryDealGetInteger(TicketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN) */) // Первое упоминание и так будет DEAL_ENTRY_IN
            {
              Ticket = TicketDeal;

            #ifndef MT4ORDERS_FASTHISTORY_OFF
              _B2(this.DealsIn.Add(MyPositionIdentifier, Ticket));
            #endif // MT4ORDERS_FASTHISTORY_OFF

              break;
            }
          }
        }
      }
    }
    else if (PositionIdentifier && // PositionIdentifier балансовых сделок равен нулю
           #ifndef MT4ORDERS_FASTHISTORY_OFF
             !(Ticket = this.GetPositionDealIn2(PositionIdentifier, DealOutTicket)) &&
           #endif // MT4ORDERS_FASTHISTORY_OFF
             _B3(::HistorySelectByPosition(PositionIdentifier)) && (::HistoryDealsTotal() > 1)) // > 1, а не > 0 - ищется DealIN для уже закрытой позиции.
    {
      Ticket = _B2(::HistoryDealGetTicket(0)); // Первое упоминание и так будет DEAL_ENTRY_IN

      /*
      const int Total = ::HistoryDealsTotal();

      for (int i = 0; i < Total; i++)
      {
        const ulong TicketDeal = ::HistoryDealGetTicket(i);

        if (TicketDeal > 0)
          if ((ENUM_DEAL_ENTRY)::HistoryDealGetInteger(TicketDeal, DEAL_ENTRY) == DEAL_ENTRY_IN)
          {
            Ticket = TicketDeal;

            break;
          }
      } */

    #ifndef MT4ORDERS_FASTHISTORY_OFF
      _B2(this.DealsIn.Add(PositionIdentifier, Ticket));
    #endif // MT4ORDERS_FASTHISTORY_OFF
    }

    return(Ticket);
  }

  ulong GetPositionDealOut( const ulong PositionIdentifier )
  {
    ulong Ticket = 0;

  #ifndef MT4ORDERS_FASTHISTORY_OFF
    if (!_B2(this.DealsOut.TryGetValue(PositionIdentifier, Ticket)) && _B2(this.RefreshHistory()))
      _B2(this.DealsOut.TryGetValue(PositionIdentifier, Ticket));
    #endif // MT4ORDERS_FASTHISTORY_OFF

    return(Ticket);
  }

  int GetAmount( void )
  {
    _B2(this.RefreshHistory());

    return((int)this.Amount);
  }

  int GetAmountPrev( void ) const
  {
    return((int)this.Amount);
  }

  long operator []( const uint &Pos )
  {
    long Res = 0;

    if ((Pos >= this.Amount)/* || (!MT4HISTORY::IsTester && (MT4HISTORY::AccountNumber != ::AccountInfoInteger(ACCOUNT_LOGIN)))*/)
    {
      _B2(this.RefreshHistory());

      if (Pos < this.Amount)
        Res = this.Tickets[Pos];
    }
    else
      Res = this.Tickets[Pos];

    return(Res);
  }

  bool GetTicketCommission( double &Commission, double &Lots ) const
  {
    if (this.TicketValid)
    {
      Commission = this.TicketCommission;
      Lots = this.TicketLots;
    }

    return(this.TicketValid);
  }

  bool GetTicketPrice( double &Price ) const
  {
    if (this.TicketValid)
      Price = this.TicketPrice;

    return(this.TicketValid);
  }

  int GetTicketDeals( void ) const
  {
    return(this.TicketValid ? this.TicketDeals : 1);
  }

  double GetTicketLots( void ) const
  {
    return(this.TicketValid ? ::NormalizeDouble(this.TicketLots, 8) : 0);
  }
};

static const bool MT4HISTORY::IsTester = ::MQLInfoInteger(MQL_TESTER);
// static long MT4HISTORY::AccountNumber = ::AccountInfoInteger(ACCOUNT_LOGIN);

#undef LASTTIME
#undef THOUSAND
#undef END_TIME
#undef HISTORY_PAUSE
#undef DAY
#undef RESERVE_SIZE

#define OP_BUY ORDER_TYPE_BUY
#define OP_SELL ORDER_TYPE_SELL
#define OP_BUYLIMIT ORDER_TYPE_BUY_LIMIT
#define OP_SELLLIMIT ORDER_TYPE_SELL_LIMIT
#define OP_BUYSTOP ORDER_TYPE_BUY_STOP
#define OP_SELLSTOP ORDER_TYPE_SELL_STOP
#define OP_BALANCE 6

#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1

#define MODE_TRADES 0
#define MODE_HISTORY 1

class MT4ORDERS
{
private:
  static MT4_ORDER Order;
  static MT4HISTORY History;

  static const bool MT4ORDERS::IsTester;
  static const bool MT4ORDERS::IsHedging;

  static const int MTBuildSLTP;

  static int OrderSendBug;

//  static bool HistorySelectOrder( const ulong &Ticket )
  static bool HistorySelectOrder( const ulong Ticket )
  {
    return(Ticket && ((::HistoryOrderGetInteger(Ticket, ORDER_TICKET) == Ticket) ||
                      (_B2(::HistorySelect(0, INT_MAX)) && (::HistoryOrderGetInteger(Ticket, ORDER_TICKET) == Ticket))));
  }

  static bool HistorySelectDeal( const ulong &Ticket )
  {
    return(Ticket && ((::HistoryDealGetInteger(Ticket, DEAL_TICKET) == Ticket) ||
                      (_B2(::HistorySelect(0, INT_MAX)) && (::HistoryDealGetInteger(Ticket, DEAL_TICKET) == Ticket))));
  }

#define UNKNOWN_COMMISSION DBL_MIN
#define UNKNOWN_REQUEST_PRICE DBL_MIN
#define UNKNOWN_TICKET 0
// #define UNKNOWN_REASON (-1)

  static bool CheckNewTicket( void )
  {
    return(false); // Ни к чему этот функционал - есть INT_MIN/INT_MAX с SELECT_BY_POS + MODE_TRADES

    static long PrevPosTimeUpdate = 0;
    static long PrevPosTicket = 0;

    const long PosTimeUpdate = ::PositionGetInteger(POSITION_TIME_UPDATE_MSC);
    const long PosTicket = ::PositionGetInteger(POSITION_TICKET);

    // На случай, если пользователь сделал выбор позиции не через MT4Orders
    // Перегружать MQL5-PositionSelect* и MQL5-OrderSelect нерезонно.
    // Этой проверки достаточно, т.к. несколько изменений позиции + PositionSelect в одну миллисекунду возможно только в тестере
    const bool Res = ((PosTimeUpdate != PrevPosTimeUpdate) || (PosTicket != PrevPosTicket));

    if (Res)
    {
      MT4ORDERS::GetPositionData();

      PrevPosTimeUpdate = PosTimeUpdate;
      PrevPosTicket = PosTicket;
    }

    return(Res);
  }

  static bool CheckPositionTicketOpen( void )
  {
    if ((MT4ORDERS::Order.TicketOpen == UNKNOWN_TICKET) || MT4ORDERS::CheckNewTicket())
    {
      MT4ORDERS::Order.TicketOpen = (long)_B2(MT4ORDERS::History.GetPositionDealIn()); // Все из-за этой очень дорогой функции

      MT4ORDERS::Order.DealsAmount = MT4ORDERS::History.GetTicketDeals();

      MT4ORDERS::Order.LotsOpen = MT4ORDERS::History.GetTicketLots();
    }

    return(true);
  }

  static bool CheckPositionCommissionComment( void )
  {
    if ((MT4ORDERS::Order.Commission == UNKNOWN_COMMISSION) || MT4ORDERS::CheckNewTicket())
    {
      MT4ORDERS::Order.Commission = 0; // ::PositionGetDouble(POSITION_COMMISSION); // Всегда ноль
      MT4ORDERS::Order.Comment = ::PositionGetString(POSITION_COMMENT);

      if (!MT4ORDERS::Order.Commission || (MT4ORDERS::Order.Comment == ""))
      {
        MT4ORDERS::CheckPositionTicketOpen();

        const ulong Ticket = MT4ORDERS::Order.TicketOpen;

        if ((Ticket > 0) && _B2(MT4ORDERS::HistorySelectDeal(Ticket)))
        {
          double LotsIn;

          if (!MT4ORDERS::Order.Commission && !MT4ORDERS::History.GetTicketCommission(MT4ORDERS::Order.Commission, LotsIn))
          {
            LotsIn = ::HistoryDealGetDouble(Ticket, DEAL_VOLUME);

            if (LotsIn > 0)
              MT4ORDERS::Order.Commission = ::HistoryDealGetDouble(Ticket, DEAL_COMMISSION) * ::PositionGetDouble(POSITION_VOLUME) / LotsIn;
          }

          if (MT4ORDERS::Order.Comment == "")
            MT4ORDERS::Order.Comment = ::HistoryDealGetString(Ticket, DEAL_COMMENT);
        }
      }
    }

    return(true);
  }
/*
  static bool CheckPositionOpenReason( void )
  {
    if ((MT4ORDERS::Order.OpenReason == UNKNOWN_REASON) || MT4ORDERS::CheckNewTicket())
    {
      MT4ORDERS::CheckPositionTicketOpen();

      const ulong Ticket = MT4ORDERS::Order.TicketOpen;

      if ((Ticket > 0) && (MT4ORDERS::IsTester || MT4ORDERS::HistorySelectDeal(Ticket)))
        MT4ORDERS::Order.OpenReason = (ENUM_DEAL_REASON)::HistoryDealGetInteger(Ticket, DEAL_REASON);
    }

    return(true);
  }
*/
  static bool CheckPositionOpenPriceRequest( void )
  {
    const long PosTicket = ::PositionGetInteger(POSITION_TICKET);

    if (((MT4ORDERS::Order.OpenPriceRequest == UNKNOWN_REQUEST_PRICE) || MT4ORDERS::CheckNewTicket()) &&
        !(MT4ORDERS::Order.OpenPriceRequest = (_B2(MT4ORDERS::HistorySelectOrder(PosTicket)) &&
                                              (MT4ORDERS::IsTester || (::PositionGetInteger(POSITION_TIME_MSC) ==
                                              ::HistoryOrderGetInteger(PosTicket, ORDER_TIME_DONE_MSC)))) // А нужна ли эта проверка?
                                            ? ::HistoryOrderGetDouble(PosTicket, ORDER_PRICE_OPEN)
                                            : ::PositionGetDouble(POSITION_PRICE_OPEN)))
      MT4ORDERS::Order.OpenPriceRequest = ::PositionGetDouble(POSITION_PRICE_OPEN); // На случай, если цена ордера нулевая

    return(true);
  }

  static void GetPositionData( void )
  {
    MT4ORDERS::Order.Ticket = POSITION_SELECT;

    MT4ORDERS::Order.Commission = UNKNOWN_COMMISSION; // MT4ORDERS::CheckPositionCommissionComment();
    MT4ORDERS::Order.OpenPriceRequest = UNKNOWN_REQUEST_PRICE; // MT4ORDERS::CheckPositionOpenPriceRequest()
    MT4ORDERS::Order.TicketOpen = UNKNOWN_TICKET;
//    MT4ORDERS::Order.OpenReason = UNKNOWN_REASON;

//    const bool AntoWarning = ::OrderSelect(0); // Обнуляет данные выбранной позиции - может быть нужно для OrderModify

    return;
  }

// #undef UNKNOWN_REASON
#undef UNKNOWN_TICKET
#undef UNKNOWN_REQUEST_PRICE
#undef UNKNOWN_COMMISSION

  static void GetOrderData( void )
  {
    MT4ORDERS::Order.Ticket = ORDER_SELECT;

//    ::PositionSelectByTicket(0); // Обнуляет данные выбранной позиции - может быть нужно для OrderModify

    return;
  }

  static void GetHistoryOrderData( const ulong Ticket )
  {
    MT4ORDERS::Order.Ticket = ::HistoryOrderGetInteger(Ticket, ORDER_TICKET);
    MT4ORDERS::Order.Type = (int)::HistoryOrderGetInteger(Ticket, ORDER_TYPE);

    MT4ORDERS::Order.TicketOpen = MT4ORDERS::Order.Ticket;
    MT4ORDERS::Order.TicketID = MT4ORDERS::Order.Ticket; // Удаленная отложка может иметь ненулевой POSITION_ID.

    MT4ORDERS::Order.Lots = ::HistoryOrderGetDouble(Ticket, ORDER_VOLUME_CURRENT);

    if (!MT4ORDERS::Order.Lots)
      MT4ORDERS::Order.Lots = ::HistoryOrderGetDouble(Ticket, ORDER_VOLUME_INITIAL);

    MT4ORDERS::Order.Symbol = ::HistoryOrderGetString(Ticket, ORDER_SYMBOL);
    MT4ORDERS::Order.Comment = ::HistoryOrderGetString(Ticket, ORDER_COMMENT);

    MT4ORDERS::Order.OpenTimeMsc = ::HistoryOrderGetInteger(Ticket, ORDER_TIME_SETUP_MSC);
    MT4ORDERS::Order.OpenTime = (datetime)(MT4ORDERS::Order.OpenTimeMsc / 1000);

    MT4ORDERS::Order.OpenPrice = ::HistoryOrderGetDouble(Ticket, ORDER_PRICE_OPEN);
    MT4ORDERS::Order.OpenPriceRequest = MT4ORDERS::Order.OpenPrice;

    MT4ORDERS::Order.OpenReason = (ENUM_DEAL_REASON)::HistoryOrderGetInteger(Ticket, ORDER_REASON);

    MT4ORDERS::Order.StopLoss = ::HistoryOrderGetDouble(Ticket, ORDER_SL);
    MT4ORDERS::Order.TakeProfit = ::HistoryOrderGetDouble(Ticket, ORDER_TP);

    MT4ORDERS::Order.CloseTimeMsc = ::HistoryOrderGetInteger(Ticket, ORDER_TIME_DONE_MSC);
    MT4ORDERS::Order.CloseTime = (datetime)(MT4ORDERS::Order.CloseTimeMsc / 1000);

    MT4ORDERS::Order.ClosePrice = ::HistoryOrderGetDouble(Ticket, ORDER_PRICE_CURRENT);
    MT4ORDERS::Order.ClosePriceRequest = MT4ORDERS::Order.ClosePrice;

    MT4ORDERS::Order.CloseReason = MT4ORDERS::Order.OpenReason;

    MT4ORDERS::Order.State = (ENUM_ORDER_STATE)::HistoryOrderGetInteger(Ticket, ORDER_STATE);

    MT4ORDERS::Order.Expiration = (datetime)::HistoryOrderGetInteger(Ticket, ORDER_TIME_EXPIRATION);

    MT4ORDERS::Order.MagicNumber = ::HistoryOrderGetInteger(Ticket, ORDER_MAGIC);

    MT4ORDERS::Order.Profit = 0;

    MT4ORDERS::Order.Commission = 0;
    MT4ORDERS::Order.Swap = 0;

    return;
  }

  static string GetTickFlag( uint tickflag )
  {
    string flag = " " + (string)tickflag;

  #define TICKFLAG_MACRO(A) flag += ((bool)(tickflag & TICK_FLAG_##A)) ? " TICK_FLAG_" + #A : ""; \
                            tickflag -= tickflag & TICK_FLAG_##A;
    TICKFLAG_MACRO(BID)
    TICKFLAG_MACRO(ASK)
    TICKFLAG_MACRO(LAST)
    TICKFLAG_MACRO(VOLUME)
    TICKFLAG_MACRO(BUY)
    TICKFLAG_MACRO(SELL)
  #undef TICKFLAG_MACRO

    if (tickflag)
      flag += " FLAG_UNKNOWN (" + (string)tickflag + ")";

    return(flag);
  }

#define TOSTR(A) " " + #A + " = " + (string)Tick.A
#define TOSTR2(A) " " + #A + " = " + ::DoubleToString(Tick.A, digits)
#define TOSTR3(A) " " + #A + " = " + (string)(A)

  static string TickToString( const string &Symb, const MqlTick &Tick )
  {
    const int digits = (int)::SymbolInfoInteger(Symb, SYMBOL_DIGITS);

    return(TOSTR3(Symb) + TOSTR(time) + "." + ::IntegerToString(Tick.time_msc % 1000, 3, '0') +
           TOSTR2(bid) + TOSTR2(ask) + TOSTR2(last)+ TOSTR(volume) + MT4ORDERS::GetTickFlag(Tick.flags));
  }

  static string TickToString( const string &Symb )
  {
    MqlTick Tick = {};

    return(TOSTR3(::SymbolInfoTick(Symb, Tick)) + MT4ORDERS::TickToString(Symb, Tick));
  }

#undef TOSTR3
#undef TOSTR2
#undef TOSTR

  static void AlertLog( void )
  {
    ::Alert("Please send the logs to the coauthor - https://www.mql5.com/en/users/fxsaber");

    string Str = ::TimeToString(::TimeLocal(), TIME_DATE);
    ::StringReplace(Str, ".", NULL);

    ::Alert(::TerminalInfoString(TERMINAL_PATH) + "\\MQL5\\Logs\\" + Str + ".log");

    return;
  }

  static long GetTimeCurrent( void )
  {
    long Res = 0;
    MqlTick Tick = {};

    for (int i = ::SymbolsTotal(true) - 1; i >= 0; i--)
    {
      const string SymbName = ::SymbolName(i, true);

      if (!::SymbolInfoInteger(SymbName, SYMBOL_CUSTOM) && ::SymbolInfoTick(SymbName, Tick) && (Tick.time_msc > Res))
        Res = Tick.time_msc;
    }

    return(Res);
  }

  static string TimeToString( const long time )
  {
    return((string)(datetime)(time / 1000) + "." + ::IntegerToString(time % 1000, 3, '0'));
  }

#define WHILE(A) while ((!(Res = (A))) && MT4ORDERS::Waiting())

#define TOSTR(A)  #A + " = " + (string)(A) + "\n"
#define TOSTR2(A) #A + " = " + ::EnumToString(A) + " (" + (string)(A) + ")\n"

  static ulong GetFirstOrderTicket( void )
  {
    static ulong FirstOrderTicket = ULONG_MAX;
    static uint PrevTime = 0;

    const uint NewTime = ::GetTickCount();

    if (NewTime - PrevTime > 1000)
    {
      if ((FirstOrderTicket != ::HistoryOrderGetTicket(0)) && ::HistorySelect(0, INT_MAX))
        FirstOrderTicket = ::HistoryOrdersTotal() ? ::HistoryOrderGetTicket(0) : ULONG_MAX;

      PrevTime = NewTime;
    }

    return(FirstOrderTicket);
  }

  static bool IsHistoryFull( const ulong &OrderTicket )
  {
    return(MT4ORDERS::IsTester || (OrderTicket >= MT4ORDERS::GetFirstOrderTicket())); // Если был живой ордер во время удаления истории брокером - плохо.
  }

  static void GetHistoryPositionData( const ulong Ticket )
  {
    MT4ORDERS::Order.Ticket = (long)Ticket;
    MT4ORDERS::Order.TicketID = ::HistoryDealGetInteger(MT4ORDERS::Order.Ticket, DEAL_POSITION_ID);
    MT4ORDERS::Order.Type = (int)::HistoryDealGetInteger(Ticket, DEAL_TYPE);

    if ((MT4ORDERS::Order.Type > OP_SELL))
      MT4ORDERS::Order.Type += (OP_BALANCE - OP_SELL - 1);
    else
      MT4ORDERS::Order.Type = 1 - MT4ORDERS::Order.Type;

    MT4ORDERS::Order.Lots = ::HistoryDealGetDouble(Ticket, DEAL_VOLUME);

    MT4ORDERS::Order.Symbol = ::HistoryDealGetString(Ticket, DEAL_SYMBOL);
    MT4ORDERS::Order.Comment = ::HistoryDealGetString(Ticket, DEAL_COMMENT);

    MT4ORDERS::Order.CloseTimeMsc = ::HistoryDealGetInteger(Ticket, DEAL_TIME_MSC);
    MT4ORDERS::Order.CloseTime = (datetime)(MT4ORDERS::Order.CloseTimeMsc / 1000); // (datetime)::HistoryDealGetInteger(Ticket, DEAL_TIME);

    MT4ORDERS::Order.ClosePrice = ::HistoryDealGetDouble(Ticket, DEAL_PRICE);

    MT4ORDERS::Order.CloseReason = (ENUM_DEAL_REASON)::HistoryDealGetInteger(Ticket, DEAL_REASON);

    MT4ORDERS::Order.Expiration = 0;

    MT4ORDERS::Order.MagicNumber = ::HistoryDealGetInteger(Ticket, DEAL_MAGIC);

    MT4ORDERS::Order.Profit = ::HistoryDealGetDouble(Ticket, DEAL_PROFIT);

    MT4ORDERS::Order.Commission = ::HistoryDealGetDouble(Ticket, DEAL_COMMISSION);
    MT4ORDERS::Order.Swap = ::HistoryDealGetDouble(Ticket, DEAL_SWAP);

    MT4ORDERS::Order.StopLoss = MT4ORDERS::MTBuildSLTP ? ::HistoryDealGetDouble(Ticket, DEAL_SL) : 0;
    MT4ORDERS::Order.TakeProfit = MT4ORDERS::MTBuildSLTP ? ::HistoryDealGetDouble(Ticket, DEAL_TP) : 0;

    MT4ORDERS::Order.DealsAmount = 0;
    MT4ORDERS::Order.LotsOpen = MT4ORDERS::Order.Lots;

    const ulong OrderTicket = (MT4ORDERS::Order.Type < OP_BALANCE) ? ::HistoryDealGetInteger(Ticket, DEAL_ORDER) : 0;
    const ulong PosTicket = MT4ORDERS::Order.TicketID;
    const ulong OpenTicket = (OrderTicket > 0) ? _B2(MT4ORDERS::History.GetPositionDealIn(PosTicket, Ticket)) : 0;

    const bool IsOrderTicket = MT4ORDERS::IsHistoryFull(OrderTicket); // Не обрезана ли брокером история до этого тикета?

    if (OpenTicket > 0)
    {
      MT4ORDERS::Order.DealsAmount = MT4ORDERS::History.GetTicketDeals();
      MT4ORDERS::Order.LotsOpen = MT4ORDERS::History.GetTicketLots();

      const ENUM_DEAL_REASON Reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(Ticket, DEAL_REASON);
      const ENUM_DEAL_ENTRY DealEntry = (ENUM_DEAL_ENTRY)::HistoryDealGetInteger(Ticket, DEAL_ENTRY);

    // История (OpenTicket и OrderTicket) подгружена, благодаря GetPositionDealIn, - HistorySelectByPosition
    #ifdef MT4ORDERS_FASTHISTORY_OFF
      const bool Res = true;
    #else // MT4ORDERS_FASTHISTORY_OFF
      // Частичное исполнение породит нужный ордер - https://www.mql5.com/ru/forum/227423/page2#comment_6543129
      bool Res = MT4ORDERS::IsTester ? MT4ORDERS::HistorySelectOrder(OrderTicket) : (!IsOrderTicket || MT4ORDERS::Waiting(true));

      // Можно долго ждать в этой ситуации: https://www.mql5.com/ru/forum/170952/page184#comment_17913645
      if (!Res)
        WHILE(_B2(MT4ORDERS::HistorySelectOrder(OrderTicket))) // https://www.mql5.com/ru/forum/304239#comment_10710403
          ;

      if (_B2(MT4ORDERS::HistorySelectDeal(OpenTicket))) // Обязательно сработает, т.к. OpenTicket гарантированно в истории.
    #endif // MT4ORDERS_FASTHISTORY_OFF
      {
        MT4ORDERS::Order.TicketOpen = (long)OpenTicket;

        MT4ORDERS::Order.OpenReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(OpenTicket, DEAL_REASON);

        if (!MT4ORDERS::History.GetTicketPrice(MT4ORDERS::Order.OpenPrice))
          MT4ORDERS::Order.OpenPrice = ::HistoryDealGetDouble(OpenTicket, DEAL_PRICE);

        MT4ORDERS::Order.OpenTimeMsc = ::HistoryDealGetInteger(OpenTicket, DEAL_TIME_MSC);
        MT4ORDERS::Order.OpenTime = (datetime)(MT4ORDERS::Order.OpenTimeMsc / 1000);

        double OpenLots;
        double Commission;

        if (!MT4ORDERS::History.GetTicketCommission(Commission, OpenLots))
        {
          Commission = ::HistoryDealGetDouble(OpenTicket, DEAL_COMMISSION);
          OpenLots = ::HistoryDealGetDouble(OpenTicket, DEAL_VOLUME);

          MT4ORDERS::Order.LotsOpen = OpenLots;
        }

        if (OpenLots > 0)
          MT4ORDERS::Order.Commission += Commission * MT4ORDERS::Order.Lots / OpenLots;

//        if (!MT4ORDERS::Order.MagicNumber) // Мэджик закрытой позиции всегда должен быть равен мэджику открывающей сделки.
          const long Magic = ::HistoryDealGetInteger(OpenTicket, DEAL_MAGIC);

          if (Magic)
            MT4ORDERS::Order.MagicNumber = Magic;

//        if (MT4ORDERS::Order.Comment == "") // Комментарий закрытой позиции всегда должен быть равен комментарию открывающей сделки.
          const string StrComment = ::HistoryDealGetString(OpenTicket, DEAL_COMMENT);

        if (Res && IsOrderTicket) // OrderTicket может не быть в истории, но может оказаться среди еще живых. Возможно, резонно оттуда выудить нужную инфу.
        {
          double OrderPriceOpen = ::HistoryOrderGetDouble(OrderTicket, ORDER_PRICE_OPEN);

          if (!MT4ORDERS::MTBuildSLTP)
          {
            if (Reason == DEAL_REASON_TP)
            {
              if (!OrderPriceOpen)
                // https://www.mql5.com/ru/forum/1111/page2820#comment_17749873
                OrderPriceOpen = (double)::StringSubstr(MT4ORDERS::Order.Comment, MT4ORDERS::IsTester ? 3 : (::StringFind(MT4ORDERS::Order.Comment, "tp ") + 3));

              MT4ORDERS::Order.TakeProfit = OrderPriceOpen;
              MT4ORDERS::Order.StopLoss = ::HistoryOrderGetDouble(OrderTicket, ORDER_TP);
            }
            else if (Reason == DEAL_REASON_SL)
            {
              if (!OrderPriceOpen)
                // https://www.mql5.com/ru/forum/1111/page2820#comment_17749873
                OrderPriceOpen = (double)::StringSubstr(MT4ORDERS::Order.Comment, MT4ORDERS::IsTester ? 3 : (::StringFind(MT4ORDERS::Order.Comment, "sl ") + 3));

              MT4ORDERS::Order.StopLoss = OrderPriceOpen;
              MT4ORDERS::Order.TakeProfit = ::HistoryOrderGetDouble(OrderTicket, ORDER_SL);
            }
            else if (!MT4ORDERS::IsTester &&::StringLen(MT4ORDERS::Order.Comment) > 3)
            {
              const string PartComment = ::StringSubstr(MT4ORDERS::Order.Comment, 0, 3);

              if (PartComment == "[tp")
              {
                MT4ORDERS::Order.CloseReason = DEAL_REASON_TP;

                if (!OrderPriceOpen)
                  // https://www.mql5.com/ru/forum/1111/page2820#comment_17749873
                  OrderPriceOpen = (double)::StringSubstr(MT4ORDERS::Order.Comment, MT4ORDERS::IsTester ? 3 : (::StringFind(MT4ORDERS::Order.Comment, "tp ") + 3));

                MT4ORDERS::Order.TakeProfit = OrderPriceOpen;
                MT4ORDERS::Order.StopLoss = ::HistoryOrderGetDouble(OrderTicket, ORDER_TP);
              }
              else if (PartComment == "[sl")
              {
                MT4ORDERS::Order.CloseReason = DEAL_REASON_SL;

                if (!OrderPriceOpen)
                  // https://www.mql5.com/ru/forum/1111/page2820#comment_17749873
                  OrderPriceOpen = (double)::StringSubstr(MT4ORDERS::Order.Comment, MT4ORDERS::IsTester ? 3 : (::StringFind(MT4ORDERS::Order.Comment, "sl ") + 3));

                MT4ORDERS::Order.StopLoss = OrderPriceOpen;
                MT4ORDERS::Order.TakeProfit = ::HistoryOrderGetDouble(OrderTicket, ORDER_SL);
              }
              else
              {
                // Перевернуто - не ошибка: см. OrderClose.
                MT4ORDERS::Order.StopLoss = ::HistoryOrderGetDouble(OrderTicket, ORDER_TP);
                MT4ORDERS::Order.TakeProfit = ::HistoryOrderGetDouble(OrderTicket, ORDER_SL);
              }
            }
            else
            {
              // Перевернуто - не ошибка: см. OrderClose.
              MT4ORDERS::Order.StopLoss = ::HistoryOrderGetDouble(OrderTicket, ORDER_TP);
              MT4ORDERS::Order.TakeProfit = ::HistoryOrderGetDouble(OrderTicket, ORDER_SL);
            }
          }

          MT4ORDERS::Order.State = (ENUM_ORDER_STATE)::HistoryOrderGetInteger(OrderTicket, ORDER_STATE);

          if (!(MT4ORDERS::Order.ClosePriceRequest = (DealEntry == DEAL_ENTRY_OUT_BY) ? MT4ORDERS::Order.ClosePrice : OrderPriceOpen))
            MT4ORDERS::Order.ClosePriceRequest = MT4ORDERS::Order.ClosePrice;

          if (!(MT4ORDERS::Order.OpenPriceRequest = _B2(MT4ORDERS::HistorySelectOrder(PosTicket) &&
                                                    // При частичном исполнении только последняя сделка полностью исполненного ордера имеет это условие для взятия цены запроса.
                                                    (MT4ORDERS::IsTester || (::HistoryDealGetInteger(OpenTicket, DEAL_TIME_MSC) == ::HistoryOrderGetInteger(PosTicket, ORDER_TIME_DONE_MSC)))) ?
                                                   ::HistoryOrderGetDouble(PosTicket, ORDER_PRICE_OPEN) : MT4ORDERS::Order.OpenPrice))
            MT4ORDERS::Order.OpenPriceRequest = MT4ORDERS::Order.OpenPrice;
        }
        else
        {
          MT4ORDERS::Order.State = ORDER_STATE_FILLED;

          MT4ORDERS::Order.ClosePriceRequest = MT4ORDERS::Order.ClosePrice;
          MT4ORDERS::Order.OpenPriceRequest = MT4ORDERS::Order.OpenPrice;
        }

        // Выше комментарий используется для нахождения SL/TP.
        if (StrComment != "")
          MT4ORDERS::Order.Comment = StrComment;
      }

      if (!Res)
      {
        ::Alert("HistoryOrderSelect(" + (string)OrderTicket + ") - BUG! MT4ORDERS - not Sync with History!");
        MT4ORDERS::AlertLog();

        ::Print(__FILE__ + "\nVersion = " + __MT4ORDERS__ + "\nCompiler = " + (string)__MQLBUILD__ + "\n" + TOSTR(__DATE__) +
                TOSTR(::AccountInfoString(ACCOUNT_SERVER)) + TOSTR2((ENUM_ACCOUNT_TRADE_MODE)::AccountInfoInteger(ACCOUNT_TRADE_MODE)) +
                TOSTR((bool)::TerminalInfoInteger(TERMINAL_CONNECTED)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_PING_LAST)) + TOSTR(::TerminalInfoDouble(TERMINAL_RETRANSMISSION)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_BUILD)) + TOSTR((bool)::TerminalInfoInteger(TERMINAL_X64)) +
                TOSTR((bool)::TerminalInfoInteger(TERMINAL_VPS)) + TOSTR2((ENUM_PROGRAM_TYPE)::MQLInfoInteger(MQL_PROGRAM_TYPE)) +
                TOSTR(::TimeCurrent()) + TOSTR(::TimeTradeServer()) + TOSTR(MT4ORDERS::TimeToString(MT4ORDERS::GetTimeCurrent())) +
                TOSTR(::SymbolInfoString(MT4ORDERS::Order.Symbol, SYMBOL_PATH)) + TOSTR(::SymbolInfoString(MT4ORDERS::Order.Symbol, SYMBOL_DESCRIPTION)) +
                "CurrentTick =" + MT4ORDERS::TickToString(MT4ORDERS::Order.Symbol) + "\n" +
                TOSTR(::PositionsTotal()) + TOSTR(::OrdersTotal()) +
                TOSTR(::HistorySelect(0, INT_MAX)) + TOSTR(::HistoryDealsTotal()) + TOSTR(::HistoryOrdersTotal()) +
                TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE)) + TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_PHYSICAL)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_TOTAL)) + TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_USED)) +
                TOSTR(::MQLInfoInteger(MQL_MEMORY_LIMIT)) + TOSTR(::MQLInfoInteger(MQL_MEMORY_USED)) + TOSTR(::MQLInfoInteger(MQL_HANDLES_USED)) +
                TOSTR(Ticket) + TOSTR(OrderTicket) + TOSTR(OpenTicket) + TOSTR(PosTicket) +
                TOSTR(MT4ORDERS::TimeToString(MT4ORDERS::Order.CloseTimeMsc)) +
                TOSTR(MT4ORDERS::HistorySelectOrder(OrderTicket)) + TOSTR(::OrderSelect(OrderTicket)) +
                TOSTR(MT4ORDERS::GetFirstOrderTicket()) +
                (::OrderSelect(OrderTicket) ? TOSTR2((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE)) : NULL) +
                (::HistoryDealsTotal() ? TOSTR(::HistoryDealGetTicket(::HistoryDealsTotal() - 1)) +
                   "DEAL_ORDER = " + (string)::HistoryDealGetInteger(::HistoryDealGetTicket(::HistoryDealsTotal() - 1), DEAL_ORDER) + "\n"
                   "DEAL_TIME_MSC = " + MT4ORDERS::TimeToString(::HistoryDealGetInteger(::HistoryDealGetTicket(::HistoryDealsTotal() - 1), DEAL_TIME_MSC)) + "\n"
                                       : NULL) +
                (::HistoryOrdersTotal() ? TOSTR(::HistoryOrderGetTicket(::HistoryOrdersTotal() - 1)) +
                   "ORDER_TIME_DONE_MSC = " + MT4ORDERS::TimeToString(::HistoryOrderGetInteger(::HistoryOrderGetTicket(::HistoryOrdersTotal() - 1), ORDER_TIME_DONE_MSC)) + "\n"
                                        : NULL) +
              #ifdef MT4ORDERS_BYPASS_MAXTIME
                "MT4ORDERS::ByPass: " + MT4ORDERS::ByPass.ToString() + "\n" +
              #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
                TOSTR(MT4ORDERS::OrderSend_MaxPause) + TOSTR(MT4ORDERS::OrderSendBug));
      }
    }
    else
    {
      MT4ORDERS::Order.TicketOpen = MT4ORDERS::Order.Ticket;

      if (!MT4ORDERS::Order.TicketID && (MT4ORDERS::Order.Type <= OP_SELL)) // ID балансовых сделок должен оставаться нулевым.
        MT4ORDERS::Order.TicketID = MT4ORDERS::Order.Ticket;

      MT4ORDERS::Order.OpenPrice = MT4ORDERS::Order.ClosePrice; // ::HistoryDealGetDouble(Ticket, DEAL_PRICE);

      MT4ORDERS::Order.OpenTimeMsc = MT4ORDERS::Order.CloseTimeMsc;
      MT4ORDERS::Order.OpenTime = MT4ORDERS::Order.CloseTime;   // (datetime)::HistoryDealGetInteger(Ticket, DEAL_TIME);

      MT4ORDERS::Order.OpenReason = MT4ORDERS::Order.CloseReason;

      MT4ORDERS::Order.State = ORDER_STATE_FILLED;

      MT4ORDERS::Order.ClosePriceRequest = MT4ORDERS::Order.ClosePrice;
      MT4ORDERS::Order.OpenPriceRequest = MT4ORDERS::Order.OpenPrice;
    }

    if (OrderTicket && IsOrderTicket)
    {
      bool Res = MT4ORDERS::IsTester ? MT4ORDERS::HistorySelectOrder(OrderTicket) : MT4ORDERS::Waiting(true);

      if (!Res)
        WHILE(_B2(MT4ORDERS::HistorySelectOrder(OrderTicket))) // https://www.mql5.com/ru/forum/304239#comment_10710403
          ;

      if ((ENUM_ORDER_TYPE)::HistoryOrderGetInteger(OrderTicket, ORDER_TYPE) == ORDER_TYPE_CLOSE_BY)
      {
        const ulong PosTicketBy = ::HistoryOrderGetInteger(OrderTicket, ORDER_POSITION_BY_ID);

        if (PosTicketBy == PosTicket) // CloseBy-Slave не должен влиять на торговый оборот. Master_DealTicket < Slave_DealTicket
        {
          MT4ORDERS::Order.Lots = 0;
          MT4ORDERS::Order.Commission = 0;

          MT4ORDERS::Order.ClosePrice = MT4ORDERS::Order.OpenPrice;
          MT4ORDERS::Order.ClosePriceRequest = MT4ORDERS::Order.ClosePrice;
        }
        else // CloseBy-Master должен получить комиссию (но не свопы!) от CloseBy-Slave.
        {
          // Может быть несколько позиций с ID от CloseBy-Slave, поэтому во входных присутствует Master_DealTicket.
          const ulong OpenTicketBy = (OrderTicket > 0) ? _B2(MT4ORDERS::History.GetPositionDealIn(PosTicketBy, Ticket)) : 0;

          if ((OpenTicketBy > 0) && _B2(MT4ORDERS::HistorySelectDeal(OpenTicketBy)))
          {
            double OpenLots;
            double Commission;

            if (!MT4ORDERS::History.GetTicketCommission(Commission, OpenLots))
            {
              Commission= ::HistoryDealGetDouble(OpenTicketBy, DEAL_COMMISSION) ;
              OpenLots = ::HistoryDealGetDouble(OpenTicketBy, DEAL_VOLUME);
            }

          if (OpenLots > 0)
            MT4ORDERS::Order.Commission += Commission * MT4ORDERS::Order.Lots / OpenLots;
          }
        }
      }
    }

    return;
  }

  static bool Waiting( const bool FlagInit = false )
  {
    static ulong StartTime = 0;

    const bool Res = FlagInit ? false : (::GetMicrosecondCount() - StartTime < MT4ORDERS::OrderSend_MaxPause);

    if (FlagInit)
    {
      StartTime = ::GetMicrosecondCount();

      MT4ORDERS::OrderSendBug = 0;
    }
    else if (Res)
    {
//      ::Sleep(0); // https://www.mql5.com/ru/forum/170952/page100#comment_8750511

      MT4ORDERS::OrderSendBug++;
    }

    return(Res);
  }

  static bool EqualPrices( const double Price1, const double &Price2, const int &digits)
  {
    return(!::NormalizeDouble(Price1 - Price2, digits));
  }

  static bool HistoryDealSelect2( MqlTradeResult &Result ) // В конце названия цифра для большей совместимости с макросами.
  {
  #ifdef MT4ORDERS_HISTORY_OLD
    // Заменить HistorySelectByPosition на HistorySelect(PosTime, PosTime)
    if (!Result.deal && Result.order && _B3(::HistorySelectByPosition(::HistoryOrderGetInteger(Result.order, ORDER_POSITION_ID))))
    {
  #else // #ifdef MT4ORDERS_HISTORY_OLD
    if (!Result.deal && Result.order && _B2(MT4ORDERS::HistorySelectOrder(Result.order)))
    {
      const long OrderTimeFill = ::HistoryOrderGetInteger(Result.order, ORDER_TIME_DONE_MSC);
  #endif // #ifdef MT4ORDERS_HISTORY_OLD #else
      if (::HistorySelect(0, INT_MAX)) // Без этого сделку можно не обнаружить.
        for (int i = ::HistoryDealsTotal() - 1; i >= 0; i--)
        {
          const ulong DealTicket = ::HistoryDealGetTicket(i);

          if (Result.order == ::HistoryDealGetInteger(DealTicket, DEAL_ORDER))
          {
            Result.deal = DealTicket;
            Result.price = ::HistoryDealGetDouble(DealTicket, DEAL_PRICE);

            break;
          }
        #ifndef MT4ORDERS_HISTORY_OLD
          else if (::HistoryDealGetInteger(DealTicket, DEAL_TIME_MSC) < OrderTimeFill)
            break;
        #endif // #ifndef MT4ORDERS_HISTORY_OLD
        }
    }

    return(_B2(MT4ORDERS::HistorySelectDeal(Result.deal)));
  }

/*
#define MT4ORDERS_BENCHMARK Alert(MT4ORDERS::LastTradeRequest.symbol + " " +       \
                                  (string)MT4ORDERS::LastTradeResult.order + " " + \
                                  MT4ORDERS::LastTradeResult.comment);             \
                            Print(ToString(MT4ORDERS::LastTradeRequest) +          \
                                  ToString(MT4ORDERS::LastTradeResult));
*/

#define TMP_MT4ORDERS_BENCHMARK(A) \
  static ulong Max##A = 0;         \
                                   \
  if (Interval##A > Max##A)        \
  {                                \
    MT4ORDERS_BENCHMARK            \
                                   \
    Max##A = Interval##A;          \
  }

  static void OrderSend_Benchmark( const ulong &Interval1, const ulong &Interval2 )
  {
    #ifdef MT4ORDERS_BENCHMARK
      TMP_MT4ORDERS_BENCHMARK(1)
      TMP_MT4ORDERS_BENCHMARK(2)
    #endif // MT4ORDERS_BENCHMARK

    return;
  }

#undef TMP_MT4ORDERS_BENCHMARK

  static string ToString( const MqlTradeRequest &Request )
  {
    return(TOSTR2(Request.action) + TOSTR(Request.magic) + TOSTR(Request.order) +
           TOSTR(Request.symbol) + TOSTR(Request.volume) + TOSTR(Request.price) +
           TOSTR(Request.stoplimit) + TOSTR(Request.sl) +  TOSTR(Request.tp) +
           TOSTR(Request.deviation) + TOSTR2(Request.type) + TOSTR2(Request.type_filling) +
           TOSTR2(Request.type_time) + TOSTR(Request.expiration) + TOSTR(Request.comment) +
           TOSTR(Request.position) + TOSTR(Request.position_by));
  }

  static string ToString( const MqlTradeResult &Result )
  {
    return(TOSTR(Result.retcode) + TOSTR(Result.deal) + TOSTR(Result.order) +
           TOSTR(Result.volume) + TOSTR(Result.price) + TOSTR(Result.bid) +
           TOSTR(Result.ask) + TOSTR(Result.comment) + TOSTR(Result.request_id) +
           TOSTR(Result.retcode_external));
  }

  static bool OrderSend( const MqlTradeRequest &Request, MqlTradeResult &Result )
  {
    const bool FlagCalc = !MT4ORDERS::IsTester && MT4ORDERS::OrderSend_MaxPause;

    MqlTick PrevTick = {};

    if (FlagCalc)
      ::SymbolInfoTick(Request.symbol, PrevTick); // Может тормозить.

    const long PrevTimeCurrent = FlagCalc ? _B2(MT4ORDERS::GetTimeCurrent()) : 0;
    const ulong StartTime1 = FlagCalc ? ::GetMicrosecondCount() : 0;

    bool Res = ::OrderSend(Request, Result);

    const ulong StartTime2 = FlagCalc ? ::GetMicrosecondCount() : 0;

    const ulong Interval1 = StartTime2 - StartTime1;

    if (FlagCalc && Res && (Result.retcode < TRADE_RETCODE_ERROR))
    {
      Res = (Result.retcode == TRADE_RETCODE_DONE);
      MT4ORDERS::Waiting(true);

      // TRADE_ACTION_CLOSE_BY отсутствует в перечне проверок
      if (Request.action == TRADE_ACTION_DEAL)
      {
        if (!Result.deal)
        {
          WHILE(_B2(::OrderSelect(Result.order)) || _B2(MT4ORDERS::HistorySelectOrder(Result.order)))
            ;

          if (!Res)
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::OrderSelect(Result.order)) + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)));
          else if (::OrderSelect(Result.order) && !(Res = ((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED) ||
                                                          ((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE) == ORDER_STATE_PARTIAL)))
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::OrderSelect(Result.order)) + TOSTR2((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE)));
        }

        // Если после частичного исполнения оставшаяся часть осталась висеть - false.
        if (Res)
        {
          const bool ResultDeal = (!Result.deal) && (!MT4ORDERS::OrderSendBug);

          if (MT4ORDERS::OrderSendBug && (!Result.deal))
            ::Print("Line = " + (string)__LINE__ + "\n" + "Before ::HistoryOrderSelect(Result.order):\n" + TOSTR(MT4ORDERS::OrderSendBug) + TOSTR(Result.deal));

          WHILE(_B2(MT4ORDERS::HistorySelectOrder(Result.order)))
            ;

          // Если ранее не было OrderSend-бага и был Result.deal == 0
          if (ResultDeal)
            MT4ORDERS::OrderSendBug = 0;

          if (!Res)
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)) +
                    TOSTR(MT4ORDERS::HistorySelectDeal(Result.deal)) + TOSTR(::OrderSelect(Result.order)) + TOSTR(Result.deal));
          // Если исторический ордер не исполнился (отклонили) - false
          else if (!(Res = ((ENUM_ORDER_STATE)::HistoryOrderGetInteger(Result.order, ORDER_STATE) == ORDER_STATE_FILLED) ||
                           ((ENUM_ORDER_STATE)::HistoryOrderGetInteger(Result.order, ORDER_STATE) == ORDER_STATE_PARTIAL)))
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR2((ENUM_ORDER_STATE)::HistoryOrderGetInteger(Result.order, ORDER_STATE)));
        }

        if (Res)
        {
          const bool ResultDeal = (!Result.deal) && (!MT4ORDERS::OrderSendBug);

          if (MT4ORDERS::OrderSendBug && (!Result.deal))
            ::Print("Line = " + (string)__LINE__ + "\n" + "Before MT4ORDERS::HistoryDealSelect(Result):\n" + TOSTR(MT4ORDERS::OrderSendBug) + TOSTR(Result.deal));

          WHILE(MT4ORDERS::HistoryDealSelect2(Result))
            ;

          // Если ранее не было OrderSend-бага и был Result.deal == 0
          if (ResultDeal)
            MT4ORDERS::OrderSendBug = 0;

          if (!Res)
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistoryDealSelect2(Result)));
        }
      }
      else if (Request.action == TRADE_ACTION_PENDING)
      {
        if (Res)
        {
          WHILE(_B2(::OrderSelect(Result.order)) || _B2(MT4ORDERS::HistorySelectOrder(Result.order))) // History - может исполниться.
            ;

          if (!Res)
          {
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::OrderSelect(Result.order)));
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)));
          }
          else if (::OrderSelect(Result.order) &&
                   (!(Res = ((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE) == ORDER_STATE_PLACED) ||
                            ((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE) == ORDER_STATE_PARTIAL))))
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR2((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE)));
        }
        else
        {
          WHILE(_B2(MT4ORDERS::HistorySelectOrder(Result.order)))
            ;

          ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)));

          Res = false;
        }
      }
      else if (Request.action == TRADE_ACTION_SLTP)
      {
        if (Res)
        {
          const int digits = (int)::SymbolInfoInteger(Request.symbol, SYMBOL_DIGITS);

          bool EqualSL = false;
          bool EqualTP = false;

          do
            if (Request.position ? _B2(::PositionSelectByTicket(Request.position)) : _B2(::PositionSelect(Request.symbol)))
            {
              EqualSL = MT4ORDERS::EqualPrices(::PositionGetDouble(POSITION_SL), Request.sl, digits);
              EqualTP = MT4ORDERS::EqualPrices(::PositionGetDouble(POSITION_TP), Request.tp, digits);
            }
          WHILE(EqualSL && EqualTP);

          if (!Res)
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::PositionGetDouble(POSITION_SL)) + TOSTR(::PositionGetDouble(POSITION_TP)) +
                    TOSTR(EqualSL) + TOSTR(EqualTP) +
                    TOSTR(Request.position ? ::PositionSelectByTicket(Request.position) : ::PositionSelect(Request.symbol)));
        }
      }
      else if (Request.action == TRADE_ACTION_MODIFY)
      {
        if (Res)
        {
          const int digits = (int)::SymbolInfoInteger(Request.symbol, SYMBOL_DIGITS);

          bool EqualSL = false;
          bool EqualTP = false;
          bool EqualPrice = false;

          do
            if (_B2(::OrderSelect(Result.order)))
            {
              // https://www.mql5.com/ru/forum/170952/page184#comment_17913645
              if (((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE) != ORDER_STATE_REQUEST_MODIFY))
              {
                EqualSL = MT4ORDERS::EqualPrices(::OrderGetDouble(ORDER_SL), Request.sl, digits);
                EqualTP = MT4ORDERS::EqualPrices(::OrderGetDouble(ORDER_TP), Request.tp, digits);
                EqualPrice = MT4ORDERS::EqualPrices(::OrderGetDouble(ORDER_PRICE_OPEN), Request.price, digits);
              }
            }
            else if (_B2(MT4ORDERS::HistorySelectOrder(Result.order))) // History - может исполниться.
            {
              EqualSL = true;
              EqualTP = true;
              EqualPrice = true;
            }
          WHILE((EqualSL && EqualTP && EqualPrice));

          if (!Res)
          {
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::OrderSelect(Result.order)));
            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)));

            ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(::OrderGetDouble(ORDER_SL)) + TOSTR(Request.sl)+
                    TOSTR(::OrderGetDouble(ORDER_TP)) + TOSTR(Request.tp) +
                    TOSTR(::OrderGetDouble(ORDER_PRICE_OPEN)) + TOSTR(Request.price) +
                    TOSTR(EqualSL) + TOSTR(EqualTP) + TOSTR(EqualPrice) +
                    TOSTR(::OrderSelect(Result.order)) +
                    TOSTR2((ENUM_ORDER_STATE)::OrderGetInteger(ORDER_STATE)));
          }
        }
      }
      else if (Request.action == TRADE_ACTION_REMOVE)
      {
        if (Res)
          WHILE(_B2(MT4ORDERS::HistorySelectOrder(Result.order)))
            ;

        if (!Res)
          ::Print("Line = " + (string)__LINE__ + "\n" + TOSTR(MT4ORDERS::HistorySelectOrder(Result.order)));
      }

      const ulong Interval2 = ::GetMicrosecondCount() - StartTime2;

      Result.comment += " " + ::DoubleToString(Interval1 / 1000.0, 3) + " + " +
                              ::DoubleToString(Interval2 / 1000.0, 3) + " (" + (string)MT4ORDERS::OrderSendBug + ") ms.";

      if (!Res || MT4ORDERS::OrderSendBug)
      {
        ::Alert(Res ? "OrderSend(" + (string)Result.order + ") - BUG!" : "MT4ORDERS - not Sync with History!");
        MT4ORDERS::AlertLog();

        ::Print(__FILE__ + "\nVersion = " + __MT4ORDERS__ + "\nCompiler = " + (string)__MQLBUILD__ + "\n" + TOSTR(__DATE__) +
                TOSTR(::AccountInfoString(ACCOUNT_SERVER)) + TOSTR2((ENUM_ACCOUNT_TRADE_MODE)::AccountInfoInteger(ACCOUNT_TRADE_MODE)) +
                TOSTR((bool)::TerminalInfoInteger(TERMINAL_CONNECTED)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_PING_LAST)) + TOSTR(::TerminalInfoDouble(TERMINAL_RETRANSMISSION)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_BUILD)) + TOSTR((bool)::TerminalInfoInteger(TERMINAL_X64)) +
                TOSTR((bool)::TerminalInfoInteger(TERMINAL_VPS)) + TOSTR2((ENUM_PROGRAM_TYPE)::MQLInfoInteger(MQL_PROGRAM_TYPE)) +
                TOSTR(::TimeCurrent()) + TOSTR(::TimeTradeServer()) +
                TOSTR(MT4ORDERS::TimeToString(MT4ORDERS::GetTimeCurrent())) + TOSTR(MT4ORDERS::TimeToString(PrevTimeCurrent)) +
                "PrevTick =" + MT4ORDERS::TickToString(Request.symbol, PrevTick) + "\n" +
                "CurrentTick =" + MT4ORDERS::TickToString(Request.symbol) + "\n" +
                TOSTR(::SymbolInfoString(Request.symbol, SYMBOL_PATH)) + TOSTR(::SymbolInfoString(Request.symbol, SYMBOL_DESCRIPTION)) +
                TOSTR(::PositionsTotal()) + TOSTR(::OrdersTotal()) +
                TOSTR(::HistorySelect(0, INT_MAX)) + TOSTR(::HistoryDealsTotal()) + TOSTR(::HistoryOrdersTotal()) +
                (::HistoryDealsTotal() ? TOSTR(::HistoryDealGetTicket(::HistoryDealsTotal() - 1)) +
                   "DEAL_ORDER = " + (string)::HistoryDealGetInteger(::HistoryDealGetTicket(::HistoryDealsTotal() - 1), DEAL_ORDER) + "\n"
                   "DEAL_TIME_MSC = " + MT4ORDERS::TimeToString(::HistoryDealGetInteger(::HistoryDealGetTicket(::HistoryDealsTotal() - 1), DEAL_TIME_MSC)) + "\n"
                                       : NULL) +
                (::HistoryOrdersTotal() ? TOSTR(::HistoryOrderGetTicket(::HistoryOrdersTotal() - 1)) +
                   "ORDER_TIME_DONE_MSC = " + MT4ORDERS::TimeToString(::HistoryOrderGetInteger(::HistoryOrderGetTicket(::HistoryOrdersTotal() - 1), ORDER_TIME_DONE_MSC)) + "\n"
                                        : NULL) +
                TOSTR(MT4ORDERS::GetFirstOrderTicket()) +
                TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_AVAILABLE)) + TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_PHYSICAL)) +
                TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_TOTAL)) + TOSTR(::TerminalInfoInteger(TERMINAL_MEMORY_USED)) + TOSTR(::MQLInfoInteger(MQL_HANDLES_USED)) +
                TOSTR(::MQLInfoInteger(MQL_MEMORY_LIMIT)) + TOSTR(::MQLInfoInteger(MQL_MEMORY_USED)) +
                TOSTR(MT4ORDERS::IsHedging) + TOSTR(Res) + TOSTR(MT4ORDERS::OrderSendBug) +
                MT4ORDERS::ToString(Request) + MT4ORDERS::ToString(Result) +
              #ifdef MT4ORDERS_BYPASS_MAXTIME
                "MT4ORDERS::ByPass: " + MT4ORDERS::ByPass.ToString() + "\n" +
              #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
                TOSTR(MT4ORDERS::OrderSend_MaxPause));
      }
      else
        MT4ORDERS::OrderSend_Benchmark(Interval1, Interval2);
    }
    else if (FlagCalc)
    {
      Result.comment += " " + ::DoubleToString(Interval1 / 1000.0, 3) + " ms";

      ::Print(TOSTR(::TimeCurrent()) + TOSTR(::TimeTradeServer()) + TOSTR(MT4ORDERS::TimeToString(PrevTimeCurrent)) +
              MT4ORDERS::TickToString(Request.symbol, PrevTick) + "\n" + MT4ORDERS::TickToString(Request.symbol) + "\n" +
              MT4ORDERS::ToString(Request) + MT4ORDERS::ToString(Result));

//      ExpertRemove();
    }

    return(Res);
  }

#undef TOSTR2
#undef TOSTR
#undef WHILE

  static ENUM_DAY_OF_WEEK GetDayOfWeek( const datetime &time )
  {
    return((ENUM_DAY_OF_WEEK)((time / (24 * 3600) + THURSDAY) % 7));
  }

  static bool SessionTrade( const string &Symb )
  {
    datetime TimeNow = ::TimeCurrent();

    const ENUM_DAY_OF_WEEK DayOfWeek = MT4ORDERS::GetDayOfWeek(TimeNow);

    TimeNow %= 24 * 60 * 60;

    bool Res = false;
    datetime From, To;

    for (int i = 0; (!Res) && ::SymbolInfoSessionTrade(Symb, DayOfWeek, i, From, To); i++)
      Res = ((From <= TimeNow) && (TimeNow < To));

    return(Res);
  }

  static bool SymbolTrade( const string &Symb )
  {
    MqlTick Tick;

    return(::SymbolInfoTick(Symb, Tick) ? (Tick.bid && Tick.ask && MT4ORDERS::SessionTrade(Symb) /* &&
           ((ENUM_SYMBOL_TRADE_MODE)::SymbolInfoInteger(Symb, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL) */) : false);
  }

  static bool CorrectResult( void )
  {
    ::ZeroMemory(MT4ORDERS::LastTradeResult);

    MT4ORDERS::LastTradeResult.retcode = MT4ORDERS::LastTradeCheckResult.retcode;
    MT4ORDERS::LastTradeResult.comment = MT4ORDERS::LastTradeCheckResult.comment;

    return(false);
  }

  static bool NewOrderCheck( void )
  {
    return((::OrderCheck(MT4ORDERS::LastTradeRequest, MT4ORDERS::LastTradeCheckResult) &&
           (MT4ORDERS::IsTester || MT4ORDERS::SymbolTrade(MT4ORDERS::LastTradeRequest.symbol))) ||
           (!MT4ORDERS::IsTester && MT4ORDERS::CorrectResult()));
  }

  static bool NewOrderSend( const int &Check )
  {
    return((Check == INT_MAX) ? MT4ORDERS::NewOrderCheck() :
           (((Check != INT_MIN) || MT4ORDERS::NewOrderCheck()) && MT4ORDERS::OrderSend(MT4ORDERS::LastTradeRequest, MT4ORDERS::LastTradeResult)
              ? (MT4ORDERS::LastTradeResult.retcode < TRADE_RETCODE_ERROR)
              #ifdef MT4ORDERS_BYPASS_MAXTIME
                && _B2(MT4ORDERS::ByPass += MT4ORDERS::LastTradeResult.order)
              #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
              : false));
  }

  static bool ModifyPosition( const long &Ticket, MqlTradeRequest &Request )
  {
    const bool Res = _B2(::PositionSelectByTicket(Ticket));

    if (Res)
    {
      Request.action = TRADE_ACTION_SLTP;

      Request.position = Ticket;
      Request.symbol = ::PositionGetString(POSITION_SYMBOL); // указания одного тикета не достаточно!
    }

    return(Res);
  }

  static ENUM_ORDER_TYPE_FILLING GetFilling( const string &Symb, const uint Type = ORDER_FILLING_FOK )
  {
    static ENUM_ORDER_TYPE_FILLING Res = ORDER_FILLING_FOK;
    static string LastSymb = NULL;
    static uint LastType = ORDER_FILLING_FOK;

    const bool SymbFlag = (LastSymb != Symb);

    if (SymbFlag || (LastType != Type)) // Можно немного ускорить, поменяв очередность проверки условия.
    {
      LastType = Type;

      if (SymbFlag)
        LastSymb = Symb;

      const ENUM_SYMBOL_TRADE_EXECUTION ExeMode = (ENUM_SYMBOL_TRADE_EXECUTION)::SymbolInfoInteger(Symb, SYMBOL_TRADE_EXEMODE);
      const int FillingMode = (int)::SymbolInfoInteger(Symb, SYMBOL_FILLING_MODE);

      Res = (!FillingMode || (Type >= ORDER_FILLING_RETURN) || ((FillingMode & (Type + 1)) != Type + 1)) ?
            (((ExeMode == SYMBOL_TRADE_EXECUTION_EXCHANGE) || (ExeMode == SYMBOL_TRADE_EXECUTION_INSTANT)) ?
             ORDER_FILLING_RETURN : ((FillingMode == SYMBOL_FILLING_IOC) ? ORDER_FILLING_IOC : ORDER_FILLING_FOK)) :
            (ENUM_ORDER_TYPE_FILLING)Type;
    }

    return(Res);
  }

  static ENUM_ORDER_TYPE_TIME GetExpirationType( const string &Symb, uint Expiration = ORDER_TIME_GTC )
  {
    static ENUM_ORDER_TYPE_TIME Res = ORDER_TIME_GTC;
    static string LastSymb = NULL;
    static uint LastExpiration = ORDER_TIME_GTC;

    const bool SymbFlag = (LastSymb != Symb);

    if ((LastExpiration != Expiration) || SymbFlag)
    {
      LastExpiration = Expiration;

      if (SymbFlag)
        LastSymb = Symb;

      const int ExpirationMode = (int)::SymbolInfoInteger(Symb, SYMBOL_EXPIRATION_MODE);

      if ((Expiration > ORDER_TIME_SPECIFIED_DAY) || (!((ExpirationMode >> Expiration) & 1)))
      {
        if ((Expiration < ORDER_TIME_SPECIFIED) || (ExpirationMode < SYMBOL_EXPIRATION_SPECIFIED))
          Expiration = ORDER_TIME_GTC;
        else if (Expiration > ORDER_TIME_DAY)
          Expiration = ORDER_TIME_SPECIFIED;

        uint i = 1 << Expiration;

        while ((Expiration <= ORDER_TIME_SPECIFIED_DAY) && ((ExpirationMode & i) != i))
        {
          i <<= 1;
          Expiration++;
        }
      }

      Res = (ENUM_ORDER_TYPE_TIME)Expiration;
    }

    return(Res);
  }

  static bool ModifyOrder( const long Ticket, const double &Price, const datetime &Expiration, MqlTradeRequest &Request )
  {
    const bool Res = _B2(::OrderSelect(Ticket));

    if (Res)
    {
      Request.action = TRADE_ACTION_MODIFY;
      Request.order = Ticket;

      Request.price = Price;

      Request.symbol = ::OrderGetString(ORDER_SYMBOL);

      // https://www.mql5.com/ru/forum/1111/page1817#comment_4087275
//      Request.type_filling = (ENUM_ORDER_TYPE_FILLING)::OrderGetInteger(ORDER_TYPE_FILLING);
      Request.type_filling = _B2(MT4ORDERS::GetFilling(Request.symbol));
      Request.type_time = _B2(MT4ORDERS::GetExpirationType(Request.symbol, (uint)Expiration));

      if (Expiration > ORDER_TIME_DAY)
        Request.expiration = Expiration;
    }

    return(Res);
  }

  static bool SelectByPosHistory( const int Index )
  {
    const long Ticket = MT4ORDERS::History[Index];
    const bool Res = (Ticket > 0) ? _B2(MT4ORDERS::HistorySelectDeal(Ticket)) : ((Ticket < 0) && _B2(MT4ORDERS::HistorySelectOrder(-Ticket)));

    if (Res)
    {
      if (Ticket > 0)
        _BV2(MT4ORDERS::GetHistoryPositionData(Ticket))
      else
        _BV2(MT4ORDERS::GetHistoryOrderData(-Ticket))
    }

    return(Res);
  }

  // https://www.mql5.com/ru/forum/227960#comment_6603506
  static bool OrderVisible( void )
  {
    // Если позиция закрылась при живой частично исполненной отложке, что ее породила.
    // А после оставшаяся часть отложки полностью исполнилась, но не успела исчезнуть.
    // То будет видна и новая позиция (правильно) и не исчезнувшая отложка (неправильно).

    const ulong PositionID = ::OrderGetInteger(ORDER_POSITION_ID);
    const ENUM_ORDER_TYPE Type = (ENUM_ORDER_TYPE)::OrderGetInteger(ORDER_TYPE);
    ulong Ticket = 0;

    return(!((Type == ORDER_TYPE_CLOSE_BY) ||
             (PositionID && // Partial-отложенник имеет ненулевой PositionID.
              (Type <= ORDER_TYPE_SELL) && // Закрывающие маркет-ордера игнорируем
              ((Ticket = ::OrderGetInteger(ORDER_TICKET)) != PositionID))) && // Открывающие частично исполненные маркет-ордера не игнорируем.
           // Открывающий/доливающий позицию ордер может не успеть исчезнуть.
           (!::PositionsTotal() || !(::PositionSelectByTicket(Ticket ? Ticket : ::OrderGetInteger(ORDER_TICKET)) &&
//                                     (::PositionGetInteger(POSITION_TYPE) == (::OrderGetInteger(ORDER_TYPE) & 1)) &&
//                                     (::PositionGetInteger(POSITION_TIME_MSC) >= ::OrderGetInteger(ORDER_TIME_SETUP_MSC)) &&
                                     (::PositionGetDouble(POSITION_VOLUME) == ::OrderGetDouble(ORDER_VOLUME_INITIAL)))));
  }

  static ulong OrderGetTicket( const int Index )
  {
    ulong Res;
    int PrevTotal;
    const long PrevTicket = ::OrderGetInteger(ORDER_TICKET);
    const long PositionTicket = ::PositionGetInteger(POSITION_TICKET);

    do
    {
      Res = 0;
      PrevTotal = ::OrdersTotal();

      if ((Index >= 0) && (Index < PrevTotal))
      {
        int Count = 0;

        for (int i = 0; i < PrevTotal; i++)
        {
          const int Total = ::OrdersTotal();

          // Во время перебора может измениться количество ордеров
          if (Total != PrevTotal)
          {
            PrevTotal = -1;

            break;
          }
          else
          {
            const ulong Ticket = ::OrderGetTicket(i);

            if (Ticket && MT4ORDERS::OrderVisible())
            {
              if (Count == Index)
              {
                Res = Ticket;

                break;
              }

              Count++;
            }
          }
        }

      #ifdef MT4ORDERS_BYPASS_MAXTIME
       _B2(MT4ORDERS::ByPass.Waiting()); // Изменяет ORDER_TICKET.
      #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
      }
    } while (PrevTotal != ::OrdersTotal()); // Во время перебора может измениться количество ордеров

    if (!Res)
    {
      // При неудаче выбираем тот ордер, что был выбран ранее.
      if (PrevTicket && (::OrderGetInteger(ORDER_TICKET) != PrevTicket))
        const bool AntiWarning = _B2(::OrderSelect(PrevTicket));
    }
  #ifdef MT4ORDERS_BYPASS_MAXTIME
    else if (::OrderGetInteger(ORDER_TICKET) != Res)
      const bool AntiWarning = _B2(::OrderSelect(Res)); // MT4ORDERS::ByPass.Waiting() изменяет ORDER_TICKET.
  #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

    // MT4ORDERS::OrderVisible() меняет выбор позиции.
    if (PositionTicket && (::PositionGetInteger(POSITION_TICKET) != PositionTicket))
      ::PositionSelectByTicket(PositionTicket);

    return(Res);
  }

  // С одним и тем же тикетом приоритет выбора позиции выше ордера
  static bool SelectByPos( const int Index )
  {
    bool Flag = (Index == INT_MAX);
    bool Res = Flag || (Index == INT_MIN);

    if (!Res)
    {
      if (MT4ORDERS::IsTester)
      {
        const int Total = ::PositionsTotal();

        Flag = (Index < Total);

        Res = Flag ? ::PositionGetTicket(Index) : ::OrderGetTicket(Index - Total);
      }
      else
      {
        int Total;

        do
        {
          Total = ::PositionsTotal();
          Flag = (Index < Total);

          if (Flag)
            Res = _B2(::PositionGetTicket(Index));
          else
          {
            const int Index2 = Index - Total;
            const int Total2 = ::OrdersTotal();

            if ((Index2 >= 0) && (Index2 < Total2))
            {
            #ifdef MT4ORDERS_SELECTFILTER_OFF
              Res = ::OrderGetTicket(Index2);
            #else // MT4ORDERS_SELECTFILTER_OFF
              Res = _B2(MT4ORDERS::OrderGetTicket(Index2));
            #endif //MT4ORDERS_SELECTFILTER_OFF
            }
            else
              Res = 0;
          }
        } while (Total != ::PositionsTotal()); // Во время перебора может измениться количество позиций.
      }
    }

    if (Res)
    {
      if (Flag)
        MT4ORDERS::GetPositionData(); // (Index == INT_MAX) - переход на MT5-позицию без проверки существования и обновления.
      else
        MT4ORDERS::GetOrderData();    // (Index == INT_MIN) - переход на живой MT5-ордер без проверки существования и обновления.
    }

    return(Res);
  }

  static bool SelectByHistoryTicket( const long &Ticket )
  {
    bool Res = false;

    if (!Ticket) // Выбор по OrderTicketID (по нулевому значению - балансовые операции).
    {
      const ulong TicketDealOut = MT4ORDERS::History.GetPositionDealOut(Ticket);

      if (Res = _B2(MT4ORDERS::HistorySelectDeal(TicketDealOut)))
        _BV2(MT4ORDERS::GetHistoryPositionData(TicketDealOut));
    }
    else if (_B2(MT4ORDERS::HistorySelectDeal(Ticket)))
    {
    #ifdef MT4ORDERS_TESTER_SELECT_BY_TICKET
      // В Тестере при поиске закрытой позиции нужно искать сначала по PositionID из-за близкой нумерации тикетов MT5-сделок/ордеров.
      if (MT4ORDERS::IsTester)
      {
        const ulong TicketDealOut = MT4ORDERS::History.GetPositionDealOut(HistoryOrderGetInteger(Ticket, ORDER_POSITION_ID));

        if (Res = _B2(MT4ORDERS::HistorySelectDeal(TicketDealOut)))
          _BV2(MT4ORDERS::GetHistoryPositionData(TicketDealOut));
      }

      if (!Res)
    #endif // #ifdef MT4ORDERS_TESTER_SELECT_BY_TICKET
      {
        if (Res = MT4HISTORY::IsMT4Deal(Ticket))
          _BV2(MT4ORDERS::GetHistoryPositionData(Ticket))
        else// DealIn
        {
          const ulong TicketDealOut = MT4ORDERS::History.GetPositionDealOut(HistoryDealGetInteger(Ticket, DEAL_POSITION_ID)); // Выбор по DealIn

          if (Res = _B2(MT4ORDERS::HistorySelectDeal(TicketDealOut)))
            _BV2(MT4ORDERS::GetHistoryPositionData(TicketDealOut))
        }
      }
    }
    else if (_B2(MT4ORDERS::HistorySelectOrder(Ticket)))
    {
      if (Res = MT4HISTORY::IsMT4Order(Ticket))
        _BV2(MT4ORDERS::GetHistoryOrderData(Ticket))
      else
      {
        const ulong TicketDealOut = MT4ORDERS::History.GetPositionDealOut(HistoryOrderGetInteger(Ticket, ORDER_POSITION_ID));

        if (Res = _B2(MT4ORDERS::HistorySelectDeal(TicketDealOut)))
          _BV2(MT4ORDERS::GetHistoryPositionData(TicketDealOut));
      }
    }
    else
    {
      // Выбор по OrderTicketID или тикету исполненной отложки - актуально для Неттинга.
      const ulong TicketDealOut = MT4ORDERS::History.GetPositionDealOut(Ticket);

      if (Res = _B2(MT4ORDERS::HistorySelectDeal(TicketDealOut)))
        _BV2(MT4ORDERS::GetHistoryPositionData(TicketDealOut));
    }

    return(Res);
  }

  static bool SelectByExistingTicket( const long &Ticket )
  {
    bool Res = true;

    if (Ticket < 0)
    {
      if (_B2(::OrderSelect(-Ticket)))
        MT4ORDERS::GetOrderData();
      else if (_B2(::PositionSelectByTicket(-Ticket)))
        MT4ORDERS::GetPositionData();
      else
        Res = false;
    }
    else if (_B2(::PositionSelectByTicket(Ticket)))
      MT4ORDERS::GetPositionData();
    else if (_B2(::OrderSelect(Ticket)))
      MT4ORDERS::GetOrderData();
    else if (_B2(MT4ORDERS::HistorySelectDeal(Ticket)))
    {
    #ifdef MT4ORDERS_TESTER_SELECT_BY_TICKET
      // В Тестере при поиске закрытой позиции нужно искать сначала по PositionID из-за близкой нумерации тикетов MT5-сделок/ордеров.
      if (Res = !MT4ORDERS::IsTester)
    #endif // #ifdef MT4ORDERS_TESTER_SELECT_BY_TICKET
      {
        if (MT4HISTORY::IsMT4Deal(Ticket)) // Если сделан выбор по DealOut.
          _BV2(MT4ORDERS::GetHistoryPositionData(Ticket))
        else if (_B2(::PositionSelectByTicket(::HistoryDealGetInteger(Ticket, DEAL_POSITION_ID)))) // Выбор по DealIn
          MT4ORDERS::GetPositionData();
        else
          Res = false;
      }
    }
    else if (_B2(MT4ORDERS::HistorySelectOrder(Ticket)) && _B2(::PositionSelectByTicket(::HistoryOrderGetInteger(Ticket, ORDER_POSITION_ID)))) // Выбор по тикету MT5-ордера
      MT4ORDERS::GetPositionData();
    else
      Res = false;

    return(Res);
  }

  // С одним и тем же тикетом приоритеты выбора:
  // MODE_TRADES:  существующая позиция > существующий ордер > сделка > отмененный ордер
  // MODE_HISTORY: сделка > отмененный ордер > существующая позиция > существующий ордер
  static bool SelectByTicket( const long &Ticket, const int &Pool )
  {
    return((Pool == MODE_TRADES) || (Ticket < 0) ?
           (_B2(MT4ORDERS::SelectByExistingTicket(Ticket)) || ((Ticket > 0) && _B2(MT4ORDERS::SelectByHistoryTicket(Ticket)))) :
           (_B2(MT4ORDERS::SelectByHistoryTicket(Ticket)) || _B2(MT4ORDERS::SelectByExistingTicket(Ticket))));
  }

  static void CheckPrices( double &MinPrice, double &MaxPrice, const double Min, const double Max )
  {
    if (MinPrice && (MinPrice >= Min))
      MinPrice = 0;

    if (MaxPrice && (MaxPrice <= Max))
      MaxPrice = 0;

    return;
  }

  static int OrdersTotal( void )
  {
    int Res = 0;
    int PrevTotal = ::OrdersTotal();

    if (PrevTotal)
    {
      const long PrevTicket = ::OrderGetInteger(ORDER_TICKET);
      const long PositionTicket = ::PositionGetInteger(POSITION_TICKET);

      do
      {
        PrevTotal = ::OrdersTotal();

        for (int i = PrevTotal - 1; i >= 0; i--)
        {
          // Во время перебора может измениться количество ордеров
          if (PrevTotal != ::OrdersTotal())
          {
            PrevTotal = -1;
            Res = 0;

            break;
          }
          else if (::OrderGetTicket(i) && MT4ORDERS::OrderVisible())
            Res++;
        }

      #ifdef MT4ORDERS_BYPASS_MAXTIME
        if (PrevTotal)
          _B2(MT4ORDERS::ByPass.Waiting());
      #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
      } while (PrevTotal && (PrevTotal != ::OrdersTotal())); // Во время перебора может измениться количество ордеров

      if (PrevTicket && (::OrderGetInteger(ORDER_TICKET) != PrevTicket))
        const bool AntiWarning = _B2(::OrderSelect(PrevTicket));

      // MT4ORDERS::OrderVisible() меняет выбор позиции.
      if (PositionTicket && (::PositionGetInteger(POSITION_TICKET) != PositionTicket))
        ::PositionSelectByTicket(PositionTicket);
    }

    return(Res);
  }

public:
  static uint OrderSend_MaxPause; // максимальное время на синхронизацию в мкс.

#ifdef MT4ORDERS_BYPASS_MAXTIME
  static BYPASS ByPass;
#endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

  static MqlTradeResult LastTradeResult;
  static MqlTradeRequest LastTradeRequest;
  static MqlTradeCheckResult LastTradeCheckResult;

  static bool MT4OrderSelect( const long &Index, const int &Select, const int &Pool )
  {
    return(
         #ifdef MT4ORDERS_BYPASS_MAXTIME
           (MT4ORDERS::IsTester || ((Select == SELECT_BY_POS) && ((Index == INT_MIN) || (Index == INT_MAX) ||
                                                                  ((Pool != MODE_TRADES) && (Index < MT4ORDERS::History.GetAmountPrev())))) ||
                                   _B2(MT4ORDERS::ByPass.Waiting())) &&
         #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
         
         
           (
           (Select ==SELECT_BY_POS) ?
            (
               (Pool == MODE_TRADES) ? _B2(MT4ORDERS::SelectByPos((int)Index)) 
               : _B2(MT4ORDERS::SelectByPosHistory((int)Index))) 
               :_B2(MT4ORDERS::SelectByTicket(Index, Pool))
            );
           //)
           
  }

  static int MT4OrdersTotal( void )
  {
  #ifdef MT4ORDERS_SELECTFILTER_OFF
    return(::OrdersTotal() + ::PositionsTotal());
  #else // MT4ORDERS_SELECTFILTER_OFF
    int Res;

    if (MT4ORDERS::IsTester)
      return(::OrdersTotal() + ::PositionsTotal());
    else
    {
      int PrevTotal;

    #ifdef MT4ORDERS_BYPASS_MAXTIME
      _B2(MT4ORDERS::ByPass.Waiting());
    #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

      do
      {
        const int Total = ::OrdersTotal();

        PrevTotal = ::PositionsTotal();

        Res = Total ? _B2(MT4ORDERS::OrdersTotal()) + PrevTotal : PrevTotal;
      } while (PrevTotal != ::PositionsTotal()); // Отслеживаем только изменение позиций, т.к. ордера отслеживаются в MT4ORDERS::OrdersTotal()
    }

    return(Res); // https://www.mql5.com/ru/forum/290673#comment_9493241
  #endif //MT4ORDERS_SELECTFILTER_OFF
  }

  // Такая "перегрузка" позволяет использоваться совместно и MT5-вариант OrdersTotal
  static int MT4OrdersTotal( const bool )
  {
    return(::OrdersTotal());
  }

  static int MT4OrdersHistoryTotal( void )
  {
    #ifdef MT4ORDERS_BYPASS_MAXTIME
      _B2(MT4ORDERS::ByPass.Waiting());
    #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

    return(MT4ORDERS::History.GetAmount());
  }

  static long MT4OrderSend( const string &Symb, const int &Type, const double &dVolume, const double &Price, const int &SlipPage, const double &SL, const double &TP,
                            const string &comment, const MAGIC_TYPE &magic, const datetime &dExpiration, const color &arrow_color )

  {
    ::ZeroMemory(MT4ORDERS::LastTradeRequest);

    MT4ORDERS::LastTradeRequest.action = (((Type == OP_BUY) || (Type == OP_SELL)) ? TRADE_ACTION_DEAL : TRADE_ACTION_PENDING);
    MT4ORDERS::LastTradeRequest.magic = magic;

    MT4ORDERS::LastTradeRequest.symbol = ((Symb == NULL) ? ::Symbol() : Symb);
    MT4ORDERS::LastTradeRequest.volume = dVolume;
    MT4ORDERS::LastTradeRequest.price = Price;

    MT4ORDERS::LastTradeRequest.tp = TP;
    MT4ORDERS::LastTradeRequest.sl = SL;
    MT4ORDERS::LastTradeRequest.deviation = SlipPage;
    MT4ORDERS::LastTradeRequest.type = (ENUM_ORDER_TYPE)Type;

    MT4ORDERS::LastTradeRequest.type_filling = _B2(MT4ORDERS::GetFilling(MT4ORDERS::LastTradeRequest.symbol, (uint)MT4ORDERS::LastTradeRequest.deviation));

    if (MT4ORDERS::LastTradeRequest.action == TRADE_ACTION_PENDING)
    {
      MT4ORDERS::LastTradeRequest.type_time = _B2(MT4ORDERS::GetExpirationType(MT4ORDERS::LastTradeRequest.symbol, (uint)dExpiration));

      if (dExpiration > ORDER_TIME_DAY)
        MT4ORDERS::LastTradeRequest.expiration = dExpiration;
    }

    if (comment != NULL)
      MT4ORDERS::LastTradeRequest.comment = comment;

    return((arrow_color == INT_MAX) ? (MT4ORDERS::NewOrderCheck() ? 0 : -1) :
           ((((int)arrow_color != INT_MIN) || MT4ORDERS::NewOrderCheck()) &&
            MT4ORDERS::OrderSend(MT4ORDERS::LastTradeRequest, MT4ORDERS::LastTradeResult)
          #ifdef MT4ORDERS_BYPASS_MAXTIME
            && (!MT4ORDERS::IsHedging || _B2(MT4ORDERS::ByPass += MT4ORDERS::LastTradeResult.order))
          #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
                                                                                          ?
            (MT4ORDERS::IsHedging ? (long)MT4ORDERS::LastTradeResult.order : // PositionID == Result.order - особенность MT5-Hedge
             ((MT4ORDERS::LastTradeRequest.action == TRADE_ACTION_DEAL) ?
              (MT4ORDERS::IsTester ? (_B2(::PositionSelect(MT4ORDERS::LastTradeRequest.symbol)) ? PositionGetInteger(POSITION_TICKET) : 0) :
                                      // HistoryDealSelect в MT4ORDERS::OrderSend
                                      ::HistoryDealGetInteger(MT4ORDERS::LastTradeResult.deal, DEAL_POSITION_ID)) :
              (long)MT4ORDERS::LastTradeResult.order)) : -1));
  }

  static bool MT4OrderModify( const long &Ticket, const double &Price, const double &SL, const double &TP, const datetime &Expiration, const color &Arrow_Color )
  {
    ::ZeroMemory(MT4ORDERS::LastTradeRequest);

               // Учитывается случай, когда присутствуют ордер и позиция с одним и тем же тикетом
    bool Res = (Ticket < 0) ? MT4ORDERS::ModifyOrder(-Ticket, Price, Expiration, MT4ORDERS::LastTradeRequest) :
               ((MT4ORDERS::Order.Ticket != ORDER_SELECT)
                // Спорное решение. Проблема, когда нужно модифицировать позицию, а получается модификация ордера с тем же тикетом.
//                || (((::PositionGetInteger(POSITION_TICKET) == Ticket) && (::OrderGetInteger(ORDER_TICKET) != Ticket))
                                                          ?
                (MT4ORDERS::ModifyPosition(Ticket, MT4ORDERS::LastTradeRequest) || MT4ORDERS::ModifyOrder(Ticket, Price, Expiration, MT4ORDERS::LastTradeRequest)) :
                (MT4ORDERS::ModifyOrder(Ticket, Price, Expiration, MT4ORDERS::LastTradeRequest) || MT4ORDERS::ModifyPosition(Ticket, MT4ORDERS::LastTradeRequest)));

//    if (Res) // Игнорируем проверку - есть OrderCheck
    {
      MT4ORDERS::LastTradeRequest.tp = TP;
      MT4ORDERS::LastTradeRequest.sl = SL;

      Res = MT4ORDERS::NewOrderSend(Arrow_Color);
    }

    return(Res);
  }

  // Невозможно закрыть на весь объем определенную MT4-позицию - открывающий позицию MT5-маркет ордер: отсутствует вариант с вызовом OrderDelete.
  // Искусственно воспроизвести такую ситуацию не получилось.
  static bool MT4OrderClose( const long &Ticket, const double &dLots, const double &Price, const int &SlipPage, const color &Arrow_Color, const string &comment )
  {
    // Есть MT4ORDERS::LastTradeRequest и MT4ORDERS::LastTradeResult, поэтому на результат не влияет, но нужно для PositionGetString ниже
    _B2(::PositionSelectByTicket(Ticket));

    ::ZeroMemory(MT4ORDERS::LastTradeRequest);

    MT4ORDERS::LastTradeRequest.action = TRADE_ACTION_DEAL;
    MT4ORDERS::LastTradeRequest.position = Ticket;

    MT4ORDERS::LastTradeRequest.symbol = ::PositionGetString(POSITION_SYMBOL);

    // Сохраняем комментарий при частичном закрытии позиции
//    if (dLots < ::PositionGetDouble(POSITION_VOLUME))
      MT4ORDERS::LastTradeRequest.comment = (comment == NULL) ? ::PositionGetString(POSITION_COMMENT) : comment;

    // Правильно ли не задавать мэджик при закрытии? -Правильно!
    MT4ORDERS::LastTradeRequest.volume = dLots;
    MT4ORDERS::LastTradeRequest.price = Price;

    if (!MT4ORDERS::MTBuildSLTP)
    {
      // Нужно для определения SL/TP-уровней у закрытой позиции. Перевернуто - не ошибка
      // SYMBOL_SESSION_PRICE_LIMIT_MIN и SYMBOL_SESSION_PRICE_LIMIT_MAX проверять не требуется, т.к. исходные SL/TP уже установлены
      MT4ORDERS::LastTradeRequest.tp = ::PositionGetDouble(POSITION_SL);
      MT4ORDERS::LastTradeRequest.sl = ::PositionGetDouble(POSITION_TP);

      if (MT4ORDERS::LastTradeRequest.tp || MT4ORDERS::LastTradeRequest.sl)
      {
        const double StopLevel = ::SymbolInfoInteger(MT4ORDERS::LastTradeRequest.symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                                 ::SymbolInfoDouble(MT4ORDERS::LastTradeRequest.symbol, SYMBOL_POINT);

        const bool FlagBuy = (::PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
        const double CurrentPrice = SymbolInfoDouble(MT4ORDERS::LastTradeRequest.symbol, FlagBuy ? SYMBOL_ASK : SYMBOL_BID);

        if (CurrentPrice)
        {
          if (FlagBuy)
            MT4ORDERS::CheckPrices(MT4ORDERS::LastTradeRequest.tp, MT4ORDERS::LastTradeRequest.sl, CurrentPrice - StopLevel, CurrentPrice + StopLevel);
          else
            MT4ORDERS::CheckPrices(MT4ORDERS::LastTradeRequest.sl, MT4ORDERS::LastTradeRequest.tp, CurrentPrice - StopLevel, CurrentPrice + StopLevel);
        }
        else
        {
          MT4ORDERS::LastTradeRequest.tp = 0;
          MT4ORDERS::LastTradeRequest.sl = 0;
        }
      }
    }

    MT4ORDERS::LastTradeRequest.deviation = SlipPage;

    MT4ORDERS::LastTradeRequest.type = (ENUM_ORDER_TYPE)(1 - ::PositionGetInteger(POSITION_TYPE));

    MT4ORDERS::LastTradeRequest.type_filling = _B2(MT4ORDERS::GetFilling(MT4ORDERS::LastTradeRequest.symbol, (uint)MT4ORDERS::LastTradeRequest.deviation));

    return(MT4ORDERS::NewOrderSend(Arrow_Color));
  }

  static bool MT4OrderCloseBy( const long &Ticket, const long &Opposite, const color &Arrow_Color )
  {
    ::ZeroMemory(MT4ORDERS::LastTradeRequest);

    MT4ORDERS::LastTradeRequest.action = TRADE_ACTION_CLOSE_BY;
    MT4ORDERS::LastTradeRequest.position = Ticket;
    MT4ORDERS::LastTradeRequest.position_by = Opposite;

    if ((!MT4ORDERS::IsTester) && _B2(::PositionSelectByTicket(Ticket))) // нужен для MT4ORDERS::SymbolTrade()
      MT4ORDERS::LastTradeRequest.symbol = ::PositionGetString(POSITION_SYMBOL);

    return(MT4ORDERS::NewOrderSend(Arrow_Color));
  }

  static bool MT4OrderDelete( const long &Ticket, const color &Arrow_Color )
  {
//    bool Res = ::OrderSelect(Ticket); // Надо ли это, когда нужны MT4ORDERS::LastTradeRequest и MT4ORDERS::LastTradeResult ?

    ::ZeroMemory(MT4ORDERS::LastTradeRequest);

    MT4ORDERS::LastTradeRequest.action = TRADE_ACTION_REMOVE;
    MT4ORDERS::LastTradeRequest.order = Ticket;

    if ((!MT4ORDERS::IsTester) && _B2(::OrderSelect(Ticket))) // нужен для MT4ORDERS::SymbolTrade()
      MT4ORDERS::LastTradeRequest.symbol = ::OrderGetString(ORDER_SYMBOL);

    return(MT4ORDERS::NewOrderSend(Arrow_Color));
  }

#define MT4_ORDERFUNCTION(NAME,T,A,B,C)                               \
  static T MT4Order##NAME( void )                                     \
  {                                                                   \
    return(POSITION_ORDER((T)(A), (T)(B), MT4ORDERS::Order.NAME, C)); \
  }

#define POSITION_ORDER(A,B,C,D) (((MT4ORDERS::Order.Ticket == POSITION_SELECT) && (D)) ? (A) : ((MT4ORDERS::Order.Ticket == ORDER_SELECT) ? (B) : (C)))

  MT4_ORDERFUNCTION(Ticket, long, ::PositionGetInteger(POSITION_TICKET), ::OrderGetInteger(ORDER_TICKET), true)
  MT4_ORDERFUNCTION(Type, int, ::PositionGetInteger(POSITION_TYPE), ::OrderGetInteger(ORDER_TYPE), true)
  MT4_ORDERFUNCTION(Lots, double, ::PositionGetDouble(POSITION_VOLUME), ::OrderGetDouble(ORDER_VOLUME_CURRENT), true)
  MT4_ORDERFUNCTION(OpenPrice, double, ::PositionGetDouble(POSITION_PRICE_OPEN), (::OrderGetDouble(ORDER_PRICE_OPEN) ? ::OrderGetDouble(ORDER_PRICE_OPEN) : ::OrderGetDouble(ORDER_PRICE_CURRENT)), true)
  MT4_ORDERFUNCTION(OpenTimeMsc, long, ::PositionGetInteger(POSITION_TIME_MSC), ::OrderGetInteger(ORDER_TIME_SETUP_MSC), true)
  MT4_ORDERFUNCTION(OpenTime, datetime, ::PositionGetInteger(POSITION_TIME), ::OrderGetInteger(ORDER_TIME_SETUP), true)
  MT4_ORDERFUNCTION(StopLoss, double, ::PositionGetDouble(POSITION_SL), ::OrderGetDouble(ORDER_SL), true)
  MT4_ORDERFUNCTION(TakeProfit, double, ::PositionGetDouble(POSITION_TP), ::OrderGetDouble(ORDER_TP), true)
  MT4_ORDERFUNCTION(ClosePrice, double, ::PositionGetDouble(POSITION_PRICE_CURRENT), ::OrderGetDouble(ORDER_PRICE_CURRENT), true)
  MT4_ORDERFUNCTION(CloseTimeMsc, long, 0, 0, true)
  MT4_ORDERFUNCTION(CloseTime, datetime, 0, 0, true)
  MT4_ORDERFUNCTION(Expiration, datetime, 0, ::OrderGetInteger(ORDER_TIME_EXPIRATION), true)
  MT4_ORDERFUNCTION(MagicNumber, long, ::PositionGetInteger(POSITION_MAGIC), ::OrderGetInteger(ORDER_MAGIC), true)
  MT4_ORDERFUNCTION(Profit, double, ::PositionGetDouble(POSITION_PROFIT), 0, true)
  MT4_ORDERFUNCTION(Swap, double, ::PositionGetDouble(POSITION_SWAP), 0, true)
  MT4_ORDERFUNCTION(Symbol, string, ::PositionGetString(POSITION_SYMBOL), ::OrderGetString(ORDER_SYMBOL), true)
  MT4_ORDERFUNCTION(Comment, string, MT4ORDERS::Order.Comment, ::OrderGetString(ORDER_COMMENT), MT4ORDERS::CheckPositionCommissionComment())
  MT4_ORDERFUNCTION(Commission, double, MT4ORDERS::Order.Commission, 0, MT4ORDERS::CheckPositionCommissionComment())

  MT4_ORDERFUNCTION(OpenPriceRequest, double, MT4ORDERS::Order.OpenPriceRequest, ::OrderGetDouble(ORDER_PRICE_OPEN), MT4ORDERS::CheckPositionOpenPriceRequest())
  MT4_ORDERFUNCTION(ClosePriceRequest, double, ::PositionGetDouble(POSITION_PRICE_CURRENT), ::OrderGetDouble(ORDER_PRICE_CURRENT), true)

  MT4_ORDERFUNCTION(TicketOpen, long, MT4ORDERS::Order.TicketOpen, ::OrderGetInteger(ORDER_TICKET), MT4ORDERS::CheckPositionTicketOpen())
//  MT4_ORDERFUNCTION(OpenReason, ENUM_DEAL_REASON, MT4ORDERS::Order.OpenReason, ::OrderGetInteger(ORDER_REASON), MT4ORDERS::CheckPositionOpenReason())
  MT4_ORDERFUNCTION(OpenReason, ENUM_DEAL_REASON, ::PositionGetInteger(POSITION_REASON), ::OrderGetInteger(ORDER_REASON), true)
  MT4_ORDERFUNCTION(CloseReason, ENUM_DEAL_REASON, 0, ::OrderGetInteger(ORDER_REASON), true)
  MT4_ORDERFUNCTION(TicketID, long, ::PositionGetInteger(POSITION_IDENTIFIER), ::OrderGetInteger(ORDER_TICKET), true)
  MT4_ORDERFUNCTION(DealsAmount, int, MT4ORDERS::Order.DealsAmount, 0, MT4ORDERS::CheckPositionTicketOpen())
  MT4_ORDERFUNCTION(LotsOpen, double, ::PositionGetDouble(POSITION_VOLUME), ::OrderGetDouble(ORDER_VOLUME_INITIAL), true)

#undef POSITION_ORDER
#undef MT4_ORDERFUNCTION

  static void MT4OrderPrint( void )
  {
    if (MT4ORDERS::Order.Ticket == POSITION_SELECT)
      MT4ORDERS::CheckPositionCommissionComment();

    ::Print(MT4ORDERS::Order.ToString());

    return;
  }

  static double MT4OrderLots( const bool& )
  {
                 // На случай, если будет решение в пользу целесообразности проверок (OrderLots() != OrderLots(true)).
                 // Такой вариант позволяет не порождать ошибки в OrderClose, но неоднозначен в удобстве во всех сценариях.
    double Res = /*((MT4ORDERS::Order.Ticket == ORDER_SELECT) && (::OrderGetInteger(ORDER_TYPE) <= OP_SELL)) ? 0 :*/ MT4ORDERS::MT4OrderLots();

    if (Res && (MT4ORDERS::Order.Ticket == POSITION_SELECT))
    {
      const ulong PositionID = ::PositionGetInteger(POSITION_IDENTIFIER);

      if (::PositionSelectByTicket(PositionID))
      {
        const int Type = 1 - (int)::PositionGetInteger(POSITION_TYPE);

        double PrevVolume = Res;
        double NewVolume = 0;

        while (Res && (NewVolume != PrevVolume))
        {
        #ifdef MT4ORDERS_BYPASS_MAXTIME
          _B2(MT4ORDERS::ByPass.Waiting());
        #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

          if (::PositionSelectByTicket(PositionID))
          {
            Res = ::PositionGetDouble(POSITION_VOLUME);
            PrevVolume = Res;

            for (int i = ::OrdersTotal() - 1; i >= 0; i--)
              if (!::OrderGetTicket(i)) // Случается при i == ::OrdersTotal() - 1.
              {
                PrevVolume = -1;

                break;
              }
              else if ((::OrderGetInteger(ORDER_POSITION_ID) == PositionID) &&
                       (::OrderGetInteger(ORDER_TYPE) == Type))
                Res -= ::OrderGetDouble(ORDER_VOLUME_CURRENT);
/*
          #ifdef MT4ORDERS_BYPASS_MAXTIME
            _B2(MT4ORDERS::ByPass.Waiting());
          #endif // #ifdef MT4ORDERS_BYPASS_MAXTIME
*/
            if (::PositionSelectByTicket(PositionID))
              NewVolume = ::PositionGetDouble(POSITION_VOLUME);
            else
              Res = 0;
          }
          else
            Res = 0;
        }
      }
      else
        Res = 0;
    }

    return(Res);
  }

#undef ORDER_SELECT
#undef POSITION_SELECT
};

// #define OrderToString MT4ORDERS::MT4OrderToString

static MT4_ORDER MT4ORDERS::Order = {};

static MT4HISTORY MT4ORDERS::History;

static const bool MT4ORDERS::IsTester = ::MQLInfoInteger(MQL_TESTER);

// Если переключить счет, это значение у советников все равно пересчитается
// https://www.mql5.com/ru/forum/170952/page61#comment_6132824
static const bool MT4ORDERS::IsHedging = ((ENUM_ACCOUNT_MARGIN_MODE)::AccountInfoInteger(ACCOUNT_MARGIN_MODE) ==
                                          ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

static const int MT4ORDERS::MTBuildSLTP = (::TerminalInfoInteger(TERMINAL_BUILD) >= 3081); // https://www.mql5.com/ru/forum/378360

static int MT4ORDERS::OrderSendBug = 0;

static uint MT4ORDERS::OrderSend_MaxPause = 1000000; // максимальное время на синхронизацию в мкс.

#ifdef MT4ORDERS_BYPASS_MAXTIME
  static BYPASS MT4ORDERS::ByPass(MT4ORDERS_BYPASS_MAXTIME);
#endif // #ifdef MT4ORDERS_BYPASS_MAXTIME

static MqlTradeResult MT4ORDERS::LastTradeResult = {};
static MqlTradeRequest MT4ORDERS::LastTradeRequest = {};
static MqlTradeCheckResult MT4ORDERS::LastTradeCheckResult = {};

bool OrderClose( const long Ticket, const double dLots, const double Price, const int SlipPage, const color Arrow_Color = clrNONE, const string comment = NULL )
{
  return(MT4ORDERS::MT4OrderClose(Ticket, dLots, Price, SlipPage, Arrow_Color, comment));
}

bool OrderModify( const long Ticket, const double Price, const double SL, const double TP, const datetime Expiration, const color Arrow_Color = clrNONE )
{
  return(MT4ORDERS::MT4OrderModify(Ticket, Price, SL, TP, Expiration, Arrow_Color));
}

bool OrderCloseBy( const long Ticket, const long Opposite, const color Arrow_Color = clrNONE )
{
  return(MT4ORDERS::MT4OrderCloseBy(Ticket, Opposite, Arrow_Color));
}

bool OrderDelete( const long Ticket, const color Arrow_Color = clrNONE )
{
  return(MT4ORDERS::MT4OrderDelete(Ticket, Arrow_Color));
}

void OrderPrint( void )
{
  MT4ORDERS::MT4OrderPrint();

  return;
}

#define MT4_ORDERGLOBALFUNCTION(NAME,T)     \
  T Order##NAME( void )                     \
  {                                         \
    return((T)MT4ORDERS::MT4Order##NAME()); \
  }

MT4_ORDERGLOBALFUNCTION(sHistoryTotal, int)
MT4_ORDERGLOBALFUNCTION(Ticket, TICKET_TYPE)
MT4_ORDERGLOBALFUNCTION(Type, int)
MT4_ORDERGLOBALFUNCTION(Lots, double)
MT4_ORDERGLOBALFUNCTION(OpenPrice, double)
MT4_ORDERGLOBALFUNCTION(OpenTimeMsc, long)
MT4_ORDERGLOBALFUNCTION(OpenTime, datetime)
MT4_ORDERGLOBALFUNCTION(StopLoss, double)
MT4_ORDERGLOBALFUNCTION(TakeProfit, double)
MT4_ORDERGLOBALFUNCTION(ClosePrice, double)
MT4_ORDERGLOBALFUNCTION(CloseTimeMsc, long)
MT4_ORDERGLOBALFUNCTION(CloseTime, datetime)
MT4_ORDERGLOBALFUNCTION(Expiration, datetime)
MT4_ORDERGLOBALFUNCTION(MagicNumber, MAGIC_TYPE)
MT4_ORDERGLOBALFUNCTION(Profit, double)
MT4_ORDERGLOBALFUNCTION(Commission, double)
MT4_ORDERGLOBALFUNCTION(Swap, double)
MT4_ORDERGLOBALFUNCTION(Symbol, string)
MT4_ORDERGLOBALFUNCTION(Comment, string)

MT4_ORDERGLOBALFUNCTION(OpenPriceRequest, double)
MT4_ORDERGLOBALFUNCTION(ClosePriceRequest, double)

MT4_ORDERGLOBALFUNCTION(TicketOpen, TICKET_TYPE)
MT4_ORDERGLOBALFUNCTION(OpenReason, ENUM_DEAL_REASON)
MT4_ORDERGLOBALFUNCTION(CloseReason, ENUM_DEAL_REASON)
MT4_ORDERGLOBALFUNCTION(TicketID, TICKET_TYPE)
MT4_ORDERGLOBALFUNCTION(DealsAmount, int)
MT4_ORDERGLOBALFUNCTION(LotsOpen, double)

#undef MT4_ORDERGLOBALFUNCTION

double OrderLots( const bool Value )
{
  return(MT4ORDERS::MT4OrderLots(Value));
}

// Перегруженные стандартные функции
#define OrdersTotal MT4ORDERS::MT4OrdersTotal // ПОСЛЕ Expert/Expert.mqh - идет вызов MT5-OrdersTotal()

bool OrderSelect( const long Index, const int Select, const int Pool = MODE_TRADES )
{
  return(_B2(MT4ORDERS::MT4OrderSelect(Index, Select, Pool)));
}

TICKET_TYPE OrderSend( const string Symb, const int Type, const double dVolume, const double Price, const int SlipPage, const double SL, const double TP,
                       const string comment = NULL, const MAGIC_TYPE magic = 0, const datetime dExpiration = 0, color arrow_color = clrNONE )
{
  return((TICKET_TYPE)MT4ORDERS::MT4OrderSend(Symb, Type, dVolume, Price, SlipPage, SL, TP, comment, magic, dExpiration, arrow_color));
}

#define RETURN_ASYNC(A) return((A) && ::OrderSendAsync(MT4ORDERS::LastTradeRequest, MT4ORDERS::LastTradeResult) &&                        \
                               (MT4ORDERS::LastTradeResult.retcode == TRADE_RETCODE_PLACED) ? MT4ORDERS::LastTradeResult.request_id : 0);

uint OrderCloseAsync( const long Ticket, const double dLots, const double Price, const int SlipPage, const color Arrow_Color = clrNONE )
{
  RETURN_ASYNC(OrderClose(Ticket, dLots, Price, SlipPage, INT_MAX))
}

uint OrderModifyAsync( const long Ticket, const double Price, const double SL, const double TP, const datetime Expiration, const color Arrow_Color = clrNONE )
{
  RETURN_ASYNC(OrderModify(Ticket, Price, SL, TP, Expiration, INT_MAX))
}

uint OrderDeleteAsync( const long Ticket, const color Arrow_Color = clrNONE )
{
  RETURN_ASYNC(OrderDelete(Ticket, INT_MAX))
}

uint OrderSendAsync( const string Symb, const int Type, const double dVolume, const double Price, const int SlipPage, const double SL, const double TP,
                    const string comment = NULL, const MAGIC_TYPE magic = 0, const datetime dExpiration = 0, color arrow_color = clrNONE )
{
  RETURN_ASYNC(!OrderSend(Symb, Type, dVolume, Price, SlipPage, SL, TP, comment, magic, dExpiration, INT_MAX))
}

#undef RETURN_ASYNC

#undef _BV2
#undef _B3
#undef _B2

#ifdef MT4ORDERS_BENCHMARK_MINTIME
  #undef MT4ORDERS_BENCHMARK_MINTIME
#endif // MT4ORDERS_BENCHMARK_MINTIME

// #undef TICKET_TYPE
#endif // __MT4ORDERS__
#else  // __MQL5__
  #define TICKET_TYPE int
  #define MAGIC_TYPE  int

  TICKET_TYPE OrderTicketID( void ) { return(::OrderTicket()); }
#endif // __MQL5__