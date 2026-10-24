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

    $solutionsDir = Join-Path -Path $PSScriptRoot -ChildPath "Solutions"
    if (-not (Test-Path $solutionsDir)) {
        New-Item -ItemType Directory -Path $solutionsDir -Force | Out-Null
    }

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $parentDir = [System.IO.Path]::GetDirectoryName((Resolve-Path $FilePath))
    $targetPath = $FilePath

    # If file is outside Solutions/, auto-move it into Solutions/
    if (-not $parentDir.StartsWith($solutionsDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        $targetPath = Join-Path -Path $solutionsDir -ChildPath $fileName
        Write-Host "[*] Auto-moving solution: $fileName -> Solutions/$fileName" -ForegroundColor Cyan
        Move-Item -Path $FilePath -Destination $targetPath -Force
        git add -A -- "$FilePath" "$targetPath" 2>&1 | Out-Null
    }

    $probName = if ($CustomProblem) { $CustomProblem } else { [System.IO.Path]::GetFileNameWithoutExtension($targetPath) }
    
    # Try reading problem title from header comments
    if (-not $CustomProblem) {
        try {
            $lines = Get-Content -Path $targetPath -TotalCount 30 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                if ($line -match "(?i)(?:problem\s*(?:name|title|code)?|task|title)\s*[:=-]\s*(.+)") {
                    $matched = $matches[1].Trim(" *#/-`t`r`n")
                    $matched = $matched -replace "\s*\*\/.*$", ""
                    if ($matched.Length -gt 0) {
                        $probName = $matched.Trim()
                        break
                    }
                }
                if ($line -match "(?i)codeforces\.com/(?:contest|problemset/problem)/(\d+)/problem/([A-Za-z0-9]+)") {
                    $probName = "$($matches[1])$($matches[2])"
                    break
                }
            }
        } catch {}
    }

    $commitMsg = "Solved problem $probName"

    Write-Host "[*] Staging: $targetPath" -ForegroundColor Cyan
    git add -A -- "$targetPath"
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
