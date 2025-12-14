import argparse

import neo_ae

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dataset_path", type=str, required=True, help="Path to the dataset"
    )
    parser.add_argument(
        "--model_path", type=str, required=True, help="Path to the model"
    )
    parser.add_argument(
        "--yaml_path", type=str, default="", help="Path to the YAML configuration file"
    )
    parser.add_argument(
        "--output_path", type=str, required=True, help="Path to save outputs"
    )
    parser.add_argument(
        "--device", type=str, required=True, help="Device to use (e.g., 'orin')"
    )
    parser.add_argument(
        "--scene", type=str, default="family", help="Scene name for the workload"
    )
    parser.add_argument(
        "--resolution", type=str, default="QHD", help="Resolution for the workload"
    )
    parser.add_argument(
        "--iteration", type=int, default=2000, help="Number of iterations to run"
    )
    parser.add_argument("--algorithm", type=str, default="gs", help="Algorithm to use")
    parser.add_argument(
        "--runtime_measurement",
        action="store_true",
        help="Flag to enable runtime measurement",
    )
    parser.add_argument(
        "--figure_idx", type=int, default=0, help="figure index for the run"
    )

    args = parser.parse_args()

    neo_ae.init(
        args.dataset_path,
        args.model_path,
        args.yaml_path,
        args.output_path,
        args.device,
    )
    neo_ae.init_workload(
        args.resolution,
        args.scene,
        args.iteration,
        args.algorithm,
        args.runtime_measurement,
    )
    neo_ae.run(figure_idx=args.figure_idx)
