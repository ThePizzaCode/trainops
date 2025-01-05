#!/bin/bash

DB_PATH="../trainops/gtfs.db"

# Debugging function to display query results for debugging purposes
debug_query() {
    local query="$1"
    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
$query
EOF
}

# Function to search for trains by date, departure station, and arrival station
search_itinerary() {
    # read -p "Enter the date (YYYY-MM-DD): " date
    # read -p "Enter the departure station name: " departure_station
    # read -p "Enter the arrival station name: " arrival_station

    date=$1
    departure_station=$2
    arrival_station=$3

    echo "Searching trains for the given itinerary..."

    # SQL query to find trains matching the itinerary
    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT DISTINCT trips.trip_id AS "Trip ID",
                trips.trip_short_name AS "Train Name",
                dep_times.departure_time AS "Departure Time",
                arr_times.arrival_time AS "Arrival Time"
FROM trips
JOIN stop_times AS dep_times ON trips.trip_id = dep_times.trip_id
JOIN stop_times AS arr_times ON trips.trip_id = arr_times.trip_id
JOIN stops AS dep_stops ON dep_times.stop_id = dep_stops.stop_id
JOIN stops AS arr_stops ON arr_times.stop_id = arr_stops.stop_id
JOIN calendar_dates ON trips.service_id = calendar_dates.service_id
WHERE dep_stops.stop_name = '$departure_station'
  AND arr_stops.stop_name = '$arrival_station'
  AND calendar_dates.date = '$date'
  AND dep_times.stop_sequence < arr_times.stop_sequence
ORDER BY dep_times.departure_time;
EOF
}


# Function to search by trip ID
search_by_trip_id() {
    trip_id=$1

    sqlite3 "$DB_PATH" <<EOF
.headers off
.mode csv
    SELECT stop_times.stop_sequence AS "Stop Sequence",
        stops.stop_name AS "Stop Name",
        stop_times.arrival_time AS "Arrival Time",
        stop_times.departure_time AS "Departure Time"
    FROM stop_times
    JOIN stops ON stop_times.stop_id = stops.stop_id
    WHERE stop_times.trip_id = '$trip_id'
    ORDER BY CAST(stop_times.stop_sequence AS INTEGER);
EOF
}

handle_request() {
    IFS="," read -r -a request <<< "$1"
    
    endpoint=${request[0]}

    case $endpoint in
        train_id)
            id=${request[1]}
            search_by_trip_id $id
            ;;
        route)
            date=${request[1]}
            from=${request[2]}
            to=${request[3]}
            search_itinerary $date $from $to 
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
}

handle_request $1