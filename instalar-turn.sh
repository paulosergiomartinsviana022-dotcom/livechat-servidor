#!/bin/bash
# Instala o servidor de chamadas (TURN / coturn) para o Live Chat na mesma VPS.
# Faz as chamadas de voz/vídeo funcionarem no 4G e em redes fechadas.
set -e
DIR=/opt/livechat
IP=$(curl -4 -fsS https://api.ipify.org || hostname -I | awk '{print $1}')
echo ">> IP público: $IP"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq coturn >/dev/null
# segredo compartilhado (mantém o mesmo se já existir)
if [ -f $DIR/turn.env ] && grep -q LIVECHAT_TURN_SECRET $DIR/turn.env; then
  SECRET=$(grep LIVECHAT_TURN_SECRET $DIR/turn.env | cut -d= -f2)
else
  SECRET=$(openssl rand -hex 32)
fi
cat > /etc/turnserver.conf <<CONF
# coturn do Live Chat
listening-port=3478
external-ip=$IP
min-port=49160
max-port=49200
realm=chat.vill2.com
fingerprint
use-auth-secret
static-auth-secret=$SECRET
no-cli
no-tls
no-dtls
no-multicast-peers
stale-nonce=600
user-quota=12
total-quota=200
# não deixa usar o TURN para chegar em redes internas
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=::1
syslog
CONF
[ -f /etc/default/coturn ] && sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn
systemctl enable coturn >/dev/null 2>&1
systemctl restart coturn
# liga o Live Chat ao TURN
umask 077
cat > $DIR/turn.env <<ENV
LIVECHAT_TURN_SECRET=$SECRET
LIVECHAT_TURN_URLS=turn:$IP:3478?transport=udp,turn:$IP:3478?transport=tcp
ENV
mkdir -p /etc/systemd/system/livechat.service.d
cat > /etc/systemd/system/livechat.service.d/turn.conf <<UNIT
[Service]
EnvironmentFile=-$DIR/turn.env
UNIT
systemctl daemon-reload
systemctl restart livechat
sleep 2
echo ">> coturn: $(systemctl is-active coturn) | livechat: $(systemctl is-active livechat)"
ss -lnup | grep -q ':3478 ' && echo ">> TURN ouvindo na porta 3478 (UDP)" || echo ">> ATENCAO: porta 3478 nao abriu"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  echo ">> FIREWALL (ufw) LIGADO: precisa liberar 3478/udp, 3478/tcp e 49160-49200/udp"
else
  echo ">> firewall ufw desligado (ok)"
fi
echo TURN-OK
