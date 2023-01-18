import argparse
import os
from time import perf_counter
import subprocess
from typing import List, Dict

import pandas as pd
import seaborn as sns


COMMANDS: Dict[str, List[str]] = {
    "docker-cpu": ["docker", "buildx", "build", "-f", "Dockerfile", "."],
    "docker-gpu": ["docker", "buildx", "build", "-f", "gpu.Dockerfile", "."],
    "envd-v0-cpu": [
        "envd",
        "build",
        "-f",
        "v0.envd:build",
        "--output",
        "type=image,name=docker.io/tensorchord/python-cpu-v0",
    ],
    "envd-v0-gpu": [
        "envd",
        "build",
        "-f",
        "v0.envd:gpu_build",
        "--output",
        "type=image,name=docker.io/tensorchord/python-gpu-v0",
    ],
    "envd-v1-cpu": [
        "envd",
        "build",
        "-f",
        "v1.envd:build",
        "--output",
        "type=image,name=docker.io/tensorchord/python-cpu-v1",
    ],
    "envd-v1-gpu": [
        "envd",
        "build",
        "-f",
        "v1.envd:gpu_build",
        "--output",
        "type=image,name=docker.io/tensorchord/python-gpu-v1",
    ],
}
NAMES = list(COMMANDS.keys())


parser = argparse.ArgumentParser(description="Process some integers.")
parser.add_argument("--path", required=True, help="path for the saved data file")
parser.add_argument(
    "--github",
    default=False,
    action="store_true",
    help="detect if it's running in the GitHub Actions",
)
args = parser.parse_args()


def envd_version() -> str:
    version = subprocess.check_output(
        ["envd", "version", "--short"], universal_newlines=True
    ).strip()
    ver = version.rsplit(" ", 1)[-1][1:]
    return ver


def record(name: str, cmd: List[str]) -> float:
    # envd needs to bootstrap the buildkitd
    if name.startswith("envd"):
        subprocess.call(["envd", "bootstrap"])

    t0 = perf_counter()

    code = subprocess.call(cmd)
    if code != 0:
        print("ERROR: ", cmd)
        res = float("inf")
    else:
        res = perf_counter() - t0

    # clean cache
    if name.startswith("envd"):
        subprocess.call(["envd", "prune", "--all"])
    else:
        subprocess.call(["docker", "buildx", "prune", "--all"])

    # GitHub Action has limited disk space
    # refer to https://docs.github.com/en/actions/learn-github-actions/variables#default-environment-variables
    if os.environ.get("GITHUB_ACTIONS") or args.github:
        subprocess.run(
            "docker rm -vf $(docker ps -aq) && docker rmi -f $(docker images -aq)",
            check=True,
            shell=True,
        )
    return res


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
    res = run()
    data = combine(res, args.path)
    render(data)
