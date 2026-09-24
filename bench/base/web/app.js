// benchapp front-end: plain browser JavaScript, no build step.
const results = document.getElementById("results");

async function search(query) {
  const res = await fetch(`/api/users?q=${encodeURIComponent(query)}`);
  const users = await res.json();
  results.replaceChildren(...users.map((u) => Object.assign(document.createElement("li"), { textContent: u.email })));
}

document.getElementById("search").addEventListener("input", (e) => search(e.target.value));
