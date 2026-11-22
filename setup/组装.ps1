# ============================================================
#  组装.ps1  —— 按官方链接把缺的组件补齐，再交给「一键部署」
#
#  用法：双击 教程\组装.bat
#        或在本目录执行：
#        powershell -ExecutionPolicy Bypass -File .\组装.ps1
#
#  它只做三件事：
#    1) 缺什么下什么（Java 17 / MongoDB / 服务端 jar / resources / 插件）
#    2) 把下载的东西摆到 XH_YS 规定的目录里
#    3) 客户端没放齐就提示你去下官方包，放齐了就直接进入部署
#
#  重复运行是安全的：已经齐了的组件会跳过。
# ============================================================

$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ---------- 路径 ----------
$KitDir  = $PSScriptRoot
$Root    = Split-Path -Parent $KitDir
$CfgDir  = Join-Path $Root  '配置'
$SrvDir  = Join-Path $CfgDir '服务端'
$DbDir   = Join-Path $CfgDir '数据库'
$ToolDir = Join-Path $CfgDir '工具'
$GameDir = Join-Path $Root  '游戏'
$TmpDir  = Join-Path $env:TEMP ('xhys_asm_' + [Guid]::NewGuid().ToString('N').Substring(0,8))

# ---------- 官方链接（要换版本改这里） ----------
$UrlJava      = 'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse'
$UrlMongo     = 'https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-7.0.5.zip'
$UrlJar       = 'https://github.com/Grasscutters/Grasscutter/releases/download/v1.7.4/grasscutter-1.7.4.jar'
$UrlResources = 'https://gitlab.com/api/v4/projects/35984297/repository/archive.zip'
$UrlPlugin    = 'https://github.com/jie65535/gc-opencommand-plugin/releases/download/v1.7.0/opencommand-1.7.0.jar'
$UrlClient    = 'https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20230804185804_eTmE8EZjJZdAJapq/GenshinImpact_4.0.0.zip'
$UrlAudio     = 'https://autopatchhk.yuanshen.com/client_app/download/pc_zip/20230804185804_eTmE8EZjJZdAJapq/Audio_Chinese_4.0.0.zip'

# ---------- 小工具 ----------
function Say  ($m, $c = 'Cyan')   { Write-Host $m -ForegroundColor $c }
function Ok   ($m)                { Write-Host ('  [OK] '   + $m) -ForegroundColor Green }
function Skip ($m)                { Write-Host ('  [跳过] ' + $m) -ForegroundColor DarkGray }
function Note ($m)                { Write-Host ('  [说明] ' + $m) -ForegroundColor Yellow }
function Bad  ($m)                { Write-Host ('  [问题] ' + $m) -ForegroundColor Red }
function Step ($i, $m)            { Write-Host ''; Write-Host ('== ' + $i + ' ' + $m) -ForegroundColor Cyan }

function EnsureDir($p) {
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

# 用 Windows 自带的 curl 下载（带断点续传 + 进度条），失败回退到 Invoke-WebRequest
function Get-File($url, $dest) {
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue }
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        & $curl -L --fail --retry 3 --retry-delay 5 -C - --progress-bar -o $dest $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $dest)) { return $true }
        Write-Host ''
        Note ('curl 下载失败（退出码 ' + $LASTEXITCODE + '），换 .NET 再试一次')
    }
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 900 -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# 解压：有 7-Zip 就用 7-Zip，没有就用系统自带的 Expand-Archive
function Expand-Any($file, $dst) {
    $sevenZip = $null
    foreach ($p in @('D:\Program Files\7-Zip\7z.exe', 'C:\Program Files\7-Zip\7z.exe', 'C:\Program Files (x86)\7-Zip\7z.exe')) {
        if (Test-Path -LiteralPath $p) { $sevenZip = $p; break }
    }
    if (-not $sevenZip) {
        $cmd = Get-Command '7z.exe' -ErrorAction SilentlyContinue
        if ($cmd) { $sevenZip = $cmd.Source }
    }
    EnsureDir $dst
    if ($sevenZip) {
        & $sevenZip x -y ('-o' + $dst) $file | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    try {
        Expand-Archive -LiteralPath $file -DestinationPath $dst -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# 在目录树里找名字匹配的文件夹（取最浅的一个）
function Find-Dir($base, $name) {
    $hit = Get-ChildItem -LiteralPath $base -Recurse -Directory -Filter $name -ErrorAction SilentlyContinue |
           Sort-Object { $_.FullName.Length } | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}

# ---------- 抬头 ----------
Say ''
Say '======================================================='
Say '  原神 4.0 私服 · 一键组装（缺什么下什么）'
Say '======================================================='
Say ('  根目录 : ' + $Root)
Say ('  临时目录 : ' + $TmpDir)
if (Test-Path -LiteralPath $TmpDir) { Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
EnsureDir $TmpDir

foreach ($d in @($CfgDir, $SrvDir, $DbDir, $ToolDir, $GameDir, (Join-Path $Root '脚本'), $KitDir)) { EnsureDir $d }
EnsureDir (Join-Path $DbDir 'data')
EnsureDir (Join-Path $DbDir 'log')
EnsureDir (Join-Path $SrvDir 'plugins')

# ---------- 1/6 Java 17 ----------
Step '1/6' 'Java 17'
$javaHome   = Join-Path $ToolDir 'jdk-17'
$javaExe    = Join-Path $javaHome 'bin\java.exe'
$javaPathTxt = Join-Path $CfgDir 'java_path.txt'

if (Test-Path -LiteralPath $javaExe) {
    Skip '随包已有的 JDK 17（配置\工具\jdk-17）'
} elseif ((Test-Path -LiteralPath $javaPathTxt) -and (Test-Path -LiteralPath ((Get-Content -LiteralPath $javaPathTxt -Raw).Trim()))) {
    Skip ('已记录 Java 路径：' + (Get-Content -LiteralPath $javaPathTxt -Raw).Trim())
} else {
    $hasJava = $false
    $cmd = Get-Command 'java.exe' -ErrorAction SilentlyContinue
    if ($cmd) {
        $v = (& $cmd.Source -version 2>&1 | Select-Object -First 1)
        if (("$v") -match '"17') { $hasJava = $true; Ok ('系统里已有 JDK 17：' + $cmd.Source) }
    }
    if (-not $hasJava) {
        Say '  没找到 JDK 17，开始下载 Temurin 17（约 182MB，来源 adoptium.net）...'
        $zip = Join-Path $TmpDir 'jdk17.zip'
        if (Get-File $UrlJava $zip) {
            if (Expand-Any $zip $TmpDir) {
                $found = Get-ChildItem -LiteralPath $TmpDir -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    if (Test-Path -LiteralPath $javaHome) { Remove-Item -LiteralPath $javaHome -Recurse -Force -ErrorAction SilentlyContinue }
                    Move-Item -LiteralPath $found.FullName -Destination $javaHome
                    if (Test-Path -LiteralPath $javaExe) {
                        Set-Content -LiteralPath $javaPathTxt -Value $javaExe -Encoding UTF8
                        Ok ('已安装到 ' + $javaHome)
                    } else { Bad '解压后没找到 bin\java.exe' }
                } else { Bad '解压后没找到 jdk-17 目录' }
            } else { Bad 'JDK 压缩包解压失败' }
        } else {
            Bad '下载失败。手动方案：装 JDK 17 后重跑本脚本，或把 java.exe 的路径写进 配置\java_path.txt'
        }
    }
}

$javaFromTxt = $null
if (Test-Path -LiteralPath $javaPathTxt) { $javaFromTxt = (Get-Content -LiteralPath $javaPathTxt -Raw).Trim() }
$javaCheck = $null
if ($javaFromTxt -and (Test-Path -LiteralPath $javaFromTxt)) { $javaCheck = $javaFromTxt }
elseif (Test-Path -LiteralPath $javaExe) { $javaCheck = $javaExe }
# ---------- 2/6 MongoDB ----------
Step '2/6' 'MongoDB 7.0.5'
$mongod = Join-Path $DbDir 'bin\mongod.exe'
if (Test-Path -LiteralPath $mongod) {
    Skip '随包已有的 MongoDB（配置\数据库\bin\mongod.exe）'
} else {
    Say '  没找到 MongoDB，开始下载 7.0.5 免安装版（约 594MB，来源 fastdl.mongodb.org）...'
    $zip = Join-Path $TmpDir 'mongo.zip'
    if (Get-File $UrlMongo $zip) {
        $out = Join-Path $TmpDir 'mongo'
        if (Expand-Any $zip $out) {
            $bin = Find-Dir $out 'bin'
            if ($bin -and (Test-Path -LiteralPath (Join-Path $bin 'mongod.exe'))) {
                $target = Join-Path $DbDir 'bin'
                EnsureDir $target
                Get-ChildItem -LiteralPath $bin -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $target -Force }
                Ok ('已放到 ' + $target)
            } else { Bad '压缩包里没找到 bin\mongod.exe' }
        } else { Bad 'MongoDB 压缩包解压失败' }
    } else {
        Bad '下载失败。手动方案：下 ' + $UrlMongo + ' ，把里面的 bin 目录整个拷到 配置\数据库\bin'
    }
}

# ---------- 3/6 Grasscutter 服务端 ----------
Step '3/6' 'Grasscutter 1.7.4 服务端 jar'
$jar = Get-ChildItem -LiteralPath $SrvDir -Filter 'grasscutter-*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($jar) {
    Skip ('随包已有的 ' + $jar.Name)
} else {
    Say '  开始下载 grasscutter-1.7.4.jar（约 98MB，来源 GitHub Releases）...'
    $dst = Join-Path $SrvDir 'grasscutter-1.7.4.jar'
    if (Get-File $UrlJar $dst) { Ok '已放到 配置\服务端\' }
    else { Bad ('下载失败。手动方案：下 ' + $UrlJar + ' 放到 配置\服务端\') }
}

# ---------- 4/6 resources（4.0 资源，约 1GB） ----------
Step '4/6' 'resources（4.0 游戏资源配置）'
$resDir = Join-Path $SrvDir 'resources'
if (Test-Path -LiteralPath $resDir) {
    Skip '随包已有的 配置\服务端\resources'
} else {
    Say '  缺 resources，来源 GitLab（约 1GB，国内可能较慢，断点续传可重跑）'
    Say ('  ' + $UrlResources)
    $go = Read-Host '  现在下载？(Y/N)'
    if ($go -match '^[Yy]') {
        $zip = Join-Path $TmpDir 'resources.zip'
        if (Get-File $UrlResources $zip) {
            $out = Join-Path $TmpDir 'res'
            if (Expand-Any $zip $out) {
                $hit = Find-Dir $out 'resources'
                if ($hit) {
                    Move-Item -LiteralPath $hit -Destination $resDir
                    Ok '已放到 配置\服务端\resources'
                } else { Bad '压缩包里没找到 resources 目录，请手动放' }
            } else { Bad 'resources 压缩包解压失败' }
        } else { Bad '下载失败（GitLab 有时会断），重跑本脚本会续传' }
    } else {
        Note '跳过。没有 resources 服务端起不来，之后可以重跑本脚本或手动放 配置\服务端\resources'
    }
}

# ---------- 5/6 opencommand 插件 ----------
Step '5/6' 'opencommand 插件（给指令工具用）'
$pluginDir = Join-Path $SrvDir 'plugins'
$plug = Get-ChildItem -LiteralPath $pluginDir -Filter 'opencommand*.jar' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($plug) {
    Skip ('已有 ' + $plug.Name)
} else {
    Say '  开始下载 opencommand-1.7.0.jar（约 100KB）...'
    $dst = Join-Path $pluginDir 'opencommand-1.7.0.jar'
    if (Get-File $UrlPlugin $dst) { Ok '已放到 配置\服务端\plugins\' }
    else { Bad ('下载失败。手动方案：下 ' + $UrlPlugin + ' 放到 配置\服务端\plugins\') }
}

# ---------- 6/6 客户端 ----------
Step '6/6' '游戏客户端（4.0.0 本体 + 中文语音，官方 CDN）'
$exe = Join-Path $GameDir 'GenshinImpact.exe'
$audio = Join-Path $GameDir 'GenshinImpact_Data\StreamingAssets\AudioAssets\Chinese'
if ((Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $audio)) {
    Ok '客户端和中文语音都在'
} else {
    if (-not (Test-Path -LiteralPath $exe)) {
        Say '  缺客户端本体（56.16GB）：' -c Yellow
        Say ('  ' + $UrlClient)
        Say '  下完解压到 游戏\（zip 里没有多余一层目录，解压完应该直接看到 GenshinImpact.exe）'
    }
    if (-not (Test-Path -LiteralPath $audio)) {
        Say '  缺中文语音包（10.45GB）：' -c Yellow
        Say ('  ' + $UrlAudio)
        Say '  同样解压到 游戏\，提示合并就合并（会落到 GenshinImpact_Data\StreamingAssets\AudioAssets\Chinese）'
    }
    Note '客户端体积太大，脚本不代下；用浏览器 / IDM / 迅雷都行，支持断点续传。放好后重跑本脚本即可。'
}

# ---------- 收尾 ----------
Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
Say ''
Say '======================================================='
Say '  组装结果'
Say '======================================================='
$checks = @(
    @{ n = 'Java 17';        p = $javaCheck },
    @{ n = 'MongoDB';        p = $mongod },
    @{ n = '服务端 jar';     p = $(if ($jar) { $jar.FullName } else { Join-Path $SrvDir 'grasscutter-1.7.4.jar' }) },
    @{ n = 'resources';      p = $resDir },
    @{ n = 'opencommand 插件'; p = (Join-Path $pluginDir 'opencommand-1.7.0.jar') },
    @{ n = '客户端本体';     p = $exe },
    @{ n = '中文语音';       p = $audio }
)
foreach ($c in $checks) {
    if ($c.p -and (Test-Path -LiteralPath $c.p)) { Ok $c.n } else { Bad ($c.n + ' 还缺') }
}

$allOk = $true
foreach ($c in $checks) { if (-not ($c.p -and (Test-Path -LiteralPath $c.p))) { $allOk = $false } }

Say ''
if ($allOk) {
    Say '  全部齐了。下一步：双击 教程\一键部署.bat（它会装补丁、写启动器配置、试跑数据库）' 'Green'
} else {
    Say '  还有东西没齐，按上面的提示补齐后重跑本脚本。' 'Yellow'
}
Say ''
$pause = Read-Host '按回车关闭窗口'
