#!/bin/bash

# Check if input is provided and is a valid directory
if [ -z "$1" ] || [ ! -d "$1" ]; then
    echo "image://icon/steam"
    exit 1
fi

# Search for the first matching file, routing permission errors to /dev/null
LOGO=$(find "$1" -type f -name "logo.png" -print -quit 2>/dev/null)
HEADER=$(find "$1" -type f -name "header.jpg" -print -quit 2>/dev/null)

if [ -n "$LOGO" ]; then
    echo "file://$LOGO"
elif [ -n "$HEADER" ]; then
    echo "file://$HEADER"
else
    echo "image://icon/steam"
fi