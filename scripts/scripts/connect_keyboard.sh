#!/usr/bin/bash

# Device MAC address
DEVICE_MAC="6C:93:08:65:6C:50"

# Check if the device is already connected
if bluetoothctl info "$DEVICE_MAC" | grep -q "Connected: yes"; then
    echo "Device is already connected."
    exit 0
fi

# Start Bluetooth service
sudo systemctl start bluetooth.service

# Turn on the Bluetooth adapter
bluetoothctl power on

# Trust the device
bluetoothctl trust "$DEVICE_MAC"

# Disconnect if already connected (to reset connection)
bluetoothctl disconnect "$DEVICE_MAC"
sleep 1

# Connect to the device
bluetoothctl connect "$DEVICE_MAC"

