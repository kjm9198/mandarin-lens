@echo off
setlocal
title Kamihi Lens 4.3

set "APP_DIR=%~dp0app"
set "APP_URL=file:///%APP_DIR:\=/%/index.html"

:: Check for Microsoft Edge to run in native App Mode (chromeless, native window feel)
set "EDGE_PATH=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE_PATH%" set "EDGE_PATH=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE_PATH%" set "EDGE_PATH=%LocalAppData%\Microsoft\Edge\Application\msedge.exe"

if exist "%EDGE_PATH%" (
    start "" "%EDGE_PATH%" --app="%APP_URL%" --window-size=1120,780 --user-data-dir="%LocalAppData%\KamihiLens\Profile"
    goto :done
)

:: Fallback to Chrome in App Mode
set "CHROME_PATH=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME_PATH%" set "CHROME_PATH=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME_PATH%" set "CHROME_PATH=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if exist "%CHROME_PATH%" (
    start "" "%CHROME_PATH%" --app="%APP_URL%" --window-size=1120,780 --user-data-dir="%LocalAppData%\KamihiLens\Profile"
    goto :done
)

:: General browser fallback
start "" "%APP_DIR%\index.html"

:done
exit /b 0
