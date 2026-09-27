const sections = {
  session: ['Session', 'Prepare the audio path, rehearse the run, and review the evidence.'],
  setup: ['Setup', 'Stage your peer and audio devices. Changes clear readiness and arming.'],
  monitor: ['Monitor', 'Observe the boundary between fixture samples and current session evidence.'],
  evidence: ['Evidence', 'Keep current observations separate from the historical sample report.'],
  tour: ['Screenshots', 'Offline renders of the native Signal Desk and a quick tour of each workspace.']
};
const state = {
  phase: 'Setup', armed: false, checking: false, ready: false, section: 'session',
  config: { peer: '192.0.2.20', input: 'Studio Input 64ch', output: 'Studio Output 64ch', scenario: 'ready' },
  result: 'Readiness has not been checked.', recording: false, preview: false, messages: [], revision: 0
};
const $ = selector => document.querySelector(selector);
let toastTimer;

function announce(message) {
  $('#toast').textContent = message;
  $('#toast').classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => $('#toast').classList.remove('show'), 4200);
}

function readinessError() {
  if (!['192.0.2.20', '192.0.2.30'].includes(state.config.peer)) return 'Choose 192.0.2.20 or 192.0.2.30 for this fixture rehearsal.';
  return '';
}

function nextStep() {
  if (state.checking) return ['Checking readiness', 'Reading the selected local fixture…', 'Open Setup', 'setup'];
  if (state.phase === 'Live') return ['Simulation running', 'Stop the simulation to review. Real audio health remains Not measured.', 'Open Monitor', 'monitor'];
  if (state.phase === 'Review') return ['Review this rehearsal', 'No runtime report was produced. Review the evidence boundary or check readiness for another run.', 'Open Evidence', 'evidence'];
  if (state.armed) return ['Ready to start', 'Audio path is armed for simulation. Start is available in the persistent controls.', 'Open Monitor', 'monitor'];
  if (state.ready) return ['Ready to arm', 'The fixture configuration passed its readiness check. Arm below, then Start.', 'Review Setup', 'setup'];
  return ['Prepare your audio path', 'Choose a peer and audio devices in Setup, then check readiness before arming.', 'Open Setup', 'setup'];
}

function setControl(action, enabled, reason) {
  const button = $(`[data-action="${action}"]`);
  button.disabled = !enabled;
  button.title = reason;
  button.setAttribute('aria-describedby', `${action.toLowerCase()}-reason`);
  let description = $(`#${action.toLowerCase()}-reason`);
  if (!description) {
    description = document.createElement('span');
    description.id = `${action.toLowerCase()}-reason`;
    description.className = 'control-reason';
    button.after(description);
  }
  description.textContent = reason;
}

function updateChrome() {
  const live = state.phase === 'Live';
  const step = nextStep();
  $('#run-state-title').textContent = `${state.phase} · ${state.armed ? 'Armed' : 'Not armed'} · simulated`;
  $('#run-state-copy').textContent = step[1];
  $('#inspector-phase').textContent = state.phase;
  $('#inspector-arm').textContent = state.armed ? 'Armed for simulation' : 'Not armed';
  document.querySelectorAll('[data-phase]').forEach(el => {
    el.classList.toggle('current', el.dataset.phase === state.phase);
    if (el.dataset.phase === state.phase) el.setAttribute('aria-current', 'step');
    else el.removeAttribute('aria-current');
  });
  setControl('Arm', state.ready && !state.armed && !live, state.armed ? 'Already armed' : state.ready ? 'Arm the simulation' : 'Check readiness first');
  setControl('Start', state.armed && !live, live ? 'Simulation running' : state.armed ? 'Start the simulation' : 'Arm before starting');
  setControl('Stop', live, live ? 'Stop and review' : 'No simulation running');
}

function fillObservations() {
  const values = [
    ['Control reachable', 'Not measured'], ['Session negotiated', 'Not measured'],
    ['Media TX', 'Not measured'], ['Media RX', 'Not measured'],
    ['Preview provenance', 'Fixture only · no remote receive proof'], ['Current report validated', 'No runtime report']
  ];
  document.querySelectorAll('[data-observations]').forEach(container => {
    for (const [name, value] of values) {
      const row = document.createElement('div');
      const label = document.createElement('span');
      const result = document.createElement('strong');
      label.textContent = name;
      result.textContent = value;
      row.append(label, result);
      container.append(row);
    }
  });
}

function fillSection() {
  document.querySelectorAll('[data-template]').forEach(el => {
    el.append($(`#${el.dataset.template}-template`).content.cloneNode(true));
  });
  document.querySelectorAll('[data-config]').forEach(el => { el.textContent = state.config[el.dataset.config]; });
  fillObservations();
  if ($('#next-title')) {
    const [title, copy, label, target] = nextStep();
    $('#next-title').textContent = title;
    $('#next-copy').textContent = copy;
    $('#next-action').textContent = label;
    $('#next-action').dataset.go = target;
  }
  if ($('#setup-form')) bindSetup();
  if ($('#chat-form')) bindMonitor();
  if ($('#review-state')) $('#review-state').textContent = state.phase === 'Review' ? 'Simulation stopped. No real media was sent, received, or recorded.' : 'No completed rehearsal to review yet. Stop a running simulation to enter Review.';
}

function renderSection(id, focus = false, historyMode = 'replace') {
  const aliases = { devices: 'setup', routing: 'setup', streams: 'monitor', packets: 'monitor', validation: 'evidence', diagnostics: 'evidence' };
  state.section = sections[id] ? id : aliases[id] || 'session';
  const [title, intro] = sections[state.section];
  $('#workspace-title').textContent = title;
  $('#titlebar-section').textContent = title;
  $('#workspace-intro').textContent = intro;
  $('#workspace-body').replaceChildren($(`#${state.section}-template`).content.cloneNode(true));
  document.querySelectorAll('.nav-item').forEach(button => {
    const selected = button.dataset.section === state.section;
    button.classList.toggle('active', selected);
    if (selected) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  });
  document.title = `${title} · Open LoLa Signal Desk demo`;
  if (historyMode !== 'none') history[`${historyMode}State`](null, '', `#${state.section}`);
  fillSection();
  updateChrome();
  if (focus) $('#workspace').focus();
}

function refreshSetup() {
  const error = readinessError();
  $('[name="peer"]').setAttribute('aria-invalid', String(Boolean(error)));
  $('#config-error').textContent = error;
  $('#readiness-result').textContent = state.result;
  $('#configuration').disabled = state.phase === 'Live';
  $('#check-ready').disabled = Boolean(error) || state.checking || state.phase === 'Live';
  $('#check-ready').textContent = state.checking ? 'Checking fixture…' : 'Check readiness · simulated';
  $('#setup-form').setAttribute('aria-busy', String(state.checking));
  if (state.phase === 'Live') $('#readiness-result').textContent = 'Stop the simulation before changing configuration.';
}

function bindSetup() {
  Object.entries(state.config).forEach(([key, value]) => { $(`[name="${key}"]`).value = value; });
  $('#setup-form').addEventListener('input', event => {
    if (!Object.hasOwn(state.config, event.target.name)) return;
    state.config[event.target.name] = event.target.value.trim();
    state.revision += 1;
    state.ready = false;
    state.armed = false;
    state.checking = false;
    state.phase = 'Setup';
    state.result = 'Configuration changed. Check readiness again; arming was cleared.';
    refreshSetup();
    updateChrome();
  });
  $('#setup-form').addEventListener('submit', event => {
    event.preventDefault();
    checkReadiness();
  });
  refreshSetup();
}

function checkReadiness() {
  if (readinessError() || state.checking || state.phase === 'Live') return;
  const revision = state.revision;
  state.checking = true;
  state.armed = false;
  state.ready = false;
  state.phase = 'Setup';
  state.result = 'Reading fixture configuration…';
  refreshSetup();
  updateChrome();
  setTimeout(() => {
    if (revision !== state.revision) return;
    state.checking = false;
    const results = {
      ready: 'Ready fixture passed. Arm, then Start to rehearse. No hardware or network was checked.',
      error: 'Input unavailable in this fixture. Choose Ready fixture and check again.',
      empty: 'No audio devices in this fixture. Choose Ready fixture to restore the sample inventory.'
    };
    state.ready = state.config.scenario === 'ready';
    state.phase = state.ready ? 'Ready' : 'Setup';
    state.result = results[state.config.scenario];
    if ($('#setup-form')) refreshSetup();
    if (state.section === 'session') renderSection('session', false, 'none');
    updateChrome();
    announce(state.result);
  }, 450);
}

function renderMessages() {
  $('#chat-empty').hidden = state.messages.length > 0;
  $('#chat-messages').replaceChildren();
  state.messages.forEach(message => {
    const item = document.createElement('li');
    item.textContent = `You · local only: ${message}`;
    $('#chat-messages').append(item);
  });
}

function updateRecording() {
  $('#record').disabled = state.phase !== 'Live';
  $('#record').setAttribute('aria-pressed', String(state.recording));
  $('#record').textContent = state.recording ? 'Stop recording simulation' : 'Start recording simulation';
  $('#record-state').textContent = state.phase !== 'Live' ? 'Start the session simulation to rehearse recording.' : state.recording ? 'Recording simulation active. No file is written.' : 'No recording simulation active.';
  $('#preview-state').textContent = `Preview ${state.preview ? 'on' : 'off'} · fixture only; no decoded remote media`;
}

function bindMonitor() {
  updateRecording();
  renderMessages();
  $('#record').addEventListener('click', () => {
    state.recording = !state.recording;
    updateRecording();
  });
  $('#chat-form').addEventListener('submit', event => {
    event.preventDefault();
    const message = $('#chat-message').value.trim();
    if (!message) return;
    state.messages.push(message);
    $('#chat-message').value = '';
    renderMessages();
  });
}

function runAction(action) {
  if (action === 'Arm' && state.ready) state.armed = true;
  else if (action === 'Start' && state.armed) state.phase = 'Live';
  else if (action === 'Stop' && state.phase === 'Live') {
    state.phase = 'Review';
    state.result = 'Rehearsal stopped. Check readiness again before arming.';
    state.armed = false;
    state.ready = false;
    state.recording = false;
  } else if (action === 'Toggle preview') {
    state.preview = !state.preview;
    updateRecording();
    return;
  } else {
    announce(`${action} simulated. No device, media, network, or filesystem action occurred.`);
    return;
  }
  renderSection(state.section, false, 'none');
  announce(`${action} simulated. ${nextStep()[1]}`);
}

document.addEventListener('click', event => {
  const button = event.target.closest('button');
  if (!button || button.disabled) return;
  const destination = button.dataset.section || button.dataset.go;
  if (destination) {
    renderSection(destination, true, 'push');
    $('#sidebar').classList.remove('open');
    $('.mobile-nav').setAttribute('aria-expanded', 'false');
  }
  if (button.dataset.action) runAction(button.dataset.action);
});
$('.mobile-nav').addEventListener('click', () => {
  const open = $('#sidebar').classList.toggle('open');
  $('.mobile-nav').setAttribute('aria-expanded', String(open));
});
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && $('#sidebar').classList.contains('open')) {
    $('#sidebar').classList.remove('open');
    $('.mobile-nav').setAttribute('aria-expanded', 'false');
    $('.mobile-nav').focus();
  }
});
window.addEventListener('popstate', () => renderSection(location.hash.slice(1), true, 'none'));
renderSection(location.hash.slice(1));
