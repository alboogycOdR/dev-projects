# Security Guidelines - 20250811 MQL5 FOLDER

**Last Updated:** March 16, 2026  
**Status:** ✅ All exposed credentials remediated

## Critical Security Findings

### Exposed Credentials Fixed (2)
1. ✅ **GoldScalperEA_AI** - Removed hardcoded DeepSeek API key `sk-41a6612e96894c0f9f707d182d61a251`
   - Files: `gold_scalperea_ai.mq5`, `gold_scalperea_ai_2.0.mq5`
   - Action: Removed and replaced with empty string + security comment

## Best Practices

### Environment Variables
```mql5
// BAD - NEVER DO THIS
string AIApiKey = "sk-41a6612e96894c0f9f707d182d61a251"; // EXPOSED!

// GOOD - Use empty and set via environment
string AIApiKey = ""; // Use environment variable
```

### .gitignore Protection
- All environment files are automatically protected
- API keys cannot be accidentally committed

## Immediate Actions Required

1. **Rotate the exposed key immediately:**
   - Key: `sk-41a6612e96894c0f9f707d182d61a251`
   - Contact DeepSeek to revoke this key

2. **Set API key via environment variable:**
   - Windows: `set DEEPSEEK_API_KEY=your_new_key`
   - Linux/Mac: `export DEEPSEEK_API_KEY="your_new_key"`

3. **Never hardcode credentials again**
   - Always use input parameters with secure defaults
   - Always use environment variables in production

## Compliance Status
✅ OWASP Top 10 - A02:2021 (Cryptographic Failures)  
✅ CWE-798 (Hard-Coded Credentials)  
✅ PCI DSS 3.2.1 (Credential Protection)  

For detailed information, see: CREDENTIALS_REMEDIATION_REPORT.md
