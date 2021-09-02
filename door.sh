#!/bin/bash
DOOR_SCRIPT="door.py"
HOST_FILE=".host_name"
PY36="venv/lib/python3.6"
PY37="venv/lib/python3.7"
PY38="venv/lib/python3.8"
PY39="venv/lib/python3.9"
PYRPI="/site-packages/RPi"
PYWS="/site-packages/websockets"
(
    if [ ! -d "venv" ]; then
      python3 -m venv venv
    fi

    if [ ! -d "$PY36$PYRPI" ]  && [ ! -d "$PY37$PYRPI" ] && [ ! -d "$PY38$PYRPI" ] && [ ! -d "$PY39$PYRPI" ]; then
      venv/bin/python -m pip install RPi.GPIO
    fi

    if [ ! -d "$PY36PYWS" ]  && [ ! -d "$PY37PYWS" ] && [ ! -d "$PY38PYWS" ] && [ ! -d "$PY39PYWS" ]; then
      venv/bin/python -m pip install websockets
    fi

    host="localhost"
    if [ -f "$HOST_FILE" ]; then
      host=$(cat "$HOST_FILE")
    fi
    venv/bin/python "$DOOR_SCRIPT" --host "$host"
) &