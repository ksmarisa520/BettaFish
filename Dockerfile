# syntax=docker/dockerfile:1.4          # 启用 --mount 缓存
FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/python:3.11-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ================ 环境变量 ================
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/root/.local/bin:${PATH}" \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    # 手动安装
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

# ================ 换国内 Debian 源 ================
RUN sed -i 's@http://deb.debian.org@http://mirrors.aliyun.com@g' /etc/apt/sources.list && \
    sed -i 's@http://security.debian.org@http://mirrors.aliyun.com@g' /etc/apt/sources.list

# ================ 系统依赖（缓存挂载） ================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        build-essential curl git \
        libgl1 libglib2.0-0 libgtk-3-0 libpango-1.0-0 libpangocairo-1.0-0 \
        libatk1.0-0 libatk-bridge2.0-0 libxcb1 libxcomposite1 libxdamage1 \
        libxext6 libxfixes3 libxi6 libxtst6 libnss3 libxrandr2 libxkbcommon0 \
        libasound2 libx11-xcb1 libxshmfence1 libgbm1 ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ================ 安装 uv（国内高速下载） ================
RUN --mount=type=cache,target=/root/.cache/pip \
    pip config set global.index-url https://mirrors.huaweicloud.com/repository/pypi/simple && \
    curl -LsSf --retry 3 --retry-delay 2 --proto '=https' --proto-redir '=https' --tlsv1.2 \
        https://astral.sh/uv/install.sh | sh

WORKDIR /app

# ================ Python 依赖（缓存挂载） ================
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    uv pip install --system -r requirements.txt

# ================ 安装 Chromium（缓存浏览器） ================
RUN --mount=type=cache,target=/root/.cache/pip \
    python -m playwright install chromium

# ================ 业务代码 ================
COPY .env.example .env
COPY . .

# 确保运行时目录
RUN mkdir -p /ms-playwright logs final_reports \
             insight_engine_streamlit_reports \
             media_engine_streamlit_reports \
             query_engine_streamlit_reports

EXPOSE 5000 8501 8502 8503
CMD ["python", "app.py"]
