import MetaTrader5 as mt5
from Trade.HistoryOrderInfo import CHistoryOrderInfo
from datetime import datetime, timedelta

if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      

# The date range

from_date = datetime.now() - timedelta(hours=24)
to_date = datetime.now()

# Get history orders

history_orders = mt5.history_orders_get(from_date, to_date)

if history_orders == None:
    print(f"No deals, error code={mt5.last_error()}")
    exit()
    
# m_order instance
m_order = CHistoryOrderInfo()

# Loop and print each order
for i, order in enumerate(history_orders):
    if m_order.select_order(order):
        print(f"""
History Order #{i}

--- Integer, Datetime & String type properties ---

Time Setup: {m_order.time_setup()}
Time Setup (ms): {m_order.time_setup_msc()}
Time Done: {m_order.time_done()}
Time Done (ms): {m_order.time_done_msc()}
Magic Number: {m_order.magic()}
Ticket: {m_order.ticket()}
Order Type: {m_order.order_type()} ({m_order.type_description()})
Order State: {m_order.state()} ({m_order.state_description()})
Expiration Time: {m_order.time_expiration()}
Filling Type: {m_order.type_filling()} ({m_order.type_filling_description()})
Time Type: {m_order.type_time()} ({m_order.type_time_description()})
Position ID: {m_order.position_id()}
Position By ID: {m_order.position_by_id()}

--- Double type properties ---

Volume Initial: {m_order.volume_initial()}
Volume Current: {m_order.volume_current()}
Price Open: {m_order.price_open()}
Price Current: {m_order.price_current()}
Stop Loss: {m_order.stop_loss()}
Take Profit: {m_order.take_profit()}
Price Stop Limit: {m_order.price_stop_limit()}

--- Access to text properties ---

Symbol: {m_order.symbol()}
Comment: {m_order.comment()}
""")


mt5.shutdown()