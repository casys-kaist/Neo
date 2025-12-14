import csv
import os
import subprocess

import matplotlib.pyplot as plt
import numpy as np

LIGHT_GREEN = "#D8F3DC"
MEDIUM_GREEN = "#74C69D"
DARK_GREEN = "#40916B"

YELLOW = "#FFD063"
ORANGE = "#FF9C1B"


def _draw_figure_5(target_path, data, max_value):
    x = np.arange(3)

    bottom_layer = data[0]
    middle_layer = data[1]
    top_layer = data[2]

    width = 0.65
    colors = [DARK_GREEN, MEDIUM_GREEN, LIGHT_GREEN]

    fig, ax = plt.subplots(figsize=(2, 1.5))

    ax.bar(x, bottom_layer, width, color=colors[0], edgecolor="black", zorder=5)
    ax.bar(
        x,
        middle_layer,
        width,
        bottom=bottom_layer,
        color=colors[1],
        edgecolor="black",
        zorder=5,
    )
    ax.bar(
        x,
        top_layer,
        width,
        bottom=np.array(bottom_layer) + np.array(middle_layer),
        color=colors[2],
        edgecolor="black",
        zorder=5,
    )

    ax.axhline(51.2, color="brown", linestyle="--", linewidth=2, zorder=10)

    ranges = range(0, max_value + 1, max_value // 3)
    ax.set_yticks(ranges)
    ax.set_yticklabels(["" for _ in ranges])
    ax.set_ylim(0, max_value)
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    ax.set_xlim(-0.5, 2.5)
    ax.set_xticks(x)
    ax.set_xticklabels(["", "", ""])

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_5(summary_path):
    orin_csv_path = os.path.join(summary_path, "orin", "orin_figure_5.csv")

    data = [[], [], []]

    with open(orin_csv_path, mode="r", newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            feature_extraction = int(row["Feature Extraction (GB)"])
            sorting = int(row["Sorting (GB)"])
            rasterization = int(row["Rasterization (GB)"])

            data[0].append(feature_extraction)
            data[1].append(sorting)
            data[2].append(rasterization)

    target_path = os.path.join(summary_path, "figure_5_3dgs.pdf")
    _draw_figure_5(target_path, data, 360)

    data = [
        [7.773262023925781, 11.549471855163574, 16.04710578918457],
        [27.94595718383789, 40.592972338199615, 55.34545183181763],
        [8.525809720158577, 8.525809720158577, 8.525809720158577],
    ]

    target_path = os.path.join(summary_path, "figure_5_gscore.pdf")
    _draw_figure_5(target_path, data, 90)


def _draw_figure_10(original, neo, target_path, max_value):
    original = list(original.values())
    neo = list(neo.values())

    colors = [LIGHT_GREEN, MEDIUM_GREEN, DARK_GREEN]
    fig, ax = plt.subplots(figsize=(2, 1.5))

    delta = 0.7
    start = 1.2
    x_positions = [start - delta, start, start * 2, start * 2 + delta]

    ax.bar(x_positions[1], original[-1], color=colors[-1], edgecolor="black", zorder=3)
    ax.bar(
        x_positions[1],
        original[-2],
        bottom=original[-1],
        color=colors[-2],
        edgecolor="black",
        zorder=3,
    )
    ax.bar(
        x_positions[1],
        original[-3],
        bottom=original[-1] + original[-2],
        color=colors[-3],
        edgecolor="black",
        zorder=3,
    )

    ax.bar(x_positions[2], neo[-1], color=colors[-1], edgecolor="black", zorder=3)
    ax.bar(
        x_positions[2],
        neo[-2],
        bottom=neo[-1],
        color=colors[-2],
        edgecolor="black",
        zorder=3,
    )
    ax.bar(
        x_positions[2],
        neo[-3],
        bottom=neo[-1] + neo[-2],
        color=colors[-3],
        edgecolor="black",
        zorder=3,
    )

    ax.set_xticks(x_positions)
    ax.set_xticklabels(["", "", "", ""])

    ranges = range(0, max_value + 1, max_value // 4)
    ax.set_yticks(ranges)
    ax.set_ylim(0, max_value)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_10(summary_path):
    orin_csv_path = os.path.join(summary_path, "orin", "orin_figure_10.csv")

    runtime_original = {"preprocess": 0, "sorting": 0, "rasterization": 0}
    runtime_neo = {"preprocess": 0, "sorting": 0, "rasterization": 0}
    memory_original = {"preprocess": 0, "sorting": 0, "rasterization": 0}
    memory_neo = {"preprocess": 0, "sorting": 0, "rasterization": 0}

    with open(orin_csv_path, mode="r", newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            algorithm = row["Algorithm"].strip().lower()
            runtime_target = (
                runtime_original if algorithm == "3dgs".lower() else runtime_neo
            )
            memory_target = (
                memory_original if algorithm == "3dgs".lower() else memory_neo
            )

            runtime_target["preprocess"] = float(row["Feature Extraction (ms)"])
            runtime_target["sorting"] = float(row["Sorting (ms)"])
            runtime_target["rasterization"] = float(row["Rasterization (ms)"])

            memory_target["preprocess"] = float(row["Feature Extraction (GB)"])
            memory_target["sorting"] = float(row["Sorting (GB)"])
            memory_target["rasterization"] = float(row["Rasterization (GB)"])

    runtime_path = os.path.join(summary_path, "figure_10_runtime.pdf")
    memory_path = os.path.join(summary_path, "figure_10_memory.pdf")

    _draw_figure_10(runtime_original, runtime_neo, runtime_path, 120)
    _draw_figure_10(memory_original, memory_neo, memory_path, 360)


def _draw_figure_15(target_path, orin, gscore, neo):
    orin_hd_mean = sum(orin[0::3]) / 6
    orin_fhd_mean = sum(orin[1::3]) / 6
    orin_qhd_mean = sum(orin[2::3]) / 6

    orin.append(orin_hd_mean)
    orin.append(orin_fhd_mean)
    orin.append(orin_qhd_mean)

    gscore_hd_mean = sum(gscore[0::3]) / 6
    gscore_fhd_mean = sum(gscore[1::3]) / 6
    gscore_qhd_mean = sum(gscore[2::3]) / 6

    gscore.append(gscore_hd_mean)
    gscore.append(gscore_fhd_mean)
    gscore.append(gscore_qhd_mean)

    neo_hd_mean = sum(neo[0::3]) / 6
    neo_fhd_mean = sum(neo[1::3]) / 6
    neo_qhd_mean = sum(neo[2::3]) / 6

    neo.append(neo_hd_mean)
    neo.append(neo_fhd_mean)
    neo.append(neo_qhd_mean)

    orin_fps = [1000 / latency for latency in orin]
    gscore_fps = [1000 / latency for latency in gscore]
    neo_fps = [1000 / latency for latency in neo]

    labels = ["" for _ in range(21)]

    x = np.arange(len(labels))
    width = 0.27

    fig, ax = plt.subplots(figsize=(10, 2))

    ax.bar(
        x - width,
        orin_fps,
        width,
        label="Orin AGX",
        edgecolor="black",
        color=LIGHT_GREEN,
        zorder=5,
    )
    ax.bar(
        x,
        gscore_fps,
        width,
        label="GSCore",
        edgecolor="black",
        color=MEDIUM_GREEN,
        zorder=5,
    )
    ax.bar(
        x + width,
        neo_fps,
        width,
        label="Neo",
        edgecolor="black",
        color=DARK_GREEN,
        zorder=5,
    )

    ax.set_xlim(-0.5, len(labels) - 0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(["" for _ in labels])

    max_value = 200
    ranges = range(0, max_value + 1, max_value // 10)
    ax.set_yticks(ranges)
    ax.set_ylim(0, max_value)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_15(summary_path):
    orin_csv_path = os.path.join(summary_path, "orin", "orin_figure_15.csv")
    server_csv_path = os.path.join(summary_path, "server", "server_figure_15.csv")

    gscore = [
        12.434720805908345,
        25.201638551764496,
        48.32481278238982,
        9.817504610491794,
        21.108990609263323,
        42.38490203149417,
        14.737847861690987,
        31.854993726931433,
        64.88322312750556,
        10.782843426711873,
        23.768103977715487,
        48.030916451969084,
        17.79998298337915,
        35.17832139033029,
        66.40176600441502,
        16.485350737449536,
        33.77635468030948,
        65.96375043569189,
    ]

    scene_list = [
        "family",
        "francis",
        "lighthouse",
        "horse",
        "playground",
        "train",
    ]
    resolution_list = ["HD", "FHD", "QHD"]

    def load_runtime(csv_path, algorithm):
        runtime_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != algorithm:
                    continue

                scene = row["Scene"].strip().lower()
                resolution = row["Resolution"].strip().upper()
                runtime_map[(scene, resolution)] = float(row["Runtime (ms)"])

        return runtime_map

    orin_runtime = load_runtime(orin_csv_path, "3dgs")
    neo_runtime = load_runtime(server_csv_path, "neo")

    def build_sequence(runtime_map):
        sequence = []
        for scene in scene_list:
            for resolution in resolution_list:
                key = (scene, resolution)
                if key not in runtime_map:
                    raise ValueError(
                        f"Missing runtime for scene '{scene}' at resolution '{resolution}'"
                    )
                sequence.append(runtime_map[key])
        return sequence

    orin = build_sequence(orin_runtime)
    neo = build_sequence(neo_runtime)

    target_path = os.path.join(summary_path, "figure_15.pdf")
    _draw_figure_15(target_path, orin, gscore, neo)


def _draw_figure_16(target_path, orin, gscore, neo):
    labels = ["" for i in range(6)]
    x = np.arange(len(labels))
    width = 0.27

    colors = [LIGHT_GREEN, MEDIUM_GREEN, DARK_GREEN]

    fig, ax = plt.subplots(figsize=(4.5, 1.5))

    ax.bar(x - width, orin, width, color=colors[0], edgecolor="black", zorder=3)
    ax.bar(x, gscore, width, color=colors[1], edgecolor="black", zorder=3)
    ax.bar(x + width, neo, width, color=colors[2], edgecolor="black", zorder=3)

    ax.set_xlim(-0.5, len(labels) - 0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(labels)

    max_value = 140
    ranges = range(0, max_value + 1, max_value // 7)
    ax.set_yticks(ranges)
    ax.set_ylim(0, max_value)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_16(summary_path):
    orin_csv_path = os.path.join(summary_path, "orin", "orin_figure_16.csv")
    server_csv_path = os.path.join(summary_path, "server", "server_figure_16.csv")

    gscore = [90.6148, 79.3624, 120.6724, 89.5536, 123.67760000000001, 123.4644]

    scene_list = [
        "family",
        "francis",
        "lighthouse",
        "horse",
        "playground",
        "train",
    ]

    def load_orin(csv_path):
        traffic_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != "3dgs":
                    continue
                scene = row["Scene"].strip().lower()
                traffic_map[scene] = float(row["Traffic (GB)"])
        return traffic_map

    def load_neo(csv_path):
        traffic_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != "neo":
                    continue
                if row["Resolution"].strip().upper() != "QHD":
                    continue
                scene = row["Scene"].strip().lower()
                traffic_map[scene] = float(row["Traffic (GB)"])
        return traffic_map

    def build_sequence(traffic_map):
        sequence = []
        for scene in scene_list:
            if scene not in traffic_map:
                raise ValueError(f"Missing traffic value for scene '{scene}'")
            sequence.append(traffic_map[scene])
        return sequence

    orin = build_sequence(load_orin(orin_csv_path))
    neo = build_sequence(load_neo(server_csv_path))

    target_path = os.path.join(summary_path, "figure_16.pdf")
    _draw_figure_16(target_path, orin, gscore, neo)


def _draw_figure_17_A(target_path, orin, gscore, neo):
    orin_fps = [1000 / latency for latency in orin]
    gscore_fps = [1000 / latency for latency in gscore]
    neo_fps = [1000 / latency for latency in neo]

    labels = ["Building", "Rubble"]
    x = np.arange(len(labels))
    width = 0.27

    colors = [LIGHT_GREEN, MEDIUM_GREEN, DARK_GREEN]

    fig, ax = plt.subplots(figsize=(1.5, 1.5))

    ax.bar(x - width, orin_fps, width, color=colors[0], edgecolor="black", zorder=3)
    ax.bar(x, gscore_fps, width, color=colors[1], edgecolor="black", zorder=3)
    ax.bar(x + width, neo_fps, width, color=colors[2], edgecolor="black", zorder=3)

    ax.set_xlim(-0.5, len(labels) - 0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(["" for _ in labels])

    max_value = 100
    ranges = range(0, max_value + 1, max_value // 4)
    ax.set_yticks(ranges)
    ax.set_ylim(0, max_value)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def _draw_figure_17_B(target_path, neo):
    neo_fps = [1000 / x for x in neo]

    x_labels = range(len(neo_fps))
    x = range(len(x_labels))

    fig, ax = plt.subplots(figsize=(1.5, 1.5))

    ax.plot(x, neo_fps, "o-", color=DARK_GREEN, linewidth=2, markersize=6, zorder=5)
    ax.plot(
        x,
        neo_fps,
        "o-",
        color="black",
        linewidth=4,
        markersize=8,
        markeredgewidth=1,
        markeredgecolor="black",
        zorder=4,
    )

    ax.set_xlim(-0.5, len(x_labels) - 0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(["" for _ in x_labels])

    min_value = 70
    max_value = 100
    ranges = range(min_value, max_value + 1, 5)
    ax.set_ylim(min_value, max_value)
    ax.set_yticks(ranges)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_17(summary_path):
    orin_csv_path = os.path.join(summary_path, "orin", "orin_figure_17.csv")
    server_csv_A_path = os.path.join(summary_path, "server", "server_figure_17_A.csv")
    server_csv_B_path = os.path.join(summary_path, "server", "server_figure_17_B.csv")

    gscore = [49.036558715812056, 50.80617206808035]

    scene_list = ["building", "rubble"]
    step_list = ["1", "2", "4", "8", "16"]

    def load_orin(csv_path):
        runtime_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != "3dgs":
                    continue
                scene = row["Scene"].strip().lower()
                runtime_map[scene] = float(row["Runtime (ms)"])
        return runtime_map

    def load_server_A(csv_path):
        runtime_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != "neo":
                    continue
                if row["Resolution"].strip().upper() != "QHD":
                    continue
                scene = row["Scene"].strip().lower()
                runtime_map[scene] = float(row["Runtime (ms)"])
        return runtime_map

    def build_sequence(runtime_map, keys):
        sequence = []
        for key in keys:
            if key not in runtime_map:
                raise ValueError(f"Missing runtime for key '{key}'")
            sequence.append(runtime_map[key])
        return sequence

    def load_server_B(csv_path):
        runtime_map = {}
        with open(csv_path, mode="r", newline="") as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                if row["Algorithm"].strip().lower() != "neo":
                    continue
                if row["Resolution"].strip().upper() != "QHD":
                    continue
                step = row["Step"].strip()
                runtime_map[step] = float(row["Runtime (ms)"])
        return runtime_map

    orin = build_sequence(load_orin(orin_csv_path), scene_list)
    neo_A = build_sequence(load_server_A(server_csv_A_path), scene_list)
    neo_B = build_sequence(load_server_B(server_csv_B_path), step_list)

    target_path_A = os.path.join(summary_path, "figure_17_large_scale_scene.pdf")
    _draw_figure_17_A(target_path_A, orin, gscore, neo_A)

    target_path_B = os.path.join(summary_path, "figure_17_rapid_camera_movement.pdf")
    _draw_figure_17_B(target_path_B, neo_B)


def _draw_figure_18(target_path, gscore, neo_s, neo, max_value):
    labels = ["gscore", "neo-s", "neo"]

    fig, ax = plt.subplots(figsize=(2.2, 1.5))

    colors = [LIGHT_GREEN, MEDIUM_GREEN, DARK_GREEN]

    ax.bar(labels[0], gscore / gscore, color=colors[0], edgecolor="black", zorder=3)
    ax.bar(labels[1], neo_s / gscore, color=colors[1], edgecolor="black", zorder=3)
    ax.bar(labels[2], neo / gscore, color=colors[2], edgecolor="black", zorder=3)

    ax.set_xticklabels(["", "", ""])

    ranges = [i * max_value / 4 for i in range(5)]
    ax.set_yticks(ranges)
    ax.set_ylim(0, max_value)
    ax.set_yticklabels(["" for _ in ranges])
    ax.yaxis.grid(True, linestyle="-", linewidth=1, color="lightgray", zorder=0)

    plt.tight_layout()
    plt.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_18(summary_path):
    server_csv_path = os.path.join(summary_path, "server", "server_figure_18.csv")

    gscore_fps = 20.6933031381
    gscore_traffic = 90.6148

    neo_fps = None
    neo_traffic = None
    neo_s_fps = None
    neo_s_traffic = None

    with open(server_csv_path, mode="r", newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            algorithm = row["Algorithm"].strip().lower()
            runtime_ms = float(row["Runtime (ms)"])
            traffic_gb = float(row["Traffic (GB)"])

            if algorithm == "neo":
                neo_fps = 1000 / runtime_ms
                neo_traffic = traffic_gb
            elif algorithm == "neo-s":
                neo_s_fps = 1000 / runtime_ms
                neo_s_traffic = traffic_gb

    if None in (neo_fps, neo_traffic, neo_s_fps, neo_s_traffic):
        raise ValueError("Missing Neo or Neo-S data in server_figure_18.csv")

    target_path_A = os.path.join(summary_path, "figure_18_runtime.pdf")
    _draw_figure_18(target_path_A, gscore_fps, neo_s_fps, neo_fps, 6.0)

    target_path_B = os.path.join(summary_path, "figure_18_traffic.pdf")
    _draw_figure_18(target_path_B, gscore_traffic, neo_s_traffic, neo_traffic, 1)


def _draw_figure_19_A(
    target_path, neo, periodic_sorting, background_sorting, hierarchical_sorting, N
):
    x = np.arange(N)

    plt.plot(x, neo[:N], linestyle="-", color=DARK_GREEN, zorder=5)
    plt.plot(x, periodic_sorting[:N], linestyle="-", color=YELLOW, zorder=2)
    plt.plot(x, background_sorting[:N], linestyle="-", color=ORANGE, zorder=3)
    plt.plot(x, hierarchical_sorting[:N], linestyle="-", color=MEDIUM_GREEN, zorder=4)

    for line in plt.gca().get_lines():
        line.set_linewidth(2)

    plt.axhline(y=0.017, color="brown", linestyle="--", linewidth=1.5, zorder=6)

    ax = plt.gca()
    ax.set_xlim(0, N)
    ax.set_xticks(range(0, N + 1, 15))
    ax.set_xticklabels([])

    ax.set_ylim(0.01, 0.025)
    ax.set_yticks([0.01, 0.015, 0.02, 0.025])
    ax.set_yticklabels([])

    fig = plt.gcf()
    fig.set_figheight(1.1)
    fig.set_figwidth(4)

    fig.tight_layout()
    plt.grid(True, zorder=0)
    fig.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def _draw_figure_19_B(
    target_path, neo, periodic_sorting, background_sorting, hierarchical_sorting, N
):
    x = np.arange(N)

    plt.plot(x, neo[:N], linestyle="-", color=DARK_GREEN, zorder=5, linewidth=1.5)
    plt.plot(
        x, periodic_sorting[:N], linestyle="-", color=YELLOW, zorder=2, linewidth=2
    )
    plt.plot(
        x, background_sorting[:N], linestyle="-", color=ORANGE, zorder=3, linewidth=2
    )
    plt.plot(
        x,
        hierarchical_sorting[:N],
        linestyle="-",
        color=MEDIUM_GREEN,
        zorder=4,
        linewidth=2,
    )

    ax = plt.gca()
    ax.set_xlim(0, N)
    ax.set_xticks(range(0, N + 1, 15))
    ax.set_xticklabels([])

    ax.set_ylim(10, 30)
    ax.set_yticks(range(10, 31, 5))
    ax.set_yticklabels([])

    fig = plt.gcf()
    fig.set_figheight(1.1)
    fig.set_figwidth(4)

    fig.tight_layout()
    plt.grid(True, zorder=1)
    fig.savefig(target_path, format="pdf", bbox_inches="tight", dpi=600)

    try:
        subprocess.run(["pdfcrop", target_path, target_path], check=True)
    except FileNotFoundError:
        print("pdfcrop not found; skipping cropping step")
    except subprocess.CalledProcessError as exc:
        print(f"pdfcrop failed with exit code {exc.returncode}; saved uncropped PDF")


def draw_figure_19(summary_path):
    server_csv_path = os.path.join(summary_path, "server", "server_figure_19.csv")

    N = 165

    latency_map = {
        "neo": [],
        "periodic sorting": [],
        "background sorting": [],
        "hierarchical sorting": [],
    }
    psnr_map = {
        "neo": [],
        "periodic sorting": [],
        "background sorting": [],
        "hierarchical sorting": [],
    }

    with open(server_csv_path, mode="r", newline="") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            algorithm = row["Algorithm"].strip().lower()
            if algorithm not in latency_map:
                continue

            frame_idx = int(row["Frame"])
            runtime_ms = float(row["Runtime (ms)"])
            psnr = float(row["PSNR (dB)"])

            latency_map[algorithm].append((frame_idx, runtime_ms / 1000.0))
            psnr_map[algorithm].append((frame_idx, psnr))

    def sorted_values(map_entry):
        if not map_entry:
            return []
        map_entry.sort(key=lambda x: x[0])
        return [value for _, value in map_entry]

    neo = sorted_values(latency_map["neo"])
    periodic_sorting = sorted_values(latency_map["periodic sorting"])
    background_sorting = sorted_values(latency_map["background sorting"])
    hierarchical_sorting = sorted_values(latency_map["hierarchical sorting"])

    neo_psnr = sorted_values(psnr_map["neo"])
    periodic_psnr = sorted_values(psnr_map["periodic sorting"])
    background_psnr = sorted_values(psnr_map["background sorting"])
    hierarchical_psnr = sorted_values(psnr_map["hierarchical sorting"])

    required = [
        neo,
        periodic_sorting,
        background_sorting,
        hierarchical_sorting,
        neo_psnr,
        periodic_psnr,
        background_psnr,
        hierarchical_psnr,
    ]
    if any(len(arr) < N for arr in required):
        raise ValueError(
            f"Not enough frame data to plot figure 19 (need at least {N} frames for each algorithm)"
        )

    target_path_A = os.path.join(summary_path, "figure_19_latency.pdf")
    _draw_figure_19_A(
        target_path_A,
        neo,
        periodic_sorting,
        background_sorting,
        hierarchical_sorting,
        N,
    )

    target_path_B = os.path.join(summary_path, "figure_19_accuracy.pdf")
    _draw_figure_19_B(
        target_path_B, neo_psnr, periodic_psnr, background_psnr, hierarchical_psnr, N
    )
