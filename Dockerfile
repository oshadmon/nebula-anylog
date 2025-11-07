FROM python:3.11-slim AS base

# declare params
ENV ANYLOG_PATH=/app \
    DEBIAN_FRONTEND=noninteractive \
    PROFILER=false
#    IS_LIGHTHOUSE=false \
#    CIDR_OVERLAY_ADDRESS="10.10.1.1/24" \
#    LIGHTHOUSE_IP=10.10.1.1 \
#    LIGHTHOUSE_NODE_IP=172.233.108.122 \
#    OVERLAY_IP=""

WORKDIR $ANYLOG_PATH

# Nebula
#COPY configs/ca.crt $ANYLOG_PATH/nebula/configs/ca.crt
#COPY configs/ca.key $ANYLOG_PATH/nebula/configs/ca.key
#COPY configs/lighthouse.crt $ANYLOG_PATH/nebula/configs/lighthouse.crt
#COPY configs/lighthouse.key $ANYLOG_PATH/nebula/configs/lighthouse.key

COPY config.yml $ANYLOG_PATH/nebula/
COPY config_nebula.py $ANYLOG_PATH/nebula/
COPY deploy_nebula.sh $ANYLOG_PATH/nebula/
COPY export_nebula.sh $ANYLOG_PATH/nebula/
COPY validate_ip_against_cidr.py $ANYLOG_PATH/nebula/
COPY used_ips.txt $ANYLOG_PATH/nebula/

# Install dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get -y install wget && \
   python3 -m pip install --no-cache-dir --upgrade pip pyyaml && \
   apt-get autoremove -y && apt-get clean && \
   rm -rf /var/lib/apt/lists/* /root/.cache /tmp/*

# Make shell scripts executable (important!)
RUN chmod +x $ANYLOG_PATH/nebula/*.sh

FROM base AS deployment

# Run deployment script by default
WORKDIR /app/nebula
#CMD ["bash", "/app/nebula/deploy_nebula.sh"]
WORKDIR /app/
ENTRYPOINT ["/bin/sh"]
