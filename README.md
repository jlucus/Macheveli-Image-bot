# Modal AI Logo Generator + Discord Bot

AI-powered logo generator using Modal for GPU compute and Discord for user interaction.

## 📁 Project Structure

```
modal-logo-bot/                    # Project root (recommended: ~/projects/modal-logo-bot)
├── README.md                       # This file
├── .env                           # Environment variables (DO NOT COMMIT)
├── .gitignore                     # Git ignore file
├── requirements.txt               # Python dependencies
├── discord_logo_bot.py            # Discord bot main file
├── logo_generator.py              # Modal app definition
├── venv/                          # Python virtual environment (DO NOT COMMIT)
├── scripts/                       # Automation scripts
│   ├── README.md                  # Scripts documentation
│   ├── deploy.sh                  # Git deployment script
│   └── stat.sh                    # Modal setup script
├── modal_project/                 # Modal app directory
│   ├── src/
│   │   └── logo_generator.py      # Modal GPU function
│   ├── output/                    # Generated logos
│   └── logs/                      # Application logs
└── logs/                          # Setup script logs
```

## 💻 Hardware Requirements

### Recommended Specs (Local Development)
- **CPU:** 4+ cores (Intel i5/Ryzen 5 or better)
- **RAM:** 8GB minimum, 16GB recommended
- **Storage:** 10GB free space (for dependencies and models)
- **GPU:** Not required (computation runs on Modal's cloud GPUs)
- **Network:** Stable internet connection

### Modal Cloud GPU (Production)
The bot uses Modal's serverless GPU infrastructure:
- **GPU:** H100, A100, or T4 (configurable in `logo_generator.py`)
- **Memory:** 40GB+ VRAM for H100
- **Cost:** Pay-per-use serverless pricing
- **Scaling:** Automatic scaling based on demand

### Discord Bot Server
- **CPU:** 2+ cores
- **RAM:** 2GB minimum (bot process is lightweight)
- **Storage:** 2GB for dependencies
- **Network:** Low latency connection to Discord API

**Note:** The heavy AI computation happens on Modal's cloud GPUs, so your local machine only needs to run the Discord bot client.

---

## 🐧 Linux Installation Path

**Recommended location:**
```bash
~/projects/modal-logo-bot
```

**Or:**
```bash
/opt/modal-logo-bot  # System-wide installation
```

**Setup commands:**
```bash
# Create project directory
mkdir -p ~/projects/modal-logo-bot
cd ~/projects/modal-logo-bot

# Clone or copy your files here
# Then follow setup instructions below
```

## 🚀 Quick Start with Scripts

**Automated setup (recommended):**
```bash
# First-time setup
./scripts/stat.sh

# Future updates
./scripts/deploy.sh
```

**See [scripts/README.md](scripts/README.md) for detailed script documentation.**

---

## 🚀 Setup Instructions

### 1. Environment Setup

Create `.env` file:
```bash
DISCORD_APP_ID=your-app-id
DISCORD_PUBLIC_KEY=your-public-key
DISCORD_INSTALL_LINK=your-invite-url
DISCORD_BOT_TOKE=your-bot-token
MODAL_SERVER=ta-01KBQAEXXVA0D12EGEFZP3HXDM
```

### 2. Install Dependencies

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # Linux/Mac
# OR
venv\Scripts\activate     # Windows

# Install packages
pip install -r requirements.txt
```

### 3. Modal Setup

```bash
# Authenticate with Modal
modal token new

# Deploy the Modal app
cd modal_project/src
modal deploy logo_generator.py
```

### 4. Discord Bot Setup

#### Get Discord Credentials:
1. Go to https://discord.com/developers/applications
2. Create New Application
3. Go to "Bot" tab → Reset Token → Copy token
4. Enable these intents:
   - Message Content Intent
   - Server Members Intent (optional)

#### Invite Bot:
1. Go to "OAuth2" → "URL Generator"
2. Select scopes: `bot`, `applications.commands`
3. Select permissions:
   - Send Messages
   - Attach Files
   - Embed Links
   - Use Slash Commands
4. Copy URL and open in browser to add bot to server

### 5. Run the Bot

```bash
# From project root
python discord_logo_bot.py
```

## 📝 Usage

In Discord, use:
```
/logo prompt: Your logo description here
/logo prompt: Cyberpunk dragon logo style: Gaming
```

## 🛠️ Dependencies

- **Python 3.8+**
- **Discord.py** - Discord bot framework
- **Modal** - Serverless GPU compute
- **python-dotenv** - Environment variable management
- **Pillow** - Image processing
- **torch** - PyTorch for AI models
- **vllm** - Efficient LLM inference

## 📦 Key Files

### `discord_logo_bot.py`
Discord bot that receives commands and calls Modal functions.

### `logo_generator.py`
Modal app with GPU-accelerated logo generation function.

### `stat.sh`
Bash script for automated setup in Modal environments.

### `.env`
Environment variables (secrets). **Never commit this file!**

## 🔧 Troubleshooting

### Modal Connection Issues
```bash
# Check Modal authentication
modal token list

# Verify deployed apps
modal app list
```

### Discord Bot Not Responding
- Check bot token in .env
- Verify bot has proper permissions
- Check bot is in your server
- Run with `python -u discord_logo_bot.py` for unbuffered output

### Import Errors
```bash
# Reinstall dependencies
pip install -r requirements.txt --force-reinstall
```

## 🔐 Security Notes

- Never commit `.env` file
- Keep Discord bot token secret
- Use environment variables for all secrets
- Add `venv/`, `.env`, `*.log` to `.gitignore`

## 📄 License

[Your License Here]

## 🤝 Contributing

[Your contribution guidelines]

## 📧 Contact

[Your contact info]

---

**Generated with Modal + Discord.py**
