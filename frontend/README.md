# Frontend architecture

The frontend is a Gleam/Lustre application organized around a small set of
explicit layers. Keep dependencies flowing toward the application and domain,
not the other way around.

```text
src/
├── api/
├── app/
├── domain/
├── pages/
├── routes/
├── ui/
│   ├── layout/
│   └── styles/
└── frontend.gleam
```

## Layer responsibilities

### `src/frontend.gleam`

Browser entrypoint only. It creates and starts the Lustre application. It should
not contain page markup, API calls, or business rules.

### `src/app/`

Global application coordination:

- global `Model`;
- global `Message` type;
- root `update` function;
- root view composition and application-wide effects.

`app/` connects pages, routes, API effects, and domain data. It should not become
a dumping ground for screen-specific state or reusable visual components.

### `src/domain/`

Pure business model and business rules:

- domain types such as `User`;
- validation and transformations;
- rules that do not depend on Lustre, HTML, browser APIs, HTTP, or JSON DTOs.

Domain modules must remain framework- and transport-independent. This is the
most reusable layer and should be easy to test as pure Gleam code.

### `src/api/`

Network boundary:

- HTTP requests;
- request and response DTOs;
- JSON encoders and decoders;
- mapping transport errors into application-facing results.

API modules may depend on transport libraries and domain modules, but domain
modules must not depend on `api/`.

### `src/pages/`

Screen-level composition and orchestration. A page owns the view and, when it
becomes non-trivial, its screen-specific state and messages. Pages may combine
`ui/` components, call application callbacks, and translate domain data into
page-facing state.

Do not put generic UI primitives or transport implementation here.

### `src/routes/`

URL and route concerns:

- route types;
- parsing the current location;
- route matching and navigation policy.

Routes select pages. They should not contain business logic or API decoding.

### `src/ui/`

Reusable presentation and UI primitives:

- layouts;
- buttons, forms, lists, and other reusable components;
- Lustre elements and presentation attributes.

`ui/` should focus on rendering and interaction wiring. It should not perform
HTTP requests or own global application state.

The current base layout is located at:

```text
src/ui/layout/base_layout.gleam
```

### `src/ui/styles/`

Global visual system owned by the UI layer:

- reset;
- design tokens;
- theme variables;
- global styles.

Styles are connected from `gleam.toml` and are kept separate from Gleam view
code. Component-specific styles can be added near the relevant UI layer when
that need appears.

## Dependency rules

Use these rules when adding a module:

1. `domain/` must not import `ui/`, `pages/`, `app/`, `api/`, Lustre, or HTTP.
2. `ui/` renders data and emits messages; it does not fetch data.
3. `api/` owns serialization and transport details; it does not render HTML.
4. `pages/` orchestrates a screen; reusable visual code belongs in `ui/`.
5. `app/` coordinates the application; it should delegate domain rules to
   `domain/` and network work to `api/`.
6. Add new modules only when a real feature needs them; avoid creating empty
   abstractions in advance.
