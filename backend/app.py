from flask import Flask, jsonify
from flask_cors import CORS
from datetime import datetime, timedelta
import requests

app = Flask(__name__)
CORS(app)

# San Bernardino coordinates
LATITUDE = 34.1083
LONGITUDE = -117.2898

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
    now = datetime.now() + timedelta(seconds=5)
    weather = get_weather()
    
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
        'events': ['No events scheduled']
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
