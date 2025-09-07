# Installation Guide for 714EA V8.00

This guide provides step-by-step instructions to correctly install and configure the SevenOneFourEA and its required components in your MetaTrader 5 terminal.

## Step 1: File Placement

You need to place two main components in the correct folders within your MT5 Data Folder.

1.  **Open the MT5 Data Folder**: In your MT5 terminal, go to `File` -> `Open Data Folder`. This will open the main directory where MT5 stores all its custom files.
2.  **Place the EA File**:
    *   Navigate to `MQL5` -> `Experts`.
    *   Copy the `714EA_800.mq5` file into this `Experts` folder.
3.  **Place the Custom Indicator**:
    *   The EA relies on the `SmartMoneyConcepts` indicator. This must be placed in a specific sub-folder.
    *   Navigate to `MQL5` -> `Indicators`.
    *   Create a new folder here named `2025SMART`.
    *   Copy the `SmartMoneyConcepts.ex5` (or `.mq5`) file into this `2025SMART` folder.

    The final path for the indicator must be: `MQL5\Indicators\2025SMART\SmartMoneyConcepts.ex5`

4.  **Refresh Your Navigator**:
    *   Return to your MT5 terminal.
    *   In the "Navigator" panel (usually on the left), right-click on "Expert Advisors" and select "Refresh".
    *   You should now see `714EA_800` listed under the `Experts` tree.

## Step 2: Configure MetaTrader 5 Options for Alerts

For the screenshot and Telegram alert features to work, you must enable two settings in the main MT5 options.

1.  Go to `Tools` -> `Options` in the main menu.
2.  Select the **"Expert Advisors"** tab.
3.  **Allow DLL Imports**:
    *   Check the box for `Allow DLL imports`. This is **required** for the `ChartScreenShot()` function to work.
4.  **Allow WebRequest**:
    *   Check the box for `Allow WebRequest for the following URLs:`.
    *   Click the `+` icon or "Add new URL" button.
    *   Enter the following URL exactly: `https://api.telegram.org`
    *   This is **required** to allow the EA to communicate with the Telegram Bot API.

![MT5 Options Configuration](https://i.imgur.com/8wV3v2k.png)

## Step 3: Configure Telegram Bot and Chat ID

To receive alerts, you must provide the EA with your unique Telegram Bot Token and Chat ID.

1.  **Create a Telegram Bot**:
    *   Open Telegram and search for the **BotFather**.
    *   Start a chat with BotFather and send the `/newbot` command.
    *   Follow the prompts to name your bot. BotFather will give you a unique **HTTP API token**. It will look something like `1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi`.
    *   **Copy this token.**
2.  **Get Your Chat ID**:
    *   **For personal alerts**: Search for the **`@userinfobot`** on Telegram, start it, and it will immediately tell you your Chat ID.
    *   **For channel alerts**: Add your bot to the desired channel as an administrator. Then send any message to the channel. Forward that message to `@userinfobot`, and it will reply with the channel's Chat ID (it usually starts with `-100...`).
3.  **Enter Credentials in the EA**:
    *   When you drag the `714EA_800` onto a chart, go to the "Inputs" tab.
    *   Find the `telegram_bot_token` parameter and paste your bot token.
    *   Find the `telegram_chat_id` parameter and paste your Chat ID.

## Step 4: Attach the EA to a Chart

1.  Open the chart and timeframe you wish to monitor (e.g., EURUSD, M5).
2.  Drag the `714EA_800` from the Navigator panel onto the chart.
3.  In the pop-up window, go to the "Common" tab and ensure **"Allow Algo Trading"** is checked.
4.  Go to the "Inputs" tab, review the settings (especially your Telegram credentials), and click "OK".

If everything is configured correctly, the EA will print its initialization messages in the "Experts" tab of the Terminal window, and you will see the session lines appear on your chart. 