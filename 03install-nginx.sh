#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

#set -x

# 証明書ファイルの存在をチェック
if [ ! -e $CERTS_DIR/$SRV_CN/$SRV_FULL_CERT -o ! -e $CERTS_DIR/$SRV_CN/$SRV_PRIV_KEY ]; then
    echo "[ERROR] 下記いずれかのサーバ用TLS証明書/秘密鍵ファイルが見つかりません。"
    echo "- $CERTS_DIR/$SRV_CN/$SRV_FULL_CERT"
    echo "- $CERTS_DIR/$SRV_CN/$SRV_PRIV_KEY"
    echo "01create-certs.sh を実行して生成するか、別途用意してある場合は上記パスに配置してください。"
    echo "(パスを変更する場合は config ファイルを編集してください)"
    exit 1
fi

echo "[INFO] nginx をインストール中..."
sudo apt-get install -y nginx

# NEXUS_EXTRA_REPOS が有効のときに使うポート番号
DOCKER_ACCESS_PORT2=$((DOCKER_ACCESS_PORT + 1))

REPO_CONFS=(nexus.conf nexus-dockerhub.conf)
if [ "$NEXUS_EXTRA_REPOS" = Y ]; then
    REPO_CONFS+=(nexus-local-group.conf)
fi

for conf in "${REPO_CONFS[@]}"; do
    echo "[INFO] /etc/nginx/sites-available/$conf を設定中 ..."
    sudo install -m 644 $SCRIPT_DIR/templates/nginx/$conf /etc/nginx/sites-available/$conf
    sudo ln -fs /etc/nginx/sites-available/$conf /etc/nginx/sites-enabled/$conf

    # ファイル中の変数を置換
    sudo sed -e "s=%CERTS_DIR%=$CERTS_DIR=g" \
             -e "s=%SRV_CN%=$SRV_CN=g" \
             -e "s=%SRV_FULL_CERT%=$SRV_FULL_CERT=g" \
             -e "s=%SRV_PRIV_KEY%=$SRV_PRIV_KEY=g" \
             -e "s=%DOCKER_ACCESS_PORT%=$DOCKER_ACCESS_PORT=g" \
             -e "s=%DOCKER_ACCESS_PORT2%=$DOCKER_ACCESS_PORT2=g" \
             -i \
             /etc/nginx/sites-available/$conf
done

if ! sudo nginx -t; then
    echo "[ERROR] nginx の構文チェックエラー"
    echo "/etc/nginx/sites-available/ 以下の .conf ファイルを確認してください"
    exit 1
fi
echo "[INFO] nginx 構文チェック OK"

echo "[INFO] nginx 設定リロード"
sudo systemctl reload nginx

echo "[INFO] 完了しました"
