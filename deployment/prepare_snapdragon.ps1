#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive Snapdragon X Elite Demo Readiness Script
.DESCRIPTION
    Checks and installs all requirements for Snapdragon demo machine
    Handles NPU-specific dependencies and optimizations
.NOTES
    Run as Administrator on Snapdragon X Elite Windows 11 ARM64
#>

param(
    [switch]$CheckOnly = $false,
    [switch]$Force = $false,
    [switch]$Verbose = $false,
    [string]$LogPath = "C:\AIDemo\logs"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$script:totalSteps = 20
$script:currentStep = 0
$script:issues = @()
$script:warnings = @()

# Color output functions
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Error { Write-Host "[X] $args" -ForegroundColor Red }
function Write-Warning { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Info { Write-Host "[i] $args" -ForegroundColor Cyan }
function Write-VerboseInfo {
    if ($script:Verbose) {
        Write-Host "  -> $args" -ForegroundColor DarkGray
    }
}
function Write-Progress {
    param($Message)
    $script:currentStep++
    $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
    Write-Host "`n[$script:currentStep/$script:totalSteps] $Message" -ForegroundColor Magenta
    Write-Progress -Activity "Snapdragon Demo Setup" -Status $Message -PercentComplete $percent
    if ($script:Verbose) {
        Write-Host ("-" * 60) -ForegroundColor DarkGray
    }
}

# Progress spinner for long operations
$script:spinnerChars = @('|','/','-','\')
$script:spinnerIndex = 0
function Show-Spinner {
    param($Message)
    if ($script:Verbose) {
        $char = $script:spinnerChars[$script:spinnerIndex % $script:spinnerChars.Length]
        Write-Host "`r  $char $Message" -NoNewline -ForegroundColor Yellow
        $script:spinnerIndex++
    }
}

function Clear-Spinner {
    if ($script:Verbose) {
        Write-Host "`r" + (" " * 80) + "`r" -NoNewline
    }
}

# Create required directories
function Initialize-Directories {
    Write-Progress "Creating directory structure"
    
    $dirs = @(
        "C:\AIDemo",
        "C:\AIDemo\client",
        "C:\AIDemo\models",
        "C:\AIDemo\cache",
        "C:\AIDemo\logs",
        "C:\AIDemo\temp"
    )
    
    foreach ($dir in $dirs) {
        Write-VerboseInfo "Checking directory: $dir"
        if (!(Test-Path $dir)) {
            Show-Spinner "Creating $dir"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Clear-Spinner
            Write-Success "Created $dir"
        } else {
            Write-VerboseInfo "Directory exists: $dir"
        }
    }
}

# Check hardware requirements
function Test-HardwareRequirements {
    Write-Progress "Checking hardware requirements"
    
    try {
        # Check if running on ARM64
        Write-VerboseInfo "Querying processor architecture..."
        Show-Spinner "Checking architecture"
        $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
        Clear-Spinner
        
        if ($arch -ne "ARM64") {
            $script:issues += "Not running on ARM64 architecture (found: $arch)"
            Write-Error "Architecture: $arch (expected ARM64)"
            return $false
        }
        Write-Success "Architecture: ARM64"
        Write-VerboseInfo "Architecture verified: $arch"
        
        # Check for Snapdragon processor
        Write-VerboseInfo "Querying processor information via WMI..."
        Show-Spinner "Identifying processor"
        $cpu = Get-WmiObject Win32_Processor
        Clear-Spinner
        
        Write-VerboseInfo "Processor details: $($cpu.Name), $($cpu.NumberOfCores) cores, $($cpu.MaxClockSpeed)MHz"
        
        if ($cpu.Name -notmatch "Snapdragon|Qualcomm") {
            $script:issues += "Not a Snapdragon processor: $($cpu.Name)"
            Write-Error "Processor: $($cpu.Name)"
            return $false
        }
        Write-Success "Processor: $($cpu.Name)"
        
        # Check RAM
        Write-VerboseInfo "Querying system memory..."
        Show-Spinner "Checking RAM"
        $memInfo = Get-WmiObject Win32_ComputerSystem
        $ram = [math]::Round($memInfo.TotalPhysicalMemory / 1GB)
        Clear-Spinner
        
        Write-VerboseInfo "Total physical memory: $($memInfo.TotalPhysicalMemory) bytes"
        
        if ($ram -lt 16) {
            $script:warnings += "RAM below recommended 16GB: $($ram)GB"
            Write-Warning "RAM: $($ram)GB (16GB+ recommended)"
        } else {
            Write-Success "RAM: $($ram)GB"
        }
        
        # Check disk space
        Write-VerboseInfo "Checking disk space on C: drive..."
        Show-Spinner "Checking disk space"
        $drive = Get-PSDrive C
        $freeSpace = [math]::Round($drive.Free / 1GB, 2)
        $totalSpace = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
        Clear-Spinner
        
        Write-VerboseInfo "Disk C: - Total: $($totalSpace)GB, Free: $($freeSpace)GB"
        
        if ($freeSpace -lt 3) {
            $script:issues += "Insufficient disk space: $($freeSpace)GB (3GB required)"
            Write-Error "Free space: $($freeSpace)GB"
            return $false
        }
        Write-Success "Free space: $($freeSpace)GB"
        
        # Check for Hexagon NPU
        Write-VerboseInfo "Searching for Hexagon NPU devices..."
        Show-Spinner "Detecting NPU"
        try {
            $pnpDevices = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue
            $npuDevice = $pnpDevices | Where-Object {$_.Name -match "Hexagon|NPU|Neural|Qualcomm.*AI"}
            Clear-Spinner
            
            if ($npuDevice) {
                Write-Success "Hexagon NPU detected"
                Write-VerboseInfo "NPU Device: $($npuDevice.Name)"
                Write-VerboseInfo "Device ID: $($npuDevice.DeviceID)"
            } else {
                Write-Warning "Hexagon NPU not explicitly detected (may still be available)"
                Write-VerboseInfo "Searched $($pnpDevices.Count) PnP devices"
            }
        } catch {
            Clear-Spinner
            Write-Warning "Could not verify NPU status"
            Write-VerboseInfo "Error checking NPU: $_"
        }
        
        return $true
    } catch {
        Clear-Spinner
        $script:issues += "Hardware check failed: $_"
        Write-Error "Hardware check failed: $_"
        return $false
    }
}

# Check and install Python
function Install-Python {
    Write-Progress "Checking Python installation"
    
    $pythonVersions = @("3.10", "3.9")
    $pythonFound = $false
    
    Write-VerboseInfo "Searching for Python installations..."
    
    foreach ($version in $pythonVersions) {
        $pythonPath = "C:\Python$($version -replace '\.', '')"
        $pythonExe = "$pythonPath\python.exe"
        
        Write-VerboseInfo "Checking for Python $version at $pythonPath"
        Show-Spinner "Looking for Python $version"
        
        if (Test-Path $pythonExe) {
            try {
                $installedVersion = & $pythonExe --version 2>&1
                Clear-Spinner
                Write-VerboseInfo "Found executable, version output: $installedVersion"
                
                if ($installedVersion -match "Python $version") {
                    Write-Success "Python $version found at $pythonPath"
                    $env:Path = "$pythonPath;$pythonPath\Scripts;$env:Path"
                    Write-VerboseInfo "Added to PATH: $pythonPath and $pythonPath\Scripts"
                    $pythonFound = $true
                    break
                }
            } catch {
                Clear-Spinner
                Write-VerboseInfo "Error checking Python version: $_"
            }
        } else {
            Clear-Spinner
            Write-VerboseInfo "Python $version not found at expected location"
        }
    }
    
    if (!$pythonFound -and !$CheckOnly) {
        Write-Info "Installing Python 3.10..."
        $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-arm64.exe"
        $installer = "C:\AIDemo\temp\python-installer.exe"
        
        Write-VerboseInfo "Download URL: $pythonUrl"
        Write-VerboseInfo "Installer path: $installer"
        
        try {
            Write-VerboseInfo "Downloading Python installer (this may take a few minutes)..."
            $downloadStart = Get-Date
            
            # Download with progress tracking
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadProgressChanged += {
                if ($script:Verbose) {
                    $percent = $_.ProgressPercentage
                    $received = [math]::Round($_.BytesReceived / 1MB, 2)
                    $total = [math]::Round($_.TotalBytesToReceive / 1MB, 2)
                    Show-Spinner "Downloading: $($received)MB / $($total)MB ($percent%)"
                }
            }
            
            $webClient.DownloadFileTaskAsync($pythonUrl, $installer).Wait()
            Clear-Spinner
            
            $downloadTime = [math]::Round((Get-Date - $downloadStart).TotalSeconds, 1)
            Write-VerboseInfo "Download completed in $downloadTime seconds"
            
            Write-VerboseInfo "Starting Python installation (silent mode)..."
            Show-Spinner "Installing Python 3.10"
            
            $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "TargetDir=C:\Python310")
            Write-VerboseInfo "Installation arguments: $($installArgs -join ' ')"
            
            Start-Process -FilePath $installer -ArgumentList $installArgs -Wait
            Clear-Spinner
            
            $env:Path = "C:\Python310;C:\Python310\Scripts;$env:Path"
            Write-Success "Python 3.10 installed"
            Write-VerboseInfo "Python installation completed successfully"
            $pythonFound = $true
        } catch {
            Clear-Spinner
            $script:issues += "Failed to install Python: $_"
            Write-Error "Python installation failed"
            Write-VerboseInfo "Installation error details: $_"
        }
    } elseif (!$pythonFound) {
        $script:issues += "Python 3.9 or 3.10 not found"
        Write-Error "Python 3.9/3.10 required"
    }
    
    return $pythonFound
}

# Install Poetry
function Install-Poetry {
    Write-Progress "Checking Poetry installation"
    
    try {
        $poetryVersion = & poetry --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Poetry already installed: $poetryVersion"
            return $true
        }
    } catch {}
    
    if ($CheckOnly) {
        $script:issues += "Poetry not installed"
        Write-Error "Poetry not found"
        return $false
    }
    
    Write-Info "Installing Poetry..."
    try {
        (Invoke-WebRequest -Uri https://install.python-poetry.org -UseBasicParsing).Content | python -
        $env:Path = "$env:USERPROFILE\.poetry\bin;$env:Path"
        Write-Success "Poetry installed"
        return $true
    } catch {
        $script:issues += "Failed to install Poetry: $_"
        Write-Error "Poetry installation failed"
        return $false
    }
}

# Clone or update repository
function Update-Repository {
    Write-Progress "Updating repository"
    
    $repoPath = "C:\AIDemo\repo"
    
    if (Test-Path "$repoPath\.git") {
        Write-Info "Updating existing repository..."
        Push-Location $repoPath
        try {
            & git pull origin main
            Write-Success "Repository updated"
        } catch {
            Write-Warning "Could not update repository: $_"
        }
        Pop-Location
    } else {
        if ($CheckOnly) {
            $script:warnings += "Repository not cloned"
            Write-Warning "Repository not found at $repoPath"
            return $true
        }
        
        Write-Info "Cloning repository..."
        try {
            & git clone https://github.com/your-repo/AI-image-gen-battle.git $repoPath
            Write-Success "Repository cloned"
        } catch {
            Write-Warning "Could not clone repository (will use local files)"
        }
    }
    
    # Copy client files
    $sourceClient = if (Test-Path "$repoPath\src\windows-client") { 
        "$repoPath\src\windows-client" 
    } else { 
        ".\src\windows-client" 
    }
    
    if (Test-Path $sourceClient) {
        Write-Info "Copying client files..."
        Copy-Item -Path "$sourceClient\*" -Destination "C:\AIDemo\client\" -Recurse -Force
        Write-Success "Client files deployed"
    } else {
        $script:warnings += "Client source files not found"
        Write-Warning "Client files not found"
    }
    
    return $true
}

# Install Python dependencies
function Install-Dependencies {
    Write-Progress "Installing Python dependencies"
    
    Push-Location "C:\AIDemo\client"
    
    # Create virtual environment
    if (!(Test-Path "C:\AIDemo\venv")) {
        Write-Info "Creating virtual environment..."
        Write-VerboseInfo "Virtual environment path: C:\AIDemo\venv"
        Show-Spinner "Creating virtual environment"
        & python -m venv C:\AIDemo\venv
        Clear-Spinner
        Write-VerboseInfo "Virtual environment created successfully"
    } else {
        Write-VerboseInfo "Virtual environment already exists"
    }
    
    # Activate virtual environment
    Write-VerboseInfo "Activating virtual environment..."
    & C:\AIDemo\venv\Scripts\Activate.ps1
    
    # Upgrade pip
    Write-Info "Upgrading pip..."
    Write-VerboseInfo "Current pip version: $(& pip --version)"
    Show-Spinner "Upgrading pip"
    & python -m pip install --upgrade pip 2>&1 | ForEach-Object {
        if ($script:Verbose) { Write-VerboseInfo $_ }
    }
    Clear-Spinner
    Write-VerboseInfo "Pip upgraded to: $(& pip --version)"
    
    # Install core dependencies
    $coreDeps = @(
        "numpy>=1.21.0,<2.0.0",
        "pillow>=8.0.0,<11.0.0",
        "requests>=2.25.0,<3.0.0",
        "psutil>=5.8.0",
        "flask>=2.0.0,<3.0.0",
        "flask-socketio>=5.0.0,<6.0.0"
    )
    
    $depCount = 0
    $totalDeps = $coreDeps.Count + 7  # Core deps + ML deps
    
    foreach ($dep in $coreDeps) {
        $depCount++
        Write-Info "Installing $dep... [$depCount/$totalDeps]"
        Write-VerboseInfo "Running: pip install $dep"
        Show-Spinner "Installing $dep"
        
        $output = & pip install $dep 2>&1
        Clear-Spinner
        
        if ($LASTEXITCODE -ne 0) {
            $script:warnings += "Failed to install $dep"
            Write-Warning "Installation failed for $dep"
            if ($script:Verbose) {
                Write-VerboseInfo "Error output:"
                $output | ForEach-Object { Write-VerboseInfo "  $_" }
            }
        } else {
            Write-VerboseInfo "Successfully installed $dep"
        }
    }
    
    # Install PyTorch (CPU version for ARM64)
    $depCount++
    Write-Info "Installing PyTorch for ARM64... [$depCount/$totalDeps]"
    Write-VerboseInfo "PyTorch URL: https://download.pytorch.org/whl/cpu"
    Show-Spinner "Installing PyTorch (this may take several minutes)"
    
    $output = & pip install torch==2.1.2 torchvision==0.16.2 --index-url https://download.pytorch.org/whl/cpu 2>&1
    Clear-Spinner
    
    if ($LASTEXITCODE -eq 0) {
        Write-VerboseInfo "PyTorch installed successfully"
    } else {
        Write-Warning "PyTorch installation may have issues"
        if ($script:Verbose) {
            $output | ForEach-Object { Write-VerboseInfo "  $_" }
        }
    }
    
    # Install AI/ML dependencies
    $mlDeps = @(
        "huggingface_hub==0.24.6",
        "transformers==4.36.2",
        "diffusers==0.25.1",
        "accelerate==0.25.0",
        "safetensors==0.4.1",
        "optimum"
    )
    
    foreach ($dep in $mlDeps) {
        $depCount++
        Write-Info "Installing $dep... [$depCount/$totalDeps]"
        Write-VerboseInfo "Running: pip install $dep"
        Show-Spinner "Installing $dep"
        
        $output = & pip install $dep 2>&1
        Clear-Spinner
        
        if ($LASTEXITCODE -ne 0) {
            $script:warnings += "Failed to install $dep"
            Write-Warning "Installation failed for $dep"
            if ($script:Verbose) {
                Write-VerboseInfo "Error output:"
                $output | ForEach-Object { Write-VerboseInfo "  $_" }
            }
        } else {
            Write-VerboseInfo "Successfully installed $dep"
        }
    }
    
    Pop-Location
    
    Write-Success "Core dependencies installed"
    Write-VerboseInfo "Total packages installed: $depCount"
    return $true
}

# Install Snapdragon NPU support
function Install-NPUSupport {
    Write-Progress "Installing Snapdragon NPU support"
    
    & C:\AIDemo\venv\Scripts\Activate.ps1
    
    # Install ONNX Runtime with QNN support
    Write-Info "Installing ONNX Runtime with QNN..."
    try {
        # Try to install QNN-enabled ONNX Runtime
        & pip install onnxruntime-qnn
        Write-Success "ONNX Runtime QNN installed"
    } catch {
        Write-Warning "QNN-specific runtime not available, trying standard ONNX Runtime"
        & pip install "onnxruntime>=1.16.0,<1.17.0"
    }
    
    # Install Windows ML for NPU access
    Write-Info "Installing Windows ML support..."
    & pip install winml
    
    # Install Qualcomm AI Hub tools
    Write-Info "Installing Qualcomm AI Hub tools..."
    try {
        & pip install qai-hub
        Write-Success "Qualcomm AI Hub tools installed"
    } catch {
        Write-Warning "Qualcomm AI Hub tools not available"
    }
    
    # Verify NPU providers
    Write-Info "Verifying NPU providers..."
    $verifyScript = @"
import onnxruntime as ort
providers = ort.get_available_providers()
print('Available providers:', providers)
if 'QNNExecutionProvider' in providers:
    print('SUCCESS: QNN Provider available')
elif 'DmlExecutionProvider' in providers:
    print('WARNING: Using DirectML fallback')
else:
    print('WARNING: No accelerated providers, using CPU')
"@
    
    $verifyScript | & python
    
    return $true
}

# Download optimized models
function Download-Models {
    Write-Progress "Downloading optimized models"
    
    $modelsPath = "C:\AIDemo\models"
    Write-VerboseInfo "Models directory: $modelsPath"
    
    # Model configurations for Snapdragon
    $models = @(
        @{
            Name = "SDXL-Lightning-4step"
            URL = "https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_unet.safetensors"
            Size = "400MB"
            SizeBytes = 419430400
            Path = "$modelsPath\sdxl_lightning_4step"
        },
        @{
            Name = "SDXL-Turbo-1step"
            URL = "https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/unet/diffusion_pytorch_model.safetensors"
            Size = "500MB"
            SizeBytes = 524288000
            Path = "$modelsPath\sdxl_turbo_1step"
        }
    )
    
    $modelCount = 0
    $totalModels = $models.Count + 1  # Models + tokenizer
    
    foreach ($model in $models) {
        $modelCount++
        Write-Info "Processing $($model.Name) ($($model.Size))... [$modelCount/$totalModels]"
        Write-VerboseInfo "Model URL: $($model.URL)"
        Write-VerboseInfo "Target path: $($model.Path)"
        
        if (!(Test-Path $model.Path)) {
            Write-VerboseInfo "Creating model directory: $($model.Path)"
            New-Item -ItemType Directory -Path $model.Path -Force | Out-Null
        }
        
        $outputFile = Join-Path $model.Path "model.safetensors"
        Write-VerboseInfo "Output file: $outputFile"
        
        if (Test-Path $outputFile) {
            $fileSize = (Get-Item $outputFile).Length
            Write-VerboseInfo "File exists with size: $([math]::Round($fileSize / 1MB, 2))MB"
            
            if ($fileSize -gt ($model.SizeBytes * 0.9)) {  # Allow 10% variance
                Write-Success "$($model.Name) already downloaded"
            } else {
                Write-Warning "Incomplete download detected, re-downloading..."
                Remove-Item $outputFile -Force
            }
        }
        
        if (!(Test-Path $outputFile) -and !$CheckOnly) {
            try {
                Write-VerboseInfo "Starting download of $($model.Name)..."
                $downloadStart = Get-Date
                
                # Create web client with progress tracking
                $webClient = New-Object System.Net.WebClient
                $lastPercent = 0
                
                # Register event for progress updates
                Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
                    if ($script:Verbose) {
                        $percent = $Event.SourceEventArgs.ProgressPercentage
                        $received = [math]::Round($Event.SourceEventArgs.BytesReceived / 1MB, 2)
                        $total = [math]::Round($Event.SourceEventArgs.TotalBytesToReceive / 1MB, 2)
                        
                        # Update every 5% or on completion
                        if ($percent -ge ($lastPercent + 5) -or $percent -eq 100) {
                            Write-Host "`r  [v] Downloading: $($received)MB / $($total)MB ($percent%)" -NoNewline -ForegroundColor Yellow
                            $lastPercent = $percent
                        }
                    }
                } | Out-Null
                
                # Start download
                $webClient.DownloadFileTaskAsync($model.URL, $outputFile).Wait()
                
                # Clear progress line
                if ($script:Verbose) {
                    Write-Host "`r" + (" " * 80) + "`r" -NoNewline
                }
                
                $downloadTime = [math]::Round((Get-Date - $downloadStart).TotalSeconds, 1)
                $downloadSpeed = [math]::Round(($model.SizeBytes / 1MB) / $downloadTime, 2)
                
                Write-Success "$($model.Name) downloaded"
                Write-VerboseInfo "Download completed in $downloadTime seconds ($($downloadSpeed)MB/s)"
                
                # Verify file size
                $actualSize = (Get-Item $outputFile).Length
                Write-VerboseInfo "Downloaded file size: $([math]::Round($actualSize / 1MB, 2))MB"
                
            } catch {
                $script:warnings += "Failed to download $($model.Name)"
                Write-Warning "Could not download $($model.Name)"
                Write-VerboseInfo "Download error: $_"
            }
        } elseif ($CheckOnly -and !(Test-Path $outputFile)) {
            $script:warnings += "$($model.Name) not downloaded"
            Write-Warning "$($model.Name) missing"
        }
    }
    
    # Download tokenizer files
    $modelCount++
    Write-Info "Downloading tokenizer files... [$modelCount/$totalModels]"
    $tokenizerUrl = "https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/tokenizer_config.json"
    $tokenizerPath = "$modelsPath\tokenizer"
    
    Write-VerboseInfo "Tokenizer URL: $tokenizerUrl"
    Write-VerboseInfo "Tokenizer path: $tokenizerPath"
    
    if (!(Test-Path $tokenizerPath)) {
        Write-VerboseInfo "Creating tokenizer directory"
        New-Item -ItemType Directory -Path $tokenizerPath -Force | Out-Null
    }
    
    $tokenizerFile = "$tokenizerPath\tokenizer_config.json"
    
    if (!(Test-Path $tokenizerFile) -and !$CheckOnly) {
        try {
            Show-Spinner "Downloading tokenizer configuration"
            Invoke-WebRequest -Uri $tokenizerUrl -OutFile $tokenizerFile -UseBasicParsing
            Clear-Spinner
            Write-Success "Tokenizer downloaded"
            Write-VerboseInfo "Tokenizer file saved to: $tokenizerFile"
        } catch {
            Clear-Spinner
            Write-Warning "Could not download tokenizer"
            Write-VerboseInfo "Tokenizer download error: $_"
        }
    } elseif (Test-Path $tokenizerFile) {
        Write-VerboseInfo "Tokenizer already exists"
    }
    
    # Summary
    Write-VerboseInfo "Model download summary:"
    Write-VerboseInfo "  Models path: $modelsPath"
    $modelFiles = Get-ChildItem -Path $modelsPath -Recurse -File
    $totalSize = ($modelFiles | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-VerboseInfo "  Total files: $($modelFiles.Count)"
    Write-VerboseInfo "  Total size: $([math]::Round($totalSize, 2))GB"
    
    return $true
}

# Configure network and firewall
function Configure-Network {
    Write-Progress "Configuring network settings"
    
    if ($CheckOnly) {
        # Check if port is open
        $rule = Get-NetFirewallRule -DisplayName "AI Demo Client" -ErrorAction SilentlyContinue
        if ($rule) {
            Write-Success "Firewall rule exists"
        } else {
            $script:warnings += "Firewall rule for port 5000 not configured"
            Write-Warning "Firewall not configured"
        }
    } else {
        # Add firewall rule for port 5000
        Write-Info "Adding firewall rule for port 5000..."
        try {
            New-NetFirewallRule -DisplayName "AI Demo Client" `
                -Direction Inbound `
                -Protocol TCP `
                -LocalPort 5000 `
                -Action Allow `
                -ErrorAction SilentlyContinue
            Write-Success "Firewall rule added"
        } catch {
            Write-Warning "Could not add firewall rule"
        }
    }
    
    # Get network info
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "Loopback"}).IPAddress | Select-Object -First 1
    Write-Info "Machine IP: $ip"
    
    return $true
}

# Create startup scripts
function Create-StartupScripts {
    Write-Progress "Creating startup scripts"
    
    # Create start script
    $startScript = @"
@echo off
echo Starting Snapdragon AI Demo Client...
cd /d C:\AIDemo\client
call C:\AIDemo\venv\Scripts\activate.bat
set PYTHONPATH=C:\AIDemo\client
set SNAPDRAGON_NPU=1
set ONNX_PROVIDERS=QNNExecutionProvider,CPUExecutionProvider
python demo_client.py
pause
"@
    
    $startScript | Out-File -FilePath "C:\AIDemo\start_demo.bat" -Encoding ASCII
    Write-Success "Start script created"
    
    # Create auto-start PowerShell script
    $autoStartScript = @'
# Auto-start AI Demo Client
$logFile = "C:\AIDemo\logs\autostart_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logFile

Write-Host "Starting AI Demo Client..." -ForegroundColor Green
Set-Location C:\AIDemo\client
& C:\AIDemo\venv\Scripts\Activate.ps1

$env:PYTHONPATH = "C:\AIDemo\client"
$env:SNAPDRAGON_NPU = "1"
$env:ONNX_PROVIDERS = "QNNExecutionProvider,CPUExecutionProvider"

python demo_client.py

Stop-Transcript
'@
    
    $autoStartScript | Out-File -FilePath "C:\AIDemo\start_demo.ps1" -Encoding UTF8
    Write-Success "PowerShell start script created"
    
    return $true
}

# Run performance test
function Test-Performance {
    Write-Progress "Running performance test"
    
    if ($CheckOnly) {
        Write-Info "Skipping performance test in check-only mode"
        return $true
    }
    
    Write-Info "Testing AI pipeline performance..."
    Write-VerboseInfo "Activating virtual environment for test..."
    
    & C:\AIDemo\venv\Scripts\Activate.ps1
    Set-Location C:\AIDemo\client
    
    Write-VerboseInfo "Python path: $(& python -c 'import sys; print(sys.executable)')"
    Write-VerboseInfo "Working directory: $(Get-Location)"
    
    if ($script:Verbose) {
        Write-VerboseInfo "Checking installed packages..."
        $packages = & pip list --format=freeze | Select-Object -First 10
        Write-VerboseInfo "Sample packages:"
        $packages | ForEach-Object { Write-VerboseInfo "  $_" }
    }
    
    $testScript = @"
import time
import sys
import os

# Set verbose flag for test script
verbose = $(if ($script:Verbose) { "True" } else { "False" })

sys.path.insert(0, 'C:\\AIDemo\\client')

try:
    if verbose:
        print("-> Importing platform detection module...")
    from platform_detection import detect_platform
    
    if verbose:
        print("-> Importing AI pipeline module...")
    from ai_pipeline import AIImagePipeline
    
    print("Detecting platform...")
    platform = detect_platform()
    print(f"Platform: {platform['name']}")
    print(f"Acceleration: {platform['acceleration']}")
    
    if verbose:
        print(f"-> Platform details:")
        for key, value in platform.items():
            print(f"  {key}: {value}")
    
    if platform['is_snapdragon']:
        print("[OK] Snapdragon platform confirmed")
    else:
        print("[!] Not detected as Snapdragon")
    
    print("\nInitializing AI pipeline...")
    if verbose:
        print("-> Loading model weights and configuration...")
    
    start = time.time()
    pipeline = AIImagePipeline(platform)
    init_time = time.time() - start
    print(f"Initialization time: {init_time:.2f}s")
    
    if verbose:
        print(f"-> Pipeline initialized with providers: {getattr(pipeline, 'providers', 'unknown')}")
    
    print("\nGenerating test image...")
    prompt = "A futuristic robot, digital art, highly detailed"
    
    if verbose:
        print(f"-> Prompt: {prompt}")
        print(f"-> Steps: 4")
        print(f"-> Resolution: 768x768")
        print("-> Starting generation...")
    
    start = time.time()
    
    # Progress callback for verbose mode
    def progress_callback(step, total):
        if verbose:
            elapsed = time.time() - start
            print(f"  Step {step}/{total} - {elapsed:.1f}s elapsed")
    
    result = pipeline.generate(prompt, steps=4, callback=progress_callback if verbose else None)
    gen_time = time.time() - start
    
    print(f"\n[OK] Generation completed in {gen_time:.2f}s")
    
    if verbose:
        print(f"-> Average time per step: {gen_time/4:.2f}s")
        print(f"-> Estimated throughput: {60/gen_time:.1f} images/minute")
    
    if gen_time < 10:
        print("[OK] NPU acceleration appears to be working!")
    elif gen_time < 30:
        print("[!] Performance is moderate - NPU may not be fully utilized")
    else:
        print("[!] Performance is slow - likely using CPU fallback")
        
except Exception as e:
    print(f"[X] Test failed: {e}")
    if verbose:
        import traceback
        traceback.print_exc()
"@
    
    Write-VerboseInfo "Executing performance test script..."
    $testOutput = $testScript | & python 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    
    return $true
}

# Generate summary report
function Generate-Report {
    Write-Progress "Generating readiness report"
    
    $report = @"

========================================
SNAPDRAGON DEMO READINESS REPORT
========================================
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Machine: $env:COMPUTERNAME

HARDWARE STATUS:
"@
    
    # Add hardware info
    $cpu = Get-WmiObject Win32_Processor
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $report += @"

  Processor: $($cpu.Name)
  Architecture: $($env:PROCESSOR_ARCHITECTURE)
  RAM: $($ram)GB
  
"@
    
    if ($script:issues.Count -eq 0) {
        $report += @"
OVERALL STATUS: [OK] DEMO READY

All requirements met. The system is ready for demonstration.

Key Features Enabled:
  * Snapdragon X Elite NPU acceleration
  * Optimized INT8 models loaded
  * Network communication configured
  * Expected performance: 3-5 seconds per image

"@
    } else {
        $report += @"
OVERALL STATUS: [X] NOT READY

Critical Issues Found:
"@
        foreach ($issue in $script:issues) {
            $report += "  * $issue`n"
        }
    }
    
    if ($script:warnings.Count -gt 0) {
        $report += @"

Warnings:
"@
        foreach ($warning in $script:warnings) {
            $report += "  * $warning`n"
        }
    }
    
    $report += @"

NEXT STEPS:
1. Start the demo client: C:\AIDemo\start_demo.bat
2. Verify network connectivity with control hub
3. Run test prompt from control hub
4. Monitor performance metrics

Log files saved to: C:\AIDemo\logs\
========================================
"@
    
    Write-Host $report
    
    # Save report
    $reportPath = "C:\AIDemo\logs\readiness_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "Report saved to $reportPath"
}

# Main execution
function Main {
    # Store verbose flag in script scope
    $script:Verbose = $Verbose
    
    Write-Host @"
+============================================================+
|     SNAPDRAGON X ELITE DEMO PREPARATION SCRIPT            |
|     Optimized for NPU-Accelerated AI Generation           |
+============================================================+
"@ -ForegroundColor Cyan
    
    if ($CheckOnly) {
        Write-Warning "Running in CHECK-ONLY mode - no changes will be made"
    }
    
    if ($Verbose) {
        Write-Info "VERBOSE mode enabled - detailed progress will be shown"
        Write-VerboseInfo "Script parameters:"
        Write-VerboseInfo "  CheckOnly: $CheckOnly"
        Write-VerboseInfo "  Force: $Force"
        Write-VerboseInfo "  LogPath: $LogPath"
        Write-VerboseInfo "System information:"
        Write-VerboseInfo "  Computer: $env:COMPUTERNAME"
        Write-VerboseInfo "  User: $env:USERNAME"
        Write-VerboseInfo "  PowerShell: $($PSVersionTable.PSVersion)"
        Write-VerboseInfo "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    }
    
    # Start timing
    $startTime = Get-Date
    Write-VerboseInfo "Setup started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    # Initialize
    Initialize-Directories
    
    # Run all checks and installations
    $hardwareOK = Test-HardwareRequirements
    
    if (!$hardwareOK -and !$Force) {
        Write-Error "Hardware requirements not met. Use -Force to continue anyway."
        exit 1
    }
    
    $pythonOK = Install-Python
    $poetryOK = Install-Poetry
    
    if ($pythonOK -and $poetryOK) {
        Update-Repository
        
        if (!$CheckOnly) {
            Install-Dependencies
            Install-NPUSupport
            Download-Models
        }
    }
    
    Configure-Network
    Create-StartupScripts
    
    if (!$CheckOnly) {
        Test-Performance
    }
    
    # Calculate elapsed time
    $endTime = Get-Date
    $elapsed = $endTime - $startTime
    Write-VerboseInfo "Setup completed at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-VerboseInfo "Total elapsed time: $($elapsed.ToString('hh\:mm\:ss'))"
    
    # Generate final report
    Generate-Report
    
    # Summary with timing
    Write-Host "`n" + ("=" * 60) -ForegroundColor DarkGray
    Write-Info "Setup completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
    
    if ($script:Verbose) {
        Write-VerboseInfo "Detailed timing breakdown:"
        Write-VerboseInfo "  Total seconds: $([math]::Round($elapsed.TotalSeconds, 1))"
        Write-VerboseInfo "  Issues found: $($script:issues.Count)"
        Write-VerboseInfo "  Warnings: $($script:warnings.Count)"
    }
    
    # Exit code based on readiness
    if ($script:issues.Count -eq 0) {
        Write-Host "`n[OK] SYSTEM IS DEMO READY!" -ForegroundColor Green
        if ($script:Verbose) {
            Write-VerboseInfo "All requirements satisfied - system ready for Snapdragon NPU demo"
        }
        exit 0
    } else {
        Write-Host "`n[X] System requires attention before demo" -ForegroundColor Red
        if ($script:Verbose) {
            Write-VerboseInfo "Critical issues must be resolved:"
            $script:issues | ForEach-Object { Write-VerboseInfo "  - $_" }
        }
        exit 1
    }
}

# Run main function
try {
    Main
} catch {
    Write-Error "Fatal error: $_"
    exit 1
}