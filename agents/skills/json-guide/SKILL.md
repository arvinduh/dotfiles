---
name: json-guide
description: >-
  Personal JSON engineering standard — the Google JSON Style Guide with personal
  engineering directives (strict double quotes, camelCase property naming, ISO
  8601/RFC 3339 timestamps, standard API envelopes, zero comments), enforced by
  Biome/Prettier and schema validators. Complements typescript-guide and
  html-css-guide. Use whenever designing, serializing, validating, or consuming
  JSON data and APIs.
---

# JSON Engineering Guide

The standard builds on the [Google JSON Style Guide][google-json]. Enforce
through tools wherever possible. Prose covers property naming, serialization
formats, pagination protocols, and standard API envelopes.

[google-json]: https://google.github.io/styleguide/jsoncguide.html

## 0. Precedence

This guide is the default. A repository's own `AGENTS.md`/`CLAUDE.md`, API
specifications (OpenAPI/JSONSchema), `.prettierrc`, `biome.json`, or
`package.json` wins where it says something different. Never "fix" a repo toward
this guide as a side effect of other work.

Where this guide and the Google JSON Style Guide differ, **this guide's rules
take precedence**.

## 1. Toolchain & Enforcement

| Tool / Layer         | Covers                                              |
| -------------------- | --------------------------------------------------- |
| `biome` / `prettier` | layout: 2-space indent, 80 columns, double quotes   |
| `zod` / `typebox`    | schema validation, runtime invariants, typing       |
| JSONSchema / Linter  | structural validation, formats, required properties |

- Enforce standard formatting via automated formatters.
- Zero comments in raw `.json` files. For configurations requiring comments, use
  `.jsonc` or `.json5` where explicitly supported by tooling.

Gate: `biome format --check .` (or repo equivalent JSON lint / validation).

## 2. Core Baseline Rules

- **Strict JSON Syntax:** Double quotes are mandatory for all property names and
  string values (`"key": "value"`). Never use single quotes.
- **No Comments:** JSON payloads must never contain comments.
- **Flattened Data over Deep Nesting:** Keep structures flat and avoid arbitrary
  grouping. Group sub-properties only when they represent a distinct, reusable
  semantic structure (e.g. `"address": { "line1": "...", ... }`).

## 3. Property Naming Guidelines

- **Format:** Property names must be camelCase ASCII strings (`"userId"`,
  `"totalItems"`). The first character must be a letter, underscore, or `$`.
- **Reserved Words:** Avoid JavaScript reserved keywords as property names
  (`class`, `function`, `default`, `delete`, `return`). This ensures clients can
  access properties cleanly via dot notation (`response.data.userId`).
- **Plural vs. Singular:**
  - Array properties must use plural names (`"items"`, `"users"`, `"tags"`).
  - Scalar properties and objects must use singular names (`"author"`,
    `"address"`).
  - Quantitative metrics: Use singular total qualifiers (`"totalItems"` or
    `"itemCount"`, never `"totalItem"`).
- **Map Keys:** Objects used as associative arrays or dictionaries (maps) may
  use numbers or arbitrary Unicode keys (e.g. `"thumbnails": { "72": "..." }`).
  Clients access map keys via bracket notation (`obj.thumbnails["72"]`).

## 4. Property Value Guidelines

- **Allowed Types:** Values must be booleans, numbers, strings, objects, arrays,
  or `null`. JavaScript expressions or functions are strictly disallowed.
- **Null and Empty Values:** Drop optional or null properties from the payload
  unless there is a meaningful semantic distinction between `null` and absent
  (e.g., an audio balance of `0` is meaningful, while `null` fields can be
  omitted to save bandwidth).
- **Enums as Strings:** Enum values must always be serialized as strings
  (`"ACTIVE"`, `"PENDING"`), never arbitrary integer codes.
- **Standardized Formats for Strings:**
  - **Timestamps:** Format all dates and timestamps using RFC 3339 / ISO 8601
    UTC strings: `"2026-10-10T16:00:00.000Z"`.
  - **Durations:** Format time durations using ISO 8601 duration strings:
    `"P3Y6M4DT12H30M5S"`.
  - **Coordinates:** Format latitudes and longitudes using ISO 6709:
    `"+40.6894-074.0447"`.

---

## 5. JSON API Structure & Reserved Property Names

Standard JSON request and response payloads follow a unified envelope.

### A. Top-Level Envelope

```json
{
  "apiVersion": "2.0",
  "context": "client-correlation-id",
  "id": "server-log-id-1234",
  "data": { ... }
}
```

- **`apiVersion`:** String representing the service API version.
- **`context`:** Client-supplied correlation identifier echoed by the server.
- **`id`:** Server-supplied unique response identifier for log tracing.
- **Mutually Exclusive Payloads:** An API response must contain either `"data"`
  or `"error"`, never both. If an error occurs, `"error"` takes precedence.

### B. The `data` Object & Property Ordering

When streaming or parsing JSON responses, order properties intentionally: place
`"kind"` first and `"items"` last.

```json
{
  "data": {
    "kind": "photoAlbum",
    "id": "album-42",
    "totalItems": 100,
    "itemsPerPage": 10,
    "startIndex": 1,
    "items": [{ "id": "photo-1", "title": "First Photo" }]
  }
}
```

- **`kind`:** (First property) Discriminator identifying the payload type.
- **`etag`:** Concurrency / version token for conditional requests.
- **`items`:** (Last property) The primary collection array.

### C. Paging Properties (inside `data`)

Standard pagination fields for collections:

- **`currentItemCount`:** Integer count of elements in this payload's `items`.
- **`itemsPerPage`:** Integer page size requested or delivered.
- **`startIndex`:** 1-based index of the first item in `items`.
- **`totalItems`:** Total number of items across all pages.
- **`pageIndex`:** 1-based page number (`floor(startIndex / itemsPerPage) + 1`).
- **`totalPages`:** Total page count (`ceiling(totalItems / itemsPerPage)`).
- **Navigation Links:** `"nextLink"`, `"previousLink"`, `"selfLink"`, and
  `"pagingLinkTemplate"`.

### D. The `error` Object

Error responses return a structured error envelope:

```json
{
  "apiVersion": "2.0",
  "error": {
    "code": 404,
    "message": "Resource Not Found",
    "errors": [
      {
        "domain": "Storage",
        "reason": "FileNotFound",
        "message": "The requested image does not exist."
      }
    ]
  }
}
```

- **`code`:** HTTP status code integer (`404`, `400`, `500`).
- **`message`:** Human-readable summary of the error.
- **`errors`:** Array of fine-grained error details, each containing:
  - `domain`: Service or subsystem identifier raising the error.
  - `reason`: Machine-readable error code.
  - `message`: Detailed description.
  - Optional `location`, `locationType`, `extendedHelp`, `sendReport`.

---

## 6. Companion Guides & Cross-References

- **TypeScript Type System:** Consult `typescript-guide` to model JSON API
  envelopes using `interface ApiResponse<T>` and `interface ApiError`, ensuring
  all payloads are typed and validated at runtime.
- **Web & HTML Integration:** Consult `html-css-guide` when serializing JSON
  into HTML data attributes (`data-options='{...}'`) or embedding configuration
  in `<script type="application/json">` blocks.
