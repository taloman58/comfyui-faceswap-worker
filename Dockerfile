# Custom ComfyUI worker: FLUX Schnell + ReActor Face Swap + Video
FROM runpod/worker-comfyui:5.7.1-flux1-schnell

# ReActor (yuz degistirme) custom node
RUN comfy-node-install comfyui-reactor-node

# Video Helper Suite (video yukleme/kaydetme)
RUN comfy-node-install comfyui-videohelpersuite

# InsightFace inswapper modeli (ReActor icin gerekli)
RUN mkdir -p /comfyui/models/insightface && \
    wget -q -O /comfyui/models/insightface/inswapper_128.onnx \
    https://github.com/facefusion/facefusion-assets/releases/download/models-3.0.0/inswapper_128.onnx
