#include <Ossi\LongTails\Utils.mqh>      // For GridInfo, GridBase, EA_TAG, NodeExistsAtPrice etc.
#include <Ossi\LongTails\GridHandler\PlaceGridNodes.mqh> // The file to test

// Global CTrade object used by PlaceGridNodes.mqh and this test script
CTrade trade; // This global 'trade' object is used by PlaceGridNodes.mqh

// Test framework globals
int tests_passed = 0;
int tests_failed = 0;
string current_test_suite = "";

// Define constants if not available from includes
#ifndef SESSION_ACTIVE
#define SESSION_ACTIVE 0
#endif
#ifndef SESSION_OVER
#define SESSION_OVER 1
#endif


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
//| Cleanup Helper                                                   |
//+------------------------------------------------------------------+
void CleanupCurrentSymbol(CTrade &trade_obj, string symbol_to_clean = _Symbol)
{
    // Close any open positions for the specified symbol
    if (PositionSelect(symbol_to_clean))
    {
        trade_obj.PositionClose(symbol_to_clean, EA_DEVIATION);
        Sleep(500); // Allow time for close
    }
    // Delete all pending orders for the specified symbol
    DeleteAllPending(trade_obj, symbol_to_clean); // Assumes DeleteAllPending is in Utils.mqh
    Sleep(500); // Allow time for deletion
}

//+------------------------------------------------------------------+
//| Test Suite for PlaceContinuationNode                             |
//+------------------------------------------------------------------+
void Test_PlaceContinuationNode_Functionality()
{
    current_test_suite = "PlaceContinuationNode";
    string symbol = _Symbol;
    double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if (volume_min == 0) volume_min = 0.01;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0) point = (_Digits == 5 || _Digits == 3) ? 0.00001 : 0.001; // Fallback

    GridInfo grid_params;
    grid_params.Init(200 * point, 2.0, USE_SESSION); // unit, multiplier
    ArrayResize(grid_params.progression_sequence, 2);
    grid_params.progression_sequence[0] = volume_min;
    grid_params.progression_sequence[1] = volume_min*2;

    ulong ref_ticket = 0;
    double ref_price = 0;
    long ref_type = -1;

    // --- Test Case 1: Valid BUY position, session active ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 1: BUY position, active session ---", current_test_suite);
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " ContBuyBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            ref_type = PositionGetInteger(POSITION_TYPE);
            // Set TP on base position as PlaceContinuationNode checks for it
            trade.PositionModify(ref_ticket, PositionGetDouble(POSITION_SL), ref_price + grid_params.target);
            Sleep(200);

            PlaceContinuationNode(trade, ref_ticket, grid_params);
            Sleep(500);

            // For BUY position, continuation node is BUY_STOP at ref_price + target + spread
            double expected_node_price = NormalizeDouble(ref_price + grid_params.target + grid_params.spread, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "BUY Cont: Node placed", "Expected at " + DoubleToString(expected_node_price, _Digits));

            if (node_ticket != 0 && OrderSelect(node_ticket))
            {
                Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP, "BUY Cont: Node type BUY_STOP");
                Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - grid_params.progression_sequence[0]) < 0.00001, "BUY Cont: Node volume");
                string expected_comment = EA_TAG + " Continuation node as ORDER_TYPE_BUY_STOP";
                Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "BUY Cont: Node comment", "Expected: '"+expected_comment+"', Got: '"+OrderGetString(ORDER_COMMENT)+"'");
            }
        } else { Print("%s - BUY Cont: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - BUY Cont: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 2: Valid SELL position, session active ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 2: SELL position, active session ---", current_test_suite);
    if (trade.Sell(volume_min, symbol, 0, 0, 0, EA_TAG + " ContSellBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            ref_type = PositionGetInteger(POSITION_TYPE);
            trade.PositionModify(ref_ticket, PositionGetDouble(POSITION_SL), ref_price - grid_params.target); // Set TP
            Sleep(200);

            PlaceContinuationNode(trade, ref_ticket, grid_params);
            Sleep(500);

            // For SELL position, continuation node is SELL_STOP at ref_price - target
            double expected_node_price = NormalizeDouble(ref_price - grid_params.target, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "SELL Cont: Node placed", "Expected at " + DoubleToString(expected_node_price, _Digits));

            if (node_ticket != 0 && OrderSelect(node_ticket))
            {
                Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "SELL Cont: Node type SELL_STOP");
                Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - grid_params.progression_sequence[0]) < 0.00001, "SELL Cont: Node volume");
                string expected_comment = EA_TAG + " Continuation node as ORDER_TYPE_SELL_STOP";
                Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "SELL Cont: Node comment", "Expected: '"+expected_comment+"', Got: '"+OrderGetString(ORDER_COMMENT)+"'");
            }
        } else { Print("%s - SELL Cont: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - SELL Cont: SKIPPED (Failed to open base SELL position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 3: Session OVER ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 3: Session OVER ---", current_test_suite);
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " ContSessionOverBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            grid_params.session_status = SESSION_OVER;
            PlaceContinuationNode(trade, ref_ticket, grid_params);
            Sleep(500);
            Assert(SymbolOrdersTotal() == 0, "Session OVER: No node placed");
        } else { Print("%s - Session OVER: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
        grid_params.session_status = SESSION_RUNNING;
    } else { Print("%s - Session OVER: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 4: Node already exists ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 4: Node already exists ---", current_test_suite);
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " ContNodeExistsBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            trade.PositionModify(ref_ticket, 0, ref_price + grid_params.target); // Set TP
            Sleep(200);

            double node_price = NormalizeDouble(ref_price + grid_params.target + grid_params.spread, _Digits);
            trade.BuyStop(grid_params.progression_sequence[0], node_price, symbol, 0, 0, ORDER_TIME_GTC, 0, "ManualContNode");
            Sleep(500);
            int orders_before = SymbolOrdersTotal();

            PlaceContinuationNode(trade, ref_ticket, grid_params);
            Sleep(500);
            Assert(SymbolOrdersTotal() == orders_before, "Node Exists: No new node placed");
        } else { Print("%s - Node Exists: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Node Exists: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 5: Invalid reference ticket ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 5: Invalid reference ticket ---", current_test_suite);
    PlaceContinuationNode(trade, 99999999, grid_params);
    Sleep(500);
    Assert(SymbolOrdersTotal() == 0, "Invalid Ref Ticket: No node placed");
    CleanupCurrentSymbol(trade);
    
    // --- Test Case 6: Reference position has no TP (warning case) ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 6: BUY position, no TP (warning) ---", current_test_suite);
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " ContBuyNoTPBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            // DO NOT set TP

            PlaceContinuationNode(trade, ref_ticket, grid_params);
            Sleep(500); // Allow time for print message to appear in logs

            // Node should still be placed, but a warning printed.
            double expected_node_price = NormalizeDouble(ref_price + grid_params.target + grid_params.spread, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "BUY Cont No TP: Node placed despite no TP on ref", "Expected at " + DoubleToString(expected_node_price, _Digits));
            // Manual check of logs for "WARNING. No take profit set..." is needed for full verification of this case.
        } else { Print("%s - BUY Cont No TP: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - BUY Cont No TP: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }
}

//+------------------------------------------------------------------+
//| Test Suite for PlaceRecoveryNode                                 |
//+------------------------------------------------------------------+
void Test_PlaceRecoveryNode_Functionality()
{
    current_test_suite = "PlaceRecoveryNode";
    string symbol = _Symbol;
    double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if (volume_min == 0) volume_min = 0.01;

    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0) point = (_Digits == 5 || _Digits == 3) ? 0.00001 : 0.001; // Fallback

    GridInfo grid_params;
    grid_params.Init(200 * point, 2.0, USE_SESSION); // unit, multiplier
    ArrayResize(grid_params.progression_sequence, 2);
    grid_params.progression_sequence[0] = volume_min;
    grid_params.progression_sequence[1] = volume_min * 2; // Next volume in sequence

    GridBase base_info; // Will be properly initialized per test case

    ulong ref_ticket = 0;
    double ref_price = 0;

    // --- Test Case 1: Ref is BUY position, place SELL_STOP ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 1: Ref BUY position ---", current_test_suite);
    base_info.volume_index = 0; // So recovery node uses progression_sequence[1]
    if (trade.Buy(grid_params.progression_sequence[0], symbol, 0, 0, 0, EA_TAG + " RecBuyBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            // Set SL on base position as PlaceRecoveryNode checks for it
            trade.PositionModify(ref_ticket, ref_price - grid_params.unit, PositionGetDouble(POSITION_TP));
            Sleep(200);

            PlaceRecoveryNode(trade, ref_ticket, grid_params, &base_info);
            Sleep(500);

            // For BUY position, recovery node is SELL_STOP at ref_price - unit
            double expected_node_price = NormalizeDouble(ref_price - grid_params.unit, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "Rec from BUY: Node placed", "Expected at " + DoubleToString(expected_node_price, _Digits));

            if (node_ticket != 0 && OrderSelect(node_ticket))
            {
                Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "Rec from BUY: Node type SELL_STOP");
                Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - grid_params.progression_sequence[base_info.volume_index + 1]) < 0.00001, "Rec from BUY: Node volume");
                string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_SELL_STOP";
                Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "Rec from BUY: Node comment", "Expected: '"+expected_comment+"', Got: '"+OrderGetString(ORDER_COMMENT)+"'");
            }
        } else { Print("%s - Rec from BUY: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Rec from BUY: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 2: Ref is SELL position, place BUY_STOP ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 2: Ref SELL position ---", current_test_suite);
    base_info.volume_index = 0;
    if (trade.Sell(grid_params.progression_sequence[0], symbol, 0, 0, 0, EA_TAG + " RecSellBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            trade.PositionModify(ref_ticket, ref_price + grid_params.unit, PositionGetDouble(POSITION_TP)); // Set SL
            Sleep(200);

            PlaceRecoveryNode(trade, ref_ticket, grid_params, &base_info);
            Sleep(500);

            // For SELL position, recovery node is BUY_STOP at ref_price + unit + spread
            double expected_node_price = NormalizeDouble(ref_price + grid_params.unit + grid_params.spread, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "Rec from SELL: Node placed", "Expected at " + DoubleToString(expected_node_price, _Digits));

            if (node_ticket != 0 && OrderSelect(node_ticket))
            {
                Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP, "Rec from SELL: Node type BUY_STOP");
                Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - grid_params.progression_sequence[base_info.volume_index + 1]) < 0.00001, "Rec from SELL: Node volume");
                string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_BUY_STOP";
                Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "Rec from SELL: Node comment", "Expected: '"+expected_comment+"', Got: '"+OrderGetString(ORDER_COMMENT)+"'");
            }
        } else { Print("%s - Rec from SELL: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Rec from SELL: SKIPPED (Failed to open base SELL position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 3: Ref is pending BUY_STOP order, place SELL_STOP ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 3: Ref pending BUY_STOP ---", current_test_suite);
    double pending_buy_stop_price = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK) + 200 * point, _Digits); // Place away from market
    double pending_volume = volume_min * 3; // A distinct volume
    if (trade.BuyStop(pending_volume, pending_buy_stop_price, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RefPendingBuyStop"))
    {
        ref_ticket = trade.ResultOrder();
        Sleep(500);
        if (ref_ticket != 0)
        {
            PlaceRecoveryNode(trade, ref_ticket, grid_params, NULL); // base_info is NULL for pending order ref
            Sleep(500);

            // For pending BUY_STOP, recovery is SELL_STOP at ref_price - (unit + spread)
            double expected_node_price = NormalizeDouble(pending_buy_stop_price - (grid_params.unit + grid_params.spread), _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "Rec from BUY_STOP: Node placed", "Expected at " + DoubleToString(expected_node_price, _Digits));

            if (node_ticket != 0 && OrderSelect(node_ticket))
            {
                Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "Rec from BUY_STOP: Node type SELL_STOP");
                Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - pending_volume) < 0.00001, "Rec from BUY_STOP: Node volume (same as ref)");
                string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_SELL_STOP";
                Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "Rec from BUY_STOP: Node comment", "Expected: '"+expected_comment+"', Got: '"+OrderGetString(ORDER_COMMENT)+"'");
            }
        } else { Print("%s - Rec from BUY_STOP: SKIPPED (Failed to place ref pending order. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Rec from BUY_STOP: SKIPPED (Failed to place ref pending order. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 4: Invalid reference ticket ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 4: Invalid reference ticket ---", current_test_suite);
    PlaceRecoveryNode(trade, 99999998, grid_params, NULL);
    Sleep(500);
    Assert(SymbolOrdersTotal() == 0, "Invalid Ref Ticket (Rec): No node placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 5: Ref is pending order but NOT BUY_STOP (e.g., SELL_LIMIT) ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 5: Ref pending SELL_LIMIT (invalid for recovery) ---", current_test_suite);
    double pending_sell_limit_price = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK) + 200 * point, _Digits);
    if (trade.SellLimit(volume_min, pending_sell_limit_price, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RefWrongPending"))
    {
        ref_ticket = trade.ResultOrder();
        Sleep(500);
        if (ref_ticket != 0)
        {
            PlaceRecoveryNode(trade, ref_ticket, grid_params, NULL);
            Sleep(500);
            // Expect "FATAL. Recovery node can only be placed on buy stop" print and no new order.
            // Original order should still exist.
            Assert(OrdersTotal() == 1 && OrderSelect(ref_ticket) && OrderGetInteger(ORDER_TICKET) == ref_ticket,
                   "Ref wrong pending: No new node placed, original still exists");
        } else { Print("%s - Ref wrong pending: SKIPPED (Failed to place ref SELL_LIMIT order. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Ref wrong pending: SKIPPED (Failed to place ref SELL_LIMIT order. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

    // --- Test Case 6: Ref is Position, but base_info is NULL ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 6: Ref Position, base_info NULL ---", current_test_suite);
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " RecNullBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            int orders_before = SymbolOrdersTotal(); // Should be 0 if only position exists
            PlaceRecoveryNode(trade, ref_ticket, grid_params, NULL); // Pass NULL for base
            Sleep(500);
            // Expects "unable to assess grid base" print from AssertRecoveryNode and no order.
            Assert(SymbolOrdersTotal() == orders_before, "Ref Pos, base NULL: No node placed");
        } else { Print("%s - Ref Pos, base NULL: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Ref Pos, base NULL: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }
    
    // --- Test Case 7: Ref is BUY position, no SL (warning case) ---
    CleanupCurrentSymbol(trade);
    Print("--- %s: Test Case 7: Ref BUY position, no SL (warning) ---", current_test_suite);
    base_info.volume_index = 0; 
    if (trade.Buy(grid_params.progression_sequence[0], symbol, 0, 0, 0, EA_TAG + " RecBuyNoSLBase"))
    {
        Sleep(500);
        if (PositionSelect(symbol))
        {
            ref_ticket = PositionGetInteger(POSITION_TICKET);
            ref_price = PositionGetDouble(POSITION_PRICE_OPEN);
            // DO NOT set SL

            PlaceRecoveryNode(trade, ref_ticket, grid_params, &base_info);
            Sleep(500);

            // Node should still be placed, but a warning printed.
            double expected_node_price = NormalizeDouble(ref_price - grid_params.unit, _Digits);
            ulong node_ticket = NodeExistsAtPrice(expected_node_price);
            Assert(node_ticket != 0, "Rec from BUY No SL: Node placed despite no SL on ref", "Expected at " + DoubleToString(expected_node_price, _Digits));
            // Manual check of logs for "WARNING. No stop loss set..." is needed.
        } else { Print("%s - Rec from BUY No SL: SKIPPED (Could not select base position)", current_test_suite); tests_failed++; }
        CleanupCurrentSymbol(trade);
    } else { Print("%s - Rec from BUY No SL: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed++; }

}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("--- Starting PlaceGridNodes.mqh Tests ---");

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
     double point_val = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
     if (point_val == 0) {
        PrintFormat("WARNING: Symbol %s reports SYMBOL_POINT as 0. Price calculations might be affected. Using a fallback.", _Symbol);
     }
     if (SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) == 0 && SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP) == 0)
     {
        PrintFormat("WARNING: Symbol %s reports SYMBOL_VOLUME_MIN as 0. Test trades might use a default 0.01 volume.", _Symbol);
     }

    // --- Initialize CTrade ---
    // trade.SetExpertMagicNumber(12345); // The global 'trade' object is used by PlaceGridNodes.mqh
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(EA_DEVIATION); 
    trade.SetAsyncMode(false);      // Synchronous trading for tests

    // --- Run Test Suites ---
    Test_PlaceContinuationNode_Functionality();
    Test_PlaceRecoveryNode_Functionality();

    // --- Test Summary ---
    Print("--- PlaceGridNodes.mqh Test Summary ---");
    PrintFormat("Total Tests: %d", tests_passed + tests_failed);
    PrintFormat("Tests Passed: %d", tests_passed);
    PrintFormat("Tests Failed: %d", tests_failed);
    Print("--- Testing Finished ---\n");

    // Final cleanup
    CleanupCurrentSymbol(trade);
}
//+------------------------------------------------------------------+

```

3.  **`GridBase` Pointer:** In `Test_PlaceRecoveryNode_Functionality`, `&base_info` is passed when a position is the reference, and `NULL` is passed when a pending order is the reference, aligning with how `PlaceRecoveryNode` expects the `GridBase* base` parameter.
4.  **Warning Cases:** Added test cases (Test Case 6 for `PlaceContinuationNode` and Test Case 7 for `PlaceRecoveryNode`) to check scenarios where warnings about missing TP/SL are expected. The tests verify that the node is still placed, but you'd need to manually check the logs for the printed warning message itself.
6.  **Clarity in Skipped Tests:** Improved messages for skipped tests to include `GetLastError()` where applicable.
7.  **Pending Order Type for Recovery:** Test Case 5 for `PlaceRecoveryNode` now uses `SELL_LIMIT` as an example of an invalid pending order type for recovery, as `PlaceRecoveryNode` specifically checks if the reference order is `ORDER_TYPE_BUY_STOP`.
8.  **`NodeExistsAtPrice`:** The tests implicitly rely on `NodeExistsAtPrice` to find the placed orders for verification.

