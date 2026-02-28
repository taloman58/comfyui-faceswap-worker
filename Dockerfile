# =============================================================
# 1. BASE IMAGE & SYSTEM DEPENDENCIES
# =============================================================
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# Kurulum sırasında interaktif ekranların çıkmasını engeller
ENV DEBIAN_FRONTEND=noninteractive

# Python headers ve C++ derleyiciler insightface paketinin derlenmesi icin zorunludur
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake python3-dev && rm -rf /var/lib/apt/lists/*

# =============================================================
# 2. REACTOR (FACE SWAP)
# =============================================================
# InsightFace ozel olarak derleniyor
RUN pip install --no-cache-dir insightface==0.7.3

# ReActor klasoru cekilir ve tum requirements tam olarak kurulur
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Gourieff/ComfyUI-ReActor.git

RUN cd /comfyui/custom_nodes/ComfyUI-ReActor && \
    pip install --no-cache-dir -r requirements.txt

# Torchvision eksik olma ihtimaline karsi manuel kurulur
RUN pip install --no-cache-dir torchvision --extra-index-url https://download.pytorch.org/whl/cu121

# =============================================================
# 3. OTHER REQUIRED CUSTOM NODES
# =============================================================
RUN comfy-node-install comfyui_ipadapter_plus
RUN comfy-node-install comfyui-videohelpersuite
RUN comfy-node-install comfyui-animatediff-evolved
RUN comfy-node-install comfyui-frame-interpolation
RUN comfy-node-install comfyui_ultimatesdupscale
RUN comfy-node-install comfyui-impact-pack
RUN comfy-node-install comfyui-advanced-controlnet
RUN comfy-node-install comfyui-kjnodes
RUN comfy-node-install comfyui_essentials
RUN comfy-node-install was-node-suite-comfyui

# ------------------------------------------------------------
# FIX: ONNXRUNTIME KURULUMU (REACTOR ICIN KRITIK)
# ------------------------------------------------------------
RUN pip install --no-cache-dir onnxruntime-gpu

# =============================================================
# 4. MODEL KLASORLERINI OLUSTUR (symlink hedefleri)
# =============================================================
RUN mkdir -p /comfyui/models/insightface \
    /comfyui/models/facerestore_models \
    /comfyui/models/upscale_models \
    /comfyui/models/clip_vision \
    /comfyui/models/ipadapter \
    /comfyui/models/controlnet \
    /comfyui/models/nsfw_detector/vit-base-nsfw-detector

# =============================================================
# 4.1 NSFW DETECTION MODEL (ReActor cold start fix)
# Bu olmadan her cold start'ta ~328MB HuggingFace'den indiriliyor
# =============================================================
RUN cd /comfyui/models/nsfw_detector/vit-base-nsfw-detector && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json && \
    echo 'NSFW model pre-downloaded OK'

# =============================================================
# 5. HANDLER - VIDEO/GIF DESTEGI VE BUCKET_NAME FIX
# =============================================================
COPY handler.py /handler.py

# =============================================================
# 6. NETWORK VOLUME ENTRYPOINT
# Modeller /runpod-volume/models/ klasöründen symlink edilir
# =============================================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
