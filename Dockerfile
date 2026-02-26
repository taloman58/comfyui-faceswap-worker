# =============================================================
# COMFYUI FULL CONTENT CREATOR - RunPod Serverless
# =============================================================
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# =============================================================
# REACT0R - ELLE KURULUM
# =============================================================

# Build araclari
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake && rm -rf /var/lib/apt/lists/*

# InsightFace (onnxruntime base image'da ZATEN var, tekrar kurma!)
RUN pip install --no-cache-dir insightface

# ReActor klonla
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Gourieff/ComfyUI-ReActor.git

# ReActor bagimliliklari (insightface zaten kurulu, tekrar kurma)
RUN cd /comfyui/custom_nodes/ComfyUI-ReActor && \
    pip install --no-cache-dir \
    albumentations>=1.4.16 \
    onnx>=1.14.0 \
    "opencv-python>=4.7.0.72" \
    segment_anything \
    ultralytics


# =============================================================
# DIGER CUSTOM NODES
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

# =============================================================
# MODELLER
# =============================================================

RUN mkdir -p /comfyui/models/insightface && \
    wget -q -O /comfyui/models/insightface/inswapper_128.onnx \
    https://github.com/facefusion/facefusion-assets/releases/download/models-3.0.0/inswapper_128.onnx

RUN mkdir -p /comfyui/models/upscale_models && \
    wget -q -O /comfyui/models/upscale_models/RealESRGAN_x4plus.pth \
    https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth && \
    wget -q -O /comfyui/models/upscale_models/4x-UltraSharp.pth \
    https://huggingface.co/Kim2091/UltraSharp/resolve/main/4x-UltraSharp.pth

RUN mkdir -p /comfyui/models/ipadapter && \
    mkdir -p /comfyui/models/clip_vision && \
    wget -q -O /comfyui/models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors && \
    wget -q -O /comfyui/models/ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors \
    https://huggingface.co/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus-face_sdxl_vit-h.safetensors
