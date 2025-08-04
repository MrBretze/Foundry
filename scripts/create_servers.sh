#!/bin/bash

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
server_num=1
link=""
port=7050
confirm_download=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --server_num=*)
        server_num="${key#*=}"
        shift
        ;;
        link=*)
        link="${key#*=}"
        shift
        ;;
        port=*)
        port="${key#*=}"
        shift
        ;;
        --confirm)
        confirm_download=true
        shift
        ;;
        *)
        echo "Unknown option: $key"
        exit 1
        ;;
    esac
done

# Function to check and download binary
check_and_download_binary() {
    local src_dir="./src"
    local binary_file="$src_dir/StarDeception.dedicated_server.x86_64"
    local link_file="$src_dir/StarDeception.dedicated_server_link.txt"

    echo -e "${BLUE}Checking for dedicated server binary...${NC}"

    # Check if binary already exists
    if [[ -f "$binary_file" ]]; then
        echo -e "${GREEN}✓ Dedicated server binary found${NC}"
        return 0
    fi

    echo -e "${YELLOW}⚠ Dedicated server binary not found${NC}"
    echo

    # Use the provided link if available
    if [[ -n "$link" ]]; then
        download_url="$link"
    else
        # Check if link file exists
        if [[ ! -f "$link_file" ]]; then
            echo -e "${RED}✗ Link file not found: $link_file${NC}"
            echo "Please make sure the link file exists with a valid download URL."
            read -p "Press Enter to continue..."
            return 1
        fi

        # Extract download link from file
        download_url=$(grep -E "^https?://" "$link_file" | head -1)
    fi

    if [[ -z "$download_url" || "$download_url" == *"????????????"* ]]; then
        echo -e "${RED}✗ No valid download URL found${NC}"
        echo
        echo -e "${BLUE}💡 Download URL Guidelines:${NC}"
        echo "  • The URL must be a DIRECT download link to the binary file"
        echo "  • It should end with the filename (e.g., .../StarDeception.dedicated_server.x86_64)"
        echo "  • Avoid URLs that redirect to web pages or download pages"
        echo "  • If using a file hosting service, use the 'direct download' or 'raw' URL"
        echo
        echo "Please provide a valid download URL for the dedicated server binary:"
        read -p "Enter URL: " user_url

        if [[ -z "$user_url" ]]; then
            echo -e "${RED}No URL provided. Cannot create servers without binary.${NC}"
            read -p "Press Enter to continue..."
            return 1
        fi

        download_url="$user_url"

        # Update the link file with the new URL
        echo -e "${BLUE}Updating link file with provided URL...${NC}"
        echo "$download_url" > "$link_file"
    fi

    echo -e "${BLUE}Found download URL: ${CYAN}$download_url${NC}"
    echo

    # Confirmation
    if [[ "$confirm_download" == false ]]; then
        echo -e "${YELLOW}Do you want to download the dedicated server binary now?${NC}"
        read -p "Enter [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Download cancelled. Cannot create servers without binary.${NC}"
            read -p "Press Enter to continue..."
            return 1
        fi
    else
        echo -e "${BLUE}Automatically confirmed download.${NC}"
    fi

    # Create src directory if it doesn't exist
    mkdir -p "$src_dir"

    # Download the file
    echo -e "${BLUE}Downloading dedicated server binary...${NC}"

    # Try different download methods
    local temp_file="/tmp/stardeception_server_download"
    local download_success=false

    # Try wget first
    if command -v wget >/dev/null 2>&1; then
        echo -e "${BLUE}Using wget to download...${NC}"
        # Use wget with better options for direct downloads
        if wget --no-check-certificate --content-disposition -O "$temp_file" "$download_url" 2>/dev/null; then
            download_success=true
        fi
    # Try curl if wget is not available
    elif command -v curl >/dev/null 2>&1; then
        echo -e "${BLUE}Using curl to download...${NC}"
        # Use curl with follow redirects and better headers
        if curl -L -k -H "Accept: application/octet-stream" -o "$temp_file" "$download_url" 2>/dev/null; then
            download_success=true
        fi
    else
        echo -e "${RED}✗ Neither wget nor curl found. Please install one of them.${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    if [[ "$download_success" == false ]]; then
        echo -e "${RED}✗ Download failed. Please check the URL and your internet connection.${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Check if the downloaded file is actually HTML (common issue with web hosting)
    if file "$temp_file" | grep -q "HTML"; then
        echo -e "${RED}✗ Downloaded file appears to be HTML instead of a binary.${NC}"
        echo -e "${YELLOW}This usually means the URL points to a web page instead of the direct file.${NC}"
        echo
        echo -e "${BLUE}💡 Suggestions:${NC}"
        echo "  • Make sure the URL is a direct download link"
        echo "  • If using a file hosting service, get the direct download URL"
        echo "  • Try right-clicking and 'Copy link address' on the download button"
        echo
        rm -f "$temp_file"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Check if the file is actually executable (has the right format)
    if ! file "$temp_file" | grep -q "executable\|ELF"; then
        echo -e "${YELLOW}⚠ Warning: Downloaded file doesn't appear to be an executable binary.${NC}"
        echo -e "${BLUE}File type detected:${NC} $(file "$temp_file")"
        echo
        echo -e "${YELLOW}Do you want to continue anyway? [y/N]: ${NC}"
        read -p "" continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            rm -f "$temp_file"
            echo -e "${YELLOW}Download cancelled.${NC}"
            read -p "Press Enter to continue..."
            return 1
        fi
    fi

    # Move and rename the downloaded file
    mv "$temp_file" "$binary_file"

    # Make it executable
    chmod +x "$binary_file"

    echo -e "${GREEN}✓ Dedicated server binary downloaded and configured successfully${NC}"
    echo -e "${GREEN}✓ File saved as: $binary_file${NC}"
    echo -e "${GREEN}✓ Executable permissions set${NC}"
    echo

    return 0
}

echo -e "${CYAN}========== Game Server Creator ==========${NC}"
echo

# First check and download the binary if needed
if ! check_and_download_binary; then
    echo -e "${RED}Cannot proceed without the dedicated server binary.${NC}"
    exit 1
fi

echo
count=$server_num
id="01" # Default ID, you can modify this as needed
sdo_ip="127.0.0.1" # Default SDO IP, you can modify this as needed

# Quick validation
if ! [[ $id =~ ^[0-9]{2}$ ]]; then
  echo "Invalid identifier. It must be composed of 2 digits."
  exit 1
fi

for ((i=1; i<=count; i++)); do
  folder="server$i"
  mkdir -p "$folder"

  # Server number format: 01, 02, ...
  num=$(printf "%02d" $i)
  cat > "$folder/server.ini" <<EOF
[server]
name="gameserver${id}${num}"
port=${port}
SDO="${sdo_ip}"
EOF

  # Copy the server files from src directory
  echo -e "${BLUE}Copying server files...${NC}"

  # Get the script directory to build absolute paths
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  project_dir="$(dirname "$script_dir")"
  src_dir="$project_dir/src"

  # Check if source files exist before copying
  if [[ ! -f "$src_dir/StarDeception.dedicated_server.sh" ]]; then
    echo -e "${RED}✗ Error: $src_dir/StarDeception.dedicated_server.sh not found${NC}"
    continue
  fi

  if [[ ! -f "$src_dir/StarDeception.dedicated_server.x86_64" ]]; then
    echo -e "${YELLOW}⚠ Warning: $src_dir/StarDeception.dedicated_server.x86_64 not found${NC}"
    echo -e "${YELLOW}  Server will be created but binary needs to be downloaded separately${NC}"
  fi

  # Copy files
  cp "$src_dir/StarDeception.dedicated_server.sh" "$folder/" || {
    echo -e "${RED}✗ Failed to copy StarDeception.dedicated_server.sh${NC}"
    continue
  }

  if [[ -f "$src_dir/StarDeception.dedicated_server.x86_64" ]]; then
    cp "$src_dir/StarDeception.dedicated_server.x86_64" "$folder/" || {
      echo -e "${YELLOW}⚠ Failed to copy binary file${NC}"
    }
  fi
  ((port++))
done

echo "$count servers created successfully."
