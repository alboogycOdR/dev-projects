
ALL THE CODE THAT ENSURES STRATEGY GUIDELINES ARE ADHERED

This worker module ensures the strategy rules are followed.

- EnforceGridPlacementAccuracy; checks if the grid nodes are in the right price or have been moved(by a user). A small deviation is considered to account for slippage.

- EnforceNoInterference; checks if a user has interfered by opening a position or an order, or moved the exits.

- EnforceCoreRules; corrects execution error. 
    - ensures there are only one positions at a time. deletes excess
    - ensures there are only maximum of two orders at a time. deletes excess
    - If trading session is in use, ensures no lagging order is left after session over and cycle over.

- CheckSLTP; Prints a warning if SL or TP is not placed on an open position

- CheckVolumeAccuracy; checks that base and nodes are correspondent with the current progression sequence. Helps detect mathematical errors.

- CheckSequenceAccuracy; checks that the sequences is initialized accurate to the user account balance. Potentially rebuilds sequence.

---

`Check` functions print warnings.

`Enforce` functions perform correction actions.

---