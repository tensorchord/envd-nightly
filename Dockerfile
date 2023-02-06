ARG base=ubuntu:20.04

FROM tensorchord/envd-sshd-from-scratch:v0.3.11 as sshd
FROM tensorchord/horust:v0.2.1 as horust

FROM ${base}

ENV DEBIAN_FRONTEND=noninteractive LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y apt-utils && \
    apt-get install -y --no-install-recommends --fix-missing \
        bash-static \
        libtinfo5 \
        libncursesw5 \
        bzip2 \
        ca-certificates \
        git \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        libxrender1 \
        mercurial \
        openssh-client \
        procps \
        subversion \
        wget \
        curl \
        openssh-client \
        sudo \
        vim \
        zsh \
        locales \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://starship.rs/install.sh | sh -s -- -y && \
    locale-gen en_US.UTF-8

ENV PATH /opt/conda/bin:$PATH

ARG CONDA_VERSION=py39_4.11.0

RUN set -x && \
    UNAME_M="$(uname -m)" && \
    if [ "${UNAME_M}" = "x86_64" ]; then \
	    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh"; \
	    SHA256SUM="4ee9c3aa53329cd7a63b49877c0babb49b19b7e5af29807b793a76bdb1d362b4"; \
    elif [ "${UNAME_M}" = "s390x" ]; then \
	    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-s390x.sh"; \
	    SHA256SUM="e5e5e89cdcef9332fe632cd25d318cf71f681eef029a24495c713b18e66a8018"; \
    elif [ "${UNAME_M}" = "aarch64" ]; then \
	    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-aarch64.sh"; \
	    SHA256SUM="00c7127a8a8d3f4b9c2ab3391c661239d5b9a88eafe895fd0f3f2a8d9c0f4556"; \
    elif [ "${UNAME_M}" = "ppc64le" ]; then \
	    MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-ppc64le.sh"; \
	    SHA256SUM="8ee1f8d17ef7c8cb08a85f7d858b1cb55866c06fcf7545b98c3b82e4d0277e66"; \
    fi && \
    wget "${MINICONDA_URL}" -O miniconda.sh -q && \
    echo "${SHA256SUM} miniconda.sh" > shasum && \
    if [ "${CONDA_VERSION}" != "latest" ]; then sha256sum --check --status shasum; fi && \
    mkdir -p /opt/conda && \
    sh miniconda.sh -b -u -p /opt/conda && \
    touch ~/.bashrc && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    echo -e "channels:\n  - defaults" > /opt/conda/.condarc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy && \
    rm miniconda.sh

RUN conda create -n envd python=3.9

ENV ENVD_PREFIX=/opt/conda/envs/envd/bin

RUN update-alternatives --install /usr/bin/python python ${ENVD_PREFIX}/python 1 && \
    update-alternatives --install /usr/bin/python3 python3 ${ENVD_PREFIX}/python3 1 && \
    update-alternatives --install /usr/bin/pip pip ${ENVD_PREFIX}/pip 1 && \
    update-alternatives --install /usr/bin/pip3 pip3 ${ENVD_PREFIX}/pip3 1

RUN ${ENVD_PREFIX}/pip install ipython numpy

COPY --from=sshd /usr/bin/envd-sshd /var/envd/bin/envd-sshd
COPY --from=horust / /usr/local/bin/

RUN groupadd -g 1000 envd && \
    useradd -p "" -u 1000 -g envd -s /bin/sh -m envd && \
    usermod -a -G sudo envd && \
    install -d -o envd -g 1000 -m 0700 /home/envd/.config /home/envd/.cache

USER envd
WORKDIR /home/envd
