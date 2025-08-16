@echo off
setlocal enabledelayedexpansion

:: ==================================================
:: Git Project Manager - Universal Script
:: Auto-inits repo if missing
:: ==================================================

:: Config storage
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
echo 3. Create new branch (from this folder)
echo 4. Commit + Push changes (update branch)
echo 5. Clone branch (into a new folder)
echo 6. Make checkpoint tag
echo 7. Delete local branch
echo 8. Delete remote branch
echo 9. Show commit history
echo 10. Back to Main Menu
echo ================================================
set /p action="Choose action: "

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
    set /p BRANCH="Enter branch to switch: "
    git checkout %BRANCH%
    pause
    goto ACTION_MENU
)

:: --- Create new branch from this folder ---
if "%action%"=="3" (
    set /p NEWBR="Enter new branch name (or EXIT to cancel): "
    if /i "!NEWBR!"=="EXIT" goto ACTION_MENU

    git checkout -b %NEWBR%

    git add .
    set /p MSG="Commit message: "
    if "!MSG!"=="" (
        echo [ERROR] Commit message cannot be empty!
        pause
        goto ACTION_MENU
    )

    git commit -m "!MSG!"

    git push -u https://%AUTH_TOKEN%@%REPO_URL% %NEWBR%
    pause
    goto ACTION_MENU
)


:: --- Commit + Push changes ---
if "%action%"=="4" (
    git status
    git add .
    set /p MSG="Commit message: "
    git commit -m "%MSG%"
    for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set CURBR=%%i
    git push https://%AUTH_TOKEN%@%REPO_URL% !CURBR!
    pause
    goto ACTION_MENU
)

:: --- Clone branch into new folder ---
if "%action%"=="5" (
    set /p BRANCH="Enter branch to clone: "
    set /p NEWDIR="Enter new folder name: "
    git clone -b %BRANCH% https://%AUTH_TOKEN%@%REPO_URL% %NEWDIR%
    pause
    goto ACTION_MENU
)

:: --- Make checkpoint tag ---
if "%action%"=="6" (
    set /p TAG="Enter tag name (e.g., v1, checkpoint_2): "
    git tag %TAG%
    git push https://%AUTH_TOKEN%@%REPO_URL% %TAG%
    pause
    goto ACTION_MENU
)

:: --- Delete local branch ---
if "%action%"=="7" (
    git branch
    set /p BRANCH="Enter local branch to delete: "
    git branch -d %BRANCH%
    pause
    goto ACTION_MENU
)

:: --- Delete remote branch ---
if "%action%"=="8" (
    git branch -a
    set /p BRANCH="Enter remote branch to delete: "
    git push https://%AUTH_TOKEN%@%REPO_URL% --delete %BRANCH%
    pause
    goto ACTION_MENU
)

:: --- Show commit history ---
if "%action%"=="9" (
    git log --oneline --graph --decorate --all
    pause
    goto ACTION_MENU
)

if "%action%"=="10" goto MAIN_MENU

goto ACTION_MENU
