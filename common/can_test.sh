#!/bin/bash

echo -e "Usage: $ sudo ./can_test.sh <s/r> <canX> <Dbitrate> [optional_frames]\n"
#v1.01-shows packets per time.
#v1.02-modify receive side can0 bug.
#v1.03-add can2.0 test if not support fd
#v1.04-receive side shows inter-packet time
#v1.05-receive side removes inter-packet time
#v1.06-change the receive-side FPS calculation, separating send and receive FPS.

if [ "$2" == "" ]; then exit ; fi
if [ "$3" == "" ]; then exit ; fi

frame=${4:-100000}
R_frame=0
pR_frame=0
PL=64

if [ ! -f /bin/candump ]; then
    sudo apt install can-utils -y
fi

if [ "$1" == "s" -o "$1" == "S" ]; then
    sudo ip link set $2 down
    sudo ip link set $2 txqueue $frame
    if sudo ip link set $2 up type can bitrate 1000000 dbitrate $3 fd on 2>/dev/null; then 
        echo CAN FD ON
    else sudo ip link set $2 up type can bitrate $3 2>/dev/null
        echo CAN FD OFF; PL=8; 
    fi
    sleep 1
    start_t=$(date +%s.%N)
    cangen $2 -g 0 -L $PL -n $frame $(if [ "$PL" == "64" ]; then echo '-b'; fi)
    end_t=$(date +%s.%N)
    cost_t=$(printf "%.9f" $(echo "$end_t - $start_t" | bc))
    FPS=$(echo "$frame / $cost_t" | bc)
    echo -e "Sent $frame frmaes\ncost $cost_t seconds\nFrames per seconds: $FPS"
fi

if [ "$1" == "r" -o "$1" == "R" ]; then
    sudo ip link set $2 down
    if sudo ip link set $2 up type can bitrate 1000000 dbitrate $3 fd on 2>/dev/null; then
        echo CAN FD ON
    else sudo ip link set $2 up type can bitrate $3 2>/dev/null
        echo CAN FD OFF; PL=8;
    fi
    candump $2 -n $frame > canbus_log.txt &
    while [ $R_frame -le $frame ]; do
        R_frame=$(grep -c $2 canbus_log.txt)
        if [ $pR_frame -eq 0 -a $R_frame -ne 0 ]; then
            start_t=$(date +%s.%N)
        fi
        if [ $R_frame -eq $frame -o $R_frame -eq $pR_frame -a $R_frame -ne 0 ]; then
            end_t=$(date +%s.%N)
			break
        fi
        pR_frame=$R_frame
        if [ "$C" == 60 ]; then echo "Received $R_frame frmaes..."; C=0; else C=$((C+1)) ; fi
        sleep 0.05
    done
    cost_t=$(printf "%.9f" $(echo "$end_t - $start_t" | bc))
    FPS=$(echo "$R_frame / $cost_t" | bc)
    echo -e "Received $R_frame frmaes\ncost $cost_t seconds\nFrames per seconds: $FPS"
fi
