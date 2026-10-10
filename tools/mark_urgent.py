"""台帳の変更を即時配信する印を付ける。

使い方: python tools/mark_urgent.py   # data/cameras.json の urgent_version を現在の version にして保存。あとは push するだけ

site/build.py の delivery_version が、urgent_version と version が一致するあいだ配信版番号を
完全な時刻で出す（通常は日付だけ＝再取得は1日1回）。台帳が次に変わると自動で日次に戻る。
"""
import json
from pathlib import Path

P = Path(__file__).resolve().parents[1] / "data" / "cameras.json"


def main() -> None:
    d = json.loads(P.read_text(encoding="utf-8"))
    d["urgent_version"] = d["version"]
    # version の直後に置く（並び順を保つ）
    out = {"version": d["version"], "urgent_version": d["urgent_version"]}
    out.update({k: v for k, v in d.items() if k not in out})
    P.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print("urgent_version =", d["version"])


if __name__ == "__main__":
    main()
