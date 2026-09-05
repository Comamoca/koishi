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
