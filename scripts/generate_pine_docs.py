#!/usr/bin/env python3

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

WORKSPACE_ROOT = Path("/workspace")
DOCS_ROOT = WORKSPACE_ROOT / "docs"

# ---------------------------
# Helpers
# ---------------------------

def read_text(path: Path) -> str:
	with path.open("r", encoding="utf-8", errors="ignore") as f:
		return f.read()


def ensure_dir(path: Path) -> None:
	path.mkdir(parents=True, exist_ok=True)


def write_text(path: Path, content: str) -> None:
	ensure_dir(path.parent)
	with path.open("w", encoding="utf-8") as f:
		f.write(content)


# ---------------------------
# Pine parsing (best-effort heuristics)
# ---------------------------

STRING_RE = r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\""

DECLARATION_RE = re.compile(
	rf"(?m)^\s*(?P<kind>indicator|strategy|study)\s*\((?P<args>.*)\)",
	re.DOTALL,
)

VERSION_RE = re.compile(r"(?m)^\s*\/\/@version\s+(?P<version>\d+)")

# Matches: varName = input*(...)
INPUT_ASSIGN_RE = re.compile(
	rf"(?m)^\s*(?P<var>[a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(?P<call>input[a-zA-Z0-9_]*\s*\((?P<args>[^\)]*)\))"
)

# Standalone input*(...) calls (without direct assignment)
INPUT_CALL_RE = re.compile(rf"(?m)^\s*(?P<call>input[a-zA-Z0-9_]*\s*\((?P<args>[^\)]*)\))")

ALERTCOND_RE = re.compile(
	rf"(?m)^\s*alertcondition\s*\((?P<args>[^\)]*)\)"
)

PLOT_CALL_RE = re.compile(
	rf"(?m)^\s*(?P<fn>plot(?:shape|char|bar|candle)?|hline)\s*\((?P<args>[^\)]*)\)"
)

STRATEGY_CALL_RE = re.compile(
	rf"(?m)^\s*strategy\.(?P<fn>entry|exit|order|close|close_all|cancel)\s*\((?P<args>[^\)]*)\)"
)

STRING_LITERAL_RE = re.compile(rf"{STRING_RE}")

KWARG_TITLE_RE = re.compile(rf"(?<![a-zA-Z0-9_])title\s*=\s*({STRING_RE})")
KWARG_SHORTTITLE_RE = re.compile(rf"(?<![a-zA-Z0-9_])shorttitle\s*=\s*({STRING_RE})")
KWARG_MSG_RE = re.compile(rf"(?<![a-zA-Z0-9_])message\s*=\s*({STRING_RE})")


def unquote(s: str) -> str:
	if len(s) >= 2 and ((s[0] == s[-1] == '"') or (s[0] == s[-1] == "'")):
		return s[1:-1]
	return s


def first_string_literal(text: str) -> Optional[str]:
	m = STRING_LITERAL_RE.search(text)
	return unquote(m.group(0)) if m else None


def kwarg_string(text: str, key: str) -> Optional[str]:
	if key == "title":
		m = KWARG_TITLE_RE.search(text)
	elif key == "shorttitle":
		m = KWARG_SHORTTITLE_RE.search(text)
	elif key == "message":
		m = KWARG_MSG_RE.search(text)
	else:
		return None
	return unquote(m.group(1)) if m else None


@dataclass
class PineDoc:
	path: Path
	kind: str  # indicator | strategy | study
	title: Optional[str]
	shorttitle: Optional[str]
	version: Optional[str]
	inputs: List[Dict[str, Optional[str]]]
	alerts: List[Dict[str, Optional[str]]]
	plots: List[Dict[str, Optional[str]]]
	orders: List[Dict[str, Optional[str]]]


# Python 3.7 compatibility for dataclass import
try:
	from dataclasses import dataclass
except Exception:
	def dataclass(cls):
		return cls


def parse_declaration(source: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
	m = DECLARATION_RE.search(source)
	if not m:
		return None, None, None
	kind = m.group("kind")
	args = m.group("args")
	# Try explicit title/shorttitle kwargs first
	title = kwarg_string(args, "title")
	shorttitle = kwarg_string(args, "shorttitle")
	# If no explicit title, try first string literal
	if title is None:
		fs = first_string_literal(args)
		if fs:
			title = fs
	return kind, title, shorttitle


def parse_version(source: str) -> Optional[str]:
	m = VERSION_RE.search(source)
	return m.group("version") if m else None


def parse_inputs(source: str) -> List[Dict[str, Optional[str]]]:
	results: List[Dict[str, Optional[str]]] = []
	seen_spans: List[Tuple[int, int]] = []
	# Prefer assigned inputs to capture variable names
	for m in INPUT_ASSIGN_RE.finditer(source):
		var = m.group("var")
		call = m.group("call")
		args = m.group("args")
		seen_spans.append(m.span())
		item = {
			"var": var,
			"fn": call.split("(", 1)[0].strip(),
			"label": kwarg_string(args, "title") or first_string_literal(args),
			"default": None,
			"raw": call,
		}
		results.append(item)
	# Also capture standalone input calls not already covered
	for m in INPUT_CALL_RE.finditer(source):
		span = m.span()
		if any(a <= span[0] and span[1] <= b for a, b in seen_spans):
			continue
		call = m.group("call")
		args = m.group("args")
		item = {
			"var": None,
			"fn": call.split("(", 1)[0].strip(),
			"label": kwarg_string(args, "title") or first_string_literal(args),
			"default": None,
			"raw": call,
		}
		results.append(item)
	return results


def parse_alerts(source: str) -> List[Dict[str, Optional[str]]]:
	alerts: List[Dict[str, Optional[str]]] = []
	for m in ALERTCOND_RE.finditer(source):
		args = m.group("args")
		# Try to find second and third string literals for title and message
		strings = [unquote(s) for s in STRING_LITERAL_RE.findall(args)]
		title = None
		message = None
		if len(strings) >= 1:
			# title could be explicit title= or second positional
			title = kwarg_string(args, "title") or (strings[0] if len(strings) == 1 else strings[1])
		if len(strings) >= 2:
			# message could be explicit message= or next positional
			message = kwarg_string(args, "message") or (strings[-1] if len(strings) >= 2 else None)
		alerts.append({"title": title, "message": message, "raw": m.group(0)})
	return alerts


def parse_plots(source: str) -> List[Dict[str, Optional[str]]]:
	plots: List[Dict[str, Optional[str]]] = []
	for m in PLOT_CALL_RE.finditer(source):
		fn = m.group("fn")
		args = m.group("args")
		title = kwarg_string(args, "title") or None
		if title is None:
			# If no explicit title, sometimes a string literal is passed as a param (rare)
			lit = first_string_literal(args)
			if lit:
				title = lit
		plots.append({"fn": fn, "title": title, "raw": m.group(0)})
	return plots


def parse_orders(source: str) -> List[Dict[str, Optional[str]]]:
	orders: List[Dict[str, Optional[str]]] = []
	for m in STRATEGY_CALL_RE.finditer(source):
		fn = m.group("fn")
		args = m.group("args")
		name = first_string_literal(args)
		orders.append({"fn": fn, "name": name, "raw": m.group(0)})
	return orders


def parse_pine(path: Path) -> PineDoc:
	source = read_text(path)
	kind, title, shorttitle = parse_declaration(source)
	version = parse_version(source)
	inputs = parse_inputs(source)
	alerts = parse_alerts(source)
	plots = parse_plots(source)
	orders = parse_orders(source)
	return PineDoc(
		path=path,
		kind=kind or "indicator",
		title=title,
		shorttitle=shorttitle,
		version=version,
		inputs=inputs,
		alerts=alerts,
		plots=plots,
		orders=orders,
	)


# ---------------------------
# Markdown generation
# ---------------------------

def rel_path(p: Path) -> str:
	try:
		return str(p.relative_to(WORKSPACE_ROOT))
	except ValueError:
		return str(p)


def md_esc(text: Optional[str]) -> str:
	if text is None:
		return ""
	return text.replace("\n", " ")


def render_inputs(doc: PineDoc) -> str:
	if not doc.inputs:
		return "No user inputs.\n"
	lines = ["- **Inputs**:"]
	for it in doc.inputs:
		label = md_esc(it.get("label")) or "(untitled)"
		var = it.get("var") or "(unassigned)"
		fn = it.get("fn") or "input"
		lines.append(f"  - `{var}`: {fn} — {label}")
	return "\n".join(lines) + "\n"


def render_alerts(doc: PineDoc) -> str:
	if not doc.alerts:
		return "No alerts defined.\n"
	lines = ["- **Alerts**:"]
	for al in doc.alerts:
		title = md_esc(al.get("title")) or "(untitled)"
		message = md_esc(al.get("message")) or ""
		msg = f" — {message}" if message else ""
		lines.append(f"  - {title}{msg}")
	return "\n".join(lines) + "\n"


def render_plots(doc: PineDoc) -> str:
	if not doc.plots:
		return "No plots.\n"
	lines = ["- **Plots**:"]
	for pl in doc.plots:
		title = md_esc(pl.get("title")) or "(untitled)"
		fn = pl.get("fn") or "plot"
		lines.append(f"  - {fn}: {title}")
	return "\n".join(lines) + "\n"


def render_orders(doc: PineDoc) -> str:
	if not doc.orders:
		return "No strategy orders.\n"
	lines = ["- **Strategy orders**:"]
	for od in doc.orders:
		name = md_esc(od.get("name")) or "(unnamed)"
		fn = od.get("fn")
		lines.append(f"  - {fn}: {name}")
	return "\n".join(lines) + "\n"


def generate_usage(doc: PineDoc) -> str:
	base = [
		"### Usage",
	]
	if doc.kind == "strategy":
		base.extend([
			"- **Add to chart**: Open the Pine editor in TradingView, paste the script, click Add to chart.",
			"- **Backtest**: Open Strategy Tester, configure initial capital/commission, and time range.",
			"- **Configure inputs**: Adjust the inputs listed above to suit your market and timeframe.",
			"- **Alerts**: If alerts exist, create an alert and select one of this strategy's alert conditions.",
		])
	else:
		base.extend([
			"- **Add to chart**: Open the Pine editor in TradingView, paste the script, click Add to chart.",
			"- **Configure inputs**: Adjust the inputs listed above to suit your market and timeframe.",
			"- **Alerts**: If alerts exist, create an alert and select one of this indicator's alert conditions.",
		])
	return "\n".join(base) + "\n"


def generate_example(doc: PineDoc) -> str:
	name = doc.title or doc.shorttitle or doc.path.stem
	return (
		"### Example\n"
		"```text\n"
		f"Add '{name}' to the chart and enable relevant inputs.\n"
		"Create an alert using one of the documented conditions.\n"
		"Backtest using Strategy Tester if this is a strategy.\n"
		"```\n"
	)


def render_doc(doc: PineDoc) -> str:
	title = doc.title or doc.shorttitle or doc.path.stem
	kind = doc.kind.capitalize() if doc.kind else "Indicator"
	version = doc.version or "(unspecified)"
	out = []
	out.append(f"## {title}")
	out.append("")
	out.append(f"- **Type**: {kind}")
	out.append(f"- **Path**: `{rel_path(doc.path)}`")
	out.append(f"- **Pine version**: {version}")
	out.append("")
	out.append("### Overview")
	out.append("This document summarizes public inputs, plots, alerts, and strategy order calls discovered in the script.")
	out.append("")
	out.append(render_inputs(doc))
	out.append(render_plots(doc))
	out.append(render_alerts(doc))
	out.append(render_orders(doc))
	out.append(generate_usage(doc))
	out.append(generate_example(doc))
	return "\n".join(out)


def generate_docs_for_file(p: Path) -> Path:
	doc = parse_pine(p)
	rel = p.relative_to(WORKSPACE_ROOT)
	dest = DOCS_ROOT / rel.with_suffix(".md")
	content = render_doc(doc)
	write_text(dest, content)
	return dest


def group_by_dir(paths: List[Path]) -> Dict[Path, List[Path]]:
	groups: Dict[Path, List[Path]] = {}
	for p in paths:
		rel_dir = p.parent.relative_to(WORKSPACE_ROOT)
		groups.setdefault(rel_dir, []).append(p)
	return groups


def make_index(all_docs: List[Path]) -> None:
	groups = group_by_dir(all_docs)
	lines: List[str] = []
	lines.append("## Documentation Index")
	lines.append("")
	for grp in sorted(groups.keys(), key=lambda x: str(x)):
		lines.append(f"### `{grp}`")
		for p in sorted(groups[grp], key=lambda x: str(x)):
			rel = p.relative_to(DOCS_ROOT)
			title = p.stem
			lines.append(f"- **{title}**: `docs/{rel}`")
		lines.append("")
	write_text(DOCS_ROOT / "index.md", "\n".join(lines))


def make_readme() -> None:
	content = (
		"## Project Documentation\n\n"
		"This repository contains multiple TradingView Pine Script indicators and strategies.\n\n"
		"- Documentation is generated into the `docs/` directory.\n"
		"- See `docs/index.md` for a full index of generated pages.\n\n"
		"### Regenerating documentation\n\n"
		"Run the generator from the repository root:\n\n"
		"```bash\n"
		"python3 scripts/generate_pine_docs.py\n"
		"```\n\n"
		"### Scope\n\n"
		"The generator extracts best-effort metadata: declaration (indicator/strategy), inputs, plots, alerts, and strategy orders.\n"
		"It does not execute the code and may miss items constructed dynamically.\n"
	)
	write_text(WORKSPACE_ROOT / "README.md", content)


def find_pine_files(root: Path) -> List[Path]:
	files: List[Path] = []
	for dirpath, dirnames, filenames in os.walk(root):
		for fn in filenames:
			if fn.endswith(".pine"):
				files.append(Path(dirpath) / fn)
	return files


def main() -> int:
	ensure_dir(DOCS_ROOT)
	pine_files = find_pine_files(WORKSPACE_ROOT)
	if not pine_files:
		print("No .pine files found.")
		return 0
	generated: List[Path] = []
	for p in pine_files:
		out = generate_docs_for_file(p)
		generated.append(out)
	make_index(generated)
	make_readme()
	print(f"Generated {len(generated)} documentation files under {DOCS_ROOT}")
	return 0


if __name__ == "__main__":
	sys.exit(main())