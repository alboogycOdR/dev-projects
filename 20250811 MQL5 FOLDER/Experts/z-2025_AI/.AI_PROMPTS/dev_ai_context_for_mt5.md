# MQL5 Language Core Concepts and Syntax Summary

This document summarizes the fundamental rules, syntax, and concepts of the MetaQuotes Language 5 (MQL5) based on the book "Expert Advisor Programming for MetaTrader 5".

## 1. MQL5 Program Types and Structure

*   **Program Types:**
    *   `Expert Advisor (.mq5/.ex5)`: Automated trading systems attached to a chart (one per chart). Executes primarily within `OnTick()`, `OnInit()`, `OnDeinit()`, `OnTimer()`, `OnTrade()`.
    *   `Indicator (.mq5/.ex5)`: Displays technical analysis data on a chart (multiple allowed). Executes primarily within `OnCalculate()`, `OnInit()`, `OnDeinit()`.
    *   `Script (.mq5/.ex5)`: Performs a one-time task when attached to a chart (one per chart). Executes once within `OnStart()`.
*   **File Extensions:**
    *   `.mq5`: Source code file.
    *   `.ex5`: Compiled executable file.
    *   `.mqh`: Include file (source code for reuse).
*   **Program Structure Order:**
    1.  Preprocessor Directives (`#property`, `#define`, `#include`, `#import`)
    2.  Input and Global Variables (`input`, `sinput`, global scope variables)
    3.  Class and Function Definitions
    4.  Event Handlers (`OnInit`, `OnTick`, `OnCalculate`, etc.)
*   **File Locations:** MQL5 files reside within the MetaTrader 5 Data Folder, typically under the `MQL5` subdirectory (e.g., `MQL5\Experts`, `MQL5\Indicators`, `MQL5\Include`, `MQL5\Libraries`, `MQL5\Files`).

## 2. Basic Syntax

*   **Statements:** Terminated with a semicolon (`;`).
    *   `int x = 5;`
*   **Blocks:** Code enclosed in curly braces `{}`. Used for functions, control structures (if, for, while), classes, etc. A closing brace `}` does not require a semicolon after it.
*   **Case Sensitivity:** MQL5 is case-sensitive (`myVariable` is different from `MyVariable`).
*   **Comments:**
    *   Single-line: `// comment text`
    *   Multi-line: `/* comment text */`
*   **Identifiers (Variable/Function/Class Names):**
    *   Can contain letters, numbers, and underscores (`_`).
    *   Must start with a letter or underscore.
    *   Maximum length: 64 characters.
    *   Cannot be an MQL5 reserved keyword.
*   **Naming Conventions (from book):**
    *   Global variables, objects, classes, function names: Capitalize first letter of each word (e.g., `MyFunction`, `CTrade`).
    *   Local variables/objects (inside functions): Camel case (e.g., `myVariable`, `requestObject`).
    *   Constants: All uppercase with underscores (e.g., `MAX_ORDERS`, `MY_CONSTANT`).
    *   Function parameters: Prefixed with 'p' (e.g., `pSymbol`, `pVolume`).

## 3. Data Types

*   **Integer Types (Whole Numbers):**
    *   Signed: `char` (1 byte), `short` (2 bytes), `int` (4 bytes), `long` (8 bytes - common for IDs, times).
    *   Unsigned: `uchar`, `ushort`, `uint`, `ulong`.
*   **Real Types (Floating-Point Numbers):**
    *   `float` (4 bytes, ~7 significant digits).
    *   `double` (8 bytes, ~15 significant digits - **preferred type for prices, calculations**).
*   **Boolean Type:**
    *   `bool`: Represents `true` or `false`. Can be assigned 0 (false) or non-zero (true).
*   **String Type:**
    *   `string`: Sequence of characters enclosed in double quotes (`"`).
    *   Escaping: Use backslash (`\`) to escape special characters (e.g., `\"`, `\\`, `\n`).
    *   Concatenation: Use the `+` operator or `StringConcatenate()`.
*   **Color Type:**
    *   `color`: Represents color values.
    *   Constants: `clrRed`, `clrBlue`, etc.
    *   RGB Literal: `C'R,G,B'` (e.g., `C'255,0,0'`).
    *   Hex Literal: `0xRRGGBB` (e.g., `0xFF0000`).
*   **Datetime Type:**
    *   `datetime`: Stores date and time as seconds since 1970-01-01 00:00:00 (Unix time).
    *   Constants: `D'YYYY.MM.DD HH:MM:SS'` (parts can be omitted).
    *   Built-in Constants: `__DATETIME__`, `__DATE__` (compilation time/date).
    *   Functions: `TimeCurrent()` (server time), `TimeLocal()` (local PC time), `StringToTime()`, `TimeToString()`.
*   **Enumerations (`enum`):**
    *   User-defined integer types with named constants.
    *   `enum EnumName { CONST1, CONST2=5, CONST3 };`
    *   Creates a new data type `EnumName`.
    *   Standard MQL5 enums often start with `ENUM_`.
*   **Structures (`struct`):**
    *   Collections of variables (members) of potentially different types.
    *   `struct StructName { type member1; type member2; };`
    *   Access members using the dot operator (`.`) on an object of the struct type.
    *   Predefined MQL5 structures: `MqlDateTime`, `MqlRates`, `MqlTick`, `MqlTradeRequest`, `MqlTradeResult`.

## 4. Variables

*   **Declaration:** `type identifier [= initial_value];`
    *   Must be declared before use.
*   **Initialization:** Optional. If not initialized, defaults to 0, 0.0, false, `""` or `NULL` depending on type.
*   **Variable Scopes:**
    *   **Local:** Declared inside a function or block (`{}`). Exists only within that scope. Block scope applies (inner declaration hides outer).
    *   **Global:** Declared outside any function. Accessible throughout the program file.
    *   **Static Local:** Declared inside a function with `static`. Retains its value between function calls. Initialized only once. `static int counter = 0;`
    *   **Input:** Declared globally with `input`. User-configurable parameters visible in EA/Indicator properties. `input int MAPeriod = 14;`
    *   **Static Input:** Declared globally with `sinput`. User-configurable but *not* optimizable in Strategy Tester. Often used for grouping labels `sinput string GroupLabel = "--- Settings ---";`.
*   **Constants:** Values that cannot be changed after definition.
    *   Preprocessor: `#define NAME value`
    *   Variable: `const type NAME = value;`

## 5. Operators

*   **Arithmetic:** `+`, `-`, `*`, `/`, `%` (modulus).
*   **Assignment:** `=`, `+=`, `-=`, `*=`, `/=`, `%=`.
*   **Relational (Comparison):** `>`, `<`, `>=`, `<=`, `==` (equality), `!=` (inequality). Return `bool`.
*   **Logical:** `&&` (AND), `||` (OR), `!` (NOT). Return `bool`.
*   **Increment/Decrement:** `++`, `--` (prefix or postfix).
*   **Scope Resolution:** `::` (Used for accessing members of classes/namespaces).
*   **Ternary:** `condition ? value_if_true : value_if_false`.

## 6. Control Flow

*   **Conditional Statements:**
    *   `if (condition) { statements; }`
    *   `if (condition) { statements; } else { statements; }`
    *   `if (condition1) { statements; } else if (condition2) { statements; } else { statements; }`
    *   `switch (expression) { case constant1: statements; break; case constant2: statements; break; default: statements; break; }` (`break` is crucial to prevent fall-through).
*   **Loop Statements:**
    *   `for (initialization; condition; increment) { statements; }`
    *   `while (condition) { statements; }`
    *   `do { statements; } while (condition);` (Always executes at least once).
*   **Loop Control:**
    *   `break;`: Exits the innermost loop or switch statement immediately.
    *   `continue;`: Skips the rest of the current loop iteration and proceeds to the next iteration.

## 7. Functions

*   **Declaration:** `return_type FunctionName(parameter_list) { // function body return value; }`
*   **Return Type:** Specifies the data type of the value returned by the function. `void` means no value is returned.
*   **Parameters:** Variables passed into the function. Can have default values (`type name = default_value`). Default parameters must be last in the list.
*   **Passing Parameters:**
    *   **By Value (Default):** A copy of the argument is passed. Changes inside the function do not affect the original variable.
    *   **By Reference:** Use the ampersand (`&`) after the type in the parameter list (`type& name`). The function operates directly on the original variable. Required for modifying complex types like arrays or structures passed into functions. `OrderSend()` uses reference parameters.
*   **Function Overloading:** Defining multiple functions with the same name but different parameter lists (either number or types of parameters).

## 8. Object-Oriented Programming (OOP)

*   **Classes (`class`):** Blueprints for creating objects. Combine data (member variables) and functions (member methods) that operate on that data.
    *   Declaration: `class ClassName { access_modifier: members; ... };` (ends with semicolon).
*   **Objects:** Instances of a class. Created like variables: `ClassName myObject;`.
*   **Access Modifiers:** Control visibility of class members.
    *   `public:`: Accessible from anywhere.
    *   `protected:`: Accessible within the class and derived classes.
    *   `private:` (default if none specified): Accessible only within the class itself.
*   **Member Access:** Use the dot operator (`.`) to access public members of an object: `myObject.publicMember`.
*   **Scope Resolution Operator (`::`):** Used to define member functions outside the class declaration: `return_type ClassName::FunctionName(params) { ... }`.
*   **Constructors:** Special member function with the same name as the class, no return type. Called automatically when an object is created. Used for initialization.
*   **Inheritance:** Creating a new class (derived class) from an existing class (base class). `class DerivedClass : public BaseClass { ... };`. The derived class inherits public and protected members.
*   **Virtual Functions (`virtual`):** Member functions declared with `virtual` in the base class. Allows derived classes to provide their own specific implementation (override) the function. Enables polymorphism. The `Init()` function in the book's `CIndicator` is an example.

## 9. MQL5 Program Execution & Event Handlers

*   MQL5 programs are event-driven. Execution starts and continues based on specific events.
*   **Common Event Handlers:**
    *   `OnInit()`: Called once when the program is loaded/initialized (or parameters/symbol/period change). Return `INIT_SUCCEEDED` or `INIT_FAILED`.
    *   `OnDeinit(const int reason)`: Called when the program is unloaded/deinitialized. `reason` indicates why.
    *   `OnTick()` (EAs): Called on every new incoming price tick. Main loop for many EAs.
    *   `OnTimer()` (EAs, Indis): Called when a timer set by `EventSetTimer()` elapses.
    *   `OnTrade()` (EAs): Called when a trade event occurs (order placed, modified, position change, etc.).
    *   `OnCalculate(...)` (Indicators): Called on new ticks to perform indicator calculations. Has two variants depending on required price data.
    *   `OnStart()` (Scripts): The main function for scripts, executes once.

## 10. Trading Operations (MQL5 Netting System)

*   **Netting System:** MQL5 maintains *one net position* per symbol. There are no individual buy/sell orders open simultaneously like in MQL4. Placing an opposing order reduces or reverses the net position. Hedging is not directly supported by opening opposing positions.
*   **Orders:** Requests to perform a trade operation (buy, sell, modify SL/TP, place/modify/delete pending).
*   **Deals:** The result of a successful order execution (a trade fill).
*   **Positions:** The net result of all deals for a symbol (net long, net short, or flat).
*   **Core Trading Function:**
    *   `OrderSend(MqlTradeRequest& request, MqlTradeResult& result)`: Sends trade requests. Takes request and result structures *by reference*. Returns `true` if the request was successfully *sent*, `false` otherwise.
*   **`MqlTradeRequest` Structure:** Holds all parameters for a trade request. Key fields:
    *   `action` (Type of operation: `TRADE_ACTION_DEAL` for market, `TRADE_ACTION_PENDING`, `TRADE_ACTION_SLTP`, `TRADE_ACTION_MODIFY`, `TRADE_ACTION_REMOVE`)
    *   `symbol` (e.g., `_Symbol`)
    *   `volume` (Lot size)
    *   `type` (Order type: `ORDER_TYPE_BUY`, `ORDER_TYPE_SELL`, `ORDER_TYPE_BUY_LIMIT`, etc.)
    *   `price` (Entry price for market/pending)
    *   `sl`, `tp` (Stop Loss, Take Profit prices)
    *   `magic` (Magic number for EA identification)
    *   `deviation` (Slippage tolerance for instant/request execution)
    *   `type_filling` (Fill policy: `ORDER_FILLING_FOK`, `IOC`, `RETURN`)
    *   `type_time`, `expiration` (For pending order expiry)
    *   `order` (Ticket number for modifying/deleting pending orders)
    *   `stoplimit` (Price for stop-limit orders)
*   **`MqlTradeResult` Structure:** Holds the results of a trade request returned by the server. Key fields:
    *   `retcode` (Return code indicating success/failure. E.g., `TRADE_RETCODE_DONE`, `TRADE_RETCODE_PLACED` indicate success).
    *   `deal` (Deal ticket number)
    *   `order` (Order ticket number)
    *   `price` (Execution price)
    *   `volume` (Executed volume)
*   **Position Information:**
    *   `PositionSelect(symbol)`: Selects the current position for the symbol. Returns `true` if a position exists.
    *   `PositionGetDouble(property)`: e.g., `POSITION_PRICE_OPEN`, `POSITION_SL`, `POSITION_TP`, `POSITION_VOLUME`, `POSITION_PROFIT`.
    *   `PositionGetInteger(property)`: e.g., `POSITION_TYPE` (`POSITION_TYPE_BUY`/`SELL`), `POSITION_MAGIC`, `POSITION_TICKET`.
    *   `PositionGetString(property)`: e.g., `POSITION_COMMENT`.

## 11. Indicators

*   **Built-in:** Functions like `iMA()`, `iRSI()`, `iStochastic()`, `iMACD()`, etc.
    *   Return an integer `handle` unique to that indicator instance.
    *   Take parameters specific to the indicator (period, price type, etc.).
*   **Custom:** Use `iCustom(symbol, period, indicator_name, [input parameters...])`.
    *   `indicator_name` is path relative to `MQL5\Indicators`, e.g., `"Examples\\BB"`.
    *   Requires passing all indicator input parameters in the correct order and type.
*   **Buffers:** Indicators store their calculated values in buffers (numbered starting from 0).
*   **`CopyBuffer(handle, buffer_num, start_pos, count, target_array[])`:** Copies data from an indicator buffer into a `double` array. `buffer_num` specifies which line/buffer (e.g., 0 for MA, 0/1 for Stochastics %K/%D).
*   **Indicator Handles:** Must be managed (released when no longer needed, although class destructors can handle this).

## 12. Working with Price/Time Data

*   **Predefined Variables:** `_Symbol`, `_Period`, `_Point` (value of one point), `_Digits` (digits after decimal).
*   **Current Prices:** Use `SymbolInfoDouble(_Symbol, SYMBOL_BID/SYMBOL_ASK)` or `SymbolInfoTick()` with `MqlTick` structure.
*   **Bar Data (`MqlRates` Structure):** Contains `time`, `open`, `high`, `low`, `close`, `tick_volume`, `real_volume`, `spread`.
*   **Copying Bar Data:**
    *   `CopyRates(symbol, timeframe, start_pos, count, MqlRates_array[])`: Copies OHLC, time, volume, spread.
    *   Specific price copies: `CopyOpen()`, `CopyHigh()`, `CopyLow()`, `CopyClose()`.
    *   Other copies: `CopyTime()`, `CopyTickVolume()`, `CopyRealVolume()`, `CopySpread()`.
*   **Series Arrays:** Arrays indexed chronologically backwards (index 0 is the current/most recent bar). Use `ArraySetAsSeries(array, true)` before copying price/indicator data into an array intended to be used as a time series.
*   **MQL5 Structure `MqlDateTime`:** Holds broken-down date/time components (`year`, `mon`, `day`, `hour`, `min`, `sec`, `day_of_week`, `day_of_year`).
    *   `TimeToStruct(datetime_var, MqlDateTime_struct)`: Converts `datetime` to structure.
    *   `StructToTime(MqlDateTime_struct)`: Converts structure back to `datetime`.

## 13. Other Important Functions/Concepts

*   **Normalization:** `NormalizeDouble(value, digits)`: Rounds a double to the specified number of decimal places. Crucial for prices, SL/TP levels.
*   **Error Handling:**
    *   `GetLastError()`: Returns the code of the last runtime error.
    *   `ResetLastError()`: Resets the last error code to 0.
    *   Check `retcode` from `MqlTradeResult` after `OrderSend()`.
*   **Math:** `MathAbs()`, `MathRound()`, etc.
*   **Typecasting:** Explicitly converting between data types `(type)value`. Be aware of potential data loss.
*   **User Interaction:** `Alert()`, `Print()`, `Comment()`, `MessageBox()`, `SendMail()`, `SendNotification()`, `PlaySound()`.
*   **Chart Objects:** `ObjectCreate()`, `ObjectDelete()`, `ObjectSetInteger()`, `ObjectSetDouble()`, `ObjectSetString()`, `ObjectMove()`, `ObjectsDeleteAll()`. Many `OBJ_*` types and `OBJPROP_*` properties.
*   **File I/O:** `FileOpen()`, `FileClose()`, `FileWrite()`, `FileReadString()`, `FileReadNumber()`, etc. Operations usually limited to `MQL5\Files`. Requires appropriate `FILE_*` flags. `FileSeek()` to position pointer.
*   **Global Variables (Terminal):** Persistent variables stored by MetaTrader accessible by any EA/script. `GlobalVariableSet()`, `GlobalVariableGet()`, `GlobalVariableDel()`. Distinct from program global variables.
*   **Stop Level:** Minimum distance (`SYMBOL_TRADE_STOPS_LEVEL` * `_Point`) required between current market price and SL/TP/pending order prices. Must be checked before placing/modifying orders.
*   **Libraries (.ex5):** Contain reusable functions (no global variables/classes directly accessible from outside). Functions must be declared with `export`. Imported using `#import`.
*   **Debugging:** Breakpoints (F9), Step Into/Over/Out, Watch window (Shift+F9). `DebugBreak()`.
*   **Strategy Tester:** Tool for backtesting and optimizing EAs. Modes: Every Tick, 1 minute OHLC, Open prices only. Optimization algorithms. Forward testing.
*   **WebRequest:** Sends HTTP/HTTPS requests to external web servers.
    *   **Purpose:** Interact with web APIs, fetch external data (news, signals), send notifications to external systems.
    *   **Syntax:**
        ```mql5
        int WebRequest(
           const string method,        // HTTP method ("GET", "POST")
           const string url,           // URL to request
           const string cookie,        // Cookie value (usually NULL)
           const string referer,       // Referer header (usually NULL)
           int          timeout,       // Timeout in milliseconds
           const char&  data[],        // Array with POST data body
           int          data_size,     // Size of data array (0 for GET)
           char&        result[],      // Array to receive response body (by reference)
           string&      result_headers // String to receive response headers (by reference)
        );
        ```
    *   **Security:** The target `url` **must** be added to the allowed list in `Tools -> Options -> Expert Advisors`.
    *   **Return Value:** Returns the HTTP status code (e.g., `200` for OK) or a negative value for internal MQL5 errors. Check `GetLastError()` for MQL5 specific errors if return is negative.
    *   **Synchronous:** Blocks execution until the request completes or times out. Use with caution.
    *   **Data:** Use `StringToCharArray()` / `CharArrayToString()` for text data handling.
*   **Socket Functions (TCP):** Allows establishing direct TCP connections for lower-level network communication.
    *   **Purpose:** Communicate with custom servers/protocols, real-time data streams where HTTP is not suitable.
    *   **Core Function:** `SocketCreate()`
        *   **Syntax:** `int SocketCreate(uint flags);`
        *   **Parameters:** `flags` (currently only `SOCKET_DEFAULT`).
        *   **Return Value:** Returns an integer socket `handle` if successful, otherwise `INVALID_HANDLE`. Check `GetLastError()` on failure.
    *   **Workflow:**
        1.  `SocketCreate()`: Get a socket handle.
        2.  `SocketConnect(handle, server, port, timeout)`: Connect to a remote server.
        3.  `SocketSend(handle, data[], data_size)` / `SocketTlsSend()`: Send data. (Requires `StringToCharArray()` for string data).
        4.  `SocketIsReadable(handle)`: Check if data is available to read.
        5.  `SocketRead(handle, result[], maxlen, timeout)` / `SocketTlsRead()`: Read incoming data into a `char` array. (Use `CharArrayToString()` to convert back).
        6.  `SocketClose(handle)`: **Crucial** - Close the socket and release resources when done.
    *   **Restrictions:**
        *   Can only be used in Expert Advisors and Scripts (not Indicators - Error `4014`).
        *   Maximum of 128 sockets per MQL5 program (`ERR_NETSOCKET_TOO_MANY_OPENED`).
    *   **Security/TLS:** `SocketTls*` functions exist for creating secure TLS/SSL connections. `SocketTlsCertificate()` can check server certificate details.