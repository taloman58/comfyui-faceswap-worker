# =============================================================
# COMFYUI FULL CONTENT CREATOR - RunPod Serverless
# "Total Football" - Her şey dahil, tek seferde
# =============================================================
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# Base image icerigi:
#   - FLUX.1 Schnell checkpoint
#   - FLUX text encoders (clip_l, t5xxl_fp8)
#   - FLUX VAE (ae.safetensors)
#   - ComfyUI + onnxruntime

# =============================================================
# 1. SYSTEM DEPENDENCIES
# =============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake python3-dev && rm -rf /var/lib/apt/lists/*

# =============================================================
# 2. REACTOR (FACE SWAP) - Elle kurulum
# =============================================================

# InsightFace
RUN pip install --no-cache-dir insightface==0.7.3

# ReActor klonla
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Gourieff/ComfyUI-ReActor.git

# ReActor - TUM bagimliliklari requirements.txt'den kur
# (eksik paket olursa ComfyUI node'u tamamen atlar!)
RUN cd /comfyui/custom_nodes/ComfyUI-ReActor && \
    pip install --no-cache-dir -r requirements.txt

# torchvision - ReActor icin gerekli, base image'da olmayabilir
RUN pip install --no-cache-dir torchvision --extra-index-url https://download.pytorch.org/whl/cu121

# =============================================================
# 3. CUSTOM NODES
# =============================================================

# IP-Adapter: Stil/kiyafet/yuz transferi
RUN comfy-node-install comfyui_ipadapter_plus

# Video islemleri
RUN comfy-node-install comfyui-videohelpersuite

# Video animasyon
RUN comfy-node-install comfyui-animatediff-evolved
RUN comfy-node-install comfyui-frame-interpolation

# Upscale
RUN comfy-node-install comfyui_ultimatesdupscale

# Segmentation + maskeleme (SAM dahil)
RUN comfy-node-install comfyui-impact-pack

# ControlNet (poz/derinlik/kenar koruma)
RUN comfy-node-install comfyui-advanced-controlnet

# Yardimci node'lar
RUN comfy-node-install comfyui-kjnodes
RUN comfy-node-install comfyui_essentials
RUN comfy-node-install was-node-suite-comfyui

# =============================================================
# 4. MODEL: Face Swap (inswapper)
# =============================================================
RUN mkdir -p /comfyui/models/insightface && \
    wget -q -O /comfyui/models/insightface/inswapper_128.onnx \
    "https://github.com/facefusion/facefusion-assets/releases/download/models-3.0.0/inswapper_128.onnx"

# =============================================================
# 5. MODEL: Face Restore (CodeFormer + GFPGAN)
#    ReActor Face Boost ve genel yuz kalitesi icin
# =============================================================
RUN mkdir -p /comfyui/models/facerestore_models && \
    wget -q -O /comfyui/models/facerestore_models/codeformer-v0.1.0.pth \
    "https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer.pth" && \
    wget -q -O /comfyui/models/facerestore_models/GFPGANv1.4.pth \
    "https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth"

# =============================================================
# 6. MODEL: Upscale (4x buyutme)
# =============================================================
RUN mkdir -p /comfyui/models/upscale_models && \
    wget -q -O /comfyui/models/upscale_models/RealESRGAN_x4plus.pth \
    "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth" && \
    wget -q -O /comfyui/models/upscale_models/4x-UltraSharp.pth \
    "https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth"

# =============================================================
# 7. MODEL: CLIP Vision (IP-Adapter encoder)
#    ~2.5GB - IP-Adapter icin zorunlu
# =============================================================
RUN mkdir -p /comfyui/models/clip_vision && \
    wget -q -O /comfyui/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors"

# =============================================================
# 8. MODEL: IP-Adapter (SDXL)
#    Face versiyonu: yuz stili transferi
#    Plus versiyonu: genel stil/kiyafet transferi
# =============================================================
RUN mkdir -p /comfyui/models/ipadapter && \
    wget -q -O /comfyui/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors" && \
    wget -q -O /comfyui/models/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors \
    "https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors"

# =============================================================
# 9. MODEL: SDXL Base 1.0 Checkpoint (~6.5GB)
#    IP-Adapter + ControlNet workflow'lari icin gerekli
#    (FLUX hizli uretim icin, SDXL kontrollü uretim icin)
# =============================================================
RUN wget -q -O /comfyui/models/checkpoints/sd_xl_base_1.0.safetensors \
    "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"

# =============================================================
# 10. MODEL: ControlNet SDXL (kenar + derinlik kontrolu)
#     Canny: kenar koruma - kiyafet seklini korur
#     Depth: derinlik koruma - vucut pozisyonunu korur
# =============================================================
RUN mkdir -p /comfyui/models/controlnet && \
    wget -q -O /comfyui/models/controlnet/diffusers_xl_canny_mid.safetensors \
    "https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/diffusers_xl_canny_mid.safetensors" && \
    wget -q -O /comfyui/models/controlnet/diffusers_xl_depth_mid.safetensors \
    "https://huggingface.co/lllyasviel/sd_control_collection/resolve/main/diffusers_xl_depth_mid.safetensors"
# ------------------------------------------------------------
# Future model additions can be appended below this line

# FIX: onnxruntime pip install sirasinda silinmis, ReActor icin zorunlu
RUN pip install --no-cache-dir onnxruntime-gpu
