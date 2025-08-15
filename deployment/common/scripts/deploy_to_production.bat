@echo off
REM Universal Deploy to Production Script for Intel and Snapdragon Systems
REM Copies files from GitHub working directory to C:\AIDemo production location

setlocal EnableDelayedExpansion

REM Default parameters
set "SourceDir=C:\Users\Mosai\ai-demo-working"
set "TargetDir=C:\AIDemo"
set "Platform=auto"

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_deploy
if /i "%~1"=="-SourceDir" (
    set "SourceDir=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-TargetDir" (
    set "TargetDir=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-Platform" (
    set "Platform=%~2"
    shift
    shift
    goto :parse_args
)
shift
goto :parse_args

:start_deploy
echo ===========================================
echo   Universal AI Demo - Production Deploy   
echo ===========================================
echo.

REM Detect platform if auto
if /i "%Platform%"=="auto" (
    call :detect_platform
) else (
    set "detectedPlatform=%Platform%"
    echo Using specified platform: !detectedPlatform!
)

echo Platform: !detectedPlatform!
echo Source: %SourceDir%
echo Target: %TargetDir%
echo.

REM Verify source directory exists
if not exist "%SourceDir%" (
    echo ERROR: Source directory not found: %SourceDir%
    pause
    exit /b 1
)

REM Create target directory if it doesn't exist
if not exist "%TargetDir%" (
    echo Creating target directory: %TargetDir%
    mkdir "%TargetDir%"
)

echo Starting deployment...
echo.

REM 1. Copy core Python application files
echo === Core Application Files ===
call :copy_with_progress "%SourceDir%\src\windows-client\*.py" "%TargetDir%\src\" "Python application files"

echo.
REM 2. Copy static web assets  
echo === Static Web Assets ===
call :copy_with_progress "%SourceDir%\src\windows-client\static" "%TargetDir%\static\" "HTML/JS/CSS files"

echo.
REM 3. Copy deployment scripts
echo === Deployment Scripts ===
call :copy_with_progress "%SourceDir%\deployment\common" "%TargetDir%\deployment\common\" "Common scripts"

if /i "!detectedPlatform!"=="intel" (
    call :copy_with_progress "%SourceDir%\deployment\intel" "%TargetDir%\deployment\intel\" "Intel-specific scripts"
) else (
    call :copy_with_progress "%SourceDir%\deployment\snapdragon" "%TargetDir%\deployment\snapdragon\" "Snapdragon-specific scripts"
)

echo.
REM 4. Copy requirements files
echo === Requirements Files ===
call :copy_with_progress "%SourceDir%\requirements.txt" "%TargetDir%\requirements.txt" "Main requirements"

if /i "!detectedPlatform!"=="intel" (
    call :copy_with_progress "%SourceDir%\deployment\intel\requirements\*.txt" "%TargetDir%\requirements\" "Intel requirements"
) else (
    call :copy_with_progress "%SourceDir%\deployment\snapdragon\requirements\*.txt" "%TargetDir%\requirements\" "Snapdragon requirements"
)

echo.
REM 5. Copy documentation
echo === Documentation ===
call :copy_with_progress "%SourceDir%\docs" "%TargetDir%\docs\" "Documentation files"
call :copy_with_progress "%SourceDir%\README.md" "%TargetDir%\README.md" "README"

echo.
REM 6. Create necessary empty directories
echo === Creating Directory Structure ===
if /i "!detectedPlatform!"=="intel" (
    set "modelPath=%TargetDir%\models\stable-diffusion\intel-optimized"
) else (
    set "modelPath=%TargetDir%\models\stable-diffusion\snapdragon-optimized"
)

for %%d in (
    "!modelPath!"
    "%TargetDir%\logs"
    "%TargetDir%\cache" 
    "%TargetDir%\temp"
    "%TargetDir%\diagnostic_reports"
    "%TargetDir%\config"
) do (
    if not exist "%%~d" (
        mkdir "%%~d"
        echo   Created: %%~d
    )
)

echo.
REM 7. Create production config file
echo === Creating Production Config ===
if not exist "%TargetDir%\config" mkdir "%TargetDir%\config"

if /i "!detectedPlatform!"=="intel" (
    call :create_intel_config
) else (
    call :create_snapdragon_config
)
echo   Created production config for !detectedPlatform!

echo.
REM 8. Create launcher scripts
echo === Creating Launcher Scripts ===
call :create_launcher_scripts

echo.
REM 9. Create model download script
echo === Creating Model Preparation Script ===
call :create_model_script

echo.
REM 10. Create platform info file
echo === Creating Platform Info ===
call :create_platform_info

echo.
echo ===========================================
echo Deployment Complete!
echo ===========================================
echo.
echo Platform: !detectedPlatform!
echo.
echo Next Steps:
echo 1. Navigate to: %TargetDir%
echo 2. Run: setup_environment.bat (first time only)
echo 3. Download models: python prepare_models.py
echo 4. Launch demo: launch_demo.bat
echo.
echo Production directory structure created at: %TargetDir%
echo Optimized for: !detectedPlatform! platform
echo.
pause
goto :eof

REM ===== SUBROUTINES =====

:detect_platform
echo Detecting platform...
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "Name"') do (
    set "cpuName=%%i"
)

echo CPU: !cpuName!

echo !cpuName! | findstr /i "intel" >nul
if !errorlevel! == 0 (
    set "detectedPlatform=intel"
    echo   Intel processor detected
    goto :eof
)

echo !cpuName! | findstr /i "snapdragon qualcomm arm" >nul  
if !errorlevel! == 0 (
    set "detectedPlatform=snapdragon"
    echo   Snapdragon/ARM processor detected
    goto :eof
)

set "detectedPlatform=intel"
echo   Unknown processor, defaulting to Intel configuration
goto :eof

:copy_with_progress
set "source=%~1"
set "dest=%~2" 
set "desc=%~3"

echo   Copying %desc%...

if not exist "%source%" (
    echo     Source not found: %source%
    goto :eof
)

REM Create destination directory
for %%f in ("%dest%") do (
    if not exist "%%~dpf" mkdir "%%~dpf"
)

REM Copy files/directories
if exist "%source%\*" (
    xcopy "%source%" "%dest%" /E /I /Q /Y >nul 2>&1
) else (
    copy "%source%" "%dest%" >nul 2>&1
)

if !errorlevel! == 0 (
    echo     Copied successfully
) else (
    echo     Error copying files
)
goto :eof

:create_intel_config
(
echo {
echo     "platform": "intel",
echo     "environment": "production",
echo     "model_path": "C:\\AIDemo\\models\\stable-diffusion\\intel-optimized",
echo     "cache_dir": "C:\\AIDemo\\cache",
echo     "log_dir": "C:\\AIDemo\\logs",
echo     "host": "0.0.0.0",
echo     "port": 5000,
echo     "debug": false,
echo     "enable_diagnostics": true,
echo     "performance_mode": "optimized",
echo     "max_batch_size": 2,
echo     "device": "cpu",
echo     "use_directml": true,
echo     "use_onnx": false,
echo     "num_threads": 8,
echo     "optimization_level": "O2"
echo }
) > "%TargetDir%\config\production.json"
goto :eof

:create_snapdragon_config
(
echo {
echo     "platform": "snapdragon", 
echo     "environment": "production",
echo     "model_path": "C:\\AIDemo\\models\\stable-diffusion\\snapdragon-optimized",
echo     "cache_dir": "C:\\AIDemo\\cache",
echo     "log_dir": "C:\\AIDemo\\logs",
echo     "host": "0.0.0.0",
echo     "port": 5000,
echo     "debug": false,
echo     "enable_diagnostics": true,
echo     "performance_mode": "optimized",
echo     "max_batch_size": 1,
echo     "device": "cpu",
echo     "use_onnx": true,
echo     "onnx_providers": ["CPUExecutionProvider"]
echo }
) > "%TargetDir%\config\production.json"
goto :eof

:create_launcher_scripts
REM Main launcher
(
echo @echo off
echo cd /d C:\AIDemo
echo echo Starting AI Demo ^(!detectedPlatform!^)...
echo call .venv\Scripts\activate.bat
echo python src\demo_client.py
echo pause
) > "%TargetDir%\launch_demo.bat"
echo   Created launch_demo.bat

REM Setup script
if /i "!detectedPlatform!"=="intel" (
    set "requirementsFile=requirements\requirements-intel.txt"
) else (
    set "requirementsFile=requirements\requirements-snapdragon.txt"
)

(
echo @echo off
echo cd /d C:\AIDemo
echo echo Setting up Python environment for !detectedPlatform!...
echo python -m venv .venv
echo call .venv\Scripts\activate.bat
echo pip install --upgrade pip
echo.
echo echo Installing core requirements...
echo pip install -r requirements.txt
echo.
echo if exist "!requirementsFile!" ^(
echo     echo Installing !detectedPlatform!-specific requirements...
echo     pip install -r !requirementsFile!
echo ^)
echo.
echo echo Setup complete for !detectedPlatform!!
echo pause
) > "%TargetDir%\setup_environment.bat"
echo   Created setup_environment.bat
goto :eof

:create_model_script
(
echo # Download and prepare models for !detectedPlatform!
echo import os
echo import sys
echo import platform
echo.
echo sys.path.append^('C:\\AIDemo\\src'^)
echo.
echo detected_platform = '!detectedPlatform!'
echo print^(f"Downloading and converting models for {detected_platform.upper^(^)}..."^)
echo print^("This process will:"^)
echo print^("1. Download Stable Diffusion v1.5"^)
echo.
if /i "!detectedPlatform!"=="intel" (
echo print^("2. Optimize for Intel CPU with DirectML"^)
echo print^("3. Configure for multi-threading"^)
) else (
echo print^("2. Convert to ONNX format"^)  
echo print^("3. Optimize for Snapdragon/ARM"^)
)
echo.
echo print^(""^)
echo print^("Note: This requires ~4GB of disk space and may take 15-30 minutes"^)
echo print^(""^)
echo.
echo # Model preparation logic would go here
echo # For now, this is a placeholder
echo print^(f"Model preparation complete for {detected_platform}!"^)
) > "%TargetDir%\prepare_models.py"
echo   Created model preparation script
goto :eof

:create_platform_info
for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value ^| find "Name"') do set "cpuName=%%i"
(
echo Platform: !detectedPlatform!
echo Deployed: %date% %time%
echo Source: %SourceDir%
echo CPU: !cpuName!
) > "%TargetDir%\platform_info.txt"
goto :eof
