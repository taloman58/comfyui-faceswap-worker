# 🚀 ComfyUI FaceSwap Worker for RunPod Serverless

![ComfyUI](https://img.shields.io/badge/ComfyUI-Active-green) ![RunPod](https://img.shields.io/badge/RunPod-Serverless-blue) ![Docker](https://img.shields.io/badge/Docker-Ready-2496ED)

This repository contains a fully configured Docker image to run ComfyUI with **ReActor (FaceSwap)**, **AnimateDiff**, **IP-Adapter**, and **ControlNet** on RunPod Serverless. It allows you to design workflows on a local PC (without a GPU) and execute them on a high-end cloud GPU, paying only for the exact seconds you use ($0.00 cost when idle).

🇬🇧 [English Instructions](#-english-instructions) | 🇹🇷 [Türkçe Kurulum](#-türkçe-kurulum)

---

## 🇹🇷 Türkçe Kurulum ve Kullanım

### 🏗️ Ne İşe Yarar?
Ekran kartı olmayan yerel bilgisayarınızda ComfyUI arayüzünü açarsınız. İşlemi başlattığınızda (Queue Prompt), sistem işi otomatik olarak RunPod'daki GPU'ya (örn: RTX 4090) gönderir. İşlem cloud'da bittiğinde, sonuç (video/resim) bilgisayarınıza geri iner.

### 📦 İçerdiği Modeller ve Düğümler (Nodes)
* **ReActor:** Yüz değiştirme (inswapper_128, GFPGAN, CodeFormer)
* **AnimateDiff Evolved:** Video animasyon modelleri
* **IP-Adapter Plus:** Stil ve kıyafet transferi (SDXL uyumlu)
* **ControlNet:** Poz, derinlik ve kenar algılama
* **FLUX.1 Schnell & SDXL Base 1.0**
* *(Toplamda yaklaşık 35GB model içerir)*

### 🚀 Nasıl Kurulur?

**1. RunPod'da Endpoint Oluşturma:**
1. RunPod Console > Serverless > My Templates gidin.
2. Yeni bir Template oluşturun:
   * **Container Image:** `ghcr.io/taloman58/comfyui-faceswap-worker:latest`
   * **Container Disk:** `50 GB`
3. "Serverless" menüsüne gidip **New Endpoint** oluşturun. Seçtiğiniz template'i kullanın (FlashBoot tavsiye edilir). ***Active Workers sayısını `0` yapmayı unutmayın!*** Böylece kullanmadığınızda hiç para ödemezsiniz.

**2. Yerel Bilgisayarı Bağlamak:**
1. Kendi yerel [ComfyUI](https://github.com/comfyanonymous/ComfyUI) kurulumunuzu açın.
2. RunPod'dan aldığınız **API Key** ve **Endpoint ID** (URL'deki l4gg8... gibi bir kod) bilgilerini alın.
3. Çalışma planınıza (Workflow) **RunPodSender** düğümünü ekleyin ve bu bilgileri içine girin.
4. "Queue Prompt" dediğiniz an, işlem buluta gidecek ve yüz değiştirilmiş videonuz geri gelecektir!

---

## 🇬🇧 English Instructions

### 🏗️ What is this?
Design your workflows on a local PC (even without a GPU). When you hit "Queue Prompt", the workflow is sent to a RunPod Serverless endpoint (e.g., RTX 4090). Once generated, the output image/video is instantly returned to your local machine.

### 📦 Included Features & Nodes
* **ReActor FaceSwap** (incl. inswapper_128, GFPGAN, CodeFormer)
* **AnimateDiff Evolved** for video generation
* **IP-Adapter Plus** for style reference (SDXL)
* **ControlNet** (Canny, Depth for SDXL)
* **Models:** FLUX.1 Schnell, SDXL Base 1.0, and RealESRGAN Upscalers.

### 🚀 Setup Guide

**1. Create a RunPod Endpoint:**
1. Go to RunPod Console > Serverless > My Templates.
2. Create New Template:
   * **Container Image:** `ghcr.io/taloman58/comfyui-faceswap-worker:latest`
   * **Container Disk Size:** `50 GB`
3. Go to Endpoints > New Endpoint. Select your template. **Set Active Workers to `0`** so you don't pay while idle!

**2. Connect Local ComfyUI:**
1. Open your local ComfyUI.
2. Add your **RunPod API Key** and **Endpoint ID** to your RunPod Sender node default settings.
3. Drop your media, hit "Queue Prompt", and watch the magic happen in the cloud!
