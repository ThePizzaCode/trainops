#!/bin/bash

REQ_PORT=12345 # Port for sending requests
RES_PORT=12346 # Port for receiving responses

# Function to send a request and receive a response
send_request() {
    local request="$1"

    # Send the request to the server
    echo -e "$request" | nc localhost "$REQ_PORT" &

    # Listen for the response on the response port
    echo "Waiting for server response..."
    response=$(nc -l "$RES_PORT")
    echo "Response received: $response"
}

# Menu for client
while true; do
    echo "Choose an option:"
    echo "1. Search Train by Number"
    echo "2. Search Itinerary"
    echo "3. Exit"
    read -p "Enter your choice: " choice

    case "$choice" in
        1)
            read -p "Enter train number: " train_number
            request="{\"type\":\"search_train\",\"train_number\":\"$train_number\"}"
            send_request "$request"
            ;;
        2)
            read -p "Enter date (YYYY-MM-DD): " date
            read -p "Enter departure station: " departure_station
            read -p "Enter arrival station: " arrival_station
            request="{\"type\":\"search_itinerary\",\"date\":\"$date\",\"departure_station\":\"$departure_station\",\"arrival_station\":\"$arrival_station\"}"
            send_request "$request"
            ;;
        3)
            echo "Exiting client."
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done