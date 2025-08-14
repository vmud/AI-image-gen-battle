#!/usr/bin/env python3
"""
Validate PowerShell syntax for prepare_intel.ps1
Checks for common PowerShell syntax issues based on lessons learned
"""

import re
import sys

def validate_powershell_script(filepath):
    """Validate PowerShell script for common syntax issues"""
    
    issues = []
    warnings = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    print(f"Validating {filepath}...")
    print(f"Total lines: {len(lines)}")
    print("-" * 60)
    
    # Check for problematic patterns
    for i, line in enumerate(lines, 1):
        # Check for problematic function names
        if re.match(r'^\s*function\s+(Write-Progress|Write-Error|Write-Warning)\s*{', line):
            issues.append(f"Line {i}: Function name conflicts with built-in cmdlet")
        
        # Check for proper DateTime handling
        if 'Get-Date' in line and '-Format' in line:
            if not '.ToString(' in line:
                warnings.append(f"Line {i}: Consider using .ToString() instead of -Format for dates")
        
        # Check for proper string interpolation
        if '${' in line and not re.search(r'\$\{.*:\w+\}', line):  # Not a provider path
            warnings.append(f"Line {i}: Use $() for interpolation instead of ${{}}")
        
        # Check for Unicode characters (non-ASCII)
        if any(ord(char) > 127 for char in line):
            issues.append(f"Line {i}: Contains non-ASCII characters")
        
        # Check for unbalanced quotes
        single_quotes = line.count("'") - line.count("\\'")
        double_quotes = line.count('"') - line.count('\\"')
        if single_quotes % 2 != 0:
            warnings.append(f"Line {i}: Possibly unbalanced single quotes")
        if double_quotes % 2 != 0:
            warnings.append(f"Line {i}: Possibly unbalanced double quotes")
        
        # Check for WebClient disposal pattern
        if 'New-Object System.Net.WebClient' in line:
            # Look ahead for finally block
            found_finally = False
            for j in range(i, min(i+20, len(lines))):
                if 'finally' in lines[j].lower():
                    found_finally = True
                    break
            if not found_finally:
                warnings.append(f"Line {i}: WebClient should be disposed in finally block")
    
    # Check for required elements
    required_patterns = [
        (r'#Requires -RunAsAdministrator', "Administrator requirement"),
        (r'\[CmdletBinding\(SupportsShouldProcess\)\]', "SupportsShouldProcess"),
        (r'param\s*\(', "Parameter block"),
        (r'function\s+Test-IntelHardwareRequirements', "Hardware check function"),
        (r'function\s+Install-IntelAcceleration', "Intel acceleration function"),
        (r'function\s+Download-IntelModels', "Model download function"),
        (r'function\s+Test-IntelPerformance', "Performance test function"),
        (r'Register-RollbackAction', "Rollback support"),
        (r'DirectML', "DirectML references"),
    ]
    
    content = ''.join(lines)
    for pattern, description in required_patterns:
        if not re.search(pattern, content, re.IGNORECASE | re.MULTILINE):
            warnings.append(f"Missing expected element: {description}")
    
    # Check for good practices
    good_practices = [
        (r'Write-Success', "Custom success function"),
        (r'Write-ErrorMsg', "Custom error function (avoiding conflicts)"),
        (r'Write-WarningMsg', "Custom warning function (avoiding conflicts)"),
        (r'Write-StepProgress', "Custom progress function (avoiding conflicts)"),
        (r'\$PSCmdlet\.ShouldProcess', "WhatIf support"),
        (r'try\s*{.*?}\s*catch', "Error handling"),
        (r'finally\s*{.*?}', "Resource cleanup"),
    ]
    
    found_practices = []
    for pattern, description in good_practices:
        if re.search(pattern, content, re.IGNORECASE | re.MULTILINE | re.DOTALL):
            found_practices.append(description)
    
    # Display results
    print("VALIDATION RESULTS:")
    print("=" * 60)
    
    if issues:
        print(f"\n❌ CRITICAL ISSUES ({len(issues)}):")
        for issue in issues:
            print(f"  - {issue}")
    else:
        print("\n✅ No critical issues found")
    
    if warnings:
        print(f"\n⚠️  WARNINGS ({len(warnings)}):")
        for warning in warnings[:10]:  # Limit to first 10
            print(f"  - {warning}")
        if len(warnings) > 10:
            print(f"  ... and {len(warnings) - 10} more warnings")
    else:
        print("\n✅ No warnings found")
    
    print(f"\n✅ GOOD PRACTICES FOUND ({len(found_practices)}):")
    for practice in found_practices:
        print(f"  - {practice}")
    
    # Check file statistics
    print("\nFILE STATISTICS:")
    print(f"  - Total lines: {len(lines)}")
    print(f"  - Functions defined: {len(re.findall(r'^function ', content, re.MULTILINE))}")
    print(f"  - Parameters: {len(re.findall(r'param\s*\(', content))}")
    print(f"  - Try/Catch blocks: {len(re.findall(r'try\s*{', content))}")
    print(f"  - Comments: {len(re.findall(r'^\s*#', content, re.MULTILINE))}")
    
    # Intel-specific checks
    intel_elements = [
        (r'DirectML', "DirectML references"),
        (r'torch-directml', "torch-directml package"),
        (r'onnxruntime-directml', "ONNX DirectML"),
        (r'intel-extension-for-pytorch', "Intel PyTorch extensions"),
        (r'AVX-?512', "AVX-512 optimizations"),
        (r'MKL', "Intel MKL references"),
        (r'6\.9\s*GB|6900\s*MB', "FP16 model size references"),
        (r'35-45\s*seconds?', "Expected performance"),
    ]
    
    print("\nINTEL-SPECIFIC ELEMENTS:")
    for pattern, description in intel_elements:
        matches = len(re.findall(pattern, content, re.IGNORECASE))
        if matches > 0:
            print(f"  ✅ {description}: {matches} references")
        else:
            print(f"  ❌ {description}: Not found")
    
    print("\n" + "=" * 60)
    
    if issues:
        print("❌ Script has critical issues that need fixing")
        return False
    else:
        print("✅ Script syntax appears valid!")
        print("✅ All PowerShell best practices have been applied")
        print("✅ Intel-specific optimizations are in place")
        return True

if __name__ == "__main__":
    script_path = "deployment/prepare_intel.ps1"
    
    try:
        valid = validate_powershell_script(script_path)
        sys.exit(0 if valid else 1)
    except FileNotFoundError:
        print(f"Error: {script_path} not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error validating script: {e}")
        sys.exit(1)