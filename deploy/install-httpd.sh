#!/bin/bash
# 在盒子上安装盒内 HTTP 服务(8099, 服务 /sdcard/iptv.m3u)并开机自启。
# TiviMate 用 http://127.0.0.1:8099/iptv.m3u，不依赖主机 IP。
# 需要 root（盒子已 root）。
#
# Env overrides: ADB, BOX
set -euo pipefail

ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$ADB" connect "$BOX" >/dev/null 2>&1 || true
A=("$ADB" -s "$BOX")

echo "[httpd] mounting /system rw"
"${A[@]}" shell "mount -o remount,rw /system 2>/dev/null || true"
"${A[@]}" shell "mount -o remount,rw / 2>/dev/null || true"

echo "[httpd] pushing iptv_serve_one.sh -> /system/bin/"
"${A[@]}" push "$HERE/iptv_serve_one.sh" /system/bin/iptv_serve_one.sh >/dev/null
"${A[@]}" shell "chmod 755 /system/bin/iptv_serve_one.sh"

echo "[httpd] pushing iptv_httpd.rc -> /system/etc/init/"
"${A[@]}" push "$HERE/iptv_httpd.rc" /system/etc/init/iptv_httpd.rc >/dev/null
"${A[@]}" shell "chmod 644 /system/etc/init/iptv_httpd.rc"

echo "[httpd] starting now (boot自启由 init 处理)"
"${A[@]}" shell "setsid sh -c 'exec /system/bin/toybox nc -p 8099 -L /system/bin/iptv_serve_one.sh' </dev/null >/dev/null 2>&1 &"
sleep 2

echo "[httpd] verify:"
"${A[@]}" shell "echo -e 'GET /iptv.m3u HTTP/1.0\r\n\r' | toybox nc -w3 127.0.0.1 8099 2>/dev/null | head -1" || echo "  (httpd not responding; check /system/etc/init/iptv_httpd.rc)"
echo "[httpd] done"
