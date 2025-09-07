# ML Scalping System: Python and MQ5 Integration Instructions

This document provides instructions for setting up and running the Python ML Scalping system and integrating it with your MetaTrader 5 (MT5) terminal.

## 1. Prerequisites

Before you begin, ensure you have the following:

*   **MetaTrader 5 (MT5) Terminal:** Installed and running on a Windows machine.
*   **Python 3.x:** Installed on your system (preferably a virtual environment).
*   **ZeroMQ Library for MQL5:** Downloaded and placed in your MT5 `MQL5/Include/ZeroMQ/` directory. If you don't have it, search for "MQL5 ZeroMQ library" on MQL5.community or GitHub.

## 2. Python Setup

1.  **Create a Project Directory:** Create a new directory on your system for this project, e.g., `ml_scalping_system`.

2.  **Save Python Files:** Place the following Python files into your `ml_scalping_system` directory:
    *   `trading_logic.py`
    *   `zmq_client.py`

    You can copy the content of these files from the previous messages or from the `/home/ubuntu/` directory in the sandbox.

3.  **Install Python Dependencies:** Open a terminal or command prompt, navigate to your `ml_scalping_system` directory, and install the required Python libraries:
    ```bash
    pip install pandas scikit-learn pyzmq
    ```

## 3. MetaTrader 5 (MQ5) Setup

1.  **Enable DLL Imports:** In your MT5 terminal, go to `Tools -> Options -> Expert Advisors` tab, and ensure the "Allow DLL imports" checkbox is ticked.

2.  **Place MQL5 Expert Advisor:** Save the `MQL5_ZeroMQ_EA.mq5` file (provided previously) into your MT5 `MQL5/Experts/` directory.

3.  **Compile MQL5_ZeroMQ_EA.mq5:**
    *   Open MetaEditor (from your MT5 terminal, go to `Tools -> MetaQuotes Language Editor`).
    *   Open `MQL5_ZeroMQ_EA.mq5` from the `MQL5/Experts/` folder.
    *   Click "Compile" (or press F7). Ensure there are no compilation errors. If there are errors, double-check that `ZeroMQ.mqh` is correctly placed in `MQL5/Include/ZeroMQ/`.

4.  **Attach EA to a Chart:**
    *   In your MT5 terminal, open a new chart for the desired trading instrument (e.g., XAUUSD, BTCUSD, EURUSD, GBPUSD, Nasdaq) and timeframe (M1, M5, M15).
    *   From the "Navigator" window (Ctrl+N), find "Expert Advisors" -> `MQL5_ZeroMQ_EA`.
    *   Drag and drop `MQL5_ZeroMQ_EA` onto the chart.
    *   In the EA settings window:
        *   Go to the "Inputs" tab.
        *   Set `DataPort` to `5556`.
        *   Set `SignalPort` to `5557`.
        *   Set `SymbolToTrade` to the exact symbol name of the chart (e.g., `XAUUSD`, `BTCUSD`).
        *   Set `Timeframe` to match the chart's timeframe (e.g., `PERIOD_M1`, `PERIOD_M5`, `PERIOD_M15`).
        *   Ensure "Allow Algo Trading" is checked.
        *   Click "OK".

    You should see a happy smiley face icon in the top right corner of the chart, indicating the EA is running.

## 4. Running the System

1.  **Start the MQ5 Expert Advisor:** Ensure the `MQL5_ZeroMQ_EA` is running on your MT5 chart as described in Section 3.4.

2.  **Run the Python Client:** Open a terminal or command prompt, navigate to your `ml_scalping_system` directory, and run the Python ZeroMQ client:
    ```bash
    python zmq_client.py
    ```

    You should start seeing output in the Python terminal indicating data being received from MQ5 and potentially trading signals being generated. The MQ5 terminal's Experts tab should also show messages about data being published and signals being received.

## 5. Important Notes

*   **ZeroMQ Library for MQL5:** The `MQL5_ZeroMQ_EA.mq5` file assumes you have the ZeroMQ library for MQL5. This is a separate download and is crucial for the communication to work. If you encounter compilation errors related to `ZeroMQ.mqh`, it means the library is not correctly installed.
*   **Error Handling:** The provided code includes basic error handling. For a production system, more robust error handling, logging, and monitoring would be necessary.
*   **ML Model Training:** The `trading_logic.py` includes a simplified `train_ml_model` function. In a real-world scenario, you would need a more sophisticated approach to data collection, feature engineering, and model training/validation. Consider using a larger historical dataset for training.
*   **Trading Logic:** The `get_trading_signal` function is a basic example. You will need to refine the logic for identifying and confirming SMC/CRT patterns and generating actual trade signals based on your strategy.
*   **Risk Management:** The current system has minimal risk management. Implement proper stop-loss, take-profit, and position sizing based on your risk tolerance.
*   **Network Configuration:** If your MT5 terminal and Python script are on different machines, you will need to adjust the IP addresses in `zmq_client.py` and `MQL5_ZeroMQ_EA.mq5` accordingly (e.g., `tcp://<MT5_IP_ADDRESS>:5556`).

By following these instructions, you should be able to set up and run your ML Scalping system. Remember to continuously test and refine your trading logic and ML model for optimal performance.

