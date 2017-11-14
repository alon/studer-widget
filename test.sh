#!/bin/bash

echo "starting two terminals, one serving a site, the other serving the widget"
gnome-terminal --title embedder -- bash -c "cd embedder; python3 -mhttp.server 8050" &
gnome-terminal --title widget -- bash -c "cd widget; python3 -mhttp.server 8000" &
