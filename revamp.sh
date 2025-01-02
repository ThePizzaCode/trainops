#!/bin/bash

DB_PATH="gtfs.db"

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
search_trains_by_date() {
    read -p "Enter the date (YYYY-MM-DD): " date
    read -p "Enter the departure station name: " departure_station
    read -p "Enter the arrival station name: " arrival_station

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
WHERE dep_stops.stop_name = "$departure_station"
  AND arr_stops.stop_name = "$arrival_station"
  AND calendar_dates.date = "$date"
  AND dep_times.stop_sequence < arr_times.stop_sequence
ORDER BY dep_times.departure_time;
EOF
}

# Function to test/debug schema
validate_schema() {
    echo "Validating database schema..."
    
    # List all tables
    echo "Tables in the database:"
    debug_query ".tables"

    # Display schema of `trips`, `stops`, `stop_times`, and `calendar_dates`
    echo "Schema of trips:"
    debug_query ".schema trips"
    
    echo "Schema of stops:"
    debug_query ".schema stops"

    echo "Schema of stop_times:"
    debug_query ".schema stop_times"

    echo "Schema of calendar_dates:"
    debug_query ".schema calendar_dates"
}

# Function to search by trip ID
search_by_trip_id() {
    read -p "Enter a train number (trip ID): " trip_id

    echo "Fetching route details for Train ID: $trip_id..."

    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT routes.route_short_name AS "Route Short Name",
       routes.route_long_name AS "Route Long Name"
FROM routes
JOIN trips ON routes.route_id = trips.route_id
WHERE trips.trip_id = "$trip_id";
EOF

    echo "Fetching agency details..."
    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT agency.agency_name AS "Agency Name",
       agency.agency_url AS "Agency URL",
       agency.agency_timezone AS "Agency Timezone"
FROM agency
JOIN routes ON agency.agency_id = routes.agency_id
JOIN trips ON trips.route_id = routes.route_id
WHERE trips.trip_id = "$trip_id";
EOF

    echo "Fetching stop times for the trip..."
    sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
    SELECT stop_times.stop_sequence AS "Stop Sequence",
        stops.stop_name AS "Stop Name",
        stop_times.arrival_time AS "Arrival Time",
        stop_times.departure_time AS "Departure Time"
    FROM stop_times
    JOIN stops ON stop_times.stop_id = stops.stop_id
    WHERE stop_times.trip_id = "$trip_id"
    ORDER BY stop_times.stop_sequence;
EOF
}

# Main menu
main_menu() {
    echo "Choose a search method:"
    echo "1. Search by Train ID"
    echo "2. Search by Itinerary (Date, Departure, Arrival)"
    echo "3. Debug Database Schema"
    read -p "Enter choice (1, 2, or 3): " choice

    case "$choice" in
        1)
            search_by_trip_id
            ;;
        2)
            search_trains_by_date
            ;;
        3)
            validate_schema
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
}

# Run the main menu
main_menu