# 脚本自己算根目录：C:\XH_YS\脚本 -> C:\XH_YS
$Root = Split-Path -Parent $PSScriptRoot

Write-Host '关闭游戏客户端 ...'
Stop-Process -Name GenshinImpact -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host '关闭启动器（退出时会自己清掉 8365 代理）...'
Stop-Process -Name Cultivation -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host '复位系统代理 ...'
Set-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host '   ProxyEnable = 0'

Write-Host '关闭 Grasscutter 服务端 ...'
Get-CimInstance Win32_Process -Filter "Name='java.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'grasscutter' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

Write-Host '关闭 MongoDB（正常落盘退出）...'
$dbDir  = Join-Path $Root '配置\数据库'
$mongod = Join-Path $dbDir 'bin\mongod.exe'
if (Test-Path -LiteralPath $mongod) {
    & $mongod --dbpath (Join-Path $dbDir 'data') --shutdown 2>$null | Out-Null
    Start-Sleep -Seconds 4
}
Stop-Process -Name mongod -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host '已全部关闭。' -ForegroundColor Green
Write-Host ''
$left = @()
if (Get-Process mongod -ErrorAction SilentlyContinue) { $left += 'mongod' }
if (Get-Process java -ErrorAction SilentlyContinue) { $left += 'java' }
if (Get-Process GenshinImpact -ErrorAction SilentlyContinue) { $left += 'GenshinImpact' }
if (Get-Process Cultivation -ErrorAction SilentlyContinue) { $left += 'Cultivation' }
if ($left.Count -eq 0) { Write-Host '残留进程检查：干净。' -ForegroundColor Green } else { Write-Host ('仍在运行: ' + ($left -join ', ')) -ForegroundColor Yellow }
Start-Sleep -Seconds 6
