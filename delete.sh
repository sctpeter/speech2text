#!/usr/bin/env bash

# 提取 .env 中的项目路径，如果未设置则默认使用当前目录
BASE_DIR=$(grep -E '^BASE_DIR=' .env 2>/dev/null | cut -d '=' -f 2- | sed "s/['\"]//g")
WORK_DIR="${BASE_DIR:-$PWD}"

COURSE_DIR="$WORK_DIR/course"
RAW_DIR="$WORK_DIR/raw"
RESULT_DIR="$WORK_DIR/result"

echo "开始扫描 course, raw, result 三个目录中都存在的课程..."
echo

declare -a to_delete_course
declare -a to_delete_raw
declare -a to_delete_result

# 遍历 course 目录中的 mp4 和 mp3 文件
for course_file in "$COURSE_DIR"/*.mp4 "$COURSE_DIR"/*.mp3; do
    [ -e "$course_file" ] || continue
    
    # 获取文件名和去除后缀的基础名(stem)
    filename=$(basename -- "$course_file")
    stem="${filename%.*}"
    
    # 构建对应的原始识别文本以及最终输出笔记路径
    raw_file="$RAW_DIR/${stem}.txt"
    result_file="$RESULT_DIR/${stem}.md"
    
    # 检查关联的 raw 和 result 文件是否都存在
    if [[ -f "$raw_file" && -f "$result_file" ]]; then
        to_delete_course+=("$course_file")
        to_delete_raw+=("$raw_file")
        to_delete_result+=("$result_file")
        
        echo "[发现完整流程文件组: $stem]"
        echo "  1. 视频/音频 : $course_file"
        echo "  2. 转录文本 : $raw_file"
        echo "  3. 最终笔记 : $result_file"
        echo "--------------------------------------------------------"
    fi
done

# 如果没有检测到则直接退出
if [ ${#to_delete_course[@]} -eq 0 ]; then
    echo "没有需要清理的、三个目录下均存在的文件组！"
    exit 0
fi

echo "共发现 ${#to_delete_course[@]} 组需要清理的文件！"
read -rp "⚠ 警告: 确定要永久删除以上所有文件吗？请输入 yes 确认: " confirm

if [ "$confirm" == "yes" ]; then
    for i in "${!to_delete_course[@]}"; do
        rm -f "${to_delete_course[$i]}"
        rm -f "${to_delete_raw[$i]}"
        rm -f "${to_delete_result[$i]}"
    done
    echo "所有指定文件已成功删除！"
else
    echo "操作已取消。"
fi
