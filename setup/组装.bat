@echo off
chcp 65001 >nul
title Genshin 4.0 Private Server - Assemble
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0组装.ps1"
echo.
echo 按任意键关闭本窗口。
pause >nul
