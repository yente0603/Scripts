#!/bin/bash
# Qualcomm Ubuntu platform flashing script
# Supported chipsets: QCS6490, QCS9075

if [[ $EUID -eq 0 ]]; then
    echo "[ERROR] This script must NOT be run as root or with sudo."
    exit 1
fi

###############################################################################
# Global configuration
###############################################################################
PIDS=()
LOG_DIR="./qualcomm_flashing_logs"
FORCE_START=false
EXPECTED_COUNT=0
AVAILABLE_CIDS="0440|042F"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
mkdir -p "$LOG_DIR"

# Cleanup child processes on exit.
cleanup() {
    set +e
    local exit_code=$?
    trap - SIGINT SIGTERM EXIT

    local alive=0
    for PID in "${PIDS[@]}"; do
        if kill -0 "$PID" 2>/dev/null; then
            alive=1
            kill "$PID" 2>/dev/null
            sleep 1
            kill -9 "$PID" 2>/dev/null
        fi
    done
    
    if [[ $alive -eq 1 ]]; then
        echo -e "\n=== [WARNING] Cleaned up running child processes ==="
    fi
    
    wait 2>/dev/null
    exit "$exit_code"
}
trap cleanup SIGINT SIGTERM EXIT

# Detect chipset by serial number.
detect_platform() {
    local sn="$1"
    local cid
    cid=$(lsusb -v -d 05c6:9008 2>/dev/null \
          | grep iProduct \
          | grep "$sn" \
          | sed -E 's/.*CID:([0-9A-Fa-f]+)_SN:.*/\1/')
    case "$cid" in
        042F) echo "QCS6490" ;;
        0440) echo "QCS9075" ;;
        *)    echo "UNKNOWN" ;;
    esac
}

# Verify flashing result.   
verify_success() {
    local log="$1"
    local platform="$2"

    case "$platform" in
        QCS9075)
            (grep -q "partition 1 is now bootable" "$log" || \
             grep -q "partition 0 is now bootable" "$log") && \
            grep -q "UFS provisioning succeeded" "$log" && \
            grep -q 'flashed "cdt" successfully' "$log" && \
            grep -q 'flashed "SAIL_HYP" successfully' "$log" && \
            grep -q 'flashed "SAIL_SW1" successfully' "$log"
            ;;
        QCS6490)
            (grep -q "partition 1 is now bootable" "$log" || \
             grep -q "partition 0 is now bootable" "$log")
            ;;
        *)
            return 1
            ;;
    esac
}

# Flash a single device.
flash_device() {
    local SN="$1"
    local QDL_TOOL_PATH="$2"
    local IMAGE_PATH="$3"
    local STORAGE_TYPE="$4"
    local PASSWORD="$5"
    local PLATFORM="$6"
    local DEV_LOG="$(realpath "$LOG_DIR/flash_${SN}_${TIMESTAMP}.log")"
    local PROG_FILE="$(realpath "$IMAGE_PATH/prog_firehose_ddr.elf")"

    echo "[INFO][$PLATFORM][$SN] Flashing start. Log: $DEV_LOG"
    : > "$DEV_LOG"

   wait_for_device() {
        local timeout=60
        local count=0
        while ! lsusb -v -d 05c6:9008 2>/dev/null | grep iProduct | grep -q "$SN"; do
            #if [[ "$count" -ge $timeout ]]; then echo "[ERROR][$PLATFORM][$SN] Device not responding after ${timeout}s."; return 1; fi
            sleep 1
            count=$((count + 1))
        done
        sleep 2
        return 0
    }

    do_flash() {
        pushd "$IMAGE_PATH" > /dev/null || exit 1

        # Safety Island  (QCS9075)
        if [[ "$PLATFORM" == "QCS9075" ]] && [[ -d "sail_nor" ]]; then
            echo "[INFO] sail_nor found, flashing spinor."
            cd sail_nor
            wait_for_device || { cd ..; exit 1; }
            echo "$PASSWORD" | sudo -S "${QDL_TOOL_PATH}/qdl" -S "$SN" -s spinor \
                "$PROG_FILE" rawprogram0.xml patch0.xml
            cd ..
        fi

        # UFS Provision
        if [[ "$PLATFORM" == "QCS9075" ]] && [[ "$STORAGE_TYPE" == "ufs" ]]; then
            echo "[INFO] UFS provisioning."
            wait_for_device || exit 1
            echo "$PASSWORD" | sudo -S "${QDL_TOOL_PATH}/qdl" -S "$SN" \
                "$PROG_FILE" provision_1_2.xml
        elif [[ "$PLATFORM" == "QCS6490" ]] && [[ "$STORAGE_TYPE" == "ufs" ]]; then
            echo "[INFO] UFS provisioning."
            wait_for_device || exit 1
            echo "$PASSWORD" | sudo -S "${QDL_TOOL_PATH}/qdl" -S "$SN" \
                "$PROG_FILE" provision_ufs31.xml
        fi

        # CDT (QCS9075)
        if [[ -d "cdt" ]] && [[ "$STORAGE_TYPE" == "ufs" ]]; then
            echo "[INFO] cdt found, flashing cdt partition."
            cd cdt
            wait_for_device || exit 1
            echo "$PASSWORD" | sudo -S "${QDL_TOOL_PATH}/qdl" -S "$SN" \
                "$PROG_FILE" rawprogram3.xml patch3.xml
            cd ..
        fi

        # Flash all system partitions.
        echo "[INFO] Flashing system partitions."
        wait_for_device || exit 1
        echo "$PASSWORD" | sudo -S "${QDL_TOOL_PATH}/qdl" -S "$SN" -s "$STORAGE_TYPE" \
            "$PROG_FILE" rawprogram*.xml patch*.xml

        popd > /dev/null
    }

    (
        export SN QDL_TOOL_PATH IMAGE_PATH STORAGE_TYPE PROG_FILE PASSWORD PLATFORM
        script -q -c "$(declare -f wait_for_device do_flash); do_flash" /dev/null \
            >> "$DEV_LOG" 2>&1
    )

    # Verify
    if verify_success "$DEV_LOG" "$PLATFORM"; then
        echo "[SUCCESS][$PLATFORM][$SN] Flash completed."
    else
        echo "[ERROR][$PLATFORM][$SN] Flash failed. Check $DEV_LOG"
    fi
}

# Parse command-line arguments.
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t) QDL_TOOL_PATH=$(realpath "$2"); shift 2 ;;
        -i) IMAGE_PATH=$(realpath "$2");    shift 2 ;;
        -s) STORAGE_TYPE="$2";              shift 2 ;;
        -p) PASSWORD="$2";                  shift 2 ;;
        -f) FORCE_START=true;               shift   ;;
        -n) EXPECTED_COUNT="$2";            shift 2 ;;
        -h|--help)
            cat <<EOF
Usage: $0 -t <QDL_TOOL_PATH> -i <IMAGE_PATH> -p <PASSWORD> [-s ufs|emmc] [-n N] [-f]
  -t  Path to QDL tool directory
  -i  Path to BSP image directory
  -p  Your sudo password
  -s  Storage type (default: ufs)
  -n  Expected device count for auto-start
  -f  Force start without confirmation
EOF
            exit 0 ;;
        *)  echo "Unknown parameter: $1"; exit 1     ;;
    esac
done

# Validate arguments.
[[ -z "$QDL_TOOL_PATH" || -z "$IMAGE_PATH" || -z "$PASSWORD" ]] && {
    echo "[ERROR] Missing required arguments (-t, -i, -p)"
    exit 1
}
[[ -z "$STORAGE_TYPE" ]] && { echo "[WARN] STORAGE empty, defaulting to ufs"; STORAGE_TYPE=ufs; }

# Detect connected devices.
OUTPUT=$(lsusb -v -d 05c6:9008 2>/dev/null | grep iProduct | grep -E "CID:($AVAILABLE_CIDS)_")
SN_LIST=$(echo "$OUTPUT" | sed 's/.*_SN://' | awk '{print $1}')
ACTUAL_COUNT=$(echo "$SN_LIST" | wc -w)

if [ "$ACTUAL_COUNT" -eq 0 ]; then
    echo "[ERROR] No supported 9008 devices found (CID in $AVAILABLE_CIDS)."
    exit 1
fi

echo "------------------------------------------"
echo "[INFO] Found $ACTUAL_COUNT device(s):"
for SN in $SN_LIST; do
    P=$(detect_platform "$SN")
    echo "       - $SN  [$P]"
done
echo "------------------------------------------"

# Confirm before flashing.x
START=false
if [ "$FORCE_START" = true ]; then
    echo "[INFO] -f detected: Force starting..."
    START=true
elif [ "$EXPECTED_COUNT" -ne 0 ]; then
    if [ "$ACTUAL_COUNT" -eq "$EXPECTED_COUNT" ]; then
        echo "[INFO] -n $EXPECTED_COUNT matches actual count: Auto starting..."
        START=true
    else
        echo "[ERROR] Expected $EXPECTED_COUNT device(s) but detected $ACTUAL_COUNT."
        echo "[ERROR] Please check device connections and try again."
        exit 1
    fi
else
    read -rp "Proceed with $ACTUAL_COUNT devices? (y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] && START=true
fi

[ "$START" = false ] && { echo "[INFO] Cancelled."; exit 0; }

# Ensure image directory ownership.
echo "$PASSWORD" | sudo -S chown -R "$(id -u):$(id -g)" "$IMAGE_PATH"

# Flash all devices in parallel.
for SN in $SN_LIST; do
    PLATFORM=$(detect_platform "$SN")
    echo "[INFO] Starting flash for $SN ($PLATFORM)"
    flash_device "$SN" "$QDL_TOOL_PATH" "$IMAGE_PATH" "$STORAGE_TYPE" "$PASSWORD" "$PLATFORM" &
    PIDS+=($!)
done

echo "[INFO] All flash processes running. PIDs: ${PIDS[@]}"
wait

trap - SIGINT SIGTERM EXIT