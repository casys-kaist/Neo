try:
    # for orin device
    import gaussian_splatting_frontend
    import neo_sw_frontend
except:
    pass

try:
    # for server
    import neo_trace_frontend
except:
    pass

from .env import *


def run_figure_5():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        if ALGORITHM == "gs":
            gaussian_splatting_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )


def run_figure_10():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        if ALGORITHM == "gs":
            gaussian_splatting_runtime = gaussian_splatting_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )

            if RUNTIME_MEASUREMENT:
                with open(
                    f"{OUTPUT_PATH}/orin-gs-runtime.txt",
                    mode="w",
                ) as f:
                    f.write(f"{gaussian_splatting_runtime}\n")
        elif ALGORITHM == "neo":
            neo_sw_runtime = neo_sw_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )

            if RUNTIME_MEASUREMENT:
                with open(
                    f"{OUTPUT_PATH}/orin-neo-runtime.txt",
                    mode="w",
                ) as f:
                    f.write(f"{neo_sw_runtime}\n")


def run_figure_15():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        if ALGORITHM == "gs":
            gaussian_splatting_runtime = gaussian_splatting_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )

            if RUNTIME_MEASUREMENT:
                with open(
                    f"{OUTPUT_PATH}/orin-gs-{SCENE}-{RESOLUTION}-runtime.txt",
                    mode="w",
                ) as f:
                    f.write(f"{gaussian_splatting_runtime}\n")
    elif DEVICE == "neo":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )


def run_figure_16():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        if ALGORITHM == "gs":
            gaussian_splatting_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )


def run_figure_17():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "orin":
        if ALGORITHM == "gs":
            gaussian_splatting_runtime = gaussian_splatting_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{RESOLUTION}",
                RESOLUTION,
                ITERATION,
                False,
            )

            if RUNTIME_MEASUREMENT:
                with open(
                    f"{OUTPUT_PATH}/{DEVICE}-gs-{SCENE}-QHD-runtime.txt",
                    mode="w",
                ) as f:
                    f.write(f"{gaussian_splatting_runtime}\n")
    elif DEVICE == "neo":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )


def run_figure_18():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "neo_s":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )


def run_figure_19():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "neo":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )
    elif DEVICE == "periodic_sorting":
        if ALGORITHM == "periodic_sorting":
            neo_trace_frontend.mode.periodic_sorting.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )
    elif DEVICE == "background_sorting":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )
        elif ALGORITHM == "background_sorting":
            neo_trace_frontend.mode.background_sorting.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )
    elif DEVICE == "neo_hs":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )


def run_table_2():
    DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE = get_environment()
    RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT = get_workload()

    if DEVICE == "neo":
        if ALGORITHM == "neo":
            neo_trace_frontend.run(
                f"{DATASET_PATH}/{SCENE}",
                f"{MODEL_PATH}/{SCENE}",
                f"{OUTPUT_PATH}/{DEVICE}/{SCENE}/{RESOLUTION}",
                YAML_PATH,
            )
