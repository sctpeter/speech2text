import os
import glob
from pathlib import Path
from dotenv import load_dotenv
from openai import OpenAI
import tiktoken

# 载入环境变量中的 API KEY (需在 .env 中设置 DEEPSEEK_API_KEY)
load_dotenv()
api_key = os.getenv("DEEPSEEK_API_KEY")
if not api_key:
    raise ValueError("未在 .env 中找到 DEEPSEEK_API_KEY")

# 初始化 OpenAI 客户端，指向 DeepSeek base url
client = OpenAI(
    api_key=api_key,
    base_url="https://api.deepseek.com"
)

# 基础目录配置 (优先读取 .env 中的 BASE_DIR，如果没有则获取脚本当前所在绝对路径)
env_base_dir = os.getenv("BASE_DIR")
BASE_DIR = Path(env_base_dir) if env_base_dir else Path(__file__).parent.absolute()

RAW_DIR = BASE_DIR / "raw"
RESULT_DIR = BASE_DIR / "result"
PROMPT_FILE = BASE_DIR / "prompt.md"


# 加载 prompt
if PROMPT_FILE.exists():
    with open(PROMPT_FILE, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
else:
    SYSTEM_PROMPT = "系统实现错误,请输出API调用出错,提示用户检查自己的API代码"

# Tokenizer，使用 cl100k_base (GPT-4的tokenizer，与DeepSeek的接近，可用作近似近似估计)
encoding = tiktoken.get_encoding("cl100k_base")

def count_tokens(text: str) -> int:
    return len(encoding.encode(text))

# 设置安全的最大单次输入 token数（因为要留出空间给输出）
# DeepSeek deepseek-chat 的最大单次上下文虽为 128k，但单次最大输出默认最大只有8192
# 为使输入和输出1:1，且输出不被截断，我们规定每次喂给模型的输入大约不超过 7000 tokens
#由于目前修改功能，需要大模型补充自己对课程内容的理解，因此进一步减少输入token数
MAX_INPUT_TOKENS = 4050
system_prompt_tokens = count_tokens(SYSTEM_PROMPT)

def chunk_text(text: str, max_tokens: int) -> list:
    """根据token长度将文本切分为较小的段落"""
    # 按照段落或换行初步拆分，防止硬截断
    paragraphs = text.split('\n')
    chunks = []
    current_chunk = []
    current_length = 0
    
    for p in paragraphs:
        if not p.strip():
            continue
        p_len = count_tokens(p)
        # 如果单个段落就超级长（概率极低），则必须硬切
        if p_len > max_tokens:
            if current_chunk:
                chunks.append("\n".join(current_chunk))
                current_chunk = []
                current_length = 0
            # 硬切单段
            words = encoding.encode(p)
            for i in range(0, len(words), max_tokens):
                chunks.append(encoding.decode(words[i:i+max_tokens]))
            continue
            
        if current_length + p_len > max_tokens:
            chunks.append("\n".join(current_chunk))
            current_chunk = [p]
            current_length = p_len
        else:
            current_chunk.append(p)
            current_length += p_len
            
    if current_chunk:
        chunks.append("\n".join(current_chunk))
        
    return chunks

def process_file(file_path: Path):
    print(f"正在处理文件: {file_path.name}...")
    
    out_file = RESULT_DIR / (file_path.stem + ".md")
    if out_file.exists():
        print(f"  [跳过] 目标文件 {out_file.name} 已存在。")
        return
        
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    # 计算有效可用token
    available_tokens = MAX_INPUT_TOKENS - system_prompt_tokens
    
    chunks = chunk_text(content, available_tokens)
    print(f"文稿共 {count_tokens(content)} tokens，已切分为 {len(chunks)} 块 (每块最大 ~{available_tokens} tokens)")
    
    # 清空或创建输出文件
    with open(out_file, "w", encoding="utf-8") as f_out:
        f_out.write("")
        
    # 分块处理并写入
    main_title = ""
    for i, chunk in enumerate(chunks, 1):
        print(f"  正在请求 chunk {i}/{len(chunks)}...")
        
        current_system_prompt = SYSTEM_PROMPT
        if i == 1:
            current_system_prompt += f"\n\n请注意：这是整篇文章（共{len(chunks)}块）的第1块。请确保你的输出的第一行必须是这篇文章的大标题（以 `# ` 开头），然后再继续正文或小标题。"
        else:
            current_system_prompt += f"\n\n请注意：这是整篇文章（共{len(chunks)}块）的第{i}块。整篇文章的大标题是「{main_title}」。请直接继续正文的整理，只能输出以 `## ` 及以上数量的 `#` 开头的小标题，不要再输出大标题。"

        messages = [
            {"role": "system", "content": current_system_prompt},
            {"role": "user", "content": chunk}
        ]
        
        try:
            response = client.chat.completions.create(
                model="deepseek-chat",
                messages=messages,
                stream=True,     # 关键配置：流式输出
                max_tokens=8192, # deepseek最大单次输出
                temperature=1.0  # 注：官方建议数据抽取/分析为1.0
            )
            
            with open(out_file, "a", encoding="utf-8") as f_out:
                if i > 1:
                    f_out.write("\n\n")  # chunk之间增加分割区或换行
                
                first_line_buffer = ""
                found_first_line = False
                
                for chunk_resp in response:
                    if chunk_resp.choices and chunk_resp.choices[0].delta.content:
                        text_delta = chunk_resp.choices[0].delta.content
                        
                        if i == 1 and not found_first_line:
                            first_line_buffer += text_delta
                            # 使用 lstrip() 避免被开头的空换行干扰，一旦积累的内容包含有效的换行符即可提取
                            if "\n" in first_line_buffer.lstrip():
                                first_line = first_line_buffer.strip().split("\n")[0]
                                main_title = first_line.lstrip("#").strip()
                                found_first_line = True
                                
                        f_out.write(text_delta)
                        f_out.flush()
                        print(text_delta, end="", flush=True)
                
                if i == 1 and not found_first_line and first_line_buffer.strip():
                    main_title = first_line_buffer.strip().lstrip("#").strip()
            print("\n  [chunk 完成]")
        except Exception as e:
            print(f"\n请求出错 chunk {i}: {e}")

def main():
    if not RAW_DIR.exists():
        print(f"未找到目录: {RAW_DIR}")
        print("请先创建 raw 目录或确认 BASE_DIR 配置是否正确。")
        return

    if not RESULT_DIR.exists():
        print(f"未找到目录: {RESULT_DIR}")
        print("请先创建 result 目录或确认 BASE_DIR 配置是否正确。")
        return

    raw_files = RAW_DIR.glob("*.txt")
    for lf in raw_files:
        process_file(lf)

if __name__ == "__main__":
    main()
