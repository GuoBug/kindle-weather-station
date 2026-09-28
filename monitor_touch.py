#!/usr/bin/env python
# -*- coding: utf-8 -*-
# ==============================================================================
# KINDLE TOUCHSCREEN INPUT EVENT MONITOR
# ==============================================================================
# Decodes binary touch events, scales coordinates, and detects button zones.
# Exit code 10 = TOGGLE, Exit code 20 = EXIT, Exit code 0 = TIMEOUT/NONE.
# ==============================================================================

import sys
import os
import struct
import select
import time

def main():
    if len(sys.argv) < 3:
        print("Usage: monitor_touch.py <device_path> <timeout_sec> [ext_dir]")
        sys.exit(0)
        
    dev_path = sys.argv[1]
    timeout = float(sys.argv[2])
    
    ext_dir = "/mnt/us/extensions/weather-station"
    if len(sys.argv) >= 4:
        ext_dir = sys.argv[3]
        
    # Read current orientation state
    orientation = "portrait"
    state_file = os.path.join(ext_dir, "orientation.state")
    if os.path.exists(state_file):
        try:
            with open(state_file, "r") as f:
                orientation = f.read().strip().lower()
        except Exception:
            pass

    try:
        f = open(dev_path, "rb")
    except Exception as e:
        print("Error opening touchscreen device: {0}".format(e))
        sys.exit(0)
        
    # Event format: 2iHHi
    # struct timeval (8 bytes) + type (2 bytes) + code (2 bytes) + value (4 bytes) = 16 bytes
    event_format = "2iHHi"
    event_size = struct.calcsize(event_format)
    
    x = None
    y = None
    touch_x = None
    touch_y = None
    
    try:
        start_time = time.time()
        
        while True:
            elapsed = time.time() - start_time
            if elapsed >= timeout:
                break
                
            r, w, x_err = select.select([f], [], [], max(0.0, timeout - elapsed))
            if not r:
                break # Timeout
                
            data = f.read(event_size)
            if not data or len(data) < event_size:
                break
                
            _, _, ev_type, ev_code, ev_val = struct.unpack(event_format, data)
            
            # EV_ABS (type = 3)
            if ev_type == 3:
                if ev_code in [0, 53]: # ABS_X or ABS_MT_POSITION_X
                    x = ev_val
                elif ev_code in [1, 54]: # ABS_Y or ABS_MT_POSITION_Y
                    y = ev_val
            # EV_KEY (type = 1) and BTN_TOUCH (code = 330)
            elif ev_type == 1 and ev_code == 330:
                if ev_val == 0: # Release
                    if x is not None and y is not None:
                        touch_x = x
                        touch_y = y
                        break
            # EV_SYN (type = 0) as fallback
            elif ev_type == 0 and ev_code == 0:
                if x is not None and y is not None:
                    touch_x = x
                    touch_y = y
    finally:
        f.close()
        
    # Fallback to last coordinates seen if release event was missed
    if touch_x is None or touch_y is None:
        touch_x = x
        touch_y = y
        
    if touch_x is None or touch_y is None:
        print("No touch event detected (Timeout).")
        sys.exit(0)
        
    orig_x = touch_x
    orig_y = touch_y
    
    # Scale coordinates if they are in 0-4095 range (common for Kindle digitizers)
    # The default coordinate space is mapped to portrait (758x1024)
    if touch_x > 2000 or touch_y > 2000:
        touch_x = int(touch_x * 758 / 4096)
        touch_y = int(touch_y * 1024 / 4096)
    elif touch_x > 1024 or touch_y > 1024:
        touch_x = int(touch_x * 758 / 1024)
        touch_y = int(touch_y * 1024 / 1280)
        
    print("Detected touch: Raw=({0},{1}) Scaled_Portrait=({2},{3}) Orientation={4}".format(orig_x, orig_y, touch_x, touch_y, orientation))
    
    # Check 5 button zones: [Rotate] [Mode] [Light] [Lang] [Exit]
    if orientation == "landscape":
        if touch_x < 120:
            if 640 <= touch_y < 715:
                print("Action: TOGGLE")
                sys.exit(10)
            elif 715 <= touch_y < 785:
                print("Action: MODE")
                sys.exit(12)
            elif 785 <= touch_y < 855:
                print("Action: LIGHT")
                sys.exit(14)
            elif 855 <= touch_y < 925:
                print("Action: LANG")
                sys.exit(15)
            elif touch_y >= 925:
                print("Action: EXIT")
                sys.exit(20)
    else:
        # Default Portrait (758x1024)
        if touch_y > 950:
            if 440 <= touch_x < 500:
                print("Action: TOGGLE")
                sys.exit(10)
            elif 500 <= touch_x < 560:
                print("Action: MODE")
                sys.exit(12)
            elif 560 <= touch_x < 620:
                print("Action: LIGHT")
                sys.exit(14)
            elif 620 <= touch_x < 680:
                print("Action: LANG")
                sys.exit(15)
            elif touch_x >= 680:
                print("Action: EXIT")
                sys.exit(20)
                
    print("Action: NONE")
    sys.exit(0)

if __name__ == "__main__":
    main()
