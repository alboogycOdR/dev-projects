/*https://www.mql5.com/en/docs/network/socketconnect




   MetaTrader 5 Expert Advisor that implements the hedging and scalping strategy between two account terminals .
   AI PROMPT
   https://claude.ai/chat/e6aa1a5a-485d-4fa5-8425-fa8414accf46

   DOCUMENTATION
   https://www.notion.so/EA-Dual-Account-Hedging-and-Scalping-1c649e541670801e9427cf9bb8c30eb7?pvs=4


   This will involve SocketObj communication for synchronization, generational trading logic, and high-speed execution

   Usage Instructions
   =============================
   Place this EA file in your MetaTrader 5 experts folder
   Launch two instances of MT5 with separate accounts
   Configure one instance as the server (IsServerAccount = true)
   Configure the second instance as the client (IsServerAccount = false)
   Set the same symbol, server port, and other parameters on both instances
   EA will automatically establish connection and begin trading

   Notes on Implementation
   =============
   The EA uses a standard SocketObj library to establish communication between terminals
   Performance is optimized for high-speed execution
   Error handling is included to prevent running with mismatched symbols or settings
   The visual interface updates in real-time with information about the current generation and positions

   Key Features Implemented
   =========================
   1 Hedging Functionality
   Creates complementary BUY and SELL positions across two accounts
   Maintains the correct position balance (2 BUY/1 SELL or 2 SELL/1 BUY) based on account role
   Handles trading for a single instrument per session

   2 Socket Communication
   Direct communication between two MT5 terminals
   Synchronizes trading activities and account states
   Configurable server ports in settings

   3 Generational Trading Logic
   Automatically alternates trading roles between generations
   Configurable generation duration (default: 600 seconds)
   Visual tracking of current generation on chart

   4 High-Speed Scalping
   Fast execution for position opening and closing
   Profit calculation accounting for spreads
   Closes positions only when profitable

   5 Stop Loss Implementation
   Optional stop loss mode (disabled by default)
   Applies only to the dominant position type (BUY-heavy or SELL-heavy)
   Synchronized stop loss triggering between accounts

   6 Lot Size and Compounding
   Configurable lot sizes
   Optional profit compounding feature
   Maintains position balance after scalping

*/
//+------------------------------------------------------------------+
//|                        Dual Account Hedging and Scalping EA       |
//|                              Copyright 2025                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// Include necessary libraries
#include <Trade/Trade.mqh>
//#include <Socket.mqh>
// Enum for account roles
enum ACCOUNT_ROLE
  {
   ROLE_BUY_HEAVY,     // Account with more BUY positions
   ROLE_SELL_HEAVY     // Account with more SELL positions
  };

// Enum for operational modes
enum OPERATIONAL_MODE
  {
   MODE_SANDBOX,       // Continuous trading without predefined strategies
   MODE_STRATEGY       // Strategy-based trading (for future implementation)
  };

// Input parameters
input string           GeneralSettings        = "===== General Settings =====";
input string           Symbol                 = "";             // Trading instrument
input int              GenerationDuration     = 600;            // Duration of generation in seconds
input OPERATIONAL_MODE OperationMode          = MODE_SANDBOX;   // Operational mode

input string           AccountSettings        = "===== Account Settings =====";
input bool             IsServerAccount        = true;          // Is this the server account?
input int              ServerPort             = 30303;          // Server port for SocketObj connection
input string           ServerAddress          = "127.0.0.1";    // Server address (local for MT5 instances)

input string           TradeSettings          = "===== Trade Settings =====";
input double           LotSize                = 0.01;           // Lot size for trades
input bool             CompoundProfits        = false;          // Enable profit compounding
input bool             StopLossMode           = false;          // Enable stop loss
input double           StopLossPips           = 10.0;           // Stop loss in pips

// Global variables
CTrade            trade;                        // Trade object
//CSocket           SocketObj;                       // Socket object
ACCOUNT_ROLE      currentRole;                  // Current role of this account
long currentGeneration = 1;        // Current generation counter
datetime          generationStartTime;          // Generation start time
bool              isConnected = false;          // Socket connection status
string            currentSymbol;                // Current trading symbol
double            point;                        // Point value for the current symbol
int               smbl_dgts;                       // Digits for the current symbol
double            pipValue;                     // Value of 1 pip
double            spread;                       // Current spread

// Order tracking
int               buyPositionsCount = 0;        // Count of BUY positions
int               sellPositionsCount = 0;       // Count of SELL positions
ulong             buyPositions[];               // Array to store BUY position tickets
ulong             sellPositions[];              // Array to store SELL position tickets


int SocketObj;
// Socket variables
int serverSocket = INVALID_HANDLE;  // For server only - the listening socket
int clientSocket = INVALID_HANDLE;  // Connection to client (for server) or to server (for client)
bool isConnected = false;           // Connection status


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Initialize symbol information
   Print("DEBUG: Initializing symbol information");
   if(Symbol == "")
     {
      currentSymbol = Symbol();
     }
   else
     {
      currentSymbol = Symbol;
     }
   Print("DEBUG: Using symbol: ", currentSymbol);
// Get symbol properties
   smbl_dgts = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
   point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
   pipValue = (smbl_dgts == 3 || smbl_dgts == 5) ? point * 10 : point;
   Print("DEBUG: Symbol properties - Digits: ", smbl_dgts, ", Point: ", point, ", Pip Value: ", pipValue);
// Set up trade object
   trade.SetExpertMagicNumber(123456);
   Print("DEBUG: Trade object initialized with magic number: 123456");
// Start generation timer
   generationStartTime = TimeCurrent();
   Print("DEBUG: Generation timer started at: ", TimeToString(generationStartTime));
// Determine initial role based on generation
   currentRole = (currentGeneration % 2 == 1) ?
                 (IsServerAccount ? ROLE_BUY_HEAVY : ROLE_SELL_HEAVY) :
                 (IsServerAccount ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY);
   Print("DEBUG: Initial role set to: ", (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy");
// Initialize SocketObj connection
   Print("DEBUG: Initializing socket connection. IsServerAccount: ", IsServerAccount);
   /*


   */
   if(IsServerAccount)
     {
      Print("DEBUG: Starting OnInit() function");
      serverSocket=SocketCreate();
      Print("DEBUG: SocketCreate() result - Handle: ", SocketObj, ", Error: ", GetLastError());
      if(serverSocket!=INVALID_HANDLE)
        {
         Print("DEBUG: Socket created successfully with handle: ", serverSocket);
         
        }
      else
        {
         Print("ERROR: Failed to create socket. Error code: ", GetLastError(), " (", ErrorDescription(GetLastError()), ")");
         return INIT_FAILED;
        }
      SocketTimeouts(serverSocket, 60000, 60000);
      // Try to bind to the port
      if(!SocketBind(serverSocket, ServerPort)) {
         int error = GetLastError();
         Print("ERROR: Failed to bind to port ", ServerPort, ". Error: ", error, " (", ErrorDescription(error), ")");
         SocketClose(serverSocket);
         return INIT_FAILED;
      }
      Print("DEBUG: Socket bound to port ", ServerPort);
      
      // Listen for incoming connections
      if(!SocketListen(serverSocket, 1)) {
         int error = GetLastError();
         Print("ERROR: Failed to listen on socket. Error: ", error, " (", ErrorDescription(error), ")");
         SocketClose(serverSocket);
         return INIT_FAILED;
      }
      Print("SUCCESS: Server socket is listening on port ", ServerPort);
      
      // The server is now listening, connection acceptance happens in ProcessSocketMessages
      isConnected = false; // Not connected to a client yet

     }
   else  // Client account
     {
      // Print("DEBUG: Starting client socket initialization");
      // Print("DEBUG: Attempting to connect to server at: ", ServerAddress, ", port: ", ServerPort, ", Timeout: 5000ms");
      // // Connect to the server
      // if(!SocketConnect(SocketObj, ServerAddress, ServerPort, 5000))
      //   {
      //    int error = GetLastError();
      //    Print("ERROR: Failed to connect to server. Error code: ", error, " (", ErrorDescription(error), ")");
      //    Print("DEBUG: Connection details - Address: ", ServerAddress, ", Port: ", ServerPort);
      //    SocketClose(SocketObj);
      //    return INIT_FAILED;
      //   }
      // isConnected = true;
      // Print("SUCCESS: Connected to server at ", ServerAddress, ":", ServerPort);
      // // Send initial handshake
      // string handshakeMsg = "CONNECT|" + currentSymbol;
      // Print("DEBUG: Preparing handshake message: '", handshakeMsg, "'");
      // uchar buffer[];
      // StringToCharArray(handshakeMsg, buffer, 0, StringLen(handshakeMsg));
      // Print("DEBUG: Message converted to char array. Size: ", ArraySize(buffer));
      // Print("DEBUG: Sending handshake message to server");
      // int sendResult = SocketSend(SocketObj, buffer, ArraySize(buffer));
      // if(sendResult <= 0)
      //   {
      //    int error = GetLastError();
      //    Print("ERROR: Failed to send handshake. Error code: ", error, " (", ErrorDescription(error), ")");
      //    Print("DEBUG: Socket status - Connected: ", SocketIsConnected(SocketObj));
      //   }
      // else
      //   {
      //    Print("SUCCESS: Handshake sent successfully. Bytes sent: ", sendResult);
      //   }
    Print("DEBUG: Starting client initialization");
    
    // Create the socket
    clientSocket = SocketCreate();
    if(clientSocket == INVALID_HANDLE) {
        Print("ERROR: Failed to create client socket. Error: ", GetLastError(), " (", ErrorDescription(GetLastError()), ")");
        return INIT_FAILED;
    }
    Print("DEBUG: Client socket created with handle: ", clientSocket);
    
    // Set appropriate timeouts
    SocketTimeouts(clientSocket, 5000, 5000);
    
    // Connect to the server
    Print("INFO: Attempting to connect to server at ", ServerAddress, ":", ServerPort);
    if(!SocketConnect(clientSocket, ServerAddress, ServerPort)) {
        int error = GetLastError();
        Print("ERROR: Failed to connect to server. Error: ", error, " (", ErrorDescription(error), ")");
        SocketClose(clientSocket);
        return INIT_FAILED;
    }
    Print("SUCCESS: Connected to server at ", ServerAddress, ":", ServerPort);
    isConnected = true;
    
    // Send initial handshake
    string handshakeMsg = "CONNECT|" + currentSymbol;
    SendSocketMessage(handshakeMsg);

     }
// Add chart description
   string roleStr = (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy";
   Comment("Generation: ", currentGeneration, "\nRole: ", roleStr);
   Print("DEBUG: OnInit completed successfully");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
// void OnDeinit(const int reason)
//   {
//    Print("DEBUG: OnDeinit called with reason code: ", reason);
//    if(SocketObj != INVALID_HANDLE)
//      {
//       Print("DEBUG: Closing socket with handle: ", SocketObj);
//       bool closeResult = SocketClose(SocketObj);
//       Print("DEBUG: Socket close result: ", closeResult, ", Error: ", GetLastError());
//      }
//    else
//      {
//       Print("DEBUG: No valid socket handle to close");
//      }
//    Comment("");
//    Print("DEBUG: OnDeinit completed");
//   }
void OnDeinit(const int reason) {
    Print("DEBUG: OnDeinit called with reason code: ", reason);
    
    // Close the client connection socket
    if(clientSocket != INVALID_HANDLE) {
        Print("DEBUG: Closing client socket with handle: ", clientSocket);
        SocketClose(clientSocket);
        clientSocket = INVALID_HANDLE;
    }
    
    // Close the server listening socket
    if(IsServerAccount && serverSocket != INVALID_HANDLE) {
        Print("DEBUG: Closing server socket with handle: ", serverSocket);
        SocketClose(serverSocket);
        serverSocket = INVALID_HANDLE;
    }
    
    isConnected = false;
    Comment("");
    Print("DEBUG: OnDeinit completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Update spread
   spread = SymbolInfoInteger(currentSymbol, SYMBOL_SPREAD) * point;
// Check if we need to switch generations
   CheckGenerationSwitch();
// Process serverSocket communications
   ProcessSocketMessages();
// Update position counts
   UpdatePositionCounts();
// Execute hedging strategy
   ExecuteHedgingStrategy();
// Execute scalping strategy
   ExecuteScalpingStrategy();
// Apply stop loss if enabled
   if(StopLossMode)
     {
      ApplyStopLoss();
     }
// Update chart info
   UpdateChartInfo();
  }

//+------------------------------------------------------------------+
//| Check if we need to switch to a new generation                   |
//+------------------------------------------------------------------+
void CheckGenerationSwitch()
  {
   if(TimeCurrent() - generationStartTime >= GenerationDuration)
     {
      // Increment generation
      currentGeneration++;
      // Switch roles
      currentRole = (currentRole == ROLE_BUY_HEAVY) ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY;
      // Reset generation timer
      generationStartTime = TimeCurrent();
      // Close all existing positions
      CloseAllPositions();
      // Send generation change message
      if(isConnected || SocketIsConnected(serverSocket))
        {
         string genChangeMsg = "GEN_CHANGE|" + IntegerToString(currentGeneration);
         uchar buffer[];
         StringToCharArray(genChangeMsg, buffer, 0, StringLen(genChangeMsg));
         SocketSend(serverSocket, buffer, ArraySize(buffer));
        }
      Print("Switched to Generation ", currentGeneration, ", new role: ",
            (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy");
     }
  }

//+------------------------------------------------------------------+
//| Process incoming serverSocket messages                                 |
//+------------------------------------------------------------------+
void ProcessSocketMessages()
  {
void ProcessSocketMessages() {
    // For server: Handle new connections
    if(IsServerAccount) {
        // If we don't have a client connection yet, or the client disconnected
        if(clientSocket == INVALID_HANDLE || !SocketIsConnected(clientSocket)) {
            // Accept a new connection if one is pending
            if(SocketIsReadable(serverSocket)) {
                // Accept the new connection
                clientSocket = SocketAccept(serverSocket, ServerAddress);
                if(clientSocket != INVALID_HANDLE) {
                    Print("SUCCESS: New client connection accepted");
                    // Set appropriate timeouts for the client connection
                    SocketTimeouts(clientSocket, 60000, 60000);
                    isConnected = true;
                    
                    // Send current state to the client
                    string stateMsg = "STATE|" + IntegerToString(currentGeneration) + "|" + 
                                     IntegerToString(currentRole);
                    SendSocketMessage(stateMsg);
                }
                else {
                    int error = GetLastError();
                    Print("WARNING: Failed to accept client connection. Error: ", error, " (", ErrorDescription(error), ")");
                }
            }
        }
    }
    
    // For both server and client: Read incoming messages
    if(isConnected && clientSocket != INVALID_HANDLE) {
        // Check if the socket is still connected
        if(!SocketIsConnected(clientSocket)) {
            Print("WARNING: Socket connection lost");
            isConnected = false;
            
            // For client, try to reconnect
            if(!IsServerAccount) {
                Print("INFO: Client attempting to reconnect...");
                if(SocketConnect(clientSocket, ServerAddress, ServerPort)) {
                    Print("SUCCESS: Reconnected to server");
                    isConnected = true;
                    // Resend handshake
                    string handshakeMsg = "CONNECT|" + currentSymbol;
                    SendSocketMessage(handshakeMsg);
                }
                else {
                    Print("ERROR: Failed to reconnect. Error: ", GetLastError());
                }
            }
            return;
        }
        
        // Check if there's data to read
        if(SocketIsReadable(clientSocket)) {
            // Read the message
            uchar buffer[1024];
            int bytesRead = SocketRead(clientSocket, buffer, ArraySize(buffer), 0);
            
            if(bytesRead > 0) {
                // Convert the message to a string
                string message = CharArrayToString(buffer, 0, bytesRead);
                Print("DEBUG: Received message: ", message);
                
                // Process the message
                ProcessMessage(message);
            }
            else if(bytesRead == 0) {
                // No data available (normal for non-blocking sockets)
            }
            else {
                // Error reading from socket
                int error = GetLastError();
                Print("ERROR: Failed to read from socket. Error: ", error, " (", ErrorDescription(error), ")");
                isConnected = false;
            }
        }
    }
}
  }

//+------------------------------------------------------------------+
//| Update the count of open positions                               |
//+------------------------------------------------------------------+
void UpdatePositionCounts()
  {
   buyPositionsCount = 0;
   sellPositionsCount = 0;
// Reset arrays
   ArrayResize(buyPositions, 0);
   ArrayResize(sellPositions, 0);
// Count positions
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == currentSymbol)
           {
            long type = PositionGetInteger(POSITION_TYPE);
            if(type == POSITION_TYPE_BUY)
              {
               buyPositionsCount++;
               int size = ArraySize(buyPositions);
               ArrayResize(buyPositions, size + 1);
               buyPositions[size] = ticket;
              }
            else
               if(type == POSITION_TYPE_SELL)
                 {
                  sellPositionsCount++;
                  int size = ArraySize(sellPositions);
                  ArrayResize(sellPositions, size + 1);
                  sellPositions[size] = ticket;
                 }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Execute the hedging strategy                                     |
//+------------------------------------------------------------------+
void ExecuteHedgingStrategy()
  {
// Verify the current role and open positions accordingly
   if(currentRole == ROLE_BUY_HEAVY)
     {
      // This account should have 2 BUY and 1 SELL
      while(buyPositionsCount < 2)
        {
         if(trade.Buy(LotSize, currentSymbol))
           {
            Print("Opened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            // Notify other terminal
            if(isConnected || SocketIsConnected(serverSocket))
              {
               string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(LotSize, 2) + "|" +
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
               SocketSend(serverSocket, buffer, ArraySize(buffer));
              }
            buyPositionsCount++;
           }
         else
           {
            Print("Failed to open BUY position, Error: ", GetLastError());
            break;
           }
        }
      while(sellPositionsCount < 1)
        {
         if(trade.Sell(LotSize, currentSymbol))
           {
            Print("Opened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            // Notify other terminal
            if(isConnected || SocketIsConnected(serverSocket))
              {
               string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(LotSize, 2) + "|" +
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
               SocketSend(serverSocket, buffer, ArraySize(buffer));
              }
            sellPositionsCount++;
           }
         else
           {
            Print("Failed to open SELL position, Error: ", GetLastError());
            break;
           }
        }
     }
   else   // ROLE_SELL_HEAVY
     {
      // This account should have 2 SELL and 1 BUY
      while(sellPositionsCount < 2)
        {
         if(trade.Sell(LotSize, currentSymbol))
           {
            Print("Opened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            // Notify other terminal
            if(isConnected || SocketIsConnected(serverSocket))
              {
               string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(LotSize, 2) + "|" +
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
               SocketSend(serverSocket, buffer, ArraySize(buffer));
              }
            sellPositionsCount++;
           }
         else
           {
            Print("Failed to open SELL position, Error: ", GetLastError());
            break;
           }
        }
      while(buyPositionsCount < 1)
        {
         if(trade.Buy(LotSize, currentSymbol))
           {
            Print("Opened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            // Notify other terminal
            if(isConnected || SocketIsConnected(serverSocket))
              {
               string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(LotSize, 2) + "|" +
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
               SocketSend(serverSocket, buffer, ArraySize(buffer));
              }
            buyPositionsCount++;
           }
         else
           {
            Print("Failed to open BUY position, Error: ", GetLastError());
            break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Execute the scalping strategy                                    |
//+------------------------------------------------------------------+
void ExecuteScalpingStrategy()
  {
// Implement high-speed scalping
   if(currentRole == ROLE_BUY_HEAVY)
     {
      // For BUY-heavy account:
      // Check BUY positions for profit
      for(int i = 0; i < ArraySize(buyPositions); i++)
        {
         if(IsPositionProfitable(buyPositions[i], true))
           {
            ClosePositionWithTicket(buyPositions[i]);
           }
        }
      // Check SELL position for profit
      for(int i = 0; i < ArraySize(sellPositions); i++)
        {
         if(IsPositionProfitable(sellPositions[i], false))
           {
            ClosePositionWithTicket(sellPositions[i]);
           }
        }
     }
   else   // ROLE_SELL_HEAVY
     {
      // For SELL-heavy account:
      // Check SELL positions for profit
      for(int i = 0; i < ArraySize(sellPositions); i++)
        {
         if(IsPositionProfitable(sellPositions[i], false))
           {
            ClosePositionWithTicket(sellPositions[i]);
           }
        }
      // Check BUY position for profit
      for(int i = 0; i < ArraySize(buyPositions); i++)
        {
         if(IsPositionProfitable(buyPositions[i], true))
           {
            ClosePositionWithTicket(buyPositions[i]);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if a position is profitable                                |
//+------------------------------------------------------------------+
bool IsPositionProfitable(ulong ticket, bool isBuy)
  {
   if(!PositionSelectByTicket(ticket))
     {
      return false;
     }
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
// Get current bid/ask
   double currentBid = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
// Calculate profit considering spread
   if(isBuy)
     {
      // For BUY positions, we close at BID price
      double potentialProfit = volume * ((currentBid - openPrice) / point);
      return (potentialProfit > 0 && profit > 0);
     }
   else
     {
      // For SELL positions, we close at ASK price
      double potentialProfit = volume * ((openPrice - currentAsk) / point);
      return (potentialProfit > 0 && profit > 0);
     }
  }

//+------------------------------------------------------------------+
//| Close a position with the given ticket                           |
//+------------------------------------------------------------------+
void ClosePositionWithTicket(ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
     {
      return;
     }
   string posType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   double profit = PositionGetDouble(POSITION_PROFIT);
   if(trade.PositionClose(ticket, ULONG_MAX))
     {
      Print("Closed ", posType, " position, Ticket: ", ticket, ", Profit: ", profit);
      // Notify other terminal
      if(isConnected || SocketIsConnected(serverSocket))
        {
         string closeMsg = "TRADE_CLOSE|" + posType + "|" + IntegerToString(ticket) + "|" +
                           DoubleToString(profit, 2);
         uchar buffer[];
         StringToCharArray(closeMsg, buffer, 0, StringLen(closeMsg));
         SocketSend(serverSocket, buffer, ArraySize(buffer));
        }
      // Reopen position based on account role (to maintain the balance)
      if((posType == "BUY" && currentRole == ROLE_BUY_HEAVY) ||
         (posType == "SELL" && currentRole == ROLE_SELL_HEAVY))
        {
         // Calculate new lot size if compounding is enabled
         double newLotSize = LotSize;
         if(CompoundProfits && profit > 0)
           {
            // Simple compounding: increase lot size proportionally to profit
            double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            double profitPercentage = profit / accountBalance;
            newLotSize = LotSize * (1 + profitPercentage);
            // Round to valid lot size
            newLotSize = NormalizeDouble(newLotSize, 2);
            // Ensure minimum lot size
            if(newLotSize < SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN))
              {
               newLotSize = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
              }
           }
         // Reopen position
         if(posType == "BUY")
           {
            if(trade.Buy(newLotSize, currentSymbol))
              {
               Print("Reopened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
               // Notify other terminal
               if(isConnected || SocketIsConnected(serverSocket))
                 {
                  string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(newLotSize, 2) + "|" +
                                    DoubleToString(trade.ResultPrice(), smbl_dgts);
                  uchar buffer[];
                  StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
                  SocketSend(serverSocket, buffer, ArraySize(buffer));
                 }
              }
           }
         else   // SELL
           {
            if(trade.Sell(newLotSize, currentSymbol))
              {
               Print("Reopened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
               // Notify other terminal
               if(isConnected || SocketIsConnected(serverSocket))
                 {
                  string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(newLotSize, 2) + "|" +
                                    DoubleToString(trade.ResultPrice(), smbl_dgts);
                  uchar buffer[];
                  StringToCharArray(tradeMsg, buffer, 0, StringLen(tradeMsg));
                  SocketSend(serverSocket, buffer, ArraySize(buffer));
                 }
              }
           }
        }
     }
   else
     {
      Print("Failed to close position, Ticket: ", ticket, ", Error: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| Apply stop loss to positions if enabled                          |
//+------------------------------------------------------------------+
void ApplyStopLoss()
  {
// Only apply stop loss to the dominant position type
   if(currentRole == ROLE_BUY_HEAVY)
     {
      // Apply stop loss to BUY positions
      for(int i = 0; i < ArraySize(buyPositions); i++)
        {
         if(PositionSelectByTicket(buyPositions[i]))
           {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = openPrice - (StopLossPips * pipValue);
            // Check if stop loss is breached
            double currentBid = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
            if(currentBid <= stopLoss)
              {
               // Trigger stop loss
               Print("Stop Loss triggered for BUY position, Ticket: ", buyPositions[i]);
               // Send SL trigger message to other terminal
               if(isConnected || SocketIsConnected(serverSocket))
                 {
                  string slMsg = "SL_TRIGGER";
                  uchar buffer[];
                  StringToCharArray(slMsg, buffer, 0, StringLen(slMsg));
                  SocketSend(serverSocket, buffer, ArraySize(buffer));
                 }
               // Close all positions in both accounts
               CloseAllPositions();
               break;
              }
           }
        }
     }
   else   // ROLE_SELL_HEAVY
     {
      // Apply stop loss to SELL positions
      for(int i = 0; i < ArraySize(sellPositions); i++)
        {
         if(PositionSelectByTicket(sellPositions[i]))
           {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = openPrice + (StopLossPips * pipValue);
            // Check if stop loss is breached
            double currentAsk = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
            if(currentAsk >= stopLoss)
              {
               // Trigger stop loss
               Print("Stop Loss triggered for SELL position, Ticket: ", sellPositions[i]);
               // Send SL trigger message to other terminal
               if(isConnected || SocketIsConnected(serverSocket))
                 {
                  string slMsg = "SL_TRIGGER";
                  uchar buffer[];
                  StringToCharArray(slMsg, buffer, 0, StringLen(slMsg));
                  SocketSend(serverSocket, buffer, ArraySize(buffer));
                 }
               // Close all positions in both accounts
               CloseAllPositions();
               break;
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Execute emergency stop loss (triggered by other terminal)        |
//+------------------------------------------------------------------+
void ExecuteEmergencyStopLoss()
  {
   CloseAllPositions();
  }

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
        {
         if(PositionGetString(POSITION_SYMBOL) == currentSymbol)
           {
            trade.PositionClose(ticket);
           }
        }
     }
// Reset position counts
   buyPositionsCount = 0;
   sellPositionsCount = 0;
   ArrayResize(buyPositions, 0);
   ArrayResize(sellPositions, 0);
  }

//+------------------------------------------------------------------+
//| Update chart info                                                |
//+------------------------------------------------------------------+
void UpdateChartInfo()
  {
   string roleStr = (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy";
   string genInfo = "Generation: " + IntegerToString(currentGeneration) +
                    "\nRole: " + roleStr +
                    "\nTime left: " + IntegerToString(GenerationDuration - (TimeCurrent() - generationStartTime)) + " sec" +
                    "\nBuy Positions: " + IntegerToString(buyPositionsCount) +
                    "\nSell Positions: " + IntegerToString(sellPositionsCount);
   Comment(genInfo);
  }

// Add a new helper function to format error messages
string ErrorDescription(int errorCode)
  {
   switch(errorCode)
     {
      // Standard MQL5 error codes
      case 1:
         return "No error, but result is unknown";
      case 2:
         return "Common error";
      case 3:
         return "Invalid trade parameters";
      case 4:
         return "Trade server is busy";
      case 5:
         return "Old version of the client terminal";
      case 6:
         return "No connection with trade server";
      case 7:
         return "Not enough rights";
      case 8:
         return "Too frequent requests";
      case 9:
         return "Malfunctional trade operation";
      case 64:
         return "Account disabled";
      case 65:
         return "Invalid account";
      case 128:
         return "Trade timeout";
      case 129:
         return "Invalid price";
      case 130:
         return "Invalid stops";
      // Socket-specific errors (based on Windows serverSocket error codes)
      case 10004:
         return "Interrupted system call";
      case 10009:
         return "Bad file number";
      case 10013:
         return "Access denied";
      case 10014:
         return "Bad address";
      case 10022:
         return "Invalid argument";
      case 10024:
         return "Too many open files";
      case 10035:
         return "Resource temporarily unavailable (serverSocket would block)";
      case 10036:
         return "Operation now in progress";
      case 10037:
         return "Operation already in progress";
      case 10038:
         return "Socket operation on non-serverSocket";
      case 10040:
         return "Message too long";
      case 10049:
         return "Cannot assign requested address";
      case 10050:
         return "Network is down";
      case 10051:
         return "Network is unreachable";
      case 10052:
         return "Network dropped connection on reset";
      case 10053:
         return "Software caused connection abort";
      case 10054:
         return "Connection reset by peer";
      case 10055:
         return "No buffer space available";
      case 10056:
         return "Socket is already connected";
      case 10057:
         return "Socket is not connected";
      case 10058:
         return "Cannot send after serverSocket shutdown";
      case 10060:
         return "Connection timed out";
      case 10061:
         return "Connection refused";
      case 10064:
         return "Host is down";
      case 10065:
         return "No route to host";
      // Custom serverSocket error interpretations
      case 4000:
         return "Socket not created";
      case 4001:
         return "Socket connection error";
      case 4002:
         return "Socket read error";
      case 4003:
         return "Socket write error";
      case 4014:
         return "Socket address already in use or cannot be bound";
      default:
         return "Unknown error " + IntegerToString(errorCode);
     }
  }
//+------------------------------------------------------------------+
// Helper function to send a message through the socket
bool SendSocketMessage(string message) {
    if(!isConnected || clientSocket == INVALID_HANDLE) {
        Print("ERROR: Cannot send message - socket not connected");
        return false;
    }
    
    // Convert the message to a character array
    uchar buffer[];
    int len = StringToCharArray(message, buffer);
    
    // Send the message
    int bytesSent = SocketSend(clientSocket, buffer, len);
    if(bytesSent > 0) {
        Print("DEBUG: Sent message: ", message, " (", bytesSent, " bytes)");
        return true;
    }
    else {
        int error = GetLastError();
        Print("ERROR: Failed to send message. Error: ", error, " (", ErrorDescription(error), ")");
        isConnected = false;
        return false;
    }
}

// Process a received message
void ProcessMessage(string message) {
    // Split the message into parts
    string parts[];
    StringSplit(message, '|', parts);
    
    if(ArraySize(parts) > 0) {
        string command = parts[0];
        
        if(command == "CONNECT") {
            // Connection handshake
            if(ArraySize(parts) > 1) {
                string remoteSymbol = parts[1];
                if(remoteSymbol != currentSymbol) {
                    Print("ERROR: Symbol mismatch! Local: ", currentSymbol, ", Remote: ", remoteSymbol);
                    // Consider stopping the EA or taking other corrective action
                }
                else {
                    Print("INFO: Connection established with matching symbol: ", currentSymbol);
                }
            }
        }
        else if(command == "STATE") {
            // State information from server
            if(ArraySize(parts) >= 3) {
                long remoteGen = StringToInteger(parts[1]);
                int remoteRole = StringToInteger(parts[2]);
                
                Print("INFO: Received state from server - Generation: ", remoteGen, ", Role: ", remoteRole);
                
                // Update local state if needed
                if(remoteGen != currentGeneration) {
                    currentGeneration = remoteGen;
                    // Determine role based on generation
                    currentRole = (currentGeneration % 2 == 1) ? 
                         (IsServerAccount ? ROLE_BUY_HEAVY : ROLE_SELL_HEAVY) : 
                         (IsServerAccount ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY);
                    
                    Print("INFO: Updated generation to ", currentGeneration, ", role: ", 
                         (currentRole == ROLE_BUY_HEAVY ? "BUY-Heavy" : "SELL-Heavy"));
                }
            }
        }
        else if(command == "GEN_CHANGE") {
            // Generation change notification
            if(ArraySize(parts) > 1) {
                long remoteGen = StringToInteger(parts[1]);
                if(remoteGen != currentGeneration) {
                    currentGeneration = remoteGen;
                    // Switch roles
                    currentRole = (currentRole == ROLE_BUY_HEAVY) ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY;
                    generationStartTime = TimeCurrent();
                    
                    Print("INFO: Generation changed to ", currentGeneration, ", new role: ", 
                         (currentRole == ROLE_BUY_HEAVY ? "BUY-Heavy" : "SELL-Heavy"));
                    
                    // Close all positions for new generation
                    CloseAllPositions();
                }
            }
        }
        else if(command == "TRADE_OPEN") {
            // Trade opened on remote terminal
            if(ArraySize(parts) >= 4) {
                string type = parts[1];
                double lots = StringToDouble(parts[2]);
                double price = StringToDouble(parts[3]);
                
                Print("INFO: Remote trade opened - Type: ", type, ", Lots: ", lots, ", Price: ", price);
            }
        }
        else if(command == "TRADE_CLOSE") {
            // Trade closed on remote terminal
            if(ArraySize(parts) >= 4) {
                string type = parts[1];
                ulong ticket = StringToInteger(parts[2]);
                double profit = StringToDouble(parts[3]);
                
                Print("INFO: Remote trade closed - Type: ", type, ", Ticket: ", ticket, ", Profit: ", profit);
            }
        }
        else if(command == "SL_TRIGGER") {
            // Stop loss triggered on remote terminal
            Print("ALERT: Remote stop loss triggered - executing emergency stop loss");
            ExecuteEmergencyStopLoss();
        }
        else {
            Print("WARNING: Unknown command received: ", command);
        }
    }
}