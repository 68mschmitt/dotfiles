#!/bin/bash

CONFIG_DIR="$HOME/.config/my-wallpapers"

mkdir -p "$CONFIG_DIR"

# Copy the config files
cp default-configs/.* "$CONFIG_DIR"

# Copy the config script
cp default-configs/_* "$CONFIG_DIR"
