# Explorer

A modular Roblox client instance explorer with a Studio-style dark interface. A 420-pixel-wide dock fills the right edge of the screen, with larger 22-pixel rows and 14-pixel text. Explorer and Properties are stacked together, with 313 class-icon mappings, category headings, a filter bar, and a separate script source viewer.

## Execute

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pldsp/explorer/main/loader.luau"))()
```

Requires a client executor providing `loadstring` and `game:HttpGet`. The loader downloads 17 separately minified modules from one pinned release commit, validates their byte lengths and Adler-32 checksums, and caches module exports. Downloads use up to four workers, three attempts per module and a 45-second startup wait limit. Failed downloads leave an existing explorer running. Executing again replaces the old explorer after downloads and compilation succeed.

The GUI uses `gethui()` when available, otherwise a writable CoreGui or PlayerGui. Clipboard copying uses `setclipboard`/`toclipboard` when available, with a selectable path field as fallback. No executor-specific identity changes are required by this project. Compatibility depends on the executor's Roblox API support.

## Controls

- Click disclosure triangles to expand branches; click names to select instances.
- Right-click a row for **View script**, **Properties**, **Focus selection**, **Reveal in Explorer**, **Copy path**, and **Refresh**.
- Properties opens beneath the tree by default. The title-bar properties icon toggles it. Filter by property name or category; collapse category headers; use checkboxes, enum choices, or text fields to edit supported values. Color properties include a swatch. Existing attributes are editable; new attributes added by the game appear automatically.
- **Ctrl+Shift+X** focuses the filter. Search names or classes; **Reveal in Explorer** returns the selected match to its hierarchy.
- **RightShift** or the title-bar minus hides the dock and script viewer. Click the floating Explorer button to restore the dock. **x** unloads the utility.
- Drag the dock's left edge to change its width while it remains attached to the right edge. Drag the horizontal divider to resize Explorer versus Properties. The dock adapts to viewport size changes.
- Double-click a script, use **View script** in its context menu, or click **</>** in the title bar to read source. Other branches expand/collapse on double-click.
- Values: vectors are comma-separated, Color3 channels are `0..1`, UDim2 is `xScale, xOffset, yScale, yOffset`, enum values accept names such as `Neon`.

Inspection follows the client-visible DataModel and streaming boundaries. Property edits remain subject to Roblox permissions, replication, and game scripts. Properties use a bundled official Roblox API snapshot with 950 classes and 2,761 public property definitions; inherited properties are grouped by engine category. Hidden, deprecated, and non-scriptable fields are filtered, read-only metadata is respected, and unreadable values are skipped. The snapshot source/version is recorded in `dist/api-source.json`. Focus moves the camera once; the game's camera controller can move it again. Search results are snapshots; use Refresh to include changes outside watched branches.

## Script source

The source viewer first tries a readable `Source` property, then the executor's existing `decompile(script)` function. It does not download or install a decompiler. Unsupported executors, unavailable server source, empty results, errors, and timeouts show a message inside the viewer. Decompilation runs asynchronously; stale results are ignored after switching scripts, closing the viewer, or unloading. Source is cached per instance; Reload bypasses the cache.

The viewer has line numbers, horizontal/vertical scrolling, Reload, and Copy. Source is selectable and read-only. Very large scripts display their first 200,000 bytes; Copy retains the full returned source. Server-only bytecode that is absent from the client cannot be recovered by this viewer.

## Modules and performance

`dist/modules/` contains 17 separate comment-free, level-3 minified modules. ApiMetadata and PropertyCatalog provide the engine property catalog; IconAtlas and Icons provide class icons; SourceReader and ScriptViewer provide source reading. The loader does not bundle modules into one large script. The icon atlas reference and mapping are adapted from the supplied DexPlusPlus source; its MIT notice is preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The local reference checkout is excluded from releases.

TreeView recycles only viewport rows. TreeModel watches visible hierarchy nodes, coalesces structural events, and yields during cancellable searches. Search output is capped at 1,500 matches. There is no per-frame hierarchy scan. Closing disconnects listeners and destroys owned instances. Very large expanded branches still require flattened hierarchy rows and event subscriptions; collapse unused branches to reduce that cost.

`src/` contains editable modules. `init.client.luau` and `default.project.json` are an optional Studio/Rojo adapter; the executor release does not require ModuleScript instances or `script.Parent`.

## Build and validate

Uses the user's **tuffmin** minifier at `C:/Users/Asus/Documents/minifier`; set `EXPLORER_MINIFIER` to change its location. No Node dependencies are installed.

```text
node tools/release.mjs
lune run tools/check.luau
lune run tools/check-tree.luau
lune run tools/check-reader.luau
lune run tools/check-app.luau
```

Publish modules first, then run `node tools/release.mjs <full-modules-commit-sha>` to generate the pinned, minified `loader.luau`. Commit that loader. Source and generated modules are compiled with Lune; conversion, tree behavior, source/decompiler handling, and minified app/loader lifecycle are exercised with test harnesses. Mock engine checks do not replace a visual Roblox/executor playtest.

`node tools/update-metadata.mjs` refreshes bundled metadata from Roblox's official Studio deployment API dump. `node tools/import-dex-icons.mjs` regenerates icon mappings and notices from the local DexPlusPlus reference.

Optional Studio model: `lune run tools/build.luau`, then insert `dist/ExplorerPlus.rbxm` into StarterPlayerScripts and start Play.
