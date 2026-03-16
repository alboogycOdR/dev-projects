# Security Guidelines - tradingview

**Last Updated:** March 16, 2026  
**Status:** ✅ Scanned - No exposed credentials found

## Security Scan Results

✅ **No exposed API keys, tokens, or credentials detected**
✅ **tradingview folder is secure**

## Pine Script Security Best Practices

### Credential Handling
```pine
// For webhook notifications, never hardcode URLs with tokens
// Instead, use:
// 1. Environment-based injection
// 2. Parameters with placeholders
// 3. Secure configuration files
```

### No Hardcoded Secrets
- Never include API keys in published scripts
- Never commit telegram tokens or webhook URLs
- Use placeholders for sensitive parameters

## Security Guidelines for TradingView Scripts

1. **Don't embed credentials** in Pine Script code
2. **Use parameters** for user-configurable values
3. **Document required setup** in comments
4. **Use external services** for sensitive operations

## Maintenance
- Review scripts before publishing
- Use `.gitignore` to protect config files
- Never commit test scripts with real credentials

For more details, see project-specific documentation.
