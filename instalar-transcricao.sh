#!/bin/bash
# Instala a transcrição de áudio do Live Chat (whisper.cpp + ffmpeg) na VPS.
# Tudo roda aqui mesmo: o áudio não vai para nenhum serviço de fora.
set -e
export DEBIAN_FRONTEND=noninteractive
echo ">> CPUs: $(nproc) | memória livre: $(free -m | awk '/Mem:/{print $7}') MB | disco livre: $(df -h / | awk 'NR==2{print $4}')"
apt-get update -qq
apt-get install -y -qq ffmpeg git cmake build-essential >/dev/null
D=/opt/whisper
if [ ! -d $D/.git ]; then git clone -q --depth 1 https://github.com/ggml-org/whisper.cpp $D; fi
cd $D
echo ">> compilando (pode levar alguns minutos)…"
cmake -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF >/dev/null
cmake --build build -j"$(nproc)" --config Release --target whisper-cli >/dev/null
BIN=$D/build/bin/whisper-cli
test -x $BIN
M=$D/models/ggml-base-q5_1.bin
[ -s $M ] || sh ./models/download-ggml-model.sh base-q5_1 >/dev/null 2>&1
test -s $M
T=$(( $(nproc) > 2 ? 2 : $(nproc) ))
cat > /opt/livechat/whisper.env <<ENV
LIVECHAT_WHISPER_BIN=$BIN
LIVECHAT_WHISPER_MODEL=$M
LIVECHAT_WHISPER_THREADS=$T
ENV
mkdir -p /etc/systemd/system/livechat.service.d
cat > /etc/systemd/system/livechat.service.d/whisper.conf <<UNIT
[Service]
EnvironmentFile=-/opt/livechat/whisper.env
UNIT
systemctl daemon-reload
systemctl restart livechat
sleep 2
echo ">> teste:"
S=$(date +%s); $BIN -m $M -f samples/jfk.wav -nt -np -t $T 2>/dev/null | head -2; echo ">> levou $(( $(date +%s) - S ))s para 11s de áudio"
echo ">> livechat: $(systemctl is-active livechat)"
echo TRANSCRICAO-OK
