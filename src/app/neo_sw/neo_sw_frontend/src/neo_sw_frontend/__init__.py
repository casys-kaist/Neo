import os
from argparse import ArgumentParser

import torch
import torchvision
from tqdm import tqdm

from .arguments import ModelParams, PipelineParams, get_combined_args
from .gaussian_renderer import GaussianModel, render
from .scene import Scene
from .scene.dataset_readers import set_num_images
from .utils.camera_utils import get_resolution, set_resolution

IMAGE_FLAG = False


def render_set(
    output_path,
    name,
    iteration,
    views,
    gaussians,
    pipeline,
    background,
    train_test_exp,
    separate_sh,
):
    if IMAGE_FLAG:
        render_path = os.path.join(output_path, name, "renders")
        gts_path = os.path.join(output_path, name, "gt")

        os.makedirs(render_path, exist_ok=True)
        os.makedirs(gts_path, exist_ok=True)

    runtime = list()

    start_event = torch.cuda.Event(enable_timing=True)
    end_event = torch.cuda.Event(enable_timing=True)

    number_of_gaussians = gaussians._xyz.shape[0]
    w, h = get_resolution()
    number_of_tiles = (w // 16) * (h // 16)
    max_element_of_tile = 32768
    size_of_array = number_of_tiles * max_element_of_tile

    prev_gaussian_data = torch.zeros(
        (number_of_gaussians, 12), device="cuda", dtype=torch.float32
    )
    prev_gaussian_rect = torch.zeros(
        number_of_gaussians, device="cuda", dtype=torch.uint64
    )
    prev_gaussian_keys = torch.zeros(size_of_array, device="cuda", dtype=torch.uint64)
    prev_gaussian_values = torch.zeros(size_of_array, device="cuda", dtype=torch.uint32)
    prev_gaussian_ranges = torch.zeros(
        number_of_tiles, device="cuda", dtype=torch.uint32
    )

    curr_gaussian_data = torch.zeros(
        (number_of_gaussians, 12), device="cuda", dtype=torch.float32
    )
    curr_gaussian_rect = torch.zeros(
        number_of_gaussians, device="cuda", dtype=torch.uint64
    )
    curr_gaussian_keys = torch.zeros(size_of_array, device="cuda", dtype=torch.uint64)
    curr_gaussian_values = torch.zeros(size_of_array, device="cuda", dtype=torch.uint32)
    curr_gaussian_ranges = torch.zeros(
        number_of_tiles, device="cuda", dtype=torch.uint32
    )

    for idx, view in enumerate(tqdm(views, desc="Rendering progress")):
        if idx >= min(iteration, len(views)):
            break

        if idx % 2 == 0:
            packed_gaussian = (
                prev_gaussian_data,
                prev_gaussian_rect,
                prev_gaussian_keys,
                prev_gaussian_values,
                prev_gaussian_ranges,
                curr_gaussian_data,
                curr_gaussian_rect,
                curr_gaussian_keys,
                curr_gaussian_values,
                curr_gaussian_ranges,
            )
        else:
            packed_gaussian = (
                curr_gaussian_data,
                curr_gaussian_rect,
                curr_gaussian_keys,
                curr_gaussian_values,
                curr_gaussian_ranges,
                prev_gaussian_data,
                prev_gaussian_rect,
                prev_gaussian_keys,
                prev_gaussian_values,
                prev_gaussian_ranges,
            )

        start_event.record()
        if idx == 0:
            rendering = render(
                view,
                gaussians,
                pipeline,
                background,
                use_trained_exp=train_test_exp,
                separate_sh=separate_sh,
                is_reuse=False,
                packed_gaussian=packed_gaussian,
            )["render"]
        else:
            rendering = render(
                view,
                gaussians,
                pipeline,
                background,
                use_trained_exp=train_test_exp,
                separate_sh=separate_sh,
                is_reuse=True,
                packed_gaussian=packed_gaussian,
            )["render"]
        end_event.record()
        torch.cuda.synchronize()

        elapsed_time_ms = start_event.elapsed_time(end_event)
        runtime.append(elapsed_time_ms)

        gt = view.original_image[0:3, :, :]

        if IMAGE_FLAG:
            torchvision.utils.save_image(
                rendering, os.path.join(render_path, "{0:05d}".format(idx) + ".png")
            )
            torchvision.utils.save_image(
                gt, os.path.join(gts_path, "{0:05d}".format(idx) + ".png")
            )

    if len(runtime) >= 1:
        runtime = runtime[1:]
        print(f"Average Rendering Time: {sum(runtime) / len(runtime):.1f} ms")
        print(f"Average Rendering FPS: {1000 / (sum(runtime) / len(runtime)):.1f} fps")

    return sum(runtime) / len(runtime)


def render_sets(dataset: ModelParams, pipeline: PipelineParams, output_path, iteration):
    with torch.no_grad():
        gaussians = GaussianModel(dataset.sh_degree)
        scene = Scene(dataset, gaussians, load_iteration=-1, shuffle=False)

        bg_color = [1, 1, 1] if dataset.white_background else [0, 0, 0]
        background = torch.tensor(bg_color, dtype=torch.float32, device="cuda")

        return render_set(
            output_path,
            "train",
            iteration,
            scene.getTrainCameras(),
            gaussians,
            pipeline,
            background,
            dataset.train_test_exp,
            False,
        )


def run(dataset_path, model_path, output_path, resolution, iteration, image=False):
    global IMAGE_FLAG
    IMAGE_FLAG = image

    set_resolution(resolution)
    set_num_images(iteration)
    print(f"Set rendering resolution to: {get_resolution()}")

    parser = ArgumentParser(description="Testing script parameters")
    parser.add_argument("--iteration", default=-1, type=int)
    parser.add_argument("--skip_train", action="store_true")
    parser.add_argument("--skip_test", action="store_true")
    parser.add_argument("--quiet", action="store_true")

    model = ModelParams(parser, sentinel=True)
    pipeline = PipelineParams(parser)
    args = get_combined_args(parser, dataset_path, model_path)

    print(f"Rendering {model_path} on dataset {dataset_path}")
    return render_sets(
        model.extract(args), pipeline.extract(args), output_path, iteration
    )
