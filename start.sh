#!/bin/bash
set -e

# ─── Değişkenler ──────────────────────────────────────────────────────────────
COMFY_DIR="/comfyui"
COMFY_MODELS="$COMFY_DIR/models"
CUSTOM_NODES="$COMFY_DIR/custom_nodes"
R2_SYNC_SCRIPT="/sync_from_r2.py"

echo "========================================="
echo "  🚀 ComfyUI Worker Başlatılıyor"
echo "  R2 Stateless Modeli"
echo "========================================="

# ─── 1. R2'den NODE'ları çek ve kur ──────────────────────────────────────────
echo ""
echo "📦 ADIM 1: R2'den Custom Node'lar indiriliyor..."
if [ -f "$R2_SYNC_SCRIPT" ]; then
    python "$R2_SYNC_SCRIPT" --mode nodes
else
    echo "  ⚠️ sync_from_r2.py bulunamadı, node kurulum atlanıyor."
fi

# ─── 2. R2'den MODELleri çek ──────────────────────────────────────────────────
echo ""
echo "🧠 ADIM 2: R2'den Modeller senkronize ediliyor..."
if [ -f "$R2_SYNC_SCRIPT" ]; then
    python "$R2_SYNC_SCRIPT" --mode models
else
    echo "  ⚠️ sync_from_r2.py bulunamadı, model senkronizasyon atlanıyor."
fi

echo ""
echo "========================================="
echo "✅ R2 senkronizasyonu tamamlandı!"
echo "========================================="

# ─── 3. ComfyUI'ı başlat ──────────────────────────────────────────────────────
echo ""
echo "🚀 ComfyUI başlatılıyor..."
cd "$COMFY_DIR"
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
COMFY_PID=$!
echo "  ComfyUI PID: $COMFY_PID"

# ─── 4. Handler'ı başlat ──────────────────────────────────────────────────────
echo ""
echo "⏳ ComfyUI'ın başlaması bekleniyor..."
sleep 6

echo "🚀 Worker handler başlatılıyor..."
exec python /handler.py
