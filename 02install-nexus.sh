#!/bin/bash

# config ファイルを読み込み
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE:-$0}); pwd)
source $SCRIPT_DIR/config

#set -x

if ! hash docker 2>/dev/null; then
    echo "[INFO] Docker (Community Edition) のインストールを開始します"
    cd /tmp
    curl -fsSL get.docker.com -o get-docker.sh
    sh get-docker.sh
fi

if ! hash jq 2>/dev/null; then
    echo "[INFO] jq コマンドをインストールしています"
    sudo apt-get install -y jq
fi

# 既に nexus のコンテナが稼動しているかチェックする。
# 稼動している場合はエラーを出力して中止する。
COUNT=$(sudo docker ps --all | grep "$NEXUS_CONT_NAME" | wc -l)
if [ "$COUNT" -ge 1 ]; then
    echo "[ERROR] It looks like nexus container (name=$NEXUS_CONT_NAME) already exists. Aborting."
    exit 1
fi

# Check if nexus dir already exists
if [ -d "$NEXUS_DIR" ]; then
    echo "[INFO] Existing Nexus data dir $NEXUS_DIR will be used."
elif [ ! -e "$NEXUS_DIR" ]; then
    echo "[INFO] Creating Nexus data dir $NEXUS_DIR"
    sudo mkdir -p $NEXUS_DIR && sudo chown 200:200 $NEXUS_DIR
    if [ "$?" -ne 0 ]; then
        echo "[ERROR] Failed to create Nexus data dir: $NEXUS_DIR"
        exit 3
    fi
elif [ -f "$NEXUS_DIR" ]; then
    echo "[ERROR] $NEXUS_DIR is not directory"
    exit 1
fi

echo "[INFO] Pulling image ..."
sudo docker pull sonatype/nexus3:latest
echo "[INFO] Starting Nexus repository manager ..."
sudo docker run -d $NEXUS_PORTS --name $NEXUS_CONT_NAME --restart=always -v $NEXUS_DIR:/nexus-data sonatype/nexus3
if [ "$?" -ne 0 ]; then
    echo "[ERROR] Failed to start a Nexus container."
    exit 2
fi

echo -n "Waiting for Nexus starting up (max $NEXUS_CHK_RETRY retries)"
while true; do
    SC=$(curl -o /dev/null -w '%{http_code}\n' -s http://${SRV_CN}:8081/service/rest/v1/status)
    if [ "$SC" -eq 200 ]; then
        break
    fi
    NEXUS_CHK_RETRY=$(($NEXUS_CHK_RETRY - 1))
    if [ "$NEXUS_CHK_RETRY" -eq 0 ]; then
        echo
        echo "Nexus がうまく起動していないようです。"
        echo "ログ (docker logs nexus) などを確認してください。"
        exit 1
    fi
    echo -n "."
    sleep $NEXUS_CHK_INTERVAL
done
echo

ADMIN_PASS=$(cat $NEXUS_DIR/admin.password)

if [ -n "$DOCKERHUB_USER" ]; then
# DOCKERHUB_USER が設定されている場合はパスワードを聞く
    echo "[INFO] Docker Hub から Pull する際のアカウントを設定します"
    read -p "Password for Docker Hub user $DOCKERHUB_USER : " -s DOCKERHUB_PASS
    echo
fi

### Nexus 初期設定
# Realms 設定
curl -f -u "admin:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d@${SCRIPT_DIR}/templates/nexus/realm.conf \
  -X PUT \
  http://${SRV_CN}:8081/service/rest/v1/security/realms/active

# Docker Hub proxy リポジトリ追加
if [ -n "$DOCKERHUB_USER" ]; then
  # パスワード入りのjsonをファイルシステムに保存しないようにするため、sed で生成した json を直接curlに流しこむ
  curl -f -u "admin:$ADMIN_PASS" \
    -H "Content-Type: application/json" \
    "-d@"<(sed -e "s/%DOCKERHUB_USER%/$DOCKERHUB_USER/g" -e "s/%DOCKERHUB_PASS%/$DOCKERHUB_PASS/g" $SCRIPT_DIR/templates/nexus/dockerhub-proxy.conf) \
    http://${SRV_CN}:8081/service/rest/v1/repositories/docker/proxy
else
  # 認証部分を削除して流しこむ
  curl -f -u "admin:$ADMIN_PASS" \
    -H "Content-Type: application/json" \
    "-d@"<(jq "del(.httpClient.authentication)" < $SCRIPT_DIR/templates/nexus/dockerhub-proxy.conf) \
    http://${SRV_CN}:8081/service/rest/v1/repositories/docker/proxy
fi

# ONAP proxy リポジトリ追加
curl -f -u "admin:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d@${SCRIPT_DIR}/templates/nexus/onap-proxy.conf \
  http://${SRV_CN}:8081/service/rest/v1/repositories/docker/proxy

# アクセス用 一般ユーザ追加
curl -f -u "admin:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d@${SCRIPT_DIR}/templates/nexus/user.conf \
  http://${SRV_CN}:8081/service/rest/v1/security/users

# Nexus への匿名アクセス設定
curl -f -u "admin:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d@${SCRIPT_DIR}/templates/nexus/anonymous.conf \
  -X PUT \
  http://${SRV_CN}:8081/service/rest/v1/security/anonymous


echo "Nexus Repository Manager の設定が完了しました。"
echo "ブラウザで http://${SRV_CN}:8081/ にアクセスし、"
echo "admin / $ADMIN_PASS でログインして管理者パスワードを変更してください。"
