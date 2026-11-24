#!/system/bin/sh
# One-shot HTTP responder for /sdcard/iptv.m3u.
# toybox `nc -p 8099 -L <this>` runs it once per connection with
# stdin/stdout wired to the client socket (xinetd-style).
#
# NOTE: keep the trailing `sleep 1` before exit -- without it toybox nc
# closes the socket before the kernel flushes the body over a real LAN
# link, so clients receive a truncated playlist (~46KB).
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
