@echo off
title Genshin Private Server - Shutdown
"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0stop_all.ps1"
