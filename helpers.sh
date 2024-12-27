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

validate_date() {
    local date="$1"
    if [[ "$date" =~ ^[0-9]{8}$ ]]; then
        local year="${date:0:4}"
        local month="${date:4:2}"
        local day="${date:6:2}"

        # Check if the month is valid (01 to 12)
        if [[ $month -ge 01 && $month -le 12 ]]; then
            # Check for valid days in the month (not considering leap years)
            case $month in
                01|03|05|07|08|10|12) # 31 days
                    if [[ $day -ge 01 && $day -le 31 ]]; then
                        return 0
                    fi
                    ;;
                04|06|09|11) # 30 days
                    if [[ $day -ge 01 && $day -le 30 ]]; then
                        return 0
                    fi
                    ;;
                02) # 28 days
                    if [[ $day -ge 01 && $day -le 28 ]]; then
                        return 0
                    fi
                    ;;
            esac
        fi
    fi
    return 1
}

get_day_of_week() {
    local input_date="$1"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        day=$(date -j -f "%Y%m%d" "$input_date" "+%A" | tr '[:upper:]' '[:lower:]')
    else
        # Linux
        day=$(date -d "$input_date" "+%A" | tr '[:upper:]' '[:lower:]')
    fi

    echo "$day"
}

get_valid_service_ids() {
    local dotw="$1"
    local validation_date="$2"
    local service_ids=()
    local validated_service_ids=()

    # Ensure calendar and exceptions files exist
    if [[ ! -f "$calendar_file" ]]; then
        echo "Error: Calendar file '$calendar_file' not found."
        return 1
    fi
    if [[ ! -f "$calendar_dates_file" ]]; then
        echo "Error: Exceptions file '$calendar_dates_file' not found."
        return 1
    fi

    # Determine the column number for the given day
    header=$(head -1 "$calendar_file")
    column_number=$(echo "$header" | tr ',' '\n' | nl -w1 -s',' | grep -w "$dotw" | cut -d',' -f1)

    # Exit if the day of the week is not found
    if [[ -z "$column_number" ]]; then
        echo "Error: Day '$dotw' not found in the calendar file."
        return 1
    fi

    # Extract service IDs for the specified day
    while IFS=',' read -r line; do
        # Skip the header
        if [[ "$line" == "$header" ]]; then
            continue
        fi

        # Extract service_id and the value for the specified day
        service_id=$(echo "$line" | cut -d',' -f1)
        day_value=$(echo "$line" | cut -d',' -f"$column_number")

        # Add to service IDs if the value is "1"
        if [[ "$day_value" == "1" ]]; then
            service_ids+=("$service_id")
        fi
    done < "$calendar_file"

    # Validate the service IDs against the exceptions file
    for service_id in "${service_ids[@]}"; do
        # Check if the service_id and date exist in the exceptions file
        if ! grep -q "^$service_id,$validation_date," "$calendar_dates_file"; then
            validated_service_ids+=("$service_id")
        fi
    done

    # Return the validated service IDs
    echo "${validated_service_ids[@]}"
}

extract_trip_id() {
    local route_id="$1"
    
    # Find the trip_id for the given route_id
    while IFS=',' read -r current_route_id service_id trip_id trip_short_name; do
        if [[ "$current_route_id" == "$route_id" ]]; then
            echo "$trip_id"
            return 0  # Exit once the trip_id is found
        fi
    done < "$trips_file"
    
    
    return 1
}


check_trip_stops() {
    local route_id="$1"
    local departure_station_id="$2"
    local arrival_station_id="$3"
    local trip_id
    trip_id=$(extract_trip_id "$route_id" "$trips_file")
    
    # Initialize variables for tracking stop sequences
    local departure_sequence=-1
    local arrival_sequence=-1
    local stop_found=0

    # Loop through stop_times.txt and gather stop sequences
    while IFS=',' read -r current_trip_id arrival_time departure_time stop_id stop_sequence; do
        if [[ "$current_trip_id" == "$trip_id" ]]; then
            # Check for departure station
            if [[ "$stop_id" == "$departure_station_id" ]]; then
                departure_sequence="$stop_sequence"
            fi
            # Check for arrival station
            if [[ "$stop_id" == "$arrival_station_id" ]]; then
                arrival_sequence="$stop_sequence"
            fi
        fi
        
        # If both departure and arrival sequences are found, break early
        if [[ "$departure_sequence" -ne -1 && "$arrival_sequence" -ne -1 ]]; then
            stop_found=1
            break
        fi
    done < "$stop_times_file"

    # Only proceed if both stations are found
    if [[ "$stop_found" -eq 1 && "$departure_sequence" -lt "$arrival_sequence" ]]; then
        return 0 # Valid trip
    else
        return 1 # Invalid trip
    fi
}

filter_routes_by_service_ids() {
    local dotw="$1"
    local validation_date="$2"
    local departure_station_id="$3"
    local arrival_station_id="$4"
    local valid_service_ids
    local route_ids=()

    # Ensure input files exist
    if [[ ! -f "$calendar_file" || ! -f "$calendar_dates_file" || ! -f "$trips_file" ]]; then
        echo "Error: Required input files are missing."
        return 1
    fi

    # Step 1: Get valid service IDs
    valid_service_ids=$(get_valid_service_ids "$dotw" "$validation_date")
    if [[ -z "$valid_service_ids" ]]; then
        echo "No valid service IDs found for $dotw ($validation_date)."
        return 1
    fi

    # Step 2: Filter route IDs from trips.txt based on valid service IDs
    # Use grep to find relevant service IDs first to avoid reading the entire file multiple times
    while IFS=',' read -r route_id service_id trip_id trip_short_name; do
        # Skip header
        if [[ "$route_id" == "route_id" ]]; then
            continue
        fi

        # Check if service_id is in the list of valid service IDs
        if echo "$valid_service_ids" | grep -qw "$service_id"; then
            # Process each route in parallel using background jobs
            check_trip_stops "$route_id" "$departure_station_id" "$arrival_station_id" &
        fi
    done < "$trips_file"

    # Wait for all background jobs to complete
    wait

    # Output filtered route IDs (only the valid ones)
    if [[ ${#route_ids[@]} -gt 0 ]]; then
        echo "Valid routes: ${route_ids[@]}"
    else
        echo "No valid routes found for $departure_station_id to $arrival_station_id on $validation_date."
    fi
}