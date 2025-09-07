# Semi-Automated Economic News Trading System

## Description

This project implements a semi-automated trading system designed to trade around high-impact economic events using data from the Trading Economics economic calendar. It allows users to automatically scrape and filter upcoming macroeconomic releases, manually input trading decisions for selected events via a GUI, and execute trades through MetaTrader 5 based on those inputs.

The architecture bridges **Python** (for data scraping and preprocessing) and **MetaTrader 5 (MQL5)** (for graphical interaction and execution logic), enabling real-time event-driven trading workflows.

---

## Key Features

1. **Automated Data Acquisition**
   - Scrapes economic calendar data from Trading Economics via Python.
   - Includes event name, datetime, country, importance, and URLs.
   - Filters only high-relevance events within a chosen date range.

2. **Manual Trading Decision Input**
   - Launches a graphical interface (Python) displaying the filtered events.
   - Allows the user to manually assign an expected impact/direction (e.g., BUY, SELL, WAIT).
   - Saves the selected events and user decisions into a structured file.

3. **MetaTrader 5 Integration**
   - Loads the selected events in MQL5.
   - Displays event-related metadata directly on the trading chart.
   - Facilitates semi-automated execution logic based on user-inputted direction.

4. **Custom Event Handling**
   - The system supports real-time reaction to macro events based on user-validated signals.
   - Ensures trader remains in control while automating the repetitive steps.

---

## File Structure

### 🐍 Python Scripts

- **`Scraping-Trading_Economics-1.3.py`**  
  - Scrapes and filters economic calendar events from TradingEconomics.  
  - Exports structured data to a CSV or JSON file.  

- **`Scraping_Trading_Economics_Header.py`**  
  - Utility script that defines headers and functions for data formatting and export.

### 📊 MetaTrader 5 Scripts

- **`CalendarTrading-V0.6.2.mq5`**  
  - Main MQL5 script for event handling and chart-based execution.  
  - Loads filtered economic events and user decisions.  
  - Draws event markers and initiates semi-automated order logic.  

- **`header-CalendarTrading-V0.6.2.mqh`**  
  - Header file with data structures, constants, and helper functions for processing event data.

---

## Workflow

1. **Scrape and Filter Events (Python)**  
   ```bash
   python Scraping-Trading_Economics-1.3.py
   ```
   - Launches a GUI.
   - Select events of interest and assign a trading direction.
   - Saves the result to a file (e.g., `filtered_events.csv`).

2. **Load in MetaTrader 5 (MQL5)**
   - Copy the `.mq5` and `.mqh` files to your MT5 terminal.
   - Attach `CalendarTrading-V0.6.2.mq5` to a chart.
   - The script reads the events file and displays instructions on screen.

3. **Execute Semi-Automated Trades**
   - The script uses time-based triggers to monitor and react to upcoming events.
   - Based on user-defined inputs, it prepares trade logic (entry, direction, etc.).
   - The final trade execution may still require manual confirmation, ensuring control.

---

## Requirements

### Python (3.8+)
- `tkinter` (for GUI)
- `requests`, `bs4` (for web scraping)
- `pandas`, `datetime`, `json`

### MetaTrader 5
- MQL5-compatible terminal (tested on Windows)
- Access to trading account and charts

---

## Limitations

- Trading direction must be input manually before the news event.
- Not fully autonomous — designed for semi-discretionary trading workflows.
- Requires periodic manual launching of the Python scraping tool.

---

## Future Improvements

- Auto-sync between Python and MT5 without manual file exchange.
- Historical backtesting of news impact strategies.
- Integration of AI-based sentiment analysis or economic forecast engines.
