//+------------------------------------------------------------------+
//|                                           AI_Scalper_EA_v2.1.mq5 |
//|                                                     Manus AI       |
//|                                   (Refactored by AI Assistant)     |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://www.manus.ai"
#property version   "2.1"
#property description "V2.1: Implements full feature vector, robust JSON parsing, and hardened state/risk management."

//--- Included Libraries
#include "Json.mqh" // Production-grade JSON handling

// --- TCP/IP Socket Wrapper Class ---
#import "ws2_32.dll"
int socket(int af, int type, int protocol);
int closesocket(int s);
int connect(int s, const uchar &name[], int namelen);
int send(int s, const uchar &buf[], int len, int flags);
int recv(int s, uchar &buf[], int len, int flags);
ushort htons(ushort hostshort);
uint inet_addr(string cp);
#import

#define INVALID_SOCKET -1
#define SOCKET_ERROR -1
#define AF_INET 2
#define SOCK_STREAM 1
#define CP_UTF8 65001

class CTCPSocket
  {
private:
   int m_socket;
   string m_ip;
   int m_port;

public:
                     CTCPSocket() : m_socket(INVALID_SOCKET), m_ip(""), m_port(0) {}
                    ~CTCPSocket() { Disconnect(); }

   bool              Connect(string ip, int port)
     {
      m_ip = ip;
      m_port = port;
      m_socket = socket(AF_INET, SOCK_STREAM, 0);
      if(m_socket == INVALID_SOCKET)
        {
         Print("socket() failed, error: ", GetLastError());
         return false;
        }

      struct sockaddr_in
        {
         short          sin_family;
         ushort         sin_port;
         uint           sin_addr;
         char           sin_zero[8];
        };
      sockaddr_in server_addr;
      server_addr.sin_family = AF_INET;
      server_addr.sin_port = htons((ushort)m_port);
      server_addr.sin_addr = inet_addr(m_ip);

      uchar address[];
      StructToCharArray(server_addr, address);

      if(connect(m_socket, address, sizeof(sockaddr_in)) != 0)
        {
         Print("connect() failed, error: ", GetLastError());
         closesocket(m_socket);
         m_socket = INVALID_SOCKET;
         return false;
        }
      return true;
     }

   void              Disconnect()
     {
      if(m_socket != INVALID_SOCKET)
        {
         closesocket(m_socket);
         m_socket = INVALID_SOCKET;
        }
     }

   string            SendRequest(string data)
     {
      if(m_socket == INVALID_SOCKET)
        {
         Print("Socket not connected. Cannot send request.");
         return "";
        }
      char data_bytes[];
      StringToCharArray(data, data_bytes, 0, -1, CP_UTF8);
      int data_len = ArraySize(data_bytes) - 1;

      uchar u_data_bytes[];
      ArrayCopy(u_data_bytes, data_bytes, 0, 0, data_len);

      if(send(m_socket, u_data_bytes, data_len, 0) == SOCKET_ERROR)
        {
         Print("send() failed, error: ", GetLastError());
         Disconnect();
         return "";
        }

      uchar u_buffer[4096];
      int bytes_received = recv(m_socket, u_buffer, 4096, 0);
      if(bytes_received > 0)
        {
         return CharArrayToString(u_buffer, 0, bytes_received, CP_UTF8);
        }
      else
        {
         Print("recv() failed or connection closed by server. Error: ", GetLastError());
         Disconnect();
         return "";
        }
     }

   bool IsConnected() { return m_socket != INVALID_SOCKET; }
  };
//--- End of TCP Wrapper ---


//--- Input parameters
input string         AI_SERVER_IP      = "127.0.0.1";    // IP address of the Python AI server
input int            AI_SERVER_PORT    = 5555;           // Port of the Python AI server
input int            MAGIC_NUMBER      = 67890;          // Magic number for this version
input double         RISK_PER_TRADE    = 0.01;           // Risk per trade as a percentage of balance
input uint           MAX_SLIPPAGE_PIPS = 3;              // Maximum allowed slippage in pips

//--- Trading State Management
enum ETradingState
  {
   IDLE,           // Ready to look for a trade
   TRADE_PENDING,  // Order sent, waiting for confirmation
   TRADE_OPEN      // A trade is currently open
  };
ETradingState g_trading_state = IDLE;

//--- Global variables
CTCPSocket g_socket;                 // Socket class instance
string     g_symbol;                 // Current symbol
double     g_point;                  // Point value of the symbol
double     g_min_lot;                // Minimum allowed lot size
double     g_lot_step;               // Lot step
double     g_tick_value;             // Value of a tick for risk calculation
int        g_atr_handle;             // Handle for the ATR indicator
int        g_rsi_handle;             // Handle for the RSI indicator
int        g_stoch_handle;           // Handle for the Stochastic indicator

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = Symbol();
   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   g_lot_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
   g_tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
   if(g_tick_value == 0) // Fallback for indices/unusual symbols
      g_tick_value = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);

   //--- Get indicator handles
   g_atr_handle = iATR(g_symbol, PERIOD_M1, 14);
   g_rsi_handle = iRSI(g_symbol, PERIOD_M1, 14, PRICE_CLOSE);
   g_stoch_handle = iStochastic(g_symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);

   //--- Initialize socket connection
   if(!g_socket.Connect(AI_SERVER_IP, AI_SERVER_PORT))
     {
      Print("Failed to connect to AI server. EA will not function.");
      return INIT_FAILED;
     }

   //--- Set initial trading state
   UpdateTradingState();
   Print("EA Initialized. Current State: ", EnumToString(g_trading_state));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_socket.Disconnect();
   Print("Socket connection closed.");

   IndicatorRelease(g_atr_handle);
   IndicatorRelease(g_rsi_handle);
   IndicatorRelease(g_stoch_handle);

   Print("EA Deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Only check for signals if we are IDLE and ready
   if(g_trading_state != IDLE)
      return;

   static datetime last_bar_time = 0;
   MqlRates rates[];

   if(CopyRates(g_symbol, PERIOD_M1, 0, 1, rates) > 0)
     {
      if(rates[0].time != last_bar_time)
        {
         last_bar_time = rates[0].time;
         ProcessSignalOnNewBar();
        }
     }
  }

//+------------------------------------------------------------------+
//| Trade Transaction Function - The single point for state changes  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   //--- Filter out irrelevant transactions
   if(request.magic != MAGIC_NUMBER)
      return;
      
   //--- A successful order has become a position or a position was closed
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_POSITION)
     {
      UpdateTradingState();
     }
  }

//+------------------------------------------------------------------+
//| Updates the global trading state. This is our source of truth.   |
//+------------------------------------------------------------------+
void UpdateTradingState()
  {
   int open_positions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionSelectByTicket(PositionGetTicket(i)) && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
         open_positions++;
        }
     }

   if(open_positions > 0)
     {
      g_trading_state = TRADE_OPEN;
     }
   else
     {
      // If we are not waiting for an order to be filled, we are idle
      if(g_trading_state != TRADE_PENDING)
         g_trading_state = IDLE;
     }
  }
  
//+------------------------------------------------------------------+
//| Main logic block for a new bar.                                  |
//+------------------------------------------------------------------+
void ProcessSignalOnNewBar()
  {
   string payload = CreateFeaturePayloadJSON();
   if(payload == "")
     {
      Print("Failed to create feature payload.");
      return;
     }

   if(!g_socket.IsConnected())
   {
      Print("Socket disconnected. Attempting to reconnect...");
      if(!g_socket.Connect(AI_SERVER_IP, AI_SERVER_PORT))
      {
         Print("Reconnect failed.");
         return;
      }
      Print("Reconnect successful.");
   }
   
   string ai_response_str = g_socket.SendRequest(payload);
   
   if(ai_response_str != "")
     {
      Print("AI Response: ", ai_response_str);
      ExecuteTrade(ai_response_str);
     }
   else
     {
      Print("No valid response from AI server.");
     }
  }

//+------------------------------------------------------------------+
//| Creates the JSON payload with the full ML model feature set.     |
//+------------------------------------------------------------------+
string CreateFeaturePayloadJSON()
  {
   CJson payload;
   MqlRates current_bar[];
   if(CopyRates(g_symbol, PERIOD_M1, 0, 1, current_bar) <= 0) return "";
   
   double close = current_bar[0].close;
   double open = current_bar[0].open;
   double high = current_bar[0].high;
   double low = current_bar[0].low;

   //--- Basic Info
   payload.Add("symbol", g_symbol);
   payload.Add("current_price", close, _Digits);

   //--- Feature Set
   double buffer[];

   if(CopyBuffer(g_atr_handle, 0, 0, 1, buffer) > 0) payload.Add("volatility_atr", buffer[0]);
   if(CopyBuffer(g_rsi_handle, 0, 0, 1, buffer) > 0) payload.Add("momentum_rsi", buffer[0]);
   if(CopyBuffer(g_stoch_handle, 0, 0, 1, buffer) > 0) payload.Add("momentum_stoch_k", buffer[0]); // MAIN_LINE is %K
   if(CopyBuffer(g_stoch_handle, 1, 0, 1, buffer) > 0) payload.Add("momentum_stoch_d", buffer[0]); // SIGNAL_LINE is %D

   // Candle Body/Range Ratio
   double range = high - low;
   if(range > 0) payload.Add("price_action_body_ratio", (close - open) / range);

   // Distance from 20-period EMA
   double ema20_array[];
   if(CopyBuffer(iMA(g_symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE), 0, 0, 1, ema20_array) > 0)
      payload.Add("relative_price_dist_ema20", (close - ema20_array[0])/g_point);

   // Relative Volume
   long volume_history[20];
   if(CopyTickVolume(g_symbol, PERIOD_M1, 1, 20, volume_history) > 0)
     {
      long total_volume = 0;
      for(int i = 0; i < 20; i++) total_volume += volume_history[i];
      double avg_volume = total_volume / 20.0;
      if(avg_volume > 0) payload.Add("relative_volume", (current_bar[0].tick_volume / avg_volume));
     }
   
   // Key Level Proximity
   MqlRates daily_bars[];
   if(CopyRates(g_symbol, PERIOD_D1, 0, 1, daily_bars) > 0)
     {
      payload.Add("proximity_to_daily_high", (daily_bars[0].high - close) / g_point);
      payload.Add("proximity_to_daily_low", (close - daily_bars[0].low) / g_point);
     }
     
   return payload.ToString();
  }

//+------------------------------------------------------------------+
//| Parses AI response and executes the trade.                       |
//+------------------------------------------------------------------+
void ExecuteTrade(string ai_response)
  {
   // The Json.mqh library uses a standalone function for parsing simple key-value pairs.
   // It does not "load" the string into a CJson object.
   if(StringLen(ai_response) == 0)
     {
      Print("Cannot execute trade, AI response is empty.");
      return;
     }

   string signal = JsonGetValue(ai_response, "signal");
   if(signal != "BUY" && signal != "SELL")
     {
      Print("AI signal is '", signal, "'. No trade. Full response: ", ai_response);
      return;
     }
     
   double entry_price = StringToDouble(JsonGetValue(ai_response, "entry"));
   double stop_loss = StringToDouble(JsonGetValue(ai_response, "sl"));
   double take_profit = StringToDouble(JsonGetValue(ai_response, "tp"));
   
   if(stop_loss == 0 || take_profit == 0)
     {
      Print("Invalid SL/TP from AI. Aborting trade.");
      return;
     }

   ENUM_ORDER_TYPE order_type = (signal == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   double stop_loss_distance_pips = MathAbs(entry_price - stop_loss) / g_point;
   if(stop_loss_distance_pips < 1)
     {
      Print("Stop loss distance is too small (", stop_loss_distance_pips, " pips). Aborting trade.");
      return;
     }
     
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * RISK_PER_TRADE;
   double loss_per_lot = stop_loss_distance_pips * g_tick_value;
   if(loss_per_lot <= 0)
   {
      Print("Invalid SL monetary value. Cannot calculate lot size. Check Tick Value.");
      return;
   }
   double lot_size = NormalizeLot(risk_amount / loss_per_lot);

   if(lot_size < g_min_lot)
     {
      Print("Calculated lot size (", lot_size, ") is below minimum. Aborting trade.");
      return;
     }
     
   Print("Attempting to execute trade: ", signal);

   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = g_symbol;
   request.volume       = lot_size;
   request.price        = NormalizeDouble(SymbolInfoDouble(g_symbol, order_type == ORDER_TYPE_BUY ? SYMBOL_ASK : SYMBOL_BID), _Digits);
   request.deviation    = (uint)MAX_SLIPPAGE_PIPS;
   request.type         = order_type;
   request.type_filling = ORDER_FILLING_FOK;
   request.magic        = MAGIC_NUMBER;
   request.sl           = NormalizeDouble(stop_loss, _Digits);
   request.tp           = NormalizeDouble(take_profit, _Digits);

   g_trading_state = TRADE_PENDING;
   
   if(!OrderSend(request, result))
     {
      PrintFormat("OrderSend failed. RetCode: %u, Comment: %s", result.retcode, result.comment);
      g_trading_state = IDLE; // Reset state on failure
     }
   else
     {
      PrintFormat("OrderSend successful. Deal #%I64u, Order #%I64u", result.deal, result.order);
      // State will be updated to TRADE_OPEN by OnTradeTransaction
     }
  }

//+------------------------------------------------------------------+
//| Normalize Lot Size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double rounded_lot = floor(lot / g_lot_step) * g_lot_step;
   return(fmax(g_min_lot, rounded_lot));
  }
//+------------------------------------------------------------------+