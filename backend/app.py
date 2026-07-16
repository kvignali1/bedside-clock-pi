from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
from datetime import datetime, timedelta
import requests
from pathlib import Path
import subprocess
import threading
import os
from zoneinfo import ZoneInfo

BASE_DIR = Path(__file__).resolve().parent
FRONTEND_DIR = BASE_DIR.parent / "frontend"
UPDATE_SCRIPT = BASE_DIR.parent / "update.sh"
UPDATE_LOG = BASE_DIR.parent / "update.log"
update_lock = threading.Lock()
update_state = {
    "running": False,
    "message": "Idle",
    "log_tail": "",
}

app = Flask(__name__, static_folder=str(FRONTEND_DIR), static_url_path="")
CORS(app)

def read_update_log_tail():
    try:
        lines = [
            line.strip()
            for line in UPDATE_LOG.read_text(encoding='utf-8').splitlines()
            if line.strip()
        ]
        return lines[-1] if lines else ''
    except FileNotFoundError:
        return ''

# San Bernardino coordinates
LATITUDE = 34.1083
LONGITUDE = -117.2898
CALENDAR_TIMEZONE = os.getenv('CALENDAR_TIMEZONE', 'America/Los_Angeles')
GOOGLE_CALENDAR_ID = os.getenv('GOOGLE_CALENDAR_ID', 'primary')
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
GOOGLE_REFRESH_TOKEN = os.getenv('GOOGLE_REFRESH_TOKEN')

def format_event_time(start_dt, end_dt, all_day):
    if all_day:
        return 'All day'
    return f"{start_dt.strftime('%-I:%M %p')} - {end_dt.strftime('%-I:%M %p')}"

def get_google_access_token():
    if not all([GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN]):
        return None

    response = requests.post(
        'https://oauth2.googleapis.com/token',
        data={
            'client_id': GOOGLE_CLIENT_ID,
            'client_secret': GOOGLE_CLIENT_SECRET,
            'refresh_token': GOOGLE_REFRESH_TOKEN,
            'grant_type': 'refresh_token',
        },
        timeout=10,
    )
    response.raise_for_status()
    return response.json().get('access_token')

def get_calendar_events(now):
    if not all([GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REFRESH_TOKEN]):
        return ['Set Google Calendar env vars to load events']

    tz = ZoneInfo(CALENDAR_TIMEZONE)
    window_start = now.astimezone(tz).replace(hour=0, minute=0, second=0, microsecond=0)
    window_end = window_start + timedelta(days=1)

    try:
        access_token = get_google_access_token()
        if not access_token:
            return ['Unable to authenticate Google Calendar']

        response = requests.get(
            f'https://www.googleapis.com/calendar/v3/calendars/{GOOGLE_CALENDAR_ID}/events',
            params={
                'singleEvents': 'true',
                'orderBy': 'startTime',
                'timeMin': window_start.isoformat(),
                'timeMax': window_end.isoformat(),
                'maxResults': 6,
            },
            headers={'Authorization': f'Bearer {access_token}'},
            timeout=10,
        )
        response.raise_for_status()
        items = response.json().get('items', [])

        if not items:
            return ['No events scheduled']

        events = []
        for item in items:
            start_value = item.get('start', {}).get('dateTime') or item.get('start', {}).get('date')
            end_value = item.get('end', {}).get('dateTime') or item.get('end', {}).get('date')
            if not start_value or not end_value:
                continue

            all_day = 'date' in item.get('start', {})
            if all_day:
                start_dt = datetime.fromisoformat(start_value).replace(tzinfo=tz)
                end_dt = datetime.fromisoformat(end_value).replace(tzinfo=tz)
            else:
                start_dt = datetime.fromisoformat(start_value).astimezone(tz)
                end_dt = datetime.fromisoformat(end_value).astimezone(tz)

            title = item.get('summary') or 'Untitled event'
            events.append(f"{format_event_time(start_dt, end_dt, all_day)}  {title}")

        return events or ['No events scheduled']
    except Exception as exc:
        print(f'Google Calendar error: {exc}')
        return ['Calendar unavailable']

def get_season(date):
    """Get the official season based on the date"""
    month = date.month
    day = date.day
    
    # Northern Hemisphere seasons
    if (month == 3 and day >= 21) or (month > 3 and month < 6) or (month == 6 and day <= 20):
        return 'Spring'
    elif (month == 6 and day >= 21) or (month > 6 and month < 9) or (month == 9 and day <= 22):
        return 'Summer'
    elif (month == 9 and day >= 23) or (month > 9 and month < 12) or (month == 12 and day <= 20):
        return 'Fall'
    else:  # December 21 - March 20
        return 'Winter'

def get_weather():
    """Fetch weather data from weather.gov"""
    try:
        # Get grid point
        points_url = f"https://api.weather.gov/points/{LATITUDE},{LONGITUDE}"
        points_response = requests.get(points_url)
        
        if points_response.status_code != 200:
            return {'temperature': 75, 'precipitation': 0, 'cloud_cover': 0, 'humidity': 0}
        
        points_data = points_response.json()
        forecast_url = points_data['properties']['forecast']
        forecast_griddata_url = points_data['properties']['forecastGridData']
        
        # Get forecast
        forecast_response = requests.get(forecast_url)
        forecast_data = forecast_response.json()
        
        # Get grid data for humidity
        griddata_response = requests.get(forecast_griddata_url)
        griddata = griddata_response.json()
        
        # Extract current conditions from first period
        current = forecast_data['properties']['periods'][0]
        
        # Parse temperature
        temp = int(current['temperature'])
        
        # Get high and low temps - search through periods for today's high and low
        high_temp = temp
        low_temp = temp
        periods = forecast_data['properties']['periods']
        
        for period in periods[:4]:  # Check first 4 periods (usually covers day/night)
            if 'isDaytime' in period and period['isDaytime']:
                high_temp = int(period['temperature'])
            elif 'isDaytime' in period and not period['isDaytime']:
                low_temp = int(period['temperature'])
        
        # Extract humidity from grid data
        humidity = 0
        if 'properties' in griddata and 'relativeHumidity' in griddata['properties']:
            humidity_data = griddata['properties']['relativeHumidity']['values']
            if humidity_data:
                # Get the first humidity value
                humidity = int(humidity_data[0]['value'])
        
        # Estimate precipitation and cloud cover (weather.gov doesn't provide these directly in forecast)
        precipitation = 0
        cloud_cover = 0
        
        # Simple parsing of forecast text
        forecast_text = current.get('shortForecast', '').lower()
        if 'rain' in forecast_text or 'shower' in forecast_text:
            precipitation = 30
        if 'cloudy' in forecast_text or 'overcast' in forecast_text:
            cloud_cover = 75
        elif 'mostly cloudy' in forecast_text:
            cloud_cover = 50
        elif 'partly cloudy' in forecast_text:
            cloud_cover = 25
        
        return {
            'temperature': temp,
            'high_temp': high_temp,
            'low_temp': low_temp,
            'precipitation': precipitation,
            'cloud_cover': cloud_cover,
            'humidity': humidity
        }
    except Exception as e:
        print(f"Weather API error: {e}")
        return {'temperature': 75, 'high_temp': 85, 'low_temp': 65, 'precipitation': 0, 'cloud_cover': 0, 'humidity': 0}

@app.route('/api/time', methods=['GET'])
def get_time():
    """Returns the current time, date, and weather data"""
    tz = ZoneInfo(CALENDAR_TIMEZONE)
    now = datetime.now(tz) + timedelta(seconds=5)
    weather = get_weather()
    events = get_calendar_events(now)
    
    return jsonify({
        'time': now.strftime('%H:%M:%S'),
        'date': now.strftime('%m/%d/%Y'),
        'temperature': weather['temperature'],
        'high_temp': weather['high_temp'],
        'low_temp': weather['low_temp'],
        'precipitation': weather['precipitation'],
        'cloud_coverage': weather['cloud_cover'],
        'humidity': weather['humidity'],
        'season': get_season(now),
        'events': events
    })

@app.route('/api/update', methods=['POST'])
def run_update():
    if update_lock.locked():
        return jsonify({'ok': False, 'message': 'Update already running.'}), 409

    def _run_update():
        with update_lock:
            update_state['running'] = True
            update_state['message'] = 'Running update...'
            update_state['log_tail'] = ''
            try:
                UPDATE_LOG.write_text('Starting update...\n', encoding='utf-8')
                with UPDATE_LOG.open('a', encoding='utf-8') as log_file:
                    result = subprocess.run(
                        ['/bin/bash', str(UPDATE_SCRIPT)],
                        cwd=str(BASE_DIR.parent),
                        stdout=log_file,
                        stderr=subprocess.STDOUT,
                        text=True,
                        check=False,
                    )
                update_state['log_tail'] = read_update_log_tail()
                if result.returncode == 0:
                    update_state['message'] = 'Update complete. Refreshing...'
                else:
                    details = update_state['log_tail']
                    if details:
                        update_state['message'] = f'Update failed: {result.returncode}. {details}'
                    else:
                        update_state['message'] = f'Update failed: {result.returncode}'
            except Exception as exc:
                update_state['message'] = f'Update error: {exc}'
            finally:
                update_state['running'] = False

    threading.Thread(target=_run_update, daemon=True).start()
    return jsonify({'ok': True, 'message': 'Update started.'})

@app.route('/api/update/status', methods=['GET'])
def update_status():
    if update_state['running']:
        update_state['log_tail'] = read_update_log_tail()
    return jsonify(update_state)

@app.route('/')
def index():
    return send_from_directory(FRONTEND_DIR, 'index.html')

@app.route('/<path:path>')
def serve_frontend(path):
    file_path = FRONTEND_DIR / path
    if file_path.is_file():
        return send_from_directory(FRONTEND_DIR, path)
    return send_from_directory(FRONTEND_DIR, 'index.html')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
