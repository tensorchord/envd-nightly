import argparse
import os
from time import perf_counter
import subprocess
from typing import List, Dict
import pandas as pd
import seaborn as sns


COMMANDS: Dict[str, List[str]] = {
    "envd-cpu": ["envd", "build"],
    "envd-gpu": ["envd", "build", "-f", ":gpu_build"],
    "docker-cpu": ["docker", "buildx", "build", "-f", "Dockerfile", "."],
    "docker-gpu": ["docker", "buildx", "build", "-f", "gpu.Dockerfile", "."],
}
NAMES = list(COMMANDS.keys())


parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument("--path", required=True, help="path for the saved data file")


def envd_version() -> str:
    version = subprocess.check_output(
        ["envd", "version", "--short"], universal_newlines=True
    ).strip()
    ver = version.rsplit(" ", 1)[-1][1:]
    return ver


def record(cmd: List[str]) -> float:
    t0 = perf_counter()
    code = subprocess.call(cmd)
    if code != 0:
        print("ERROR: ", cmd)
        return float("inf")

    return perf_counter() - t0


def run() -> List[float]:
    res = []
    for cmd in COMMANDS.values():
        res.append(record(cmd))
    print(res)
    return res


def render(data: pd.DataFrame):
    sns.set_theme(style="whitegrid")
    ax = sns.lineplot(data=data, palette="tab10", linewidth=2.5)
    ax.get_figure().savefig("benchmark.png")


def combine(record: List[float], path: str) -> pd.DataFrame:
    old = pd.DataFrame(columns=NAMES)
    if os.path.isfile(path):
        old = pd.read_csv(path)
    data = pd.concat([old, pd.DataFrame([record], columns=NAMES)])
    data.to_csv(path)
    return data


if __name__ == "__main__":
    args = parser.parse_args()
    res = run()
    data = combine(res, args.path)
    render(data)
