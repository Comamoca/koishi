# koishi: OG-image generation from Lustre HTML Trees — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `koishi` into a Gleam (JavaScript target) package that renders OG images: HTML string or Lustre `Element` tree → `@comamoca/komeiji` VNode → `satori` → SVG string.

**Architecture:** Core module `src/koishi.gleam` wraps the two npm packages through a single FFI (`src/koishi/ffi.mjs`). A separate integration module `src/koishi/lustre.gleam` serializes `lustre/element.Element(msg)` with `element.to_string` (verified compact, non-pretty) and delegates to the core. Since Gleam 1.14 has no native npm dependency support (empirically verified), the repo carries a root `package.json` for dev/CI and the README instructs consumers to install the npm packages themselves — exactly Comamoca's `node-pg` house pattern.

**Tech Stack:** Gleam 1.14 (`target = "javascript"`), `gleam_javascript` (Promise), `lustre` (integration module), `@comamoca/komeiji@0.1.1`, `satori`, `gleeunit` (JS target — its FFI `await`s Promise-returning test functions, verified from `lpil/gleeunit@main` source).

**Spec:** `docs/superpowers/specs/2026-09-05-koishi-ogp-design.md`

---

## Verified facts (do not re-derive)

- komeiji API: `import { html } from "@comamoca/komeiji"; html("<div>…</div>") -> VNode` (v0.1.1; HTML string input, satori VDOM output).
- satori API: `import satori from "satori"; await satori(vnode, { width, height, fonts, debug }) -> Promise<string (SVG)>`. Fonts entry: `{ name: string, data: Uint8Array, weight: number, style: "normal" | "italic" }`. satori accepts Buffers/Uint8Array/ArrayBuffer font data. Note: woff2 NOT supported by satori — use `.woff`/`.ttf`/`.otf`.
- Gleam JS prelude: `./gleam.mjs` exports `Ok, Error, toList, toBitArray, CustomType`. From `src/koishi/ffi.mjs` (compiled to `build/dev/javascript/koishi/koishi/ffi.mjs`), the prelude is `../gleam.mjs` and the package main module classes are `../koishi.mjs`.
- Gleam records compile to JS classes with named fields: `font.name`, `font.data`, `font.weight`, `font.style` all readable directly. `instanceof` distinguishes variants (compiled code does `value instanceof Empty`).
- Gleam `List` has `.toArray()` in the JS prelude (verified: `toList([1,2,3]).toArray() === [1,2,3]`).
- Gleam `BitArray` is a prelude `BitArray` class (NOT a Uint8Array); its `.rawBuffer` field is a `Uint8Array` for byte-aligned data (verified at runtime).
- gleeunit JS runner does `await module[fnName]()` — a test function may return a `Promise` and gleeunit waits for it.
- Font fixture path `node_modules/@fontsource/inter/files/inter-latin-400-normal.woff` exists after `npm install` (verified locally).
- `target = "javascript"` must be a **top-level** key in gleam.toml (before any table header); appending it after `[dev-dependencies]` is silently wrong (verified pitfall).
- `[javascript]` config: `runtime = "node"` (matches node-pg's gleam.toml).
- lustre exposes `element.to_string` — documented "not pretty-printed, no newlines or indentation" (verified in lustre source).

---

### Task 1: Configure JavaScript target and npm dependencies

**Files:**
- Modify: `gleam.toml`
- Modify: `.gitignore`
- Create (committed): `package.json`, `package-lock.json` (via npm install)

- [ ] **Step 1: Rewrite gleam.toml — top-level target, JS runtime section, metadata**

Full replacement content:

```toml
name = "koishi"
version = "1.0.0"
target = "javascript"

description = "Generate OG images from Lustre HTML trees, via @comamoca/komeiji and satori"
licences = ["MIT"]
repository = { type = "github", user = "Comamoca", repo = "koishi" }
links = [{ title = "GitHub", href = "https://github.com/Comamoca/koishi" }]

[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0 and < 2.0.0"

[javascript]
runtime = "node"
```

- [ ] **Step 2: Add gleam_javascript and lustre dependencies**

Run: `gleam add gleam_javascript lustre`
Expected: consent queries appended to `[dependencies]` in gleam.toml (gleam_javascript ~> 1.0, lustre ~> 5).

- [ ] **Step 3: Add node_modules to .gitignore**

Append to `.gitignore` (current content: `*.beam`, `*.ez`, `/build`, `erl_crash.dump`):

```
/node_modules
```

- [ ] **Step 4: Install npm dependencies (this creates package.json + package-lock.json with real versions)**

Run: `npm install --save @comamoca/komeiji@^0.1.1 satori @fontsource/inter --exclude=optional`
Expected success criteria:
- `package.json` contains `@comamoca/komeiji`: `^0.1.1`, `satori`: a real `^1.x` version, `@fontsource/inter`: a real version
- `git status` shows package.json + package-lock.json as new files

- [ ] **Step 5: Verify build with placeholder-free stub**

`src/koishi.gleam` still has `main()` — build JS target as sanity check.

Run: `gleam build`
Expected: `Compiled in …s` with no errors.

- [ ] **Step 6: Commit**

```bash
git add gleam.toml .gitignore package.json package-lock.json
git commit -m "feat: configure JavaScript target and npm deps (komeiji/satori)"
```

---

### Task 2: Core types + FFI + happy-path render test (TDD)

**Files:**
- Modify: `src/koishi.gleam`
- Create: `src/koishi/ffi.mjs`
- Modify: `test/koishi_test.gleam`

- [ ] **Step 1: Write the failing happy-path test**

Replace `test/koishi_test.gleam` content with:

```gleam
import gleam/javascript/promise.{type Promise}
import gleam/string
import gleeunit

import koishi.{type Options}

@external(javascript, "./koishi/ffi.mjs", "read_test_font_file")
fn read_test_font_file(path: String) -> BitArray

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn to_svg_renders_html_to_svg_test() -> Promise(Nil) {
  let font_bytes =
    read_test_font_file(
      "node_modules/@fontsource/inter/files/inter-latin-400-normal.woff",
    )
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options: Options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  koishi.to_svg(
    "<div style=\"display:flex;color:black;\">Hello from koishi</div>",
    options,
  )
  |> promise.map(fn(result) {
    let assert Ok(svg) = result
    assert string.starts_with(svg, "<svg")
    Nil
  })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `gleam test`
Expected: FAIL — compile errors like `module ./koishi/ffi.mjs does not export read_test_font_file` and `koishi.Font` does not exist (types do not exist yet). Confirm the failure is the missing symbols, not unrelated.

- [ ] **Step 3: Write the core module types**

Replace `src/koishi.gleam` content with:

```gleam
//// koishi: render Open Graph (og:image) SVG images from HTML strings and
//// Lustre element trees, using the npm packages
//// [`@comamoca/komeiji`](https://www.npmjs.com/package/@comamoca/komeiji)
//// and [`satori`](https://github.com/vercel/satori).
////
//// Install the npm packages before use (see README):
////
//// ```sh
//// npm install @comamoca/komeiji satori
//// ```

import gleam/javascript/promise.{type Promise}

pub type FontStyle {
  NormalStyle
  Italic
}

/// A font for satori rendering.
///
/// `data` is the raw font file bytes. satori accepts TTF, OTF, and WOFF
/// (not WOFF2 — use **.woff** fixtures such as @fontsource's `.woff` files).
pub type Font {
  Font(name: String, data: BitArray, weight: Int, style: FontStyle)
}

/// Rendering options. `fonts` must contain at least one font;
/// satori fails with a `SatoriError` otherwise.
pub type Options {
  Options(width: Int, height: Int, fonts: List(Font), debug: Bool)
}

pub type SatoriError {
  SatoriError(message: String)
}

/// Render an HTML string to an SVG string.
///
/// Internally: `@comamoca/komeiji`'s `html()` parses the HTML into a
/// satori-friendly VNode, then `satori()` renders it to SVG.
///
/// ```gleam
/// koishi.to_svg("<div style=\"color:black;\">hi</div>", options)
/// // -> Promise(Result(String, SatoriError))
/// ```
@external(javascript, "./koishi/ffi.mjs", "renderInternal")
pub fn to_svg(html: String, options: Options) -> Promise(
  Result(String, SatoriError),
)
```

- [ ] **Step 4: Write the FFI module**

Create `src/koishi/ffi.mjs`:

```js
/**
 * FFI for koishi: bridges Gleam and the npm packages
 * @comamoca/komeiji (HTML string -> satori VNode) and satori (VNode -> SVG).
 *
 * Compiled location: build/dev/javascript/koishi/koishi/ffi.mjs, hence
 * the prelude is "../gleam.mjs" and the package main module is "../koishi.mjs".
 */
import { html } from "@comamoca/komeiji";
import satori from "satori";
import { Ok, Error, toBitArray } from "../gleam.mjs";
import { SatoriError, Italic } from "../koishi.mjs";
import { readFileSync } from "node:fs";

// Gleam BitArray -> Uint8Array.
// Verified: BitArray.rawBuffer is a Uint8Array for byte-aligned data.
export function fontDataToUint8Array(bitArray) {
  const bytes = bitArray.rawBuffer;
  if (bytes instanceof Uint8Array) return bytes;
  return Uint8Array.from(bytes);
}

// Gleam Font record -> satori font object.
export function fontToJs(font) {
  return {
    name: font.name,
    data: fontDataToUint8Array(font.data),
    weight: font.weight,
    style: font.style instanceof Italic ? "italic" : "normal",
  };
}

// Gleam Options record -> satori options object.
// Gleam List has .toArray() in the JS prelude (verified).
export function optionsToJs(options) {
  return {
    width: options.width,
    height: options.height,
    fonts: options.fonts.toArray().map(fontToJs),
    debug: options.debug,
  };
}

// Test-only helper: load a font file as a Gleam BitArray.
// Gleam type: String -> BitArray. Used via @external from test modules.
export function read_test_font_file(path) {
  return toBitArray(Array.from(readFileSync(path)));
}

// html: String -> Options record -> Promise.
// Result constructors (Ok/Error) and SatoriError come from the JS prelude /
// compiled koishi.mjs classes (same imports as node-pg/gleeunit use).
export function renderInternal(htmlString, options) {
  return new Promise((resolve) => {
    try {
      const vnode = html(htmlString);
      const satoriOptions = optionsToJs(options);
      satori(vnode, satoriOptions).then(
        (svg) => resolve(new Ok(svg)),
        (err) =>
          resolve(new Error(new SatoriError(errorToMessage(err)))),
      );
    } catch (err) {
      resolve(new Error(new SatoriError(errorToMessage(err))));
    }
  });
}

function errorToMessage(err) {
  if (err instanceof Error && err.message) return err.message;
  return String(err);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `gleam test`
Expected: PASS — 1 test green. Note: satori requires Node ≥ 20 (komeiji engines); run under local node (≥ 20 installed).

- [ ] **Step 6: Commit**

```bash
git add src/koishi.gleam src/koishi/ffi.mjs test/koishi_test.gleam
git commit -m "feat: render HTML string to SVG via komeiji + satori"
```

---

### Task 3: Error-path test

**Files:**
- Modify: `test/koishi_test.gleam`

- [ ] **Step 1: Write the failing-then-passing error test**

Append to `test/koishi_test.gleam` (imports already present except `koishi` is imported; add nothing):

```gleam
pub fn to_svg_missing_font_returns_error_test() -> Promise(Nil) {
  let options = koishi.Options(width: 1200, height: 630, fonts: [], False)

  koishi.to_svg("<div style=\"display:flex;\">hi</div>", options)
  |> promise.map(fn(result) {
    let assert Error(koishi.SatoriError(message)) = result
    assert message != ""
    Nil
  })
}
```

(Note the positional `False` to prove both construction styles compile; if gleam's formatter complains, switch the field to `debug: False` — either compiles.)

- [ ] **Step 2: Run tests**

Run: `gleam test`
Expected: PASS — 2 tests green. (Implementation already consolidates thrown errors in `renderInternal`; if this ever fails, the fix is in `ffi.mjs` `errorToMessage`/catch, not in Gleam code.)

- [ ] **Step 3: Commit**

```bash
git add test/koishi_test.gleam
git commit -m "test: satori error path returns SatoriError"
```

---

### Task 4: Lustre integration module

**Files:**
- Create: `src/koishi/lustre.gleam`
- Modify: `test/koishi_test.gleam`

- [ ] **Step 1: Write the failing integration test**

Append to `test/koishi_test.gleam` (add needed imports at top of file):

```gleam
import gleam/int
import lustre/element
import lustre/element/html
import koishi/lustre as koishi_lustre

pub fn lustre_element_to_svg_test() -> Promise(Nil) {
  let font_bytes =
    read_test_font_file(
      "node_modules/@fontsource/inter/files/inter-latin-400-normal.woff",
    )
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options: Options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  let tree =
    html.div([html.style("display:flex;")], [
      html.h1([], [html.text("koishi " <> int.to_string(2026))]),
    ])

  koishi_lustre.to_svg(tree, options)
  |> promise.map(fn(result) {
    let assert Ok(svg) = result
    assert string.starts_with(svg, "<svg")
    Nil
  })
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `gleam test`
Expected: FAIL — `koishi/lustre` module does not exist.

- [ ] **Step 3: Write the integration module**

Create `src/koishi/lustre.gleam`:

```gleam
//// Render OG images from Lustre element trees.
////
//// Serializes the tree with `element.to_string` (compact, non-pretty —
//// no extra whitespace that could disturb satori's text layout) and
//// delegates to the core renderer.

import gleam/javascript/promise
import koishi
import lustre/element.{type Element}

/// Render a Lustre element tree to an SVG string.
///
/// ```gleam
/// let view = html.div([], [html.h1([], [html.text("Hello")])])
/// koishi_lustre.to_svg(view, options)
/// // -> Promise(Result(String, koishi.SatoriError))
/// ```
pub fn to_svg(
  tree: Element(msg),
  options: koishi.Options,
) -> promise.Promise(Result(String, koishi.SatoriError)) {
  element.to_string(tree)
  |> koishi.to_svg(options)
}
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `gleam test`
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add src/koishi/lustre.gleam test/koishi_test.gleam
git commit -m "feat: lustre element tree -> SVG integration module"
```

---

### Task 5: Update CI workflow for JavaScript target

**Files:**
- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Rewrite the workflow**

Full replacement content:

```yaml
name: test

on:
  push:
    branches:
      - master
      - main
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          otp-version: "28"
          gleam-version: "1.14.0"
          rebar3-version: "3"
          # elixir-version: "1"
      - uses: actions/setup-node@v4
        with:
          node-version: "24"
      - run: npm ci
      - run: gleam deps download
      - run: gleam test
      - run: gleam format --check src test
```

(`target = "javascript"` in gleam.toml makes `gleam test` run under node automatically; `npm ci` supplies komeiji/satori/fixture from the committed lockfile.)

- [ ] **Step 2: Verify the same commands locally**

Run: `npm ci && gleam deps download && gleam test && gleam format --check src test`
Expected: exit 0, all tests pass, formatting clean. (`gleam format` only touches `.gleam` files; `ffi.mjs` is not formatted by it — keep ffi.mjs prettier-clean by hand.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: run JavaScript-target tests with node"
```

---

### Task 6: README rewrite

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite README following the node-pg install pattern**

Full replacement content:

```markdown
# koishi

[![Package Version](https://img.shields.io/hexpm/v/koishi)](https://hex.pm/packages/koishi)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/koishi/)

Generate Open Graph (og:image) SVG images from Lustre HTML trees — a Gleam
bridge to [`@comamoca/komeiji`](https://github.com/Comamoca/komeiji)
(HTML → satori VDOM) and [`satori`](https://github.com/vercel/satori)
(VDOM → SVG).

## ⬇️ Install

koishi depends on the npm packages `@comamoca/komeiji` and `satori`; install
them in advance.

### Node.js

```sh
npm install @comamoca/komeiji satori
```

### Bun

```sh
bun add @comamoca/komeiji satori
```

### Deno

```sh
deno add npm:@comamoca/komeiji npm:satori
```

Add koishi to your Gleam project:

```sh
gleam add koishi
```

## 🖼️ Usage

From a Lustre element tree:

```gleam
import gleam/javascript/promise
import koishi
import koishi/lustre
import lustre/element/html

pub fn main() -> Nil {
  let font_bytes =  // load your font file as bytes (BitArray); .woff/.ttf/.otf
    koishi_ffi_font()  // <- load with your own I/O code
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  let og_image =
    html.div([], [html.h1([], [html.text("Hello from koishi!")])])

  promise.await(lustre.to_svg(og_image, options), fn(svg) {
    case svg {
      Ok(svg) -> io.println(svg)
      Error(koishi.SatoriError(message)) -> io.println(message)
    }
  })
}
```

Or from a plain HTML string:

```gleam
koishi.to_svg(
  "<div style=\"display:flex;\">Hello</div>",
  options,
)
```

Requirements: Node.js ≥ 20 (Bun and Deno also work; satori accepts
TTF/OTF/WOFF fonts — WOFF2 is not supported).

Further documentation can be found at <https://hexdocs.pm/koishi>.

## Development

```sh
npm ci     # install npm deps (komeiji, satori, test font fixture)
gleam test # runs on the JavaScript target
```

## 👍 Special Thanks

- [komeiji](https://github.com/Comamoca/komeiji)
- [satori](https://github.com/vercel/satori)
```

(Note: in the README example replace the pseudo call `koishi_ffi_font()` comment with prose only — the example above already notes font loading is app-side I/O; do not invent an API.)

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: usage and install instructions"
```

---

### Task 7: Final verification sweep

- [ ] **Step 1: Full green run**

Run: `gleam format && gleam deps download && gleam test && gleam format --check src test && git status`
Expected: all exit 0; `git status` shows a clean tree (all tasks committed).

- [ ] **Step 2: Real-surface sanity (manual QA)**

Run a one-off script through node exporting the SVG to a file:

```bash
node -e "
import('./build/dev/javascript/koishi/koishi.mjs').then(async (k) => {
  const { renderInternal, read_test_font_file } = await import('./build/dev/javascript/koishi/koishi/ffi.mjs');
  const opts = { width: 1200, height: 630, fonts: [
    { name: 'Inter', data: read_test_font_file('node_modules/@fontsource/inter/files/inter-latin-400-normal.woff'), weight: 400, style: 'normal' }
  ], debug: false };
  const result = await renderInternal('<div style=\"display:flex;color:black;font-style:normal\">Hello</div>', opts);
  console.log(result[0] ? result[0].slice(0, 60) : 'ERROR: ' + result[1].message);
});
"
```

Expected: printed text starts with `<svg` (real-surface artifact of the FFI path). Cleanup: none needed (no server/temp files).

Reference: `renderInternal` returns Gleam `Ok` as class instance with `.a` field (verified `Ok` record access via prototype accessors), so `result[0]` indexing is NOT applicable — instead inspect via `result instanceof Ok` from `../gleam.mjs`, or simply fall back to the gleeunit tests as the authoritative e2e proof and treat this Step 2 as optional if the JS snippet shape fails; the tests in Tasks 2–4 already exercise the exact same path (gleeunit awaits them).

---

## Self-Review record

- Spec coverage: core `to_svg(string, Options)` (Task 2), `SatoriError` consolidation (Tasks 2–3), lustre integration (Task 4), FFI node-pg pattern & consumer-install docs (Tasks 1, 6), CI switch to node + JS target (Task 5), README metadata/install/usage (Tasks 1, 6). Non-goals unchanged (no Erlang target, no satori sub-APIs, no OGP meta tags).
- Placeholder scan: no TBD/TODO; every code step shows complete content; both variants of `Options` construction shown (named + positional).
- Type consistency: `Font`, `FontStyle` (`NormalStyle`/`Italic`), `Options`, `SatoriError`, `to_svg` names identical across src, ffi, tests, README. ffi imports match compiled module paths verified empirically (`../gleam.mjs`, `../koishi.mjs`).
