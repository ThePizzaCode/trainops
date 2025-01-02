#!/bin/bash

# Set the path to your SQLite database
DB_PATH="gtfs.db"

while true; do
    # Start a TCP server on port 12345 using netcat and process a single input
    echo "Waiting for input..."
    trip_id=$(nc -l 12345)
    echo "Received: $trip_id"

    # Fetch route details
    route_details=$(sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT routes.route_short_name AS "Route Short Name",
       routes.route_long_name AS "Route Long Name"
FROM routes
JOIN trips ON routes.route_id = trips.route_id
WHERE trips.trip_id = "$trip_id";
EOF
)
    echo "Route Details: $route_details"

    # Fetch agency details
    agency_details=$(sqlite3 "$DB_PATH" <<EOF
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
)
    echo "Agency Details: $agency_details"

    # Fetch stop times
    stop_times=$(sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT stop_times.stop_sequence AS "Stop Sequence",
       stops.stop_name AS "Stop Name",
       stop_times.arrival_time AS "Arrival Time",
       stop_times.departure_time AS "Departure Time"
FROM stop_times
JOIN stops ON stop_times.stop_id = stops.stop_id
WHERE stop_times.trip_id = "$trip_id";
EOF
)
    echo "Stop Times: $stop_times"

    # Combine all results into a single response
    response="Route Details:\n$route_details\n\nAgency Details:\n$agency_details\n\nStop Times:\n$stop_times"

    # Send the response back to the client by acting as a client
    echo -e "$response" | nc localhost 12346
done