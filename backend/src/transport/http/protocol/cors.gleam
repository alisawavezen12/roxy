import gleam/http

pub const allowed_methods = [http.Get, http.Head]

pub const allowed_headers = ["Content-Type"]
