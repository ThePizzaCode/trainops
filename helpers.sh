#!/bin/bash

# Helper functions

# Paths to GTFS
trips_file="gtfs/trips.txt"
routes_file="gtfs/routes.txt"
agency_file="gtfs/agency.txt"
stop_times_file="gtfs/stop_times.txt"
stops_file="gtfs/stops.txt"
calendar_file="gtfs/calendar.txt"
calendar_dates_file="gtfs/calendar_dates.txt"

get_station_id() {
    local station_name=$1
    awk -F',' -v station="$station_name" '$2==station {print $1}' "$stops_file"
}

get_route_details() {
    local route_id=$1
    awk -F',' -v route="$route_id" '$1 == route { print $2, $3; }' "$routes_file"
}

get_agency_details() {
    local agency_id=$1
    awk -F',' -v agency="$agency_id" '$1 == agency { print $2, $3, $4; }' "$agency_file"
}


display_trips() {
    local trips=$1
    echo "Trains on the selected date:"
    echo "$trips" | while IFS=',' read -r trip_id departure_time arrival_time; do
        echo "Trip ID: $trip_id | Departure: $departure_time | Arrival: $arrival_time"
    done

    
}