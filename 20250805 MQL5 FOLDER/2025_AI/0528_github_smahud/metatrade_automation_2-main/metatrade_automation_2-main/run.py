"""
This script runs the MetaTrader5 LLM Trading Bot application.
"""

import os
import sys
import subprocess
import time
import json
import shutil

# Define the installation directory
INSTALL_DIR = "C:\\Users\\sousa\\Documents\\DataH\\metatradebot2"

def check_dependencies():
    """Check if all required packages are installed."""
    try:
        # Read requirements.txt
        with open("requirements.txt", "r") as f:
            requirements = f.read().splitlines()
        
        # Install any missing dependencies
        for req in requirements:
            if req:
                try:
                    module_name = req.split(">=")[0].split("==")[0].strip()
                    __import__(module_name)
                except ImportError:
                    print(f"Installing {req}...")
                    subprocess.check_call([sys.executable, "-m", "pip", "install", req])
        
        print("All dependencies installed successfully.")
        return True
    except Exception as e:
        print(f"Error checking dependencies: {e}")
        return False

def setup_environment():
    """Set up the environment for the application."""
    try:
        # Create the installation directory if it doesn't exist
        os.makedirs(INSTALL_DIR, exist_ok=True)
        
        # Copy all files to the installation directory
        files_to_copy = ["app.py", "indicators.py", "prompts.py", "utils.py", "requirements.txt", "README.md"]
        for file in files_to_copy:
            shutil.copy2(file, os.path.join(INSTALL_DIR, file))
        
        # Create a default config.json file if it doesn't exist
        config_path = os.path.join(INSTALL_DIR, "config.json")
        if not os.path.exists(config_path):
            default_config = {
                "mt5_account": {
                    "server": "MetaQuotes-Demo",
                    "login": 12345678,
                    "password": "password"
                },
                "openai_api_key": "",
                "default_symbol": "EURUSD",
                "default_timeframe": "H4",
                "default_max_contracts": 5
            }
            
            with open(config_path, "w") as f:
                json.dump(default_config, f, indent=4)
        
        print(f"Environment set up successfully in {INSTALL_DIR}")
        return True
    except Exception as e:
        print(f"Error setting up environment: {e}")
        return False

def main():
    """Main function to run the application."""
    print("MetaTrader5 LLM Trading Bot")
    print("==========================")
    
    # Check dependencies
    if not check_dependencies():
        print("Failed to install dependencies. Exiting.")
        return
    
    # Set up environment
    if not setup_environment():
        print("Failed to set up environment. Exiting.")
        return
    
    # Change to the installation directory
    os.chdir(INSTALL_DIR)
    
    # Check if OpenAI API key is set
    if not os.environ.get("OPENAI_API_KEY"):
        # Try to get it from config.json
        try:
            with open("config.json", "r") as f:
                config = json.load(f)
                api_key = config.get("openai_api_key", "")
                
                if api_key:
                    os.environ["OPENAI_API_KEY"] = api_key
                else:
                    api_key = input("Enter your OpenAI API key: ")
                    os.environ["OPENAI_API_KEY"] = api_key
                    
                    # Update config.json
                    config["openai_api_key"] = api_key
                    with open("config.json", "w") as f:
                        json.dump(config, f, indent=4)
        except Exception as e:
            print(f"Error setting up API key: {e}")
            api_key = input("Enter your OpenAI API key: ")
            os.environ["OPENAI_API_KEY"] = api_key
    
    print("Starting application...")
    print(f"Access the dashboard at http://localhost:8050")
    
    # Run the application
    try:
        import app
        app.app.run_server(debug=True, port=8050)
    except Exception as e:
        print(f"Error running application: {e}")

if __name__ == "__main__":
    main()