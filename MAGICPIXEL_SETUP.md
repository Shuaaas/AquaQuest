# MagicPixel setup for AquaQuest

Checked: 2026-11-05. Project: `C:\Users\joshu\OneDrive\Documents\aqua-questt`.

## Status and installation

Configured, but **authenticated MCP connection is not verified**.

- Read the official MCP, OAuth, and sync documentation and inspected the existing project/configuration.
- Backed up Codex configuration to `C:\Users\joshu\.codex\backups\config.before-magicpixel.20261105-014514.toml`.
- Ran `codex mcp add magicpixel --url https://magicpixel.art/mcp`.
- Configuration: `C:\Users\joshu\.codex\config.toml` now contains:

```toml
[mcp_servers.magicpixel]
url = "https://magicpixel.art/mcp"
```

- Compared parsed configurations: every previous setting and MCP server is preserved.
- `codex mcp list` reports MagicPixel enabled with Streamable HTTP; authentication status is `unknown`.
- No local MCP package is needed. The optional official sync package `@magicpixelart/cli` was verified on npm (0.6.5, Node >=18), but not installed or run.

## Authentication and current blocker

MCP requires a MagicPixel account and human approval through OAuth 2.1 with PKCE; no API key is required for MCP.

`codex mcp login magicpixel` currently fails before browser sign-in:

```text
OAuth metadata discovery failed for
https://magicpixel.art/.well-known/oauth-protected-resource/mcp
HTTP request failed: error decoding response body
```

Independent checks reached the endpoint and read its JSON, while curl reported `chunk hex-length char not a hex digit`. A temporary gzip-header diagnostic got further but failed dynamic registration with HTTP 404. That override was not saved. This is an unresolved HTTP/OAuth compatibility issue; credentials and actual tool access have not been verified.

Retry `codex mcp login magicpixel` after the service issue is corrected. Sign in and approve the displayed app yourself. Then refresh/restart Codex and use a new chat if tools are missing. Never paste OAuth tokens into this repository or chat.

## Tools and generation

The public server card identifies `magicpixel-mcp` 0.21.0 and advertises these **23 tools**; this is discovery information, not an authenticated `tools/list` result:

```text
whoami, get_generation_result, get_credit_balance, create_credit_checkout,
list_projects, create_project, list_assets, get_asset, create_folder,
list_style_references, get_style_reference, upload_style_reference,
get_style_profile, update_style_profile, enrich_prompt, get_style_set,
add_style_sample, list_marketplace_assets, get_marketplace_asset,
generate_pixel_art, generate_variants, generate_directions, apply_with_ai
```

After login, verify the live tool list and call `whoami` and `get_credit_balance` first. Generation, variants, directions, and AI editing spend credits. **Ask the user to approve the displayed credit cost before generating.** No generation was attempted and no credits were spent during setup.

Suggested test request to Codex:

> Using MagicPixel, inspect my credit balance and quote the cost before generating one 32x32 fishing float icon. After I approve, use transparent PNG, hard pixel edges, a centered subject, no scenery, and the colors in Resources/UI/ui_palette.json. Put it in the aquaquest-test library folder and save the result under Assets/UI/Items/MagicPixelTest without overwriting files.

## Godot integration and optional sync

`magicpixel.json` is staged, inactive, and contains no credentials. It limits uploads and syncing to `Assets/UI/Items/MagicPixelTest`; downloads are restricted to the `aquaquest-test` library folder. Its schema follows the official sync guide; operational sync is untested. No watcher is running and no existing art was uploaded or replaced.

Sync requires a paid plan and a separate project-bound API key. After user approval of paid-plan use, bind a key to the intended MagicPixel project and authenticate with the official CLI's interactive login. Keep credentials in its ignored `.magicpixel/` directory, never command arguments or source files. Do not run `start`: it bootstraps an initial two-way sync with broader defaults. Keep the supplied restricted configuration.

From the AquaQuest root, first review:

```powershell
npx @magicpixelart/cli@0.6.5 doctor --json
npx @magicpixelart/cli@0.6.5 sync --dry-run --no-prune
```

Only after reviewing the plan and obtaining any required approval, use `sync --watch --no-prune`. Recheck dry runs after configuration changes. Avoid force, flatten, prune, rename, or delete operations on existing assets without approval.

Godot imports downloaded PNGs normally. Preserve transparency, nearest filtering, lossless import, and disabled mipmaps for these small icons. Existing item icons are 32x32; player atlas frames inspected in `Scene/Player/player.tscn` are 128x128. Do not replace or resize player sheets. The UI palette is a reference for the test icon, not a verified palette for every game asset. No gameplay scripts, scenes, player assets, or Godot settings were changed.

## Remaining checks and troubleshooting

1. Resolve OAuth discovery/registration, finish human sign-in, and refresh Codex.
2. Verify live tools, identity, and balance; public documentation alone does not prove connection.
3. Obtain credit approval before the test generation; inspect PNG dimensions and alpha afterward.
4. Approve paid sync use, authenticate its separate key locally, and review the dry run before syncing.
5. Test the generated asset in Godot and on Android. Neither test is complete.

For the current blocker, send MagicPixel support the Codex version (`0.166.0-alpha.5.1`), public failing endpoint, and errors above, without credentials. For later sync failures use `doctor --json`; do not use destructive repair commands automatically.

Sources: [MagicPixel connection guide](https://magicpixel.art/guides/connect), [OAuth reference](https://magicpixel.art/auth.md), [public server card](https://magicpixel.art/.well-known/mcp/server-card.json), [sync reference](https://magicpixel.art/guides/sync), [Codex MCP documentation](https://developers.openai.com/codex/mcp).
