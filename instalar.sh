#!/bin/bash
# Instala/atualiza o Live Chat na VPS (porta 8430). Nao mexe em outros servicos.
set -e
URL=https://raw.githubusercontent.com/paulosergiomartinsviana022-dotcom/livechat-servidor/main
echo ">> Baixando o servidor..."
mkdir -p /opt/livechat/dados
curl -fsSL "$URL/livechat-servidor-linux" -o /opt/livechat/livechat-servidor-linux.novo
chmod +x /opt/livechat/livechat-servidor-linux.novo
systemctl stop livechat 2>/dev/null || true
mv /opt/livechat/livechat-servidor-linux.novo /opt/livechat/livechat-servidor-linux
if [ ! -f /etc/systemd/system/livechat.service ]; then
  curl -fsSL "$URL/livechat.service" -o /etc/systemd/system/livechat.service
fi
systemctl daemon-reload
systemctl enable livechat >/dev/null 2>&1
systemctl restart livechat
sleep 2
if curl -fs http://localhost:8430/api/config >/dev/null; then
  echo ">> LIVECHAT_OK - rodando na porta 8430"
else
  echo ">> ERRO: o servidor nao respondeu"; journalctl -u livechat -n 20 --no-pager; exit 1
fi
