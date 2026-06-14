#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib
import json
import os
import sys
from pathlib import Path

COMMON_IMPORTS = (
    "carla",
    "cv2",
    "gymnasium",
    "h5py",
    "jsonpickle",
    "numpy",
    "omegaconf",
    "pytorch_lightning",
    "scipy",
    "shapely",
    "timm",
    "torch",
    "torchmetrics",
    "torchvision",
    "transformers",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-weights", action="store_true")
    args = parser.parse_args()

    for module_name in COMMON_IMPORTS:
        importlib.import_module(module_name)

    import torch

    assert sys.version_info[:2] == (3, 8), sys.version
    assert torch.__version__.startswith("2.2.0"), torch.__version__
    assert torch.version.cuda == "12.1", torch.version.cuda
    assert not Path("/opt/conda").exists()
    assert not Path("/usr/local/cuda-11.8").exists()

    if args.check_weights:
        manifest_path = Path("/opt/pcla-pretrained/pcla-weight-profile.json")
        if manifest_path.is_file():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            assert manifest["profile"] == "common"
        os.environ["PCLA_IMAGE_PROFILE"] = "common"
        from pcla_wrapper.profiles import load_agent_profiles, validate_image_profile

        for agent_name in load_agent_profiles()["common"]["agents"]:
            validate_image_profile(agent_name, Path("/opt/pcla-pretrained"))

    print(
        json.dumps(
            {
                "python": sys.version.split()[0],
                "torch": torch.__version__,
                "torch_cuda": torch.version.cuda,
                "cuda_available": torch.cuda.is_available(),
                "profile": os.environ.get("PCLA_IMAGE_PROFILE"),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
