#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

if [ ! -r $CERTS_DIR/$CA_CERT ]; then
    echo "[ERROR] ルート認証局 証明書ファイル $CERTS_DIR/$CA_CERT が見つからないか、読み込めません。"
    echo "01create-certs.sh を実行して証明書を生成してください。"
    exit 1
fi

echo "==================== Linux 向けセットアップガイド ===================="
echo
echo "端末を開いて bash シェルでログインし、次のスクリプトをペーストして実行してください。"
echo "  a) 証明書のインストール"
echo "  b) docker デーモン設定"
echo "  c) /etc/hosts への登録"
echo "を行います。"
echo
echo "############## ここから"
echo
echo "cat <<EOF | base64 -d | gzip -d - > local-repos-setup.sh && bash local-repos-setup.sh"
# 1. EOF_PRE までの前部分 / 2. $CERTS_DIR/$CA_CERT の証明書の中身 / 3. EOF_POST までの後部分
# を連結し、gzip で固めて端末にペーストできるように base64 化する
COLS=$(tput cols 2>/dev/null)
[ -z "$COLS" -o "$COLS" -eq 0 ] && COLS=80
(cat <<EOF_PRE; cat $CERTS_DIR/$CA_CERT; cat <<EOF_POST) | gzip -c | base64 --wrap=$(($COLS - 3))
echo "[INFO] adding certificates ..."
cat <<EOCERT | sudo tee /usr/local/share/ca-certificates/$CA_CERT >/dev/null
EOF_PRE
EOCERT
sudo update-ca-certificates
echo "[INFO] writing docker daemon config /etc/docker/daemon.json ..."
[ -e /etc/docker/daemon.json ] && sudo cp -ai /etc/docker/daemon.json{,.org}
sudo mkdir -p /etc/docker/
cat <<EOS | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "max-concurrent-downloads": 10,
  "registry-mirrors": [ "https://$SRV_CN:$DOCKER_ACCESS_PORT" ]
}
EOS
echo "[INFO] adding $SRV_CN to /etc/hosts ..."
cat <<EOS | sudo tee -a /etc/hosts
$SRV_IP  $SRV_CN
EOS
echo "[INFO] done"
EOF_POST
echo "EOF"
echo
echo "############## ここまで"
echo
echo "docker をインストールしていない場合は次のコマンドでインストールしてください:"
echo "  curl -fsSL get.docker.com | sh"
echo
echo "インストール済みの場合は次のコマンドで再起動し、設定ファイルを読み込んでください:"
echo "  sudo systemctl restart docker"
echo
echo "設定反映後、 sudo docker pull nginx:latest  などで適当なイメージを pull して動作を確認してください。"
echo
echo "以上で完了です。"
