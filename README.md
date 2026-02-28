# ComfyUI Face Swap Worker for RunPod Serverless

A production-ready RunPod Serverless worker that runs ComfyUI with ReActor face swap, video processing, and Cloudflare R2 output storage. Built on top of the official `runpod/worker-comfyui` base image with extensive customizations for face-swapping workflows.

> **Turkish documentation:** See [TR-README.md](./TR-README.md) for Turkish instructions.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Handler Deep Dive](#handler-deep-dive)
- [Dockerfile Breakdown](#dockerfile-breakdown)
- [start.sh — Startup Script](#startsh--startup-script)
- [Network Volume Setup](#network-volume-setup)
- [Environment Variables](#environment-variables)
- [Cloudflare R2 Configuration](#cloudflare-r2-configuration)
- [RunPod Endpoint Configuration](#runpod-endpoint-configuration)
- [Sending Requests](#sending-requests)
- [Output Handling](#output-handling)
- [Custom Nodes Included](#custom-nodes-included)
- [Models Required](#models-required)
- [Troubleshooting](#troubleshooting)
- [Known Issues](#known-issues)
- [Building & Deploying](#building--deploying)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   RunPod Worker                      │
│                                                      │
│  ┌──────────┐    ┌──────────┐    ┌───────────────┐  │
│  │ start.sh │───▶│ ComfyUI  │    │  handler.py   │  │
│  │          │    │ (bg)     │◄──▶│  (main proc)  │  │
│  │ symlinks │    │ :8188    │ WS │               │  │
│  │ models   │    └──────────┘    └───────┬───────┘  │
│  └──────────┘                            │          │
│                                          │          │
│  ┌──────────────────┐          ┌─────────▼────────┐ │
│  │ Network Volume   │          │ Cloudflare R2    │ │
│  │ /runpod-volume/  │          │ (S3-compatible)  │ │
│  │ models/          │          │ comfyui-output   │ │
│  └──────────────────┘          └──────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**Flow:**

1. `start.sh` runs on container startup
2. Models are symlinked from Network Volume → ComfyUI models directory
3. ComfyUI starts in the background on port 8188
4. `handler.py` starts and waits for ComfyUI API to be reachable
5. When a job arrives, handler uploads input images, queues the workflow, waits for completion
6. Output images/videos are uploaded to Cloudflare R2 (or returned as base64)

---

## Features

- ✅ **ReActor Face Swap** — High-quality face swapping using InsightFace
- ✅ **Video Processing** — Frame-by-frame face swap on video files
- ✅ **Cloudflare R2 Upload** — Automatic output upload with signed URLs
- ✅ **Network Volume Support** — Models stored on persistent network storage
- ✅ **WebSocket Monitoring** — Real-time workflow progress tracking
- ✅ **Auto-Reconnect** — WebSocket reconnection with configurable retry logic
- ✅ **Error Handling** — Detailed error messages with node-level diagnostics
- ✅ **GIF/Video Output** — Handles both `images` and `gifs` output keys from ComfyUI

---

## Quick Start

### 1. Build the Docker Image

```bash
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .
```

### 2. Push to Registry

```bash
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
```

### 3. Create RunPod Endpoint

1. Go to [RunPod Serverless](https://www.runpod.io/console/serverless)
2. Click **New Endpoint**
3. Set the container image: `ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest`
4. Select GPU: RTX 3090 or higher recommended
5. Attach a Network Volume for models (see [Network Volume Setup](#network-volume-setup))
6. Set Environment Variables (see [Environment Variables](#environment-variables))
7. Set Execution Timeout: **1200 seconds** (20 minutes recommended)
8. Enable FlashBoot for faster cold starts

### 4. Send a Test Request

```bash
curl -X POST "https://api.runpod.ai/v2/YOUR_ENDPOINT_ID/runsync" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": {
      "workflow": { ... },
      "images": [
        {
          "name": "source_face.jpg",
          "image": "BASE64_ENCODED_IMAGE"
        }
      ]
    }
  }'
```

---

## Project Structure

```
comfyui-faceswap-worker/
├── Dockerfile           # Multi-stage build with all dependencies
├── handler.py           # Main RunPod serverless handler (927 lines)
├── start.sh             # Container startup script (model linking + ComfyUI launch)
├── README.md            # This file (English)
├── TR-README.md         # Turkish documentation
├── runpod.json          # RunPod configuration
├── runpod-test.json     # Test payload
└── workflows/           # Example ComfyUI workflow JSON files
```

---

## Handler Deep Dive

The `handler.py` file is the core of this worker. It handles the complete lifecycle of a RunPod serverless job.

### Key Constants

| Constant                          | Default          | Description                               |
| --------------------------------- | ---------------- | ----------------------------------------- |
| `COMFY_HOST`                      | `127.0.0.1:8188` | ComfyUI server address                    |
| `COMFY_API_AVAILABLE_MAX_RETRIES` | `500`            | Max attempts to check if ComfyUI is ready |
| `COMFY_API_AVAILABLE_INTERVAL_MS` | `50`             | Delay between retries (ms)                |
| `WEBSOCKET_RECONNECT_ATTEMPTS`    | `5`              | WebSocket reconnection attempts           |
| `WEBSOCKET_RECONNECT_DELAY_S`     | `3`              | Delay between reconnection attempts (s)   |
| `REFRESH_WORKER`                  | `false`          | Reset worker state after each job         |

### Main Functions

#### `handler(job)` — Main Entry Point (Line ~400)

The RunPod serverless handler function. Called for every incoming job.

**Flow:**

1. Validates input (workflow JSON + optional images)
2. Checks if ComfyUI API is reachable at `http://127.0.0.1:8188/`
3. Uploads input images to ComfyUI via `/upload/image` endpoint
4. Connects to WebSocket at `ws://127.0.0.1:8188/ws?clientId=<uuid>`
5. Queues the workflow via `/prompt` API
6. Monitors execution via WebSocket messages
7. Fetches output from `/history/<prompt_id>`
8. Processes outputs (images and gifs/videos)
9. Uploads to Cloudflare R2 or encodes as base64
10. Returns result to RunPod

#### `validate_input(job_input)` — Input Validation (Line 142)

Validates the incoming job payload:

- Checks for `workflow` key (required)
- Validates `images` array format (optional)
- Extracts `comfy_org_api_key` if provided

**Expected Input Format:**

```json
{
  "workflow": { "ComfyUI API format workflow JSON" },
  "images": [
    {
      "name": "filename.jpg",
      "image": "base64_encoded_data_or_url"
    }
  ]
}
```

#### `check_server(url, retries, delay)` — Server Health Check (Line 191)

Polls the ComfyUI HTTP API until it responds with status 200.

- Default: 500 retries × 50ms = ~25 seconds max wait
- Logs success/failure to stdout

#### `upload_images(images)` — Image Upload (Line 227)

Uploads base64-encoded images to ComfyUI's `/upload/image` endpoint.

- Supports data URI prefix stripping
- Handles both base64 strings and HTTP URLs
- Reports per-image success/failure

#### `queue_workflow(workflow)` — Workflow Submission (Line ~350)

Sends the workflow JSON to ComfyUI's `/prompt` endpoint.

- Returns the `prompt_id` for tracking
- Captures and reports validation errors from ComfyUI

#### `get_history(prompt_id)` — History Retrieval (Line ~400)

Fetches completed workflow results from `/history/<prompt_id>`.

#### `get_image_data(filename, subfolder, folder_type)` — Image Data Fetch (Line ~420)

Downloads processed images from ComfyUI's `/view` endpoint.

- Parameters match ComfyUI's output format (filename, subfolder, type)
- Returns raw bytes

### Output Processing (Lines 700-920)

The handler processes two types of outputs from ComfyUI nodes:

#### Images (`node_output["images"]`)

- Each image is fetched via `/view` endpoint
- Temp images (type="temp") are skipped
- If `BUCKET_ENDPOINT_URL` is set → uploaded to Cloudflare R2
- Otherwise → encoded as base64

#### Videos/GIFs (`node_output["gifs"]`)

- Same logic as images but for video outputs
- ComfyUI stores video outputs under the `gifs` key
- Supports `.mp4`, `.gif`, `.webm` extensions
- Uploaded to R2 with correct content type

### Error Handling

The handler includes comprehensive error handling:

- **WebSocket disconnects**: Auto-reconnect with configurable retries
- **ComfyUI crashes**: Detected via HTTP health check during reconnect
- **Upload failures**: Individual file errors don't stop processing
- **Workflow errors**: ComfyUI validation errors are captured and returned

---

## Dockerfile Breakdown

```dockerfile
FROM runpod/worker-comfyui:5.7.1-flux1-schnell   # Base image with ComfyUI

# System dependencies for InsightFace compilation
RUN apt-get update && apt-get install -y build-essential cmake python3-dev

# ReActor face swap node
RUN pip install insightface==0.7.3
RUN cd /comfyui/custom_nodes && git clone ComfyUI-ReActor

# Additional custom nodes (11 total)
RUN comfy-node-install comfyui_ipadapter_plus
RUN comfy-node-install comfyui-videohelpersuite
# ... (see Dockerfile for full list)

# ONNX Runtime for ReActor
RUN pip install onnxruntime-gpu

# Create model directories for symlinks
RUN mkdir -p /comfyui/models/insightface ...

# Copy custom handler and startup script
COPY handler.py /handler.py
COPY start.sh /start.sh
CMD ["/start.sh"]
```

---

## start.sh — Startup Script

The startup script performs three critical tasks:

### 1. Model Symlink from Network Volume

```bash
# For each model category (checkpoints, insightface, facerestore, etc.)
ln -sf /runpod-volume/models/checkpoints/* /comfyui/models/checkpoints/
```

### 2. ComfyUI Background Launch

```bash
cd /comfyui
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
```

### 3. Handler Start

```bash
exec python /handler.py
```

> **Important:** ComfyUI MUST be started before handler.py. The original base image's CMD is overridden, so we explicitly start ComfyUI in the background.

---

## Network Volume Setup

### Why Network Volume?

- Models (7+ GB) don't need to be baked into the Docker image
- Faster cold starts (no model re-download)
- Easy model updates without rebuilding the image

### Setup Steps

1. **Create Network Volume** on RunPod Dashboard → Storage
2. **Region:** Must match your endpoint region (e.g., `EU-CZ-1`)
3. **Create Directories:**
   ```bash
   mkdir -p /runpod-volume/models/{checkpoints,insightface,facerestore_models,upscale_models,clip_vision,ipadapter,controlnet}
   ```
4. **Download Models** (see [Models Required](#models-required))
5. **Attach to Endpoint:** Edit Endpoint → Advanced → Network Volume

### Volume Mount Path

- Endpoint workers mount at: `/runpod-volume/`
- Temporary pods mount at: `/workspace/` (maps to same volume)

---

## Environment Variables

### Required (for R2 Upload)

| Variable                   | Example                                 | Description     |
| -------------------------- | --------------------------------------- | --------------- |
| `BUCKET_ENDPOINT_URL`      | `https://XXXX.r2.cloudflarestorage.com` | R2 endpoint URL |
| `BUCKET_ACCESS_KEY_ID`     | `267a26bd...`                           | R2 access key   |
| `BUCKET_SECRET_ACCESS_KEY` | `e24414a8...`                           | R2 secret key   |
| `BUCKET_NAME`              | `comfyui-output`                        | R2 bucket name  |

### Optional

| Variable                       | Default | Description                 |
| ------------------------------ | ------- | --------------------------- |
| `REFRESH_WORKER`               | `false` | Reset worker after each job |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | `5`     | Max WS reconnect attempts   |
| `WEBSOCKET_RECONNECT_DELAY_S`  | `3`     | Delay between reconnects    |
| `WEBSOCKET_TRACE`              | `false` | Enable verbose WS logging   |
| `NETWORK_VOLUME_DEBUG`         | `false` | Enable volume diagnostics   |

---

## Cloudflare R2 Configuration

### Setting Up R2

1. Go to Cloudflare Dashboard → R2
2. Create a bucket: `comfyui-output`
3. Create an API Token with read/write access
4. Note the endpoint URL, access key, and secret key

### How It Works

When `BUCKET_ENDPOINT_URL` is set in the environment:

1. Handler writes output to a temporary file
2. Uses `rp_upload.upload_image()` to upload to R2
3. Passes `bucket_name` from `BUCKET_NAME` env var
4. Returns a signed URL valid for 7 days
5. Temporary file is deleted after upload

If `BUCKET_ENDPOINT_URL` is NOT set:

- Outputs are returned as base64-encoded strings in the response
- ⚠️ Large videos can exceed RunPod's response size limits

---

## RunPod Endpoint Configuration

### Recommended Settings

| Setting           | Value           | Reason                             |
| ----------------- | --------------- | ---------------------------------- |
| GPU               | RTX 3090 (24GB) | SDXL + ReActor needs ~16GB VRAM    |
| Execution Timeout | 1200s (20 min)  | Video processing can take 5-10 min |
| FlashBoot         | Enabled         | Reduces cold start to ~2 seconds   |
| Max Workers       | 2               | Adjust based on demand             |
| Active Workers    | 0               | Scale to zero when idle            |
| Network Volume    | Attached        | Required for models                |

### Releasing Updates

After pushing a new Docker image:

1. Go to Endpoint → **Manage** → **New Release**
2. Wait for workers to pull the new image
3. Version number increments automatically
4. Old workers must be terminated to pick up new image

---

## Sending Requests

### Basic Image Face Swap

```python
import requests
import base64

API_KEY = "your_runpod_api_key"
ENDPOINT_ID = "your_endpoint_id"

# Read and encode the source face
with open("face.jpg", "rb") as f:
    face_b64 = base64.b64encode(f.read()).decode()

# Read and encode the target image
with open("target.jpg", "rb") as f:
    target_b64 = base64.b64encode(f.read()).decode()

payload = {
    "input": {
        "workflow": { ... },  # Your ComfyUI API-format workflow
        "images": [
            {"name": "source_face.jpg", "image": face_b64},
            {"name": "target.jpg", "image": target_b64}
        ]
    }
}

response = requests.post(
    f"https://api.runpod.ai/v2/{ENDPOINT_ID}/run",
    headers={"Authorization": f"Bearer {API_KEY}"},
    json=payload
)

job_id = response.json()["id"]
print(f"Job submitted: {job_id}")
```

### Video Face Swap

```python
# Same as above, but with a video file
with open("video.mp4", "rb") as f:
    video_b64 = base64.b64encode(f.read()).decode()

payload = {
    "input": {
        "workflow": { ... },
        "images": [
            {"name": "source_face.jpg", "image": face_b64},
            {"name": "input_video.mp4", "image": video_b64}
        ]
    }
}
```

### Checking Job Status

```python
status_response = requests.get(
    f"https://api.runpod.ai/v2/{ENDPOINT_ID}/status/{job_id}",
    headers={"Authorization": f"Bearer {API_KEY}"}
)

result = status_response.json()
if result["status"] == "COMPLETED":
    images = result["output"]["images"]
    for img in images:
        if img["type"] == "s3_url":
            print(f"Download: {img['data']}")
        elif img["type"] == "base64":
            # Decode and save
            data = base64.b64decode(img["data"])
            with open(img["filename"], "wb") as f:
                f.write(data)
```

---

## Output Handling

### Response Format

```json
{
  "status": "COMPLETED",
  "output": {
    "images": [
      {
        "filename": "faceswap_preview_00001_.png",
        "type": "s3_url",
        "data": "https://XXXX.r2.cloudflarestorage.com/comfyui-output/JOB_ID/HASH.png?X-Amz-..."
      },
      {
        "filename": "output_video.mp4",
        "type": "s3_url",
        "data": "https://XXXX.r2.cloudflarestorage.com/comfyui-output/JOB_ID/HASH.mp4?X-Amz-..."
      }
    ]
  }
}
```

### Output Types

| Type     | When                         | Description                            |
| -------- | ---------------------------- | -------------------------------------- |
| `s3_url` | `BUCKET_ENDPOINT_URL` is set | Signed URL to R2 bucket (7-day expiry) |
| `base64` | No bucket configured         | Base64-encoded file data               |

---

## Custom Nodes Included

| Node                            | Purpose                             |
| ------------------------------- | ----------------------------------- |
| **ComfyUI-ReActor**             | Face swapping with InsightFace      |
| **comfyui-ipadapter-plus**      | IP-Adapter for style/face transfer  |
| **comfyui-videohelpersuite**    | Video loading and saving            |
| **comfyui-animatediff-evolved** | AnimateDiff for video generation    |
| **comfyui-frame-interpolation** | Frame interpolation (FILM/RIFE)     |
| **comfyui-ultimatesdupscale**   | Ultimate SD Upscale                 |
| **comfyui-impact-pack**         | Detection, segmentation, refinement |
| **comfyui-advanced-controlnet** | Advanced ControlNet features        |
| **comfyui-kjnodes**             | Utility nodes                       |
| **comfyui-essentials**          | Essential utility nodes             |
| **was-node-suite-comfyui**      | 220+ utility nodes                  |

---

## Models Required

Store these in your Network Volume under `/runpod-volume/models/`:

### Checkpoints

| Model          | Path                                     | Size   |
| -------------- | ---------------------------------------- | ------ |
| SD XL Base 1.0 | `checkpoints/sd_xl_base_1.0.safetensors` | 6.9 GB |

### InsightFace

| Model         | Path                             | Size   |
| ------------- | -------------------------------- | ------ |
| inswapper_128 | `insightface/inswapper_128.onnx` | 554 MB |

### Face Restore

| Model      | Path                                       | Size   |
| ---------- | ------------------------------------------ | ------ |
| GFPGANv1.3 | `facerestore_models/GFPGANv1.3.pth`        | 348 MB |
| GFPGANv1.4 | `facerestore_models/GFPGANv1.4.pth`        | 348 MB |
| CodeFormer | `facerestore_models/codeformer-v0.1.0.pth` | 376 MB |

### Upscale

| Model          | Path                                   | Size  |
| -------------- | -------------------------------------- | ----- |
| 4x-UltraSharp  | `upscale_models/4x-UltraSharp.pth`     | 67 MB |
| RealESRGAN x4+ | `upscale_models/RealESRGAN_x4plus.pth` | 67 MB |

### CLIP Vision

| Model         | Path                                                      | Size   |
| ------------- | --------------------------------------------------------- | ------ |
| CLIP-ViT-H-14 | `clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 3.9 GB |

### IP-Adapter

| Model                     | Path                                                    | Size   |
| ------------------------- | ------------------------------------------------------- | ------ |
| IP-Adapter Plus Face SDXL | `ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors` | 847 MB |

### ControlNet

| Model     | Path                                            | Size   |
| --------- | ----------------------------------------------- | ------ |
| Canny Mid | `controlnet/diffusers_xl_canny_mid.safetensors` | 2.5 GB |
| Depth Mid | `controlnet/diffusers_xl_depth_mid.safetensors` | 2.5 GB |

---

## Troubleshooting

### "Failed to connect to server at http://127.0.0.1:8188/ after 500 attempts"

**Cause:** ComfyUI is not starting. This happens when `start.sh` doesn't launch ComfyUI before `handler.py`.

**Fix:** Ensure `start.sh` contains:

```bash
cd /comfyui
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
```

### "NoSuchBucket" Error on R2 Upload

**Cause:** `BUCKET_NAME` not set or incorrect.

**Fix:** Add `BUCKET_NAME=comfyui-output` to RunPod endpoint environment variables.

### Worker Stuck in "Throttled" State

**Cause:** Worker failed health checks too many times.

**Fix:**

1. Delete throttled workers
2. Check container logs for errors
3. If persistent, do a New Release to force fresh image pull

### Execution Timeout

**Cause:** Default timeout (600s) too short for video processing.

**Fix:** Increase to 1200s (20 min) in Endpoint settings.

### Models Not Found

**Cause:** Network Volume not mounted or symlinks not created.

**Fix:**

1. Verify Network Volume is in same region as endpoint
2. Check `start.sh` logs for "Network Volume bulundu"
3. Manually verify models exist in the volume

---

## Known Issues

### 1. Video Output Not Downloaded to Local Machine

**Status:** Open

When using the RunPod Worker node locally in ComfyUI, the processed **video file is not automatically saved** to the local machine. The video frames (as individual PNGs) are uploaded to Cloudflare R2 successfully, but the combined video output is not downloaded to the desktop.

**Workaround:**

- Download the video directly from Cloudflare R2 bucket
- Use the signed URLs returned in the API response
- Check the R2 bucket for `.mp4` files in the job folder

### 2. NSFW Detection Model Downloaded on Every Cold Start

ReActor downloads a ~328 MB NSFW detection model on first run. This is cached within the container but lost on cold starts.

**Potential Fix:** Pre-download this model into the Docker image or Network Volume.

### 3. AnimateDiff Motion Models Not Found

Warning in logs: `No motion models found`. This doesn't affect face swap workflows but will affect animation workflows.

**Fix:** Download motion models to `animatediff_models/` in Network Volume.

---

## Building & Deploying

### Full Build & Push

```bash
# Build
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Push
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
```

### After Pushing

1. Go to RunPod → Your Endpoint → **Manage** → **New Release**
2. Wait for workers to show new version number
3. Delete old workers if they don't auto-update
4. Test with a simple workflow first

### GitHub Actions (CI/CD)

A GitHub Actions workflow is available at `.github/workflows/` for automated builds on push.

---

## License

This project uses the official RunPod Worker ComfyUI base image. See individual component licenses:

- RunPod Worker: [RunPod License](https://runpod.io)
- ComfyUI: [GPL-3.0](https://github.com/comfyanonymous/ComfyUI)
- ReActor: [AGPL-3.0](https://github.com/Gourieff/ComfyUI-ReActor)
- InsightFace: [MIT](https://github.com/deepinsight/insightface)
