#!/data/data/com.termux/files/usr/bin/bash
set -e

# Save absolute path of the script at start (before any cd)
if [[ "$0" == /* ]]; then
    SCRIPT_SOURCE="$0"
else
    SCRIPT_SOURCE="$(pwd)/$0"
fi


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
INSTALL_DIR="$HOME/snispf"
BINARY_URL="https://github.com/NaxonM/snispf-core/releases/download/v0.1.8/snispf_linux_arm64"
CONFIG_FILE="$INSTALL_DIR/config.json"
BINARY_FILE="$INSTALL_DIR/snispf"
SCRIPT_FILE="$INSTALL_DIR/snispf.sh"

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

# Check and install dependencies
check_dependencies() {
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        print_warn "curl not found. Installing..."
        pkg update && pkg install -y curl
        print_msg "curl installed"
    fi
    
    # Install file if not present
    if ! command -v file &> /dev/null; then
        print_warn "file not found. Installing..."
        pkg install -y file
        print_msg "file installed"
    fi
    
    # Install grep if not present (usually pre-installed, but just in case)
    if ! command -v grep &> /dev/null; then
        print_warn "grep not found. Installing..."
        pkg install -y grep
        print_msg "grep installed"
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

# Download binary with validation
download_binary() {
    mkdir -p "$INSTALL_DIR"

    if [ -f "$BINARY_FILE" ]; then
        # Check if existing binary is valid using file command
        if file "$BINARY_FILE" 2>/dev/null | grep -q "ELF.*executable"; then
            print_warn "Valid binary already exists, skipping download"
            return 0
        else
            print_warn "Existing binary is corrupted, re-downloading..."
            rm -f "$BINARY_FILE"
        fi
    fi
    
    print_msg "Downloading SNISPF binary..."
    cd "$INSTALL_DIR"
    
    # Download with retry
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -L --fail --progress-bar "$BINARY_URL" -o "$BINARY_FILE.tmp" 2>/dev/null; then
            # Verify the downloaded file
            if file "$BINARY_FILE.tmp" 2>/dev/null | grep -q "ELF.*executable"; then
                mv "$BINARY_FILE.tmp" "$BINARY_FILE"
                chmod +x "$BINARY_FILE"
                print_msg "Download complete"
                return 0
            else
                print_warn "Downloaded file is not a valid executable (attempt $((retry+1))/$max_retries)"
                rm -f "$BINARY_FILE.tmp"
            fi
        else
            print_warn "Download failed (attempt $((retry+1))/$max_retries)"
        fi
        retry=$((retry + 1))
        [ $retry -lt $max_retries ] && sleep 2
    done
    
    print_error "Failed to download valid binary after $max_retries attempts"
    exit 1
}

# Self-copy script to install directory
copy_script_to_install_dir() {
    local script_path=""

    if [ -f "$SCRIPT_SOURCE" ]; then
        script_path="$SCRIPT_SOURCE"
    elif [ -f "$(pwd)/termux_snispf.sh" ]; then
        script_path="$(pwd)/termux_snispf.sh"
    elif [ -f "$HOME/termux_snispf.sh" ]; then
        script_path="$HOME/termux_snispf.sh"
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
    local bin_path="$PREFIX/bin/snispf"
    
    if [ -n "$bin_path" ]; then
        cat > "$bin_path" << EOF
#!$PREFIX/bin/bash
exec $SCRIPT_FILE "\$@"
EOF
        chmod +x "$bin_path"
        print_msg "Command created: snispf"
    fi
}

# Install main function
install_snispf() {
    local root_mode="$1"

    print_msg "Installing SNISPF for Termux..."
    check_termux
    check_dependencies

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
    echo "  snispf run          # Start proxy (foreground)"
    echo "  snispf stop         # Stop proxy"
    echo "  snispf status       # Check status"
    echo "  snispf update       # Update binary"
    echo "  snispf uninstall    # Uninstall SNISPF"

    if [ "$root_mode" = "--root" ]; then
        echo ""
        print_info "Root mode: 'snispf run' will auto-request root via sudo"
    fi
}

# Update binary
update_snispf() {
    print_msg "Updating SNISPF binary..."
    check_termux
    check_dependencies
    
    if [ -f "$BINARY_FILE" ]; then
        print_msg "Removing old binary..."
        rm -f "$BINARY_FILE"
    fi
    
    download_binary
    print_msg "Update completed!"
}

# Run the proxy
run_snispf() {
    check_termux
    
    if [ ! -f "$BINARY_FILE" ]; then
        print_error "SNISPF not installed. Run: snispf install"
        exit 1
    fi
    
    # Verify binary before running
    if ! file "$BINARY_FILE" 2>/dev/null | grep -q "ELF.*executable"; then
        print_error "Binary is corrupted. Please run: snispf update"
        exit 1
    fi

    local mode=$(get_current_mode)

    if [ "$mode" = "wrong_seq" ]; then
        if [ "$EUID" -ne 0 ]; then
            print_msg "Root required. Executing with sudo..."
            exec sudo "$BINARY_FILE" --config "$CONFIG_FILE"
        else
            print_msg "Starting SNISPF with root..."
            exec "$BINARY_FILE" --config "$CONFIG_FILE"
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
        local pids=$(sudo pgrep -f "snispf" 2>/dev/null || sudo pidof snispf 2>/dev/null || sudo ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}')
        if [ -n "$pids" ]; then
            for pid in $pids; do
                sudo kill -9 "$pid" 2>/dev/null
            done
            print_msg "Stopped"
        else
            print_warn "No running process found"
        fi
    else
        local pids=$(pgrep -f "snispf" 2>/dev/null || pidof snispf 2>/dev/null || ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}')
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
        local pid=$(sudo pgrep -f "snispf" 2>/dev/null | head -1 || sudo pidof snispf 2>/dev/null | head -1 || sudo ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}' | head -1)
        
        if [ -n "$pid" ] && sudo kill -0 "$pid" 2>/dev/null; then
            print_msg "SNISPF is RUNNING (Root mode)"
            echo "  PID: $pid"
            return 0
        else
            print_warn "SNISPF is NOT running"
            return 1
        fi
    fi
    
    local pid=$(pgrep -f "snispf" 2>/dev/null | head -1 || pidof snispf 2>/dev/null | head -1 || ps -e -o pid,comm 2>/dev/null | grep -E "snispf$" | grep -v grep | awk '{print $1}' | head -1)
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

Usage: snispf [COMMAND]

Commands:
  install                Install (normal mode)
  install --root         Install (root mode)
  uninstall              Uninstall manager and binaries
  run                    Start proxy (foreground)
  stop                   Stop proxy
  status                 Show status
  update                 Update binary
  --help                 Show help

Examples:
  snispf install         # Normal install
  snispf install --root  # Root install
  snispf run             # Start proxy
  snispf stop            # Stop proxy
  snispf status          # Check status
  snispf update          # Update to latest binary

Notes:
  - Termux only (Android)
  - Config: ~/snispf/config.json
  - Root mode: 'snispf run' auto-requests root via sudo
  - Press Ctrl+C to stop the proxy
EOF
}

# Uninstall function
uninstall_snispf() {
    check_termux
    print_msg "Uninstalling SNISPF for Termux..."
    local bin_path="$PREFIX/bin/snispf"
    if [ -f "$bin_path" ]; then
        rm -f "$bin_path"
        print_msg "Shortcut command removed: snispf"
    fi
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        print_msg "Installation directory removed: $INSTALL_DIR"
    fi
    print_msg "Uninstall complete!"
}

# Main
case "$1" in
    install|--install)
        install_snispf "$2"
        ;;
    uninstall)
        uninstall_snispf
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
