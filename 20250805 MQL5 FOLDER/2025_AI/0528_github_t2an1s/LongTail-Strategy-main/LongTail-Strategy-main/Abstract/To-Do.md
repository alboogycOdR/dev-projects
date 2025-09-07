# To-Do

### Sequence
- [ ] Re adjust sequence and how it is progressed. Re asses session time management.
- [ ] Confirm all functions take args and not reference global vars, and are passed by reference when updates are needed
- [ ] List all utility func
- [ ] Observe live trading for more unaccounted events.
- [ ] Test without continuation range, it might be unnecessary.
- [ ] Include image description
- [ ] Code for all activities to be logged; position open/close, order open/close, managements and sessions, etc.
- [ ] Handle failed buys, sells, etc
- [ ] Include docstring for all functionalities
- [ ] Include Strategy definition
- [ ] Clean up README, separate pseudo code
- [ ] Allow ea to manage multiple charts by confirming symbol before any operation- CheckRules,
- Script to detect slippages between two 15m candles, price must fill, 1:2 - camera photo on 12 feb.2025
- Confirm short scalps strategy idea - screen shot on 13th feb.2025
---
- All functions should return success or failure. Return Value Checks for Trade Operations:
- Define utility to avoid midnight/weekend skippage

-
// NEW IDEA
// Advantage of quick reactions at value points
// --- anticipate reaction, place stop order with tp only(at minimum stop level)
// --- place 500 order at 1% account_bal