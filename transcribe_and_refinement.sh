#!/usr/bin/env bash

# 从 .env 读取 CONDA_BASE，未设置则回退到 $HOME/miniconda
CONDA_BASE=$(grep -E '^CONDA_BASE=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
CONDA_BASE="${CONDA_BASE:-$HOME/miniconda}"

# 激活 conda 环境
__conda_setup="$("$CONDA_BASE/bin/conda" 'shell.bash' 'hook' 2>/dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
        . "$CONDA_BASE/etc/profile.d/conda.sh"
    else
        export PATH="$CONDA_BASE/bin:$PATH"
    fi
fi
unset __conda_setup
conda activate speech2text

# 提取项目路径
BASE_DIR=$(grep -E '^BASE_DIR=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
WORK_DIR="${BASE_DIR:-$PWD}"
COURSE_DIR="$WORK_DIR/course"

if [ ! -d "$COURSE_DIR" ]; then
    echo "未找到目录: $COURSE_DIR"
    echo "请先创建 course 目录或确认 BASE_DIR 配置是否正确。"
    exit 1
fi

# 阶段 1：批量转录
echo "==========================================================="
echo "                  [阶段 1/2] 本地转录 (run_course.sh)"
echo "==========================================================="
bash run_course.sh

# 阶段 2：批量精炼
echo "==========================================================="
echo "                  [阶段 2/2] 排版和精炼 (refinement.py)"
echo "==========================================================="
python refinement.py

echo "==========================================================="
echo "全部课程处理完成！文件保存在 result 目录下。"
echo "==========================================================="
