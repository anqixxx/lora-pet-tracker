function fetchData() {
    const mode = document.getElementById('mode').value;
    const params = new URLSearchParams({ mode });
    
    window.history.replaceState({}, '', `?${params}`);
    
    fetch(`/api/data?${params}`)
        .then(response => response.json())
        .then(data => {
            updateCommandTable(data.app_data);
            updateNodeTable(data.node_data);
            
            updateCurrentUserDisplay(mode);
        })
        .catch(error => {
            console.error('Error fetching data:', error);
        });
}

function updateCommandTable(appData) {
    const tbody = document.querySelector('#command-table tbody');
    if (!appData || !tbody) return;
    
    tbody.innerHTML = appData.map(item => `
        <tr>
            <td>${formatDateTime(item.timestamp)}</td>
            <td>${item.status}</td>
            <td title="${item.msg}">${item.msg}</td>
        </tr>
    `).join('');
}

function updateNodeTable(nodeData) {
    const tbody = document.querySelector('#status-table tbody');
    if (!nodeData || !tbody) return;
    
    tbody.innerHTML = nodeData.map(item => `
        <tr>
            <td>${formatDateTime(item.timestamp)}</td>
            <td>${item.battery_level}</td>
            <td title="${item.gps_latitude}, ${item.gps_longitude}">${item.gps_latitude}, ${item.gps_longitude}</td>
            <td title="${item.msg}">${item.msg || ''}</td>
        </tr>
    `).join('');
}

function updateCurrentUserDisplay(mode) {
    const display = document.getElementById('current-user-display');
    modes = ['none', 'test', 'exp']
    if (mode.lower() in modes) {
        display.innerHTML = `Currently viewing data for mode: <span style="color: #2ecc71;">${mode}</span>`;
    } 
    else if (mode){
        display.innerHTML = 'Invalid mode selected - showing all data';
        mode = null;
    }
    else {
        display.innerHTML = 'No mode selected - showing all data';
    }
}

function formatDateTime(timestamp) {
    const date = new Date(timestamp);
    const options = { 
        year: 'numeric', month: 'short', day: 'numeric',
        hour: 'numeric', minute: '2-digit', second: '2-digit', hour12: true 
    };
    return date.toLocaleString('en-US', options);
}

setInterval(fetchData, 500);

fetchData();
