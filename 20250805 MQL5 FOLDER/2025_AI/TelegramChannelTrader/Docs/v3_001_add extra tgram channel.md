Excellent! Implementing the dynamic loading and mapping is the key step to unlocking the real power and flexibility of the V3 architecture. Let's tackle this.

**Goal:** Modify `main.py` and `signal_processor.py` so that adding a new Telegram channel with a different signal format only requires:

1.  Adding a new source definition under `sources:` in `config.yaml`.
2.  Adding a new parser definition under `parsers:` in `config.yaml` (referencing a new parser class).
3.  Creating a new Python file (e.g., `parsers/telegram_parser_format2.py`) containing the class that handles the *new* signal format.

**Steps:**

**Step 1: Prepare `config.yaml` for a Second Source**

Let's assume your second Telegram channel is called `@DifferentSignalChannel` and uses a completely hypothetical "Format 2".

Modify your `config.yaml`:

```yaml
# config.yaml
logging:
  level: INFO # Set to DEBUG when testing changes
  format: '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

api_endpoint:
  host: "127.0.0.1"
  port: 5000

sources:
  # --- Source 1: Original Channel ---
  telegram_fxscalping: # Unique ID
    enabled: true
    type: telegram_user      # Connector type
    session_name: "mt5_signal_session" # Or whatever session you use
    credentials:
      api_id: YOUR_API_ID_HERE
      api_hash: YOUR_API_HASH_HERE
      phone: YOUR_PHONE_NUMBER_HERE
    targets:
      - "fx_scalping"      # Telegram channel username/ID
    parser: telegram_format_1 # <--- Maps to the parser for THIS format

  # --- Source 2: NEW Channel ---
  telegram_otherchannel:   # UNIQUE ID for the new source
    enabled: true            # Set to true to activate
    type: telegram_user      # Same connector type (using Telethon user)
                             # Or telegram_bot if using a different mechanism
    session_name: "mt5_signal_session_other" # Use a DIFFERENT session name for a potentially different user or just isolation
    credentials:
      # If using the SAME Telegram user account, copy the SAME api_id/hash/phone
      api_id: YOUR_API_ID_HERE
      api_hash: YOUR_API_HASH_HERE
      phone: YOUR_PHONE_NUMBER_HERE
      # If using a DIFFERENT account, provide its credentials here
    targets:
      - "DifferentSignalChannel" # <--- Username/ID of the second channel
    parser: telegram_format_2   # <--- MAPS to a NEW parser for Format 2

parsers:
  telegram_format_1: # ID for the first parser
    type: TelegramFormat1Parser # Class name in telegram_parser.py
    # config specific to this parser (if any)

  telegram_format_2: # ID for the second parser
    type: TelegramFormat2Parser # <<< NEW Class name (we will create this)
    # Example specific config:
    # keyword_buy: "ENTER LONG"
    # keyword_sell: "ENTER SHORT"

# Optional symbol mapping (apply in normalizer)
# symbol_mapping:
#  US30: DJ30 # Example mapping
```

**Key Changes in Config:**

*   Added a second entry under `sources:` named `telegram_otherchannel`.
*   It uses the same `type: telegram_user` (assuming you use the same account, otherwise adjust credentials/session). **Crucially, use a distinct `session_name` if connecting multiple times even with the same credentials to avoid conflicts.**
*   It targets `DifferentSignalChannel`.
*   It maps to a **new parser ID `telegram_format_2`**.
*   Added a corresponding entry under `parsers:` for `telegram_format_2`, specifying its `type` (class name) as `TelegramFormat2Parser`.

**Step 2: Create the New Parser Class (`parsers/telegram_parser_format2.py`)**

Create this new file. For now, let's make a placeholder parser that just logs the message text and doesn't actually parse, so we can test the loading mechanism.

```python
# parsers/telegram_parser_format2.py
import logging
from .base_parser import BaseParser
from utils.message_models import RawMessage

logger = logging.getLogger(__name__) # Use module-level logger

class TelegramFormat2Parser(BaseParser):
    """
    Placeholder parser for a hypothetical second Telegram signal format.
    Currently just logs the message.
    """
    def parse(self, raw_message: RawMessage) -> dict | None:
        self.logger.info(f"Parser '{self.parser_id}' received message {raw_message.original_id} from {raw_message.source_id}. Text: '{raw_message.text[:100]}...'")
        self.logger.warning(f"Parser '{self.parser_id}' is a placeholder and does not implement actual parsing yet.")

        # In a real implementation:
        # 1. Use Regex or other methods to parse raw_message.text
        # 2. Extract action, symbol, prices, volume, etc.
        # 3. Return a dictionary similar to TelegramFormat1Parser's output,
        #    e.g., {'action': 'BUY', 'symbol': 'GBPUSD', 'open_price': '1.2500', ...}
        #    (values as strings ok, normalization handles type conversion)
        # For now, return None so it doesn't proceed further in the test
        return None
```

**Step 3: Implement Dynamic Loading in `main.py`**

Modify the parser and connector initialization loops to dynamically find and instantiate classes. We'll use `importlib` and potentially `inspect` for this.

```python
# main.py (MODIFIED sections)

import asyncio
import logging
import signal
import threading
from queue import Queue
import importlib # <<< ADDED for dynamic loading
import inspect   # <<< ADDED for finding classes

# --- Assume these imports are correct relative to your project structure ---
try:
    from utils.config_loader import load_config, setup_logging
    from utils.message_models import RawMessage # Might be needed if connectors use it directly

    # Import the MODULES, not necessarily every class directly
    import connectors.base_connector
    import connectors.telegram_connector
    # import connectors.discord_connector # Example placeholder

    import parsers.base_parser
    import parsers.telegram_parser
    import parsers.telegram_parser_format2 # <<< ADDED import for the new parser module

    from normalizer import normalize_signal
    from signal_processor import SignalProcessor
    from api_server import run_api_server
except ImportError as e:
     print(f"ERROR: Failed to import modules. Check file structure and paths: {e}")
     exit(1)

# --- Global Queue & Lock (Remain the same) ---
raw_message_queue = Queue()
latest_signal_for_api = {}
api_data_lock = threading.Lock()


# --- Helper function to find classes ---
def find_classes(module, base_class):
    """Finds all classes in a module that inherit from a base class."""
    classes = {}
    for name, obj in inspect.getmembers(module, inspect.isclass):
        if obj is not base_class and issubclass(obj, base_class):
            classes[name] = obj
            # logger.debug(f"Found class '{name}' inheriting from {base_class.__name__} in {module.__name__}")
    return classes

async def main():
    # 1. Load Configuration
    config = load_config()
    if not config: return
    setup_logging(config)
    logger = logging.getLogger("MainApp")
    logger.info("Application starting...")

    # 2. Initialize Components based on Config

    # --- Dynamic Parser Loading ---
    active_parsers = {}
    parser_configs = config.get('parsers', {})
    # Find all parser classes automatically
    available_parser_classes = find_classes(parsers.telegram_parser, parsers.base_parser.BaseParser)
    available_parser_classes.update(find_classes(parsers.telegram_parser_format2, parsers.base_parser.BaseParser))
    # Add other parser modules here...
    logger.info(f"Found available parser classes: {list(available_parser_classes.keys())}")

    logger.info(f"Loading {len(parser_configs)} parser configurations...")
    for parser_id, p_config in parser_configs.items():
        parser_class_name = p_config.get('type')
        if not parser_class_name:
            logger.warning(f"Parser config '{parser_id}' missing 'type' (class name). Skipping.")
            continue

        ParserClass = available_parser_classes.get(parser_class_name) # Find class by name
        if ParserClass:
            try:
                active_parsers[parser_id] = ParserClass(parser_id, p_config) # Instantiate
                logger.info(f"Instantiated Parser: {parser_id} ({parser_class_name})")
            except Exception as e:
                logger.error(f"Failed to instantiate parser '{parser_id}' using class '{parser_class_name}': {e}", exc_info=True)
        else:
            logger.warning(f"Parser class '{parser_class_name}' not found for parser config '{parser_id}'. Skipping.")


    # --- Dynamic Connector Loading (Similar Pattern) ---
    connectors = []
    connector_tasks = []
    source_configs = config.get('sources', {})
    source_parser_map = {} # Map: source_id -> parser_id

    # Find all connector classes
    available_connector_classes = find_classes(connectors.telegram_connector, connectors.base_connector.BaseConnector)
    # available_connector_classes.update(find_classes(connectors.discord_connector, connectors.base_connector.BaseConnector))
    # ... add other connector modules
    logger.info(f"Found available connector classes: {list(available_connector_classes.keys())}")

    logger.info(f"Loading {len(source_configs)} source configurations...")
    for source_id, s_config in source_configs.items():
        if not s_config.get('enabled', False):
            logger.info(f"Source '{source_id}' is disabled. Skipping.")
            continue

        # --- Determine Connector Type ---
        connector_type_key = s_config.get('type') # e.g., "telegram_user"
        ConnectorClass = None
        # Map type key from config to actual Class name found
        # This mapping might need refinement if type key != Class name exactly
        if connector_type_key == "telegram_user":
             ConnectorClass = available_connector_classes.get("TelegramUserConnector")

        if not ConnectorClass:
             logger.warning(f"No matching connector class found for type '{connector_type_key}' defined for source '{source_id}'. Skipping.")
             continue

        # --- Check Parser Mapping ---
        parser_id = s_config.get('parser')
        if not parser_id or parser_id not in active_parsers:
            logger.error(f"Invalid or missing parser reference '{parser_id}' for source '{source_id}'. Skipping source.")
            continue
        source_parser_map[source_id] = parser_id # Add valid mapping
        logger.debug(f"Mapping source '{source_id}' to parser '{parser_id}'")

        # --- Instantiate and Start Connector ---
        try:
            # Pass correct Queue type (needs check)
            # Assuming standard Queue based on SignalProcessor usage
            connector_instance = ConnectorClass(source_id, s_config, raw_message_queue)
            logger.info(f"Instantiated Connector: {source_id} ({connector_type_key})")
            connectors.append(connector_instance)
            connector_tasks.append(asyncio.create_task(connector_instance.run(), name=f"Connector_{source_id}"))

        except Exception as e:
            logger.error(f"Failed to instantiate or start connector task '{source_id}' for type '{connector_type_key}': {e}", exc_info=True)


    # 3. Initialize Signal Processor Thread (Pass the map)
    logger.info("Initializing Signal Processor...")
    signal_processor = SignalProcessor(
        message_queue=raw_message_queue,
        parsers=active_parsers,             # Dict of ACTIVE parser instances
        source_parser_map=source_parser_map,# <<< Pass the generated map here
        latest_signal_store=latest_signal_for_api,
        api_lock=api_data_lock,
        symbol_map=config.get('symbol_mapping', {})
    )
    processor_thread = threading.Thread(target=signal_processor.run, daemon=True, name="SignalProcessor")

    # ... (Rest of section 4: API Thread, section 5: Running Tasks, section 6: Shutdown remains the same) ...

    # ... inside the try...finally block for task running ...
    # ... shutdown logic ...

# ... (Rest of file: if __name__ == "__main__": remains the same) ...

```

**Step 4: Implement Dynamic Lookup in `signal_processor.py`**

Ensure the hardcoded `if raw_message.source_id == ...` check is replaced by the dynamic lookup using the map passed during initialization. (The code provided previously already included this, just double-check).

```python
# signal_processor.py (MODIFIED run method section)

    def run(self):
        """The main loop executed in a separate thread."""
        logger.info("Signal Processor thread starting run loop.")
        while not self._stop_event.is_set():
            try:
                raw_message = self.message_queue.get(block=True, timeout=1.0)

                message_unique_key = f"{raw_message.source_id}-{raw_message.original_id}"
                # ... (duplicate check) ...

                # ====> USE the map for dynamic lookup <====
                parser_id = self.source_parser_map.get(raw_message.source_id) # Dynamic lookup

                if not parser_id or parser_id not in self.parsers:
                    logger.warning(f"No valid parser found or mapped for source '{raw_message.source_id}'. Map: {self.source_parser_map}. Skipping msg {raw_message.original_id}.")
                    self.processed_ids.add(message_unique_key)
                    self.message_queue.task_done()
                    continue
                # ====> End dynamic lookup part <====

                parser = self.parsers[parser_id] # Get the correct parser instance
                logger.debug(f"Processing msg {raw_message.original_id} from {raw_message.source_id} using parser '{parser_id}' ({type(parser).__name__})")

                # --- Parse ---
                parsed_data = parser.parse(raw_message)
                # ... (rest of loop: check parsed_data, normalize, store, task_done) ...

            except Empty:
                continue
            except Exception as e:
                logger.error(f"Critical Error in signal processor loop: {e}", exc_info=True)
                time.sleep(1.0)
        logger.info("Signal Processor thread stopped.")

    # ... (stop method remains the same) ...

```

**Testing:**

1.  Ensure all imports are correct, especially for the new parser module (`parsers.telegram_parser_format2`) in `main.py`.
2.  Make sure you have filled in your credentials in `config.yaml`. If using the same Telegram account for both sources, remember to use **different `session_name` values** (e.g., `mt5_signal_session` and `mt5_signal_session_other`) to avoid file conflicts. You will likely need to run the authorization script (or modify the connector) **twice**, once for each session name specified.
3.  Run `python main.py`.
4.  **Check Logs:**
    *   Verify `main.py` logs that it found and instantiated *both* parser classes (`TelegramFormat1Parser`, `TelegramFormat2Parser`).
    *   Verify it found and instantiated *both* connector types (likely two `TelegramUserConnector` instances).
    *   Verify `SignalProcessor` is initialized and started.
    *   Verify `APIServer` is initialized and started.
    *   Verify both connectors attempt to connect (and likely need authorization if sessions are new).
5.  **Authorize (if needed):** Authorize *both* sessions using Method A or B from before (running `authorize_telegram.py` modified to target each session name, or temporarily modifying the connector).
6.  **Test Signal Reception:**
    *   Send a signal matching Format 1 to `@fx_scalping`. Check logs for correct parsing by `TelegramFormat1Parser`.
    *   Send *any* text message to `@DifferentSignalChannel`. Check logs to see `TelegramFormat2Parser` logging that it received the message (it won't parse it yet, as it's a placeholder).

This demonstrates that the dynamic loading and mapping are working. The next step would be to implement the actual parsing logic inside `TelegramFormat2Parser` for the *real* format used by that second channel.