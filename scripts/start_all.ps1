$ErrorActionPreference = 'Continue'
# 脚本自己算根目录：C:\XH_YS\脚本 -> C:\XH_YS
$Scripts = $PSScriptRoot
$Root    = Split-Path -Parent $Scripts
$GameDir = Join-Path $Root '游戏'

# Java 路径：优先读 配置\java_path.txt（由 教程\一键部署.bat 按本机实际情况写入），再自动找，最后退回默认
$javaNote = Join-Path $Root '配置\java_path.txt'
$javaExe = $null
if (Test-Path -LiteralPath $javaNote) { $javaExe = (Get-Content -LiteralPath $javaNote -Raw).Trim() }
if (-not $javaExe -or -not (Test-Path -LiteralPath $javaExe)) {
    $jcmd = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($jcmd) { $javaExe = $jcmd.Source }
}
if (-not $javaExe) { $javaExe = 'C:\Program Files\Java\jdk-17\bin\java.exe' }

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host '   原神 4.0 私服 Grasscutter  一键启动' -ForegroundColor Cyan
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ''

if (Get-Process GenshinImpact -ErrorAction SilentlyContinue) {
    Write-Host '游戏已经在运行了，不需要重复启动。' -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    exit
}

$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
try { Set-ItemProperty -LiteralPath $reg -Name ProxyEnable -Value 0 -Type DWord -ErrorAction Stop } catch {}

# ---------- 1. MongoDB ----------
if (Get-NetTCPConnection -State Listen -LocalPort 27017 -ErrorAction SilentlyContinue) {
    Write-Host '[1/6] MongoDB 已在运行' -ForegroundColor Green
} else {
    Write-Host '[1/6] 启动 MongoDB ...'
    Start-Process -FilePath (Join-Path $Scripts 'run_mongo.cmd') -WorkingDirectory $Scripts
    $wait = 0
    while ($wait -lt 30) {
        Start-Sleep -Seconds 1
        $wait++
        if (Get-NetTCPConnection -State Listen -LocalPort 27017 -ErrorAction SilentlyContinue) { break }
    }
}

# ---------- 2. 清掉残留服务端 ----------
Write-Host '[2/6] 清理残留服务端进程 ...'
Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'grasscutter' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# ---------- 3. 启动服务端 ----------
if (-not (Test-Path -LiteralPath $javaExe)) {
    Write-Host ('[提示] 没找到 Java 17：' + $javaExe) -ForegroundColor Red
    Write-Host '        先双击 教程\一键部署.bat，它会帮你装好。' -ForegroundColor Red
    Start-Sleep -Seconds 15
    exit 1
}
Write-Host '[3/6] 启动 Grasscutter 服务端（会另开一个窗口）...'
Start-Process -FilePath (Join-Path $Scripts 'run_server.cmd') -WorkingDirectory (Join-Path $Root '配置\服务端')

Write-Host '[4/6] 等待 127.0.0.1:443 真正就绪（最长 120 秒）...'
$deadline = (Get-Date).AddSeconds(120)
$ok = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:443/query_region_list' -Method Get -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        if ($r.StatusCode -eq 200) { $ok = $true; break }
    } catch {}
}
if (-not $ok) {
    Write-Host ''
    Write-Host '[失败] 服务端 120 秒内没能应答，请看 "Grasscutter Server" 窗口里的报错。' -ForegroundColor Red
    Start-Sleep -Seconds 10
    exit 1
}
Write-Host '[4/6] 服务端已就绪。' -ForegroundColor Green

# ---------- 4.5 重载卡池与商店 ----------
# 服务端启动时 Excel 商品表还没加载完，商店的商品会被填成空列表；
# 等数据就绪后让它自己 reload 一遍，商店才有货（玩家还没上线，感觉不到）。
Write-Host '[4.5] 重载卡池与商店数据 ...'
$cmdBody = '{"token":"ygphArqKIbKuskYTaetTOW9CgmS8UhsT","action":"command","data":"reload"}'
$reloadOk = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        $r = Invoke-WebRequest -Uri 'http://127.0.0.1:443/opencommand/api' -Method Post -ContentType 'application/json' -Body $cmdBody -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
        if ($r.Content -match '"retcode":\s*200') { $reloadOk = $true; break }
    } catch {}
    Start-Sleep -Seconds 3
}
if ($reloadOk) {
    Write-Host '      已重载：卡池与商店商品已就绪。' -ForegroundColor Green
} else {
    Write-Host '      重载没成功（不影响进游戏；进游戏后在指令工具里执行 reload 即可补上商店）。' -ForegroundColor Yellow
}

# ---------- 5. 客户端补丁 ----------
# 缺 version.dll 客户端验签失败 -> 4206 / 4214；缺了要自动补回去
Write-Host '[5/6] 校验客户端补丁 ...'
$master = Join-Path $Root '配置\工具\patch_master'
foreach ($f in @('version.dll','PublicKey.txt')) {
    $src = Join-Path $master $f
    $dst = Join-Path $GameDir $f
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $need = $true
    if (Test-Path -LiteralPath $dst) {
        try {
            if ((Get-FileHash -LiteralPath $dst -Algorithm MD5).Hash -eq (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash) { $need = $false }
        } catch { $need = $true }
    }
    if ($need) {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host ('      已装回 ' + $f) -ForegroundColor Yellow
    }
}
Write-Host '[5/6] 补丁正常。' -ForegroundColor Green

# ---------- 6. 启动器 ----------
# 启动器必须开着：它起的 8365 代理负责把 HOYOVERSE 登录请求转给本地服务端
Write-Host '[6/6] 启动代理器并自动点击【启动】...'
Get-Process Cultivation -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$cfgDir = Join-Path $env:APPDATA 'cultivation'
$cfg = Join-Path $cfgDir 'configuration.json'
if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null }

# 没有配置文件就按默认模板建一份（换电脑/第一次部署时全靠这段）
$j = $null
if (Test-Path -LiteralPath $cfg) {
    try { $j = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json } catch { $j = $null }
}
if ($null -eq $j) {
    $j = [pscustomobject]@{
        toggle_grasscutter = $false; game_install_path = ''; grasscutter_with_game = $false
        grasscutter_path = ''; java_path = ''; close_action = 0; startup_launch = $false
        last_ip = '127.0.0.1'; last_port = '443'; language = 'chs'; custom_background = ''
        use_theme_background = $false; cert_generated = $false; theme = 'default'
        https_enabled = $false; debug_enabled = $true; patch_rsa = $true; use_internal_proxy = $true
        wipe_login = $false; horny_mode = $false; auto_mongodb = $false; un_elevated = $true
        redirect_more = $false; grasscutter_elevation = 'None'; other_redirects = $false
    }
}
foreach ($kv in @(
    @('toggle_grasscutter', $true),
    @('https_enabled', $false),
    @('patch_rsa', $true),
    @('use_internal_proxy', $true),
    @('last_ip', '127.0.0.1'),
    @('last_port', '443'),
    @('game_install_path', (Join-Path $GameDir 'GenshinImpact.exe')),
    @('grasscutter_path', (Join-Path $Root '配置\服务端\grasscutter-1.7.4.jar')),
    @('java_path', $javaExe)
)) {
    $j | Add-Member -NotePropertyName $kv[0] -NotePropertyValue $kv[1] -Force
}
try {
    [IO.File]::WriteAllText($cfg, ($j | ConvertTo-Json -Depth 10 -Compress), (New-Object Text.UTF8Encoding($false)))
} catch {}

$launcherDir = Join-Path $Root '配置\工具\Cultivation'
Start-Process -FilePath (Join-Path $launcherDir 'Cultivation.exe') -ArgumentList '--no-admin' -WorkingDirectory $launcherDir

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -Namespace W -Name N -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint f, int x, int y, uint d, int t);
'@

$clicked = $false
for ($try = 0; $try -lt 15; $try++) {
    Start-Sleep -Seconds 2
    $proc = Get-Process Cultivation -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $proc) { continue }
    $h = $proc.MainWindowHandle
    if ($h -eq 0) { continue }
    try {
        # 置顶 + 固定位置，保证按钮不被别的窗口盖住（置顶不需要抢前台权限）
        [W.N]::SetWindowPos($h, [IntPtr]::new(-1), 40, 40, 1000, 940, 0x0040) | Out-Null
        Start-Sleep -Milliseconds 1000

        $rootEl = [System.Windows.Automation.AutomationElement]::RootElement
        $cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $proc.Id)
        $win = $rootEl.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($null -eq $win) { continue }
        $all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
        $target = $null
        foreach ($e in $all) { if ($e.Current.Name -eq '启动') { $target = $e; break } }
        if ($null -eq $target) { continue }
        $r = $target.Current.BoundingRectangle
        if ($r.Width -le 0 -or $r.Height -le 0) { continue }
        $x = [int](($r.Left + $r.Right) / 2)
        $y = [int](($r.Top + $r.Bottom) / 2)
        [W.N]::SetCursorPos($x, $y) | Out-Null
        Start-Sleep -Milliseconds 500
        [W.N]::mouse_event(0x0002, 0, 0, 0, 0)
        Start-Sleep -Milliseconds 200
        [W.N]::mouse_event(0x0004, 0, 0, 0, 0)
        Start-Sleep -Seconds 6
        if (Get-NetTCPConnection -State Listen -LocalPort 8365 -ErrorAction SilentlyContinue) {
            $clicked = $true
            break
        }
    } catch {}
}

# 点完恢复成普通窗口，别一直压在最上面
$proc = Get-Process Cultivation -ErrorAction SilentlyContinue | Select-Object -First 1
if ($proc -and $proc.MainWindowHandle -ne 0) {
    try { [W.N]::SetWindowPos($proc.MainWindowHandle, [IntPtr]::new(-2), 60, 60, 1000, 940, 0x0040) | Out-Null } catch {}
}

if ($clicked) {
    Write-Host '      已自动点击【启动】。' -ForegroundColor Green
} else {
    Write-Host '      没自动点中，请手动点一下启动器里的黄色【启动】按钮。' -ForegroundColor Yellow
}

$gameOk = $false
$t2 = 0
while ($t2 -lt 70) {
    Start-Sleep -Seconds 2
    $t2 += 2
    if (Get-Process GenshinImpact -ErrorAction SilentlyContinue) { $gameOk = $true; break }
}

Write-Host ''
Write-Host '----------------------------------------------------------' -ForegroundColor Yellow
if ($gameOk) {
    Write-Host ' 游戏已启动，等 HOYOVERSE 登录框出来，输入：' -ForegroundColor Yellow
} else {
    Write-Host ' 游戏没自动起来，请手动点启动器里的【启动】。登录框里输入：' -ForegroundColor Yellow
}
Write-Host '      账号 test    密码 123456   （首次登录会自动建号）' -ForegroundColor Yellow
Write-Host ' 看到「点击进入」点一下即进服，UID 10001。' -ForegroundColor Yellow
Write-Host ' 启动器别关：它负责把登录请求转给本地服务端，关了登录就失败。' -ForegroundColor Yellow
Write-Host (' 关服双击 ' + (Join-Path $Scripts '关闭游戏.bat')) -ForegroundColor Yellow
Write-Host '----------------------------------------------------------' -ForegroundColor Yellow
Write-Host ''
Start-Sleep -Seconds 5
