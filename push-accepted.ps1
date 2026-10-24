<#
.SYNOPSIS
    Commits and pushes an Accepted Codeforces solution file to GitHub.

.DESCRIPTION
    Stages the specified file (or all modified/untracked solution files),
    creates a descriptive commit message with problem details and timestamp,
    and pushes to the main branch.

.PARAMETER File
    Path to the solution file to commit (e.g. .\4A.cpp). If omitted, scans for changed solution files.

.PARAMETER Problem
    Optional custom problem name / ID (e.g. "4A - Watermelon").

.PARAMETER Branch
    Target Git branch (default: main).

.PARAMETER Remote
    Target Git remote (default: origin).

.EXAMPLE
    .\push-accepted.ps1 -File 4A.cpp
    .\push-accepted.ps1 -File 71A.cpp -Problem "71A - Way Too Long Words"
    .\push-accepted.ps1
#>

[CmdletBinding()]
param (
    [string]$File = "",
    [string]$Problem = "",
    [string]$Branch = "main",
    [string]$Remote = "origin"
)

# Ensure Git is in PATH
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
        $env:Path += ";C:\Program Files\Git\cmd"
    }
}

function Push-SingleFile {
    param ([string]$FilePath, [string]$CustomProblem)

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $probName = if ($CustomProblem) { $CustomProblem } else { $fileName }
    
    # Try reading problem title from header comments
    if (-not $CustomProblem) {
        try {
            $lines = Get-Content -Path $FilePath -TotalCount 15 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match "(?i)problem\s*(?:name|title|code)?\s*:\s*(.+)") {
                    $probName = $matches[1].Trim(" *#/-\t")
                    break
                }
            }
        } catch {}
    }

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $commitMsg = "Solve Codeforces: $probName [Accepted] - $timestamp"

    Write-Host "[*] Staging: $FilePath" -ForegroundColor Cyan
    git add -- "$FilePath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to stage $FilePath"
        return
    }

    $status = git status --porcelain "$FilePath"
    if (-not $status) {
        Write-Host "[!] No uncommitted changes detected for $FilePath" -ForegroundColor Yellow
        return
    }

    Write-Host "[*] Committing: '$commitMsg'" -ForegroundColor Green
    git commit -m "$commitMsg"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git commit failed."
        return
    }

    Write-Host "[*] Pushing to $Remote/$Branch..." -ForegroundColor Cyan
    $pushRes = git push $Remote $Branch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[SUCCESS] Pushed successfully to $Remote/$Branch!" -ForegroundColor Green
    } else {
        Write-Host "[!] Push notice: git push returned an error." -ForegroundColor Yellow
        Write-Host "    $pushRes" -ForegroundColor DarkGray
        Write-Host "    (Your commit is saved locally in Git. When your remote repository is configured, push will succeed!)" -ForegroundColor Gray
    }
}

if ($File) {
    Push-SingleFile -FilePath $File -CustomProblem $Problem
} else {
    Write-Host "Scanning for modified solution files..." -ForegroundColor Cyan
    $changed = git status --porcelain | ForEach-Object {
        $parts = $_.Trim().Split(" ", 2)
        if ($parts.Count -ge 2) { $parts[1].Trim() }
    } | Where-Object {
        $_ -match '\.(cpp|cc|cxx|c|py|java|rs|go)$'
    }

    if (-not $changed) {
        Write-Host "No changed solution files found to commit." -ForegroundColor Yellow
        exit 0
    }

    foreach ($f in $changed) {
        Push-SingleFile -FilePath $f -CustomProblem ""
    }
}
