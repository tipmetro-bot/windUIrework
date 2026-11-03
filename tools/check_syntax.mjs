/**
 * WindUI Rework / syntax check
 * ----------------------------
 * Parses every .lua / .luau file in the repository (including the generated
 * dist/main.lua) with a real Luau parser.
 *
 *   npm install
 *   node tools/check_syntax.mjs
 *
 * For a full compiler check (Luau CLI):
 *   luau-compile --null dist/main.lua
 */
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const require = createRequire(import.meta.url)
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')

let parser
try {
  parser = require('luau-parser').luauparser
} catch {
  console.error('[check] luau-parser is missing. Run `npm install` first.')
  process.exit(1)
}

const files = []
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === '.git' || entry.name === 'node_modules' || entry.name === '.cache') continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walk(full)
    else if (/\.(lua|luau)$/.test(entry.name)) files.push(full)
  }
}
walk(root)

let failed = 0
for (const file of files) {
  try {
    parser.parse(fs.readFileSync(file, 'utf8'))
  } catch (error) {
    failed++
    console.error(`FAIL ${path.relative(root, file)}: ${error.message || error}`)
  }
}

if (failed > 0) {
  console.error(`[check] ${failed} of ${files.length} Luau files failed to parse`)
  process.exit(1)
}
console.log(`[check] ${files.length} Luau files parsed OK`)
