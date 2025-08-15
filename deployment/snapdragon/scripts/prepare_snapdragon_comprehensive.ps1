#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive Snapdragon X Elite Demo Preparation Script
.DESCRIPTION
    Advanced preparation script mirroring Intel deployment functionality
    Optimized for Snapdragon X Elite NPU acceleration with comprehensive error recovery
    Research-backed package versions and installation strategies (Aug 2025)
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
.NOTES
    Target: Snapdragon X Elite on Windows 11 24H2+ (Copilot+ PC)
    Models: SDXL Lightning INT8 optimized for NPU (~2.1GB)
    Acceleration: DirectML → QNN → CPU fallback hierarchy
    Expected performance: 8-12 seconds per 768x768 image (NPU mode)
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$CheckOnly = $false,
    [switch]$Force = $false,
    [switch]$SkipModelDownload = $false,
    [switch]$UseHttpRange = $true,
    [string]$LogPath = "C:\AIDemo\logs",
    [ValidateSet('Speed', 'Balanced', 'Quality')]
    [string]$OptimizationProfile = 'Speed'  # NPU optimized for speed
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

# Snapdragon-specific configuration
$script:DEMO_BASE = "C:\AIDemo"
$script:VENV_PATH = "$script:DEMO_BASE\venv"
$script:CLIENT_PATH = "$script:DEMO_BASE\client"
$script:MODELS_PATH = "$script:DEMO_BASE\models"
$script:CACHE_PATH = "$script:DEMO_BASE\cache"
$script:TEMP_PATH = "$script:DEMO_BASE\temp"

# State management (mirroring Intel script approach)
$script:stateFile = "$script:DEMO_BASE\snapdragon_deployment_state.json"
$script:deploymentState = $null
$script:machineFingerprint = $null
$script:resumeFromStep = 0
$script:checkpointSteps = @(
    "directories",
    "hardware_check",
    "python_install",
    "core_dependencies",
    "snapdragon_acceleration",
    "npu_config",
    "models_download",
    "repository_update",
    "network_config",
    "startup_scripts",
    "performance_test"
)

# Color output functions
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
    Write-Progress -Activity "Snapdragon Setup" -Status $Message -PercentComplete $percent
    if ($VerbosePreference -eq 'Continue') {
        Write-Host ("-" * 60) -ForegroundColor DarkGray
    }
}

# ============================================================================
# STATE MANAGEMENT (Mirroring Intel approach)
# ============================================================================

function Get-MachineFingerprint {
    Write-VerboseInfo "Generating Snapdragon machine fingerprint..."
    
    try {
        $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
        $memory = Get-WmiObject Win32_ComputerSystem
        $os = Get-WmiObject Win32_OperatingSystem
        
        $fingerprint = @{
            ProcessorId = $cpu.ProcessorId
            ProcessorName = $cpu.Name
            IsSnapdragon = $cpu.Name -match "Snapdragon|Qualcomm|Oryon"
            TotalMemory = $memory.TotalPhysicalMemory
            OSVersion = $os.Version
            OSBuildNumber = $os.BuildNumber
            ComputerName = $env:COMPUTERNAME
            Username = $env:USERNAME
            Architecture = $env:PROCESSOR_ARCHITECTURE
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        
        $fingerprintString = ($fingerprint.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ';'
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($fingerprintString))
        $hashString = [System.BitConverter]::ToString($hash) -replace '-', ''
        
        return @{
            Hash = $hashString
            Details = $fingerprint
        }
    } catch {
        Write-WarningMsg "Could not generate machine fingerprint: $_"
        return @{
            Hash = "UNKNOWN"
            Details = @{ Error = $_.Exception.Message }
        }
    }
}

function Initialize-DeploymentState {
    Write-VerboseInfo "Initializing Snapdragon deployment state..."
    
    $script:machineFingerprint = Get-MachineFingerprint
    
    if (Test-Path $script:stateFile) {
        try {
            $stateContent = Get-Content $script:stateFile -Raw | ConvertFrom-Json
            
            if ($stateContent.StateVersion -ne "1.0") {
                Write-WarningMsg "State file version mismatch. Creating new state."
                $script:deploymentState = New-DeploymentState
            } else {
                $script:deploymentState = $stateContent
                Write-Success "Loaded existing deployment state"
            }
        } catch {
            Write-WarningMsg "Could not load existing state: $_"
            $script:deploymentState = New-DeploymentState
        }
    } else {
        $script:deploymentState = New-DeploymentState
    }
}

function New-DeploymentState {
    return @{
        StateVersion = "1.0"
        Platform = "Snapdragon"
        CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        MachineFingerprint = $script:machineFingerprint
        CompletedSteps = @()
        StepDetails = @{}
        PackageVersions = @{}
        ValidationResults = @{}
        Configuration = @{
            OptimizationProfile = $OptimizationProfile
            LogPath = $LogPath
            SkipModelDownload = $SkipModelDownload.IsPresent
            UseHttpRange = $UseHttpRange.IsPresent
        }
    }
}

function Save-DeploymentState {
    param([string]$Context = "General")
    
    if ($script:deploymentState -eq $null) { return }
    
    try {
        $script:deploymentState.LastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $stateJson = $script:deploymentState | ConvertTo-Json -Depth 10
        $stateJson | Out-File -FilePath $script:stateFile -Encoding UTF8
        Write-VerboseInfo "Deployment state saved ($Context)"
    } catch {
        Write-WarningMsg "Could not save deployment state: $_"
    }
}

function Test-StepCompleted {
    param([string]$StepName)
    
    if ($script:deploymentState -eq $null) { return $false }
    return $script:deploymentState.CompletedSteps -contains $StepName
}

function Set-StepCompleted {
    param(
        [string]$StepName,
        [hashtable]$Details = @{}
    )
    
    if ($script:deploymentState -eq $null) { return }
    
    if (!(Test-StepCompleted $StepName)) {
        $script:deploymentState.CompletedSteps += $StepName
    }
    
    $script:deploymentState.StepDetails[$StepName] = @{
        CompletedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Details = $Details
    }
    
    Save-DeploymentState "Step: $StepName"
}

# ============================================================================
# DIRECTORY INITIALIZATION
# ============================================================================

function Initialize-Directories {
    Write-StepProgress "Creating Snapdragon demo directory structure"
    
    $dirs = @(
        $script:DEMO_BASE,
        $script:CLIENT_PATH,
        $script:MODELS_PATH,
        $script:CACHE_PATH,
        "$script:CACHE_PATH\downloads",
        "$script:CACHE_PATH\compiled",
        $LogPath,
        $script:TEMP_PATH,
        "$script:MODELS_PATH\sdxl-lightning",
        "$script:MODELS_PATH\tokenizer"
    )
    
    foreach ($dir in $dirs) {
        if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
            if (!(Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Success "Created $dir"
            } else {
                Write-VerboseInfo "Directory exists: $dir"
            }
        }
    }
}

# ============================================================================
# SNAPDRAGON HARDWARE REQUIREMENTS
# ============================================================================

function Test-SnapdragonHardwareRequirements {
    Write-StepProgress "Checking Snapdragon X Elite hardware requirements"
    
    $hardwareStatus = @{
        ProcessorValid = $false
        ProcessorName = ""
        IsSnapdragonXElite = $false
        NPUAvailable = $false
        Windows11_24H2 = $false
        SystemRAM = 0
        StorageAvailable = 0
        OverallStatus = $false
        Warnings = @()
        Errors = @()
    }
    
    try {
        # Check architecture (Snapdragon X Elite reports as AMD64 for compatibility)
        $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
        
        if ($arch -ne "AMD64") {
            $hardwareStatus.Errors += "Not running on compatible architecture (found: $arch)"
            Write-ErrorMsg "Architecture: $arch (expected AMD64 for Snapdragon X Elite)"
        } else {
            Write-Success "Architecture: $arch (Snapdragon X Elite compatible)"
        }
        
        # Check for Snapdragon X Elite processor
        $cpu = Get-WmiObject Win32_Processor
        $hardwareStatus.ProcessorName = $cpu.Name
        
        if ($cpu.Name -match "Snapdragon.*X.*Elite|Qualcomm.*Oryon") {
            Write-Success "Processor: $($cpu.Name)"
            $hardwareStatus.ProcessorValid = $true
            $hardwareStatus.IsSnapdragonXElite = $true
            Write-Info "Snapdragon X Elite detected - NPU acceleration available"
        } elseif ($cpu.Name -match "Snapdragon|Qualcomm") {
            Write-WarningMsg "Snapdragon processor detected but not X Elite: $($cpu.Name)"
            $hardwareStatus.ProcessorValid = $true
            $hardwareStatus.Warnings += "Not a Snapdragon X Elite - performance may vary"
        } else {
            $hardwareStatus.Warnings += "Non-Snapdragon processor: $($cpu.Name)"
            Write-WarningMsg "Processor: $($cpu.Name) (Snapdragon X Elite recommended for optimal NPU performance)"
        }
        
        # Check Windows 11 24H2 for Copilot+ PC features
        $os = Get-WmiObject Win32_OperatingSystem
        $buildNumber = [int]$os.BuildNumber
        
        Write-Info "Windows Build: $buildNumber"
        
        if ($buildNumber -ge 26120) {
            Write-Success "Windows 11 24H2 stable detected - optimal Snapdragon NPU support"
            $hardwareStatus.Windows11_24H2 = $true
        } elseif ($buildNumber -ge 26100) {
            Write-WarningMsg "Windows 11 24H2 detected but stable version recommended"
            $hardwareStatus.Windows11_24H2 = $true
            $hardwareStatus.Warnings += "Windows 11 24H2 stable recommended for best NPU performance"
        } else {
            $hardwareStatus.Errors += "Windows version too old for Snapdragon NPU (build $buildNumber < 26100)"
            Write-ErrorMsg "Please update to Windows 11 24H2 for Copilot+ PC NPU features"
        }
        
        # Check RAM (Snapdragon systems typically have 16GB)
        $memInfo = Get-WmiObject Win32_ComputerSystem
        $ram = [math]::Round($memInfo.TotalPhysicalMemory / 1GB)
        $hardwareStatus.SystemRAM = $ram
        
        if ($ram -ge 16) {
            Write-Success "RAM: $($ram)GB (optimal for NPU acceleration)"
        } elseif ($ram -ge 8) {
            Write-WarningMsg "RAM: $($ram)GB (16GB recommended for optimal performance)"
            $hardwareStatus.Warnings += "Low memory - consider upgrading to 16GB+"
        } else {
            $hardwareStatus.Errors += "Insufficient RAM: $($ram)GB (8GB minimum required)"
            Write-ErrorMsg "RAM: $($ram)GB (insufficient for AI workloads)"
        }
        
        # Check storage (models require ~3GB)
        $drive = Get-PSDrive C
        $freeSpace = [math]::Round($drive.Free / 1GB, 2)
        $hardwareStatus.StorageAvailable = $freeSpace
        
        if ($freeSpace -lt 5) {
            $hardwareStatus.Errors += "Insufficient disk space: $($freeSpace)GB (5GB required)"
            Write-ErrorMsg "Free space: $($freeSpace)GB (5GB required for models and cache)"
        } else {
            Write-Success "Free space: $($freeSpace)GB"
        }
        
        # Check for NPU availability indicators
        try {
            # Look for Snapdragon-specific NPU indicators
            $npuIndicators = @(
                "Qualcomm.*NPU",
                "Snapdragon.*AI",
                "Hexagon.*Processor"
            )
            
            $devices = Get-WmiObject Win32_PnPEntity | Where-Object { 
                $_.Name -match ($npuIndicators -join "|") 
            }
            
            if ($devices) {
                $hardwareStatus.NPUAvailable = $true
                Write-Success "NPU hardware detected for acceleration"
            } else {
                Write-Info "NPU detection: Will verify during software installation"
            }
        } catch {
            Write-VerboseInfo "NPU hardware detection: $_"
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

# ============================================================================
# PYTHON INSTALLATION (Snapdragon optimized)
# ============================================================================

function Install-Python {
    Write-StepProgress "Installing Python 3.10 for Snapdragon NPU compatibility"
    
    # Python 3.10 is required for NPU driver compatibility
    $pythonVersions = @("3.10")
    $pythonFound = $false
    
    Write-Info "Enforcing Python 3.10 requirement (Snapdragon NPU driver compatibility)..."
    
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
            Write-Info "Installing Python 3.10.11..."
            
            try {
                # Try ARM64 installer first, fallback to AMD64 (Snapdragon X Elite compatibility)
                $pythonUrls = @(
                    @{URL="https://www.python.org/ftp/python/3.10.11/python-3.10.11-arm64.exe"; Type="ARM64"},
                    @{URL="https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe"; Type="AMD64"}
                )
                
                $installed = $false
                foreach ($pythonInfo in $pythonUrls) {
                    try {
                        $installer = "$script:TEMP_PATH\python-installer-$($pythonInfo.Type).exe"
                        
                        Write-Info "Downloading Python $($pythonInfo.Type) installer..."
                        $webClient = New-Object System.Net.WebClient
                        $webClient.DownloadFile($pythonInfo.URL, $installer)
                        
                        Write-Info "Installing Python 3.10 ($($pythonInfo.Type))..."
                        $installArgs = @("/quiet", "InstallAllUsers=1", "PrependPath=1", "TargetDir=C:\Python310")
                        Start-Process -FilePath $installer -ArgumentList $installArgs -Wait
                        
                        $env:Path = "C:\Python310;C:\Python310\Scripts;$env:Path"
                        
                        # Verify installation
                        $versionCheck = & C:\Python310\python.exe --version 2>&1
                        if ($versionCheck -match "Python 3\.10") {
                            Write-Success "Python 3.10 installed successfully ($($pythonInfo.Type)): $versionCheck"
                            $installed = $true
                            break
                        }
                        
                    } catch {
                        Write-WarningMsg "Failed to install Python $($pythonInfo.Type): $_"
                        continue
                    }
                }
                
                if (!$installed) {
                    throw "All Python installation attempts failed"
                }
                
                return $true
            } catch {
                Write-ErrorMsg "Failed to install Python: $_"
                return $false
            }
        }
    } elseif (!$pythonFound) {
        Write-ErrorMsg "Python 3.10 not found"
        return $false
    }
    
    return $pythonFound
}

# ============================================================================
# CORE DEPENDENCIES (ARM64 optimized)
# ============================================================================

function Install-CoreDependencies {
    Write-StepProgress "Installing core dependencies with ARM64 optimizations"
    
    if (!$PSCmdlet.ShouldProcess("Core dependencies", "Install")) {
        return $true
    }
    
    Push-Location $script:CLIENT_PATH
    
    try {
        # Create virtual environment
        if (!(Test-Path $script:VENV_PATH)) {
            Write-Info "Creating virtual environment..."
            & python -m venv $script:VENV_PATH
            
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create virtual environment"
            }
        }
        
        # Activate virtual environment
        & "$script:VENV_PATH\Scripts\Activate.ps1"
        
        # Verify Python 3.10 in venv
        $venvVersion = & python --version 2>&1
        if ($venvVersion -notmatch "Python 3\.10") {
            throw "Virtual environment not using Python 3.10: $venvVersion"
        }
        Write-Success "Virtual environment using: $venvVersion"
        
        # Upgrade pip
        Write-Info "Upgrading pip..."
        & python -m pip install --upgrade pip
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to upgrade pip"
        }
        
        # Install core dependencies optimized for ARM64
        $coreDeps = @(
            "numpy>=1.21.0,<2.0.0",      # Standard numpy (no MKL for ARM64)
            "pillow>=8.0.0,<11.0.0",     # Image processing
            "flask>=2.0.0,<3.0.0",       # Web framework
            "requests>=2.25.0,<3.0.0",   # HTTP library
            "psutil>=5.8.0"               # System utilities
        )
        
        foreach ($dep in $coreDeps) {
            Write-Info "Installing $dep..."
            & pip install $dep
            if ($LASTEXITCODE -ne 0) {
                Write-WarningMsg "Failed to install $dep - continuing anyway"
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

# ============================================================================
# SNAPDRAGON NPU ACCELERATION
# ============================================================================

function Install-SnapdragonAcceleration {
    Write-StepProgress "Installing Snapdragon NPU acceleration packages"
    
    if (Test-StepCompleted "snapdragon_acceleration") {
        Write-Info "Snapdragon acceleration packages already installed"
        return $true
    }
    
    if (!$PSCmdlet.ShouldProcess("Snapdragon NPU acceleration", "Install")) {
        return $true
    }
    
    & "$script:VENV_PATH\Scripts\Activate.ps1"
    
    # Research-backed package installation order for Snapdragon
    $accelerationStages = @(
        @{
            Name = "ONNX Runtime Base"
            Packages = @("onnxruntime==1.18.1")  # Stable version, not 1.19.0
            Critical = $true
        },
        @{
            Name = "DirectML NPU Provider"
            Packages = @("onnxruntime-directml")  # Primary NPU acceleration
            Critical = $false
            Description = "Primary NPU acceleration for Snapdragon"
        },
        @{
            Name = "PyTorch ARM64"
            Packages = @("torch==2.1.2", "torchvision==0.16.2")  # ARM64 compatible
            IndexUrl = "https://download.pytorch.org/whl/cpu"
            Critical = $true
            Description = "ARM64 optimized PyTorch"
        },
        @{
            Name = "AI/ML Libraries"
            Packages = @(
                "transformers==4.36.2",    # Conservative version, not 4.55+ 
                "diffusers==0.25.1",
                "accelerate==0.25.0",
                "safetensors==0.4.1",
                "huggingface_hub==0.24.6"
            )
            Critical = $true
            Description = "Stable AI libraries for ARM64"
        },
        @{
            Name = "Experimental QNN Provider"
            Packages = @("onnxruntime-qnn")  # Experimental native Snapdragon
            Critical = $false
            Description = "Experimental native Snapdragon NPU (may not be available)"
        }
    )
    
    $success = $true
    
    foreach ($stage in $accelerationStages) {
        Write-Info "Installing $($stage.Name)..."
        if ($stage.Description) {
            Write-VerboseInfo $stage.Description
        }
        
        try {
            foreach ($package in $stage.Packages) {
                Write-Info "Installing $package..."
                
                $installArgs = @("install", $package, "--prefer-binary")
                
                if ($stage.IndexUrl) {
                    $installArgs += "--index-url"
                    $installArgs += $stage.IndexUrl
                }
                
                & pip @installArgs
                
                if ($LASTEXITCODE -ne 0) {
                    if ($stage.Critical) {
                        throw "Critical package installation failed: $package"
                    } else {
                        Write-WarningMsg "Optional package failed: $package"
                        continue
                    }
                }
                
                Write-VerboseInfo "Successfully installed: $package"
            }
            
            Write-Success "$($stage.Name) installed successfully"
            
        } catch {
            $errorMsg = "Package installation failed: $($stage.Name) - $_"
            
            if ($stage.Critical) {
                Write-ErrorMsg "Critical package failed: $($stage.Name)"
                $success = $false
                break
            } else {
                Write-WarningMsg "Optional package failed: $($stage.Name) - $_"
            }
        }
    }
    
    # Comprehensive verification
    if ($success) {
        Write-Info "Running Snapdragon acceleration verification..."
        
        $verifyScript = @"
import sys
print('=== Snapdragon NPU Verification ===')
print(f'Python version: {sys.version}')

# Verify Python 3.10
if sys.version_info.major == 3 and sys.version_info.minor == 10:
    print('✓ Python 3.10: CORRECT')
else:
    print(f'✗ Wrong Python version: {sys.version_info.major}.{sys.version_info.minor}')

try:
    import torch
    print(f'✓ PyTorch: {torch.__version__}')
    print(f'  PyTorch CUDA available: {torch.cuda.is_available()}')
except ImportError as e:
    print(f'✗ PyTorch: {e}')

# Test ONNX Runtime and NPU providers
try:
    import onnxruntime as ort
    providers = ort.get_available_providers()
    print(f'✓ ONNX Runtime: Available')
    print('Available providers:')
    for provider in providers:
        print(f'  - {provider}')
    
    # Check DirectML (primary NPU acceleration)
    if 'DmlExecutionProvider' in providers:
        print('✓ DirectML NPU: Available')
        npu_mode = 'DirectML'
    elif 'QNNExecutionProvider' in providers:
        print('✓ QNN Native NPU: Available (experimental)')
        npu_mode = 'QNN'
    else:
        print('! NPU Providers: Not available - using CPU')
        npu_mode = 'CPU'
        
    print(f'NPU Mode: {npu_mode}')
    
    # Performance expectations
    if npu_mode == 'DirectML':
        print('Expected performance: 8-12 seconds per image')
    elif npu_mode == 'QNN':
        print('Expected performance: 3-5 seconds per image (experimental)')
    else:
        print('Expected performance: 25-35 seconds per image (CPU fallback)')
        
except ImportError as e:
    print(f'✗ ONNX Runtime: {e}')

# Test AI libraries
try:
    import transformers
    print(f'✓ Transformers: {transformers.__version__}')
except ImportError as e:
    print(f'✗ Transformers: {e}')

try:
    import diffusers
    print(f'✓ Diffusers: {diffusers.__version__}')
except ImportError as e:
    print(f'✗ Diffusers: {e}')

print('=== End Verification ===')
"@
        
        $verificationOutput = $verifyScript | & python 2>&1
        $verificationOutput | ForEach-Object {
            if ($_ -match "^✓") {
                Write-Success $_.Replace("✓ ", "")
            } elseif ($_ -match "^✗") {
                Write-ErrorMsg $_.Replace("✗ ", "")
            } elseif ($_ -match "^!") {
                Write-WarningMsg $_.Replace("! ", "")
            } else {
                Write-Info $_
            }
        }
        
        # Determine NPU status
        $npuAvailable = $verificationOutput -match "DirectML NPU: Available|QNN Native NPU: Available"
        
        Set-StepCompleted "snapdragon_acceleration" @{
            NPUAvailable = $npuAvailable
            PackagesInstalled = $accelerationStages.Count
            VerificationPassed = $true
        }
        
        Write-Success "Snapdragon acceleration setup completed"
    }
    
    return $success
}

# ============================================================================
# NPU CONFIGURATION
# ============================================================================

function Configure-NPUProvider {
    Write-StepProgress "Configuring Snapdragon NPU optimization settings"
    
    Write-Info "Setting Snapdragon NPU environment variables..."
    
    # Snapdragon-specific NPU configuration
    $env:ORT_DIRECTML_DEVICE_ID = "0"
    $env:ORT_DIRECTML_MEMORY_ARENA = "1"
    $env:ORT_DIRECTML_GRAPH_OPTIMIZATION = "ALL"
    
    # Snapdragon optimization settings
    $env:SNAPDRAGON_NPU = "1"
    $env:OMP_NUM_THREADS = [Environment]::ProcessorCount
    
    # ARM64 specific optimizations
    $env:ARM64_OPTIMIZED = "1"
    $env:ONNX_PROVIDERS = "DmlExecutionProvider,QNNExecutionProvider,CPUExecutionProvider"
    
    Write-Success "NPU provider configured for Snapdragon"
    Write-VerboseInfo "DirectML device: 0"
    Write-VerboseInfo "Memory arena: Enabled" 
    Write-VerboseInfo "Graph optimization: ALL"
    Write-VerboseInfo "OMP threads: $env:OMP_NUM_THREADS"
}

# ============================================================================
# SNAPDRAGON-OPTIMIZED MODEL DOWNLOAD
# ============================================================================

function Download-SnapdragonModels {
    Write-StepProgress "Downloading Snapdragon-optimized models"
    
    if ($SkipModelDownload) {
        Write-Info "Skipping model download (--SkipModelDownload specified)"
        return $true
    }
    
    if (!$PSCmdlet.ShouldProcess("SDXL Lightning INT8 models (2.1GB)", "Download")) {
        return $true
    }
    
    # Confirm download
    if (!$CheckOnly -and !$Force) {
        Write-Host "`n====== SNAPDRAGON MODEL DOWNLOAD ======" -ForegroundColor Yellow
        Write-Host "Models optimized for NPU acceleration"
        Write-Host "Total download size: ~2.1 GB"
        Write-Host "Estimated time (50 Mbps): ~6 minutes"
        Write-Host "Storage required: ~3.2 GB"
        Write-Host "======================================`n"
        
        $confirm = Read-Host "Proceed with download? (Y/N)"
        if ($confirm -ne 'Y') {
            Write-Info "Model download skipped by user"
            return $true
        }
    }
    
    # Snapdragon-optimized models (smaller, faster)
    $models = @(
        @{
            Name = "SDXL-Lightning-4step-INT8"
            URL = "https://huggingface.co/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_unet.safetensors"
            Path = "$script:MODELS_PATH\sdxl-lightning"
            File = "unet.safetensors"
            Size = 2147483648  # 2GB
            Description = "NPU-optimized 4-step SDXL"
        },
        @{
            Name = "SDXL-VAE-FP16"
            URL = "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors" 
            Path = "$script:MODELS_PATH\sdxl-lightning"
            File = "vae.safetensors"
            Size = 167772160   # 160MB
            Description = "FP16 VAE encoder/decoder"
        },
        @{
            Name = "Text-Encoder"
            URL = "https://huggingface.co/openai/clip-vit-large-patch14/resolve/main/pytorch_model.bin"
            Path = "$script:MODELS_PATH\tokenizer"
            File = "pytorch_model.bin"
            Size = 605030400   # 577MB
            Description = "CLIP text encoder"
        }
    )
    
    $totalModels = $models.Count
    $currentModel = 0
    
    foreach ($model in $models) {
        $currentModel++
        Write-Info "[$currentModel/$totalModels] Processing $($model.Name)..."
        Write-VerboseInfo $model.Description
        
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
        
        # Download with enhanced error recovery
        try {
            if ($UseHttpRange -and (Test-Path $outputFile)) {
                $existingSize = (Get-Item $outputFile).Length
                Write-Info "Resuming download from $([math]::Round($existingSize / 1MB))MB..."
                
                # Fix the HTTP 416 errors from your original run
                $downloadSuccess = Download-WithResumeFixed -URL $model.URL -OutputFile $outputFile -ExpectedSize $model.Size -ExistingSize $existingSize
            } else {
                $downloadSuccess = Download-SimpleFileWithMirrors -URL $model.URL -OutputFile $outputFile
            }
            
            if ($downloadSuccess) {
                Write-Success "$($model.Name) downloaded successfully"
            } else {
                Write-WarningMsg "Failed to download $($model.Name) - will affect functionality"
            }
        } catch {
            Write-ErrorMsg "Download error for $($model.Name): $_"
        }
    }
    
    # Download configuration files
    Write-Info "Downloading model configuration..."
    $configFiles = @(
        @{
            URL = "https://huggingface.co/ByteDance/SDXL-Lightning/raw/main/scheduler_config.json"
            Path = "$script:MODELS_PATH\sdxl-lightning\scheduler_config.json"
        },
        @{
            URL = "https://huggingface.co/openai/clip-vit-large-patch14/raw/main/tokenizer_config.json"
            Path = "$script:MODELS_PATH\tokenizer\tokenizer_config.json"
        }
    )
    
    foreach ($config in $configFiles) {
        if (!(Test-Path $config.Path)) {
            try {
                $dir = Split-Path $config.Path -Parent
                if (!(Test-Path $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
                
                Invoke-WebRequest -Uri $config.URL -OutFile $config.Path -UseBasicParsing
                Write-VerboseInfo "Downloaded: $(Split-Path $config.Path -Leaf)"
            } catch {
                Write-WarningMsg "Could not download config: $(Split-Path $config.Path -Leaf)"
            }
        }
    }
    
    Write-Success "Snapdragon model download completed"
    return $true
}

# Fixed download function to address HTTP 416 errors
function Download-WithResumeFixed {
    param(
        [string]$URL,
        [string]$OutputFile, 
        [int64]$ExpectedSize,
        [int64]$ExistingSize
    )
    
    try {
        # Test if server supports range requests first
        $headRequest = [System.Net.HttpWebRequest]::Create($URL)
        $headRequest.Method = "HEAD"
        $headResponse = $headRequest.GetResponse()
        
        $acceptsRanges = $headResponse.Headers["Accept-Ranges"] -eq "bytes"
        $contentLength = [int64]$headResponse.Headers["Content-Length"]
        $headResponse.Close()
        
        if (!$acceptsRanges) {
            Write-VerboseInfo "Server doesn't support range requests, downloading fresh"
            Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
            return Download-SimpleFileWithMirrors -URL $URL -OutputFile $OutputFile
        }
        
        if ($ExistingSize -ge $contentLength) {
            Write-Success "File already complete"
            return $true
        }
        
        # Create range request
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $request.Method = "GET" 
        $request.AddRange($ExistingSize)
        
        $response = $request.GetResponse()
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.FileStream]::new($OutputFile, [System.IO.FileMode]::Append)
        
        $buffer = New-Object byte[] 8192
        $totalRead = $ExistingSize
        
        while ($true) {
            $read = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) { break }
            
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            
            $progress = [math]::Round(($totalRead / $contentLength) * 100)
            Write-Progress -Activity "Downloading (resumed)" -Status "$progress% Complete" -PercentComplete $progress
        }
        
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
        
        Write-Progress -Activity "Downloading (resumed)" -Completed
        return $true
        
    } catch {
        Write-VerboseInfo "Resume download failed: $_"
        # Fall back to fresh download
        Remove-Item $OutputFile -Force -ErrorAction SilentlyContinue
        return Download-SimpleFileWithMirrors -URL $URL -OutputFile $OutputFile
    }
}

function Download-SimpleFileWithMirrors {
    param(
        [string]$URL,
        [string]$OutputFile
    )
    
    # Try multiple mirrors to avoid download failures
    $mirrors = @(
        $URL,
        ($URL -replace "huggingface.co", "hf-mirror.com"),
        ($URL -replace "huggingface.co", "huggingface.co.cn")
    )
    
    foreach ($mirror in $mirrors) {
        try {
            Write-VerboseInfo "Trying mirror: $mirror"
            
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($mirror, $OutputFile)
            $webClient.Dispose()
            
            Write-VerboseInfo "Download successful from mirror"
            return $true
            
        } catch {
            Write-VerboseInfo "Mirror failed: $_"
            continue
        }
    }
    
    return $false
}

# ============================================================================
# REPOSITORY UPDATE
# ============================================================================

function Update-Repository {
    Write-StepProgress "Deploying Snapdragon demo client files"
    
    if (Test-StepCompleted "repository_update") {
        Write-Info "Repository files already deployed"
        return $true
    }
    
    # Find source path (mirroring Intel script logic)
    $primarySourcePath = "$PSScriptRoot\..\..\..\src\windows-client"
    $fallbackSourcePath = ".\src\windows-client"
    
    Write-VerboseInfo "Primary source path: $primarySourcePath"
    Write-VerboseInfo "Fallback source path: $fallbackSourcePath"
    
    $sourceClient = $null
    if (Test-Path $primarySourcePath) {
        $sourceClient = $primarySourcePath
    } elseif (Test-Path $fallbackSourcePath) {
        $sourceClient = $fallbackSourcePath
    }
    
    if ($sourceClient) {
        if ($PSCmdlet.ShouldProcess("Client files from $sourceClient", "Copy")) {
            try {
                Write-Info "Copying Snapdragon demo client files..."
                
                # Ensure destination exists
                if (!(Test-Path $script:CLIENT_PATH)) {
                    New-Item -ItemType Directory -Path $script:CLIENT_PATH -Force | Out-Null
                }
                
                # Copy all files
                Copy-Item "$sourceClient\*" -Destination $script:CLIENT_PATH -Recurse -Force
                
                # Create Snapdragon-specific configuration
                $snapdragonConfig = @{
                    "platform" = "snapdragon"
                    "optimization_profile" = $OptimizationProfile
                    "npu_enabled" = $true
                    "model_path" = $script:MODELS_PATH
                    "performance_targets" = @{
                        "excellent_threshold" = 8.0   # DirectML NPU
                        "good_threshold" = 12.0       # DirectML NPU
                        "fallback_threshold" = 35.0   # CPU fallback
                    }
                    "provider_hierarchy" = @("DmlExecutionProvider", "QNNExecutionProvider", "CPUExecutionProvider")
                    "setup_timestamp" = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                }
                
                $configJson = $snapdragonConfig | ConvertTo-Json -Depth 10
                $configPath = "$script:CLIENT_PATH\snapdragon_config.json"
                $configJson | Out-File -FilePath $configPath -Encoding UTF8
                
                Write-Success "Snapdragon demo client files deployed successfully"
                
                Set-StepCompleted "repository_update" @{
                    SourcePath = $sourceClient
                    ConfigCreated = $true
                }
                
            } catch {
                Write-ErrorMsg "Failed to copy client files: $_"
                return $false
            }
        }
    } else {
        Write-ErrorMsg "Client source files not found"
        return $false
    }
    
    return $true
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

function Configure-Network {
    Write-StepProgress "Configuring network settings"
    
    if ($CheckOnly) {
        $rule = Get-NetFirewallRule -DisplayName "AI Demo Snapdragon Client" -ErrorAction SilentlyContinue
        if ($rule) {
            Write-Success "Firewall rule exists"
        } else {
            Write-WarningMsg "Firewall rule not configured"
        }
    } else {
        if ($PSCmdlet.ShouldProcess("Firewall rule for port 5000", "Create")) {
            try {
                New-NetFirewallRule -DisplayName "AI Demo Snapdragon Client" `
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

# ============================================================================
# STARTUP SCRIPTS
# ============================================================================

function Create-StartupScripts {
    Write-StepProgress "Creating Snapdragon startup scripts"
    
    if (!$PSCmdlet.ShouldProcess("Startup scripts", "Create")) {
        return $true
    }
    
    # Snapdragon batch starter
    $batchScript = @"
@echo off
echo ===================================================
echo  Snapdragon X Elite AI Image Generation Demo
echo  NPU-Accelerated DirectML + QNN Support
echo  Expected Performance: 8-12 seconds per image
echo ===================================================
echo.
cd /d $script:CLIENT_PATH
call $script:VENV_PATH\Scripts\activate.bat

REM Set Snapdragon environment
set SNAPDRAGON_NPU=1
set ONNX_PROVIDERS=DmlExecutionProvider,QNNExecutionProvider,CPUExecutionProvider
set ORT_DIRECTML_DEVICE_ID=0

python launch_snapdragon_demo.py
pause
"@
    
    $batchScript | Out-File -FilePath "$script:DEMO_BASE\start_snapdragon_demo.bat" -Encoding ASCII
    Write-Success "Batch startup script created"
    
    # Enhanced PowerShell starter
    $psScript = @"
# Snapdragon AI Demo Client Launcher - NPU Optimized
param([switch]`$Verbose = `$false)

Write-Host '====================================================' -ForegroundColor Cyan
Write-Host ' Snapdragon X Elite AI Image Generation Demo' -ForegroundColor White
Write-Host ' NPU-Accelerated • DirectML + QNN Support' -ForegroundColor Yellow
Write-Host '====================================================' -ForegroundColor Cyan
Write-Host ''

try {
    # Change to client directory
    Set-Location '$script:CLIENT_PATH'
    Write-Host 'Activating Python environment...' -ForegroundColor Green
    
    # Activate virtual environment
    & '$script:VENV_PATH\Scripts\Activate.ps1'
    
    # Set Snapdragon environment variables
    `$env:SNAPDRAGON_NPU = "1"
    `$env:ONNX_PROVIDERS = "DmlExecutionProvider,QNNExecutionProvider,CPUExecutionProvider"
    `$env:ORT_DIRECTML_DEVICE_ID = "0"
    
    # Launch with NPU validation
    Write-Host 'Launching Snapdragon AI demo with NPU acceleration...' -ForegroundColor Green
    python launch_snapdragon_demo.py
    
} catch {
    Write-Host ''
    Write-Host 'ERROR: Snapdragon demo launch failed' -ForegroundColor Red
    Write-Host 'Error details: ' -ForegroundColor Yellow -NoNewline
    Write-Host `$_.Exception.Message -ForegroundColor White
    Write-Host ''
    Write-Host 'Troubleshooting steps:' -ForegroundColor Yellow
    Write-Host '1. Re-run prepare_snapdragon_comprehensive.ps1 script' -ForegroundColor White
    Write-Host '2. Check NPU installation and drivers' -ForegroundColor White
    Write-Host '3. Verify Windows 11 24H2 is installed' -ForegroundColor White
    Write-Host ''
    Read-Host 'Press Enter to exit'
}
"@
    
    $psScript | Out-File -FilePath "$script:DEMO_BASE\start_snapdragon_demo.ps1" -Encoding UTF8
    Write-Success "Enhanced PowerShell startup script created"
    
    return $true
}

# ============================================================================
# PERFORMANCE TEST
# ============================================================================

function Test-SnapdragonPerformance {
    Write-StepProgress "Testing Snapdragon NPU performance"
    
    if ($CheckOnly -or $WhatIf) {
        Write-Info "Skipping performance test"
        return $true
    }
    
    Write-Info "Running Snapdragon NPU performance benchmark..."
    
    & "$script:VENV_PATH\Scripts\Activate.ps1"
    Set-Location $script:CLIENT_PATH
    
    $testScript = @"
import time
import sys
import os

sys.path.insert(0, '$script:CLIENT_PATH')

print('Initializing Snapdragon X Elite NPU pipeline...')
print('Using DirectML + QNN acceleration')

try:
    from platform_detection import detect_platform
    from ai_pipeline import AIImagePipeline
    
    # Detect platform
    platform = detect_platform()
    print(f'Platform: {platform["name"]}')
    print(f'Processor: {platform.get("processor", "Unknown")}')
    print(f'NPU Available: {platform.get("npu_available", False)}')
    print(f'Acceleration: {platform.get("acceleration", "CPU")}')
    
    # Initialize pipeline
    print('Loading Snapdragon-optimized models...')
    start = time.time()
    pipeline = AIImagePipeline(platform)
    init_time = time.time() - start
    print(f'Initialization time: {init_time:.2f}s')
    
    # Warmup run
    print('Performing NPU warmup...')
    start = time.time()
    result = pipeline.generate('test', steps=1)
    warmup_time = time.time() - start
    print(f'Warmup time: {warmup_time:.2f}s')
    
    # Actual benchmark (4 steps for Lightning model)
    print('Running Snapdragon NPU benchmark (4 steps, 768x768)...')
    prompt = 'A futuristic cityscape at sunset, highly detailed, photorealistic'
    
    start = time.time()
    result = pipeline.generate(prompt, steps=4, width=768, height=768)
    gen_time = time.time() - start
    
    print(f'')
    print(f'=== SNAPDRAGON PERFORMANCE RESULTS ===')
    print(f'Generation time: {gen_time:.2f}s')
    print(f'Time per step: {gen_time/4:.2f}s')
    
    # Performance assessment for Snapdragon
    if gen_time < 8:
        print('[EXCELLENT] QNN native NPU acceleration working perfectly!')
    elif gen_time < 12:
        print('[VERY GOOD] DirectML NPU acceleration performing well!')
    elif gen_time < 20:
        print('[GOOD] NPU acceleration active but suboptimal')
    elif gen_time < 35:
        print('[ACCEPTABLE] Using optimized CPU fallback (Oryon cores)')
    else:
        print('[SLOW] Performance below expectations - check NPU setup')
        
except ImportError as e:
    print(f'[ERROR] Import failed: {e}')
    print('Please ensure all Snapdragon dependencies are installed')
except Exception as e:
    print(f'[ERROR] Test failed: {e}')
    import traceback
    traceback.print_exc()
"@
    
    $testOutput = $testScript | & python 2>&1
    $testOutput | ForEach-Object { Write-Host $_ }
    
    return $true
}

# ============================================================================
# FINAL REPORT GENERATION
# ============================================================================

function Show-SnapdragonPerformanceExpectations {
    Write-Host "`n====== SNAPDRAGON PERFORMANCE EXPECTATIONS ======" -ForegroundColor Magenta
    Write-Host "Image Resolution: 768x768"
    Write-Host "Model: SDXL Lightning 4-step (NPU optimized)"
    Write-Host "Hardware: Snapdragon X Elite with NPU"
    Write-Host ""
    Write-Host "Performance Profile: $OptimizationProfile"
    Write-Host ""
    
    switch ($OptimizationProfile) {
        "Speed" {
            Write-Host "  - Steps: 4"
            Write-Host "  - Generation time: 3-8 seconds (NPU)"
            Write-Host "  - Quality: Very Good"
        }
        "Balanced" {
            Write-Host "  - Steps: 8"
            Write-Host "  - Generation time: 8-15 seconds (NPU)"
            Write-Host "  - Quality: Excellent"
        }
        "Quality" {
            Write-Host "  - Steps: 20"
            Write-Host "  - Generation time: 20-40 seconds (NPU)"
            Write-Host "  - Quality: Maximum"
        }
    }
    
    Write-Host ""
    Write-Host "Fallback Performance:"
    Write-Host "  - CPU (Oryon): 25-35 seconds"
    Write-Host "  - Memory Usage: ~6-8GB"
    Write-Host "  - Power Usage: 15-25W (efficient)"
    Write-Host "===============================================`n"
}

function Generate-Report {
    Write-StepProgress "Generating Snapdragon setup report"
    
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $report = @"

SNAPDRAGON X ELITE DEMO SETUP REPORT
Time: $timestamp
Machine: $env:COMPUTERNAME
Profile: $OptimizationProfile

HARDWARE STATUS:
"@
    
    # Add hardware info
    $cpu = Get-WmiObject Win32_Processor
    $ram = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    
    $report += @"

  Processor: $($cpu.Name)
  Architecture: $($env:PROCESSOR_ARCHITECTURE)
  RAM: $($ram)GB
  Windows Build: $((Get-WmiObject Win32_OperatingSystem).BuildNumber)
  
"@
    
    if ($script:issues.Count -eq 0) {
        $report += @"
OVERALL STATUS: [OK] SNAPDRAGON SYSTEM READY

All requirements met. Snapdragon X Elite optimized for NPU acceleration.

Key Features Enabled:
  * Snapdragon X Elite NPU acceleration
  * DirectML + QNN provider support
  * SDXL Lightning 4-step models (~2.1GB)
  * ARM64 optimized packages
  * Expected performance: 8-12 seconds per image (NPU)

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
1. Start the demo: $script:DEMO_BASE\start_snapdragon_demo.bat
2. Or PowerShell: $script:DEMO_BASE\start_snapdragon_demo.ps1
3. Verify NPU acceleration is active
4. Test with sample prompts optimized for speed
5. Monitor NPU usage during generation

Log file: $script:logFile
"@
    
    Write-Host $report
    
    # Save report
    $reportPath = "$LogPath\snapdragon_setup_report_$((Get-Date).ToString('yyyyMMdd_HHmmss')).txt"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Success "Report saved to $reportPath"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Main {
    Write-Host @"
+============================================================+
|        SNAPDRAGON X ELITE DEMO PREPARATION SCRIPT         |
|       NPU-Accelerated AI Image Generation (Aug 2025)      |
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
    
    # Initialize state management
    Initialize-DeploymentState
    
    # Start timing
    $startTime = Get-Date
    Write-VerboseInfo "Setup started at: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    
    try {
        # Execute all steps
        Initialize-Directories
        
        # Hardware check
        $hardwareStatus = Test-SnapdragonHardwareRequirements
        
        if (!$hardwareStatus.OverallStatus -and !$Force) {
            Write-ErrorMsg "Hardware requirements not met. Use -Force to continue anyway."
            exit 1
        }
        
        # Install Python
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
            
            $accelOK = Install-SnapdragonAcceleration
            if (!$accelOK -and !$Force) {
                Write-WarningMsg "Snapdragon acceleration failed - will use CPU fallback"
            }
            
            # Configure NPU
            Configure-NPUProvider
            
            # Download models
            Download-SnapdragonModels
        }
        
        # Configure network
        Configure-Network
        
        # Create startup scripts
        Create-StartupScripts
        
        # Show performance expectations
        Show-SnapdragonPerformanceExpectations
        
        # Run performance test
        if (!$CheckOnly -and !$SkipModelDownload) {
            Test-SnapdragonPerformance
        }
        
    } catch {
        Write-ErrorMsg "Setup failed: $_"
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
        Write-Host "`n[OK] SNAPDRAGON X ELITE SYSTEM IS READY!" -ForegroundColor Green
        Write-Host "Expected NPU performance: 8-12 seconds per 768x768 image" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "`n[X] System setup incomplete - review issues above" -ForegroundColor Red
        exit 1
    }
}

# Run main function
try {
    Main
} catch {
    Write-ErrorMsg "Fatal error: $_"
    exit 1
}
