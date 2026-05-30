#!/data/data/com.termux/files/usr/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
INSTALL_DIR="$HOME/sni-spoof"
BINARY_URL="https://github.com/NaxonM/snispf-core/releases/download/v0.1.8/snispf_linux_arm64"
CONFIG_FILE="$INSTALL_DIR/config.json"
BINARY_FILE="$INSTALL_DIR/snispf"
SCRIPT_FILE="$INSTALL_DIR/sni.sh"

print_msg() { echo -e "${GREEN}[+]${NC} $1"; }
print_error() { echo -e "${RED}[!]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[*]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Check if running in Termux
check_termux() {
    if ! command -v termux-info &> /dev/null && [ ! -d "/data/data/com.termux" ]; then
        print_error "This script is only for Termux (Android)"
        print_info "Please run this script in Termux environment"
        exit 1
    fi
}

# Get current mode from config
get_current_mode() {
    if [ -f "$CONFIG_FILE" ]; then
        grep -o '"BYPASS_METHOD": "[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4 || echo "combined"
    else
        echo "combined"
    fi
}

# Check and install curl if not present
check_curl() {
    if ! command -v curl &> /dev/null; then
        print_warn "curl not found. Installing..."
        pkg update && pkg install -y curl
        print_msg "curl installed"
    fi
}

# Install root packages for Termux (only if not installed)
install_root_packages() {
    local need_install=false
    
    if ! command -v tsu &> /dev/null; then
        need_install=true
    fi
    
    if ! pkg list-installed root-repo &> /dev/null; then
        need_install=true
    fi
    
    if [ "$need_install" = true ]; then
        print_msg "Installing root packages..."
        pkg update
        pkg install -y root-repo tsu
        print_msg "Root packages installed"
    else
        print_msg "Root packages already installed"
    fi
}

# Create config
create_config() {
    local method="$1"
    mkdir -p "$INSTALL_DIR"

    if [ "$method" = "wrong_seq" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
  "LISTEN_HOST": "127.0.0.1",
  "LISTEN_PORT": 40443,
  "LOG_LEVEL": "info",
  "CONNECT_IP": "104.19.229.21",
  "CONNECT_PORT": 443,
  "FAKE_SNI": "hcaptcha.com",
  "BYPASS_METHOD": "wrong_seq",
  "FRAGMENT_STRATEGY": "sni_split",
  "FRAGMENT_DELAY": 0.05,
  "USE_TTL_TRICK": false,
  "FAKE_SNI_METHOD": "raw_inject",
  "PROBE_TIMEOUT_MS": 2500,
  "WRONG_SEQ_CONFIRM_TIMEOUT_MS": 2000,
  "INTERFACE": ""
}
EOF
    else
        cat > "$CONFIG_FILE" << 'EOF'
{
  "LISTEN_HOST": "127.0.0.1",
  "LISTEN_PORT": 40443,
  "LOG_LEVEL": "info",
  "CONNECT_IP": "104.19.229.21",
  "CONNECT_PORT": 443,
  "FAKE_SNI": "hcaptcha.com",
  "BYPASS_METHOD": "combined",
  "FRAGMENT_STRATEGY": "sni_split",
  "FRAGMENT_DELAY": 0.05,
  "USE_TTL_TRICK": false,
  "FAKE_SNI_METHOD": "raw_inject",
  "PROBE_TIMEOUT_MS": 2500,
  "WRONG_SEQ_CONFIRM_TIMEOUT_MS": 2000
}
EOF
    fi
    print_msg "Config created"
}

# Download binary
download_binary() {
    mkdir -p "$INSTALL_DIR"

    if [ -f "$BINARY_FILE" ]; then
        print_warn "Binary already exists, skipping download"
    else
        print_msg "Downloading SNISPF binary..."
        cd "$INSTALL_DIR"
        curl -L --progress-bar "$BINARY_URL" -o "$BINARY_FILE"
        chmod +x "$BINARY_FILE"
        print_msg "Download complete"
    fi
}

# Self-copy script to install directory
copy_script_to_install_dir() {
    local script_path=""

    if [ -f "$(pwd)/termux.sh" ]; then
        script_path="$(pwd)/termux.sh"
    elif [ -f "$HOME/termux.sh" ]; then
        script_path="$HOME/termux.sh"
    elif [ -f "$0" ]; then
        script_path="$0"
        if [[ "$script_path" != /* ]]; then
            script_path="$(pwd)/$script_path"
        fi
    fi

    if [ -n "$script_path" ] && [ -f "$script_path" ]; then
        mkdir -p "$INSTALL_DIR"
        cp "$script_path" "$SCRIPT_FILE"
        chmod +x "$SCRIPT_FILE"
        print_msg "Script copied"
    else
        print_error "Could not find script to copy."
        exit 1
    fi
}

# Create standalone command
create_standalone_command() {
    local bin_path="$PREFIX/bin/sni"
    
    if [ -n "$bin_path" ]; then
        cat > "$bin_path" << EOF
#!/bin/bash
exec $SCRIPT_FILE "\$@"
EOF
        chmod +x "$bin_path"
        print_msg "Command created: sni"
    fi
}

# Install main function
install_snispf() {
    local root_mode="$1"

    print_msg "Installing SNISPF for Termux..."
    check_termux
    check_curl

    if [ "$root_mode" = "--root" ]; then
        print_msg "Root mode installation"
        install_root_packages
        create_config "wrong_seq"
    else
        print_msg "Normal mode installation (no root)"
        create_config "combined"
    fi

    download_binary
    copy_script_to_install_dir
    create_standalone_command

    print_msg "Installation complete!"
    echo ""
    print_info "Directory: $INSTALL_DIR"
    echo ""
    print_msg "Usage:"
    echo "  sni run          # Start proxy (foreground)"
    echo "  sni stop         # Stop proxy"
    echo "  sni status       # Check status"
    echo "  sni update       # Update binary"

    if [ "$root_mode" = "--root" ]; then
        echo ""
        print_info "Root mode: 'sni run' will auto-request root via sudo"
    fi
}

# Update binary
update_snispf() {
    print_msg "Updating SNISPF binary..."
    check_termux
    check_curl
    
    if [ -f "$BINARY_FILE" ]; then
        print_msg "Removing old binary..."
        rm -f "$BINARY_FILE"
    fi
    
    print_msg "Downloading latest binary..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    curl -L --progress-bar "$BINARY_URL" -o "$BINARY_FILE"
    chmod +x "$BINARY_FILE"
    print_msg "Update completed!"
}

# Run the proxy
run_snispf() {
    check_termux
    
    if [ ! -f "$BINARY_FILE" ]; then
        print_error "SNISPF not installed. Run: sni --install"
        exit 1
    fi

    local mode=$(get_current_mode)

    if [ "$mode" = "wrong_seq" ]; then
        if [ "$EUID" -ne 0 ]; then
            print_msg "Root required. Executing with sudo..."
            exec sudo "$BINARY_FILE" --config "$CONFIG_FILE"
        fi
    else
        print_msg "Starting SNISPF (foreground mode)..."
        cd "$INSTALL_DIR"
        exec ./snispf --config "$CONFIG_FILE"
    fi
}

# Stop the proxy
stop_snispf() {
    check_termux
    
    local mode=$(get_current_mode)
    
    print_msg "Stopping SNISPF..."
    
    if [ "$mode" = "wrong_seq" ]; then
        local pids=$(sudo ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}')
        if [ -n "$pids" ]; then
            for pid in $pids; do
                sudo kill -9 "$pid" 2>/dev/null
            done
            print_msg "Stopped"
        else
            print_warn "No running process found"
        fi
    else
        local pids=$(ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}')
        if [ -n "$pids" ]; then
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null
            done
            print_msg "Stopped"
        else
            print_warn "No running process found"
        fi
    fi
}

# Show status
status_snispf() {
    check_termux
    
    local mode=$(get_current_mode)
    
    if [ "$mode" = "wrong_seq" ]; then
        local pid=$(sudo ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}' | head -1)
        
        if [ -n "$pid" ] && sudo kill -0 "$pid" 2>/dev/null; then
            print_msg "SNISPF is RUNNING (Root mode)"
            echo "  PID: $pid"
            return 0
        else
            print_warn "SNISPF is NOT running"
            return 1
        fi
    fi
    
    local pid=$(ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}' | head -1)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        print_msg "SNISPF is RUNNING"
        echo "  PID: $pid"
        return 0
    fi
    
    print_warn "SNISPF is NOT running"
    return 1
}

# Show help
show_help() {
    cat << EOF
SNISPF Core Manager for Termux

Usage: sni [COMMAND]

Commands:
  --install              Install (normal mode)
  --install --root       Install (root mode)
  run                    Start proxy (foreground)
  stop                   Stop proxy
  status                 Show status
  update                 Update binary
  --help                 Show help

Examples:
  sni --install          # Normal install
  sni --install --root   # Root install
  sni run                # Start proxy
  sni stop               # Stop proxy
  sni status             # Check status
  sni update             # Update to latest binary

Notes:
  - Termux only (Android)
  - Config: ~/sni-spoof/config.json
  - Root mode: 'sni run' auto-requests root via sudo
  - Press Ctrl+C to stop the proxy
EOF
}

# Main
case "$1" in
    --install)
        install_snispf "$2"
        ;;
    update)
        update_snispf
        ;;
    run)
        run_snispf
        ;;
    stop)
        stop_snispf
        ;;
    status)
        status_snispf
        ;;
    --help|-h)
        show_help
        ;;
    *)
        show_help
        ;;
esac
