#!/usr/bin/env bash

# git-autocommit.sh
# AI-powered git commit message generator using Ollama
# Generates descriptive commit messages from staged changes

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.git-autocommit.conf"

# Default configuration values
MODEL="qwen2.5-coder:14b"
MAX_DIFF_LINES=500
MAX_CONTEXT_CHARS=8000
OLLAMA_API_URL="http://localhost:11434/api/generate"
OLLAMA_TIMEOUT=30
COMMIT_SUBJECT_MAX_LENGTH=50
COMMIT_BODY_WRAP_LENGTH=72
TEMPERATURE=0.7
MAX_TOKENS=200
FALLBACK_MESSAGE_PREFIX="Auto-commit"
FALLBACK_MESSAGE_FORMAT="%Y-%m-%d %H:%M:%S"

# Load configuration file if it exists
load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${CONFIG_FILE}"
        echo -e "${BLUE}[INFO]${NC} Configuration loaded from ${CONFIG_FILE}"
    else
        echo -e "${YELLOW}[WARN]${NC} Configuration file not found, using defaults"
    fi
}

# Check prerequisites before running
check_prerequisites() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Not a git repository"
        exit 1
    fi

    # Check for required commands
    local missing_cmds=()
    for cmd in git curl jq; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Missing required commands: ${missing_cmds[*]}"
        exit 1
    fi

    # Check if there are staged changes
    if git diff --cached --quiet; then
        echo -e "${YELLOW}[INFO]${NC} No staged changes to commit"
        echo "Use 'git add' to stage changes first"
        exit 0
    fi

    # Check if Ollama is running
    if ! curl -s --max-time 5 "${OLLAMA_API_URL%/*}/tags" > /dev/null 2>&1; then
        echo -e "${YELLOW}[WARN]${NC} Ollama API is not responding at ${OLLAMA_API_URL}"
        echo "The script will offer a fallback commit message if AI generation fails"
    fi
}

# Get the git diff of staged changes
get_git_diff() {
    git diff --cached
}

# Truncate diff if it exceeds limits
truncate_diff_if_needed() {
    local diff="$1"
    local line_count
    local char_count
    
    line_count=$(echo "$diff" | wc -l | tr -d ' ')
    char_count=${#diff}

    # Check if diff exceeds limits
    if [[ $line_count -gt $MAX_DIFF_LINES ]] || [[ $char_count -gt $MAX_CONTEXT_CHARS ]]; then
        echo -e "${YELLOW}[INFO]${NC} Diff is large (${line_count} lines, ${char_count} chars), truncating..."
        
        # Get summary stats
        local stats
        stats=$(git diff --cached --stat)
        
        # Get first 100 lines of actual diff
        local truncated_diff
        truncated_diff=$(echo "$diff" | head -n 100)
        
        # Combine stats and truncated diff
        echo "${stats}"
        echo ""
        echo "${truncated_diff}"
        echo ""
        echo "... (diff truncated for AI context)"
    else
        echo "$diff"
    fi
}

# Build the prompt for the AI
build_prompt() {
    local diff="$1"
    local user_guidance="${2:-}"
    
    local prompt="You are generating a git commit message. Analyze the diff and create a detailed, descriptive commit message.

FORMAT REQUIREMENTS:
- First line: ${COMMIT_SUBJECT_MAX_LENGTH} characters or less (the subject)
- Blank line
- Body: Wrapped at ${COMMIT_BODY_WRAP_LENGTH} characters, providing detail about what changed and why

STYLE:
- Be descriptive and specific
- Focus on what changed and the purpose
- Use plain language, no prefixes like \"feat:\" or \"fix:\"
- Write in imperative mood (e.g., \"Add feature\" not \"Added feature\")

DIFF:
\`\`\`diff
${diff}
\`\`\`"

    if [[ -n "$user_guidance" ]]; then
        prompt="${prompt}

USER GUIDANCE: ${user_guidance}"
    fi

    prompt="${prompt}

Generate only the commit message, nothing else."

    echo "$prompt"
}

# Call Ollama API to generate commit message
call_ollama() {
    local prompt="$1"
    
    # Print status to stderr so it doesn't interfere with response capture
    echo -e "${BLUE}[INFO]${NC} Generating commit message with ${MODEL}..." >&2
    
    # Create JSON payload using jq to properly escape everything
    local json_payload
    json_payload=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$prompt" \
        --argjson temp "$TEMPERATURE" \
        --argjson tokens "$MAX_TOKENS" \
        '{
            model: $model,
            prompt: $prompt,
            stream: false,
            options: {
                temperature: $temp,
                num_predict: $tokens
            }
        }')
    
    # Make API call
    local response
    response=$(curl -s --max-time "${OLLAMA_TIMEOUT}" "${OLLAMA_API_URL}" \
        -H "Content-Type: application/json" \
        -d "$json_payload" 2>&1)
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Failed to call Ollama API (curl exit code: ${exit_code})" >&2
        return 1
    fi
    
    echo "$response"
}

# Parse the response from Ollama
parse_ollama_response() {
    local response="$1"
    
    # Check if response is empty
    if [[ -z "$response" ]]; then
        echo -e "${RED}[ERROR]${NC} Empty response from Ollama API" >&2
        return 1
    fi
    
    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Invalid JSON response from Ollama" >&2
        echo -e "${YELLOW}[DEBUG]${NC} Response preview: ${response:0:200}" >&2
        return 1
    fi
    
    # Extract the response field
    local message
    message=$(echo "$response" | jq -r '.response // empty')
    
    if [[ -z "$message" ]]; then
        echo -e "${RED}[ERROR]${NC} Empty message field in Ollama response" >&2
        return 1
    fi
    
    echo "$message"
}

# Format commit message to ensure proper line lengths
format_commit_message() {
    local message="$1"
    
    # Clean up any markdown code blocks or extra formatting
    message=$(echo "$message" | sed 's/```//g' | sed 's/^[[:space:]]*//g')
    
    # Split into lines
    local lines=()
    while IFS= read -r line; do
        lines+=("$line")
    done <<< "$message"
    
    # Check if first line exceeds subject length
    local subject="${lines[0]}"
    if [[ ${#subject} -gt $COMMIT_SUBJECT_MAX_LENGTH ]]; then
        # Truncate and add ellipsis
        subject="${subject:0:$((COMMIT_SUBJECT_MAX_LENGTH - 3))}..."
    fi
    
    # Reconstruct message
    local formatted="${subject}"
    
    # Add the rest of the lines (if any)
    if [[ ${#lines[@]} -gt 1 ]]; then
        formatted="${formatted}\n"
        for ((i=1; i<${#lines[@]}; i++)); do
            formatted="${formatted}\n${lines[$i]}"
        done
    fi
    
    echo -e "$formatted"
}

# Display the generated commit message
display_message() {
    local message="$1"
    
    echo ""
    echo -e "${GREEN}Generated Commit Message:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${message}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Get user input for accepting/rejecting the commit message
get_user_input() {
    local user_input=""
    
    # Print options to stderr so they aren't captured by command substitution
    echo -e "${YELLOW}Options:${NC}" >&2
    echo "  [y] Accept and commit" >&2
    echo "  [n] Cancel" >&2
    echo "  [any text] Provide guidance and regenerate" >&2
    echo "" >&2
    
    # Read input with explicit prompt (also to stderr)
    printf "Your choice: " >&2
    read -r user_input || true
    
    # Return only the user's choice on stdout
    echo "$user_input"
}

# Execute the git commit
execute_commit() {
    local message="$1"
    
    # Use a temporary file for the commit message
    local temp_file
    temp_file=$(mktemp)
    echo -e "$message" > "$temp_file"
    
    # Execute commit
    if git commit -F "$temp_file"; then
        rm "$temp_file"
        echo -e "${GREEN}[SUCCESS]${NC} Commit created successfully"
        return 0
    else
        rm "$temp_file"
        echo -e "${RED}[ERROR]${NC} Failed to create commit"
        return 1
    fi
}

# Generate a fallback commit message
generate_fallback_message() {
    local timestamp
    timestamp=$(date +"${FALLBACK_MESSAGE_FORMAT}")
    echo "${FALLBACK_MESSAGE_PREFIX}: ${timestamp}"
}

# Main function
main() {
    echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Git Auto-Commit with AI Generation     ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    
    # Load configuration
    load_config
    
    # Check prerequisites
    check_prerequisites
    
    # Get the staged diff
    echo -e "${BLUE}[INFO]${NC} Analyzing staged changes..."
    local diff
    diff=$(get_git_diff)
    
    # Truncate if needed
    diff=$(truncate_diff_if_needed "$diff")
    
    # Main loop for generating and refining commit message
    local user_guidance=""
    local attempt=1
    local max_attempts=5
    
    while true; do
        if [[ $attempt -gt $max_attempts ]]; then
            echo -e "${YELLOW}[WARN]${NC} Maximum attempts reached. Using fallback message."
            local fallback_msg
            fallback_msg=$(generate_fallback_message)
            display_message "$fallback_msg"
            
            read -r -p "Use this fallback message? [y/n]: " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                execute_commit "$fallback_msg"
                exit 0
            else
                echo -e "${YELLOW}[INFO]${NC} Commit cancelled"
                exit 0
            fi
        fi
        
        # Build prompt
        local prompt
        prompt=$(build_prompt "$diff" "$user_guidance")
        
        # Call Ollama
        local response
        if ! response=$(call_ollama "$prompt"); then
            echo -e "${YELLOW}[WARN]${NC} AI generation failed. Would you like to use a fallback message?"
            local fallback_msg
            fallback_msg=$(generate_fallback_message)
            echo "Fallback: ${fallback_msg}"
            
            read -r -p "Use fallback message? [y/n]: " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                execute_commit "$fallback_msg"
                exit 0
            else
                echo -e "${YELLOW}[INFO]${NC} Commit cancelled"
                exit 1
            fi
        fi
        
        # Parse response
        local commit_message
        if ! commit_message=$(parse_ollama_response "$response"); then
            echo -e "${YELLOW}[WARN]${NC} Failed to parse AI response. Would you like to use a fallback message?"
            local fallback_msg
            fallback_msg=$(generate_fallback_message)
            echo "Fallback: ${fallback_msg}"
            
            read -r -p "Use fallback message? [y/n]: " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                execute_commit "$fallback_msg"
                exit 0
            else
                echo -e "${YELLOW}[INFO]${NC} Commit cancelled"
                exit 1
            fi
        fi
        
        # Format message
        commit_message=$(format_commit_message "$commit_message")
        
        # Display message
        display_message "$commit_message"
        
        # Get user input
        local user_choice
        user_choice=$(get_user_input)
        
        case "$user_choice" in
            [Yy]|[Yy][Ee][Ss])
                execute_commit "$commit_message"
                exit 0
                ;;
            [Nn]|[Nn][Oo])
                echo -e "${YELLOW}[INFO]${NC} Commit cancelled"
                exit 0
                ;;
            *)
                # User provided guidance, regenerate
                user_guidance="$user_choice"
                attempt=$((attempt + 1))
                echo -e "${BLUE}[INFO]${NC} Regenerating with your guidance (attempt ${attempt}/${max_attempts})..."
                ;;
        esac
    done
}

# Run main function
main "$@"
