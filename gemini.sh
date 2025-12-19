#!/bin/bash

# ==============================================================================
# GEMINI CLI SETUP SCRIPT FOR PROXMOX LXC
# ==============================================================================
# This script automates the creation and configuration of an LXC container
# for running the Google Gemini CLI.
#
# USAGE: ./gemini.sh
# AUTHOR: Gemini CLI Assistant
# ==============================================================================

# --- CONFIGURATION VARIABLES ---
CONTAINER_ID=100
HISTNAME="gemini"
PASSWORD="telkom123"
STORAGE_ID="local-lvm"
DISK_SIZE_GB="8"

# LXC Template Path (Adjust based on your local storage)
TEMPLATE_PATH="local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

# Network Configuration
NET_INTERFACE="eth0"
BRIDGE="vmbrlan" # WARNING: Change to 'vmbr0' if using default Proxmox bridge
IP_CONFIG="dhcp"

# --- MAIN EXECUTION ---

echo "=========================================="
echo "   GEMINI CLI SETUP INITIATED             "
echo "=========================================="

# 1. CLEANUP: Remove existing container if it exists
if pct status $CONTAINER_ID >/dev/null 2>&1;
then
    echo "[WARN] Existing container $CONTAINER_ID detected. Removing..."
    pct stop $CONTAINER_ID >/dev/null 2>&1
    pct destroy $CONTAINER_ID --purge >/dev/null
    echo "[INFO] Cleanup complete."
fi

# 2. PROVISION: Create the new LXC container
echo "[INFO] Creating container $CONTAINER_ID on storage '$STORAGE_ID' (${DISK_SIZE_GB}GB)..."

pct create $CONTAINER_ID $TEMPLATE_PATH \
    --hostname "$HOSTNAME" \
    --password "$PASSWORD" \
    --rootfs "volume=$STORAGE_ID:$DISK_SIZE_GB" \
    --memory 2048 \
    --cores 2 \
    --net0 "name=$NET_INTERFACE,bridge=$BRIDGE,ip=$IP_CONFIG" \
    --features nesting=1 \
    --onboot 1 \
    --unprivileged 1

# Check for creation errors
if [ $? -ne 0 ]; then
    echo ""
    echo "[FATAL ERROR] Container creation failed."
    echo "Possible causes:"
    echo "  - The storage ID '$STORAGE_ID' does not exist."
    echo "  - The template path '$TEMPLATE_PATH' is incorrect."
    echo "  - The bridge '$BRIDGE' is invalid (try 'vmbr0')."
    echo ""
    echo "Manual debug command:"
    echo "pct create $CONTAINER_ID $TEMPLATE_PATH --rootfs volume=$STORAGE_ID:$DISK_SIZE_GB --storage $STORAGE_ID"
    exit 1
fi

# 3. INITIALIZE: Start container and install dependencies
echo "[INFO] Container created successfully. Starting up..."
pct start $CONTAINER_ID

# Wait for network initialization (simple sleep)
sleep 5

echo "[INFO] Installing Node.js, NPM, and SSH tools..."
# Update apt cache and install required packages
pct exec $CONTAINER_ID -- bash -c "apt-get update -qq && apt-get install -y -qq curl git nodejs npm openssh-server openssh-client >/dev/null"

echo "[INFO] Installing Google Gemini CLI (Global)"
pct exec $CONTAINER_ID -- npm install -g @google/gemini-cli --silent

# 4. COMPLETION
echo "=========================================="
echo "   SETUP COMPLETED SUCCESSFULLY           "
echo "=========================================="
echo "Next Steps:"
echo "1. Enter the container:  pct enter $CONTAINER_ID"
echo "2. Start Gemini:         gemini"
echo "3. (Optional) Auto-mode: gemini --yolo"
echo "=========================================="