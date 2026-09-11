/**
 * FFI for koishi: bridges Gleam and the npm packages
 * @comamoca/komeiji (HTML string -> satori VNode) and satori (VNode -> SVG).
 *
 * Compiled location: build/dev/javascript/koishi/koishi/ffi.mjs, hence
 * the prelude is "../gleam.mjs" and the package main module is "../koishi.mjs".
 */
import { html } from "@comamoca/komeiji";
import satori from "satori";
import { Resvg } from "@resvg/resvg-js";
import {
  Ok as GleamOk,
  Error as GleamError,
  toBitArray,
} from "../gleam.mjs";
import { SatoriError, PngError, Italic } from "../koishi.mjs";
import { readFileSync } from "node:fs";

// Gleam BitArray -> Uint8Array.
// Fast path: byte-aligned BitArrays (bitOffset 0, whole bytes) — the prelude
// guarantees rawBuffer is exactly the data in that case.
export function fontDataToUint8Array(bitArray) {
  if (bitArray.bitOffset === 0 && bitArray.bitSize % 8 === 0) {
    return bitArray.rawBuffer;
  }
  // Unaligned BitArrays: copy the logical bytes out via byteAt.
  const bytes = new Uint8Array(bitArray.byteSize);
  for (let i = 0; i < bytes.length; i++) bytes[i] = bitArray.byteAt(i);
  return bytes;
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
// compiled koishi.mjs classes. The prelude constructors are aliased
// (GleamOk/GleamError) so they do not shadow the global Error class used in
// errorToMessage below.
export function renderInternal(htmlString, options) {
  return new Promise((resolve) => {
    try {
      const vnode = html(htmlString);
      const satoriOptions = optionsToJs(options);
      satori(vnode, satoriOptions).then(
        (svg) => resolve(new GleamOk(svg)),
        (err) =>
          resolve(new GleamError(new SatoriError(errorToMessage(err)))),
      );
    } catch (err) {
      resolve(new GleamError(new SatoriError(errorToMessage(err))));
    }
  });
}

function errorToMessage(err) {
  if (err instanceof globalThis.Error && err.message) return err.message;
  return String(err);
}

// Uint8Array -> Gleam BitArray. Relies on the Gleam JS prelude's
// toBitArray helper, which is also used by read_test_font_file.
function uint8ArrayToBitArray(bytes) {
  return toBitArray(Array.from(bytes));
}

// SVG string -> PngOptions record -> Promise<Result(BitArray, PngError)>.
// Uses @resvg/resvg-js to rasterise the SVG to PNG.
export function svgToPng(svg, options) {
  return new Promise((resolve) => {
    try {
      const opts = { font: { loadSystemFonts: false } };
      if (options.width > 0) {
        opts.fitTo = { mode: "width", value: options.width };
      } else if (options.height > 0) {
        opts.fitTo = { mode: "height", value: options.height };
      }
      if (options.background) {
        opts.background = options.background;
      }
      const resvg = new Resvg(svg, opts);
      const pngData = resvg.render();
      resolve(new GleamOk(uint8ArrayToBitArray(pngData.asPng())));
    } catch (err) {
      resolve(new GleamError(new PngError(errorToMessage(err))));
    }
  });
}
