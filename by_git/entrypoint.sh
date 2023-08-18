#!/bin/bash

# 开启命令调试：显示所有命令
#set -x
# 开启零容错：指令返回错误，直接终止脚本
set -e


# 运行环境变量设置，如path等
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)" 
eval "$(pyenv virtualenv-init -)" 

# python虚拟环境切换
pyenv global 3.11.0

# cd into APP folder
cd /APP/customerQuest/demo/

# 运行依赖服务 后台运行
python ../Sparkdesk-Openaiapi/api.py &

# 运行主服务 前台运行
streamlit run "项目介绍.py"


