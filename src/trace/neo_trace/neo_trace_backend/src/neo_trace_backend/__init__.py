import math

import torch

from . import _C

INITIAL_PHASE = 0
REUSE_PHASE = 1


def set_config(W, H, tile_size, min_tile_size, chunk_size):
    args = (
        W,
        H,
        tile_size,
        min_tile_size,
        chunk_size,
    )
    _C.set_config(*args)


def set_cam(camera):
    args = (
        math.tan(camera.FoVx * 0.5),
        math.tan(camera.FoVy * 0.5),
        camera.world_view_transform,
        camera.full_proj_transform,
        camera.camera_center,
    )
    _C.set_cam(*args)


def set_gaussian(gaussians):
    args = (
        gaussians.get_xyz,
        gaussians.get_opacity,
        gaussians.get_scaling,
        gaussians.get_rotation,
        gaussians.get_features,
        gaussians.active_sh_degree,
    )
    _C.set_gaussian(*args)


def set_trace(trace, trace_dir):
    _C.set_trace(trace, trace_dir)


def set_phase(phase):
    _C.set_phase(phase)


def render():
    _C.render()


def get_img(W, H):
    return _C.get_img().reshape(3, H, W)
