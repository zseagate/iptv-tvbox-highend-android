#!/system/bin/sh
# 盒内单次 HTTP 应答器: 把 /sdcard/iptv.m3u 用 HTTP 吐给 TiviMate。
# toybox `nc -p 8099 -L <this>` 每来一个连接执行一次(xinetd 风格),
# stdin/stdout 直接接到客户端 socket。
#
# 注意: 结尾的 `sleep 1` 必须保留 —— 否则 toybox nc 会在内核把响应体
# 真正刷过局域网之前就关闭 socket, 客户端会收到截断的列表(~46KB)。
F=/sdcard/iptv.m3u

# consume the request line, then answer immediately; never block on
# draining the remaining headers (read keeps "\r", blank-line detect fails)
read -r line

if [ -s "$F" ]; then
  LEN=$(wc -c < "$F")
  printf 'HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Length: %s\r\nConnection: close\r\nCache-Control: no-cache\r\n\r\n' "$LEN"
  cat "$F"
else
  printf 'HTTP/1.1 404 Not Found\r\nConnection: close\r\nContent-Length: 0\r\n\r\n'
fi
sleep 1
exit 0
