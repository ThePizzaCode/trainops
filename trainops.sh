#!/bin/bash

DB_PATH="gtfs.db"

dep_stop_id="10017" # Fixed departure station ID for Bucuresti Nord

extract_stop_ids() {
  local db_path="$1"      # Path to the SQLite database
  local arr_stop="$2"     # Arrival stop name

  # Query to get stop ID for the given arrival stop name
  local query="
    SELECT stop_id, stop_name
    FROM stops
    WHERE stop_name = '$arr_stop';
  "

  # Execute the query and store results
  local result
  result=$(sqlite3 "$db_path" "$query")

  # Parse the results to extract the arrival stop ID
  while IFS='|' read -r stop_id stop_name; do
    if [[ "$stop_name" == "$arr_stop" ]]; then
      arr_stop_id="$stop_id"
    fi
  done <<< "$result"

  # Output the results for debugging
  echo "Arrival Stop ID: $arr_stop_id"
}

search_by_trip_id() {
    local trip_id="$1"
    local train_info
    local stop_times

    # Fetch route details
    train_info=$(sqlite3 -json "$DB_PATH" <<EOF
SELECT routes.route_short_name AS "route_short_name",
       routes.route_long_name AS "route_long_name"
FROM routes
JOIN trips ON routes.route_id = trips.route_id
WHERE trips.trip_id = "$trip_id";
EOF
)

    # Check if the train info is empty (no train found)
    if [[ -z "$train_info" || "$train_info" == "[]" ]]; then
        echo "Error: Train not found for trip_id $trip_id."
        return
    fi

    # Fetch stop times
    stop_times=$(sqlite3 -json "$DB_PATH" <<EOF
SELECT stop_times.stop_sequence AS "stop_sequence",
       stops.stop_name AS "stop_name",
       stop_times.arrival_time AS "arrival_time",
       stop_times.departure_time AS "departure_time"
FROM stop_times
JOIN stops ON stop_times.stop_id = stops.stop_id
WHERE stop_times.trip_id = "$trip_id"
ORDER BY stop_times.stop_sequence;
EOF
)

    # Display the results
    echo "Train Information:"
    echo "$train_info"
    echo "\nStop Times:"
    echo "$stop_times"
}

search_itinerary() {
    local departure_time="$1"
    local arrival_station="$2"

    extract_stop_ids "$DB_PATH" "$arrival_station"

    # Fetch itinerary details
    itinerary=$(sqlite3 -json "$DB_PATH" <<EOF
WITH StopTimesWithNames AS (
    SELECT st.trip_id, st.stop_id, st.stop_sequence, st.departure_time
    FROM stop_times st
    WHERE st.stop_id IN ('$dep_stop_id', '$arr_stop_id') 
),
TripsBetweenStops AS (
    SELECT 
        d.trip_id
    FROM StopTimesWithNames d
    INNER JOIN StopTimesWithNames a ON d.trip_id = a.trip_id
    WHERE d.stop_id = '$dep_stop_id' 
      AND a.stop_id = '$arr_stop_id'
      AND d.stop_sequence < a.stop_sequence 
      AND d.departure_time >= '$departure_time'
)
SELECT DISTINCT trip_id
FROM TripsBetweenStops;
EOF
)

    # Check if the itinerary is empty (no itinerary found)
    if [[ -z "$itinerary" || "$itinerary" == "[]" ]]; then
        echo "Error: No itinerary found from Bucuresti Nord to $arrival_station after $departure_time."
        return
    fi

    # Display the results
    echo "Itinerary Found:"
    echo "$itinerary"
}

# Main menu
while true; do
    echo "Train Operations Console Menu"
    echo "1. Search Train by Trip ID"
    echo "2. Search Itinerary by Arrival Station"
    echo "3. Exit"
    read -p "Select an option: " choice

    case "$choice" in
        1)
            read -p "Enter Trip ID: " trip_id
            if [[ -z "$trip_id" ]]; then
                echo "Error: Trip ID is required"
            else
                search_by_trip_id "$trip_id"
            fi
            ;;
        2)
            read -p "Enter Arrival Station: " arrival_station
            read -p "Enter Departure Time (HH:MM:SS): " departure_time
            if [[ -z "$arrival_station" || -z "$departure_time" ]]; then
                echo "Error: All fields are required"
            else
                search_itinerary "$departure_time" "$arrival_station"
            fi
            ;;
        3)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
