#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any, Dict, Tuple

try:
    import yaml  # PyYAML
except ImportError:
    print("ERROR: PyYAML is required (pip install pyyaml).", file=sys.stderr)
    sys.exit(2)

BEGIN = "<!-- BEGIN MCIX-ACTION-DOCS -->"
END = "<!-- END MCIX-ACTION-DOCS -->"

REPO_SLUG = "${{ github.repository }}"
DEFAULT_VERSION = "v1"  # placeholder in generated usage lines


def load_yaml(path: Path) -> Dict[str, Any]:
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def normalize_md(text: str) -> str:
    text = re.sub(r"[ \t]+(\r?\n)", r"\1", text)
    if not text.endswith("\n"):
        text += "\n"
    return text


def md_escape(s: str) -> str:
    return str(s).replace("|", r"\|").strip()


def infer_namespace_action(action_dir: Path) -> Tuple[str, str]:
    return action_dir.parent.name, action_dir.name


def marker_wrap(block: str) -> str:
    return normalize_md(f"{BEGIN}\n{block.rstrip()}\n{END}\n")


def looks_boolean_input(name: str, meta: Dict[str, Any]) -> bool:
    """
    Heuristic detection of boolean-style inputs.
    """
    desc = str(meta.get("description", "")).lower()
    name_l = name.lower()

    if "(true/false)" in desc:
        return True

    # Common MCIX boolean naming conventions
    for prefix in ("include-", "ignore-", "enable-", "disable-"):
        if name_l.startswith(prefix):
            return True

    return False


def extract_marker_block(readme: str) -> Tuple[str, str, str]:
    """
    Returns (prefix, existing_block, suffix).
    If markers missing, existing_block is "" and prefix is whole file.
    """
    if BEGIN not in readme or END not in readme:
        return readme.rstrip() + "\n\n", "", ""

    # Non-greedy match
    pattern = re.compile(
        re.escape(BEGIN) + r".*?" + re.escape(END),
        re.DOTALL,
    )
    m = pattern.search(readme)
    if not m:
        return readme.rstrip() + "\n\n", "", ""

    prefix = readme[: m.start()]
    existing = readme[m.start() : m.end()]
    suffix = readme[m.end() :]
    return prefix, existing, suffix


def infer_project_selection_rules(inputs: Dict[str, Any]) -> str | None:
    """
    Heuristic: if action has 'project' and/or 'project-id' inputs, generate the rule text.
    Customize here if you standardize other naming.
    """
    keys = {k.lower() for k in inputs.keys()}
    has_project = "project" in keys
    has_project_id = "project-id" in keys or "project_id" in keys
    if not (has_project or has_project_id):
        return None

    parts = []
    parts.append("### Project selection rules")
    parts.append("")
    if has_project and has_project_id:
        parts.append("- Provide **exactly one** of `project` or `project-id`.")
        parts.append("- If both are supplied, the action should fail fast (ambiguous).")
    elif has_project:
        parts.append("- Use `project` to select the target project by name.")
    else:
        parts.append("- Use `project-id` to select the target project by ID.")
    parts.append("")
    return "\n".join(parts)


def build_generated_block(action_dir: Path, meta: Dict[str, Any]) -> str:
    ns, act = infer_namespace_action(action_dir)

    name = str(meta.get("name") or f"{ns}/{act}").strip()
    description = str(meta.get("description") or "").strip()

    inputs: Dict[str, Any] = meta.get("inputs") or {}
    outputs: Dict[str, Any] = meta.get("outputs") or {}

    runs: Dict[str, Any] = meta.get("runs") or {}
    using = str(runs.get("using") or "").strip()
    image = str(runs.get("image") or "").strip()

    usage_ref = f"{REPO_SLUG}/{ns}/{act}@{DEFAULT_VERSION}"

    out = []
    out.append(f"# {name}")
    out.append("")
    if description:
        out.append(description)
        out.append("")
    out.append(f"> Namespace: `{ns}`  ")
    out.append(f"> Action: `{act}`  ")
    out.append(f"> Usage: `{usage_ref}`")
    out.append("")
    out.append(f"... where `{DEFAULT_VERSION}` is the version of the action you wish to use.")
    out.append("")
    out.append("---")
    out.append("")
    out.append("## 🚀 Usage")
    out.append("")
    out.append("Minimal example:")
    out.append("")
    out.append("```yaml")
    out.append("jobs:")
    out.append(f"  {ns}-{act}:")
    out.append("    runs-on: ubuntu-latest")
    out.append("")
    out.append("    steps:")
    out.append("      - name: Checkout repository")
    out.append("        uses: actions/checkout@v4")
    out.append("")
    out.append(f"      - name: Run {name}")
    out.append(f"        id: {ns}-{act}")
    out.append(f"        uses: {usage_ref}")
    if inputs:
        out.append("        with:")
        # show required inputs first, then optional
        required_keys = [k for k, v in inputs.items() if bool((v or {}).get("required", False))]
        optional_keys = [k for k in inputs.keys() if k not in required_keys]
        for k in required_keys + optional_keys:
            v = inputs[k] or {}
            required = bool(v.get("required", False))
            default = v.get("default", None)
            if required:
                out.append(f"          {k}: <required>")
            else:
                if default in (None, ""):
                    if looks_boolean_input(k, v):
                        out.append(f"          # {k}: false")
                    else:
                        out.append(f"          # {k}: <optional>")
                else:
                    out.append(f"          # {k}: {default}")
    out.append("```")
    out.append("")
    out.append("---")
    out.append("")

    rules = infer_project_selection_rules(inputs)
    if rules:
        out.append(rules)
        out.append("---")
        out.append("")

    if inputs:
        out.append("## 🔧 Inputs")
        out.append("")
        out.append("| Name | Required | Default | Description |")
        out.append("| --- | --- | --- | --- |")
        for k, v in inputs.items():
            v = v or {}
            req = "✅" if bool(v.get("required", False)) else "❌"
            default = v.get("default", "")
            if default in (None, ""):
                if looks_boolean_input(k, v):
                    default_cell = "false (if omitted)"
                else:
                    default_cell = ""
            else:
                default_cell = md_escape(default)
            desc = md_escape(v.get("description", ""))
            out.append(f"| `{k}` | {req} | {default_cell} | {desc} |")
        out.append("")
        out.append("---")
        out.append("")

    # Outputs may vary: generate if present, otherwise explicitly say none
    out.append("## 📤 Outputs")
    out.append("")
    if outputs:
        out.append("| Name | Description |")
        out.append("| --- | --- |")
        for k, v in outputs.items():
            v = v or {}
            desc = md_escape(v.get("description", ""))
            out.append(f"| `{k}` | {desc} |")
        out.append("")
    else:
        out.append("_This action does not declare any outputs in `action.yml`._")
        out.append("")

    out.append("---")
    out.append("")
    out.append("## 🧱 Implementation details")
    out.append("")
    out.append(f"- `runs.using`: `{using or 'N/A'}`")
    if image:
        out.append(f"- `runs.image`: `{image}`")
    out.append("")
    out.append("---")
    out.append("")
    out.append("## 🧩 Notes")
    out.append("")
    out.append("- The section above is auto-generated from `action.yml`.")
    out.append("- To edit documentation, update `action.yml` (name/description/inputs/outputs).")
    out.append("")

    return normalize_md("\n".join(out)).rstrip("\n")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    action_yamls = sorted(repo_root.glob("*/*/action.yml"))

    if not action_yamls:
        print("No */*/action.yml files found. Nothing to do.")
        return 0

    changed = 0
    for action_yml in action_yamls:
        action_dir = action_yml.parent
        meta = load_yaml(action_yml)

        readme_path = action_dir / "README.md"
        existing_readme = readme_path.read_text(encoding="utf-8") if readme_path.exists() else ""

        prefix, _existing_block, suffix = extract_marker_block(existing_readme)
        new_block = marker_wrap(build_generated_block(action_dir, meta))

        # If README didn’t exist, prefix will be "\n\n" etc; handle cleanly
        if BEGIN not in existing_readme or END not in existing_readme:
            # If there's hand-written content already, keep it, then append block
            new_readme = normalize_md(prefix.rstrip() + "\n\n" + new_block + suffix.lstrip())
        else:
            new_readme = normalize_md(prefix.rstrip() + "\n\n" + new_block + suffix.lstrip())

        if existing_readme != new_readme:
            readme_path.write_text(new_readme, encoding="utf-8")
            print(f"Updated {readme_path.relative_to(repo_root)}")
            changed += 1

    print(f"Done. README files updated: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
