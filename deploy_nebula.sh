#!/bin/bash

# Download and untar nebula
cd "$ANYLOG_PATH/nebula"
mkdir -p configs

NEBULA_VERSION="v1.8.2"
DOWNLOAD_URL="https://github.com/slackhq/nebula/releases/download/${NEBULA_VERSION}"

#if [[ -z "$OVERLAY_IP" ]]; then
#  echo "Missing desired Overlay IP address"
#  exit 1
#elif grep -q "$OVERLAY_IP" "$ANYLOG_PATH/nebula/used_ips.txt"; then
#  echo "IP Address ${OVERLAY_IP} already used, cannot connect to nebula"
#  exit 1
#fi

# Detect architecture
if [ ! -e "$ANYLOG_PATH/nebula/nebula.tar.gz" ]; then
  ARCHITECTURE=$(uname -m)
  case "$ARCHITECTURE" in
    "x86_64")
      DOWNLOAD_LINK="${DOWNLOAD_URL}/nebula-linux-amd64.tar.gz"
      ;;
    "aarch64")
      DOWNLOAD_LINK="${DOWNLOAD_URL}/nebula-linux-arm64.tar.gz"
      ;;
    "armv7l")
      DOWNLOAD_LINK="${DOWNLOAD_URL}/nebula-linux-arm-7.tar.gz"
      ;;
    *)
      echo "Unsupported architecture: $ARCHITECTURE"
      exit 1
      ;;
  esac
  wget "$DOWNLOAD_LINK" -O "$ANYLOG_PATH/nebula/nebula.tar.gz"
  tar -xzvf "$ANYLOG_PATH/nebula/nebula.tar.gz"
fi

if [[ -z "$COMPANY_NAME" ]]; then
  COMPANY_NAME="New Company"
fi

if [[ "${IS_LIGHTHOUSE}" == "true" ]]; then
  # Ensure CA exists (only lighthouse should create it)
  if [ ! -e "$ANYLOG_PATH/nebula/configs/ca.crt" ] || [ ! -e "$ANYLOG_PATH/nebula/configs/ca.key" ]; then
    ./nebula-cert ca -name "$COMPANY_NAME"
    mv ca.crt ca.key "$ANYLOG_PATH/nebula/configs/"
  fi

  # Generate node certs
  if [ ! -e "$ANYLOG_PATH/nebula/configs/lighthouse.crt" ] || [ ! -e "$ANYLOG_PATH/nebula/configs/lighthouse.key" ]; then
    ./nebula-cert sign -name "lighthouse" -ip "${CIDR_OVERLAY_ADDRESS}" \
      -ca-key "$ANYLOG_PATH/nebula/configs/ca.key" \
      -ca-crt "$ANYLOG_PATH/nebula/configs/ca.crt" \
      -out-crt "$ANYLOG_PATH/nebula/configs/lighthouse.crt" \
      -out-key "$ANYLOG_PATH/nebula/configs/lighthouse.key"
  fi

  # Copy files to "root"
  for file in lighthouse.crt lighthouse.key ca.key ca.crt; do
    if [ ! -e "$ANYLOG_PATH/nebula/$file" ] && [ -e "$ANYLOG_PATH/nebula/configs/$file" ]; then
      cp "$ANYLOG_PATH/nebula/configs/$file" "$ANYLOG_PATH/nebula/"
    fi
  done

elif [ ! -e "$ANYLOG_PATH/nebula/configs/host.crt" ] || [ ! -e "$ANYLOG_PATH/nebula/configs/host.key" ]; then
  # Create node certificates
  if [ -e "$ANYLOG_PATH/nebula/ca.key" ]; then
    ./nebula-cert sign -name "host" -ip "${CIDR_OVERLAY_ADDRESS}" \
      -ca-key "$ANYLOG_PATH/nebula/ca.key" \
      -out-crt "$ANYLOG_PATH/nebula/configs/host.crt" \
      -out-key "$ANYLOG_PATH/nebula/configs/host.key" \
      -groups "anylog-node" \
      -duration "8760h"
  else
    echo "Missing CA key — cannot sign host certificate"
    exit 1
  fi

  for file in host.crt host.key; do
    if [ ! -e "$ANYLOG_PATH/nebula/$file" ] && [ -e "$ANYLOG_PATH/nebula/configs/$file" ]; then
      cp "$ANYLOG_PATH/nebula/configs/$file" "$ANYLOG_PATH/nebula/"
    fi
  done
fi

# create config file
CMD="python3 $ANYLOG_PATH/nebula/config_nebula.py ${CIDR_OVERLAY_ADDRESS}"
if [[ ${PORTS} ]] ; then CMD+=" --ports ${PORTS}" ; fi
if [[ "${IS_LIGHTHOUSE}" == "true" ]] ; then
  CMD+=" --is-lighthouse"
elif [[ -n "${LIGHTHOUSE_NODE_IP}" ]] ; then
  CMD+=" --lighthouse-node-ip ${LIGHTHOUSE_NODE_IP}"
else
  echo "Missing lighthouse configuration information"
fi

eval $CMD
if [[ ! -e "${ANYLOG_PATH}/nebula/node.yml" ]] ; then
  echo "Failed to locate nebula config file"
 fi

./nebula -config $ANYLOG_PATH/nebula/node.yml > $ANYLOG_PATH/nebula/nebula.log 2>&1 &

/bin/bash