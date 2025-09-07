import socket
import json
import threading
import os

# --- DeepSeek API Configuration (Replace with your actual API Key)
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "YOUR_DEEPSEEK_API_KEY_HERE")
DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions"

# --- AI Server Configuration
HOST = '0.0.0.0'
PORT = 5555

def get_ai_decision(market_data):
    """
    Analyzes market data to generate a trading decision.
    In a real system, this would either call a trained ML model or use
    advanced prompt engineering with an LLM like DeepSeek.
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}"
    }

    # --- Advanced Prompt Engineering ---
    # The prompt is now structured to provide a rich narrative of the market context,
    # as recommended in the review.
    prompt = (
        f"You are a professional forex scalping analyst for {market_data.get('symbol', 'the specified asset')}. "
        f"Analyze the M1 chart based on the following context. Your response must be in JSON format only. "
        f"Provide a 'signal' ('BUY', 'SELL', or 'HOLD'), and precise 'entry', 'sl', and 'tp' prices.\n\n"
        f"**Market Context:**\n"
        f"- **Analysis Timeframe:** 1-Minute\n"
        f"- **Current Price:** {market_data.get('current_price', 'N/A')}\n"
        f"- **Volatility (14-period ATR):** {market_data.get('volatility_atr', 'N/A')} pips\n"
        f"- **Volume Analysis:** The current tick volume is {market_data.get('relative_volume', 'N/A')}% of the 20-period average.\n"
        f"- **Key Level Proximity:**\n"
        f"  - Price is {market_data.get('proximity_to_daily_high', 'N/A')} pips away from the daily high.\n"
        f"  - Price is {market_data.get('proximity_to_daily_low', 'N/A')} pips away from the daily low.\n"
        f"  - Nearest major round number is {market_data.get('nearest_round_number', 'N/A')}.\n\n"
        f"**Recent Price Action (Latest Bar):**\n"
        f"Open={market_data['current_bar']['open']}, High={market_data['current_bar']['high']}, "
        f"Low={market_data['current_bar']['low']}, Close={market_data['current_bar']['close']}, "
        f"TickVolume={market_data['current_bar']['tick_volume']}\n\n"
        f"**Historical Context (Previous 19 Bars):**\n"
        f"{json.dumps(market_data.get('history', []), indent=2)}\n\n"
        f"**Instruction:** Based ONLY on the principles of price action, inferred order flow, and the context provided, "
        f"what is the highest probability scalping trade? Your entire response must be a single, clean JSON object."
    )


    data = {
        "model": "deepseek-chat",
        "messages": [
            {"role": "system", "content": "You are an expert forex scalping AI. Your response must be only a single JSON object with the keys 'signal', 'entry', 'sl', and 'tp'. Do not include any other text, explanations, or markdown formatting."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.5,
        "max_tokens": 200
    }

    try:
        # The real API call to DeepSeek would be here.
        # import requests
        # response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        # response.raise_for_status()
        # ai_output = response.json()['choices'][0]['message']['content']

        # --- SIMULATED AI RESPONSE (ENHANCED) ---
        # This logic is enhanced to use the new features, demonstrating how the
        # richer context can lead to better (though still simulated) decisions.
        current_close = market_data['current_bar']['close']
        volatility = market_data.get('volatility_atr', 10.0) # Default to 10 pips if not provided
        relative_volume = market_data.get('relative_volume', 100.0) # Default to 100%

        # More nuanced simulation
        if relative_volume > 120:  # Only trade on high relative volume
            is_bullish_candle = market_data['current_bar']['close'] > market_data['current_bar']['open']
            # Dynamic SL/TP based on volatility
            sl_pips = volatility * 1.5
            tp_pips = volatility * 0.8
            pip_value = 0.0001 # Assuming standard pip for EURUSD, etc.

            if is_bullish_candle:
                # Add a condition: only buy if not too close to daily high
                if market_data.get('proximity_to_daily_high', 100) > sl_pips:
                    ai_output = json.dumps({
                        "signal": "BUY",
                        "entry": current_close,
                        "sl": round(current_close - sl_pips * pip_value, 5),
                        "tp": round(current_close + tp_pips * pip_value, 5)
                    })
                else:
                    ai_output = json.dumps({"signal": "HOLD", "entry": 0.0, "sl": 0.0, "tp": 0.0})
            else: # Bearish candle
                # Add a condition: only sell if not too close to daily low
                if market_data.get('proximity_to_daily_low', 100) > sl_pips:
                    ai_output = json.dumps({
                        "signal": "SELL",
                        "entry": current_close,
                        "sl": round(current_close + sl_pips * pip_value, 5),
                        "tp": round(current_close - tp_pips * pip_value, 5)
                    })
                else:
                    ai_output = json.dumps({"signal": "HOLD", "entry": 0.0, "sl": 0.0, "tp": 0.0})
        else:
            ai_output = json.dumps({"signal": "HOLD", "entry": 0.0, "sl": 0.0, "tp": 0.0})
        # --- END SIMULATED AI RESPONSE ---

        return ai_output
    except Exception as e:
        print(f"Error getting AI decision: {e}")
        return json.dumps({"signal": "HOLD", "error": str(e)})

def handle_client(client_socket):
    try:
        while True:
            data = client_socket.recv(4096) # Receive up to 4096 bytes
            if not data:
                print("Client disconnected.")
                break

            received_data = data.decode('utf-8')
            print(f"Received from MQL5: {received_data}")

            try:
                market_data = json.loads(received_data)
                ai_response = get_ai_decision(market_data)
                client_socket.sendall(ai_response.encode('utf-8'))
                print(f"Sent to MQL5: {ai_response}")
            except json.JSONDecodeError:
                print("Invalid JSON received.")
                client_socket.sendall(b'{"error": "Invalid JSON"}')
            except Exception as e:
                print(f"Error processing request: {e}")
                client_socket.sendall(json.dumps({"error": str(e)}).encode('utf-8'))

    except Exception as e:
        print(f"Error in client handler: {e}")
    finally:
        client_socket.close()

def start_server():
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
    # Install requests library if not present
    # import subprocess
    # try:
    #     import requests
    # except ImportError:
    #     print("Installing 'requests' library...")
    #     subprocess.check_call([sys.executable, "-m", "pip", "install", "requests"])
    #     import requests

    start_server()


