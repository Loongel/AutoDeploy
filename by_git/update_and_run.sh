#!/bin/bash

# 使用环境变量获取参数
GIT_REPO=${GIT_REPO}
BRANCH_NAME=${BRANCH_NAME}
LOCAL_DIR=${LOCAL_DIR}
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"  # 保存当前工作目录
RUN_SCRIPT="$CURRENT_DIR/run_helper_non_repeating.sh"  # 使用保存的工作目录来引用脚本

# 检查并安装缺失的命令（上面提供的代码片段）
commands=("git" "pgrep" "pkill" "sleep")
for cmd in "${commands[@]}"; do
    which $cmd > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Installing $cmd..."

        # 检测操作系统类型
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            case $ID in
                debian|ubuntu)
                    apt-get update
                    apt-get install -y $cmd
                    ;;
                centos)
                    yum install -y $cmd
                    ;;
                alpine)
                    apk add --no-cache $cmd
                    ;;
                *)
                    echo "Unsupported OS"
                    exit 1
                    ;;
            esac
        else
            echo "Cannot detect OS type"
            exit 1
        fi
    fi
done


# 如果输入参数为 --manual，直接执行 run_helper_non_repeating.sh 脚本并退出
if [ "$1" == "--manual" ]; then
    bash $RUN_SCRIPT --restart
    exit 0
fi


# 如果有其他同名进程在运行，结束它们
script_name=$(basename $0)
pids=$(pgrep -f "$script_name")

for pid in $pids; do
    # 不结束当前进程
    if [ $pid != $$ ]; then
        kill -9 $pid 2>/dev/null
    fi
done

# 创建命名管道
PIPE="$CURRENT_DIR/woker_pipe"
mkfifo $PIPE

# 先关闭目标进程
bash $RUN_SCRIPT --stop

# 将整个检查逻辑放入后台
(
    # 切换到本地仓库目录
    cd $LOCAL_DIR || { echo "Failed to switch to directory $LOCAL_DIR"; exit 1; }

    while true; do
        # 检查git状态
        git fetch

        LOCAL_COMMIT=$(git rev-parse HEAD)
        REMOTE_COMMIT=$(git rev-parse "origin/$BRANCH_NAME")

        if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
            echo "[UPDATE-SRV]: New changes detected."

            # 先停止进程
            bash $RUN_SCRIPT --stop

            # 拉取更新
            git pull origin $BRANCH_NAME
            git reset --hard origin/$BRANCH_NAME
            git checkout $BRANCH_NAME
            echo "[UPDATE-SRV]: Updated to the newest release."
            
            # 重新启动进程
            bash $RUN_SCRIPT --run > $PIPE 2>&1 &
        else
            echo "[UPDATE-SRV]: No changes detected."
            
        fi

        # 等待一分钟再次检查
        sleep 60
    done
) > $PIPE 2>&1 &

bash $RUN_SCRIPT --run > $PIPE 2>&1 &
# 在前台读取命名管道的内容
cat < $PIPE