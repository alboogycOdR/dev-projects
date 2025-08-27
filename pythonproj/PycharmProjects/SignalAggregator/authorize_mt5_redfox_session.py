# authorize_telegram.py
import asyncio
from telethon import TelegramClient
import yaml
import logging

logging.basicConfig(level=logging.INFO)

# Load config just to get credentials
config = None
try:
     with open('config.yaml', 'r') as f:
          cfg_data = yaml.safe_load(f)
          config = cfg_data.get('sources',{}).get('telegram_redfox') # Adjust if source ID changes
          if not config or 'credentials' not in config:
              print("ERROR: Cannot find credentials for 'telegram_redfox' in config.yaml")
              exit(1)
except Exception as e:
     print(f"Error loading config.yaml: {e}")
     exit(1)

creds = config['credentials']
session_name = config.get('session_name', 'mt5_redfox_session')
api_id = int(creds['api_id'])
api_hash = creds['api_hash']
phone = creds['phone']

print(f"Attempting to authorize session '{session_name}' for {phone}...")

client = TelegramClient(session_name, api_id, api_hash)

async def run_auth():
    print("Connecting...")
    await client.connect()
    if await client.is_user_authorized():
        print("Already authorized!")
    else:
        print("Sending code request...")
        await client.send_code_request(phone)
        try:
            code = input('Please enter the code you received: ')
            await client.sign_in(phone, code)
            print("Signed in successfully!")
        except errors.SessionPasswordNeededError:
             pwd = input("Two-factor authentication password needed: ")
             await client.sign_in(password=pwd)
             print("Signed in successfully with 2FA!")
        except Exception as e:
            print(f"ERROR signing in: {e}")
    print("Disconnecting...")
    await client.disconnect()
    print(f"Authorization process complete. Session file '{session_name}.session' should be updated/created.")

# Run the async function
# asyncio.run(run_auth()) # Standard way, but might have loop issues on some OS configs
# Manual loop creation/running often more compatible in simple scripts
try:
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run_auth())
except RuntimeError: # Handle if loop already running (e.g., in some IDEs)
    asyncio.run(run_auth()) # Fallback
except KeyboardInterrupt:
    print("Cancelled.")