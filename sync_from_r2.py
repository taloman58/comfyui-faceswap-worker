#!/usr/bin/env python3
"""
sync_from_r2.py — RunPod Container Startup R2 Sync

start.sh tarafından container başlarken çağrılır.
R2'den node zip'lerini ve model dosyalarını indirir.

Kullanım:
  python sync_from_r2.py --mode nodes    # sadece node'lar
  python sync_from_r2.py --mode models   # sadece modeller
  python sync_from_r2.py --mode all      # hepsi (default)
"""

import os
import sys
import zipfile
import argparse
import subprocess
import boto3

# ─── R2 Bağlantısı (RunPod env vars'tan) ─────────────────────────────────────
ENDPOINT   = os.environ.get("BUCKET_ENDPOINT_URL", "")
ACCESS_KEY = os.environ.get("BUCKET_ACCESS_KEY_ID", "")
SECRET_KEY = os.environ.get("BUCKET_SECRET_ACCESS_KEY", "")
BUCKET     = os.environ.get("BUCKET_NAME", "comfyui-models")

COMFY_DIR  = "/comfyui"
MODELS_DIR = f"{COMFY_DIR}/models"
NODES_DIR  = f"{COMFY_DIR}/custom_nodes"


def make_s3():
    return boto3.client(
        's3',
        endpoint_url=ENDPOINT,
        aws_access_key_id=ACCESS_KEY,
        aws_secret_access_key=SECRET_KEY,
        region_name='auto'
    )


# ─── Node Sync ────────────────────────────────────────────────────────────────
def sync_nodes(s3):
    print("\n━━━ 📦 NODE SYNC ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Mevcut kurulu node'lar
    existing = set()
    if os.path.isdir(NODES_DIR):
        existing = set(os.listdir(NODES_DIR))

    try:
        paginator = s3.get_paginator('list_objects_v2')
        found = 0
        for page in paginator.paginate(Bucket=BUCKET, Prefix="nodes/"):
            for obj in page.get('Contents', []):
                key = obj['Key']
                if not key.endswith('.zip'):
                    continue
                found += 1
                node_name = os.path.basename(key).replace('.zip', '')

                if node_name in existing:
                    print(f"  ⏭️  {node_name} — zaten kurulu")
                    continue

                size_mb = obj['Size'] / (1024 * 1024)
                print(f"  ⬇️  {node_name}.zip ({size_mb:.1f} MB) indiriliyor...")
                zip_path = f"/tmp/{node_name}.zip"
                s3.download_file(BUCKET, key, zip_path)

                print(f"  📂  {node_name} kuruluyor...")
                os.makedirs(NODES_DIR, exist_ok=True)
                with zipfile.ZipFile(zip_path, 'r') as zf:
                    zf.extractall(NODES_DIR)
                os.remove(zip_path)

                # requirements.txt varsa kur
                req = os.path.join(NODES_DIR, node_name, 'requirements.txt')
                if os.path.exists(req):
                    print(f"  📦  requirements.txt yükleniyor...")
                    subprocess.run(
                        [sys.executable, '-m', 'pip', 'install', '-r', req, '-q', '--no-cache-dir'],
                        check=False
                    )

                print(f"  ✅  {node_name} kuruldu!")

        if found == 0:
            print("  ℹ️  R2'de nodes/ klasöründe zip bulunamadı.")

    except Exception as e:
        print(f"  ❌ Node sync hatası: {e}")


# ─── Node İçi Model Sync ──────────────────────────────────────────────────────
def sync_node_models(s3):
    print("\n━━━ 🔌 NODE MODEL SYNC ━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    try:
        paginator = s3.get_paginator('list_objects_v2')
        found = 0
        for page in paginator.paginate(Bucket=BUCKET, Prefix="custom_nodes/"):
            for obj in page.get('Contents', []):
                key   = obj['Key']   # custom_nodes/ComfyUI-ReActor/models/inswapper.onnx
                rel   = key[len("custom_nodes/"):]
                local = os.path.join(NODES_DIR, rel)

                os.makedirs(os.path.dirname(local), exist_ok=True)
                found += 1

                if os.path.exists(local) and os.path.getsize(local) == obj['Size']:
                    print(f"  ⏭️  {rel} — mevcut")
                    continue

                size_mb = obj['Size'] / (1024 * 1024)
                print(f"  ⬇️  {rel} ({size_mb:.0f} MB)...")
                s3.download_file(BUCKET, key, local)
                print(f"  ✅  {os.path.basename(local)}")

        if found == 0:
            print("  ℹ️  R2'de custom_nodes/ modeli bulunamadı.")

    except Exception as e:
        print(f"  ❌ Node model sync hatası: {e}")


# ─── Model Sync ───────────────────────────────────────────────────────────────
def sync_models(s3):
    print("\n━━━ 🧠 MODEL SYNC ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    try:
        paginator = s3.get_paginator('list_objects_v2')
        found = 0
        for page in paginator.paginate(Bucket=BUCKET, Prefix="models/"):
            for obj in page.get('Contents', []):
                key   = obj['Key']                     # models/checkpoints/model.safetensors
                rel   = key[len("models/"):]           # checkpoints/model.safetensors
                local = os.path.join(MODELS_DIR, rel)

                os.makedirs(os.path.dirname(local), exist_ok=True)
                found += 1

                # Boyut eşleşiyorsa atla
                if os.path.exists(local) and os.path.getsize(local) == obj['Size']:
                    print(f"  ⏭️  {rel} — mevcut")
                    continue

                size_mb = obj['Size'] / (1024 * 1024)
                print(f"  ⬇️  {rel} ({size_mb:.0f} MB)...")
                s3.download_file(BUCKET, key, local)
                print(f"  ✅  {os.path.basename(local)}")

        if found == 0:
            print("  ℹ️  R2'de models/ klasöründe dosya bulunamadı.")

    except Exception as e:
        print(f"  ❌ Model sync hatası: {e}")


# ─── Ana Fonksiyon ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="R2'den ComfyUI dosyalarını senkronize eder")
    parser.add_argument('--mode', choices=['nodes', 'models', 'all'], default='all',
                        help='Hangi bölüm senkronize edilecek (default: all)')
    args = parser.parse_args()

    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  🚀 sync_from_r2.py — R2 Senkronizasyon Başlıyor")
    print(f"  Mod: {args.mode}  |  Bucket: {BUCKET}")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if not ENDPOINT or not ACCESS_KEY or not SECRET_KEY:
        print("⚠️  R2 env vars eksik! Senkronizasyon atlanıyor.")
        print("   Gerekli: BUCKET_ENDPOINT_URL, BUCKET_ACCESS_KEY_ID, BUCKET_SECRET_ACCESS_KEY")
        sys.exit(0)   # crash değil, sessizce geç

    s3 = make_s3()

    if args.mode in ('nodes', 'all'):
        sync_nodes(s3)
        sync_node_models(s3)

    if args.mode in ('models', 'all'):
        sync_models(s3)

    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("  ✅ R2 senkronizasyonu tamamlandı!")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")


if __name__ == '__main__':
    main()
