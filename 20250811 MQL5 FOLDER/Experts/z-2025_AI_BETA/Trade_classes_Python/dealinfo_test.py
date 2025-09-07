import MetaTrader5 as mt5
from datetime import datetime, timedelta
from Trade.DealInfo import CDealInfo

# The date range
from_date = datetime.now() - timedelta(hours=24)
to_date = datetime.now()


if not mt5.initialize(r"c:\Users\Omega Joctan\AppData\Roaming\Pepperstone MetaTrader 5\terminal64.exe"):
    print("Failed to initialize Metatrader5 Error = ",mt5.last_error())
    quit()
      
m_deal = CDealInfo()

# Get all deals from MT5 history
deals = mt5.history_deals_get(from_date, to_date)
    
for i, deal in enumerate(deals):
    
    if (m_deal.select_deal(deal=deal)):
        print(f"""
Deal #{i}

--- integer and dateteime properties ---

Ticket: {m_deal.ticket()}
Time: {m_deal.time()}
Time (ms): {m_deal.time_msc()}
Deal Type: {m_deal.deal_type()} ({m_deal.type_description()})
Entry Type: {m_deal.entry()} ({m_deal.entry_description()})
Order: {m_deal.order()}
Magic Number: {m_deal.magic()}
Position ID: {m_deal.position_id()}

--- double type properties ---

Volume: {m_deal.volume()}
Price: {m_deal.price()}
Commission: {m_deal.commission()}
Swap: {m_deal.swap()}
Profit: {m_deal.profit()}

--- string type properties --- 

Comment: {m_deal.comment()}
Symbol: {m_deal.symbol()}

External ID: {m_deal.external_id()}
""")


mt5.shutdown()