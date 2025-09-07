
#include  <Ossi\LongTails\Utils.mqh>

//+------------------------------------------------------------------+
//| Global Variables for Testing                                     |
//+------------------------------------------------------------------+
CTrade trade;
int tests_passed = 0;
int tests_failed = 0;
string current_test_suite = ""; // To group assertion messages

//+------------------------------------------------------------------+
//| Assertion Helper                                                 |
//+------------------------------------------------------------------+
void Assert(bool condition, string test_name, string message = "")
{
    if (condition)
    {
        PrintFormat("%s - %s: PASSED", current_test_suite, test_name);
        tests_passed++;
    }
    else
    {
        string fail_msg = StringFormat("%s - %s: FAILED", current_test_suite, test_name);
        if (message != "")
            fail_msg += " (" + message + ")";
        Print(fail_msg);
        tests_failed++;
    }
}

//+------------------------------------------------------------------+
//| Test Suite Functions                                             |
//+------------------------------------------------------------------+

void Test_StructureInitialization() //CLEAN
{
    current_test_suite = "Struct Init";
    // --- Test Grid::Init ---
    GridInfo test_grid;
    double unit = 2.0, spread = 0.4, multiplier = 1.5;
    test_grid.Init(unit, spread, multiplier);

    Assert(test_grid.unit == unit, "Grid::Init Unit");
    Assert(test_grid.spread == spread, "Grid::Init Spread");
    Assert(test_grid.multiplier == multiplier, "Grid::Init Multiplier");
    Assert(test_grid.target == unit * multiplier, "Grid::Init Target");
    // Note: progression_sequence, session_status, session_time_* are initialized to default

    // --- Test GridBase::UpdateGridBase ---
    GridBase test_base;
    ulong test_pos_ticket = 0;
    string symbol = _Symbol;
    double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

    // Close any existing position first for a clean slate
    if(PositionSelect(symbol))
       trade.PositionClose(symbol);
    Sleep(500); // Allow time for close

    if(trade.Buy(volume, symbol, 0, 0, 0, "TestBasePos"))
    {
       Sleep(500); // Allow time for position to open and be selectable
       if(PositionSelect(symbol))
       {
          test_pos_ticket = PositionGetInteger(POSITION_TICKET);
          test_base.UpdateGridBase(test_pos_ticket);

          Assert(test_base.ticket == test_pos_ticket, "GridBase::UpdateGridBase Ticket");
          Assert(test_base.name == "TestBasePos", "GridBase::UpdateGridBase Name (Comment)");
          Assert(test_base.type == POSITION_TYPE_BUY, "GridBase::UpdateGridBase Type");
          Assert(test_base.volume == volume, "GridBase::UpdateGridBase Volume");
          Assert(test_base.open_price == PositionGetDouble(POSITION_PRICE_OPEN), "GridBase::UpdateGridBase Open Price");

          // Cleanup: Close the test position
          trade.PositionClose(symbol);
          Sleep(500);
       }
       else
       {
           Print("Test_StructureInitialization - GridBase::UpdateGridBase: SKIPPED (Could not select test position after opening)");
           tests_failed++; // handle as skipped
           // Attempt cleanup just in case
           if(PositionSelect(symbol)) trade.PositionClose(symbol);
       }
    }
    else
    {
        Print("Test_StructureInitialization - GridBase::UpdateGridBase: SKIPPED (Failed to open test position. Error: ", GetLastError(), ")");
        tests_failed++; // handle as skipped
    }
}

void Test_ArrayAndValueFunctions()  //CLEAN
{
    current_test_suite = "Array/Value Utils";
    // --- Test GetValueIndex ---
    double arr[] = {1.1, 2.2, 3.3, 4.4, 5.5};
    double empty_arr[];
    Assert(GetValueIndex(3.3, arr) == 2, "GetValueIndex Found");
    Assert(GetValueIndex(1.1, arr) == 0, "GetValueIndex First");
    Assert(GetValueIndex(5.5, arr) == 4, "GetValueIndex Last");
    Assert(GetValueIndex(9.9, arr) == -1, "GetValueIndex Not Found");
    Assert(GetValueIndex(1.1, empty_arr) == -1, "GetValueIndex Empty Array");

    // --- Test ArraySum ---
    double arr1[] = {1.0, 2.5, 3.0};
    double arr2[] = {-1.0, -2.0, 5.0};
    double arr3[] = {10.0};
    Assert(MathAbs(ArraySum(arr1) - 6.5) < 0.00001, "ArraySum Positive");
    Assert(MathAbs(ArraySum(arr2) - 2.0) < 0.00001, "ArraySum Mixed");
    Assert(MathAbs(ArraySum(arr3) - 10.0) < 0.00001, "ArraySum Single");
    Assert(MathAbs(ArraySum(empty_arr) - 0.0) < 0.00001, "ArraySum Empty Array");
}

void Test_TimeFunctions()  //CLEAN
{
    current_test_suite = "Time Utils";
    // --- Test IsWithinTradingTime ---
    // Uses TimeCurrent(), so results depend on when the script is run or tester time
    datetime now = TimeCurrent();
    datetime start = now - 3600; // 1 hour ago
    datetime end = now + 3600;   // 1 hour from now
    datetime future_start = now + 1800; // 30 mins from now
    datetime future_end = now + 5400;   // 1.5 hours from now
    datetime past_start = now - 7200; // 2 hours ago
    datetime past_end = now - 3600;   // 1 hour ago

    Assert(IsWithinTradingTime(start, end) == true, "IsWithinTradingTime Inside");
    Assert(IsWithinTradingTime(future_start, future_end) == false, "IsWithinTradingTime Future");
    Assert(IsWithinTradingTime(past_start, past_end) == false, "IsWithinTradingTime Past");
    Assert(IsWithinTradingTime(end, start) == true, "IsWithinTradingTime Swapped Times");
}


void Test_OrderRelatedFunctions() //CLEAN
{
    current_test_suite = "Order Utils";
    string symbol = _Symbol;
    double price_step = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) * 300; // Place orders away from market
    if(price_step == 0) price_step = _Point * 300; // Fallback if tick size is zero
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double price1 = ask + price_step;
    double price2 = ask + price_step * 2;
    double price3 = bid - price_step; // For sell limit/stop
    ulong ticket1 = 0, ticket2 = 0, ticket3 = 0;

    // --- Cleanup before tests ---
    DeleteAllPending(trade, symbol); // Use the function itself for cleanup!
    Sleep(500);

    // --- Test NodeExistsAtPrice ---
    Assert(NodeExistsAtPrice(price1) == 0, "NodeExistsAtPrice Not Found Initially");
    if(trade.BuyStop(0.01, price1, symbol, 0, 0, ORDER_TIME_GTC, 0, "TestNode1"))
    {
    //Print("xxxxxxxxxx000000000000000xxxxxxxxxxxx");
        ticket1 = trade.ResultOrder();
        Sleep(500); // Allow order processing
        ulong found_ticket = NodeExistsAtPrice(price1);
        Assert(found_ticket == ticket1, "NodeExistsAtPrice Found", "Expected " + (string)ticket1 + ", Got " + (string)found_ticket);
        Assert(NodeExistsAtPrice(price2) == 0, "NodeExistsAtPrice Not Found Different Price");
    } else {
        Print("Test_OrderRelatedFunctions - NodeExistsAtPrice: SKIPPED (Failed to place test order 1. Error: ", GetLastError(), ")");
        tests_failed++;
    }

    // --- Test SymbolOrdersTotal ---
    Assert(SymbolOrdersTotal() == (ticket1 != 0 ? 1 : 0), "SymbolOrdersTotal One Order");
    if(trade.BuyStop(0.01, price2, symbol, 0, 0, ORDER_TIME_GTC, 0, "TestNode2"))
    {
        ticket2 = trade.ResultOrder();
        Sleep(500);
        Assert(SymbolOrdersTotal() == (ticket1 != 0 ? 1 : 0) + (ticket2 != 0 ? 1 : 0), "SymbolOrdersTotal Two Orders");
    } else {
         Print("Test_OrderRelatedFunctions - SymbolOrdersTotal: SKIPPED (Failed to place test order 2. Error: ", GetLastError(), ")");
         tests_failed++;
    }
    // Test with an order for another symbol (if possible)
    string other_symbol = "";
    for(int i=0; i < SymbolsTotal(false); i++) {
       string s = SymbolName(i, false);
       if (s != symbol && SymbolInfoInteger(s, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED) {
          other_symbol = s; break;
       }
    }
    ulong other_ticket = 0;
    if(other_symbol != "") {
        double other_ask = SymbolInfoDouble(other_symbol, SYMBOL_ASK);
        double other_point = SymbolInfoDouble(other_symbol, SYMBOL_POINT);
        if(other_ask > 0 && other_point > 0) {
             if(trade.BuyStop(0.01, other_ask + 300 * other_point, other_symbol, 0, 0, ORDER_TIME_GTC, 0, "TestOtherSymbol")) {
                 other_ticket = trade.ResultOrder();
                 Sleep(500);
                 int expected_count = (ticket1 != 0 ? 1 : 0) + (ticket2 != 0 ? 1 : 0);
                 Assert(SymbolOrdersTotal() == expected_count, "SymbolOrdersTotal Ignores Other Symbol");
                 trade.OrderDelete(other_ticket); // Clean up other symbol order
                 Sleep(500);
             }
        }
    }


    // --- Test DeleteAllPending ---
    // We have ticket1 and ticket2 pending (if placed successfully)
    DeleteAllPending(trade, symbol);
    Sleep(500);
    Assert(SymbolOrdersTotal() == 0, "DeleteAllPending Cleared Orders");
    // Reset tickets as they are now invalid
    ticket1 = 0;
    ticket2 = 0;

    // --- Test ClearContinuationNodes ---
    ulong t_cont1=0, t_cont2=0, t_rec=0;
    if(trade.BuyStop(0.01, price1, symbol, 0, 0, ORDER_TIME_GTC, 0, "Some Node")) t_cont1 = trade.ResultOrder();
    if(trade.BuyStop(0.01, price2, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " Continuation")) t_cont2 = trade.ResultOrder();
    if(trade.SellStop(0.01, price3, symbol, 0, 0, ORDER_TIME_GTC, 0, "Recovery Node Test")) t_rec = trade.ResultOrder();
    Sleep(500);

    int initial_orders = SymbolOrdersTotal(); // Should be 3 if all placed
    ClearContinuationNodes(trade);
    Sleep(500);

    bool cont1_exists = OrderSelect(t_cont1);
    bool cont2_exists = OrderSelect(t_cont2);
    bool rec_exists = OrderSelect(t_rec);

    Assert(cont1_exists == false, "ClearContinuationNodes Deletes Random Node");
    Assert(cont2_exists == false, "ClearContinuationNodes Deletes Continuation Node");
    Assert(rec_exists == true, "ClearContinuationNodes Keeps Recovery Node");
    Assert(SymbolOrdersTotal() == (rec_exists ? 1:0), "ClearContinuationNodes Final Count");

    // --- Final Cleanup ---
    DeleteAllPending(trade, symbol); // Clear any remaining orders (like the recovery node)
    Sleep(500);
}

void Test_PositionRelatedFunctions() //CLEAN
{
    current_test_suite = "Position Utils";
    string symbol = _Symbol;
    double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    ulong pos_ticket = 0;
    ulong saved_ticket = 99999; // A dummy ticket unlikely to exist

    // --- Cleanup before tests ---
    if(PositionSelect(symbol))
       trade.PositionClose(symbol);
    DeleteAllPending(trade, symbol);
    Sleep(500);

    // --- Test IsEmptyChart ---
    Assert(IsEmptyChart() == true, "IsEmptyChart Initially True");
    // Place an order
    if(trade.BuyStop(0.01, SymbolInfoDouble(symbol, SYMBOL_ASK) + _Point * 300, symbol, 0, 0, ORDER_TIME_GTC, 0, "TestEmptyOrder")) {
        ulong order_ticket = trade.ResultOrder();
        Sleep(500);
        Assert(IsEmptyChart() == false, "IsEmptyChart False with Order");
        trade.OrderDelete(order_ticket);
        Sleep(500);
        Assert(IsEmptyChart() == true, "IsEmptyChart True after Order Delete");
    } else {
        Print("Test_PositionRelatedFunctions - IsEmptyChart (Order): SKIPPED (Failed to place test order. Error: ", GetLastError(), ")");
        tests_failed++;
    }
    // Open a position
    if(trade.Buy(volume, symbol, 0, 0, 0, "TestEmptyPos")) {
        Sleep(500);
        Assert(IsEmptyChart() == false, "IsEmptyChart False with Position");
        // Leave position open for next test
    } else {
        Print("Test_PositionRelatedFunctions - IsEmptyChart (Position): SKIPPED (Failed to open test position. Error: ", GetLastError(), ")");
        tests_failed++;
    }
    // Test with an order for another symbol (if possible)
    string other_symbol = "";
    for(int i=0; i < SymbolsTotal(false); i++) {
       string s = SymbolName(i, false);
       if (s != symbol && SymbolInfoInteger(s, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED) {
          other_symbol = s; break;
       }
    }
    ulong other_ticket = 0;   
    if(other_symbol != "") {
        double other_ask = SymbolInfoDouble(other_symbol, SYMBOL_ASK);
        double other_point = SymbolInfoDouble(other_symbol, SYMBOL_POINT);
        if(other_ask > 0 && other_point > 0) {
             if(trade.BuyStop(0.01, other_ask + 300 * other_point, other_symbol, 0, 0, ORDER_TIME_GTC, 0, "TestOtherSymbol")) {
                 other_ticket = trade.ResultOrder();
                 Sleep(500);
                 Assert(IsEmptyChart() == true, "IsEmptyChart True with Other Symbol Order");
                 trade.OrderDelete(other_ticket); // Clean up other symbol order
                 Sleep(500);
             }
        }
    }
    Assert(IsEmptyChart() == false, "IsEmptyChart False with Position");
    

    // --- Test IsNewPosition ---
    // Assumes position from previous test is open
    if(PositionSelect(symbol)) {
        pos_ticket = PositionGetInteger(POSITION_TICKET);
        Assert(IsNewPosition(saved_ticket) == true, "IsNewPosition True (Different Ticket)");
        saved_ticket = pos_ticket; // Update saved ticket
        Assert(IsNewPosition(saved_ticket) == false, "IsNewPosition False (Same Ticket)");
    } else {
         Print("Test_PositionRelatedFunctions - IsNewPosition: SKIPPED (Test position not found)");
         // Don't increment fail count if IsEmptyChart failed to create the position
    }

    // --- Test OpenShort ---
    // Close existing BUY first
    if(PositionSelect(symbol)) {
       trade.PositionClose(symbol);
       Sleep(500);
    }
    ulong short_ticket = OpenShort(volume, trade);
    Assert(short_ticket != 0, "OpenShort Success", "Returned ticket: " + (string)short_ticket + ", LastError: " + (string)GetLastError());
    Sleep(500);
    if(short_ticket != 0) {
        Assert(PositionSelect(symbol), "OpenShort Position Exists");
        if(PositionSelect(symbol)) {
            Assert(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL, "OpenShort Position Type is SELL");
            Assert(PositionGetString(POSITION_COMMENT) == EA_TAG + " Session Start", "OpenShort Position Comment");
        }
    } else {
         Print("Test_PositionRelatedFunctions - OpenShort: FAILED to open short position");
         // Already counted in Assert(short_ticket != 0)
    }


    // --- Final Cleanup ---
    if(PositionSelect(symbol))
       trade.PositionClose(symbol);
    Sleep(500);
}


//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("--- Starting Utils.mqh Tests ---");

    // --- Sanity Checks ---
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("ERROR: Automated trading is not enabled. Please enable 'Allow automated trading' in Terminal options and EA properties.");
        return;
    }
     if(AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)
     {
        Print("WARNING: Running tests on a REAL account! Ensure this is intended and the symbol/volume are safe.");
        ExpertRemove();
        return;
     }
     if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
     {
         Print("ERROR: The current symbol (", _Symbol, ") is not tradable. Please attach the script to a tradable symbol chart.");
         return;
     }

    // --- Initialize CTrade ---
    // trade.SetExpertMagicNumber(EA_MAGIC);
    trade.SetTypeFillingBySymbol(_Symbol); // Crucial for execution
    trade.SetDeviationInPoints(10); // Allow some slippage for market orders in tests

    // --- Run Test Suites ---
    Test_StructureInitialization();
    Test_ArrayAndValueFunctions();
    Test_TimeFunctions();
    Test_OrderRelatedFunctions();
    Test_PositionRelatedFunctions();

    // --- Test Summary ---
    Print("--- Utils.mqh Test Summary ---");
    PrintFormat("Total Tests: %d", tests_passed + tests_failed);
    PrintFormat("Tests Passed: %d", tests_passed);
    PrintFormat("Tests Failed: %d", tests_failed);
    Print("--- Testing Finished ---\n");

    // Clean up chart after tests
    // ObjectsDeleteAll(0);
    // ChartRedraw();
}
//+------------------------------------------------------------------+
