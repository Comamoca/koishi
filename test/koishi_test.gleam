import gleam/bit_array
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/string
import gleeunit
import lustre/attribute

import koishi.{type Options}
import koishi/lustre as koishi_lustre
import lustre/element
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
    // satori renders text as glyph <path> outlines (never literal text), so
    // the presence of path data is the signal that content actually rendered.
    assert string.contains(svg, "<path")
    Nil
  })
}

pub fn to_png_renders_svg_to_png_test() -> Promise(Nil) {
  let svg =
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\">"
    <> "<rect width=\"100\" height=\"100\" fill=\"red\"/></svg>"

  koishi.to_png(svg, koishi.PngOptions(width: 100, height: 0, background: ""))
  |> promise.map(fn(result) {
    let assert Ok(png) = result
    assert bit_array.byte_size(png) > 0
    // PNG file signature: 89 50 4E 47 0D 0A 1A 0A
    let assert <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _:bits>> = png
    Nil
  })
}

pub fn lustre_fragment_tree_to_svg_test() -> Promise(Nil) {
  let font_bytes =
    read_test_font_file(
      "node_modules/@fontsource/inter/files/inter-latin-400-normal.woff",
    )
  let font = koishi.Font("Inter", font_bytes, 400, koishi.NormalStyle)
  let options: Options =
    koishi.Options(width: 1200, height: 630, fonts: [font], debug: False)

  // satori requires an explicit display style on elements with more than one
  // child, so the outer div must be flex. Lustre serializes the fragment with
  // <!--lustre:fragment--> marker comments; komeiji's parser drops comment
  // nodes before satori sees them, so the SVG must contain no trace of them.
  let tree =
    html.div([attribute.style("display", "flex")], [
      element.fragment([
        html.h1([], [html.text("fragmented title")]),
        html.p([], [html.text("body text")]),
      ]),
    ])

  koishi_lustre.to_svg(tree, options)
  |> promise.map(fn(result) {
    let assert Ok(svg) = result
    assert string.starts_with(svg, "<svg")
    // Fragment content rendered: glyph paths present in the SVG.
    assert string.contains(svg, "<path")
    // Lustre's fragment marker comments were dropped, not passed through.
    assert !string.contains(svg, "lustre")
    Nil
  })
}
