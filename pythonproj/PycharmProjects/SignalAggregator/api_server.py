# api_server.py (SignalAggregatorV3 directory)
import logging
import threading
from flask import Flask

logger = logging.getLogger("APIServer")

# Define Flask app globally or pass it if needed
flask_app = Flask(__name__)

# Global references needed inside the endpoint function
# These will be set by the run_api_server function
shared_latest_signal = {}
shared_api_lock = None


@flask_app.route('/get_signal', methods=['GET'])
def get_signal_endpoint():
    """Endpoint for MQL5 EA to fetch the latest signal as a delimited string."""
    global shared_latest_signal, shared_api_lock

    signal_to_format = None
    if shared_api_lock is None:
        logger.error("API Lock not initialized!")
        return "ERROR: Server configuration invalid", 500  # Internal Server Error

    # --- Access Shared Data Safely ---
    with shared_api_lock:
        if shared_latest_signal and shared_latest_signal.get('internal_id'):  # Check basic validity
            signal_to_format = shared_latest_signal.copy()

    # --- Format Data ---
    if signal_to_format:
        try:
            # Format the pipe-delimited string using NORMALIZED data
            # Field order: message_id|timestamp_unix|action|symbol|open_price|stop_loss|take_profit|volume|original_open_msg_id
            # Note: original_open_msg_id is non-zero ONLY for CLOSE signals meant for comment matching.
            # IMPORTANT: The message_id sent here should be the one MQL5 uses to check for duplicates.
            #            Using the original message ID from the source platform is probably best here.

            signal_string = (
                f"{signal_to_format.get('original_message_id', 0)}|"  # Original Msg ID for MQL5 duplicate check
                f"{signal_to_format.get('timestamp_unix', 0)}|"
                f"{signal_to_format.get('action', '')}|"
                f"{signal_to_format.get('symbol', '')}|"
                f"{signal_to_format.get('open_price', 0.0):.5f}|"
                f"{signal_to_format.get('stop_loss', 0.0):.5f}|"
                f"{signal_to_format.get('take_profit', 0.0):.5f}|"
                f"{signal_to_format.get('volume', 0.0):.2f}|"
                f"{signal_to_format.get('original_open_msg_id', 0)}"  # Added 9th field for CLOSE logic V3
            )

            logger.info(f"API Serving Signal String: {signal_string}")
            return signal_string

        except Exception as e:
            logger.error(f"Error formatting signal string for API: {signal_to_format} - Error: {e}", exc_info=True)
            return "ERROR: Failed to format signal", 500
    else:
        logger.info("API Serving: No valid signal data available.")
        return ""  # Return empty string if no valid signal is stored


def run_api_server(latest_signal_ref: dict, lock_ref: threading.Lock, host: str, port: int):
    """Runs the Flask server, passing references to shared data."""
    global shared_latest_signal, shared_api_lock
    shared_latest_signal = latest_signal_ref
    shared_api_lock = lock_ref

    logger.info(f"Starting Flask API server on http://{host}:{port}")
    try:
        # Use waitress or another production-ready WSGI server in a real deployment
        # For development:
        flask_app.run(host=host, port=port, threaded=True, use_reloader=False, debug=False)
    except Exception as e:
        logger.critical(f"Flask API server failed to start or crashed: {e}", exc_info=True)
