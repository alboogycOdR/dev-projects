#!/usr/bin/env python3
"""
Setup script for Forex Arbitrage Trading System
"""

import os
import sys
import subprocess

def install_requirements():
    """Install required Python packages"""
    print("Installing required packages...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✓ Requirements installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ Error installing requirements: {e}")
        return False

def create_directories():
    """Create necessary directories"""
    directories = ['logs', 'data', 'results']

    for directory in directories:
        if not os.path.exists(directory):
            os.makedirs(directory)
            print(f"✓ Created directory: {directory}")
        else:
            print(f"✓ Directory already exists: {directory}")

def check_mt5_installation():
    """Check if MetaTrader 5 is accessible"""
    try:
        import MetaTrader5 as mt5
        print("✓ MetaTrader5 package is available")

        # Try to initialize (will fail without MT5 installed, but that's expected)
        if mt5.initialize():
            print("✓ MetaTrader 5 connection successful")
            mt5.shutdown()
        else:
            print("! MetaTrader 5 not running or not installed")
            print("  Please install MetaTrader 5 from your broker")

        return True
    except ImportError:
        print("✗ MetaTrader5 package not available")
        return False

def main():
    """Main setup function"""
    print("Forex Arbitrage Trading System Setup")
    print("=" * 40)

    # Install requirements
    if not install_requirements():
        print("Setup failed: Could not install requirements")
        return

    # Create directories
    create_directories()

    # Check MT5
    check_mt5_installation()

    print("\n" + "=" * 40)
    print("Setup completed!")
    print("\nNext steps:")
    print("1. Install MetaTrader 5 from your broker")
    print("2. Update terminal_path in arbitrage_config.ini")
    print("3. Configure your broker account in MT5")
    print("4. Run: python forex_arbitrage_system.py")
    print("\nFor backtesting, run: python arbitrage_backtester.py")

if __name__ == "__main__":
    main()
