@echo off
setlocal enabledelayedexpansion

:: ==================================================
:: Git Project Manager - Multi Repo Saver
:: ==================================================

set CONFIG_FILE=%~dp0repos.txt

:: === Load saved repos if present ===
set REPO_COUNT=0
if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2,3 delims=|" %%A in (%CONFIG_FILE%) do (
        set /a REPO_COUNT+=1
        set REPO_NAME[!REPO_COUNT!]=%%A
        set REPO_URL[!REPO_COUNT!]=%%B
        set AUTH_TOKEN[!REPO_COUNT!]=%%C
    )
)

:MAIN_MENU
cls
echo ================================================
echo 🚀 Git Project Manager
echo ================================================
if %REPO_COUNT% GTR 0 (
    echo Saved Repositories:
    for /l %%i in (1,1,%REPO_COUNT%) do (
        echo   %%i. !REPO_NAME[%%i]!
    )
    echo 0. Enter New Repo
) else (
    echo [INFO] No saved repos yet.
)
echo X. Exit
echo ================================================
set /p choice="Choose option: "

if /i "%choice%"=="X" exit

if "%choice%"=="0" (
    goto NEW_REPO
)

:: --- Use saved repo ---
if %REPO_COUNT% GTR 0 (
    for /l %%i in (1,1,%REPO_COUNT%) do (
        if "%choice%"=="%%i" (
            set REPO_NAME=!REPO_NAME[%%i]!
            set REPO_URL=!REPO_URL[%%i]!
            set AUTH_TOKEN=!AUTH_TOKEN[%%i]!
            goto ACTION_MENU
        )
    )
)

goto MAIN_MENU

:NEW_REPO
set /p REPO_NAME="Enter short name for this repo: "
set /p REPO_URL="Enter GitHub Repo URL (e.g., github.com/user/repo.git): "
set /p AUTH_TOKEN="Enter GitHub Personal Access Token: "
echo %REPO_NAME%^|%REPO_URL%^|%AUTH_TOKEN%>>"%CONFIG_FILE%"
echo [INFO] Repo saved as %REPO_NAME%.
pause
goto MAIN_MENU

:ACTION_MENU
cls
echo ================================================
echo Working Repo: %REPO_NAME% - %REPO_URL%
echo ================================================
echo 1. Show branches
echo 2. Switch branch
echo 3. Create new branch (mirror local folder)
echo 4. Update current branch (mirror local folder)
echo 5. Clone branch (into new folder)
echo 6. Back to Main Menu
echo ================================================
set /p action="Choose action: "

if "%action%"=="6" goto MAIN_MENU

:: --- Show branches ---
if "%action%"=="1" (
    git branch -a
    pause
    goto ACTION_MENU
)

:: --- Switch branch ---
if "%action%"=="2" (
    git fetch
    git branch -a
    set /p BRANCH="Enter branch to switch (or EXIT): "
    if /i "!BRANCH!"=="EXIT" goto ACTION_MENU
    git checkout !BRANCH!
    pause
    goto ACTION_MENU
)

:: --- Create new branch ---
if "%action%"=="3" (
    set /p NEWBR="Enter new branch name (or EXIT): "
    if /i "!NEWBR!"=="EXIT" goto ACTION_MENU

    git checkout --orphan "!NEWBR!"
    git add -A
    set /p MSG="Commit message: "
    if "!MSG!"=="" set MSG=Initial snapshot for !NEWBR!
    git commit -m "!MSG!"
    git push -u --force https://%AUTH_TOKEN%@%REPO_URL% "!NEWBR!"

    echo [INFO] Branch !NEWBR! now mirrors this folder.
    pause
    goto ACTION_MENU
)

:: --- Update current branch ---
if "%action%"=="4" (
    for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CURBR=%%i
    echo [INFO] Updating branch: !CURBR!

    git add -A
    set /p MSG="Commit message: "
    if "!MSG!"=="" set MSG=Update snapshot of !CURBR!
    git commit -m "!MSG!"
    git push --force https://%AUTH_TOKEN%@%REPO_URL% !CURBR!

    echo [INFO] Branch !CURBR! updated with current folder state.
    pause
    goto ACTION_MENU
)

:: --- Clone branch ---
if "%action%"=="5" (
    set /p BRANCH="Enter branch to clone (or EXIT): "
    if /i "!BRANCH!"=="EXIT" goto ACTION_MENU
    set /p NEWDIR="Enter new folder name: "
    git clone -b !BRANCH! https://%AUTH_TOKEN%@%REPO_URL% !NEWDIR!
    pause
    goto ACTION_MENU
)

goto ACTION_MENU
