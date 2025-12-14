import os

DATASET_PATH = ""
MODEL_PATH = ""
YAML_PATH = ""
OUTPUT_PATH = ""
DEVICE = "orin"


def set_environment(dataset_path, model_path, yaml_path, output_path, device):
    global DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE
    os.makedirs(output_path, exist_ok=True)

    DATASET_PATH = dataset_path
    MODEL_PATH = model_path
    YAML_PATH = yaml_path
    OUTPUT_PATH = output_path
    DEVICE = device


def get_environment():
    return DATASET_PATH, MODEL_PATH, YAML_PATH, OUTPUT_PATH, DEVICE


SCENE = ""
RESOLUTION = ""
ITERATION = 0
ALGORITHM = "gs"
RUNTIME_MEASUREMENT = False


def set_workload(resolution, scene, iteration, algorithm, runtime_measurement):
    global SCENE, RESOLUTION, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT
    SCENE = scene
    RESOLUTION = resolution
    ITERATION = iteration
    ALGORITHM = algorithm
    RUNTIME_MEASUREMENT = runtime_measurement


def get_workload():
    return RESOLUTION, SCENE, ITERATION, ALGORITHM, RUNTIME_MEASUREMENT
