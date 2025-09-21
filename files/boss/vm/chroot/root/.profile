#!/usr/bin/bash

if [ -n "$SSH_CONNECTION" ];then
    # If we're an SSH session, don't do anything special
    return
fi

# Suppress logging to console (which trashes htop output)
dmesg -D

# Get time set up
ntpdate -q boss.local

screen -c /root/.config/screen/console

# If user kills screen, drop them to a bash shell
exec bash