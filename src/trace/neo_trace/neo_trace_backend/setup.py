import os
from pathlib import Path

from setuptools import setup
from torch.utils.cpp_extension import BuildExtension, CUDAExtension

pwd = Path(__file__).parent.resolve()

src_dir = Path("src") / "neo_trace_backend"
third_party_glm_dir = pwd / src_dir / "third_party" / "glm"

setup(
    name="neo_trace_backend",
    packages=["neo_trace_backend"],
    package_dir={"": "src"},
    ext_modules=[
        CUDAExtension(
            name="neo_trace_backend._C",
            sources=[
                str(src_dir / "cuda_rasterizer" / "forward.cu"),
                str(src_dir / "cuda_rasterizer" / "preprocess.cu"),
                str(src_dir / "cuda_rasterizer" / "rasterize.cu"),
                str(src_dir / "cuda_rasterizer" / "sort.cu"),
                str(src_dir / "cuda_rasterizer" / "utils.cu"),
                str(src_dir / "cuda_rasterizer" / "variable.cu"),
                str(src_dir / "ext.cpp"),
            ],
            extra_compile_args={
                "nvcc": [
                    "-I" + str(third_party_glm_dir),
                ]
            },
        ),
    ],
    cmdclass={"build_ext": BuildExtension},
)
