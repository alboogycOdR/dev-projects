
#include <Ossi\LongTails\Utils.mqh>      
#include  <Ossi\LongTails\ExitManager.mqh>

//+------------------------------------------------------------------+
//| Global Variables for Testing                                     |
//+------------------------------------------------------------------+
CTrade trade;
GridInfo Grid;
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
//| Test Suite for ExitManager::SetExits                             |
//+------------------------------------------------------------------+
void Test_SetExits_Functionality()
{
    current_test_suite = "ExitManager::SetExits";
    string symbol = _Symbol;
    double volume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if (volume == 0) volume = 0.01; // Fallback for symbols reporting 0 min_vol (e.g., some indices)

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double stop_size_pips = 200; // A reasonable stop size in pips (e.g. 200 points for 5-digit broker)
    double stop_size_price = stop_size_pips * point;
    int target_multiplier = 2;
    ulong test_ticket = 0;
    Grid.Init(stop_size_price, target_multiplier);

    CleanupCurrentSymbol(trade); // Initial cleanup

    // --- Test Case 1: Valid BUY position ---
    Print("--- Test Case 1: Valid BUY position ---");
    if (trade.Buy(volume, symbol, 0, 0, 0, EA_TAG + " TestBuySetExits"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            test_ticket = PositionGetInteger(POSITION_TICKET);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            SetExits(trade, test_ticket, Grid);
            Sleep(500); 

            if (PositionSelectByTicket(test_ticket))
            {
                double expected_sl = NormalizeDouble(open_price - stop_size_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                double expected_tp = NormalizeDouble(open_price + stop_size_price * target_multiplier, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                double actual_sl = PositionGetDouble(POSITION_SL);
                double actual_tp = PositionGetDouble(POSITION_TP);

                Assert(MathAbs(actual_sl - expected_sl) < point, "BUY SL Set Correctly", "Expected: " + DoubleToString(expected_sl,8) + " Got: " + DoubleToString(actual_sl,8));
                Assert(MathAbs(actual_tp - expected_tp) < point, "BUY TP Set Correctly", "Expected: " + DoubleToString(expected_tp,8) + " Got: " + DoubleToString(actual_tp,8));
            }
            else { Print("Test_SetExits_Functionality - Valid BUY: FAILED (Position disappeared after SetExits call)"); tests_failed++; }
        }
        else { Print("Test_SetExits_Functionality - Valid BUY: SKIPPED (Could not select test position. Error: ", GetLastError(), ")"); tests_failed++; }
        CleanupCurrentSymbol(trade);
    }
    else { Print("Test_SetExits_Functionality - Valid BUY: SKIPPED (Failed to open test BUY position. Error: ", GetLastError(), ")"); tests_failed++; }

    // --- Test Case 2: Valid SELL position ---
    Print("--- Test Case 2: Valid SELL position ---");
    if (trade.Sell(volume, symbol, 0, 0, 0, EA_TAG + " TestSellSetExits"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            test_ticket = PositionGetInteger(POSITION_TICKET);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            SetExits(trade, test_ticket, Grid);
            Sleep(500);

            if (PositionSelectByTicket(test_ticket))
            {
                double expected_sl = NormalizeDouble(open_price + stop_size_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                double expected_tp = NormalizeDouble(open_price - stop_size_price * target_multiplier, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                double actual_sl = PositionGetDouble(POSITION_SL);
                double actual_tp = PositionGetDouble(POSITION_TP);

                Assert(MathAbs(actual_sl - expected_sl) < point, "SELL SL Set Correctly", "Expected: " + DoubleToString(expected_sl,8) + " Got: " + DoubleToString(actual_sl,8));
                Assert(MathAbs(actual_tp - expected_tp) < point, "SELL TP Set Correctly", "Expected: " + DoubleToString(expected_tp,8) + " Got: " + DoubleToString(actual_tp,8));
            }
            else { Print("Test_SetExits_Functionality - Valid SELL: FAILED (Position disappeared after SetExits call)"); tests_failed++; }
        }
        else { Print("Test_SetExits_Functionality - Valid SELL: SKIPPED (Could not select test position. Error: ", GetLastError(), ")"); tests_failed++; }
        CleanupCurrentSymbol(trade);
    }
    else { Print("Test_SetExits_Functionality - Valid SELL: SKIPPED (Failed to open test SELL position. Error: ", GetLastError(), ")"); tests_failed++; }

    // --- Test Case 3: Invalid ticket (position does not exist) ---
    Print("--- Test Case 3: Invalid ticket ---");
    CleanupCurrentSymbol(trade);
    ulong non_existent_ticket = 9999999;
    SetExits(trade, non_existent_ticket, Grid);
    Assert(!PositionSelectByTicket(non_existent_ticket), "Invalid Ticket: No position selected/modified for non-existent ticket");
    // Expect log message: "TP/SL can only be placed on open positions. Invalid ticket: ..."

    // --- Test Case 4: Position not placed by EA (different comment) ---
    Print("--- Test Case 4: Position not by EA ---");
    CleanupCurrentSymbol(trade);
    if (trade.Buy(volume, symbol, 0, 0, 0, "MANUAL_TRADE_COMMENT"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            test_ticket = PositionGetInteger(POSITION_TICKET);
            SetExits(trade, test_ticket, Grid);
            Sleep(500);

            if (PositionSelectByTicket(test_ticket))
            {
                Assert(PositionGetDouble(POSITION_SL) == 0.0, "Not EA Position: SL not set");
                Assert(PositionGetDouble(POSITION_TP) == 0.0, "Not EA Position: TP not set");
            }
            else { Print("Test_SetExits_Functionality - Not EA Position: FAILED (Position disappeared)"); tests_failed++; }
        }
        else { Print("Test_SetExits_Functionality - Not EA Position: SKIPPED (Could not select test position. Error: ", GetLastError(), ")"); tests_failed++; }
        CleanupCurrentSymbol(trade);
    }
    else { Print("Test_SetExits_Functionality - Not EA Position: SKIPPED (Failed to open test position. Error: ", GetLastError(), ")"); tests_failed++; }

    // --- Test Case 5: Position on a different symbol ---
    Print("--- Test Case 5: Position on different symbol ---");
    CleanupCurrentSymbol(trade); // Clean current symbol first
    
    string other_symbol = GetRandomSymbol(symbol);
    if(other_symbol != "")
    {
        Print("Testing with other symbol: ", other_symbol);
        CleanupCurrentSymbol(trade, other_symbol); // Clean other symbol

        CTrade other_symbol_trade;
        other_symbol_trade.SetTypeFillingBySymbol(other_symbol);
        other_symbol_trade.SetExpertMagicNumber(12346); 
        other_symbol_trade.SetAsyncMode(false);
        other_symbol_trade.SetDeviationInPoints(EA_DEVIATION);
        
        double other_volume = SymbolInfoDouble(other_symbol, SYMBOL_VOLUME_MIN);
        if(other_volume == 0) other_volume = 0.01;

        if (other_symbol_trade.Buy(other_volume, other_symbol, 0, 0, 0, EA_TAG + " OtherSymbolPos"))
        {
            Sleep(1000);
            if (PositionSelect(other_symbol))
            {
                ulong other_ticket = PositionGetInteger(POSITION_TICKET);
                SetExits(trade, other_ticket, Grid); // Use main 'trade' object
                Sleep(500);

                if (PositionSelectByTicket(other_ticket))
                {
                    Assert(PositionGetDouble(POSITION_SL) == 0.0, "Other Symbol: SL not set by current chart's SetExits");
                    Assert(PositionGetDouble(POSITION_TP) == 0.0, "Other Symbol: TP not set by current chart's SetExits");
                }
                else { Print("Test_SetExits_Functionality - Other Symbol: FAILED (Position on other symbol disappeared)"); tests_failed++; }
                CleanupCurrentSymbol(trade, other_symbol); // Clean up other_symbol's position
            }
            else { Print("Test_SetExits_Functionality - Other Symbol: SKIPPED (Could not select position on other symbol. Error: ", GetLastError(), ")"); tests_failed++; CleanupCurrentSymbol(trade, other_symbol); }
        }
        else { Print("Test_SetExits_Functionality - Other Symbol: SKIPPED (Failed to open position on '", other_symbol, "'. Error: ", GetLastError(), ")"); tests_failed++; }
        SymbolSelect(other_symbol, false); 
    }
    else { Print("Test_SetExits_Functionality - Other Symbol: SKIPPED (No other tradable symbol found)"); }
    trade.SetTypeFillingBySymbol(symbol); // Ensure main trade object is set back

    // --- Test Case 6: PositionModify fails (e.g., SL/TP too close) ---
    Print("--- Test Case 6: PositionModify Fails (SL/TP too close) ---");
    CleanupCurrentSymbol(trade);
    double stops_level_points = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_stop_price_delta = stops_level_points * point;
    if (min_stop_price_delta == 0) min_stop_price_delta = point * 5; // Fallback if stops_level is 0 or very small

    double too_small_stop_size = min_stop_price_delta * 0.5; // Try to set SL/TP half of minimum distance
    if (too_small_stop_size < point) too_small_stop_size = point; // Ensure it's at least 1 point
    Grid.unit = too_small_stop_size;

    if (trade.Buy(volume, symbol, 0, 0, 0, EA_TAG + " TestModifyFail"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            test_ticket = PositionGetInteger(POSITION_TICKET);
            PrintFormat("Attempting SetExits with too_small_stop_size: %.5f (min_stop_price_delta: %.5f) for ticket %d", too_small_stop_size, min_stop_price_delta, test_ticket);

            SetExits(trade, test_ticket, Grid);
            Sleep(1000); 

            Assert(!PositionSelectByTicket(test_ticket), "PositionModify Fails: Position was closed", "Ticket " + (string)test_ticket + " should be closed. LastError for trade: " + (string)trade.ResultRetcode() + ", Message: " + trade.ResultRetcodeDescription());
            // Expect log messages: "FATAL ERROR - Failed to set take profit and stop loss..." and "Position closed due to error..."
        }
        else { Print("Test_SetExits_Functionality - PositionModify Fails: SKIPPED (Could not select test position. Error: ", GetLastError(), ")"); tests_failed++; }
        CleanupCurrentSymbol(trade); // Ensure clean state
    }
    else { Print("Test_SetExits_Functionality - PositionModify Fails: SKIPPED (Failed to open test position. Error: ", GetLastError(), ")"); tests_failed++; }
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("--- Starting ExitManager.mqh Tests ---");

    // --- Sanity Checks ---
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("ERROR: Automated trading is not enabled. Please enable 'Allow automated trading' in Terminal options and EA properties.");
        return;
    }
    if (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
    {
        Print("WARNING: Running tests on a REAL account! Ensure this is intended and the symbol/volume are safe.");
        ExpertRemove(); 
        return;
    }
    if (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
    {
        Print("ERROR: The current symbol (", _Symbol, ") is not tradable. Please attach the script to a tradable symbol chart.");
        return;
    }
    if (SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0 && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) == 0)
    {
        // This might be too broad, as some symbols (like XAUUSD on some brokers) might have 0 min_vol but allow 0.01
        PrintFormat("WARNING: Symbol %s reports SYMBOL_VOLUME_MIN as 0. Test trades might use a default 0.01 volume.", _Symbol);
    }

    // --- Initialize CTrade ---
    // trade.SetExpertMagicNumber(EA_MAGIC); // Set a specific magic number for tests if needed, though ExitManager relies on comment
    trade.SetTypeFillingBySymbol(_Symbol); 
    trade.SetDeviationInPoints(EA_DEVIATION);      // Allow some slippage
    trade.SetAsyncMode(false);           // Synchronous trading for tests

    // --- Run Test Suites ---
    Test_SetExits_Functionality();

    // --- Test Summary ---
    Print("--- ExitManager.mqh Test Summary ---");
    PrintFormat("Total Tests: %d", tests_passed + tests_failed);
    PrintFormat("Tests Passed: %d", tests_passed);
    PrintFormat("Tests Failed: %d", tests_failed);
    Print("--- Testing Finished ---\n");

    // Final cleanup of the current symbol chart
    CleanupCurrentSymbol(trade);
    // ObjectsDeleteAll(0);
    // ChartRedraw();
}
//+------------------------------------------------------------------+