#!/bin/bash
# 安装 TVBox4.1+ 并添加/切换 MacCMS 点播源(暴风资源 首选)。
#
# 原理: TVBox4.1+ 在"设置 -> 扫码添加接口"页起一个临时 HTTP 服务
#       http://<盒IP>:9979/<token>，POST 一次即把 MacCMS 源存为自定义源。
#       token 每会话随机、屏幕显示，需自动提取(uiautomator)或手工提供。
#
# 用法:
#   tvbox-vod-setup.sh                      # 装 APK + 起扫码页 + 自动提取 token 并 POST
#   tvbox-vod-setup.sh --token <token>      # 手工提供 token(从屏幕 URL 复制)
#   tvbox-vod-setup.sh --name 暴风资源 --base-url https://bfzyapi.com/api.php/provide/vod/
#
# Env: ADB, BOX, APK(默认 ../apk/TVBox4.1+_v0.0.7.apk), MACMS_NAME, MACMS_BASE
set -euo pipefail

ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK="${APK:-$HERE/../apk/TVBox4.1+_v0.0.7.apk}"
MACMS_NAME="${MACMS_NAME:-暴风资源}"
MACMS_BASE="${MACMS_BASE:-https://bfzyapi.com/api.php/provide/vod/}"
PKG="com.tvbox.android44"
PORT=9979
TOKEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token) TOKEN="$2"; shift 2;;
    --name)  MACMS_NAME="$2"; shift 2;;
    --base-url) MACMS_BASE="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

"$ADB" connect "$BOX" >/dev/null 2>&1 || true
A=("$ADB" -s "$BOX")

# 1. 安装
if ! "${A[@]}" shell "pm list packages | grep -q $PKG"; then
  echo "[vod] installing TVBox4.1+ ..."
  "${A[@]}" install -r "$APK" >/dev/null
else
  echo "[vod] TVBox4.1+ already installed"
fi

# 2. 启动并打开"扫码添加接口"
"${A[@]}" shell "monkey -p $PKG -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1
sleep 3
# 设置tab(右上) -> 扫码添加接口；用 uiautomator 找 bounds，找不到则用默认坐标
"${A[@]}" shell "uiautomator dump /sdcard/vod_ui.xml >/dev/null 2>&1 || true"
QR_BOUNDS=$("${A[@]}" shell "grep -oE 'text=\"扫码添加接口\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"' /sdcard/vod_ui.xml 2>/dev/null" | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1 || true)
if [[ -n "$QR_BOUNDS" ]]; then
  X1=$(echo "$QR_BOUNDS" | tr -d '[]' | cut -d, -f1); Y1=$(echo "$QR_BOUNDS" | tr -d '[]' | cut -d, -f2)
  X2=$(echo "$QR_BOUNDS" | sed 's/.*\]\[//' | tr -d '[]' | cut -d, -f1); Y2=$(echo "$QR_BOUNDS" | sed 's/.*\]\[//' | tr -d '[]' | cut -d, -f2)
  CX=$(( (X1+X2)/2 )); CY=$(( (Y1+Y2)/2 ))
  echo "[vod] tap 扫码添加接口 @($CX,$CY)"
  "${A[@]}" shell "input tap $CX $CY"
else
  echo "[vod] fallback: tapping 扫码添加接口 @(357,528)"
  "${A[@]}" shell "input tap 357 528"   # 1280x720 逻辑坐标
fi
sleep 3

# 3. 提取 token
if [[ -z "$TOKEN" ]]; then
  "${A[@]}" shell "uiautomator dump /sdcard/vod_ui2.xml >/dev/null 2>&1 || true"
  TOKEN=$("${A[@]}" shell "grep -oE 'http://[0-9.]+:$PORT/[a-zA-Z0-9]+' /sdcard/vod_ui2.xml 2>/dev/null" | grep -oE '[a-zA-Z0-9]+$' | head -1 | tr -d '\r' || true)
fi
"${A[@]}" shell "rm -f /sdcard/vod_ui.xml /sdcard/vod_ui2.xml" 2>/dev/null || true

if [[ -z "$TOKEN" ]]; then
  echo "[vod] 未能自动提取 token。请在电视上读取 'http://<盒IP>:$PORT/<token>' 并重试:"
  echo "      $0 --token <token>"
  echo "      或手工 POST:"
  echo "      curl -X POST -d 'name=$MACMS_NAME' --data-urlencode 'baseUrl=$MACMS_BASE' http://$BOX_HOST_IP:$PORT/<token>"
  exit 2
fi

# 4. POST MacCMS 源
BOX_IP="${BOX%%:*}"
echo "[vod] POST MacCMS source '$MACMS_NAME' ($MACMS_BASE)"
curl -sS -X POST -d "name=$MACMS_NAME" --data-urlencode "baseUrl=$MACMS_BASE" \
  "http://$BOX_IP:$PORT/$TOKEN" -w "\nHTTP %{http_code}\n" | tail -3

echo "[vod] 已在自定义源中添加 '$MACMS_NAME'。请在 设置->选择视频源 中选中它。"
