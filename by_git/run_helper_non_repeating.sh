#!/bin/bash

# 替换为你的进程名列表
PROCESS_NAMES=("streamlit" "Sparkdesk-Openaiapi/api.py")
DIR="$(cd "$(dirname "$0")" && pwd)"
START_COMMAND="$DIR/entrypoint.sh"  # 替换为启动命令

ACTION="run"

# 解析参数
for arg in "$@"; do
    case $arg in
        --stop)
            ACTION="stop"
            ;;
        --restart)
            ACTION="restart"
            ;;
        *)
            ;;
    esac
done

# 递归地杀死进程及其所有子进程
kill_recursive() {
    local parent_pid=$1

    # 获取所有子进程
    local children=$(pgrep -P $parent_pid)
    for child in $children; do
        kill_recursive $child
    done

    # 杀死这个进程
    kill -KILL $parent_pid 2>/dev/null
}

# 停止进程的函数
stop_process() {
    local process_name=$1
    local PIDS=$(pgrep -f $process_name)

    if [ "$PIDS" == "" ]; then
        echo "No $process_name process found."
        return
    fi

    # Step 1: Send the TERM signal
    for pid in $PIDS; do
        pkill -TERM -g $pid
    done

    # Step 2: Wait for a short period (e.g., 5 seconds) to give processes a chance to shut down gracefully
    sleep 5

    # Step 3: Check if the processes are still running and force kill them if necessary
    for pid in $PIDS; do
        if ps -p $pid > /dev/null; then
            # 使用递归函数杀死目标进程及其所有子进程
            kill_recursive $pid
        fi
    done

    # Check and echo the result
    sleep 2
    PIDS=$(pgrep -f $process_name)
    if [ "$PIDS" == "" ]; then
        echo "[RUN HELPER]: All $process_name processes were successfully stopped."
        return
    else
        echo "[RUN HELPER]: Stop $process_name failed. some processes are running."
    fi
}

# 根据参数执行操作
case $ACTION in
    run)
        for process_name in "${PROCESS_NAMES[@]}"; do
            if ! pgrep -f $process_name > /dev/null; then
                echo "[RUN HELPER]: Starting the $process_name process..."
                $START_COMMAND
            else
                echo "[RUN HELPER]: $process_name process is already running."
            fi
        done
        ;;
    stop)
        for process_name in "${PROCESS_NAMES[@]}"; do
            stop_process $process_name
        done
        ;;
    restart)
        for process_name in "${PROCESS_NAMES[@]}"; do
            stop_process $process_name
            echo "[RUN HELPER]: Starting the $process_name process..."
            $START_COMMAND
        done
        ;;
esac
