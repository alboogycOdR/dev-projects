@echo off
echo MetaTrader5 LLM Trading Bot Installation
echo =====================================
echo.

REM Create installation directory
mkdir "C:\Users\sousa\Documents\DataH\metatradebot2" 2>nul

REM Copy files to installation directory
echo Copying files to installation directory...
copy "app.py" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "indicators.py" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "prompts.py" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "utils.py" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "run.py" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "requirements.txt" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "README.md" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y
copy "run_bot.bat" "C:\Users\sousa\Documents\DataH\metatradebot2\" /Y

REM Install Python dependencies
echo Installing Python dependencies...
cd /d "C:\Users\sousa\Documents\DataH\metatradebot2"
pip install -r requirements.txt

echo.
echo Installation completed successfully!
echo You can run the application by double-clicking on run_bot.bat in the installation directory.
echo.
echo Press any key to exit...
pause > nul