#!/bin/bash

# SNISPF Core Manager
# Usage: 
#   bash sni.sh --install
#   sni run

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
INSTALL_DIR="$HOME/sni-spoof"
BINARY_URL="https://github.com/NaxonM/snispf-core/releases/download/v0.1.7/snispf_linux_arm64"
CONFIG_FILE="$INSTALL_DIR/config.json"
BINARY_FILE="$INSTALL_DIR/snispf"
PID_FILE="$INSTALL_DIR/snispf.pid"
SCRIPT_FILE="$INSTALL_DIR/sni.sh"
ALIAS_NAME="sni"

print_msg() { echo -e "${GREEN}[+]${NC} $1"; }
print_error() { echo -e "${RED}[!]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[*]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }

# Detect platform
detect_platform() {
    if command -v termux-info &> /dev/null || [ -d "/data/data/com.termux" ]; then
        PLATFORM="termux"
    else
        PLATFORM="linux"
    fi
}

detect_shell() {
    local current_shell=$(basename "$SHELL")
    case "$current_shell" in
        zsh) CURRENT_SHELL="zsh" ;;
        fish) CURRENT_SHELL="fish" ;;
        bash|*) CURRENT_SHELL="bash" ;;
    esac
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
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        print_warn "Installing wget..."
        if [ "$PLATFORM" = "termux" ]; then
            pkg update && pkg install -y wget
        else
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y wget
            elif command -v yum &> /dev/null; then
                sudo yum install -y wget
            fi
        fi
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
    print_msg "Config created at $CONFIG_FILE"
}

# Download binary
download_binary() {
    mkdir -p "$INSTALL_DIR"
    
    if [ -f "$BINARY_FILE" ]; then
        print_warn "Binary already exists, skipping download"
    else
        print_msg "Downloading SNISPF binary..."
        cd "$INSTALL_DIR"
        if command -v wget &> /dev/null; then
            wget -q --show-progress "$BINARY_URL" -O "$BINARY_FILE"
        else
            curl -L -o "$BINARY_FILE" "$BINARY_URL"
        fi
        chmod +x "$BINARY_FILE"
        print_msg "Download complete"
    fi
}

# Self-copy script to install directory
copy_script_to_install_dir() {
    local script_path=""
    
    if [ -f "$(pwd)/sni.sh" ]; then
        script_path="$(pwd)/sni.sh"
    elif [ -f "$HOME/sni.sh" ]; then
        script_path="$HOME/sni.sh"
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
        print_msg "Script copied to $SCRIPT_FILE"
    else
        cat > "$SCRIPT_FILE" << 'EOF'
#!/bin/bash
INSTALL_DIR="$HOME/sni-spoof"
case "$1" in
    run) cd "$INSTALL_DIR" && exec ./snispf --config ./config.json ;;
    stop) pkill -f "snispf.*config.json" ;;
    status) pgrep -f "snispf.*config.json" > /dev/null && echo "Running" || echo "Stopped" ;;
    *) echo "Usage: sni {run|stop|status}" ;;
esac
EOF
        chmod +x "$SCRIPT_FILE"
        print_warn "Created wrapper script"
    fi
}

# Add alias for bash, zsh, and fish
add_shell_alias() {
    local alias_cmd="alias $ALIAS_NAME='$SCRIPT_FILE'"
    local fish_alias_cmd="alias $ALIAS_NAME='$SCRIPT_FILE'"
    local added=0
    
    # For bash
    if [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "alias $ALIAS_NAME=" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# SNISPF alias" >> "$HOME/.bashrc"
            echo "$alias_cmd" >> "$HOME/.bashrc"
            print_msg "Added alias to ~/.bashrc"
            added=1
        fi
    fi
    
    # For zsh
    if [ -f "$HOME/.zshrc" ]; then
        if ! grep -q "alias $ALIAS_NAME=" "$HOME/.zshrc" 2>/dev/null; then
            echo "" >> "$HOME/.zshrc"
            echo "# SNISPF alias" >> "$HOME/.zshrc"
            echo "$alias_cmd" >> "$HOME/.zshrc"
            print_msg "Added alias to ~/.zshrc"
            added=1
        fi
    fi
    
    # For fish
    if [ -d "$HOME/.config/fish" ]; then
        local fish_config="$HOME/.config/fish/config.fish"
        if [ -f "$fish_config" ]; then
            if ! grep -q "alias $ALIAS_NAME=" "$fish_config" 2>/dev/null; then
                echo "" >> "$fish_config"
                echo "# SNISPF alias" >> "$fish_config"
                echo "$fish_alias_cmd" >> "$fish_config"
                print_msg "Added alias to ~/.config/fish/config.fish"
                added=1
            fi
        fi
    fi
    
    # For Termux
    if [ "$PLATFORM" = "termux" ] && [ -f "$HOME/.bashrc" ]; then
        if ! grep -q "alias $ALIAS_NAME=" "$HOME/.bashrc" 2>/dev/null; then
            echo "" >> "$HOME/.bashrc"
            echo "# SNISPF alias" >> "$HOME/.bashrc"
            echo "$alias_cmd" >> "$HOME/.bashrc"
            print_msg "Added alias to ~/.bashrc (Termux)"
            added=1
        fi
    fi
    
    if [ $added -eq 1 ]; then
        print_warn "Run: source ~/.bashrc (or restart terminal)"
    fi
}

# Create standalone command script in PATH
create_standalone_command() {
    local bin_path=""
    
    if [ "$PLATFORM" = "termux" ] && [ -d "$PREFIX/bin" ]; then
        bin_path="$PREFIX/bin/sni"
    elif [ -d "$HOME/.local/bin" ]; then
        bin_path="$HOME/.local/bin/sni"
    elif [ -d "$HOME/bin" ]; then
        bin_path="$HOME/bin/sni"
    else
        mkdir -p "$HOME/.local/bin"
        bin_path="$HOME/.local/bin/sni"
    fi
    
    if [ -n "$bin_path" ]; then
        cat > "$bin_path" << EOF
#!/bin/bash
exec $SCRIPT_FILE "\$@"
EOF
        chmod +x "$bin_path"
        print_msg "Command created: $bin_path"
    fi
}

# Install main function
install_snispf() {
    local root_mode="$1"
    
    print_msg "Installing SNISPF..."
    detect_platform
    detect_shell
    
    if [ "$root_mode" = "--root" ]; then
        print_msg "Root mode installation"
        create_config "wrong_seq"
    else
        print_msg "Normal mode installation (no root)"
        create_config "combined"
    fi
    
    check_dependencies
    download_binary
    copy_script_to_install_dir
    add_shell_alias
    create_standalone_command
    
    print_msg "Installation complete!"
    echo ""
    print_info "Installation directory: $INSTALL_DIR"
    print_info "Config file: $CONFIG_FILE"
    echo ""
    print_msg "Usage:"
    echo "  $ALIAS_NAME run          # Start proxy"
    echo "  $ALIAS_NAME stop         # Stop proxy"
    echo "  $ALIAS_NAME status       # Check status"
    
    if [ "$root_mode" = "--root" ]; then
        echo ""
        print_warn "Root mode requires: sudo $ALIAS_NAME run"
    fi
}

# Run the proxy
run_snispf() {
    detect_platform
    
    if [ ! -f "$BINARY_FILE" ]; then
        print_error "SNISPF not installed. Run: $ALIAS_NAME --install"
        exit 1
    fi
    
    local mode=$(get_current_mode)
    
    # Handle root mode
    if [ "$mode" = "wrong_seq" ]; then
        if [ "$EUID" -ne 0 ]; then
            if [ "$PLATFORM" = "termux" ]; then
                print_msg "Requesting root via su..."
                exec su -c "cd $INSTALL_DIR && ./snispf --config $CONFIG_FILE"
            else
                print_error "Root mode requires sudo! Run: sudo $ALIAS_NAME run"
                exit 1
            fi
        fi
    fi
    
    # Check if already running
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        print_error "SNISPF is already running (PID: $(cat $PID_FILE))"
        print_info "Run: $ALIAS_NAME stop"
        exit 1
    fi
    
    print_msg "Starting SNISPF..."
    cd "$INSTALL_DIR"
    
    # Run in background and save PID
    nohup ./snispf --config "$CONFIG_FILE" > /dev/null 2>&1 &
    echo $! > "$PID_FILE"
    
    sleep 1
    
    if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        print_msg "SNISPF started successfully (PID: $(cat $PID_FILE))"
        print_info "Proxy listening on 127.0.0.1:40443"
    else
        print_error "Failed to start SNISPF"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Stop the proxy
stop_snispf() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_msg "SNISPF stopped (PID: $pid)"
            rm -f "$PID_FILE"
        else
            rm -f "$PID_FILE"
        fi
    fi
    pkill -f "snispf.*config.json" 2>/dev/null && print_msg "SNISPF stopped"
}

# Show status
status_snispf() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        local mode=$(get_current_mode)
        print_msg "SNISPF is RUNNING"
        print_info "  PID: $(cat $PID_FILE)"
        print_info "  Mode: $mode"
        print_info "  Proxy: 127.0.0.1:40443"
    else
        rm -f "$PID_FILE"
        if pgrep -f "snispf.*config.json" > /dev/null; then
            print_warn "SNISPF is running (no PID file)"
        else
            print_warn "SNISPF is NOT running"
        fi
    fi
}

# Show help
show_help() {
    cat << EOF
SNISPF Core Manager

Usage: $ALIAS_NAME [COMMAND]

Commands:
  --install              Install SNISPF (normal mode)
  --install --root       Install SNISPF with root mode support
  run                    Start the proxy
  stop                   Stop the proxy
  status                 Show proxy status
  --help                 Show this help

Examples:
  $ALIAS_NAME --install          # Install normal mode
  $ALIAS_NAME --install --root   # Install root mode
  $ALIAS_NAME run                # Start proxy
  sudo $ALIAS_NAME run           # Start proxy in root mode (Linux)
  $ALIAS_NAME stop               # Stop proxy
  $ALIAS_NAME status             # Check status

Notes:
  - After installation, you can use '$ALIAS_NAME' from anywhere
  - Supports bash, zsh, and fish shells
  - Config file: ~/sni-spoof/config.json
  - Proxy address: 127.0.0.1:40443
EOF
}

# Main
case "$1" in
    --install)
        install_snispf "$2"
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
        if [ -z "$1" ]; then
            show_help
        else
            print_error "Unknown command: $1"
            show_help
            exit 1
        fi
        ;;
esac
