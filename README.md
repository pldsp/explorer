# Explorer

A modular Roblox client instance explorer with a compact, Studio-style interface inspired by the supplied reference. Narrow dark panel, class icons, disclosure triangles, blue selection, a filter bar, and a separate properties window. No annotation arrows.

## Execute

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pldsp/explorer/main/loader.luau"))()
```

Requires a client executor providing `loadstring` and `game:HttpGet`. The loader downloads 12 separately minified modules from one pinned release commit, validates their byte lengths and Adler-32 checksums, and caches module exports. Downloads use up to four workers, three attempts per module and a 45-second startup wait limit. Failed downloads leave an existing explorer running. Executing again replaces the old explorer after downloads and compilation succeed.

The GUI uses `gethui()` when available, otherwise a writable CoreGui or PlayerGui. Clipboard copying uses `setclipboard`/`toclipboard` when available, with a selectable path field as fallback. No executor-specific identity changes are required by this project. Compatibility depends on the executor's Roblox API support.

## Controls

- Click disclosure triangles to expand branches; click names to select instances.
- Right-click a row for **Properties**, **Focus selection**, **Reveal in Explorer**, **Copy path**, and **Refresh**.
- **P** in the title bar toggles the separate properties window. Edit a value and press Enter or leave the field to apply it. Existing attributes are editable; new attributes added by the game appear automatically.
- **Ctrl+Shift+X** focuses the filter. Search names or classes; **Reveal in Explorer** returns the selected match to its hierarchy.
- **RightShift** or the title-bar **v** hides the windows. Click the floating Explorer button to restore them. **x** unloads the utility.
- Drag either title bar to move a window. Drag the explorer's lower-right grip to resize it.
- Values: vectors are comma-separated, Color3 channels are `0..1`, UDim2 is `xScale, xOffset, yScale, yOffset`, enum values accept names such as `Neon`.

Inspection follows the client-visible DataModel and streaming boundaries. Property edits remain subject to Roblox permissions, replication, and game scripts. The property schema covers common classes and can be extended. Focus moves the camera once; the game's camera controller can move it again. Search results are snapshots; use Refresh to include changes outside watched branches.

## Modules and performance

`dist/modules/` contains separate comment-free, level-3 minified modules: App, Config, Icons, Inspector, Janitor, PropertySchema, Selection, TreeModel, TreeView, UI, ValueCodec, and Window. The loader does not bundle these into one large script. Class icons are drawn with UI objects and require no downloaded image assets.

TreeView recycles only viewport rows. TreeModel watches visible hierarchy nodes, coalesces structural events, and yields during cancellable searches. Search output is capped at 1,500 matches. There is no per-frame hierarchy scan. Closing disconnects listeners and destroys owned instances. Very large expanded branches still require flattened hierarchy rows and event subscriptions; collapse unused branches to reduce that cost.

`src/` contains editable modules. `init.client.luau` and `default.project.json` are an optional Studio/Rojo adapter; the executor release does not require ModuleScript instances or `script.Parent`.

## Build and validate

Uses the user's **tuffmin** minifier at `C:/Users/Asus/Documents/minifier`; set `EXPLORER_MINIFIER` to change its location. No Node dependencies are installed.

```text
node tools/release.mjs
lune run tools/check.luau
lune run tools/check-tree.luau
lune run tools/check-app.luau
```

Publish modules first, then run `node tools/release.mjs <full-modules-commit-sha>` to generate the pinned, minified `loader.luau`. Commit that loader. Source and generated modules are compiled with Lune; conversion, tree behavior, and minified app/loader lifecycle are exercised with test harnesses. Mock engine checks do not replace a visual Roblox/executor playtest.

Optional Studio model: `lune run tools/build.luau`, then insert `dist/ExplorerPlus.rbxm` into StarterPlayerScripts and start Play.
