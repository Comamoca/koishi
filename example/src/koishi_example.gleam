//// Sample: render an OG image from a Lustre element tree with koishi.
////
//// Run with `gleam run` from the `example/` directory. The generated SVG is
//// written to `og-image.svg` in the current working directory.
//// File I/O is done with simplifile (works on both Erlang and JS targets).

import gleam/io
import gleam/javascript/promise
import gleam/string
import koishi
import koishi/lustre
import lustre/attribute
import lustre/element/html
import simplifile

const font_path = "../node_modules/@fontsource/inter/files/inter-latin-400-normal.woff"

pub fn main() -> promise.Promise(Nil) {
  case simplifile.read_bits(font_path) {
    Error(error) -> {
      io.println("Failed to read font file: " <> string.inspect(error))
      promise.resolve(Nil)
    }
    Ok(font_bytes) -> main_with_font(font_bytes)
  }
}

fn main_with_font(font_bytes: BitArray) -> promise.Promise(Nil) {
  let font_normal = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let font_bold = koishi.Font("Inter", font_bytes, 700, koishi.NormalStyle)
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
        html.h1([attribute.style("color", "#ffffff")], [
          html.text("Hello from koishi!"),
        ]),
        html.p([attribute.style("color", "#c0caf5")], [
          html.text("OGP image generated from a Lustre element tree"),
        ]),
      ],
    )

  lustre.to_svg(og_image, options)
  |> promise.map(fn(result) {
    case result {
      Ok(svg) -> write_svg(svg)
      Error(koishi.SatoriError(message)) -> io.println("Error: " <> message)
    }
    Nil
  })
}

fn write_svg(svg: String) -> Nil {
  case simplifile.write("og-image.svg", svg) {
    Ok(Nil) -> io.println("Wrote og-image.svg")
    Error(error) -> {
      io.println("Failed to write og-image.svg: " <> string.inspect(error))
    }
  }
}
