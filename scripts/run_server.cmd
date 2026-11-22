@echo off
title Grasscutter Server
set "ROOT=%~dp0.."
cd /d "%ROOT%\配置\服务端"
set "JAVA="
if exist "%ROOT%\配置\java_path.txt" set /p JAVA=<"%ROOT%\配置\java_path.txt"
if not defined JAVA set "JAVA=C:\Program Files\Java\jdk-17\bin\java.exe"
if not exist "%JAVA%" (
    echo.
    echo  [错误] 找不到 Java 17: "%JAVA%"
    echo  请先双击 教程\一键部署.bat 让脚本装好 Java，再启动。
    echo.
    pause
    exit /b 1
)
"%JAVA%" -Xms2G -Xmx6G -XX:+UseG1GC -XX:MaxGCPauseMillis=50 -XX:+ParallelRefProcEnabled -Dfile.encoding=UTF-8 -jar grasscutter-1.7.4.jar
echo.
echo Server stopped. Press any key to close this window.
pause >nul