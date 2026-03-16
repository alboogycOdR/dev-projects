# Security Guidelines - tradingviewlabs

**Last Updated:** March 16, 2026  
**Status:** ✅ Scanned - No exposed credentials found

## Security Scan Results

✅ **No exposed API keys, tokens, or credentials detected**
✅ **tradingviewlabs folder is secure**

## Script Security Best Practices

### Protecting Your Indicators
1. **Never hardcode API keys** in your scripts
2. **Never include webhook tokens** in published code
3. **Use parameters** for user configuration
4. **Document security requirements** clearly

### Example Good Practices
```
// Instead of hardcoding:
webhook_url = "https://hooks.slack.com/services/TOKEN/HERE"

// Use parameter:
input string webhookUrl = ""  // User provides this
```

## Security Checklist
- [ ] No API keys in code
- [ ] No tokens in scripts
- [ ] No hardcoded URLs with secrets
- [ ] `.gitignore` configured
- [ ] Credentials documented separately

## Maintenance
- Review before publishing to market
- Keep sensitive configs in `.gitignore`
- Rotate any exposed credentials

For detailed security guidelines, see root SECURITY_README.md
