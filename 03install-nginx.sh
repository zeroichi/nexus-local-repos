#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

set -x

echo "[INFO] nginx をインストール中..."
sudo apt-get install -y nginx

echo "[INFO] nginx の設定ファイルを作成中..."
sudo install -m 644 $SCRIPT_DIR/templates/nginx/nexus.conf /etc/nginx/sites-available/
sudo install -m 644 $SCRIPT_DIR/templates/nginx/nexus-dockerhub.conf /etc/nginx/sites-available/
sudo sed -e "s=%CERTS_DIR%=$CERTS_DIR=g" \
         -e "s=%SRV_CN%=$SRV_CN=g" \
         -e "s=%SRV_FULL_CERT%=$SRV_FULL_CERT=g" \
         -e "s=%SRV_PRIV_KEY%=$SRV_PRIV_KEY=g" \
         -e "s=%DOCKER_ACCESS_PORT%=$DOCKER_ACCESS_PORT=g" \
         -i \
         /etc/nginx/sites-available/nexus.conf \
         /etc/nginx/sites-available/nexus-dockerhub.conf

sudo ln -fs /etc/nginx/sites-available/nexus.conf /etc/nginx/sites-enabled/nexus.conf
sudo ln -fs /etc/nginx/sites-available/nexus-dockerhub.conf /etc/nginx/sites-enabled/nexus-dockerhub.conf

echo "[INFO] nginx 構文チェック"
if ! sudo nginx -t; then
    echo "[ERROR] nginx の構文チェックエラー"
    echo "/etc/nginx/sites-available/ 以下の .conf ファイルを確認してください"
    exit 1
fi

echo "[INFO] nginx 設定リロード"
sudo systemctl reload nginx
