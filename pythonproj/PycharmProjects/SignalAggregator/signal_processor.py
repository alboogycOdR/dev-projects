import logging
import time
import threading
# Using standard Queue assuming API server runs in separate thread
from queue import Queue, Empty # Import Empty exception

import logger

# Assuming normalizer.py is accessible (e.g., same directory or via Python path)
try:
    from normalizer import normalize_signal
except ImportError:
    # Adjust import path if normalizer is elsewhere (e.g., in utils)
    logger.error("Failed to import normalize_signal. Check path/structure.")
    # Define a dummy function to avoid crashing immediately

    def normalize_signal(parsed_data: dict, symbol_map: dict = None):
        logger.error("Dummy normalize_signal called! Normalizer module failed import.")
        return None

logger = logging.getLogger("SignalProcessor")

class SignalProcessor:
    """
    Runs in a dedicated thread, processing raw messages from a queue.
    It finds the appropriate parser, parses the message, normalizes the data,
    and updates a shared dictionary holding the latest valid signal for the API.
    """
    def __init__(self,
                 message_queue: Queue,
                 parsers: dict,             # Dict {parser_id: parser_instance} from main.py
                 source_parser_map: dict,  # Dict {source_id: parser_id} from main.py
                 latest_signal_store: dict,# Shared dict (passed by ref)
                 api_lock: threading.Lock, # Shared lock (passed by ref)
                 symbol_map: dict = None):
        """
        Initializes the SignalProcessor.

        Args:
            message_queue: The queue instance (e.g., queue.Queue) to get RawMessage objects from.
            parsers: A dictionary mapping parser configuration IDs to instantiated parser objects.
            source_parser_map: A dictionary mapping source configuration IDs to parser configuration IDs.
            latest_signal_store: A dictionary object used to store the latest processed signal.
            api_lock: A threading.Lock object to protect access to latest_signal_store.
            symbol_map: An optional dictionary for symbol normalization.
        """
        self.message_queue = message_queue
        self.parsers = parsers
        self.source_parser_map = source_parser_map
        self.latest_signal_store = latest_signal_store
        self.api_lock = api_lock
        self.symbol_map = symbol_map if symbol_map else {}
        self._stop_event = threading.Event()
        # Stores unique keys (e.g., "source_id-original_msg_id") processed in this run instance
        self.processed_ids = set()
        logger.info("SignalProcessor initialized.")
        # Log the mappings received for debugging startup
        logger.debug(f"SP Initialized with Source->Parser Map: {self.source_parser_map}")
        logger.debug(f"SP Initialized with Parsers: {list(self.parsers.keys())}")


    def run(self):
        """The main loop executed in the Signal Processor thread."""
        logger.info("Signal Processor thread starting run loop...")
        while not self._stop_event.is_set():
            try:
                # Wait for a message from the queue (blocks for timeout)
                raw_message = self.message_queue.get(block=True, timeout=1.0)

                # --- Basic Duplicate Check for this session ---
                message_unique_key = f"{raw_message.source_id}-{raw_message.original_id}"
                if message_unique_key in self.processed_ids:
                     logger.debug(f"Skipping already processed message: {message_unique_key}")
                     self.message_queue.task_done()
                     continue

                # --- Dynamic Parser Lookup ---
                # Get the PARSER ID configured for this message's source ID
                parser_id = self.source_parser_map.get(raw_message.source_id)

                # Debugging Print (Optional - keep level=DEBUG in config)
                logger.debug(f"SP Lookup: Msg Source='{raw_message.source_id}', Mapped Parser ID='{parser_id}'")

                # Check if lookup failed or the required parser instance doesn't exist
                parser_instance = self.parsers.get(parser_id) if parser_id else None

                if not parser_instance: # Checks if parser_id was found AND parser instance exists
                    logger.warning(
                        f"No valid parser instance found for Source='{raw_message.source_id}' (Mapped Parser ID: '{parser_id}'). Skipping msg {raw_message.original_id}.")
                    # Mark as processed to avoid re-logging the warning constantly if issue persists
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue
                # --- End Lookup/Validation ---


                # --- Parse the Raw Message ---
                logger.debug(f"Processing msg {raw_message.original_id} from {raw_message.source_id} using parser '{parser_id}' (Type: {type(parser_instance).__name__})")
                parsed_data = parser_instance.parse(raw_message) # Call the specific parser's parse method

                if not parsed_data:
                    logger.debug(f"Msg {raw_message.original_id} not parsed by {parser_id}. Parser returned None.")
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue

                # --- Normalize the Parsed Data ---
                logger.debug(f"Normalizing data for msg {raw_message.original_id}...")
                # Pass necessary info if parser didn't add it (parsers should ideally add these)
                if 'source_id' not in parsed_data: parsed_data['source_id'] = raw_message.source_id
                if 'channel_info' not in parsed_data: parsed_data['channel_info'] = raw_message.channel_info
                if 'timestamp' not in parsed_data: parsed_data['timestamp'] = raw_message.timestamp

                normalized_data = normalize_signal(parsed_data, self.symbol_map) # Call the normalizer function/module

                if not normalized_data:
                    logger.warning(f"Normalization failed for msg {raw_message.original_id}. Discarding.")
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue

                # --- Store the Latest Valid & Normalized Signal (Thread-Safe) ---
                logger.debug(f"Attempting to acquire lock to update latest signal store...")
                with self.api_lock:
                    logger.debug(f"Lock acquired. Updating store.")
                    # Overwrite the single latest signal entry
                    self.latest_signal_store.clear()
                    self.latest_signal_store.update(normalized_data)
                    logger.info(f"Updated latest signal store with signal ID {normalized_data['internal_id']} (Orig: {normalized_data['original_message_id']})")
                    # Optionally log less verbose details here
                    # logger.debug(f"Stored snapshot: action={normalized_data['action']}, symbol={normalized_data['symbol']}")
                logger.debug(f"Lock released.")


                # --- Mark task as fully processed ---
                self.processed_ids.add(message_unique_key)
                self.message_queue.task_done() # Signal to queue task is done

            except Empty:
                # This is expected when the queue is empty during the timeout
                continue # Simply continue the loop
            except Exception as e:
                # Catch any other unexpected errors in the loop
                logger.error(f"Critical error in SignalProcessor run loop: {e}", exc_info=True)
                # Optional: Pause briefly to prevent high CPU usage if errors persist
                time.sleep(1.0)

        logger.info("Signal Processor thread loop finished.") # Loop exited (likely due to stop event)

    def stop(self):
        """Signals the processor thread's main loop to stop."""
        logger.info("Stop requested for Signal Processor thread.")
        self._stop_event.set()