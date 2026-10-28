<#
.SYNOPSIS
    Silent background file watcher for Codeforces C++ solutions.
    Automatically commits and pushes changes when any .cpp file is saved.
#>

$watchPath = Split-Path -Parent $PSScriptRoot
if (-not $watchPath) {
    $watchPath = (Get-Location).Path
}

# Ensure Git is accessible
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
        $env:Path += ";C:\Program Files\Git\cmd"
    }
}

Write-Host "[Watcher Active] Watching for .cpp changes in $watchPath..." -ForegroundColor Cyan

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchPath
$watcher.Filter = "*.cpp"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size

$lastHandled = @{}
$debounceSeconds = 1.5

$action = {
    $filePath = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # Exclude internal directories
    if ($filePath -match "\\\.git\\" -or $filePath -match "\\\.cph\\" -or $filePath -match "\\\.vscode\\") {
        return
    }

    # Only process .cpp files
    if (-not $filePath.EndsWith(".cpp", [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $now = Get-Date
    if ($lastHandled.ContainsKey($filePath)) {
        $span = ($now - $lastHandled[$filePath]).TotalSeconds
        if ($span -lt $debounceSeconds) {
            return
        }
    }
    $lastHandled[$filePath] = $now

    # Small delay for editor file write buffer
    Start-Sleep -Milliseconds 400

    if (Test-Path $filePath) {
        Set-Location $watchPath
        git add . 2>&1 | Out-Null
        $status = git status --porcelain 2>&1
        if ($status) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Change detected in $fileName. Committing and pushing..." -ForegroundColor Green
            git commit -m "Solved Codeforces problem" 2>&1 | Out-Null
            $pushOutput = git push origin main 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Successfully pushed to GitHub main." -ForegroundColor Green
            } else {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Push output: $pushOutput" -ForegroundColor Yellow
            }
        }
    }
}

$createdEvent = Register-ObjectEvent $watcher 'Created' -Action $action
$changedEvent = Register-ObjectEvent $watcher 'Changed' -Action $action

Write-Host "[Watcher Ready] Auto Git Push On Save is active." -ForegroundColor Green

try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Unregister-Event -SourceIdentifier $createdEvent.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $changedEvent.Name -ErrorAction SilentlyContinue
    $watcher.Dispose()
    Write-Host "[Watcher Stopped] Auto Git Push On Save terminated." -ForegroundColor Yellow
}
