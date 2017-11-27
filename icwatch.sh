#/bin/bash

SERVER=$1 # such as http://source.target:8000/
TARGET=$2 # such as icecast://source:client@transcode.target:8000/

function quitscreens {
	screen -S icw-transcode -X quit
	screen -S icw-dump -X quit
}
trap quitscreens EXIT

while true
do
	TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
	RESPONSE=$(curl -s $(echo "$SERVER/status-json.xsl" | sed -E "s/([^:])(\/{2,})/\1\//") 2>&1)
	SOURCE=$(echo $RESPONSE | grep -Eo "([^\"]*)\.ogg")
	if [ ! -z "$SOURCE" ]; then
		IS_RUNNING=$(($(ps -aux | grep $SOURCE | wc -l) - 1))
		if [ $IS_RUNNING -eq 0 ]; then
		    # event title
		    STREAM_TITLE=$(echo $RESPONSE | grep -Po '"server_name":"\K([^"]*)' | tail -1)
		    STREAM_URL=$(echo $RESPONSE | grep -Po '"server_url":"\K([^"]*)' | tail -1)
		    if [ ! -z "$STREAM_URL" ]; then
		    	EVENT_TITLE=$(curl -Ls "$STREAM_URL" | grep -m1 -Eio '([^>]*)radio([^<]*)' | sed 's/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&quot;/\"/g; s/#&#39;/\'"'"'/g; s/&ldquo;/\"/g; s/&rdquo;/\"/g;')
		    fi
		    if [ -z "$EVENT_TITLE" ]; then
	    		EVENT_TITLE="$STREAM_TITLE"
		    fi
	        # event title end
	        MOUNTPOINT=${SOURCE##*/}
	        echo "[$TIMESTAMP] Mount point detected at $SOURCE, starting screen sessions..."
	        screen -dmS icw-transcode ./transcode.sh "$SOURCE" $(echo "$TARGET/${MOUNTPOINT%.*}" | sed -E "s/([^:])(\/{2,})/\1\//")
	        screen -dmS icw-dump curl -o "recordings/$TIMESTAMP $MOUNTPOINT" "$SOURCE"
	        screen -dms icw-irc ./topic.sh "$EVENT_TITLE ~ LIVE NOW ~ $SOURCE"
	    else
	        echo "[$TIMESTAMP] Matching screen sessions are running, sleeping..."
	    fi
	else
	    echo "[$TIMESTAMP] Nothing to do, sleeping..."
	fi
	sleep 10s
done
