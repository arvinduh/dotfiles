---
name: html-css-guide
description: >-
  Personal HTML & CSS engineering standard — the Google HTML/CSS Style Guide
  with personal engineering directives (2-space indent, 80 columns, strict
  separation of concerns, semantic HTML5, modern CSS without !important or ID
  selectors, HTTPS everywhere), enforced by Prettier/Biome and Stylelint.
  Complements typescript-guide and json-guide. Use whenever writing, editing,
  reviewing, or refactoring HTML, templates, JSX/TSX markup, CSS, Sass, or
  styling.
---

# HTML & CSS Engineering Guide

The standard builds on the [Google HTML/CSS Style Guide][google-html-css].
Enforce through tools wherever possible. Prose covers architectural boundaries,
accessibility, semantics, and cascade ergonomics.

[google-html-css]: https://google.github.io/styleguide/htmlcssguide.html

## 0. Precedence

This guide is the default. A repository's own `AGENTS.md`/`CLAUDE.md`,
`.stylelintrc*`, `.prettierrc`, `biome.json`, or `package.json` wins where it
says something different. Never "fix" a repo toward this guide as a side effect
of other work.

Where this guide and the Google HTML/CSS Style Guide differ, **this guide's
rules take precedence**.

## 1. Toolchain & Enforcement

| Tool / Layer         | Covers                                               |
| -------------------- | ---------------------------------------------------- |
| `biome` / `prettier` | layout: 2-space indent, 80 columns, lowercase syntax |
| `stylelint`          | selector rules, no !important, property units, order |
| HTML Validator / W3C | semantic validation, no-quirks doctype, closed tags  |

- Run the formatter automatically; never reason about indentation or spacing.
- Silence a linter rule only on the exact line with an explanatory comment:
  `/* stylelint-disable-next-line <RULE> -- <why> */`.

Gate: `biome check .` / `prettier --check . && stylelint "**/*.css"`.

## 2. Core Baseline Rules

- **Indentation:** 2 spaces, never tabs.
- **Line Width:** 80 columns maximum. Wrap long attributes or declarations
  cleanly onto indented continuation lines.
- **Protocol:** Always use HTTPS (`https:`) for all embedded resources, scripts,
  fonts, and stylesheets. Never use HTTP or protocol-relative URLs.
- **Character Encoding:** UTF-8 without BOM. Declare `<meta charset="utf-8">` in
  HTML templates.
- **Lowercase Syntax:** All HTML elements, attributes, CSS selectors,
  properties, and hex color values must be lowercase.

## 3. HTML Architectural & Structural Invariants

### A. Document Structure & Validity

- **Doctype:** Always begin with `<!doctype html>` to ensure standard no-quirks
  rendering across browsers.
- **Validity:** HTML must be valid HTML5. Verify templates and output using
  automated linters or W3C validation.
- **Block Formatting:** Place every block, list, and table element on its own
  line, and indent all child elements.
- **Attribute Quotes:** Always enclose attribute values in double quotation
  marks (`<a class="nav-link">`).

### B. Semantics & Accessibility

- **Semantic Elements:** Use native HTML elements for their designated purpose:
  - `<button>` for actions, triggers, and state changes.
  - `<a>` with a valid `href` for navigation. Never `<div onclick="...">` or
    `<a href="javascript:void(0)">`.
  - Heading hierarchy (`<h1>` through `<h6>`) reflecting outline structure.
  - Content containers: `<main>`, `<nav>`, `<article>`, `<section>`, `<aside>`,
    `<header>`, `<footer>`.
- **Media Fallbacks:**
  - All `<img>` tags must include an `alt` attribute. Use descriptive text for
    informative images; use empty `alt=""` for purely decorative images.
  - Provide captions and transcripts for `<video>` and `<audio>` elements.
- **ARIA as Augmentation:** Use native elements first. Add ARIA roles and
  attributes (`aria-expanded`, `aria-label`) only when native HTML cannot convey
  dynamic or custom widget state.

### C. Separation of Concerns

- **Zero Inline Styles:** Never use the `style="..."` attribute or obsolete
  presentational elements (`<center>`, `<u>`, `<font>`). Keep all styling in
  external or scoped stylesheets.
- **Zero Inline Scripts:** Never attach inline event handlers (`onclick`,
  `onload`). All behavior belongs in TypeScript/JavaScript modules.
- **Type Attributes Omitted:** Omit redundant MIME types for standards-based
  assets:
  - `<link rel="stylesheet" href="...">` (omit `type="text/css"`).
  - `<script src="...">` (omit `type="text/javascript"`).

### D. IDs, Classes & Entity References

- **Prefer Classes over IDs:** Use classes for styling and `data-*` attributes
  for script bindings.
- **Hyphenated IDs:** Where an `id` is required (e.g. for accessibility links
  like `aria-labelledby` or `<label for="...">`), always include a hyphen
  (`id="user-profile"`). Browsers expose IDs as global properties on `window`;
  hyphenated IDs prevent collisions with JavaScript identifiers.
- **No Entity References:** Use UTF-8 characters directly (e.g. `“`, `”`, `€`,
  `—`) instead of entity references (`&ldquo;`, `&eur;`, `&mdash;`). Reserve
  entities strictly for syntax characters: `&lt;` (`<`) and `&amp;` (`&`).

---

## 4. CSS Architectural & Styling Invariants

### A. Class Naming & Selectors

- **Functional Kebab-Case:** Name classes using descriptive, kebab-case words
  that reflect the purpose of the element (`.nav-bar`, `.author-bio`,
  `.gallery`).
- **Never Use Presentational Names:** Avoid naming classes by appearance (e.g.,
  avoid `.green-button`, `.bold-text`, `.float-left`).
- **Avoid Qualified Selectors:** Do not qualify classes with tag names. Use
  `.example`, never `div.example` or `ul.nav`.
- **Zero ID Selectors:** Never style using ID selectors (`#header`). IDs have
  excessive specificity that destroys modularity.
- **Avoid `!important`:** Do not use `!important` declarations. Resolve style
  overrides through selector specificity, cascade order, or CSS `@layer`.

### B. Property Declarations & Units

- **Shorthand Properties:** Use shorthand properties where possible (`font`,
  `margin`, `padding`, `border`).
- **Unitless Zeros:** Omit unit suffixes after zero values
  (`margin: 0; padding: 0;`), unless required by CSS syntax (such as
  `flex: 0px`).
- **Leading Zeros:** Always include leading zeros for fractional lengths
  (`font-size: 0.8em;`, never `.8em`).
- **Hex Colors:** Use 3-character hex shorthand when digits repeat (`#ebc`
  instead of `#eebbcc`, `#fff` instead of `#ffffff`). Keep hex characters
  lowercase.
- **No CSS Hacks:** Avoid user-agent sniffing, proprietary filters, or syntax
  hacks. Use standards-based responsive design and `@supports` queries.

### C. CSS Formatting & Layout

- **Spacing & Braces:** Place a single space between the selector and the
  opening brace (`.card {`).
- **Colons & Semicolons:** Follow every property colon with a single space
  (`display: block;`). Terminate every declaration with a semicolon.
- **Rule Separation:** Separate rules with a single blank line.
- **Strings & Quotes:** Use single quotation marks (`'...'`) for attribute
  selectors and font families (`font-family: 'Open Sans', sans-serif;`). Omit
  quotes inside `url()` (`background: url(https://example.com/bg.png)`).

---

## 5. Companion Guides & Cross-References

- **Behavior & Interactive Logic:** Consult `typescript-guide` for managing DOM
  events, typed custom element lifecycle, accessibility states, and reactive
  templates.
- **Configuration & Design Tokens:** Consult `json-guide` for defining theme
  tokens, typography scales, or structured data embedded in HTML
  `<script type="application/json">` blocks.
