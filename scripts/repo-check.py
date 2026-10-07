#!/usr/bin/env python3
"""Fast dependency-free repository consistency checks used locally and in CI."""
from __future__ import annotations

import ast
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def require(path: str) -> Path:
    p = ROOT / path
    if not p.exists():
        errors.append(f"missing required file: {path}")
    return p


required = [
    "app/api/app/main.py",
    "app/api/app/seed.py",
    "app/web/src/App.jsx",
    "infra/shared/main.tf",
    "infra/environments/dev/main.tf",
    "infra/environments/prod/main.tf",
    "infra/modules/aks/main.tf",
    "infra/modules/environment/main.tf",
    "helm/quiz-app/templates/configmap.yaml",
    "helm/quiz-app/templates/secretproviderclass.yaml",
    ".github/workflows/infrastructure.yml",
    ".github/workflows/app.yml",
]
for item in required:
    require(item)

# Exactly 20 seed questions.
seed_path = ROOT / "app/api/app/seed.py"
if seed_path.exists():
    tree = ast.parse(seed_path.read_text(encoding="utf-8"))
    seed_count = None
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "SEED_QUESTIONS" for t in node.targets):
            seed_count = len(ast.literal_eval(node.value))
            break
    if seed_count != 20:
        errors.append(f"expected 20 seed questions, found {seed_count}")

infra_workflow = (ROOT / ".github/workflows/infrastructure.yml").read_text(encoding="utf-8")
if "shared.tfstate" not in infra_workflow:
    errors.append("infrastructure workflow does not reference shared.tfstate")
if 'key=${{ inputs.environment }}.tfstate' not in infra_workflow:
    errors.append("infrastructure workflow must derive dev/prod state keys from inputs.environment")
for environment_name in ("dev", "prod"):
    if environment_name not in infra_workflow:
        errors.append(f"infrastructure workflow does not expose {environment_name} environment")
if "-lock-timeout=5m" not in infra_workflow:
    errors.append("Terraform workflow must use -lock-timeout=5m")
if "use_azuread_auth=true" not in infra_workflow or "use_oidc=true" not in infra_workflow:
    errors.append("Terraform backend must use Azure AD/OIDC authentication")

app_workflow = (ROOT / ".github/workflows/app.yml").read_text(encoding="utf-8")
for required_text in ("${{ github.sha }}", "helm upgrade --install", "curl --fail"):
    if required_text not in app_workflow:
        errors.append(f"app workflow missing: {required_text}")

values = (ROOT / "helm/quiz-app/values.yaml").read_text(encoding="utf-8")
if re.search(r"\btag:\s*latest\b", values):
    errors.append("Helm defaults must not use mutable latest image tags")

# Catch the HCL generation failure that places multiple block attributes on one line.
for tf in ROOT.glob("infra/**/*.tf"):
    text = tf.read_text(encoding="utf-8")
    # Basic delimiter balance after removing quoted strings and line comments.
    cleaned = re.sub(r'"(?:\\.|[^"\\])*"', '""', text)
    cleaned = re.sub(r"#.*", "", cleaned)
    if cleaned.count("{") != cleaned.count("}"):
        errors.append(f"unbalanced HCL braces: {tf.relative_to(ROOT)}")
    for lineno, line in enumerate(text.splitlines(), 1):
        if re.search(r'\{\s*(?:type|value|length|sample_size)\s*=.+\s+(?:default|sensitive|description|special|upper|successful_samples_required)\s*=', line):
            errors.append(f"multiple HCL block attributes on one line: {tf.relative_to(ROOT)}:{lineno}")

# No real subscription/tenant GUID should be committed; the all-zero example is allowed.
guid = re.compile(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b")
for path in ROOT.rglob("*"):
    if not path.is_file() or ".git" in path.parts or path.suffix in {".pyc", ".zip"}:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for match in guid.findall(text):
        if match.lower() != "00000000-0000-0000-0000-000000000000":
            errors.append(f"real-looking GUID committed in {path.relative_to(ROOT)}")
            break

if errors:
    print("Repository checks FAILED:")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("Repository checks passed.")
