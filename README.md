# ComfyUI Face Swap Worker for RunPod Serverless

A production-ready RunPod Serverless worker for high-quality face swapping on images and videos using ComfyUI + ReActor. Includes intelligent video output handling, pre-downloaded models for zero cold-start delays, and Cloudflare R2 storage integration.

> **Türkçe dokümantasyon:** [TR-README.md](./TR-README.md)

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    RunPod Worker                         │
│                                                          │
│  ┌──────────┐    ┌──────────┐    ┌───────────────────┐  │
│  │ start.sh │───▶│ ComfyUI  │    │    handler.py     │  │
│  │          │    │ (bg)     │◄──▶│    (main proc)    │  │
│  │ symlinks │    │ :8188    │ WS │                   │  │
│  │ models   │    └──────────┘    └─────────┬─────────┘  │
│  └──────────┘                              │            │
│                                            │            │
│  ┌──────────────────┐           ┌──────────▼─────────┐  │
│  │ Network Volume   │           │  Cloudflare R2     │  │
│  │ /runpod-volume/  │           │  (S3-compatible)   │  │
│  │ models/          │           │  comfyui-output    │  │
│  └──────────────────┘           └────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Flow:**

1. `start.sh` → models symlinked from Network Volume → ComfyUI starts (bg)
2. `handler.py` → waits for ComfyUI API → processes jobs
3. Input images/videos uploaded to ComfyUI → workflow executed
4. Outputs uploaded to R2 (or returned as base64) → signed URL returned

---

## Features

| Feature                    | Description                                                                     |
| -------------------------- | ------------------------------------------------------------------------------- |
| **ReActor Face Swap**      | High-quality face swapping using InsightFace + CodeFormer                       |
| **Video Processing**       | Frame-by-frame face swap with audio preservation                                |
| **Frame Flood Protection** | When video output exists, skips uploading individual frame images automatically |
| **R2 Upload**              | Automatic output upload to Cloudflare R2 with 7-day signed URLs                 |
| **Zero Cold Start Models** | NSFW, buffalo_l, facexlib, AnimateDiff, YOLO all pre-downloaded                 |
| **FaceDetailer**           | Second-pass face refinement for beard preservation and consistency              |
| **LivePortrait**           | Natural face animation and expression transfer                                  |
| **WebSocket Monitoring**   | Real-time workflow progress with configurable auto-reconnect                    |
| **Network Volume**         | Large models stored on persistent storage, not baked into image                 |

---

## Quick Start

### 1. Build & Push

```bash
# Build
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .

# Push
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
```

Or push to GitHub `main` branch — GitHub Actions will build automatically.

### 2. Create RunPod Endpoint

1. Go to [RunPod Serverless](https://www.runpod.io/console/serverless)
2. **New Endpoint** → Container image: `ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest`
3. GPU: **RTX 3090** (24GB) or higher
4. Attach **Network Volume** (same region)
5. Set **Environment Variables** (see below)
6. Execution Timeout: **1200s** (20 min)
7. Enable **FlashBoot**

### 3. Test

```bash
curl -X POST "https://api.runpod.ai/v2/YOUR_ENDPOINT/run" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "workflow": { ... },
      "images": [
        {"name": "source_face.jpg", "image": "BASE64_DATA"},
        {"name": "target.mp4", "image": "BASE64_DATA"}
      ]
    }
  }'
```

---

## Project Structure

```
comfyui-faceswap-worker/
├── Dockerfile           # Multi-stage build (119 lines)
├── handler.py           # RunPod serverless handler (~950 lines)
├── start.sh             # Container startup (symlinks + ComfyUI launch)
├── README.md            # This file
├── TR-README.md         # Turkish documentation
├── KURULUM.md           # Setup guide (Turkish)
├── runpod.json          # RunPod configuration
├── runpod-test.json     # Test payload
├── .github/workflows/   # CI/CD (auto build on push)
└── workflows/           # Example ComfyUI workflow JSONs
```

---

## Custom Nodes (15 total)

| Node                            | Purpose                                    | Category |
| ------------------------------- | ------------------------------------------ | -------- |
| **ComfyUI-ReActor**             | Face swap with InsightFace                 | Core     |
| **comfyui-impact-pack**         | FaceDetailer, YOLO detection, segmentation | Core     |
| **comfyui-videohelpersuite**    | Video loading/saving with audio            | Core     |
| **comfyui-liveportraitkj**      | LivePortrait face animation                | Pro      |
| **comfyui_faceanalysis**        | Face similarity analysis                   | Pro      |
| **comfyui_ipadapter_plus**      | IP-Adapter for style/face transfer         | Style    |
| **comfyui-animatediff-evolved** | AnimateDiff video generation               | Video    |
| **comfyui-frame-interpolation** | Frame interpolation (FILM/RIFE)            | Video    |
| **comfyui_ultimatesdupscale**   | Ultimate SD Upscale                        | Quality  |
| **comfyui-advanced-controlnet** | Advanced ControlNet                        | Control  |
| **comfyui-kjnodes**             | Utility nodes                              | Utility  |
| **comfyui_essentials**          | Essential utility nodes                    | Utility  |
| **was-node-suite-comfyui**      | 220+ utility nodes                         | Utility  |

---

## Pre-Downloaded Models (in Docker Image)

These models are baked into the Docker image to eliminate cold-start downloads:

| Model                          | Size   | Purpose                              |
| ------------------------------ | ------ | ------------------------------------ |
| `vit-base-nsfw-detector`       | 328 MB | ReActor NSFW detection               |
| `buffalo_l` (InsightFace)      | 282 MB | Face detection & recognition         |
| `detection_Resnet50_Final.pth` | 104 MB | Facexlib face detection              |
| `parsing_parsenet.pth`         | 81 MB  | CodeFormer face parsing              |
| `mm_sd_v15_v2.ckpt`            | 1.8 GB | AnimateDiff motion model             |
| `face_yolov8m.pt`              | 52 MB  | YOLO face detection for FaceDetailer |

**Total pre-downloaded:** ~2.6 GB

---

## Network Volume Models

Store these in your Network Volume under `/runpod-volume/models/`:

| Model                | Path                                                      | Size   |
| -------------------- | --------------------------------------------------------- | ------ |
| SD XL Base 1.0       | `checkpoints/sd_xl_base_1.0.safetensors`                  | 6.9 GB |
| inswapper_128        | `insightface/inswapper_128.onnx`                          | 554 MB |
| GFPGANv1.3           | `facerestore_models/GFPGANv1.3.pth`                       | 348 MB |
| GFPGANv1.4           | `facerestore_models/GFPGANv1.4.pth`                       | 348 MB |
| CodeFormer           | `facerestore_models/codeformer-v0.1.0.pth`                | 376 MB |
| 4x-UltraSharp        | `upscale_models/4x-UltraSharp.pth`                        | 67 MB  |
| RealESRGAN x4+       | `upscale_models/RealESRGAN_x4plus.pth`                    | 67 MB  |
| CLIP-ViT-H-14        | `clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 3.9 GB |
| IP-Adapter Face SDXL | `ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors`   | 847 MB |
| Canny ControlNet     | `controlnet/diffusers_xl_canny_mid.safetensors`           | 2.5 GB |
| Depth ControlNet     | `controlnet/diffusers_xl_depth_mid.safetensors`           | 2.5 GB |

---

## Environment Variables

### Required (R2 Upload)

| Variable                   | Example                                | Description    |
| -------------------------- | -------------------------------------- | -------------- |
| `BUCKET_ENDPOINT_URL`      | `https://XXX.r2.cloudflarestorage.com` | R2 endpoint    |
| `BUCKET_ACCESS_KEY_ID`     | `267a26bd...`                          | R2 access key  |
| `BUCKET_SECRET_ACCESS_KEY` | `e24414a8...`                          | R2 secret key  |
| `BUCKET_NAME`              | `comfyui-output`                       | R2 bucket name |

### Optional

| Variable                       | Default | Description                 |
| ------------------------------ | ------- | --------------------------- |
| `REFRESH_WORKER`               | `false` | Reset worker after each job |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | `5`     | Max WS reconnect attempts   |
| `WEBSOCKET_RECONNECT_DELAY_S`  | `3`     | Delay between reconnects    |

---

## Handler Features

### Frame Flood Protection

When a workflow produces both video output (`VHS_VideoCombine`) and individual frames (`SaveImage`), the handler automatically skips uploading frame images:

```
WITHOUT protection: 386 PNGs + 1 MP4 = 387 uploads → slow, timeout
WITH protection:    1 MP4 only = 1 upload → instant
```

- Threshold: 10 images per node
- If any node produces `gifs` output AND another node produces >10 images → frames skipped
- Works for **any workflow** — no workflow modification needed

### Output Format

```json
{
  "status": "COMPLETED",
  "output": {
    "images": [
      {
        "filename": "faceswap_result_00001-audio.mp4",
        "type": "s3_url",
        "data": "https://XXX.r2.cloudflarestorage.com/comfyui-output/JOB_ID/HASH.mp4?X-Amz-..."
      }
    ]
  }
}
```

| Type     | When                         | Description                     |
| -------- | ---------------------------- | ------------------------------- |
| `s3_url` | `BUCKET_ENDPOINT_URL` is set | Signed URL to R2 (7-day expiry) |
| `base64` | No bucket configured         | Base64-encoded file data        |

---

## Pro Face Swap Workflow

For high-quality, consistent face swapping on video:

```
LoadImage (source face)
       ↓
VHS_LoadVideo (target video) → ReActorFaceSwap → FaceDetailer → VHS_VideoCombine
                          (audio) ─────────────────────────────────↗
```

### Key Settings for Quality

| Problem                                | Solution                             | Setting                                   |
| -------------------------------------- | ------------------------------------ | ----------------------------------------- |
| **Flickering** (original face appears) | Lower det_size, use YOLO             | `det_size: 320`, FaceDetailer with YOLOv8 |
| **Beard cut off**                      | Enable face_boost, increase dilation | `face_boost: ON`, `dilation: 20`          |
| **Inconsistent restore**               | Lower CodeFormer strength            | `restore_cf: 0.5-0.7`                     |
| **Soft blend edges**                   | Increase feather                     | `feather: 15`                             |

---

## Dockerfile Layers (Cache-Optimized)

```
Layer 1-17:  Base image + pip installs + custom nodes    [CACHED]
Layer 18:    Model directories                           [CACHED]
Layer 19:    NSFW model pre-download (328MB)              [CACHED]
Layer 20:    COPY handler.py                              [rebuilds if changed]
Layer 21-22: COPY start.sh + chmod                        [rebuilds if changed]
Layer 23:    buffalo_l pre-download (282MB)                [CACHED]
Layer 24:    facexlib pre-download (185MB)                 [CACHED]
Layer 25:    AnimateDiff pre-download (1.8GB)              [CACHED]
Layer 26-27: LivePortrait + FaceAnalysis nodes             [CACHED]
Layer 28:    YOLO face model (52MB)                        [CACHED]
```

Model downloads are placed **after** COPY commands so that code changes don't trigger ~3GB re-downloads.

---

## Troubleshooting

| Error                                                     | Cause                       | Fix                                     |
| --------------------------------------------------------- | --------------------------- | --------------------------------------- |
| `Failed to connect to server at :8188 after 500 attempts` | ComfyUI not starting        | Check `start.sh` has `python main.py &` |
| `NoSuchBucket` on R2 upload                               | Wrong bucket name           | Set `BUCKET_NAME=comfyui-output`        |
| Worker stuck in "Throttled"                               | Failed health checks        | Delete worker, do New Release           |
| Execution Timeout                                         | Default too short for video | Set to 1200s in Endpoint settings       |
| Models Not Found                                          | Volume not mounted          | Check region matches, verify symlinks   |

---

## Known Issues

### ~~1. Video Output Not Downloaded~~ ✅ FIXED

**Problem:** 386 individual PNG frames + 1 MP4 uploaded → timeout.
**Fix:** Frame Flood Protection in `handler.py` — frames skipped when video exists.

### ~~2. NSFW Model Cold Start~~ ✅ FIXED

**Problem:** ~328MB download on every cold start.
**Fix:** Pre-downloaded in Docker image.

### 3. AnimateDiff Motion Models

**Status:** ✅ FIXED — `mm_sd_v15_v2.ckpt` pre-downloaded in Docker image.

### 4. Extra Workers Spawning

**Status:** Platform Issue — RunPod may spawn extra workers with FlashBoot. Delete manually from dashboard.

---

## Building & Deploying

### Manual Build

```bash
docker build -t ghcr.io/taloman58/comfyui-faceswap-worker:latest .
docker push ghcr.io/taloman58/comfyui-faceswap-worker:latest
```

### GitHub Actions (Automatic)

Push to `main` branch triggers auto-build via `.github/workflows/docker-push.yml`.

### After Pushing

1. RunPod → Endpoint → **Manage** → **New Release**
2. Wait for workers to pull new image
3. Delete old workers if needed
4. Test with a simple workflow

---

## API Usage

### Python Example

```python
import requests, base64, time

API_KEY = "your_runpod_api_key"
ENDPOINT = "your_endpoint_id"

# Encode files
with open("face.jpg", "rb") as f:
    face_b64 = base64.b64encode(f.read()).decode()
with open("video.mp4", "rb") as f:
    video_b64 = base64.b64encode(f.read()).decode()

# Submit job
r = requests.post(
    f"https://api.runpod.ai/v2/{ENDPOINT}/run",
    headers={"Authorization": f"Bearer {API_KEY}"},
    json={
        "input": {
            "workflow": { ... },
            "images": [
                {"name": "source_face.jpg", "image": face_b64},
                {"name": "target.mp4", "image": video_b64}
            ]
        }
    }
)
job_id = r.json()["id"]

# Poll for result
while True:
    status = requests.get(
        f"https://api.runpod.ai/v2/{ENDPOINT}/status/{job_id}",
        headers={"Authorization": f"Bearer {API_KEY}"}
    ).json()
    if status["status"] == "COMPLETED":
        for item in status["output"]["images"]:
            if item["type"] == "s3_url":
                video = requests.get(item["data"])
                with open(item["filename"], "wb") as f:
                    f.write(video.content)
                print(f"Saved: {item['filename']}")
        break
    elif status["status"] == "FAILED":
        print(f"Error: {status}")
        break
    time.sleep(5)
```

### File Size Limits

| Method        | Payload Limit | Real File Limit         |
| ------------- | ------------- | ----------------------- |
| `runsync`     | ~10 MB        | ~7 MB (base64 overhead) |
| `run` (async) | ~20 MB        | ~15 MB                  |

> For files >15MB, consider uploading to R2 first and passing URLs.

---

## License

- RunPod Worker: [RunPod License](https://runpod.io)
- ComfyUI: [GPL-3.0](https://github.com/comfyanonymous/ComfyUI)
- ReActor: [AGPL-3.0](https://github.com/Gourieff/ComfyUI-ReActor)
- InsightFace: [MIT](https://github.com/deepinsight/insightface)
