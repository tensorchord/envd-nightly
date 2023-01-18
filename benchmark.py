import argparse
import os
from time import perf_counter
import subprocess
from typing import List, Dict

import pandas as pd
import seaborn as sns


COMMANDS: Dict[str, List[str]] = {
    "envd-v0-cpu": ["envd", "build", "-f", "v0.envd:build"],
    "envd-v0-gpu": ["envd", "build", "-f", "v0.envd:gpu_build"],
    "envd-v1-cpu": ["envd", "build", "-f", "v1.envd:build"],
    "envd-v1-gpu": ["envd", "build", "-f", "v1.envd:gpu_build"],
    "docker-cpu": ["docker", "buildx", "build", "-f", "Dockerfile", "."],
    "docker-gpu": ["docker", "buildx", "build", "-f", "gpu.Dockerfile", "."],
}
NAMES = list(COMMANDS.keys())


parser = argparse.ArgumentParser(description="Process some integers.")
parser.add_argument("--path", required=True, help="path for the saved data file")


def envd_version() -> str:
    version = subprocess.check_output(
        ["envd", "version", "--short"], universal_newlines=True
    ).strip()
    ver = version.rsplit(" ", 1)[-1][1:]
    return ver


def record(name: str, cmd: List[str]) -> float:
    t0 = perf_counter()

    # envd needs to bootstrap the buildkitd
    if name.startswith("envd"):
        subprocess.call(["envd", "bootstrap"])

    code = subprocess.call(cmd)
    if code != 0:
        print("ERROR: ", cmd)
        return float("inf")

    # GitHub Action has limited disk space
    subprocess.run(
        "docker rm -vf $(docker ps -aq) && docker rmi -f $(docker images -aq)",
        check=True,
        shell=True,
    )
    return perf_counter() - t0


def run() -> List[float]:
    res = []
    for name, cmd in COMMANDS.items():
        res.append(record(name, cmd))
    print(res)
    return res


def render(data: pd.DataFrame):
    sns.set_theme(style="whitegrid")
    ax = sns.lineplot(
        data=data, palette="tab10", linewidth=2.5, markers=True, dashes=False
    )
    ax.get_figure().savefig("trend.png")


def combine(record: List[float], path: str) -> pd.DataFrame:
    old = pd.DataFrame(columns=NAMES)
    if os.path.isfile(path):
        old = pd.read_csv(path)
    data = pd.concat(
        [old, pd.DataFrame([record], columns=NAMES)], ignore_index=True, sort=False
    )
    data.to_csv(path, index=False)
    return data


if __name__ == "__main__":
    args = parser.parse_args()
    # res = run()
    res = [10, 20, 30, 40]
    data = combine(res, args.path)
    render(data)
