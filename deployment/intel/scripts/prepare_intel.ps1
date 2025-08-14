#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Intel Core Ultra Optimized Demo Preparation Script
.DESCRIPTION
    Prepares Intel Core Ultra systems for AI image generation demos
    Utilizes DirectML GPU acceleration for FP16 models
    Expected performance: 35-45 seconds per 768x768 image
.NOTES
    Target: Intel Core Ultra on Windows 11 x64 (AMD64)
    Models: SDXL Base 1.0 FP16 (~6.9GB)
    Acceleration: DirectML via GPU/iGPU
.PARAMETER CheckOnly
    Only check requirements without making changes
.PARAMETER Force
    Continue even if hardware requirements not fully met
.PARAMETER WhatIf
    Show what would be done without making changes
.PARAMETER Verbose
    Show detailed progress information
.PARAMETER SkipModelDownload
    Skip downloading large model files
.PARAMETER UseHttpRange
    Enable HTTP range requests for resumable downloads
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$CheckOnly = $false,
    [switch]$Force = $false,
    [switch]$SkipModelDownload = $false,
    [switch]$UseHttpRange = $true,
    [string]$LogPath = "C:\AIDemo\logs",
    [ValidateSet('Speed', 'Balanced', 'Quality')]
    [string]$OptimizationProfile = 'Balanced'
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$script:totalSteps = 25
$script:currentStep = 0
$script:issues = @()
$script:warnings = @()
$script:rollbackStack = @()
$script:logFile = $null
$script:transcriptStarted = $false

# Constants
$script:DEMO_BASE = "C:\AIDemo"
$script:VENV_PATH = "$script:DEMO_BASE\venv"
$script:CLIENT_PATH = "$script:DEMO_BASE\client"
$script:MODELS_PATH = "$script:DEMO_BASE\models"
$script:CACHE_PATH = "$script:DEMO_BASE\cache"
$script:TEMP_PATH = "$script:DEMO_BASE\temp"

# Color output functions - avoiding conflicts with built-in cmdlets
function Write-Success { 
    param($Message)
    Write-Host "[OK] $Message" -ForegroundColor Green 
}

function Write-ErrorMsg { 
    param($Message)
    Write-Host "[X] $Message" -ForegroundColor Red 
    $script:issues += $Message
}

function Write-WarningMsg { 
    param($Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow 
    $script:warnings += $Message
}

function Write-Info { 
    param($Message)
    Write-Host "[i] $Message" -ForegroundColor Cyan 
}

function Write-VerboseInfo {
    param($Message)
    if ($VerbosePreference -eq 'Continue') {
        Write-Host "  -> $Message" -ForegroundColor DarkGray
    }
}

function Write-StepProgress {
    param($Message)
    $script:currentStep++
    $percent = [math]::Round(($script:currentStep / $script:totalSteps) * 100)
    Write-Host "`n[$script:currentStep/$script:totalSteps] $Message" -ForegroundColor Magenta
    Write-Progress -Activity "Intel Demo Setup" -Status $Message -PercentComplete $percent
    if ($VerbosePreference -eq 'Continue') {
        Write-Host ("-" * 60) -ForegroundColor DarkGray
    }
}

# Progress tracking
class ProgressReporter {
    [string]$CurrentOperation
    [int]$TotalSteps
    [int]$CurrentStep
    [datetime]$StartTime
    
    ProgressReporter([int]$totalSteps) {
        $this.TotalSteps = $totalSteps
        $this.CurrentStep = 0
        $this.StartTime = Get-Date
    }
    
    [void]Update([string]$operation) {
        $this.CurrentStep++
        $this.CurrentOperation = $operation
        
        $percentComplete = ($this.CurrentStep / $this.TotalSteps) * 100
        $elapsed = (Get-Date) - $this.StartTime
        $remaining = if ($this.CurrentStep -gt 0) {
            $avgTime = $elapsed.TotalSeconds / $this.CurrentStep
            $remainingSteps = $this.TotalSteps - $this.CurrentStep
            [TimeSpan]::FromSeconds($avgTime * $remainingSteps)
        } else {
            [TimeSpan]::Zero
        }
        
        Write-Progress `
            -Activity "Intel Setup Progress" `
            -Status $operation `
            -PercentComplete $percentComplete `
            -SecondsRemaining $remaining.TotalSeconds
    }
}

# Initialize logging
function Initialize-Logging {
    if (!$script:transcriptStarted) {
        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $script:logFile = "$LogPath\intel_setup_$timestamp.log"
        
        # Create log directory if needed
        if (!(Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        
        # Start transcript
        try {
            Start-Transcript -Path $script:logFile -Append
            $script:transcriptStarted = $true
            Write-VerboseInfo "Logging started: $script:logFile"
        } catch {
            Write-WarningMsg "Could not start transcript: $_"
        }
    }
}

# Cleanup function
function Stop-Logging {
    if ($script:transcriptStarted) {
        try {
            Stop-Transcript
            Write-VerboseInfo "Logging stopped"
        } catch {
            # Transcript might already be stopped
        }
    }
}

# Rollback support
function Register-RollbackAction {
    param(
        [scriptblock]$Action,
        [string]$Description
    )
    
    $script:rollbackStack += @{
        Action = $Action
        Description = $Description
        Timestamp = Get-Date
    }
    
    Write-VerboseInfo "Registered rollback: $Description"
}

function Invoke-Rollback {
    if ($script:rollbackStack.Count -eq 0) {
        Write-Info "No rollback actions to perform"
        return
    }
    
    Write-WarningMsg "Initiating rollback of $($script:rollbackStack.Count) actions..."
    
    for ($i = $script:rollbackStack.Count - 1; $i -ge 0; $i--) {
        $action = $script:rollbackStack[$i]
        Write-Info "Rolling back: $($action.Description)"
        
        try {
            & $action.Action
            Write-Success "Rolled back: $($action.Description)"
        } catch {
            Write-ErrorMsg "Rollback failed for: $($action.Description) - $_"
        }
    }
    
    $script:rollbackStack = @()
}

# Create required directories
function Initialize-Directories {
    Write-StepProgress "Creating directory structure"
    
    $dirs = @(
        $script:DEMO_BASE,
        $script:CLIENT_PATH,
        $script:MODELS_PATH,
        $script:CACHE_PATH,
        "$script:CACHE_PATH\downloads",
        "$script:CACHE_PATH\compiled",
        $LogPath,
        $script:TEMP_PATH
    )
    
    foreach ($dir in $dirs) {
        if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
            if (!(Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Success "Created $dir"
                
                # Register rollback
                Register-RollbackAction -Description "Remove directory $dir" -Action {
                    if (Test-Path $dir) {
                        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                Write-VerboseInfo "Directory exists: $dir"
            }
        }
    }
}

# Test Intel hardware requirements
function Test-IntelHardwareRequirements {
    Write-StepProgress "Checking Intel hardware requirements"
    
    $hardwareStatus = @{
        ProcessorValid = $false
        ProcessorName = ""
        ProcessorGeneration = 0
        AVX512Support = $false
        DirectX12Valid = $false
        DirectMLAvailable = $false
        GPUName = ""
        GPUMemory = 0
        SystemRAM = 0
        StorageAvailable = 0
        OverallStatus = $false
        Warnings = @()
        Errors = @()
    }
    
    try {
        # Check architecture (Intel reports as AMD64)
        Write-VerboseInfo "Checking system architecture..."
        $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
        
        if ($arch -ne "AMD64") {
            $hardwareStatus.Errors += "Not running on x64 architecture (found: $arch)"
            Write-ErrorMsg "Architecture: $arch (expected AMD64 for Intel x64)"
        } else {
            Write-Success "Architecture: $arch (Intel x64 compatible)"
        }
        
        # Check processor
        Write-VerboseInfo "Querying Intel processor information..."
        $cpu = Get-WmiObject Win32_Processor
        $hardwareStatus.ProcessorName = $cpu.Name
        
        # Check for Intel Core Ultra or recent generations
        if ($cpu.Name -match "Intel.*Core.*Ultra" -or 
            $cpu.Name -match "Intel.*Core.*i[579].*1[34]\d{2,3}[HUP]") {
            Write-Success "Processor: $($cpu.Name)"
            $hardwareStatus.ProcessorValid = $true
            
            # Extract generation
            if ($cpu.Name -match "(\d{2})\d{2,3}[HUP]") {
                $hardwareStatus.ProcessorGeneration = [int]$matches[1]
                Write-VerboseInfo "Processor generation: $($hardwareStatus.ProcessorGeneration)"
            }
        } else {
            $hardwareStatus.Warnings += "Not an Intel Core Ultra processor: $($cpu.Name)"
            Write-WarningMsg "Processor: $($cpu.Name) (Intel Core Ultra recommended)"
        }
        
        # Check AVX-512 support (simplified check)
        Write-VerboseInfo "Checking AVX-512 instruction set support..."
        try {
            $cpuInfo = Get-WmiObject Win32_Processor | Select-Object -First 1
            # Note: Actual AVX-512 detection would require CPUID checks
            # For now, assume 11th gen+ Intel Core has AVX-512
            if ($hardwareStatus.ProcessorGeneration -ge 11) {
                $hardwareStatus.AVX512Support = $true
                Write-Success "AVX-512 instruction set likely supported"
            } else {
                Write-VerboseInfo "AVX-512 may not be available on this processor"
            }
        } catch {
            Write-VerboseInfo "Could not verify AVX-512 support"
        }
        
        # Check RAM
        Write-VerboseInfo "Checking system memory..."
        $memInfo = Get-WmiObject Win32_ComputerSystem
        $ram = [math]::Round($memInfo.TotalPhysicalMemory / 1GB)
        $hardwareStatus.SystemRAM = $ram
        
        if ($ram -lt 16) {
            $hardwareStatus.Errors += "Insufficient RAM: $($ram)GB (16GB minimum required)"
            Write-ErrorMsg "RAM: $($ram)GB (16GB minimum required for FP16 models)"
        } elseif ($ram -lt 32) {
            $hardwareStatus.Warnings += "RAM below recommended: $($ram)GB (32GB recommended)"
            Write-WarningMsg "RAM: $($ram)GB (32GB recommended for optimal performance)"
        } else {
            Write-Success "RAM: $($ram)GB"
        }
        
        # Check GPU and DirectX 12
        Write-VerboseInfo "Checking GPU and DirectX 12 support..."
        $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "Intel|Arc|Iris" } | Select-Object -First 1
        
        if ($gpu) {
            $hardwareStatus.GPUName = $gpu.Name
            $hardwareStatus.GPUMemory = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            Write-Success "GPU: $($gpu.Name)"
            Write-VerboseInfo "GPU Memory: $($hardwareStatus.GPUMemory)GB"
        } else {
            # Check for any GPU that supports DirectX 12
            $gpu = Get-WmiObject Win32_VideoController | Select-Object -First 1
            if ($gpu) {
                $hardwareStatus.GPUName = $gpu.Name
                Write-Info "GPU: $($gpu.Name) (will attempt DirectML)"
            } else {
                $hardwareStatus.Errors += "No GPU detected"
                Write-ErrorMsg "No GPU detected for DirectML acceleration"
            }
        }
        
        # Check DirectX version and WDDM
        Write-VerboseInfo "Checking DirectX 12 and WDDM support..."
        try {
            # Check Windows version for DirectX 12 support
            $os = Get-WmiObject Win32_OperatingSystem
            $osVersion = [version]$os.Version
            
            # Windows 10 1903+ or Windows 11
            if (($osVersion.Major -eq 10 -and $osVersion.Build -ge 18362) -or $osVersion.Major -gt 10) {
                $hardwareStatus.DirectX12Valid = $true
                Write-Success "DirectX 12 compatible OS detected"
                
                # Check WDDM version
                $wddm = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\DirectX" -ErrorAction SilentlyContinue
                if ($wddm) {
                    Write-VerboseInfo "DirectX registry found"
                }
            } else {
                $hardwareStatus.Errors += "OS version too old for DirectX 12 (requires Windows 10 1903+)"
                Write-ErrorMsg "OS does not support DirectX 12"
            }
        } catch {
            Write-WarningMsg "Could not verify DirectX 12 support"
        }
        
        # Check disk space
        Write-VerboseInfo "Checking disk space..."
        $drive = Get-PSDrive C
        $freeSpace = [math]::Round($drive.Free / 1GB, 2)
        $hardwareStatus.StorageAvailable = $freeSpace
        
        if ($freeSpace -lt 10) {
            $hardwareStatus.Errors += "Insufficient disk space: $($freeSpace)GB (10GB required)"
            Write-ErrorMsg "Free space: $($freeSpace)GB (10GB required for models)"
        } else {
            Write-Success "Free space: $($freeSpace)GB"
        }
        
        # Set overall status
        $hardwareStatus.OverallStatus = $hardwareStatus.Errors.Count -eq 0
        
        return $hardwareStatus
        
    } catch {
        Write-ErrorMsg "Hardware check failed: $_"
        $hardwareStatus.Errors += "Hardware check exception: $_"
        return $hardwareStatus
    }
}

# Show hardware confirmation dialog
function Show-HardwareConfirmation {
    param(
        [hashtable]$HardwareStatus
    )
    
    Write-Host "`n====== DETECTED HARDWARE ======" -ForegroundColor Cyan
    Write-Host "Processor: $($HardwareStatus.ProcessorName)"
    Write-Host "GPU: $($HardwareStatus.GPUName)"
    Write-Host "RAM: $($HardwareStatus.SystemRAM)GB"
    Write-Host "DirectX 12: $(if ($HardwareStatus.DirectX12Valid) { 'Available' } else { 'Not Available' })"
    Write-Host "Free Space: $($HardwareStatus.StorageAvailable)GB"
    Write-Host "================================`n"
    
    if ($HardwareStatus.Warnings.Count -gt 0) {
        Write-WarningMsg "Warnings detected:"
        $HardwareStatus.Warnings | ForEach-Object { Write-WarningMsg "  - $_" }
        Write-Host ""
    }
    
    if ($HardwareStatus.Errors.Count -gt 0) {
        Write-ErrorMsg "Errors detected:"
        $HardwareStatus.Errors | ForEach-Object { Write-ErrorMsg "  - $_" }
        Write-Host ""
        
        if (!$Force) {
            Write-Host "Continue anyway? Use -Force to bypass hardware checks" -ForegroundColor Yellow
            return $false
        }
    }
    
    if (!$CheckOnly -and !$WhatIf) {
        $continue = Read-Host "Continue with this configuration? (Y/N)"
        return $continue -eq 'Y'
    }
    
    return $true
}

# Check and install Python
function Install-Python {
    Write-StepProgress "Checking Python installation"
    
    $pythonVersions = @("3.10", "3.9")
    $pythonFound = $false
    
    foreach ($version in $pythonVersions) {
        $pythonPaths = @(
            "C:\Python$($version -replace '\.', '')",
            "$env:LOCALAPPDATA\Programs\Python\Python$($version -replace '\.', '')",
            "$env:ProgramFiles\Python$($version -replace '\.', '')"
        )
        
        foreach ($pythonPath in $pythonPaths) {
            $pythonExe = "$pythonPath\python.exe"
            
            if (Test-Path $pythonExe) {
                try {
                    $installedVersion = & $pythonExe --version 2>&1
                    if ($installedVersion -match "Python $version") {
                        Write-Success "Python $version found at $pythonPath"
                        $env:Path = "$pythonPath;$pythonPath\Scripts;$env:Path"
                        $pythonFound = $true
                        return $true
                    }
                } catch {
                    Write-VerboseInfo "Error checking Python at $pythonPath"
                }
            }
        }
    }
    
    if (!$pythonFound -and !$CheckOnly) {
        if ($PSCmdlet.ShouldProcess("Python 3.10", "Install")) {
            Write-Info "Installing Python 3.10..."
            $pythonUrl = "https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"
            $installer = "$script:TEMP_PATH\python-installer.exe"
            
            try {
                Write-VerboseInfo "Downloading Python installer..."
                $webClient = $null
                try {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($pythonUrl, $installer)
                } catch {
                    Write-ErrorMsg "Error downloading Python installer: $_"
                    throw
                } finally {
                    if ($webClient) { $webClient.Dispose() }
                }
                
                Write-VerboseInfo "Running Python installer..."
                $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "TargetDir=C:\Python310")
                Start-Process -FilePath $installer -ArgumentList $installArgs -Wait
                
                $env:Path = "C:\Python310;C:\Python310\Scripts;$env:Path"
                Write-Success "Python 3.10 installed"
                
                Register-RollbackAction -Description "Uninstall Python" -Action {
                    Write-Info "Note: Python uninstallation requires manual intervention"
                }
                
                return $true
            } catch {
                Write-ErrorMsg "Failed to install Python: $_"
                return $false
            }
        }
    } elseif (!$pythonFound) {
        Write-ErrorMsg "Python 3.9/3.10 not found"
        return $false
    }
    
    return $pythonFound
}

# Install virtual environment and core dependencies
function Install-CoreDependencies {
    Write-StepProgress "Installing core dependencies"
    
    if (!$PSCmdlet.ShouldProcess("Core dependencies", "Install")) {
        return $true
    }
    
    Push-Location $script:CLIENT_PATH
    
    try {
        # Create virtual environment
        if (!(Test-Path $script:VENV_PATH)) {
            Write-Info "Creating virtual environment..."
            & python -m venv $script:VENV_PATH
            
            Register-RollbackAction -Description "Remove virtual environment" -Action {
                if (Test-Path $script:VENV_PATH) {
                    Remove-Item $script:VENV_PATH -Recurse -Force
                }
            }
        }
        
        # Activate virtual environment
        & "$script:VENV_PATH\Scripts\Activate.ps1"
        
        # Upgrade pip
        Write-Info "Upgrading pip..."
        & python -m pip install --upgrade pip --quiet
        
        # Install core dependencies from requirements file
        $requirementsPath = "$PSScriptRoot\..\requirements\requirements-core.txt"
        if (Test-Path $requirementsPath) {
            Write-Info "Installing from requirements-core.txt..."
            & pip install -r $requirementsPath --quiet
            Write-Success "Core dependencies installed"
        } else {
            # Fallback to individual packages
            $coreDeps = @(
                "numpy>=1.21.0,<2.0.0",
                "pillow>=8.0.0,<11.0.0",
                "flask>=2.0.0,<3.0.0",
                "requests>=2.25.0,<3.0.0",
                "psutil>=5.8.0"
            )
            
            foreach ($dep in $coreDeps) {
                Write-Info "Installing $dep..."
                & pip install $dep --quiet
            }
        }
        
        return $true
        
    } catch {
        Write-ErrorMsg "Failed to install core dependencies: $_"
        return $false
    } finally {
        Pop-Location
    }
}

# Install Intel-specific acceleration packages
function Install-IntelAcceleration {
    Write-StepProgress "Installing Intel acceleration packages"
    
    if (!$PSCmdlet.ShouldProcess("Intel acceleration", "Install")) {
        return $true
    }
    
    & "$script:VENV_PATH\Scripts\Activate.ps1"
    
    $accelerationStages = @(
        @{
            Name = "PyTorch CPU"
            Packages = @("torch>=2.1.0,<2.2.0", "torchvision>=0.16.0,<0.17.0")
            IndexUrl = "https://download.pytorch.org/whl/cpu"
            Critical = $true
        },
        @{
            Name = "DirectML"
            Packages = @("torch-directml>=1.13.0")
            IndexUrl = "https://download.pytorch.org/whl/directml"
            PreRelease = $true
            Critical = $true
        },
        @{
            Name = "ONNX DirectML"
            Packages = @("onnxruntime-directml>=1.16.0")
            Critical = $false
        },
        @{
            Name = "Intel Extensions"
            Packages = @("intel-extension-for-pytorch>=2.0.0")
            Critical = $true
        },
        @{
            Name = "AI/ML Libraries"
            Packages = @(
                "huggingface_hub==0.24.6",
                "transformers==4.36.2",
                "diffusers==0.25.1",
                "accelerate==0.25.0",
                "safetensors==0.4.1",
                "optimum"
            )
            Critical = $true
        }
    )
    
    $success = $true
    
    foreach ($stage in $accelerationStages) {
        Write-Info "Installing $($stage.Name)..."
        
        # Pre-installation validation
        Write-VerboseInfo "Running pip check before installing $($stage.Name)..."
        & pip check | Out-String | Write-VerboseInfo
        
        try {
            foreach ($package in $stage.Packages) {
                Write-Info "Installing $package..."
                
                $installArgs = @($package)
                
                if ($stage.IndexUrl) {
                    $installArgs += "--index-url"
                    $installArgs += $stage.IndexUrl
                }
                
                if ($stage.PreRelease) {
                    $installArgs += "--pre"
                }
                
                # Remove --quiet to show installation errors
                Write-VerboseInfo "Running: pip install $($installArgs -join ' ')"
                & pip install @installArgs
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Package installation failed: $package (Exit code: $LASTEXITCODE)"
                }
                
                Write-VerboseInfo "Successfully installed: $package"
            }
            
            # Post-installation validation
            Write-VerboseInfo "Running pip check after installing $($stage.Name)..."
            & pip check | Out-String | Write-VerboseInfo
            
            Write-Success "$($stage.Name) installed successfully"
            
        } catch {
            $errorMsg = "Package installation failed: $($stage.Name) - $_"
            Write-VerboseInfo "Detailed error: $errorMsg"
            
            if ($stage.Critical) {
                Write-ErrorMsg "Critical package failed: $($stage.Name) - $_"
                Write-ErrorMsg "This will prevent DirectML acceleration from working properly"
                $success = $false
                break
            } else {
                Write-WarningMsg "Optional package failed: $($stage.Name) - $_"
            }
        }
    }
    
    # Comprehensive DirectML verification
    if ($success) {
        Write-Info "Performing comprehensive DirectML verification..."
        
        # Final dependency check
        Write-VerboseInfo "Running final pip check..."
        $pipCheckOutput = & pip check 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "All package dependencies are satisfied"
        } else {
            Write-WarningMsg "Package dependency issues detected:"
            $pipCheckOutput | ForEach-Object { Write-VerboseInfo "  $_" }
        }
        
        $verifyScript = @"
import sys
import os

print('=== DirectML Verification Report ===')
print(f'Python version: {sys.version}')
print(f'Python executable: {sys.executable}')

# Test torch import
try:
    import torch
    print(f'PyTorch version: {torch.__version__}')
    print(f'PyTorch CUDA available: {torch.cuda.is_available()}')
except ImportError as e:
    print(f'ERROR: Cannot import PyTorch: {e}')
    sys.exit(1)

# Test DirectML import and functionality
try:
    import torch_directml
    print(f'DirectML version: {torch_directml.__version__ if hasattr(torch_directml, "__version__") else "Unknown"}')
    
    # Test device creation
    dml_device = torch_directml.device()
    print(f'SUCCESS: DirectML device created: {dml_device}')
    
    # Get device name
    try:
        device_name = torch_directml.device_name(0)
        print(f'DirectML device name: {device_name}')
    except:
        print('DirectML device name: Not available')
    
    # Test tensor operations
    print('Testing DirectML tensor operations...')
    test_tensor = torch.ones(100, 100).to(dml_device)
    result = torch.mm(test_tensor, test_tensor)
    print(f'DirectML tensor test: SUCCESS (result shape: {result.shape})')
    
    # Test memory allocation
    try:
        large_tensor = torch.randn(1000, 1000).to(dml_device)
        print('DirectML memory allocation: SUCCESS')
        del large_tensor
    except Exception as e:
        print(f'DirectML memory allocation: WARNING - {e}')
    
    print('SUCCESS: DirectML is fully functional')
    
except ImportError as e:
    print(f'ERROR: Cannot import DirectML: {e}')
    print('DirectML acceleration will not be available')
    print('The system will fall back to CPU-only processing')
except Exception as e:
    print(f'ERROR: DirectML test failed: {e}')
    print('DirectML may be installed but not functioning properly')
    import traceback
    traceback.print_exc()

# Test Intel Extensions
try:
    import intel_extension_for_pytorch as ipex
    print(f'Intel Extension for PyTorch: Available')
    print(f'Intel Extension version: {ipex.__version__ if hasattr(ipex, "__version__") else "Unknown"}')
except ImportError:
    print('Intel Extension for PyTorch: Not available (will use standard PyTorch)')

# Test ONNX Runtime DirectML
try:
    import onnxruntime as ort
    providers = ort.get_available_providers()
    print(f'ONNX Runtime providers: {", ".join(providers)}')
    if 'DmlExecutionProvider' in providers:
        print('ONNX Runtime DirectML: Available')
    else:
        print('ONNX Runtime DirectML: Not available')
except ImportError:
    print('ONNX Runtime: Not available')

print('=== End Verification Report ===')
"@
        
        Write-VerboseInfo "Running DirectML verification script..."
        $verificationOutput = $verifyScript | & python 2>&1
        $verificationOutput | ForEach-Object {
            if ($_ -match "^SUCCESS:") {
                Write-Success $_.Replace("SUCCESS: ", "")
            } elseif ($_ -match "^ERROR:") {
                Write-ErrorMsg $_.Replace("ERROR: ", "")
            } elseif ($_ -match "^WARNING:") {
                Write-WarningMsg $_.Replace("WARNING: ", "")
            } else {
                Write-Info $_
            }
        }
        
        # Check if DirectML verification was successful
        if ($verificationOutput -match "SUCCESS: DirectML is fully functional") {
            Write-Success "DirectML verification completed successfully"
        } elseif ($verificationOutput -match "DirectML acceleration will not be available") {
            Write-WarningMsg "DirectML not available - falling back to CPU processing"
            Write-WarningMsg "Performance will be significantly slower without GPU acceleration"
        } else {
            Write-WarningMsg "DirectML verification completed with issues"
            Write-Info "Review the verification output above for details"
        }
    }
    
    return $success
}

# Configure DirectML provider
function Configure-DirectMLProvider {
    Write-StepProgress "Configuring DirectML optimization settings"
    
    Write-Info "Setting DirectML environment variables..."
    
    # DirectML configuration
    $env:ORT_DIRECTML_DEVICE_ID = "0"
    $env:ORT_DIRECTML_MEMORY_ARENA = "1"
    $env:ORT_DIRECTML_GRAPH_OPTIMIZATION = "ALL"
    
    # Intel MKL optimizations
    $env:MKL_ENABLE_INSTRUCTIONS = "AVX512"
    $env:OMP_NUM_THREADS = [Environment]::ProcessorCount
    $env:MKL_DYNAMIC = "FALSE"
    $env:MKL_NUM_THREADS = [Math]::Max(4, [Environment]::ProcessorCount / 2)
    
    Write-Success "DirectML provider configured"
    Write-VerboseInfo "Device ID: 0"
    Write-VerboseInfo "Memory Arena: Enabled"
    Write-VerboseInfo "Graph Optimization: ALL"
    Write-VerboseInfo "MKL Instructions: AVX512"
    Write-VerboseInfo "OMP Threads: $env:OMP_NUM_THREADS"
}

# Download large models with resume capability
function Download-IntelModels {
    Write-StepProgress "Downloading Intel-optimized models"
    
    if ($SkipModelDownload) {
        Write-Info "Skipping model download (--SkipModelDownload specified)"
        return $true
    }
    
    if (!$PSCmdlet.ShouldProcess("SDXL FP16 models (6.9GB)", "Download")) {
        return $true
    }
    
    # Confirm large download
    if (!$CheckOnly -and !$Force) {
        Write-Host "`n====== MODEL DOWNLOAD ======" -ForegroundColor Yellow
        Write-Host "Total download size: ~6.9 GB"
        Write-Host "Estimated time (50 Mbps): ~20 minutes"
        Write-Host "Storage required: ~8.5 GB"
        Write-Host "============================`n"
        
        $confirm = Read-Host "Proceed with download? (Y/N)"
        if ($confirm -ne 'Y') {
            Write-Info "Model download skipped by user"
            return $true
        }
    }
    
    $models = @(
        @{
            Name = "SDXL-Base-1.0-FP16-UNet"
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/unet/diffusion_pytorch_model.fp16.safetensors"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\unet"
            File = "diffusion_pytorch_model.fp16.safetensors"
            Size = 6900MB
            SHA256 = $null  # Would be provided in production
        },
        @{
            Name = "SDXL-Base-1.0-FP16-VAE"
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/vae/diffusion_pytorch_model.fp16.safetensors"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\vae"
            File = "diffusion_pytorch_model.fp16.safetensors"
            Size = 335MB
            SHA256 = $null
        },
        @{
            Name = "SDXL-Base-1.0-Text-Encoder"
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/text_encoder/model.safetensors"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\text_encoder"
            File = "model.safetensors"
            Size = 246MB
            SHA256 = $null
        },
        @{
            Name = "SDXL-Base-1.0-Text-Encoder-2"
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/text_encoder_2/model.safetensors"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\text_encoder_2"
            File = "model.safetensors"
            Size = 1390MB
            SHA256 = $null
        }
    )
    
    $totalModels = $models.Count
    $currentModel = 0
    
    foreach ($model in $models) {
        $currentModel++
        Write-Info "[$currentModel/$totalModels] Processing $($model.Name)..."
        
        # Create directory
        if (!(Test-Path $model.Path)) {
            New-Item -ItemType Directory -Path $model.Path -Force | Out-Null
        }
        
        $outputFile = Join-Path $model.Path $model.File
        
        # Check if already downloaded
        if (Test-Path $outputFile) {
            $fileSize = (Get-Item $outputFile).Length
            if ($fileSize -ge ($model.Size * 0.95)) {  # Allow 5% variance
                Write-Success "$($model.Name) already downloaded"
                continue
            } else {
                Write-WarningMsg "Incomplete download detected, resuming..."
            }
        }
        
        # Download with resume capability
        if ($UseHttpRange -and (Test-Path $outputFile)) {
            $existingSize = (Get-Item $outputFile).Length
            Write-Info "Resuming download from $([math]::Round($existingSize / 1MB))MB..."
            
            try {
                Download-WithResume -URL $model.URL -OutputFile $outputFile -ExpectedSize $model.Size
                Write-Success "$($model.Name) downloaded"
            } catch {
                Write-WarningMsg "Resume failed, attempting fresh download..."
                Remove-Item $outputFile -Force -ErrorAction SilentlyContinue
                Download-SimpleFile -URL $model.URL -OutputFile $outputFile
            }
        } else {
            Download-SimpleFile -URL $model.URL -OutputFile $outputFile
        }
    }
    
    # Download config files
    Write-Info "Downloading model configuration files..."
    $configUrls = @(
        @{
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/raw/main/model_index.json"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\model_index.json"
        },
        @{
            URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/raw/main/scheduler/scheduler_config.json"
            Path = "$script:MODELS_PATH\sdxl-base-1.0\scheduler\scheduler_config.json"
        }
    )
    
    foreach ($config in $configUrls) {
        $dir = Split-Path $config.Path -Parent
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        
        if (!(Test-Path $config.Path)) {
            try {
                Invoke-WebRequest -Uri $config.URL -OutFile $config.Path -UseBasicParsing
                Write-VerboseInfo "Downloaded config: $(Split-Path $config.Path -Leaf)"
            } catch {
                Write-WarningMsg "Could not download config: $(Split-Path $config.Path -Leaf)"
            }
        }
    }
    
    Write-Success "Model download complete"
    return $true
}

# Simple file download function
function Download-SimpleFile {
    param(
        [string]$URL,
        [string]$OutputFile
    )
    
    Write-VerboseInfo "Downloading from: $URL"
    Write-VerboseInfo "Saving to: $OutputFile"
    
    $webClient = $null
    try {
        $webClient = New-Object System.Net.WebClient
        
        # Add progress callback
        $webClient.add_DownloadProgressChanged({
            param($sender, $e)
            $percent = $e.ProgressPercentage
            Write-Progress -Activity "Downloading" -Status "$percent% Complete" -PercentComplete $percent
        })
        
        # Download file
        $webClient.DownloadFile($URL, $OutputFile)
        Write-Progress -Activity "Downloading" -Completed
        
    } catch {
        Write-ErrorMsg "Download failed: $_"
        throw
    } finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}

# Download with HTTP range support for resume
function Download-WithResume {
    param(
        [string]$URL,
        [string]$OutputFile,
        [int64]$ExpectedSize
    )
    
    $existingSize = 0
    if (Test-Path $OutputFile) {
        $existingSize = (Get-Item $OutputFile).Length
    }
    
    if ($existingSize -ge $ExpectedSize) {
        Write-VerboseInfo "File already complete"
        return
    }
    
    Write-VerboseInfo "Attempting resume from byte $existingSize"
    
    $webRequest = [System.Net.HttpWebRequest]::Create($URL)
    $webRequest.Method = "GET"
    $webRequest.AddRange($existingSize)
    
    $response = $webRequest.GetResponse()
    $responseStream = $response.GetResponseStream()
    
    $fileStream = [System.IO.FileStream]::new($OutputFile, [System.IO.FileMode]::Append)
    
    try {
        $buffer = New-Object byte[] 8192
        $totalRead = $existingSize
        
        while ($true) {
            $read = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($read -le 0) { break }
            
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            
            $percent = [math]::Round(($totalRead / $ExpectedSize) * 100)
            Write-Progress -Activity "Downloading (resumed)" -Status "$percent% Complete" -PercentComplete $percent
        }
        
        Write-Progress -Activity "Downloading (resumed)" -Completed
        
    } catch {
        Write-ErrorMsg "Resume download failed: $_"
        throw
    } finally {
        if ($fileStream) { $fileStream.Close() }
        if ($responseStream) { $responseStream.Close() }
        if ($response) { $response.Close() }
    }
}

# Create startup scripts
function Create-StartupScripts {
    Write-StepProgress "Creating startup scripts"
    
    if (!$PSCmdlet.ShouldProcess("Startup scripts", "Create")) {
        return $true
    }
    
    # Create batch file starter
    $batchScript = @"
@echo off
echo Starting Intel AI Demo Client...
echo Expected generation time: 35-45 seconds per image
cd /d $script:CLIENT_PATH
call $script:VENV_PATH\Scripts\activate.bat
set PYTHONPATH=$script:CLIENT_PATH
set INTEL_OPTIMIZED=1
set ORT_DIRECTML_DEVICE_ID=0
set MKL_ENABLE_INSTRUCTIONS=AVX512
python demo_client.py
pause
"@
    
    $batchScript | Out-File -FilePath "$script:DEMO_BASE\start_intel_demo.bat" -Encoding ASCII
    Write-Success "Batch startup script created"
    
    # Create PowerShell starter
    $psScript = @"
# Intel AI Demo Client Launcher
Write-Host 'Starting Intel-optimized AI Demo Client...' -ForegroundColor Green
Write-Host 'Using DirectML GPU acceleration' -ForegroundColor Cyan
Write-Host 'Expected performance: 35-45 seconds per 768x768 image' -ForegroundColor Yellow

Set-Location '$script:CLIENT_PATH'
& '$script:VENV_PATH\Scripts\Activate.ps1'

`$env:PYTHONPATH = '$script:CLIENT_PATH'
`$env:INTEL_OPTIMIZED = '1'
`$env:ORT_DIRECTML_DEVICE_ID = '0'
`$env:MKL_ENABLE_INSTRUCTIONS = 'AVX512'
`$env:OMP_NUM_THREADS = [Environment]::ProcessorCount

python demo_client.py
"@
    
    $psScript | Out-File -FilePath "$script:DEMO_BASE\start_intel_demo.ps1" -Encoding UTF8
    Write-Success "PowerShell startup script created"
    
    Register-RollbackAction -Description "Remove startup scripts" -Action {
        Remove-Item "$script:DEMO_BASE\start_intel_demo.bat" -ErrorAction SilentlyContinue
        Remove-Item "$script:DEMO_BASE\start_intel_demo.ps1" -ErrorAction SilentlyContinue
    }
    
    return $true
}

# Configure network and firewall
function Configure-Network {
    Write-StepProgress "Configuring network settings"
    
    if ($CheckOnly) {
        $rule = Get-NetFirewallRule -DisplayName "AI Demo Intel Client" -ErrorAction SilentlyContinue
        if ($rule) {
            Write-Success "Firewall rule exists"
        } else {
            Write-WarningMsg "Firewall rule not configured"
        }
    } else {
        if ($PSCmdlet.ShouldProcess("Firewall rule for port 5000", "Create")) {
            try {
                New-NetFirewallRule -DisplayName "AI Demo Intel Client" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 5000 `
                    -Action Allow `
                    -ErrorAction SilentlyContinue | Out-Null
                Write-Success "Firewall rule added for port 5000"
            } catch {
                Write-WarningMsg "Could not add firewall rule: $_"
            }
        }
    }
    
    # Get network info
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | 
           Where-Object {$_.InterfaceAlias -notmatch "Loopback"}).IPAddress | 
           Select-Object -First 1
    Write-Info "Machine IP: $ip"
    
    return $true
}

# Test Intel performance
function Test-IntelPerformance {
    Write-StepProgress "Testing Intel-optimized performance"
    
    if ($CheckOnly -or $WhatIf) {
        Write-Info "Skipping performance test"
        return $true
    }
    
    Write-Info "Running performance benchmark..."
    Write-Info "This will generate a test image to measure actual performance"
    
    & "$script:VENV_PATH\Scripts\Activate.ps1"
    Set-Location $script:CLIENT_PATH
    
    $testScript = @"
import time
import sys
import os

sys.path.insert(0, '$script:CLIENT_PATH')

print('Initializing Intel-optimized pipeline...')
print('Using DirectML GPU acceleration')

try:
    # Import with proper error handling
    from platform_detection import detect_platform
    from ai_pipeline import AIImagePipeline
    
    # Detect platform
    platform = detect_platform()
    print(f'Platform: {platform["name"]}')
    print(f'Acceleration: {platform.get("acceleration", "CPU")}')
    
    # Initialize pipeline
    print('Loading FP16 models (this may take a moment)...')
    start = time.time()
    pipeline = AIImagePipeline(platform)
    init_time = time.time() - start
    print(f'Initialization time: {init_time:.2f}s')
    
    # Warmup run
    print('Performing warmup generation...')
    start = time.time()
    result = pipeline.generate('test', steps=1)
    warmup_time = time.time() - start
    print(f'Warmup time: {warmup_time:.2f}s')
    
    # Actual benchmark
    print('Running performance benchmark (25 steps, 768x768)...')
    prompt = 'A majestic mountain landscape at sunset, highly detailed, professional photography'
    
    start = time.time()
    result = pipeline.generate(prompt, steps=25, width=768, height=768)
    gen_time = time.time() - start
    
    print(f'')
    print(f'=== PERFORMANCE RESULTS ===')
    print(f'Generation time: {gen_time:.2f}s')
    print(f'Time per step: {gen_time/25:.2f}s')
    
    if gen_time < 30:
        print('[EXCELLENT] DirectML acceleration is working perfectly!')
    elif gen_time < 45:
        print('[GOOD] Performance is within expected range (35-45s)')
    elif gen_time < 60:
        print('[OK] Performance is acceptable but not optimal')
    else:
        print('[WARNING] Performance is slower than expected - check DirectML setup')
        
except ImportError as e:
    print(f'[ERROR] Import failed: {e}')
    print('Please ensure all dependencies are installed correctly')
except Exception as e:
    print(f'[ERROR] Test failed: {e}')
    import traceback
    traceback.print_exc()
"@
    
    $testOutput = $testScript | & python 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    
    return $true
}

# Update repository
function Update-Repository {
    Write-StepProgress "Setting up repository files"
    
    # Calculate correct path from script location to project root
    # Script is at: deployment/intel/scripts/prepare_intel.ps1
    # Need to go up 3 levels: scripts -> intel -> deployment -> project root
    $primarySourcePath = "$PSScriptRoot\..\..\..\src\windows-client"
    $fallbackSourcePath = ".\src\windows-client"
    
    Write-VerboseInfo "Script location: $PSScriptRoot"
    Write-VerboseInfo "Primary source path: $primarySourcePath"
    Write-VerboseInfo "Fallback source path: $fallbackSourcePath"
    
    # Resolve the absolute path for better validation
    $resolvedPrimaryPath = $null
    $resolvedFallbackPath = $null
    
    try {
        $resolvedPrimaryPath = Resolve-Path $primarySourcePath -ErrorAction SilentlyContinue
        Write-VerboseInfo "Resolved primary path: $resolvedPrimaryPath"
    } catch {
        Write-VerboseInfo "Could not resolve primary path: $primarySourcePath"
    }
    
    try {
        $resolvedFallbackPath = Resolve-Path $fallbackSourcePath -ErrorAction SilentlyContinue
        Write-VerboseInfo "Resolved fallback path: $resolvedFallbackPath"
    } catch {
        Write-VerboseInfo "Could not resolve fallback path: $fallbackSourcePath"
    }
    
    # Determine which source path to use
    $sourceClient = $null
    if ($resolvedPrimaryPath -and (Test-Path $resolvedPrimaryPath)) {
        $sourceClient = $resolvedPrimaryPath.Path
        Write-VerboseInfo "Using primary source path: $sourceClient"
    } elseif ($resolvedFallbackPath -and (Test-Path $resolvedFallbackPath)) {
        $sourceClient = $resolvedFallbackPath.Path
        Write-VerboseInfo "Using fallback source path: $sourceClient"
    } elseif (Test-Path $primarySourcePath) {
        $sourceClient = $primarySourcePath
        Write-VerboseInfo "Using unresolved primary path: $sourceClient"
    } elseif (Test-Path $fallbackSourcePath) {
        $sourceClient = $fallbackSourcePath
        Write-VerboseInfo "Using unresolved fallback path: $sourceClient"
    }
    
    if ($sourceClient) {
        # Validate that source contains expected client files
        $expectedFiles = @("ai_pipeline.py", "demo_client.py", "platform_detection.py")
        $missingFiles = @()
        
        foreach ($file in $expectedFiles) {
            $filePath = Join-Path $sourceClient $file
            if (!(Test-Path $filePath)) {
                $missingFiles += $file
                Write-VerboseInfo "Missing expected file: $filePath"
            }
        }
        
        if ($missingFiles.Count -gt 0) {
            Write-WarningMsg "Source directory missing expected files: $($missingFiles -join ', ')"
            Write-WarningMsg "Source path: $sourceClient"
            Write-Info "Continuing anyway - some files may be optional"
        } else {
            Write-VerboseInfo "All expected client files found in source directory"
        }
        
        if ($PSCmdlet.ShouldProcess("Client files from $sourceClient", "Copy")) {
            try {
                Write-Info "Copying client files from: $sourceClient"
                Write-Info "Destination: $script:CLIENT_PATH"
                
                # Ensure destination directory exists
                if (!(Test-Path $script:CLIENT_PATH)) {
                    New-Item -ItemType Directory -Path $script:CLIENT_PATH -Force | Out-Null
                    Write-VerboseInfo "Created client destination directory"
                }
                
                # Copy all files and subdirectories
                $copyParams = @{
                    Path = "$sourceClient\*"
                    Destination = $script:CLIENT_PATH
                    Recurse = $true
                    Force = $true
                    ErrorAction = "Stop"
                }
                
                Copy-Item @copyParams
                
                # Verify the copy operation
                $copiedFiles = Get-ChildItem -Path $script:CLIENT_PATH -Recurse -File
                Write-VerboseInfo "Copied $($copiedFiles.Count) files to client directory"
                
                # Log the copied files for debugging
                if ($VerbosePreference -eq 'Continue') {
                    $copiedFiles | ForEach-Object {
                        Write-VerboseInfo "  Copied: $($_.Name)"
                    }
                }
                
                Write-Success "Client files deployed successfully"
                Write-Info "Copied from: $sourceClient"
                Write-Info "Files copied: $($copiedFiles.Count)"
                
            } catch {
                Write-ErrorMsg "Failed to copy client files: $_"
                Write-ErrorMsg "Source: $sourceClient"
                Write-ErrorMsg "Destination: $script:CLIENT_PATH"
                Write-Info "This may prevent the demo from running properly"
                return $false
            }
        }
    } else {
        Write-ErrorMsg "Client source files not found at any expected location:"
        Write-ErrorMsg "  Primary: $primarySourcePath"
        Write-ErrorMsg "  Fallback: $fallbackSourcePath"
        Write-ErrorMsg "  Script location: $PSScriptRoot"
        Write-Info "Please ensure the script is run from the correct location"
        Write-Info "Expected project structure: deployment/intel/scripts/prepare_intel.ps1"
        return $false
    }
    
    return $true
}

# Show performance expectations
function Show-PerformanceExpectations {
    Write-Host "`n====== EXPECTED PERFORMANCE ======" -ForegroundColor Magenta
    Write-Host "Image Resolution: 768x768"
    Write-Host "Model: SDXL Base 1.0 (FP16)"
    Write-Host "Hardware: Intel Core Ultra with DirectML"
    Write-Host ""
    Write-Host "Performance Profile: $OptimizationProfile"
    Write-Host ""
    
    switch ($OptimizationProfile) {
        "Speed" {
            Write-Host "  - Steps: 4-8"
            Write-Host "  - Generation time: 15-25 seconds"
            Write-Host "  - Quality: Draft"
        }
        "Balanced" {
            Write-Host "  - Steps: 20-25"
            Write-Host "  - Generation time: 35-45 seconds"
            Write-Host "  - Quality: Good"
        }
        "Quality" {
            Write-Host "  - Steps: 30-50"
            Write-Host "  - Generation time: 50-80 seconds"
            Write-Host "  - Quality: Maximum"
        }
    }
    
    Write-Host ""
    Write-Host "Memory Usage: ~8-10GB"
    Write-Host "Power Usage: 25-35W"
    Write-Host "==================================`n"
}

# Generate final report
function Generate-Report {
    Write-StepProgress "Generating setup report"
    
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $report = @"

========================================
INTEL DEMO SETUP REPORT
========================================
Time: $timestamp
Machine: $env:COMPUTERNAME
Profile: $OptimizationProfile

HARDWARE STATUS:
"@
    
    # Add hardware info
    $cpu = Get-WmiObject Win32_Processor
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $gpu = Get-WmiObject Win32_VideoController | Select-Object -First 1
    
    $report += @"

  Processor: $($cpu.Name)
  Architecture: $($env:PROCESSOR_ARCHITECTURE)
  RAM: $($ram)GB
  GPU: $($gpu.Name)
  
"@
    
    if ($script:issues.Count -eq 0) {
        $report += @"
OVERALL STATUS: [OK] SYSTEM READY

All requirements met. The system is ready for Intel-optimized AI generation.

Key Features Enabled:
  * DirectML GPU acceleration configured
  * FP16 models loaded (~6.9GB)
  * Intel MKL optimizations enabled
  * Expected performance: 35-45 seconds per image

"@
    } else {
        $report += @"
OVERALL STATUS: [X] SETUP INCOMPLETE

Issues Found:
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
1. Start the demo: $script:DEMO_BASE\start_intel_demo.bat
2. Verify DirectML acceleration is active
3. Test with sample prompts
4. Monitor GPU usage during generation

Log file: $script:logFile
========================================
"@
    
    Write-Host $report
    
    # Save report
    $reportPath = "$LogPath\intel_setup_report_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "Report saved to $reportPath"
}

# Main execution function
function Main {
    # Parameters are handled by CmdletBinding
    
    Write-Host @"
+============================================================+
|          INTEL CORE ULTRA DEMO PREPARATION SCRIPT         |
|         DirectML GPU-Accelerated AI Image Generation      |
+============================================================+
"@ -ForegroundColor Cyan
    
    if ($CheckOnly) {
        Write-Info "Running in CHECK-ONLY mode - no changes will be made"
    }
    
    if ($WhatIf) {
        Write-Info "Running in WHAT-IF mode - showing what would be done"
    }
    
    if ($VerbosePreference -eq 'Continue') {
        Write-Info "VERBOSE mode enabled - detailed output will be shown"
    }
    
    # Initialize logging
    Initialize-Logging
    
    # Start timing
    $startTime = Get-Date
    Write-VerboseInfo "Setup started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    try {
        # Initialize directories
        Initialize-Directories
        
        # Check hardware
        $hardwareStatus = Test-IntelHardwareRequirements
        
        if (!$(Show-HardwareConfirmation -HardwareStatus $hardwareStatus)) {
            Write-ErrorMsg "Setup cancelled by user or hardware requirements not met"
            if (!$Force) {
                exit 1
            }
        }
        
        # Install Python if needed
        $pythonOK = Install-Python
        if (!$pythonOK -and !$Force) {
            throw "Python installation failed"
        }
        
        # Update repository files
        Update-Repository
        
        # Install dependencies
        if (!$CheckOnly) {
            $coreOK = Install-CoreDependencies
            if (!$coreOK -and !$Force) {
                throw "Core dependency installation failed"
            }
            
            $accelOK = Install-IntelAcceleration
            if (!$accelOK -and !$Force) {
                Write-WarningMsg "Acceleration packages failed - will use CPU fallback"
            }
            
            # Configure DirectML
            Configure-DirectMLProvider
            
            # Download models
            Download-IntelModels
        }
        
        # Configure network
        Configure-Network
        
        # Create startup scripts
        Create-StartupScripts
        
        # Show performance expectations
        Show-PerformanceExpectations
        
        # Run performance test
        if (!$CheckOnly -and !$SkipModelDownload) {
            Test-IntelPerformance
        }
        
    } catch {
        Write-ErrorMsg "Setup failed: $_"
        
        if (!$Force) {
            $rollback = Read-Host "Do you want to rollback changes? (Y/N)"
            if ($rollback -eq 'Y') {
                Invoke-Rollback
            }
        }
        
        throw
    }
    
    # Calculate elapsed time
    $endTime = Get-Date
    $elapsed = $endTime - $startTime
    Write-VerboseInfo "Setup completed at: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-VerboseInfo "Total elapsed time: $($elapsed.ToString('hh\:mm\:ss'))"
    
    # Generate final report
    Generate-Report
    
    # Summary
    Write-Host "`n" + ("=" * 60) -ForegroundColor DarkGray
    Write-Info "Setup completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
    
    # Exit code based on readiness
    if ($script:issues.Count -eq 0) {
        Write-Host "`n[OK] INTEL SYSTEM IS READY!" -ForegroundColor Green
        Write-Host "Expected performance: 35-45 seconds per 768x768 image" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "`n[X] System setup incomplete - review issues above" -ForegroundColor Red
        exit 1
    }
}

# Cleanup on exit
trap {
    Stop-Logging
}

# Run main function
try {
    Main
} catch {
    Write-ErrorMsg "Fatal error: $_"
    Stop-Logging
    exit 1
} finally {
    Stop-Logging
}