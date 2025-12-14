from .draw import *
from .env import *
from .postprocess import *
from .run import *

FIGURE_BASE = 0
TABLE_BASE = 1000


def init(dataset_path, model_path, yaml_path, output_path, device):
    set_environment(dataset_path, model_path, yaml_path, output_path, device)


def init_workload(resolution, scene, iteration, algorithm, runtime_measurement):
    set_workload(resolution, scene, iteration, algorithm, runtime_measurement)


def draw(figure_idx, summary_path):
    if figure_idx == FIGURE_BASE + 5:
        draw_figure_5(summary_path)
    elif figure_idx == FIGURE_BASE + 10:
        draw_figure_10(summary_path)
    elif figure_idx == FIGURE_BASE + 15:
        draw_figure_15(summary_path)
    elif figure_idx == FIGURE_BASE + 16:
        draw_figure_16(summary_path)
    elif figure_idx == FIGURE_BASE + 17:
        draw_figure_17(summary_path)
    elif figure_idx == FIGURE_BASE + 18:
        draw_figure_18(summary_path)
    elif figure_idx == FIGURE_BASE + 19:
        draw_figure_19(summary_path)


def run(figure_idx):
    if figure_idx == FIGURE_BASE + 5:
        run_figure_5()
    elif figure_idx == FIGURE_BASE + 10:
        run_figure_10()
    elif figure_idx == FIGURE_BASE + 15:
        run_figure_15()
    elif figure_idx == FIGURE_BASE + 16:
        run_figure_16()
    elif (
        figure_idx == FIGURE_BASE + 17
        or figure_idx == FIGURE_BASE + 170
        or figure_idx == FIGURE_BASE + 171
    ):
        run_figure_17()
    elif figure_idx == FIGURE_BASE + 18:
        run_figure_18()
    elif figure_idx == FIGURE_BASE + 19:
        run_figure_19()
    elif figure_idx == TABLE_BASE + 2:
        run_table_2()


def postprocess(figure_idx):
    if figure_idx == FIGURE_BASE + 5:
        postprocess_figure_5()
    elif figure_idx == FIGURE_BASE + 10:
        postprocess_figure_10()
    elif figure_idx == FIGURE_BASE + 15:
        postprocess_figure_15()
    elif figure_idx == FIGURE_BASE + 16:
        postprocess_figure_16()
    elif figure_idx == FIGURE_BASE + 17:
        postprocess_figure_17()
    elif figure_idx == FIGURE_BASE + 18:
        postprocess_figure_18()
    elif figure_idx == FIGURE_BASE + 19:
        postprocess_figure_19()
    elif figure_idx == TABLE_BASE + 2:
        postprocess_table_2()
