#!/bin/bash

RUN_ID=$(date '+%Y%m%d-%H%M%S')
function grant_permission(){
	sudo cat /etc/sudoers | grep "NOPASSWD"
	if [ "$?" == "1" ]; then
		echo "[grant_permission]"
		sudo /bin/bash -c 'echo "ubuntu  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
	fi
}

function run_cpu(){
    echo "[run_cpu] Launching CPU stress test"
    gnome-terminal -- /bin/bash -c "sudo stress-ng -c 6 -l 100 -t 999999 2>&1 | tee burnin_logs_$RUN_ID/cpu_$RUN_ID.log; exec bash"
}

function run_mem(){
    echo "[run_mem] Launching Memory test"
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    TEST_MEM=$(( TOTAL_MEM / 2 ))
    gnome-terminal -- /bin/bash -c "sudo memtester ${TEST_MEM}G 999 2>&1 | tee burnin_logs_$RUN_ID/mem_$RUN_ID.log; exec bash"
}

function run_gpu(){
    echo "[run_gpu] Checking for glmark2"
    if [[ ! -f /usr/bin/glmark2 ]]; then
        echo "[run_gpu] Installing glmark2..."
        sudo apt update && sudo apt install -y glmark2
    fi
    gnome-terminal -- /bin/bash -c "sudo glmark2 2>&1 | tee burnin_logs_$RUN_ID/gpu_$RUN_ID.log; exec bash"
}

function main(){
    grant_permission
    mkdir -p burnin_logs_$RUN_ID
    run_cpu
    run_gpu
    run_mem
}

main "$@"