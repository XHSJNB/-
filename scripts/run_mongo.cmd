@echo off
title MongoDB
set "ROOT=%~dp0.."
set "DB=%ROOT%\配置\数据库"
if not exist "%DB%\data" mkdir "%DB%\data"
if not exist "%DB%\log" mkdir "%DB%\log"
"%DB%\bin\mongod.exe" --dbpath "%DB%\data" --logpath "%DB%\log\mongod.log" --wiredTigerCacheSizeGB 1 --bind_ip 127.0.0.1 --port 27017
