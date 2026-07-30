const sections = [
  { id: "session", title: "Session", intro: "Establish the route, run audio first, and keep measured proof distinct from configuration." },
  { id: "devices", title: "Devices", intro: "Review the sanitized endpoint inventory used by this demo. Browser access to local hardware is disabled." },
  { id: "routing", title: "Routing", intro: "Inspect the staged direct-peer route. Editing and applying routes are simulated in this static demo." },
  { id: "streams", title: "Streams", intro: "Monitor a fixed sample of the Signal Desk stream view. Levels do not come from a microphone or network peer." },
  { id: "packets", title: "Packet Monitor", intro: "Inspect three sanitized fixture packets. This page never captures, sends, or receives network traffic." },
  { id: "validation", title: "Validation", intro: "Review which fixture checks passed and which real-world evidence remains outside this static demo." },
  { id: "diagnostics", title: "Diagnostics", intro: "View a sanitized diagnostic summary. No process, filesystem, device, or network diagnostics run in the browser." }
];

const workspace = document.querySelector("#workspace");
const workspaceTitle = document.querySelector("#workspace-title");
const workspaceIntro = document.querySelector("#workspace-intro");
const workspaceBody = document.querySelector("#workspace-body");
const titlebarSection = document.querySelector("#titlebar-section");
const sidebar = document.querySelector("#sidebar");
const mobileNav = document.querySelector(".mobile-nav");
const toast = document.querySelector("#toast");
let toastTimer;

function sectionDefinition(id) {
  return sections.find(section => section.id === id) || sections.find(section => section.id === "session");
}

function renderSection(id, moveFocus = false) {
  const section = sectionDefinition(id);
  const template = document.getElementById(`${section.id}-template`);
  titlebarSection.textContent = section.title;
  workspaceTitle.textContent = section.title;
  workspaceIntro.textContent = section.intro;
  workspaceBody.replaceChildren(template.content.cloneNode(true));
  document.querySelectorAll(".nav-item").forEach(button => {
    const selected = button.dataset.section === section.id;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-current", selected ? "page" : "false");
  });
  document.title = `${section.title} · Open LoLa Signal Desk demo`;
  history.replaceState(null, "", `#${section.id}`);
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
