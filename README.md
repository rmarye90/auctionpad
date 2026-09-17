# Auctionpad

Sell groups and recraft tracking for the World of Warcraft auction house — a companion to
[Auctionator](https://www.curseforge.com/wow/addons/auctionator).

Group your crafted items ("Flasks", "Enchants", "Gems"), give each one a target quantity,
and see at a glance what is on sale, what you can post right now, what is sitting in the
bank, and what you still need to craft.

## Status

Early development (v0.1.0). The data layer and stock calculations are in place; the UI,
auction tracking and posting queue are next.

## Install (development)

```bash
ln -s /path/to/workflow_ai/addons/auctionpad \
      "/Applications/World of Warcraft/_retail_/Interface/AddOns/Auctionpad"
```

## Commands

| Command | Effect |
|---|---|
| `/auctionpad`, `/apad` | Toggle the main window (or select the Auctionpad tab, see below) |
| `/apad help` | Show the command list |

## Auction house integration

When the auction house is open, Auctionpad docks into it as a tab (next to Blizzard's
own Buy/Sell/Auctions, and Auctionator's if it's installed) instead of floating on top
of it. `/apad` and the minimap button select that tab; a repeated `/apad` while it's
already selected does nothing. Outside the auction house, the same content shows up in
the floating window as before — nothing is lost, it's the same widgets reparented.

By default, opening the auction house does **not** auto-select the tab (so it never
hides Buy/Sell/Auctions on you) — set `settings.auto_open_at_ah = true` to change that.

This is built on [LibAHTab](https://github.com/TheMouseNest/LibAHTab) (vendored in
`Libs/`, MIT licensed), the same library Auctionator and TradeSkillMaster use to add
their own AH tabs. It's the one exception to this addon's "no external dependencies"
rule: hand-rolling AH tab anchoring is a known source of bag taint on the second time
the auction house is opened (see `Libs/LibAHTab/README.md`) — LibAHTab exists
specifically to avoid that, and embedding it lets Auctionpad's tab coexist correctly
with any other addon's tabs that also use it. `Libs/LibAHTab/LibAHTab.lua` is never
edited directly; behavior changes belong in `UI/AHTab.lua`.

## Development

```bash
# Lua 5.4 specifically — luacheck does not run on 5.5 yet
brew install lua@5.4 luarocks
luarocks --lua-version 5.4 --lua-dir /opt/homebrew/opt/lua@5.4 install busted
luarocks --lua-version 5.4 --lua-dir /opt/homebrew/opt/lua@5.4 install luacheck

export PATH="$HOME/.luarocks/bin:$PATH"

make lint    # luacheck
make test    # busted
make check   # both
```

Tests must be run from the addon root — the specs use relative `dofile()` paths.

Pure logic lives in `Data/`, `Stock/`, `Utils/` and `Auction/` and is unit tested.
Anything under `UI/` renders only and is covered by manual testing in game.

## Notes on the auction house API

`C_AuctionHouse.PostItem` and `PostCommodity` require a hardware event, so a group is
posted one stack per click through a queue — there is no way to post in bulk from an addon,
by design.

Commodities are posted at a **unit** price that must be a whole silver; non-commodity items
are posted at a **stack** price. `C_AuctionHouse.GetItemKeyInfo().isCommodity` decides which.

## License

MIT
