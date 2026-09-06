/**
 * FFI for the koishi_example sample: font file loading and SVG output,
 * mirroring the patterns from the koishi package's own FFI.
 *
 * Compiled location: build/dev/javascript/koishi_example/koishi_example_ffi.mjs
 * (package root, like node-pg's src/ffi.mjs) hence the prelude import is
 * "./gleam.mjs".
 */
import { readFileSync, writeFileSync } from "node:fs";
import { toBitArray } from "./gleam.mjs";

// Load a font file as a Gleam BitArray. Gleam type: String -> BitArray.
export function read_font_file(path) {
  return toBitArray(Array.from(readFileSync(path)));
}

// Write a text file. Gleam type: String -> String -> Nil. Throws on I/O error.
export function write_file(path, contents) {
  writeFileSync(path, contents);
}
