"""candidates.json / cameras.json のスキーマ検証。"""

from __future__ import annotations

import json
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent
CAMERA_SCHEMA = json.loads(
    (REPO_ROOT / "data" / "schema" / "camera.schema.json").read_text(encoding="utf-8"))
STATUS_SCHEMA = json.loads(
    (REPO_ROOT / "data" / "schema" / "status.schema.json").read_text(encoding="utf-8"))


def validate_camera_record(record: dict) -> list[str]:
    """1レコードを検証してエラー文字列のリストを返す（空なら合格）。"""
    validator = jsonschema.Draft202012Validator(CAMERA_SCHEMA)
    return [f"{'/'.join(str(p) for p in e.path)}: {e.message}"
            for e in validator.iter_errors(record)]


def validate_camera_file(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    errors: list[str] = []
    ids: set[str] = set()
    for i, rec in enumerate(data.get("cameras", [])):
        for msg in validate_camera_record(rec):
            errors.append(f"cameras[{i}] ({rec.get('id', '?')}): {msg}")
        rid = rec.get("id")
        if rid in ids:
            errors.append(f"cameras[{i}]: duplicate id {rid}")
        ids.add(rid)
    return errors


def validate_status_file(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(STATUS_SCHEMA)
    return [e.message for e in validator.iter_errors(data)]


if __name__ == "__main__":
    import sys
    failed = False
    for name, fn in [("data/cameras.json", validate_camera_file),
                     ("data/candidates.json", validate_camera_file)]:
        p = REPO_ROOT / name
        if not p.exists():
            continue
        errs = fn(p)
        for e in errs:
            print(f"{name}: {e}")
        failed = failed or bool(errs)
    sp = REPO_ROOT / "data" / "status.json"
    if sp.exists():
        errs = validate_status_file(sp)
        for e in errs:
            print(f"data/status.json: {e}")
        failed = failed or bool(errs)
    sys.exit(1 if failed else 0)
