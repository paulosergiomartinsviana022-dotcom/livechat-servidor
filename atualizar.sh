#!/bin/bash
# Atualizacao automatica do Live Chat (roda a cada 2 minutos pelo systemd).
# Confere no GitHub se tem versao nova; se tiver, baixa, confere o sha256,
# troca o programa e reinicia o servico. Nao mexe em mais nada da VPS.
set -e
REPO=paulosergiomartinsviana022-dotcom/livechat-servidor
API="https://api.github.com/repos/$REPO/commits/main"
DIR=/opt/livechat
SHA=$(curl -fsS -H "Accept: application/vnd.github.sha" "$API") || exit 0
[ -n "$SHA" ] || exit 0
[ "$SHA" = "$(cat $DIR/.commit 2>/dev/null)" ] && exit 0
RAW="https://raw.githubusercontent.com/$REPO/$SHA"
WANT=$(curl -fsS "$RAW/livechat-servidor-linux.sha256" | tr -d ' \n') || exit 0
HAVE=$(sha256sum $DIR/livechat-servidor-linux | cut -d' ' -f1)
if [ "$WANT" != "$HAVE" ]; then
  curl -fsSL "$RAW/livechat-servidor-linux" -o $DIR/livechat-servidor-linux.novo
  GOT=$(sha256sum $DIR/livechat-servidor-linux.novo | cut -d' ' -f1)
  if [ "$GOT" != "$WANT" ]; then echo "download corrompido, ignorando"; rm -f $DIR/livechat-servidor-linux.novo; exit 1; fi
  chmod +x $DIR/livechat-servidor-linux.novo
  cp $DIR/livechat-servidor-linux $DIR/livechat-servidor-linux.anterior
  mv $DIR/livechat-servidor-linux.novo $DIR/livechat-servidor-linux
  systemctl restart livechat
  sleep 3
  if ! curl -fs http://localhost:8440/api/config >/dev/null; then
    echo "versao nova nao subiu, voltando a anterior"
    mv $DIR/livechat-servidor-linux.anterior $DIR/livechat-servidor-linux
    systemctl restart livechat
    exit 1
  fi
  echo "atualizado para $SHA ($WANT)"
fi
echo "$SHA" > $DIR/.commit
