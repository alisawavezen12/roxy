import { API_ORIGIN } from "../../config/runtime.mjs";

export function loadCurrentUser(dispatch) {
  fetch(`${API_ORIGIN}/auth/me`, { credentials: "include" })
    .then(async response => {
      if (response.status === 401) return { status: "unauthenticated" };
      if (!response.ok) return { status: "error" };

      const payload = await response.json();
      const name = payload?.user?.name;
      return typeof name === "string" && name.trim() !== ""
        ? { status: "authenticated", name }
        : { status: "error" };
    })
    .catch(() => ({ status: "error" }))
    .then(result => dispatch(
      result.status === "authenticated" ? `authenticated:${result.name}` : result.status,
    ));
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
