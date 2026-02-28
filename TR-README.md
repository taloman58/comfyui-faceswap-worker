# ComfyUI Face Swap Worker — RunPod Serverless (Türkçe Rehber)

RunPod Serverless üzerinde çalışan, ReActor yüz değiştirme ve video işleme destekli, Cloudflare R2 depolama entegrasyonlu bir ComfyUI worker'ı.

> **English documentation:** See [README.md](./README.md)

---

## İçindekiler

- [Mimari Genel Bakış](#mimari-genel-bakış)
- [Özellikler](#özellikler)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Proje Yapısı](#proje-yapısı)
- [Handler Detayları](#handler-detayları)
- [Network Volume Kurulumu](#network-volume-kurulumu)
- [Ortam Değişkenleri](#ortam-değişkenleri)
- [Cloudflare R2 Yapılandırması](#cloudflare-r2-yapılandırması)
- [RunPod Endpoint Ayarları](#runpod-endpoint-ayarları)
- [İstek Gönderme](#i̇stek-gönderme)
- [Çıktı İşleme](#çıktı-i̇şleme)
- [Dahil Edilen Custom Node'lar](#dahil-edilen-custom-nodelar)
- [Gerekli Modeller](#gerekli-modeller)
- [Sorun Giderme](#sorun-giderme)
- [Bilinen Sorunlar](#bilinen-sorunlar)
- [Build ve Deploy](#build-ve-deploy)

---

## Mimari Genel Bakış

```
┌─────────────────────────────────────────────────────┐
│                   RunPod Worker                      │
│                                                      │
│  ┌──────────┐    ┌──────────┐    ┌───────────────┐  │
│  │ start.sh │───▶│ ComfyUI  │    │  handler.py   │  │
│  │          │    │ (arka    │◄──▶│  (ana süreç)  │  │
│  │ model    │    │  plan)   │ WS │               │  │
│  │ bağlama  │    │ :8188    │    │               │  │
│  └──────────┘    └──────────┘    └───────┬───────┘  │
│                                          │          │
│  ┌──────────────────┐          ┌─────────▼────────┐ │
│  │ Network Volume   │          │ Cloudflare R2    │ │
│  │ /runpod-volume/  │          │ (S3 uyumlu)      │ │
│  │ models/          │          │ comfyui-output   │ │
│  └──────────────────┘          └──────────────────┘ │
└─────────────────────────────────────────────────────┘
```

**Akış:**

1. Container başlatılınca `start.sh` çalışır
2. Network Volume'daki modeller → ComfyUI klasörüne symlink edilir
3. ComfyUI arka planda 8188 portunda başlar
4. `handler.py` başlar ve ComfyUI API'nin hazır olmasını bekler
5. İş gelince: giriş resimleri yüklenir, workflow kuyruğa alınır, tamamlanması beklenir
6. Çıktılar Cloudflare R2'ye yüklenir (veya base64 olarak döndürülür)

---

## Özellikler

- ✅ **ReActor Yüz Değiştirme** — InsightFace ile yüksek kaliteli face swap
- ✅ **Video İşleme** — Kare kare yüz değiştirme
- ✅ **Cloudflare R2 Yükleme** — Otomatik çıktı yükleme, imzalı URL'ler
- ✅ **Network Volume Desteği** — Modeller kalıcı depolamada
- ✅ **WebSocket İzleme** — Gerçek zamanlı ilerleme takibi
- ✅ **Otomatik Yeniden Bağlanma** — WebSocket kesintilerinde retry
- ✅ **Hata Yönetimi** — Node seviyesinde detaylı hata mesajları
- ✅ **GIF/Video Çıktı** — ComfyUI'ın `images` ve `gifs` çıktılarını işler

---

## Hızlı Başlangıç

### 1. Docker İmajını Build Et

```bash
docker build -t ghcr.io/KULLANICI_ADI/comfyui-faceswap-worker:latest .
```

### 2. Registry'ye Push Et

```bash
# GHCR'a giriş yap
echo $GITHUB_TOKEN | docker login ghcr.io -u KULLANICI_ADI --password-stdin

# Push et
docker push ghcr.io/KULLANICI_ADI/comfyui-faceswap-worker:latest
```

### 3. RunPod Endpoint Oluştur

1. [RunPod Serverless](https://www.runpod.io/console/serverless) sayfasına git
2. **New Endpoint** tıkla
3. Container image: `ghcr.io/KULLANICI_ADI/comfyui-faceswap-worker:latest`
4. GPU: RTX 3090 veya üstü önerilir
5. Network Volume ekle (modeller için)
6. Ortam değişkenlerini ayarla (aşağıya bak)
7. Execution Timeout: **1200 saniye** (20 dakika önerilir)
8. FlashBoot: **Etkin** (daha hızlı cold start)

### 4. Test İsteği Gönder

```bash
curl -X POST "https://api.runpod.ai/v2/ENDPOINT_ID/runsync" \
  -H "Authorization: Bearer API_KEY" \
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

## Proje Yapısı

```
comfyui-faceswap-worker/
├── Dockerfile           # Tüm bağımlılıklarla multi-stage build
├── handler.py           # Ana RunPod serverless handler (927 satır)
├── start.sh             # Container başlatma scripti
├── README.md            # İngilizce dokümantasyon
├── TR-README.md         # Bu dosya (Türkçe)
├── runpod.json          # RunPod yapılandırma
├── runpod-test.json     # Test payload'u
└── workflows/           # Örnek ComfyUI workflow JSON dosyaları
```

---

## Handler Detayları

`handler.py` dosyası bu worker'ın çekirdeğidir. Bir RunPod serverless işinin tüm yaşam döngüsünü yönetir.

### Temel Sabitler

| Sabit                             | Varsayılan       | Açıklama                                |
| --------------------------------- | ---------------- | --------------------------------------- |
| `COMFY_HOST`                      | `127.0.0.1:8188` | ComfyUI sunucu adresi                   |
| `COMFY_API_AVAILABLE_MAX_RETRIES` | `500`            | ComfyUI hazırlık kontrolü deneme sayısı |
| `COMFY_API_AVAILABLE_INTERVAL_MS` | `50`             | Denemeler arası bekleme (ms)            |
| `WEBSOCKET_RECONNECT_ATTEMPTS`    | `5`              | WebSocket yeniden bağlanma denemesi     |
| `WEBSOCKET_RECONNECT_DELAY_S`     | `3`              | Denemeler arası bekleme (s)             |
| `REFRESH_WORKER`                  | `false`          | Her iş sonrası worker'ı sıfırla         |

### Ana Fonksiyonlar

#### `handler(job)` — Ana Giriş Noktası

RunPod serverless handler fonksiyonu. Her gelen iş için çağrılır.

**Akış:**

1. Girdiyi doğrula (workflow JSON + opsiyonel resimler)
2. ComfyUI API'nin `http://127.0.0.1:8188/` adresinde hazır olup olmadığını kontrol et
3. Giriş resimlerini ComfyUI'ın `/upload/image` endpoint'ine yükle
4. `ws://127.0.0.1:8188/ws?clientId=<uuid>` adresinde WebSocket'e bağlan
5. Workflow'u `/prompt` API'si ile kuyruğa al
6. WebSocket mesajları ile iş takibi yap
7. `/history/<prompt_id>` endpoint'inden çıktıyı al
8. Çıktıları işle (resimler ve videolar/gifler)
9. Cloudflare R2'ye yükle veya base64 olarak kodla
10. Sonucu RunPod'a döndür

#### `validate_input(job_input)` — Girdi Doğrulama

Gelen iş yükünü doğrular:

- `workflow` anahtarı zorunlu
- `images` dizisi formatını kontrol eder (opsiyonel)
- `comfy_org_api_key` varsa çıkarır

**Beklenen Girdi Formatı:**

```json
{
  "workflow": { "ComfyUI API format workflow JSON" },
  "images": [
    {
      "name": "dosya_adi.jpg",
      "image": "base64_kodlanmis_veri"
    }
  ]
}
```

#### `check_server(url, retries, delay)` — Sunucu Sağlık Kontrolü

ComfyUI HTTP API'sini 200 yanıtı alana kadar yoklar.

- Varsayılan: 500 deneme × 50ms = ~25 saniye maksimum bekleme

#### `upload_images(images)` — Resim Yükleme

Base64 kodlanmış resimleri ComfyUI'ın `/upload/image` endpoint'ine yükler.

- Data URI prefix'ini otomatik temizler
- Hem base64 hem HTTP URL destekler

### Çıktı İşleme

Handler, ComfyUI node'larından iki tür çıktı işler:

#### Resimler (`node_output["images"]`)

- Her resim `/view` endpoint'inden indirilir
- `type="temp"` olanlar atlanır
- `BUCKET_ENDPOINT_URL` ayarlıysa → R2'ye yüklenir
- Yoksa → base64 olarak kodlanır

#### Videolar/GIF'ler (`node_output["gifs"]`)

- Resimlerle aynı mantık ama video çıktıları için
- ComfyUI video çıktılarını `gifs` anahtarı altında saklar
- `.mp4`, `.gif`, `.webm` uzantılarını destekler

---

## Network Volume Kurulumu

### Neden Network Volume?

- Modeller (7+ GB) Docker imajına gömülmez
- Daha hızlı cold start (model tekrar indirilmez)
- İmaj yeniden build etmeden kolay model güncelleme

### Kurulum Adımları

1. RunPod Dashboard → **Storage** → Network Volume oluştur
2. **Bölge:** Endpoint'inle aynı bölge olmalı (örn. `EU-CZ-1`)
3. **Geçici Pod oluştur** (volume'u bağlamak için)
4. **Klasörleri oluştur:**
   ```bash
   mkdir -p /workspace/models/{checkpoints,insightface,facerestore_models,upscale_models,clip_vision,ipadapter,controlnet}
   ```
5. **Modelleri indir** (aşağıdaki [Gerekli Modeller](#gerekli-modeller) bölümüne bak)
6. **Endpoint'e bağla:** Edit Endpoint → Advanced → Network Volume seç

### Volume Bağlama Yolu

| Ortam             | Yol               | Açıklama                            |
| ----------------- | ----------------- | ----------------------------------- |
| Serverless Worker | `/runpod-volume/` | Endpoint worker'larında             |
| Geçici Pod        | `/workspace/`     | Pod'larda (aynı volume'a map'lenir) |

---

## Ortam Değişkenleri

### Zorunlu (R2 Yükleme için)

| Değişken                   | Örnek                                   | Açıklama           |
| -------------------------- | --------------------------------------- | ------------------ |
| `BUCKET_ENDPOINT_URL`      | `https://XXXX.r2.cloudflarestorage.com` | R2 endpoint URL'si |
| `BUCKET_ACCESS_KEY_ID`     | `267a26bd...`                           | R2 erişim anahtarı |
| `BUCKET_SECRET_ACCESS_KEY` | `e24414a8...`                           | R2 gizli anahtar   |
| `BUCKET_NAME`              | `comfyui-output`                        | R2 bucket adı      |

### Opsiyonel

| Değişken                       | Varsayılan | Açıklama                          |
| ------------------------------ | ---------- | --------------------------------- |
| `REFRESH_WORKER`               | `false`    | Her iş sonrası worker sıfırlama   |
| `WEBSOCKET_RECONNECT_ATTEMPTS` | `5`        | Maks WS yeniden bağlanma denemesi |
| `WEBSOCKET_RECONNECT_DELAY_S`  | `3`        | Denemeler arası bekleme           |
| `WEBSOCKET_TRACE`              | `false`    | Detaylı WS logları                |
| `NETWORK_VOLUME_DEBUG`         | `false`    | Volume teşhis bilgileri           |

---

## Cloudflare R2 Yapılandırması

### R2 Kurulumu

1. Cloudflare Dashboard → R2'ye git
2. Bucket oluştur: `comfyui-output`
3. Okuma/yazma erişimli API Token oluştur
4. Endpoint URL, erişim anahtarı ve gizli anahtarı not et

### Nasıl Çalışır?

`BUCKET_ENDPOINT_URL` ayarlandığında:

1. Handler çıktıyı geçici dosyaya yazar
2. `rp_upload.upload_image()` ile R2'ye yükler
3. `BUCKET_NAME` env var'ından bucket adını alır
4. 7 gün geçerli imzalı URL döndürür
5. Geçici dosya yükleme sonrası silinir

`BUCKET_ENDPOINT_URL` ayarlanmamışsa:

- Çıktılar yanıtta base64 kodlanmış metin olarak döndürülür
- ⚠️ Büyük videolar RunPod'un yanıt boyutu sınırlarını aşabilir

---

## RunPod Endpoint Ayarları

### Önerilen Ayarlar

| Ayar              | Değer           | Neden                                |
| ----------------- | --------------- | ------------------------------------ |
| GPU               | RTX 3090 (24GB) | SDXL + ReActor ~16GB VRAM gerektirir |
| Execution Timeout | 1200s (20 dk)   | Video işleme 5-10 dk sürebilir       |
| FlashBoot         | Etkin           | Cold start'ı ~2 saniyeye düşürür     |
| Max Workers       | 2               | Talebe göre ayarla                   |
| Active Workers    | 0               | Boştayken sıfıra ölçekle             |
| Network Volume    | Bağlı           | Modeller için gerekli                |

### Güncelleme Yayınlama

Yeni Docker imajı push ettikten sonra:

1. Endpoint → **Manage** → **New Release** tıkla
2. Worker'ların yeni imajı çekmesini bekle
3. Versiyon numarası otomatik artar
4. Eski worker'lar yeni imajı almıyorsa sil

---

## İstek Gönderme

### Basit Resim Face Swap

```python
import requests
import base64

API_KEY = "runpod_api_anahtarin"
ENDPOINT_ID = "endpoint_id"

# Kaynak yüzü oku ve kodla
with open("yuz.jpg", "rb") as f:
    yuz_b64 = base64.b64encode(f.read()).decode()

# Hedef resmi oku ve kodla
with open("hedef.jpg", "rb") as f:
    hedef_b64 = base64.b64encode(f.read()).decode()

payload = {
    "input": {
        "workflow": { ... },  # ComfyUI API format workflow
        "images": [
            {"name": "source_face.jpg", "image": yuz_b64},
            {"name": "target.jpg", "image": hedef_b64}
        ]
    }
}

response = requests.post(
    f"https://api.runpod.ai/v2/{ENDPOINT_ID}/run",
    headers={"Authorization": f"Bearer {API_KEY}"},
    json=payload
)

job_id = response.json()["id"]
print(f"İş gönderildi: {job_id}")
```

### İş Durumu Kontrolü

```python
durum = requests.get(
    f"https://api.runpod.ai/v2/{ENDPOINT_ID}/status/{job_id}",
    headers={"Authorization": f"Bearer {API_KEY}"}
)

sonuc = durum.json()
if sonuc["status"] == "COMPLETED":
    resimler = sonuc["output"]["images"]
    for img in resimler:
        if img["type"] == "s3_url":
            print(f"İndir: {img['data']}")
        elif img["type"] == "base64":
            data = base64.b64decode(img["data"])
            with open(img["filename"], "wb") as f:
                f.write(data)
```

---

## Dahil Edilen Custom Node'lar

| Node                            | Amaç                                |
| ------------------------------- | ----------------------------------- |
| **ComfyUI-ReActor**             | InsightFace ile yüz değiştirme      |
| **comfyui-ipadapter-plus**      | IP-Adapter ile stil/yüz transferi   |
| **comfyui-videohelpersuite**    | Video yükleme ve kaydetme           |
| **comfyui-animatediff-evolved** | AnimateDiff ile video üretimi       |
| **comfyui-frame-interpolation** | Kare interpolasyonu (FILM/RIFE)     |
| **comfyui-ultimatesdupscale**   | Ultimate SD Upscale                 |
| **comfyui-impact-pack**         | Algılama, segmentasyon, iyileştirme |
| **comfyui-advanced-controlnet** | Gelişmiş ControlNet                 |
| **comfyui-kjnodes**             | Yardımcı node'lar                   |
| **comfyui-essentials**          | Temel yardımcı node'lar             |
| **was-node-suite-comfyui**      | 220+ yardımcı node                  |

---

## Gerekli Modeller

Network Volume'da `/runpod-volume/models/` altında sakla:

| Model                | Yol                                                       | Boyut  |
| -------------------- | --------------------------------------------------------- | ------ |
| SD XL Base 1.0       | `checkpoints/sd_xl_base_1.0.safetensors`                  | 6.9 GB |
| inswapper_128        | `insightface/inswapper_128.onnx`                          | 554 MB |
| GFPGANv1.3           | `facerestore_models/GFPGANv1.3.pth`                       | 348 MB |
| GFPGANv1.4           | `facerestore_models/GFPGANv1.4.pth`                       | 348 MB |
| CodeFormer           | `facerestore_models/codeformer-v0.1.0.pth`                | 376 MB |
| 4x-UltraSharp        | `upscale_models/4x-UltraSharp.pth`                        | 67 MB  |
| RealESRGAN x4+       | `upscale_models/RealESRGAN_x4plus.pth`                    | 67 MB  |
| CLIP-ViT-H-14        | `clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 3.9 GB |
| IP-Adapter Plus Face | `ipadapter/ip-adapter-plus-face_sdxl_vit-h.safetensors`   | 847 MB |
| Canny Mid            | `controlnet/diffusers_xl_canny_mid.safetensors`           | 2.5 GB |
| Depth Mid            | `controlnet/diffusers_xl_depth_mid.safetensors`           | 2.5 GB |

---

## Sorun Giderme

### "Failed to connect to server at http://127.0.0.1:8188/ after 500 attempts"

**Neden:** ComfyUI başlamıyor. `start.sh`'ın handler'dan önce ComfyUI'ı başlatmaması durumunda oluşur.

**Çözüm:** `start.sh`'ın şu satırları içerdiğinden emin ol:

```bash
cd /comfyui
python main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch &
```

### "NoSuchBucket" R2 Hatası

**Neden:** `BUCKET_NAME` ortam değişkeni ayarlı değil veya yanlış.

**Çözüm:** RunPod endpoint ortam değişkenlerine `BUCKET_NAME=comfyui-output` ekle.

### Worker "Throttled" Durumunda Takılıyor

**Neden:** Worker sağlık kontrollerini çok kez geçemedi.

**Çözüm:**

1. Throttled worker'ları sil
2. Container loglarını kontrol et
3. Devam ederse: Manage → New Release yap

### Execution Timeout

**Neden:** Varsayılan timeout (600s) video işleme için çok kısa.

**Çözüm:** Endpoint ayarlarında 1200s (20 dk) yap.

---

## Bilinen Sorunlar

### 1. Video Çıktısı Masaüstüne İndirilmiyor

**Durum:** Açık

Yerel ComfyUI'da RunPod Worker node'u kullanılırken işlenen **video dosyası otomatik olarak yerel makineye kaydedilmiyor**. Video kareleri (tekil PNG'ler) Cloudflare R2'ye başarıyla yükleniyor, fakat birleştirilmiş video çıktısı masaüstüne indirilemiyor.

**Geçici Çözüm:**

- Videoyu doğrudan Cloudflare R2 bucket'ından indir
- API yanıtındaki imzalı URL'leri kullan

### 2. NSFW Algılama Modeli Her Cold Start'ta İndiriliyor

ReActor ilk çalıştırmada ~328 MB NSFW algılama modeli indiriyor. Container içinde cache'leniyor ama cold start'ta kayboluyor.

### 3. AnimateDiff Motion Modelleri Bulunamıyor

Loglarda uyarı: `No motion models found`. Face swap workflow'larını etkilemiyor ama animasyon workflow'larını etkiler.

---

## Build ve Deploy

### Tam Build & Push

```bash
# Build
docker build -t ghcr.io/KULLANICI_ADI/comfyui-faceswap-worker:latest .

# GHCR'a giriş
echo $GITHUB_TOKEN | docker login ghcr.io -u KULLANICI_ADI --password-stdin

# Push
docker push ghcr.io/KULLANICI_ADI/comfyui-faceswap-worker:latest
```

### Push Sonrası

1. RunPod → Endpoint → **Manage** → **New Release**
2. Worker'ların yeni versiyon numarasını göstermesini bekle
3. Eski worker'lar güncelenmiyorsa sil
4. Önce basit bir workflow ile test et
