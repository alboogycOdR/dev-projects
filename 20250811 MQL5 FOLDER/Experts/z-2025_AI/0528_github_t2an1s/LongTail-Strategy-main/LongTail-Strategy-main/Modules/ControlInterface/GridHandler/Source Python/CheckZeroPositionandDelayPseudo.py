
'''
//manages all delay

void check_zero_position()
{
    // reason1: a position just closed within trading time leaving a delay
    // reason2: outside trading time
    // reason3: fatal error, unforeseen event, log status

    if (PositionSelect(_Symbol)) return;

    if (use_daily_session) post_session_clean_up();

    check_range_delay();
}

void post_session_clean_up()
{
    if end_session == false or theres open position: return

    if there is one orders:
        get the pending order details
        if price is far from the order(relative to grid_size + grid_spread * 2), delete the order, log

}
'''

'''
// !function is trusted to understand why theres are tickets on the chart

// Goal: To set up range delay
// Description: 
//  When a range delay occurs, there will be two orders(or one outside daily session); 
//  the lagging continuation order and a recovery buy stop, initially.
//  We want to replace the continuation order with a recovery sell stop.
//  The last trade was sell and we're working on a buy stop;
//  the buy stop should have been opened but it was delayed.

def check_range_delay():
    get no of tickets
    if theres an open position or no ticket: return //not a delay

    if last position was buy: return // to confirm its not a buy side continuation delay
    
    if no of ticket ==2 // continuation stop is present
        if distance between two ticket is <= than grid_size + grid_spread*2: return//range delay is already set

        if current price greater than half the the distance:// confirm its not a sell side continuation delay
            delete continuation sell stop
            get buy stop ticket
            call recovery on the buy stop //places a sell recovery order
    else if no of ticket ==1 // outside trading session
        call post_session_clean_up
        get buy stop ticket else return
        call recovery on the buy stop //places a sell recovery order
    else call mismanagement

'''