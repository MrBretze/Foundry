#!/bin/bash

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Flags
confirm_flag=0
interactive_flag=0

# Array to store PIDs of started servers
server_pids=()

# Function to stop all servers using their PIDs
stop_servers() {
    echo -e "${BLUE}Stopping all servers...${NC}"
    for pid in "${server_pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo -e "${GREEN}Server with PID $pid stopped.${NC}"
        else
            echo -e "${YELLOW}Server with PID $pid is not running.${NC}"
        fi
    done
    echo -e "${GREEN}All servers stopped.${NC}"
}

# Function to check servers
check_servers() {
    if [ -f "scripts/check_servers.sh" ]; then
        bash scripts/check_servers.sh
    else
        echo -e "${RED}Error: scripts/check_servers.sh not found.${NC}"
    fi
}

# Function to get server status
status_servers() {
    if [ -f "scripts/status_servers.sh" ]; then
        bash scripts/status_servers.sh
    else
        echo -e "${RED}Error: scripts/status_servers.sh not found.${NC}"
    fi
}

# Parse all arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --confirm)
            confirm_flag=1
            shift ;;
        --interactive)
            interactive_flag=1
            shift ;;
        *)
            shift ;;
    esac
done

echo -e "${GREEN}========== Start All Game Servers ==========${NC}"
echo

# Check if dedicated server binary exists
binary_file="./src/StarDeception.dedicated_server.x86_64"
if [[ ! -f "$binary_file" ]]; then
    echo -e "${RED}✗ Dedicated server binary not found: $binary_file${NC}"
    echo -e "${YELLOW}Please make sure the binary is downloaded and placed in the src/ directory.${NC}"
    echo -e "${BLUE}Tip: Use the main menu option to automatically download the binary.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dedicated server binary found${NC}"

# Find all server directories
server_dirs=($(find . -maxdepth 1 -type d -name "server*" | sort))
if [ ${#server_dirs[@]} -eq 0 ]; then
    echo -e "${RED}No server directories found. Please run create_servers.sh first.${NC}"
    exit 1
fi

echo -e "${BLUE}Found ${#server_dirs[@]} server(s) to start:${NC}"
for dir in "${server_dirs[@]}"; do
    echo "  - $dir"
done
echo

if [[ $confirm_flag -eq 0 ]]; then
    echo -e "${YELLOW}Do you want to start all servers?${NC}"
    read -p "Enter [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
    echo -e "${BLUE}Starting all servers...${NC}"
    echo
else
    echo -e "${BLUE}Starting automatically all servers because --confirm is present${NC}"
    echo
fi

# Start each server
started_count=0
current_dir=$(pwd)
for dir in "${server_dirs[@]}"; do
    if [ -f "$dir/StarDeception.dedicated_server.sh" ]; then
        echo -e "${BLUE}Starting server in $dir...${NC}"
        cd "$dir"
        chmod +x StarDeception.dedicated_server.sh
        nohup ./StarDeception.dedicated_server.sh > server.log 2>&1 &
        server_pid=$!
        server_pids+=("$server_pid") # Store the PID
        echo -e "${GREEN}  ✓ Server started with PID: $server_pid${NC}"
        ((started_count++))
        cd "$current_dir"  # Return to original directory
        sleep 1  # Small delay between server starts
    else
        echo -e "${YELLOW}  ⚠ Warning: StarDeception.dedicated_server.sh not found in $dir${NC}"
    fi
done

echo

if [ $started_count -gt 0 ]; then
    echo -e "${GREEN}✓ Successfully started $started_count server(s)!${NC}"

    # Interactive command loop
    if [[ $interactive_flag -eq 1 ]]; then
        while true; do
            echo -e "\n${CYAN}Enter a command (check, status, exit to stop): ${NC}\c"
            echo
            read cmd
            case $cmd in
                exit)
                    stop_servers
                    echo -e "${BLUE}Exiting...${NC}"
                    break
                    ;;
                check)
                    check_servers
                    ;;
                status)
                    status_servers
                    ;;
                *)
                    echo -e "${YELLOW}Unknown command. Use 'check', 'status', 'exit', or 'quit' to stop.${NC}"
                    ;;
            esac
        done
    else
        echo -e "${BLUE}📋 Server management tips:${NC}"
        echo "  • Check individual server.log files in each server directory for output"
        echo "  • To stop all servers: pkill -f StarDeception.dedicated_server"
        echo "  • To check running servers: ps aux | grep StarDeception"
    fi
    
else
    echo -e "${RED}✗ No servers were started${NC}"