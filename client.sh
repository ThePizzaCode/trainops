#!/bin/bash

# Send a trip ID to the server and wait for a response
echo "Enter the Trip ID:"
read trip_id

# Send the Trip ID to the server
echo "$trip_id" | nc localhost 12345

# Listen for the response
nc -l 12346