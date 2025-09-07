//+------------------------------------------------------------------+
//|                        Dual Account Hedging and Scalping EA       |
//|                              Copyright 2025                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property strict

// Include necessary libraries
#include <Trade\Trade.mqh>
#include <Socket\Socket.mqh>

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
input bool             IsServerAccount        = false;          // Is this the server account?
input int              ServerPort             = 30303;          // Server port for socket connection
input string           ServerAddress          = "127.0.0.1";    // Server address (local for MT5 instances)

input string           TradeSettings          = "===== Trade Settings =====";
input double           LotSize                = 0.01;           // Lot size for trades
input bool             CompoundProfits        = false;          // Enable profit compounding
input bool             StopLossMode           = false;          // Enable stop loss
input double           StopLossPips           = 10.0;           // Stop loss in pips

// Global variables
CTrade            trade;                        // Trade object
CSocket           socket;                       // Socket object
ACCOUNT_ROLE      currentRole;                  // Current role of this account
int               currentGeneration = 1;        // Current generation counter
datetime          generationStartTime;          // Generation start time
bool              isConnected = false;          // Socket connection status
string            currentSymbol;                // Current trading symbol
double            point;                        // Point value for the current symbol
int               digits;                       // Digits for the current symbol
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
   digits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
   point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
   pipValue = (digits == 3 || digits == 5) ? point * 10 : point;
   
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
      if (!socket.Create(ServerPort, SOCKET_SERVER)) {
         Print("Failed to create server socket on port ", ServerPort);
         return INIT_FAILED;
      }
      Print("Server socket created on port ", ServerPort);
   } else {
      if (!socket.Create()) {
         Print("Failed to create client socket");
         return INIT_FAILED;
      }
      if (!socket.Connect(ServerAddress, ServerPort)) {
         Print("Failed to connect to server at ", ServerAddress, ":", ServerPort);
         return INIT_FAILED;
      }
      Print("Connected to server at ", ServerAddress, ":", ServerPort);
      isConnected = true;
      
      // Send initial handshake
      string handshakeMsg = "CONNECT|" + currentSymbol;
      socket.Send(handshakeMsg);
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
         socket.Send(genChangeMsg);
      }
      
      Print("Switched to Generation ", currentGeneration, ", new role: ", 
            (currentRole == ROLE_BUY_HEAVY) ? "BUY-Heavy" : "SELL-Heavy");
   }
}

//+------------------------------------------------------------------+
//| Process incoming socket messages                                 |
//+------------------------------------------------------------------+
void ProcessSocketMessages() {
   if (IsServerAccount) {
      // Check for new connections
      if (socket.Accept()) {
         isConnected = true;
         Print("Client connected");
         
         // Send current state
         string stateMsg = "STATE|" + IntegerToString(currentGeneration) + "|" + 
                           IntegerToString(currentRole);
         socket.Send(stateMsg);
      }
   }
   
   // Process messages if connected
   if (isConnected || socket.IsConnected()) {
      char buffer[];
      uint len = socket.Receive(buffer);
      
      if (len > 0) {
         string message = CharArrayToString(buffer);
         string parts[];
         StringSplit(message, '|', parts);
         
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
                  int remoteGen = StringToInteger(parts[1]);
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
      }
   }
   
   // Check for server account accepting new connections
   if (IsServerAccount && !socket.IsConnected()) {
      socket.Accept();
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
                                 DoubleToString(trade.ResultPrice(), digits);
               socket.Send(tradeMsg);
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
                                 DoubleToString(trade.ResultPrice(), digits);
               socket.Send(tradeMsg);
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
                                 DoubleToString(trade.ResultPrice(), digits);
               socket.Send(tradeMsg);
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
                                 DoubleToString(trade.ResultPrice(), digits);
               socket.Send(tradeMsg);
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
         socket.Send(closeMsg);
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
                                    DoubleToString(trade.ResultPrice(), digits);
                  socket.Send(tradeMsg);
               }
            }
         }
         else { // SELL
            if (trade.Sell(newLotSize, currentSymbol)) {
               Print("Reopened SELL position, Ticket: ", trade.ResultOrder(), ", Price: ", trade.ResultPrice());
               
               // Notify other terminal
               if (isConnected || socket.IsConnected()) {
                  string tradeMsg = "TRADE_OPEN|SELL|" + DoubleToString(newLotSize, 2) + "|" + 
                                    DoubleToString(trade.ResultPrice(), digits);
                  socket.Send(tradeMsg);
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
                  socket.Send(slMsg);
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
                  socket.Send(slMsg);
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
