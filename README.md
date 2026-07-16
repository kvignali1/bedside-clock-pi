# Bedside Clock Pi

This project is designed to run on a Raspberry Pi as a small always-on bedside clock dashboard.

The backend starts automatically as a systemd service and also serves the frontend. The setup script can also install a Chromium kiosk autostart so the Pi opens the clock full-screen on login.

## What it does

- Runs a Flask backend on port `5000`
- Serves time, date, weather, and season data at `/api/time`
- Lets the frontend poll that endpoint once per second

## Files

- `backend/app.py` - Flask API
- `frontend/` - static HTML, CSS, and JavaScript for the display
- `bedside.service` - systemd service file
- `setup.sh` - installs Python dependencies and enables the service
- Chromium kiosk autostart is created during setup if Chromium is installed

## Raspberry Pi setup

1. On the Pi, clone the repo into your home directory:

```bash
cd /home/kvignali1
git clone https://github.com/kvignali1/bedside-clock-pi.git Bedside_clock_pi
```

2. From the repo root, run the setup script:

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:

- Create a Python virtual environment in `.venv`
- Install packages from `requirements.txt`
- Copy `bedside.service` into `/etc/systemd/system`
- Reload systemd
- Enable the service at boot
- Restart the service immediately
- Create a kiosk autostart entry for Chromium if it is available

## Service behavior

After setup, the backend will start automatically on boot.

The frontend is served by the same Flask app, so there is only one service to manage.

If Chromium is installed and the Pi is set to auto-login into the desktop, the clock will open in kiosk mode after login.

The clock UI also includes a lower-left update button that runs `update.sh` for you and reboots the Pi after updating. The setup script installs the narrow sudo permissions needed for that flow.

## Manual service commands

```bash
sudo systemctl status bedside.service
sudo systemctl restart bedside.service
sudo systemctl stop bedside.service
sudo systemctl enable bedside.service
```

## Notes

- The backend uses `weather.gov` for weather data.
- The install script works from the repo root, so it does not depend on a hard-coded folder name.
- If `python3 -m venv` fails, install `python3-venv` on the Pi and rerun the setup script.
- If kiosk mode does not launch, make sure Chromium is installed and desktop auto-login is enabled on the Pi.
- If the update button fails, you can still run `./update.sh` from SSH on the Pi.
- If the update button says idle, make sure you have pulled the latest repo version and rerun `./setup.sh` so the sudo permissions are installed.
