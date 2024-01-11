#!/usr/bin/env bash
# Last modified: 2024 Jan 11

# 1. Authenticates to XetHub (if credentials are available)

if [ -n "$XETHUB_PAT" ] && [ -n "$XETHUB_USERNAME" ] && [ -n "$XETHUB_EMAIL" ]; then
    echo "Authenticating to Xethub..."
    xet login -u $XETHUB_USERNAME -e $XETHUB_EMAIL -p $XETHUB_PAT
else 
    echo "Xethub credentials not found. Skipping authentication..."
fi