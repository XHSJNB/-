# 原神 4.0 单机私服 · 一键部署（Grasscutter 1.7.4）

> **本仓库不托管任何游戏客户端、服务端程序或资源文件。** 能下官方原件的全部给链接，只有「没有现成链接、又必须调好才能跑」的东西（脚本、调好的配置、客户端补丁、便携启动器）才打包成一个小 Kit（14MB）。
> 不用网盘、不用移动硬盘、不用开着一台机器做种。

一套已经调通、开箱即用的原神 4.0 国际版离线私服环境：下载 → 组装 → 双击一个 bat，从起数据库到进游戏全自动，不用改 hosts、不用装 MongoDB、不用手填启动器路径、不用手动装 Java。

---

## 一、它能做到什么

- **双击 `脚本\开始游戏.bat` 从零进游戏**：自动起 MongoDB → 起服务端 → 等 443 真就绪 → 重载卡池商店 → 校验客户端补丁 → 拉起启动器并自动点【启动】
- 服务端 **Grasscutter 1.7.4**（443/TCP 明文 dispatch + 22102/UDP 游戏世界）
- 数据库 **MongoDB 7.0.5** 免安装版（27017，正常 shutdown 落盘）
- 启动器 **Cultivation 1.2.0**（本地 8365 代理劫持 `*.hoyoverse.com` 登录请求转给本地服务端）
- 全部只监听 **127.0.0.1**，单机单人，默认 **UID 10001**，实测延迟 6~8ms
- 已验证：重启电脑后冷启动 → 自动开服 → 自动点启动器 → 直接进游戏世界

## 二、环境要求

| 项目 | 要求 |
| --- | --- |
| 系统 | Windows 10 / 11，**64 位** |
| 内存 | 8GB 以上（服务端 `-Xms2G -Xmx6G`） |
| 硬盘 | 约 **70GB** 可用空间（客户端解压后 66GB） |
| 网络 | 下载量约 **68.5GB**（客户端 66.6GB + 自动下载的组件约 1.9GB） |
| Java | **JDK 17**，`教程\组装.bat` 会自动下载（约 182MB） |
| 运行库 | 微软 VC++ 2015-2022 x64（MongoDB 需要） |
| 权限 | 普通用户即可，**不需要管理员** |

## 三、每个组件从哪来（官方链接）

| 组件 | 版本 | 体积 | 链接 |
| --- | --- | --- | --- |
| 游戏本体 | 4.0.0 国际版 | 56.16 GB | <https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20230804185804_eTmE8EZjJZdAJapq/GenshinImpact_4.0.0.zip> |
| 中文语音 | 4.0.0 | 10.45 GB | <https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20230804185804_eTmE8EZjJZdAJapq/Audio_Chinese_4.0.0.zip> |
| Java 17 | Temurin 17 (x64) | 182 MB | <https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse> |
| MongoDB | 7.0.5 免安装 zip | 594 MB | <https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.5.zip> |
| 服务端 | Grasscutter 1.7.4 | 98 MB | <https://github.com/Grasscutters/Grasscutter/releases/download/v1.7.4/grasscutter-1.7.4.jar> |
| 服务端 resources | 4.0 | 约 1 GB | <https://gitlab.com/api/v4/projects/35984297/repository/archive.zip> |
| 指令插件 | opencommand 1.7.0 | 100 KB | <https://github.com/jie65535/gc-opencommand-plugin/releases/download/v1.7.0/opencommand-1.7.0.jar> |
| 启动器 | Cultivation 1.2.0 | 18 MB | <https://github.com/Grasscutters/Cultivation/releases> |
| 图形化指令工具 | GcTools 1.13.0 | 13 MB | <https://github.com/jie65535/GrasscutterCommandGenerator/releases/download/v1.13.0/GcTools-v1.13.0.exe> |

> 客户端两个 zip 内部**没有多余的一层目录**，解压出来直接就是 `GenshinImpact.exe` + `GenshinImpact_Data`；语音包内部路径是 `GenshinImpact_Data/StreamingAssets/AudioAssets/Chinese`，同样直接解压进 `游戏\` 就能对上。

**没有现成链接、只能自己打包的部分**（本仓库 Release 提供 `XH_YS_Kit.7z`，14MB）：

- `脚本\`：开始游戏 / 关闭游戏 / 指令工具 + `start_all.ps1` / `stop_all.ps1` / `run_mongo.cmd` / `run_server.cmd`（全部自解析路径，换机器不用改）
- `教程\`：部署教程、`组装.bat` + `组装.ps1`（自动下载并摆放上面那些组件）、`一键部署.bat` + `自检.bat` + `deploy.ps1`
- `配置\服务端\config.json`：调好的 443 / 明文 / 自动建号 / 全权限
- `配置\服务端\plugins\`：opencommand 插件配置（token 已生成）
- `配置\工具\patch_master\`：客户端补丁 `version.dll` + `PublicKey.txt`（社区补丁，没有官方地址）
- `配置\工具\Cultivation\`：**便携版**启动器（官方只发 msi，装起来要管理员，这个解压即用、`--no-admin` 启动）

## 四、安装：两条路，选一条

### 路线 A：一键组装（推荐）

1. 新建 `D:\XH_YS`，把 **`XH_YS_Kit.7z`** 解压进去，会得到 `配置\`、`脚本\`、`教程\`。
2. 进 `教程`，双击 **`组装.bat`**。它会：
   - 检查缺什么：Java 17 / MongoDB / 服务端 jar / resources / opencommand 插件
   - **缺哪个就从上面的官方链接下哪个**（curl 断点续传，断了重跑接着下）
   - 把下到的东西摆进 `配置\工具\jdk-17`、`配置\数据库\bin`、`配置\服务端\resources` 等固定位置
   - 客户端没放齐时，直接把两条官方直链打出来给你
3. 下客户端：`GenshinImpact_4.0.0.zip` 和 `Audio_Chinese_4.0.0.zip` 都解压到 `D:\XH_YS\游戏\`（提示合并就合并），确认 `游戏\GenshinImpact.exe` 存在。
4. 再双击 **`教程\一键部署.bat`**：装补丁、写启动器配置、试跑数据库、问你要不要直接开服。

### 路线 B：全手动

照第三节的表把每个组件下下来，按第五节的目录结构摆好（jar 放 `配置\服务端\`、MongoDB 的 `bin` 放 `配置\数据库\bin`、resources 放 `配置\服务端\resources`、Java 解压到 `配置\工具\jdk-17` 并把 `java.exe` 路径写进 `配置\java_path.txt`），然后照样跑 `教程\一键部署.bat` 校验一遍。

## 五、目录结构

```
XH_YS
├─ 游戏\                   原神 4.0 国际版客户端（约 66GB，GenshinImpact.exe + GenshinImpact_Data…）
├─ 配置\
│   ├─ 服务端\             grasscutter-1.7.4.jar、config.json、resources、plugins、data、日志
│   ├─ 数据库\             MongoDB 7.0.5（bin / data / log）
│   ├─ 工具\               Cultivation（便携版）、patch_master 补丁母本、GcTools
│   ├─ 教程源码\           Grasscutter_build（参考用，可选）
│   └─ java_path.txt       本机 JDK 17 路径，由组装/部署脚本写入
├─ 脚本\                   开始游戏.bat / 关闭游戏.bat / 指令工具.bat + 底层 ps1、cmd + 说明.md
└─ 教程\                   部署教程.md、组装.bat/组装.ps1、一键部署.bat/自检.bat/deploy.ps1、打包与分享说明.md
```

## 六、一键部署具体做什么

`教程\一键部署.bat` 依次执行：

1. 检查四个文件夹、`GenshinImpact.exe`、`grasscutter-*.jar` 是否齐全，并检查解压路径是否过长/在受保护目录
2. 找 Java 17（PATH、随包 JDK、常见安装目录、注册表），找不到就询问是否自动下载 Temurin 17，把结果写进 `配置\java_path.txt`
3. 校验并自动修复客户端补丁 `version.dll` / `PublicKey.txt`
4. 按本机真实路径生成 Cultivation 启动器配置（`toggle_grasscutter/https_enabled/patch_rsa/use_internal_proxy` 全部预设正确）
5. 检查 443 / 27017 是否被占用（冲突时指出是哪个进程）
6. 真跑一次 mongod 验证数据库能启动，再正常关闭
7. 检查 VC++ 运行库、长路径、系统位数

最后问「现在直接开服并进游戏？」—— 输 **Y**，它会拉起 `脚本\开始游戏.bat`。弹 HOYOVERSE 登录框时账号 `test`、密码 `123456`（随便填也会自动建号），看到「点击进入」点一下即可。

以后每次玩：直接双击 **`脚本\开始游戏.bat`**；玩完双击 **`脚本\关闭游戏.bat`**（会连系统代理一起复位）。

## 七、账号与常用指令

| 项 | 值 |
| --- | --- |
| 账号 / 密码 | `test` / `123456`（首次登录自动建号） |
| 默认 UID | `10001` |
| 管理权限 | 已授 `*`（全权限） |
| 游戏内指令 | 聊天框输入，以 `/` 开头：`/give 201 99999`（原石）、`/prop 1000 3000`、`/permission list`、`/help` |
| 图形化指令 | 双击 `脚本\指令工具.bat`（GcTools，地址与 token 已在 Kit 的插件配置里预置） |

## 八、常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| `组装.bat` 里 resources 下载很慢 / 断 | GitLab 国内不稳。重跑 `组装.bat` 会断点续传，也可以手动下 <https://gitlab.com/api/v4/projects/35984297/repository/archive.zip> 解出 `resources` 放到 `配置\服务端\` |
| 网络错误 4206 / 4214 / 4210 | 客户端缺 `version.dll` 补丁（启动器退出时会删掉它）。重跑一键部署，或把 `配置\工具\patch_master\version.dll` 复制到 `游戏\` |
| 登录页 502 / 服务器繁忙 | 启动器没在跑（没有 8365 代理），或勾了「使用 HTTPS」。重跑 `开始游戏.bat`，启动器窗口别关 |
| 点【启动】只弹资源管理器 | 启动器里游戏路径填成了目录。重跑一键部署会自动改对 |
| 启动器闪退（退出码 101） | 必须带 `--no-admin` 启动（Kit 里的便携版 + bat 已带好，别用官方 msi 装的那个） |
| 服务端黑窗口报 Java 错误 | 没装 JDK 17。跑 `教程\组装.bat` 或 `自检.bat`，按提示装或让它自动下 |
| 443 被占用 | `Get-NetTCPConnection -State Listen -LocalPort 443` 看占用进程，常见是 IIS / 残留 java |
| MongoDB 起不来 | 缺 VC++ 运行库：<https://aka.ms/vs/17/release/vc_redist.x64.exe> |
| 客户端解压报「文件损坏」 | 56GB 包下载中断过，用 IDM / 迅雷重下或整体重下 |
| 玩完浏览器上不了网 | 系统代理没复位：跑 `关闭游戏.bat`，或手动关闭「使用代理服务器」 |

## 九、本仓库内容

```
.
├─ README.md                    本说明
├─ .gitignore
├─ docs/
│   ├─ 部署教程.md              给收包的人：下 Kit → 组装 → 部署 → 进游戏 → FAQ
│   ├─ 打包与分享说明.md         给分享者：Kit 怎么打、Release 怎么发
│   └─ 完整说明.md              技术全量文档：目录、配置项、原理、排障、卡池/商城
├─ setup/
│   ├─ 组装.bat / 组装.ps1       缺什么下什么（Java / MongoDB / jar / resources / 插件）
│   ├─ 一键部署.bat             补丁 + 启动器配置 + 预检 + 可选开服
│   ├─ 自检.bat                 只检查不启动
│   └─ deploy.ps1               上面两个 bat 的实现
└─ scripts/
    ├─ 开始游戏.bat / 关闭游戏.bat / 指令工具.bat
    └─ start_all.ps1 / stop_all.ps1 / run_mongo.cmd / run_server.cmd
```

Release 里的 `XH_YS_Kit.7z` = `配置\工具` + `配置\服务端\config.json` + `配置\服务端\plugins` + `脚本\` + `教程\`，与上面的 `setup/`、`scripts/` 内容一致。

## 附录 A：关键配置项

服务端 `config.json`：

```json
"server": {
  "http": {
    "bindPort": 443,
    "encryption": { "useEncryption": false, "useInRouting": false }
  },
  "game": { "bindPort": 22102 }
},
"databaseInfo": { "connectionUri": "mongodb://localhost:27017", "collection": "grasscutter" },
"account": { "autoCreate": true, "defaultPermissions": ["*"] }
```

启动器配置（`%APPDATA%\cultivation\configuration.json`）：

```json
"toggle_grasscutter": true, "https_enabled": false,
"patch_rsa": true, "use_internal_proxy": true,
"last_ip": "127.0.0.1", "last_port": "443",
"game_install_path": "<...>\\游戏\\GenshinImpact.exe"
```

`useInRouting` 必须为 `false`：设成 `true` 会下发 `https://` 地址给明文端口，客户端直接报 4206。

## 免责声明

本项目仅用于**个人学习与研究**（游戏服务端协议模拟、逆向工程与自动化脚本实践）。本仓库**不包含、不托管、不转存任何游戏客户端、资源文件或破解补丁**；客户端与各组件均由使用者自行从官方公开地址获取。

《原神》及相关素材的版权归米哈游 / COGNOSPHERE 所有。请勿用于商业用途、公开传播游戏资源或任何盈利行为，并请支持正版游戏。

## 更新日志

- **2026-11-22（三次更新）**：改为「官方链接优先 + 小 Kit」模型——Release 只放 14MB 的 `XH_YS_Kit.7z`（脚本/配置/补丁/便携启动器），其余组件全部走官方链接，由 `组装.bat` 自动下载摆放
- **2026-11-22（二次更新）**：去掉 70GB 整合包；客户端改用官方 CDN 直链；`run_mongo.cmd` 首次启动自动创建 `data` / `log`
- **2026-11-22** 首次发布：一键部署脚本、部署教程、打包说明、目录规范
