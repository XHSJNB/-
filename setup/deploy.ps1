param(
    [switch]$OnlyCheck,
    [switch]$AutoStart
)

# ============================================================
#  原神 4.0 私服 一键部署 / 环境自检
#  作用：把「解压到任意路径」变成「双击就能用」
#  做四件事：
#    1. 找 Java 17（找不到就问要不要自动下载 Temurin 17）
#    2. 修客户端补丁（version.dll / PublicKey.txt）
#    3. 生成/修正 Cultivation 启动器配置（路径按本机实际情况写）
#    4. 检测 443 端口、试跑一次 MongoDB、检查运行库与长路径
#  最后可以直接帮你开服。
# ============================================================

$ErrorActionPreference = 'Continue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Here = $PSScriptRoot
$Root = Split-Path -Parent $Here
$CfgDir   = Join-Path $Root '配置'
$ToolDir  = Join-Path $CfgDir '工具'
$GameDir  = Join-Path $Root '游戏'
$Scripts  = Join-Path $Root '脚本'
$ServerDir= Join-Path $CfgDir '服务端'
$DbDir    = Join-Path $CfgDir '数据库'
$JavaNote = Join-Path $CfgDir 'java_path.txt'

$script:warnings = @()
$script:problems = @()

function Title($t) {
    Write-Host ''
    Write-Host ('== ' + $t + ' ' + ('=' * [Math]::Max(4, 46 - $t.Length))) -ForegroundColor Cyan
}
function Step($n, $t) { Write-Host ''; Write-Host ("[$n] $t") -ForegroundColor Cyan }
function OK($m)   { Write-Host ('   [OK]   ' + $m) -ForegroundColor Green }
function WARN($m) { Write-Host ('   [注意] ' + $m) -ForegroundColor Yellow; $script:warnings += $m }
function FAIL($m) { Write-Host ('   [问题] ' + $m) -ForegroundColor Red;    $script:problems += $m }

Title '原神 4.0 私服 - 一键部署'
Write-Host ("文件夹位置：" + $Root)

# ---------- 0. 结构 & 路径 ----------
Step '1/7' '检查文件夹结构和解压位置'
$need = @{
    '游戏（客户端）'   = $GameDir
    '配置\服务端'      = $ServerDir
    '配置\数据库'      = $DbDir
    '配置\工具'        = $ToolDir
    '脚本'            = $Scripts
}
foreach ($k in $need.Keys) {
    if (Test-Path -LiteralPath $need[$k]) { OK ($k + ' 存在') } else { FAIL ($k + ' 缺失：' + $need[$k] + '（压缩包可能没解压完整）') }
}
if (Test-Path -LiteralPath (Join-Path $GameDir 'GenshinImpact.exe')) { OK '客户端主程序 GenshinImpact.exe 存在' } else { FAIL '找不到 游戏\GenshinImpact.exe' }
if (Test-Path -LiteralPath (Join-Path $ServerDir 'grasscutter-1.7.4.jar')) { OK '服务端 grasscutter-1.7.4.jar 存在' } else { FAIL '找不到 配置\服务端\grasscutter-1.7.4.jar' }

if ($Root.Length -gt 70) { WARN ('路径太长（' + $Root.Length + ' 字符），建议解压到 D:\XH_YS 这类短路径，否则个别文件可能读写失败') }
if ($Root -match 'Program Files|OneDrive|\\Windows\\') { WARN '当前路径带了 Program Files / OneDrive / Windows，权限或同步会出问题，请换到 D:\ 根目录一类的地方' }

# ---------- 1. Java ----------
Step '2/7' '检查 Java 17（服务端必需）'

function Test-JavaExe {
    param([string]$p)
    if ([string]::IsNullOrWhiteSpace($p)) { return $false }
    if (-not (Test-Path -LiteralPath $p)) { return $false }
    try {
        $out = (& $p -version 2>&1 | Out-String)
    } catch { return $false }
    if ($out -match 'version\s+"(\d+)') { return ([int]$Matches[1] -ge 17) }
    return $false
}

function Find-Java {
    $cands = @()

    # a) 上次记录
    if (Test-Path -LiteralPath $JavaNote) {
        $saved = (Get-Content -LiteralPath $JavaNote -Raw).Trim()
        if ($saved) { $cands += $saved }
    }
    # b) 随包携带的 JDK
    foreach ($d in @((Join-Path $ToolDir 'jdk-17'), (Join-Path $ToolDir 'jdk'))) {
        $cands += (Join-Path $d 'bin\java.exe')
    }
    $cands += @(Get-ChildItem -LiteralPath $ToolDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^jdk' } |
                ForEach-Object { Join-Path $_.FullName 'bin\java.exe' })
    # c) PATH
    $cmd = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($cmd) { $cands += $cmd.Source }
    # d) 常见安装目录
    $bases = @('C:\Program Files\Java','C:\Program Files\Eclipse Adoptium','C:\Program Files\Microsoft',
               'C:\Program Files\Amazon Corretto','C:\Program Files\Zulu','C:\Program Files\BellSoft',
               'C:\Program Files (x86)\Java','C:\Program Files (x86)\Eclipse Adoptium','C:\Program Files (x86)\Microsoft')
    foreach ($b in $bases) {
        if (-not (Test-Path -LiteralPath $b)) { continue }
        $cands += @(Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match 'jdk|jre' } |
                    ForEach-Object { Join-Path $_.FullName 'bin\java.exe' })
    }
    # e) 注册表
    foreach ($rk in @('HKLM:\SOFTWARE\JavaSoft\JDK','HKLM:\SOFTWARE\JavaSoft\Java Development Kit',
                      'HKLM:\SOFTWARE\Eclipse Adoptium\JDK')) {
        if (-not (Test-Path -LiteralPath $rk)) { continue }
        foreach ($sub in (Get-ChildItem -LiteralPath $rk -ErrorAction SilentlyContinue)) {
            $jhome = $null
            try { $jhome = (Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction Stop).JavaHome } catch {}
            if (-not $jhome) { try { $jhome = (Get-ItemProperty -LiteralPath $sub.PSPath -ErrorAction Stop).InstallationPath } catch {} }
            if ($jhome) { $cands += (Join-Path $jhome 'bin\java.exe') }
        }
    }

    # 先挑真正的 JDK 目录，最后才接受 PATH 里的 javapath 转发壳（更稳）
    foreach ($relaxed in @($false, $true)) {
        foreach ($p in $cands) {
            if (-not $relaxed -and $p -match 'javapath') { continue }
            if (Test-JavaExe $p) { return $p }
        }
    }
    return $null
}

$javaExe = Find-Java

if ($javaExe) {
    $ver = (& $javaExe -version 2>&1 | Out-String).Trim().Split("`n")[0]
    OK ('已找到 Java：' + $javaExe)
    Write-Host ('          ' + $ver)
} else {
    Write-Host '   没有找到 Java 17。' -ForegroundColor Yellow
    Write-Host '   说明：服务端是 jar 程序，必须有 Java 17 才能跑（自带 60MB 左右的 JDK 也行）。' -ForegroundColor Gray
    if (-not $OnlyCheck) {
        Write-Host ''
        Write-Host '   可以现在自动下载 Adoptium Temurin 17（开源免费版，约 190MB，需要联网）。' -ForegroundColor Gray
        $ans = Read-Host '   是否自动下载并安装到 配置\工具\jdk-17 ？(Y/N)'
        if ($ans -match '^[yY]') {
            $urls = @(
                'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse',
                'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip'
            )
            $zip = Join-Path $env:TEMP 'temurin17-jdk.zip'
            $tmp = Join-Path $env:TEMP ('temurin17_' + [Guid]::NewGuid().ToString('N').Substring(0,8))
            $done = $false
            foreach ($u in $urls) {
                try {
                    Write-Host ('   下载中：' + $u) -ForegroundColor Gray
                    Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing -TimeoutSec 900
                    if ((Get-Item -LiteralPath $zip).Length -gt 50MB) { $done = $true; break }
                } catch {
                    Write-Host ('   这个地址失败：' + $_.Exception.Message) -ForegroundColor DarkYellow
                }
            }
            if ($done) {
                Write-Host '   解压中（1~3 分钟）...' -ForegroundColor Gray
                try {
                    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
                    $inner = Get-ChildItem -LiteralPath $tmp -Directory | Where-Object { $_.Name -match '^jdk' } | Select-Object -First 1
                    if ($inner) {
                        $dst = Join-Path $ToolDir 'jdk-17'
                        if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
                        Move-Item -LiteralPath $inner.FullName -Destination $dst
                        $candidate = Join-Path $dst 'bin\java.exe'
                        if (Test-JavaExe $candidate) { $javaExe = $candidate; OK ('Java 已装好：' + $candidate) }
                        else { FAIL '下载的 Java 无法运行，请手动安装 JDK 17 后重试' }
                    } else { FAIL '压缩包里没有找到 jdk 目录' }
                } catch { FAIL ('解压失败：' + $_.Exception.Message) }
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            } else {
                FAIL '自动下载失败，请手动装 JDK 17（见 教程\部署教程.md 第 2 步）'
            }
        } else {
            FAIL '未安装 Java 17，服务端起不来（见 教程\部署教程.md 第 2 步）'
        }
    } else {
        FAIL '未找到 Java 17'
    }
}

if ($javaExe) {
    [IO.File]::WriteAllText($JavaNote, $javaExe, (New-Object Text.UTF8Encoding($false)))
    OK ('已记录 Java 路径到 配置\java_path.txt（脚本和 run_server.cmd 都读它）')
}

# ---------- 2. 客户端补丁 ----------
Step '3/7' '检查客户端补丁（version.dll / PublicKey.txt）'
$master = Join-Path $ToolDir 'patch_master'
$files = @('version.dll', 'PublicKey.txt')
foreach ($f in $files) {
    $m = Join-Path $master $f
    $g = Join-Path $GameDir $f
    if ((Test-Path -LiteralPath $m) -and (Test-Path -LiteralPath $g)) {
        try {
            $same = (Get-FileHash -LiteralPath $m -Algorithm MD5).Hash -eq (Get-FileHash -LiteralPath $g -Algorithm MD5).Hash
            if ($same) { OK ($f + ' 已在客户端，且与母本一致') } else { Copy-Item -LiteralPath $m -Destination $g -Force; OK ($f + ' 与母本不一致，已用母本覆盖') }
        } catch { WARN ($f + ' 校验失败（可能被占用）') }
    } elseif ((Test-Path -LiteralPath $m) -and -not (Test-Path -LiteralPath $g)) {
        Copy-Item -LiteralPath $m -Destination $g -Force
        OK ($f + ' 缺失，已从 patch_master 装回')
    } elseif (-not (Test-Path -LiteralPath $m) -and (Test-Path -LiteralPath $g)) {
        Copy-Item -LiteralPath $g -Destination $m -Force
        OK ($f + ' 母本缺失，已用客户端里的备份补齐')
    } else {
        FAIL ($f + ' 在客户端和 patch_master 里都找不到，缺它进游戏会报 4206 / 4214')
    }
}

# ---------- 3. 启动器配置 ----------
Step '4/7' '生成启动器配置（Cultivation）'
$appdata = Join-Path $env:APPDATA 'cultivation'
$cfg = Join-Path $appdata 'configuration.json'
$running = Get-Process Cultivation -ErrorAction SilentlyContinue
if ($running) { WARN '启动器正在运行，配置可能被它退出时覆盖；建议先关掉启动器再跑一次本脚本' }

if (-not (Test-Path -LiteralPath $appdata)) { New-Item -ItemType Directory -Force -Path $appdata | Out-Null }

$template = @{
    toggle_grasscutter      = $true
    game_install_path       = (Join-Path $GameDir 'GenshinImpact.exe')
    grasscutter_with_game   = $false
    grasscutter_path        = (Join-Path $ServerDir 'grasscutter-1.7.4.jar')
    java_path               = $javaExe
    close_action            = 0
    startup_launch          = $false
    last_ip                 = '127.0.0.1'
    last_port               = '443'
    language                = 'chs'
    custom_background       = ''
    use_theme_background    = $false
    cert_generated          = $false
    theme                   = 'default'
    https_enabled           = $false
    debug_enabled           = $true
    patch_rsa               = $true
    use_internal_proxy      = $true
    wipe_login              = $false
    horny_mode              = $false
    auto_mongodb            = $false
    un_elevated             = $true
    redirect_more           = $false
    grasscutter_elevation   = 'None'
    other_redirects         = $false
}

if (Test-Path -LiteralPath $cfg) {
    try {
        $j = (Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json)
        # 只覆盖跟路径/连接有关的字段，保留界面上其它设置
        foreach ($k in @('toggle_grasscutter','game_install_path','grasscutter_path','java_path',
                         'https_enabled','patch_rsa','use_internal_proxy','last_ip','last_port')) {
            if ($template.ContainsKey($k)) { $j | Add-Member -NotePropertyName $k -NotePropertyValue $template[$k] -Force }
        }
        $out = ($j | ConvertTo-Json -Depth 10 -Compress)
    } catch {
        $out = ($template | ConvertTo-Json -Depth 10 -Compress)
    }
} else {
    $out = ($template | ConvertTo-Json -Depth 10 -Compress)
}
try {
    [IO.File]::WriteAllText($cfg, $out, (New-Object Text.UTF8Encoding($false)))
    OK ('已写入 ' + $cfg)
    OK ('game_install_path = ' + $template.game_install_path)
    OK ('grasscutter_path  = ' + $template.grasscutter_path)
    OK ('java_path         = ' + $template.java_path)
} catch { FAIL ('写启动器配置失败：' + $_.Exception.Message) }

# ---------- 4. 端口 ----------
Step '5/7' '检查 443 / 27017 端口'
$c443 = Get-NetTCPConnection -State Listen -LocalPort 443 -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $c443) {
    OK '443 空闲（服务端要用）'
} else {
    $pname = '未知进程'
    try { $pname = (Get-Process -Id $c443.OwningProcess -ErrorAction Stop).ProcessName } catch {}
    if ($pname -eq 'java') { OK '443 已被 java 占用 —— 服务端好像已经在跑了' }
    else { FAIL ('443 被 ' + $pname + ' 占用，服务端起不来。先关掉它（常见是 IIS / 其它 web 服务 / 残留代理）') }
}
$c27 = Get-NetTCPConnection -State Listen -LocalPort 27017 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($c27) { OK '27017 已在监听（MongoDB 正在跑）' } else { OK '27017 空闲（MongoDB 还没起，属于正常）' }

# ---------- 5. MongoDB 试跑 ----------
Step '6/7' '试跑一次 MongoDB（验证它能在这台机器上启动）'
$mongod = Join-Path $DbDir 'bin\mongod.exe'
if (-not (Test-Path -LiteralPath $mongod)) {
    FAIL '找不到 配置\数据库\bin\mongod.exe（解压不完整？）'
} elseif (Get-NetTCPConnection -State Listen -LocalPort 27017 -ErrorAction SilentlyContinue) {
    OK 'MongoDB 本来就在跑，跳过试跑'
} else {
    $dataDir = Join-Path $DbDir 'data'
    $logFile = Join-Path $DbDir 'log\deploy_test.log'
    if (-not (Test-Path -LiteralPath $dataDir)) { New-Item -ItemType Directory -Force -Path $dataDir | Out-Null }
    $p = Start-Process -FilePath $mongod -ArgumentList @('--dbpath', $dataDir, '--logpath', $logFile,
            '--wiredTigerCacheSizeGB', '1', '--bind_ip', '127.0.0.1', '--port', '27017') -PassThru -WindowStyle Hidden
    $t = 0; $up = $false
    while ($t -lt 20) {
        Start-Sleep -Seconds 1; $t++
        if (Get-NetTCPConnection -State Listen -LocalPort 27017 -ErrorAction SilentlyContinue) { $up = $true; break }
        if ($p.HasExited) { break }
    }
    if ($up) {
        OK ('MongoDB 能正常启动（' + $t + 's）')
        & $mongod --dbpath $dataDir --shutdown 2>$null | Out-Null
        Start-Sleep -Seconds 3
        Stop-Process -Name mongod -Force -ErrorAction SilentlyContinue
        OK '已正常关闭，数据库文件没被占用'
    } else {
        Stop-Process -Name mongod -Force -ErrorAction SilentlyContinue
        FAIL 'MongoDB 起不来，多半缺运行库（微软 VC++ 2015-2022 x64）'
        if (Test-Path -LiteralPath $logFile) {
            Write-Host '   ---- mongod 日志末尾 ----' -ForegroundColor DarkGray
            Get-Content -LiteralPath $logFile -Tail 6 | ForEach-Object { Write-Host ('   ' + $_) -ForegroundColor DarkGray }
        }
    }
    Remove-Item -LiteralPath $logFile -Force -ErrorAction SilentlyContinue
}

# ---------- 6. 运行库 / 系统 ----------
Step '7/7' '检查系统运行库与小设置'
$vc = Join-Path $env:SystemRoot 'System32\vcruntime140.dll'
if (Test-Path -LiteralPath $vc) { OK '系统里有 VC++ 运行库（vcruntime140.dll）' }
else { WARN '没找到 vcruntime140.dll，MongoDB 和游戏可能起不来：装一下 https://aka.ms/vs/17/release/vc_redist.x64.exe' }

try {
    $lp = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction Stop).LongPathsEnabled
    if ($lp -ne 1) { WARN '系统未启用长路径支持（一般不影响，实在解压报错再用它：https://learn.microsoft.com/zh-cn/windows/win32/fileio/maximum-file-path-limitation）' }
    else { OK '长路径支持已开启' }
} catch {}

$os = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
if ($os) { Write-Host ('   系统：' + $os) -ForegroundColor Gray }
if (-not [Environment]::Is64BitOperatingSystem) { FAIL '需要 64 位 Windows（客户端和服务端都只有 x64）' }

# ---------- 汇总 ----------
Write-Host ''
Write-Host ('=' * 60) -ForegroundColor Cyan
if ($script:problems.Count -gt 0) {
    Write-Host ('自检发现 ' + $script:problems.Count + ' 个必须先解决的问题：') -ForegroundColor Red
    foreach ($p in $script:problems) { Write-Host ('  - ' + $p) -ForegroundColor Red }
    Write-Host ''
    Write-Host '按提示处理好后，再双击一次「一键部署.bat」。详细说明见 教程\部署教程.md。' -ForegroundColor Yellow
} else {
    Write-Host '环境自检通过，可以直接开服了。' -ForegroundColor Green
    if ($script:warnings.Count -gt 0) {
        Write-Host ('有 ' + $script:warnings.Count + ' 条提醒（不影响启动，建议看一眼）：') -ForegroundColor Yellow
        foreach ($w in $script:warnings) { Write-Host ('  - ' + $w) -ForegroundColor Yellow }
    }
}

# ---------- 开服 ----------
if (-not $OnlyCheck -and $script:problems.Count -eq 0) {
    Write-Host ''
    if (Get-Process GenshinImpact -ErrorAction SilentlyContinue) {
        Write-Host '游戏已经在运行，不需要再启动一次。' -ForegroundColor Yellow
    } else {
        $go = $true
        if (-not $AutoStart) {
            $ans = Read-Host '现在直接开服并进游戏？(Y/N)'
            if ($ans -notmatch '^[yY]') { $go = $false }
        }
        if ($go) {
            $bat = Join-Path $Scripts '开始游戏.bat'
            if (Test-Path -LiteralPath $bat) {
                Write-Host '正在启动：脚本\开始游戏.bat（它会依次起数据库 → 服务端 → 启动器 → 游戏）' -ForegroundColor Cyan
                Start-Process -FilePath $bat -WorkingDirectory $Scripts
                Write-Host ''
                Write-Host '接下来：等游戏窗口出来 → 弹登录框就输 test / 123456（首次会自动建号）→ 看到「点击进入」点一下。' -ForegroundColor Yellow
                Write-Host '玩完双击 脚本\关闭游戏.bat。' -ForegroundColor Yellow
            } else {
                Write-Host ('找不到 ' + $bat) -ForegroundColor Red
            }
        }
    }
}
Write-Host ''
