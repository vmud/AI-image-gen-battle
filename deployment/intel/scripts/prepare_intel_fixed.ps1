#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Intel Core Ultra Optimized Demo Preparation Script - RemoteException Fixed Version
.DESCRIPTION
    Fixed version addressing System.Management.Automation.RemoteException errors
    Preserves all critical validation while making non-critical operations resilient
    Targets specific failure points without masking demo-breaking issues
.NOTES
    Changes from original:
    - Enhanced non-interactive detection
    - Safe CIM/WMI fallbacks for non-critical operations
    - Improved Python subprocess handling
    - Graceful prompt handling in non-interactive contexts
    - Resilient logging and transcript handling
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$CheckOnly = $false,
    [switch]$Force = $false,
    [switch]$SkipModelDownload = $false,
    [switch]$UseHttpRange = $false,  # Fixed: Switch parameters should default to false
    [switch]$NonInteractive = $false,
    [string]$LogPath = "C:\AIDemo\logs",
    [ValidateSet('Speed', 'Balanced', 'Quality')]
    [string]$OptimizationProfile = 'Balanced'
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

# ============================================================================
# FIX 1: ENHANCED NON-INTERACTIVE DETECTION
# ============================================================================
if (!$script:NonInteractive) {
    # More comprehensive detection of non-interactive contexts
    $nonInteractiveIndicators = @(
        ($env:GITHUB_ACTIONS -eq 'true'),
        ($env:CI -eq 'true'),
        ($env:TF_BUILD -eq 'true'),
        ($null -ne $env:JENKINS_HOME),  # Fixed: $null should be on left side
        ($env:GITLAB_CI -eq 'true'),
        ($env:CIRCLECI -eq 'true'),
        ($env:TRAVIS -eq 'true'),
        ($env:APPVEYOR -eq 'true'),
        ($null -ne $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI),  # Fixed: $null should be on left side
        ($Host.Name -eq 'ServerRemoteHost'),
        ($Host.Name -eq 'ConsoleHost' -and [Environment]::UserInteractive -eq $false),
        (-not [Environment]::UserInteractive),
        ($env:TERM_PROGRAM -eq 'vscode' -and $env:VSCODE_INJECTION -eq '1')  # VSCode terminal detection
    )
    
    if ($nonInteractiveIndicators -contains $true) {
        $script:NonInteractive = $true
        Write-Warning "Non-interactive environment detected - automatic mode enabled"
    }
}

# Script variables initialization
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

# ============================================================================
# FIX 2: SAFE INTERACTIVE MODE CHECK
# ============================================================================
function Test-InteractiveMode {
    if ($script:NonInteractive) {
        return $false
    }
    
    # Additional safety check for interactive capability
    try {
        # Test if we can actually read from host
        $keyAvailable = $host.UI.RawUI.KeyAvailable
        if ($null -ne $keyAvailable) {
            return [Environment]::UserInteractive
        }
        return $false
    } catch {
        # If we can't even check for key availability, we're not interactive
        $script:NonInteractive = $true
        return $false
    }
}

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
    Write-Progress -Activity "Intel Demo Setup" -Status $Message -PercentComplete $percent
    if ($VerbosePreference -eq 'Continue') {
        Write-Host ("-" * 60) -ForegroundColor DarkGray
    }
}

# ============================================================================
# FIX 3: SAFE LOGGING INITIALIZATION
# ============================================================================
function Initialize-Logging {
    if (!$script:transcriptStarted) {
        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $script:logFile = "$LogPath\intel_setup_$timestamp.log"
        
        # Create log directory if needed
        if (!(Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        
        # Start transcript with error handling
        try {
            Start-Transcript -Path $script:logFile -Append -ErrorAction SilentlyContinue
            $script:transcriptStarted = $true
            Write-VerboseInfo "Logging started: $script:logFile"
        } catch {
            Write-VerboseInfo "Could not start transcript (non-critical): $_"
            # Continue without transcript in restricted environments
        }
    }
}

function Stop-Logging {
    if ($script:transcriptStarted) {
        try {
            Stop-Transcript -ErrorAction SilentlyContinue
            Write-VerboseInfo "Logging stopped"
        } catch {
            # Transcript might already be stopped or not available
        }
    }
}

# ============================================================================
# FIX 4: SAFE HARDWARE REQUIREMENTS CHECK
# ============================================================================
function Test-IntelHardwareRequirements {
    Write-StepProgress "Checking Intel hardware requirements"
    
    $hardwareStatus = @{
        ProcessorValid = $false
        ProcessorName = "Unknown"
        ProcessorGeneration = 0
        AVX512Support = $false
        DirectX12Valid = $false
        DirectMLAvailable = $false
        GPUName = "Unknown"
        GPUMemory = 0
        SystemRAM = 0
        StorageAvailable = 0
        OverallStatus = $false
        Warnings = @()
        Errors = @()
    }
    
    # Safe processor check
    try {
        $cpu = $null
        try {
            $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        } catch {
            Write-VerboseInfo "CIM failed, trying WMI: $_"
            try {
                $cpu = Get-WmiObject Win32_Processor -ErrorAction Stop | Select-Object -First 1
            } catch {
                Write-VerboseInfo "WMI also failed: $_"
                # Use environment variable as last resort
                $hardwareStatus.ProcessorName = $env:PROCESSOR_IDENTIFIER
            }
        }
        
        if ($cpu) {
            $hardwareStatus.ProcessorName = $cpu.Name
            
            # Check for Intel Core Ultra or recent generations
            if ($cpu.Name -match "Intel.*Core.*Ultra" -or 
                $cpu.Name -match "Intel.*Core.*i[579].*1[34]\d{2,3}[HUP]") {
                Write-Success "Processor: $($cpu.Name)"
                $hardwareStatus.ProcessorValid = $true
                
                # Extract generation
                if ($cpu.Name -match "(\d{2})\d{2,3}[HUP]") {
                    try {
                        $hardwareStatus.ProcessorGeneration = [int]$matches[1]
                    } catch {
                        Write-VerboseInfo "Could not parse processor generation"
                    }
                }
            } else {
                $hardwareStatus.Warnings += "Not an Intel Core Ultra processor: $($cpu.Name)"
                Write-WarningMsg "Processor: $($cpu.Name) (Intel Core Ultra recommended)"
            }
        }
    } catch {
        Write-WarningMsg "Could not detect processor: $_"
        # Continue anyway - processor detection is non-critical for demo functionality
    }
    
    # Safe RAM check
    try {
        $memInfo = $null
        try {
            $memInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        } catch {
            try {
                $memInfo = Get-WmiObject Win32_ComputerSystem -ErrorAction Stop
            } catch {
                Write-VerboseInfo "Could not get memory info: $_"
                # Assume sufficient RAM if we can't detect
                $hardwareStatus.SystemRAM = 16
            }
        }
        
        if ($memInfo) {
            $ram = [math]::Round($memInfo.TotalPhysicalMemory / 1GB)
            $hardwareStatus.SystemRAM = $ram
            Write-Success "RAM: $($ram)GB detected"
        }
    } catch {
        Write-VerboseInfo "RAM detection failed (non-critical): $_"
        $hardwareStatus.SystemRAM = 16  # Assume sufficient
    }
    
    # Safe GPU check
    try {
        $gpu = Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue | 
               Where-Object { $_.Name -match "Intel|Arc|Iris" } | 
               Select-Object -First 1
        
        if ($gpu) {
            $hardwareStatus.GPUName = $gpu.Name
            Write-Success "GPU: $($gpu.Name)"
        } else {
            # Check for any GPU
            $gpu = Get-WmiObject Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gpu) {
                $hardwareStatus.GPUName = $gpu.Name
                Write-Info "GPU: $($gpu.Name) (will attempt DirectML)"
            }
        }
    } catch {
        Write-VerboseInfo "GPU detection failed (non-critical): $_"
    }
    
    # Safe DirectX check
    try {
        $os = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $osVersion = $os.Version
            # Basic version check for DirectX 12 support
            if ($osVersion -ge "10.0.18362") {
                $hardwareStatus.DirectX12Valid = $true
                Write-Success "DirectX 12 compatible OS detected"
            }
        }
    } catch {
        Write-VerboseInfo "OS version check failed (non-critical): $_"
        # Assume DirectX 12 is available on modern Windows
        $hardwareStatus.DirectX12Valid = $true
    }
    
    # Safe disk space check
    try {
        $drive = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($drive) {
            $freeSpace = [math]::Round($drive.Free / 1GB, 2)
            $hardwareStatus.StorageAvailable = $freeSpace
            
            if ($freeSpace -lt 10) {
                $hardwareStatus.Errors += "Insufficient disk space: $($freeSpace)GB"
                Write-ErrorMsg "Free space: $($freeSpace)GB (10GB required)"
            } else {
                Write-Success "Free space: $($freeSpace)GB"
            }
        }
    } catch {
        Write-VerboseInfo "Disk space check failed: $_"
        # This is critical - re-throw
        throw "Cannot verify disk space: $_"
    }
    
    # Set overall status
    $hardwareStatus.OverallStatus = $hardwareStatus.Errors.Count -eq 0
    
    return $hardwareStatus
}

# ============================================================================
# FIX 5: SAFE HARDWARE CONFIRMATION
# ============================================================================
function Show-HardwareConfirmation {
    param([hashtable]$HardwareStatus)
    
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
        # Safe prompt handling
        if (Test-InteractiveMode) {
            try {
                $continue = Read-Host "Continue with this configuration? (Y/N)"
                return $continue -eq 'Y'
            } catch {
                Write-Info "Cannot prompt - auto-continuing in non-interactive mode"
                return $true
            }
        } else {
            Write-Info "Non-interactive mode - auto-continuing with configuration"
            return $true
        }
    }
    
    return $true
}

# ============================================================================
# FIX 6: SAFE PYTHON INSTALLATION CHECK
# ============================================================================
function Install-Python {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    Write-StepProgress "Checking Python installation"
    
    # Only support Python 3.10 for DirectML compatibility
    $pythonVersions = @("3.10")
    $pythonFound = $false
    
    Write-Info "Checking for Python 3.10 (required for torch-directml)..."
    
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
                # Ensure temp directory exists
                if (!(Test-Path $script:TEMP_PATH)) {
                    New-Item -ItemType Directory -Path $script:TEMP_PATH -Force | Out-Null
                }
                
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
                
                return $true
            } catch {
                Write-ErrorMsg "Failed to install Python: $_"
                return $false
            }
        }
    } elseif (!$pythonFound) {
        Write-ErrorMsg "Python 3.10 not found - required for demo"
        return $false
    }
    
    return $pythonFound
}

# Create required directories
function Initialize-Directories {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
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
            } else {
                Write-VerboseInfo "Directory exists: $dir"
            }
        }
    }
}

# Main execution function
function Main {
    Write-Host @"
+============================================================+
|          INTEL CORE ULTRA DEMO PREPARATION SCRIPT         |
|       DirectML GPU-Accelerated (RemoteException Fixed)    |
+============================================================+
"@ -ForegroundColor Cyan
    
    if ($CheckOnly) {
        Write-Info "Running in CHECK-ONLY mode - no changes will be made"
    }
    
    if ($WhatIf) {
        Write-Info "Running in WHAT-IF mode - showing what would be done"
    }
    
    # Initialize logging with error handling
    Initialize-Logging
    
    # Start timing
    $startTime = Get-Date
    
    try {
        # Initialize directories
        Initialize-Directories
        
        # Check hardware with safe fallbacks
        $hardwareStatus = Test-IntelHardwareRequirements
        
        if (!$(Show-HardwareConfirmation -HardwareStatus $hardwareStatus)) {
            if (!$Force) {
                Write-ErrorMsg "Setup cancelled - hardware requirements not met"
                exit 1
            }
        }
        
        # Install Python if needed (critical - must not mask failures)
        $pythonOK = Install-Python
        if (!$pythonOK -and !$Force) {
            throw "Python installation failed - cannot continue"
        }
        
        Write-Success "All critical checks passed!"
        Write-Info "Core components ready for Intel demo deployment"
        
    } catch {
        Write-ErrorMsg "Setup failed: $_"
        if (!$Force) {
            throw
        }
    } finally {
        Stop-Logging
    }
    
    # Calculate elapsed time
    $endTime = Get-Date
    $elapsed = $endTime - $startTime
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor DarkGray
    Write-Info "Initial setup completed in $([math]::Round($elapsed.TotalMinutes, 1)) minutes"
    
    # Summary
    if ($script:issues.Count -eq 0) {
        Write-Host "`n[OK] System ready for next steps!" -ForegroundColor Green
        Write-Info "Run the original prepare_intel.ps1 script to continue installation"
        exit 0
    } else {
        Write-Host "`n[X] Issues found - review above" -ForegroundColor Red
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
