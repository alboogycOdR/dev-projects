# --- START OF FILE main.py (MODIFIED - Option 1 Applied) ---

import asyncio
import logging
import signal # Keep signal import - maybe needed for other purposes later
import threading
# Use standard Queue, as SignalProcessor runs in a thread
from queue import Queue
# from asyncio import Queue # Only if ALL components become async

# --- Assume these imports are correct relative to your project structure ---
try:
    from utils.config_loader import load_config, setup_logging
    from connectors.telegram_connector import TelegramUserConnector
    # from connectors.discord_connector import DiscordConnector # Example placeholder

    from parsers.telegram_parser import TelegramFormat1Parser


    # from parsers.discord_parser import DiscordFormatXParser # Example placeholder

    from normalizer import normalize_signal # Assuming top-level or accessible via path

    from signal_processor import SignalProcessor
    from api_server import run_api_server
except ImportError as e:
     print(f"ERROR: Failed to import modules. Check file structure and paths: {e}")
     exit(1)

# --- Global Queue & Lock ---
raw_message_queue = Queue()
latest_signal_for_api = {}
api_data_lock = threading.Lock()

async def main():
    # 1. Load Configuration
    config = load_config()
    if not config: return
    setup_logging(config)
    logger = logging.getLogger("MainApp")
    logger.info("Application starting...")

    # 2. Initialize Components based on Config
    active_parsers = {}
    parser_configs = config.get('parsers', {})
    logger.info(f"Loading {len(parser_configs)} parser configurations...")
    for parser_id, p_config in parser_configs.items():
        parser_type_str = p_config.get('type')
        try:
            # TODO: Implement dynamic parser loading based on parser_type_str
            if parser_type_str == "TelegramFormat1Parser":
                active_parsers[parser_id] = TelegramFormat1Parser(parser_id, p_config)
                logger.info(f"Instantiated Parser: {parser_id} ({parser_type_str})")
            else:
                logger.warning(f"Skipping unknown parser type '{parser_type_str}' for id '{parser_id}'")
        except Exception as e:
            logger.error(f"Failed to instantiate parser '{parser_id}': {e}", exc_info=True)

    connectors = []
    connector_tasks = []
    source_configs = config.get('sources', {})
    source_parser_map = {} # Map: source_id -> parser_id
    logger.info(f"Loading {len(source_configs)} source configurations...")
    for source_id, s_config in source_configs.items():
        if not s_config.get('enabled', False):
            logger.info(f"Source '{source_id}' is disabled. Skipping.")
            continue

        source_type = s_config.get('type')
        parser_id = s_config.get('parser')

        if not parser_id or parser_id not in active_parsers:
            logger.error(f"Invalid or missing parser '{parser_id}' for source '{source_id}'. Skipping source.")
            continue

        # Add to source->parser map
        source_parser_map[source_id] = parser_id
        logger.debug(f"Mapping source '{source_id}' to parser '{parser_id}'")

        try:
            connector = None
            # TODO: Implement dynamic connector instantiation based on source_type
            if source_type == "telegram_user":
                # Pass the standard Queue (make sure connector expects this or asyncio.Queue)
                connector = TelegramUserConnector(source_id, s_config, raw_message_queue)
            # Add elif for other connector types...
            else:
                logger.warning(f"Unknown connector type '{source_type}' for source '{source_id}'. Skipping.")
                continue

            if connector:
                logger.info(f"Instantiated Connector: {source_id} ({source_type})")
                connectors.append(connector)
                # Use connector's main run method as the task
                connector_tasks.append(asyncio.create_task(connector.run(), name=f"Connector_{source_id}"))

        except Exception as e:
            logger.error(f"Failed to instantiate or start connector task '{source_id}': {e}", exc_info=True)

    # 3. Initialize Signal Processor Thread
    logger.info("Initializing Signal Processor...")
    signal_processor = SignalProcessor(
        message_queue=raw_message_queue,
        parsers=active_parsers,
        source_parser_map=source_parser_map, # Pass the dynamically built map
        latest_signal_store=latest_signal_for_api,
        api_lock=api_data_lock,
        symbol_map=config.get('symbol_mapping', {})
    )
    processor_thread = threading.Thread(target=signal_processor.run, daemon=True, name="SignalProcessor")

    # 4. Initialize Flask API Server Thread
    logger.info("Initializing API Server...")
    api_config = config.get('api_endpoint', {})
    api_host = api_config.get('host', '127.0.0.1') # Provide defaults
    api_port = api_config.get('port', 5000)
    api_thread = threading.Thread(
        target=run_api_server,
        args=(latest_signal_for_api, api_data_lock, api_host, api_port),
        daemon=True,
        name="APIServer"
    )

    # --- Start Background Threads ---
    processor_thread.start()
    logger.info("Started Signal Processor Thread")
    api_thread.start()
    logger.info(f"Started API Server Thread (aiming for http://{api_host}:{api_port})")


    # --- Run Connector Tasks (Main Async Part) ---
    running_connector_tasks = list(connector_tasks) # Track currently active tasks

    try:
        if running_connector_tasks:
            logger.info(f"Running {len(running_connector_tasks)} connector task(s)... Use Ctrl+C to exit gracefully.")
            # Wait for the first task to complete (normally or with error)
            # If a task finishes, log it and maybe decide to stop others, or let them run.
            # This loop allows monitoring tasks one by one as they might finish.
            while running_connector_tasks:
                 done, pending = await asyncio.wait(
                      running_connector_tasks,
                      return_when=asyncio.FIRST_COMPLETED
                 )
                 running_connector_tasks = list(pending) # Update list of tasks still running

                 for task in done:
                      task_name = task.get_name()
                      try:
                          task.result() # Raise exception if task failed
                          # If task completed without error, it means the connector's run() finished normally,
                          # which might indicate an issue if it wasn't supposed to stop.
                          logger.warning(f"Connector task '{task_name}' completed unexpectedly without error. Check connector logic.")
                      except asyncio.CancelledError:
                          logger.info(f"Connector task '{task_name}' was cancelled (likely during shutdown).")
                      except Exception as e:
                          logger.error(f"Connector task '{task_name}' failed: {e}", exc_info=True)
                          # Optional: Decide if failure of one connector should stop others
                          # logger.critical("Stopping application due to connector failure.")
                          # raise # Re-raise exception to trigger shutdown via outer handler

        else:
            logger.warning("No active connector tasks were started. Application will run until manually stopped (Ctrl+C).")
            # Keep the main async loop alive so background threads (processor, API) can run
            await asyncio.Event().wait() # Waits indefinitely until interrupted/cancelled

    except asyncio.CancelledError:
        logger.info("Main async task was cancelled (expected during shutdown).")
    except Exception as e:
        # Catch any other unexpected errors in the main async logic
        logger.critical(f"Error in main async task execution: {e}", exc_info=True)
    finally:
        # --- Graceful Shutdown Sequence ---
        logger.info("Initiating application shutdown sequence...")

        # 1. Stop Connectors (Await their stop methods)
        if connectors:
             logger.info(f"Signaling {len(connectors)} connectors to stop...")
             stop_tasks = [asyncio.create_task(conn.stop(), name=f"Stop_{conn.source_id}") for conn in connectors]
             # Wait for stop tasks to complete, with a timeout
             done, pending = await asyncio.wait(stop_tasks, timeout=10.0)
             if pending:
                  logger.warning(f"{len(pending)} connector stop tasks timed out.")
                  for task in pending: task.cancel() # Force cancel timeout tasks
             else:
                 logger.info("All connectors signaled to stop.")
             # Give a moment for network operations to finish
             await asyncio.sleep(0.5)

        # 2. Stop Processor Thread
        # Check if it was initialized and started correctly before stopping
        if 'signal_processor' in locals() and processor_thread.is_alive():
            logger.info("Stopping signal processor thread...")
            signal_processor.stop() # Signal the thread's internal loop to stop
            processor_thread.join(timeout=5.0) # Wait up to 5s for clean exit
            if processor_thread.is_alive():
                logger.warning("Processor thread did not stop cleanly.")
        else:
            logger.debug("Processor thread already stopped or wasn't started.")

        # 3. API Server Thread (Daemon)
        # No explicit stop needed for daemon threads, will exit when main program ends.
        logger.info("API Server thread (daemon) will exit.")

        logger.info("Application shutdown complete.")


# --- REMOVED: def setup_signal_handlers(stop_event, loop): ... function ... ---


if __name__ == "__main__":
    # Configure root logger minimally in case config fails or is missing logging section
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    try:
        # Start the main asynchronous event loop and run the 'main' coroutine
        asyncio.run(main())
    except KeyboardInterrupt: # Catch Ctrl+C at the top level
        print("\nCtrl+C detected by entry point. Initiating shutdown...")
        # asyncio.run() is designed to catch KeyboardInterrupt and handle
        # cancelling the main task ('main()'). The 'finally' block inside 'main()'
        # should then execute the graceful shutdown sequence.
        logging.info("Shutdown initiated via KeyboardInterrupt.")
    except Exception as e:
        # Catch any critical exceptions during startup or if main crashes badly
        logging.critical(f"Critical unhandled exception at entry point: {e}", exc_info=True)

    logging.info("Script finished execution.")

# --- END OF FILE main.py ---