#!/bin/bash

# Train operations for Train Lookup

# Paths to GTFS
trips_file="gtfs/trips.txt"
routes_file="gtfs/routes.txt"
agency_file="gtfs/agency.txt"
stop_times_file="gtfs/stop_times.txt"
stops_file="gtfs/stops.txt"
calendar_file="gtfs/calendar.txt"
calendar_dates_file="gtfs/calendar_dates.txt"

search_train_number() {
    clear_screen
    read -p "Enter a train number: " tripID

    route_id=$(awk -F',' -v trip="$tripID" '$3 == trip { print $1; }' "$trips_file")

    if [[ -z "$route_id" ]]; then
        echo "No matching trip found for Trip ID: $tripID."
        return
    fi

    route_details=$(get_route_details "$route_id")
    if [[ -z "$route_details" ]]; then
        echo "No matching route found for Route ID: $route_id."
        return
    fi

    read agency_id route_short_name <<< "$route_details"

   agency_details=$(get_agency_details "$agency_id")
    if [[ -z "$agency_details" ]]; then
     echo "No matching agency found for Agency ID: $agency_id."
     return
    fi

    IFS=',' read -r agency_name agency_url agency_timezone <<< "$agency_details"
    echo "Trip ID: $tripID"
    echo "Route ID: $route_id"
    echo "Route Short Name: $route_short_name"
    echo "Agency: $agency_name"

    echo -e "\nListing stations with arrival and departure times:\n"
    awk -F',' -v trip="$tripID" '$1 == trip { print $4, $2, $3; }' "$stop_times_file" | while read stop_id arrival_time departure_time; do
    stop_name=$(awk -F',' -v stop="$stop_id" '$1 == stop { print $2; }' "$stops_file")
    
    # Adjust times for overnight trains (more than hour 24 in the gtfs file)
    adjust_time() {
        time=$1
        hours=$(echo $time | cut -d':' -f1)
        minutes=$(echo $time | cut -d':' -f2)
        
        if ((hours >= 24)); then
            hours=$((hours - 24))
        fi
       
        printf "%02d:%02d\n" $hours $minutes
    }

    adjusted_arrival_time=$(adjust_time "$arrival_time")
    adjusted_departure_time=$(adjust_time "$departure_time")

    echo "Stop Name: $stop_name"
    echo "Arrival Time: $adjusted_arrival_time"
    echo "Departure Time: $adjusted_departure_time"
    echo "-----------------------------"
done
}

