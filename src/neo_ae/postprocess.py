import csv
import glob
import re
import statistics

from .env import *
from .metric import measure

TARGET_FPS = 60

KB = 1024
MB = KB * 1024
GB = MB * 1024


def postprocess_figure_5():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        processType_function = [
            ("feature extraction", "preprocessCUDA"),
            ("sorting", "DeviceScanInitKernel"),
            ("sorting", "DeviceScanKernel"),
            ("sorting", "duplicateWithKeys"),
            ("sorting", "DeviceRadixSortHistogramKernel"),
            ("sorting", "DeviceRadixSortExclusiveSumKernel"),
            ("sorting", "DeviceRadixSortOnesweepKernel"),
            ("sorting", "identifyTileRanges"),
            ("rasterization", "renderCUDA"),
        ]

        resolution_list = ["HD", "FHD", "QHD"]

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Feature Extraction (GB)",
                    "Sorting (GB)",
                    "Rasterization (GB)",
                ]
            )

            for resolution in resolution_list:
                csv_file_path = f"{OUTPUT_PATH}/{DEVICE}-{resolution}.csv"

                memory_breakdown = dict()
                for process_type in ["feature extraction", "sorting", "rasterization"]:
                    memory_breakdown[process_type] = 0

                with open(csv_file_path, mode="r") as readfile:
                    reader = csv.DictReader(readfile)
                    for row in reader:
                        kernel_name = row["Kernel Name"]
                        for proc_type, kernel in processType_function:
                            if kernel in kernel_name:
                                read_sectors = float(
                                    row["lts__d_sectors_fill_sysmem.sum"] or 0.0
                                )
                                write_sectors = float(
                                    row["lts__t_sectors_aperture_sysmem_op_write.sum"]
                                    or 0.0
                                )
                                memory_breakdown[proc_type] += (
                                    read_sectors + write_sectors
                                ) * 32
                                break

                writer.writerow(
                    [
                        "3DGS",
                        resolution,
                        f"{int(memory_breakdown['feature extraction'] / GB * TARGET_FPS / ITERATION)}",
                        f"{int(memory_breakdown['sorting'] / GB * TARGET_FPS / ITERATION)}",
                        f"{int(memory_breakdown['rasterization'] / GB * TARGET_FPS / ITERATION)}",
                    ]
                )


def postprocess_figure_10():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        gs_processType_function = [
            ("feature extraction", "preprocessCUDA"),
            ("sorting", "DeviceScanInitKernel"),
            ("sorting", "DeviceScanKernel"),
            ("sorting", "duplicateWithKeys"),
            ("sorting", "DeviceRadixSortHistogramKernel"),
            ("sorting", "DeviceRadixSortExclusiveSumKernel"),
            ("sorting", "DeviceRadixSortOnesweepKernel"),
            ("sorting", "identifyTileRanges"),
            ("rasterization", "renderCUDA"),
        ]

        neo_processType_function = [
            ("feature extraction", "preprocessCUDA"),
            ("feature extraction", "preprocess_reuseCUDA"),
            ("sorting", "DeviceScanInitKernel"),
            ("sorting", "DeviceScanKernel"),
            ("sorting", "duplicateWithKeys"),
            ("sorting", "duplicateWithKeys_reuse"),
            ("sorting", "DeviceRadixSortHistogramKernel"),
            ("sorting", "DeviceRadixSortExclusiveSumKernel"),
            ("sorting", "DeviceRadixSortOnesweepKernel"),
            ("sorting", "identifyTileRanges"),
            ("sorting", "optimized_mergingCUDA"),
            ("rasterization", "renderCUDA"),
            ("rasterization", "render_reuseCUDA"),
        ]

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Feature Extraction (ms)",
                    "Sorting (ms)",
                    "Rasterization (ms)",
                    "Feature Extraction (GB)",
                    "Sorting (GB)",
                    "Rasterization (GB)",
                ]
            )

            for algorithm in ["gs", "neo"]:
                csv_file_path = f"{OUTPUT_PATH}/{DEVICE}-{algorithm}.csv"

                memory_breakdown = dict()
                for process_type in [
                    "feature extraction",
                    "sorting",
                    "rasterization",
                ]:
                    memory_breakdown[process_type] = 0

                runtime_breakdown = dict()
                for process_type in [
                    "feature extraction",
                    "sorting",
                    "rasterization",
                ]:
                    runtime_breakdown[process_type] = 0

                processType_function = (
                    gs_processType_function
                    if algorithm == "gs"
                    else neo_processType_function
                )
                neo_flag = False

                with open(csv_file_path, mode="r") as readfile:
                    reader = csv.DictReader(readfile)
                    for row in reader:
                        kernel_name = row["Kernel Name"]

                        if algorithm == "neo" and not neo_flag:
                            if "renderCUDA" in kernel_name:
                                neo_flag = True
                            continue

                        for proc_type, kernel in processType_function:
                            if kernel in kernel_name:
                                read_sectors = float(
                                    row["lts__d_sectors_fill_sysmem.sum"] or 0.0
                                )
                                write_sectors = float(
                                    row["lts__t_sectors_aperture_sysmem_op_write.sum"]
                                    or 0.0
                                )
                                memory_breakdown[proc_type] += (
                                    read_sectors + write_sectors
                                ) * 32
                                runtime_breakdown[proc_type] += float(
                                    row["gpu__time_duration.avg"] or 0.0
                                )
                                break

                actual_iteration = ITERATION if algorithm == "gs" else ITERATION - 1

                total_runtime = sum(runtime_breakdown.values())
                for proc_type in runtime_breakdown:
                    runtime_breakdown[proc_type] = (
                        runtime_breakdown[proc_type] / total_runtime
                    )

                with open(
                    f"{OUTPUT_PATH}/{DEVICE}-{algorithm}-runtime.txt",
                    mode="r",
                ) as readfile:
                    runtime_overall = float(readfile.read().strip())
                    others = (
                        1.0
                        - runtime_breakdown["sorting"]
                        - runtime_breakdown["rasterization"]
                    )

                writer.writerow(
                    [
                        "3DGS" if algorithm == "gs" else "Neo-SW",
                        f"{runtime_overall * others:.1f}",
                        f"{runtime_overall * runtime_breakdown['sorting']:.1f}",
                        f"{runtime_overall * runtime_breakdown['rasterization']:.1f}",
                        f"{int(memory_breakdown['feature extraction'] / GB * TARGET_FPS / actual_iteration)}",
                        f"{int(memory_breakdown['sorting'] / GB * TARGET_FPS / actual_iteration)}",
                        f"{int(memory_breakdown['rasterization'] / GB * TARGET_FPS / actual_iteration)}",
                    ]
                )


def extract_latency(log_path):
    with open(log_path, "r") as f:
        content = f.read()
    matches = re.findall(r"\(([\d.]+) FPS\)", content)
    return 1000.0 / float(matches[-1]) if matches else None


def extract_traffic(log_path):
    with open(log_path, "r") as f:
        content = f.read()
        matches = re.findall(r"Total DRAM Traffic\s*:\s*([\d.]+)\s*MB", content)
    return float(matches[-1]) if matches else None


def arithmetric_mean(values):
    return sum(values) / len(values) if len(values) > 0 else 0


def geometric_mean(values):
    return statistics.geometric_mean(values) if len(values) > 0 else 0


def postprocess_figure_15():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Runtime (ms)",
                ]
            )

            for scene in [
                "family",
                "francis",
                "horse",
                "lighthouse",
                "playground",
                "train",
            ]:
                for resolution in ["HD", "FHD", "QHD"]:
                    with open(
                        f"{OUTPUT_PATH}/{DEVICE}-gs-{scene}-{resolution}-runtime.txt",
                        mode="r",
                    ) as readfile:
                        gs_runtime = float(readfile.read().strip())
                    writer.writerow(
                        [
                            "3DGS",
                            resolution,
                            scene,
                            f"{gs_runtime:.1f}",
                        ]
                    )
    elif DEVICE == "server":
        dataset_list = [
            "family",
            "francis",
            "horse",
            "lighthouse",
            "playground",
            "train",
        ]
        resolution_list = ["HD", "FHD", "QHD"]

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Runtime (ms)",
                ]
            )

            for scene in dataset_list:
                for resolution in resolution_list:
                    log_path = f"{OUTPUT_PATH}/neo/{scene}/{resolution}"
                    log_files = glob.glob(f"{log_path}/trace/*/sim.log")

                    latency = list()
                    for path in log_files:
                        lat = extract_latency(path)
                        if lat is not None:
                            latency.append(lat)

                    writer.writerow(
                        [
                            "Neo",
                            resolution,
                            scene,
                            f"{arithmetric_mean(latency):.1f}",
                        ]
                    )


def postprocess_figure_16():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        processType_function = [
            ("feature extraction", "preprocessCUDA"),
            ("sorting", "DeviceScanInitKernel"),
            ("sorting", "DeviceScanKernel"),
            ("sorting", "duplicateWithKeys"),
            ("sorting", "DeviceRadixSortHistogramKernel"),
            ("sorting", "DeviceRadixSortExclusiveSumKernel"),
            ("sorting", "DeviceRadixSortOnesweepKernel"),
            ("sorting", "identifyTileRanges"),
            ("rasterization", "renderCUDA"),
        ]

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Scene",
                    "Traffic (GB)",
                ]
            )

            for scene in [
                "family",
                "francis",
                "horse",
                "lighthouse",
                "playground",
                "train",
            ]:
                csv_file_path = f"{OUTPUT_PATH}/{DEVICE}-gs-{scene}-QHD.csv"

                total_traffic = 0

                with open(csv_file_path, mode="r") as readfile:
                    reader = csv.DictReader(readfile)
                    for row in reader:
                        kernel_name = row["Kernel Name"]
                        for proc_type, kernel in processType_function:
                            if kernel in kernel_name:
                                read_sectors = float(
                                    row["lts__d_sectors_fill_sysmem.sum"] or 0.0
                                )
                                write_sectors = float(
                                    row["lts__t_sectors_aperture_sysmem_op_write.sum"]
                                    or 0.0
                                )
                                total_traffic += (read_sectors + write_sectors) * 32
                                break

                writer.writerow(
                    [
                        "3DGS",
                        scene,
                        f"{int(total_traffic / GB * TARGET_FPS / ITERATION)}",
                    ]
                )
    elif DEVICE == "server":
        dataset_list = [
            "family",
            "francis",
            "horse",
            "lighthouse",
            "playground",
            "train",
        ]
        resolution_list = [
            "QHD",
        ]

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Traffic (GB)",
                ]
            )

            for scene in dataset_list:
                for resolution in resolution_list:
                    log_path = f"{OUTPUT_PATH}/../figure_15/neo/{scene}/{resolution}"
                    log_files = glob.glob(f"{log_path}/trace/*/sim.log")

                    traffic = list()
                    for path in log_files:
                        traf = extract_traffic(path)
                        if traf is not None:
                            traffic.append(traf)

                    writer.writerow(
                        [
                            "Neo",
                            resolution,
                            scene,
                            f"{arithmetric_mean(traffic) * 60 / 1024:.1f}",
                        ]
                    )


def postprocess_figure_17():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Scene",
                    "Runtime (ms)",
                ]
            )

            for scene in [
                "rubble",
                "building",
            ]:
                with open(
                    f"{OUTPUT_PATH}/{DEVICE}-gs-{scene}-QHD-runtime.txt",
                    mode="r",
                ) as readfile:
                    gs_runtime = float(readfile.read().strip())
                writer.writerow(
                    [
                        "3DGS",
                        scene,
                        f"{gs_runtime:.1f}",
                    ]
                )
    elif DEVICE == "server":
        dataset_list = [
            "rubble",
            "building",
        ]
        resolution_list = ["QHD"]

        with open(f"{OUTPUT_PATH}/{DEVICE}-A.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Runtime (ms)",
                ]
            )

            for scene in dataset_list:
                for resolution in resolution_list:
                    log_path = f"{OUTPUT_PATH}/A/neo/{scene}/{resolution}"
                    log_files = glob.glob(f"{log_path}/trace/*/sim.log")

                    latency = list()
                    for path in log_files:
                        lat = extract_latency(path)
                        if lat is not None:
                            latency.append(lat)

                    writer.writerow(
                        [
                            "Neo",
                            resolution,
                            scene,
                            f"{arithmetric_mean(latency):.1f}",
                        ]
                    )

        scene = "family"
        resolution = "QHD"

        with open(f"{OUTPUT_PATH}/{DEVICE}-B.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Step",
                    "Runtime (ms)",
                ]
            )

            for step in [1, 2, 4, 8, 16]:
                log_path = f"{OUTPUT_PATH}/B/step-{step}/neo/{scene}/{resolution}"
                log_files = glob.glob(f"{log_path}/trace/*/sim.log")

                latency = list()
                for path in log_files:
                    lat = extract_latency(path)
                    if lat is not None:
                        latency.append(lat)

                writer.writerow(
                    [
                        "Neo",
                        resolution,
                        scene,
                        step,
                        f"{arithmetric_mean(latency):.1f}",
                    ]
                )


def postprocess_figure_18():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "server":
        scene = "family"
        resolution = "QHD"

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Runtime (ms)",
                    "Traffic (GB)",
                ]
            )

            log_path = f"{OUTPUT_PATH}/../figure_17/B/step-1/neo/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            latency = list()
            traffic = list()
            for path in log_files:
                lat = extract_latency(path)
                traf = extract_traffic(path)
                if lat is not None:
                    latency.append(lat)
                if traf is not None:
                    traffic.append(traf)

            writer.writerow(
                [
                    "Neo",
                    resolution,
                    scene,
                    f"{arithmetric_mean(latency):.1f}",
                    f"{arithmetric_mean(traffic) * 60 / 1024:.1f}",
                ]
            )

            log_path = f"{OUTPUT_PATH}/neo_s/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            latency = list()
            traffic = list()
            for path in log_files:
                lat = extract_latency(path)
                traf = extract_traffic(path)
                if lat is not None:
                    latency.append(lat)
                if traf is not None:
                    traffic.append(traf)

            writer.writerow(
                [
                    "Neo-S",
                    resolution,
                    scene,
                    f"{arithmetric_mean(latency):.1f}",
                    f"{arithmetric_mean(traffic) * 60 / 1024:.1f}",
                ]
            )


def postprocess_figure_19():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "server":
        scene = "train"
        resolution = "QHD"

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "Frame",
                    "Runtime (ms)",
                    "PSNR (dB)",
                    "LPIPS",
                ]
            )

            log_path = f"{OUTPUT_PATH}/neo/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            rows = list()

            for path in log_files:
                lat = extract_latency(path)
                idx = int(path.split("/")[-2])
                psnr = measure(
                    f"{OUTPUT_PATH}/neo/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/neo/{scene}/{resolution}/renders/{idx:05d}.png",
                    "PSNR",
                )
                lpips = measure(
                    f"{OUTPUT_PATH}/neo/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/neo/{scene}/{resolution}/renders/{idx:05d}.png",
                    "LPIPS",
                )
                rows.append((idx, lat, psnr, lpips))

            rows.sort(key=lambda x: x[0])

            for idx, lat, psnr, lpips in rows:
                writer.writerow(
                    [
                        "Neo",
                        resolution,
                        scene,
                        idx,
                        f"{lat:.1f}",
                        f"{psnr:.2f}",
                        f"{lpips:.4f}",
                    ]
                )

            log_path = f"{OUTPUT_PATH}/periodic_sorting/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            rows = list()

            for path in log_files:
                lat = extract_latency(path)
                idx = int(path.split("/")[-2])
                psnr = measure(
                    f"{OUTPUT_PATH}/periodic_sorting/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/periodic_sorting/{scene}/{resolution}/renders/{idx:05d}.png",
                    "PSNR",
                )
                lpips = measure(
                    f"{OUTPUT_PATH}/periodic_sorting/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/periodic_sorting/{scene}/{resolution}/renders/{idx:05d}.png",
                    "LPIPS",
                )
                rows.append((idx, lat, psnr, lpips))

            rows.sort(key=lambda x: x[0])

            for idx, lat, psnr, lpips in rows:
                writer.writerow(
                    [
                        "Periodic Sorting",
                        resolution,
                        scene,
                        idx,
                        f"{lat:.1f}",
                        f"{psnr:.2f}",
                        f"{lpips:.4f}",
                    ]
                )

            log_path = f"{OUTPUT_PATH}/neo_hs/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            rows = list()

            for path in log_files:
                lat = extract_latency(path)
                idx = int(path.split("/")[-2])
                psnr = measure(
                    f"{OUTPUT_PATH}/neo_hs/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/neo_hs/{scene}/{resolution}/renders/{idx:05d}.png",
                    "PSNR",
                )
                lpips = measure(
                    f"{OUTPUT_PATH}/neo_hs/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/neo_hs/{scene}/{resolution}/renders/{idx:05d}.png",
                    "LPIPS",
                )
                rows.append((idx, lat, psnr, lpips))

            rows.sort(key=lambda x: x[0])

            for idx, lat, psnr, lpips in rows:
                writer.writerow(
                    [
                        "Hierarchical Sorting",
                        resolution,
                        scene,
                        idx,
                        f"{lat:.1f}",
                        f"{psnr:.2f}",
                        f"{lpips:.4f}",
                    ]
                )

            log_path = (
                f"{OUTPUT_PATH}/sort_time/background_sorting/{scene}/{resolution}"
            )
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            background_latency = list()

            for path in log_files:
                lat = extract_latency(path)
                background_latency.append(lat)

            background_mean_latency = arithmetric_mean(background_latency) / 6

            log_path = f"{OUTPUT_PATH}/background_sorting/{scene}/{resolution}"
            log_files = glob.glob(f"{log_path}/trace/*/sim.log")

            rows = list()

            for path in log_files:
                lat = extract_latency(path)
                idx = int(path.split("/")[-2])
                psnr = measure(
                    f"{OUTPUT_PATH}/background_sorting/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/background_sorting/{scene}/{resolution}/renders/{idx:05d}.png",
                    "PSNR",
                )
                lpips = measure(
                    f"{OUTPUT_PATH}/background_sorting/{scene}/{resolution}/gt/{idx:05d}.png",
                    f"{OUTPUT_PATH}/background_sorting/{scene}/{resolution}/renders/{idx:05d}.png",
                    "LPIPS",
                )
                rows.append((idx, lat, psnr, lpips))

            rows.sort(key=lambda x: x[0])

            for idx, lat, psnr, lpips in rows:
                writer.writerow(
                    [
                        "Background Sorting",
                        resolution,
                        scene,
                        idx,
                        f"{lat + background_mean_latency:.1f}",
                        f"{psnr:.2f}",
                        f"{lpips:.4f}",
                    ]
                )


def postprocess_table_2():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "server":
        resolution = "QHD"

        with open(f"{OUTPUT_PATH}/{DEVICE}.csv", mode="w") as writefile:
            writer = csv.writer(writefile)
            writer.writerow(
                [
                    "Algorithm",
                    "Resolution",
                    "Scene",
                    "PSNR (dB)",
                    "LPIPS",
                ]
            )

            for reuse in [True, False]:
                for scene in [
                    "family",
                    "francis",
                    "horse",
                    "lighthouse",
                    "playground",
                    "train",
                ]:
                    log_path = f"{OUTPUT_PATH}/reuse-{'true' if reuse else 'false'}/neo/{scene}/{resolution}"
                    log_files = glob.glob(f"{log_path}/renders/*.png")

                    psnr_list = list()
                    lpips_list = list()

                    for path in log_files:
                        idx = int(path.split("/")[-1].split(".")[0])
                        psnr = measure(
                            f"{OUTPUT_PATH}/reuse-{'true' if reuse else 'false'}/neo/{scene}/{resolution}/gt/{idx:05d}.png",
                            f"{OUTPUT_PATH}/reuse-{'true' if reuse else 'false'}/neo/{scene}/{resolution}/renders/{idx:05d}.png",
                            "PSNR",
                        )
                        lpips = measure(
                            f"{OUTPUT_PATH}/reuse-{'true' if reuse else 'false'}/neo/{scene}/{resolution}/gt/{idx:05d}.png",
                            f"{OUTPUT_PATH}/reuse-{'true' if reuse else 'false'}/neo/{scene}/{resolution}/renders/{idx:05d}.png",
                            "LPIPS",
                        )

                        psnr_list.append(psnr)
                        lpips_list.append(lpips)

                    writer.writerow(
                        [
                            "Neo" if reuse else "3DGS",
                            resolution,
                            scene,
                            f"{geometric_mean(psnr_list):.2f}",
                            f"{geometric_mean(lpips_list):.4f}",
                        ]
                    )
