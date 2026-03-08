#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 -f <file> | -p <prompt> [-a <url>] [-u <user>] [-P <pass>] [-d <dir>] [-l <log-level>] [-L]" >&2
    echo "  -f <file>       Read prompt from file" >&2
    echo "  -p <prompt>     Use prompt string directly" >&2
    echo "  -a <url>        Attach to a running opencode server (e.g. https://host:4096)" >&2
    echo "  -u <user>       Basic auth username (prefer env var OPENCODE_AUTH_USER)" >&2
    echo "  -P <pass>       Basic auth password (prefer env var OPENCODE_AUTH_PASS)" >&2
    echo "  -d <dir>        Working directory on the server (used with -a)" >&2
    echo "  -l <log-level>  opencode log level (DEBUG|INFO|WARN|ERROR), default: INFO" >&2
    echo "  -L              Enable --print-logs (disabled by default)" >&2
    echo "" >&2
    echo "  Credentials are resolved in order: flags > env vars OPENCODE_AUTH_USER / OPENCODE_AUTH_PASS" >&2
    exit 1
}

prompt=""
attach_url=""
auth_user="${OPENCODE_AUTH_USER:-}"   # prefer env vars — flags override if provided
auth_pass="${OPENCODE_AUTH_PASS:-}"
work_dir=""
log_level="INFO"
print_logs=""

while getopts ":f:p:a:u:P:d:l:L" opt; do
    case $opt in
        f) prompt=$(cat "$OPTARG") ;;
        p) prompt="$OPTARG" ;;
        a) attach_url="$OPTARG" ;;
        u) auth_user="$OPTARG" ;;
        P) auth_pass="$OPTARG" ;;
        d) work_dir="$OPTARG" ;;
        l) log_level="$OPTARG" ;;
        L) print_logs="--print-logs" ;;
        *) usage ;;
    esac
done

if [ -z "$prompt" ]; then
    usage
fi

if [[ -z "${ZHIPU_API_KEY:-}" ]]; then
    echo "::error::ZHIPU_API_KEY is not set" >&2
    exit 1
fi

# Embed basic auth credentials into the attach URL if provided
if [[ -n "$attach_url" && -n "$auth_user" && -n "$auth_pass" ]]; then
    # Warn if credentials are being sent over plain HTTP
    if [[ "$attach_url" == http://* ]]; then
        echo "::warning::Basic auth credentials over http:// are sent in plaintext — use https://" >&2
    fi
    scheme="${attach_url%%://*}"
    rest="${attach_url#*://}"
    attach_url="${scheme}://${auth_user}:${auth_pass}@${rest}"
elif [[ ( -n "$auth_user" || -n "$auth_pass" ) && -z "$attach_url" ]]; then
    echo "::error::OPENCODE_AUTH_USER/PASS (or -u/-P) require -a <url>" >&2
    exit 1
fi

# Build opencode args — optional flags only included when set
opencode_args=(
    run
    --model zai-coding-plan/glm-5
    --agent orchestrator
    --log-level "$log_level"
)
[[ -n "$attach_url" ]] && opencode_args+=(--attach "$attach_url")
[[ -n "$work_dir"   ]] && opencode_args+=(--dir    "$work_dir")
[[ -n "$print_logs" ]] && opencode_args+=("$print_logs")
opencode_args+=("$prompt")

echo "Starting opencode at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
set +e
stdbuf -oL -eL timeout 10m opencode "${opencode_args[@]}" 2>&1
OPENCODE_EXIT=$?
set -e

if [[ ${OPENCODE_EXIT} -eq 124 ]]; then
    echo "::warning::opencode run timed out after 10 minutes; continuing workflow"
    exit 0
fi

exit ${OPENCODE_EXIT}
