const sectionContent = {
  session: {
    title: "Session",
    intro: "Establish the route, run audio first, and keep measured proof distinct from configuration.",
    body: `
      <section class="panel metric-hero">
        <div class="latency"><div class="panel-kicker">Worst-peer audio p99 <span class="status-label">fixture target met</span></div><strong>4.7</strong><b>ms</b><small>Validated sample report · not live meters</small></div>
        <div class="metric-pairs"><div class="metric-row"><span>Packet loss</span><strong>0.0<small>%</small></strong></div><div class="metric-row"><span>Jitter p99</span><strong>0.3<small> ms</small></strong></div></div>
      </section>
      <p class="evidence-note"><b>Fixture evidence</b> Maximum audio p99 across a sanitized sample. Local preview meters do not prove remote receive.</p>
      <section class="panel"><h2>Signal path</h2><div class="signal-path"><div class="endpoint"><small>Local</small><strong>mac-a</strong><span>192.0.2.10</span></div><div class="route-lines"><div class="route-line active" data-label="Audio · 64 ch"></div><div class="route-line" data-label="Video"></div><div class="route-line" data-label="Control"></div><div class="route-line" data-label="Metrics"></div></div><div class="endpoint"><small>Remote</small><strong>mac-b</strong><span>192.0.2.20</span></div></div></section>
      <section class="panel"><h2>Evidence chain</h2><div class="grid-three"><article class="data-card"><small>Source</small><strong>Partial</strong><span>Inventory and capability checks. Not a media measurement.</span></article><article class="data-card"><small>Observed</small><strong>Fixture run</strong><span>Sanitized report loaded. No process was launched.</span></article><article class="data-card pass"><small>Validated</small><strong>Passed</strong><span>Schema and useful-media policy passed for the fixture.</span></article></div></section>`
  },
  devices: {
    title: "Devices",
    intro: "Review the sanitized endpoint inventory used by this demo. Browser access to local hardware is disabled.",
    body: `<section class="panel"><div class="panel-kicker">Local endpoint <span class="status-label">fixture inventory</span></div><div class="grid-two"><article class="data-card"><small>Audio input</small><strong>Studio Input 64ch</strong><span>Fixture UID: demo-input-01 · 48 kHz · 64 channels</span></article><article class="data-card"><small>Audio output</small><strong>Studio Output 64ch</strong><span>Fixture UID: demo-output-01 · 48 kHz · 64 channels</span></article><article class="data-card"><small>Video input</small><strong>Demo Camera 1080p</strong><span>Sanitized AVFoundation inventory record</span></article><article class="data-card"><small>Clock</small><strong>External · locked</strong><span>Recorded fixture state, not a current device query</span></article></div><button class="sim-action section-action" data-action="Refresh device inventory">Refresh Inventory · simulated</button></section>`
  },
  routing: {
    title: "Routing",
    intro: "Inspect the staged direct-peer route. Editing and applying routes are simulated in this static demo.",
    body: `<section class="panel"><h2>Direct peer</h2><div class="signal-path"><div class="endpoint"><small>Local</small><strong>mac-a</strong><span>192.0.2.10 : 40100</span></div><div class="route-lines"><div class="route-line active" data-label="UDP PCM"></div><div class="route-line active" data-label="64 × Float 32"></div><div class="route-line" data-label="Preview off"></div></div><div class="endpoint"><small>Remote</small><strong>mac-b</strong><span>192.0.2.20 : 40100</span></div></div></section><section class="panel"><div class="grid-two"><article class="data-card"><small>Profile</small><strong>Synthetic Headless</strong><span>Audio-first · 48 kHz · 64 samples per packet</span></article><article class="data-card"><small>Policy</small><strong>Direct path required</strong><span>No relay · fixed sanitized addresses · preview optional</span></article></div><button class="sim-action section-action" data-action="Apply route">Apply Route · simulated</button></section>`
  },
  streams: {
    title: "Streams",
    intro: "Monitor a fixed sample of the Signal Desk stream view. Levels do not come from a microphone or network peer.",
    body: `<section class="panel"><h2>Audio receive preview</h2><div class="table-wrap"><table><thead><tr><th>Stream</th><th>Channels</th><th>Level</th><th>State</th></tr></thead><tbody><tr><td>Main return</td><td>1–32</td><td><div class="meter" style="--level:68%"><span></span></div></td><td>Fixture active</td></tr><tr><td>Stage return</td><td>33–64</td><td><div class="meter" style="--level:43%"><span></span></div></td><td>Fixture active</td></tr><tr><td>Video return</td><td>Stream 101</td><td>1920 × 1080</td><td>Preview sample</td></tr></tbody></table></div><button class="sim-action section-action" data-action="Toggle preview">Toggle Preview · simulated</button></section>`
  },
  packets: {
    title: "Packet Monitor",
    intro: "Inspect three sanitized fixture packets. This page never captures, sends, or receives network traffic.",
    body: `<section class="panel"><div class="panel-kicker">Decoded packet fixture <span class="status-label">3 packets</span></div><div class="table-wrap"><table><thead><tr><th>Sequence</th><th>Source</th><th>Destination</th><th>Payload</th><th>Delta</th></tr></thead><tbody><tr><td><code>004218</code></td><td><code>192.0.2.10</code></td><td><code>192.0.2.20</code></td><td>Audio · 64ch</td><td>0.00 ms</td></tr><tr><td><code>004219</code></td><td><code>192.0.2.10</code></td><td><code>192.0.2.20</code></td><td>Audio · 64ch</td><td>0.33 ms</td></tr><tr><td><code>004220</code></td><td><code>192.0.2.10</code></td><td><code>192.0.2.20</code></td><td>Audio · 64ch</td><td>0.34 ms</td></tr></tbody></table></div><button class="sim-action section-action" data-action="Export packet fixture">Export Packet View · simulated</button></section>`
  },
  validation: {
    title: "Validation",
    intro: "Review which fixture checks passed and which real-world evidence remains outside this static demo.",
    body: `<section class="panel"><div class="grid-three"><article class="data-card pass"><small>Report schema</small><strong>Passed</strong><span>Required fields and evidence classifications are present.</span></article><article class="data-card pass"><small>Useful media</small><strong>Passed</strong><span>Fixture packet and timing fields meet sample policy.</span></article><article class="data-card"><small>Field evidence</small><strong>Not tested</strong><span>Requires physical peers, devices, and measured runs.</span></article></div><button class="sim-action section-action" data-action="Validate fixture">Validate Fixture · simulated</button></section><p class="evidence-note"><b>Boundary</b> A successful fixture validation is not latency, hardware, stability, or interoperability proof.</p>`
  },
  diagnostics: {
    title: "Diagnostics",
    intro: "View a sanitized diagnostic summary. No process, filesystem, device, or network diagnostics run in the browser.",
    body: `<section class="panel"><h2>Fixture diagnostic summary</h2><div class="table-wrap"><table><tbody><tr><th>Application</th><td>Open LoLa Signal Desk</td><td>Static demo</td></tr><tr><th>Configuration</th><td>Synthetic Headless Profile</td><td>Loaded</td></tr><tr><th>Report</th><td><code>/fixture/reports/session-042.json</code></td><td>Validated</td></tr><tr><th>Network access</th><td>Disabled</td><td>Not requested</td></tr><tr><th>Media access</th><td>Disabled</td><td>Not requested</td></tr></tbody></table></div><button class="sim-action section-action" data-action="Run diagnostics">Run Diagnostics · simulated</button></section>`
  }
};

const workspace = document.querySelector("#workspace");
const titlebarSection = document.querySelector("#titlebar-section");
const sidebar = document.querySelector("#sidebar");
const mobileNav = document.querySelector(".mobile-nav");
const toast = document.querySelector("#toast");
let toastTimer;

function renderSection(id, moveFocus = false) {
  const section = sectionContent[id] || sectionContent.session;
  titlebarSection.textContent = section.title;
  workspace.innerHTML = `<header class="page-head"><div><h1>${section.title}</h1><p>${section.intro}</p></div><div class="phase-rail" aria-label="Demo workflow"><span class="done">Setup</span><span class="done">Ready</span><span class="done">Fixture</span><span class="current">Review</span></div></header>${section.body}`;
  document.querySelectorAll(".nav-item").forEach(button => {
    const selected = button.dataset.section === id;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-current", selected ? "page" : "false");
  });
  document.title = `${section.title} · Open LoLa Signal Desk demo`;
  history.replaceState(null, "", `#${id}`);
  bindSimulatedActions();
  if (moveFocus) workspace.focus();
}

function showSimulation(action) {
  const message = `${action} was simulated locally. No command, device, media, network, or filesystem action occurred.`;
  document.querySelector("#run-state-title").textContent = `${action} simulated`;
  document.querySelector("#run-state-copy").textContent = "No command ran.";
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 4200);
}

function bindSimulatedActions() {
  document.querySelectorAll(".sim-action").forEach(button => {
    if (button.dataset.bound) return;
    button.dataset.bound = "true";
    button.addEventListener("click", () => showSimulation(button.dataset.action || "Action"));
  });
}

document.querySelectorAll(".nav-item").forEach(button => {
  button.addEventListener("click", () => {
    renderSection(button.dataset.section, true);
    sidebar.classList.remove("open");
    mobileNav.setAttribute("aria-expanded", "false");
  });
});

mobileNav.addEventListener("click", () => {
  const open = sidebar.classList.toggle("open");
  mobileNav.setAttribute("aria-expanded", String(open));
});

window.addEventListener("hashchange", () => renderSection(location.hash.slice(1) || "session"));
renderSection(location.hash.slice(1) || "session");
bindSimulatedActions();
