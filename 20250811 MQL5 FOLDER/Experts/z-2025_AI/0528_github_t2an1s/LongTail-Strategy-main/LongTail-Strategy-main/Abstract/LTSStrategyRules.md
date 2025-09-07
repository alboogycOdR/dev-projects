# Long Tail Scalper Strategy
## Rules
<!-- General -->
1. EA only acts on the chart **symbol** it is attached to.
2. EA would not start if there is a foriegn order/position on the chart. <!-- only in production -->
3. EA corrects user interference
4. Maximum one position must be open at a time.
5. Maximum two orders must be pending at a time. In the case of one pending order, order must be a recovery node
6. All open positions must have exits(TP/SL).
7. No buy stop should be placed at the price of the last
<!-- Sessions -->
8. User may chose to use daily sessions or not. (Start/Stop EA at a particular time)
9. All sessions starts with a short position.
10. Continuation node must never be placed outside session
11. After a trading session, progression cycles are handled (TP/SL is set and recovery is set) regardless of EndSession status
    - At the end of the progresion cycle, all orders must be cleared. Prevent forgoten **recovery** node.
<!-- Grid & Grid Nodes -->
12. Grid consists of a Base and 2 Nodes.
13. Grid Base is the current location of the grid. it is the currently open position.
14. Grid Nodes are pending orders.
15. There are two types of nodes(orders), Recovery nodes and Continuation nodes.
16. Recovery node can only placed on an open position or a pending order, if it doesn't already exist.
<!-- Progression sequence -->
17. EA adjusts node volumes based on a defined progression sequence
18. EA ensures the sequence is accurate, relative to the account balance and all node volumes are picked(fetched) corectly.

<!-- Implementation-->
### Implementation Constraints
- EA must never delete either Exit (TakeProfit/StopLoss).
- EA deletes all pending orders when a new position is opened, and places relevant orders.
- EA places all buy stops(continuation or recovery) grid.spread higher than target to ensure full profit is realised and avoid price range trap.
- EA replaces lagging continuation node with recovery node when a price range trap is detected.
- EA loggs unforeseen events as FATAL error.


(!) Refer to documentation for defination of terms