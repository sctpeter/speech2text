#!/usr/bin/env bash
set -euo pipefail

# 激活 conda 环境
if [ -f "$HOME/miniconda/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
fi
conda activate speech2text

# 提取 .env 中的项目路径，如果未设置则默认使用当前目录
BASE_DIR=$(grep -E '^BASE_DIR=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
WORK_DIR="${BASE_DIR:-$PWD}"

# 定义录音输入和输出目录
COURSE_DIR="$WORK_DIR/course"
RAW_DIR="$WORK_DIR/raw"

if [ ! -d "$COURSE_DIR" ]; then
    echo "未找到目录: $COURSE_DIR"
    echo "请先创建 course 目录或确认 BASE_DIR 配置是否正确。"
    exit 1
fi

if [ ! -d "$RAW_DIR" ]; then
    echo "未找到目录: $RAW_DIR"
    echo "请先创建 raw 目录或确认 BASE_DIR 配置是否正确。"
    exit 1
fi

echo "开始扫描视频..."

# 遍历 course 文件夹下的音视频文件 (支持 mp4, mp3)
for input_file in "$COURSE_DIR"/*.mp4 "$COURSE_DIR"/*.mp3; do
    # 判断文件是否存在 (防止通配符部分匹配失败返回字面量)
    [ -e "$input_file" ] || continue
    
    # 提取纯文件名（不含路径和后缀）
    filename=$(basename -- "$input_file")
    stem="${filename%.*}"
    
    # 对应的输出 txt 路径
    output_file="$RAW_DIR/${stem}.txt"
    
    # 判断结果是否已经存在，如果存在则跳过
    if [ -f "$output_file" ]; then
        echo "[INFO] [跳过] 转录结果已存在: $output_file"
        continue
    fi
    
    echo "==========================================="
    echo "[INFO] 正在处理视频: $filename"
    echo "[INFO] 输入: $input_file"
    echo "[INFO] 输出: $output_file"
    
    # 运行转录脚本
    python transcribe.py "$input_file" "$output_file"
done

echo "扫描和处理完成！"
