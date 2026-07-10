"""
Draw Things gRPC JSON-over-stdio CLI entrypoint for Front Porch AI.

This is a thin wrapper around the rich client.py (kept 100% untouched).
Protocol matches whisper_stt.py / kokoro_tts.py style:
  - One JSON request on stdin
  - One JSON response on stdout
  - Errors to stderr + non-zero exit

Ops supported:
  test:    {"op":"test","host":"127.0.0.1","port":7859}
  models:  {"op":"models","host":"...","port":7859}
  loras:   {"op":"loras","host":"...","port":7859}
  generate:{"op":"generate","host":"...","port":7859,
            "prompt":"...","negative_prompt":"",
            "config":{...GenerationConfig fields as dict (enums as int);
                      "loras":[{"file":"...","weight":0.8}] optional...},
            "reference_image_path":"/abs/path/to/ref.png" (optional),
            "output_path":"/abs/path/for/result.png" (optional)}

Response shapes:
  success: {"success":true, "output_path": "...", "elapsed":12.3, "file_size":12345}
  error:   {"success":false, "error":"..." }
"""

import contextlib
import io
import re
import sys
import json
import os
import tempfile
import time
from pathlib import Path

# Make sibling imports (client.py + generated pb2) work whether run as script or bundled
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from client import DrawThingsClient, GenerationConfig, LoRAConfig, Sampler, SeedMode
except ImportError as e:
    print(json.dumps({"success": False, "error": f"Import failed (client.py or deps): {e}"}), flush=True)
    sys.exit(1)

# pb2 only needed for the legacy "Echo(name='models')" listing hack used by Draw Things
try:
    import imageService_pb2 as pb2
except ImportError:
    pb2 = None


def _build_generation_config(cfg: dict) -> GenerationConfig:
    """Map a JSON dict (from Dart) into GenerationConfig dataclass.
    Enum values are passed as ints (0-18 for sampler, 0-3 for seed_mode).
    Unknown keys are ignored (dataclass has defaults for everything else).
    """
    # Allow friendly string names for sampler in addition to ints (future-proof)
    sampler_val = cfg.get("sampler", Sampler.DDIM_TRAILING)
    if isinstance(sampler_val, str):
        # Map common friendly names (case-insensitive, with/without _TRAILING)
        name = sampler_val.upper().replace(" ", "_")
        sampler_map = {
            "DDIM_TRAILING": Sampler.DDIM_TRAILING,
            "DDIM": Sampler.DDIM,
            "UNIPC_TRAILING": Sampler.UNIPC_TRAILING,
            "UNIPC": Sampler.UNIPC,
            "EULER_A_TRAILING": Sampler.EULER_A_TRAILING,
            "EULER_A": Sampler.EULER_A,
            "DPMPP2M_KARRAS": Sampler.DPMPP2M_KARRAS,
            "DPMPP_SDE_KARRAS": Sampler.DPMPP_SDE_KARRAS,
            "DPMPP2M_AYS": Sampler.DPMPP2M_AYS,
            "DPMPP_SDE_AYS": Sampler.DPMPP_SDE_AYS,
            "DPMPP_SDE_TRAILING": Sampler.DPMPP_SDE_TRAILING,
            "DPMPP2M_TRAILING": Sampler.DPMPP2M_TRAILING,
            "UNIPC_AYS": Sampler.UNIPC_AYS,
            "EULER_A_AYS": Sampler.EULER_A_AYS,
            "EULER_A_SUBSTEP": Sampler.EULER_A_SUBSTEP,
            "DPMPP_SDE_SUBSTEP": Sampler.DPMPP_SDE_SUBSTEP,
            "TCD": Sampler.TCD,
            "LCM": Sampler.LCM,
            "PLMS": Sampler.PLMS,
        }
        sampler_val = sampler_map.get(name, Sampler.DDIM_TRAILING)

    seed_mode_val = cfg.get("seed_mode", SeedMode.SCALE_ALIKE)
    if isinstance(seed_mode_val, str):
        sm_name = seed_mode_val.upper().replace(" ", "_")
        sm_map = {
            "SCALE_ALIKE": SeedMode.SCALE_ALIKE,
            "LEGACY": SeedMode.LEGACY,
            "TORCH_CPU": SeedMode.TORCH_CPU,
            "NVIDIA_GPU": SeedMode.NVIDIA_GPU,
        }
        seed_mode_val = sm_map.get(sm_name, SeedMode.SCALE_ALIKE)

    # LoRAs: list of {"file": str, "weight": float, "mode": int} dicts from Dart.
    # Draw Things applies them natively (unlike A1111's <lora:...> prompt tags).
    loras = []
    for entry in cfg.get("loras") or []:
        if not isinstance(entry, dict):
            continue
        lora_file = str(entry.get("file") or "").strip()
        if not lora_file:
            continue
        try:
            weight = float(entry.get("weight", 1.0))
        except (TypeError, ValueError):
            weight = 1.0
        try:
            mode = int(entry.get("mode", 0))  # 0=All, 1=Base, 2=Refiner
        except (TypeError, ValueError):
            mode = 0
        loras.append(LoRAConfig(file=lora_file, weight=weight, mode=mode))

    return GenerationConfig(
        model=cfg.get("model", ""),
        refiner_model=cfg.get("refiner_model", ""),
        start_width=int(cfg.get("start_width", 16)),
        start_height=int(cfg.get("start_height", 16)),
        seed=int(cfg.get("seed", 0)),
        steps=int(cfg.get("steps", 20)),
        guidance_scale=float(cfg.get("guidance_scale", cfg.get("cfg_scale", 7.0))),
        strength=float(cfg.get("strength", 1.0)),
        shift=float(cfg.get("shift", 1.0)),
        sampler=int(sampler_val),
        seed_mode=int(seed_mode_val),
        tea_cache=bool(cfg.get("tea_cache", False)),
        tea_cache_threshold=float(cfg.get("tea_cache_threshold", 0.15)),
        tea_cache_start=int(cfg.get("tea_cache_start", 2)),
        tea_cache_end=int(cfg.get("tea_cache_end", -1)),
        tea_cache_max_skip_steps=int(cfg.get("tea_cache_max_skip_steps", 3)),
        cfg_zero_star=bool(cfg.get("cfg_zero_star", False)),
        causal_inference_enabled=bool(cfg.get("causal_inference_enabled", False)),
        causal_inference=int(cfg.get("causal_inference", 3)),
        resolution_dependent_shift=bool(cfg.get("resolution_dependent_shift", False)),
        mask_blur=float(cfg.get("mask_blur", 1.5)),
        sharpness=float(cfg.get("sharpness", 0.0)),
        loras=loras,
    )


def main():
    raw = sys.stdin.readline()
    if not raw:
        print(json.dumps({"success": False, "error": "No input on stdin"}), flush=True)
        sys.exit(1)

    line = raw.strip()
    if not line:
        print(json.dumps({"success": False, "error": "Empty request"}), flush=True)
        sys.exit(1)

    try:
        req = json.loads(line)
    except json.JSONDecodeError as e:
        print(json.dumps({"success": False, "error": f"Invalid JSON: {e}"}), flush=True)
        sys.exit(1)

    op = (req.get("op") or "").lower()
    host = req.get("host") or "127.0.0.1"
    try:
        port = int(req.get("port", 7859))
    except (TypeError, ValueError):
        port = 7859

    client = None
    try:
        client = DrawThingsClient(host, port)

        if op == "test":
            try:
                _ = client.echo("ping-from-frontporch")
                print(json.dumps({"success": True}), flush=True)
                sys.exit(0)
            except Exception as e:
                print(json.dumps({"success": False, "error": f"gRPC connect/test failed: {e}"}), flush=True)
                sys.exit(1)

        elif op in ("models", "loras"):
            if pb2 is None:
                print(json.dumps({"success": False, "error": "pb2 module not importable (grpc generated files missing)"}), flush=True)
                sys.exit(1)
            try:
                client._connect()
                # Draw Things special-case: Echo(name='models') returns a response with .files
                # (one flat list of everything DT knows about — checkpoints, LoRAs, VAEs, …).
                # op "models" filters that list down to plausible checkpoints; op "loras"
                # filters the same list down to LoRA files instead.
                response = client._stub.Echo(pb2.EchoRequest(name="models"))
                raw_files = getattr(response, "files", []) or []
                if op == "loras":
                    loras = [str(f) for f in raw_files if "lora" in str(f).lower()]
                    print(json.dumps({"success": True, "loras": loras}), flush=True)
                    sys.exit(0)
                # Heuristic filter to show only plausible main diffusion checkpoints.
                # Draw Things' raw model list contains everything (VAEs, encoders,
                # ControlNets, upscalers, preprocessors, LoRAs, video models, etc.).
                # We use broad category patterns instead of blacklisting individual files.
                # Text encoders / CLIP / T5 / LLM sidecars. These skip a file
                # ONLY when it lacks an image-model marker: modern checkpoints
                # carry their LLM family name AND "image" (qwen_image_*.ckpt,
                # z_image_*, ernie_image_*), while their encoder sidecars never
                # do (qwen_2.5_vl_*, ministral_3_3b_*, t5_xxl_*). A blanket
                # "qwen" ban used to hide the Qwen-Image checkpoint itself.
                encoder_keywords = [
                    "clip", "t5", "text_encoder", "encoder", "gemma", "llama",
                    "mistral", "ministral", "qwen", "phi", "vicuna", "alpaca",
                ]
                skip_keywords = [
                    # VAEs (catches most custom VAEs without naming each one)
                    "vae",

                    # Safety / NSFW filters
                    "safety",

                    # LoRAs
                    "lora",

                    # ControlNet + common preprocessors / pose / depth / lineart etc.
                    "controlnet", "openpose", "dwpose", "pose", "depth", "canny",
                    "normal", "lineart", "softedge", "seg", "inpaint", "ip2p",
                    "shuffle", "mlsd", "tile", "blur", "hed", "parsenet",

                    # Upscalers / face restorers (4x_ultrasharp, realesrgan, etc.)
                    "4x_", "2x_", "realesrgan", "esrgan", "ultrasharp", "swinir",
                    "hat_", "real_esrgan", "upscaler", "restoreformer", "gfpgan",
                    "codeformer",

                    # Video / I2V / motion models (these are not for regular img2img)
                    "i2v", "video", "wan_", "svd", "motion", "ltx",
                ]
                models = []
                for f in raw_files:
                    lower = str(f).lower()
                    if any(k in lower for k in skip_keywords):
                        continue
                    if "image" not in lower and any(
                        k in lower for k in encoder_keywords
                    ):
                        continue
                    # Return anything that survived the skip list.
                    # Draw Things Echo("models") can return bare names, full paths,
                    # or names with various extensions (.safetensors, .ckpt, .pth, etc.).
                    # We no longer require specific extensions here; the caller (UI)
                    # presents them as the checkpoint picker. Over-filtering was
                    # the main reason users saw an empty list after a successful Test.
                    models.append(str(f))
                print(json.dumps({"success": True, "models": models}), flush=True)
                sys.exit(0)
            except Exception as e:
                print(json.dumps({"success": False, "error": f"Model list failed: {e}"}), flush=True)
                sys.exit(1)

        elif op == "generate":
            prompt = req.get("prompt") or ""
            negative = req.get("negative_prompt") or ""
            ref_image_path = req.get("reference_image_path")
            user_out = req.get("output_path")
            cfg_dict = req.get("config") or {}

            # Basic safety for the internal reference_image_path field (prevent obvious arbitrary file read via the JSON protocol)
            if ref_image_path:
                rp = os.path.abspath(os.path.expanduser(ref_image_path))
                tmp_roots = [os.path.abspath(tempfile.gettempdir()), os.path.abspath("/tmp"), os.path.abspath(os.path.expanduser("~/Library/Caches"))]
                if not any(rp.startswith(r) for r in tmp_roots if r):
                    # Log but do not hard-fail in dev; production bundles are the real path
                    print(json.dumps({"success": False, "error": "reference_image_path must be under a temporary directory"}), flush=True)
                    sys.exit(1)

            gcfg = _build_generation_config(cfg_dict)

            # Decide output location (CLI owns a temp if caller didn't provide)
            if user_out:
                out_path = user_out
                Path(out_path).parent.mkdir(parents=True, exist_ok=True)
            else:
                fd, out_path = tempfile.mkstemp(suffix=".png", prefix="dtgen_")
                os.close(fd)

            start = time.time()
            # Live step progress WITHOUT touching client.py: its verbose mode
            # prints "  Step N..." per sampling signpost to stdout. Stdout is
            # reserved for the final JSON, so route those prints through a
            # scanner that forwards them to STDERR as "FP_PROGRESS <N>" lines
            # (the Dart side streams stderr and turns them into a progress
            # bar) and swallows the rest of the verbose chatter.
            step_re = re.compile(r"^\s*Step (\d+)\.\.\.")

            class _ProgressScanner(io.TextIOBase):
                def write(self, text):
                    for line in str(text).splitlines():
                        m = step_re.match(line)
                        if m:
                            print(f"FP_PROGRESS {m.group(1)}",
                                  file=sys.stderr, flush=True)
                    return len(text)

            with contextlib.redirect_stdout(_ProgressScanner()):
                result = client.generate(
                    config=gcfg,
                    prompt=prompt,
                    negative_prompt=negative,
                    image_path=ref_image_path,
                    scale_factor=1,
                    verbose=True,
                )
            elapsed = result.elapsed_seconds if hasattr(result, "elapsed_seconds") else (time.time() - start)

            if not result.images:
                print(json.dumps({"success": False, "error": "Generation produced no images"}), flush=True)
                sys.exit(1)

            # save() decodes NNC if necessary and writes PNG.
            # verbose=False so we don't pollute stdout with "Saved:" messages
            # (the Dart side expects clean JSON on stdout for machine use).
            result.save(out_path, verbose=False)

            if not os.path.exists(out_path):
                print(json.dumps({"success": False, "error": f"Output file was not written: {out_path}"}), flush=True)
                sys.exit(1)

            fsize = os.path.getsize(out_path)
            print(json.dumps({
                "success": True,
                "output_path": out_path,
                "elapsed": round(elapsed, 3),
                "file_size": fsize,
            }), flush=True)
            sys.exit(0)

        else:
            print(json.dumps({"success": False, "error": f"Unknown op '{op}' (expected test/models/loras/generate)"}), flush=True)
            sys.exit(1)

    except Exception as e:
        # Full error to stderr for logs; structured to stdout
        err = str(e)
        print(json.dumps({"success": False, "error": err}), flush=True)
        # Also dump to stderr for flutter run logs
        print(f"dt_grpc_client error: {err}", file=sys.stderr, flush=True)
        sys.exit(1)
    finally:
        if client is not None:
            try:
                client.close()
            except Exception:
                pass


if __name__ == "__main__":
    main()
