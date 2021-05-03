#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

set -x

# ルート認証局の作成 (既に証明書が存在する場合はスキップ)
mkdir -p $CERTS_DIR 2>/dev/null || sudo mkdir -p $CERTS_DIR
# $CERTS_DIR への書き込みに sudo が必要かどうかを判定 (必要ないなら使わず現在のユーザで作成)
[ ! -w $CERTS_DIR ] && SUDO=sudo
cd $CERTS_DIR
if [ ! -e $CA_CERT ]; then
  openssl genrsa 2048 | $SUDO tee $CA_PRIV_KEY
  $SUDO chmod 400 $CA_PRIV_KEY
  $SUDO openssl req -new -key $CA_PRIV_KEY -subj "${SUBJ_BASE}/CN=${CA_CN}" | $SUDO tee $CA_CSR
  $SUDO openssl x509 -req -in $CA_CSR -signkey $CA_PRIV_KEY -CAcreateserial  -out $CA_CERT -days $DAYS
  openssl x509 -noout -text -in $CA_CERT
fi

# サーバ証明書の作成
$SUDO mkdir -p "$SRV_CN" && cd "$SRV_CN"
if [ ! -e $SRV_CERT ]; then
  openssl genrsa 2048 | $SUDO tee $SRV_PRIV_KEY
  $SUDO chmod 400 $SRV_PRIV_KEY
  $SUDO openssl req -new -key $SRV_PRIV_KEY -out $SRV_CSR -subj "${SUBJ_BASE}/CN=$SRV_CN"
  echo "subjectAltName = $SRV_SAN" | $SUDO tee ext.txt
  $SUDO openssl x509 -req -in $SRV_CSR -CA ../$CA_CERT -CAkey ../$CA_PRIV_KEY -CAcreateserial -days $DAYS -out $SRV_CERT -extfile ext.txt
  cat $SRV_CERT ../$CA_CERT | $SUDO tee $SRV_FULL_CERT
fi

# ルート認証局証明書のシステムへのインストール
cd $CERTS_DIR
sudo install -m 644 $CA_CERT /usr/local/share/ca-certificates/$CA_CN.crt
sudo update-ca-certificates

# /etc/hosts に追加
cat <<EOS | sudo tee -a /etc/hosts
$SRV_IP  $SRV_CN
EOS

