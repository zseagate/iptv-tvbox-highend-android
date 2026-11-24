# MacCMS 点播源选型（高配盒子友好度）
#
> 只记录选型标准与评测结论，不含完整源清单（源为公开聚合接口，自行确认可用性）。

## 选型三问

1. **API 合法**：`GET <baseUrl>` 返回 MacCMS JSON（含 `list`/`class`），状态 200。
2. **直链优先**：播放地址是 `https://<cdn>/.../index.m3u8`（直链）优于 `.../share/<hash>`（解析页）。
3. **TLS 兼容**：播放域名至少能协商 TLS 1.2；高配盒(Android 9+ / TVBox4.1+ 自带较新 SSL)一般均可。

## 实测参考（某网络环境，2026-11，高配盒实测）

| 名称 | baseUrl | 条数 | 播放地址类型 | 备注 |
|---|---|---|---|---|
| 暴风资源 | `https://bfzyapi.com/api.php/provide/vod/` | ~17万 | 直链 index.m3u8 | **首选**，TVBox4.1+ 实测可搜可播 |
| 量子资源 | `https://cj.lziapi.com/api.php/provide/vod/` | ~16万 | /share/ 解析页 | 部分能播 |
| 索尼资源 | `https://suoniapi.com/api.php/provide/vod/` | ~15万 | /share/ 解析页 | 部分能播 |

> 已停/域名失效（勿用）：`api.bdzybf.com`、`caiji.zhao1.top`、`api.kunyu77.com`、`www.tycjzy.com`、`api.wcyy.tv`、`api.hzyua.com`、`api.jyzy.com`、`vip.kuaiche.com`。

## 为什么高配盒用 TVBox4.1+ 而非 Q 版

- 高配盒(Android 9+/SDK 28)可装 TiviMate(minSdk 21)与 TVBox4.1+(minSdk 16, target 28)。
- TVBox4.1+（2026 构建）自带较新 SSL，HTTPS MacCMS 源可用。
- 点播 = TVBox4.1+（MacCMS 源，扫码/API 添加）；直播 = TiviMate（盒内本地列表）。
