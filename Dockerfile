FROM nvidia/cuda:13.0.0-runtime-ubuntu22.04

EXPOSE 5000
ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /root

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git wget curl screen python3 python3-venv python3-pip sqlite3 \
      ocl-icd-libopencl1 ocl-icd-opencl-dev clinfo gnupg ca-certificates \
      p7zip-full build-essential libncurses5-dev && \
    rm -rf /var/lib/apt/lists/*

# Intel oneAPI
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
      | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
      > /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update && apt-get install -y --no-install-recommends intel-oneapi-runtime-libs && \
    rm -rf /var/lib/apt/lists/*

# NVIDIA OpenCL ICD (hashcat GPU support)
RUN mkdir -p /etc/OpenCL/vendors && \
    echo "/usr/lib/x86_64-linux-gnu/libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd

# Hashcat 7.x
RUN curl -L https://hashcat.net/files/hashcat-7.1.2.7z -o /tmp/hashcat.7z && \
    7zr x /tmp/hashcat.7z -o /opt/ && \
    ln -s /opt/hashcat-7.1.2/hashcat.bin /usr/local/bin/hashcat && \
    rm -f /tmp/hashcat.7z

RUN git clone --depth=1 https://github.com/Sadykov70/crackerjack.git

RUN python3 -m venv /root/.venv && \
    /root/.venv/bin/pip install --upgrade pip && \
    /root/.venv/bin/pip install -r /root/crackerjack/requirements.txt

WORKDIR /root/crackerjack

# Flask env
ENV PATH="/root/.venv/bin:$PATH"
ENV FLASK_ENV=production
ENV FLASK_APP=app
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Migrations
RUN flask db init && flask db migrate && flask db upgrade

ENTRYPOINT ["flask","run","--host=0.0.0.0"]
