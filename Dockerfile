# =============================================================
# BASE IMAGE - model yok, node yok, sadece worker
# Node'lar ve modeller R2'den geliyor (sync_from_r2.py)
# =============================================================
FROM runpod/worker-comfyui:5.7.1-base

ENV DEBIAN_FRONTEND=noninteractive

# Sistem bagimliliklar (insightface derleme + ffmpeg)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake python3-dev ffmpeg x264 libx264-dev \
    && rm -rf /var/lib/apt/lists/*

# ReActor icin zorunlu Python paketleri
RUN pip install --no-cache-dir \
    insightface==0.7.3 \
    onnxruntime-gpu \
    torchvision \
    faiss-gpu \
    accelerate diffusers transformers lark \
    --extra-index-url https://download.pytorch.org/whl/cu121 || true

# Handler ve startup scriptleri
COPY handler.py /handler.py
COPY start.sh /start.sh
COPY sync_from_r2.py /sync_from_r2.py
RUN chmod +x /start.sh

CMD ["/start.sh"]
