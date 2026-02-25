# =============================================================
# COMFYUI FULL CONTENT CREATOR - RunPod Serverless
# Instagram icin: resim, video, face swap, upscale, yazi, animasyon
# =============================================================
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# =============================================================
# CUSTOM NODES
# =============================================================

# --- YUZ DEGISTIRME ---
# ReActor: Gercek yuz swap - ELLE KURULUM (comfy-node-install calismadi)
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Gourieff/ComfyUI-ReActor.git && \
    cd ComfyUI-ReActor && \
    pip install -r requirements.txt && \
    pip install insightface onnxruntime-gpu

# IPAdapter Plus: Yuz tutarliligi, stil transferi, referans yuz
RUN comfy-node-install comfyui_ipadapter_plus

# --- VIDEO ---
# Video Helper Suite: Video yukleme, kaydetme, frame isleme
RUN comfy-node-install comfyui-videohelpersuite

# AnimateDiff: Metinden video uretme, resmi animate etme
RUN comfy-node-install comfyui-animatediff-evolved

# Frame Interpolation: Video'yu akici yapma (frame arasi dolgu)
RUN comfy-node-install comfyui-frame-interpolation

# --- UPSCALE (BUYUTME) ---
# Ultimate SD Upscale: Buyuk resimleri parcalayarak upscale
RUN comfy-node-install comfyui_ultimatesdupscale

# --- KONTROL ---
# Impact Pack: Yuz algilama, segmentasyon, detay iyilestirme
RUN comfy-node-install comfyui-impact-pack

# Advanced ControlNet: Poz, kenar, derinlik kontrolu
RUN comfy-node-install comfyui-advanced-controlnet

# --- YARDIMCI ARACLAR ---
# KJ Nodes: Batch isleme, text overlay, utilityler
RUN comfy-node-install comfyui-kjnodes

# Essentials: Temel islem araclari
RUN comfy-node-install comfyui_essentials

# WAS Node Suite: Yazi ekleme, resim manipulasyonu, filtreler
RUN comfy-node-install was-node-suite-comfyui

# =============================================================
# MODELLER
# =============================================================

# --- Face Swap Modeli ---
RUN mkdir -p /comfyui/models/insightface && \
    wget -q -O /comfyui/models/insightface/inswapper_128.onnx \
    https://github.com/facefusion/facefusion-assets/releases/download/models-3.0.0/inswapper_128.onnx

# --- Upscale Modelleri ---
RUN mkdir -p /comfyui/models/upscale_models && \
    wget -q -O /comfyui/models/upscale_models/RealESRGAN_x4plus.pth \
    https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth && \
    wget -q -O /comfyui/models/upscale_models/4x-UltraSharp.pth \
    https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth

# --- IPAdapter Modelleri ---
RUN mkdir -p /comfyui/models/ipadapter && \
    mkdir -p /comfyui/models/clip_vision && \
    wget -q -O /comfyui/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors && \
    wget -q -O /comfyui/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors

# --- AnimateDiff Modeli ---
# Not: AnimateDiff node kurulu, model gerektiginde ayrica eklenebilir
