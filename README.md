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
  gen_live.py  拉 hypnotix -> 合并去重 -> 应用分组/排列规则 -> m3u
  merge_rules.py  仓库分组/排列规则(从 iptv-tivimate 提取, 自包含):
                  央视数字序 -> 电影/新闻/体育/港澳台/海外...分组 -> 组内字母序
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

## 直播源规则（分组/排列）

`playlist/merge_rules.py` 提取自 `iptv-tivimate/playlist/merge_playlists.py`：

1. **重分类**（`classify_group`）：央视/CGTN -> 央视频道；凤凰/TVB/東森/中天/三立/民视... -> 港澳台频道；
   电影 -> 电影频道；体育 -> 体育频道；新闻 -> 新闻频道；国际公共(freetv) -> 海外频道·地区；
   中文字段保留；其余按关键字归中文分类。
2. **排序**（`sort_final`）：CCTV-1..17 数字序最前，再按 `电影频道/少儿动漫/新闻频道/...` 分组顺序，
   组内按英文名字母序。

源优先级（`gen_live.py`，先出现者胜，按 URL 去重）：freetv > 新闻 > 港澳台/中文/体育/电影(iptv-org)。

## TiviMate 重载要点

TiviMate 会把列表缓存在 `TvPlayer.db`，**仅推送文件不会重载**。`iptv-push-box.sh` 在
`force-stop` 后给 playlist URL 加 `?ts=<时间戳>` 缓存破坏参数，使 TiviMate 下次启动即重新拉取
`http://127.0.0.1:8099/iptv.m3u`。

## 安全与合规

仅整理开源壳 + 配置脚本，不内置、不转载、不提供任何片源/接口清单。请仅播放你自有或已授权内容。
