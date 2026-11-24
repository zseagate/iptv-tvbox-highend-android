#!/bin/bash
# 推送直播节目源到高配盒子并让 TiviMate 重新拉取。
#
# 关键点: TiviMate 会把列表缓存在 TvPlayer.db，仅推送文件不会让它重载。
# 这里在 force-stop 后给 playlist URL 加缓存破坏参数(ts=时间戳)，使 TiviMate
# 认为列表已变化，下次启动即重新拉取 http://127.0.0.1:8099/iptv.m3u。
#
# Env overrides: ADB, BOX (默认 192.168.10.165:60001), SRC, DST
set -euo pipefail

ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
SRC="${SRC:-$(dirname "$0")/../playlist/merged.m3u}"
DST="${DST:-/sdcard/iptv.m3u}"
DB="/data/user_de/0/ar.tvplayer.tv/databases/TvPlayer.db"
PKG="ar.tvplayer.tv"
# 盒内服务: http://127.0.0.1:8099/iptv.m3u
PORT=8099

[[ -s "$SRC" ]] || { echo "[push] $SRC missing, skip push" >&2; exit 0; }

"$ADB" connect "$BOX" >/dev/null 2>&1 || true

# 1. 推送列表
if ! "$ADB" -s "$BOX" push "$SRC" "$DST" >/dev/null; then
  echo "[push] STB unreachable, skip push" >&2; exit 0
fi
COUNT=$(grep -c '^#EXTINF' "$SRC")
echo "[push] $COUNT channels -> $BOX:$DST $(date)"

# 2. 确保盒内 httpd(8099)在跑
"$ADB" -s "$BOX" shell "echo -e 'GET / HTTP/1.0\r\n\r' | toybox nc -w2 127.0.0.1 $PORT >/dev/null 2>&1" || true
if ! "$ADB" -s "$BOX" shell "toybox nc -w2 127.0.0.1 $PORT </dev/null >/dev/null 2>&1"; then
  echo "[push] starting in-box httpd :$PORT"
  "$ADB" -s "$BOX" shell "setsid sh -c 'exec /system/bin/toybox nc -p $PORT -L /system/bin/iptv_serve_one.sh' </dev/null >/dev/null 2>&1 &"
  sleep 2
fi

# 3. 让 TiviMate 重新拉取列表
"$ADB" -s "$BOX" shell "am force-stop $PKG" >/dev/null 2>&1 || true
TS=$(date +%s)
# 3a. 首选: 缓存破坏参数(URL 变化 -> TiviMate 重新拉取)
"$ADB" -s "$BOX" shell "sqlite3 $DB \"UPDATE playlists SET url='http://127.0.0.1:$PORT/iptv.m3u?ts=$TS' WHERE id=1;\"" 2>/dev/null || true
# 3b. 兜底: 若 sqlite 未生效, 删除列表缓存让 TiviMate 重新导入
CUR=$("$ADB" -s "$BOX" shell "sqlite3 $DB 'SELECT url FROM playlists WHERE id=1;'" 2>/dev/null | tr -d '\r')
if [[ "$CUR" != *"ts=$TS"* ]]; then
  echo "[push] sqlite bump failed, clearing cached channels"
  "$ADB" -s "$BOX" shell "sqlite3 $DB 'DELETE FROM channels;'" 2>/dev/null || true
fi
"$ADB" -s "$BOX" shell "monkey -p $PKG -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1 || true
echo "[push] TiviMate reload triggered (ts=$TS)"
