# utils/config_loader.py
import yaml
import logging
import os


def load_config(config_path='config.yaml'):
    """Loads configuration from a YAML file."""
    try:
        # Ensure path is absolute or relative to current script
        if not os.path.isabs(config_path):
            script_dir = os.path.dirname(os.path.dirname(__file__))  # Get parent dir (SignalAggregatorV3)
            config_path = os.path.join(script_dir, config_path)

        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
            logging.info(f"Configuration loaded successfully from {config_path}")
            return config
    except FileNotFoundError:
        logging.error(f"Configuration file not found at {config_path}")
        return None
    except yaml.YAMLError as e:
        logging.error(f"Error parsing configuration file {config_path}: {e}")
        return None
    except Exception as e:
        logging.error(f"An unexpected error occurred loading config: {e}")
        return None


def setup_logging(config):
    """Configures logging based on the loaded config."""
    log_config = config.get('logging', {})
    level = getattr(logging, log_config.get('level', 'INFO').upper(), logging.INFO)
    log_format = log_config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logging.basicConfig(level=level, format=log_format)
    # Optionally configure file logging here too
