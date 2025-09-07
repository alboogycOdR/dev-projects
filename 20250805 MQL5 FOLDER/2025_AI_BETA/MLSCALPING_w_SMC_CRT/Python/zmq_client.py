import zmq
import json
import time
import pandas as pd
from trading_logic import feature_engineering, train_ml_model, get_trading_signal

# ZeroMQ Context
context = zmq.Context()

# Socket for receiving data from MQ5 (Subscriber)
data_socket = context.socket(zmq.SUB)
data_socket.connect("tcp://localhost:5556") # MQ5 data publisher address
data_socket.setsockopt_string(zmq.SUBSCRIBE, "") # Subscribe to all topics

# Socket for sending signals to MQ5 (Requester)
signal_socket = context.socket(zmq.REQ)
signal_socket.connect("tcp://localhost:5557") # MQ5 signal replier address

# Global variable to store historical data
historical_data = pd.DataFrame()
ml_model = None

def send_signal_to_mq5(signal_data):
    """Sends a trading signal to MQ5 and waits for a response."""
    print(f"Sending signal to MQ5: {signal_data}")
    signal_socket.send_string(json.dumps(signal_data))
    message = signal_socket.recv_string()
    print(f"Received response from MQ5: {message}")
    return json.loads(message)

if __name__ == "__main__":
    print("Python ZeroMQ Client Started...")

    while True:
        try:
            # Receive data from MQ5
            message = data_socket.recv_string(flags=zmq.NOBLOCK) # Non-blocking receive
            if message:
                print(f"Received data from MQ5: {message}")
                
                # Parse the incoming JSON data
                new_data_json = json.loads(message)
                new_bars = pd.DataFrame(new_data_json["data"])
                new_bars["time"] = pd.to_datetime(new_bars["time"], unit="s") # Assuming Unix timestamp
                new_bars = new_bars.set_index("time")

                global historical_data
                historical_data = pd.concat([historical_data, new_bars]).drop_duplicates().sort_index()

                # Keep only the last N bars for efficiency (e.g., 500 bars)
                historical_data = historical_data.tail(500)

                # Feature Engineering
                processed_data = feature_engineering(historical_data.copy())

                # Train/Retrain ML model periodically or when enough data is available
                global ml_model
                if len(processed_data) > 100 and ml_model is None: # Train only once initially
                    ml_model = train_ml_model(processed_data)
                    print("ML Model trained successfully.")
                elif len(processed_data) > 100 and len(processed_data) % 50 == 0: # Retrain every 50 new bars
                    ml_model = train_ml_model(processed_data)
                    print("ML Model retrained successfully.")

                # Get trading signal if model is trained
                if ml_model is not None:
                    signal = get_trading_signal(processed_data, ml_model)
                    print(f"Generated Trading Signal: {signal}")

                    # Send signal to MQ5
                    if signal != "HOLD":
                        # Customize signal data based on your needs
                        trade_signal = {
                            "action": signal,
                            "symbol": new_data_json["symbol"],
                            "volume": 0.01, # Example volume
                            "price": processed_data["close"].iloc[-1]
                        }
                        response = send_signal_to_mq5(trade_signal)
                        print(f"Signal response: {response}")

        except zmq.Again:
            # No message received yet, continue
            pass
        except Exception as e:
            print(f"An error occurred: {e}")

        time.sleep(0.1) # Short delay to prevent busy-waiting
