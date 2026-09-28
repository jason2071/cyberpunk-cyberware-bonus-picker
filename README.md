# Cyberware Bonus Picker (CET UI)

Choose one, two, or three vanilla secondary bonus types on one equipped Cyberware item. With one type selected, the picker maximizes that bonus and accepts any other two. With two or three selected, it requires those types and lets you choose either Priority or Product ranking. The picker can be opened anywhere through Cyber Engine Tweaks; no Ripperdoc or Mod Settings menu is required.

## Requirements

- Cyber Engine Tweaks
- redscript
- A backup save before the first use

## Use

1. Load a save and open CET. Equipped Cyberware loads automatically the first time; use **Refresh items** only if your equipment changes while the picker is open.
2. Select an equipped Cyberware item. The search box stays above the single scrolling item list. Switching to another item keeps your selected bonus types and their priority order; it clears only the previous item's candidate roll.
3. Tick **one** type to maximize it while allowing any other two bonuses. Tick **two** or **three** types to require those types. **Product**, on the left and selected by default for a fresh installation, multiplies the selected values. **Priority** ranks bonus 1 first, then bonus 2 and 3 as tie breakers. Your ranking choice is saved in `picker_settings.json`; an existing saved choice is kept when you update the mod. Your selections and **Clear bonuses** stay fixed above the only scrolling bonus list. **Filter compatible bonuses** is optional; press it only when you want to narrow the list for the selected item.
4. The seed limit defaults to **100,000**. Enter another limit from 1 to 1,000,000, then press **Search**. The entered number is remembered in `picker_settings.json` across Cyberware changes and game sessions. Each Search starts at seed 0 and scans the entire limit. Press Search again with the same item, bonus selection, ranking mode, and seed limit to see the next distinct ranked result. Changing any of those search settings starts again with the best result. With one type selected, ranking mode does not affect the result. The **matches** counter shows how many seeds contained the selected types. Press **Stop** to cancel.
5. Check **Current item** for the bonus types on the equipped shard. Review the candidate's raw shard values, then press **Apply roll**. Apply can be pressed once for each result; press Search again to get another candidate and unlock Apply. Raw values are shown without a percent sign because they are used only to rank seeds; they are not the final numbers shown in the game tooltip. The picker confirms either the exact seed ID or a change to the three selected bonus types and distinguishes these results in its status.
6. Save and reload, then check the displayed bonuses in the game. Search history is kept only until the mod is reloaded or the game closes.

### Example: find Electric Damage

Select a Cyberware item, tick only **Electric Damage Bonus %**, and press **Search**. Result 1 has the highest raw Electric Damage value found in the chosen seed range. If you want another roll, press the same **Search** button again; Result 2 has the next lower distinct raw Electric Damage value. You do not need to change the seed limit or add another bonus. Check the in-game tooltip for the displayed percentage before saving.

Each result allows one **Apply roll** attempt. After applying, press **Search** to unlock Apply for the next result. If the item, selected bonuses, ranking mode, or seed limit changes, the next Search starts over at Result 1. A repeated Search scans the full seed range again, so it can take about as long as the first search. No extra reset or next-result button is needed.

## Install

Install the ZIP with Vortex, enable it, deploy mods, and restart the game. The ZIP places `bin` and `r6` at the game root. This CET version replaces older versions named `CyberwareBonusPicker`; install only one version.

## Build from source

The checked-in `init.lua` and `CyberwareBonusPicker.reds` are ready to install. To regenerate them from the game's own tweak data, run:

```powershell
python build_cyberware_picker_cet.py --game-dir "C:\path\to\Cyberpunk 2077"
```

The build script reads `tools/redmod/tweaks` from the installed game and uses the checked-in `picker_init_template.lua` and `cyberware_vanilla_bonus_catalog.json`. It writes the generated files into this repository's `bin` and `r6` directories. Python 3.9 or newer is required.

## Notes

- The picker selects bonus **types** and searches the game's own random Stats Shard rolls. It does not force numeric values.
- The focus search finds the highest raw value within the chosen seed limit, not a guaranteed global maximum or a guaranteed displayed percentage. For example, to seek Electric Damage above 6% in the tooltip, select only Electric Damage, inspect the candidate and Apply it, then check the displayed percentage in the game.
- The optional bonus filter samples 2,000 vanilla rolls when you press **Filter compatible bonuses**. Changing the Cyberware item does not start this scan. It can exclude unlikely combinations early, but a combination missing from the sample is not proven impossible. All 36 individual bonus types were observed on Self-ICE in prior tests; the important restriction is which types occur together.
- The game may display different numbers from the raw shard values because other modifiers and scaling apply. The **Current item** list is read from the equipped shard and can be refreshed at any time. It is separate from the three candidate bonuses.
- If several matching seeds have identical raw values, changing the seed cannot improve those raw values in that scanned range. The picker reports this instead of claiming a better roll.
- **Apply roll** installs the selected vanilla Stats Shard into the equipped item and checks the equipped shard over the next few seconds. If the bonus types change but the game's shard ID cannot be matched to the requested ID, the picker reports that distinction rather than saying installation failed. Use **Recheck apply** if the result appears later, and inspect the game's tooltip before saving.
- Search progress and previously shown results are not saved. Every search starts scanning at seed 0, but repeated searches with the same settings skip results already shown in this session. With one selected bonus, the next result has a lower raw value; with two or three, it has a different combination of selected raw values. Rounded values in the game tooltip may still look the same.
- Item labels come from internal game record names to remain in English even when the game's interface uses another language. Some names may differ from the official English labels.
