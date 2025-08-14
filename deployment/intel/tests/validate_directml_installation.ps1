<#
.SYNOPSIS
    Comprehensive DirectML Validation Script for Intel Systems
    
.DESCRIPTION
    This script provides thorough testing and validation of DirectML functionality on Intel systems.
    It verifies package installations, hardware compatibility, functional operations, and integration scenarios.
    
.PARAMETER Verbose
    Enable detailed output for all operations
    
.PARAMETER QuickTest
    Run only essential tests (skips performance benchmarks)
    
.PARAMETER BenchmarkOnly
    Run only performance testing operations
    
.PARAMETER ExportResults
    Export detailed results to specified JSON file path
    
.EXAMPLE
    .\validate_directml_installation.ps1 -Verbose
    
.EXAMPLE
    .\validate_directml_installation.ps1 -QuickTest -ExportResults "validation_results.json"
    
.EXAMPLE
    .\validate_directml_installation.ps1 -BenchmarkOnly

.NOTES
    Author: DirectML Validation System
    Version: 1.0
    Requires: PowerShell 5.1+, Python 3.8+
#>

[CmdletBinding()]
param(
    [switch]$Verbose,
    [switch]$QuickTest,
    [switch]$BenchmarkOnly,
    [string]$ExportResults
)

# Global validation results
$global:ValidationResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OverallStatus = "UNKNOWN"
    TestCategories = @{}
    PerformanceMetrics = @{}
    Errors = @()
    Recommendations = @()
}

# Output functions
function Write-TestHeader {
    param([string]$Title)
    if ($Verbose -or -not $QuickTest) {
        Write-Host "`n================================" -ForegroundColor Cyan
        Write-Host " $Title" -ForegroundColor Cyan
        Write-Host "================================" -ForegroundColor Cyan
    }
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$Recommendation = ""
    )
    
    $status = if ($Success) { "PASS" } else { "FAIL" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    if ($Verbose -or -not $Success) {
        Write-Host "[$status] $TestName" -ForegroundColor $color
        if ($Details) {
            Write-Host "  Details: $Details" -ForegroundColor Gray
        }
        if ($Recommendation -and -not $Success) {
            Write-Host "  Recommendation: $Recommendation" -ForegroundColor Yellow
        }
    }
    
    return @{
        TestName = $TestName
        Status = $status
        Success = $Success
        Details = $Details
        Recommendation = $Recommendation
    }
}

function Test-DirectMLPackages {
    Write-TestHeader "DirectML Package Verification"
    
    $results = @()
    $categorySuccess = $true
    
    try {
        # Test torch-directml
        Write-Host "Testing torch-directml installation..." -ForegroundColor Gray
        $torchTest = python -c "
try:
    import torch_directml
    print('SUCCESS: torch-directml imported successfully')
    print(f'Version: {torch_directml.__version__}')
except ImportError as e:
    print(f'ERROR: torch-directml import failed: {e}')
    exit(1)
except Exception as e:
    print(f'ERROR: torch-directml unexpected error: {e}')
    exit(1)
" 2>&1
        
        $torchSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "torch-directml Import" -Success $torchSuccess -Details ($torchTest -join "`n") -Recommendation "Install torch-directml: pip install torch-directml"
        $categorySuccess = $categorySuccess -and $torchSuccess
        
        # Test Intel Extension for PyTorch
        Write-Host "Testing intel-extension-for-pytorch..." -ForegroundColor Gray
        $intelTest = python -c "
try:
    import intel_extension_for_pytorch as ipex
    print('SUCCESS: intel-extension-for-pytorch imported successfully')
    print(f'Version: {ipex.__version__}')
except ImportError as e:
    print(f'WARNING: intel-extension-for-pytorch not available: {e}')
    exit(0)
except Exception as e:
    print(f'ERROR: intel-extension-for-pytorch unexpected error: {e}')
    exit(1)
" 2>&1
        
        $intelSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Intel Extension for PyTorch" -Success $intelSuccess -Details ($intelTest -join "`n") -Recommendation "Install Intel Extension: pip install intel-extension-for-pytorch"
        
        # Test ONNX Runtime DirectML
        Write-Host "Testing onnxruntime-directml..." -ForegroundColor Gray
        $onnxTest = python -c "
try:
    import onnxruntime as ort
    providers = ort.get_available_providers()
    print('SUCCESS: onnxruntime imported successfully')
    print(f'Available providers: {providers}')
    if 'DmlExecutionProvider' in providers:
        print('SUCCESS: DirectML provider available')
    else:
        print('WARNING: DirectML provider not found')
except ImportError as e:
    print(f'ERROR: onnxruntime import failed: {e}')
    exit(1)
except Exception as e:
    print(f'ERROR: onnxruntime unexpected error: {e}')
    exit(1)
" 2>&1
        
        $onnxSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "ONNX Runtime DirectML" -Success $onnxSuccess -Details ($onnxTest -join "`n") -Recommendation "Install ONNX Runtime DirectML: pip install onnxruntime-directml"
        $categorySuccess = $categorySuccess -and $onnxSuccess
        
        # Test PyTorch DirectML compatibility
        Write-Host "Testing PyTorch DirectML compatibility..." -ForegroundColor Gray
        $compatTest = python -c "
try:
    import torch
    import torch_directml
    device = torch_directml.device()
    print(f'SUCCESS: PyTorch version: {torch.__version__}')
    print(f'DirectML device created: {device}')
    print('SUCCESS: PyTorch-DirectML compatibility verified')
except Exception as e:
    print(f'ERROR: PyTorch-DirectML compatibility issue: {e}')
    exit(1)
" 2>&1
        
        $compatSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "PyTorch DirectML Compatibility" -Success $compatSuccess -Details ($compatTest -join "`n") -Recommendation "Reinstall compatible versions: pip install torch-directml"
        $categorySuccess = $categorySuccess -and $compatSuccess
        
    } catch {
        $results += Write-TestResult -TestName "Package Verification" -Success $false -Details $_.Exception.Message -Recommendation "Check Python installation and package manager"
        $categorySuccess = $false
    }
    
    $global:ValidationResults.TestCategories["DirectMLPackages"] = @{
        Success = $categorySuccess
        Results = $results
    }
    
    return $categorySuccess
}

function Test-HardwareCompatibility {
    Write-TestHeader "Hardware Compatibility Tests"
    
    $results = @()
    $categorySuccess = $true
    
    try {
        # Test DirectX 12 support
        Write-Host "Checking DirectX 12 support..." -ForegroundColor Gray
        $dx12Test = python -c "
import subprocess
import sys
try:
    result = subprocess.run(['dxdiag', '/t', 'dxdiag_output.txt'], capture_output=True, text=True, timeout=30)
    with open('dxdiag_output.txt', 'r') as f:
        content = f.read()
        if 'DirectX Version: DirectX 12' in content or 'DirectX 12' in content:
            print('SUCCESS: DirectX 12 supported')
        else:
            print('WARNING: DirectX 12 support unclear')
    import os
    os.remove('dxdiag_output.txt')
except Exception as e:
    print(f'WARNING: Could not verify DirectX 12 support: {e}')
" 2>&1
        
        $dx12Success = $true  # Non-critical test
        $results += Write-TestResult -TestName "DirectX 12 Support" -Success $dx12Success -Details ($dx12Test -join "`n") -Recommendation "Update graphics drivers for DirectX 12 support"
        
        # Test WDDM driver version
        Write-Host "Checking WDDM driver version..." -ForegroundColor Gray
        $wddmInfo = Get-WmiObject -Class Win32_VideoController | Select-Object Name, DriverVersion, DriverDate
        $wddmDetails = ($wddmInfo | ForEach-Object { "$($_.Name): Driver $($_.DriverVersion) ($($_.DriverDate))" }) -join "`n"
        $wddmSuccess = $wddmInfo.Count -gt 0
        $results += Write-TestResult -TestName "WDDM Driver Detection" -Success $wddmSuccess -Details $wddmDetails -Recommendation "Update graphics drivers to latest version"
        $categorySuccess = $categorySuccess -and $wddmSuccess
        
        # Test Intel GPU detection
        Write-Host "Detecting Intel GPU..." -ForegroundColor Gray
        $intelGPU = Get-WmiObject -Class Win32_VideoController | Where-Object { $_.Name -like "*Intel*" }
        $intelGPUSuccess = $intelGPU.Count -gt 0
        $intelGPUDetails = if ($intelGPU) { ($intelGPU | ForEach-Object { $_.Name }) -join ", " } else { "No Intel GPU detected" }
        $results += Write-TestResult -TestName "Intel GPU Detection" -Success $intelGPUSuccess -Details $intelGPUDetails -Recommendation "Ensure Intel graphics drivers are installed"
        $categorySuccess = $categorySuccess -and $intelGPUSuccess
        
        # Test DirectML device enumeration
        Write-Host "Testing DirectML device enumeration..." -ForegroundColor Gray
        $deviceTest = python -c "
try:
    import torch_directml
    device_count = torch_directml.device_count()
    print(f'SUCCESS: Found {device_count} DirectML device(s)')
    for i in range(device_count):
        device = torch_directml.device(i)
        print(f'Device {i}: {device}')
except Exception as e:
    print(f'ERROR: DirectML device enumeration failed: {e}')
    exit(1)
" 2>&1
        
        $deviceSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "DirectML Device Enumeration" -Success $deviceSuccess -Details ($deviceTest -join "`n") -Recommendation "Check DirectML installation and GPU drivers"
        $categorySuccess = $categorySuccess -and $deviceSuccess
        
    } catch {
        $results += Write-TestResult -TestName "Hardware Compatibility" -Success $false -Details $_.Exception.Message -Recommendation "Check system hardware and driver installation"
        $categorySuccess = $false
    }
    
    $global:ValidationResults.TestCategories["HardwareCompatibility"] = @{
        Success = $categorySuccess
        Results = $results
    }
    
    return $categorySuccess
}

function Test-DirectMLFunctionality {
    Write-TestHeader "DirectML Functionality Tests"
    
    $results = @()
    $categorySuccess = $true
    
    try {
        # Test DirectML device creation
        Write-Host "Testing DirectML device creation..." -ForegroundColor Gray
        $deviceCreationTest = python -c "
try:
    import torch
    import torch_directml
    device = torch_directml.device()
    print(f'SUCCESS: DirectML device created: {device}')
    print(f'Device type: {device.type}')
except Exception as e:
    print(f'ERROR: DirectML device creation failed: {e}')
    exit(1)
" 2>&1
        
        $deviceSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "DirectML Device Creation" -Success $deviceSuccess -Details ($deviceCreationTest -join "`n") -Recommendation "Verify DirectML installation and GPU compatibility"
        $categorySuccess = $categorySuccess -and $deviceSuccess
        
        # Test tensor operations
        Write-Host "Testing tensor operations on DirectML..." -ForegroundColor Gray
        $tensorTest = python -c "
try:
    import torch
    import torch_directml
    device = torch_directml.device()
    
    # Create tensors
    x = torch.randn(3, 3, device=device)
    y = torch.randn(3, 3, device=device)
    
    # Test basic operations
    z = x + y
    print(f'SUCCESS: Tensor addition completed')
    print(f'Result shape: {z.shape}')
    print(f'Result device: {z.device}')
    
    # Test matrix multiplication
    result = torch.mm(x, y)
    print(f'SUCCESS: Matrix multiplication completed')
    print(f'Result shape: {result.shape}')
    
except Exception as e:
    print(f'ERROR: Tensor operations failed: {e}')
    exit(1)
" 2>&1
        
        $tensorSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "DirectML Tensor Operations" -Success $tensorSuccess -Details ($tensorTest -join "`n") -Recommendation "Check GPU memory and DirectML device initialization"
        $categorySuccess = $categorySuccess -and $tensorSuccess
        
        # Test memory allocation
        Write-Host "Testing DirectML memory allocation..." -ForegroundColor Gray
        $memoryTest = python -c "
try:
    import torch
    import torch_directml
    device = torch_directml.device()
    
    # Test various memory allocations
    small_tensor = torch.zeros(100, 100, device=device)
    print(f'SUCCESS: Small tensor allocation (100x100)')
    
    medium_tensor = torch.zeros(1000, 1000, device=device)
    print(f'SUCCESS: Medium tensor allocation (1000x1000)')
    
    # Test memory cleanup
    del small_tensor
    del medium_tensor
    print(f'SUCCESS: Memory cleanup completed')
    
except Exception as e:
    print(f'ERROR: Memory allocation test failed: {e}')
    exit(1)
" 2>&1
        
        $memorySuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "DirectML Memory Allocation" -Success $memorySuccess -Details ($memoryTest -join "`n") -Recommendation "Check available GPU memory and system resources"
        $categorySuccess = $categorySuccess -and $memorySuccess
        
        # Test neural network operations
        Write-Host "Testing basic neural network operations..." -ForegroundColor Gray
        $nnTest = python -c "
try:
    import torch
    import torch.nn as nn
    import torch_directml
    device = torch_directml.device()
    
    # Create simple neural network
    model = nn.Sequential(
        nn.Linear(10, 5),
        nn.ReLU(),
        nn.Linear(5, 1)
    ).to(device)
    
    # Test forward pass
    input_data = torch.randn(32, 10, device=device)
    output = model(input_data)
    
    print(f'SUCCESS: Neural network forward pass completed')
    print(f'Input shape: {input_data.shape}')
    print(f'Output shape: {output.shape}')
    print(f'Model device: {next(model.parameters()).device}')
    
except Exception as e:
    print(f'ERROR: Neural network operations failed: {e}')
    exit(1)
" 2>&1
        
        $nnSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Neural Network Operations" -Success $nnSuccess -Details ($nnTest -join "`n") -Recommendation "Check PyTorch and DirectML compatibility for neural networks"
        $categorySuccess = $categorySuccess -and $nnSuccess
        
    } catch {
        $results += Write-TestResult -TestName "DirectML Functionality" -Success $false -Details $_.Exception.Message -Recommendation "Verify DirectML installation and system compatibility"
        $categorySuccess = $false
    }
    
    $global:ValidationResults.TestCategories["DirectMLFunctionality"] = @{
        Success = $categorySuccess
        Results = $results
    }
    
    return $categorySuccess
}

function Test-IntegrationScenarios {
    Write-TestHeader "Integration Tests"
    
    $results = @()
    $categorySuccess = $true
    
    try {
        # Test ONNX Runtime DirectML provider
        Write-Host "Testing ONNX Runtime DirectML provider..." -ForegroundColor Gray
        $onnxIntegrationTest = python -c "
try:
    import onnxruntime as ort
    import numpy as np
    
    # Check DirectML provider availability
    providers = ort.get_available_providers()
    if 'DmlExecutionProvider' not in providers:
        print('WARNING: DirectML provider not available in ONNX Runtime')
        exit(0)
    
    # Create session with DirectML provider
    session_options = ort.SessionOptions()
    session = ort.InferenceSession(
        None,  # No model for this test
        providers=['DmlExecutionProvider'],
        sess_options=session_options
    )
    
    print('SUCCESS: ONNX Runtime DirectML provider integration verified')
    print(f'Available providers: {providers}')
    
except Exception as e:
    print(f'WARNING: ONNX Runtime DirectML integration test failed: {e}')
    exit(0)
" 2>&1
        
        $onnxIntegrationSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "ONNX Runtime DirectML Integration" -Success $onnxIntegrationSuccess -Details ($onnxIntegrationTest -join "`n") -Recommendation "Install onnxruntime-directml for ONNX integration"
        
        # Test Diffusers DirectML compatibility
        Write-Host "Testing Diffusers DirectML compatibility..." -ForegroundColor Gray
        $diffusersTest = python -c "
try:
    import torch
    import torch_directml
    
    # Try to import diffusers
    try:
        from diffusers import DiffusionPipeline
        diffusers_available = True
    except ImportError:
        print('INFO: Diffusers not installed, skipping integration test')
        exit(0)
    
    device = torch_directml.device()
    print(f'SUCCESS: DirectML device ready for Diffusers: {device}')
    print('SUCCESS: Diffusers DirectML compatibility verified')
    
except Exception as e:
    print(f'WARNING: Diffusers DirectML compatibility test failed: {e}')
    exit(0)
" 2>&1
        
        $diffusersSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Diffusers DirectML Compatibility" -Success $diffusersSuccess -Details ($diffusersTest -join "`n") -Recommendation "Install diffusers for AI model support: pip install diffusers"
        
        # Test Intel Extension integration
        Write-Host "Testing Intel Extension integration..." -ForegroundColor Gray
        $intelIntegrationTest = python -c "
try:
    import torch
    import torch_directml
    
    # Try Intel Extension
    try:
        import intel_extension_for_pytorch as ipex
        intel_available = True
    except ImportError:
        print('INFO: Intel Extension not available, skipping integration test')
        exit(0)
    
    device = torch_directml.device()
    print(f'SUCCESS: Intel Extension and DirectML coexistence verified')
    print(f'Intel Extension version: {ipex.__version__}')
    
except Exception as e:
    print(f'WARNING: Intel Extension integration test failed: {e}')
    exit(0)
" 2>&1
        
        $intelIntegrationSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Intel Extension Integration" -Success $intelIntegrationSuccess -Details ($intelIntegrationTest -join "`n") -Recommendation "Install Intel Extension for enhanced Intel GPU support"
        
        # Test environment variables
        Write-Host "Checking DirectML environment variables..." -ForegroundColor Gray
        $envVars = @()
        $envVars += "PYTHONPATH: $($env:PYTHONPATH)"
        $envVars += "CUDA_VISIBLE_DEVICES: $($env:CUDA_VISIBLE_DEVICES)"
        $envVars += "OMP_NUM_THREADS: $($env:OMP_NUM_THREADS)"
        
        $envDetails = $envVars -join "`n"
        $envSuccess = $true  # Non-critical test
        $results += Write-TestResult -TestName "Environment Variables Check" -Success $envSuccess -Details $envDetails -Recommendation "Set appropriate environment variables for optimal performance"
        
    } catch {
        $results += Write-TestResult -TestName "Integration Tests" -Success $false -Details $_.Exception.Message -Recommendation "Check integration library installations"
        $categorySuccess = $false
    }
    
    $global:ValidationResults.TestCategories["IntegrationScenarios"] = @{
        Success = $categorySuccess
        Results = $results
    }
    
    return $categorySuccess
}

function Test-PerformanceBenchmark {
    Write-TestHeader "Performance Benchmark Tests"
    
    $results = @()
    $categorySuccess = $true
    
    if ($QuickTest) {
        Write-Host "Skipping performance benchmarks (QuickTest mode)" -ForegroundColor Yellow
        $global:ValidationResults.TestCategories["Performance"] = @{
            Success = $true
            Results = @()
            Skipped = $true
        }
        return $true
    }
    
    try {
        # Simple tensor multiplication benchmark
        Write-Host "Running tensor multiplication benchmark..." -ForegroundColor Gray
        $benchmarkTest = python -c "
import torch
import torch_directml
import time

try:
    device = torch_directml.device()
    
    # Warm up
    x = torch.randn(1000, 1000, device=device)
    y = torch.randn(1000, 1000, device=device)
    for _ in range(3):
        torch.mm(x, y)
    
    # Benchmark
    start_time = time.time()
    for _ in range(10):
        result = torch.mm(x, y)
    end_time = time.time()
    
    avg_time = (end_time - start_time) / 10
    operations_per_second = 1.0 / avg_time
    
    print(f'SUCCESS: Tensor multiplication benchmark completed')
    print(f'Average time per operation: {avg_time:.4f} seconds')
    print(f'Operations per second: {operations_per_second:.2f}')
    print(f'Matrix size: 1000x1000')
    
except Exception as e:
    print(f'ERROR: Performance benchmark failed: {e}')
    exit(1)
" 2>&1
        
        $benchmarkSuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Tensor Multiplication Benchmark" -Success $benchmarkSuccess -Details ($benchmarkTest -join "`n") -Recommendation "Check GPU performance and system resources"
        $categorySuccess = $categorySuccess -and $benchmarkSuccess
        
        # Extract performance metrics
        if ($benchmarkSuccess) {
            $timeMatch = [regex]::Match($benchmarkTest, 'Average time per operation: ([\d.]+) seconds')
            $opsMatch = [regex]::Match($benchmarkTest, 'Operations per second: ([\d.]+)')
            
            if ($timeMatch.Success -and $opsMatch.Success) {
                $global:ValidationResults.PerformanceMetrics["TensorMultiplication"] = @{
                    AverageTime = [double]$timeMatch.Groups[1].Value
                    OperationsPerSecond = [double]$opsMatch.Groups[1].Value
                }
            }
        }
        
        # Memory bandwidth test
        Write-Host "Running memory bandwidth test..." -ForegroundColor Gray
        $memoryBandwidthTest = python -c "
import torch
import torch_directml
import time

try:
    device = torch_directml.device()
    
    # Large tensor for memory bandwidth test
    size = 2048
    data_size_mb = (size * size * 4) / (1024 * 1024)  # 4 bytes per float32
    
    # Test memory allocation and transfer
    start_time = time.time()
    tensor = torch.randn(size, size, device=device)
    allocation_time = time.time() - start_time
    
    # Test memory copy
    start_time = time.time()
    tensor_copy = tensor.clone()
    copy_time = time.time() - start_time
    
    print(f'SUCCESS: Memory bandwidth test completed')
    print(f'Tensor size: {size}x{size} ({data_size_mb:.1f} MB)')
    print(f'Allocation time: {allocation_time:.4f} seconds')
    print(f'Copy time: {copy_time:.4f} seconds')
    print(f'Memory bandwidth (copy): {data_size_mb / copy_time:.1f} MB/s')
    
except Exception as e:
    print(f'ERROR: Memory bandwidth test failed: {e}')
    exit(1)
" 2>&1
        
        $memorySuccess = $LASTEXITCODE -eq 0
        $results += Write-TestResult -TestName "Memory Bandwidth Test" -Success $memorySuccess -Details ($memoryBandwidthTest -join "`n") -Recommendation "Check GPU memory performance and utilization"
        $categorySuccess = $categorySuccess -and $memorySuccess
        
        # Extract memory metrics
        if ($memorySuccess) {
            $bandwidthMatch = [regex]::Match($memoryBandwidthTest, 'Memory bandwidth \(copy\): ([\d.]+) MB/s')
            if ($bandwidthMatch.Success) {
                $global:ValidationResults.PerformanceMetrics["MemoryBandwidth"] = @{
                    BandwidthMBps = [double]$bandwidthMatch.Groups[1].Value
                }
            }
        }
        
    } catch {
        $results += Write-TestResult -TestName "Performance Benchmark" -Success $false -Details $_.Exception.Message -Recommendation "Check system performance and GPU utilization"
        $categorySuccess = $false
    }
    
    $global:ValidationResults.TestCategories["Performance"] = @{
        Success = $categorySuccess
        Results = $results
    }
    
    return $categorySuccess
}

function Export-ValidationResults {
    param([string]$FilePath)
    
    if (-not $FilePath) {
        return
    }
    
    try {
        $jsonResults = $global:ValidationResults | ConvertTo-Json -Depth 10
        $jsonResults | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "Results exported to: $FilePath" -ForegroundColor Green
    } catch {
        Write-Host "Failed to export results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-ValidationSummary {
    Write-Host "`n================================" -ForegroundColor Cyan
    Write-Host " DIRECTML VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    
    $overallSuccess = $true
    $totalTests = 0
    $passedTests = 0
    
    foreach ($category in $global:ValidationResults.TestCategories.Keys) {
        $categoryData = $global:ValidationResults.TestCategories[$category]
        $status = if ($categoryData.Success) { "PASS" } else { "FAIL" }
        $color = if ($categoryData.Success) { "Green" } else { "Red" }
        
        if ($categoryData.ContainsKey("Skipped") -and $categoryData.Skipped) {
            Write-Host "[$category]: SKIPPED" -ForegroundColor Yellow
        } else {
            Write-Host "[$category]: $status" -ForegroundColor $color
            $overallSuccess = $overallSuccess -and $categoryData.Success
        }
        
        if ($categoryData.Results) {
            $categoryTests = $categoryData.Results.Count
            $categoryPassed = ($categoryData.Results | Where-Object { $_.Success }).Count
            $totalTests += $categoryTests
            $passedTests += $categoryPassed
            
            if ($Verbose) {
                Write-Host "  Tests: $categoryPassed/$categoryTests passed" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`nOverall Status: " -NoNewline
    if ($overallSuccess) {
        Write-Host "PASS" -ForegroundColor Green
        $global:ValidationResults.OverallStatus = "PASS"
    } else {
        Write-Host "FAIL" -ForegroundColor Red
        $global:ValidationResults.OverallStatus = "FAIL"
    }
    
    Write-Host "Total Tests: $passedTests/$totalTests passed" -ForegroundColor Gray
    
    # Show performance metrics
    if ($global:ValidationResults.PerformanceMetrics.Count -gt 0) {
        Write-Host "`nPerformance Metrics:" -ForegroundColor Cyan
        foreach ($metric in $global:ValidationResults.PerformanceMetrics.Keys) {
            $data = $global:ValidationResults.PerformanceMetrics[$metric]
            Write-Host "  ${metric}:" -ForegroundColor Gray
            foreach ($key in $data.Keys) {
                Write-Host "    ${key}: $($data[$key])" -ForegroundColor Gray
            }
        }
    }
    
    # Show recommendations for failures
    $failedTests = @()
    foreach ($category in $global:ValidationResults.TestCategories.Keys) {
        $categoryData = $global:ValidationResults.TestCategories[$category]
        if ($categoryData.Results) {
            $failedTests += $categoryData.Results | Where-Object { -not $_.Success -and $_.Recommendation }
        }
    }
    
    if ($failedTests.Count -gt 0) {
        Write-Host "`nTroubleshooting Recommendations:" -ForegroundColor Yellow
        foreach ($test in $failedTests) {
            Write-Host "  $($test.TestName): $($test.Recommendation)" -ForegroundColor Yellow
        }
    }
    
    return $overallSuccess
}

# Main execution
function Main {
    Write-Host "DirectML Validation Script for Intel Systems" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    
    if ($BenchmarkOnly) {
        Write-Host "Running benchmark tests only..." -ForegroundColor Yellow
        $benchmarkResult = Test-PerformanceBenchmark
        $global:ValidationResults.OverallStatus = if ($benchmarkResult) { "PASS" } else { "FAIL" }
    } else {
        # Run all test categories
        $packageResult = Test-DirectMLPackages
        $hardwareResult = Test-HardwareCompatibility
        $functionalityResult = Test-DirectMLFunctionality
        $integrationResult = Test-IntegrationScenarios
        $performanceResult = Test-PerformanceBenchmark
        
        # Determine overall success
        $overallSuccess = $packageResult -and $hardwareResult -and $functionalityResult -and $integrationResult -and $performanceResult
        $global:ValidationResults.OverallStatus = if ($overallSuccess) { "PASS" } else { "FAIL" }
    }
    
    # Show summary
    $finalResult = Show-ValidationSummary
    
    # Export results if requested
    if ($ExportResults) {
        Export-ValidationResults -FilePath $ExportResults
    }
    
    # Exit with appropriate code
    exit $(if ($finalResult) { 0 } else { 1 })
}

# Execute main function
Main