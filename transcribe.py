#请使用wsl中的speech2text的conda环境运行此脚本.
#输入可以用windows风格的路径名，但是记得加引号。
from faster_whisper import WhisperModel, download_model
import sys, os, time
from opencc import OpenCC
cc = OpenCC("tw2sp")  # 繁转简

# 在 WSL 中自动转换 Windows 路径 (例如 C:\ -> /mnt/c/)
def fix_wsl_path(path):
    if sys.platform.startswith("linux") and len(path) > 1 and path[1] == ":":
        try:
            drive = path[0].lower()
            # 将 C:\Users\... 转换为 /mnt/c/Users/...
            wsl_path_suffix = path[2:].replace('\\', '/')
            new_path = f"/mnt/{drive}{wsl_path_suffix}"
            if os.path.exists(new_path):
                return new_path
        except:
            pass
    return path

# model_size = os.environ.get("MODEL", "large-v3")  # 原配置暂时注释
model_size = "medium"
audio_path = fix_wsl_path(sys.argv[1])
output_path = sys.argv[2] if len(sys.argv) > 2 else None

print(f"[INFO] 模型: {model_size}")
print(f"[INFO] 文件: {audio_path}")

print(f"[INFO] 优先使用本地缓存模型 (默认路径 ~/.cache/huggingface/hub/)...")
# 优先使用本地缓存；若不存在则允许联网下载
try:
    model_path = download_model(model_size, local_files_only=True)
except Exception:
    print("[INFO] 本地缓存未找到，尝试联网下载模型...")
    model_path = download_model(model_size, local_files_only=False)

from dotenv import load_dotenv

# 加载 .env 中的环境变量
load_dotenv()

# 获取 CPU 线程数配置，如果没有默认使用 7
cpu_threads = int(os.environ.get("CPU_THREADS", 7))

print(f"[INFO] 正在加载模型：{model_path} (使用的 CPU 线程数: {cpu_threads})")
model = WhisperModel(model_path, device="cpu", compute_type="int8", cpu_threads=cpu_threads)

print(f"[INFO] 开始转写...\n")
start_time = time.time()

segments, info = model.transcribe(
    audio_path,
    language="zh",
    beam_size=1,
    vad_filter=True,
    vad_parameters=dict(
        min_silence_duration_ms=300,   # 课堂停顿较短，300ms更合适
        speech_pad_ms=400,             # 多保留一点前后语音，防止截断
    ),
    condition_on_previous_text=True,   # 课堂语音连贯，开着有助于上下文理解
    no_speech_threshold=0.6,
)

print(f"# 语言: {info.language}, 概率: {info.language_probability:.2f}")
print(f"# 音频时长: {info.duration:.1f}s ({info.duration/60:.1f}min)\n")

outfile = None
if output_path:
    outfile = open(output_path, "w", encoding="utf-8")
    outfile.write(f"# 文件: {audio_path}\n")
    outfile.write(f"# 语言: {info.language}, 概率: {info.language_probability:.2f}\n")
    outfile.write(f"# 音频时长: {info.duration:.1f}s ({info.duration/60:.1f}min)\n\n")

lines = []
for seg in segments:
    text_cn = cc.convert(seg.text)  # 转换为简体
    console_line = f"[{seg.start:.1f}s -> {seg.end:.1f}s] {text_cn}"
    file_line = text_cn
    print(console_line)
    lines.append(file_line)
    if outfile:
        outfile.write(file_line + "\n")
        outfile.flush()

elapsed = time.time() - start_time
ratio = info.duration / elapsed if elapsed > 0 else 0
print(f"\n[INFO] 耗时: {elapsed:.1f}s, 实时比: {ratio:.2f}x")

if outfile:
    outfile.write(f"\n# 耗时: {elapsed:.1f}s, 实时比: {ratio:.2f}x\n")
    outfile.flush()
    outfile.close()
    print(f"[INFO] 已保存到: {output_path}")