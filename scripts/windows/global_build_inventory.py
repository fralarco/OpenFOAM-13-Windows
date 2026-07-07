#!/usr/bin/env python3
"""Inventory every wmake target in a native-Windows OpenFOAM-13 clone and check
whether its artifact (.dll / .exe) exists. Writes a JSON status file and prints a
per-group summary. Paths come from the environment so this is location-agnostic:

  WM_PROJECT_DIR / OF13_CLONE : the OpenFOAM-13-Windows working copy
  WM_OPTIONS                  : build variant (default mingw_w64GccDPInt32Opt)
  OF13_INVENTORY_OUT          : output JSON path (default <clone>/full_build_status.json)
"""
import json
import os
import re
import sys
from pathlib import Path

OF = Path(os.environ.get("WM_PROJECT_DIR")
          or os.environ.get("OF13_CLONE")
          or "/c/OF13WinNormal/OpenFOAM-13-Windows")
OPT = os.environ.get("WM_OPTIONS", "mingw_w64GccDPInt32Opt")
PLAT = OF / "platforms" / OPT
OUT = Path(os.environ.get("OF13_INVENTORY_OUT") or (OF / "full_build_status.json"))

VAR_RE = re.compile(r"^(LIB|EXE)\s*=\s*(.+?)\s*$", re.M)


def resolve(val: str) -> str:
    for k in ("FOAM_LIBBIN", "FOAM_USER_LIBBIN"):
        val = val.replace(f"$({k})", str(PLAT / "lib"))
    for k in ("FOAM_APPBIN", "FOAM_USER_APPBIN"):
        val = val.replace(f"$({k})", str(PLAT / "bin"))
    return val


def scan(tree: Path, kind: str):
    targets = []
    for mk in sorted(tree.rglob("Make/files")):
        rel = mk.parent.parent.relative_to(OF)
        if "codeTemplates" in str(rel) or "dummyThirdParty" in str(rel):
            continue
        m = VAR_RE.search(mk.read_text(errors="replace"))
        if not m:
            continue
        ttype, raw = m.group(1), m.group(2)
        artifact = Path(resolve(raw) + (".dll" if ttype == "LIB" else ".exe"))
        targets.append({
            "target": str(rel).replace("\\", "/"), "kind": kind, "type": ttype,
            "artifact": str(artifact), "built": artifact.exists(),
            "sizeBytes": artifact.stat().st_size if artifact.exists() else 0,
        })
    return targets


def main():
    groups = {
        "srcLibraries": scan(OF / "src", "src"),
        "solvers": scan(OF / "applications" / "solvers", "solver"),
        "modules": scan(OF / "applications" / "modules", "module"),
        "legacy": scan(OF / "applications" / "legacy", "legacy"),
        "utilities": scan(OF / "applications" / "utilities", "utility"),
    }
    summary = {}
    for name, targets in groups.items():
        built = sum(1 for t in targets if t["built"])
        summary[name] = {"total": len(targets), "built": built}
        print(f"{name}: {built}/{len(targets)} built")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "generated": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "clone": str(OF), "options": OPT,
        "summary": summary, "targets": groups,
    }, indent=1))
    print(f"JSON written: {OUT}")


if __name__ == "__main__":
    sys.exit(main())
