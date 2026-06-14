# Default host directory containing plant_pretrained, plant2_pretrained, and
# carl_pretrained. Override it on recipes that accept a weights parameter.
common_weights := "/opt/pcla-pretrained"

# Build the common runtime without model weights.
build-common-slim:
    docker build --target common-slim -t pcla-wrapper:common-slim .

# Stage only common-profile weights for a bundled build.
prepare-common-weights output="/tmp/pcla-common-weights" source="PCLA/pcla_agents":
    python3 scripts/prepare_weight_profile.py \
        --profile common \
        --source "{{source}}" \
        --output "{{output}}"

# Add staged common weights to common-slim and build a self-contained image.
build-common-bundled weights="/tmp/pcla-common-weights":
    docker build \
        -f docker/Dockerfile.bundled \
        --build-arg BASE_IMAGE=pcla-wrapper:common-slim \
        -t pcla-wrapper:common-bundled \
        "{{weights}}"

# Validate common-slim dependencies and every common checkpoint.
validate-common-slim weights=common_weights:
    docker run --rm --gpus all \
        -v "{{weights}}:/opt/pcla-pretrained:ro" \
        pcla-wrapper:common-slim \
        /app/scripts/validate_common_runtime.py --check-weights

# Load one agent and checkpoint without starting CARLA.
smoke-common-agent agent weights=common_weights:
    docker run --rm --gpus all \
        -v "{{weights}}:/opt/pcla-pretrained:ro" \
        pcla-wrapper:common-slim \
        /app/scripts/smoke_common_agent.py "{{agent}}"

# Build and run common-slim with the local TYMS map directory.
run_t: build-common-slim
    docker run --gpus all --rm \
    --network host -it \
    -v /opt/sbsvf/map/tyms/xodr:/mnt/map/xodr \
    -v {{common_weights}}:/opt/pcla-pretrained:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/.Xauthority:/root/.Xauthority \
    -e DISPLAY pcla-wrapper:common-slim

# Build and run common-slim with the local Frankenburg map directory.
run_f: build-common-slim
    docker run --gpus all --rm \
    --network host -it \
    -v /opt/sbsvf/map/frankenburg/xodr:/mnt/map/xodr \
    -v {{common_weights}}:/opt/pcla-pretrained:ro \
    -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/.Xauthority:/root/.Xauthority \
    -e DISPLAY pcla-wrapper:common-slim
