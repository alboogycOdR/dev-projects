/*https://www.mql5.com/en/docs/network/socketconnect




   MetaTrader 5 Expert Advisor that implements the hedging and scalping strategy between two account terminals . 
   AI PROMPT
   https://claude.ai/chat/e6aa1a5a-485d-4fa5-8425-fa8414accf46

   DOCUMENTATION
   https://www.notion.so/EA-Dual-Account-Hedging-and-Scalping-1c649e541670801e9427cf9bb8c30eb7?pvs=4


   This will involve socket communication for synchronization, generational trading logic, and high-speed execution

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
   The EA uses a standard socket library to establish communication between terminals
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

// Enum for account roles
enum ACCOUNT_ROLE {
   ROLE_BUY_HEAVY,     // Account with more BUY positions
   ROLE_SELL_HEAVY     // Account with more SELL positions
};

// Enum for operational modes
enum OPERATIONAL_MODE {
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
input int              ServerPort             = 30303;          // Server port for socket connection
input string           ServerAddress          = "127.0.0.1";    // Server address (local for MT5 instances)

input string           TradeSettings          = "===== Trade Settings =====";
input double           LotSize                = 0.01;           // Lot size for trades
input bool             CompoundProfits        = false;          // Enable profit compounding
input bool             StopLossMode           = false;          // Enable stop loss
input double           StopLossPips           = 10.0;           // Stop loss in pips

// Global variables
CTrade            trade;                        // Trade object

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

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize symbol information
   if (Symbol == "") {
      currentSymbol = Symbol();
   } else {
      currentSymbol = Symbol;
   }
   
   // Get symbol properties
   smbl_dgts = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
   point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
   pipValue = (smbl_dgts == 3 || smbl_dgts == 5) ? point * 10 : point;
   
   // Set up trade object
   trade.SetExpertMagicNumber(123456);
   
   // Start generation timer
   generationStartTime = TimeCurrent();
   
   // Determine initial role based on generation
   currentRole = (currentGeneration % 2 == 1) ? 
                 (IsServerAccount ? ROLE_BUY_HEAVY : ROLE_SELL_HEAVY) : 
                 (IsServerAccount ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY);
   
   // Initialize socket connection
   if (IsServerAccount) {
      Print("Attempting to create server socket on address: ", ServerAddress, ", port: ", ServerPort);
      if (!socket.Open(ServerAddress, ServerPort, 5000, false, true)) {
         int error = GetLastError();
         Print("Failed to create server socket. Error code: ", error, " (", ErrorDescription(error), ")");
         return INIT_FAILED;
      }
      Print("Server socket created successfully. Socket ID: ", socket.SocketID(), ", Connected: ", socket.IsConnected());
   } else {
      Print("Attempting to connect to server at: ", ServerAddress, ", port: ", ServerPort);
      if (!socket.Open(ServerAddress, ServerPort, 5000, false, true)) {
         int error = GetLastError();
         Print("Failed to connect to server. Error code: ", error, " (", ErrorDescription(error), ")");
         return INIT_FAILED;
      }
      Print("Connected to server successfully. Socket ID: ", socket.SocketID(), ", Connected: ", socket.IsConnected());
      isConnected = true;
      
      // Send initial handshake
      string handshakeMsg = "CONNECT|" + currentSymbol;
      Print("Sending handshake message: ", handshakeMsg);
      uchar buffer[];
      StringToCharArray(handshakeMsg, buffer);
      int sendResult = socket.Send(buffer, ArraySize(buffer));
      if (sendResult <= 0) {
         int error = GetLastError();
         Print("Failed to send handshake. Error code: ", error, " (", ErrorDescription(error), "), Send result: ", sendResult);
      } else {
         Print("Handshake sent successfully. Bytes sent: ", sendResult);
      }
   }
   
   // Add chart description
   string roleStr = (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy";
   Comment("Generation: ", currentGeneration, "\nRole: ", roleStr);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   socket.Close();
   Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Update spread
   spread = SymbolInfoInteger(currentSymbol, SYMBOL_SPREAD) * point;
   
   // Check if we need to switch generations
   CheckGenerationSwitch();
   
   // Process socket communications
   ProcessSocketMessages();
   
   // Update position counts
   UpdatePositionCounts();
   
   // Execute hedging strategy
   ExecuteHedgingStrategy();
   
   // Execute scalping strategy
   ExecuteScalpingStrategy();
   
   // Apply stop loss if enabled
   if (StopLossMode) {
      ApplyStopLoss();
   }
   
   // Update chart info
   UpdateChartInfo();
}

//+------------------------------------------------------------------+
//| Check if we need to switch to a new generation                   |
//+------------------------------------------------------------------+
void CheckGenerationSwitch() {
   if (TimeCurrent() - generationStartTime >= GenerationDuration) {
      // Increment generation
      currentGeneration++;
      
      // Switch roles
      currentRole = (currentRole == ROLE_BUY_HEAVY) ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY;
      
      // Reset generation timer
      generationStartTime = TimeCurrent();
      
      // Close all existing positions
      CloseAllPositions();
      
      // Send generation change message
      if (isConnected || socket.IsConnected()) {
         string genChangeMsg = "GEN_CHANGE|" + IntegerToString(currentGeneration);
         uchar buffer[];
         StringToCharArray(genChangeMsg, buffer);
         socket.Send(buffer, ArraySize(buffer));
      }
      
      Print("Switched to Generation ", currentGeneration, ", new role: ", 
            (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy");
   }
}

//+------------------------------------------------------------------+
//| Process incoming socket messages                                 |
//+------------------------------------------------------------------+
void ProcessSocketMessages() {
   // Debug socket status
   Print("Socket status - ID: ", socket.SocketID(), ", Connected: ", socket.IsConnected(), 
         ", Readable: ", socket.Readable(), ", Writable: ", socket.Writable());
         
   if (IsServerAccount) {
      // Check for new connections
      if (!isConnected && socket.IsConnected()) {
         isConnected = true;
         Print("Client connected! Socket is now connected.");
         
         // Send current state
         string stateMsg = "STATE|" + IntegerToString(currentGeneration) + "|" + 
                           IntegerToString(currentRole);
         Print("Sending state message to client: ", stateMsg);
         uchar buffer[];
         StringToCharArray(stateMsg, buffer);
         int sendResult = socket.Send(buffer, ArraySize(buffer));
         if (sendResult <= 0) {
            int error = GetLastError();
            Print("Failed to send state message. Error code: ", error, " (", ErrorDescription(error), "), Send result: ", sendResult);
         } else {
            Print("State message sent successfully. Bytes sent: ", sendResult);
         }
      }
   }
   
   // Process messages if connected
   if (isConnected || socket.IsConnected()) {
      uint readableBytes = socket.Readable();
      if (readableBytes > 0) {
         Print("Data available to read: ", readableBytes, " bytes");
      }
      
      uchar buffer[1024]; // Define a fixed size buffer
      int len = socket.Read(buffer, 1024, 5000, false);
      
      if (len > 0) {
         string message = CharArrayToString(buffer);
         Print("Received message: '", message, "' (", len, " bytes)");
         
         string parts[];
         StringSplit(message, '|', parts);
         Print("Message split into ", ArraySize(parts), " parts");
         
         if (ArraySize(parts) > 0) {
            // Handle different message types
            if (parts[0] == "CONNECT") {
               // Connection handshake
               if (ArraySize(parts) > 1 && parts[1] != currentSymbol) {
                  Print("Symbol mismatch! Local: ", currentSymbol, ", Remote: ", parts[1]);
                  ExpertRemove();
               }
            }
            else if (parts[0] == "GEN_CHANGE") {
               // Generation change notification
               if (ArraySize(parts) > 1) {
                  long remoteGen = StringToInteger(parts[1]);
                  if (remoteGen != currentGeneration) {
                     currentGeneration = remoteGen;
                     currentRole = (currentRole == ROLE_BUY_HEAVY) ? ROLE_SELL_HEAVY : ROLE_BUY_HEAVY;
                     generationStartTime = TimeCurrent();
                     CloseAllPositions();
                     Print("Remote Generation Change to ", currentGeneration, ", new role: ", 
                           (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy");
                  }
               }
            }
            else if (parts[0] == "TRADE_OPEN") {
               // Trade opened on remote terminal
               // Format: TRADE_OPEN|BUY/SELL|LotSize|Price
               if (ArraySize(parts) >= 4) {
                  string type = parts[1];
                  double lots = StringToDouble(parts[2]);
                  double price = StringToDouble(parts[3]);
                  
                  Print("Remote trade opened: ", type, ", Lots: ", lots, ", Price: ", price);
               }
            }
            else if (parts[0] == "TRADE_CLOSE") {
               // Trade closed on remote terminal
               // Format: TRADE_CLOSE|BUY/SELL|Ticket|Profit
               if (ArraySize(parts) >= 4) {
                  string type = parts[1];
                  ulong ticket = StringToInteger(parts[2]);
                  double profit = StringToDouble(parts[3]);
                  
                  Print("Remote trade closed: ", type, ", Ticket: ", ticket, ", Profit: ", profit);
               }
            }
            else if (parts[0] == "SL_TRIGGER") {
               // Stop loss triggered on remote terminal
               // Immediately apply stop loss to corresponding positions
               ExecuteEmergencyStopLoss();
               Print("Remote Stop Loss triggered - executing emergency stop loss");
            }
         }
      } else if (len < 0) {
         int error = GetLastError();
         Print("Error reading from socket. Error code: ", error, " (", ErrorDescription(error), ")");
      }
   } else {
      Print("Socket not connected or ready for communication");
   }
   
   // More detailed debugging for server account reconnection
   if (IsServerAccount && !isConnected) {
      Print("Server waiting for client connection. Socket status - Connected: ", socket.IsConnected(), 
            ", Readable: ", socket.Readable(), ", Writable: ", socket.Writable());
            
      if (socket.IsConnected()) {
         isConnected = true;
         Print("Client reconnected! Socket is now connected.");
      }
   }
}

//+------------------------------------------------------------------+
//| Update the count of open positions                               |
//+------------------------------------------------------------------+
void UpdatePositionCounts() {
   buyPositionsCount = 0;
   sellPositionsCount = 0;
   
   // Reset arrays
   ArrayResize(buyPositions, 0);
   ArrayResize(sellPositions, 0);
   
   // Count positions
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
         if (PositionGetString(POSITION_SYMBOL) == currentSymbol) {
            long type = PositionGetInteger(POSITION_TYPE);
            
            if (type == POSITION_TYPE_BUY) {
               buyPositionsCount++;
               int size = ArraySize(buyPositions);
               ArrayResize(buyPositions, size + 1);
               buyPositions[size] = ticket;
            }
            else if (type == POSITION_TYPE_SELL) {
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
void ExecuteHedgingStrategy() {
   // Verify the current role and open positions accordingly
   if (currentRole == ROLE_BUY_HEAVY) {
      // This account should have 2 BUY and 1 SELL
      while (buyPositionsCount < 2) {
         if (trade.Buy(LotSize, currentSymbol)) {
            Print("Opened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            
            // Notify other terminal
            if (isConnected || socket.IsConnected()) {
               string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(LotSize, 2) + "|" + 
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer);
               socket.Send(buffer, ArraySize(buffer));
            }
            
            buyPositionsCount++;
         } else {
            Print("Failed to open BUY position, Error: ", GetLastError());
            break;
         }
      }
      
      while (sellPositionsCount < 1) {
         if (trade.Sell(LotSize, currentSymbol)) {
            Print("Opened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            
            // Notify other terminal
            if (isConnected || socket.IsConnected()) {
               string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(LotSize, 2) + "|" + 
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer);
               socket.Send(buffer, ArraySize(buffer));
            }
            
            sellPositionsCount++;
         } else {
            Print("Failed to open SELL position, Error: ", GetLastError());
            break;
         }
      }
   }
   else { // ROLE_SELL_HEAVY
      // This account should have 2 SELL and 1 BUY
      while (sellPositionsCount < 2) {
         if (trade.Sell(LotSize, currentSymbol)) {
            Print("Opened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            
            // Notify other terminal
            if (isConnected || socket.IsConnected()) {
               string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(LotSize, 2) + "|" + 
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer);
               socket.Send(buffer, ArraySize(buffer));
            }
            
            sellPositionsCount++;
         } else {
            Print("Failed to open SELL position, Error: ", GetLastError());
            break;
         }
      }
      
      while (buyPositionsCount < 1) {
         if (trade.Buy(LotSize, currentSymbol)) {
            Print("Opened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
            
            // Notify other terminal
            if (isConnected || socket.IsConnected()) {
               string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(LotSize, 2) + "|" + 
                                 DoubleToString(trade.ResultPrice(), smbl_dgts);
               uchar buffer[];
               StringToCharArray(tradeMsg, buffer);
               socket.Send(buffer, ArraySize(buffer));
            }
            
            buyPositionsCount++;
         } else {
            Print("Failed to open BUY position, Error: ", GetLastError());
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Execute the scalping strategy                                    |
//+------------------------------------------------------------------+
void ExecuteScalpingStrategy() {
   // Implement high-speed scalping
   if (currentRole == ROLE_BUY_HEAVY) {
      // For BUY-heavy account:
      // Check BUY positions for profit
      for (int i = 0; i < ArraySize(buyPositions); i++) {
         if (IsPositionProfitable(buyPositions[i], true)) {
            ClosePositionWithTicket(buyPositions[i]);
         }
      }
      
      // Check SELL position for profit
      for (int i = 0; i < ArraySize(sellPositions); i++) {
         if (IsPositionProfitable(sellPositions[i], false)) {
            ClosePositionWithTicket(sellPositions[i]);
         }
      }
   }
   else { // ROLE_SELL_HEAVY
      // For SELL-heavy account:
      // Check SELL positions for profit
      for (int i = 0; i < ArraySize(sellPositions); i++) {
         if (IsPositionProfitable(sellPositions[i], false)) {
            ClosePositionWithTicket(sellPositions[i]);
         }
      }
      
      // Check BUY position for profit
      for (int i = 0; i < ArraySize(buyPositions); i++) {
         if (IsPositionProfitable(buyPositions[i], true)) {
            ClosePositionWithTicket(buyPositions[i]);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if a position is profitable                                |
//+------------------------------------------------------------------+
bool IsPositionProfitable(ulong ticket, bool isBuy) {
   if (!PositionSelectByTicket(ticket)) {
      return false;
   }
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double volume = PositionGetDouble(POSITION_VOLUME);
   
   // Get current bid/ask
   double currentBid = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
   
   // Calculate profit considering spread
   if (isBuy) {
      // For BUY positions, we close at BID price
      double potentialProfit = volume * ((currentBid - openPrice) / point);
      return (potentialProfit > 0 && profit > 0);
   }
   else {
      // For SELL positions, we close at ASK price
      double potentialProfit = volume * ((openPrice - currentAsk) / point);
      return (potentialProfit > 0 && profit > 0);
   }
}

//+------------------------------------------------------------------+
//| Close a position with the given ticket                           |
//+------------------------------------------------------------------+
void ClosePositionWithTicket(ulong ticket) {
   if (!PositionSelectByTicket(ticket)) {
      return;
   }
   
   string posType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   double profit = PositionGetDouble(POSITION_PROFIT);
   
   if (trade.PositionClose(ticket, ULONG_MAX)) {
      Print("Closed ", posType, " position, Ticket: ", ticket, ", Profit: ", profit);
      
      // Notify other terminal
      if (isConnected || socket.IsConnected()) {
         string closeMsg = "TRADE_CLOSE|" + posType + "|" + IntegerToString(ticket) + "|" + 
                          DoubleToString(profit, 2);
         uchar buffer[];
         StringToCharArray(closeMsg, buffer);
         socket.Send(buffer, ArraySize(buffer));
      }
      
      // Reopen position based on account role (to maintain the balance)
      if ((posType == "BUY" && currentRole == ROLE_BUY_HEAVY) || 
          (posType == "SELL" && currentRole == ROLE_SELL_HEAVY)) {
         
         // Calculate new lot size if compounding is enabled
         double newLotSize = LotSize;
         if (CompoundProfits && profit > 0) {
            // Simple compounding: increase lot size proportionally to profit
            double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            double profitPercentage = profit / accountBalance;
            newLotSize = LotSize * (1 + profitPercentage);
            
            // Round to valid lot size
            newLotSize = NormalizeDouble(newLotSize, 2);
            
            // Ensure minimum lot size
            if (newLotSize < SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN)) {
               newLotSize = SymbolInfoDouble(currentSymbol, SYMBOL_VOLUME_MIN);
            }
         }
         
         // Reopen position
         if (posType == "BUY") {
            if (trade.Buy(newLotSize, currentSymbol)) {
               Print("Reopened BUY position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
               
               // Notify other terminal
               if (isConnected || socket.IsConnected()) {
                  string tradeMsg = "TRADE_OPEN|BUY|" + DoubleToString(newLotSize, 2) + "|" + 
                                    DoubleToString(trade.ResultPrice(), smbl_dgts);
                  uchar buffer[];
                  StringToCharArray(tradeMsg, buffer);
                  socket.Send(buffer, ArraySize(buffer));
               }
            }
         }
         else { // SELL
            if (trade.Sell(newLotSize, currentSymbol)) {
               Print("Reopened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
               
               // Notify other terminal
               if (isConnected || socket.IsConnected()) {
                  string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(newLotSize, 2) + "|" + 
                                    DoubleToString(trade.ResultPrice(), smbl_dgts);
                  uchar buffer[];
                  StringToCharArray(tradeMsg, buffer);
                  socket.Send(buffer, ArraySize(buffer));
               }
            }
         }
      }
   } else {
      Print("Failed to close position, Ticket: ", ticket, ", Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Apply stop loss to positions if enabled                          |
//+------------------------------------------------------------------+
void ApplyStopLoss() {
   // Only apply stop loss to the dominant position type
   if (currentRole == ROLE_BUY_HEAVY) {
      // Apply stop loss to BUY positions
      for (int i = 0; i < ArraySize(buyPositions); i++) {
         if (PositionSelectByTicket(buyPositions[i])) {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = openPrice - (StopLossPips * pipValue);
            
            // Check if stop loss is breached
            double currentBid = SymbolInfoDouble(currentSymbol, SYMBOL_BID);
            if (currentBid <= stopLoss) {
               // Trigger stop loss
               Print("Stop Loss triggered for BUY position, Ticket: ", buyPositions[i]);
               
               // Send SL trigger message to other terminal
               if (isConnected || socket.IsConnected()) {
                  string slMsg = "SL_TRIGGER";
                  uchar buffer[];
                  StringToCharArray(slMsg, buffer);
                  socket.Send(buffer, ArraySize(buffer));
               }
               
               // Close all positions in both accounts
               CloseAllPositions();
               break;
            }
         }
      }
   }
   else { // ROLE_SELL_HEAVY
      // Apply stop loss to SELL positions
      for (int i = 0; i < ArraySize(sellPositions); i++) {
         if (PositionSelectByTicket(sellPositions[i])) {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = openPrice + (StopLossPips * pipValue);
            
            // Check if stop loss is breached
            double currentAsk = SymbolInfoDouble(currentSymbol, SYMBOL_ASK);
            if (currentAsk >= stopLoss) {
               // Trigger stop loss
               Print("Stop Loss triggered for SELL position, Ticket: ", sellPositions[i]);
               
               // Send SL trigger message to other terminal
               if (isConnected || socket.IsConnected()) {
                  string slMsg = "SL_TRIGGER";
                  uchar buffer[];
                  StringToCharArray(slMsg, buffer);
                  socket.Send(buffer, ArraySize(buffer));
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
void ExecuteEmergencyStopLoss() {
   CloseAllPositions();
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
         if (PositionGetString(POSITION_SYMBOL) == currentSymbol) {
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
void UpdateChartInfo() {
   string roleStr = (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-HEAVY";
   string genInfo = "Generation: " + IntegerToString(currentGeneration) + 
                   "\nRole: " + roleStr + 
                   "\nTime left: " + IntegerToString(GenerationDuration - (TimeCurrent() - generationStartTime)) + " sec" +
                   "\nBuy Positions: " + IntegerToString(buyPositionsCount) + 
                   "\nSell Positions: " + IntegerToString(sellPositionsCount);
   Comment(genInfo);
}

// Add a new helper function to format error messages
string ErrorDescription(int errorCode) {
   switch(errorCode) {
      // Standard MQL5 error codes
      case 1: return "No error, but result is unknown";
      case 2: return "Common error";
      case 3: return "Invalid trade parameters";
      case 4: return "Trade server is busy";
      case 5: return "Old version of the client terminal";
      case 6: return "No connection with trade server";
      case 7: return "Not enough rights";
      case 8: return "Too frequent requests";
      case 9: return "Malfunctional trade operation";
      case 64: return "Account disabled";
      case 65: return "Invalid account";
      case 128: return "Trade timeout";
      case 129: return "Invalid price";
      case 130: return "Invalid stops";
      
      // Socket-specific errors (based on Windows socket error codes)
      case 10004: return "Interrupted system call";
      case 10009: return "Bad file number";
      case 10013: return "Access denied";
      case 10014: return "Bad address";
      case 10022: return "Invalid argument";
      case 10024: return "Too many open files";
      case 10035: return "Resource temporarily unavailable (socket would block)";
      case 10036: return "Operation now in progress";
      case 10037: return "Operation already in progress";
      case 10038: return "Socket operation on non-socket";
      case 10040: return "Message too long";
      case 10049: return "Cannot assign requested address";
      case 10050: return "Network is down";
      case 10051: return "Network is unreachable";
      case 10052: return "Network dropped connection on reset";
      case 10053: return "Software caused connection abort";
      case 10054: return "Connection reset by peer";
      case 10055: return "No buffer space available";
      case 10056: return "Socket is already connected";
      case 10057: return "Socket is not connected";
      case 10058: return "Cannot send after socket shutdown";
      case 10060: return "Connection timed out";
      case 10061: return "Connection refused";
      case 10064: return "Host is down";
      case 10065: return "No route to host";
      
      // Custom socket error interpretations
      case 4000: return "Socket not created";
      case 4001: return "Socket connection error";
      case 4002: return "Socket read error";
      case 4003: return "Socket write error";
      
      default: return "Unknown error " + IntegerToString(errorCode);
   }
}
