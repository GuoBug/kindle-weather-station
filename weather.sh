#!/bin/sh
# ==============================================================================
# KINDLE WEATHER STATION EXECUTION WRAPPER
# ==============================================================================
# WARNING: MUST be saved with Unix (LF) line endings.
# ==============================================================================

# ------------------------------------------------------------------------------
# PATHS AND PLACES
# ------------------------------------------------------------------------------
EXT_DIR="/mnt/us/extensions/weather-station"
PIDFILE="$EXT_DIR/weather.pid"
STOP_FILE="/mnt/us/stop-weather"
LOG_FILE="$EXT_DIR/weather.log"

PYTHON_SCRIPT="$EXT_DIR/render.py"
OUTPUT_PNG="/tmp/output.png"
[ -f "$OUTPUT_PNG" ] || OUTPUT_PNG="$EXT_DIR/output.png"

# ------------------------------------------------------------------------------
# USER CONFIGURATION (Defaults)
# ------------------------------------------------------------------------------
API_KEY="YOUR_OPENWEATHERMAP_API_KEY"
CITY_NAME="Shanghai,CN"
POWER_MODE="eco"  # "eco" (Power-saving, recommended) or "perf" (Performance)
INTERVAL=1800     # Default weather API fetch interval in seconds (1800 for eco, 600 for perf)

# Load local private configuration if it exists
if [ -f "$EXT_DIR/user_config.sh" ]; then
	. "$EXT_DIR/user_config.sh"
elif [ -f "./user_config.sh" ]; then
	. "./user_config.sh"
fi

# Securely export configuration to environment variables to avoid exposing API_KEY in /proc cmdline
export OPENWEATHER_API_KEY="$API_KEY"
export OPENWEATHER_CITY="$CITY_NAME"
export WEATHER_POWER_MODE="$POWER_MODE"
export WEATHER_INTERVAL="$INTERVAL"

# ------------------------------------------------------------------------------
# SYSTEM FUNCTIONS
# ------------------------------------------------------------------------------

# Write logs with timestamp
log() {
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >>"$LOG_FILE" 2>/dev/null
	echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Clear the e-ink screen to prevent ghosting
clear_screen() {
	/usr/sbin/eips -c >/dev/null 2>&1 \
		|| /usr/bin/eips -c >/dev/null 2>&1 \
		|| eips -c >/dev/null 2>&1
	sleep 1
	/usr/sbin/eips -c >/dev/null 2>&1 \
		|| /usr/bin/eips -c >/dev/null 2>&1 \
		|| eips -c >/dev/null 2>&1
	sleep 1
}

# Display a compiled PNG full screen
display_image() {
	local img="$1"
	/usr/sbin/eips -g "$img" >/dev/null 2>&1 \
		|| /usr/bin/eips -g "$img" >/dev/null 2>&1 \
		|| eips -g "$img" >/dev/null 2>&1
}

# Check for USB host connection or active charging
is_usb_connected() {
	for online_file in /sys/class/power_supply/*/online; do
		if [ -f "$online_file" ] && [ "$(cat "$online_file")" = "1" ]; then
			return 0
		fi
	done
	
	local charging_lipc=$(lipc-get-prop com.lab126.powerd charging 2>/dev/null)
	if [ "$charging_lipc" = "Yes" ] || [ "$charging_lipc" = "1" ]; then
		return 0
	fi
	
	return 1
}

# Turn Wi-Fi on
wifi_on() {
	lipc-set-prop com.lab126.cmd wirelessEnable 1 >/dev/null 2>&1
	lipc-set-prop com.lab126.wifid enable 1 >/dev/null 2>&1
}

# Turn Wi-Fi off
wifi_off() {
	lipc-set-prop com.lab126.cmd wirelessEnable 0 >/dev/null 2>&1
	lipc-set-prop com.lab126.wifid enable 0 >/dev/null 2>&1
}

# Stop Java GUI framework
stop_framework() {
	lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null
	initctl stop lab126_gui >/dev/null 2>&1
	stop lab126_gui >/dev/null 2>&1
	stop framework >/dev/null 2>&1
}

# Start Java GUI framework
start_framework() {
	lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
	initctl start lab126_gui >/dev/null 2>&1
	start lab126_gui >/dev/null 2>&1
	start framework >/dev/null 2>&1
}

# System cleanup during script lifecycle termination
cleanup() {
	rm -f "$PIDFILE" "$STOP_FILE" "$EXT_DIR/stop"
	wifi_on
	clear_screen
	/usr/sbin/eips 2 10 "Restoring Kindle GUI..." >/dev/null 2>&1 || eips 2 10 "Restoring Kindle GUI..." >/dev/null 2>&1
	sleep 2
	start_framework
}

# ------------------------------------------------------------------------------
# MAIN EXECUTION ROUTER
# ------------------------------------------------------------------------------
case "$1" in
	start)
		if [ -f "$PIDFILE" ]; then
			PID=$(cat "$PIDFILE" 2>/dev/null | tr -cd '0-9')
			if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
				echo "Weather Station is already running (PID: $PID)."
				exit 0
			fi
			rm -f "$PIDFILE"
		fi
		
		# Clear existing log
		rm -f "$LOG_FILE"

		
		# Spawn independent process session daemon via sh to bypass noexec
		setsid sh "$0" daemon >"$LOG_FILE" 2>&1 &
		sleep 2
		
		if [ -f "$PIDFILE" ]; then
			echo "Weather Station started (Mode: $POWER_MODE)."
		else
			echo "Failed to start Weather Station."
		fi
		exit 0
		;;
		
	stop)
		touch "$STOP_FILE"
		touch "$EXT_DIR/stop"
		if [ -f "$PIDFILE" ]; then
			PID=$(cat "$PIDFILE" 2>/dev/null | tr -cd '0-9')
			if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
				kill "$PID"
				sleep 2
			fi
		fi
		start_framework
		echo "Weather Station stopped."
		exit 0
		;;
		
	daemon)
		echo "$$" > "$PIDFILE"
		trap "cleanup; exit 0" SIGINT SIGTERM SIGHUP
		
		log "Weather Station daemon started (Power Mode: $POWER_MODE)."

		
		# Halt native GUI
		log "Stopping framework GUI."
		stop_framework
		clear_screen
		
		# Run the persistent Python process.
		# Credentials and mode are passed via environment variables (not argv).
		log "Starting persistent Python dashboard process."
		/mnt/us/python3/bin/python3.9 -u "$PYTHON_SCRIPT"
		python_exit=$?
		log "Python process exited with code $python_exit."
		
		# Cleanup and restore Kindle GUI
		cleanup
		exit 0
		;;
		
	*)
		echo "Usage: $0 {start|stop|daemon}"
		exit 1
		;;
esac
