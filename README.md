# Bedside Clock Pi

This project is designed to run on a Raspberry Pi as a small always-on bedside clock dashboard.

The backend starts automatically as a systemd service and also serves the frontend. Once it is running, the display can open `http://localhost:5000/` and the page will keep itself updated from the backend API.

## What it does

- Runs a Flask backend on port `5000`
- Serves time, date, weather, and season data at `/api/time`
- Lets the frontend poll that endpoint once per second

## Files

- `backend/app.py` - Flask API
- `frontend/` - static HTML, CSS, and JavaScript for the display
- `bedside.service` - systemd service file
- `setup.sh` - installs Python dependencies and enables the service

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

## Service behavior

After setup, the backend will start automatically on boot.

The frontend is served by the same Flask app, so there is only one service to manage.

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
