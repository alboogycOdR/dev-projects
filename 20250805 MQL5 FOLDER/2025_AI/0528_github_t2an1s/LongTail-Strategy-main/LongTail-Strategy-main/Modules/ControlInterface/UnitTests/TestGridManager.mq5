#include <Ossi\LongTails\Utils.mqh>
#include <Ossi\LongTails\GridHandler\PlaceGridNodes.mqh> // Dependency for GridManager
#include <Ossi\LongTails\ExitManager.mqh> // Include the actual ExitManager
#include <Ossi\LongTails\GridHandler\GridManager.mqh>  // The file to test

// Global CTrade object used by PlaceGridNodes.mqh, GridManager.mqh and this test script
CTrade trade; // This global 'trade' object is used by the included files

// Test framework globals
int tests_passed = 0;
int tests_failed = 0;
string current_test_suite = "";

// Define constants if not available from includes
#ifndef EA_TAG
#define EA_TAG "LTS_TEST" // Define a test EA tag
#endif

#ifndef SESSION_ACTIVE
#define SESSION_ACTIVE 0
#endif
#ifndef SESSION_OVER
#define SESSION_OVER 1
#endif

#ifndef EA_DEVIATION
#define EA_DEVIATION 10 // Default slippage for trade operations
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
//| Test Suite for IsRecoveryGap                                     |
//+------------------------------------------------------------------+
void Test_IsRecoveryGap_Functionality()
{
    current_test_suite = "IsRecoveryGap";
    string symbol = _Symbol;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0) point = (_Digits == 5 || _Digits == 3) ? 0.00001 : 0.001;

    GridInfo test_grid; // Use GridInfo
    test_grid.Init(100 * point, 5 * point, 2.0); // unit, spread, multiplier

    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

    // --- Test Case 1: No BUY_STOP order exists ---
    Print("--- %s: Test Case 1: No BUY_STOP order ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    Assert(IsRecoveryGap(test_grid) == false, "No BUY_STOP: Returns false");

    // --- Test Case 2: BUY_STOP exists, price below threshold ---
    Print("--- %s: Test Case 2: BUY_STOP exists, price below threshold ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    // Place BUY_STOP far above current bid, so bid < (BS_price - unit)
    double buy_stop_price_case2 = NormalizeDouble(bid + 2 * test_grid.unit + test_grid.unit, _Digits); // BS Price > bid + 2*unit
    ulong bs_ticket_2 = 0;
    if (trade.BuyStop(0.01, buy_stop_price_case2, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RecoveryGapBS2")) bs_ticket_2 = trade.ResultOrder();
    Sleep(200);
    // Threshold = BS_price - unit. We need bid < Threshold.
    Assert(IsRecoveryGap(test_grid) == false, "Price below threshold: Returns false", "Bid: "+DoubleToString(bid,_Digits)+", BS Price: "+DoubleToString(buy_stop_price_case2,_Digits)+", Threshold: "+DoubleToString(buy_stop_price_case2 - test_grid.unit,_Digits));
    if(bs_ticket_2 != 0) trade.OrderDelete(bs_ticket_2);

    // --- Test Case 3: BUY_STOP exists, price above threshold ---
    Print("--- %s: Test Case 3: BUY_STOP exists, price above threshold ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    // Place BUY_STOP such that current bid > (BS_price - unit)
    double buy_stop_price_case3 = NormalizeDouble(bid + test_grid.unit * 0.5, _Digits); // BS Price = bid + 0.5*unit
    ulong bs_ticket_3 = 0;
    if (trade.BuyStop(0.01, buy_stop_price_case3, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RecoveryGapBS3")) bs_ticket_3 = trade.ResultOrder();
    Sleep(200);
    // Threshold = BS_price - unit = (bid + 0.5*unit) - unit = bid - 0.5*unit.
    // Since bid > (bid - 0.5*unit), it should be true.
    Assert(IsRecoveryGap(test_grid) == true, "Price above threshold: Returns true", "Bid: "+DoubleToString(bid,_Digits)+", BS Price: "+DoubleToString(buy_stop_price_case3,_Digits)+", Threshold: "+DoubleToString(buy_stop_price_case3 - test_grid.unit,_Digits));
    if(bs_ticket_3 != 0) trade.OrderDelete(bs_ticket_3);

    // --- Test Case 4: BUY_STOP exists, price equal to threshold ---
    Print("--- %s: Test Case 4: BUY_STOP exists, price equal to threshold ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    // Set buy_stop_price so that recovery_threshold is exactly current bid.
    double buy_stop_price_case4 = NormalizeDouble(bid + test_grid.unit, _Digits); // recovery_threshold = bid
    ulong bs_ticket_4 = 0;
    if (trade.BuyStop(0.01, buy_stop_price_case4, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RecoveryGapBS4")) bs_ticket_4 = trade.ResultOrder();
    Sleep(200);
    // The condition is `price_current > recovery_treshhold`. If equal, it's false.
    Assert(IsRecoveryGap(test_grid) == false, "Price equal threshold: Returns false", "Bid: "+DoubleToString(bid,_Digits)+", BS Price: "+DoubleToString(buy_stop_price_case4,_Digits)+", Threshold: "+DoubleToString(buy_stop_price_case4 - test_grid.unit,_Digits));
    if(bs_ticket_4 != 0) trade.OrderDelete(bs_ticket_4);

    // --- Test Case 5: Multiple BUY_STOP orders exist ---
    Print("--- %s: Test Case 5: Multiple BUY_STOP orders ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    // Place BS1 far away (should return false based on this)
    double bs1_price_c5 = NormalizeDouble(bid + 2 * test_grid.unit + test_grid.unit, _Digits);
    ulong bs_ticket_5_1 = 0;
    if (trade.BuyStop(0.01, bs1_price_c5, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RecoveryGapBS5_1")) bs_ticket_5_1 = trade.ResultOrder();
    Sleep(100);
    // Place BS2 close (should return true based on this, as loop finds last)
    double bs2_price_c5 = NormalizeDouble(bid + test_grid.unit * 0.5, _Digits);
    ulong bs_ticket_5_2 = 0;
    if (trade.BuyStop(0.01, bs2_price_c5, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " RecoveryGapBS5_2")) bs_ticket_5_2 = trade.ResultOrder();
    Sleep(200);

    // IsRecoveryGap checks the LAST BUY_STOP found in the loop (bs_ticket_5_2)
    // Threshold for bs_ticket_5_2 = bs2_price_c5 - unit = (bid + 0.5*unit) - unit = bid - 0.5*unit.
    // Since bid > (bid - 0.5*unit), it should be true.
    Assert(IsRecoveryGap(test_grid) == true, "Multiple BUY_STOPs: Returns true based on LAST order", "Bid: "+DoubleToString(bid,_Digits)+", Last BS Price: "+DoubleToString(bs2_price_c5,_Digits)+", Threshold: "+DoubleToString(bs2_price_c5 - test_grid.unit,_Digits));

    if(bs_ticket_5_1 != 0) trade.OrderDelete(bs_ticket_5_1);
    if(bs_ticket_5_2 != 0) trade.OrderDelete(bs_ticket_5_2);

    CleanupCurrentSymbol(trade);
}

//+------------------------------------------------------------------+
//| Test Suite for HandleNewPosition                                 |
//+------------------------------------------------------------------+
void Test_HandleNewPosition_Functionality()
{
    current_test_suite = "HandleNewPosition";
    string symbol = _Symbol;
    double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if (volume_min == 0) volume_min = 0.01;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0) point = (_Digits == 5 || _Digits == 3) ? 0.00001 : 0.001;

    GridInfo test_grid; // Use GridInfo
    test_grid.Init(100 * point, 5 * point, 2.0); // unit, spread, multiplier
    ArrayResize(test_grid.progression_sequence, 3); // Need at least 3 for recovery from index 1
    test_grid.progression_sequence[0] = volume_min;
    test_grid.progression_sequence[1] = volume_min * 2;
    test_grid.progression_sequence[2] = volume_min * 4;
    test_grid.status = SESSION_ACTIVE;

    GridBase test_base;

    // --- Test Case 1: New BUY position (not recovery) ---
    Print("--- %s: Test Case 1: New BUY position (not recovery) ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    ulong buy_ticket = 0;
    if (trade.Buy(volume_min, symbol, 0, 0, 0, EA_TAG + " NewBuyPos")) buy_ticket = trade.ResultTicket();
    Sleep(500);

    if (buy_ticket != 0 && PositionSelectByTicket(buy_ticket))
    {
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        HandleNewPosition(test_base, test_grid);
        Sleep(500);

        // Verify GridBase update
        Assert(test_base.ticket == buy_ticket, "BUY Base: Ticket updated");
        Assert(test_base.name == EA_TAG + " NewBuyPos", "BUY Base: Name updated");
        Assert(test_base.type == POSITION_TYPE_BUY, "BUY Base: Type updated");
        Assert(test_base.volume == volume_min, "BUY Base: Volume updated");
        Assert(test_base.open_price == open_price, "BUY Base: Open Price updated");
        Assert(test_base.volume_index == 0, "BUY Base: Volume index is 0");

        // Verify SetExits (actual ExitManager::SetExits is called)
        if (PositionSelectByTicket(buy_ticket)) // Re-select to get latest SL/TP
        {
            // SetExits uses grid.unit and grid.multiplier
            double expected_sl = NormalizeDouble(open_price - test_grid.unit, _Digits);
            double expected_tp = NormalizeDouble(open_price + test_grid.unit * test_grid.multiplier, _Digits);
            Assert(MathAbs(PositionGetDouble(POSITION_SL) - expected_sl) < point, "BUY Base: SL set", "Expected: " + DoubleToString(expected_sl,_Digits)+" Got: "+DoubleToString(PositionGetDouble(POSITION_SL),_Digits));
            Assert(MathAbs(PositionGetDouble(POSITION_TP) - expected_tp) < point, "BUY Base: TP set", "Expected: " + DoubleToString(expected_tp,_Digits)+" Got: "+DoubleToString(PositionGetDouble(POSITION_TP),_Digits));
        } else { tests_failed++; Print("%s - BUY Base: SKIPPED SL/TP check (position disappeared)", current_test_suite); }

        // Verify PlaceRecoveryNode (SELL_STOP)
        // Price: ref_price - unit
        double expected_rec_price = NormalizeDouble(open_price - test_grid.unit, _Digits);
        ulong rec_node_ticket = NodeExistsAtPrice(expected_rec_price);
        Assert(rec_node_ticket != 0, "BUY Base: Recovery node (SELL_STOP) placed", "Expected at " + DoubleToString(expected_rec_price, _Digits));
        if (rec_node_ticket != 0 && OrderSelect(rec_node_ticket))
        {
            Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "BUY Base: Recovery node type SELL_STOP");
            Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - test_grid.progression_sequence[test_base.volume_index + 1]) < 0.00001, "BUY Base: Recovery node volume"); // base.volume_index = 0, so seq[1]
            string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_SELL_STOP";
            Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "BUY Base: Recovery node comment");
        }

        // Verify PlaceContinuationNode (BUY_STOP)
        // Price: ref_price + target + spread
        double expected_cont_price = NormalizeDouble(open_price + test_grid.target + test_grid.spread, _Digits);
        ulong cont_node_ticket = NodeExistsAtPrice(expected_cont_price);
        Assert(cont_node_ticket != 0, "BUY Base: Continuation node (BUY_STOP) placed", "Expected at " + DoubleToString(expected_cont_price, _Digits));
        if (cont_node_ticket != 0 && OrderSelect(cont_node_ticket))
        {
            Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP, "BUY Base: Continuation node type BUY_STOP");
            Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - test_grid.progression_sequence[0]) < 0.00001, "BUY Base: Continuation node volume");
             string expected_comment = EA_TAG + " Continuation node as ORDER_TYPE_BUY_STOP";
            Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "BUY Base: Continuation node comment");
        }
        Assert(SymbolOrdersTotal() == 2, "BUY Base: Total 2 orders placed");

    } else { Print("%s - BUY Base: SKIPPED (Failed to open base BUY position. Error: %d)", current_test_suite, GetLastError()); tests_failed += 8; } // Skip multiple asserts
    CleanupCurrentSymbol(trade);

    // --- Test Case 2: New SELL position (recovery type name) ---
    Print("--- %s: Test Case 2: New SELL position (recovery name) ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.volume_index = 0; // Simulate previous state before this recovery position
    ulong sell_ticket = 0;
    if (trade.Sell(test_grid.progression_sequence[0], symbol, 0, 0, 0, EA_TAG + " My Recovery SellPos")) sell_ticket = trade.ResultTicket();
    Sleep(500);

    if (sell_ticket != 0 && PositionSelectByTicket(sell_ticket))
    {
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        HandleNewPosition(test_base, test_grid);
        Sleep(500);

        Assert(test_base.ticket == sell_ticket, "SELL Rec Base: Ticket updated");
        Assert(StringFind(test_base.name, "Recovery") != -1, "SELL Rec Base: Name contains Recovery");
        Assert(test_base.type == POSITION_TYPE_SELL, "SELL Rec Base: Type updated");
        Assert(test_base.volume == test_grid.progression_sequence[0], "SELL Rec Base: Volume updated");
        Assert(test_base.open_price == open_price, "SELL Rec Base: Open Price updated");
        Assert(test_base.volume_index == 1, "SELL Rec Base: Volume index incremented to 1"); // Was 0, "Recovery" in name increments it

        if (PositionSelectByTicket(sell_ticket))
        {
            double expected_sl = NormalizeDouble(open_price + test_grid.unit, _Digits);
            double expected_tp = NormalizeDouble(open_price - test_grid.unit * test_grid.multiplier, _Digits);
            Assert(MathAbs(PositionGetDouble(POSITION_SL) - expected_sl) < point, "SELL Rec Base: SL set");
            Assert(MathAbs(PositionGetDouble(POSITION_TP) - expected_tp) < point, "SELL Rec Base: TP set");
        } else { tests_failed++; Print("%s - SELL Rec Base: SKIPPED SL/TP check (position disappeared)", current_test_suite); }

        // Verify PlaceRecoveryNode (BUY_STOP)
        // Price: ref_price + unit + spread
        // Volume: progression_sequence[base.volume_index + 1] = sequence[1+1] = sequence[2]
        double expected_rec_price = NormalizeDouble(open_price + test_grid.unit + test_grid.spread, _Digits);
        ulong rec_node_ticket_s = NodeExistsAtPrice(expected_rec_price);
        Assert(rec_node_ticket_s != 0, "SELL Rec Base: Recovery node (BUY_STOP) placed", "Expected at " + DoubleToString(expected_rec_price, _Digits));
        if (rec_node_ticket_s != 0 && OrderSelect(rec_node_ticket_s))
        {
            Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP, "SELL Rec Base: Recovery node type BUY_STOP");
            Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - test_grid.progression_sequence[test_base.volume_index + 1]) < 0.00001, "SELL Rec Base: Recovery node volume"); // base.volume_index = 1, so seq[2]
             string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_BUY_STOP";
            Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "SELL Rec Base: Recovery node comment");
        }

        // Verify PlaceContinuationNode (SELL_STOP)
        // Price: ref_price - target
        // Volume: progression_sequence[0]
        double expected_cont_price = NormalizeDouble(open_price - test_grid.target, _Digits);
        ulong cont_node_ticket_s = NodeExistsAtPrice(expected_cont_price);
        Assert(cont_node_ticket_s != 0, "SELL Rec Base: Continuation node (SELL_STOP) placed", "Expected at " + DoubleToString(expected_cont_price, _Digits));
        if (cont_node_ticket_s != 0 && OrderSelect(cont_node_ticket_s))
        {
            Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "SELL Rec Base: Continuation node type SELL_STOP");
            Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - test_grid.progression_sequence[0]) < 0.00001, "SELL Rec Base: Continuation node volume");
             string expected_comment = EA_TAG + " Continuation node as ORDER_TYPE_SELL_STOP";
            Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "SELL Rec Base: Continuation node comment");
        }
        Assert(SymbolOrdersTotal() == 2, "SELL Rec Base: Total 2 orders placed");

    } else { Print("%s - SELL Rec Base: SKIPPED (Failed to open base SELL position. Error: %d)", current_test_suite, GetLastError()); tests_failed += 8; }
    CleanupCurrentSymbol(trade);

    // --- Test Case 3: No position selected on chart ---
    Print("--- %s: Test Case 3: No position on chart ---", current_test_suite);
    CleanupCurrentSymbol(trade); // Ensure no position
    test_base.ticket = 0; test_base.name = ""; // Reset base
    int orders_before = SymbolOrdersTotal();

    HandleNewPosition(test_base, test_grid);
    Sleep(200);

    Assert(test_base.ticket == 0, "No Position: Base ticket remains 0");
    Assert(test_base.name == "", "No Position: Base name remains empty");
    Assert(SymbolOrdersTotal() == orders_before, "No Position: No new orders placed");
    CleanupCurrentSymbol(trade);
}

//+------------------------------------------------------------------+
//| Test Suite for HandleGridGap                                     |
//+------------------------------------------------------------------+
void Test_HandleGridGap_Functionality()
{
    current_test_suite = "HandleGridGap";
    string symbol = _Symbol;
    double volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if (volume_min == 0) volume_min = 0.01;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if (point == 0) point = (_Digits == 5 || _Digits == 3) ? 0.00001 : 0.001;

    GridInfo test_grid; // Use GridInfo
    test_grid.Init(100 * point, 5 * point, 2.0); // unit, spread, multiplier
    ArrayResize(test_grid.progression_sequence, 2); // For PlaceRecoveryNode from pending
    test_grid.progression_sequence[0] = volume_min;
    test_grid.progression_sequence[1] = volume_min * 2;

    GridBase test_base; // For HandleGridGap, base.type is important
    // CTrade local_trader; // HandleGridGap now takes CTrade&, use global 'trade'
    // local_trader.SetTypeFillingBySymbol(symbol);
    // local_trader.SetAsyncMode(false);
    // local_trader.SetDeviationInPoints(EA_DEVIATION);

    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

    // --- Test Case 1: Conditions met for gap handling (SELL base type, IsRecoveryGap true, 1 BUY_STOP) ---
    Print("--- %s: Test Case 1: Conditions met for gap handling ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.type = POSITION_TYPE_SELL; // Simulate base was a SELL

    // Create a BUY_STOP (our recovery node) such that IsRecoveryGap will be true
    // Place BUY_STOP such that current bid > (BS_price - unit)
    double buy_stop_price_c1 = NormalizeDouble(bid + test_grid.unit * 0.5, _Digits);
    ulong bs_ticket_c1 = 0;
    // Use EA_TAG + " Recovery node" comment for the initial BS so ClearContinuationNodes doesn't delete it
    if(trade.BuyStop(volume_min, buy_stop_price_c1, symbol, 0, 0, ORDER_TIME_GTC, 0, EA_TAG + " Recovery node as ORDER_TYPE_BUY_STOP")) bs_ticket_c1 = trade.ResultOrder();
    Sleep(200);

    // Verify setup conditions
    bool is_gap_c1 = IsRecoveryGap(test_grid);
    int orders_total_c1 = SymbolOrdersTotal();
    bool pos_exists_c1 = PositionSelect(symbol);

    if (bs_ticket_c1 != 0 && is_gap_c1 && orders_total_c1 == 1 && !pos_exists_c1 && test_base.type == POSITION_TYPE_SELL)
    {
        HandleGridGap(test_grid, test_base, trade); // Pass global 'trade' by reference
        Sleep(500);

        // Original BUY_STOP should still exist (ClearContinuationNodes doesn't delete "Recovery node")
        bool original_bs_exists = OrderSelect(bs_ticket_c1);
        Assert(original_bs_exists, "Gap Handled: Original BUY_STOP still exists");

        // A new SELL_STOP should be placed by PlaceRecoveryNode(bs_ticket_c1, test_grid)
        // Price: buy_stop_price_c1 - (test_grid.unit + test_grid.spread)
        // Volume: Same as reference BS (volume_min)
        double expected_new_sell_stop_price = NormalizeDouble(buy_stop_price_c1 - (test_grid.unit + test_grid.spread), _Digits);
        ulong new_sell_stop_ticket = NodeExistsAtPrice(expected_new_sell_stop_price);
        Assert(new_sell_stop_ticket != 0, "Gap Handled: New SELL_STOP placed", "Expected at " + DoubleToString(expected_new_sell_stop_price, _Digits));

        if (new_sell_stop_ticket != 0 && OrderSelect(new_sell_stop_ticket))
        {
            Assert(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP, "Gap Handled: New node type SELL_STOP");
            Assert(MathAbs(OrderGetDouble(ORDER_VOLUME_CURRENT) - volume_min) < 0.00001, "Gap Handled: New node volume (same as ref BS)");
             string expected_comment = EA_TAG + " Recovery node as ORDER_TYPE_SELL_STOP";
            Assert(OrderGetString(ORDER_COMMENT) == expected_comment, "Gap Handled: New node comment");
        }
         Assert(SymbolOrdersTotal() == 2, "Gap Handled: Total 2 orders (original BS, new SS)");

    } else { Print("%s - Gap Handled: SKIPPED (Pre-conditions not met. BS: %d, IsGap: %s, Orders: %d, Pos: %s, BaseType: %s)", current_test_suite, bs_ticket_c1, BoolToString(is_gap_c1), orders_total_c1, BoolToString(pos_exists_c1), EnumToString(test_base.type)); tests_failed += 5; } // Account for multiple asserts below
    CleanupCurrentSymbol(trade);

    // --- Test Case 2: Position exists ---
    Print("--- %s: Test Case 2: Position exists ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    if(trade.Buy(volume_min, symbol, 0,0,0, EA_TAG + " PosExists")) Sleep(200);
    int orders_before_c2 = SymbolOrdersTotal();
    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'
    Sleep(200);
    Assert(SymbolOrdersTotal() == orders_before_c2, "Position Exists: No orders changed/placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 3: No orders exist ---
    Print("--- %s: Test Case 3: No orders exist ---", current_test_suite);
    CleanupCurrentSymbol(trade); // Ensures no orders, no positions
    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'
    Sleep(200);
    Assert(SymbolOrdersTotal() == 0, "No Orders Exist: No orders placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 4: More than 2 orders exist initially ---
    Print("--- %s: Test Case 4: More than 2 orders initially ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.type = POSITION_TYPE_SELL; // To pass that check
    if(trade.BuyStop(volume_min, ask + 100 * point, symbol, 0,0,0,0, EA_TAG + " Order1")) Sleep(50);
    if(trade.SellStop(volume_min, bid - 100 * point, symbol, 0,0,0,0, EA_TAG + " Order2")) Sleep(50);
    if(trade.BuyLimit(volume_min, bid - 100 * point, symbol, 0,0,0,0, EA_TAG + " Order3")) Sleep(50);
    int orders_before_c4 = SymbolOrdersTotal(); // Should be 3 if all placed
    Assert(orders_before_c4 > 2, "More than 2 orders: Setup Correct");

    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'. Expects print warning.
    Sleep(200);
    Assert(SymbolOrdersTotal() == orders_before_c4, "More than 2 orders: No orders changed/placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 5: base.type is POSITION_TYPE_BUY ---
    Print("--- %s: Test Case 5: Base type is BUY ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.type = POSITION_TYPE_BUY;
    // Place a BUY_STOP that would trigger IsRecoveryGap if base type was SELL
    double buy_stop_price_c5 = NormalizeDouble(bid + test_grid.unit * 0.5, _Digits);
    if(trade.BuyStop(volume_min, buy_stop_price_c5, symbol, 0,0,0,0, EA_TAG + " SomeOrder")) Sleep(50); // Ensure an order exists
    Assert(IsRecoveryGap(test_grid), "Base Type BUY: IsRecoveryGap True Setup Correct");
    int orders_before_c5 = SymbolOrdersTotal();
    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'
    Sleep(200);
    Assert(SymbolOrdersTotal() == orders_before_c5, "Base Type BUY: No orders changed/placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 6: IsRecoveryGap returns false ---
    Print("--- %s: Test Case 6: IsRecoveryGap is false ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.type = POSITION_TYPE_SELL;
    // Place BUY_STOP far away so IsRecoveryGap is false
    double buy_stop_price_c6 = NormalizeDouble(ask + 5 * test_grid.unit, _Digits);
    if(trade.BuyStop(volume_min, buy_stop_price_c6, symbol, 0,0,0,0, EA_TAG + " FarBS")) Sleep(50);
    Assert(IsRecoveryGap(test_grid) == false, "IsRecoveryGap False: Setup Correct");
    int orders_before_c6 = SymbolOrdersTotal();

    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'
    Sleep(200);
    Assert(SymbolOrdersTotal() == orders_before_c6, "IsRecoveryGap False: No orders changed/placed");
    CleanupCurrentSymbol(trade);

    // --- Test Case 7: More than 1 order after ClearContinuationNodes ---
    // This tests the `if (SymbolOrdersTotal() > 1) return;` check after clearing.
    Print("--- %s: Test Case 7: >1 order after ClearContinuationNodes ---", current_test_suite);
    CleanupCurrentSymbol(trade);
    test_base.type = POSITION_TYPE_SELL;
    // Create two "recovery" nodes (by comment, ClearContinuationNodes shouldn't remove them)
    // And ensure IsRecoveryGap is true for the first one (which is the last one found by the loop).
    double bs1_price_c7 = NormalizeDouble(bid + test_grid.unit * 0.6, _Digits); // This one is found first by loop
    double bs2_price_c7 = NormalizeDouble(bid + test_grid.unit * 0.5, _Digits); // This one is found LAST by loop, triggers IsRecoveryGap
    if(trade.BuyStop(volume_min, bs1_price_c7, symbol, 0,0,0,0, EA_TAG + " Recovery node as ORDER_TYPE_BUY_STOP")) Sleep(50);
    if(trade.BuyStop(volume_min, bs2_price_c7, symbol, 0,0,0,0, EA_TAG + " Recovery node as ORDER_TYPE_BUY_STOP")) Sleep(50);

    Assert(IsRecoveryGap(test_grid), "Multiple Orders After Clear: IsRecoveryGap True Setup Correct"); // Based on bs2_price_c7
    Assert(SymbolOrdersTotal() == 2, "Multiple Orders After Clear: Setup has 2 orders");

    HandleGridGap(test_grid, test_base, trade); // Pass global 'trade'. ClearContinuationNodes won't remove these.
    Sleep(200);
    // SymbolOrdersTotal() will still be 2 after ClearContinuationNodes, triggering the `if (SymbolOrdersTotal() > 1) return;` check.
    Assert(SymbolOrdersTotal() == 2, "Multiple Orders After Clear: No new node placed, original 2 remain");
    CleanupCurrentSymbol(trade);
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("--- Starting GridManager.mqh Tests ---");

    // --- Sanity Checks ---
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("ERROR: Automated trading is not enabled.");
        return;
    }
    if (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
    {
        Print("WARNING: Running tests on a REAL account!");
        ExpertRemove();
        return;
    }
    if (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED)
    {
        Print("ERROR: Current symbol (", _Symbol, ") is not tradable.");
        return;
    }
    if (SymbolInfoDouble(_Symbol, SYMBOL_POINT) == 0)
    {
        PrintFormat("WARNING: Symbol %s SYMBOL_POINT is 0. Using fallback.", _Symbol);
    }

    // --- Initialize CTrade ---
    trade.SetTypeFillingBySymbol(_Symbol);
    trade.SetDeviationInPoints(EA_DEVIATION);
    trade.SetAsyncMode(false); // Synchronous trading for tests

    // --- Run Test Suites ---
    Test_IsRecoveryGap_Functionality();
    Test_HandleNewPosition_Functionality();
    Test_HandleGridGap_Functionality();

    // --- Test Summary ---
    Print("--- GridManager.mqh Test Summary ---");
    PrintFormat("Total Tests: %d", tests_passed + tests_failed);
    PrintFormat("Tests Passed: %d", tests_passed);
    PrintFormat("Tests Failed: %d", tests_failed);
    Print("--- Testing Finished ---\n");

    CleanupCurrentSymbol(trade);
}
//+------------------------------------------------------------------+