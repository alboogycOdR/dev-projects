//+------------------------------------------------------------------+
//|                                                  AI_Scalper_EA.mq5 |
//|                                                     Manus AI       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://www.manus.ai"
#property version   "1.00"
#property description "AI-Integrated Scalping EA for 1-Minute Forex"

//--- Input parameters
input string         AI_SERVER_IP      = "localhost";    // IP address of the Python AI server
input int            AI_SERVER_PORT    = 5555;           // Port of the Python AI server
input int            MAGIC_NUMBER      = 12345;          // Magic number for trades
input double         RISK_PER_TRADE    = 0.01;           // Risk per trade as a percentage of balance
input int            MAX_SLIPPAGE_PIPS = 3;              // Maximum allowed slippage in pips
input int            TP_PIPS_DEFAULT   = 5;              // Default Take Profit in pips (if AI doesn't provide)
input int            SL_PIPS_DEFAULT   = 10;             // Default Stop Loss in pips (if AI doesn't provide)

//--- Include ZeroMQ library (assuming it's available in MQL5 includes or added manually)
// You would typically need a ZeroMQ wrapper for MQL5. For demonstration, we'll assume
// a function `SendZMQMessage` and `ReceiveZMQMessage` exist.
// For a real implementation, you'd use a pre-compiled ZeroMQ library for MQL5 or a custom TCP/IP communication.
// Example of a basic TCP/IP communication (simplified for concept):
#include <WinSock.mqh> // For basic TCP/IP communication (Windows specific)

//--- Global variables
int      g_socket = INVALID_SOCKET; // Socket handle
string   g_symbol;                  // Current symbol
double   g_point;                   // Point value of the symbol
double   g_min_lot;                 // Minimum allowed lot size
double   g_lot_step;                // Lot step

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_symbol = Symbol();
   g_point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   g_min_lot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   g_lot_step = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

   //--- Initialize socket connection (simplified for concept)
   // In a real scenario, you'd handle connection/reconnection robustly
   if(!ConnectToAIServer())
     {
      Print("Failed to connect to AI server. EA will not function.");
      return INIT_FAILED;
     }

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
      closesocket(g_socket);
      g_socket = INVALID_SOCKET;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime last_bar_time = 0;
   MqlRates rates[];

   //--- Check for new 1-minute bar
   if(CopyRates(g_symbol, PERIOD_M1, 0, 1, rates) == 1)
     {
      if(rates[0].time != last_bar_time)
        {
         last_bar_time = rates[0].time;
         ProcessNewBar(rates[0]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Process new 1-minute bar                                         |
//+------------------------------------------------------------------+
void ProcessNewBar(const MqlRates& new_bar)
  {
   //--- Get historical data for AI input (e.g., last 20 bars)
   MqlRates history_rates[20];
   if(CopyRates(g_symbol, PERIOD_M1, 1, 20, history_rates) != 20)
     {
      Print("Failed to get historical data.");
      return;
     }

   //--- Prepare data for AI (example: simple JSON string)
   string data_for_ai = "{\"symbol\":\"" + g_symbol + "\",";
   data_for_ai += "\"current_bar\":{\"time\":


new_bar.time + ",\"open\":

new_bar.open + ",\"high\":" + new_bar.high + ",\"low\":" + new_bar.low + ",\"close\":" + new_bar.close + ",\"tick_volume\":" + new_bar.tick_volume + "},";
   data_for_ai += "\"history\":[";
   for(int i = 0; i < 20; i++)
     {
      data_for_ai += "{\"time\":" + history_rates[i].time + ",\"open\":" + history_rates[i].open + ",\"high\":" + history_rates[i].high + ",\"low\":" + history_rates[i].low + ",\"close\":" + history_rates[i].close + ",\"tick_volume\":" + history_rates[i].tick_volume + "}";
      if(i < 19) data_for_ai += ",";
     }
   data_for_ai += "]}";

   Print("Sending data to AI: ", data_for_ai);

   //--- Send data to AI server and get response
   string ai_response = SendDataToAI(data_for_ai);

   if(ai_response != "")
     {
      Print("AI Response: ", ai_response);
      //--- Parse AI response (simplified)
      // In a real scenario, use a JSON parsing library for MQL5
      if(StringFind(ai_response, "\"signal\":\"BUY\"") != -1)
        {
         ExecuteTrade(ORDER_TYPE_BUY, ai_response);
        }
      else if(StringFind(ai_response, "\"signal\":\"SELL\"") != -1)
        {
         ExecuteTrade(ORDER_TYPE_SELL, ai_response);
        }
      else
        {
         Print("AI did not provide a clear trade signal.");
        }
     }
   else
     {
      Print("No response from AI server.");
     }
  }

//+------------------------------------------------------------------+
//| Connect to AI Server (Simplified TCP/IP)                         |
//+------------------------------------------------------------------+
bool ConnectToAIServer()
  {
   g_socket = socket_create();
   if(g_socket == INVALID_SOCKET)
     {
      Print("socket_create failed, error: ", GetLastError());
      return false;
     }

   if(!socket_connect(g_socket, AI_SERVER_IP, AI_SERVER_PORT, 5000)) // 5 second timeout
     {
      Print("socket_connect failed, error: ", GetLastError());
      socket_close(g_socket);
      g_socket = INVALID_SOCKET;
      return false;
     }
   Print("Connected to AI server at ", AI_SERVER_IP, ":", AI_SERVER_PORT);
   return true;
  }

//+------------------------------------------------------------------+
//| Send Data to AI Server (Simplified TCP/IP)                       |
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
   StringToCharArray(data, data_bytes, 0, StringLen(data), CP_UTF8);
   if(socket_send(g_socket, data_bytes, ArraySize(data_bytes), 0) == -1)
     {
      Print("socket_send failed, error: ", GetLastError());
      socket_close(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }

   //--- Receive response
   char buffer[];
   ArrayResize(buffer, 4096); // Max response size
   int bytes_received = socket_recv(g_socket, buffer, ArraySize(buffer), 0);
   if(bytes_received == -1)
     {
      Print("socket_recv failed, error: ", GetLastError());
      socket_close(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }
   else if(bytes_received == 0)
     {
      Print("AI server closed connection.");
      socket_close(g_socket);
      g_socket = INVALID_SOCKET;
      return "";
     }

   return CharArrayToString(buffer, 0, bytes_received, CP_UTF8);
  }

//+------------------------------------------------------------------+
//| Execute Trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE order_type, string ai_response)
  {
   double lot_size = NormalizeLot(AccountInfoDouble(ACCOUNT_BALANCE) * RISK_PER_TRADE / (SL_PIPS_DEFAULT * g_point)); // Simplified lot calculation
   double entry_price, stop_loss, take_profit;

   //--- Parse entry, SL, TP from AI response (simplified)
   // For a real system, use a proper JSON parser.
   // For now, use default if AI doesn't provide.
   entry_price = SymbolInfoDouble(g_symbol, (order_type == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   stop_loss = (order_type == ORDER_TYPE_BUY) ? entry_price - SL_PIPS_DEFAULT * g_point : entry_price + SL_PIPS_DEFAULT * g_point;
   take_profit = (order_type == ORDER_TYPE_BUY) ? entry_price + TP_PIPS_DEFAULT * g_point : entry_price - TP_PIPS_DEFAULT * g_point;

   // Attempt to extract from AI response if available (very basic string parsing)
   int pos = StringFind(ai_response, "\"entry\":");
   if(pos != -1) entry_price = StringToDouble(StringSubstr(ai_response, pos + 8, StringFind(ai_response, ",", pos + 8) - (pos + 8)));
   pos = StringFind(ai_response, "\"sl\":");
   if(pos != -1) stop_loss = StringToDouble(StringSubstr(ai_response, pos + 5, StringFind(ai_response, ",", pos + 5) - (pos + 5)));
   pos = StringFind(ai_response, "\"tp\":");
   if(pos != -1) take_profit = StringToDouble(StringSubstr(ai_response, pos + 5, StringFind(ai_response, "}", pos + 5) - (pos + 5)));

   MqlTradeRequest request;
   MqlTradeResult  result;

   ZeroMemory(request);
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = g_symbol;
   request.volume   = lot_size;
   request.price    = entry_price;
   request.deviation = MAX_SLIPPAGE_PIPS * _Point; // Max deviation in points
   request.type     = order_type;
   request.type_filling = ORDER_FILLING_FOK; // Fill or Kill
   request.magic    = MAGIC_NUMBER;
   request.sl       = stop_loss;
   request.tp       = take_profit;

   if(!OrderSend(request, result))
     {
      PrintFormat("OrderSend failed for %s %s: retcode=%d, deal=%I64d, order=%I64d",
                  g_symbol, EnumToString(order_type), result.retcode, result.deal, result.order);
     }
   else
     {
      PrintFormat("OrderSend successful for %s %s: deal=%I64d, order=%I64d",
                  g_symbol, EnumToString(order_type), result.deal, result.order);
     }
  }

//+------------------------------------------------------------------+
//| Normalize Lot Size                                               |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   return fmax(g_min_lot, floor(lot / g_lot_step) * g_lot_step);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


