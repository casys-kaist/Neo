import argparse
import os

import yaml

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--chunk_size", type=int, default=256, help="Chunk size")
    parser.add_argument("--tile_size", type=int, default=16, help="Tile size")
    parser.add_argument("--subtile_size", type=int, default=8, help="Subtile size")
    parser.add_argument("--resolution", type=str, default="HD", help="Resolution name")
    parser.add_argument(
        "--frame_start_idx", type=int, default=0, help="Start frame index"
    )
    parser.add_argument("--frame_end_idx", type=int, default=1, help="End frame index")
    parser.add_argument("--frame_step", type=int, default=1, help="Frame step")
    parser.add_argument("--reuse_mode", action="store_true", help="Enable reuse_mode")
    parser.add_argument("--trace_mode", action="store_true", help="Enable trace_mode")
    parser.add_argument("--image_mode", action="store_true", help="Enable image_mode")
    parser.add_argument(
        "--output_path", type=str, default="config.yaml", help="Output YAML file path"
    )

    args = parser.parse_args()

    config = {
        "chunk_size": args.chunk_size,
        "tile_size": args.tile_size,
        "subtile_size": args.subtile_size,
        "resolution": args.resolution,
        "frame": list(range(args.frame_start_idx, args.frame_end_idx, args.frame_step)),
        "reuse_mode": args.reuse_mode,
        "trace_mode": args.trace_mode,
        "image_mode": args.image_mode,
    }

    os.makedirs(args.output_path, exist_ok=True)
    with open(os.path.join(args.output_path, "trace.yaml"), "w") as yaml_file:
        yaml.dump(config, yaml_file)
