#!/bin/sh

remote=$1
shift

while true; do
	for key in "$@"; do
		rand=$(shuf -i 200-10000 -n 1)
		sleep $(echo "scale=2; $rand / 1000" | bc)
		#data="token=$key&time[]=$(date --rfc-3339=ns | sed -e 's/+.\+//')"
		#data="token=$key&time[]=$(date --rfc-3339=ns)"
		data="epoch_time[]=$(date +%s,%N)"
		echo $data
		curl --data-urlencode "token=$key" --data-urlencode "$data" $remote
		echo 
	done
done