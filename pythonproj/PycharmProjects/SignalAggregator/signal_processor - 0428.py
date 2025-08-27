# signal_processor.py (SignalAggregatorV3 directory)
import logging
import time
import threading
from queue import Queue, Empty  # Import Empty exception

# Assuming normalize_signal is in normalizer.py in the same dir level or utils
try:
    from normalizer import normalize_signal
except ImportError:
    # Adjust path if necessary based on your structure
    from .normalizer import normalize_signal # Example if they are in same package


logger = logging.getLogger("SignalProcessor")


class SignalProcessor:
    def __init__(self, message_queue: Queue, parsers: dict, source_parser_map: dict,latest_signal_store: dict, api_lock: threading.Lock,
                 symbol_map: dict = None):
        self.message_queue = message_queue
        self.parsers = parsers  # Dict of {parser_id: parser_instance}
        self.source_parser_map = source_parser_map  # ===> STORE the passed map ===
        self.latest_signal_store = latest_signal_store  # Reference to the shared dict
        self.api_lock = api_lock  # Lock for accessing the shared dict
        self.symbol_map = symbol_map if symbol_map else {}
        self._stop_event = threading.Event()
        # Track processed message IDs per source to avoid reprocessing during restarts if needed
        # self.processed_ids = {} # Example: { "source_id": {message_id1, message_id2} }
        self.processed_ids = set()
        logger.info("SignalProcessor initialized.")  # Added init log

    def run(self):
        """The main loop executed in a separate thread."""
        logger.info("Signal Processor thread started.")
        while not self._stop_event.is_set():
            try:
                # Get raw message from queue, block for a short time
                raw_message = self.message_queue.get(block=True, timeout=1.0)
                message_unique_key = f"{raw_message.source_id}-{raw_message.original_id}"

                # --- Find the Correct Parser ---
                # Assumes RawMessage has a source_id which maps to a parser_id via config logic in main.py
                # For now, let's assume raw_message has 'source_id' and we get parser_id from there
                # Need config access or pass parser_id mapping
                # Simplified: Get parser config name linked to source during setup?
                # TODO: Need a way to get the parser_id for the raw_message.source_id
                # For now, ASSUME our telegram source 'telegram_fxscalping' uses 'telegram_format_1' parser
                # This needs proper mapping via config passed down/looked up here.
                parser_id_for_source = None
                logger.debug(f"SP Debug: Checking source '{raw_message.source_id}'. Available Map: {self.source_parser_map}. Available Parser Instances: {list(self.parsers.keys())}")
                # if raw_message.source_id == 'telegram_fxscalping':
                #     parser_id_for_source = 'telegram_format_1'  # Hardcoded lookup - FIX THIS

                if not parser_id_for_source or parser_id_for_source not in self.parsers:
                    logger.warning(
                        f"No valid parser configured/found for source '{raw_message.source_id}'. Skipping msg {raw_message.original_id}.")
                    self.message_queue.task_done()  # Mark task as done even if skipped
                    continue

                parser = self.parsers[parser_id_for_source]

                # --- Parse ---
                logger.debug(
                    f"Processing msg {raw_message.original_id} from {raw_message.source_id} using parser {parser_id_for_source}")
                parsed_data = parser.parse(raw_message)
                if not parsed_data:
                    # Parsing failed or msg didn't match format
                    logger.debug(f"Msg {raw_message.original_id} not parsed by {parser_id_for_source}.")
                    self.message_queue.task_done()
                    continue

                # --- Normalize ---
                # Pass source_id into parsed_data if parser doesn't add it
                parsed_data['source_id'] = raw_message.source_id
                parsed_data['channel_info'] = raw_message.channel_info
                # Pass timestamp explicitly if parser didn't return datetime
                if 'timestamp' not in parsed_data: parsed_data['timestamp'] = raw_message.timestamp

                normalized_data = normalize_signal(parsed_data, self.symbol_map)
                if not normalized_data:
                    logger.warning(f"Normalization failed for msg {raw_message.original_id}.")
                    self.message_queue.task_done()
                    continue

                # --- Store Latest Signal (Thread Safe) ---
                # Store based on unique ID (e.g., source-original_id) or use timestamp?
                # For now, simply overwrite the single 'latest' entry
                with self.api_lock:
                    self.latest_signal_store.clear()  # Remove old signal
                    self.latest_signal_store.update(normalized_data)  # Add new signal
                    logger.info(f"Updated latest signal store with signal from {normalized_data['internal_id']}")
                    logger.debug(f"Stored data: {self.latest_signal_store}")

                # Mark task as complete for the queue
                self.message_queue.task_done()

            except Empty:
                # Queue was empty, loop continues waiting
                continue
            except Exception as e:
                logger.error(f"Error in signal processor loop: {e}", exc_info=True)
                # Avoid tight loop on unexpected errors
                time.sleep(0.5)

        logger.info("Signal Processor thread finished.")

    def stop(self):
        """Signals the processor loop to stop."""
        logger.info("Stopping Signal Processor thread...")
        self._stop_event.set()
