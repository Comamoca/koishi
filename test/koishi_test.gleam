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
