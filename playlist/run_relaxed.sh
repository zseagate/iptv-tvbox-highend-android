#!/bin/bash
# 放宽档探活重跑(后台): 吞吐/时限门槛放宽, 复用缓存, 仅重探被剔除的可放宽死条目
cd "$(dirname "$0")"
. ./box-dead.env
export IPTV_OUT="$(pwd)" IPTV_CACHE="$(pwd)/probe-cache.json"
export IPTV_UA="ExoPlayerLib/2.19.1" IPTV_REFERER=auto PYTHONUNBUFFERED=1
# B 放宽: 吞吐 32KB/s->8KB/s, 期限 8s->15s, 分段 512KB/32KB->256KB/16KB, 直链 128KB->64KB, 嵌套 3->4, 超时放宽
export IPTV_READ_DEADLINE=15 IPTV_MIN_SPEED_BPS=8192 IPTV_MIN_CHUNK_BYTES=262144
export IPTV_MIN_TINY_BYTES=16384 IPTV_MIN_ALIVE_BYTES=65536 IPTV_PROBE_DEPTH=4
export IPTV_TIMEOUT=8,15 IPTV_SEG_TIMEOUT=8,12 IPTV_REACH_TIMEOUT=8,12
exec python3 merge_playlists.py
