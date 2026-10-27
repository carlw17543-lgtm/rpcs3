#!/bin/bash

# Copies the important parts of a failed build log into GitHub error annotations.
# GitHub's public API serves annotations without signing in, unlike the full job log.
# Usage: .ci/annotate-log.sh <log file> <title>

log="$1"
title="$2"

annotate() {
    # Workflow commands need % and newlines escaped
    content="$(head -n 150 | cut -c1-300 | tr -d '\r' | sed -e 's/%/%25/g' | awk 'BEGIN { ORS = "%0A" } { print }')"
    if [ -n "$content" ]; then
        echo "::error title=$title - $1::$content"
    fi
}

grep -E -A 10 -m 8 'CMake Error|error:|FAILED:|fatal:' "$log" | annotate "first errors"
grep -E ': (fatal )?error: ' "$log" | sed -E 's/^.*: (fatal )?error: //' | sort | uniq -c | sort -rn | annotate "most common errors"
grep '^FAILED: ' "$log" | sed -E 's/^FAILED: //' | annotate "failed build steps"
tail -n 60 "$log" | annotate "end of log"
