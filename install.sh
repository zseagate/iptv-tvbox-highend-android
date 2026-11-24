#!/usr/bin/env bash
# 一键安装/更新高配盒子的 IPTV(直播 + 点播):
#   1. 安装 TiviMate(直播) + TVBox4.1+(点播) APK
#   2. 安装盒内 HTTP 服务(8099, 开机自启)
#   3. 从 zseagate/hypnotix 生成直播列表(应用仓库分组/排列规则) -> 推送 -> 让 TiviMate 重载
#   4. 添加 MacCMS 点播源(暴风资源 首选) — 需提供 token 或屏幕读取
#   5. 安装 systemd timer(每 4h 自动刷新直播源)
#
# 用法:
#   bash install.sh                 # 仅装 APK + 直播源 + 定时更新
#   bash install.sh --vod           # 含点播源添加(自动尝试提取 token)
#   bash install.sh --vod --token <token>   # 手工提供 MacCMS 接口 token
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADB="${ADB:-$(command -v adb || echo /home/mac/tools/platform-tools/adb)}"
BOX="${BOX:-192.168.10.165:60001}"
DO_VOD=0
TOKEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vod) DO_VOD=1; shift;;
    --token) TOKEN="$2"; DO_VOD=1; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

echo "=== 1/5 安装 APK ==="
"$ADB" connect "$BOX" >/dev/null 2>&1 || true
"$ADB" -s "$BOX" install -r "$HERE/apk/ar.tvplayer.tv.apk" | tail -1
"$ADB" -s "$BOX" install -r "$HERE/apk/TVBox4.1+_v0.0.7.apk" | tail -1

echo "=== 2/5 安装盒内 HTTP 服务(8099) ==="
BOX="$BOX" ADB="$ADB" bash "$HERE/deploy/install-httpd.sh" || echo "  (httpd 安装失败, 继续)"

echo "=== 3/5 生成并推送直播源(应用分组/排列规则) ==="
BOX="$BOX" ADB="$ADB" bash "$HERE/deploy/iptv-refresh.sh" || echo "  (直播源刷新失败)"

echo "=== 4/5 点播源 ==="
if [[ "$DO_VOD" == "1" ]]; then
  VOD_ARGS=()
  [[ -n "$TOKEN" ]] && VOD_ARGS=(--token "$TOKEN")
  BOX="$BOX" ADB="$ADB" bash "$HERE/deploy/tvbox-vod-setup.sh" "${VOD_ARGS[@]}" \
    || echo "  (点播源添加未完成; 可稍后重跑 tvbox-vod-setup.sh)"
else
  echo "  跳过(--vod 以添加 MacCMS 点播源)"
fi

echo "=== 5/5 定时刷新(systemd user timer, 每4h) ==="
mkdir -p "$HOME/.config/systemd/user"
cp "$HERE/systemd/iptv-live-refresh.service" "$HERE/systemd/iptv-live-refresh.timer" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now iptv-live-refresh.timer 2>/dev/null \
  && echo "  timer 已启用(每4h)" || echo "  (systemd 不可用; 可用 crontab 或手动运行 deploy/iptv-refresh.sh)"

echo ""
echo "=== 完成 ==="
echo "直播: TiviMate 已加载盒内列表 http://127.0.0.1:8099/iptv.m3u"
echo "点播: TVBox4.1+ 已装; 源见 configs/macms_sources.md (默认 $MACMS_NAME)"
echo "定时: systemd iptv-live-refresh.timer 每4h 自动刷新直播源"
