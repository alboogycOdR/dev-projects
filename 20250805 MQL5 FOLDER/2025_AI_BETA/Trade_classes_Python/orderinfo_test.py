import MetaTrader5 as mt5
from Trade.OrderInfo import COrderInfo

if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      
      
# Get all orders from MT5
orders = mt5.orders_get()

# Loop and print info
m_order = COrderInfo()

for i, order in enumerate(orders):
    if m_order.select_order(order=order):
        print(f"""
Order #{i}

--- Integer & datetime type properties ---

Ticket: {m_order.ticket()}
Type Time: {m_order.type_time()} ({m_order.type_time_description()})
Time Setup: {m_order.time_setup()}
Time Setup (ms): {m_order.time_setup_msc()}
State: {m_order.state()} ({m_order.state_description()})
Order Type: {m_order.order_type()} ({m_order.order_type_description()})
Magic Number: {m_order.magic()}
Position ID: {m_order.position_id()}
Type Filling: {m_order.type_filling()} ({m_order.type_filling_description()})
Time Done: {m_order.time_done()}
Time Done (ms): {m_order.time_done_msc()}
Time Expiration: {m_order.time_expiration()}
External ID: {m_order.external_id()}

--- Double type properties ---

Volume Initial: {m_order.volume_initial()}
Volume Current: {m_order.volume_current()}
Price Open: {m_order.price_open()}
Price Current: {m_order.price_current()}
Stop Loss: {m_order.stop_loss()}
Take Profit: {m_order.take_profit()}
Price StopLimit: {m_order.price_stop_limit()}

--- Text type properties ---

Comment: {m_order.comment()}
Symbol: {m_order.symbol()}

""")


mt5.shutdown()