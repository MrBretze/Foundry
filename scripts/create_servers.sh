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
id="01"
confirm_download=false
link=""
public_ip=127.0.0.1
verbose=0
#GamePort
port=7050
#SDO
sdo_ip="127.0.0.1"
sdo_url=""
sdo_port=9001
sdo_username=""
sdo_password=""
#Chat
chat_url=""
chat_port=9001
chat_username=""
chat_password=""
#Persistance
persistence_enabled=true
persistence_dbhost=""
#Metrics
metrics_enabled=true
metrics_url=""
metrics_port=9002
metrics_username=""
metrics_password=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        server_num=*)
        server_num="${key#*=}"
        shift
        ;;
        port=*)
        port="${key#*=}"
        shift
        ;;
        link=*)
        link="${key#*=}"
        shift
        ;;
        public_ip=*)
        public_ip="${key#*=}"
        shift
        ;;
        verbose=*)
        verbose="${key#*=}"
        shift
        ;;
        sdo_url=*)
        sdo_url="${key#*=}"
        shift
        ;;
        sdo_port=*)
        sdo_port="${key#*=}"
        shift
        ;;
        sdo_username=*)
        sdo_username="${key#*=}"
        shift
        ;;
        sdo_password=*)
        sdo_password="${key#*=}"
        shift
        ;;
        --confirm)
        confirm_download=true
        shift
        ;;
        sdo_ip=*)
        sdo_ip="${key#*=}"
        shift
        ;;
        id=*)
        id="${key#*=}"
        shift
        ;;
        chat_url=*)
        chat_url="${key#*=}"
        shift
        ;;
        chat_port=*)
        chat_port="${key#*=}"
        shift
        ;;
        chat_username=*)
        chat_username="${key#*=}"
        shift
        ;;
        chat_password=*)
        chat_password="${key#*=}"
        shift
        ;;
        persistence_enabled=*)
        persistence_enabled="${key#*=}"
        shift
        ;;
        persistence_dbhost=*)
        persistence_dbhost="${key#*=}"
        shift
        ;;
        metrics_enabled=*)
        metrics_enabled="${key#*=}"
        shift
        ;;
        metrics_url=*)
        metrics_url="${key#*=}"
        shift
        ;;
        metrics_port=*)
        metrics_port="${key#*=}"
        shift
        ;;
        metrics_username=*)
        metrics_username="${key#*=}"
        shift
        ;;
        metrics_password=*)
        metrics_password="${key#*=}"
        shift
        ;;
        *)
        echo "Unknown option: $key"
        exit 1
        ;;
    esac
done

# Function to check and download zip, then extract
check_and_download_zip() {
    local src_dir="./src"
    local zip_file="$src_dir/StarDeception.dedicated_server.zip"
    local link_file="$src_dir/StarDeception.dedicated_server_link.txt"

    echo -e "${BLUE}Checking for dedicated server files...${NC}"

    # Create src directory if it doesn't exist
    mkdir -p "$src_dir"
    mkdir -p "tmp"

    # Check if the ZIP file already exists
    if [[ ! -f "$zip_file" ]]; then
        echo -e "${YELLOW}⚠ ZIP file not found.${NC}"

        # Use the provided link if available
        if [[ -n "$link" ]]; then
            download_url="$link"
        else
            # Check if link file exists
            if [[ ! -f "$link_file" ]]; then
                echo -e "${RED}✗ Link file not found: $link_file${NC}"
                echo "Please make sure the link file exists with a valid download URL."
                if [[ "$confirm_download" == false ]]; then
                    read -p "Press Enter to continue..."
                fi
                return 1
            fi
            # Extract download link from file
            download_url=$(grep -E "^https?://" "$link_file" | head -1)
        fi

        if [[ -z "$download_url" ]]; then
            echo -e "${RED}✗ No valid download URL found.${NC}"
            echo
            echo "Please provide a valid download URL for the dedicated server ZIP archive:"
            read -p "Enter URL: " user_url
            if [[ -z "$user_url" ]]; then
                echo -e "${RED}No URL provided. Cannot create servers without the archive.${NC}"
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
            echo -e "${YELLOW}Do you want to download the dedicated server ZIP archive now?${NC}"
            read -p "Enter [y/N]: " confirm
            if [[ ! $confirm =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Download cancelled. Cannot create servers without the archive.${NC}"
                read -p "Press Enter to continue..."
                return 1
            fi
        else
            echo -e "${BLUE}Automatically confirmed download.${NC}"
        fi

        # Download the file
        echo -e "${BLUE}Downloading dedicated server ZIP archive...${NC}"
        local temp_file="tmp/StarDeception.dedicated_server.zip"
        local download_success=false

        # Try wget first
        if command -v wget >/dev/null 2>&1; then
            echo -e "${BLUE}Using wget to download...${NC}"
            if wget --no-check-certificate "$download_url" -O "$temp_file" 2>/dev/null; then
                download_success=true
            fi
        # Try curl if wget is not available
        elif command -v curl >/dev/null 2>&1; then
            echo -e "${BLUE}Using curl to download...${NC}"
            if curl -L -k "$download_url" -o "$temp_file" 2>/dev/null; then
                download_success=true
            fi
        else
            echo -e "${RED}✗ Neither wget nor curl found. Please install one of them.${NC}"
            if [[ "$confirm_download" == false ]]; then
                read -p "Press Enter to continue..."
            fi
            return 1
        fi

        if [[ "$download_success" == false ]]; then
            echo -e "${RED}✗ Download failed. Please check the URL and your internet connection.${NC}"
            if [[ "$confirm_download" == false ]]; then
                read -p "Press Enter to continue..."
            fi
            return 1
        fi

        # Check if the downloaded file is actually HTML (common issue with web hosting)
        if file "$temp_file" | grep -q "HTML"; then
            echo -e "${RED}✗ Downloaded file appears to be HTML instead of a ZIP archive.${NC}"
            echo -e "${YELLOW}This usually means the URL points to a web page instead of the direct file.${NC}"
            echo
            rm -f "$temp_file"
            if [[ "$confirm_download" == false ]]; then
                read -p "Press Enter to continue..."
            fi
            return 1
        fi

        # Check if the file is actually a ZIP
        if ! file "$temp_file" | grep -q "Zip archive data"; then
            echo -e "${YELLOW}⚠ Warning: Downloaded file doesn't appear to be a ZIP archive.${NC}"
            echo -e "${BLUE}File type detected:${NC} $(file "$temp_file")"
            echo
            if [[ "$confirm_download" == false ]]; then
                echo -e "${YELLOW}Do you want to continue anyway? [y/N]: ${NC}"
                read -p "" continue_anyway
                if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
                    rm -f "$temp_file"
                    echo -e "${YELLOW}Download cancelled.${NC}"
                    read -p "Press Enter to continue..."
                    return 1
                fi
            else
                echo -e "${BLUE}Automatically continuing with the non-ZIP file.${NC}"
            fi
        fi

        # Move the downloaded ZIP to src
        mv "$temp_file" "$zip_file"
        echo -e "${GREEN}✓ ZIP archive downloaded successfully${NC}"
    else
        echo -e "${GREEN}✓ ZIP file already exists.${NC}"
    fi

    # Extract the ZIP if src is empty or force extraction
    if [[ -z "$(ls -A "$src_dir")" || ! -d "${src_dir}/.extracted" ]]; then
        echo -e "${BLUE}Extracting ZIP archive...${NC}"
        if ! unzip -o "$zip_file" -d "$src_dir" >/dev/null 2>&1; then
            echo -e "${RED}✗ Failed to extract ZIP archive.${NC}"
            echo -e "${YELLOW}Make sure 'unzip' is installed and the file is a valid ZIP archive.${NC}"
            if [[ "$confirm_download" == false ]]; then
                read -p "Press Enter to continue..."
            fi
            return 1
        fi
        touch "${src_dir}/.extracted"
    else
        echo -e "${GREEN}✓ Files already extracted.${NC}"
    fi

    # Make all executables in src/ executable
    find "$src_dir" -type f \( -iname "*.sh" -o -iname "*x86_64" \) -exec chmod +x {} \;

    echo -e "${GREEN}✓ ZIP archive ready and all files configured successfully${NC}"
    echo
    return 0
}

echo -e "${CYAN}========== Game Server Creator ==========${NC}"
echo

# First check and download the ZIP if needed
if ! check_and_download_zip; then
    echo -e "${RED}Cannot proceed without the dedicated server files.${NC}"
    exit 1
fi

echo
count=$server_num

# Quick validation for id
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
ip_public="${public_ip}"
port=${port}
sdo_url="${sdo_url}"
sdo_port=${sdo_port}
sdo_username="${sdo_username}"
sdo_password="${sdo_password}"
sdo_verbose_level=${verbose}
[chat]
url="${chat_url}"
port=${chat_port}
username="${chat_username}"
password="${chat_password}"
verbose_level=${verbose}
[persistance]
enabled=${persistence_enabled}
DBHost="${persistence_dbhost}"
[metrics]
enabled=${metrics_enabled}
url="${metrics_url}"
port=${metrics_port}
username="${metrics_username}"
password="${metrics_password}"
verbose_level=${verbose}
EOF

  # Copy ALL files from src directory to server folder
  echo -e "${BLUE}Copying all server files for server ${num}...${NC}"
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  project_dir="$(dirname "$script_dir")"
  src_dir="$project_dir/src"

  # Copy all files and directories from src/ to server folder
  cp -r "$src_dir"/. "$folder/" || {
    echo -e "${RED}✗ Failed to copy files from src/ to $folder/${NC}"
    continue
  }
  
  rm $folder/StarDeception.dedicated_server.zip

  ((port++))
done

echo "$count servers created successfully."
