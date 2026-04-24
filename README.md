# Speech2Text Course Pipeline

本项目提供面向大学课程/讲座的自动化处理流水线，可一键完成：**录播下载 ➡️ Faster-Whisper 本地语音识别转录 ➡️ OpenCC 繁简转换 ➡️ DeepSeek 大模型纠错与排版**，最终输出结构化的高质量 Markdown 笔记。

本工具面向 Linux 环境进行适配。

---

## 目录结构说明

工作流主要依赖以下三个核心数据文件夹（仓库自带目录；若使用自定义 BASE_DIR，请自行创建）：
* `course/`：用于存放原始未处理的上课视频或音频（支持 `.mp4`, `.mp3`）。
* `raw/`：存放 `faster-whisper` 转录后直接导出的粗糙文本（`.txt`）。
* `result/`：存放经过 DeepSeek AI 引擎校对错别字、排版后的最终版 MD 笔记（`.md`）。

---

##  安装与配置

### 1. 环境依赖
请确保在 Linux 中已安装以下基础工具：
```bash
# Ubuntu/Debian 示例
sudo apt update
sudo apt install aria2 ffmpeg
```
### 2. Python 环境准备
推荐使用 Conda 创建干净的虚拟环境：
```bash
conda create -n speech2text python=3.11
conda activate speech2text

# 安装必要的 Python 库
pip install faster-whisper opencc openai tiktoken python-dotenv
```

### 3. 配置 DeepSeek API 与基础路径
本项目使用 DeepSeek API 进行文本降噪与排版，目录可统一配置。
1. 复制配置文件模板：
   ```bash
   cp .env.example .env
   ```
2. 编辑 `.env` 文件，填入你的配置信息：
   - **`DEEPSEEK_API_KEY`**: 你的 API 密钥（可以在 [DeepSeek 开放平台](https://platform.deepseek.com/) 获取）。
   - **`CONDA_BASE`**: **(必填)** Conda 的安装根目录。不同用户/系统路径不同，脚本依赖此项来激活 `speech2text` 虚拟环境。常见路径示例：
     ```
     # Linux/WSL 普通用户
     CONDA_BASE="/home/<username>/miniconda3"
     # Linux root 用户
     CONDA_BASE="/root/miniconda"
     # macOS (Homebrew)
     CONDA_BASE="/opt/homebrew/anaconda3"
     ```
     若不填，脚本将回退到 `$HOME/miniconda`。
   - **`BASE_DIR`**: (可选) 项目所在绝对路径（例如 `/mnt/c/...`）。若不填写，将默认使用当前运行目录。
   - **`DEEPSEEK_MODEL`**: (可选) 调用的 DeepSeek 模型名称（默认 `deepseek-v4-flash`）。如需更高质量，可改为 `deepseek-v4-pro`。注意：旧模型名 `deepseek-chat` / `deepseek-reasoner` 将于 2026-07-24 停用。
   - **`CPU_THREADS`**: (可选) 使用 CPU 进行语音识别时的线程数（默认 7）。如设备负载较高，可适当调低。

---

## 注意与限制
- **仅预设 `.mp4`/`.mp3` 支持**：当前仅扫描 `.mp4` 与 `.mp3`，以避免误处理其他文件。底层 `faster-whisper` 与 `ffmpeg` 支持 `.mkv`、`.wav`、`.flac` 等多种格式，如有需要可调整 `run_course.sh` 与 `delete.sh` 的通配符。
- **不支持歌曲转录**：该模型针对口语与讲座场景调优，包含伴奏的音乐类音频可能触发 VAD 误判或产生幻觉，故不建议用于歌曲转录。
- **内存占用**：默认使用 `medium` 模型，建议至少保留 4GB 以上可用内存。

---

## 核心使用方法

### 方案 A：一键全自动处理 (推荐)
如拥有课程视频链接，可直接运行自动化流水线脚本完成处理。

```bash
bash run_all.sh
```
**运行过程：**

1. 终端提示输入下载链接与课程名称。
2. 从链接解析日期（若无则使用当天日期），生成如 `马原_20260305.mp4` 的文件名并使用 `aria2` 下载。
3. 触发本地模型进行语音识别生成基础文本。
4. 文本自动分块（每块 < 32000 tokens）并流式请求大模型。
5. 网络问题需用户自行处理。

最终结果在 `result/` 目录中生成 `.md` 文件。

### 方案 B：本地已有视频分步处理
如已通过其他方式获取音视频文件，可按以下流程进行批处理：

1. **导入资源**：将待处理文件放入 `course/` 目录。
2. **执行转录**：
   
   ```bash
   bash run_course.sh
   ```
   *(已识别过的文件会自动跳过，结果输出至 `raw`)*
3. **执行文本精炼**：
   
   ```bash
   python refinement.py
   ```
   *(终端将实时流式输出排版过程并写入 `result`)*

---

## 文件清理与管理

若音视频文件占用空间较大，或课程全部处理完毕，可使用清理脚本进行批量清理：

```bash
bash delete.sh
```
该脚本会检查课程资源。**仅当**同一课程的“视频/音频文件”“原始 `.txt` 转录”“最终 `.md` 笔记”均存在时，才会询问是否一键删除，释放本地硬盘空间。如需不同策略，可自行修改脚本。

---

## 进阶调整

- **自定义 Prompt**：可编辑项目根目录的 `prompt.md`，调整输出语气与排版要求。
- **自定义 DeepSeek 模型**：可在 `.env` 中修改 `DEEPSEEK_MODEL`，例如切换为 `deepseek-v4-pro`（质量更高但费用更贵）。旧模型名 `deepseek-chat` / `deepseek-reasoner` 将于 2026-07-24 停用。
- **自定义语音识别模型规模**：可在 `transcribe.py` 中修改 `model_size="medium"`，以换取更高精度但更慢的 `large-v3` 模型（需要更多内存）。

## 效果

- 在 Intel i7 机器上，使用 7 个核心、`medium` 模型、`beam=1`，3 小时课程约 1 小时完成处理。笔记质量较高。