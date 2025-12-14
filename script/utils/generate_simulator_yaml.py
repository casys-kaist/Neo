import argparse
import os

import yaml

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dram_path", type=str, default=".", help="Path to the repository"
    )
    parser.add_argument(
        "--trace_path", type=str, default=".", help="Path to the trace yaml file"
    )
    parser.add_argument("--chunk_size", type=int, default=256, help="Chunk size")
    parser.add_argument("--tile_size", type=int, default=16, help="Tile size")
    parser.add_argument(
        "--output_path", type=str, default="config.yaml", help="Output YAML file path"
    )

    args = parser.parse_args()

    DRAM_config = {
        "Config": args.dram_path,
        "Clock": 1600,
        "CacheLine": 64,
    }

    CORE_config = {
        "Clock": 1000,
    }

    OTHER_config = {
        "Trace": args.trace_path,
        "GlobalSorter": 8,
        "GlobalChunkSize": args.chunk_size,
        "AdaptiveSorter": 8,
        "AdaptiveChunkSize": args.chunk_size,
        "SortGranularity": 16,
        "Renderer": 4,
        "RenderChunkSize": args.chunk_size,
        "CacheSize": 0,
        "TileSize": args.tile_size,
    }

    config = {
        "DRAM": DRAM_config,
        "CORE": CORE_config,
        "OTHER": OTHER_config,
    }

    os.makedirs(args.output_path, exist_ok=True)
    with open(os.path.join(args.output_path, "simulator.yaml"), "w") as yaml_file:
        yaml.dump(config, yaml_file)
