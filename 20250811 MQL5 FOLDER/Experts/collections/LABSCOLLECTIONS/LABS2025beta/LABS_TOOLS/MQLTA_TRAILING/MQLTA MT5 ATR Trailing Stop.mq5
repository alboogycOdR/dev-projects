#property link          "https://www.earnforex.com/metatrader-expert-advisors/atr-trailing-stop/"
#property version       "1.08"

#property copyright     "EarnForex.com - 2019-2024"
#property description   "This expert advisor will trail the stop-loss using ATR as a distance from the price."
#property description   " "
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this EA cannot be held responsible for any damage or loss."
#property description   " "
#property description   "Find More on www.EarnForex.com"
//#property icon          "\\Files\\EF-Icon-64x64px.ico"

 
#include "MQLTA Utils.mqh"
#include <Trade/Trade.mqh>

enum ENUM_CONSIDER
{
    All = -1,                  // ALL ORDERS
    Buy = POSITION_TYPE_BUY,   // BUY ONLY
    Sell = POSITION_TYPE_SELL, // SELL ONLY
};

enum ENUM_CUSTOMTIMEFRAMES
{
    CURRENT = PERIOD_CURRENT,           // CURRENT PERIOD
    M1 = PERIOD_M1,                     // M1
    M5 = PERIOD_M5,                     // M5
    M15 = PERIOD_M15,                   // M15
    M30 = PERIOD_M30,                   // M30
    H1 = PERIOD_H1,                     // H1
    H4 = PERIOD_H4,                     // H4
    D1 = PERIOD_D1,                     // D1
    W1 = PERIOD_W1,                     // W1
    MN1 = PERIOD_MN1,                   // MN1
};

input string Comment_1 = "====================";  // Expert Advisor Settings
input int ATRPeriod = 14;                         // ATR Period
input int Shift = 1;                              // Shift In The ATR Value (1=Previous Candle)
input double ATRMultiplier = 1.0;                 // ATR Multiplier
input string Comment_2 = "====================";  // Orders Filtering Options
input bool OnlyCurrentSymbol = true;              // Apply To Current Symbol Only
input ENUM_CONSIDER OnlyType = All;               // Apply To
input bool UseMagic = false;                      // Filter By Magic Number
input int MagicNumber = 0;                        // Magic Number (if above is true)
input bool UseComment = false;                    // Filter By Comment
input string CommentFilter = "";                  // Comment (if above is true)
input bool EnableTrailingParam = false;           // Enable Trailing Stop
input string Comment_3 = "====================";  // Notification Options
input bool EnableNotify = false;                  // Enable Notifications feature
input bool SendAlert = true;                      // Send Alert Notification
input bool SendApp = true;                        // Send Notification to Mobile
input bool SendEmail = true;                      // Send Notification via Email
input string Comment_3a = "===================="; // Graphical Window
input bool ShowPanel = true;                      // Show Graphical Panel
input string ExpertName = "MQLTA-ATRTS";          // Expert Name (to name the objects)
input int Xoff = 20;                              // Horizontal spacing for the control panel
input int Yoff = 20;                              // Vertical spacing for the control panel

int OrderOpRetry = 5;
bool EnableTrailing = EnableTrailingParam;
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovX, PanelMovY, PanelLabX, PanelLabY, PanelRecX;

string Symbols[]; // Will store symbols for handles.
int SymbolHandles[]; // Will store actual handles.

CTrade *Trade; // Trading object.

int OnInit()
{
    EnableTrailing = EnableTrailingParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovX = (int)MathRound(50 * DPIScale);
    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (int)MathRound(150 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;
    
    if (ShowPanel) DrawPanel();

    ArrayResize(Symbols, 1, 10); // At least one (current symbol) and up to 10 reserved space.
    ArrayResize(SymbolHandles, 1, 10);
    
    Symbols[0] = Symbol();
    SymbolHandles[0] = iATR(Symbol(), PERIOD_CURRENT, ATRPeriod);
    
	Trade = new CTrade;

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    CleanPanel();
    delete Trade;
}

void OnTick()
{
    if (EnableTrailing) TrailingStop();
    if (ShowPanel) DrawPanel();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == PanelEnableDisable)
        {
            ChangeTrailingEnabled();
        }
    }
    else if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27)
        {
            if (MessageBox("Are you sure you want to close the EA?", "EXIT?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
}

double GetATR(string symbol)
{
    double buf[1];
    int index = FindHandle(symbol);
    if (index == -1) // Not found.
    {
        // Create handle.
        int new_size = ArraySize(Symbols) + 1;
        ArrayResize(Symbols, new_size, 10);
        ArrayResize(SymbolHandles, new_size, 10);
        
        index = new_size - 1;
        Symbols[index] = symbol;
        SymbolHandles[index] = iATR(symbol, PERIOD_CURRENT, ATRPeriod);
    }
    // Copy buffer.
    int n = CopyBuffer(SymbolHandles[index], 0, Shift, 1, buf);
    if (n < 1)
    {
        Print("PSAR data not ready for " + Symbols[index] + ".");
    }
    return buf[0];
}

double GetStopLossBuy(string symbol)
{
    return iClose(symbol, PERIOD_CURRENT, 0) - GetATR(symbol) * ATRMultiplier;
}

double GetStopLossSell(string symbol)
{
    return iClose(symbol, PERIOD_CURRENT, 0) + GetATR(symbol) * ATRMultiplier;
}

void TrailingStop()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0)
        {
            Print("PositionGetTicket failed " + IntegerToString(GetLastError()) + ".");
            continue;
        }

        if (PositionSelectByTicket(ticket) == false)
        {
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - Unable to select the position #", IntegerToString(ticket), " - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        if ((OnlyCurrentSymbol) && (PositionGetString(POSITION_SYMBOL) != Symbol())) continue;
        if ((UseMagic) && (PositionGetInteger(POSITION_MAGIC) != MagicNumber)) continue;
        if ((UseComment) && (StringFind(PositionGetString(POSITION_COMMENT), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (PositionGetInteger(POSITION_TYPE) != OnlyType)) continue;

        double NewSL = 0;
        double NewTP = 0;
        string Instrument = PositionGetString(POSITION_SYMBOL);
        double SLBuy = GetStopLossBuy(Instrument);
        double SLSell = GetStopLossSell(Instrument);
        if ((SLBuy == 0) || (SLSell == 0) || (SLSell == EMPTY_VALUE) || (SLSell == EMPTY_VALUE))
        {
            Print("Not enough historical data - please load more candles for the selected timeframe.");
            return;
        }

        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);
        SLBuy = NormalizeDouble(SLBuy, eDigits);
        SLSell = NormalizeDouble(SLSell, eDigits);
        double SLPrice = NormalizeDouble(PositionGetDouble(POSITION_SL), eDigits);
        double TPPrice = NormalizeDouble(PositionGetDouble(POSITION_TP), eDigits);
        double Spread = SymbolInfoInteger(Instrument, SYMBOL_SPREAD) * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        double StopLevel = SymbolInfoInteger(Instrument, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(Instrument, SYMBOL_POINT);
        // Adjust for tick size granularity.
        double TickSize = SymbolInfoDouble(Instrument, SYMBOL_TRADE_TICK_SIZE);
        if (TickSize > 0)
        {
            SLBuy = NormalizeDouble(MathRound(SLBuy / TickSize) * TickSize, eDigits);
            SLSell = NormalizeDouble(MathRound(SLSell / TickSize) * TickSize, eDigits);
        }
        if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) && (SLBuy < SymbolInfoDouble(Instrument, SYMBOL_BID) - StopLevel))
        {
            NewSL = NormalizeDouble(SLBuy, eDigits);
            NewTP = TPPrice;
            if ((NewSL > SLPrice) || (SLPrice == 0))
            {
                
                ModifyOrder(ticket, NewSL, NewTP);
            }
        }
        else if ((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) && (SLSell > SymbolInfoDouble(Instrument, SYMBOL_ASK) + StopLevel))
        {
            NewSL = NormalizeDouble(SLSell + Spread, eDigits);
            NewTP = TPPrice;
            if ((NewSL < SLPrice) || (SLPrice == 0))
            {
                ModifyOrder(ticket, NewSL, NewTP);
            }
        }
    }
}

void ModifyOrder(ulong Ticket, double SLPrice, double TPPrice)
{
    string symbol = PositionGetString(POSITION_SYMBOL);
    int eDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    SLPrice = NormalizeDouble(SLPrice, eDigits);
    TPPrice = NormalizeDouble(TPPrice, eDigits);
    for (int i = 1; i <= OrderOpRetry; i++)
    {
        bool res = Trade.PositionModify(Ticket, SLPrice, TPPrice);
        if (!res)
        {
            Print("Wrong position midification request: ", Ticket, " in ", symbol, " at SL = ", SLPrice, ", TP = ", TPPrice);
            return;
        }
		if ((Trade.ResultRetcode() == 10008) || (Trade.ResultRetcode() == 10009) || (Trade.ResultRetcode() == 10010)) // Success.
        {
            Print("TRADE - UPDATE SUCCESS - Position ", Ticket, " in ", symbol, ": new stop-loss ", SLPrice, " new take-profit ", TPPrice);
            NotifyStopLossUpdate(Ticket, SLPrice, symbol);
            break;
        }
        else
        {
			Print("Position Modify Return Code: ", Trade.ResultRetcodeDescription());
            int Error = GetLastError();
            string ErrorText = GetLastErrorText(Error);
            Print("ERROR - UPDATE FAILED - error modifying position ", Ticket, " in ", symbol, " return error: ", Error, " Open=", PositionGetDouble(POSITION_PRICE_OPEN),
                  " Old SL=", PositionGetDouble(POSITION_SL), " Old TP=", PositionGetDouble(POSITION_TP),
                  " New SL=", SLPrice, " New TP=", TPPrice, " Bid=", SymbolInfoDouble(symbol, SYMBOL_BID), " Ask=", SymbolInfoDouble(symbol, SYMBOL_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(ulong OrderNumber, double SLPrice, string symbol)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = ExpertName + " " + symbol + " Notification ";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n" + ExpertName + " Notification for " + symbol + "\r\n";
    EmailBody += "Stop-loss for position " + IntegerToString(OrderNumber) + " moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    string AlertText = symbol + " - stop-loss for position " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "stop-loss for position: " + IntegerToString(OrderNumber) + " was moved to " + DoubleToString(SLPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) + "";
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
}

string PanelBase = ExpertName + "-P-BAS";
string PanelLabel = ExpertName + "-P-LAB";
string PanelEnableDisable = ExpertName + "-P-ENADIS";
void DrawPanel()
{
    string PanelText = "MQLTA ATRTS";
    string PanelToolTip = "ATR Trailing Stop-Loss by EarnForex.com";

    int Rows = 1;
    ObjectCreate(0, PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(0, PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(0, PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    string EnableDisabledText = "";
    color EnableDisabledColor = clrNavy;
    color EnableDisabledBack = clrKhaki;
    if (EnableTrailing)
    {
        EnableDisabledText = "TRAILING ENABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkGreen;
    }
    else
    {
        EnableDisabledText = "TRAILING DISABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkRed;
    }

    DrawEdit(PanelEnableDisable,
             Xoff + 2,
             Yoff + (PanelMovY + 1) * Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Click to Enable or Disable the Trailing Stop Feature",
             ALIGN_CENTER,
             "Consolas",
             EnableDisabledText,
             false,
             EnableDisabledColor,
             EnableDisabledBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(0, PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * Rows + 3);
}

void CleanPanel()
{
    ObjectsDeleteAll(0, ExpertName + "-P-");
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (MQLInfoInteger(MQL_TRADE_ALLOWED)) EnableTrailing = true;
        else
        {
            MessageBox("You need to first enable Live Trading in the EA options.", "WARNING", MB_OK);
        }
    }
    else EnableTrailing = false;
    DrawPanel();
    ChartRedraw();
}

// Tries to find a handle for a symbol in arrays.
// Returns the index if found, -1 otherwise.
int FindHandle(string symbol)
{
    int size = ArraySize(Symbols);
    for (int i = 0; i < size; i++)
    {
        if (Symbols[i] == symbol) return i;
    }
    return -1;
}
//+------------------------------------------------------------------+


string GetLastErrorText(int Error){
   string Text="";
   //Print(Error);
   if(Error==ERR_SUCCESS) Text="The operation completed successfully";
   if(Error==ERR_INTERNAL_ERROR) Text="Unexpected internal error";
   if(Error==ERR_WRONG_INTERNAL_PARAMETER) Text="Wrong parameter in the inner call of the client terminal function";
   if(Error==ERR_INVALID_PARAMETER) Text="Wrong parameter when calling the system function";
   if(Error==ERR_NOT_ENOUGH_MEMORY) Text="Not enough memory to perform the system function";
   if(Error==ERR_STRUCT_WITHOBJECTS_ORCLASS) Text="The structure contains objects of strings and/or dynamic arrays and/or structure of such objects and/or classes";
   if(Error==ERR_INVALID_ARRAY) Text="Array of a wrong type, wrong size, or a damaged object of a dynamic array";
   if(Error==ERR_ARRAY_RESIZE_ERROR) Text="Not enough memory for the relocation of an array, or an attempt to change the size of a static array";
   if(Error==ERR_STRING_RESIZE_ERROR) Text="Not enough memory for the relocation of string";
   if(Error==ERR_NOTINITIALIZED_STRING) Text="Not initialized string";
   if(Error==ERR_INVALID_DATETIME) Text="Invalid date and/or time";
   if(Error==ERR_ARRAY_BAD_SIZE) Text="Requested array size exceeds 2 GB";
   if(Error==ERR_INVALID_POINTER) Text="Wrong pointer";
   if(Error==ERR_INVALID_POINTER_TYPE) Text="Wrong type of pointer";
   if(Error==ERR_FUNCTION_NOT_ALLOWED) Text="Function is not allowed for call";
   if(Error==ERR_RESOURCE_NAME_DUPLICATED) Text="The names of the dynamic and the static resource match";
   if(Error==ERR_RESOURCE_NOT_FOUND) Text="Resource with this name has not been found in EX5";
   if(Error==ERR_RESOURCE_UNSUPPORTED_TYPE) Text="Unsupported resource type or its size exceeds 16 Mb";
   if(Error==ERR_RESOURCE_NAME_IS_TOO_LONG) Text="The resource name exceeds 63 characters";
   if(Error==ERR_MATH_OVERFLOW) Text="Overflow occurred when calculating math function";
   if(Error==ERR_CHART_WRONG_ID) Text="Wrong chart ID";
   if(Error==ERR_CHART_NO_REPLY) Text="Chart does not respond";
   if(Error==ERR_CHART_NOT_FOUND) Text="Chart not found";
   if(Error==ERR_CHART_NO_EXPERT) Text="No Expert Advisor in the chart that could handle the event";
   if(Error==ERR_CHART_CANNOT_OPEN) Text="Chart opening error";
   if(Error==ERR_CHART_CANNOT_CHANGE) Text="Failed to change chart symbol and period";
   if(Error==ERR_CHART_WRONG_PARAMETER) Text="Error value of the parameter for the function of working with charts";
   if(Error==ERR_CHART_CANNOT_CREATE_TIMER) Text="Failed to create timer";
   if(Error==ERR_CHART_WRONG_PROPERTY) Text="Wrong chart property ID";
   if(Error==ERR_CHART_SCREENSHOT_FAILED) Text="Error creating screenshots";
   if(Error==ERR_CHART_NAVIGATE_FAILED) Text="Error navigating through chart";
   if(Error==ERR_CHART_TEMPLATE_FAILED) Text="Error applying template";
   if(Error==ERR_CHART_WINDOW_NOT_FOUND) Text="Subwindow containing the indicator was not found";
   if(Error==ERR_CHART_INDICATOR_CANNOT_ADD) Text="Error adding an indicator to chart";
   if(Error==ERR_CHART_INDICATOR_CANNOT_DEL) Text="Error deleting an indicator from the chart";
   if(Error==ERR_CHART_INDICATOR_NOT_FOUND) Text="Indicator not found on the specified chart";
   if(Error==ERR_OBJECT_ERROR) Text="Error working with a graphical object";
   if(Error==ERR_OBJECT_NOT_FOUND) Text="Graphical object was not found";
   if(Error==ERR_OBJECT_WRONG_PROPERTY) Text="Wrong ID of a graphical object property";
   if(Error==ERR_OBJECT_GETDATE_FAILED) Text="Unable to get date corresponding to the value";
   if(Error==ERR_OBJECT_GETVALUE_FAILED) Text="Unable to get value corresponding to the date";
   if(Error==ERR_MARKET_UNKNOWN_SYMBOL) Text="Unknown symbol";
   if(Error==ERR_MARKET_NOT_SELECTED) Text="Symbol is not selected in MarketWatch";
   if(Error==ERR_MARKET_WRONG_PROPERTY) Text="Wrong identifier of a symbol property";
   if(Error==ERR_MARKET_LASTTIME_UNKNOWN) Text="Time of the last tick is not known (no ticks)";
   if(Error==ERR_MARKET_SELECT_ERROR) Text="Error adding or deleting a symbol in MarketWatch";
   if(Error==ERR_HISTORY_NOT_FOUND) Text="Requested history not found";
   if(Error==ERR_HISTORY_WRONG_PROPERTY) Text="Wrong ID of the history property";
   if(Error==ERR_HISTORY_TIMEOUT) Text="Exceeded history request timeout";
   if(Error==ERR_HISTORY_BARS_LIMIT) Text="Number of requested bars limited by terminal settings";
   if(Error==ERR_HISTORY_LOAD_ERRORS) Text="Multiple errors when loading history";
   if(Error==ERR_HISTORY_SMALL_BUFFER) Text="Receiving array is too small to store all requested data";
   if(Error==ERR_GLOBALVARIABLE_NOT_FOUND) Text="Global variable of the client terminal is not found";
   if(Error==ERR_GLOBALVARIABLE_EXISTS) Text="Global variable of the client terminal with the same name already exists";
   if(Error==ERR_GLOBALVARIABLE_NOT_MODIFIED) Text="Global variables were not modified";
   if(Error==ERR_GLOBALVARIABLE_CANNOTREAD) Text="Cannot read file with global variable values";
   if(Error==ERR_GLOBALVARIABLE_CANNOTWRITE) Text="Cannot write file with global variable values";
   if(Error==ERR_MAIL_SEND_FAILED) Text="Email sending failed";
   if(Error==ERR_PLAY_SOUND_FAILED) Text="Sound playing failed";
   if(Error==ERR_MQL5_WRONG_PROPERTY) Text="Wrong identifier of the program property";
   if(Error==ERR_TERMINAL_WRONG_PROPERTY) Text="Wrong identifier of the terminal property";
   if(Error==ERR_FTP_SEND_FAILED) Text="File sending via ftp failed";
   if(Error==ERR_NOTIFICATION_SEND_FAILED) Text="Failed to send a notification";
   if(Error==ERR_NOTIFICATION_WRONG_PARAMETER) Text="Invalid parameter for sending a notification – an empty string or NULL has been passed to the SendNotification() function";
   if(Error==ERR_NOTIFICATION_WRONG_SETTINGS) Text="Wrong settings of notifications in the terminal (ID is not specified or permission is not set)";
   if(Error==ERR_NOTIFICATION_TOO_FREQUENT) Text="Too frequent sending of notifications";
   if(Error==ERR_FTP_NOSERVER) Text="FTP server is not specified";
   if(Error==ERR_FTP_NOLOGIN) Text="FTP login is not specified";
   if(Error==ERR_FTP_FILE_ERROR) Text="File not found in the MQL5\\Files directory to send on FTP server";
   if(Error==ERR_FTP_CONNECT_FAILED) Text="FTP connection failed";
   if(Error==ERR_FTP_CHANGEDIR) Text="FTP path not found on server";
   if(Error==ERR_BUFFERS_NO_MEMORY) Text="Not enough memory for the distribution of indicator buffers";
   if(Error==ERR_BUFFERS_WRONG_INDEX) Text="Wrong indicator buffer index";
   if(Error==ERR_CUSTOM_WRONG_PROPERTY) Text="Wrong ID of the custom indicator property";
   if(Error==ERR_ACCOUNT_WRONG_PROPERTY) Text="Wrong account property ID";
   if(Error==ERR_TRADE_WRONG_PROPERTY) Text="Wrong trade property ID";
   if(Error==ERR_TRADE_DISABLED) Text="Trading by Expert Advisors prohibited";
   if(Error==ERR_TRADE_POSITION_NOT_FOUND) Text="Position not found";
   if(Error==ERR_TRADE_ORDER_NOT_FOUND) Text="Order not found";
   if(Error==ERR_TRADE_DEAL_NOT_FOUND) Text="Deal not found";
   if(Error==ERR_TRADE_SEND_FAILED) Text="Trade request sending failed";
   if(Error==ERR_TRADE_CALC_FAILED) Text="Failed to calculate profit or margin";
   if(Error==ERR_INDICATOR_UNKNOWN_SYMBOL) Text="Unknown symbol";
   if(Error==ERR_INDICATOR_CANNOT_CREATE) Text="Indicator cannot be created";
   if(Error==ERR_INDICATOR_NO_MEMORY) Text="Not enough memory to add the indicator";
   if(Error==ERR_INDICATOR_CANNOT_APPLY) Text="The indicator cannot be applied to another indicator";
   if(Error==ERR_INDICATOR_CANNOT_ADD) Text="Error applying an indicator to chart";
   if(Error==ERR_INDICATOR_DATA_NOT_FOUND) Text="Requested data not found";
   if(Error==ERR_INDICATOR_WRONG_HANDLE) Text="Wrong indicator handle";
   if(Error==ERR_INDICATOR_WRONG_PARAMETERS) Text="Wrong number of parameters when creating an indicator";
   if(Error==ERR_INDICATOR_PARAMETERS_MISSING) Text="No parameters when creating an indicator";
   if(Error==ERR_INDICATOR_CUSTOM_NAME) Text="The first parameter in the array must be the name of the custom indicator";
   if(Error==ERR_INDICATOR_PARAMETER_TYPE) Text="Invalid parameter type in the array when creating an indicator";
   if(Error==ERR_INDICATOR_WRONG_INDEX) Text="Wrong index of the requested indicator buffer";
   if(Error==ERR_BOOKS_CANNOT_ADD) Text="Depth Of Market can not be added";
   if(Error==ERR_BOOKS_CANNOT_DELETE) Text="Depth Of Market can not be removed";
   if(Error==ERR_BOOKS_CANNOT_GET) Text="The data from Depth Of Market can not be obtained";
   if(Error==ERR_BOOKS_CANNOT_SUBSCRIBE) Text="Error in subscribing to receive new data from Depth Of Market";
   if(Error==ERR_TOO_MANY_FILES) Text="More than 64 files cannot be opened at the same time";
   if(Error==ERR_WRONG_FILENAME) Text="Invalid file name";
   if(Error==ERR_TOO_LONG_FILENAME) Text="Too long file name";
   if(Error==ERR_CANNOT_OPEN_FILE) Text="File opening error";
   if(Error==ERR_FILE_CACHEBUFFER_ERROR) Text="Not enough memory for cache to read";
   if(Error==ERR_CANNOT_DELETE_FILE) Text="File deleting error";
   if(Error==ERR_INVALID_FILEHANDLE) Text="A file with this handle was closed, or was not opening at all";
   if(Error==ERR_WRONG_FILEHANDLE) Text="Wrong file handle";
   if(Error==ERR_FILE_NOTTOWRITE) Text="The file must be opened for writing";
   if(Error==ERR_FILE_NOTTOREAD) Text="The file must be opened for reading";
   if(Error==ERR_FILE_NOTBIN) Text="The file must be opened as a binary one";
   if(Error==ERR_FILE_NOTTXT) Text="The file must be opened as a text";
   if(Error==ERR_FILE_NOTTXTORCSV) Text="The file must be opened as a text or CSV";
   if(Error==ERR_FILE_NOTCSV) Text="The file must be opened as CSV";
   if(Error==ERR_FILE_READERROR) Text="File reading error";
   if(Error==ERR_FILE_BINSTRINGSIZE) Text="String size must be specified, because the file is opened as binary";
   if(Error==ERR_INCOMPATIBLE_FILE) Text="A text file must be for string arrays, for other arrays - binary";
   if(Error==ERR_FILE_IS_DIRECTORY) Text="This is not a file, this is a directory";
   if(Error==ERR_FILE_NOT_EXIST) Text="File does not exist";
   if(Error==ERR_FILE_CANNOT_REWRITE) Text="File can not be rewritten";
   if(Error==ERR_WRONG_DIRECTORYNAME) Text="Wrong directory name";
   if(Error==ERR_DIRECTORY_NOT_EXIST) Text="Directory does not exist";
   if(Error==ERR_FILE_ISNOT_DIRECTORY) Text="This is a file, not a directory";
   if(Error==ERR_CANNOT_DELETE_DIRECTORY) Text="The directory cannot be removed";
   if(Error==ERR_CANNOT_CLEAN_DIRECTORY) Text="Failed to clear the directory (probably one or more files are blocked and removal operation failed)";
   if(Error==ERR_FILE_WRITEERROR) Text="Failed to write a resource to a file";
   if(Error==ERR_FILE_ENDOFFILE) Text="Unable to read the next piece of data from a CSV file (FileReadString, FileReadNumber, FileReadDatetime, FileReadBool), since the end of file is reached";
   if(Error==ERR_NO_STRING_DATE) Text="No date in the string";
   if(Error==ERR_WRONG_STRING_DATE) Text="Wrong date in the string";
   if(Error==ERR_WRONG_STRING_TIME) Text="Wrong time in the string";
   if(Error==ERR_STRING_TIME_ERROR) Text="Error converting string to date";
   if(Error==ERR_STRING_OUT_OF_MEMORY) Text="Not enough memory for the string";
   if(Error==ERR_STRING_SMALL_LEN) Text="The string length is less than expected";
   if(Error==ERR_STRING_TOO_BIGNUMBER) Text="Too large number, more than ULONG_MAX";
   if(Error==ERR_WRONG_FORMATSTRING) Text="Invalid format string";
   if(Error==ERR_TOO_MANY_FORMATTERS) Text="Amount of format specifiers more than the parameters";
   if(Error==ERR_TOO_MANY_PARAMETERS) Text="Amount of parameters more than the format specifiers";
   if(Error==ERR_WRONG_STRING_PARAMETER) Text="Damaged parameter of string type";
   if(Error==ERR_STRINGPOS_OUTOFRANGE) Text="Position outside the string";
   if(Error==ERR_STRING_ZEROADDED) Text="0 added to the string end, a useless operation";
   if(Error==ERR_STRING_UNKNOWNTYPE) Text="Unknown data type when converting to a string";
   if(Error==ERR_WRONG_STRING_OBJECT) Text="Damaged string object";
   if(Error==ERR_INCOMPATIBLE_ARRAYS) Text="Copying incompatible arrays. String array can be copied only to a string array, and a numeric array - in numeric array only";
   if(Error==ERR_SMALL_ASSERIES_ARRAY) Text="The receiving array is declared as AS_SERIES, and it is of insufficient size";
   if(Error==ERR_SMALL_ARRAY) Text="Too small array, the starting position is outside the array";
   if(Error==ERR_ZEROSIZE_ARRAY) Text="An array of zero length";
   if(Error==ERR_NUMBER_ARRAYS_ONLY) Text="Must be a numeric array";
   if(Error==ERR_ONEDIM_ARRAYS_ONLY) Text="Must be a one-dimensional array";
   if(Error==ERR_SERIES_ARRAY) Text="Timeseries cannot be used";
   if(Error==ERR_DOUBLE_ARRAY_ONLY) Text="Must be an array of type double";
   if(Error==ERR_FLOAT_ARRAY_ONLY) Text="Must be an array of type float";
   if(Error==ERR_LONG_ARRAY_ONLY) Text="Must be an array of type long";
   if(Error==ERR_INT_ARRAY_ONLY) Text="Must be an array of type int";
   if(Error==ERR_SHORT_ARRAY_ONLY) Text="Must be an array of type short";
   if(Error==ERR_CHAR_ARRAY_ONLY) Text="Must be an array of type char";
   if(Error==ERR_STRING_ARRAY_ONLY) Text="String array only";
   if(Error==ERR_OPENCL_NOT_SUPPORTED) Text="OpenCL functions are not supported on this computer";
   if(Error==ERR_OPENCL_INTERNAL) Text="Internal error occurred when running OpenCL";
   if(Error==ERR_OPENCL_INVALID_HANDLE) Text="Invalid OpenCL handle";
   if(Error==ERR_OPENCL_CONTEXT_CREATE) Text="Error creating the OpenCL context";
   if(Error==ERR_OPENCL_QUEUE_CREATE) Text="Failed to create a run queue in OpenCL";
   if(Error==ERR_OPENCL_PROGRAM_CREATE) Text="Error occurred when compiling an OpenCL program";
   if(Error==ERR_OPENCL_TOO_LONG_KERNEL_NAME) Text="Too long kernel name (OpenCL kernel)";
   if(Error==ERR_OPENCL_KERNEL_CREATE) Text="Error creating an OpenCL kernel";
   if(Error==ERR_OPENCL_SET_KERNEL_PARAMETER) Text="Error occurred when setting parameters for the OpenCL kernel";
   if(Error==ERR_OPENCL_EXECUTE) Text="OpenCL program runtime error";
   if(Error==ERR_OPENCL_WRONG_BUFFER_SIZE) Text="Invalid size of the OpenCL buffer";
   if(Error==ERR_OPENCL_WRONG_BUFFER_OFFSET) Text="Invalid offset in the OpenCL buffer";
   if(Error==ERR_OPENCL_BUFFER_CREATE) Text="Failed to create an OpenCL buffer";
   if(Error==ERR_OPENCL_TOO_MANY_OBJECTS) Text="Too many OpenCL objects";
   if(Error==ERR_OPENCL_SELECTDEVICE) Text="OpenCL device selection error";
   if(Error==ERR_WEBREQUEST_INVALID_ADDRESS) Text="Invalid URL";
   if(Error==ERR_WEBREQUEST_CONNECT_FAILED) Text="Failed to connect to specified URL";
   if(Error==ERR_WEBREQUEST_TIMEOUT) Text="Timeout exceeded";
   if(Error==ERR_WEBREQUEST_REQUEST_FAILED) Text="HTTP request failed";
   if(Error==ERR_NOT_CUSTOM_SYMBOL) Text="A custom symbol must be specified";
   if(Error==ERR_CUSTOM_SYMBOL_WRONG_NAME) Text="The name of the custom symbol is invalid. The symbol name can only contain Latin letters without punctuation, spaces or special characters (may only contain '.', '_', '&' and '#'). It is not recommended to use characters <, >, :, ', /,\\, |, ?, *.";
   if(Error==ERR_CUSTOM_SYMBOL_NAME_LONG) Text="The name of the custom symbol is too long. The length of the symbol name must not exceed 32 characters including the ending 0 character";
   if(Error==ERR_CUSTOM_SYMBOL_PATH_LONG) Text="The path of the custom symbol is too long. The path length should not exceed 128 characters including 'Custom', the symbol name, group separators and the ending 0";
   if(Error==ERR_CUSTOM_SYMBOL_EXIST) Text="A custom symbol with the same name already exists";
   if(Error==ERR_CUSTOM_SYMBOL_ERROR) Text="Error occurred while creating, deleting or changing the custom symbol";
   if(Error==ERR_CUSTOM_SYMBOL_SELECTED) Text="You are trying to delete a custom symbol selected in Market Watch";
   if(Error==ERR_CUSTOM_SYMBOL_PROPERTY_WRONG) Text="An invalid custom symbol property";
   if(Error==ERR_CUSTOM_SYMBOL_PARAMETER_ERROR) Text="A wrong parameter while setting the property of a custom symbol";
   if(Error==ERR_CUSTOM_SYMBOL_PARAMETER_LONG) Text="A too long string parameter while setting the property of a custom symbol";
   if(Error==ERR_CUSTOM_TICKS_WRONG_ORDER) Text="Ticks in the array are not arranged in the order of time";
   
   return Text;
}