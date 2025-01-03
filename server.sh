#!/bin/bash

DB_PATH="gtfs.db"
REQ_PORT=12345 # Port for receiving requests
RES_PORT=12346 # Port for sending responses

# Function to respond with JSON
send_response() {
    local response="$1"
    echo -e "$response" | nc localhost "$RES_PORT"
}

extract_stop_ids() {
  local db_path="$1"      # Path to the SQLite database
  local dep_stop="$2"     # Departure stop name
  local arr_stop="$3"     # Arrival stop name

  # Query to get stop IDs for the given departure and arrival stop names
  local query="
    SELECT stop_id, stop_name
    FROM stops
    WHERE stop_name IN ('$dep_stop', '$arr_stop');
  "

  # Execute the query and store results
  local result
  result=$(sqlite3 "$db_path" "$query")

  # Parse the results to extract stop IDs
  while IFS='|' read -r stop_id stop_name; do
    if [[ "$stop_name" == "$dep_stop" ]]; then
      dep_stop_id="$stop_id"
    elif [[ "$stop_name" == "$arr_stop" ]]; then
      arr_stop_id="$stop_id"
    fi
  done <<< "$result"

  # Output the results for debugging
  echo "Departure Stop ID: $dep_stop_id"
  echo "Arrival Stop ID: $arr_stop_id"
}


# Function to search for trains by train number (trip ID)
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
        send_response "{\"status\":\"error\",\"message\":\"Train not found for trip_id $trip_id.\"}"
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

    # Respond with JSON
    send_response "{
        \"status\":\"success\",
        \"train_info\":$train_info,
        \"stop_times\":$stop_times
    }"
}

# Function to search for itineraries
search_itinerary() {
    local date="$1"
    local departure_station="$2"
    local arrival_station="$3"
    local itinerary

    extract_stop_ids $DB_PATH $departure_station $arrival_station

    # Fetch itinerary details
    itinerary=$(sqlite3 -json "$DB_PATH" <<EOF
WITH StopTimesWithNames AS (
    SELECT st.trip_id, st.stop_id, st.stop_sequence
    FROM stop_times st
    WHERE st.trip_id IN (
        SELECT trip_id FROM trips WHERE service_id = '2'
    )
      AND st.stop_id IN ('$dep_stop_id', '$arr_stop_id') 
),
TripsBetweenStops AS (
    SELECT 
        d.trip_id
    FROM StopTimesWithNames d
    INNER JOIN StopTimesWithNames a ON d.trip_id = a.trip_id
    WHERE d.stop_id = '$dep_stop_id' 
      AND a.stop_id = '$arr_stop_id'
      AND d.stop_sequence < a.stop_sequence 
)

SELECT DISTINCT trip_id
FROM TripsBetweenStops;
EOF
)

    # Check if the itinerary is empty (no itinerary found)
    if [[ -z "$itinerary" || "$itinerary" == "[]" ]]; then
        send_response "{\"status\":\"error\",\"message\":\"No itinerary found for $departure_station to $arrival_station on $date.\"}"
        return
    fi

    # Respond with JSON
    send_response "{
        \"status\":\"success\",
        \"itinerary\":$itinerary
    }"
}

# Main server loop
while true; do
    echo "Listening on port $REQ_PORT for requests..."
    request=$(nc -l "$REQ_PORT")

    if [[ -z "$request" ]]; then
        continue
    fi

    # Parse the JSON request
    type=$(echo "$request" | jq -r '.type')

    case "$type" in
        "search_train")
            trip_id=$(echo "$request" | jq -r '.train_number')
            if [[ -z "$trip_id" ]]; then
                send_response "{\"status\":\"error\",\"message\":\"Invalid input: Train number is required.\"}"
            else
                search_by_trip_id "$trip_id"
            fi
            ;;
        "search_itinerary")
            date=$(echo "$request" | jq -r '.date')
            departure_station=$(echo "$request" | jq -r '.departure_station')
            arrival_station=$(echo "$request" | jq -r '.arrival_station')
            if [[ -z "$date" || -z "$departure_station" || -z "$arrival_station" ]]; then
                send_response "{\"status\":\"error\",\"message\":\"Invalid input: Date, departure station, and arrival station are required.\"}"
            else
                search_itinerary "$date" "$departure_station" "$arrival_station"
            fi
            ;;
        *)
            send_response "{\"status\":\"error\",\"message\":\"Invalid request type.\"}"
            ;;
    esac
done