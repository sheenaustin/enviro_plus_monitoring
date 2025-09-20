#!/usr/bin/env bash
set -euo pipefail

# -------- Settings you can tweak --------
APP_NAME="enviroplus"
APP_DIR="/opt/${APP_NAME}"
APP_USER="user"                     
PYTHON="/usr/bin/python3"
VENV_DIR="${APP_DIR}/.venv"
SERVICE_NAME="${APP_NAME}.service"
SCRIPT_NAME="enviro_plus_exporter.py"         # Your sensor script filename
METRICS_ADDR="${METRICS_ADDR:-0.0.0.0}"
METRICS_PORT="${METRICS_PORT:-8000}"
# ---------------------------------------

echo "[1/8] Installing OS packages…"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 python3-venv python3-pip python3-dev \
  python3-smbus i2c-tools git curl \
  libatlas-base-dev libopenjp2-7 libtiff5 \
  libjpeg-dev zlib1g-dev libfreetype6 \
  fonts-dejavu-core

echo "[2/8] Enabling SPI, I2C, UART…"
# Try raspi-config first (preferred), fall back to editing config if unavailable
if command -v raspi-config >/dev/null 2>&1; then
  # Enable SPI and I2C
  raspi-config nonint do_spi 0 || true
  raspi-config nonint do_i2c 0 || true
  # Disable serial login shell, enable serial hardware (UART) – '2' does both on modern raspi-config
  raspi-config nonint do_serial 2 || true
else
  BOOTCFG="/boot/config.txt"
  echo "raspi-config not found; editing ${BOOTCFG} directly…"
  grep -q '^dtparam=spi=on'   "${BOOTCFG}" || echo 'dtparam=spi=on'   >> "${BOOTCFG}"
  grep -q '^dtparam=i2c_arm=on' "${BOOTCFG}" || echo 'dtparam=i2c_arm=on' >> "${BOOTCFG}"
  grep -q '^enable_uart=1'    "${BOOTCFG}" || echo 'enable_uart=1'    >> "${BOOTCFG}"
fi

echo "[3/8] Disabling serial console on common UARTs (free the PMS5003 port)…"
# These may or may not exist; ignore failures.
systemctl stop serial-getty@ttyAMA0.service 2>/dev/null || true
systemctl disable serial-getty@ttyAMA0.service 2>/dev/null || true
systemctl stop serial-getty@ttyS0.service 2>/dev/null || true
systemctl disable serial-getty@ttyS0.service 2>/dev/null || true

# Ensure cmdline.txt doesn't force a console on serial
CMDLINE="/boot/cmdline.txt"
if [ -f "$CMDLINE" ] && grep -q "console=serial0,115200" "$CMDLINE"; then
  echo "Stripping serial console from ${CMDLINE}…"
  sed -i -E 's/ ?console=serial0,[0-9]+//g' "$CMDLINE"
fi

echo "[4/8] Creating app directory & virtualenv…"
mkdir -p "${APP_DIR}"
if [ ! -d "${VENV_DIR}" ]; then
  "${PYTHON}" -m venv "${VENV_DIR}"
fi
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

echo "[5/8] Installing Python packages…"
# Pimoroni Enviro+ stack and friends, plus prometheus client
pip install --upgrade pip
pip install \
  pillow \
  prometheus-client \
  RPi.GPIO spidev smbus2 \
  st7735 \
  ltr559 \
  bme280 \
  pms5003 \
  enviroplus

echo "[6/8] Deploying application files…"
# Copy your script from the current directory if present
if [ -f "./${SCRIPT_NAME}" ]; then
  install -m 0644 "./${SCRIPT_NAME}" "${APP_DIR}/${SCRIPT_NAME}"
else
  echo "WARNING: ${SCRIPT_NAME} not found in current directory."
  echo "Place your script at ${APP_DIR}/${SCRIPT_NAME} before starting the service."
fi

# Optional: copy local 'fonts' folder if you have custom fonts alongside the script
if [ -d "./fonts" ]; then
  rsync -a ./fonts "${APP_DIR}/"
fi

# Make sure ownership allows the service user to read/execute
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"
chmod -R u+rwX,go+rX "${APP_DIR}"

echo "[7/8] Adding ${APP_USER} to hardware access groups…"
for grp in gpio i2c spi dialout; do
  adduser "${APP_USER}" "$grp" || true
done

echo "[8/8] Creating systemd service…"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=Enviro+ sensors with Prometheus metrics
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
Environment=METRICS_ADDR=${METRICS_ADDR}
Environment=METRICS_PORT=${METRICS_PORT}
ExecStart=${VENV_DIR}/bin/python ${APP_DIR}/${SCRIPT_NAME}
Restart=on-failure
RestartSec=5
# Give access to UART/SPI/I2C even if udev rules are restrictive
SupplementaryGroups=gpio i2c spi dialout

# If using the SPI TFT with backlight GPIO, we might need more open files
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"

echo
echo "Setup complete."
echo
echo "==> Reboot is recommended to finalize SPI/I2C/UART changes."
echo "    You can reboot now with: sudo reboot"
echo
echo "After reboot, start the service (if not already running):"
echo "  sudo systemctl start ${SERVICE_NAME}"
echo
echo "Check status & logs:"
echo "  systemctl status ${SERVICE_NAME}"
echo "  journalctl -u ${SERVICE_NAME} -f"
echo
echo "Metrics should be at: http://${METRICS_ADDR}:${METRICS_PORT}/metrics (from the Pi)."
