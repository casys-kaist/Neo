import argparse

import neo_ae

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--figure_idx", type=int, default=0, help="figure index")
    parser.add_argument("--summary_path", type=str, default="", help="summary path")
    args = parser.parse_args()

    neo_ae.draw(figure_idx=args.figure_idx, summary_path=args.summary_path)
