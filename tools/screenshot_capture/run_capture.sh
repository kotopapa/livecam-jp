#!/bin/bash
# ストア用スクリーンショット撮影（Google マップ版）。使い方:
#   tools/screenshot_capture/run_capture.sh <simulator udid> <出力dir> [maps|details|tabs|all]
# 事前に README（docs/store_screenshots.md）のとおりパッチ・テストを app/ に当てておく。
# flutter drive の標準出力の「SNAP <名前>」行を見て、simctl で端末画面を撮る
# （Google マップは platform view なので binding.takeScreenshot には映らない）
set -u
UDID=${1:?simulator udid}
OUT=${2:?output dir}
SET=${3:-all}
mkdir -p "$OUT"
cd "$(dirname "$0")/../../app" || exit 1
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d "$UDID" \
  --dart-define=SCREENSHOT_MODE=true --dart-define=CAPTURE_SET="$SET" 2>&1 |
while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *"SNAP "*)
      name=${line##*SNAP }
      name=${name%%[[:space:]]*}
      xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1 &&
        echo ">>> saved $OUT/$name.png"
      ;;
  esac
done
