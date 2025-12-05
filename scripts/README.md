# Scripts Directory

Automation scripts for the Modal Logo Bot project.

## 📜 Available Scripts

### `deploy.sh`
**Git deployment and update script**

Handles:
- Fetching latest changes from git origin
- Pulling updates from remote repository
- Installing/updating Python dependencies
- Restarting the Discord bot
- Logging all operations

**Usage:**
```bash
./scripts/deploy.sh
```

**Interactive prompts:**
- Pull latest changes? (y/n)
- Update dependencies? (y/n)
- Start Discord bot? (y/n)

**Logs:** `logs/deploy-YYYYMMDD_HHMMSS.log`

---

### `stat.sh`
**Modal environment setup and initialization script**

Handles:
- System requirements validation
- Virtual environment creation
- Modal SDK installation
- Dependency installation (torch, discord.py, etc.)
- Modal authentication checks
- Project structure creation
- Modal app deployment

**Usage:**
```bash
./scripts/stat.sh
```

**Logs:** `logs/modal-logo-gen-YYYYMMDD_HHMMSS.log`

---

## 🚀 Quick Start

### First-time setup:
```bash
# 1. Run setup script
./scripts/stat.sh

# 2. Configure environment
cp .env.example .env
# Edit .env with your credentials

# 3. Deploy Modal app
cd modal_project/src
modal deploy logo_generator.py
```

### Regular updates:
```bash
# Fetch and deploy latest changes
./scripts/deploy.sh
```

---

## 📁 Script Locations

```
scripts/
├── README.md          # This file
├── deploy.sh          # Git deployment script
└── stat.sh           # Modal setup script
```

---

## 🔧 Making Scripts Executable

If scripts aren't executable:
```bash
chmod +x scripts/*.sh
```

---

## 📝 Creating Custom Scripts

To add your own scripts:
1. Create script in `scripts/` directory
2. Add shebang: `#!/bin/bash`
3. Make executable: `chmod +x scripts/your-script.sh`
4. Document in this README

---

## 🐛 Troubleshooting

### Permission denied
```bash
chmod +x scripts/*.sh
```

### Script not found
```bash
# Use relative path from project root
./scripts/deploy.sh

# Or absolute path
bash /full/path/to/scripts/deploy.sh
```

### Git errors in deploy.sh
- Ensure git is initialized: `git init`
- Add remote: `git remote add origin <url>`
- Check credentials: `git config --list`
