#!/usr/bin/env bash
# 定时刷新高配盒子直播源 —— 完整原仓库规则管线:
#   merge_playlists.py  (提取 + 按URL/频道名去重 + 探活 + 死链过滤 + 黑名单 + 重分类 + 排序 + 校验)
#   -> check_live.py    (媒体序号推进 -> 疑似录播/循环)
#   -> check_loop.py    (分片列表滚动 -> 确认真循环)
#   -> check_content.py (内容哈希 -> loop-confirm)
#   -> remove_loop.py   (剔除录播/循环频道)
#   -> iptv-push-box.sh (推送盒子 + 强制 TiviMate 重载)
#
# 盒子离线时自动跳过(best-effort)。
# Env: REPO, BOX, ADB, IPTV_OUT, IPTV_CACHE, SKIP_LOOP(默认1=启用录播/循环剔除)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO:-$(dirname "$here")}"
ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
PL="$REPO/playlist"
export IPTV_OUT="${IPTV_OUT:-$PL}"
export IPTV_CACHE="${IPTV_CACHE:-$PL/probe-cache.json}"
export IPTV_UA="${IPTV_UA:-ExoPlayerLib/2.19.1}"
export IPTV_REFERER="${IPTV_REFERER:-auto}"
export PYTHONUNBUFFERED=1

# 黑名单(死源) + 频道名黑名单
if [[ -f "$PL/box-dead.env" ]]; then . "$PL/box-dead.env"; fi

cd "$PL"

echo "[refresh] $(date '+%F %T') merge+probe+filter ..."
python3 merge_playlists.py 2>&1 | tail -8 || { echo "[refresh] merge failed, keep old" >&2; exit 0; }

if [[ "${SKIP_LOOP:-1}" == "1" ]]; then
  echo "[refresh] live/loop detection ..."
  python3 check_live.py merged.m3u live-check.tsv 2>/dev/null || true
  # same 序列但可能仍直播 -> check_loop 区分; 这里取 all 再交给 check_loop
  python3 check_loop.py live-check.tsv loop-check.tsv 2>/dev/null || true
  python3 check_content.py loop-check.tsv content-check.tsv 2>/dev/null || true
  python3 remove_loop.py merged.m3u content-check.tsv merged.clean.m3u 2>/dev/null || true
  if [[ -s merged.clean.m3u ]]; then
    mv merged.clean.m3u merged.m3u
    echo "[refresh] loop channels removed"
  fi
fi

echo "[refresh] push to $BOX ..."
BOX="$BOX" ADB="$ADB" SRC="$PL/merged.m3u" "$here/iptv-push-box.sh" || echo "[refresh] push skipped" >&2

echo "[refresh] done $(date '+%F %T')"
