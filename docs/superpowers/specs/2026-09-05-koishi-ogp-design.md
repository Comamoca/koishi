# koishi: OG-image generation from Lustre HTML Trees

Date: 2026-09-05
Status: Approved (design consultation with user 2026-09-05)

## Problem

Lustre authors build UI trees as `lustre/element.Element(msg)` values. There is
no Gleam-side way to turn those trees into Open Graph (og:image) card images.
The npm OSS pieces exist already:

- [`@comamoca/komeiji`](https://github.com/Comamoca/komeiji) v0.1.1 —
  HTML string → satori-friendly VDOM (`html(string) -> VNode`).
  ESM, Node ≥ 20, no DOM dependency (Bun/Node/Deno/Edge OK).
- [`satori`](https://github.com/vercel/satori) —
  VDOM → SVG string (`satori(vnode, options) -> Promise<string>`),
  requires `fonts: [{ name, data, weight, style }]` plus `width`/`height`.

`koishi` is the Gleam bridge that stitches Lustre trees through both.

## Constraints & prior art

- Gleam 1.14.0 has **no native npm dependency support** (verified: an
  `[npm-dependencies]` block in `gleam.toml` is silently ignored).
- House pattern from Comamoca's `node-pg`:
  `target = "javascript"` in `gleam.toml`, a single `src/*/ffi.mjs` importing the
  npm package, root `package.json` for dev/CI, README instructs consumers to
  install the npm package themselves (`npm install` / `bun add` / `deno add`).
- Async is bridged via `gleam/javascript/promise`:
  FFI externals return `Promise(Result(...))`, awaited with `promise.await`.

## Architecture (chosen: B — lustre-free core + lustre integration module)

```
src/
├─ koishi.gleam          # core API: HTML string → SVG (komeiji + satori FFI)
├─ koishi/
│  ├─ ffi.mjs            # all JS bridging (komeiji html(), satori(), conversions)
│  └─ lustre.gleam       # lustre integration: Element → koishi core
test/
└─ koishi_test.gleam     # gleeunit, JS target, real satori render with TTF fixture
package.json             # devDep-style root: @comamoca/komeiji + satori
```

`gleam.toml` gains `target = "javascript"`, `[javascript] runtime = "node"`,
and dependencies `gleam_stdlib`, `gleam_javascript`, `lustre`
(lustre is needed by the integration module regardless of target; Gleam has no
optional dependencies).

## Public API

### Core: `src/koishi.gleam`

```gleam
import gleam/javascript/promise.{type Promise}

pub type FontStyle { NormalStyle Italic }

pub type Font {
  Font(name: String, data: BitArray, weight: Int, style: FontStyle)
}

pub type Options {
  Options(width: Int, height: Int, fonts: List(Font), debug: Bool)
}

pub type SatoriError { SatoriError(message: String) }

/// komeiji: HTML → VNode, satori: VNode → SVG string.
pub fn to_svg(html: String, options: Options) -> Promise(Result(String, SatoriError))
```

- `weight` is the satori numeric weight (100–900); left as `Int` for freedom.
- `data` is the raw font file bytes (`BitArray`), converted to `Uint8Array` in FFI.

### Integration: `src/koishi/lustre.gleam`

```gleam
import koishi.{type Options}
import lustre/element.{type Element}

/// Serialize with `element.to_string` (compact, non-pretty — verified in
/// lustre source: "no newlines or indentation") then delegate to the core.
pub fn to_svg(element: Element(msg), options: Options)
  -> Promise(Result(String, SatoriError))
```

`Element(msg)` is generic over the message type; no runtime dependency on
messages, since serialization discards them.

Consumer flow:

```sh
npm install @comamoca/komeiji satori   # (or bun add / deno add npm:...)
gleam add koishi
```

```gleam
import koishi
import koishi/lustre
import lustre/element
import gleam/javascript/promise

let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  // font_bytes: BitArray — the app loads its own font file
let options =
  koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

promise.await(lustre.to_svg(my_element, options), fn(svg) {
  // svg: Result(String, koishi.SatoriError)
})
```

## FFI layer: `src/koishi/ffi.mjs`

Single module, house-style (`node-pg/ffi.mjs` as the model):

```js
import { html } from "@comamoca/komeiji";
import satori from "satori";
import { Error as GleamError } from "./gleam.mjs"; // Result constructors as needed
```

- `renderInternal(htmlString, optionsRecord) -> Promise`
  1. `const vnode = html(htmlString)` — komeiji accepts a plain string call.
  2. Convert Gleam `Options` record → JS object; convert each `Font`
     (`BitArray` → `Uint8Array`; satori accepts `Uint8Array`/`ArrayBuffer`).
  3. `await satori(vnode, { width, height, fonts, debug })`.
  4. Resolve `Ok(svgString)`; on ANY thrown error → resolve
     `Error(SatoriError(message))` (single consolidation point).
- Conversion helpers mirror node-pg conventions
  (`gleamList.toArray()` / `toList`, `Some/None` from gleam_stdlib).

## Error handling

One type: `SatoriError(message: String)`. Both komeiji parse failures and
satori render failures are exceptions internally; the FFI catches all and
consolidates. No error taxonomy beyond this — YAGNI.

## Testing

- `gleam test` (JS target, via `target = "javascript"`):
  - Conversion-helper unit tests (List ↔ Array round trips).
  - E2E: bundle one small TTF fixture; render real HTML through the full
    komeiji + satori path; assert the result is a string starting with `<svg`.
  - Integration via `koishi/lustre`: build a `lustre/element` tree and render
    it end-to-end.
- Error path: malformed HTML / missing font → `Error(SatoriError(_))`.

## Packaging, CI, README

- `.github/workflows/test.yml`: setup-beam (Gleam 1.14) **+ setup-node**,
  `npm ci`, `gleam test` (JS target default), keep `gleam format --check src test`.
- README rewritten in the node-pg style: Install section with per-runtime npm
  instructions, usage example, note on engines (Node ≥ 20 from komeiji).
- `gleam.toml` metadata filled in (description, licences, repository).

## Non-goals

- Erlang target support (komeiji/satori are JS-only).
- Wrapping satori's font-processing or `extractPaths` sub-APIs.
- OGP `<meta>` tag generation (separate concern; komeiji is not a metadata parser).
