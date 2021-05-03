#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

set -x

# ルート認証局の作成 (既に証明書が存在する場合はスキップ)
sudo mkdir -p $CERTS_DIR && cd $CERTS_DIR
if [ ! -e $CA_CERT ]; then
  openssl genrsa 2048 | sudo tee $CA_PRIV_KEY
  sudo chmod 400 $CA_PRIV_KEY
  sudo openssl req -new -key $CA_PRIV_KEY -subj "${SUBJ_BASE}/CN=${CA_CN}" | sudo tee $CA_CSR
  sudo openssl x509 -req -in $CA_CSR -signkey $CA_PRIV_KEY -CAcreateserial  -out $CA_CERT -days $DAYS
  openssl x509 -noout -text -in $CA_CERT
fi

# サーバ証明書の作成
sudo mkdir -p "$SRV_CN" && cd "$SRV_CN"
if [ ! -e $SRV_CERT ]; then
  openssl genrsa 2048 | sudo tee $SRV_PRIV_KEY
  sudo chmod 400 $SRV_PRIV_KEY
  sudo openssl req -new -key $SRV_PRIV_KEY -out $SRV_CSR -subj "${SUBJ_BASE}/CN=$SRV_CN"
  echo "subjectAltName = $SRV_SAN" | sudo tee ext.txt
  sudo openssl x509 -req -in $SRV_CSR -CA ../$CA_CERT -CAkey ../$CA_PRIV_KEY -CAcreateserial -days $DAYS -out $SRV_CERT -extfile ext.txt
  cat $SRV_CERT ../$CA_CERT | sudo tee $SRV_FULL_CERT
fi

# ルート認証局証明書のシステムへのインストール
cd $CERTS_DIR
sudo install $CA_CERT /usr/local/share/ca-certificates/$CA_CN.crt
sudo update-ca-certificates

# /etc/hosts に追加
cat <<EOS | sudo tee -a /etc/hosts
$SRV_IP  $SRV_CN
EOS

