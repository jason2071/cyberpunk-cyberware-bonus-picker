"""Build the CET picker from the game's vanilla random Cyberware bonuses."""
from pathlib import Path
import argparse
import json
import re

HERE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description="Regenerate the Cyberware Bonus Picker mod from installed Cyberpunk 2077 tweak data.")
parser.add_argument("--game-dir", required=True, type=Path, help="Cyberpunk 2077 installation directory")
GAME = parser.parse_args().game_dir.resolve()
GROUPS = GAME / "tools/redmod/tweaks/base/gameplay/static_data/database/items/cyberware/variants/modifier_groups.tweak"
if not GROUPS.is_file():
    parser.error(f"Game tweak data not found: {GROUPS}")
CATALOG = {row["record"]: row["stat"] for row in json.loads((HERE / "cyberware_vanilla_bonus_catalog.json").read_text())}
source = GROUPS.read_text(encoding="utf-8")
bonuses = []
for group in ("SimpleCyberwareModifiers", "AdvancedCyberwareModifiers", "SpecializedCyberwareModifiers"):
    start = source.index(group + " : ")
    end = source.index("\n}", start)
    bonuses.extend(re.findall(r'"(Modifiers\.[A-Za-z0-9]+Random)"', source[start:end]))
assert len(bonuses) == 36 and len(set(bonuses)) == 36
assert bonuses[32] == "Modifiers.ElectricDamagePercentBonusRandom"

areas = [
    ("Frontal Cortex", "FrontalCortexCW"), ("Eyes", "EyesCW"),
    ("Operating System", "SystemReplacementCW"), ("Circulatory System", "CardiovascularSystemCW"),
    ("Immune System", "ImmuneSystemCW"), ("Nervous System", "NervousSystemCW"),
    ("Integumentary System", "IntegumentarySystemCW"), ("Skeleton", "MusculoskeletalSystemCW"),
    ("Hands", "HandsCW"), ("Arms", "ArmsCW"), ("Legs", "LegsCW"), ("Extra Ability", "AbilityCW"),
]

def label(record):
    name = record.split(".", 1)[1].removesuffix("Random")
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name).replace("Quick Hack", "Quickhack").replace("Percent Bonus", "Bonus %")

modifier_source = (GROUPS.parent / "modifiers.tweak").read_text(encoding="utf-8")
percent_bonuses = []
for index, record in enumerate(bonuses):
    name = record.split(".", 1)[1]
    body = re.search(rf"^{name} : CyberwareRandomStatModifier\s*\{{(.*?)\}}", modifier_source, re.M | re.S)
    if not body:
        raise ValueError(f"Missing random modifier: {record}")
    maximum = re.search(r"\bmax\s*=\s*([0-9.]+)f;", body.group(1))
    if not maximum:
        raise ValueError(f"Missing maximum: {record}")
    if float(maximum.group(1)) <= 1.0 or "%" in label(record):
        percent_bonuses.append(index)

reds = [
    "// CET picker: inspect equipped items and apply one vanilla stats shard to the selected item.",
    "@addMethod(PlayerPuppet)",
    "public func CBPGetArea(area: Int32) -> gamedataEquipmentArea {",
    "  switch (area) {",
]
reds += [f"    case {i}: return gamedataEquipmentArea.{game};" for i, (_, game) in enumerate(areas)]
reds += ["  };", "  return gamedataEquipmentArea.FrontalCortexCW;", "}", "",
    "@addMethod(PlayerPuppet)", "public func CBPGetStat(bonus: Int32) -> gamedataStatType {", "  switch (bonus) {"]
reds += [f"    case {i}: return gamedataStatType.{CATALOG[record]};" for i, record in enumerate(bonuses)]
reds += ["  };", "  return gamedataStatType.ItemArmorModifierHelper;", "}", "",
    "@addMethod(PlayerPuppet)", "public func CBPGetItem(area: Int32, slot: Int32) -> ItemID {",
    "  if area < 0 || area >= 12 || slot < 0 || slot >= 8 { return ItemID.None(); }",
    '  let equipment = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;',
    "  return equipment.GetPlayerData(this).GetItemInEquipSlot(this.CBPGetArea(area), slot);", "}", "",
    "@addMethod(PlayerPuppet)", "public func CBPItemName(area: Int32, slot: Int32) -> String {",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  if !ItemID.IsValid(itemID) { return \"\"; }",
    "  return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));", "}", "",
    "@addMethod(PlayerPuppet)", "public func CBPShardRecord(itemID: ItemID) -> TweakDBID {",
    "  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);",
    '  if itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {',
    "    let shard: InnerItemData;",
    '    itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "    return InnerItemData.GetStaticData(shard).GetRecordID();", "  }",
    "  let quality = RPGManager.GetItemRecord(itemID).QualityHandle().Value();",
    '  if quality >= 8 { return t"Items.CyberwareStatsShardLegendary"; }',
    '  if quality >= 6 { return t"Items.CyberwareStatsShardEpic"; }',
    '  if quality >= 4 { return t"Items.CyberwareStatsShardRare"; }',
    '  if quality >= 2 { return t"Items.CyberwareStatsShardUncommon"; }',
    '  return t"Items.CyberwareStatsShardCommon";', "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPShardRecordName(area: Int32, slot: Int32) -> String {",
    "  let itemID = this.CBPGetItem(area, slot);",
    '  if !ItemID.IsValid(itemID) { return ""; }',
    "  return TDBID.ToStringDEBUG(this.CBPShardRecord(itemID));",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPValid(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32) -> Bool {",
    "  return area >= 0 && area < 12 && slot >= 0 && slot < 8",
    "    && a >= 0 && a < 36 && b >= 0 && b < 36 && c >= 0 && c < 36",
    "    && a != b && a != c && b != c && ItemID.IsValid(this.CBPGetItem(area, slot));", "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPMatches(itemID: ItemID, record: TweakDBID, a: gamedataStatType, b: gamedataStatType, c: gamedataStatType, seed: Uint32) -> Bool {",
    "  let params: ItemModParams;",
    "  params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));",
    "  params.quantity = 1;",
    "  let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);",
    "  ArrayPush(params.customPartsToInstall, shardID);",
    "  let preview = Inventory.CreateItemData(params, this);",
    '  if !IsDefined(preview) || !preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return false; }',
    "  let shard: InnerItemData;",
    '  preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "  return InnerItemData.GetStatValueByType(shard, a) > 0.0",
    "    && InnerItemData.GetStatValueByType(shard, b) > 0.0",
    "    && InnerItemData.GetStatValueByType(shard, c) > 0.0;", "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPSeedBonusValue(area: Int32, slot: Int32, bonus: Int32, seed: Uint32) -> Float {",
    "  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 { return 0.0; }",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  if !ItemID.IsValid(itemID) { return 0.0; }",
    "  let params: ItemModParams;",
    "  params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));",
    "  params.quantity = 1;",
    "  let shardID = ItemID.CreateFromSeedWithOffset(this.CBPShardRecord(itemID), seed, 0);",
    "  ArrayPush(params.customPartsToInstall, shardID);",
    "  let preview = Inventory.CreateItemData(params, this);",
    '  if !IsDefined(preview) || !preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return 0.0; }',
    "  let shard: InnerItemData;",
    '  preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "  return InnerItemData.GetStatValueByType(shard, this.CBPGetStat(bonus));",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPCurrentBonusValue(area: Int32, slot: Int32, bonus: Int32) -> Float {",
    "  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 { return 0.0; }",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  if !ItemID.IsValid(itemID) { return 0.0; }",
    "  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);",
    '  if !IsDefined(itemData) || !itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return 0.0; }',
    "  let shard: InnerItemData;",
    '  itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "  return InnerItemData.GetStatValueByType(shard, this.CBPGetStat(bonus));",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPCurrentShardIsSeed(area: Int32, slot: Int32, seed: Uint32) -> Bool {",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  if !ItemID.IsValid(itemID) { return false; }",
    "  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);",
    '  if !IsDefined(itemData) || !itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return false; }',
    "  let shard: InnerItemData;",
    '  itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "  let actual = InnerItemData.GetItemID(shard);",
    "  let expected = ItemID.CreateFromSeedWithOffset(this.CBPShardRecord(itemID), seed, 0);",
    "  return Equals(actual, expected);",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPObserveBonusPatterns(area: Int32, slot: Int32, startSeed: Uint32, count: Int32) -> String {",
    "  let itemID = this.CBPGetItem(area, slot);",
    '  if !ItemID.IsValid(itemID) { return ""; }',
    "  let record = this.CBPShardRecord(itemID);",
    "  let seen: array<Bool>;",
    "  let patterns: array<Bool>;",
    "  let i: Int32 = 0;",
    "  while i < 36 { ArrayPush(seen, false); i += 1; }",
    "  i = 0;",
    "  while i < 64 { ArrayPush(patterns, false); i += 1; }",
    "  let n: Int32 = 0;",
    "  while n < count {",
    "    let params: ItemModParams;",
    "    params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));",
    "    params.quantity = 1;",
    "    let shardID = ItemID.CreateFromSeedWithOffset(record, startSeed + Cast<Uint32>(n), 0);",
    "    ArrayPush(params.customPartsToInstall, shardID);",
    "    let preview = Inventory.CreateItemData(params, this);",
    '    if IsDefined(preview) && preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {',
    "      let shard: InnerItemData;",
    '      preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "      let simple: Int32 = 0; let advanced: Int32 = 0; let specialized: Int32 = 0;",
    "      i = 0;",
    "      while i < 36 {",
    "        if InnerItemData.GetStatValueByType(shard, this.CBPGetStat(i)) > 0.0 {",
    "          seen[i] = true;",
    "          if i < 10 { simple += 1; } else { if i < 22 { advanced += 1; } else { specialized += 1; } }",
    "        }",
    "        i += 1;",
    "      }",
    "      if simple < 4 && advanced < 4 && specialized < 4 { patterns[simple * 16 + advanced * 4 + specialized] = true; }",
    "    }",
    "    n += 1;",
    "  }",
    '  let mask: String = "";',
    "  i = 0;",
    '  while i < 36 { mask += seen[i] ? "1" : "0"; i += 1; }',
    '  mask += "|";',
    "  i = 0;",
    '  while i < 64 { mask += patterns[i] ? "1" : "0"; i += 1; }',
    "  return mask;",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPFind(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32, startSeed: Uint32, count: Int32) -> Int32 {",
    "  if !this.CBPValid(area, slot, a, b, c) { return -2; }",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  let shardRecord = this.CBPShardRecord(itemID);",
    "  let first = this.CBPGetStat(a); let second = this.CBPGetStat(b); let third = this.CBPGetStat(c);",
    "  let i: Int32 = 0;",
    "  while i < count {",
    "    let seed = startSeed + Cast<Uint32>(i);",
    "    if this.CBPMatches(itemID, shardRecord, first, second, third, seed) { return Cast<Int32>(seed); }",
    "    i += 1;", "  }", "  return -1;", "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPFindTwo(area: Int32, slot: Int32, a: Int32, b: Int32, startSeed: Uint32, count: Int32) -> Int32 {",
    "  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || a < 0 || a >= 36 || b < 0 || b >= 36 || a == b || !ItemID.IsValid(this.CBPGetItem(area, slot)) { return -2; }",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  let record = this.CBPShardRecord(itemID);",
    "  let first = this.CBPGetStat(a); let second = this.CBPGetStat(b);",
    "  let i: Int32 = 0;",
    "  while i < count {",
    "    let seed = startSeed + Cast<Uint32>(i);",
    "    if this.CBPMatches(itemID, record, first, second, first, seed) { return Cast<Int32>(seed); }",
    "    i += 1;",
    "  }",
    "  return -1;",
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPFindBestOne(area: Int32, slot: Int32, bonus: Int32, startSeed: Uint32, count: Int32, ceiling: Float, excluded: String) -> String {",
    '  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 || !ItemID.IsValid(this.CBPGetItem(area, slot)) { return "-2|0"; }',
    "  let itemID = this.CBPGetItem(area, slot);",
    "  let record = this.CBPShardRecord(itemID);",
    "  let stat = this.CBPGetStat(bonus);",
    "  let bestSeed: Int32 = -1;",
    "  let bestValue: Float = 0.0;",
    "  let matched: Int32 = 0;",
    "  let i: Int32 = 0;",
    "  while i < count {",
    "    let seed = startSeed + Cast<Uint32>(i);",
    "    let params: ItemModParams;",
    "    params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));",
    "    params.quantity = 1;",
    "    let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);",
    "    ArrayPush(params.customPartsToInstall, shardID);",
    "    let preview = Inventory.CreateItemData(params, this);",
    '    if IsDefined(preview) && preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {',
    "      let shard: InnerItemData;",
    '      preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");',
    "      let value = InnerItemData.GetStatValueByType(shard, stat);",
    "      if value > 0.0 { matched += 1; }",
    '      if value > bestValue && value < ceiling && !StrContains(excluded, "," + ToString(seed) + ",") { bestValue = value; bestSeed = Cast<Int32>(seed); }',
    "    }",
    "    i += 1;",
    "  }",
    '  return ToString(bestSeed) + "|" + ToString(matched);',
    "}", "",
    "@addMethod(ItemModificationSystem)",
    "public func CBPInstallShard(owner: ref<GameObject>, itemID: ItemID, shardID: ItemID) -> Bool {",
    '  return this.InstallItemPart(owner, itemID, shardID, t"AttachmentSlots.StatsShardSlot");',
    "}", "",
    "@addMethod(PlayerPuppet)",
    "public func CBPApply(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32, seed: Uint32) -> Bool {",
    "  if !this.CBPValid(area, slot, a, b, c) { return false; }",
    "  let itemID = this.CBPGetItem(area, slot);",
    "  let record = this.CBPShardRecord(itemID);",
    "  if !this.CBPMatches(itemID, record, this.CBPGetStat(a), this.CBPGetStat(b), this.CBPGetStat(c), seed) { return false; }",
    "  let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);",
    "  let ts = GameInstance.GetTransactionSystem(this.GetGame());",
    "  ts.GiveItem(this, shardID, 1);",
    '  let mods = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"ItemModificationSystem") as ItemModificationSystem;',
    "  if !IsDefined(mods) { return false; }",
    "  return mods.CBPInstallShard(this, itemID, shardID);", "}",
]

root = HERE
red_path = root / "r6/scripts/CyberwareBonusPicker/CyberwareBonusPicker.reds"
red_path.parent.mkdir(parents=True, exist_ok=True)
red_path.write_text("\n".join(reds) + "\n", encoding="utf-8")

lua_path = root / "bin/x64/plugins/cyber_engine_tweaks/mods/CyberwareBonusPicker/init.lua"
lua_path.parent.mkdir(parents=True, exist_ok=True)
lua = (HERE / "picker_init_template.lua").read_text(encoding="utf-8")
lua = lua.replace("__AREAS__", "{" + ", ".join(json.dumps(name) for name, _ in areas) + "}")
lua = lua.replace("__BONUSES__", "{" + ", ".join(json.dumps(label(record)) for record in bonuses) + "}")
lua = lua.replace("__PERCENT_BONUSES__", "{" + ", ".join(f"[{index}] = true" for index in percent_bonuses) + "}")
lua_path.write_text(lua, encoding="utf-8")
print(f"Generated CET picker: {len(areas)} areas, {len(bonuses)} bonuses")
