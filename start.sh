#!/bin/bash
set -e

VOLUME_PATH="/runpod-volume"
COMFY_MODELS="/comfyui/models"

echo "========================================="
echo "  Network Volume Model Linker"
echo "========================================="

# Network Volume bağlı mı kontrol et
if [ -d "$VOLUME_PATH/models" ]; then
    echo "✅ Network Volume bulundu: $VOLUME_PATH"

    # Checkpoints
    if [ -d "$VOLUME_PATH/models/checkpoints" ]; then
        for f in "$VOLUME_PATH/models/checkpoints"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/checkpoints/$(basename "$f")" && echo "  → checkpoint: $(basename "$f")"
        done
    fi

    # InsightFace (inswapper)
    if [ -d "$VOLUME_PATH/models/insightface" ]; then
        for f in "$VOLUME_PATH/models/insightface"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/insightface/$(basename "$f")" && echo "  → insightface: $(basename "$f")"
        done
    fi

    # FaceRestore models
    if [ -d "$VOLUME_PATH/models/facerestore_models" ]; then
        for f in "$VOLUME_PATH/models/facerestore_models"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/facerestore_models/$(basename "$f")" && echo "  → facerestore: $(basename "$f")"
        done
    fi

    # Upscale models
    if [ -d "$VOLUME_PATH/models/upscale_models" ]; then
        for f in "$VOLUME_PATH/models/upscale_models"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/upscale_models/$(basename "$f")" && echo "  → upscale: $(basename "$f")"
        done
    fi

    # CLIP Vision
    if [ -d "$VOLUME_PATH/models/clip_vision" ]; then
        for f in "$VOLUME_PATH/models/clip_vision"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/clip_vision/$(basename "$f")" && echo "  → clip_vision: $(basename "$f")"
        done
    fi

    # IP-Adapter
    if [ -d "$VOLUME_PATH/models/ipadapter" ]; then
        for f in "$VOLUME_PATH/models/ipadapter"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/ipadapter/$(basename "$f")" && echo "  → ipadapter: $(basename "$f")"
        done
    fi

    # ControlNet
    if [ -d "$VOLUME_PATH/models/controlnet" ]; then
        for f in "$VOLUME_PATH/models/controlnet"/*; do
            [ -e "$f" ] && ln -sf "$f" "$COMFY_MODELS/controlnet/$(basename "$f")" && echo "  → controlnet: $(basename "$f")"
        done
    fi

    echo "========================================="
    echo "✅ Tüm modeller Network Volume'dan bağlandı!"
    echo "========================================="
else
    echo "⚠️ Network Volume bulunamadı ($VOLUME_PATH)"
    echo "  Image içindeki modeller kullanılacak (varsa)"
fi

# ComfyUI'ı arka planda başlat
echo "🚀 ComfyUI başlatılıyor..."
cd /comfyui
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
COMFY_PID=$!
echo "  ComfyUI PID: $COMFY_PID"

# ComfyUI'ın ayağa kalkması için kısa bir bekleme
echo "⏳ ComfyUI'ın başlaması bekleniyor..."
sleep 5

# Handler'ı başlat (handler kendi retry mekanizmasıyla ComfyUI'ı bekleyecek)
echo "🚀 Worker handler başlatılıyor..."
exec python /handler.py
