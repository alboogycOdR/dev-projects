# Requirements (Modules)

### Daily sessions management(CORE) ☑️☑️
```
if Outside trading time:
    EndSession = True
    delete non recovery orders
    return 
else:
    EndSession = False

    if an order or a position is on the chart:
        #a progression cycle is still running
        return
    else:
        open a short position at market price
        
```

### New position management(logic)☑️☑️
```
saved ticket = 0 #default
def check new position():
    if position is open
        get open positions ticket
        if saved ticket ≠ open positions ticket:
            call set exits
            
            delete all pending orders.
            
            call recovery.
            
            call continuation if not endsession.
            
            update stored ticket to open ticket
```

### Inadvertent event management(logic)☑️
```
if there are more than one positions

    raise fatal error, close bot. log event.

if there are more that two orders:

    raise fatal error, close bot. log event.
```

### Zero position management(logic) ☑️

*manages all delay*

reasons: outside trading time, a position just closed leaving a delay, fatal error(unforeseen)
```
if there are no open positions:

    # reason : a position just closed within trading time leaving a delay
    if there are two tickets: # theres a delay 

        call range delay management

        return
    # reason: outside trading time
    if use_daily_session and EndSession: 

        # reset relevant params, currently none
        if theres a ticket:
            Delete any order whose comment does not contain 'recovery', log what you deleted
        
            call range delay management
        
        return
    # reason: fatal error,unforeseen event
    else: fatal error log current terminal status #number of open positions etc. for journaling
```

### Range delay management(logic)☑️
→To set up range delay

### Exit management(called)☑️☑️
→Sets take profit and stop loss on an open position
```
def set exits(position ticket, grid_size, reward multiplier)
    get ticket details

    determine tp and sl

    modify open position
```

### Recovery management(called) ☑️☑️

→places one order *(opposite of the reference ticket type)*
```
def place recovery order(reference ticket)

    if ticket is open:
        get ticket detail
        check if stop loss present
        
        order lot = next term of the sequence, relative to the reference(currently open) ticket
    
    else if ticket is a buy stop:
    
        order lot = reference ticket lot
    
    else: fatal error(unforeseen), return
    
    place pending order of type opposite to the ticket type
```
---

**buy stop as recovery position:** recovery buy stops are placed grid_spread higher than the short position’s stop loss.

**sell stop as recovery order:** recovery sell stops are placed on the stop loss of a long position or a buy stop (range delay)

### Continuation management(called) ☑️☑️

→*places one order (continuation order) relative to open positions, during trading time*
```
def place continuation order(reference ticket)

    if EndSession: return
    
    if ticket is still open:
        get ticket details
        check if take profit is set

        get lot size as first term of the progression sequence
        
        check if order already exists
        place a stop order similar to the open position’s type
    
    else: fatal error
```
---

**buy stop as continuation position:** continuation buy stops are placed grid_spread higher than the long position’s take profit.

**sell stop as continuation order:** continuation sell stops are placed on the take profit of a short position.

### Sequence builder(called) ☑️☑️
```
def Initialize progression sequence(reward multiplier)

- Ensure lot sizes(lot progression sequence) are accurate
- relative to account balance 🏁 (not yet, we use symbol minimum volume)

return an array with progression sequence.
```

---

## Utility functions

- Rules enforcer utils
- delete all pending orders, if there are orders.
- fatal error(error location, error message). removes bot and reports event.
- XXX

## Report Modules
#### Logger

#### Telegram reporter