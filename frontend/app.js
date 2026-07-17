const API_URL = '/api';
const DEGREE_SYMBOL = '\u00B0';
const PRECIPITATION_ICON = '\u{1F4A7}';
const CLOUD_ICON = '\u2601\uFE0F';
const HUMIDITY_ICON = '\u{1F4A8}';

/* 7-segment display mapping: which segments to light for each digit */
const SEGMENT_MAP = {
    0: ['top', 'top-right', 'bottom-right', 'bottom', 'bottom-left', 'top-left'],
    1: ['top-right', 'bottom-right'],
    2: ['top', 'top-right', 'middle', 'bottom-left', 'bottom'],
    3: ['top', 'top-right', 'middle', 'bottom-right', 'bottom'],
    4: ['top-left', 'middle', 'top-right', 'bottom-right'],
    5: ['top', 'top-left', 'middle', 'bottom-right', 'bottom'],
    6: ['top', 'top-left', 'middle', 'bottom-left', 'bottom', 'bottom-right'],
    7: ['top', 'top-right', 'bottom-right'],
    8: ['top', 'top-right', 'bottom-right', 'bottom', 'bottom-left', 'top-left', 'middle'],
    9: ['top', 'top-right', 'bottom-right', 'bottom', 'top-left', 'middle']
};

function renderSegmentDigit(digitId, value) {
    const digit = document.getElementById(digitId);
    digit.innerHTML = '';

    const segments = SEGMENT_MAP[parseInt(value, 10)] || SEGMENT_MAP[0];

    ['top', 'top-left', 'top-right', 'middle', 'bottom-left', 'bottom-right', 'bottom'].forEach(segName => {
        const seg = document.createElement('div');
        seg.className = `segment ${segName}`;
        if (segments.includes(segName)) {
            seg.classList.add('active');
        }
        digit.appendChild(seg);
    });
}

function isDaytime(hour) {
    /* Day is from 6 AM (6) to 6 PM (18) */
    return hour >= 6 && hour < 18;
}

function updateDisplay() {
    fetch(`${API_URL}/time`)
        .then(response => response.json())
        .then(data => {
            const timeStr = data.time;
            const [hours, minutes, seconds] = timeStr.split(':').map(Number);

            /* Render 7-segment display */
            const h = String(hours).padStart(2, '0');
            const m = String(minutes).padStart(2, '0');
            const s = String(seconds).padStart(2, '0');

            renderSegmentDigit('digit-1', h[0]);
            renderSegmentDigit('digit-2', h[1]);
            renderSegmentDigit('digit-3', m[0]);
            renderSegmentDigit('digit-4', m[1]);
            renderSegmentDigit('digit-5', s[0]);
            renderSegmentDigit('digit-6', s[1]);

            document.getElementById('tempurature').textContent = `${data.temperature}${DEGREE_SYMBOL}F`;
            document.getElementById('precipitation').textContent = `${PRECIPITATION_ICON} ${data.precipitation}%`;
            document.getElementById('cloud-coverage').textContent = `${CLOUD_ICON} ${data.cloud_coverage}%`;
            document.getElementById('humidity').textContent = `${HUMIDITY_ICON} ${data.humidity}%`;
            document.getElementById('season').textContent = data.season;
            document.getElementById('date').textContent = data.date;

            /* Update day/night display */
            const sky = document.getElementById('sky');
            const body = document.getElementById('celestial-body');

            if (isDaytime(hours)) {
                sky.className = 'daytime';
                body.classList.remove('moon');
            } else {
                sky.className = 'nighttime';
                body.classList.add('moon');
            }

            const eventDiv = document.getElementById('event');
            if (data.events && data.events.length > 0) {
                eventDiv.textContent = data.events.join('\n\n');
            } else {
                eventDiv.textContent = 'No events scheduled';
            }
        })
        .catch(error => console.error('Error fetching data:', error));
}

function updateSoftware() {
    const button = document.getElementById('update-button');
    const status = document.getElementById('update-status');
    const banner = document.getElementById('update-banner');

    button.disabled = true;
    status.textContent = 'Updating...';
    banner.hidden = false;
    banner.textContent = 'Updating now. The Pi will reboot when it finishes.';

    fetch('/api/update', { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            status.textContent = data.message || 'Update started.';
            banner.textContent = data.message || 'Update started.';
            const poll = setInterval(() => {
                fetch('/api/update/status')
                    .then(response => response.json())
                    .then(state => {
                        status.textContent = state.message || 'Idle';
                        if (state.log_tail) {
                            const details = `${state.message || 'Idle'} ${state.log_tail}`;
                            status.textContent = details;
                            banner.textContent = details;
                        } else {
                            banner.textContent = state.message || 'Idle';
                        }
                        if (!state.running) {
                            button.disabled = false;
                            clearInterval(poll);
                            if ((state.message || '').toLowerCase().includes('complete')) {
                                banner.textContent = 'Update complete. Rebooting the Pi now.';
                            }
                        }
                    })
                    .catch(() => {
                        status.textContent = 'Update status unavailable.';
                        banner.textContent = 'Update status unavailable.';
                        button.disabled = false;
                        clearInterval(poll);
                    });
            }, 2000);
        })
        .catch(() => {
            status.textContent = 'Update failed to start.';
            banner.textContent = 'Update failed to start.';
            button.disabled = false;
        });
}

/* Update display immediately and then every second */
updateDisplay();
setInterval(updateDisplay, 1000);

document.getElementById('update-button').addEventListener('click', updateSoftware);
