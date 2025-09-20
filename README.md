# Enviro+ Sensors with Prometheus Metrics

This project runs the [Pimoroni Enviro+ HAT](https://shop.pimoroni.com/products/enviro-plus) on a Raspberry Pi.  
It collects temperature, pressure, humidity, light, gas, and particulate matter readings, displays them on the onboard LCD, and exposes them as Prometheus metrics for monitoring in Grafana.

---

## Features

- Reads from:
  - **BME280** (temperature, pressure, humidity)
  - **LTR559** (light, proximity)
  - **Gas sensor** (oxidising, reducing, NH₃)
  - **PMS5003** (PM1, PM2.5, PM10 particulates)
- Displays values on the ST7735 LCD
- Exposes a Prometheus `/metrics` endpoint
- Ships with a `systemd` service definition
- Includes a Grafana dashboard

---

## Requirements

- Raspberry Pi with **SPI**, **I²C**, and **UART** enabled  
- [Enviro+ HAT](https://shop.pimoroni.com/products/enviro-plus)  
- Optional PMS5003 sensor on UART  
- Raspberry Pi OS (Bullseye/Bookworm recommended)  

---

## Installation

Clone this repository:

```bash
git clone https://github.com/yourusername/enviroplus-prometheus.git
cd enviroplus-prometheus
````

Run the setup script:

```bash
sudo bash setup_enviroplus.sh
```

Reboot to apply SPI/I²C/UART changes:

```bash
sudo reboot
```

---

## Usage

Start the service manually:

```bash
sudo systemctl start enviroplus.service
```

Enable autostart:

```bash
sudo systemctl enable enviroplus.service
```

Check logs:

```bash
journalctl -u enviroplus.service -f
```

---

## Prometheus Metrics

Metrics are served at:

```
http://<raspberry-pi-ip>:8000/metrics
```

Environment variables:

```bash
METRICS_ADDR=127.0.0.1
METRICS_PORT=9100
```

Exported metrics:

* `enviro_temperature` (C)
* `enviro_pressure` (hPa)
* `enviro_humidity` (%)
* `enviro_light` (Lux)
* `enviro_oxidised` (kΩ)
* `enviro_reduced` (kΩ)
* `enviro_nh3` (kΩ)
* `enviro_pm1` (µg/m³)
* `enviro_pm25` (µg/m³)
* `enviro_pm10` (µg/m³)
* `enviro_cpu_temperature_c` (°C)
* `enviro_proximity_raw` (raw units)

---

## Grafana Dashboard

Import `grafana-dashboard.json` into Grafana:

1. Go to **Dashboards → Import**
2. Upload the JSON file
3. Choose your Prometheus datasource
4. Save and view the dashboard

Panels include current stats and time-series graphs for all metrics.

---

## Troubleshooting

**No data on `/metrics`**

```bash
journalctl -u enviroplus.service -f
```

**PMS5003 not working**
Make sure serial login shell is disabled in `raspi-config`.

**Fonts missing**
Ensure the `fonts/` folder with `RobotoMedium` is in `/opt/enviroplus/`.

---

## License

MIT License. See [LICENSE](LICENSE).
