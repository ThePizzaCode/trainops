#!/bin/bash

# Created by: Gabriel Stanciu
# Created on: 23 Dec 2024
# Main script for Train Lookup

# Source utility and train operations
source utils.sh
source train_ops.sh
source helpers.sh

# Main loop
while true; do
    show_menu
    read -p "Enter your choice (1-3): " choice

    case $choice in
        1) search_train_number ;;
        2) list_all_trains ;;
        3) echo "Goodbye!"; break ;;
        *) echo "Invalid choice. Please try again." ;;
    esac
done
