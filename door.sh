#!/bin/bash
DOOR_SCRIPT="door.py"
HOST_FILE=".host_name"
REQUIREMENTS="RPi.GPIO websockets"
(
    if [ ! -d "venv" ]; then
      python3 -m venv venv
      venv/bin/python -m pip install "$REQUIREMENTS"
    fi

    host="localhost"
    if [ -f "$HOST_FILE" ]; then
      host=$(cat "$HOST_FILE")
    fi
    venv/bin/python "$DOOR_SCRIPT" --host "$host"
) &