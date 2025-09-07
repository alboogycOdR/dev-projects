import socket
import json
import threading
import os
import joblib
import numpy as np

# The ai_server.py has been completely transformed from a simulated prompt engineer to a production-ready ML inference engine. The DeepSeek API and prompt logic have been removed entirely.
# Key Upgrades:
# Model Loading (load_model):
# The server now loads a pre-trained model file (forex_scalp_model.pkl) into memory upon startup using joblib.
# It will exit immediately with a FATAL ERROR if the model file cannot be found, preventing it from running in a non-functional state.
# get_ai_decision Function Overhaul:
# Removed: All code related to DeepSeek API, prompt engineering, and the old simulation block.
# Feature Extraction: The function now expects a JSON object containing the feature vector from the AI_Scalper_EA_v2.1.mq5 client. It uses the FEATURE_ORDER list to construct a numpy array in the precise order the model requires. This is the most critical integration point.
# ML Inference: It calls SCALP_MODEL.predict_proba() to get real-time confidence scores for BUY and SELL signals. This is an extremely fast, local operation.
# Confidence Threshold: A trade is only considered if the model's confidence (prob_buy or prob_sell) exceeds the CONFIDENCE_THRESHOLD. This is our primary filter for trade quality.
# Dynamic Risk Calculation: The dynamic SL/TP calculation from the previous simulation has been retained and improved. It now uses the volatility_atr value provided directly from MQL5 to set the stop loss, and the take profit is calculated based on the RISK_REWARD_RATIO.


# --- ML Model Configuration ---
# The path to the serialized, trained machine learning model file.
MODEL_FILE_PATH = 'forex_scalp_model.pkl'

# CRITICAL: This list defines the exact order of features the model was trained on.
# The MQL5 client must send the JSON with these exact keys.
FEATURE_ORDER = [
    'volatility_atr',
    'momentum_rsi',
    'momentum_stoch_k',
    'momentum_stoch_d',
    'price_action_body_ratio',
    'relative_price_dist_ema20',
    'relative_volume',
    'proximity_to_daily_high',
    'proximity_to_daily_low'
]

# --- Trading Logic Configuration ---
# The confidence threshold required to place a trade. 0.75 means the model must be 75%+ confident.
CONFIDENCE_THRESHOLD = 0.75
# The Risk:Reward ratio for setting the Take Profit based on the Stop Loss distance. 0.8 means TP is 80% of SL distance.
RISK_REWARD_RATIO = 0.8
# The multiplier for the ATR value to set the Stop Loss distance. 1.5 means 1.5 * ATR value.
SL_ATR_MULTIPLIER = 1.5

# --- AI Server Configuration ---
HOST = '0.0.0.0'
PORT = 5555

# Global variable to hold the loaded model.
SCALP_MODEL = None

def load_model():
    """
    Loads the trained machine learning model from the .pkl file into memory.
    This function is called once when the server starts.
    """
    global SCALP_MODEL
    try:
        SCALP_MODEL = joblib.load(MODEL_FILE_PATH)
        print(f"Successfully loaded ML model from {MODEL_FILE_PATH}")
        print(f"Model Class: {type(SCALP_MODEL)}")
    except FileNotFoundError:
        print(f"FATAL ERROR: Model file not found at '{MODEL_FILE_PATH}'")
        print("The AI server cannot function without the model. Please train a model and place it in the correct path.")
        exit() # Exit the script if the model can't be found.
    except Exception as e:
        print(f"FATAL ERROR: An error occurred while loading the model: {e}")
        exit()

def get_ai_decision(market_data):
    """
    Analyzes market data using the loaded ML model to generate a trading decision.
    This function performs high-speed, local inference.
    """
    # Define a default HOLD signal to return on any failure or low confidence.
    hold_signal = json.dumps({"signal": "HOLD", "entry": 0.0, "sl": 0.0, "tp": 0.0})

    if SCALP_MODEL is None:
        print("ERROR: Model is not loaded. Returning HOLD.")
        return hold_signal

    try:
        # --- 1. Feature Vector Creation ---
        # Create a list of feature values in the exact order the model expects.
        feature_vector = [market_data.get(feature, 0) for feature in FEATURE_ORDER]
        print(f"Received Feature Vector: {feature_vector}")

        # --- 2. Prediction (Inference) ---
        # Convert the list to a NumPy array and reshape it for a single prediction.
        features_np = np.array(feature_vector).reshape(1, -1)
        # Get the probabilities for each class (0 = SELL, 1 = BUY)
        probabilities = SCALP_MODEL.predict_proba(features_np)[0]
        prob_sell, prob_buy = probabilities[0], probabilities[1]
        print(f"Model Confidence -> SELL: {prob_sell:.4f}, BUY: {prob_buy:.4f}")

        # --- 3. Confidence Check ---
        # Determine the signal based on the confidence threshold.
        signal = "HOLD"
        if prob_buy > CONFIDENCE_THRESHOLD:
            signal = "BUY"
        elif prob_sell > CONFIDENCE_THRESHOLD:
            signal = "SELL"

        if signal == "HOLD":
            return hold_signal

        # --- 4. Dynamic Stop-Loss & Take-Profit Calculation ---
        # Use the features sent from MQL5 to calculate precise SL/TP.
        current_price = market_data['current_price']
        volatility_atr = market_data['volatility_atr']
        pip_value = 0.0001 # This should be dynamic for non-forex pairs if needed

        # Calculate SL based on current volatility (ATR).
        sl_distance_pips = volatility_atr * SL_ATR_MULTIPLIER
        sl_distance_price = sl_distance_pips * pip_value

        # Calculate TP based on the SL distance and a fixed Risk:Reward ratio.
        tp_distance_price = sl_distance_price * RISK_REWARD_RATIO

        # --- 5. Response Formatting ---
        # Construct the final trade signal JSON.
        if signal == "BUY":
            trade_signal = {
                "signal": "BUY",
                "entry": current_price,
                "sl": round(current_price - sl_distance_price, 5),
                "tp": round(current_price + tp_distance_price, 5)
            }
        else: # signal == "SELL"
            trade_signal = {
                "signal": "SELL",
                "entry": current_price,
                "sl": round(current_price + sl_distance_price, 5),
                "tp": round(current_price - tp_distance_price, 5)
            }

        return json.dumps(trade_signal)

    except KeyError as e:
        print(f"ERROR: Missing a key in the received market data: {e}")
        return hold_signal
    except Exception as e:
        print(f"An error occurred during AI decision making: {e}")
        return hold_signal

def handle_client(client_socket):
    # This function remains largely the same as it's the transport layer.
    try:
        while True:
            # Increased buffer size to handle potentially large historical data in future versions
            data = client_socket.recv(8192)
            if not data:
                print("Client disconnected.")
                break
            received_data = data.decode('utf-8')
            # Uncomment for intense debugging to see raw incoming payload
            # print(f"Received from MQL5: {received_data}")
            try:
                market_data = json.loads(received_data)
                ai_response = get_ai_decision(market_data)
                client_socket.sendall(ai_response.encode('utf-8'))
                print(f"Sent to MQL5: {ai_response}")
            except json.JSONDecodeError:
                print("Error: Invalid JSON received from client.")
                client_socket.sendall(b'{"signal": "HOLD", "error": "Invalid JSON"}')
    except ConnectionResetError:
        print("Client connection reset.")
    except Exception as e:
        print(f"An error occurred in the client handler: {e}")
    finally:
        client_socket.close()

def start_server():
    # This function remains the same.
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((HOST, PORT))
    server_socket.listen(5)
    print(f"AI Server listening on {HOST}:{PORT}")

    while True:
        client_socket, addr = server_socket.accept()
        print(f"Accepted connection from {addr[0]}:{addr[1]}")
        client_handler = threading.Thread(target=handle_client, args=(client_socket,))
        client_handler.start()

if __name__ == "__main__":
    print("--- Starting AI Scalping Server v2.1 ---")
    # 1. Load the trained model into memory *before* starting the server.
    load_model()
    # 2. Start the server to listen for requests from MQL5.
    start_server()