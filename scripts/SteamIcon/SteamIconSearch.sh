#!/bin/bash

# Check if input is provided and is a valid directory
if [ -z "$1" ] || [ ! -d "$1" ]; then
    echo "image://icon/steam"
    exit 1
fi

# Search for the files, routing permission errors to /dev/null so they don't print
LOGOS=$(find "$1" -type f -name "logo.png" 2>/dev/null)
HEADERS=$(find "$1" -type f -name "header.jpg" 2>/dev/null)

FOUND_ANY=0

# Print logo.png paths first if found
if [ -n "$LOGOS" ]; then
    echo "file://$LOGOS"
    FOUND_ANY=1
fi

# Print header.jpg paths next if found
if [ -n "$HEADERS" ]; then
    echo "file://$HEADERS"
    FOUND_ANY=1
fi

# If nothing was found, output ERROR
if [ "$FOUND_ANY" -eq 0 ]; then
    echo "image://icon/steam"
fi