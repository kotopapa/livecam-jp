#!/bin/bash
# 国内からしか届かないサイトの死活監視を、国内の Mac で 30 分おきに回す（monitor/domestic.py）。
#
#   tools/domestic_monitor.sh run        # 1 回実行（確認 → data/status_domestic.json を push）
#   tools/domestic_monitor.sh install    # launchd に登録（毎時 12 分と 42 分）
#   tools/domestic_monitor.sh uninstall  # 登録を外す
#   tools/domestic_monitor.sh status     # 登録の有無と直近のログ
#
# 作業用の clone を開発用の作業ツリーとは別に持つ（開発中の変更と混ざらないようにする）。
# push は git の認証情報（macOS のキーチェーン）を使う。1 回の実行で確認するのは
# 1/10 シャード（GitHub 側の監視と同じく、各カメラは 5 時間に 1 回）。
set -euo pipefail

LABEL="jp.sanclead.livecam.domestic-monitor"
REPO_URL="https://github.com/kotopapa/livecam-jp.git"
WORK="${LIVECAM_DOMESTIC_DIR:-$HOME/Library/Application Support/livecam-domestic-monitor}"
PY="${LIVECAM_DOMESTIC_PYTHON:-/Library/Frameworks/Python.framework/Versions/3.10/bin/python3}"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/livecam-domestic-monitor.log"
LOCK="$WORK/lock"
FILES=(data/status_domestic.json monitor/.state/hashes_domestic.json)

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

run() {
  mkdir -p "$WORK"
  # 二重起動を防ぐ（前回が 1 時間以上残っていたら固まったとみなして外す）
  if ! mkdir "$LOCK" 2>/dev/null; then
    if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then
      rmdir "$LOCK" && mkdir "$LOCK"
    else
      log "前回の実行が続いているので見送り"; return 0
    fi
  fi
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

  local repo="$WORK/repo"
  if [ ! -d "$repo/.git" ]; then
    git clone -q --depth 1 --single-branch --branch main "$REPO_URL" "$repo"
  fi
  cd "$repo"
  git fetch -q --depth 1 origin main
  git reset -q --hard FETCH_HEAD

  local shard=$(( ($(date +%s) / 1800) % 10 ))
  "$PY" -m monitor.main --domestic --shard "${shard}/10"

  local keep="$WORK/out"
  local i f
  for i in 1 2 3; do
    git add "${FILES[@]}"
    if git diff --cached --quiet; then
      log "変更なし"; return 0
    fi
    git -c user.name="livecam-jp-bot" -c user.email="actions@users.noreply.github.com" \
      commit -q -m "monitor: domestic status update"
    if git push -q origin HEAD:main; then
      log "push 完了（shard ${shard}/10）"; return 0
    fi
    # 先に別の push が入った。結果を退避し、最新に合わせ直してから載せ直す
    # （この 2 ファイルを書くのはこの処理だけなので、上書きしてよい）
    mkdir -p "$keep"
    for f in "${FILES[@]}"; do cp "$f" "$keep/$(basename "$f")"; done
    git fetch -q --depth 1 origin main
    git reset -q --hard FETCH_HEAD
    for f in "${FILES[@]}"; do cp "$keep/$(basename "$f")" "$f"; done
    sleep $((i * 5))
  done
  log "push に 3 回失敗"; return 1
}

install() {
  local script
  script="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  mkdir -p "$WORK" "$(dirname "$PLIST")" "$(dirname "$LOG")"
  # 作業ツリーの変更に左右されないよう、スクリプトは作業用フォルダへ写して動かす
  cp "$script" "$WORK/domestic_monitor.sh"
  chmod +x "$WORK/domestic_monitor.sh"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$LABEL</string>
	<key>ProcessType</key>
	<string>Background</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/bash</string>
		<string>$WORK/domestic_monitor.sh</string>
		<string>run</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>LANG</key>
		<string>en_US.UTF-8</string>
		<key>PATH</key>
		<string>/usr/bin:/bin:/usr/sbin:/sbin</string>
		<key>PYTHONIOENCODING</key>
		<string>utf-8</string>
	</dict>
	<key>StartCalendarInterval</key>
	<array>
		<dict><key>Minute</key><integer>12</integer></dict>
		<dict><key>Minute</key><integer>42</integer></dict>
	</array>
	<key>StandardOutPath</key>
	<string>$LOG</string>
	<key>StandardErrorPath</key>
	<string>$LOG</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "登録した: $PLIST（毎時 12 分と 42 分。ログは $LOG）"
}

uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "登録を外した（作業用フォルダ $WORK は残してある）"
}

status() {
  launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -E "state|last exit|runs" || echo "未登録"
  [ -f "$LOG" ] && tail -n 15 "$LOG"
}

case "${1:-}" in
  run) run ;;
  install) install ;;
  uninstall) uninstall ;;
  status) status ;;
  *) echo "使い方: $0 run|install|uninstall|status" >&2; exit 2 ;;
esac
