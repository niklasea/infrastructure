#!/usr/bin/env bash

set -e

#Define cleanup procedure
cleanup() {
	for file in "$CONFIGURATION_DIR"/*.conf
	do
		wg-quick down "$file"
	done
}

#Trap SIGTERM and CTRL-C
trap cleanup SIGTERM
trap cleanup INT

for file in "$CONFIGURATION_DIR"/*.conf
do
	wg-quick up "$file"
done

tail -f /dev/null & wait
