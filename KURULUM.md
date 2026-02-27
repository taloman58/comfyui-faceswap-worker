# 🚀 Tam Kurulum Rehberi — ComfyUI FaceSwap Worker

> **Yama yok. Geçici çözüm yok. Her şey dahil, profesyonel kurulum.**

---

## 🏗️ Ne Kuruyoruz?

GPU'suz Windows PC'den RunPod Serverless üzerinde ComfyUI çalıştıran tam donanımlı sistem.

```
Lokal PC (GPU yok)                    RunPod Serverless (24GB+ GPU)
┌─────────────────────┐               ┌──────────────────────────────┐
│ ComfyUI (tasarım)   │   API ile     │ Docker Image                 │
│ RunPodSender Node   │ ───────────►  │ ├── ReActor (face swap)      │
│ Workflow tasarla    │               │ ├── IP-Adapter (stil)         │
│ Sonucu al           │ ◄───────────  │ ├── AnimateDiff (video)       │
└─────────────────────┘   Otomatik    │ ├── ControlNet (kontrol)      │
                                      │ ├── Tüm modeller (~35GB)      │
                                      └──────────────────────────────┘
```

---

## 📦 Docker Image İçeriği (Tam Liste)

### Base Image

`runpod/worker-comfyui:5.7.1-flux1-schnell`

İçerir:

- FLUX.1 Schnell checkpoint (~12GB)
- FLUX text encoders (clip_l, t5xxl_fp8)
- FLUX VAE (ae.safetensors)
- ComfyUI + onnxruntime

### System Packages

- `build-essential` — C/C++ derleme araçları
- `cmake` — CMake build sistemi
- `python3-dev` — Python C extension desteği (insightface için zorunlu)

### Custom Nodes (11 adet)

| #   | Node                    | Paket                            | Ne İçin                             |
| --- | ----------------------- | -------------------------------- | ----------------------------------- |
| 1   | **ReActor**             | `git clone` + `requirements.txt` | Video/resim yüz değiştirme          |
| 2   | **IP-Adapter Plus**     | `comfyui_ipadapter_plus`         | Stil/kıyafet/yüz referans transferi |
| 3   | **Video Helper Suite**  | `comfyui-videohelpersuite`       | Video yükleme/kaydetme (ffmpeg)     |
| 4   | **AnimateDiff Evolved** | `comfyui-animatediff-evolved`    | Video animasyon üretimi             |
| 5   | **Frame Interpolation** | `comfyui-frame-interpolation`    | Akıcı kare arası geçiş              |
| 6   | **Ultimate SD Upscale** | `comfyui_ultimatesdupscale`      | Akıllı 4x büyütme                   |
| 7   | **Impact Pack**         | `comfyui-impact-pack`            | SAM segmentasyon + maskeleme        |
| 8   | **Advanced ControlNet** | `comfyui-advanced-controlnet`    | Poz/kenar/derinlik kontrolü         |
| 9   | **KJNodes**             | `comfyui-kjnodes`                | Batch işleme, yardımcı araçlar      |
| 10  | **Essentials**          | `comfyui_essentials`             | Temel işlem araçları                |
| 11  | **WAS Node Suite**      | `was-node-suite-comfyui`         | Görüntü işleme, filtreler, yazı     |

### Python Paketleri (ReActor için)

- `insightface==0.7.3` — Yüz analizi motoru (C++ ile derlenir)
- `torchvision` — Görüntü işleme (CUDA 12.1)
- ReActor `requirements.txt` → kornia, facexlib, basicsr, gfpgan dahil

### Modeller (Toplam ~35GB)

| Model                     | Boyut  | Klasör                       | Kullanım                         |
| ------------------------- | ------ | ---------------------------- | -------------------------------- |
| FLUX.1 Schnell            | ~12GB  | `models/unet/`               | Hızlı resim üretimi              |
| SDXL Base 1.0             | ~6.5GB | `models/checkpoints/`        | IP-Adapter/ControlNet ile üretim |
| inswapper_128.onnx        | ~530MB | `models/insightface/`        | Yüz değiştirme motoru            |
| codeformer-v0.1.0.pth     | ~375MB | `models/facerestore_models/` | Yüz kalite artırma               |
| GFPGANv1.4.pth            | ~332MB | `models/facerestore_models/` | Yüz restorasyonu                 |
| RealESRGAN_x4plus.pth     | ~64MB  | `models/upscale_models/`     | 4x büyütme                       |
| 4x-UltraSharp.pth         | ~64MB  | `models/upscale_models/`     | 4x keskin büyütme                |
| CLIP-ViT-H-14             | ~2.4GB | `models/clip_vision/`        | IP-Adapter görsel encoder        |
| ip-adapter-plus-face_sdxl | ~808MB | `models/ipadapter/`          | Yüz stili transferi              |
| ip-adapter-plus_sdxl      | ~808MB | `models/ipadapter/`          | Genel stil/kıyafet transferi     |
| ControlNet Canny          | ~520MB | `models/controlnet/`         | Kenar koruma                     |
| ControlNet Depth          | ~520MB | `models/controlnet/`         | Derinlik/poz koruma              |

---

## 🔧 Kurulum Adımları

### Ön Gereksinimler

- Windows 10/11 (GPU gerekmez)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) — Veri dizini büyük bir diske taşınmalı (D: gibi)
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) — Lokal kurulum
- RunPod hesabı (~$15 kredi)
- GitHub hesabı

### Adım 1 — Docker Veri Dizini Ayarla

Docker Desktop → Settings → Resources → Disk image location → `D:\DockerData`

### Adım 2 — Base Image İndir (Bir kere, ~32GB)

```powershell
$env:PATH += ";C:\Program Files\Docker\Docker\resources\bin"
docker pull runpod/worker-comfyui:5.7.1-flux1-schnell
```

### Adım 3 — Image Build Et

```powershell
docker build -t ghcr.io/taloman58/comfyui-faceswap-worker:latest "C:\Users\tlh\Desktop\comfyui-faceswap-worker"
```

> İlk build: ~45-60 dakika (modeller indirilir)  
> Sonraki build'ler: ~5-10 dakika (sadece değişen satırlar)

### Adım 4 — GHCR'ye Push Et

```powershell
# GitHub token: github.com/settings/tokens → write:packages izni
echo GITHUB_TOKEN | docker login ghcr.io -u taloman58 --password-stdin
docker push ghcr.io/taloman58/comfyui-faceswap-worker:latest
```

> Push sırasında `broken pipe` → tekrar çalıştır, kaldığı yerden devam eder  
> `Layer already exists` → normal, base image katmanları zaten orada

### Adım 5 — GHCR'yi Public Yap

GitHub → Packages → `comfyui-faceswap-worker` → Package settings → Change visibility → **Public**  
(RunPod private image çekemez)

### Adım 6 — RunPod Endpoint Oluştur

1. **My Templates → New Template:**
   - Name: `comfyui-full-creator`
   - Type: `Serverless`
   - Image: `ghcr.io/taloman58/comfyui-faceswap-worker:latest`
   - Container Disk: `50 GB`

2. **Serverless → New Endpoint:**
   - Template: `comfyui-full-creator`
   - GPU: 24GB+ (RTX 4090 / A5000 / L40S)
   - **Active Workers: `0`** ← kullanmayınca $0
   - Max Workers: `1`
   - Flash Boot: enabled

### Adım 7 — Lokal ComfyUI Ayarla

```powershell
cd D:\ComfyUI_windows_portable\ComfyUI\custom_nodes\

# ReActor (lokal önizleme için)
git clone https://github.com/Gourieff/ComfyUI-ReActor.git

# Video Helper Suite
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# ffmpeg (video işleme)
D:\ComfyUI_windows_portable\python_embeded\python.exe -m pip install imageio-ffmpeg
```

`ComfyUI-RunPod-Worker` node'u → `nodes.py` + `__init__.py` dosyalarını ekle.

---

## 🎬 Workflow Kullanımı

### Senaryo 1 — Yüz Değiştirme (Video)

```
VHS_LoadVideo → ReActorFaceSwap → VHS_VideoCombine + SaveImage → RunPodSender
```

- `input/input_video.mp4` → hedef video
- `input/source_face.jpg` → kaynak yüz
- ReActor Face Boost: ON → CodeFormer ile kalite artır

### Senaryo 2 — Stil/Kıyafet Değiştirme (IP-Adapter)

```
LoadImage → ControlNet(Depth) + IP-Adapter(Style Ref) → KSampler(SDXL) → SaveImage
```

### Senaryo 3 — FLUX Hızlı Resim Üretimi

```
UNETLoader(flux1-schnell) → CLIPTextEncode → KSampler(euler, 4step, cfg 1.0) → VAEDecode → SaveImage
```

### Senaryo 4 — Video Animasyon (AnimateDiff)

```
LoadImage → AnimateDiff → VHS_VideoCombine → RunPodSender
```

### RunPodSender Node Ayarları

| Parametre     | Değer                                |
| ------------- | ------------------------------------ |
| api_key       | RunPod API Key (Settings → API Keys) |
| endpoint_id   | Endpoint ID (örn: `wheryrlbvhl8u6`)  |
| mode          | `async (run)`                        |
| poll_interval | `5`                                  |
| timeout       | `600`                                |

---

## 🔄 Güncelleme (Node veya Model Ekleme)

> **Kural:** Yeni şeyleri her zaman Dockerfile'ın **SONUNA** ekle!  
> Ortaya eklersen o satırdan sonraki TÜM katmanlar yeniden yapılır.

### Yeni Node Ekle

```dockerfile
# Dockerfile'ın SONUNA:
RUN comfy-node-install yeni-node-adi
```

### Yeni Model Ekle

```dockerfile
# Dockerfile'ın SONUNA:
RUN mkdir -p /comfyui/models/KLASOR && \
    wget -q -O /comfyui/models/KLASOR/model.safetensors \
    "https://huggingface.co/KULLANICI/REPO/resolve/main/model.safetensors"
```

### Build → Push → Deploy

```powershell
# 1. Build (sadece değişen satırlar işlenir, ~5-10 dk)
docker build -t ghcr.io/taloman58/comfyui-faceswap-worker:latest "C:\Users\tlh\Desktop\comfyui-faceswap-worker"

# 2. Push (sadece yeni katman yüklenir)
docker push ghcr.io/taloman58/comfyui-faceswap-worker:latest

# 3. RunPod → Endpoint → Manage → New Release → Deploy
```

### Model Klasör Rehberi

| Model Tipi        | Klasör                                |
| ----------------- | ------------------------------------- |
| Checkpoint / UNET | `/comfyui/models/checkpoints/`        |
| LoRA              | `/comfyui/models/loras/`              |
| VAE               | `/comfyui/models/vae/`                |
| ControlNet        | `/comfyui/models/controlnet/`         |
| Upscale           | `/comfyui/models/upscale_models/`     |
| Face Swap         | `/comfyui/models/insightface/`        |
| Face Restore      | `/comfyui/models/facerestore_models/` |
| IP-Adapter        | `/comfyui/models/ipadapter/`          |
| CLIP Vision       | `/comfyui/models/clip_vision/`        |
| AnimateDiff       | `/comfyui/models/animatediff_models/` |

---

## 💰 Maliyet

| Durum                        | Maliyet     |
| ---------------------------- | ----------- |
| Boşta (Active Workers = 0)   | **$0.00**   |
| 1 face swap (~10 sn GPU)     | ~$0.005     |
| 1 resim üretimi (~30 sn GPU) | ~$0.01–0.02 |
| 1 dk video face swap         | ~$0.05–0.10 |
| GHCR + GitHub (public)       | **$0.00**   |
| Lokal Docker build           | **$0.00**   |

> ⚠️ **Active Workers = 0 olmalı!** 1 yaparsan 7/24 para keser (~$5–12/gün)

---

## 🐛 Sorun Giderme

| Sorun                            | Çözüm                                                        |
| -------------------------------- | ------------------------------------------------------------ |
| `ReActorFaceSwap does not exist` | RunPod → Endpoint → Manage → New Release → Deploy            |
| `No valid ffmpeg found` (lokal)  | `pip install imageio-ffmpeg` + ComfyUI yeniden başlat        |
| `buffalo_l` eksik                | ReActor ilk çalışmada otomatik indirir — normal              |
| Push `broken pipe`               | Tekrar `docker push` → kaldığı yerden devam eder             |
| `Layer already exists`           | Normal — base image zaten GHCR'de                            |
| `manifest unknown` RunPod'da     | GHCR package'ı Public yap                                    |
| Build çok uzun sürüyor           | Önce `docker pull runpod/worker-comfyui:5.7.1-flux1-schnell` |
| `Python.h: No such file`         | `python3-dev` apt paketini ekle (Dockerfile'da zaten var)    |

---

## 🔗 Önemli Linkler

| Kaynak               | Link                                                                                        |
| -------------------- | ------------------------------------------------------------------------------------------- |
| GitHub Repo          | https://github.com/taloman58/comfyui-faceswap-worker                                        |
| Docker Image (GHCR)  | https://github.com/taloman58/comfyui-faceswap-worker/pkgs/container/comfyui-faceswap-worker |
| RunPod Dashboard     | https://www.runpod.io/console/serverless                                                    |
| GitHub Token Oluştur | https://github.com/settings/tokens                                                          |
| ReActor Repo         | https://github.com/Gourieff/ComfyUI-ReActor                                                 |
