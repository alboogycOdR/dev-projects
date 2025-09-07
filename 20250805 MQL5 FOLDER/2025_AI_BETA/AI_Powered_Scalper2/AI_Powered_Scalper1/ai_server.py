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
    Sends market data to DeepSeek API and gets a trading decision.
    This is a simplified example. In a real scenario, you'd have a more sophisticated
    prompt engineering or a dedicated ML model.
    """
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {DEEPSEEK_API_KEY}"
    }

    # Craft a prompt for DeepSeek based on the market data
    # This is a very basic example. For real trading, this prompt needs to be highly refined.
    prompt = f"Analyze the following 1-minute Forex market data for {market_data['symbol']}. " \
             f"Current bar: Open={market_data['current_bar']['open']}, High={market_data['current_bar']['high']}, " \
             f"Low={market_data['current_bar']['low']}, Close={market_data['current_bar']['close']}, " \
             f"TickVolume={market_data['current_bar']['tick_volume']}. " \
             f"Based on raw price action and inferred order flow, suggest a scalping trade (BUY/SELL/HOLD) " \
             f"and provide optimal entry, stop loss (SL), and take profit (TP) levels. " \
             f"Respond in JSON format: {{'signal': 'BUY'|'SELL'|'HOLD', 'entry': <price>, 'sl': <price>, 'tp': <price>}}."

    data = {
        "model": "deepseek-chat", # Or another suitable model
        "messages": [
            {"role": "system", "content": "You are a forex scalping AI. Provide precise trading signals and levels."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 150
    }

    try:
        # Using requests library for HTTP POST. This needs to be installed in the sandbox.
        # For now, I'll simulate a response.
        # import requests
        # response = requests.post(DEEPSEEK_API_URL, headers=headers, json=data)
        # response.raise_for_status() # Raise an exception for HTTP errors
        # ai_output = response.json()['choices'][0]['message']['content']

        # --- SIMULATED AI RESPONSE FOR DEMONSTRATION ---
        # In a real scenario, the above requests.post call would be active.
        # For now, we'll return a dummy response.
        current_close = market_data['current_bar']['close']
        if market_data['current_bar']['tick_volume'] > 100: # Simple condition for demo
            if market_data['current_bar']['close'] > market_data['current_bar']['open']: # Bullish candle
                ai_output = json.dumps({"signal": "BUY", "entry": current_close, "sl": round(current_close - 0.00010, 5), "tp": round(current_close + 0.00005, 5)})
            else: # Bearish candle
                ai_output = json.dumps({"signal": "SELL", "entry": current_close, "sl": round(current_close + 0.00010, 5), "tp": round(current_close - 0.00005, 5)})
        else:
            ai_output = json.dumps({"signal": "HOLD", "entry": current_close, "sl": 0.0, "tp": 0.0})
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


