#!/bin/bash

set -e

# Trap signals for graceful shutdown
# SIGTERM is sent by Docker stop, SIGINT by Ctrl+C
trap 'handle_shutdown' SIGTERM SIGINT

# Function to handle shutdown gracefully
handle_shutdown() {
    echo "Received shutdown signal, stopping services gracefully..."
    
    # Stop Node.js server if it's running
    if [ ! -z "$NODE_PID" ]; then
        echo "Stopping Node.js server (PID: $NODE_PID)..."
        kill -TERM "$NODE_PID" 2>/dev/null
        wait "$NODE_PID" 2>/dev/null
    fi
    
    # Stop MariaDB if it was started by this script
    if [ "$START_MARIADB" = "true" ] && [ ! -z "$MYSQL_PID" ]; then
        echo "Stopping MariaDB gracefully (PID: $MYSQL_PID)..."
        /opt/mariadb/bin/mysqladmin --socket=/run/mysqld/mysqld.sock -uroot -p123qweasd shutdown
        
        # Wait for MariaDB to shut down (max 30 seconds)
        local count=0
        while kill -0 "$MYSQL_PID" 2>/dev/null && [ $count -lt 30 ]; do
            echo -n "."
            sleep 1
            count=$((count + 1))
        done
        
        if kill -0 "$MYSQL_PID" 2>/dev/null; then
            echo " MariaDB did not stop gracefully, forcing..."
            kill -9 "$MYSQL_PID" 2>/dev/null
        else
            echo " MariaDB stopped cleanly."
        fi
    fi
    
    echo "Shutdown complete."
    exit 0
}

# --- CONFIG VALIDATION & ENV SETUP ---

if [ ! -f "/app/config/config.json" ]; then
  echo "==============================================="
  echo "ERROR: Configuration file not found!"
  echo "==============================================="
  echo "Please run setup.sh or provide config/config.json."
  echo "==============================================="
  exit 1
fi

YOUTUBE_OUTPUT_DIR=$(grep '"youtubeOutputDirectory"' /app/config/config.json | sed 's/.*"youtubeOutputDirectory"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
YOUTUBE_OUTPUT_DIR=$(echo "$YOUTUBE_OUTPUT_DIR" | xargs)

if [ -z "$YOUTUBE_OUTPUT_DIR" ] || [ "$YOUTUBE_OUTPUT_DIR" == "null" ]; then
  echo "==============================================="
  echo "ERROR: YouTube output directory not configured!"
  echo "==============================================="
  exit 1
fi

if [ ! -d "$YOUTUBE_OUTPUT_DIR" ]; then
  echo "==============================================="
  echo "ERROR: YouTube output directory does not exist!"
  echo "Directory: $YOUTUBE_OUTPUT_DIR"
  echo "==============================================="
  exit 1
fi
if [ ! -r "$YOUTUBE_OUTPUT_DIR" ]; then
  echo "==============================================="
  echo "ERROR: YouTube output directory is not readable!"
  echo "Directory: $YOUTUBE_OUTPUT_DIR"
  echo "==============================================="
  exit 1
fi

echo "YouTube output directory verified: $YOUTUBE_OUTPUT_DIR"
export YOUTUBE_OUTPUT_DIR

export LOG_LEVEL=${LOG_LEVEL:-warn}
export AUTH_ENABLED=${AUTH_ENABLED:-true}

# Load DB credentials from env or external file if present
if [ -f "/app/config/external-db.env" ]; then
  set -a
  source /app/config/external-db.env
  set +a
fi

# --- START MARIADB IF NEEDED ---
if [ "$START_MARIADB" = "true" ]; then
  echo "Starting MariaDB..."
  /usr/local/bin/start_mariadb.sh
  MYSQL_PID=$(pgrep -f "mysqld.*port=3321")
  echo "MariaDB started with PID: $MYSQL_PID"
fi

# --- WAIT FOR DATABASE ---
echo "Waiting for database to be ready..."
MAX_TRIES=30
TRIES=0
while [ $TRIES -lt $MAX_TRIES ]; do
    if node -e "
        const mysql = require('mysql2/promise');
        mysql.createConnection({
            host: process.env.DB_HOST || 'localhost',
            port: process.env.DB_PORT || 3321,
            user: process.env.DB_USER || 'root',
            password: process.env.DB_PASSWORD || '123qweasd',
            database: process.env.DB_NAME || 'youtarr'
        }).then(() => {
            console.log('Database connection successful');
            process.exit(0);
        }).catch((err) => {
            process.exit(1);
        });
    " 2>/dev/null; then
        echo "Database is ready!"
        break
    fi
    TRIES=$((TRIES + 1))
    if [ $TRIES -eq $MAX_TRIES ]; then
        echo "Failed to connect to database after $MAX_TRIES attempts"
        exit 1
    fi
    echo "Waiting for database... (attempt $TRIES/$MAX_TRIES)"
    sleep 2
done

# --- START NODE SERVER ---
echo "Starting Node.js server..."
node /app/server/server.js &
NODE_PID=$!
echo "Node.js server started with PID: $NODE_PID"

# Wait for Node.js process
# This keeps the script running and allows trap to work
wait "$NODE_PID"

# If we get here, Node crashed without signal
echo "Node.js server exited unexpectedly"
handle_shutdown