# Security Guidelines for MQL5 Project

## Overview
This document outlines security best practices for handling API keys, tokens, and sensitive credentials in this MQL5 project.

## Issues Found and Fixed
**Date: March 16, 2026**

### Exposed Credentials Rectified:
1. ✅ **wstradecopier.mq5** - Removed exposed SubscriberAccessKey
   - Location: `NEWSCOLLECTIONS/2025NEWSbeta/04_mql5book/` and `NEWSCOLLECTIONS/2025NEWS/`
   - Action: Replaced hardcoded key with `YOUR_SUBSCRIBER_ACCESS_KEY_HERE` placeholder
   
2. ✅ **ai_server.py** - Secured API key handling
   - Locations: `2025_AI_BETA/AI_Powered_Scalper2/Python/` and `AI_Powered_Scalper1/`
   - Action: Converted to environment-variable-only pattern with validation
   
3. ✅ **Telegram Bot Tokens** - Secured placeholder values
   - Locations: `2025_AI_BETA/PROJECT_714/714_system/`
   - Action: Replaced with empty strings and added security comments

## Best Practices

### 1. Never Commit Secrets
- **DO NOT** hardcode API keys, tokens, passwords, or any credentials in code
- **DO NOT** commit `.env` files or credential files to git
- **DO** use `.gitignore` to exclude sensitive files (see template below)

### 2. Use Environment Variables
```mql5
// BAD - NEVER DO THIS
input string api_key = "sk_live_abc123xyz"; // EXPOSED!

// GOOD - Use environment variables
string api_key = os.environ.get("API_KEY", "")
if (api_key == "") {
    Print("Error: API_KEY environment variable not set");
    return;
}
```

### 3. Python Applications
```python
# BAD - NEVER DO THIS
API_KEY = "your_actual_key_here"

# GOOD - Use environment variables
import os
API_KEY = os.environ.get("API_KEY", "")
if not API_KEY:
    raise ValueError("API_KEY environment variable not set")
```

### 4. Configuration Management
- Use external configuration files (not in git)
- Use environment-specific configs (dev.env, prod.env)
- Keep a template file (config.example.env) for documentation

### 5. Secret Rotation
- Rotate API keys regularly
- Use short-lived tokens when possible
- Monitor API key usage and invalidate compromised keys immediately

### 6. Access Control
- Use role-based access control (RBAC) for different environments
- Limit API key permissions to minimum required scope
- Separate keys for development, testing, and production

## Setting Up Environment Variables

### Windows (PowerShell)
```powershell
$env:DEEPSEEK_API_KEY = "your_actual_key"
$env:SUBSCRIBER_ACCESS_KEY = "your_key"
```

### Windows (Command Prompt)
```cmd
set DEEPSEEK_API_KEY=your_actual_key
set SUBSCRIBER_ACCESS_KEY=your_key
```

### Linux/Mac (Bash)
```bash
export DEEPSEEK_API_KEY="your_actual_key"
export SUBSCRIBER_ACCESS_KEY="your_key"
```

### Persistent Environment Variables (.env file)
Create a `.env` file in your project root (make sure it's in .gitignore):
```
DEEPSEEK_API_KEY=your_actual_key
SUBSCRIBER_ACCESS_KEY=your_key
TELEGRAM_BOT_TOKEN=your_token
```

Load it using appropriate tools:
- Python: `python-dotenv` library
- Node.js: `dotenv` package

## Credential Scanning

### Pre-commit Hook (Recommended)
Implement a pre-commit hook to prevent accidental commits of secrets:
```bash
# Install git-secrets or similar tool
pip install detect-secrets
```

### Files to Monitor
- `.env`, `.env.*`
- `config.json`, `credentials.json`
- `.aws/`, `.azure/`, `.gcp/` directories
- Files containing: api_key, token, secret, password, bearer

## Incident Response

If credentials are exposed:
1. **Immediately revoke** the exposed key/token
2. **Rotate all credentials** affected
3. **Check logs** for unauthorized access
4. **Update code** to remove hardcoded credentials
5. **Force password changes** if applicable
6. **Inform security team** and affected parties
7. **Update repository history** if needed

## References
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [Git Secrets Protection](https://github.com/awslabs/git-secrets)
- [MetaQuotes Security Guidelines](https://www.mql5.com/)

---
Last Updated: March 16, 2026
Security Officer: Automated Scanner
