import yaml

config = None
RESOLUTION = (0, 0)


def set_resolution(resolution):
    global RESOLUTION

    if resolution == "HD":
        RESOLUTION = (1280, 720)
    elif resolution == "FHD":
        RESOLUTION = (1920, 1080)
    elif resolution == "QHD":
        RESOLUTION = (2560, 1440)


def get_resolution():
    return RESOLUTION


def set_config(yaml_path):
    global config
    with open(yaml_path, "r") as file:
        config = yaml.safe_load(file)

    set_resolution(config["resolution"])
    set_frame(config["frame"])


def get_config():
    global config
    return config


def get_frame():
    return FRAME


def set_frame(frame):
    global FRAME
    FRAME = frame
