#!/usr/bin/env bash

# 从 .env 读取 CONDA_BASE，未设置则回退到 $HOME/miniconda
CONDA_BASE=$(grep -E '^CONDA_BASE=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
CONDA_BASE="${CONDA_BASE:-$HOME/miniconda}"

# 激活 conda 环境（与 conda initialize 块保持一致）
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

# 提取 .env 中的项目路径，如果未设置则默认使用当前目录
BASE_DIR=$(grep -E '^BASE_DIR=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
WORK_DIR="${BASE_DIR:-$PWD}"

# 定义要存放和工作的基础目录
COURSE_DIR="$WORK_DIR/course"
if [ ! -d "$COURSE_DIR" ]; then
    echo "未找到目录: $COURSE_DIR"
    echo "请先创建 course 目录或确认 BASE_DIR 配置是否正确。"
    exit 1
fi

# 1. 询问用户输入链接和名称
echo -n "请输入视频下载链接: "
read url
if [ -z "$url" ]; then
    echo "链接不能为空！"
    exit 1
fi

echo -n "请输入课程名称: "
read course_name
if [ -z "$course_name" ]; then
    echo "课程名称不能为空！"
    exit 1
fi

# 2. 识别提取课程日期 (匹配出类似我们看到链接中的 YYYY/MM/DD)
course_date=$(echo "$url" | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2}' | head -n 1 | sed 's/\///g')

# 如果链接中没有找到日期格式，默认兜底使用当天的日期
if [ -z "$course_date" ]; then
    echo "[警告] 未能从链接中自动识别出日期格式 (YYYY/MM/DD)，默认使用今天日期..."
    course_date=$(date +%Y%m%d)
fi

filename="${course_name}_${course_date}.mp4"
echo "[INFO] 提取完成，目标下载文件名为: $filename"

# 3. 依次执行流水线（不做重试，网络问题由用户自行处理）
echo "==========================================================="
echo "                  [阶段 1/3] aria2c 下载"
# 使用 -d 参数指定文件保存在 course 文件夹下，-o 指定重命名的文件名
referer=$(echo "$url" | grep -oE 'https?://[^/]+/')
aria2c --referer="$referer" -x 8 -s 8 -c -d "$COURSE_DIR" -o "$filename" "$url"

echo "==========================================================="
echo "                  [阶段 2/3] 本地转录提取 (run_course.sh)"
bash run_course.sh

echo "==========================================================="
echo "                  [阶段 3/3] 排版和精炼整理 (refinement.py)"
python refinement.py

echo "==========================================================="
echo "🎉 全部流程大功告成！文件保存在 result 目录下。"
