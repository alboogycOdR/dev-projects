//+------------------------------------------------------------------+
//|                                              MQL5_ZeroMQ_EA.mq5 |
//|                                                    Manus AI Team |
//|                                       https://www.manus-ai.com/ |
//+------------------------------------------------------------------+
#property copyright "Manus AI Team"
#property link      "https://www.manus-ai.com/"
#property version   "1.00"
#property description "Expert Advisor for ZeroMQ integration with Python"

#include <ZeroMQ/ZeroMQ.mqh> // You will need to download and include the ZeroMQ library for MQL5

//--- Input parameters
input int    DataPort = 5556;    // Port for publishing market data
input int    SignalPort = 5557;  // Port for receiving trading signals
input string SymbolToTrade = ""; // Symbol to trade (e.g., "XAUUSD", "BTCUSD")
input ENUM_TIMEFRAMES Timeframe = PERIOD_M1; // Timeframe for data (e.g., PERIOD_M1, PERIOD_M5, PERIOD_M15)

//--- ZeroMQ objects
CZMQContext  *g_context;
CZMQPublisher *g_publisher; // For sending data to Python
CZMQReplier   *g_replier;   // For receiving signals from Python

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Create ZeroMQ context
   g_context = new CZMQContext();
   if(g_context == NULL)
     {
      Print("Failed to create ZeroMQ context");
      return INIT_FAILED;
     }

//--- Create and bind publisher for market data
   g_publisher = new CZMQPublisher(g_context);
   if(g_publisher == NULL)
     {
      Print("Failed to create ZeroMQ publisher");
      delete g_context;
      return INIT_FAILED;
     }
   if(!g_publisher.Bind("tcp://*:" + IntegerToString(DataPort)))
     {
      Print("Failed to bind publisher to port ", DataPort);
      delete g_publisher;
      delete g_context;
      return INIT_FAILED;
     }
   Print("ZeroMQ Publisher bound to port ", DataPort);

//--- Create and bind replier for trading signals
   g_replier = new CZMQReplier(g_context);
   if(g_replier == NULL)
     {
      Print("Failed to create ZeroMQ replier");
      delete g_publisher;
      delete g_context;
      return INIT_FAILED;
     }
   if(!g_replier.Bind("tcp://*:" + IntegerToString(SignalPort)))
     {
      Print("Failed to bind replier to port ", SignalPort);
      delete g_replier;
      delete g_publisher;
      delete g_context;
      return INIT_FAILED;
     }
   Print("ZeroMQ Replier bound to port ", SignalPort);

//--- Set up symbol and timeframe for data collection
   if(SymbolToTrade == "")
     {
      SymbolToTrade = _Symbol;
     }

//--- Request historical data to be available
   if(!CopyRates(SymbolToTrade, Timeframe, 0, 100, new MqlRates[100]))
     {
      Print("Failed to copy initial rates for ", SymbolToTrade, " on ", Timeframe);
     }

//---
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Clean up ZeroMQ objects
   if(g_replier != NULL)
     {
      g_replier.Shutdown();
      delete g_replier;
     }
   if(g_publisher != NULL)
     {
      g_publisher.Shutdown();
      delete g_publisher;
     }
   if(g_context != NULL)
     {
      delete g_context;
     }
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Check for new bar (simplified for demonstration)
   static datetime last_bar_time = 0;
   MqlRates rates[];
   if(CopyRates(SymbolToTrade, Timeframe, 0, 1, rates) > 0)
     {
      if(rates[0].time != last_bar_time)
        {
         last_bar_time = rates[0].time;
         
         //--- Get historical data for Python
         MqlRates historical_rates[100]; // Get last 100 bars
         int count = CopyRates(SymbolToTrade, Timeframe, 0, 100, historical_rates);
         
         if(count > 0)
           {
            string json_data = "{\"symbol\":\"" + SymbolToTrade + "\", \"timeframe\":\"" + EnumToString(Timeframe) + "\", \"data\":[";
            for(int i = count - 1; i >= 0; i--)
              {
               json_data += "{\"time\":" + (string)historical_rates[i].time + ",\"open\":


(string)historical_rates[i].open + ",\"high\":" + (string)historical_rates[i].high + ",\"low\":" + (string)historical_rates[i].low + ",\"close\":" + (string)historical_rates[i].close + ",\"tick_volume\":" + (string)historical_rates[i].tick_volume + "}";
               if(i > 0) json_data += ",";
              }
            json_data += "]}";
            
            //--- Publish data to Python
            g_publisher.Send(json_data);
            Print("Published new bar data for ", SymbolToTrade, ": ", json_data);
           }
        }
     }

//--- Check for incoming signals from Python
   string request;
   if(g_replier.Recv(request, 10)) // 10ms timeout
     {
      Print("Received signal from Python: ", request);
      
      //--- Parse the JSON request (simplified parsing for example)
      // In a real scenario, you'd use MQL5 JSON parsing functions
      string action = "";
      string symbol = "";
      double volume = 0.0;
      double price = 0.0;
      double sl = 0.0;
      double tp = 0.0;
      
      // Example of very basic parsing (replace with robust JSON parsing)
      if(StringFind(request, "\"action\":\"BUY\"") != -1) action = "BUY";
      else if(StringFind(request, "\"action\":\"SELL\"") != -1) action = "SELL";
      
      // Extract symbol, volume, price, sl, tp (requires proper JSON parsing)
      // For now, assume a simple structure or hardcode for testing
      symbol = SymbolToTrade; // Use the EA's symbol for simplicity
      volume = 0.01; // Default volume for simplicity
      
      //--- Execute trade based on signal
      string response_message = "";
      if(action == "BUY")
        {
         // Simplified OrderSend for demonstration
         // MQL5 has robust trading functions (OrderSend, PositionOpen, etc.)
         // This part needs to be fully implemented with proper error handling and trade management
         if(PositionSelect(symbol))
           {
            response_message = "Position already open for " + symbol;
           }
         else
           {
            // Example: Open a buy order
            trade.Buy(volume, symbol, 0, 0, 0, "Python Signal");
            response_message = "BUY order sent for " + symbol + " volume " + DoubleToString(volume);
           }
        }
      else if(action == "SELL")
        {
         // Simplified OrderSend for demonstration
         if(PositionSelect(symbol))
           {
            response_message = "Position already open for " + symbol;
           }
         else
           {
            // Example: Open a sell order
            trade.Sell(volume, symbol, 0, 0, 0, "Python Signal");
            response_message = "SELL order sent for " + symbol + " volume " + DoubleToString(volume);
           }
        }
      else
        {
         response_message = "Unknown action: " + action;
        }
      
      //--- Send response back to Python
      g_replier.Send("{\"status\":\"OK\", \"message\":\"" + response_message + "\"}");
     }
  }

//+------------------------------------------------------------------+
//| Trade functions (simplified, use CTrade class for robust trading)|
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

// You will need to download the ZeroMQ library for MQL5 from MQL5.community or GitHub.
// Place the ZeroMQ.mqh file in MQL5/Include/ZeroMQ/ directory.
// You might also need to enable "Allow DLL imports" in MT5 settings for ZeroMQ to work.


