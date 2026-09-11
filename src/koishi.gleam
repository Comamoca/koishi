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
/// (not WOFF2 — use `.woff` fixtures such as @fontsource's `.woff` files).
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

/// Error returned when SVG to PNG rendering fails.
pub type PngError {
  PngError(message: String)
}

/// Options for rendering an SVG to PNG with resvg.
///
/// Set `width` or `height` to a positive value to scale the output. If both
/// are zero, the SVG's intrinsic size is used. `background` accepts any CSS
/// color string; use an empty string to keep the default (transparent).
pub type PngOptions {
  PngOptions(width: Int, height: Int, background: String)
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
pub fn to_svg(
  html: String,
  options: Options,
) -> Promise(Result(String, SatoriError))

/// Render an SVG string to a PNG image as a `BitArray`.
///
/// Uses the npm package `@resvg/resvg-js` (Rust resvg bindings).
///
/// ```gleam
/// koishi.to_png(svg, koishi.PngOptions(width: 1200, height: 0, background: ""))
/// // -> Promise(Result(BitArray, PngError))
/// ```
@external(javascript, "./koishi/ffi.mjs", "svgToPng")
pub fn to_png(
  svg: String,
  options: PngOptions,
) -> Promise(Result(BitArray, PngError))
