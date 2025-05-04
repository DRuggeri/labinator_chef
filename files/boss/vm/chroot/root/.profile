#!/usr/bin/bash

# Suppress logging to console (which trashes htop output)
dmesg -D

# Interactive view of what's going on
htop

# If user kills htop, drop them to a bash shell
exec bash