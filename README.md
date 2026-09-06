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
import gleam/io
import gleam/javascript/promise
import koishi
import koishi/lustre
import lustre/attribute
import lustre/element/html

pub fn main() -> promise.Promise(Nil) {
  // Load your font file as bytes (BitArray). satori accepts
  // TTF, OTF, and WOFF — WOFF2 is not supported.
  let font_bytes = read_font_bytes()  // your own I/O, e.g. simplifile.read_bits
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  let og_image =
    html.div([attribute.style("display", "flex")], [
      html.h1([], [html.text("Hello from koishi!")]),
    ])

  promise.await(lustre.to_svg(og_image, options), fn(svg) {
    case svg {
      Ok(svg) -> io.println(svg)
      Error(koishi.SatoriError(message)) -> io.println(message)
    }
    |> promise.resolve
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

Requirements: Node.js ≥ 20.19 (Bun and Deno also work). satori accepts
TTF/OTF/WOFF fonts — WOFF2 is not supported.

Further documentation can be found at <https://hexdocs.pm/koishi>.

## Development

```sh
npm ci     # install npm deps (komeiji, satori, test font fixture)
gleam test # runs on the JavaScript target
```

A runnable sample that renders an OG image from a Lustre tree and writes
`og-image.svg` lives in `src/example.gleam`:

```sh
gleam run -m example
```

## 👍 Special Thanks

- [komeiji](https://github.com/Comamoca/komeiji)
- [satori](https://github.com/vercel/satori)
