const API_URL = '/api';
const DEGREE_SYMBOL = '\u00B0';

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

function determineScene(data, hours) {
    if (data.precipitation >= 20) {
        return 'rain';
    }
    if (isDaytime(hours)) {
        return 'day';
    }
    return 'night';
}

function seedAtmosphere() {
    const starsLayer = document.getElementById('stars-layer');
    const rainLayer = document.getElementById('rain-layer');

    if (starsLayer && !starsLayer.children.length) {
        for (let i = 0; i < 70; i += 1) {
            const star = document.createElement('span');
            star.className = 'star';
            star.style.left = `${Math.random() * 100}%`;
            star.style.top = `${Math.random() * 62}%`;
            star.style.width = `${0.12 + Math.random() * 0.26}rem`;
            star.style.height = star.style.width;
            star.style.animationDelay = `${Math.random() * 6}s`;
            star.style.animationDuration = `${2.6 + Math.random() * 3.4}s`;
            star.style.opacity = `${0.3 + Math.random() * 0.7}`;
            starsLayer.appendChild(star);
        }
    }

    if (rainLayer && !rainLayer.children.length) {
        for (let i = 0; i < 90; i += 1) {
            const drop = document.createElement('span');
            drop.className = 'rain-drop';
            drop.style.left = `${Math.random() * 100}%`;
            drop.style.animationDelay = `${Math.random() * 2.8}s`;
            drop.style.animationDuration = `${0.7 + Math.random() * 0.8}s`;
            drop.style.opacity = `${0.15 + Math.random() * 0.5}`;
            drop.style.height = `${1.6 + Math.random() * 2.8}rem`;
            rainLayer.appendChild(drop);
        }
    }
}

function applyScene(data, hours) {
    const clock = document.getElementById('clock');
    const nextScene = determineScene(data, hours);

    clock.classList.remove('scene-day', 'scene-night', 'scene-rain', 'cloudy');
    clock.classList.add(`scene-${nextScene}`);

    if (data.cloud_coverage >= 35) {
        clock.classList.add('cloudy');
    }
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
            document.getElementById('precipitation').textContent = `${data.precipitation}%`;
            document.getElementById('cloud-coverage').textContent = `${data.cloud_coverage}%`;
            document.getElementById('humidity').textContent = `${data.humidity}%`;
            document.getElementById('season').textContent = data.season;
            document.getElementById('date').textContent = data.date;
            applyScene(data, hours);

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
seedAtmosphere();
updateDisplay();
setInterval(updateDisplay, 1000);

document.getElementById('update-button').addEventListener('click', updateSoftware);
