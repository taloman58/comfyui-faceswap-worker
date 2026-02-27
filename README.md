<<<<<<< HEAD
# 🎬 ComfyUI FaceSwap Worker — RunPod Serverless

> **Run GPU-heavy ComfyUI workflows from any PC (no GPU needed) using RunPod Serverless.**  
> Face swap, style transfer, video processing — fully automated via API.

[![Docker Image](https://img.shields.io/badge/GHCR-ghcr.io%2Ftaloman58%2Fcomfyui--faceswap--worker-blue?logo=docker)](https://github.com/taloman58/comfyui-faceswap-worker/pkgs/container/comfyui-faceswap-worker)
[![Base Image](https://img.shields.io/badge/Base-runpod%2Fworker--comfyui%3A5.7.1--flux1--schnell-orange)](https://hub.docker.com/r/runpod/worker-comfyui)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 🌍 Language / Dil

- [🇬🇧 English](#-what-is-this) — Full documentation in English
- [🇹🇷 Türkçe](#-bu-nedir) — Tam Türkçe dokümantasyon

---

## 🇬🇧 English

### 🤔 What is This?

This project lets you run **ComfyUI workflows on a powerful cloud GPU** (via RunPod Serverless) **from any computer** — even a low-end laptop with no GPU.

You design your workflow on your local ComfyUI, add the **RunPodSender** custom node, press Queue — and the work happens on RunPod's GPU in the cloud. Results are automatically downloaded to your Desktop.

**Architecture:**

```
┌─────────────────────────┐        ┌──────────────────────────────┐
│  Your Local PC          │  API   │  RunPod Serverless Worker    │
│  (No GPU needed)        │──────► │  (24GB+ GPU)                 │
│                         │        │                              │
│  • ComfyUI installed    │        │  • This Docker image         │
│  • Design workflows     │        │  • ComfyUI + all models      │
│  • RunPodSender node    │◄───────│  • Returns results via API   │
│  • Results on Desktop   │ Result │                              │
└─────────────────────────┘        └──────────────────────────────┘
```

### ✨ What Can You Do?

| Workflow                       | Use Case                                        |
| ------------------------------ | ----------------------------------------------- |
| 🎭 **Face Swap (Video)**       | Swap any face in a video with ReActor           |
| 🎨 **Style Transfer (SDXL)**   | Change clothing/style with IP-Adapter           |
| 🖼️ **Image Generation (FLUX)** | Ultra-fast image generation with FLUX.1 Schnell |
| 📐 **Upscaling**               | 4x upscale with RealESRGAN or UltraSharp        |
| 🎬 **Video Animation**         | Create video animations with AnimateDiff        |

### 📦 What's Inside the Docker Image?

**Base:** `runpod/worker-comfyui:5.7.1-flux1-schnell`

#### Custom Nodes (11 total)

| Node                    | Purpose                                    |
| ----------------------- | ------------------------------------------ |
| **ReActor**             | Face swap for images and videos            |
| **IP-Adapter Plus**     | Style / clothing / face reference transfer |
| **Video Helper Suite**  | Load and save videos (with ffmpeg)         |
| **AnimateDiff Evolved** | Video animation generation                 |
| **Frame Interpolation** | Smooth frame-to-frame transitions          |
| **Ultimate SD Upscale** | Smart 4x upscaling                         |
| **Impact Pack**         | SAM segmentation + masking                 |
| **Advanced ControlNet** | Pose / edge / depth control                |
| **KJNodes**             | Batch processing, utility tools            |
| **Essentials**          | Core processing tools                      |
| **WAS Node Suite**      | Image processing, filters, text            |

#### Pre-downloaded Models (~35GB total)

| Model                  | Size   | Purpose                                            |
| ---------------------- | ------ | -------------------------------------------------- |
| FLUX.1 Schnell         | ~12GB  | Ultra-fast image generation                        |
| SDXL Base 1.0          | ~6.5GB | Controlled generation with IP-Adapter / ControlNet |
| inswapper_128.onnx     | ~530MB | Face swap engine                                   |
| CodeFormer             | ~375MB | Face quality enhancement                           |
| GFPGANv1.4             | ~332MB | Face restoration                                   |
| RealESRGAN x4+         | ~64MB  | 4x upscaling                                       |
| 4x-UltraSharp          | ~64MB  | 4x sharp upscaling                                 |
| CLIP Vision (ViT-H-14) | ~2.4GB | IP-Adapter image encoder                           |
| IP-Adapter Plus Face   | ~808MB | Face style transfer                                |
| IP-Adapter Plus        | ~808MB | Style / clothing transfer                          |
| ControlNet Canny       | ~520MB | Edge preservation                                  |
| ControlNet Depth       | ~520MB | Depth / pose preservation                          |

---

### 🚀 Setup from Scratch

#### Prerequisites

- Any Windows/Mac/Linux PC (no GPU needed for the local side)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) installed locally
- [RunPod account](https://runpod.io) (~$15 credit is plenty)
- [GitHub account](https://github.com)

---

#### Step 1 — Clone This Repo

```bash
git clone https://github.com/taloman58/comfyui-faceswap-worker.git
cd comfyui-faceswap-worker
```

---

#### Step 2 — Build the Docker Image Locally

> ⚠️ The base image is ~32GB. First pull takes a long time on a slow connection.

```powershell
# Pull the base image once (saves to your local Docker cache)
docker pull runpod/worker-comfyui:5.7.1-flux1-schnell

# Build your image (first time: 30-60 min for model downloads)
docker build -t ghcr.io/YOUR_GITHUB_USERNAME/comfyui-faceswap-worker:latest .
```

> 💡 After the first build, subsequent builds only reprocess changed layers — takes 2-3 minutes only!

---

#### Step 3 — Push to GitHub Container Registry (GHCR)

```bash
# Create a GitHub Personal Access Token:
# github.com/settings/tokens → New classic token → check: write:packages, read:packages

echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
docker push ghcr.io/YOUR_GITHUB_USERNAME/comfyui-faceswap-worker:latest
```

> ⚠️ **Make the image public:** Go to `github.com/YOUR_USERNAME` → Packages → Select the package → Package settings → Change visibility → **Public**  
> RunPod cannot pull private images without extra authentication.

---

#### Step 4 — Create RunPod Endpoint

1. **RunPod → My Templates → New Template:**
   - Template Name: `comfyui-faceswap-worker`
   - Template Type: `Serverless`
   - Container Image: `ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest`
   - Container Disk: `50 GB`

2. **RunPod → Serverless → New Endpoint:**
   - Template: select the one you just created
   - GPU: `24 GB+` (RTX 4090, A5000, L40S)
   - Active Workers: `0` ← **IMPORTANT: keeps cost at $0 when idle**
   - Max Workers: `1`
   - Flash Boot: `enabled`

3. Copy your **Endpoint ID** (looks like `wheryrlbvhl8u6`)

---

#### Step 5 — Set Up Local ComfyUI

Install the required custom nodes in your local ComfyUI:

```bash
cd /path/to/ComfyUI/custom_nodes/

# ReActor (for local preview/design)
git clone https://github.com/Gourieff/ComfyUI-ReActor.git

# Video Helper Suite
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# ffmpeg support (for video)
pip install imageio-ffmpeg
```

**Install the RunPodSender node** (from this repo):

```bash
# Copy the custom_nodes/ComfyUI-RunPod-Worker folder to your ComfyUI custom_nodes directory
```

Then restart ComfyUI. You'll see a new **"RunPod'a Gonder"** node in the `RunPod` category.

---

#### Step 6 — Load the Workflow and Run

1. Open ComfyUI
2. Load `workflows/faceswap.json` (from this repo)
3. Upload your **source face** image as `source_face.jpg` in the ComfyUI input folder
4. Upload your **target video** as `input_video.mp4` in the ComfyUI input folder
5. Set your RunPod **API Key** and **Endpoint ID** in the RunPodSender node
6. Click **Queue Prompt**

Results appear automatically in `Desktop/RunPod/` folder!

---

### 🔄 Adding New Nodes or Models (Fast!)

Thanks to Docker layer cache, updates only take **2-3 minutes** after the first build.

> ⚠️ **Always add new things at the BOTTOM of the Dockerfile!** Adding in the middle invalidates all layers below it.

**Add a new ComfyUI node:**

```dockerfile
# At the bottom of Dockerfile
RUN comfy-node-install new-node-name
```

**Add a new model:**

```dockerfile
# At the bottom of Dockerfile
RUN wget -q -O /comfyui/models/FOLDER/model.safetensors \
    "https://huggingface.co/EXAMPLE/resolve/main/model.safetensors"
```

**Then rebuild and push:**

```powershell
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
# RunPod: Endpoint → Manage → New Release → Deploy
```

---

### 💰 Cost Estimates

| Situation                     | Cost        |
| ----------------------------- | ----------- |
| Idle (Active Workers = 0)     | **$0.00**   |
| 1 face swap (~10s GPU)        | ~$0.005     |
| 1 image generation (~30s GPU) | ~$0.01–0.02 |
| 1 min video face swap         | ~$0.05–0.10 |
| GHCR + GitHub (public)        | **$0.00**   |
| Local Docker build            | **$0.00**   |

> ⚠️ **Keep Active Workers at 0!** Setting it to 1 means the worker runs 24/7, costing ~$5–12/day.

---

### 🐛 Troubleshooting

| Problem                            | Solution                                                          |
| ---------------------------------- | ----------------------------------------------------------------- |
| `node XYZ does not exist`          | Force update on RunPod: Endpoint → Manage → New Release → Deploy  |
| `No valid ffmpeg found` (local)    | Run `pip install imageio-ffmpeg` then restart ComfyUI             |
| `buffalo_l` model missing          | ReActor downloads it automatically on first run — normal behavior |
| `broken pipe` during push          | Re-run `docker push`, it resumes from where it stopped            |
| `Layer already exists` during push | Normal! Base image layers are already on GHCR                     |
| `manifest unknown` on RunPod       | Make the GHCR image **Public**                                    |
| First build takes forever          | First run `docker pull runpod/worker-comfyui:5.7.1-flux1-schnell` |

---

### 📁 Model Folder Reference

| Type              | Path in Container                     |
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

## 🇹🇷 Türkçe

### 🤔 Bu Nedir?

Bu proje, **GPU'suz bir bilgisayardan** (dizüstü, ofis PC, fark etmez) **RunPod Serverless** üzerindeki güçlü cloud GPU'lara ComfyUI workflow'u göndermenizi sağlar.

Lokal ComfyUI'de workflow tasarlıyorsunuz, **RunPodSender** node'unu ekliyorsunuz, Queue'ya basıyorsunuz — işlem buluttaki GPU'da yapılıyor, sonuçlar otomatik olarak bilgisayarınıza iniyor.

### ✨ Ne Yapabilirsiniz?

| Workflow                      | Kullanım                                  |
| ----------------------------- | ----------------------------------------- |
| 🎭 **Yüz Değiştirme (Video)** | ReActor ile video/resimdeki yüzü değiştir |
| 🎨 **Stil Transferi**         | IP-Adapter ile kıyafet/stil değiştir      |
| 🖼️ **Resim Üretimi**          | FLUX.1 Schnell ile ultra hızlı resim üret |
| 📐 **Büyütme**                | RealESRGAN veya UltraSharp ile 4x büyüt   |
| 🎬 **Video Animasyon**        | AnimateDiff ile video animasyonu oluştur  |

### 🚀 Kurulum (Adım Adım)

Yukarıdaki İngilizce kılavuzu takip edin — tüm komutlar Windows için de geçerlidir.

**Kısaca:**

1. Bu repoyu klonla
2. Docker ile image build et (`docker build ...`)
3. GHCR'ye push et (`docker push ...`) ve **Public** yap
4. RunPod'da template + endpoint oluştur (Active Workers: **0**)
5. Lokal ComfyUI'ye `ComfyUI-RunPod-Worker` node'unu ekle
6. `workflows/faceswap.json` workflow'unu yükle
7. API key ve endpoint ID gir → Queue!

### ⚠️ Önemli Notlar

- **GitHub Actions KULLANILMIYOR** — lokal Docker build daha hızlı ve kontrollü
- Dockerfile'a yeni şey eklerken daima **SONA ekle** (cache koruması)
- **Active Workers = 0 olmalı** — 1 yaparsan 7/24 para keser (~$5-12/gün)
- `buffalo_l` modeli ilk çalışmada otomatik indirilir — normal davranış
- Push sırasında `broken pipe` hatası → tekrar çalıştır, kaldığı yerden devam eder

---

## 📜 License

MIT License — Use freely, attribution appreciated.

## 🙏 Credits

- [RunPod](https://runpod.io) — Serverless GPU infrastructure
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) — Base workflow engine
- [ReActor](https://github.com/Gourieff/ComfyUI-ReActor) — Face swap node
- [worker-comfyui](https://github.com/blib-la/runpod-worker-comfyui) — Base Docker image
=======
🚀 ComfyUI FaceSwap Worker for RunPod Serverless






Design your workflows locally. Generate in the cloud. Pay only for execution time.

This project lets you run ComfyUI on your local machine (no GPU required) while offloading all heavy processing to a RunPod Serverless GPU endpoint (e.g., RTX 4090).

When you hit “Queue Prompt”, your workflow is automatically sent to RunPod. Once processing is complete, the generated image or video is instantly returned to your local machine.

With Active Workers set to 0, you pay $0 when idle.

🏗️ Why Use This?

💻 Build and design workflows on your local PC

⚡ Leverage high-end cloud GPUs only when needed

💸 Zero idle cost (Serverless architecture)

🔄 Seamless send-and-return workflow integration

🎯 No need to keep a GPU running 24/7

You keep full control locally — the cloud only activates when you press the button.

📦 Included Models & Nodes

This container comes preloaded with approximately 35GB of models, ready to go:

🎭 Face & Restoration

ReActor FaceSwap

inswapper_128

GFPGAN

CodeFormer

🎬 Video & Animation

AnimateDiff Evolved

🎨 Style & Conditioning

IP-Adapter Plus (SDXL compatible)

ControlNet

Canny (SDXL)

Depth (SDXL)

🧠 Base Models

FLUX.1 Schnell

SDXL Base 1.0

Upscalers

Everything is pre-installed inside the Docker image — no additional setup required inside the container.

🚀 Setup Guide
Step 1 — Make Your Docker Image Public

Publish this repository’s Docker image to GitHub Container Registry.

Ensure the package visibility is set to Public (RunPod cannot pull private images).

Copy your image URL, for example:

ghcr.io/yourusername/comfyui-faceswap-worker:latest
Step 2 — Create a RunPod Serverless Endpoint

Go to RunPod Console → Serverless → My Templates

Click New Template

Container Image: Your GitHub image URL

Container Disk Size: 50 GB

Go to Serverless → New Endpoint

Select your template

Enable FlashBoot

Set:

Max Workers = 1

Active Workers = 0 ⚠️ (Important — prevents idle charges)

Your endpoint is now ready.

Step 3 — Connect Your Local ComfyUI

Install and run your local ComfyUI.

Add the custom RunPod Sender Node to your workflow.

Enter:

Your RunPod API Key

Your Endpoint ID (found in the endpoint URL)

Load your image or video.

Click Queue Prompt.

Your workflow runs in the cloud GPU.
The output returns automatically to your local machine.

💡 How It Works (Simple Flow)

Local ComfyUI → RunPod Serverless GPU → Result Returned Locally

No persistent GPU instance.
No idle billing.
Full power on demand.

🎯 Ideal For

Developers without a local GPU

Creators who want RTX 4090 power only when needed

FaceSwap & AnimateDiff workflows

SDXL + IP-Adapter pipelines

Cost-efficient production setups

⚡ Summary

This setup gives you:

✔ Local workflow control
✔ On-demand RTX-class performance
✔ Zero idle costs
✔ Preloaded FaceSwap + SDXL ecosystem
✔ Fully Dockerized & Serverless ready

Design locally. Render in the cloud.
Pay only for what you use.
>>>>>>> 08463719eea74dafb7d188e25ae3d2015cb96a5c
