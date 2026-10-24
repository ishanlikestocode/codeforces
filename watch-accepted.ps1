<#
.SYNOPSIS
    Automated Git Watcher for Codeforces Solutions.
    Monitors the repository and automatically commits and pushes code to GitHub
    whenever an Accepted solution file is saved.

.DESCRIPTION
    Watches for .cpp, .cc, .py, .java, .c, .rs, .go files.
    Debounces file save events and checks for Accepted criteria (via header comments,
    filename, directory name, or all saved solutions).
    Stages, commits with an informative message, and pushes to the main branch.

.PARAMETER Branch
    The Git branch to push to. Default: 'main'.

.PARAMETER Remote
    The Git remote name. Default: 'origin'.

.PARAMETER Mode
    'Smart'    : Commits if file contains 'Accepted' / 'AC' or filename has 'Accepted', or unless marked WA/Draft.
    'Accepted' : Only commits if 'Accepted' or 'AC' is explicitly found in content/filename.
    'All'      : Commits any saved solution file regardless of content.
    Default: 'Smart'.

.EXAMPLE
    .\watch-accepted.ps1
    .\watch-accepted.ps1 -Mode All
    .\watch-accepted.ps1 -Branch main -Remote origin
#>

[CmdletBinding()]
param (
    [string]$Branch = "main",
    [string]$Remote = "origin",
    [ValidateSet("Smart", "Accepted", "All")]
    [string]$Mode = "Smart",
    [string]$WatchPath = $PSScriptRoot
)

# Ensure Git is in PATH
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    if (Test-Path "C:\Program Files\Git\cmd\git.exe") {
        $env:Path += ";C:\Program Files\Git\cmd"
    } else {
        Write-Error "Git executable not found in PATH or standard installation directories."
        exit 1
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Codeforces Auto-Commit and Push Watcher" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Watching directory : $WatchPath" -ForegroundColor White
Write-Host " Solutions folder   : Solutions/" -ForegroundColor White
Write-Host " Target branch      : $Branch" -ForegroundColor White
Write-Host " Remote             : $Remote" -ForegroundColor White
Write-Host " Detection mode     : $Mode" -ForegroundColor White
Write-Host " Supported files    : .cpp, .cc, .cxx, .py, .java, .c, .rs, .go" -ForegroundColor Gray
Write-Host " Status             : ACTIVE (Press Ctrl+C to stop)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$supportedExtensions = @(".cpp", ".cc", ".cxx", ".c", ".py", ".java", ".rs", ".go")
$automationScripts = @("watch-accepted.ps1", "watch_accepted.py", "push-accepted.ps1", "README.md", ".gitignore")
$solutionsDir = Join-Path -Path $WatchPath -ChildPath "Solutions"
if (-not (Test-Path $solutionsDir)) {
    New-Item -ItemType Directory -Path $solutionsDir -Force | Out-Null
}

# Auto-organize any existing loose solution files from root into Solutions/
$existingLoose = Get-ChildItem -Path $WatchPath -File -ErrorAction SilentlyContinue | Where-Object {
    $supportedExtensions -contains $_.Extension.ToLower() -and
    $automationScripts -notcontains $_.Name
}
if ($existingLoose) {
    foreach ($item in $existingLoose) {
        $dest = Join-Path -Path $solutionsDir -ChildPath $item.Name
        Write-Host "[*] Organizing: Moving $($item.Name) -> Solutions/" -ForegroundColor Cyan
        Move-Item -Path $item.FullName -Destination $dest -Force
        git add -A -- "$($item.FullName)" "$dest" 2>&1 | Out-Null
    }
}

$lastHandled = @{}
$debounceSeconds = 2

function Test-IsAcceptedFile {
    param (
        [string]$FilePath,
        [string]$CheckMode
    )

    if ($CheckMode -eq "All") {
        return $true
    }

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $fileDir = [System.IO.Path]::GetDirectoryName($FilePath)

    # Check filename and folder name
    if ($fileName -match "(?i)accepted|_ac\b|\bac\b" -or $fileDir -match "(?i)accepted") {
        return $true
    }

    # Inspect file content (first 30 lines)
    if (Test-Path $FilePath) {
        try {
            $lines = Get-Content -Path $FilePath -TotalCount 30 -ErrorAction SilentlyContinue
            $contentSample = ($lines -join "`n")

            if ($contentSample -match "(?i)(wrong answer|\bwa\b|time limit exceeded|\btle\b|runtime error|\bre\b|compilation error|\bdraft\b|\btesting\b)") {
                # File indicates failure / work in progress
                return $false
            }

            if ($contentSample -match "(?i)(verdict:\s*accepted|\bstatus:\s*accepted|\baccepted\b|\baccepted solution|\bverdict\s*:\s*ac\b)") {
                return $true
            }

            # In Smart mode, if no negative indicators were found and file is non-empty, treat as Accepted
            if ($CheckMode -eq "Smart" -and ($lines.Count -ge 3)) {
                return $true
            }
        } catch {
            return $false
        }
    }

    return $false
}

function Get-ProblemIdentifier {
    param ([string]$FilePath)

    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)

    # Try extracting problem title from file header if available (check first 30 lines)
    if (Test-Path $FilePath) {
        try {
            $lines = Get-Content -Path $FilePath -TotalCount 30 -ErrorAction SilentlyContinue
            foreach ($line in $lines) {
                # Matches:
                # // Problem Name: Watermelon
                # // Problem: 4A - Watermelon
                # * Problem Name: A. Watermelon
                # // Task: Watermelon
                # // Title: Watermelon
                # # Problem: Watermelon
                if ($line -match "(?i)(?:problem\s*(?:name|title|code)?|task|title)\s*[:=-]\s*(.+)") {
                    $matched = $matches[1].Trim(" *#/-`t`r`n")
                    # Clean trailing closing comment syntax like */
                    $matched = $matched -replace "\s*\*\/.*$", ""
                    if ($matched.Length -gt 0) {
                        return $matched.Trim()
                    }
                }

                # Check for Codeforces URL like https://codeforces.com/contest/1982/problem/A
                if ($line -match "(?i)codeforces\.com/(?:contest|problemset/problem)/(\d+)/problem/([A-Za-z0-9]+)") {
                    return "$($matches[1])$($matches[2])"
                }
            }
        } catch {}
    }

    # Otherwise fallback to the filename
    return $fileNameWithoutExt
}

function Invoke-GitCommitAndPush {
    param (
        [string]$FilePath
    )

    $relativePath = Resolve-Path -Path $FilePath -Relative -ErrorAction SilentlyContinue
    if (-not $relativePath) {
        $relativePath = $FilePath
    }

    $problemName = Get-ProblemIdentifier -FilePath $FilePath
    $commitMsg = "Solved problem $problemName"

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Detected Accepted solution: $relativePath" -ForegroundColor Green
    Write-Host "  -> Staging file: $relativePath" -ForegroundColor Gray
    
    # Stage changes related to this solution file (including any move/rename)
    $addResult = git add -A -- "$FilePath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!] git add failed: $addResult" -ForegroundColor Red
        return
    }

    # Check if there are changes to commit
    $status = git status --porcelain 2>&1
    if (-not $status) {
        Write-Host "  [*] No changes to commit for $relativePath." -ForegroundColor Yellow
        return
    }

    Write-Host "  -> Committing: '$commitMsg'" -ForegroundColor Cyan
    $commitResult = git commit -m "$commitMsg" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [!] git commit failed: $commitResult" -ForegroundColor Red
        return
    }

    Write-Host "  -> Pushing to $Remote/$Branch..." -ForegroundColor Cyan
    $pushResult = git push $Remote $Branch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [SUCCESS] Successfully pushed to $Remote/$Branch!" -ForegroundColor Green
    } else {
        Write-Host "  [!] Push notice: git push returned an error." -ForegroundColor Yellow
        Write-Host "      Output: $pushResult" -ForegroundColor DarkGray
        Write-Host "      Tip: If your remote URL needs authentication or hasn't been configured," -ForegroundColor Yellow
        Write-Host "      run: git remote set-url $Remote https://github.com/<your-username>/<your-repo>.git" -ForegroundColor Yellow
        Write-Host "      Your commit has been saved safely in your local Git repository." -ForegroundColor Green
    }
    Write-Host ""
}

# Create FileSystemWatcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $WatchPath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileName($path)
    $ext = [System.IO.Path]::GetExtension($path).ToLower()

    # Ignore .git directory, CPH metadata, and VS Code configs
    if ($path -match "\\\.git\\" -or $path -match "\\\.cph\\" -or $path -match "\\\.vscode\\" -or $path -match "\\\.github\\" -or $path -match "\\__pycache__\\") {
        return
    }

    # Keep automation scripts in the main folder - never move or process them as solutions
    if ($automationScripts -contains $fileName) {
        return
    }

    if ($supportedExtensions -notcontains $ext) {
        return
    }

    # Debounce check
    $now = Get-Date
    if ($lastHandled.ContainsKey($path)) {
        $span = ($now - $lastHandled[$path]).TotalSeconds
        if ($span -lt $debounceSeconds) {
            return
        }
    }
    $lastHandled[$path] = $now

    # Small delay to ensure file write buffer is flushed
    Start-Sleep -Milliseconds 400

    if (Test-Path $path) {
        $isAccepted = Test-IsAcceptedFile -FilePath $path -CheckMode $Mode
        if ($isAccepted) {
            $parentDir = [System.IO.Path]::GetDirectoryName($path)
            $targetPath = $path

            # If solution file was saved outside Solutions/, automatically move it into Solutions/
            if (-not $parentDir.StartsWith($solutionsDir, [System.StringComparison]::OrdinalIgnoreCase)) {
                if (-not (Test-Path $solutionsDir)) {
                    New-Item -ItemType Directory -Path $solutionsDir -Force | Out-Null
                }
                $targetPath = Join-Path -Path $solutionsDir -ChildPath $fileName
                Write-Host "  -> Auto-moving solution: $fileName -> Solutions/$fileName" -ForegroundColor Cyan

                # Pre-register destination to prevent duplicate debounce trigger
                $lastHandled[$targetPath] = (Get-Date).AddSeconds(3)
                $lastHandled[$path] = Get-Date

                Move-Item -Path $path -Destination $targetPath -Force

                # Stage deletion of old root path and addition of new Solutions/ path
                git add -A -- "$path" "$targetPath" 2>&1 | Out-Null
            }

            Invoke-GitCommitAndPush -FilePath $targetPath
        }
    }
}

$createdEvent = Register-ObjectEvent $watcher 'Created' -Action $action
$changedEvent = Register-ObjectEvent $watcher 'Changed' -Action $action

try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    Unregister-Event -SourceIdentifier $createdEvent.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $changedEvent.Name -ErrorAction SilentlyContinue
    $watcher.Dispose()
    Write-Host "`nWatcher stopped." -ForegroundColor Yellow
}
