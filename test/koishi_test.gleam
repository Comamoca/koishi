import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/string
import gleeunit
import lustre/attribute

import koishi.{type Options}
import koishi/lustre as koishi_lustre
import lustre/element/html

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

pub fn to_svg_missing_font_returns_error_test() -> Promise(Nil) {
  let options =
    koishi.Options(width: 1200, height: 630, fonts: [], debug: False)

  koishi.to_svg("<div style=\"display:flex;\">hi</div>", options)
  |> promise.map(fn(result) {
    let assert Error(koishi.SatoriError(message)) = result
    assert message != ""
    Nil
  })
}

pub fn lustre_element_to_svg_test() -> Promise(Nil) {
  let font_bytes =
    read_test_font_file(
      "node_modules/@fontsource/inter/files/inter-latin-400-normal.woff",
    )
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options: Options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  let tree =
    html.div([attribute.style("display", "flex")], [
      html.h1([], [html.text("koishi " <> int.to_string(2026))]),
    ])

  koishi_lustre.to_svg(tree, options)
  |> promise.map(fn(result) {
    let assert Ok(svg) = result
    assert string.starts_with(svg, "<svg")
    Nil
  })
}
