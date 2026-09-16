import { API_ORIGIN } from "../../config/runtime.mjs";

export function loadCurrentUser(callback) {
  fetch(`${API_ORIGIN}/auth/me`, { credentials: "include" })
    .then(async response => callback(response.status, await response.text()))
    .catch(() => callback(0, ""));
}

export function syncProfile(callback) {
  fetch(`${API_ORIGIN}/auth/sync`, {
    method: "POST",
    credentials: "include",
  })
    .then(async response => callback(response.status, await response.text()))
    .catch(() => callback(0, ""));
}

export function logout(callback) {
  fetch(`${API_ORIGIN}/auth/sso/logout`, {
    method: "POST",
    credentials: "include",
  })
    .then(response => callback(response.status))
    .catch(() => callback(0));
}

export function alertUser(message) {
  window.alert(message);
}

export function startSsoLogin() {
  const apiUrl = new URL(API_ORIGIN);
  const returnTo = new URL(window.location.href);

  if (isLoopback(apiUrl.hostname) && isLoopback(returnTo.hostname)) {
    returnTo.hostname = apiUrl.hostname;
  }

  const loginUrl = new URL("/auth/sso", apiUrl);
  loginUrl.searchParams.set("return_to", returnTo.toString());
  window.location.assign(loginUrl.toString());
}

function isLoopback(hostname) {
  return hostname === "localhost" || hostname === "127.0.0.1" || hostname === "[::1]";
}
