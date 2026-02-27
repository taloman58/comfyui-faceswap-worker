"""
handler.py'yi patch'ler: video/gif ciktilari da toplanir.

RunPod worker-comfyui'nin handler.py dosyasi sadece "images" key'ini isler.
VHS_VideoCombine gibi node'lar "gifs" key'i altinda video uretir.
Bu patch "gifs" key'ini de "images" gibi isleyerek video ciktilarini dondurur.
"""
import re

HANDLER_PATH = "/handler.py"

# Orijinal kod: sadece "images" key'ini kontrol eder
OLD_BLOCK = '''            # Check for other output types
            other_keys = [k for k in node_output.keys() if k != "images"]
            if other_keys:
                warn_msg = (
                    f"Node {node_id} produced unhandled output keys: {other_keys}."
                )
                print(f"worker-comfyui - WARNING: {warn_msg}")
                print(
                    f"worker-comfyui - --> If this output is useful, please consider opening an issue on GitHub to discuss adding support."
                )'''

# Yeni kod: "gifs" key'ini de isler (video/gif dosyalari)
NEW_BLOCK = '''            # Handle "gifs" output (VHS_VideoCombine video/gif files)
            if "gifs" in node_output:
                print(
                    f"worker-comfyui - Node {node_id} contains {len(node_output['gifs'])} gif/video(s)"
                )
                for gif_info in node_output["gifs"]:
                    filename = gif_info.get("filename")
                    subfolder = gif_info.get("subfolder", "")
                    gif_type = gif_info.get("type")

                    if gif_type == "temp":
                        print(
                            f"worker-comfyui - Skipping gif {filename} because type is 'temp'"
                        )
                        continue

                    if not filename:
                        warn_msg = f"Skipping gif in node {node_id} due to missing filename: {gif_info}"
                        print(f"worker-comfyui - {warn_msg}")
                        errors.append(warn_msg)
                        continue

                    gif_bytes = get_image_data(filename, subfolder, gif_type)

                    if gif_bytes:
                        if os.environ.get("BUCKET_ENDPOINT_URL"):
                            try:
                                file_extension = os.path.splitext(filename)[1] or ".mp4"
                                with tempfile.NamedTemporaryFile(
                                    suffix=file_extension, delete=False
                                ) as temp_file:
                                    temp_file.write(gif_bytes)
                                    temp_file_path = temp_file.name
                                print(f"worker-comfyui - Uploading gif {filename} to S3...")
                                s3_url = rp_upload.upload_image(job_id, temp_file_path)
                                os.remove(temp_file_path)
                                output_data.append(
                                    {
                                        "filename": filename,
                                        "type": "s3_url",
                                        "data": s3_url,
                                    }
                                )
                            except Exception as e:
                                error_msg = f"Error uploading gif {filename} to S3: {e}"
                                print(f"worker-comfyui - {error_msg}")
                                errors.append(error_msg)
                        else:
                            try:
                                base64_gif = base64.b64encode(gif_bytes).decode("utf-8")
                                output_data.append(
                                    {
                                        "filename": filename,
                                        "type": "base64",
                                        "data": base64_gif,
                                    }
                                )
                                print(f"worker-comfyui - Encoded gif {filename} as base64")
                            except Exception as e:
                                error_msg = f"Error encoding gif {filename} to base64: {e}"
                                print(f"worker-comfyui - {error_msg}")
                                errors.append(error_msg)
                    else:
                        error_msg = f"Failed to fetch gif data for {filename} from /view endpoint."
                        errors.append(error_msg)

            # Check for other output types
            other_keys = [k for k in node_output.keys() if k not in ("images", "gifs")]
            if other_keys:
                warn_msg = (
                    f"Node {node_id} produced unhandled output keys: {other_keys}."
                )
                print(f"worker-comfyui - WARNING: {warn_msg}")
                print(
                    f"worker-comfyui - --> If this output is useful, please consider opening an issue on GitHub to discuss adding support."
                )'''

with open(HANDLER_PATH, "r") as f:
    content = f.read()

if OLD_BLOCK in content:
    content = content.replace(OLD_BLOCK, NEW_BLOCK)
    with open(HANDLER_PATH, "w") as f:
        f.write(content)
    print("PATCH BASARILI: handler.py'ye video/gif destegi eklendi!")
else:
    print("UYARI: Patch noktasi bulunamadi, handler.py zaten patch'lenmis olabilir.")
    print("handler.py icerigi kontrol ediliyor...")
    if "gifs" in content:
        print("OK: handler.py zaten gif destegi iceriyor.")
    else:
        print("HATA: handler.py beklenmeyen formatta.")
