//+------------------------------------------------------------------+
//| Custom Trade Record Structure                                    |
//+------------------------------------------------------------------+
struct TradeRecord
{
   ulong             ticket;
   ENUM_POSITION_TYPE position_type;
   datetime          open_time;
   datetime          close_time;
   double            volume;
   double            open_price;
   double            close_price;
   bool              is_closed;

   // Constructor
   TradeRecord(ulong tkt, ENUM_POSITION_TYPE type, datetime open_time, double volume, double open_price)
   {
      ticket        = tkt;
      position_type = type;
      this.open_time  = open_time;
      this.volume     = volume;
      this.open_price = open_price;
      close_time    = 0;
      close_price   = 0;
      is_closed     = false;
   }
};

//+------------------------------------------------------------------+
//| Trade History Manager Class                                      |
//+------------------------------------------------------------------+
class TradeHistoryManager
{
private:
   // Array to store trade records
   CArrayObj trade_history;

public:
   // Constructor
   TradeHistoryManager(){ LoadHistory(); }

   // Destructor
   ~TradeHistoryManager(){ SaveHistory(); }

   // Add a new trade record
   void AddTrade(TradeRecord* trade)
   {
      trade_history.Add(trade);
      SaveHistory(); // Save after each update
   }

   // Update a trade record when it closes
   void UpdateTrade(ulong ticket, datetime close_time, double close_price)
   {
      for(int i = 0; i < trade_history.Total(); i++)
      {
         TradeRecord* record = (TradeRecord*)trade_history.At(i);
         if(record.ticket == ticket && !record.is_closed)
         {
            record.close_time  = close_time;
            record.close_price = close_price;
            record.is_closed   = true;
            SaveHistory(); // Save after each update
            break;
         }
      }
   }

   // Get the last trade record
   TradeRecord* GetLastTrade()
   {
      if(trade_history.Total() > 0)
         return (TradeRecord*)trade_history.At(trade_history.Total() - 1);
      else
         return NULL;
   }

   // Save history to a file for persistence
   void SaveHistory()
   {
      int file_handle = FileOpen("TradeHistory.bin", FILE_BIN|FILE_WRITE|FILE_ANSI);
      if(file_handle != INVALID_HANDLE)
      {
         int total = trade_history.Total();
         FileWriteInteger(file_handle, total, LONG_VALUE);

         for(int i = 0; i < total; i++)
         {
            TradeRecord* record = (TradeRecord*)trade_history.At(i);
            // Write each member variable
            FileWriteInteger(file_handle, record.ticket, LONG_VALUE);
            FileWriteInteger(file_handle, (int)record.position_type, INT_VALUE);
            FileWriteDatetime(file_handle, record.open_time);
            FileWriteDouble(file_handle, record.volume);
            FileWriteDouble(file_handle, record.open_price);
            FileWriteDatetime(file_handle, record.close_time);
            FileWriteDouble(file_handle, record.close_price);
            FileWriteInteger(file_handle, record.is_closed ? 1 : 0, INT_VALUE);
         }
         FileClose(file_handle);
      }
   }

   // Load history from a file
   void LoadHistory()
   {
      int file_handle = FileOpen("TradeHistory.bin", FILE_BIN|FILE_READ|FILE_ANSI);
      if(file_handle != INVALID_HANDLE)
      {
         int total = (int)FileReadInteger(file_handle, LONG_VALUE);

         for(int i = 0; i < total; i++)
         {
            ulong ticket = (ulong)FileReadInteger(file_handle, LONG_VALUE);
            ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)FileReadInteger(file_handle, INT_VALUE);
            datetime open_time = FileReadDatetime(file_handle);
            double volume = FileReadDouble(file_handle);
            double open_price = FileReadDouble(file_handle);
            datetime close_time = FileReadDatetime(file_handle);
            double close_price = FileReadDouble(file_handle);
            bool is_closed = FileReadInteger(file_handle, INT_VALUE) == 1;

            // Recreate the TradeRecord object
            TradeRecord* record = new TradeRecord(ticket, position_type, open_time, volume, open_price);
            record.close_time = close_time;
            record.close_price = close_price;
            record.is_closed = is_closed;

            trade_history.Add(record);
         }
         FileClose(file_handle);
      }
   }
};

// Create an instance of the history manager
static TradeHistoryManager history_manager;

// A new position was opened
ENUM_POSITION_TYPE pos_type = (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_BUY_LIMIT || deal_type == DEAL_TYPE_BUY_STOP) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
TradeRecord* new_trade = new TradeRecord(position_id, pos_type, deal.time, deal.volume, deal.price);
history_manager.AddTrade(new_trade);

// A position was closed
history_manager.UpdateTrade(position_id, deal.time, deal.price);
