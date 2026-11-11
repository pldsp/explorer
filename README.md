# Explorer

A modular Roblox client instance explorer matching the supplied Dex++ screenshots: a translucent dark right dock, compact 20-pixel headers and rows, search bars with right-aligned search icons, blue selection, and stacked Explorer/Properties panels. The dock starts at 320 pixels wide and can be resized. The floating Notepad has syntax-colored source, line numbers, and full-source Copy/Save controls. There are 313 class-icon mappings.

## Execute

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pldsp/explorer/main/loader.luau"))()
```

Requires a client executor providing `loadstring` and `game:HttpGet`. The loader downloads 23 separately minified modules from one pinned release commit, validates their byte lengths and Adler-32 checksums, and caches module exports. Downloads use up to four workers, three attempts per module and a 45-second startup wait limit. Executing again brings the existing explorer into view and shows **E001 — Already running**, without downloading modules or replacing it. A simultaneous launch shows **E002 — Already loading**. Close the current Explorer before loading an updated release.

The GUI uses `gethui()` when available, otherwise a writable CoreGui or PlayerGui. Clipboard copying uses `setclipboard`/`toclipboard` when available, with a selectable path field as fallback. No executor-specific identity changes are required by this project. Compatibility depends on the executor's Roblox API support.

## Loading and animation

A Dex++-inspired startup card fades and scales into view over a temporary blur. It shows real download counts, module names, compilation, interface setup and completion, with a smooth progress bar and animated dots. It remains visible for at least 0.9 seconds so quick starts still show a complete transition. Startup failures after GUI creation turn the card into a dismissible error screen. The full error also appears in executor output. Retrying closes any old failed intro first; blur, repeating tweens and connections are cleaned on dismissal.

Explorer slides in from the right; hide/restore fades and slides it. Properties expands and collapses smoothly. Notepad opens with a subtle scale and fade, and its code content fades in after indexing. Context menus animate in/out; title and action buttons have hover/press feedback; disclosure arrows rotate. Blue or red notification cards display error codes. All motion uses TweenService rather than permanent per-frame loops. Superseded tweens are cancelled, and unload cancels active animations.

The intro source remains in `executor/intro.luau`. The build embeds that small bootstrap UI and error definitions into the loader so a progress/error screen can appear before any remote module is available. The utility modules remain separate.

## Error codes

| Code | Meaning |
| --- | --- |
| E001 | Explorer is already running; the current window is revealed. |
| E002 | Another startup is in progress. |
| E003 | The executor does not provide loadstring. |
| E004 | Explorer must run on the client. |
| E005 | No writable GUI container was found. |
| E101 | A module download failed after three attempts. |
| E102 | Download length/checksum does not match the release. |
| E103 | Downloads exceeded the 45-second startup wait. |
| E104 | A module failed to compile. |
| E105 | A module factory is invalid. |
| E106 | A module dependency cycle was detected. |
| E107 | A requested module is missing. |
| E108 | A module returned no export. |
| E109 | Interface initialization or an unexpected startup step failed. |
| E201 | Native decompilation is unavailable and Source is unreadable. |
| E202 | Source reading/decompilation failed or returned nothing. |
| E203 | The decompiler timed out. |

## Controls

- Click disclosure triangles to expand branches; click names to select instances.
- Right-click a row for **View script**, **Properties**, **Focus selection**, **Reveal in Explorer**, **Copy path**, and **Refresh**.
- Properties opens beneath the tree by default. The Explorer title-bar properties icon toggles it. Filter by property name or category; collapse category headers; use checkboxes, enum choices, or text fields to edit supported values. Color properties include a swatch. Add Attribute creates String, Number, or Boolean attributes; existing attributes are editable. The Properties header's overlapping-window icon undocks/redocks the panel.
- **Ctrl+Shift+X** focuses the filter. Search names or classes; **Reveal in Explorer** returns the selected match to its hierarchy.
- **RightShift** or the right-edge **>** tab hides the dock and Notepad. The edge **<** tab restores the dock. Explorer's **x** unloads the utility; the Properties and Notepad close buttons hide those panels.
- Drag the dock's left edge to change its width while it remains attached to the right edge. Drag the horizontal divider to resize Explorer versus Properties. The dock adapts to viewport size changes.
- Double-click a script or use **View script** in its context menu to read source. Other branches expand/collapse on double-click. Drag the Notepad title to move it, or its bottom-right grip to resize it.
- Values: vectors are comma-separated, Color3 channels are `0..1`, UDim2 is `xScale, xOffset, yScale, yOffset`, enum values accept names such as `Neon`.

Inspection follows the client-visible DataModel and streaming boundaries. Property edits remain subject to Roblox permissions, replication, and game scripts. Properties use a bundled official Roblox API snapshot with 950 classes and 2,761 public property definitions; inherited properties are grouped by engine category. Hidden, deprecated, and non-scriptable fields are filtered, read-only metadata is respected, and unreadable values are skipped. The snapshot source/version is recorded in `dist/api-source.json`. Focus moves the camera once; the game's camera controller can move it again. Search results are snapshots; use Refresh to include changes outside watched branches.

## Script source

The source viewer first tries a readable `Source` property, then the executor's existing `decompile(script)` function. It does not download or install a decompiler. Unsupported executors, unavailable server source, empty results, errors, and timeouts show a message inside the viewer. Decompilation runs asynchronously; stale results are ignored after switching scripts, closing the viewer, or unloading. Source is cached per instance; Reload bypasses the cache.

The viewer keeps the entire string returned by the source property or decompiler. There is no 200,000-byte limit or other fixed display cutoff. SourceDocument indexes every line, while ScriptViewer creates widgets only for the visible rows and renders only the visible columns. This lets you scroll to the end of large files and very long single lines without loading the whole string into one engine TextBox. CRLF and Unicode source remain intact in the stored output. Copy to Clipboard and Save to File export the complete original string through the executor's `setclipboard`/`toclipboard` and `writefile` capabilities, respectively. If a capability is unavailable, the viewer reports that. Read-only source is syntax colored; Reload Source bypasses the source cache, and Clear empties the viewer. Server-only bytecode that is absent from the client cannot be recovered by this viewer, and a decompiler that itself returns partial output cannot be made complete by the UI.

## Modules and performance

`dist/modules/` contains 23 separate comment-free, level-3 minified modules. ApiMetadata and PropertyCatalog provide the engine property catalog; IconAtlas and Icons provide class icons; SourceReader, SourceDocument, Syntax, and ScriptViewer provide complete source reading/rendering; Drag handles floating-window input; Motion, Notifications and Errors handle transitions and error presentation. The loader does not bundle utility modules into one large script. DexPlusPlus attribution and its MIT notice are preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The local reference checkout is excluded from releases.

TreeView recycles only viewport rows. TreeModel watches visible hierarchy nodes, coalesces structural events, and yields during cancellable searches. Search output is capped at 1,500 matches. There is no per-frame hierarchy scan. Closing disconnects listeners and destroys owned instances. Very large expanded branches still require flattened hierarchy rows and event subscriptions; collapse unused branches to reduce that cost.

`src/` contains editable modules. `init.client.luau` and `default.project.json` are an optional Studio/Rojo adapter; the executor release does not require ModuleScript instances or `script.Parent`.

## Build and validate

Uses the user's **tuffmin** minifier at `C:/Users/Asus/Documents/minifier`; set `EXPLORER_MINIFIER` to change its location. No Node dependencies are installed.

```text
node tools/release.mjs
lune run tools/check.luau
lune run tools/check-tree.luau
lune run tools/check-reader.luau
lune run tools/check-document.luau
lune run tools/check-app.luau
```

Publish modules first, then run `node tools/release.mjs <full-modules-commit-sha>` to generate the pinned, minified `loader.luau`. Commit that loader. Source and generated modules are compiled with Lune; conversion, tree behavior, source/decompiler handling, large-source rendering, interrupted animation cancellation, intro cleanup, duplicate launches, network/checksum/compile/init/time-out errors and retry recovery are exercised with test harnesses. Mock engine checks do not replace a visual Roblox/executor playtest.

`node tools/update-metadata.mjs` refreshes bundled metadata from Roblox's official Studio deployment API dump. `node tools/import-dex-icons.mjs` regenerates icon mappings and notices from the local DexPlusPlus reference.

Optional Studio model: `lune run tools/build.luau`, then insert `dist/ExplorerPlus.rbxm` into StarterPlayerScripts and start Play.
