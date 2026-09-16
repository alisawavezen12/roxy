import gleam/http

pub const allowed_methods = [http.Get, http.Head, http.Patch]

pub const allowed_headers = ["Content-Type"]
