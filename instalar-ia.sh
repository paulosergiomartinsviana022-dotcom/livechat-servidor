#!/bin/bash
# Live Chat — instala a IA pequena no próprio servidor (Ollama + modelo qwen2.5:1.5b, ~1 GB).
# Fica só para o próprio servidor (127.0.0.1:11434), não abre porta na internet.
set -e
echo ">> memória livre: $(free -m | awk '/Mem:/{print $7}') MB | disco livre: $(df -h / | awk 'NR==2{print $4}')"
if ! command -v ollama >/dev/null; then
  echo ">> instalando o Ollama (instalador oficial)…"
  curl -fsSL https://ollama.com/install.sh | sh
fi
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/livechat.conf <<'CONF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_KEEP_ALIVE=15m"
CONF
systemctl daemon-reload
systemctl enable --now ollama
systemctl restart ollama
sleep 3
echo ">> baixando o modelo (pode levar alguns minutos)…"
ollama pull qwen2.5:1.5b
echo ">> teste:"
t0=$(date +%s)
curl -s http://127.0.0.1:11434/api/chat -d '{"model":"qwen2.5:1.5b","stream":false,"messages":[{"role":"user","content":"Responda em uma frase em português: como salvar um arquivo no Photoshop?"}]}' | head -c 400; echo
echo ">> levou $(( $(date +%s) - t0 ))s"
echo IA-OK
