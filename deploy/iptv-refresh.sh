#!/usr/bin/env bash
# 定时刷新高配盒子直播源: 重新生成(拉 hypnotix + 仓库分组/排列规则) -> 推送盒子。
# 可被 systemd timer / cron 调用; 盒子离线时自动跳过(best-effort)。
#
# Env: REPO, BOX, ADB, IPTV_OUT(输出目录), LOWEND(默认0), VOD_REFRESH(默认0)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(dirname "$here")}"
ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
OUT="${IPTV_OUT:-$REPO/playlist/merged.m3u}"

echo "[refresh] $(date '+%F %T') regenerate ..."
python3 "$REPO/playlist/gen_live.py" -o "$OUT" 2>&1 | tail -3 || {
  echo "[refresh] gen failed, keep old playlist" >&2; exit 0
}

echo "[refresh] push to $BOX ..."
BOX="$BOX" ADB="$ADB" SRC="$OUT" "$here/iptv-push-box.sh" || echo "[refresh] push skipped" >&2

echo "[refresh] done $(date '+%F %T')"
