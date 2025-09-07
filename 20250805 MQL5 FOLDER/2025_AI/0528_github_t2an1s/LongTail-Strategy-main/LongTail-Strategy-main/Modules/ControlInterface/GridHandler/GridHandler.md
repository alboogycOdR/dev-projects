
This worker module handles placing and moving grid nodes

- PlaceGridNodes
   - **PlaceContinuationNode** - Places a continuation stop on a reference ticket(live position).
   - **PlaceRecoveryNode** - Places a recovery stop on a reference ticket(live position or buy stop ticket).

- GridHandler
   - HandleNewPosition- handle a new base after a new position has been confirmed.
      - Updates Base object
      - Sets SL and TP
      - Clears all pending orders
      - Places new nodes
   - HandleGridGap- Handles event GridGap
      - Checks if theres a grid gap event.