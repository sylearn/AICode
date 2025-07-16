# ==================================================
# Claude Code + Claude Code Proxy Automated Deployment Script
# ==================================================
#
# Features:
# 1. Automatically detect and install necessary dependencies (uv, npm)
# 2. Detect and install Claude Code
# 3. Manage Claude Code Proxy installation, startup and port conflict handling
# 4. Configure proxy environment and start Claude Code
#
# Execution Flow:
# ├── Environment Check
# │   ├── Check if uv is installed (Python package manager)
# │   ├── Check if Claude Code is installed
# │   └── Check npm/Node.js environment
# ├── Claude Code Proxy Management
# │   ├── Check if already installed
# │   ├── Check port usage (default 8082)
# │   ├── Clean conflicting processes
# │   └── Start proxy service
# └── Start Claude Code
#     ├── Configure proxy environment variables
#     └── Start Claude Code client
#
# Notes:
# - Ensure network connection is available for downloading dependencies
# - Script will automatically handle port conflicts
# - Configuration parameters can be modified in the "Settings Section" below
# ==================================================

# UTF-8 Console Encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# === Settings Section: Modify as needed ===
# control command and directory
$CLAUDE_COMMAND = "claude"   # or claude, if you install another version
$CLAUDE_DIR = "$env:USERPROFILE\.claude" # your Claude Code config directory
$CLAUDE_PROXY_DIR = "$env:USERPROFILE\.claude\proxy" # your Claude Code Proxy config directory
$PROXY_PROJECT_DIR = "$CLAUDE_PROXY_DIR\claude-code-proxy" # your Claude Code Proxy project directory
$CURRENT_DIR = Get-Location # current path

$PROXY_PORT = 8082
$OPENAI_API_KEY = "sk-**" # your openai api key
$OPENAI_BASE_URL = "https://api.yourdomain.com/v1" # your openai base url

$BIG_MODEL = "claude-sonnet-4" # big model
$SMALL_MODEL = "gpt-4o-mini" # small model
$MAX_TOKENS_LIMIT = 64000 # max tokens limit    
$ANTHROPIC_AUTH_TOKEN = "api-key" # proxy token, don't change
$LOG_LEVEL = "WARNING" # log level
$REQUEST_TIMEOUT = 120 # request timeout
$MAX_RETRIES = 3 # max retries

# proxy parameters
$PROXY_HOST = "0.0.0.0" # service listen address

# Get local IP address
try {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    if (-not $ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "*Ethernet*" -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
    }
    if (-not $ip) {
        $allIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254.*" }
        if ($allIPs) {
            $ip = $allIPs[0].IPAddress
        } else {
            $ip = "127.0.0.1"
        }
    }
} catch {
    $ip = "127.0.0.1"
}
$ANTHROPIC_BASE_URL = "http://$ip`:$PROXY_PORT" # proxy address
#==================================================
# Function Definitions
#==================================================

# Create a fresh .env file with all required configurations
function New-EnvFile {
    param(
        [string]$FilePath
    )

    Write-Host "Creating fresh .env configuration file..." -ForegroundColor Blue

    # Remove existing .env file if it exists
    if (Test-Path $FilePath) {
        Remove-Item $FilePath -Force
        Write-Host "Removed existing .env file: $FilePath" -ForegroundColor Yellow
    }

    # Create new .env file with all configurations
    $envContent = @(
        "HOST=`"$PROXY_HOST`"",
        "PORT=`"$PROXY_PORT`"",
        "OPENAI_API_KEY=`"$OPENAI_API_KEY`"",
        "OPENAI_BASE_URL=`"$OPENAI_BASE_URL`"",
        "BIG_MODEL=`"$BIG_MODEL`"",
        "SMALL_MODEL=`"$SMALL_MODEL`"",
        "MAX_TOKENS_LIMIT=`"$MAX_TOKENS_LIMIT`"",
        "LOG_LEVEL=`"$LOG_LEVEL`"",
        "REQUEST_TIMEOUT=`"$REQUEST_TIMEOUT`"",
        "MAX_RETRIES=`"$MAX_RETRIES`""
    )

    # Write content to file
    $envContent | Set-Content $FilePath -Encoding UTF8
    Write-Host "Created new .env file: $FilePath" -ForegroundColor Green
    Write-Host "Configuration completed - Big Model: $BIG_MODEL, Max Tokens: $MAX_TOKENS_LIMIT" -ForegroundColor Cyan
}

# Check if port is in use
function Test-PortInUse {
    param([int]$Port)

    try {
        # Get TCP connections on the specified port with LISTENING state
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            # Filter out system processes (PID 0, 4) and invalid processes
            foreach ($conn in $connections) {
                if ($conn.OwningProcess -gt 4) {
                    try {
                        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                        if ($process -and $process.ProcessName -ne "Idle" -and $process.ProcessName -ne "System") {
                            return $true
                        }
                    } catch {
                        continue
                    }
                }
            }
        }
        return $false
    } catch {
        return $false
    }
}

# Get process using the port
function Get-PortProcess {
    param([int]$Port)

    try {
        # Get TCP connections on the specified port with LISTENING state
        $connections = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
        if ($connections) {
            # Filter out system processes (PID 0, 4) and invalid processes
            foreach ($conn in $connections) {
                if ($conn.OwningProcess -gt 4) {
                    try {
                        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                        if ($process -and $process.ProcessName -ne "Idle" -and $process.ProcessName -ne "System") {
                            return $process
                        }
                    } catch {
                        continue
                    }
                }
            }
        }
    } catch {
        return $null
    }
    return $null
}

# Test if proxy service is responding
function Test-ProxyService {
    param([string]$Url)

    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 5 -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

# Display startup banner
Write-Host ""
Write-Host "=================================================================="
Write-Host "         Claude Code + Proxy Deployment Tool"
Write-Host "          Welcome to Enhanced Proxy Manager"
Write-Host "=================================================================="
Write-Host ""

Write-Host "-------------------------------------------------------------"
Write-Host "                   Environment Check"
Write-Host "-------------------------------------------------------------"

Write-Host "Checking if Claude Code is installed..." 
# Check if command exists
try {
    $claudeVersion = & $CLAUDE_COMMAND --version 2>$null
    if ($claudeVersion) {
        Write-Host "$CLAUDE_COMMAND is installed" -ForegroundColor Green
    } else {
        throw "claude not found"
    }
} catch {
    Write-Host "Claude Code not detected, installing via npm..." -ForegroundColor Yellow

    try {
        $npmVersion = npm --version 2>$null
        if (-not $npmVersion) {
            throw "npm not found"
        }
    } catch {
        Write-Host "npm not detected, please install Node.js first" -ForegroundColor Red
        Write-Host "Download from: https://nodejs.org/" -ForegroundColor Yellow
        Read-Host "Press any key to exit"
        exit 1
    }

    Write-Host "Installing Claude Code..." -ForegroundColor Blue
    try {
        npm install -g @anthropic-ai/claude-code
        Write-Host "Claude Code installation completed" -ForegroundColor Green
    } catch {
        Write-Host "Installation failed, please check network or permissions" -ForegroundColor Red
        Write-Host "Try running as administrator" -ForegroundColor Yellow
        Read-Host "Press any key to exit"
        exit 1
    }
}

# Check if uv is installed
Write-Host "Checking if uv is installed..."

try {
    $uvVersion = uv --version 2>$null
    if ($uvVersion) {
        Write-Host "uv is installed" -ForegroundColor Green
    } else {
        throw "uv not detected"
    }
} catch {
    Write-Host "uv not detected, installing via PowerShell..." -ForegroundColor Yellow

    Write-Host "Installing uv via PowerShell..." -ForegroundColor Blue
    try {
        Invoke-RestMethod https://astral.sh/uv/install.ps1 | Invoke-Expression
        # Reload environment variables
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path","Machine")
        $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
        $env:Path = $machinePath + ";" + $userPath
        Write-Host "uv installation completed" -ForegroundColor Green
    } catch {
        Write-Host "uv installation failed, please check network connection" -ForegroundColor Red
        Write-Host "Manual installation: https://docs.astral.sh/uv/getting-started/installation/" -ForegroundColor Yellow
        Read-Host "Press any key to exit"
        exit 1
    }
}

# Check if Git is installed
Write-Host "Checking if Git is installed..."
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "Git is installed" -ForegroundColor Green
    } else {
        throw "Git not detected"
    }
} catch {
    Write-Host "Git not detected, please install Git first" -ForegroundColor Red
    Write-Host "Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Read-Host "Press any key to exit"
    exit 1
}

# Check Claude Code Proxy installation
Write-Host ""
Write-Host "-------------------------------------------------------------"
Write-Host "                  Proxy Service Management"
Write-Host "-------------------------------------------------------------"
Write-Host ""

# git clone https://github.com/fuergaosi233/claude-code-proxy
if (Test-Path $PROXY_PROJECT_DIR) {
    Write-Host "Claude Code Proxy is installed" -ForegroundColor Green

    # Create fresh .env file with current configuration
    $envFile = Join-Path $PROXY_PROJECT_DIR ".env"
    New-EnvFile -FilePath $envFile

    Write-Host "Claude Code Proxy .env configuration completed" -ForegroundColor Green

    # Check if port is in use
    Write-Host "Checking if port $PROXY_PORT is in use..." -ForegroundColor Blue
    if (Test-PortInUse -Port $PROXY_PORT) {
        Write-Host ""
        Write-Host "Port Conflict Warning"
        Write-Host "========================================================"
        $process = Get-PortProcess -Port $PROXY_PORT
        if ($process) {
            Write-Host "Port $PROXY_PORT is occupied by process"
            Write-Host "Process: PID $($process.Id) ($($process.ProcessName))"
        } else {
            Write-Host "Port $PROXY_PORT is in use"
            Write-Host "Process: Unknown"
        }
        Write-Host ""

        $reply = Read-Host "Do you want to terminate the process to free port $PROXY_PORT? (y/n)"
        if ($reply -match "^[Yy]$") {
            Write-Host "Terminating process..." -ForegroundColor Blue 
            try {
                if ($process) {
                    Stop-Process -Id $process.Id -Force
                    Write-Host "Process $($process.Id) terminated, port $PROXY_PORT freed" -ForegroundColor Green
                } else {
                    Write-Host "Unable to terminate process" -ForegroundColor Red
                }
            } catch {
                Write-Host "Unable to terminate process, may need administrator privileges" -ForegroundColor Red
                Write-Host "Solutions:"
                Write-Host "   1. Manually terminate the process"
                Write-Host "   2. Modify PROXY_PORT to use a different port"
                Read-Host "Press any key to exit"
                exit 1
            }
        } else {
            Write-Host "User chose not to terminate process" -ForegroundColor Red
            Write-Host "Optional actions:"
            Write-Host "   1. Manually terminate the process using the port"
            Write-Host "   2. Modify PROXY_PORT to use a different port"
            Write-Host "   3. If it's a previous proxy process, you can start Claude Code directly"
            Write-Host ""
            $startChoice = Read-Host "Do you want to start Claude Code directly? (y/n)"
            if ($startChoice -match "^[Yy]$") {
                Write-Host ""
                Write-Host "Starting Claude Code..." -ForegroundColor Green
                Write-Host "========================================================"
                $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
                $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
                $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN

                # Debug: Display environment variables
                Write-Host "Environment Variables:" -ForegroundColor Magenta
                Write-Host "  CLAUDE_CODE_MAX_OUTPUT_TOKENS = $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS" -ForegroundColor Gray
                Write-Host "  ANTHROPIC_BASE_URL = $env:ANTHROPIC_BASE_URL" -ForegroundColor Gray
                Write-Host "  ANTHROPIC_AUTH_TOKEN = $env:ANTHROPIC_AUTH_TOKEN" -ForegroundColor Gray
                Write-Host ""

                # Start Claude Code with environment variables
                # Set environment variables for current session and start Claude Code
                $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
                $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
                $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN
                & $CLAUDE_COMMAND
                exit 0
            } else {
                exit 1
            }
        }
    } else {
        Write-Host "Port $PROXY_PORT is available" -ForegroundColor Green
    }
    Write-Host ""

    # Run claude-code-proxy
    Write-Host "Starting proxy service and Claude Code..." -ForegroundColor Green
    Write-Host "========================================================"
    Write-Host "    Large model: $BIG_MODEL" -ForegroundColor Cyan
    Write-Host "    Small model: $SMALL_MODEL" -ForegroundColor Cyan
    Write-Host "    Proxy address: $ANTHROPIC_BASE_URL" -ForegroundColor Cyan
    Write-Host "    Max tokens: $MAX_TOKENS_LIMIT" -ForegroundColor Cyan
    Write-Host "    Request timeout: ${REQUEST_TIMEOUT} seconds" -ForegroundColor Magenta
    Write-Host "    Max retries: $MAX_RETRIES" -ForegroundColor Magenta
    Write-Host ""

    # Set environment variables and start proxy service and Claude Code
    $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
    $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
    $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN

    # Debug: Display environment variables
    Write-Host "Environment Variables:" -ForegroundColor Magenta
    Write-Host "  CLAUDE_CODE_MAX_OUTPUT_TOKENS = $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS" -ForegroundColor Gray
    Write-Host "  ANTHROPIC_BASE_URL = $env:ANTHROPIC_BASE_URL" -ForegroundColor Gray
    Write-Host "  ANTHROPIC_AUTH_TOKEN = $env:ANTHROPIC_AUTH_TOKEN" -ForegroundColor Gray
    Write-Host ""

    # Start proxy service (background) then start Claude Code (foreground)
    # Similar to sh script: uv run --directory $PROXY_PROJECT_DIR claude-code-proxy & sleep 1 && CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_TOKENS_LIMIT ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude

    # Method 1: Use Start-Process with proper working directory
    try {
        $proxyProcess = Start-Process -FilePath "uv" -ArgumentList "run", "--directory", $PROXY_PROJECT_DIR, "claude-code-proxy" -WindowStyle Hidden -PassThru
        Write-Host "Proxy service started, PID: $($proxyProcess.Id)" -ForegroundColor Green

        # Wait and verify proxy is running
        Write-Host "Waiting for proxy service initialization..." -ForegroundColor Blue
        Start-Sleep -Seconds 3

        # Check if proxy process is still running
        if (Get-Process -Id $proxyProcess.Id -ErrorAction SilentlyContinue) {
            Write-Host "Proxy service running successfully" -ForegroundColor Green

            # Test if proxy service is responding
            Write-Host "Testing proxy service connectivity..." -ForegroundColor Blue
            if (Test-ProxyService -Url $ANTHROPIC_BASE_URL) {
                Write-Host "Proxy service responding to requests" -ForegroundColor Green
            } else {
                Write-Host "Warning: Proxy service may not be responding yet" -ForegroundColor Yellow
            }
        } else {
            Write-Host "Warning: Proxy process may have exited" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Unable to start proxy via uv, trying alternative method..." -ForegroundColor Yellow
        # Method 2: Change directory and run uv
        $currentLocation = Get-Location
        try {
            Set-Location $PROXY_PROJECT_DIR
            $proxyProcess = Start-Process -FilePath "uv" -ArgumentList "run", "claude-code-proxy" -WindowStyle Hidden -PassThru
            Write-Host "Proxy service started, PID: $($proxyProcess.Id)" -ForegroundColor Green

            # Wait and verify proxy is running
            Write-Host "Waiting for proxy service initialization..." -ForegroundColor Blue
            Start-Sleep -Seconds 3

            # Check if proxy process is still running
            if (Get-Process -Id $proxyProcess.Id -ErrorAction SilentlyContinue) {
                Write-Host "Proxy service running successfully" -ForegroundColor Green
            } else {
                Write-Host "Warning: Proxy process may have exited" -ForegroundColor Yellow
            }
        } finally {
            Set-Location $currentLocation
        }
    }

    Write-Host "Starting Claude Code..." -ForegroundColor Green

    # Start Claude Code with environment variables
    # Set environment variables for current session and start Claude Code
    $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
    $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
    $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN
    & $CLAUDE_COMMAND

} else {
    Write-Host "Claude Code Proxy not detected" -ForegroundColor Red
    Write-Host ""
    Write-Host "-------------------------------------------------------------"
    Write-Host "                  Installation Confirmation"
    Write-Host "-------------------------------------------------------------"
    $INSTALL_PROXY = Read-Host "Do you want to install Claude Code Proxy? (y/n)"
    Write-Host ""
    if ($INSTALL_PROXY -match "^[Yy]$") {
        # Execute git clone in $CLAUDE_PROXY_DIR directory
        Write-Host "Creating proxy directory: $CLAUDE_PROXY_DIR" -ForegroundColor Blue
        if (-not (Test-Path $CLAUDE_PROXY_DIR)) {
            New-Item -ItemType Directory -Path $CLAUDE_PROXY_DIR -Force | Out-Null
        }

        Write-Host "Cloning Claude Code Proxy project..." -ForegroundColor Blue
        try {
            Set-Location $CLAUDE_PROXY_DIR
            git clone https://github.com/fuergaosi233/claude-code-proxy.git

            Write-Host "Entering project directory and initializing..." -ForegroundColor Blue
            Set-Location $PROXY_PROJECT_DIR

            & uv sync

            # Create fresh .env file with all configurations
            $envFile = Join-Path $PROXY_PROJECT_DIR ".env"
            New-EnvFile -FilePath $envFile

            Write-Host "Claude Code Proxy configuration completed" -ForegroundColor Green

            # Return to original directory to ensure proper execution context
            Set-Location $CURRENT_DIR
        } catch {
            Write-Host "Error occurred during installation: $($_.Exception.Message)" -ForegroundColor Red
            Set-Location $CURRENT_DIR
            Read-Host "Press any key to exit"
            exit 1
        }

        # Check if port is being used
        Write-Host "Checking if port $PROXY_PORT is in use..." -ForegroundColor Blue
        if (Test-PortInUse -Port $PROXY_PORT) {
            Write-Host ""
            Write-Host "Port Conflict Warning" -ForegroundColor Yellow

            $process = Get-PortProcess -Port $PROXY_PORT
            if ($process) {
                Write-Host "Port $PROXY_PORT is occupied by process" -ForegroundColor Yellow
                Write-Host "Process: PID $($process.Id) ($($process.ProcessName))" -ForegroundColor Yellow
            } else {
                Write-Host "Port $PROXY_PORT is in use" -ForegroundColor Yellow
                Write-Host "Process: Unknown" -ForegroundColor Yellow
            }
            Write-Host ""

            $reply = Read-Host "Do you want to terminate the process to free port $PROXY_PORT? (y/n)"
            if ($reply -match "^[Yy]$") {
                Write-Host "Terminating process..." -ForegroundColor Blue
                try {
                    if ($process) {
                        Stop-Process -Id $process.Id -Force
                        Write-Host "Process $($process.Id) terminated, port $PROXY_PORT freed" -ForegroundColor Green
                    } else {
                        Write-Host "Unable to terminate process" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "Unable to terminate process, may need administrator privileges" -ForegroundColor Red
                    Write-Host "Please manually terminate the process or use a different port" -ForegroundColor Yellow
                    Read-Host "Press any key to exit"
                    exit 1
                }
            } else {
                Write-Host "User chose not to terminate process, skipping installation" -ForegroundColor Red
                Read-Host "Press any key to exit"
                exit 1
            }
        } else {
            Write-Host "Port $PROXY_PORT is available" -ForegroundColor Green
        }
        Write-Host ""

        # Run claude-code-proxy
        Write-Host ""
        Write-Host "========================================================"
        Write-Host "           Starting Proxy Service and Claude Code"
        Write-Host "========================================================"
        Write-Host "    Large model: $BIG_MODEL" -ForegroundColor Cyan
        Write-Host "    Small model: $SMALL_MODEL" -ForegroundColor Cyan
        Write-Host "    Proxy address: $ANTHROPIC_BASE_URL" -ForegroundColor Cyan
        Write-Host "    Max tokens: $MAX_TOKENS_LIMIT" -ForegroundColor Cyan
        Write-Host "    Request timeout: ${REQUEST_TIMEOUT} seconds" -ForegroundColor Magenta
        Write-Host "    Max retries: $MAX_RETRIES" -ForegroundColor Magenta
        Write-Host "    Project directory: $PROXY_PROJECT_DIR" -ForegroundColor Gray
        Write-Host "    Current directory: $(Get-Location)" -ForegroundColor Gray
        Write-Host ""

        # Verify project setup before starting
        if (-not (Test-Path $PROXY_PROJECT_DIR)) {
            Write-Host "Error: Project directory not found: $PROXY_PROJECT_DIR" -ForegroundColor Red
            Read-Host "Press any key to exit"
            exit 1
        }

        $envFile = Join-Path $PROXY_PROJECT_DIR ".env"
        if (-not (Test-Path $envFile)) {
            Write-Host "Error: .env file not found: $envFile" -ForegroundColor Red
            Read-Host "Press any key to exit"
            exit 1
        }

        Write-Host "✅ Project setup verified" -ForegroundColor Green

        # Set environment variables and start proxy service and Claude Code
        $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
        $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
        $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN

        # Debug: Display environment variables
        Write-Host "Environment Variables:" -ForegroundColor Magenta
        Write-Host "  CLAUDE_CODE_MAX_OUTPUT_TOKENS = $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS" -ForegroundColor Gray
        Write-Host "  ANTHROPIC_BASE_URL = $env:ANTHROPIC_BASE_URL" -ForegroundColor Gray
        Write-Host "  ANTHROPIC_AUTH_TOKEN = $env:ANTHROPIC_AUTH_TOKEN" -ForegroundColor Gray
        Write-Host ""

        # Start proxy service (background) then start Claude Code (foreground)
        # Similar to sh script: uv run --directory $PROXY_PROJECT_DIR claude-code-proxy & sleep 1 && CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_TOKENS_LIMIT ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude

        # Method 1: Use Start-Process with proper working directory
        try {
            $proxyProcess = Start-Process -FilePath "uv" -ArgumentList "run", "--directory", $PROXY_PROJECT_DIR, "claude-code-proxy" -WindowStyle Hidden -PassThru
            Write-Host "Proxy service started, PID: $($proxyProcess.Id)" -ForegroundColor Green

            # Wait and verify proxy is running
            Write-Host "Waiting for proxy service initialization..." -ForegroundColor Blue
            Start-Sleep -Seconds 3

            # Check if proxy process is still running
            if (Get-Process -Id $proxyProcess.Id -ErrorAction SilentlyContinue) {
                Write-Host "Proxy service running successfully" -ForegroundColor Green
            } else {
                Write-Host "Warning: Proxy process may have exited" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Unable to start proxy via uv, trying alternative method..." -ForegroundColor Yellow
            # Method 2: Change directory and run uv
            $currentLocation = Get-Location
            try {
                Set-Location $PROXY_PROJECT_DIR
                $proxyProcess = Start-Process -FilePath "uv" -ArgumentList "run", "claude-code-proxy" -WindowStyle Hidden -PassThru
                Write-Host "Proxy service started, PID: $($proxyProcess.Id)" -ForegroundColor Green

                # Wait and verify proxy is running
                Write-Host "Waiting for proxy service initialization..." -ForegroundColor Blue
                Start-Sleep -Seconds 3

                # Check if proxy process is still running
                if (Get-Process -Id $proxyProcess.Id -ErrorAction SilentlyContinue) {
                    Write-Host "Proxy service running successfully" -ForegroundColor Green

                    # Test if proxy service is responding
                    Write-Host "Testing proxy service connectivity..." -ForegroundColor Blue 
                    if (Test-ProxyService -Url $ANTHROPIC_BASE_URL) {
                        Write-Host "Proxy service responding to requests" -ForegroundColor Green
                    } else {
                        Write-Host "Warning: Proxy service may not be responding yet" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "Warning: Proxy process may have exited" -ForegroundColor Yellow
                }
            } finally {
                Set-Location $currentLocation
            }
        }

        Write-Host "Starting Claude Code..." -ForegroundColor Green

        # Start Claude Code with environment variables
        # Set environment variables for current session and start Claude Code
        $env:CLAUDE_CODE_MAX_OUTPUT_TOKENS = $MAX_TOKENS_LIMIT
        $env:ANTHROPIC_BASE_URL = $ANTHROPIC_BASE_URL
        $env:ANTHROPIC_AUTH_TOKEN = $ANTHROPIC_AUTH_TOKEN
        & $CLAUDE_COMMAND
    } else {
        Write-Host "User cancelled Claude Code Proxy installation" -ForegroundColor Red
        Write-Host "You can run this script manually later to install" -ForegroundColor Yellow
        Read-Host "Press any key to exit"
    }
}
