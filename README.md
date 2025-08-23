## Project Documentation

This repository contains multiple TradingView Pine Script indicators and strategies.

- Documentation is generated into the `docs/` directory.
- See `docs/index.md` for a full index of generated pages.

### Regenerating documentation

Run the generator from the repository root:

```bash
python3 scripts/generate_pine_docs.py
```

### Scope

The generator extracts best-effort metadata: declaration (indicator/strategy), inputs, plots, alerts, and strategy orders.
It does not execute the code and may miss items constructed dynamically.
