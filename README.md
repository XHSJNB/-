# 原神 4.0 单机私服 · 一键部署包（Grasscutter 1.7.4）

> 本仓库只提供**部署脚本、说明文档与目录规范**，**不包含游戏客户端与任何游戏资源文件**。
> 完整运行包约 **70GB**（客户端 66GB + 服务端/数据库/工具约 3GB），请按下文「获取完整包」自行准备。

一套已经调通、开箱即用的原神 4.0 国际版离线私服环境：双击一个 bat，从起数据库到进游戏全自动，不用改 hosts、不用装 MongoDB、不用手填启动器路径。

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
| 硬盘 | 约 **70GB** 可用空间 |
| Java | **JDK 17**（`一键部署.bat` 会自动检测/下载 Temurin 17） |
| 运行库 | 微软 VC++ 2015-2022 x64（MongoDB 需要） |
| 权限 | 普通用户即可，**不需要管理员** |
| 网络 | 仅首次装 Java 时需要联网 |

## 三、获取完整包

完整包 = 客户端 66GB + 服务端/数据库/工具约 3GB。用 7-Zip 以「仅存储」模式打包，体积仍约 70GB（客户端是音频与资源包，基本压不动）。

三种拿到方式：

1. **网盘分享链接（推荐）** —— 阿里云盘 / 123 云盘的分享页可在**网页直接下载**，不用装客户端。
   *（链接位：由仓库维护者补充）*
2. **移动硬盘 / U 盘** —— 直接拷贝整个 `XH_YS` 文件夹，最快、最稳。
3. **自己组装** —— 见附录 A。

> **为什么不用 GitHub Release 直接放包？**
> GitHub 网页上传单文件 25MB、`git push` 单文件 100MB 硬性拦截、Release 附件单文件 2GB、LFS 免费额度仅 1GB。70GB 至少要切成 35 个 2GB 分卷，上传 8 小时起；并且公开仓库分发游戏客户端资源会触发版权下架，链接失效后朋友反而更拿不到。所以本仓库只做「说明页 + 脚本分发」。

## 四、完整包的目录结构

```
XH_YS
├─ 游戏\                   原神 4.0 国际版客户端（约 66GB，GenshinImpact.exe + GenshinImpact_Data…）
├─ 配置\
│   ├─ 服务端\             Grasscutter 1.7.4（jar、config.json、resources、plugins、data、日志）
│   ├─ 数据库\             MongoDB 7.0.5（bin / data / log）
│   ├─ 工具\               Cultivation 启动器、patch_master 补丁母本、GcTools 指令工具
│   ├─ 教程源码\           Grasscutter_build（参考用）
│   └─ java_path.txt       本机 JDK 17 路径，由一键部署写入
├─ 脚本\                   开始游戏.bat / 关闭游戏.bat / 指令工具.bat + 底层 ps1、cmd + 说明.md
└─ 教程\                   部署教程.md、一键部署.bat、自检.bat、打包与分享说明.md、deploy.ps1
```

## 五、三步部署

1. **解压**到短路径（推荐 `D:\XH_YS`），别放 `Program Files`、`OneDrive`、桌面深层目录。用 7-Zip / Bandizip / WinRAR 解压，分卷包把所有分卷放同一目录后解压第一卷。
2. **双击 `教程\一键部署.bat`**。它会依次做：
   1. 检查四个文件夹、`GenshinImpact.exe`、`grasscutter-1.7.4.jar` 是否齐全，并检查解压路径是否过长/在受保护目录
   2. 找 Java 17（PATH、随包 JDK、常见安装目录、注册表），找不到就询问是否自动下载 Temurin 17 并装到 `配置\工具\jdk-17`，把结果写进 `配置\java_path.txt`
   3. 校验并自动修复客户端补丁 `version.dll` / `PublicKey.txt`
   4. 按本机真实路径生成 Cultivation 启动器配置（`toggle_grasscutter/https_enabled/patch_rsa/use_internal_proxy` 全部预设正确）
   5. 检查 443 / 27017 是否被占用（冲突时指出是哪个进程）
   6. 真跑一次 mongod 验证数据库能启动，再正常关闭
   7. 检查 VC++ 运行库、长路径、系统位数
3. 最后问「现在直接开服并进游戏？」—— 输 **Y**，它会拉起 `脚本\开始游戏.bat`。弹 HOYOVERSE 登录框时账号 `test`、密码 `123456`（随便填也会自动建号），看到「点击进入」点一下即可。

以后每次玩：直接双击 **`脚本\开始游戏.bat`**；玩完双击 **`脚本\关闭游戏.bat`**（会连系统代理一起复位）。

## 六、账号与常用指令

| 项 | 值 |
| --- | --- |
| 账号 / 密码 | `test` / `123456`（首次登录自动建号） |
| 默认 UID | `10001` |
| 管理权限 | 已授 `*`（全权限） |
| 游戏内指令 | 聊天框输入，以 `/` 开头：`/give 201 99999`（原石）、`/prop 1000 3000`、`/permission list`、`/help` |
| 图形化指令 | 双击 `脚本\指令工具.bat`（GcTools，地址与 token 已预置） |

## 七、常见问题

| 现象 | 原因 / 处理 |
| --- | --- |
| 网络错误 4206 / 4214 / 4210 | 客户端缺 `version.dll` 补丁（启动器退出时会删掉它）。重跑一键部署，或把 `配置\工具\patch_master\version.dll` 复制到 `游戏\` |
| 登录页 502 / 服务器繁忙 | 启动器没在跑（没有 8365 代理），或勾了「使用 HTTPS」。重跑 `开始游戏.bat`，启动器窗口别关 |
| 点【启动】只弹资源管理器 | 启动器里游戏路径填成了目录。重跑一键部署会自动改对 |
| 启动器闪退（退出码 101） | 必须带 `--no-admin` 启动（bat 已带好） |
| 服务端黑窗口报 Java 错误 | 没装 JDK 17。跑 `教程\自检.bat`，按提示装或让它自动下 |
| 443 被占用 | `Get-NetTCPConnection -State Listen -LocalPort 443` 看占用进程，常见是 IIS / 残留 java |
| MongoDB 起不来 | 缺 VC++ 运行库：<https://aka.ms/vs/17/release/vc_redist.x64.exe> |
| 玩完浏览器上不了网 | 系统代理没复位：跑 `关闭游戏.bat`，或手动关闭「使用代理服务器」 |
| 黑窗口里敲命令报「不是内部或外部命令」 | 那是上次运行留下的死窗口，关掉它重跑 `开始游戏.bat` |

## 八、本仓库内容

```
.
├─ README.md                    本说明
├─ .gitignore
├─ docs/
│   ├─ 部署教程.md              给收包的人：解压 → 部署 → 进游戏 → FAQ
│   ├─ 打包与分享说明.md         给分享者：7-Zip 打包参数、分卷、注意事项
│   └─ 完整说明.md              技术全量文档：目录、配置项、原理、排障、卡池/商城
├─ setup/
│   ├─ 一键部署.bat             环境自检 + 装 Java + 写启动器配置 + 可选开服
│   ├─ 自检.bat                 只检查不启动
│   └─ deploy.ps1               上面两个 bat 的实现
└─ scripts/
    ├─ 开始游戏.bat / 关闭游戏.bat / 指令工具.bat
    └─ start_all.ps1 / stop_all.ps1 / run_mongo.cmd / run_server.cmd
```

> `setup` 与 `scripts` 里的文件是完整包内同名文件的副本，方便先看代码再决定要不要用。单独放在本仓库时它们会因为找不到 `游戏`/`配置` 目录而自检失败，这是正常的——它们本来就是为完整包准备的。

## 附录 A：自己组装完整包

| 组件 | 版本 / 说明 |
| --- | --- |
| 客户端 | 原神 **4.0 国际版**（程序名 `GenshinImpact.exe`，不是 `YuanShen.exe`），含中文语音 |
| 服务端 | [Grasscutter](https://github.com/Grasscutters/Grasscutter) **1.7.4** + 4.0 `resources` + `plugins/opencommand` |
| 数据库 | MongoDB **7.0.5** 免安装版 |
| 启动器 | Cultivation **1.2.0**（带 `--no-admin`） |
| 补丁 | `version.dll`（RSA 公钥补丁）+ `PublicKey.txt`，放在客户端根目录 |

服务端 `config.json` 关键项：

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

启动器配置（`%APPDATA%\cultivation\configuration.json`）关键项：

```json
"toggle_grasscutter": true, "https_enabled": false,
"patch_rsa": true, "use_internal_proxy": true,
"last_ip": "127.0.0.1", "last_port": "443",
"game_install_path": "<...>\\游戏\\GenshinImpact.exe"
```

`useInRouting` 必须为 `false`：设成 `true` 会下发 `https://` 地址给明文端口，客户端直接报 4206。

## 免责声明

本项目仅用于**个人学习与研究**（游戏服务端协议模拟、逆向工程与自动化脚本实践），本仓库**不包含任何游戏客户端、资源文件或破解补丁**，全部由使用者自行准备。

《原神》及相关素材的版权归米哈游 / COGNOSPHERE 所有。请勿用于商业用途、公开传播游戏资源或任何盈利行为，并请支持正版游戏。

## 更新日志

- **2026-11-22** 首次发布：一键部署脚本（自动装 Java、修补丁、写启动器配置、试跑数据库）、部署教程、打包说明、完整包目录规范
- 服务端/客户端配置调优记录见 `docs/完整说明.md`
