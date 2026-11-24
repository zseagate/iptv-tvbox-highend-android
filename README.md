# IPTV 高配机顶盒：直播(TiviMate) + 点播(TVBox4.1+)

面向**高配安卓盒子**（Android 7+/9，如创维 E900V22C，SDK 28）的一键直播 + 点播方案。
低配（Android 4.4 / API 19）见姊妹仓库 **iptv-tvbox-lowend-android**。

| 用途 | App | 包名 | 关键点 |
|---|---|---|---|
| **直播** | **TiviMate** 2.1.5 | `ar.tvplayer.tv` | 读盒内本地服务 `http://127.0.0.1:8099/iptv.m3u`，不依赖主机 IP |
| **点播** | **TVBox4.1+** 0.0.7 | `com.tvbox.android44` | 自带较新 SSL，HTTPS MacCMS 源可用（暴风资源 首选） |

核心思路：**能本地化就本地化**。直播源由主机侧脚本从 `zseagate/hypnotix` 拉取、合并、
按仓库分组/排列规则重分类，推送到盒子 `/sdcard/iptv.m3u`；盒内 `nc`(toybox) 服务 8099 直接
供 TiviMate 读取。点播走 TVBox4.1+ 扫码/API 添加 MacCMS 源。

## 目录

```
apk/           TiviMate 2.1.5 + TVBox4.1+ 0.0.7 (manifest.tsv / checksums.sha256)
playlist/
  merge_playlists.py  原仓库完整规则管线: 提取(jsDelivr+iptv-org+fnos)
                      +按URL/频道名去重+探活+死链过滤+黑名单+重分类+排序+校验
  filter_playlist.py  探活/过滤引擎(probe/reachable/缓存/黑名单)
  verify_playlist.py  ParserException 校验剔除
  check_live.py check_loop.py check_content.py remove_loop.py
                      录播/循环频道检测与剔除(媒体序号+分片滚动+内容哈希)
  merge_rules.py      分组/排列规则(央视数字序 -> 分组顺序 -> 组内字母序)
  box-dead.env        死源/黑名单(IPTV_SKIP_HOSTS)
  gen_live.py         快速合并 hypnotix 的简易入口(不带探活, 调试用)
deploy/
  iptv-push-box.sh      推送 + 起盒内 httpd + 强制 TiviMate 重载
  install-httpd.sh      安装盒内 httpd(8099, /system 开机自启)
  iptv-refresh.sh       定时刷新(gen -> push)
  tvbox-vod-setup.sh    装 TVBox4.1+ + 添加/切换 MacCMS 源
  iptv_serve_one.sh     盒内 HTTP 应答(8099, 单连接)
  iptv_httpd.rc         盒内 init 开机自启
systemd/      iptv-live-refresh.{service,timer}  每4h 自动刷新
configs/      macms_sources.md(源选型) + sources.env(盒 IP/ADB)
install.sh    一键安装
```

## 快速开始（主机侧）

```bash
# 0. 连接盒子(需在盒子开 ADB/网络调试); 默认 192.168.10.165:60001, 可用 BOX 覆盖
export BOX=192.168.10.165:60001

# 1. 一键安装: APK + 盒内 httpd + 直播源 + 定时更新
bash install.sh

# 1b. 含点播源(MacCMS)。token 从电视"扫码添加接口"页读取, 或 --token 提供
bash install.sh --vod
bash install.sh --vod --token <token>

# 2. 只刷新直播源
bash deploy/iptv-refresh.sh
```

## 节目源规则（从原仓库 iptv-tivimate 同步）

`iptv-refresh.sh` 依次执行（与 iptv-tivimate 一致的规则）：

1. **提取**（`merge_playlists.py`）：基线(上次 merged.m3u，防上游抽风丢好源) 最高优先，
   再按 `jsDelivr Collect-IPTV(best_sorted) > iptv-org(news/cn/hk/tw/zh/movies/sports/ent) > fnos(BBC/CNN)` 合并。
   jsDelivr best_sorted 含「名侦探柯南」等动漫频道（hypnotix 无此源）。
2. **去重**：先按 URL 去重，再按**归一化频道名**去重（`norm_name`，如 CCTV-13/CCTV13 视为同一），
   高优先级源胜出。
3. **去不可播放**：`filter_playlist.probe` 逐流探活（HLS 分段真实可播、非 HTML/YouTube、码率达标），
   死链剔除；`box-dead.env` 死源黑名单(`IPTV_SKIP_HOSTS`)跳过；`verify_playlist` 剔除 ExoPlayer
   解析失败条目。
4. **录播/循环剔除**：`check_live`(媒体序号推进) -> `check_loop`(分片列表滚动) ->
   `check_content`(内容哈希确认) -> `remove_loop`，剔除录播/循环频道。
5. **分组/排列**（`merge_rules`）：央视/CGTN -> 央视频道；凤凰/TVB/東森/中天/三立/民视 -> 港澳台频道；
   电影 -> 电影频道；体育 -> 体育频道；新闻 -> 新闻频道；国际公共 -> 海外频道·地区；其余按关键字归中文分类。
   排序：CCTV-1..17 数字序最前，再按 `电影频道/少儿动漫/新闻频道/...` 分组顺序，组内按英文名字母序。

## TiviMate 重载要点

TiviMate 会把列表缓存在 `TvPlayer.db`，**仅推送文件不会重载**。`iptv-push-box.sh` 在
`force-stop` 后给 playlist URL 加 `?ts=<时间戳>` 缓存破坏参数，使 TiviMate 下次启动即重新拉取
`http://127.0.0.1:8099/iptv.m3u`。

## 安全与合规

仅整理开源壳 + 配置脚本，不内置、不转载、不提供任何片源/接口清单。请仅播放你自有或已授权内容。
