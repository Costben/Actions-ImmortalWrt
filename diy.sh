#!/bin/bash
# Default IP set to 192.168.31.1 (match current LAN network)
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate
