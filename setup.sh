#!/usr/bin/env bash

# Define paths
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
DOTFILES_DIR="$SCRIPT_DIR/dotfiles"
REPO_CONFIG="$SCRIPT_DIR/configuration.nix"
NIX_PATH="/etc/nixos/configuration.nix"
CONFIG_DIR="$HOME/.config"

echo "--- ❄️  NixOS System & Dotfiles Setup ---"

# --- PART 1: Link configuration.nix ---
echo -e "\n[1/2] Checking System Configuration..."
if [ -L "$NIX_PATH" ]; then
    echo "✅ /etc/nixos/configuration.nix is already linked."
else
    if [ -f "$NIX_PATH" ]; then
        echo "⚠️  Found existing file at $NIX_PATH."
        read -p "   Backup and link repo version? (y/n): " resp
        if [[ "$resp" =~ ^([yY])$ ]]; then
            sudo mv "$NIX_PATH" "$NIX_PATH.bak"
            sudo ln -s "$REPO_CONFIG" "$NIX_PATH"
            echo "🔗 Link created (Backup at .bak)."
        fi
    else
        sudo ln -s "$REPO_CONFIG" "$NIX_PATH"
        echo "🔗 Link created."
    fi
fi

# --- PART 2: Link All Dotfiles ---
echo -e "\n[2/2] Linking Dotfiles to $CONFIG_DIR..."

if [ ! -d "$DOTFILES_DIR" ]; then
    echo "❌ Error: 'dotfiles' folder not found in $SCRIPT_DIR"
    exit 1
fi

# Loop through every folder inside the dotfiles directory
for folder in "$DOTFILES_DIR"/*/; do
    target=$(basename "$folder")
    target_conf="$CONFIG_DIR/$target"
    target_dot="$DOTFILES_DIR/$target"

    # Check if it's a link AND if the target actually exists
    if [ -L "$target_conf" ]; then
        if [ -e "$target_conf" ]; then
            echo "✅ $target is already linked and valid."
        else
            echo "❌ $target link is BROKEN. Repairing..."
            rm "$target_conf"
            ln -s "$target_dot" "$target_conf"
        fi
    elif [ -d "$target_conf" ]; then
        echo "⚠️  $target exists as a real folder. Overwrite? (y/n)"
        read -p "> " resp
        if [[ "$resp" =~ ^([yY])$ ]]; then
            rm -rf "$target_conf"
            ln -s "$target_dot" "$target_conf"
        fi
    else
        ln -s "$target_dot" "$target_conf"
        echo "🔗 $target linked for the first time."
    fi
done

echo -e "\n--- 🎉 Setup Complete! ---"
echo "Run 'sudo nixos-rebuild switch' to apply system changes."