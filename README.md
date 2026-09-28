# Cyberware Bonus Picker (CET UI)

Choose one, two, or three vanilla secondary bonus types on one equipped Cyberware item. With one type selected, the picker maximizes that bonus and accepts any other two. With two or three selected, it requires those types and lets you choose either Priority or Product ranking. The picker can be opened anywhere through Cyber Engine Tweaks; no Ripperdoc or Mod Settings menu is required.

## Requirements

- Cyber Engine Tweaks
- redscript
- A backup save before the first use

## Use

1. Load a save, open CET, and press **Refresh items**.
2. Select an equipped Cyberware item. The search box stays above the single scrolling item list. Switching to another item keeps your selected bonus types and their priority order; it clears only the previous item's candidate roll.
3. Tick **one** type to maximize it while allowing any other two bonuses. Tick **two** or **three** types to require those types. Select the **Priority** radio option to rank bonus 1 first, then bonus 2 and 3 as tie breakers, or **Product** to multiply their values. The ranking choice is saved in `picker_settings.json`. Your selections and **Clear bonuses** stay fixed above the only scrolling bonus list. **Filter compatible bonuses** is optional; press it only when you want to narrow the list for the selected item.
4. The seed limit defaults to **100,000**. Enter another limit from 1,000 to 1,000,000 and press **Set limit** before searching. Every press of **Find highest focus bonus** or **Find best roll** starts again at seed 0 and scans the entire selected limit. With one type selected, ranking mode does not affect the result. With two or three types selected, the picker requires those types and ranks matching rolls by the chosen method. The **matches** counter shows how many seeds contained all selected types. Press **Stop** to cancel.
5. Check **Current item** for the bonus types on the equipped shard. Review the candidate's raw shard values, then press **Apply roll**. Raw values are shown without a percent sign because they are used only to rank seeds; they are not the final numbers shown in the game tooltip. The picker confirms either the exact seed ID or a change to the three selected bonus types and distinguishes these results in its status.
6. Save and reload, then check the displayed bonuses in the game. Change the bonus selection, ranking mode, or seed limit to try a different search.

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
- Search progress is not saved. Every search starts from seed 0, even after changing the selected Cyberware or loading a save.
- Item labels come from internal game record names to remain in English even when the game's interface uses another language. Some names may differ from the official English labels.
