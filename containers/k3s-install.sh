#!/usr/bin/env bash

# add the rancher yum repo for selinux support
if command -v rpm &>/dev/null; then
    echo "RPM-based system detected, installing prerequisites for SELinux support"

    sudo tee -a /etc/yum.repos.d/rancher-k3s-common-latest.repo <<EOF
[rancher-k3s-common-latest]
name=Rancher k3s Common Latest
baseurl=https://rpm.rancher.io/k3s/latest/common/coreos/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

fi

# install k3s (with optional release channel)
#export INSTALL_K3S_CHANNEL=v1.37
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --prefer-bundled-bin" sh -s -

# update kubeconfig
cp "${KUBECONFIG}" "${KUBECONFIG}.old"
kubectl config delete-context k3s || true
kubectl config delete-user k3s || true
kubectl config delete-cluster k3s || true
sudo install -m 600 -o "${USER}" -g "${USER}" /etc/rancher/k3s/k3s.yaml /tmp/k3s.config
sed -i "s/default/k3s/g" /tmp/k3s.config
KUBECONFIG="${KUBECONFIG}:/tmp/k3s.config" kubectl config view --merge --flatten >/tmp/new.config
mv /tmp/new.config "${KUBECONFIG}"
rm /tmp/k3s.config

# set k3s as default context
kubectl config set-context k3s
