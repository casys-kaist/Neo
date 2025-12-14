import math
import os
import random
from argparse import ArgumentParser

import torch
import torchvision
from tqdm import tqdm

from ..arguments import ModelParams, PipelineParams, get_combined_args
from ..scene import Scene
from ..scene.gaussian_model import GaussianModel
from ..utils.custom_utils import get_config, get_resolution, set_config

try:
    import periodic_sorting_trace_backend
except:
    pass

SKIP_WINDOW = 6


def render_set(
    output_path,
    views,
):
    TRACE_MODE = get_config()["trace_mode"]
    REUSE_MODE = get_config()["reuse_mode"]
    IMAGE_MODE = get_config()["image_mode"]

    if IMAGE_MODE:
        render_path = os.path.join(output_path, "renders")
        gts_path = os.path.join(output_path, "gt")
        os.makedirs(render_path, exist_ok=True)
        os.makedirs(gts_path, exist_ok=True)

    if TRACE_MODE:
        os.makedirs(os.path.join(output_path, "trace"), exist_ok=True)

    REFRESH_IDX = 0
    for idx, view in enumerate(tqdm(views, desc="Rendering progress")):
        if idx == 0:
            periodic_sorting_trace_backend.set_phase(
                periodic_sorting_trace_backend.INITIAL_PHASE
            )
            periodic_sorting_trace_backend.set_cam(views[idx])

        if (idx - REFRESH_IDX) == SKIP_WINDOW:
            periodic_sorting_trace_backend.set_phase(
                periodic_sorting_trace_backend.INITIAL_PHASE
            )
            MISS_RANGE = random.randint(0, SKIP_WINDOW // 2)
            periodic_sorting_trace_backend.set_cam(views[idx - MISS_RANGE])
            periodic_sorting_trace_backend.set_trace(False, "placeholder")
            periodic_sorting_trace_backend.render()

            REFRESH_IDX = idx

        if idx != 0:
            if TRACE_MODE:
                TRACE_PATH = os.path.join(output_path, "trace", str(idx))
                os.makedirs(TRACE_PATH, exist_ok=True)
                periodic_sorting_trace_backend.set_trace(TRACE_MODE, TRACE_PATH)

            if REUSE_MODE:
                periodic_sorting_trace_backend.set_phase(
                    periodic_sorting_trace_backend.REUSE_PHASE
                )
            else:
                periodic_sorting_trace_backend.set_phase(
                    periodic_sorting_trace_backend.INITIAL_PHASE
                )

            periodic_sorting_trace_backend.set_cam(views[idx])

        periodic_sorting_trace_backend.render()

        if IMAGE_MODE:
            width, height = get_resolution()

            gt = view.original_image[0:3, :, :]
            rendering = periodic_sorting_trace_backend.get_img(width, height)

            torchvision.utils.save_image(
                rendering, os.path.join(render_path, "{0:05d}".format(idx) + ".png")
            )
            torchvision.utils.save_image(
                gt, os.path.join(gts_path, "{0:05d}".format(idx) + ".png")
            )


def render_sets(dataset: ModelParams, pipeline: PipelineParams, output_path):
    with torch.no_grad():
        width, height = get_resolution()
        config = get_config()

        periodic_sorting_trace_backend.set_config(
            width,
            height,
            config["tile_size"],
            config["subtile_size"],
            config["chunk_size"],
        )

        gaussians = GaussianModel(dataset.sh_degree)
        scene = Scene(dataset, gaussians, load_iteration=-1, shuffle=False)

        periodic_sorting_trace_backend.set_gaussian(gaussians)

        bg_color = [1, 1, 1] if dataset.white_background else [0, 0, 0]
        background = torch.tensor(bg_color, dtype=torch.float32, device="cuda")

        render_set(
            output_path,
            scene.getTrainCameras(),
        )


def run(dataset_path, model_path, output_path, yaml_path):
    set_config(yaml_path)

    parser = ArgumentParser(description="Testing script parameters")
    parser.add_argument("--iteration", default=-1, type=int)
    parser.add_argument("--skip_train", action="store_true")
    parser.add_argument("--skip_test", action="store_true")
    parser.add_argument("--quiet", action="store_true")

    model = ModelParams(parser, sentinel=True)
    pipeline = PipelineParams(parser)
    args = get_combined_args(parser, dataset_path, model_path)

    print(f"Rendering {model_path} on dataset {dataset_path}")
    render_sets(
        model.extract(args),
        pipeline.extract(args),
        output_path,
    )
