-- Generated from package.json | tools/bundle.py

return [[
{
    "name": "windui-rework",
    "version": "1.6.66-rework.1",
    "main": "./dist/main.lua",
    "repository": "https://github.com/tipmetro-bot/windUIrework",
    "discord": "https://discord.gg/ftgs-development-hub-1300692552005189632",
    "author": "Footagesus (original) / WindUI Rework",
    "description": "WindUI Rework: Roblox UI library with a PC/mobile open button, zero-safe sliders, smooth animations and a Neverlose-style profile panel",
    "license": "MIT",
    "scripts": {
        "build": "bash build/build.sh",
        "bundle": "python3 tools/bundle.py",
        "check": "node tools/check_syntax.mjs && python3 tools/bundle.py --check",
        "dev": "bash build/build.sh dev $INPUT_FILE",
        "test": "python3 tools/smoke_test.py",
        "live": "python3 -m http.server 8642",
        "watch": "chokidar . -i 'node_modules' -i 'dist' -i 'build' -c 'npm run build --'",
        "live-build": "concurrently \"npm run live\" \"npm run watch --\"",
        "example-live-build": "INPUT_FILE=main_example.lua npm run live-build",
        "test:math": "luau tests/slider_math_test.luau"
    },
    "keywords": [
        "ui-library",
        "luau",
        "roblox",
        "script-hub",
        "windui",
        "rework"
    ],
    "devDependencies": {
        "chokidar-cli": "^3.0.0",
        "concurrently": "^9.2.0",
        "luau-parser": "^1.1.0"
    }
}
]]
