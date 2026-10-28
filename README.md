# Codeforces Solutions 🚀

A streamlined repository for C++ Competitive Programming solutions with native VS Code background Git auto-push on save.

---

## ⚡ Native VS Code Auto-Push on Save

- **Automatic Startup**: Whenever VS Code opens this directory, the background task `"Auto Git Push On Save"` launches silently in the background (`"runOn": "folderOpen"`).
- **Triggers on Save (`Ctrl+S`)**: Whenever any `.cpp` file in this workspace is saved, the background watcher immediately runs:
  ```bash
  git add .
  git commit -m "Solved Codeforces problem"
  git push origin main
  ```
- **Silent & Unobtrusive**: Runs in the background without keeping any manual terminal windows open or stealing focus.

---

## 🛡️ Microsoft Defender Exclusion Command

To permanently prevent Windows Defender from scanning or locking your compiled executables (`*.exe`), Git binaries, and CPH test runners, run this single command in **PowerShell as Administrator**:

```powershell
Add-MpPreference -ExclusionPath "C:\Users\ISHAN AHMED\OneDrive\Desktop\DSA\Codeforces-Solutions"
```

---

## 📁 Repository Structure

```text
Codeforces-Solutions/
├── Solutions/                       # Solution files
│   ├── D_Difference.cpp
│   └── A_Watermelon.cpp
├── H_Data_Type_Guessing.cpp         # Solution files
├── H_Two_numbers.cpp
├── .vscode/
│   ├── settings.json                # Automatic task permission & C++ settings
│   ├── tasks.json                   # "Auto Git Push On Save" background startup task & compiler tasks
│   ├── launch.json                  # C++ GDB debug configurations
│   └── watcher.ps1                  # Internal watcher process
├── .gitignore                       # Ignores executables (.exe, .out) and CPH cache
└── README.md
```

---

## 🔗 Remote Link

Connected to:
```text
https://github.com/ishanlikestocode/codeforces.git
```
Branch: `main`
