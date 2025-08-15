<#
.SYNOPSIS
    Error Recovery Helper Functions for Snapdragon Deployment
.DESCRIPTION
    Modular functions implementing comprehensive error recovery, fallback chains,
    and progressive failure handling for the Snapdragon X Elite deployment script.
.NOTES
    Version: 1.0
    Author: AI Demo Team
    Last Modified: 2025-01-14
#>

# ============================================================================
# OUTPUT FUNCTIONS (moved here to eliminate circular dependency)
# ============================================================================

function Write-StepProgress {
    param([string]$Message)
    $step = if ($script:checkpoint) { $script:checkpoint.Progress.CompletedSteps.Count + 1 } else { 1 }
    $total = if ($script:config) { $script:config.TotalSteps } else { 9 }
    Write-Host "[$step/$total] $Message" -ForegroundColor Cyan
    Write-Log -Message $Message -Component "Progress"
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
    Write-Log -Message $Message -Level "Success"
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Blue
    Write-Log -Message $Message -Level "Info"
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
    Write-Log -Message $Message -Level "Warning"
    if ($script:config) { $script:config.Warnings += $Message }
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[X] $Message" -ForegroundColor Red
    Write-Log -Message $Message -Level "Error"
    if ($script:config) { $script:config.Issues += $Message }
}

function Write-VerboseInfo {
    param([string]$Message)
    $verbose = if ($script:config) { $script:config.Verbose } else { $false }
    if ($verbose) {
        Write-Host "[v] $Message" -ForegroundColor Gray
        Write-Log -Message $Message -Level "Verbose"
    }
}

# ============================================================================
# CHECKPOINT AND STATE MANAGEMENT
# ============================================================================

$script:checkpointPath = "C:\AIDemo\checkpoint.json"
$script:backupCheckpointPath = "$env:TEMP\snapdragon_checkpoint_$(Get-Date -Format 'yyyyMMdd').json"

function Initialize-CheckpointSystem {
    <#
    .SYNOPSIS
        Initialize the checkpoint system for resume capability
    #>
    $script:checkpoint = @{
        Version = "1.0"
        Timestamp = Get-Date -Format "o"
        MachineId = $env:COMPUTERNAME
        Progress = @{
            CompletedSteps = @()
            FailedSteps = @()
            SkippedSteps = @()
            CurrentStep = $null
            TotalSteps = 20
            SuccessRate = 0
        }
        Environment = @{
            PythonPath = $null
            VenvPath = $null
            ModelsPath = "C:\AIDemo\models"
            InstalledPackages = @()
        }
        Failures = @{
            Recoverable = @()
            NonRecoverable = @()
            Warnings = @()
        }
        Performance = @{
            StartTime = Get-Date -Format "o"
            ElapsedTime = 0
            SuccessRate = 0
        }
    }
    
    return $script:checkpoint
}

function Save-Checkpoint {
    param(
        [string]$StepName,
        [string]$Status,
        [hashtable]$AdditionalData = @{}
    )
    
    if (-not $script:checkpoint) {
        Initialize-CheckpointSystem
    }
    
    $script:checkpoint.Timestamp = Get-Date -Format "o"
    $script:checkpoint.Progress.CurrentStep = $StepName
    
    switch ($Status) {
        "Success" { 
            $script:checkpoint.Progress.CompletedSteps += $StepName
            Write-VerboseInfo "Checkpoint saved: $StepName completed"
        }
        "Failed" { 
            $script:checkpoint.Progress.FailedSteps += $StepName
            Write-VerboseInfo "Checkpoint saved: $StepName failed"
        }
        "Skipped" { 
            $script:checkpoint.Progress.SkippedSteps += $StepName
            Write-VerboseInfo "Checkpoint saved: $StepName skipped"
        }
    }
    
    # Calculate success rate
    $completed = $script:checkpoint.Progress.CompletedSteps.Count
    $total = $script:checkpoint.Progress.TotalSteps
    $script:checkpoint.Progress.SuccessRate = [math]::Round(($completed / $total) * 100, 2)
    
    # Add any additional data
    foreach ($key in $AdditionalData.Keys) {
        $script:checkpoint[$key] = $AdditionalData[$key]
    }
    
    try {
        $script:checkpoint | ConvertTo-Json -Depth 10 | Out-File $script:checkpointPath -Force
        Copy-Item $script:checkpointPath $script:backupCheckpointPath -Force
    } catch {
        Write-WarningMsg "Failed to save checkpoint: $_"
    }
}

function Resume-FromCheckpoint {
    <#
    .SYNOPSIS
        Resume installation from a previous checkpoint
    #>
    if (Test-Path $script:checkpointPath) {
        try {
            $script:checkpoint = Get-Content $script:checkpointPath | ConvertFrom-Json -AsHashtable
            
            $completed = $script:checkpoint.Progress.CompletedSteps.Count
            $failed = $script:checkpoint.Progress.FailedSteps.Count
            
            Write-Info "Resuming from checkpoint:"
            Write-Info "  - Completed steps: $completed"
            Write-Info "  - Failed steps: $failed"
            Write-Info "  - Success rate: $($script:checkpoint.Progress.SuccessRate)%"
            
            # Restore environment
            if ($script:checkpoint.Environment.PythonPath) {
                $env:Path = $script:checkpoint.Environment.PythonPath + ";$env:Path"
            }
            
            return $script:checkpoint
        } catch {
            Write-WarningMsg "Failed to load checkpoint: $_"
            return Initialize-CheckpointSystem
        }
    } else {
        return Initialize-CheckpointSystem
    }
}

function Test-StepCompleted {
    param([string]$StepName)
    
    if ($script:checkpoint -and $script:checkpoint.Progress.CompletedSteps -contains $StepName) {
        Write-Info "Step already completed: $StepName (skipping)"
        return $true
    }
    return $false
}

# ============================================================================
# RETRY AND RECOVERY MECHANISMS
# ============================================================================

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Execute an action with exponential backoff retry logic
    #>
    param(
        [scriptblock]$Action,
        [int]$MaxRetries = 3,
        [int]$InitialDelay = 2,
        [string]$ErrorCategory = "Unknown"
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        try {
            $result = & $Action
            if ($attempt -gt 0) {
                Write-Success "Succeeded after $($attempt + 1) attempts"
            }
            return $result
        } catch {
            $lastError = $_
            $attempt++
            
            if ($attempt -ge $MaxRetries) {
                throw $lastError
            }
            
            $delay = [Math]::Pow(2, $attempt) * $InitialDelay
            Write-WarningMsg "Attempt $attempt failed: $($_.Exception.Message)"
            Write-Info "Retrying in $delay seconds..."
            
            # Apply recovery based on error type
            Apply-ErrorRecovery -ErrorRecord $lastError -Category $ErrorCategory
            
            Start-Sleep -Seconds $delay
        }
    }
}

function Apply-ErrorRecovery {
    param(
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Category
    )
    
    $errorMessage = $ErrorRecord.Exception.Message
    
    # Pattern-based recovery
    switch -Regex ($errorMessage) {
        "network|timeout|connection" {
            Write-Info "Attempting network recovery..."
            Reset-NetworkStack
        }
        "access denied|permission|unauthorized" {
            Write-Info "Checking permissions..."
            Test-AdminRights
        }
        "file in use|locked|cannot access" {
            Write-Info "Clearing resource locks..."
            Clear-ResourceLocks
        }
        "out of memory|insufficient memory" {
            Write-Info "Freeing memory..."
            Clear-MemoryCache
        }
        "disk full|insufficient space" {
            Write-Info "Clearing disk space..."
            Clear-TempFiles
        }
        default {
            Write-VerboseInfo "No specific recovery for: $errorMessage"
        }
    }
}

function Reset-NetworkStack {
    try {
        # Flush DNS cache
        ipconfig /flushdns | Out-Null
        
        # Reset Windows HTTP Services
        netsh winhttp reset proxy | Out-Null
        
        Write-VerboseInfo "Network stack reset completed"
    } catch {
        Write-VerboseInfo "Network reset failed: $_"
    }
}

function Clear-ResourceLocks {
    try {
        # Kill any hanging Python processes
        Get-Process python* -ErrorAction SilentlyContinue | 
            Where-Object { $_.Path -like "*AIDemo*" } | 
            Stop-Process -Force
        
        # Clear pip cache locks
        Remove-Item "$env:LOCALAPPDATA\pip\Cache\*.lock" -Force -ErrorAction SilentlyContinue
        
        Write-VerboseInfo "Resource locks cleared"
    } catch {
        Write-VerboseInfo "Failed to clear some locks: $_"
    }
}

function Clear-MemoryCache {
    try {
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        Write-VerboseInfo "Memory cache cleared"
    } catch {
        Write-VerboseInfo "Memory clearing failed: $_"
    }
}

function Clear-TempFiles {
    param([int]$RequiredGB = 1)
    
    $tempPaths = @(
        "$env:TEMP",
        "C:\Windows\Temp",
        "C:\AIDemo\temp",
        "$env:LOCALAPPDATA\pip\Cache"
    )
    
    $freedSpace = 0
    foreach ($path in $tempPaths) {
        if (Test-Path $path) {
            try {
                $sizeBefore = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum / 1GB
                
                Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                
                $sizeAfter = (Get-ChildItem $path -Recurse -ErrorAction SilentlyContinue | 
                    Measure-Object -Property Length -Sum).Sum / 1GB
                
                $freedSpace += ($sizeBefore - $sizeAfter)
            } catch {
                Write-VerboseInfo "Failed to clean $path : $_"
            }
        }
    }
    
    Write-Info "Freed $([math]::Round($freedSpace, 2))GB of disk space"
    return $freedSpace -ge $RequiredGB
}

# ============================================================================
# NPU PROVIDER FALLBACK CHAIN
# ============================================================================

$script:NPU_PROVIDERS = @(
    @{Name="QNNExecutionProvider"; Package="onnxruntime-qnn"; Priority=100; TestCmd="Test-QNNProvider"},
    @{Name="DmlExecutionProvider"; Package="onnxruntime-directml"; Priority=80; TestCmd="Test-DirectMLProvider"},
    @{Name="OpenVINOExecutionProvider"; Package="onnxruntime-openvino"; Priority=40; TestCmd="Test-OpenVINOProvider"},
    @{Name="CPUExecutionProvider"; Package="onnxruntime"; Priority=20; TestCmd="Test-CPUProvider"}
)

function Install-NPUProviderWithFallback {
    <#
    .SYNOPSIS
        Install NPU provider with automatic fallback chain
    #>
    Write-StepProgress "Installing NPU acceleration support"
    
    $selectedProvider = $null
    $fallbackReason = ""
    
    foreach ($provider in $script:NPU_PROVIDERS) {
        Write-Info "Trying provider: $($provider.Name) (priority: $($provider.Priority))"
        
        try {
            # Try to install the provider package
            $installResult = Invoke-WithRetry -Action {
                & pip install $provider.Package 2>&1
                if ($LASTEXITCODE -ne 0) { throw "Installation failed" }
            } -MaxRetries 2
            
            # Test if provider actually works
            if (& $provider.TestCmd) {
                $selectedProvider = $provider
                Write-Success "$($provider.Name) installed and verified"
                break
            } else {
                $fallbackReason = "Provider test failed"
                Write-WarningMsg "$($provider.Name) installed but not functional"
            }
        } catch {
            $fallbackReason = $_.Exception.Message
            Write-WarningMsg "$($provider.Name) not available: $fallbackReason"
        }
    }
    
    if (-not $selectedProvider) {
        $selectedProvider = $script:NPU_PROVIDERS[-1]  # CPU fallback
        Write-WarningMsg "All NPU providers failed, using CPU fallback"
    }
    
    # Save provider selection to checkpoint
    Save-Checkpoint -StepName "NPUProvider" -Status "Success" -AdditionalData @{
        SelectedProvider = $selectedProvider.Name
        FallbackReason = $fallbackReason
    }
    
    return $selectedProvider
}

function Test-QNNProvider {
    try {
        $testScript = @"
import onnxruntime as ort
providers = ort.get_available_providers()
print('QNNExecutionProvider' in providers)
"@
        $result = $testScript | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

function Test-DirectMLProvider {
    try {
        $testScript = @"
import onnxruntime as ort
providers = ort.get_available_providers()
print('DmlExecutionProvider' in providers)
"@
        $result = $testScript | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

function Test-WinMLProvider {
    try {
        Import-Module winml -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-OpenVINOProvider {
    try {
        $testScript = @"
import onnxruntime as ort
providers = ort.get_available_providers()
print('OpenVINOExecutionProvider' in providers)
"@
        $result = $testScript | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

function Test-CPUProvider {
    try {
        $testScript = @"
import onnxruntime as ort
providers = ort.get_available_providers()
print('CPUExecutionProvider' in providers)
"@
        $result = $testScript | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

# ============================================================================
# PACKAGE INSTALLATION FALLBACK
# ============================================================================

function Install-PackageWithFallback {
    param(
        [string]$PackageName,
        [string]$Version = "",
        [bool]$Critical = $false
    )
    
    $installMethods = @(
        "Install-FromWheelCache",
        "Install-FromBinaryWheel",
        "Install-FromCondaForge",
        "Install-FromSource",
        "Install-AlternativePackage",
        "Install-MinimalVersion"
    )
    
    foreach ($method in $installMethods) {
        try {
            Write-VerboseInfo "Trying installation method: $method"
            $result = & $method -Package $PackageName -Version $Version
            if ($result) {
                Write-Success "$PackageName installed via $method"
                return $true
            }
        } catch {
            Write-VerboseInfo "$method failed: $_"
        }
    }
    
    if ($Critical) {
        throw "Critical package $PackageName could not be installed"
    } else {
        Write-WarningMsg "Optional package $PackageName skipped"
        $script:checkpoint.Failures.Warnings += "$PackageName installation failed"
        return $false
    }
}

function Install-FromWheelCache {
    param($Package, $Version)
    
    $cacheDir = "C:\AIDemo\offline\packages"
    if (Test-Path $cacheDir) {
        $wheel = Get-ChildItem "$cacheDir\$Package*.whl" -ErrorAction SilentlyContinue | 
            Select-Object -First 1
        
        if ($wheel) {
            & pip install $wheel.FullName
            return $LASTEXITCODE -eq 0
        }
    }
    return $false
}

function Install-FromBinaryWheel {
    param($Package, $Version)
    
    $wheelUrl = Get-WheelUrl -Package $Package -Version $Version
    if ($wheelUrl) {
        & pip install $wheelUrl
        return $LASTEXITCODE -eq 0
    }
    return $false
}

function Install-FromCondaForge {
    param($Package, $Version)
    
    # Try conda-forge for ARM64 packages
    if (Get-Command conda -ErrorAction SilentlyContinue) {
        & conda install -c conda-forge $Package -y
        return $LASTEXITCODE -eq 0
    }
    return $false
}

function Install-FromSource {
    param($Package, $Version)
    
    # Install build tools if needed
    Ensure-BuildTools
    
    # Try to build from source
    if ($Version) {
        & pip install --no-binary :all: "$Package==$Version"
    } else {
        & pip install --no-binary :all: $Package
    }
    return $LASTEXITCODE -eq 0
}

function Install-AlternativePackage {
    param($Package, $Version)
    
    $alternatives = @{
        "numpy" = "numpy-mkl"
        "scipy" = "scipy-mkl"
        "torch" = "torch-cpu"
        "tensorflow" = "tensorflow-cpu"
    }
    
    if ($alternatives.ContainsKey($Package)) {
        $altPackage = $alternatives[$Package]
        Write-Info "Trying alternative package: $altPackage"
        & pip install $altPackage
        return $LASTEXITCODE -eq 0
    }
    return $false
}

function Install-MinimalVersion {
    param($Package, $Version)
    
    # Try to install minimal/oldest compatible version
    & pip install "$Package>=0.0.0" --prefer-binary
    return $LASTEXITCODE -eq 0
}

function Ensure-BuildTools {
    if (-not (Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        Write-Info "Installing Visual Studio Build Tools..."
        $buildToolsUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
        $installer = "$env:TEMP\vs_buildtools.exe"
        
        Invoke-WebRequest -Uri $buildToolsUrl -OutFile $installer
        Start-Process -FilePath $installer -ArgumentList "--quiet", "--wait", "--add", "Microsoft.VisualStudio.Workload.VCTools" -Wait
    }
}

function Get-WheelUrl {
    param($Package, $Version)
    
    # Check known wheel repositories
    $repos = @(
        "https://www.piwheels.org/simple/$Package/",
        "https://pypi.org/simple/$Package/"
    )
    
    foreach ($repo in $repos) {
        try {
            $response = Invoke-WebRequest -Uri $repo -UseBasicParsing
            $wheelLinks = $response.Links | Where-Object { $_.href -match ".*\.whl$" }
            if ($wheelLinks) {
                return $wheelLinks[0].href
            }
        } catch {
            continue
        }
    }
    return $null
}

# ============================================================================
# RESOURCE MONITORING
# ============================================================================

function Test-ResourceAvailability {
    param(
        [int]$RequiredMemoryGB = 2,
        [int]$RequiredDiskGB = 3,
        [int]$MaxCPUPercent = 90,
        [int]$RetryCount = 0,
        [int]$MaxRetries = 3
    )
    
    # Prevent infinite recursion
    if ($RetryCount -ge $MaxRetries) {
        Write-WarningMsg "Resource check retry limit reached ($MaxRetries attempts). Continuing with available resources."
        if ($script:config -and $script:config.Force) {
            Write-VerboseInfo "Force mode enabled - proceeding despite resource constraints"
            return $true
        }
        return $false
    }
    
    $resources = @{
        Memory = @{
            Available = [math]::Round((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
            Required = $RequiredMemoryGB
            OK = $false
        }
        Disk = @{
            Available = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
            Required = $RequiredDiskGB
            OK = $false
        }
        CPU = @{
            Usage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
            MaxAllowed = $MaxCPUPercent
            OK = $false
        }
    }
    
    # Add diagnostic logging for memory calculation
    Write-VerboseInfo "Resource check attempt $($RetryCount + 1)/$($MaxRetries + 1):"
    Write-VerboseInfo "  Raw FreePhysicalMemory: $((Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory) KB"
    Write-VerboseInfo "  Calculated available memory: $($resources.Memory.Available) GB"
    
    # Check each resource
    $resources.Memory.OK = $resources.Memory.Available -ge $resources.Memory.Required
    $resources.Disk.OK = $resources.Disk.Available -ge $resources.Disk.Required
    $resources.CPU.OK = $resources.CPU.Usage -le $resources.CPU.MaxAllowed
    
    $allOK = $resources.Memory.OK -and $resources.Disk.OK -and $resources.CPU.OK
    
    if (-not $allOK) {
        Write-WarningMsg "Resource constraints detected (attempt $($RetryCount + 1)):"
        
        if (-not $resources.Memory.OK) {
            Write-WarningMsg "  Memory: $($resources.Memory.Available)GB available, $($resources.Memory.Required)GB required"
            if ($RetryCount -lt $MaxRetries) {
                Clear-MemoryCache
            }
        }
        
        if (-not $resources.Disk.OK) {
            Write-WarningMsg "  Disk: $($resources.Disk.Available)GB available, $($resources.Disk.Required)GB required"
            if ($RetryCount -lt $MaxRetries) {
                Clear-TempFiles -RequiredGB ($resources.Disk.Required - $resources.Disk.Available)
            }
        }
        
        if (-not $resources.CPU.OK) {
            Write-WarningMsg "  CPU: $([math]::Round($resources.CPU.Usage))% usage, waiting for idle..."
            if ($RetryCount -lt $MaxRetries) {
                Wait-ForCPUAvailability -MaxPercent $MaxCPUPercent
            }
        }
        
        # Add delay between retries to allow cleanup to take effect
        if ($RetryCount -lt $MaxRetries) {
            Write-VerboseInfo "Waiting 2 seconds for cleanup to take effect..."
            Start-Sleep -Seconds 2
            
            # Re-check after cleanup with incremented retry count
            return Test-ResourceAvailability -RequiredMemoryGB $RequiredMemoryGB -RequiredDiskGB $RequiredDiskGB -MaxCPUPercent $MaxCPUPercent -RetryCount ($RetryCount + 1) -MaxRetries $MaxRetries
        } else {
            Write-WarningMsg "Resource cleanup attempts exhausted. Proceeding with available resources."
            return $false
        }
    }
    
    Write-VerboseInfo "Resources OK - Memory: $($resources.Memory.Available)GB, Disk: $($resources.Disk.Available)GB, CPU: $([math]::Round($resources.CPU.Usage))%"
    return $true
}

function Wait-ForCPUAvailability {
    param([int]$MaxPercent = 80)
    
    $attempts = 0
    while ($attempts -lt 30) {
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time").CounterSamples.CookedValue
        if ($cpuUsage -le $MaxPercent) {
            return $true
        }
        Write-VerboseInfo "CPU at $([math]::Round($cpuUsage))%, waiting..."
        Start-Sleep -Seconds 2
        $attempts++
    }
    return $false
}

function Enable-ResourceThrottling {
    $script:throttleSettings = @{
        MaxParallelDownloads = 1
        MaxMemoryUsageGB = 4
        MaxCPUPercent = 80
        ThermalProtection = $true
        NetworkBandwidthPercent = 50
    }
    
    Write-Info "Resource throttling enabled"
    return $script:throttleSettings
}

# ============================================================================
# MODEL DOWNLOAD WITH RESUME
# ============================================================================

function Download-ModelWithResume {
    param(
        [string]$Url,
        [string]$Destination,
        [int64]$ExpectedSize = 0
    )
    
    $sources = @(
        @{Name="Primary"; URL=$Url},
        @{Name="Mirror1"; URL=$Url -replace "huggingface.co", "hf-mirror.com"},
        @{Name="Cache"; URL="file://C:/AIDemo/offline/models/$(Split-Path $Url -Leaf)"}
    )
    
    foreach ($source in $sources) {
        try {
            Write-Info "Trying download from $($source.Name)"
            
            if ($source.URL -like "file://*") {
                $localPath = $source.URL -replace "file://", ""
                if (Test-Path $localPath) {
                    Copy-Item $localPath $Destination
                    Write-Success "Model loaded from cache"
                    return $true
                }
            } else {
                $result = Download-FileWithResume -Url $source.URL -OutputPath $Destination -ExpectedSize $ExpectedSize
                if ($result) {
                    Write-Success "Model downloaded from $($source.Name)"
                    return $true
                }
            }
        } catch {
            Write-WarningMsg "Download from $($source.Name) failed: $_"
        }
    }
    
    return $false
}

function Download-FileWithResume {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int64]$ExpectedSize = 0
    )
    
    $tempFile = "$OutputPath.partial"
    $startPosition = 0
    
    # Check if partial download exists
    if (Test-Path $tempFile) {
        $startPosition = (Get-Item $tempFile).Length
        Write-Info "Resuming download from byte $startPosition"
    }
    
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = "GET"
        
        if ($startPosition -gt 0) {
            $request.AddRange($startPosition)
        }
        
        $response = $request.GetResponse()
        $totalSize = $response.ContentLength + $startPosition
        
        $responseStream = $response.GetResponseStream()
        $fileStream = if ($startPosition -gt 0) {
            [System.IO.FileStream]::new($tempFile, [System.IO.FileMode]::Append)
        } else {
            [System.IO.FileStream]::new($tempFile, [System.IO.FileMode]::Create)
        }
        
        $buffer = New-Object byte[] 8192
        $totalRead = $startPosition
        $lastProgress = 0
        
        while ($true) {
            $read = $responseStream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) { break }
            
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            
            $progress = [math]::Round(($totalRead / $totalSize) * 100)
            if ($progress -ne $lastProgress) {
                Write-Progress -Activity "Downloading" -Status "$progress% Complete" -PercentComplete $progress
                $lastProgress = $progress
            }
        }
        
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
        
        # Verify size if expected size provided
        if ($ExpectedSize -gt 0) {
            $actualSize = (Get-Item $tempFile).Length
            if ([Math]::Abs($actualSize - $ExpectedSize) / $ExpectedSize -gt 0.1) {
                throw "Size mismatch: expected $ExpectedSize, got $actualSize"
            }
        }
        
        # Move completed file
        Move-Item $tempFile $OutputPath -Force
        Write-Progress -Activity "Downloading" -Completed
        
        return $true
    } catch {
        Write-ErrorMsg "Download failed: $_"
        return $false
    }
}

# ============================================================================
# ROLLBACK MECHANISM
# ============================================================================

$script:rollbackStack = @()

function Start-Transaction {
    param([string]$Name)
    
    $transaction = @{
        Name = $Name
        StartTime = Get-Date
        Actions = @()
        State = "Active"
    }
    
    $script:currentTransaction = $transaction
    $script:rollbackStack += $transaction
    
    Write-VerboseInfo "Transaction started: $Name"
}

function Add-RollbackAction {
    param([scriptblock]$Action)
    
    if ($script:currentTransaction) {
        $script:currentTransaction.Actions += $Action
    }
}

function Commit-Transaction {
    if ($script:currentTransaction) {
        $script:currentTransaction.State = "Committed"
        Write-VerboseInfo "Transaction committed: $($script:currentTransaction.Name)"
        $script:currentTransaction = $null
    }
}

function Rollback-Transaction {
    param([string]$Name = $null)
    
    if ($Name) {
        $transaction = $script:rollbackStack | Where-Object { $_.Name -eq $Name }
    } else {
        $transaction = $script:currentTransaction
    }
    
    if ($transaction) {
        Write-WarningMsg "Rolling back: $($transaction.Name)"
        
        # Execute rollback actions in reverse order
        [array]::Reverse($transaction.Actions)
        foreach ($action in $transaction.Actions) {
            try {
                & $action
            } catch {
                Write-ErrorMsg "Rollback action failed: $_"
            }
        }
        
        $transaction.State = "RolledBack"
    }
}

# ============================================================================
# DIAGNOSTIC LOGGING
# ============================================================================

$script:logPath = "C:\AIDemo\logs"
$script:logFile = Join-Path $script:logPath "install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Initialize-Logging {
    if (-not (Test-Path $script:logPath)) {
        New-Item -ItemType Directory -Path $script:logPath -Force | Out-Null
    }
    
    Write-Log -Message "Installation started" -Level "Info"
    Write-Log -Message "Machine: $env:COMPUTERNAME, User: $env:USERNAME" -Level "Info"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Component = "General",
        $ErrorRecord = $null
    )
    
    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        Level = $Level
        Component = $Component
        Message = $Message
    }
    
    if ($ErrorRecord) {
        $logEntry.Error = @{
            Message = $ErrorRecord.Exception.Message
            Type = $ErrorRecord.Exception.GetType().FullName
            StackTrace = $ErrorRecord.ScriptStackTrace
        }
    }
    
    $logLine = "$($logEntry.Timestamp) [$($logEntry.Level)] [$($logEntry.Component)] $($logEntry.Message)"
    
    if ($ErrorRecord) {
        $logLine += " | Error: $($ErrorRecord.Exception.Message)"
    }
    
    # Write to file
    $logLine | Add-Content -Path $script:logFile
    
    # Also write critical errors to event log
    if ($Level -eq "Critical") {
        try {
            Write-EventLog -LogName Application -Source "SnapdragonAI" -EventId 1000 -EntryType Error -Message $Message
        } catch {
            # Event log might not be available
        }
    }
}

# ============================================================================
# SUCCESS EVALUATION
# ============================================================================

function Evaluate-InstallationSuccess {
    $components = @{
        Python = Test-PythonInstallation
        VirtualEnv = Test-Path "C:\AIDemo\venv"
        NPUProvider = Test-NPUAvailability
        Models = Test-ModelAvailability
        CorePackages = Test-CorePackages
        Performance = Test-BasicPerformance
    }
    
    $weights = @{
        Python = 25
        VirtualEnv = 15
        NPUProvider = 20
        Models = 15
        CorePackages = 15
        Performance = 10
    }
    
    $totalScore = 0
    $maxScore = 100
    
    foreach ($component in $components.Keys) {
        if ($components[$component]) {
            $totalScore += $weights[$component]
            Write-Success "$component : OK (+$($weights[$component]) points)"
        } else {
            Write-WarningMsg "$component : Failed (0 points)"
        }
    }
    
    $successLevel = switch ($totalScore) {
        {$_ -ge 90} { "Full" }
        {$_ -ge 70} { "Standard" }
        {$_ -ge 50} { "Minimal" }
        default { "Failed" }
    }
    
    $result = @{
        Score = $totalScore
        Level = $successLevel
        Components = $components
        Message = "Installation completed at $successLevel level ($totalScore% success)"
    }
    
    Write-Info $result.Message
    
    # Save to checkpoint
    Save-Checkpoint -StepName "Evaluation" -Status "Success" -AdditionalData @{
        SuccessEvaluation = $result
    }
    
    return $result
}

function Test-PythonInstallation {
    try {
        $version = & python --version 2>&1
        return $version -match "Python 3\.(9|10|11)"
    } catch {
        return $false
    }
}

function Test-NPUAvailability {
    try {
        $script = @"
import onnxruntime as ort
providers = ort.get_available_providers()
npu_providers = ['QNNExecutionProvider', 'DmlExecutionProvider', 'OpenVINOExecutionProvider']
print(any(p in providers for p in npu_providers))
"@
        $result = $script | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

function Test-ModelAvailability {
    $modelPath = "C:\AIDemo\models"
    $models = Get-ChildItem "$modelPath\*\*.safetensors" -ErrorAction SilentlyContinue
    return $models.Count -gt 0
}

function Test-CorePackages {
    $required = @("numpy", "torch", "transformers", "diffusers")
    $installed = & pip list --format=freeze 2>&1
    
    foreach ($package in $required) {
        if ($installed -notmatch $package) {
            return $false
        }
    }
    return $true
}

function Test-BasicPerformance {
    # Quick performance test
    try {
        $testScript = @"
import time
import numpy as np
start = time.time()
arr = np.random.randn(1000, 1000)
result = np.dot(arr, arr.T)
elapsed = time.time() - start
print(elapsed < 5)  # Should complete in under 5 seconds
"@
        $result = $testScript | python 2>&1
        return $result -eq "True"
    } catch {
        return $false
    }
}

# ============================================================================
# ADMIN RIGHTS CHECK
# ============================================================================

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdminRights {
    if (-not (Test-AdminRights)) {
        Write-WarningMsg "Administrator rights required. Restarting with elevation..."
        
        $scriptPath = $MyInvocation.MyCommand.Path
        $arguments = $MyInvocation.Line -replace [regex]::Escape($scriptPath), ""
        
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $arguments"
        exit
    }
}

# Note: Export-ModuleMember removed - not needed for dot-sourcing
# All functions and variables are automatically available when dot-sourced
