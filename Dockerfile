# clean base image containing only comfyui, comfy-cli and comfyui-manager
FROM runpod/worker-comfyui:5.5.1-base

# Update ComfyUI from 0.3.68 to v0.11.0 for Z-Image/Qwen3 CLIP support
# v0.11.0 adds: zimage omni (#11979), Qwen3 config (#11998), regular z-image (#11985)
# NOTE: Do NOT use 'git pull origin master' - latest crashes with pinned custom nodes.
RUN cd /comfyui && git remote set-url origin https://github.com/Comfy-Org/ComfyUI.git && \
    git fetch origin --tags && git checkout v0.11.0 && \
    pip install -r requirements.txt && \
    pip install --upgrade comfy-cli && \
    comfy --skip-prompt set-default /comfyui

# install custom nodes into comfyui (first node with --mode remote to fetch updated cache)
RUN comfy node install --exit-on-fail seedvr2_videoupscaler@2.5.24 --mode remote
RUN comfy node install --exit-on-fail was-node-suite-comfyui@1.0.2
RUN comfy node install --exit-on-fail comfyui-kjnodes@1.2.9
RUN comfy node install --exit-on-fail seedvarianceenhancer@2.2.0
RUN comfy node install --exit-on-fail comfyui-impact-subpack@1.3.5
RUN comfy node install --exit-on-fail comfyui-impact-pack@8.28.2
RUN comfy node install --exit-on-fail rgthree-comfy@1.0.2512112053
RUN comfy node install --exit-on-fail comfyui-image-saver@1.21.0
RUN comfy node install --exit-on-fail comfyui-easy-use@1.3.6
RUN comfy node install --exit-on-fail efficiency-nodes-comfyui@1.0.8
# The following custom node groups were listed but could not be resolved via the ComfyUI registry or have no aux_id (GitHub repo) provided:
# - unknown_registry: Fast Groups Bypasser (rgthree), Reroute (no aux_id provided; skipped)
# - chibi (registryStatus=false; no aux_id provided; skipped)
# - comfyroll (registryStatus=false; no aux_id provided; skipped)
RUN cd /comfyui/custom_nodes && git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git

# Add extra model search paths for network volume root directory
# The old endpoint symlinked ALL model types (clip, unet, diffusion_models, checkpoints)
# to the root /runpod-volume/models/ directory. The new worker only searches type-specific
# subdirs (e.g. /runpod-volume/models/clip). Z-Image models live at /runpod-volume/models/z_image/
# and ZIT checkpoints at /runpod-volume/models/ZIT/ - both under the ROOT, not under subdirs.
# This yaml adds the root as an additional search path so those models are found.
RUN printf '\nnetwork_volume_root:\n    base_path: /runpod-volume/models\n    checkpoints: .\n    diffusion_models: .\n    clip: .\n    unet: .\n    vae: .\n    ultralytics: ultralytics\n\nnetwork_volume_loras_bbox:\n    base_path: /runpod-volume/models/loras\n    ultralytics: .\n\nnetwork_volume_comfyui_models:\n    base_path: /runpod-volume/ComfyUI/models\n    ultralytics: ultralytics\n\nnetwork_volume_slim_models:\n    base_path: /runpod-volume/runpod-slim/ComfyUI/models\n    ultralytics: ultralytics\n' >> /comfyui/extra_model_paths.yaml

# Fix Eyes.pt: Impact Pack only scans /comfyui/models/ultralytics/bbox (ignores extra_model_paths)
# Create symlink to network volume location (resolves at runtime when volume is mounted)
RUN ln -sf /runpod-volume/models/ultralytics/bbox/Eyes.pt /comfyui/models/ultralytics/bbox/Eyes.pt

# Add Eyes.pt to Impact Subpack whitelist for safe .pt file loading
RUN mkdir -p /comfyui/user/default/ComfyUI-Impact-Subpack && \
    echo "Eyes.pt" > /comfyui/user/default/ComfyUI-Impact-Subpack/model-whitelist.txt

# download models into comfyui
# ae.safetensors requires HF auth (FLUX.1-schnell is gated) - rely on network volume copy
# RUN comfy model download --url https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors --relative-path models/vae --filename ae.safetensors
RUN comfy model download --url https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth --relative-path models/sams --filename sam_vit_b_01ec64.pth
RUN comfy model download --url https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n.pt --relative-path models/ultralytics/bbox --filename face_yolov8n.pt
RUN comfy model download --url https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors --relative-path models/vae --filename ema_vae_fp16.safetensors
# RUN # Could not find URL for ZIT\2601\2601_NSFW_ZIT_BSY_bf16.safetensors
# RUN # Could not find URL for ZIT\qwen_3_4b.safetensors
# RUN # Could not find URL for seedvr2_ema_7b_sharp_fp8_e4m3fn_mixed_block35_fp16.safetensors
# RUN # Could not find URL for bbox/Eyes.pt

# copy all input data (like images or videos) into comfyui (uncomment and adjust if needed)
# COPY input/ /comfyui/input/
