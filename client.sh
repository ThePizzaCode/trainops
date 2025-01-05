#!/bin/bash

MAIN_REQ_PORT=7000
MAIN_RES_PORT=7001

while true; do
    echo "===== Client Menu ====="
    echo "1) Search Train by Number"
    echo "2) Exit"
    read -p "Choice: " choice

    case "$choice" in
        1)
            read -p "Enter train number: " train_number

            # We'll build a JSON-ish or CSV-ish request (similar to your existing approach)
            # Let's do something like "search_train,train_number,1234"
            request="search_train,train_number,$train_number"

            # 1) Send request to main on port 7000
            echo "[client] Sending request to main: $request"
            echo -e "$request" | nc localhost "$MAIN_REQ_PORT" &

            # 2) Listen for final response on 7001
            echo "[client] Waiting for response on port $MAIN_RES_PORT..."
            response=$(nc -l -p "$MAIN_RES_PORT")
            echo "[client] Received response: $response"
            ;;
        2)
            echo "[client] Exiting."
            break
            ;;
        *)
            echo "Invalid choice."
            ;;
    esac
done
