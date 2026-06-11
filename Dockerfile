FROM sys511613/pcla@sha256:698fb44c2b9b3a142304f37761a8c1c05dd7cf0a2983736657980c577e72326d AS pcla-runtime
FROM docker.io/tonychi/carla:0.9.16 AS carla-runtime

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN groupmod --new-name carla ubuntu \
    && usermod --login carla --home /home/carla --move-home ubuntu

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    libegl1 \
    libfontconfig1 \
    libgl-dev \
    libglib2.0-0t64 \
    libjpeg-dev \
    libpng-dev \
    libsm6 \
    libtiff5-dev \
    libvulkan1 \
    libxext6 \
    libxrender1 \
    mesa-vulkan-drivers \
    wget \
    xdg-user-dirs \
    && rm -rf /var/lib/apt/lists/*

# Install the legacy runtime after Noble's development package has pulled in
# libtiff5's transitive image codec dependencies.
ADD https://security.ubuntu.com/ubuntu/pool/main/t/tiff/libtiff5_4.3.0-6_amd64.deb /tmp/libtiff5.deb
RUN dpkg -i /tmp/libtiff5.deb && rm /tmp/libtiff5.deb

COPY --from=carla-runtime --chown=carla:carla /opt/carla /opt/carla
COPY --from=pcla-runtime /opt/conda /opt/conda
COPY --from=pcla-runtime /usr/local/cuda-11.8 /usr/local/cuda-11.8
RUN ln -sfn /usr/local/cuda-11.8 /usr/local/cuda \
    && ln -sfn /usr/local/cuda-11.8 /usr/local/cuda-11

COPY --from=ghcr.io/astral-sh/uv:0.10.4 /uv /uvx /bin/
COPY docker/nvidia_icd.json /etc/vulkan/icd.d/nvidia_icd.json

WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
ENV UV_PROJECT_ENVIRONMENT=/opt/conda/envs/PCLA
RUN uv sync --locked --no-dev --inexact

COPY PCLA-wrapper/PCLA/dist/carla-0.9.16-cp38-cp38-linux_x86_64.whl /tmp/
RUN uv pip install --python /opt/conda/envs/PCLA/bin/python \
    /tmp/carla-0.9.16-cp38-cp38-linux_x86_64.whl \
    && rm /tmp/carla-0.9.16-cp38-cp38-linux_x86_64.whl

COPY . /app
RUN test -f /app/PCLA-wrapper/PCLA/PCLA.py \
    && chmod +x /app/entrypoint.sh /app/carla_server.sh

ENV PATH=/opt/conda/envs/PCLA/bin:/opt/conda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV CUDA_VERSION=11.8.0
ENV NVIDIA_REQUIRE_CUDA="cuda>=11.8"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

ENV PORT=50051
ENV CARLA_HOST=localhost
ENV CARLA_PORT=2000
ENV CARLA_TIMEOUT=120
ENV CARLA_TM_PORT=8000
ENV CARLA_HOME=/mnt/output/.carla-home
ENV HOME=/mnt/output/.carla-home
ENV XDG_CACHE_HOME=/mnt/output/.carla-home/.cache

ENTRYPOINT ["/app/entrypoint.sh"]
