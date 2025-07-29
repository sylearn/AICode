# 🤖 AI Utility Scripts Collection
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](https://github.com)
[![Shell](https://img.shields.io/badge/Shell-Bash%20%7C%20PowerShell-green.svg)](https://github.com)

[🇨🇳 Chinese](./README_CN.md) | [🇺🇸 English](./README.md)

A comprehensive collection of practical AI-related scripts designed to simplify AI development workflows and automate common tasks.

## 🔧 Claude Code Automated Deployment Tool

### 🚀 Features Overview

This is a toolset for automating the deployment of Claude Code and Claude Code Proxy, with support for:

- ✅ **Auto Dependency Installation** - Detects and installs uv, npm, and Claude Code
- 🔄 **Proxy Service Management** - Automatically installs and configures Claude Code Proxy
- 🚀 **One-Click Start** - Configures environment variables and starts the services
- ⚡ **Port Conflict Handling** - Intelligently detects and resolves port occupation issues
- 🔧 **Configuration Management** - Automatically configures the .env file and environment variables
- 🌐 **Cross-Platform Support** - Supports Windows, macOS, and Linux

### 🖥️ System Support

| System | Script File | Description |
|---|---|---|
| 🐧 **Linux/macOS** | `Claude_code_proxy.sh` | Bash script for Unix-like systems |
| 🪟 **Windows** | `Claude_code_proxy.ps1` | PowerShell script for Windows |

## 🚀 Quick Start

### 1. Clone the Project

```bash
git clone https://github.com/sylearn/AICode.git
cd AICode/Claude_Code
```

### 2. Run the Script

#### For Linux/macOS

```bash
# Grant execution permission to the script
chmod +x Claude_code_proxy.sh

# Run the script
./Claude_code_proxy.sh
```

#### For Windows

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the script
.\Claude_code_proxy.ps1
```

### 3. Follow the Prompts to Complete Configuration

The script will automatically detect your environment and guide you through the configuration process.

## 💡 Features

### 🔍 Automatic Environment Detection

- Checks if Node.js and npm are installed
- Checks if the Python package manager uv is installed
- Checks if Claude Code is already installed
- Checks if Git is available

### 📦 Automatic Dependency Installation

- **uv Installation**: Automatically installs the Python package manager from the official source
- **Claude Code Installation**: Installs Claude Code globally via npm
- **Proxy Service Installation**: Automatically clones and configures Claude Code Proxy

### 🔧 Smart Configuration Management

- Automatically generates and updates the `.env` configuration file
- Intelligently detects the local IP address
- Automatically configures proxy server parameters
- Supports custom model and API configurations

### ⚡ Port Conflict Handling

- Automatically detects port usage status
- Intelligently identifies and terminates conflicting processes
- Supports interactive user choices for handling conflicts

## 📋 System Requirements

### Basic Requirements

- **Operating System**: Windows 10+, macOS 10.14+, Linux (Ubuntu 18.04+)
- **Network**: A stable internet connection
- **Permissions**: Administrator privileges (for installing dependencies)

### Software Dependencies

| Software | Version Requirement | Auto-Install | Notes |
|---|---|---|---|
| Node.js | 16.0+ | ❌ | Requires manual installation |
| npm | 8.0+ | ✅ | Installed with Node.js |
| Git | 2.0+ | ❌ | Requires manual installation |
| uv | Latest | ✅ | Script will install automatically |
| Claude Code | Latest | ✅ | Script will install automatically |

## 🛠️ Detailed Usage Instructions

### First Time Use

1.  **Prepare Your Environment**
    -   Ensure Node.js and Git are installed
    -   Have your OpenAI API Key ready
    -   Have your API Base URL ready

2.  **Run the Script**
    -   Download and run the script for your operating system
    -   The script will auto-detect the environment and install any missing dependencies

3.  **Configure Parameters**
    -   The script will prompt you to enter API configuration details
    -   Alternatively, you can directly modify the configuration variables at the top of the script

### Subsequent Use

If initialization is complete, simply run the script to start the services:

```bash
# Linux/macOS
./Claude_code_proxy.sh

# Windows
.\Claude_code_proxy.ps1
```

### Stopping the Services

Press `Ctrl+C` to stop the Claude Code client, and the proxy service will stop automatically.

## ⚙️ Configuration Details

### Main Configuration Parameters

#### Basic Configuration

```bash
# Script Configuration Area (at the top of the script file)
CLAUDE_COMMAND="claude"                    # Claude Code command name
CLAUDE_DIR="$HOME/.claude"                 # Claude Code configuration directory
PROXY_PORT=8082                           # Proxy service port
```

#### API Configuration

```bash
# API-related configuration
OPENAI_API_KEY="your-api-key-here"        # Your OpenAI API Key
OPENAI_BASE_URL="https://api.openai.com/v1" # API Base URL
BIG_MODEL="claude-sonnet-4"               # Large model name
SMALL_MODEL="gpt-4o-mini"                 # Small model name
```

#### Proxy Configuration

```bash
# Proxy service configuration
HOST="0.0.0.0"                           # Service listening address
MAX_TOKENS_LIMIT=32000                    # Max token limit（< 32000）
REQUEST_TIMEOUT=90                        # Request timeout
MAX_RETRIES=3                            # Max retries
```

### Environment Variables

The script will automatically set the following environment variables:

- `CLAUDE_CODE_MAX_OUTPUT_TOKENS`: Max output tokens
- `ANTHROPIC_BASE_URL`: Proxy service address
- `ANTHROPIC_AUTH_TOKEN`: Proxy authentication token

## 🔧 Troubleshooting

### Common Issues

#### 1. Permission Issues

**Issue**: Permission denied error during dependency installation

**Solution**:
```bash
# Linux/macOS
sudo ./Claude_code_proxy.sh

# Windows (Run PowerShell as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 2. API Error
**Issue**: API Error (401 Invalid API key)
```log
[L] API Error (401 {"detail":"Invalid API key. Please provide a valid Anthropic API key."}) Retrying in 1 second
...
2025-07-14 16:03:56,450 - WARNING - Invalid API key provided by client
```

**Solution**:
```bash
# Check your .env file
cat ~/.claude/proxy/claude-code-proxy/.env
```
Comment out `ANTHROPIC_API_KEY="your-expected-anthropic-api-key"`
or manually navigate to the `~/.claude/proxy/claude-code-proxy` directory and comment out the `ANTHROPIC_API_KEY` line in the `.env` file.


### Debug Mode

To enable debugging, you can change the log level in the script:

```bash
LOG_LEVEL="DEBUG"  # Change the log level to DEBUG
```

### Manual Cleanup

If you need to perform a complete reinstallation:

```bash
# Clean up Claude Code Proxy
rm -rf ~/.claude/proxy

# Reinstall Claude Code
npm uninstall -g @anthropic-ai/claude-code
npm install -g @anthropic-ai/claude-code
```

## 📁 Project Structure

```
AICode/
├── Claude_Code/
│   ├── Claude_code_proxy.sh      # Linux/macOS script
│   └── Claude_code_proxy.ps1     # Windows script
├── README.md                     # English documentation
├── README_CN.md                  # Chinese documentation
├── License                       # MIT License
└── .gitignore                    # Git ignore file
```

## 🤝 Contribution Guide

We welcome your contributions! Please follow these steps:

1.  Fork this repository
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=sylearn/AICode&type=Date)](https://star-history.com/#sylearn/AICode&Date)

---

**Thank you for your support! 🙏**
