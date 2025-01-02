#!/bin/bash

# Paths
GTFS_DIR="/path/to/new-gtfs"  # Directory containing the new GTFS files
DB_PATH="/path/to/database.db"  # Path to your SQLite database
BACKUP_PATH="/path/to/backup/database_$(date '+%Y%m%d%H%M%S').db"  # Timestamped backup
LOG_FILE="/path/to/update.log"  # Path to the log file

# Helper Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

validate_gtfs() {
    log "Validating GTFS files..."
    required_files=("agency.txt" "routes.txt" "trips.txt" "stop_times.txt" "stops.txt")

    for file in "${required_files[@]}"; do
        if [[ ! -f "$GTFS_DIR/$file" ]]; then
            log "Error: Missing required file: $file"
            return 1
        fi
    done

    log "All required GTFS files are present."
    return 0
}

update_database() {
    log "Updating database with GTFS data..."

    sqlite3 "$DB_PATH" <<EOF
BEGIN TRANSACTION;

-- Clear old data
DELETE FROM agency;
DELETE FROM routes;
DELETE FROM trips;
DELETE FROM stop_times;
DELETE FROM stops;

-- Import new data
.separator ,
.import $GTFS_DIR/agency.txt agency
.import $GTFS_DIR/routes.txt routes
.import $GTFS_DIR/trips.txt trips
.import $GTFS_DIR/stop_times.txt stop_times
.import $GTFS_DIR/stops.txt stops

COMMIT;
EOF

    if [[ $? -eq 0 ]]; then
        log "Database updated successfully."
    else
        log "Error: Failed to update the database."
        return 1
    fi
}

# Main Script
log "Starting GTFS update process..."

# Step 1: Create a backup of the current database
log "Creating a backup of the current database at $BACKUP_PATH..."
cp "$DB_PATH" "$BACKUP_PATH"
if [[ $? -ne 0 ]]; then
    log "Error: Failed to create a backup. Aborting update."
    exit 1
fi

# Step 2: Validate GTFS Files
validate_gtfs
if [[ $? -ne 0 ]]; then
    log "Error: GTFS validation failed."
    log "Restoring database from backup..."
    cp "$BACKUP_PATH" "$DB_PATH"
    exit 1
fi

# Step 3: Update the Database
update_database
if [[ $? -ne 0 ]]; then
    log "Error: Database update failed."
    log "Restoring database from backup..."
    cp "$BACKUP_PATH" "$DB_PATH"
    exit 1
fi

log "GTFS update process completed successfully."