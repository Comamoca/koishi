//// Sample: render an OG image from a Lustre element tree with koishi.
////
//// Run with `gleam run` from the `example/` directory. The generated SVG is
//// written to `og-image.svg` in the current working directory.

import gleam/io
import gleam/javascript/promise
import koishi
import koishi/lustre
import lustre/attribute
import lustre/element/html

@external(javascript, "./koishi_example_ffi.mjs", "read_font_file")
fn read_font_file(path: String) -> BitArray

@external(javascript, "./koishi_example_ffi.mjs", "write_file")
fn write_file(path: String, contents: String) -> Nil

pub fn main() -> promise.Promise(Nil) {
  let font_bytes =
    read_font_file(
      "../node_modules/@fontsource/inter/files/inter-latin-400-normal.woff",
    )
  let font_normal =
    koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let font_bold =
    koishi.Font("Inter", font_bytes, 700, koishi.NormalStyle)
  let options =
    koishi.Options(
      width: 1200,
      height: 630,
      fonts: [font_normal, font_bold],
      debug: False,
    )

  let og_image =
    html.div(
      [
        attribute.style("display", "flex"),
        attribute.style("flex-direction", "column"),
        attribute.style("align-items", "center"),
        attribute.style("justify-content", "center"),
        attribute.style("background-color", "#1a1b26"),
      ],
      [
        html.h1(
          [attribute.style("color", "#ffffff")],
          [html.text("Hello from koishi!")],
        ),
        html.p(
          [attribute.style("color", "#c0caf5")],
          [html.text("OGP image generated from a Lustre element tree")],
        ),
      ],
    )

  lustre.to_svg(og_image, options)
  |> promise.map(fn(result) {
    case result {
      Ok(svg) -> {
        write_file("og-image.svg", svg)
        io.println("Wrote og-image.svg")
      }
      Error(koishi.SatoriError(message)) ->
        io.println("Error: " <> message)
    }
    Nil
  })
}
