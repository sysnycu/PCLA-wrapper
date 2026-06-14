# Deployment

## Image Contract

`common-slim` is the base deployment image:

- Ubuntu 24.04
- CARLA 0.9.16 server and CPython 3.8 API
- Python 3.8.18 in `/opt/pcla-venv`
- PyTorch 2.2.0+cu121
- Plant 1.0, Plant 2.0, CaRL, and Roach dependencies
- no Conda environment or complete CUDA toolkit

Build it with:

```bash
git submodule update --init --recursive
docker build --target common-slim -t pcla-wrapper:common-slim .
```

The runtime dependency layers are before `COPY . /app`, so source-only changes
reuse the Python package cache. `.dockerignore` excludes pretrained assets,
runtime map caches, logs, and generated files.

## Slim And Bundled

Use `common-slim` during development. Mount a common weight root read-only:

```bash
-v /host/pcla-common-weights:/opt/pcla-pretrained:ro
```

For CI or a portable release, stage and bundle the selected profile:

```bash
python3 scripts/prepare_weight_profile.py \
  --profile common \
  --source /host/PCLA/pcla_agents \
  --output /tmp/pcla-common-weights

docker build \
  -f docker/Dockerfile.bundled \
  --build-arg BASE_IMAGE=pcla-wrapper:common-slim \
  -t pcla-wrapper:common-bundled \
  /tmp/pcla-common-weights
```

The bundled Dockerfile copies weights only after the runtime image is complete.
Application/dependency rebuilds therefore remain independent of the large
weight layer, and unchanged weights are reusable from Docker's cache.

## Internal CARLA

The default configuration launches `/app/carla_server.sh`. Run with the NVIDIA
container runtime:

```bash
docker run --rm --gpus all --network host \
  -e DISPLAY \
  -e CARLA_HOME=/mnt/output/.carla-home \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v "$HOME/.Xauthority":/home/carla/.Xauthority:ro \
  -v /host/maps:/mnt/map/xodr:ro \
  -v /host/output:/mnt/output \
  -v /host/pcla-common-weights:/opt/pcla-pretrained:ro \
  pcla-wrapper:common-slim
```

Remove the weight mount when using `common-bundled`.

The common images default to `CARLA_NULLRHI=1` because their supported agents
do not use RGB camera input. Set `CARLA_NULLRHI=0` only when a rendered CARLA
process is required; rendered mode may also require X11 and Vulkan access.

CARLA logs are written below
`<InitRequest.output_dir>/carla_server/`. The server is started once and reused
across Reset calls. Stop removes agent sensors and dynamic actors without
terminating the server.

The output volume must be writable because it also holds CARLA navigation and
XDG caches. When using `--user`, set a writable `CARLA_HOME`.

## External CARLA

Set:

```yaml
launch_carla_server: false
```

Then provide `CARLA_HOST`, `CARLA_PORT`, and a compatible CARLA 0.9.16 server.
The wrapper never terminates an external server.

## Ports

- `PORT`: PISA AV gRPC service, default `50051`
- `CARLA_PORT`: CARLA RPC, default `2000`
- `CARLA_TM_PORT`: TrafficManager, default `8000`

## CI

The standard workflow runs formatting and fake-based unit tests on GitHub-hosted
runners. `.github/workflows/common-runtime.yml` is a manual workflow for a
self-hosted runner labelled `gpu`. It builds `common-slim`, checks the mounted
weights, loads one model from each priority family, builds `common-bundled`, and
validates the bundled result.
