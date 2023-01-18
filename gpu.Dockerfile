ARG base=nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04

FROM tensorchord/envd-sshd-from-scratch:v0.3.6 as sshd
FROM tensorchord/horust:v0.2.1 as horust

FROM ${base}

ENV DEBIAN_FRONTEND=noninteractive LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

RUN apt-get update && \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://starship.rs/install.sh | sh -s -- -y && \
    locale-gen en_US.UTF-8

ENV PATH /opt/conda/bin:$PATH

ARG CONDA_VERSION=py310_22.11.1-1

RUN set -x && \
    UNAME_M="$(uname -m)" && \
    if [ "${UNAME_M}" = "x86_64" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-x86_64.sh"; \
        SHA256SUM="00938c3534750a0e4069499baf8f4e6dc1c2e471c86a59caa0dd03f4a9269db6"; \
    elif [ "${UNAME_M}" = "s390x" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-s390x.sh"; \
        SHA256SUM="a150511e7fd19d07b770f278fb5dd2df4bc24a8f55f06d6274774f209a36c766"; \
    elif [ "${UNAME_M}" = "aarch64" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-aarch64.sh"; \
        SHA256SUM="48a96df9ff56f7421b6dd7f9f71d548023847ba918c3826059918c08326c2017"; \
    elif [ "${UNAME_M}" = "ppc64le" ]; then \
        MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-${CONDA_VERSION}-Linux-ppc64le.sh"; \
        SHA256SUM="4c86c3383bb27b44f7059336c3a46c34922df42824577b93eadecefbf7423836"; \
    fi && \
    wget "${MINICONDA_URL}" -O miniconda.sh -q && \
    echo "${SHA256SUM} miniconda.sh" > shasum && \
    if [ "${CONDA_VERSION}" != "latest" ]; then sha256sum --check --status shasum; fi && \
    mkdir -p /opt && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh shasum && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

RUN conda create -n envd python=3.9

ENV ENVD_PREFIX=/opt/conda/envs/envd/bin

RUN update-alternatives --install /usr/bin/python python ${ENVD_PREFIX}/python 1 && \
    update-alternatives --install /usr/bin/python3 python3 ${ENVD_PREFIX}/python3 1 && \
    update-alternatives --install /usr/bin/pip pip ${ENVD_PREFIX}/pip 1 && \
    update-alternatives --install /usr/bin/pip3 pip3 ${ENVD_PREFIX}/pip3 1

RUN ${ENVD_PREFIX}/pip install ipython numpy
RUN ${ENVD_PREFIX}/pip install jax[cuda] -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html

COPY --from=sshd /usr/bin/envd-sshd /var/envd/bin/envd-sshd
COPY --from=horust / /usr/local/bin/

RUN groupadd -g 1000 envd && \
    useradd -p "" -u 1000 -g envd -s /bin/sh -m envd && \
    usermod -a -G sudo envd && \
    install -d -o envd -g 1000 -m 0700 /home/envd/.config /home/envd/.cache

USER envd
WORKDIR /home/envd
