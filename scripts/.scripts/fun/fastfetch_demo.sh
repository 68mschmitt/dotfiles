#!/bin/bash
#
# Fastfetch Demo Script
# Demonstrates all the different output examples and capabilities of fastfetch
#
# Requirements: fastfetch installed (brew install fastfetch)
# Optional: Nerd Font for icons to display correctly
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check if fastfetch is installed
if ! command -v fastfetch &> /dev/null; then
    echo -e "${RED}Error: fastfetch is not installed${NC}"
    echo "Install with: brew install fastfetch (macOS) or your package manager"
    exit 1
fi

# Function to print section header
section() {
    echo ""
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW}  $1${NC}"
    echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to print subsection
subsection() {
    echo ""
    echo -e "${BOLD}${GREEN}── $1 ──${NC}"
    echo ""
}

# Function to pause between demos
pause() {
    echo ""
    echo -e "${MAGENTA}Press Enter to continue...${NC}"
    read -r
    clear
}

# Start demo
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ______        _    __     _       _       ____                       
 |  ____|      | |  / _|   | |     | |     |  _ \  ___ _ __ ___   ___  
 | |__ __ _ ___| |_| |_ ___| |_ ___| |__   | | | |/ _ \ '_ ` _ \ / _ \ 
 |  __/ _` / __| __|  _/ _ \ __/ __| '_ \  | |_| |  __/ | | | | | (_) |
 | | | (_| \__ \ |_| ||  __/ || (__| | | | |____/ \___|_| |_| |_|\___/ 
 |_|  \__,_|___/\__|_| \___|\__\___|_| |_|                             
                                                                       
EOF
echo -e "${NC}"
echo -e "${BOLD}This script demonstrates all the output examples and capabilities of fastfetch${NC}"
echo ""
echo -e "Fastfetch version: ${GREEN}$(fastfetch --version-raw)${NC}"
echo ""
pause

# ============================================================================
# SECTION 1: Default Output
# ============================================================================
section "1. DEFAULT OUTPUT"
subsection "Standard fastfetch output with auto-detected OS logo"
fastfetch
pause

# ============================================================================
# SECTION 2: Built-in Presets
# ============================================================================
section "2. BUILT-IN PRESETS"

subsection "2.1 Neofetch Style (neofetch.jsonc)"
echo "Classic neofetch-compatible output format"
fastfetch -c neofetch.jsonc
pause

subsection "2.2 Paleofetch Style (paleofetch.jsonc)"
echo "Paleofetch-inspired minimal layout with grouped sections"
fastfetch -c paleofetch.jsonc
pause

subsection "2.3 Screenfetch Style (screenfetch.jsonc)"
echo "Screenfetch-compatible output"
fastfetch -c screenfetch.jsonc
pause

subsection "2.4 All Modules (all.jsonc)"
echo "Display ALL available modules - comprehensive system info"
fastfetch -c all.jsonc 2>&1 | head -80
echo -e "\n${YELLOW}(Output truncated - there are 70+ modules available)${NC}"
pause

# ============================================================================
# SECTION 3: Example Presets (Numbered Examples)
# ============================================================================
section "3. EXAMPLE PRESETS"

subsection "3.1 Example 2 - Hardware/Software Sections with Box Drawing"
echo "Organized layout with bordered sections"
fastfetch -c examples/2.jsonc 2>&1
pause

subsection "3.2 Example 3 - Compact Minimal"
echo "Very minimal output with only essential info"
fastfetch -c examples/3.jsonc 2>&1
pause

subsection "3.3 Example 7 - Tree Structure Layout"
echo "Hierarchical tree-style output with Nerd Font icons"
fastfetch -c examples/7.jsonc 2>&1
pause

subsection "3.4 Example 10 - Boxed Tree Layout"
echo "Tree structure with surrounding box borders"
fastfetch -c examples/10.jsonc 2>&1
pause

subsection "3.5 Example 13 - Bordered Card Layout"
echo "Card-style display with custom borders"
fastfetch -c examples/13.jsonc 2>&1
pause

subsection "3.6 Example 21 - Colorful Block Indicators"
echo "Color blocks with labeled modules"
fastfetch -c examples/21.jsonc 2>&1
pause

subsection "3.7 Example 27 - Clean Minimal Labels"
echo "Clean lowercase labels with minimal styling"
fastfetch -c examples/27.jsonc 2>&1
pause

# ============================================================================
# SECTION 4: Custom Structure Examples
# ============================================================================
section "4. CUSTOM STRUCTURE EXAMPLES"

subsection "4.1 Minimal Structure - No Logo"
echo "Only essential system info without ASCII art logo"
fastfetch -s "Title:OS:Kernel:CPU:GPU:Memory" --logo none
pause

subsection "4.2 Hardware Focus"
echo "Hardware-focused output"
fastfetch -s "Title:Separator:Host:CPU:CPUUsage:GPU:Memory:Disk:Battery" --logo none
pause

subsection "4.3 Software Focus"
echo "Software and environment focused"
fastfetch -s "Title:Separator:OS:Kernel:Shell:Terminal:TerminalFont:Packages:Uptime" --logo none
pause

subsection "4.4 Network Information"
echo "Network-focused output"
fastfetch -s "Title:Separator:LocalIp:Wifi:DNS" --logo none
pause

subsection "4.5 Display Information"
echo "Display and graphics focused"
fastfetch -s "Title:Separator:Display:Brightness:GPU:OpenGL:Vulkan" --logo none
pause

subsection "4.6 Storage Information"
echo "Storage focused output"
fastfetch -s "Title:Separator:Disk:PhysicalDisk:Memory:Swap" --logo none
pause

# ============================================================================
# SECTION 5: Different Logos
# ============================================================================
section "5. DIFFERENT LOGOS"

subsection "5.1 Arch Linux Logo"
fastfetch --logo arch -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.2 Ubuntu Logo"
fastfetch --logo ubuntu -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.3 Debian Logo"
fastfetch --logo debian -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.4 Fedora Logo"
fastfetch --logo fedora -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.5 Windows Logo"
fastfetch --logo windows -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.6 NixOS Logo"
fastfetch --logo nixos -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1 | head -25
pause

subsection "5.7 Small Logo Variant (arch_small)"
fastfetch --logo arch_small -s "Title:Separator:OS:Kernel:CPU:Memory"
pause

# ============================================================================
# SECTION 6: Output Formats
# ============================================================================
section "6. OUTPUT FORMATS"

subsection "6.1 JSON Output"
echo "Machine-readable JSON format (truncated)"
fastfetch --json 2>&1 | head -60
echo -e "\n${YELLOW}(Output truncated)${NC}"
pause

subsection "6.2 Pipe Mode (No Colors)"
echo "Plain text output without ANSI escape codes"
fastfetch --pipe -s "Title:Separator:OS:Kernel:CPU:Memory" 2>&1
pause

# ============================================================================
# SECTION 7: Available Modules List
# ============================================================================
section "7. ALL AVAILABLE MODULES (74 Total)"

echo -e "${YELLOW}Fastfetch supports 74 different information modules:${NC}"
echo ""
fastfetch --list-modules
pause

# ============================================================================
# SECTION 8: Available Logos Count
# ============================================================================
section "8. AVAILABLE LOGOS"

LOGO_COUNT=$(fastfetch --list-logos | wc -l)
echo -e "Fastfetch has ${GREEN}${LOGO_COUNT}${NC} built-in logos!"
echo ""
echo -e "${YELLOW}First 50 logos:${NC}"
fastfetch --list-logos | head -52
echo ""
echo -e "${YELLOW}Use: fastfetch --logo <name> to use any logo${NC}"
pause

# ============================================================================
# SECTION 9: Color Examples
# ============================================================================
section "9. COLOR CUSTOMIZATION"

subsection "9.1 Custom Key Color"
fastfetch -s "Title:OS:Kernel:CPU:Memory" --logo none --color-keys blue
pause

subsection "9.2 Custom Output Color"
fastfetch -s "Title:OS:Kernel:CPU:Memory" --logo none --color-output green
pause

subsection "9.3 Custom Separator"
fastfetch -s "Title:OS:Kernel:CPU:Memory" --logo none --separator " -> "
pause

# ============================================================================
# SECTION 10: Individual Module Examples
# ============================================================================
section "10. INDIVIDUAL MODULE EXAMPLES"

subsection "10.1 Battery Module"
fastfetch -s Battery --logo none 2>&1

subsection "10.2 CPU with Cache"
fastfetch -s "CPU:CPUCache:CPUUsage" --logo none 2>&1

subsection "10.3 Display Modules"
fastfetch -s "Display:Monitor:Brightness" --logo none 2>&1

subsection "10.4 Memory Modules"
fastfetch -s "Memory:PhysicalMemory:Swap" --logo none 2>&1

subsection "10.5 Sound & Media"
fastfetch -s "Sound:Media:Player" --logo none 2>&1

subsection "10.6 Bluetooth & Peripherals"
fastfetch -s "Bluetooth:BluetoothRadio:Mouse:Keyboard" --logo none 2>&1

subsection "10.7 Graphics APIs"
fastfetch -s "OpenGL:OpenCL:Vulkan" --logo none 2>&1

subsection "10.8 Date, Locale, Users"
fastfetch -s "DateTime:Locale:Users:Processes" --logo none 2>&1

subsection "10.9 Terminal Color Palette"
fastfetch -s "Colors" --logo none 2>&1
pause

# ============================================================================
# SECTION 11: Features & Capabilities
# ============================================================================
section "11. COMPILED FEATURES"

echo -e "${YELLOW}Features this fastfetch build was compiled with:${NC}"
fastfetch --list-features
pause

# ============================================================================
# SECTION 12: Help Information
# ============================================================================
section "12. GETTING HELP"

echo -e "${YELLOW}Key commands for help:${NC}"
echo ""
echo -e "  ${GREEN}fastfetch --help${NC}              - General help"
echo -e "  ${GREEN}fastfetch --help <command>${NC}    - Help for specific option"
echo -e "  ${GREEN}fastfetch --list-modules${NC}      - List all modules"
echo -e "  ${GREEN}fastfetch --list-logos${NC}        - List all logos"
echo -e "  ${GREEN}fastfetch --list-presets${NC}      - List preset configs"
echo -e "  ${GREEN}fastfetch --print-logos${NC}       - Display all logos"
echo -e "  ${GREEN}fastfetch --gen-config${NC}        - Generate config file"
echo -e "  ${GREEN}fastfetch --gen-config-full${NC}   - Generate full config"
echo ""
echo -e "${YELLOW}Config file location:${NC} ~/.config/fastfetch/config.jsonc"
pause

# ============================================================================
# FINAL SUMMARY
# ============================================================================
section "DEMO COMPLETE!"

echo -e "${BOLD}Summary of Fastfetch Capabilities:${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} 74 information modules"
echo -e "  ${GREEN}✓${NC} 500+ built-in ASCII logos"
echo -e "  ${GREEN}✓${NC} Multiple preset configurations"
echo -e "  ${GREEN}✓${NC} JSON output format"
echo -e "  ${GREEN}✓${NC} Highly customizable"
echo -e "  ${GREEN}✓${NC} Cross-platform (Linux, macOS, Windows, BSD)"
echo -e "  ${GREEN}✓${NC} Image logo support (Kitty, iTerm, Sixel)"
echo -e "  ${GREEN}✓${NC} Nerd Font icon support"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo -e "  GitHub: https://github.com/fastfetch-cli/fastfetch"
echo -e "  Wiki:   https://github.com/fastfetch-cli/fastfetch/wiki"
echo ""
echo -e "${CYAN}Thanks for watching the demo!${NC}"
echo ""
