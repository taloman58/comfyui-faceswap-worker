# =============================================================
# 1. BASE IMAGE & SYSTEM DEPENDENCIES
# =============================================================
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# Kurulum sirasinda interaktif ekranlarin cikmasini engeller
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
# 4.1 NSFW DETECTION MODEL (~328MB)
# =============================================================
RUN cd /comfyui/models/nsfw_detector/vit-base-nsfw-detector && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/config.json && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/model.safetensors && \
    wget -q https://huggingface.co/AdamCodd/vit-base-nsfw-detector/resolve/main/preprocessor_config.json && \
    echo 'NSFW model OK'

# =============================================================
# 5. HANDLER
# =============================================================
COPY handler.py /handler.py

# =============================================================
# 6. STARTUP SCRIPT
# =============================================================
COPY start.sh /start.sh
RUN chmod +x /start.sh

# =============================================================
# 7. COLD START MODEL PRE-DOWNLOADS
# En sonda — ustundeki tum layer'lar CACHE'den gelir
# =============================================================

# 7.1 InsightFace buffalo_l (~282MB)
RUN mkdir -p /comfyui/models/insightface/models/buffalo_l && \
    cd /tmp && \
    wget -q https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip && \
    python -m zipfile -e buffalo_l.zip /comfyui/models/insightface/models/buffalo_l/ && \
    rm buffalo_l.zip && \
    echo 'buffalo_l OK'

# 7.2 Facexlib + CodeFormer (~185MB)
RUN mkdir -p /comfyui/models/facedetection && \
    wget -q -O /comfyui/models/facedetection/detection_Resnet50_Final.pth \
    https://github.com/xinntao/facexlib/releases/download/v0.1.0/detection_Resnet50_Final.pth && \
    wget -q -O /comfyui/models/facedetection/parsing_parsenet.pth \
    https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/parsing_parsenet.pth && \
    echo 'facexlib OK'

# 7.3 AnimateDiff motion model (~1.8GB)
RUN mkdir -p /comfyui/models/animatediff_models && \
    wget -q -O /comfyui/models/animatediff_models/mm_sd_v15_v2.ckpt \
    https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt && \
    echo 'AnimateDiff OK'

# =============================================================
# 8. PRO VIDEO FACE SWAP NODES
# =============================================================
RUN comfy-node-install comfyui-liveportraitkj
RUN comfy-node-install comfyui_faceanalysis

# 8.1 YOLO face detection model (FaceDetailer icin)
RUN mkdir -p /comfyui/models/ultralytics/bbox && \
    wget -q -O /comfyui/models/ultralytics/bbox/face_yolov8m.pt \
    https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt && \
    echo 'YOLO face model OK'

# =============================================================
# 9. SISTEM KODEKLERI & EKSIK FFMPEG (H264/LIBX264)
# (Cache kirilmamasi icin en sona eklendi)
# =============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg x264 libx264-dev && rm -rf /var/lib/apt/lists/*

# =============================================================
# 10. SES / VOKAL AYIRICI DUGUMLER (Audio Separator UVR)
# (Cache kirilmamasi icin en sona eklendi)
# =============================================================
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ddontsov93/ComfyUI-AudioSeparator.git && \
    cd ComfyUI-AudioSeparator && \
    pip install --no-cache-dir -r requirements.txt || true


# =============================================================
# 11. VIDEO YAZI/ALTYAZI VE TAM KONTROL (WAS Suite)
# (Cache kirilmamasi icin en sona eklendi)
# =============================================================
# WAS node suite ile resim/video uzerine yazi, altyazi ve efektler eklenebilir.
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui && \
    cd was-node-suite-comfyui && \
    pip install --no-cache-dir -r requirements.txt || true


# =============================================================
# 12. SES KLONLAMA VE DEGISTIRME (ComfyUI-RVC)
# (Cache kirilmamasi icin en sona eklendi)
# =============================================================
# Bir insanin sesini baskasinin sesiyle degistirmek (Voice Conversion)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/AIFSH/ComfyUI-RVC.git && \
    cd ComfyUI-RVC && \
    pip install --no-cache-dir -r requirements.txt || true

# =============================================================
# 13. ULTRALYTICS YOLO ÇÖZÜMÜ (Impact-Subpack)
# =============================================================
# UltralyticsDetectorProvider eklentisini getiren ana paket
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git && \
    cd ComfyUI-Impact-Subpack && \
    pip install --no-cache-dir -r requirements.txt || true

# =============================================================
# 14. EKSTRA DEV EKLENTILERI (LayerStyle, WanVideo, EasyUse, vb.)
# =============================================================
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone https://github.com/cdb-boop/ComfyUI-Bringing-Old-Photos-Back-to-Life.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone https://github.com/kijai/ComfyUI-Florence2.git && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git && \
    git clone https://github.com/cubiq/ComfyUI_InstantID.git && \
    git clone https://github.com/chflame163/ComfyUI-LayerStyle.git && \
    cd comfyui_controlnet_aux && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI-Bringing-Old-Photos-Back-to-Life && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI-Easy-Use && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI-WanVideoWrapper && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI-Florence2 && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI_InstantID && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../ComfyUI-LayerStyle && pip install --no-cache-dir -r requirements.txt || true && \
    cd ../rgthree-comfy && pip install --no-cache-dir -r requirements.txt || true

# Eksik çekirdek kütüphaneler (WanVideo ve Subpack için)
RUN pip install --no-cache-dir accelerate diffusers transformers lark

# BOPBTL (Eski Fotoğraf Restorasyon) ağırlıkları ve Yüz Kurtarma (GFPGAN) indirmeleri
RUN apt-get update && apt-get install -y wget unzip && \
    mkdir -p /comfyui/models/checkpoints /comfyui/models/vae /comfyui/models/facedetection && \
    wget -q https://github.com/microsoft/Bringing-Old-Photos-Back-to-Life/releases/download/v1.0/global_checkpoints.zip -O /tmp/global_checkpoints.zip && \
    unzip -q /tmp/global_checkpoints.zip -d /tmp/bopbtl_global && \
    mv /tmp/bopbtl_global/Global/checkpoints/restoration/VAE_A_quality/latest_net_G.pth /comfyui/models/vae/VAE_A_quality.pth && \
    mv /tmp/bopbtl_global/Global/checkpoints/restoration/VAE_B_quality/latest_net_G.pth /comfyui/models/vae/VAE_B_quality.pth && \
    mv /tmp/bopbtl_global/Global/checkpoints/restoration/mapping_quality/latest_net_mapping_net.pth /comfyui/models/checkpoints/mapping_quality.pth && \
    mv /tmp/bopbtl_global/Global/checkpoints/detection/FT_Epoch_latest.pt /comfyui/models/checkpoints/FT_Epoch_latest.pt && \
    rm -rf /tmp/global_checkpoints.zip /tmp/bopbtl_global

CMD ["/start.sh"]
