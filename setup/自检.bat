@echo off
title Genshin 4.0 Private Server - Self Check
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" -OnlyCheck
echo.
echo 按任意键关闭本窗口。
pause >nul
