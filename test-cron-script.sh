#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/test-cron.log"

{
    echo "-----"
    date "+%Y-%m-%d %H:%M:%S %Z"
    echo "user: $(whoami)"
    echo "pwd: $(pwd)"
    echo "script: $0"
    echo "args: $*"
} >> "$LOG_FILE"
