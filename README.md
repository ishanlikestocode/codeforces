# Codeforces Solutions 🚀

A streamlined repository for C++ Competitive Programming solutions with native VS Code background Git auto-push on save.

---

## ⚡ Native VS Code Auto-Push on Save

Whenever you save any C++ file (`Ctrl+S`), VS Code automatically and silently executes:
```bash
git add .
git commit -m "Solved Codeforces problem"
git push origin main
```
- **Silent Background Execution**: Runs without keeping any terminal windows open or popping up terminal panels.
- **C++ Exclusive**: Triggers specifically for C++ files (`.cpp`).
- **No External Scripts**: No Python or PowerShell background scripts required to be running in terminal.

---

## 📁 Repository Structure

```text
Codeforces-Solutions/
├── Solutions/                       # Solution files
│   └── D_Difference.cpp
├── H_Data_Type_Guessing.cpp         # Solution files
├── H_Two_numbers.cpp
├── .vscode/
│   ├── settings.json                # Workspace C++ & Git settings
│   ├── tasks.json                   # Native silent Git push task & C++ build tasks
│   └── launch.json                  # C++ GDB debug configurations
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
