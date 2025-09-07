//+------------------------------------------------------------------+
//|                                           AI_Scalper_EA_v2.mq5 |
//|                                                     Manus AI       |
//|                                        (Enhanced by AI Assistant)  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://www.manus.ai"
#property version   "2.00"
#property description "V2: AI-Integrated Scalper with advanced features and robust architecture."

//--- Include new JSON library
#include "Json.mqh"

// --- Start: Manual WinSock Definitions ---
// This block is added to resolve compilation errors when WinSock.mqh is not found.
#import "ws2_32.dll"
int socket(int af, int type, int protocol);
int closesocket(int s);
int connect(int s, const uchar &name[], int namelen);
int send(int s, const uchar &buf[], int len, int flags);
int recv(int s, uchar &buf[], int len, int flags);
ushort htons(ushort hostshort);
uint inet_addr(string cp);
#import

//--- WinSock Constants
#define INVALID_SOCKET -1
#define SOCKET_ERROR -1
#define AF_INET 2
#define SOCK_STREAM 1
// --- End: Manual WinSock Definitions ---

//--- Input parameters
input string         AI_SERVER_IP      = "127.0.0.1";    // IP address of the Python AI server
input int            AI_SERVER_PORT    = 5555;           // Port of the Python AI server
input int            MAGIC_NUMBER      = 67890;          // New magic number for this version
input double         RISK_PER_TRADE    = 0.01;           // Risk per trade as a percentage of balance
input int            MAX_SLIPPAGE_PIPS = 3;              // Maximum allowed slippage in pips

//--- Trading State Management
enum ETradingState
  {
   IDLE,         // Ready to look for a trade
   TRADE_PENDING,// AI signal received, attempting to open a trade
   TRADE_OPEN    // A trade is currently open and being managed
  };
ETradingState g_trading_state = IDLE;

//--- Global variables
int      g_socket = INVALID_SOCKET; // Socket handle
string   g_symbol;                  // Current symbol
double   g_point;                   // Point value of the symbol
double   g_min_lot;                 // Minimum allowed lot size
double   g_lot_step;                // Lot step
double   g_tick_value;              // Value of a tick for risk calculation
int      g_atr_handle;              // Handle for the ATR indicator

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
   
   //--- Get indicator handles
   g_atr_handle = iATR(g_symbol, PERIOD_M1, 14);

   //--- Initialize socket connection
   if(!ConnectToAIServer())
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
   //--- Close socket connection
   if(g_socket != INVALID_SOCKET)
     {
      closesocket(g_socket); // Use direct DLL call
      g_socket = INVALID_SOCKET;
      Print("Socket connection closed.");
     }
   
   //--- Release indicator handles
   if(g_atr_handle != INVALID_HANDLE)
      IndicatorRelease(g_atr_handle);
      
   Print("EA Deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Update the trading state based on open positions
   UpdateTradingState();

   //--- If we are not idle, no need to check for new bars/signals
   if(g_trading_state != IDLE)
      return;
      
   static datetime last_bar_time = 0;
   MqlRates rates[];

   //--- Check for new 1-minute bar
   if(CopyRates(g_symbol, PERIOD_M1, 0, 1, rates) > 0)
     {
      if(rates[0].time != last_bar_time)
        {
         last_bar_time = rates[0].time;
         //--- Switched to a new function for clarity
         ProcessSignalOnNewBar();
        }
     }
  }

//+------------------------------------------------------------------+
//| Trade Transaction Function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   //--- Check if the transaction is relevant to this EA
   if(request.magic != MAGIC_NUMBER && trans.order != 0)
     {
      // If we can get order properties, check its magic number too
      if(OrderSelect(trans.order))
      {
         if(OrderGetInteger(ORDER_MAGIC) != MAGIC_NUMBER) return;
      }
      else return; // Not our transaction if we can't select it or it's not ours
     }

   //--- Check the type of transaction
   switch(trans.type)
     {
      //--- A deal has been executed (position opened, closed, reversed, etc.)
      case TRADE_TRANSACTION_DEAL_ADD:
         // This is a reliable point to re-evaluate the overall state.
         // The previous check was incorrect; checking the transaction type is sufficient.
         UpdateTradingState();
         Print("Deal executed. New State: ", EnumToString(g_trading_state));
         break;
      
      //--- A position was closed
      case TRADE_TRANSACTION_POSITION:
         if(trans.position == 0) // Position is closed
         {
            g_trading_state = IDLE;
            Print("Position closed. State reset to IDLE.");
         }
         break;
         
       //--- An order was placed
       case TRADE_TRANSACTION_ORDER_ADD:
         g_trading_state = TRADE_PENDING;
         Print("Order added. State changed to TRADE_PENDING.");
         break;
         
       //--- An order was removed (filled, expired, cancelled)
       case TRADE_TRANSACTION_ORDER_DELETE:
          UpdateTradingState(); // Re-evaluate state
          Print("Order removed. New State: ", EnumToString(g_trading_state));
          break;
     }
  }

//+------------------------------------------------------------------+
//| Updates the global trading state based on open positions         |
//+------------------------------------------------------------------+
void UpdateTradingState()
  {
   int open_positions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == g_symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER)
        {
         open_positions++;
        }
     }

   if(open_positions > 0)
     {
      if(g_trading_state != TRADE_OPEN)
        {
         g_trading_state = TRADE_OPEN;
         Print("Active trade found. State set to TRADE_OPEN.");
        }
     }
   else
     {
       // Don't switch to IDLE if we are waiting for an order to be filled
       if(g_trading_state != TRADE_PENDING)
       {
          g_trading_state = IDLE;
       }
     }
  }

//+------------------------------------------------------------------+
//| Process signal on a new bar.                                     |
//+------------------------------------------------------------------+
void ProcessSignalOnNewBar()
  {
   Print("Processing new bar for potential signal...");

   //--- 1. Create the feature-rich payload for the AI
   string payload = CreateFeaturePayload();
   if(payload == "")
     {
      Print("Failed to create feature payload. Aborting.");
      return;
     }
      
   Print("Sending data to AI: ", payload);

   //--- 2. Send data to AI server and get response
   string ai_response = SendDataToAI(payload);

   if(ai_response != "")
     {
      Print("AI Response: ", ai_response);
      //--- 3. Parse AI response and execute trade
      ExecuteTrade(ai_response);
     }
   else
     {
      Print("No response from AI server.");
     }
  }

//+------------------------------------------------------------------+
//| Creates the JSON payload with advanced features for the AI.      |
//+------------------------------------------------------------------+
string CreateFeaturePayload()
  {
   CJson payload;

   //--- Basic Info
   payload.Add("symbol", g_symbol);
   
   //--- Get Current Bar and History
   MqlRates current_bar[];
   MqlRates history[20];
   if(CopyRates(g_symbol, PERIOD_M1, 0, 1, current_bar) <= 0 || CopyRates(g_symbol, PERIOD_M1, 1, 20, history) < 20)
     {
      Print("Failed to get rate data.");
      return "";
     }
   
   //--- Add Current Price
   double current_price = current_bar[0].close;
   payload.Add("current_price", current_price, _Digits);

   //--- Feature: Volatility (ATR)
   double atr_buffer[];
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr_buffer) > 0)
     {
      payload.Add("volatility_atr", atr_buffer[0] / g_point, 2);
     }

   //--- Feature: Key Level Proximity
   MqlRates daily_bars[];
   if(CopyRates(g_symbol, PERIOD_D1, 0, 1, daily_bars) > 0)
     {
      double daily_high = daily_bars[0].high;
      double daily_low = daily_bars[0].low;
      payload.Add("proximity_to_daily_high", MathAbs(daily_high - current_price) / g_point, 2);
      payload.Add("proximity_to_daily_low", MathAbs(daily_low - current_price) / g_point, 2);
     }
   
   //--- Feature: Nearest Round Number
   double round_number_increment = g_point * 100; // e.g., for EURUSD 0.0001 * 100 = 0.01
   if(_Digits == 3 || _Digits == 5) round_number_increment = g_point * 1000;
   double nearest_round_number = round(current_price / round_number_increment) * round_number_increment;
   payload.Add("nearest_round_number", nearest_round_number, _Digits);

   //--- Feature: Relative Volume
   long total_volume = 0;
   for(int i = 0; i < 20; i++) { total_volume += history[i].tick_volume; }
   double avg_volume = total_volume / 20.0;
   if(avg_volume > 0)
     {
      double relative_volume = (current_bar[0].tick_volume / avg_volume) * 100.0;
      payload.Add("relative_volume", relative_volume, 2);
     }

   //--- Add Current Bar data
   CJson current_bar_json;
   current_bar_json.Add("time", (long)current_bar[0].time);
   current_bar_json.Add("open", current_bar[0].open, _Digits);
   current_bar_json.Add("high", current_bar[0].high, _Digits);
   current_bar_json.Add("low", current_bar[0].low, _Digits);
   current_bar_json.Add("close", current_bar[0].close, _Digits);
   current_bar_json.Add("tick_volume", (long)current_bar[0].tick_volume);
   payload.Add("current_bar", current_bar_json);

   //--- Add Historical Data
   CJAVal history_array;
   for(int i = 0; i < 20; i++)
     {
      CJson bar_data;
      bar_data.Add("time", (long)history[i].time);
      bar_data.Add("open", history[i].open, _Digits);
      bar_data.Add("high", history[i].high, _Digits);
      bar_data.Add("low", history[i].low, _Digits);
      bar_data.Add("close", history[i].close, _Digits);
      bar_data.Add("tick_volume", (long)history[i].tick_volume);
      history_array.Add(bar_data);
     }
   payload.Add("history", history_array);

   return payload.ToString();
  }

//+------------------------------------------------------------------+
//| Connect to AI Server (using direct DLL calls)                    |
//+------------------------------------------------------------------+
bool ConnectToAIServer()
  {
   g_socket = socket(AF_INET, SOCK_STREAM, 0); // Use direct DLL call
   if(g_socket == INVALID_SOCKET)
     {
      Print("socket failed, error: ", GetLastError());
      return false;
     }

   //--- Prepare the sockaddr_in structure
   struct sockaddr_in
     {
      short          sin_family;
      ushort         sin_port;
      uint           sin_addr;
      char           sin_zero[8];
     };
   sockaddr_in server_addr;
   server_addr.sin_family = AF_INET;
   server_addr.sin_port = htons((ushort)AI_SERVER_PORT); // Cast to ushort to resolve warning
   server_addr.sin_addr = inet_addr(AI_SERVER_IP);

   //--- Convert struct to uchar array for connect function using the proper MQL5 function
   uchar address[];
   StructToCharArray(server_addr, address);

   if(connect(g_socket, address, sizeof(sockaddr_in)) != 0) // Use direct DLL call
     {
      Print("connect failed, error: ", GetLastError());
      closesocket(g_socket); // Use direct DLL call
      g_socket = INVALID_SOCKET;
      return false;
     }
   Print("Connected to AI server at ", AI_SERVER_IP, ":", AI_SERVER_PORT);
   return true;
  }

//+------------------------------------------------------------------+
//| Send Data to AI Server and get response                          |
//+------------------------------------------------------------------+
string SendDataToAI(string data)
  {
   if(g_socket == INVALID_SOCKET)
     {
      Print("Socket not connected. Attempting to reconnect...");
      if(!ConnectToAIServer()) return "";
     }

   //--- Send data
   char data_bytes[];
   int data_len = StringToCharArray(data, data_bytes, 0, -1, CP_UTF8) - 1; // -1 to exclude null terminator
   uchar u_data_bytes[];
   ArrayResize(u_data_bytes, data_len);
   ArrayCopy(u_data_bytes, data_bytes, 0, 0, data_len);

   if(send(g_socket, u_data_bytes, data_len, 0) == SOCKET_ERROR)
     {
      Print("send failed, error: ", GetLastError());
      closesocket(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }

   //--- Receive response
   uchar u_buffer[];
   ArrayResize(u_buffer, 4096); // Max response size
   int bytes_received = recv(g_socket, u_buffer, ArraySize(u_buffer), 0);
   if(bytes_received > 0)
     {
      char buffer[];
      ArrayResize(buffer, bytes_received);
      ArrayCopy(buffer, u_buffer, 0, 0, bytes_received);
      return CharArrayToString(buffer, 0, bytes_received, CP_UTF8);
     }
   else if(bytes_received == 0)
     {
      Print("AI server closed connection.");
      closesocket(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }
   else // bytes_received < 0 (is SOCKET_ERROR)
     {
      Print("recv failed, error: ", GetLastError());
      closesocket(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }
  }

//+------------------------------------------------------------------+
//| Execute Trade - Uses AI response for dynamic risk management     |
//+------------------------------------------------------------------+
void ExecuteTrade(string ai_response)
  {
   //--- 1. Parse the JSON response
   string signal = JsonGetValue(ai_response, "signal");
   double entry_price = StringToDouble(JsonGetValue(ai_response, "entry"));
   double stop_loss = StringToDouble(JsonGetValue(ai_response, "sl"));
   double take_profit = StringToDouble(JsonGetValue(ai_response, "tp"));
   
   //--- 2. Validate the signal and data from AI
   if(signal != "BUY" && signal != "SELL")
     {
      Print("AI signal is '", signal, "'. No trade will be executed.");
      return;
     }
   if(stop_loss == 0 || take_profit == 0)
     {
      Print("Invalid SL/TP from AI. Aborting trade.");
      return;
     }

   //--- Determine order type
   ENUM_ORDER_TYPE order_type = (signal == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   //--- 3. Calculate Lot Size based on Dynamic Risk (AI-provided SL)
   double stop_loss_pips = MathAbs(entry_price - stop_loss) / g_point;
   if(stop_loss_pips < 1) // Prevent division by zero or tiny SL
   {
      Print("Stop loss distance is too small (", stop_loss_pips, " pips). Aborting trade.");
      return;
   }
   
   //--- More robust lot calculation using Tick Value
   double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * RISK_PER_TRADE;
   double sl_monetary_value_per_lot = stop_loss_pips * g_tick_value;
   double lot_size = NormalizeLot(risk_amount / sl_monetary_value_per_lot);

   if(lot_size < g_min_lot)
     {
      Print("Calculated lot size (", lot_size, ") is below minimum. Aborting trade.");
      return;
     }
   
   Print("Trade Execution Details:");
   Print("Signal: ", signal);
   Print("Lot Size: ", lot_size, " (Risk ", RISK_PER_TRADE * 100, "%)");
   Print("Entry: ", DoubleToString(entry_price, _Digits));
   Print("SL: ", DoubleToString(stop_loss, _Digits), " (", stop_loss_pips, " pips)");
   Print("TP: ", DoubleToString(take_profit, _Digits));

   //--- 4. Populate and Send the Trade Request
   MqlTradeRequest request;
   MqlTradeResult  result;

   ZeroMemory(request);
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = g_symbol;
   request.volume       = lot_size;
   request.price        = NormalizeDouble(SymbolInfoDouble(g_symbol, (order_type == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID), _Digits);
   request.deviation    = MAX_SLIPPAGE_PIPS;
   request.type         = order_type;
   request.type_filling = ORDER_FILLING_FOK;
   request.magic        = MAGIC_NUMBER;
   request.sl           = NormalizeDouble(stop_loss, _Digits);
   request.tp           = NormalizeDouble(take_profit, _Digits);

   //--- Set state to PENDING before sending order
   g_trading_state = TRADE_PENDING;
   Print("State set to TRADE_PENDING. Sending order...");

   if(!OrderSend(request, result))
     {
      PrintFormat("OrderSend failed for %s %s: retcode=%u, comment=%s",
                  g_symbol, EnumToString(order_type), result.retcode, result.comment);
      // If order failed, reset state to allow new signals
      g_trading_state = IDLE;
     }
   else
     {
      PrintFormat("OrderSend successful for %s %s: Deal #%I64u, Order #%I64u",
                  g_symbol, EnumToString(order_type), result.deal, result.order);
     }
  }

//+------------------------------------------------------------------+
//| Normalize Lot Size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   if(lot < g_min_lot) lot = g_min_lot;
   double lots = floor(lot / g_lot_step) * g_lot_step;
   return(lots);
  }
//+------------------------------------------------------------------+


