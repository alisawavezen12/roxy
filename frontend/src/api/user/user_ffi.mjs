import { API_ORIGIN } from "../../config/runtime.mjs";

export function loadUser(id, callback) {
  fetch(`${API_ORIGIN}/users/${encodeURIComponent(id)}`, { credentials: "include" })
    .then(async response => callback(response.status, await response.text()))
    .catch(() => callback(0, ""));
}

export function saveBio(bio, callback) {
  fetch(`${API_ORIGIN}/auth/profile`, {
    method: "PATCH",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ bio }),
  })
    .then(async response => callback(response.status, await response.text()))
    .catch(() => callback(0, ""));
}
