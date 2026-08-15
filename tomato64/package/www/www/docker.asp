<!DOCTYPE html>
<!--
	FreshTomato Docker Dashboard
-->
<html lang="en-GB">
<head>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
<meta name="robots" content="noindex,nofollow">
<title>[<% ident(); %>] Docker Dashboard</title>
<link rel="stylesheet" type="text/css" href="tomato.css">
<% css(); %>

<style>
    /* Tab System */
    .dk-tabs { display: flex; border-bottom: 2px solid #ccc; margin-bottom: 15px; user-select: none; flex-wrap: wrap; }
    .dk-tab { padding: 8px 16px; cursor: pointer; border: 1px solid transparent; border-bottom: none; margin-bottom: -2px; font-size: 13px; color: #555; }
    .dk-tab:hover { color: #000; }
    .dk-tab.active { background: #fff; border-color: #ccc; border-top: 2px solid #2a70a0; font-weight: bold; color: #000; border-radius: 4px 4px 0 0; }
    .dk-tab-content { display: none; }
    .dk-tab-content.active { display: block; }

    /* Controls & Tables */
    .dk-toolbar { display: flex; gap: 10px; margin-bottom: 10px; align-items: center; flex-wrap: wrap; }
    .dk-btn { padding: 5px 12px; cursor: pointer; background: #e0e0e0; border: 1px solid #ccc; border-radius: 3px; font-size: 12px; font-weight: bold; }
    .dk-btn:hover:not(:disabled) { background: #d0d0d0; }
    .dk-btn-action { background: #ccffcc; border-color: #99ee99; }
    .dk-btn-action:hover:not(:disabled) { background: #bbffbb; }
    .dk-btn-danger { background: #ffcccc; border-color: #ff9999; }
    .dk-btn-danger:hover:not(:disabled) { background: #ffbbbb; }
    
    .dk-table { width: 100%; border-collapse: collapse; background: #fff; font-size: 13px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .dk-table th, .dk-table td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }
    .dk-table th { background: #f9f9f9; font-weight: bold; }
    .dk-table tr:hover { background: #f5f5f5; }
    
    .status-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 5px; }
    .status-running { background-color: #28a745; box-shadow: 0 0 5px #28a745; }
    .status-exited { background-color: #dc3545; }
    .status-created { background-color: #ffc107; }
    
    /* Forms & Compose */
    .dk-form-grid { display: grid; grid-template-columns: 1fr 2fr; gap: 10px 15px; align-items: center; max-width: 700px; margin-bottom: 15px; }
    .dk-form-grid label { font-weight: bold; font-size: 13px; text-align: right; }
    .dk-input { padding: 6px; font-family: monospace; border: 1px solid #ccc; border-radius: 3px; width: 100%; box-sizing: border-box; }
    .dk-select { padding: 6px; border: 1px solid #ccc; border-radius: 3px; background: #fff; width: 100%; box-sizing: border-box; }
    
    .dk-compose-box { background: #f9f9f9; padding: 15px; border: 1px solid #ddd; border-radius: 4px; }
    .dk-terminal-out { width: 100%; height: 250px; background: #1e1e1e; color: #00ff00; font-family: monospace; font-size: 12px; padding: 10px; box-sizing: border-box; overflow-y: auto; white-space: pre-wrap; border-radius: 3px; margin-top: 10px; }
    
    .dk-modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); z-index: 10000; align-items: center; justify-content: center; }
    .dk-modal-content { background: #fff; padding: 20px; border-radius: 5px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); width: 90%; max-width: 900px; }
    
    @media(max-width: 600px) {
        .dk-form-grid { grid-template-columns: 1fr; gap: 5px; }
        .dk-form-grid label { text-align: left; }
    }
</style>

<!-- Standard FreshTomato JS inclusion -->
<script>
//	<% nvram("http_id"); %>
</script>
<script src="tomato.js"></script>

<script>
var DockerDash = {
    xob: null,
    currentTab: 'containers',
    
    cmd: function(command, callback) {
        if (this.xob) {
            this.xob = null;
        }
        this.xob = new XmlHttp();
        
        var timer = setTimeout(function() {
            if (DockerDash.xob) {
                DockerDash.xob = null;
                if (callback) callback('ERROR: Request timed out. Check if Docker is responding.');
            }
        }, 8000);

        this.xob.onCompleted = function(text) {
            clearTimeout(timer);
            window.cmdresult = '';
            var res = '';
            try { 
                eval(text); 
                res = window.cmdresult || ''; 
            } catch(e) {
                res = 'ERROR: Failed to parse router output.'; 
            }
            if (callback) callback(res);
            DockerDash.xob = null;
        };

        this.xob.onError = function(err) {
            clearTimeout(timer);
            if (callback) callback('ERROR: HTTP POST failed.');
            DockerDash.xob = null;
        };

        try {
            var encoded = (typeof escapeCGI === 'function' ? escapeCGI(command) : encodeURIComponent(command));
            var validToken = window.http_id || '<% http_id(); %>';
            var params = 'action=execute&command=' + encoded + '&_http_id=' + validToken;
            
            this.xob.post('shell.cgi', params);
        } catch (e) { 
            clearTimeout(timer);
            if (callback) callback('ERROR: ' + e.message); 
        }
    },

    // --- UI Navigation ---
    switchTab: function(tabId) {
        document.querySelectorAll('.dk-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.dk-tab-content').forEach(c => c.classList.remove('active'));
        
        document.getElementById('tab-btn-' + tabId).classList.add('active');
        document.getElementById('tab-' + tabId).classList.add('active');
        this.currentTab = tabId;
        
        if (tabId === 'containers') this.loadContainers();
        if (tabId === 'images') this.loadImages();
        if (tabId === 'volumes') this.loadVolumes();
        if (tabId === 'networks') this.loadNetworks();
    },

    // --- Containers Logic ---
    loadContainers: function() {
        var tbody = document.getElementById('dk-containers-tbody');
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">Loading containers...</td></tr>';
        
        var format = "{{.ID}}~{{.Names}}~{{.Image}}~{{.State}}~{{.Status}}~{{.Ports}}";
        this.cmd('docker ps -a --format "' + format + '" 2>&1', function(res) {
            if (res.indexOf('ERROR:') === 0 || res.indexOf('Cannot connect') > -1 || res.indexOf('not found') > -1) {
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:red;">' + res + '</td></tr>';
                return;
            }
            var lines = res.trim().split('\n');
            tbody.innerHTML = '';
            if (!res.trim() || lines.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No containers found.</td></tr>'; return;
            }
            lines.forEach(line => {
                if (!line.trim()) return;
                var p = line.split('~');
                if (p.length < 5) return;
                var state = (p[3] || '').toLowerCase(), isRunning = (state === 'running');
                var dotClass = isRunning ? 'status-running' : (state === 'created' ? 'status-created' : 'status-exited');
                
                tbody.innerHTML += `<tr>
                    <td><b>${p[1]}</b><br><span style="font-size:11px;color:#888;">${p[0]}</span></td>
                    <td>${p[2]}</td>
                    <td><span class="status-dot ${dotClass}"></span> ${p[4]}</td>
                    <td style="font-size:11px;">${p[5] || 'None'}</td>
                    <td>
                        <button class="dk-btn" onclick="DockerDash.viewLogs('${p[0]}', '${p[1]}')">Logs</button>
                        ${isRunning ? `<button class="dk-btn" onclick="DockerDash.execAction('stop', '${p[0]}')">Stop</button>
                                       <button class="dk-btn" onclick="DockerDash.execAction('restart', '${p[0]}')">Restart</button>` 
                                    : `<button class="dk-btn dk-btn-action" onclick="DockerDash.execAction('start', '${p[0]}')">Start</button>`}
                        <button class="dk-btn dk-btn-danger" onclick="DockerDash.confirmDelete('rm -f', '${p[0]}', '${p[1]}')">Rm</button>
                    </td>
                </tr>`;
            });
        });
    },

    // --- Images Logic ---
    loadImages: function() {
        var tbody = document.getElementById('dk-images-tbody');
        tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">Loading images...</td></tr>';
        
        var format = "{{.ID}}~{{.Repository}}~{{.Tag}}~{{.Size}}~{{.CreatedSince}}";
        this.cmd('docker images --format "' + format + '" 2>&1', function(res) {
            if (res.indexOf('ERROR:') === 0) {
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:red;">' + res + '</td></tr>';
                return;
            }
            var lines = res.trim().split('\n');
            tbody.innerHTML = '';
            if (!res.trim() || lines.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No images found.</td></tr>'; return;
            }
            lines.forEach(line => {
                if (!line.trim()) return;
                var p = line.split('~');
                if (p.length < 4) return;
                tbody.innerHTML += `<tr>
                    <td><b>${p[1]}</b></td>
                    <td>${p[2]}</td>
                    <td>${p[0]}</td>
                    <td>${p[3]}</td>
                    <td><button class="dk-btn dk-btn-danger" onclick="DockerDash.confirmDelete('rmi -f', '${p[0]}', '${p[1]}:${p[2]}')">Delete</button></td>
                </tr>`;
            });
        });
    },

    // --- Volumes Logic ---
    loadVolumes: function() {
        var tbody = document.getElementById('dk-volumes-tbody');
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">Loading volumes...</td></tr>';
        
        var format = "{{.Name}}~{{.Driver}}~{{.Scope}}";
        this.cmd('docker volume ls --format "' + format + '" 2>&1', function(res) {
            if (res.indexOf('ERROR:') === 0) {
                tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:red;">' + res + '</td></tr>';
                return;
            }
            var lines = res.trim().split('\n');
            tbody.innerHTML = '';
            if (!res.trim() || lines.length === 0) {
                tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">No volumes found.</td></tr>'; return;
            }
            lines.forEach(line => {
                if (!line.trim()) return;
                var p = line.split('~');
                if (p.length < 3) return;
                tbody.innerHTML += `<tr>
                    <td><b>${p[0]}</b></td>
                    <td>${p[1]}</td>
                    <td>${p[2]}</td>
                    <td><button class="dk-btn dk-btn-danger" onclick="DockerDash.confirmDelete('volume rm', '${p[0]}', '${p[0]}')">Remove</button></td>
                </tr>`;
            });
        });
    },

    // --- Networks Logic ---
    loadNetworks: function() {
        var tbody = document.getElementById('dk-networks-tbody');
        tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">Loading networks...</td></tr>';
        
        var format = "{{.ID}}~{{.Name}}~{{.Driver}}~{{.Scope}}";
        this.cmd('docker network ls --format "' + format + '" 2>&1', function(res) {
            if (res.indexOf('ERROR:') === 0) {
                tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;color:red;">' + res + '</td></tr>';
                return;
            }
            var lines = res.trim().split('\n');
            tbody.innerHTML = '';
            if (!res.trim() || lines.length === 0) {
                tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;">No networks found.</td></tr>'; return;
            }
            lines.forEach(line => {
                if (!line.trim()) return;
                var p = line.split('~');
                if (p.length < 4) return;
                tbody.innerHTML += `<tr>
                    <td><b>${p[1]}</b><br><span style="font-size:11px;color:#888;">${p[0]}</span></td>
                    <td>${p[2]}</td>
                    <td>${p[3]}</td>
                    <td><button class="dk-btn dk-btn-danger" onclick="DockerDash.confirmDelete('network rm', '${p[0]}', '${p[1]}')">Remove</button></td>
                </tr>`;
            });
        });
    },

    // --- Generic Actions ---
    execAction: function(act, target) {
        this.cmd(`docker ${act} ${target} 2>&1`, function() {
            setTimeout(function() {
                if (DockerDash.currentTab === 'containers') DockerDash.loadContainers();
                if (DockerDash.currentTab === 'images') DockerDash.loadImages();
                if (DockerDash.currentTab === 'volumes') DockerDash.loadVolumes();
                if (DockerDash.currentTab === 'networks') DockerDash.loadNetworks();
            }, 1000);
        });
    },

    confirmDelete: function(act, id, name) {
        if (confirm(`Are you sure you want to remove/delete: ${name}?`)) {
            this.execAction(act, id);
        }
    },

    viewLogs: function(id, name) {
        document.getElementById('dk-modal-title').textContent = 'Logs: ' + name;
        var logView = document.getElementById('dk-log-viewer');
        logView.textContent = 'Fetching logs...';
        document.getElementById('dk-logs-modal').style.display = 'flex';
        
        this.cmd(`docker logs --tail 200 ${id} 2>&1`, function(res) {
            logView.textContent = res.trim() ? res : '[No logs found]';
            logView.scrollTop = logView.scrollHeight;
        });
    },

    closeModal: function() { document.getElementById('dk-logs-modal').style.display = 'none'; },

    // --- Create Container Logic ---
    runCreateContainer: function() {
        var image = document.getElementById('dk-crt-image').value.trim();
        var name = document.getElementById('dk-crt-name').value.trim();
        var ports = document.getElementById('dk-crt-ports').value.trim();
        var restart = document.getElementById('dk-crt-restart').value;
        var extra = document.getElementById('dk-crt-extra').value.trim();
        var outEl = document.getElementById('dk-crt-out');

        if (!image) { alert('Please enter a Docker image name.'); return; }

        var cmdParts = ['docker run -d'];
        if (name) cmdParts.push('--name "' + name + '"');
        if (restart !== 'none') cmdParts.push('--restart ' + restart);
        if (ports) {
            ports.split(',').forEach(p => {
                p = p.trim();
                if (p) cmdParts.push('-p ' + p);
            });
        }
        if (extra) cmdParts.push(extra);
        cmdParts.push(image);

        var finalCmd = cmdParts.join(' ') + ' 2>&1';
        outEl.textContent = 'Executing:\n' + finalCmd + '\n\n...\n';

        this.cmd(finalCmd, function(res) {
            outEl.textContent += res;
            if (res.indexOf('ERROR:') === -1 && res.trim().length > 0) {
                outEl.textContent += '\n\n[Success! Container deployed.]';
            }
            outEl.scrollTop = outEl.scrollHeight;
        });
    },

    // --- Compose Logic ---
    composeAction: function(act) {
        var dir = document.getElementById('dk-compose-dir').value.trim();
        var outEl = document.getElementById('dk-compose-out');
        if (!dir) { alert('Enter an absolute path.'); return; }

        outEl.textContent = `Executing: docker compose ${act}\nDirectory: ${dir}\n...\n`;
        this.cmd(`cd "${dir}" && docker compose ${act} 2>&1`, function(res) {
            outEl.textContent += res;
            outEl.scrollTop = outEl.scrollHeight;
        });
    }
};

function earlyInit() { DockerDash.switchTab('containers'); }
</script>
</head>

<body>
<table id="container">
<tr><td colspan="2" id="header">
	<div class="title"><a href="/">FreshTomato</a></div>
	<div class="version">Version <% version(); %> on <% nv("t_model_name"); %></div>
</td></tr>
<tr id="body"><td id="navi"><script>navi()</script></td>
<td id="content">
<div id="ident"><% ident(); %> | <script>wikiLink();</script></div>

<div class="section-title">Docker Dashboard</div>

<!-- Tab Navigation -->
<div class="dk-tabs">
    <div id="tab-btn-containers" class="dk-tab active" onclick="DockerDash.switchTab('containers')">Containers</div>
    <div id="tab-btn-create" class="dk-tab" onclick="DockerDash.switchTab('create')">+ Create</div>
    <div id="tab-btn-images" class="dk-tab" onclick="DockerDash.switchTab('images')">Images</div>
    <div id="tab-btn-volumes" class="dk-tab" onclick="DockerDash.switchTab('volumes')">Volumes</div>
    <div id="tab-btn-networks" class="dk-tab" onclick="DockerDash.switchTab('networks')">Networks</div>
    <div id="tab-btn-compose" class="dk-tab" onclick="DockerDash.switchTab('compose')">Compose</div>
</div>

<!-- Containers Tab -->
<div id="tab-containers" class="dk-tab-content active">
    <div class="dk-toolbar">
        <button class="dk-btn dk-btn-action" onclick="DockerDash.loadContainers()">&#128260; Refresh</button>
    </div>
    <div style="overflow-x:auto;">
        <table class="dk-table">
            <thead>
                <tr>
                    <th style="width:20%;">Name / ID</th><th style="width:25%;">Image</th>
                    <th style="width:15%;">Status</th><th style="width:20%;">Ports</th><th style="width:20%;">Actions</th>
                </tr>
            </thead>
            <tbody id="dk-containers-tbody"></tbody>
        </table>
    </div>
</div>

<!-- Create Tab -->
<div id="tab-create" class="dk-tab-content">
    <div class="dk-compose-box">
        <h3 style="margin-top:0; font-size:14px; border-bottom:1px solid #ddd; padding-bottom:8px;">Quick Run Container (`docker run`)</h3>
        <div class="dk-form-grid">
            <label>Docker Image *</label>
            <input type="text" id="dk-crt-image" class="dk-input" placeholder="e.g. nginx:latest or alpine">

            <label>Container Name</label>
            <input type="text" id="dk-crt-name" class="dk-input" placeholder="e.g. my-web-server">

            <label>Port Mappings</label>
            <input type="text" id="dk-crt-ports" class="dk-input" placeholder="e.g. 8080:80 (comma separated for multiple)">

            <label>Restart Policy</label>
            <select id="dk-crt-restart" class="dk-select">
                <option value="unless-stopped">unless-stopped (Recommended)</option>
                <option value="always">always</option>
                <option value="no">no</option>
                <option value="on-failure">on-failure</option>
            </select>

            <label>Extra Flags / Env</label>
            <input type="text" id="dk-crt-extra" class="dk-input" placeholder="e.g. -e TZ=America/Toronto -v /opt/data:/data">
        </div>
        <div class="dk-toolbar">
            <button class="dk-btn dk-btn-action" onclick="DockerDash.runCreateContainer()">Deploy Container</button>
        </div>
        <div id="dk-crt-out" class="dk-terminal-out">Deployment output will appear here...</div>
    </div>
</div>

<!-- Images Tab -->
<div id="tab-images" class="dk-tab-content">
    <div class="dk-toolbar">
        <button class="dk-btn dk-btn-action" onclick="DockerDash.loadImages()">&#128260; Refresh</button>
        <button class="dk-btn" onclick="DockerDash.execAction('image prune', '-f')">Prune Unused Images</button>
    </div>
    <div style="overflow-x:auto;">
        <table class="dk-table">
            <thead>
                <tr>
                    <th style="width:25%;">Repository</th><th style="width:15%;">Tag</th>
                    <th style="width:20%;">Image ID</th><th style="width:20%;">Size</th><th style="width:20%;">Actions</th>
                </tr>
            </thead>
            <tbody id="dk-images-tbody"></tbody>
        </table>
    </div>
</div>

<!-- Volumes Tab -->
<div id="tab-volumes" class="dk-tab-content">
    <div class="dk-toolbar">
        <button class="dk-btn dk-btn-action" onclick="DockerDash.loadVolumes()">&#128260; Refresh</button>
        <button class="dk-btn" onclick="DockerDash.execAction('volume prune', '-f')">Prune Unused Volumes</button>
    </div>
    <div style="overflow-x:auto;">
        <table class="dk-table">
            <thead>
                <tr>
                    <th style="width:40%;">Volume Name</th><th style="width:20%;">Driver</th>
                    <th style="width:20%;">Scope</th><th style="width:20%;">Actions</th>
                </tr>
            </thead>
            <tbody id="dk-volumes-tbody"></tbody>
        </table>
    </div>
</div>

<!-- Networks Tab -->
<div id="tab-networks" class="dk-tab-content">
    <div class="dk-toolbar">
        <button class="dk-btn dk-btn-action" onclick="DockerDash.loadNetworks()">&#128260; Refresh</button>
        <button class="dk-btn" onclick="DockerDash.execAction('network prune', '-f')">Prune Unused Networks</button>
    </div>
    <div style="overflow-x:auto;">
        <table class="dk-table">
            <thead>
                <tr>
                    <th style="width:30%;">Name / ID</th><th style="width:25%;">Driver</th>
                    <th style="width:25%;">Scope</th><th style="width:20%;">Actions</th>
                </tr>
            </thead>
            <tbody id="dk-networks-tbody"></tbody>
        </table>
    </div>
</div>

<!-- Compose Tab -->
<div id="tab-compose" class="dk-tab-content">
    <div class="dk-compose-box">
        <div style="margin-bottom: 15px;">
            <label style="font-weight:bold; margin-right: 10px;">Stack Directory:</label>
            <input type="text" id="dk-compose-dir" class="dk-compose-input dk-input" placeholder="/opt/docker/forgejo" style="max-width:350px;">
        </div>
        <div class="dk-toolbar">
            <button class="dk-btn dk-btn-action" onclick="DockerDash.composeAction('up -d')">Up (-d)</button>
            <button class="dk-btn" onclick="DockerDash.composeAction('stop')">Stop</button>
            <button class="dk-btn" onclick="DockerDash.composeAction('start')">Start</button>
            <button class="dk-btn dk-btn-danger" onclick="DockerDash.composeAction('down')">Down</button>
            <button class="dk-btn" onclick="DockerDash.composeAction('pull')">Pull Updates</button>
            <button class="dk-btn" onclick="DockerDash.composeAction('logs --tail 100')">Logs</button>
        </div>
        <div id="dk-compose-out" class="dk-terminal-out">Output will appear here...</div>
    </div>
</div>

<div id="footer">&nbsp;</div>
</td></tr>
</table>

<!-- Log Modal -->
<div id="dk-logs-modal" class="dk-modal">
    <div class="dk-modal-content">
        <h3 id="dk-modal-title" style="margin-top:0;">Logs</h3>
        <div id="dk-log-viewer" class="dk-terminal-out" style="height:400px; margin-top:0;"></div>
        <div style="text-align:right; margin-top:10px;">
            <button class="dk-btn dk-btn-danger" onclick="DockerDash.closeModal()">Close</button>
        </div>
    </div>
</div>

<script>earlyInit();</script>
</body>
</html>
