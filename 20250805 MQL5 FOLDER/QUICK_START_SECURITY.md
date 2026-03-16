# Quick Start: Security Setup Guide

**Time to complete:** 5 minutes  
**Difficulty:** Beginner-friendly

---

## Step 1: Copy the Environment Template (1 min)

```bash
# Copy the template file
cp .env.example .env

# On Windows (PowerShell)
Copy-Item .env.example .env
```

---

## Step 2: Add Your Credentials (2 min)

Open `.env` file in your text editor and fill in your actual values:

```env
DEEPSEEK_API_KEY=sk_your_actual_key_here
TELEGRAM_BOT_TOKEN=123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh
SUBSCRIBER_ACCESS_KEY=your_secure_key_here
```

**⚠️ IMPORTANT:** 
- `.env` is already in `.gitignore` - it won't be committed
- Never share your `.env` file
- Never paste `.env` content into chat or emails

---

## Step 3: Load Environment Variables (1 min)

### Option A: Windows (PowerShell)
```powershell
# Run this in PowerShell before starting your application
$env:DEEPSEEK_API_KEY = "your_key_from_.env"
$env:TELEGRAM_BOT_TOKEN = "your_token_from_.env"
$env:SUBSCRIBER_ACCESS_KEY = "your_key_from_.env"
```

### Option B: Windows (Command Prompt)
```cmd
set DEEPSEEK_API_KEY=your_key_from_.env
set TELEGRAM_BOT_TOKEN=your_token_from_.env
set SUBSCRIBER_ACCESS_KEY=your_key_from_.env
```

### Option C: Linux/Mac (Bash)
```bash
# Add to your ~/.bashrc or ~/.zshrc
export DEEPSEEK_API_KEY="your_key_from_.env"
export TELEGRAM_BOT_TOKEN="your_token_from_.env"
export SUBSCRIBER_ACCESS_KEY="your_key_from_.env"

# Then reload:
source ~/.bashrc  # or source ~/.zshrc
```

### Option D: Python (Automatic)
```python
# Install python-dotenv if not already installed
pip install python-dotenv

# Add this to the beginning of your Python file
from dotenv import load_dotenv
load_dotenv()  # This automatically loads .env file
```

---

## Step 4: Verify Setup (1 min)

### For Python Applications
```bash
# Run your Python app
python ai_server.py

# Should NOT show: "DEEPSEEK_API_KEY environment variable is not set"
# If it does, go back to Step 2-3 and check your setup
```

### For MQL5 Applications
1. Open the EA in MetaEditor
2. Check the inputs - you should see placeholders like `"YOUR_SUBSCRIBER_ACCESS_KEY_HERE"`
3. In MT5, right-click the EA and select "Properties"
4. Fill in actual credentials in the settings
5. **Never hardcode credentials in the code itself**

---

## Common Issues & Solutions

### Python Says: "DEEPSEEK_API_KEY environment variable is not set"
**Problem:** Environment variable not set  
**Solution:**
```bash
# Linux/Mac - Add to your shell
export DEEPSEEK_API_KEY="your_actual_key"

# Windows PowerShell
$env:DEEPSEEK_API_KEY = "your_actual_key"

# Or use .env file with python-dotenv
pip install python-dotenv
```

### git Says: "fatal: .env is untracked"
**Problem:** .env file isn't in .gitignore  
**Solution:**
```bash
# Check if .gitignore exists and contains .env
cat .gitignore | grep ".env"

# Should output: .env
# If not, the .gitignore file in this repo already has it
```

### "ModuleNotFoundError: No module named 'dotenv'"
**Problem:** python-dotenv not installed  
**Solution:**
```bash
pip install python-dotenv
```

---

## Best Practices Checklist

- [ ] Created `.env` file from `.env.example`
- [ ] Added real credentials to `.env` (not placeholders)
- [ ] `.env` is in `.gitignore` (preventing accidental commits)
- [ ] Environment variables are set before running applications
- [ ] Never pasted credentials in code comments
- [ ] Never shared `.env` file with anyone
- [ ] Credentials are stored securely (not in public repositories)
- [ ] Reviewed `SECURITY_README.md` for detailed guidelines

---

## Need Help?

1. **Quick questions?** → Read `SECURITY_README.md`
2. **Detailed audit?** → Check `CREDENTIALS_REMEDIATION_REPORT.md`
3. **Full verification?** → Review `VERIFICATION_CHECKLIST.md`
4. **Long-term security?** → Follow recommendations in the report

---

## Remember: Golden Rules

✅ **DO:**
- Use `.env` for local development
- Use environment variables
- Keep credentials in secure vaults (production)
- Rotate keys regularly
- Use different keys for different environments

❌ **DON'T:**
- Commit `.env` to git
- Hardcode credentials in source code
- Share credentials via chat, email, or tickets
- Use same keys for dev/staging/production
- Forget to set environment variables before running

---

**You're now secure! 🔒**

For more details, see `SECURITY_README.md`
