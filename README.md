# Codeforces Solutions 🚀

A structured repository for Codeforces and Competitive Programming solutions with automatic Git commit & push automation.

---

## ⚡ Automated Workflow (Auto-Push on Save)

Whenever you solve a problem and save an **Accepted** solution, the automation script automatically stages the file, creates a formatted commit message (e.g., `Solve Codeforces: 4A - Watermelon [Accepted]`), and pushes it to the `main` branch on GitHub.

### 1. Running the Watcher (PowerShell)
Open a PowerShell terminal in this folder and run:
```powershell
.\watch-accepted.ps1
```
*Options:*
- `.\watch-accepted.ps1 -Mode Smart` *(Default)*: Commits solutions when saved, skipping drafts or failed submissions.
- `.\watch-accepted.ps1 -Mode Accepted`: Only commits if explicitly marked with `Accepted`, `Verdict: Accepted`, or `_AC`.
- `.\watch-accepted.ps1 -Mode All`: Automatically commits and pushes every saved solution file.

### 2. Running the Watcher (Python)
If you prefer running via Python:
```bash
python watch_accepted.py
```
*(Supports `--all` and `--accepted` flags).*

### 3. VS Code One-Click Integration
If you are using VS Code:
- **Start Background Watcher**: Open Command Palette (`Ctrl+Shift+P`) ➔ `Tasks: Run Task` ➔ `Watch & Auto-Push Accepted Solutions`.
- **Commit Current Solution Now**: Open Command Palette (`Ctrl+Shift+P`) ➔ `Tasks: Run Task` ➔ `Commit & Push Current Solution [Accepted]`.

### 4. Manual One-Shot Push
To push a single solution or all pending solutions without keeping the background watcher running:
```powershell
.\push-accepted.ps1 -File "4A.cpp"
# or commit all pending solution changes:
.\push-accepted.ps1
```

---

## 🔗 Linking Your GitHub Repository

The local Git repository is currently initialized on branch `main` and linked to `https://github.com`.

To connect it to your specific GitHub repository (e.g., `https://github.com/<your-username>/Codeforces-Solutions.git`), update the remote URL using:

```bash
git remote set-url origin https://github.com/<your-username>/<your-repo-name>.git
```

To push your initial commit:
```bash
git push -u origin main
```

---

## 📁 Recommended Solution Structure

You can organize your solution files as you prefer:

```text
Codeforces-Solutions/
├── 0800-1000/           # Grouped by difficulty rating
│   ├── 4A_Watermelon.cpp
│   └── 71A_Way_Too_Long_Words.cpp
├── Div2/                # Or grouped by contest division / round
│   └── Round_900/
│       ├── A.cpp
│       └── B.cpp
├── .vscode/             # VS Code task automation
├── .github/workflows/   # CI/CD solution compilation verification
├── .gitignore           # Ignores executables (.exe, .out) and CPH test files
├── watch-accepted.ps1   # PowerShell automation watcher
├── watch_accepted.py    # Python automation watcher
└── push-accepted.ps1    # Manual instant push script
```

---

## 🏷️ Solution File Template (Optional)

Include a problem header in your solution file for automatic commit message formatting:

```cpp
/**
 * Problem Name: 4A - Watermelon
 * Contest: Codeforces Beta Round 4 (Div. 2 Only)
 * Verdict: Accepted
 */

#include <iostream>
using namespace std;

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    int w;
    if (cin >> w) {
        if (w > 2 && w % 2 == 0) {
            cout << "YES\n";
        } else {
            cout << "NO\n";
        }
    }
    return 0;
}
```
