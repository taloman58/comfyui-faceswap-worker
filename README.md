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
