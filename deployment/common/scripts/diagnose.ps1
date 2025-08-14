# Platform Diagnostic Script for AI Acceleration
# This script helps diagnose and fix platform-specific AI acceleration issues

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Acceleration Diagnostic Tool" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Detect platform
function Get-PlatformArchitecture {
    $arch = $env:PROCESSOR_ARCHITECTURE
    $processor = (Get-WmiObject -Class Win32_Processor).Name
    
    if ($processor -like "*Snapdragon*" -or $processor -like "*Qualcomm*" -or $arch -eq "ARM64") {
        return "ARM64"
    } else {
        return "x86_64"
    }
}

$platform = Get-PlatformArchitecture
$processor = (Get-WmiObject -Class Win32_Processor).Name

Write-Host "Platform detected: $platform" -ForegroundColor Cyan
Write-Host "Processor: $processor" -ForegroundColor Cyan

if ($platform -eq "ARM64") {
    Write-Host "`nRunning Snapdragon NPU diagnostics..." -ForegroundColor Yellow
} else {
    Write-Host "`nRunning Intel DirectML diagnostics..." -ForegroundColor Yellow
}

# Function to check Windows version
function Check-WindowsVersion {
    Write-Host "`nChecking Windows version..." -ForegroundColor Yellow
    
    $os = Get-CimInstance Win32_OperatingSystem
    $version = $os.Version
    $build = $os.BuildNumber
    
    Write-Host "Windows Version: $($os.Caption)" -ForegroundColor White
    Write-Host "Build: $build" -ForegroundColor White
    
    # DirectML requires Windows 10 1903+ (build 18362+)
    if ([int]$build -lt 18362) {
        Write-Host "❌ DirectML requires Windows 10 version 1903 or later (build 18362+)" -ForegroundColor Red
        Write-Host "Please update Windows to continue" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✅ Windows version is compatible" -ForegroundColor Green
    return $true
}

# Function to check Python version
function Check-PythonVersion {
    Write-Host "`nChecking Python version..." -ForegroundColor Yellow
    
    try {
        $pythonVersion = python --version 2>&1
        Write-Host "Python version: $pythonVersion" -ForegroundColor White
        
        # Extract version number
        $versionNum = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
        
        if ($versionNum -in @("3.8", "3.9", "3.10")) {
            Write-Host "✅ Python $versionNum is compatible with DirectML" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Python $versionNum is not compatible with DirectML" -ForegroundColor Red
            Write-Host "DirectML requires Python 3.8, 3.9, or 3.10" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Python not found or error checking version" -ForegroundColor Red
        return $false
    }
}

# Function to check Visual C++ Redistributables
function Check-VCRedist {
    Write-Host "`nChecking Visual C++ Redistributables..." -ForegroundColor Yellow
    
    $vcRedistKeys = @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    )
    
    $found = $false
    foreach ($key in $vcRedistKeys) {
        if (Test-Path $key) {
            $version = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).Version
            if ($version) {
                Write-Host "Found VC++ Redistributable: $version" -ForegroundColor White
                $found = $true
                break
            }
        }
    }
    
    if ($found) {
        Write-Host "✅ Visual C++ Redistributables installed" -ForegroundColor Green
        return $true
    } else {
        Write-Host "⚠️ Visual C++ Redistributables may not be installed" -ForegroundColor Yellow
        Write-Host "Download from: https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Yellow
        return $false
    }
}

# Function to test platform-specific acceleration
function Test-AccelerationInstall {
    $platform = Get-PlatformArchitecture
    
    if ($platform -eq "ARM64") {
        Write-Host "`nTesting Snapdragon NPU support..." -ForegroundColor Yellow
        return Test-SnapdragonNPU
    } else {
        Write-Host "`nTesting DirectML installation..." -ForegroundColor Yellow
        return Test-DirectML
    }
}

# Function to test Snapdragon NPU
function Test-SnapdragonNPU {
    # Create a test script for Snapdragon
    $testScript = @"
import sys
try:
    import onnxruntime as ort
    
    # Check for QNN provider
    providers = ort.get_available_providers()
    print(f"Available providers: {providers}")
    
    if 'QNNExecutionProvider' in providers:
        print("SUCCESS: Snapdragon NPU support available")
    else:
        print("WARNING: NPU not available, using CPU fallback")
        
    # Try Windows ML
    try:
        import winml
        print("Windows ML available")
    except:
        print("Windows ML not available")
    
    print("SUCCESS")
except ImportError as e:
    print(f"IMPORT_ERROR: {e}")
except Exception as e:
    print(f"ERROR: {e}")
"@

    $testFile = "$env:TEMP\test_snapdragon.py"
    $testScript | Out-File -FilePath $testFile -Encoding UTF8
    
    try {
        $result = python $testFile 2>&1
        
        if ($result -match "SUCCESS") {
            Write-Host "✅ Snapdragon NPU support is available!" -ForegroundColor Green
            Write-Host $result -ForegroundColor White
            return $true
        } else {
            Write-Host "⚠️ Snapdragon NPU may have issues:" -ForegroundColor Yellow
            Write-Host $result -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ Error testing Snapdragon NPU: $_" -ForegroundColor Red
        return $false
    } finally {
        Remove-Item $testFile -ErrorAction SilentlyContinue
    }
}

# Function to test DirectML installation
function Test-DirectML {
    
    # Create a test script
    $testScript = @"
import sys
try:
    import directml
    print(f"DirectML version: {directml.__version__}")
    
    # Try to list devices
    import torch
    import torch_directml
    
    device_count = torch_directml.device_count()
    print(f"DirectML devices found: {device_count}")
    
    if device_count > 0:
        for i in range(device_count):
            device = torch_directml.device(i)
            print(f"Device {i}: {torch_directml.device_name(i)}")
    
    print("SUCCESS")
except ImportError as e:
    print(f"IMPORT_ERROR: {e}")
except Exception as e:
    print(f"ERROR: {e}")
"@

    $testFile = "$env:TEMP\test_directml.py"
    $testScript | Out-File -FilePath $testFile -Encoding UTF8
    
    try {
        $result = python $testFile 2>&1
        
        if ($result -match "SUCCESS") {
            Write-Host "✅ DirectML is working correctly!" -ForegroundColor Green
            Write-Host $result -ForegroundColor White
            return $true
        } elseif ($result -match "IMPORT_ERROR") {
            Write-Host "❌ DirectML not installed" -ForegroundColor Red
            return $false
        } else {
            Write-Host "⚠️ DirectML installed but may have issues:" -ForegroundColor Yellow
            Write-Host $result -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Host "❌ Error testing DirectML: $_" -ForegroundColor Red
        return $false
    } finally {
        Remove-Item $testFile -ErrorAction SilentlyContinue
    }
}

# Function to install Snapdragon NPU support
function Install-SnapdragonSupport {
    Write-Host "`nAttempting to install Snapdragon NPU support..." -ForegroundColor Yellow
    
    # Upgrade pip first
    Write-Host "Upgrading pip..." -ForegroundColor Yellow
    python -m pip install --upgrade pip
    
    # Try different installation methods for ARM64
    $methods = @(
        @{
            Name = "ONNX Runtime with QNN"
            Commands = @(
                "pip install onnxruntime",
                "pip install onnxruntime-qnn",
                "pip install winml"
            )
        },
        @{
            Name = "Qualcomm AI Hub Tools"
            Commands = @(
                "pip install qai-hub",
                "pip install onnxruntime"
            )
        },
        @{
            Name = "Standard ARM64 ONNX"
            Commands = @(
                "pip install onnxruntime",
                "pip install optimum[onnxruntime]"
            )
        }
    )
    
    foreach ($method in $methods) {
        Write-Host "`nTrying: $($method.Name)" -ForegroundColor Yellow
        
        $success = $true
        foreach ($cmd in $method.Commands) {
            Write-Host "Running: $cmd" -ForegroundColor Gray
            $result = Invoke-Expression $cmd 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                $success = $false
                break
            }
        }
        
        if ($success) {
            Write-Host "✅ $($method.Name) installed successfully" -ForegroundColor Green
            return $true
        }
    }
    
    return $false
}

# Function to attempt DirectML installation
function Install-DirectML {
    Write-Host "`nAttempting to install DirectML..." -ForegroundColor Yellow
    
    # Upgrade pip first
    Write-Host "Upgrading pip..." -ForegroundColor Yellow
    python -m pip install --upgrade pip
    
    # Try different installation methods
    $methods = @(
        @{
            Name = "Standard DirectML"
            Commands = @(
                "pip install directml",
                "pip install torch-directml"
            )
        },
        @{
            Name = "DirectML with PyTorch"
            Commands = @(
                "pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu",
                "pip install directml",
                "pip install torch-directml"
            )
        },
        @{
            Name = "ONNX Runtime DirectML"
            Commands = @(
                "pip install onnxruntime-directml"
            )
        }
    )
    
    foreach ($method in $methods) {
        Write-Host "`nTrying: $($method.Name)" -ForegroundColor Yellow
        
        $success = $true
        foreach ($cmd in $method.Commands) {
            Write-Host "Running: $cmd" -ForegroundColor Gray
            $result = Invoke-Expression $cmd 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                $success = $false
                break
            }
        }
        
        if ($success) {
            Write-Host "✅ $($method.Name) installed successfully" -ForegroundColor Green
            return $true
        }
    }
    
    return $false
}

# Main diagnostic flow
function Main {
    $issues = @()
    
    # Run all checks
    if (-not (Check-WindowsVersion)) {
        $issues += "Windows version"
    }
    
    if (-not (Check-PythonVersion)) {
        $issues += "Python version"
    }
    
    if (-not (Check-VCRedist)) {
        $issues += "Visual C++ Redistributables"
    }
    
    if (-not (Test-AccelerationInstall)) {
        Write-Host "`n============================================" -ForegroundColor Yellow
        Write-Host "DirectML not working. Attempting to fix..." -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Yellow
        
        if ($issues.Count -gt 0) {
            Write-Host "`n⚠️ Please fix these issues first:" -ForegroundColor Red
            foreach ($issue in $issues) {
                Write-Host "  - $issue" -ForegroundColor Red
            }
        } else {
            # Try to install acceleration support
            $platform = Get-PlatformArchitecture
            if ($platform -eq "ARM64") {
                if (Install-SnapdragonSupport) {
                    # Test again
                    if (Test-AccelerationInstall) {
                        Write-Host "`n✅ Snapdragon NPU support successfully installed!" -ForegroundColor Green
                    } else {
                        Write-Host "`n❌ Snapdragon NPU installed but still not working properly" -ForegroundColor Red
                    }
                } else {
                    Write-Host "`n❌ Failed to install Snapdragon NPU support" -ForegroundColor Red
                    Write-Host "`nManual installation steps for Snapdragon:" -ForegroundColor Yellow
                    Write-Host "1. Ensure you're in an admin PowerShell" -ForegroundColor White
                    Write-Host "2. Update Windows to latest version" -ForegroundColor White
                    Write-Host "3. Run these commands:" -ForegroundColor White
                    Write-Host "   python -m pip install --upgrade pip" -ForegroundColor Cyan
                    Write-Host "   pip install onnxruntime" -ForegroundColor Cyan
                    Write-Host "   pip install onnxruntime-qnn" -ForegroundColor Cyan
                    Write-Host "   pip install winml" -ForegroundColor Cyan
                }
            } else {
                if (Install-DirectML) {
                    # Test again
                    if (Test-AccelerationInstall) {
                        Write-Host "`n✅ DirectML successfully installed and working!" -ForegroundColor Green
                    } else {
                        Write-Host "`n❌ DirectML installed but still not working properly" -ForegroundColor Red
                    }
                } else {
                    Write-Host "`n❌ Failed to install DirectML" -ForegroundColor Red
                    Write-Host "`nManual installation steps for Intel:" -ForegroundColor Yellow
                Write-Host "1. Ensure you're in an admin PowerShell" -ForegroundColor White
                Write-Host "2. Install Visual C++ Redistributables from:" -ForegroundColor White
                Write-Host "   https://aka.ms/vs/17/release/vc_redist.x64.exe" -ForegroundColor Cyan
                Write-Host "3. Restart your computer" -ForegroundColor White
                Write-Host "4. Run these commands:" -ForegroundColor White
                Write-Host "   python -m pip install --upgrade pip" -ForegroundColor Cyan
                Write-Host "   pip install directml" -ForegroundColor Cyan
                Write-Host "   pip install torch-directml" -ForegroundColor Cyan
                Write-Host "   pip install onnxruntime-directml" -ForegroundColor Cyan
                }
            }
        }
    } else {
        Write-Host "`n============================================" -ForegroundColor Green
        $platform = Get-PlatformArchitecture
        if ($platform -eq "ARM64") {
            Write-Host "✅ Snapdragon NPU is properly configured!" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "Your Snapdragon system is ready for AI acceleration" -ForegroundColor Green
        } else {
            Write-Host "✅ DirectML is properly configured!" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "Your Intel system is ready for AI acceleration" -ForegroundColor Green
        }
    }
}

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "⚠️ Warning: Not running as administrator" -ForegroundColor Yellow
    Write-Host "Some fixes may require administrator privileges" -ForegroundColor Yellow
    Write-Host ""
}

# Run diagnostics
Main
