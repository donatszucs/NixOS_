#!/usr/bin/env bash

# Define paths (Change these if your dotfiles folder name is different)
DOTFILES_DIR="$(pwd)/dotfiles"
CONFIG_DIR="$HOME/.config"

# Ensure the dotfiles destination directory exists
mkdir -p "$DOTFILES_DIR"

# Ask for input
echo -n "Enter the config folder name (e.g., mako, hypr, rofi): "
read -r TARGET

if [ -z "$TARGET" ]; then
    echo "Error: No folder name entered."
    exit 1
fi

TARGET_DOT="$DOTFILES_DIR/$TARGET"
TARGET_CONF="$CONFIG_DIR/$TARGET"

# CASE 1: Folder exists in dotfiles but not in .config (Just link it)
if [ -d "$TARGET_DOT" ] && [ ! -d "$TARGET_CONF" ]; then
    echo "Found $TARGET in dotfiles. Linking to $CONFIG_DIR..."
    ln -s "$TARGET_DOT" "$TARGET_CONF"
    echo "Done!"

# CASE 2: Folder exists in .config but NOT in dotfiles (Move then link)
elif [ -d "$TARGET_CONF" ] && [ ! -L "$TARGET_CONF" ] && [ ! -d "$TARGET_DOT" ]; then
    echo "Moving $TARGET to dotfiles and creating link..."
    mv "$TARGET_CONF" "$TARGET_DOT"
    ln -s "$TARGET_DOT" "$TARGET_CONF"
    echo "Done!"

# CASE 3: Folder exists in both (Avoid overwriting)
elif [ -d "$TARGET_DOT" ] && [ -d "$TARGET_CONF" ]; then
    if [ -L "$TARGET_CONF" ]; then
        echo "Already linked!"
    else
        echo "Error: $TARGET exists in both locations. Resolve manually to avoid data loss."
    fi

# CASE 4: Folder exists nowhere
else
    echo "Error: Could not find '$TARGET' in .config or dotfiles."
fi