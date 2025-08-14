# Setup Monitor Script
# Run this in a separate PowerShell window to watch setup progress

param(
    [string]$LogPath = "C:\AIDemo\setup.log"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AI Demo Setup Monitor" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Monitoring log file: $LogPath" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Gray
Write-Host ""

# Wait for log file to be created
while (-not (Test-Path $LogPath)) {
    Write-Host "Waiting for setup to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
}

Write-Host "Setup started! Monitoring progress..." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Gray

# Monitor the log file
$lastPosition = 0

while ($true) {
    try {
        if (Test-Path $LogPath) {
            $fileStream = [System.IO.FileStream]::new($LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $fileStream.Seek($lastPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
            
            $reader = [System.IO.StreamReader]::new($fileStream)
            
            while (-not $reader.EndOfStream) {
                $line = $reader.ReadLine()
                if ($line) {
                    # Color code based on content
                    if ($line -match "ERROR|❌|Failed") {
                        Write-Host $line -ForegroundColor Red
                    } elseif ($line -match "WARNING|⚠️|Warning") {
                        Write-Host $line -ForegroundColor Yellow
                    } elseif ($line -match "SUCCESS|✅|completed|installed") {
                        Write-Host $line -ForegroundColor Green
                    } elseif ($line -match "🔍|🔧|📥|⬇️|🐍|📁|🌐") {
                        Write-Host $line -ForegroundColor Cyan
                    } else {
                        Write-Host $line -ForegroundColor White
                    }
                }
            }
            
            $lastPosition = $fileStream.Position
            $reader.Close()
            $fileStream.Close()
        }
        
        Start-Sleep -Seconds 1
        
    } catch {
        # File might be locked, just continue
        Start-Sleep -Seconds 1
    }
}