# 🚀 Sıfırdan Kurulum Rehberi

Bu rehber, ComfyUI + RunPod face swap sistemini **sıfırdan** nasıl kuracağını anlatıyor. Hiçbir şey bilmesen bile adım adım takip edebilirsin.

---

## 📁 Saklanması Gereken Dosyalar

Tüm sistem bu 5 dosyadan ibaret. Bunları sakla, gerisini unut:

```
comfyui-faceswap-worker/
├── Dockerfile        ← Docker image tarifi (tüm node'lar + modeller burada)
├── handler.py        ← RunPod iş işleyicisi (video flood koruması dahil)
├── start.sh          ← Container başlangıç scripti
├── README.md         ← İngilizce dokümantasyon
└── Rehber.md         ← Bu dosya
```

> ⚠️ **Bu 5 dosya = tüm sistem.** GitHub'a push'la, istediğin zaman sıfırdan kurarsın.

---

## 🧩 Büyük Resim — Ne Nedir?

```
SEN (Bilgisayarın)                         BULUT (RunPod)
─────────────────                          ──────────────

ComfyUI (localhost:8188)                   Docker Container
  │                                          │
  ├── RunPodSender node'u ──── API ────────▶ handler.py
  │   (workflow + resim/video gönderir)      │
  │                                          ├── ComfyUI (arka planda)
  │                                          ├── ReActor (yüz değiştirme)
  │                                          ├── FaceDetailer (kalite)
  │                                          └── ...diğer node'lar
  │                                          │
  │                                          ▼
  │                                        Cloudflare R2
  │                                          │ (video yüklenir)
  │                                          │
  └── Desktop/RunPod/ ◀──── indirme ────────┘
      (sonuç dosyaları buraya iner)
```

---

## 📋 Adım Adım Kurulum

### ADIM 1: Gerekli Hesaplar

| Hesap              | Neden Lazım                  | Link           |
| ------------------ | ---------------------------- | -------------- |
| **GitHub**         | Docker image'ı depolamak     | github.com     |
| **RunPod**         | GPU kiralayıp iş çalıştırmak | runpod.io      |
| **Cloudflare**     | R2 bucket (dosya depolama)   | cloudflare.com |
| **Docker Desktop** | Lokal image build etmek      | docker.com     |

---

### ADIM 2: Cloudflare R2 Kurulumu

1. Cloudflare Dashboard → **R2** → **Create Bucket**
2. Bucket adı: `comfyui-output`
3. **Manage R2 API Tokens** → **Create API Token**
4. İzinler: **Object Read & Write**
5. Şu 4 değeri not al:

```
BUCKET_ENDPOINT_URL = https://XXXXXXX.r2.cloudflarestorage.com
BUCKET_ACCESS_KEY_ID = 267a26bd...
BUCKET_SECRET_ACCESS_KEY = e24414a8...
BUCKET_NAME = comfyui-output
```

> Bu değerler RunPod'a girilecek. Kaybet diye bir yere kaydet.

---

### ADIM 3: Docker Image Build & Push

#### İlk kez yapıyorsan:

```bash
# 1. GitHub'a login ol (token gerekir)
echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# 2. Proje klasörüne git
cd comfyui-faceswap-worker

# 3. Build et (bu 20-40 dk sürer, bir kere yapılır)
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .

# 4. Push et
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
```

#### Sonraki değişikliklerde:

```bash
# Sadece değişen layer'lar rebuild edilir (çok hızlı)
docker build -t ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest .
docker push ghcr.io/YOUR_USERNAME/comfyui-faceswap-worker:latest
```

> 💡 **İpucu:** GitHub'a push edersen `.github/workflows/` otomatik build yapar. Ama yavaş olabilir.

---

### ADIM 4: RunPod Network Volume Oluşturma

Network Volume = büyük modellerin depolandığı kalıcı disk.

1. RunPod → **Storage** → **Create Network Volume**
2. **Bölge:** Endpoint ile AYNI bölge olmalı (örn: `EU-CZ-1`)
3. **Boyut:** 20 GB yeterli
4. Volume'a modelleri yükle (GPU Pod ile):

```bash
# Geçici bir pod oluştur (volume bağlı)
# Pod içinde:
mkdir -p /workspace/models/{checkpoints,insightface,facerestore_models,upscale_models,clip_vision,ipadapter,controlnet}

# Modelleri indir
cd /workspace/models/checkpoints
wget https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors

cd /workspace/models/insightface
wget https://huggingface.co/ezioruan/inswapper_128.onnx/resolve/main/inswapper_128.onnx

cd /workspace/models/facerestore_models
wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.3.pth
wget https://github.com/TencentARC/GFPGAN/releases/download/v1.3.4/GFPGANv1.4.pth
wget https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/codeformer-v0.1.0.pth
```

> ⚠️ Pod'u kapattıktan sonra volume'daki dosyalar **kalır**. Pod'u silsen bile.

---

### ADIM 5: RunPod Endpoint Oluşturma

1. RunPod → **Serverless** → **New Endpoint**
2. Ayarlar:

| Ayar              | Değer                                              | Açıklama                      |
| ----------------- | -------------------------------------------------- | ----------------------------- |
| Container Image   | `ghcr.io/taloman58/comfyui-faceswap-worker:latest` | Senin image                   |
| GPU               | RTX 3090 (24GB)                                    | Face swap için yeterli        |
| Execution Timeout | 1200                                               | 20 dakika (video işleme için) |
| FlashBoot         | ✅ Açık                                            | Hızlı cold start              |
| Max Workers       | 2                                                  | Aynı anda kaç iş              |
| Active Workers    | 0                                                  | Boşta para yeme               |
| Network Volume    | Seç                                                | ADIM 4'te oluşturduğun        |

3. **Environment Variables** ekle:

```
BUCKET_ENDPOINT_URL    = https://XXXXXXX.r2.cloudflarestorage.com
BUCKET_ACCESS_KEY_ID   = 267a26bd...
BUCKET_SECRET_ACCESS_KEY = e24414a8...
BUCKET_NAME            = comfyui-output
```

4. **Create Endpoint** → Endpoint ID'yi not al

---

### ADIM 6: Lokal ComfyUI Kurulumu

#### ComfyUI Portable İndir

1. https://github.com/comfyanonymous/ComfyUI/releases → Windows Portable indir
2. `D:\ComfyUI_windows_portable\` klasörüne çıkar
3. `run_nvidia_gpu.bat` çalıştır → `http://127.0.0.1:8188` açılır

#### RunPodSender Node'u Kur

```bash
cd D:\ComfyUI_windows_portable\ComfyUI\custom_nodes
git clone https://github.com/taloman58/ComfyUI-RunPod-Worker.git
```

Bu node sayesinde ComfyUI arayüzünden direkt RunPod'a iş gönderebilirsin.

#### Gerekli Node'lar (Yerelde)

```bash
cd D:\ComfyUI_windows_portable\ComfyUI\custom_nodes

# Face swap
git clone https://github.com/Gourieff/ComfyUI-ReActor.git

# Video
git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# Yüz iyileştirme
git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git

# Pro yüz
git clone https://github.com/kijai/ComfyUI-LivePortraitKJ.git
git clone https://github.com/cubiq/ComfyUI_FaceAnalysis.git
```

ComfyUI'ı yeniden başlat. Tüm node'lar yüklenir.

---

## 🎬 Kullanım — Video Face Swap

### ComfyUI Arayüzünden:

1. ComfyUI'ı aç (`http://127.0.0.1:8188`)
2. Workflow'u yükle (faceswap.json)
3. **LoadImage** node'una kaynak yüz fotoğrafını yükle
4. **VHS_LoadVideo** node'una hedef videoyu yükle
5. **RunPodSender** node'una API Key ve Endpoint ID gir
6. **Queue Prompt** tıkla → iş RunPod'a gider
7. Sonuç `Desktop/RunPod/` klasörüne iner

### Ne Kadar Sürer?

| Video Süresi | İşlem Süresi | Yaklaşık Maliyet |
| ------------ | ------------ | ---------------- |
| 5 saniye     | ~1 dakika    | ~$0.01           |
| 15 saniye    | ~3 dakika    | ~$0.03           |
| 30 saniye    | ~7 dakika    | ~$0.07           |
| 1 dakika     | ~15 dakika   | ~$0.15           |

> RTX 3090 fiyatı: ~$0.44/saat

---

## 🔧 Güncelleme Yapmak İstersen

### handler.py değiştirdiysen:

```bash
cd comfyui-faceswap-worker
docker build -t ghcr.io/taloman58/comfyui-faceswap-worker:latest .
docker push ghcr.io/taloman58/comfyui-faceswap-worker:latest
# RunPod → Manage → New Release
```

### Yeni node eklediysen:

Dockerfile'ın **sonuna** ekle (cache kırılmasın):

```dockerfile
# Yeni node (en sona ekle!)
RUN comfy-node-install yeni-node-adi
```

Sonra build + push + New Release.

### Yeni model eklediysen:

Network Volume'a yükle (pod ile) veya Dockerfile'ın sonuna wget ekle.

---

## 🚨 Sorun Giderme

### "Worker Throttled" diyor

→ Worker sil, **New Release** yap.

### Video inmiyor

→ R2 environment variable'ları doğru mu kontrol et. `BUCKET_NAME` eksikse video base64 olarak döner ve timeout olur.

### "Failed to connect to :8188"

→ `start.sh` dosyasında ComfyUI arka planda başlıyor mu kontrol et:

```bash
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
```

### Yüzler arası flickering var

→ Workflow'da **FaceDetailer** ekle. `det_size: 320`, `dilation: 20` ayarla.

### Sakal kesiliyor

→ ReActor'da `face_boost: ON` aç. FaceDetailer'da `dilation: 20`, `feather: 15`.

---

## 💰 Maliyet Kontrolü

| Dikkat Et                 | Neden                             |
| ------------------------- | --------------------------------- |
| Active Workers = 0 yap    | Boşta GPU para yer                |
| Idle Timeout = 5s         | Worker hemen kapansın             |
| Max Workers = 1-2         | Fazla worker = fazla para         |
| Throttled worker'ları sil | Arka planda çalışmaya devam eder  |
| FlashBoot = açık          | Cold start hızlı, daha az bekleme |

> 💡 **Pro tip:** İşin yokken RunPod Dashboard'a bak, "Workers" sekmesinde çalışan worker var mı kontrol et. Varsa sil.

---

## 📦 Sıfırdan Yeniden Kurulum Checklist

Eğer her şeyi silip sıfırdan kurmak istersen:

- [ ] GitHub repo'dan 5 dosyayı çek (`Dockerfile`, `handler.py`, `start.sh`, `README.md`, `Rehber.md`)
- [ ] Docker Desktop kur
- [ ] `docker build` + `docker push` yap
- [ ] RunPod'da Network Volume oluştur → modelleri yükle
- [ ] RunPod'da Endpoint oluştur → container image + env vars gir
- [ ] Cloudflare R2 bucket oluştur → token al
- [ ] Lokalde ComfyUI kur → RunPodSender node'u ekle
- [ ] Test et

**Bu kadar. 5 dosya + 3 hesap = tüm sistem.**
