@echo off
setlocal enabledelayedexpansion

:: ==================================================
:: Git Project Manager - Mirror Folder to GitHub
:: ==================================================

set CONFIG_FILE=%~dp0git_config.txt

:: === Detect if repo exists ===
if not exist ".git" (
    echo [INFO] No Git repo found in this folder. Initializing...

    set /p REPO_URL="Enter GitHub Repo URL (e.g., github.com/user/repo.git): "
    set /p AUTH_TOKEN="Enter GitHub Personal Access Token: "
    set /p save="Save these for future? (y/n): "

    git init
    git branch -M main
    git remote add origin https://%AUTH_TOKEN%@%REPO_URL%

    if /i "%save%"=="y" (
        > "%CONFIG_FILE%" echo URL=%REPO_URL%
        >> "%CONFIG_FILE%" echo TOKEN=%AUTH_TOKEN%
        echo [INFO] Saved credentials.
    )
    echo [INFO] Repo initialized and linked to: %REPO_URL%
    pause
)

:: === Load saved config if present ===
if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%A in (%CONFIG_FILE%) do (
        if "%%A"=="URL" set SAVED_URL=%%B
        if "%%A"=="TOKEN" set SAVED_TOKEN=%%B
    )
)

:MAIN_MENU
cls
echo ================================================
echo 🚀 Git Project Manager
echo ================================================
echo 1. Use Saved Repo (if available)
echo 2. Enter New Repo URL + Token
echo 3. Exit
echo ================================================
set /p choice="Choose option: "

if "%choice%"=="1" (
    if defined SAVED_URL (
        set REPO_URL=%SAVED_URL%
        set AUTH_TOKEN=%SAVED_TOKEN%
        goto ACTION_MENU
    ) else (
        echo [ERROR] No saved config found!
        pause
        goto MAIN_MENU
    )
)

if "%choice%"=="2" (
    set /p REPO_URL="Enter GitHub Repo URL (e.g., github.com/user/repo.git): "
    set /p AUTH_TOKEN="Enter GitHub Personal Access Token: "
    set /p save="Save these for future? (y/n): "
    if /i "%save%"=="y" (
        > "%CONFIG_FILE%" echo URL=%REPO_URL%
        >> "%CONFIG_FILE%" echo TOKEN=%AUTH_TOKEN%
        echo [INFO] Saved credentials.
    )
    goto ACTION_MENU
)

if "%choice%"=="3" exit

goto MAIN_MENU

:ACTION_MENU
cls
echo ================================================
echo Working Repo: %REPO_URL%
echo ================================================
echo 1. Show branches
echo 2. Switch branch
echo 3. Create new branch (overwrite with local folder)
echo 4. Update current branch (overwrite with local folder)
echo 5. Clone branch (into a new folder)
echo 6. Exit
echo ================================================
set /p action="Choose action: "

:: --- Exit ---
if "%action%"=="6" exit

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
    set /p BRANCH="Enter branch to switch (or EXIT to cancel): "
    if /i "!BRANCH!"=="EXIT" goto ACTION_MENU
    git checkout !BRANCH!
    pause
    goto ACTION_MENU
)

:: --- Create new branch from this folder ---
if "%action%"=="3" (
    set /p NEWBR="Enter new branch name (or EXIT to cancel): "
    if /i "!NEWBR!"=="EXIT" goto ACTION_MENU
    if "!NEWBR!"=="" (
        echo [ERROR] Branch name cannot be empty!
        pause
        goto ACTION_MENU
    )

    git checkout --orphan "!NEWBR!"

    :: remove everything
    git rm -rf . >nul 2>&1

    :: add local files fresh
    git add -A
    set /p MSG="Commit message: "
    if "!MSG!"=="" set MSG=Initial snapshot for !NEWBR!

    git commit -m "!MSG!"
    git push -u --force https://%AUTH_TOKEN%@%REPO_URL% "!NEWBR!"

    echo [INFO] Branch !NEWBR! now mirrors this folder.
    pause
    goto ACTION_MENU
)

:: --- Update current branch (overwrite) ---
if "%action%"=="4" (
    for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CURBR=%%i
    echo [INFO] Updating branch: !CURBR!

    :: remove everything
    git rm -rf . >nul 2>&1

    :: add local files fresh
    git add -A
    set /p MSG="Commit message: "
    if "!MSG!"=="" set MSG=Update snapshot of !CURBR!

    git commit -m "!MSG!"
    git push --force https://%AUTH_TOKEN%@%REPO_URL% !CURBR!

    echo [INFO] Branch !CURBR! updated with current folder state.
    pause
    goto ACTION_MENU
)

:: --- Clone branch into new folder ---
if "%action%"=="5" (
    set /p BRANCH="Enter branch to clone (or EXIT): "
    if /i "!BRANCH!"=="EXIT" goto ACTION_MENU
    set /p NEWDIR="Enter new folder name: "
    git clone -b !BRANCH! https://%AUTH_TOKEN%@%REPO_URL% !NEWDIR!
    pause
    goto ACTION_MENU
)

goto ACTION_MENU
