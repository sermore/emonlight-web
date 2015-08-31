#!/bin/sh

while true; do
	for key in "$@"; do
		rand=$(shuf -i 200-10000 -n 1)
		sleep $(echo "scale=2; $rand / 1000" | bc)
		data="token=$key&time[]=$(date --rfc-3339=ns | sed -e 's/+.\+//')"
		echo $data
		curl -d "$data" http://localhost:3000/nodes/read
		echo 
	done
done