@echo off
echo ========================================
echo  Strength Meter + OB EA Installation
echo ========================================
echo.

REM Get the current directory
set "SOURCE_DIR=%~dp0"

REM Find MetaTrader 5 installation
set "MT5_DATA_PATH="
for /d %%i in ("%APPDATA%\MetaQuotes\Terminal\*") do (
    if exist "%%i\MQL5" (
        set "MT5_DATA_PATH=%%i\MQL5"
        goto :found
    )
)

:found
if "%MT5_DATA_PATH%"=="" (
    echo ERROR: MetaTrader 5 data folder not found!
    echo Please make sure MetaTrader 5 is installed and has been run at least once.
    pause
    exit /b 1
)

echo Found MetaTrader 5 data folder: %MT5_DATA_PATH%
echo.

REM Create directories if they don't exist
if not exist "%MT5_DATA_PATH%\Experts" mkdir "%MT5_DATA_PATH%\Experts"
if not exist "%MT5_DATA_PATH%\Include" mkdir "%MT5_DATA_PATH%\Include"

echo Installing EA files...

REM Copy main EA file
if exist "%SOURCE_DIR%StrengthMeter_OB_EA.mq5" (
    copy "%SOURCE_DIR%StrengthMeter_OB_EA.mq5" "%MT5_DATA_PATH%\Experts\" >nul
    echo ✓ StrengthMeter_OB_EA.mq5 copied to Experts folder
) else (
    echo ✗ StrengthMeter_OB_EA.mq5 not found in source directory
)

REM Copy enhanced order block library
if exist "%SOURCE_DIR%OrderBlock_Enhanced.mqh" (
    copy "%SOURCE_DIR%OrderBlock_Enhanced.mqh" "%MT5_DATA_PATH%\Include\" >nul
    echo ✓ OrderBlock_Enhanced.mqh copied to Include folder
) else (
    echo ✗ OrderBlock_Enhanced.mqh not found in source directory
)

echo.
echo ========================================
echo Installation completed!
echo ========================================
echo.
echo Next steps:
echo 1. Open MetaTrader 5
echo 2. Press F4 to open MetaEditor
echo 3. Navigate to Experts folder
echo 4. Double-click StrengthMeter_OB_EA.mq5
echo 5. Press F7 to compile
echo 6. Attach the EA to any chart
echo.
echo For detailed instructions, please read README.md
echo.
pause 