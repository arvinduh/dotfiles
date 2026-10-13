---
name: typescript-guide
description: >-
  Personal TypeScript engineering standard — the Google TypeScript Style Guide
  with personal engineering directives (2-space indent, 80 columns, strict
  types, named exports only, interface over type, narrow try-catch scoping,
  immutable primitives), enforced by Biome/Prettier, ESLint, and tsc.
  Complements html-css-guide and json-guide. Use whenever writing, editing,
  reviewing, or refactoring TypeScript.
---

# TypeScript Engineering Guide

The standard builds on the [Google TypeScript Style Guide][google-ts]. Enforce
through tools wherever possible. Prose covers architectural boundaries,
computational efficiency, error invariants, and language idioms.

[google-ts]: https://google.github.io/styleguide/tsguide.html

## 0. Precedence

This guide is the default. A repository's own `AGENTS.md`/`CLAUDE.md`,
`tsconfig.json`, `biome.json`, `.eslintrc*`, `package.json`, or `.prettierrc`
wins where it says something different. Never "fix" a repo toward this guide as
a side effect of other work.

Where this guide and the Google TypeScript Style Guide differ, **this guide's
rules take precedence**.

## 1. Toolchain & Enforcement

| Tool / Layer         | Covers                                              |
| -------------------- | --------------------------------------------------- |
| `biome` / `prettier` | layout: 2-space indent, 80 columns, single quotes   |
| `biome` / `eslint`   | import rules, bug idioms, naming, dead code, no-var |
| `tsc --noEmit`       | static types, strict null checks, no implicit any   |

- Never reason about layout; run the formatter.
- Silence a linter rule only on the exact line with an explanatory comment:
  `// eslint-disable-next-line <RULE> -- <why>`.
- Never use `@ts-ignore` or `@ts-nocheck`. Use `@ts-expect-error -- <why>`
  strictly in unit tests when verifying runtime rejection of bad inputs.
- Unused parameters: ignore via destructuring commas `const [, b] = tuple;` or
  omit the parameter if the signature permits. Never use `_` or `unused`
  prefixes.

Gate: `biome check . && tsc --noEmit` (or repo equivalent lint + typecheck).

## 2. Core Deviations & Baseline Rules

- **Indentation:** 2 spaces, never tabs.
- **Line Width:** 80 columns maximum.
- **Semicolons:** Semicolons are mandatory. Never rely on Automatic Semicolon
  Insertion (ASI).
- **String Quotes:** Single quotes (`'...'`) for TypeScript string literals;
  template literals (`` `...` ``) for interpolation and multi-line strings.
- **Exports:** **Named exports only.** Never use `export default`.
- **Contracts:** **Prefer `interface` over `type` literal aliases** for object
  shapes.

## 3. Architecture & Operational Invariants

### A. Imports, Exports & Module Boundaries

- **Named exports everywhere:** `export class UserRepo { ... }` or
  `export function parseConfig() { ... }`.
  - Never use default exports (`export default`). Default exports prevent
    canonical symbol renaming, hinder refactoring, and encourage monolithic
    container classes.
- **No container classes for namespacing:** Do not declare classes with only
  static methods or constants. Export module-level constants and functions
  directly from the file.
- **No mutable exports:** Never write `export let foo = 1`. Exports must be
  immutable. If a mutable value must be exposed, export an explicit accessor:
  `export function getFoo(): number`.
- **Import styles:**
  - Use named imports (`import {foo} from './foo';`) for common or clear
    symbols.
  - Use namespace imports (`import * as storage from './storage';`) when
    consuming large APIs or when symbols share generic names (e.g., `Model`).
  - Use relative paths (`./foo`, `../bar`) within the same package. Limit parent
    traversals (`../../../`).
  - Import types explicitly: use `import type {User} from './user';` or
    `import {type User, fetchUser} from './user';` to support type-only elision
    under `isolatedModules`. Re-export types with `export type`.
- **Disallowed constructs:** Never use TypeScript namespaces (`namespace Foo`),
  triple-slash references (`/// <reference ... />`), or CommonJS `require()`.

### B. Functions, Closures & `this` Invariants

- **Top-level functions:** Prefer function declarations
  (`function computeTotal(): number`) over arrow function variable assignments
  (`const computeTotal = () => ...`).
- **Callbacks & nested functions:** Use arrow functions (`() => {}`). Never use
  legacy `function` expressions (`function() {}`), which risk unbound `this`.
- **Arrow function bodies:**
  - Use concise expression bodies only when the return value is actively
    consumed.
  - If the return value is unused, use a braced block body (`{ fn(); }`) or the
    `void` operator (`v => void log(v)`) to prevent accidental leaks.
- **Never rebind `this`:** Avoid `.bind(this)`, `const self = this`, or
  manipulating execution context. Rely on lexical scoping in arrow functions.
- **Explicit callback forwarding:** When passing callbacks to higher-order
  functions, wrap calls in arrow functions if the callee accepts optional
  parameters (e.g. `items.map(n => parseInt(n))` instead of
  `items.map(parseInt)` to prevent index injection into radix).
- **Event handlers & arrow properties:** Avoid arrow functions as class
  properties except when an event listener must be uninstalled via
  `removeEventListener` (which requires a stable reference).
- **Default parameters:** Parameter defaults must be simple, pure, and free of
  observable side effects. Prefer object destructuring when more than two
  optional parameters exist.
- **Rest parameters:** Always use `...args` instead of the legacy `arguments`
  object.

### C. Classes & Object-Oriented Design

- **Constructor calls:** Always use parentheses, even without arguments:
  `new User()`, never `new User`.
- **Parameter properties:** Use constructor parameter properties
  (`constructor(private readonly client: Client) {}`) to eliminate redundant
  field declaration and plumbing.
- **Field initializers:** Initialize non-parameter fields inline at declaration
  rather than in the constructor body.
- **No private identifiers (`#field`):** Use TypeScript's `private` visibility
  modifier. Private identifiers (`#field`) add runtime overhead and emit
  penalties when down-leveling.
- **Immutability:** Mark all properties that are not reassigned with `readonly`.
- **Properties vs. Getters/Setters:**
  - Getters must be pure functions with zero observable side effects.
  - Never define pass-through getters/setters that merely read/write a private
    variable without logic; make the field public (or `readonly`) directly.
  - Use explicit methods (`fetchData()`, `updateState()`) when access incurs
    I/O, cache invalidation, or non-trivial computation.
- **Static members:** Avoid private static methods (use module-local private
  functions instead). Never access `this` within a static method. Do not rely on
  dynamic dispatch across static inheritance.
- **Prototypes:** Never manipulate prototypes directly or patch built-in
  objects. `toString()` overrides must never fail or produce side effects.

### D. Control Flow, Guard Clauses & Strict YAGNI

- **Flat control flow:** Prioritize early returns, guard clauses, and flat
  branching to keep the primary path at minimal indentation.
- **Braced control blocks:** Always enclose bodies of `if`, `else`, `for`,
  `while` in braces. Exception: a single-line `if` statement may omit braces
  only if it fits entirely on one 80-column line without an `else`.
- **No assignment in control statements:** Never write `if (x = getResult())`.
  Perform assignment on the preceding line.
- **Iteration:**
  - Iterate arrays with `for (const item of array)`.
  - Iterate objects with `for (const [key, val] of Object.entries(obj))`.
  - Never use unfiltered `for (const k in obj)` (iterates prototype chain) and
    never use `for..in` on arrays (yields string indices).
- **Switch statements:** Every `switch` must have a `default:` case as its final
  clause. Non-empty cases must terminate with `break`, `return`, or `throw` (no
  implicit fallthrough).
- **Strict equality:** Always use `===` and `!==`. The only exception is
  `val == null` (which conveniently checks both `null` and `undefined`).
- **Strict YAGNI:** Implement only what active callers consume right now. No
  speculative abstractions, wrappers, or unused utility functions.

### E. Error Handling & Exceptions

- **Throw Error instances only:** Always throw `new Error(...)` or a custom
  class extending `Error`. Never throw strings, numbers, or raw objects.
- **Custom errors:** Subclass `Error` (or a base domain error), set
  `this.name = 'CustomError'`, and suffix the class name with `Error`.
- **Catch typing:** Always type catch variables as `unknown`:
  `catch (err: unknown)`. Narrow with `if (err instanceof Error)` before
  accessing `.message` or `.stack`.
- **No silent catch blocks:** Empty catch blocks are prohibited unless justified
  with an explicit comment explaining why ignoring the error is safe.
- **Focused try blocks:** Keep `try` blocks narrowly scoped around the exact
  expression expected to throw, rather than wrapping entire functions.

### F. Type System Invariants & Strictness

- **Type inference:** Omit type annotations for trivially inferred values
  (`const count = 10;`, `const name = 'alice';`). Explicitly annotate generic
  instantiations with empty containers (`new Set<string>()`, `new Map<K, V>()`).
- **Prefer interfaces:** Use `interface` for object structures and API
  contracts. Reserve `type` for unions, primitives, tuples, and mapped types.
- **Structural typing:** Annotate object literals at declaration
  (`const config: Config = { ... };`) instead of asserting (`... as Config`),
  ensuring the compiler catches misspelled or missing fields immediately.
- **Undefined vs. Null:**
  - Do not define union aliases containing nullability (e.g., avoid
    `type Id = string | null`; use `Id | null` at usage sites).
  - Prefer optional properties (`timeoutMs?: number`) over explicit union with
    undefined (`timeoutMs: number | undefined`).
- **Array types:** Use `T[]` and `readonly T[]` for simple alphanumeric types.
  Use `Array<T>` for complex types (`Array<string | number>`).
- **Indexable types:** Prefer ES6 `Map` and `Set` over `{ [key: string]: T }`.
  When an object map is required, use `Record<string, T>` with explicit keys.
- **Avoid `any`:**
  - Use `unknown` when a type cannot be statically known, and narrow with type
    guards.
  - Never use the empty interface `{}` as an arbitrary type; use `unknown`,
    `object`, or `Record<string, unknown>`.
  - Suppress `any` warnings strictly in test mocks with an explanatory comment.
- **Type assertions:**
  - Treat `as Target` and non-null assertions (`!`) as unsafe. Prefer runtime
    checks (`instanceof`, narrowing).
  - Never use angle-bracket assertion syntax (`<Target>val`).
  - Double assertions must route through `unknown`:
    `(val as unknown as Target)`.
- **Avoid return-type-only generics:** Generics must appear in parameter types
  to allow inference.

### G. Literals, Coercion & Arithmetic

- **Number parsing:** Parse numeric strings using `Number(str)` and verify with
  `Number.isFinite()`. Use `Math.trunc()` or `Math.floor()` for integers.
  - Never use unary plus (`+str`) for coercion.
  - Never use `parseInt(str)` or `parseFloat(str)` for base-10 strings (they
    silently ignore invalid trailing characters).
- **Boolean conversion:** Use `Boolean(x)` or `!!x`.
  - **Never convert enums to booleans** with `Boolean()` or `!!` (enum value 0
    is falsy while other members are truthy). Always compare explicitly:
    `status !== Status.NONE`.
- **No primitive wrapper constructors:** Never instantiate `new String()`,
  `new Number()`, or `new Boolean()`. Call them without `new` for conversion.

### H. Naming Conventions

- `UpperCamelCase`: Classes, interfaces, types, enums, decorators, type
  parameters (`T`, `ItemT`), TSX component functions.
- `lowerCamelCase`: Variables, parameters, functions, methods, properties,
  module namespace aliases.
- `CONSTANT_CASE`: Module-level immutable constants, static readonly class
  constants, enum values.
- **No underscores:** Never prefix or suffix identifiers with `_` (e.g. no
  `_privateField`, no `_unusedParam`).
- **Acronyms:** Treat acronyms as regular words (`loadHttpUrl`, `userId`,
  `xmlParser`), except where required by platform APIs (`XMLHttpRequest`).
- **Filenames:** Use `lower_with_under.ts` (or repo-consistent kebab-case).
  Never use uppercase letters or spaces in file names.

### I. Documentation & JSDoc Standards

- **JSDoc (`/** ... \*/`) vs. Comments (`//`):\*\*
  - Use `/** ... */` for exported declarations, public interfaces, and methods.
  - Use `//` for internal implementation logic.
- **High-signal documentation:** Do not write tautological JSDoc that merely
  repeats names and types. Explain _intent_, _preconditions_, and _units_.
- **No redundant types in JSDoc:** Never include `@param {string} foo` or
  `@type` tags in TypeScript; types belong exclusively in TypeScript syntax.
- **Decorators and JSDoc:** JSDoc blocks must precede decorators directly.
- **TODO comments:** Format as `// TODO: <issue-link> - <explanation>`.

---

## 4. Companion Guides & Cross-References

TypeScript code operating in web or network contexts must integrate cleanly with
companion standards:

- **Markup & Styling:** Consult the `html-css-guide` for HTML semantics, DOM
  attribute rules, accessible element hierarchy, and CSS class naming.
  TypeScript manages only behavior, typed DOM listeners, and state.
- **Data Serialization & API Contracts:** Consult the `json-guide` for payload
  formatting, camelCase property standards, RFC 3339 timestamps, and standard
  `{ apiVersion, data, error }` envelopes. In TypeScript, represent these
  contracts with explicit `interface` definitions and runtime validation.
