#
# Copyright (C) 2023, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

import os
from pathlib import Path

from setuptools import setup
from torch.utils.cpp_extension import BuildExtension, CUDAExtension

pwd = Path(__file__).parent.resolve()
src_dir = Path("src") / "gaussian_splatting_backend"
third_party_glm_dir = pwd / src_dir / "third_party" / "glm"

setup(
    name="gaussian_splatting_backend",
    packages=["gaussian_splatting_backend"],
    package_dir={"": "src"},
    ext_modules=[
        CUDAExtension(
            name="gaussian_splatting_backend._C",
            sources=[
                str(src_dir / "cuda_rasterizer" / "rasterizer_impl.cu"),
                str(src_dir / "cuda_rasterizer" / "forward.cu"),
                str(src_dir / "cuda_rasterizer" / "backward.cu"),
                str(src_dir / "rasterize_points.cu"),
                str(src_dir / "ext.cpp"),
            ],
            extra_compile_args={
                "nvcc": [
                    "-I" + str(third_party_glm_dir),
                ]
            },
        )
    ],
    cmdclass={"build_ext": BuildExtension},
)
