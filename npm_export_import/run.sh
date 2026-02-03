#!/bin/sh
# Simple test service: serve files on 8080
exec python3 -m http.server 8080 --bind 0.0.0.0
