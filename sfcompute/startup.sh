#!/usr/bin/env bash
set -euxo pipefail

# 1) Ensure SSH keys for root (so you can actually log in)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat >> /root/.ssh/authorized_keys <<"EOF"
# paste one or more public keys here
ssh-ed25519 AAAA... you@host
EOF
chmod 600 /root/.ssh/authorized_keys

# 2) (Optional) Basic packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl ca-certificates

# 3) (Optional) Your setup
# git clone https://github.com/you/your-repo.git /opt/your-repo
# bash /opt/your-repo/scripts/bootstrap.sh
