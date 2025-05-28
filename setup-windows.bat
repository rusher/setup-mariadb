@echo off
setlocal enabledelayedexpansion

REM MariaDB Windows Installation Script
REM This script installs MariaDB on Windows using Chocolatey

echo ::group:: Detecting Windows Environment

REM Check if running on Windows
if not "%OS%"=="Windows_NT" (
    echo [!ERROR!] This script is designed for Windows only
    exit /b 1
)

echo ??? Detected Windows OS

REM Check for Chocolatey (required)
if exist "%ProgramData%\chocolatey\bin\choco.exe" (
    echo [???] Using Chocolatey package manager
) else (
    echo [!ERROR!] Chocolatey is required but not found
    echo Please install Chocolatey first: https://chocolatey.org/install
    exit /b 1
)

echo ::endgroup::

REM ############################################################################
echo ::group:: Processing Configuration

REM Set MariaDB version
set MARIADB_VERSION=
if not "%SETUP_TAG%"=="" (
    if not "%SETUP_TAG%"=="latest" (
        set MARIADB_VERSION=%SETUP_TAG%
        echo [???] MariaDB version set to !MARIADB_VERSION!
    ) else (
        echo [???] Using latest MariaDB version
    )
) else (
    echo [???] Using latest MariaDB version
)

REM Set port
set MARIADB_PORT=3306
if not "%SETUP_PORT%"=="" (
    set MARIADB_PORT=%SETUP_PORT%
)
echo [???] MariaDB port set to !MARIADB_PORT!

REM Set root password
set MARIADB_ROOT_PASSWORD=
if not "%SETUP_ROOT_PASSWORD%"=="" (
    set MARIADB_ROOT_PASSWORD=%SETUP_ROOT_PASSWORD%
    echo [???] Root password is explicitly set
) else (
    if "%SETUP_ALLOW_EMPTY_ROOT_PASSWORD%"=="1" (
        set MARIADB_ROOT_PASSWORD=
        echo [!] Root password will be empty
    ) else (
        REM Generate random password
        set MARIADB_ROOT_PASSWORD=%RANDOM%%RANDOM%%RANDOM%
        echo [!] Root password will be randomly generated: !MARIADB_ROOT_PASSWORD!
    )
)

REM Set user and password
set MARIADB_USER=
set MARIADB_PASSWORD=
if not "%SETUP_USER%"=="" (
    set MARIADB_USER=%SETUP_USER%
    echo [???] MariaDB user set to !MARIADB_USER!
)

if not "%SETUP_PASSWORD%"=="" (
    set MARIADB_PASSWORD=%SETUP_PASSWORD%
    echo [???] MariaDB user password is explicitly set
)

REM Set database
set MARIADB_DATABASE=
if not "%SETUP_DATABASE%"=="" (
    set MARIADB_DATABASE=%SETUP_DATABASE%
    echo [???] Initial database set to !MARIADB_DATABASE!
)

REM Check for unsupported SETUP_ADDITIONAL_CONF
if not "%SETUP_ADDITIONAL_CONF%"=="" (
    echo [!] SETUP_ADDITIONAL_CONF is not supported on Windows and will be ignored
)

echo ::endgroup::

REM ############################################################################
echo ::group::???? Installing MariaDB

REM Check if MariaDB is already installed
where mysql >nul 2>&1
if %errorlevel%==0 (
    echo [!] MariaDB/MySQL appears to be already installed
    mysql --version 2>nul
) else (
    echo Installing MariaDB using Chocolatey...
    if not "%MARIADB_VERSION%"=="" (
        choco install mariadb --version=%MARIADB_VERSION% -y
    ) else (
        choco install mariadb -y
    )
    if !errorlevel! neq 0 (
        echo [!ERROR!] Failed to install MariaDB via Chocolatey
        exit /b 1
    )
    echo [???] MariaDB installation completed
)

echo ::endgroup::

REM ############################################################################
echo ::group:: Starting MariaDB Service

echo Starting MariaDB service...
net start MariaDB >nul 2>&1
if %errorlevel%==0 (
    echo [???] MariaDB service started successfully
) else (
    echo [!] MariaDB service may already be running or failed to start
)

REM Wait for MariaDB to be ready
echo [LOADING] Waiting for MariaDB to be ready...
set /a counter=0
:wait_loop
mysql -u root -e "SELECT 1;" >nul 2>&1
if %errorlevel%==0 (
    echo [???] MariaDB is ready!
    goto configure_db
)
set /a counter+=1
if %counter% geq 30 (
    echo [!ERROR!] MariaDB failed to start within 30 seconds
    exit /b 1
)
timeout /t 1 /nobreak >nul
goto wait_loop

:configure_db
echo ::endgroup::

REM ############################################################################
echo ::group:: Configuring MariaDB

REM Set root password if specified
if not "%MARIADB_ROOT_PASSWORD%"=="" (
    echo Configuring root password...
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '%MARIADB_ROOT_PASSWORD%';" 2>nul
    if !errorlevel! neq 0 (
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('%MARIADB_ROOT_PASSWORD%');" 2>nul
        if !errorlevel! neq 0 (
            mysqladmin -u root password "%MARIADB_ROOT_PASSWORD%" 2>nul
        )
    )
    echo [???] Root password configured
)

REM Create database if specified
if not "%MARIADB_DATABASE%"=="" (
    echo Creating database '%MARIADB_DATABASE%'...
    if not "%MARIADB_ROOT_PASSWORD%"=="" (
        mysql -u root -p%MARIADB_ROOT_PASSWORD% -e "CREATE DATABASE IF NOT EXISTS `%MARIADB_DATABASE%`;"
    ) else (
        mysql -u root -e "CREATE DATABASE IF NOT EXISTS `%MARIADB_DATABASE%`;"
    )
    if !errorlevel!==0 (
        echo [???] Database '%MARIADB_DATABASE%' created
    ) else (
        echo [!ERROR!] Failed to create database '%MARIADB_DATABASE%'
    )
)

REM Create user if specified
if not "%MARIADB_USER%"=="" (
    if not "%MARIADB_PASSWORD%"=="" (
        echo Creating user '%MARIADB_USER%'...
        if not "%MARIADB_ROOT_PASSWORD%"=="" (
            mysql -u root -p%MARIADB_ROOT_PASSWORD% -e "CREATE USER IF NOT EXISTS '%MARIADB_USER%'@'%%' IDENTIFIED BY '%MARIADB_PASSWORD%';"
            if not "%MARIADB_DATABASE%"=="" (
                mysql -u root -p%MARIADB_ROOT_PASSWORD% -e "GRANT ALL PRIVILEGES ON `%MARIADB_DATABASE%`.* TO '%MARIADB_USER%'@'%%';"
            ) else (
                mysql -u root -p%MARIADB_ROOT_PASSWORD% -e "GRANT ALL PRIVILEGES ON *.* TO '%MARIADB_USER%'@'%%';"
            )
            mysql -u root -p%MARIADB_ROOT_PASSWORD% -e "FLUSH PRIVILEGES;"
        ) else (
            mysql -u root -e "CREATE USER IF NOT EXISTS '%MARIADB_USER%'@'%%' IDENTIFIED BY '%MARIADB_PASSWORD%';"
            if not "%MARIADB_DATABASE%"=="" (
                mysql -u root -e "GRANT ALL PRIVILEGES ON `%MARIADB_DATABASE%`.* TO '%MARIADB_USER%'@'%%';"
            ) else (
                mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '%MARIADB_USER%'@'%%';"
            )
            mysql -u root -e "FLUSH PRIVILEGES;"
        )
        echo [???] User '%MARIADB_USER%' created and granted privileges
    )
)

echo ::endgroup::

REM ############################################################################
echo ::group:: Running Additional Configuration

REM Run configuration scripts if provided
if not "%SETUP_CONF_SCRIPT_FOLDER%"=="" (
    if exist "%SETUP_CONF_SCRIPT_FOLDER%" (
        echo Processing configuration scripts from %SETUP_CONF_SCRIPT_FOLDER%
        
        REM Find MariaDB data directory and my.ini file
        set MARIADB_DATA_DIR=
        set MY_INI_PATH=
        
        REM Try common MariaDB installation paths
        if exist "C:\ProgramData\MariaDB\MariaDB Server*\data\my.ini" (
            for /d %%d in ("C:\ProgramData\MariaDB\MariaDB Server*") do (
                if exist "%%d\data\my.ini" (
                    set MARIADB_DATA_DIR=%%d\data
                    set MY_INI_PATH=%%d\data\my.ini
                    goto found_config
                )
            )
        )
        
        REM Try alternative path
        if exist "C:\Program Files\MariaDB*\data\my.ini" (
            for /d %%d in ("C:\Program Files\MariaDB*") do (
                if exist "%%d\data\my.ini" (
                    set MARIADB_DATA_DIR=%%d\data
                    set MY_INI_PATH=%%d\data\my.ini
                    goto found_config
                )
            )
        )
                
        
        :found_config
        
        REM Check if MY_INI_PATH was actually found
        if "!MY_INI_PATH!"=="" (
            echo [!ERROR!] MariaDB configuration file (my.ini) not found in any expected location
            echo Expected locations:
            echo   - C:\ProgramData\MariaDB\MariaDB Server*\data\my.ini
            echo   - C:\Program Files\MariaDB*\data\my.ini
            exit /b 1
        )
        
        echo [???] Using configuration file: !MY_INI_PATH!
        
        REM Create backup of original my.ini if it exists
        if exist "!MY_INI_PATH!" (
            copy "!MY_INI_PATH!" "!MY_INI_PATH!.backup.%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%" >nul 2>&1
            echo [???] Created backup of existing my.ini
        )
        
        REM Process each .cnf file
        set CONFIG_UPDATED=0
        for %%f in ("%SETUP_CONF_SCRIPT_FOLDER%\*.cnf") do (
            if exist "%%f" (
                echo Processing configuration file: %%f
                echo. >> "!MY_INI_PATH!"
                echo # Configuration from %%~nxf >> "!MY_INI_PATH!"
                type "%%f" >> "!MY_INI_PATH!"
                echo. >> "!MY_INI_PATH!"
                set CONFIG_UPDATED=1
            )
        )
        
        REM Restart MariaDB service if configuration was updated
        if !CONFIG_UPDATED!==1 (
            echo [???] Configuration files processed, restarting MariaDB service...
            net stop MariaDB >nul 2>&1
            timeout /t 2 /nobreak >nul
            net start MariaDB >nul 2>&1
            if !errorlevel!==0 (
                echo ??? MariaDB service restarted successfully
                
                REM Wait for MariaDB to be ready after restart
                echo ??? Waiting for MariaDB to be ready after restart...
                set /a restart_counter=0
                :restart_wait_loop
                mysql -u root -e "SELECT 1;" >nul 2>&1
                if !errorlevel!==0 (
                    echo [???] MariaDB is ready after restart!
                    goto restart_complete
                )
                set /a restart_counter+=1
                if !restart_counter! geq 30 (
                    echo [!ERROR!] MariaDB failed to start within 30 seconds after restart
                    exit /b 1
                )
                timeout /t 1 /nobreak >nul
                goto restart_wait_loop
                
                :restart_complete
            ) else (
                echo [!ERROR!] Failed to restart MariaDB service
                exit /b 1
            )
        ) else (
            echo [!] No .cnf files found in %SETUP_CONF_SCRIPT_FOLDER%
        )
    ) else (
        echo [!] Configuration script folder %SETUP_CONF_SCRIPT_FOLDER% does not exist
    )
)

REM Run initialization scripts if provided
if not "%SETUP_INIT_SCRIPT_FOLDER%"=="" (
    if exist "%SETUP_INIT_SCRIPT_FOLDER%" (
        echo [LOADING] Processing initialization scripts from %SETUP_INIT_SCRIPT_FOLDER%
        for %%f in ("%SETUP_INIT_SCRIPT_FOLDER%\*.sql") do (
            if exist "%%f" (
                echo Executing initialization script: %%f
                if not "%MARIADB_ROOT_PASSWORD%"=="" (
                    mysql -u root -p%MARIADB_ROOT_PASSWORD% < "%%f"
                ) else (
                    mysql -u root < "%%f"
                )
            )
        )
    )
)

echo ::endgroup::

REM ############################################################################
echo ::group:: MariaDB Windows Installation Complete

echo [???] MariaDB has been successfully installed and configured on Windows!
echo.
echo [???] Configuration Summary:
echo   [???] Port: %MARIADB_PORT%
if not "%MARIADB_ROOT_PASSWORD%"=="" (
    echo   [???] Root Password set
) else (
    echo   [???] Root Password: ^(empty^)
)
if not "%MARIADB_USER%"=="" (
    echo   [???] User: %MARIADB_USER%
    if not "%MARIADB_PASSWORD%"=="" (
        echo   [???] User Password set
    ) else (
        echo   [???] User Password: ^(not set^)
    )
)
if not "%MARIADB_DATABASE%"=="" (
    echo   [???] Database: %MARIADB_DATABASE%
)
echo.
echo [???] Connection Examples:
if not "%MARIADB_ROOT_PASSWORD%"=="" (
    echo   mysql -u root -p%MARIADB_ROOT_PASSWORD% -P %MARIADB_PORT%
) else (
    echo   mysql -u root -P %MARIADB_PORT%
)
if not "%MARIADB_USER%"=="" (
    if not "%MARIADB_PASSWORD%"=="" (
        echo   mysql -u %MARIADB_USER% -p%MARIADB_PASSWORD% -P %MARIADB_PORT%
        if not "%MARIADB_DATABASE%"=="" (
            echo   mysql -u %MARIADB_USER% -p%MARIADB_PASSWORD% -P %MARIADB_PORT% %MARIADB_DATABASE%
        )
    )
)

echo ::endgroup::

exit /b 0 
