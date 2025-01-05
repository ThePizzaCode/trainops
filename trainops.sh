#!/bin/bash

DB_PATH="../trainops/gtfs.db"

dep_stop_id="10017" # Fixed departure station ID for Bucuresti Nord

extract_stop_ids() {
  local arr_stop=$1     # Arrival stop name

  # Query to get stop ID for the given arrival stop name
  local query="
    SELECT stop_id, stop_name
    FROM stops
    WHERE stop_name = '$arr_stop';
  "

  # Execute the query and store results
  local result
  result=$(sqlite3 "$DB_PATH" "$query")

  # Parse the results to extract the arrival stop ID
  while IFS='|' read -r stop_id stop_name; do
    if [[ "$stop_name" == "$arr_stop" ]]; then
      arr_stop_id="$stop_id"
    fi
  done <<< "$result"
}

search_by_trip_id() {
    trip_id="$1"

    # Fetch stop times
    trips=$(sqlite3 "$DB_PATH" <<EOF
.headers off
.mode csv
SELECT stop_times.stop_sequence AS "stop_sequence",
       stops.stop_name AS "stop_name",
       stop_times.arrival_time AS "arrival_time",
       stop_times.departure_time AS "departure_time"
FROM stop_times
JOIN stops ON stop_times.stop_id = stops.stop_id
WHERE stop_times.trip_id = '$trip_id'
ORDER BY CAST(stop_times.stop_sequence AS INTEGER);
EOF
    )

    echo "$trips"

}


search_itinerary() {
    arrival_station="$1"
    departure_time="$2"

    # extract_stop_ids $arrival_station
    arr_stop_id=$arrival_station

    # Fetch itinerary details
    itinerary=$(sqlite3 "$DB_PATH" <<EOF
.headers off
.mode csv
WITH StopTimesWithNames AS (
    SELECT st.trip_id, st.stop_id, st.stop_sequence, st.departure_time, st.arrival_time
    FROM stop_times st
    WHERE st.stop_id IN ('$dep_stop_id', '$arr_stop_id') 
),
TripsBetweenStops AS (
    SELECT 
       d.departure_time, a.arrival_time
    FROM StopTimesWithNames d
    INNER JOIN StopTimesWithNames a ON d.trip_id = a.trip_id
    WHERE d.stop_id = '$dep_stop_id' 
      AND a.stop_id = '$arr_stop_id'
      AND d.stop_sequence < a.stop_sequence 
      AND d.departure_time >= '$departure_time'
    ORDER BY d.departure_time
)
SELECT DISTINCT *
FROM TripsBetweenStops;
EOF
)

    # Check if the itinerary is empty (no itinerary found)
    if [[ -z "$itinerary" || "$itinerary" == "[]" ]]; then
        echo "error, no route found"
        return
    fi

    # Display the results
    echo "$itinerary"
}

search_stop_name_similar() {
    local stop_name="$1"
    
    sqlite3 "$DB_PATH" <<EOF
.headers off
.mode csv
    SELECT stop_id, stop_name 
    FROM stops
    WHERE stop_name COLLATE NOCASE LIKE '%$stop_name%' COLLATE NOCASE;
EOF
}



handle_request() {
    IFS=, read -r -a request <<< "$1"
    
    endpoint=${request[0]}

    case $endpoint in
        check_itinerary)
            id=${request[1]}
            search_by_trip_id $id
            ;;

        find_itinerary)
            arrival_station=${request[1]} 
            departure_time=${request[2]} 
            search_itinerary $arrival_station $departure_time
            ;;

        search_stop)
            search_stop_name_similar ${request[1]} 
            ;;

        *)
            echo $endpoint 
            ;;
    esac

    echo DONE
}

handle_request "$1"
