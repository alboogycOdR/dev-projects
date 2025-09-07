# ML Scalping System: User Guide and Documentation

## 1. Introduction

This document serves as a comprehensive user guide and technical documentation for the ML Scalping system. This system is designed to automate scalping strategies by leveraging Smart Money Concepts (SMC) and Candle Range Theory (CRT) for pattern identification and confirmation, integrated with MetaTrader 5 (MT5) for real-time data and trade execution.

## 2. System Overview and Architecture

The ML Scalping system is composed of two primary, interconnected modules:

*   **Python-based Machine Learning and Signal Generation Module:** This module is the core intelligence of the system, responsible for processing market data, identifying SMC and CRT patterns, applying machine learning models for pattern confirmation, and generating trading signals.
*   **MQ5-based Data Feed and Trade Execution Module:** This module, implemented as an Expert Advisor (EA) in MetaTrader 5, handles real-time market data acquisition from the MT5 terminal and executes trading signals received from the Python module.

Communication between these two modules is facilitated using **ZeroMQ (ZMQ)**, a high-performance asynchronous messaging library, ensuring low-latency and efficient data exchange.

### 2.1. Data Flow Diagram

```mermaid
graph TD
    MQ5_Terminal[MT5 Terminal] -->|Real-time Data (Bars/Ticks)| MQ5_EA(MQ5 Expert Advisor)
    MQ5_EA -->|ZeroMQ (Pub/Sub)| Python_Module(Python ML & Signal Generation Module)
    Python_Module -->|ZeroMQ (Req/Rep)| MQ5_EA
    MQ5_EA -->|Trade Execution| MQ5_Terminal
    Python_Module -->|Historical Data| Data_Storage[Data Storage (e.g., CSV/DB)]
    Data_Storage -->|Historical Data| Python_Module
    Python_Module -->|ML Model Training| ML_Model[ML Model]
    ML_Model -->|Pattern Confirmation & Signal Generation| Python_Module
```

### 2.2. Technology Stack

*   **MQ5:** MQL5 (for Expert Advisor)
*   **Python:** Python 3.x
    *   **Data Manipulation:** Pandas, NumPy
    *   **Machine Learning:** Scikit-learn (RandomForestClassifier)
    *   **Communication:** PyZMQ
*   **Communication Protocol:** ZeroMQ (ZMQ)

## 3. Installation and Setup

To get the ML Scalping system up and running, follow these steps carefully:

### 3.1. Prerequisites

Ensure you have the following installed and configured:

*   **MetaTrader 5 (MT5) Terminal:** Installed and running on a Windows machine. This is where your trading account is managed and trades are executed.
*   **Python 3.x:** Installed on your operating system (Windows, macOS, or Linux). It is highly recommended to use a virtual environment to manage dependencies.
*   **ZeroMQ Library for MQL5:** This is a crucial component for communication between MT5 and Python. You will need to download it and place it in your MT5 `MQL5/Include/ZeroMQ/` directory. If you don't have it, search for "MQL5 ZeroMQ library" on the MQL5.community website or GitHub.

### 3.2. Python Setup

1.  **Create a Project Directory:** Choose a suitable location on your computer and create a new directory for this project. For example, `C:\Users\YourUser\Documents\ML_Scalping_System` on Windows, or `/home/youruser/ML_Scalping_System` on Linux/macOS.

2.  **Save Python Files:** Copy the following Python files into your newly created project directory:
    *   `trading_logic.py`: Contains the core logic for SMC/CRT pattern identification, feature engineering, and the machine learning model.
    *   `zmq_client.py`: This is the main Python script that communicates with the MT5 EA, receives data, processes it, generates signals, and sends them back to MT5.

    You can find the content of these files in the previous messages or directly from the sandbox environment if you have access to `/home/ubuntu/trading_logic.py` and `/home/ubuntu/zmq_client.py`.

3.  **Install Python Dependencies:** Open a terminal or command prompt, navigate to your project directory (e.g., `cd C:\Users\YourUser\Documents\ML_Scalping_System`), and run the following command to install all necessary Python libraries:
    ```bash
    pip install pandas scikit-learn pyzmq
    ```
    This command will install `pandas` for data manipulation, `scikit-learn` for machine learning algorithms, and `pyzmq` for ZeroMQ communication.

### 3.3. MetaTrader 5 (MQ5) Setup

1.  **Enable DLL Imports:** For the ZeroMQ communication to function correctly, you must enable DLL imports in your MT5 terminal. Open MT5, go to `Tools -> Options`, navigate to the `Expert Advisors` tab, and ensure the checkbox next to "Allow DLL imports" is ticked. Click "OK" to save the changes.

2.  **Place MQL5 Expert Advisor:** Copy the `MQL5_ZeroMQ_EA.mq5` file (which was provided to you previously) into your MT5 installation directory, specifically in the `MQL5/Experts/` folder. For example, `C:\Program Files\MetaTrader 5\MQL5\Experts\MQL5_ZeroMQ_EA.mq5`.

3.  **Compile MQL5_ZeroMQ_EA.mq5:**
    *   Open MetaEditor. You can launch it directly from your MT5 terminal by going to `Tools -> MetaQuotes Language Editor` or by pressing F4.
    *   In MetaEditor, open the `MQL5_ZeroMQ_EA.mq5` file from the `MQL5/Experts/` folder.
    *   Click the "Compile" button (or press F7) in the MetaEditor toolbar. You should see a message in the "Errors" tab indicating "0 errors, 0 warnings" if the compilation is successful. If you encounter errors, especially those related to `ZeroMQ.mqh`, double-check that the ZeroMQ library for MQL5 is correctly placed in `MQL5/Include/ZeroMQ/`.

4.  **Attach EA to a Chart:**
    *   In your MT5 terminal, open a new chart for the specific trading instrument and timeframe you wish to trade (e.g., XAUUSD M1, BTCUSD M5, EURUSD M15). The system is designed for 1-minute, 5-minute, and 15-minute timeframes for Gold, BTCUSD, EURUSD, GBPUSD, and Nasdaq.
    *   From the "Navigator" window (you can open it by pressing Ctrl+N), expand the "Expert Advisors" section. You should find `MQL5_ZeroMQ_EA` listed there.
    *   Drag and drop `MQL5_ZeroMQ_EA` onto the desired chart.
    *   A settings window for the Expert Advisor will appear:
        *   Go to the "Inputs" tab.
        *   Set `DataPort` to `5556`. This is the port the EA will use to publish market data to Python.
        *   Set `SignalPort` to `5557`. This is the port the EA will listen on for trading signals from Python.
        *   Set `SymbolToTrade` to the exact symbol name of the chart you attached the EA to (e.g., `XAUUSD`, `BTCUSD`, `EURUSD`, `GBPUSD`, `NAS100`). **Ensure this matches exactly, including case.**
        *   Set `Timeframe` to match the chart's timeframe (e.g., `PERIOD_M1` for 1-minute, `PERIOD_M5` for 5-minute, `PERIOD_M15` for 15-minute). **This is crucial for the EA to send the correct bar data to Python.**
        *   Go to the "Common" tab and ensure "Allow Algo Trading" is checked. This permits the EA to execute trades.
        *   Click "OK" to close the settings window and attach the EA.

    Upon successful attachment and configuration, you should see a "happy smiley face" icon in the top right corner of the chart, indicating that the Expert Advisor is running correctly.

## 4. Running the System

Once both the Python and MT5 environments are set up, you can start the system:

1.  **Start the MQ5 Expert Advisor:** Ensure the `MQL5_ZeroMQ_EA` is running on your MT5 chart as described in Section 3.4. Verify the smiley face icon is present.

2.  **Run the Python Client:** Open a terminal or command prompt, navigate to your `ml_scalping_system` project directory, and execute the Python ZeroMQ client script:
    ```bash
    python zmq_client.py
    ```

    You should immediately start seeing output in your Python terminal. This output will show data being received from MT5, messages about the ML model training (after enough data is collected), and generated trading signals. Simultaneously, the "Experts" tab in your MT5 terminal should display messages confirming data publication and signal reception/execution.

## 5. Understanding the Python Code (`trading_logic.py`)

`trading_logic.py` is the core of the ML intelligence. It performs the following key functions:

*   **`identify_smc_patterns(data)`:** This function identifies various Smart Money Concepts (SMC) patterns within the provided candlestick data. It includes simplified implementations for:
    *   **Break of Structure (BOS):** Indicates a continuation of the trend.
    *   **Change of Character (ChoCH):** Suggests a potential reversal in market direction.
    *   **Order Blocks:** Represents areas of concentrated institutional orders.
    *   **Fair Value Gaps (FVG):** Identifies market imbalances where price moved quickly in one direction.

*   **`identify_crt_patterns(data)`:** This function identifies Candle Range Theory (CRT) patterns. It looks for instances where price raids the high or low of a previous candle and then moves in the opposite direction, indicating liquidity grabs.

*   **`feature_engineering(data)`:** This function takes the raw candlestick data and transforms it into features suitable for the machine learning model. It calls `identify_smc_patterns` and `identify_crt_patterns` to add pattern-based features. Additionally, it includes basic technical indicators like Relative Strength Index (RSI) and Moving Average Convergence Divergence (MACD) as features. A simplified `target` variable is also created for training purposes, indicating if the price moved up in the next 5 bars.

*   **`train_ml_model(data)`:** This function trains a `RandomForestClassifier` model. It uses the engineered features and the target variable to learn the relationship between patterns/indicators and future price movement. The model's accuracy on a test set is printed to the console.

*   **`get_trading_signal(data, model)`:** This function takes the latest processed market data and the trained ML model to generate a trading signal (`BUY`, `SELL`, or `HOLD`). It uses the model's prediction and prediction probability to determine a high-confidence signal.

## 6. Important Considerations and Customization

*   **ZeroMQ Library for MQL5:** The successful operation of this system heavily relies on the correct installation of the ZeroMQ library for MQL5. Ensure it's in the correct `MQL5/Include/ZeroMQ/` path and that DLL imports are enabled in MT5.
*   **ML Model Refinement:** The provided `train_ml_model` and `get_trading_signal` functions are starting points. For optimal performance, you will need to:
    *   **Collect More Data:** Train the model on a significantly larger and more diverse historical dataset. The more relevant data the model sees, the better it will learn.
    *   **Feature Engineering:** Experiment with additional features, including more sophisticated SMC/CRT pattern detection, volume analysis, and other technical indicators.
    *   **Target Variable Definition:** The current target variable is a simple example. For scalping, you might define a target based on a small profit target within a few bars, or a more complex risk-reward ratio.
    *   **Model Selection and Hyperparameter Tuning:** Explore other machine learning models (e.g., Gradient Boosting, Neural Networks) and fine-tune their hyperparameters for your specific trading style and market conditions.
    *   **Overfitting:** Be mindful of overfitting, especially with scalping strategies. Ensure your model generalizes well to unseen data through proper validation techniques.
*   **Trading Logic and Risk Management:** The `get_trading_signal` function provides a basic BUY/SELL/HOLD signal. You will need to implement comprehensive trading logic within the `MQL5_ZeroMQ_EA.mq5` to handle:
    *   **Entry Conditions:** Precise entry rules based on the Python signal.
    *   **Exit Conditions:** Take-profit and stop-loss levels, potentially dynamic based on market conditions or pattern characteristics.
    *   **Position Sizing:** Determine the appropriate trade volume based on your risk tolerance and account size.
    *   **Slippage and Latency:** Account for potential slippage and network latency, which are critical in scalping.
    *   **Error Handling:** Robust error handling for all trade operations.
*   **Backtesting and Optimization:** Once the system is running, utilize the MetaTrader 5 Strategy Tester for thorough backtesting. This will allow you to evaluate the system's historical performance, identify weaknesses, and optimize parameters. The Python module will receive data from the Strategy Tester just as it would from live market data.
*   **Live Trading:** Before deploying to a live account, rigorously test the system on a demo account. Start with small volumes and gradually increase as you gain confidence in its performance and stability.
*   **Network Configuration:** If your Python script and MT5 terminal are running on different machines, you must adjust the IP addresses in both `zmq_client.py` and `MQL5_ZeroMQ_EA.mq5` to reflect the correct network addresses (e.g., `tcp://<MT5_MACHINE_IP>:5556`).

This documentation provides a solid foundation for your ML Scalping system. Continuous monitoring, testing, and refinement will be key to its long-term success.

