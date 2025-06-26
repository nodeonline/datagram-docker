#!/bin/bash

set -e

echo "🚀 Memulai setup datagram multi-akun interaktif..."

# ===================== 1. Cek & install Docker =====================
if ! command -v docker &> /dev/null; then
  echo "🔧 Docker tidak ditemukan. Menginstall dependensi..."
  sudo apt update && sudo apt install -y ca-certificates curl gnupg lsb-release

  echo "🔧 Menginstall Docker..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER
  echo "✅ Docker berhasil diinstal. Silakan logout & login ulang untuk akses tanpa sudo."
else
  echo "✅ Docker sudah terinstal."
fi

# ===================== 2. Siapkan Dockerfile =====================
mkdir -p ~/datagram-multi && cd ~/datagram-multi || exit 1

cat << 'EOF' > Dockerfile
FROM alpine:latest

RUN apk add --no-cache wget ca-certificates

WORKDIR /app

ARG DATAGRAM_CLI_URL="https://github.com/Datagram-Group/datagram-cli-release/releases/latest/download/datagram-cli-x86_64-linux"
RUN wget -O datagram-cli "$DATAGRAM_CLI_URL" && chmod +x datagram-cli

RUN mkdir -p /app/data
ENV DATAGRAM_DATA_DIR=/app/data

VOLUME ["/app/data"]

ENTRYPOINT ["./datagram-cli"]
CMD ["run"]
EOF

# ===================== 3. Input API Key secara interaktif =====================
read -p "🔢 Berapa jumlah akun/API key yang ingin kamu jalankan? " TOTAL

echo "📥 Silakan masukkan $TOTAL API key:"
API_KEYS=()
for ((i=1; i<=TOTAL; i++)); do
  read -p "  API key #$i: " KEY
  API_KEYS+=("$KEY")
done

# ===================== 4. Buat skrip run-multi.sh secara otomatis =====================
cat <<EOF > run-multi.sh
#!/bin/bash
IMAGE_NAME="datagram"
EOF

echo "API_KEYS=(" >> run-multi.sh
for KEY in "${API_KEYS[@]}"; do
  echo "  \"$KEY\"" >> run-multi.sh
done
echo ")" >> run-multi.sh

cat << 'EOF' >> run-multi.sh

for i in "${!API_KEYS[@]}"; do
  index=$((i+1))
  container="dgram${index}"
  volume="datagram${index}_data"
  key="${API_KEYS[$i]}"

  echo "[+] Menjalankan $container dengan API key: $key"
  docker run -d --name "$container" -v "$volume":/app/data "$IMAGE_NAME" run -- -key "$key"
done
EOF

chmod +x run-multi.sh

# ===================== 5. Build image =====================
echo "[*] Membangun Docker image 'datagram'..."
docker build -t datagram .

# ===================== 6. Jalankan multiakun =====================
echo
echo "🚀 Menjalankan semua akun..."
./run-multi.sh

echo
echo "✅ Semua container sudah dijalankan!"
