import { API_ORIGIN } from "../../config/runtime.mjs";

export function loadUser(id, callback) {
  fetch(`${API_ORIGIN}/users/${encodeURIComponent(id)}`, { credentials: "include" })
    .then(async response => callback(response.status, await response.text()))
    .catch(() => callback(0, ""));
}
