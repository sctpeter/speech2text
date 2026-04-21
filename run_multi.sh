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

# 收集所有课程 URL 和名称
declare -a URLS
declare -a FILENAMES

echo "请依次输入课程下载链接和名称，完成后在链接处输入 done。"
echo "-----------------------------------------------------------"

while true; do
    echo -n "请输入视频下载链接 (输入 done 结束): "
    read url
    if [ "$url" = "done" ]; then
        break
    fi
    if [ -z "$url" ]; then
        echo "[警告] 链接不能为空，请重新输入。"
        continue
    fi

    echo -n "请输入课程名称: "
    read course_name
    if [ -z "$course_name" ]; then
        echo "[警告] 课程名称不能为空，请重新输入。"
        continue
    fi

    # 从链接中提取日期，找不到则用今天
    course_date=$(echo "$url" | grep -oE '[0-9]{4}/[0-9]{2}/[0-9]{2}' | head -n 1 | sed 's/\///g')
    if [ -z "$course_date" ]; then
        echo "[警告] 未能从链接中识别日期，使用今天日期。"
        course_date=$(date +%Y%m%d)
    fi

    filename="${course_name}_${course_date}.mp4"
    URLS+=("$url")
    FILENAMES+=("$filename")
    echo "[已加入] $filename"
    echo ""
done

total=${#URLS[@]}
if [ "$total" -eq 0 ]; then
    echo "未输入任何课程，退出。"
    exit 0
fi

echo ""
echo "==========================================================="
echo "共收集到 $total 个课程，开始处理..."
echo "==========================================================="

# 阶段 1：批量下载
echo ""
echo "                  [阶段 1/3] 批量下载"
echo "==========================================================="
for i in $(seq 0 $((total - 1))); do
    url="${URLS[$i]}"
    filename="${FILENAMES[$i]}"
    echo "[下载 $((i+1))/$total] $filename"
    referer=$(echo "$url" | grep -oE 'https?://[^/]+/')
    aria2c --referer="$referer" -x 8 -s 8 -c -d "$COURSE_DIR" -o "$filename" "$url"
    echo ""
done

# 阶段 2：批量转录
echo "==========================================================="
echo "                  [阶段 2/3] 本地转录 (run_course.sh)"
echo "==========================================================="
bash run_course.sh

# 阶段 3：批量精炼
echo "==========================================================="
echo "                  [阶段 3/3] 排版和精炼 (refinement.py)"
echo "==========================================================="
python refinement.py

echo "==========================================================="
echo "全部 $total 个课程处理完成！文件保存在 result 目录下。"
echo "==========================================================="
