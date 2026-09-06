/**
 * FFI for koishi: bridges Gleam and the npm packages
 * @comamoca/komeiji (HTML string -> satori VNode) and satori (VNode -> SVG).
 *
 * Compiled location: build/dev/javascript/koishi/koishi/ffi.mjs, hence
 * the prelude is "../gleam.mjs" and the package main module is "../koishi.mjs".
 */
import { html } from "@comamoca/komeiji";
import satori from "satori";
import { Ok as GleamOk, Error as GleamError, toBitArray } from "../gleam.mjs";
import { SatoriError, Italic } from "../koishi.mjs";
import { writeFileSync, readFileSync } from "node:fs";

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

// Load a font file from disk as a Gleam BitArray.
// Gleam type: String -> BitArray. Used by tests and the example module.
export function read_test_font_file(path) {
  return toBitArray(Array.from(readFileSync(path)));
}

// Write a text file from disk (used by the example module to output the SVG).
// Gleam type: String -> String -> Nil. Throws on I/O failure.
export function write_file(path, contents) {
  writeFileSync(path, contents);
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
