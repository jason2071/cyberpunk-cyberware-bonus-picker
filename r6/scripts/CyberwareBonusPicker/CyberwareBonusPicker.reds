// CET picker: inspect equipped items and apply one vanilla stats shard to the selected item.
@addMethod(PlayerPuppet)
public func CBPGetArea(area: Int32) -> gamedataEquipmentArea {
  switch (area) {
    case 0: return gamedataEquipmentArea.FrontalCortexCW;
    case 1: return gamedataEquipmentArea.EyesCW;
    case 2: return gamedataEquipmentArea.SystemReplacementCW;
    case 3: return gamedataEquipmentArea.CardiovascularSystemCW;
    case 4: return gamedataEquipmentArea.ImmuneSystemCW;
    case 5: return gamedataEquipmentArea.NervousSystemCW;
    case 6: return gamedataEquipmentArea.IntegumentarySystemCW;
    case 7: return gamedataEquipmentArea.MusculoskeletalSystemCW;
    case 8: return gamedataEquipmentArea.HandsCW;
    case 9: return gamedataEquipmentArea.ArmsCW;
    case 10: return gamedataEquipmentArea.LegsCW;
    case 11: return gamedataEquipmentArea.AbilityCW;
  };
  return gamedataEquipmentArea.FrontalCortexCW;
}

@addMethod(PlayerPuppet)
public func CBPGetStat(bonus: Int32) -> gamedataStatType {
  switch (bonus) {
    case 0: return gamedataStatType.HealthModifierHelper;
    case 1: return gamedataStatType.ItemArmorModifierHelper;
    case 2: return gamedataStatType.CarryCapacityModifierHelper;
    case 3: return gamedataStatType.MeleeResistanceModifierHelper;
    case 4: return gamedataStatType.StealthHitDamageBonusModifierHelper;
    case 5: return gamedataStatType.MeleeDamagePercentBonusModifierHelper;
    case 6: return gamedataStatType.ReloadSpeedPercentBonusModifierHelper;
    case 7: return gamedataStatType.HealingItemsEffectPercentBonusModifierHelper;
    case 8: return gamedataStatType.HealthGeneralRegenRateMultModifierHelper;
    case 9: return gamedataStatType.ExplosionDamagePercentBonusModifierHelper;
    case 10: return gamedataStatType.ExplosionResistanceModifierHelper;
    case 11: return gamedataStatType.BonusQuickHackDamageModifierHelper;
    case 12: return gamedataStatType.HealingItemsChargesRegenMultModifierHelper;
    case 13: return gamedataStatType.RecoilPercentBonusModifierHelper;
    case 14: return gamedataStatType.DamageOverTimeResistanceModifierHelper;
    case 15: return gamedataStatType.RamOnKillModifierHelper;
    case 16: return gamedataStatType.BonusRicochetDamageModifierHelper;
    case 17: return gamedataStatType.GrenadesChargesRegenMultModifierHelper;
    case 18: return gamedataStatType.ADSSpeedPercentBonusModifierHelper;
    case 19: return gamedataStatType.HeadshotDamageMultiplierModifierHelper;
    case 20: return gamedataStatType.VisibilityReductionModifierHelper;
    case 21: return gamedataStatType.DamageOverTimePercentBonusModifierHelper;
    case 22: return gamedataStatType.CritChanceBonusModifierHelper;
    case 23: return gamedataStatType.CritDamageBonusModifierHelper;
    case 24: return gamedataStatType.MitigationChanceModifierHelper;
    case 25: return gamedataStatType.MitigationStrengthModifierHelper;
    case 26: return gamedataStatType.BonusPercentDamageToEnemiesBelowHalfHealthModifierHelper;
    case 27: return gamedataStatType.BonusPercentDamageToEnemiesAtFullHealthModifierHelper;
    case 28: return gamedataStatType.PercentDamageReductionFromPoisonedEnemiesModifierHelper;
    case 29: return gamedataStatType.DodgeStaminaCostReductionModifierHelper;
    case 30: return gamedataStatType.ChemicalDamagePercentBonusModifierHelper;
    case 31: return gamedataStatType.ThermalDamagePercentBonusModifierHelper;
    case 32: return gamedataStatType.ElectricDamagePercentBonusModifierHelper;
    case 33: return gamedataStatType.HealOnKillingBleedingTargetModifierHelper;
    case 34: return gamedataStatType.BonusCritChanceVsElectrocutedEnemiesModifierHelper;
    case 35: return gamedataStatType.BonusPercentDamageVsBurningEnemiesModifierHelper;
  };
  return gamedataStatType.ItemArmorModifierHelper;
}

@addMethod(PlayerPuppet)
public func CBPGetItem(area: Int32, slot: Int32) -> ItemID {
  if area < 0 || area >= 12 || slot < 0 || slot >= 8 { return ItemID.None(); }
  let equipment = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
  return equipment.GetPlayerData(this).GetItemInEquipSlot(this.CBPGetArea(area), slot);
}

@addMethod(PlayerPuppet)
public func CBPItemName(area: Int32, slot: Int32) -> String {
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return ""; }
  return TDBID.ToStringDEBUG(ItemID.GetTDBID(itemID));
}

@addMethod(PlayerPuppet)
public func CBPShardRecord(itemID: ItemID) -> TweakDBID {
  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);
  if itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {
    let shard: InnerItemData;
    itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
    return InnerItemData.GetStaticData(shard).GetRecordID();
  }
  let quality = RPGManager.GetItemRecord(itemID).QualityHandle().Value();
  if quality >= 8 { return t"Items.CyberwareStatsShardLegendary"; }
  if quality >= 6 { return t"Items.CyberwareStatsShardEpic"; }
  if quality >= 4 { return t"Items.CyberwareStatsShardRare"; }
  if quality >= 2 { return t"Items.CyberwareStatsShardUncommon"; }
  return t"Items.CyberwareStatsShardCommon";
}

@addMethod(PlayerPuppet)
public func CBPShardRecordName(area: Int32, slot: Int32) -> String {
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return ""; }
  return TDBID.ToStringDEBUG(this.CBPShardRecord(itemID));
}

@addMethod(PlayerPuppet)
public func CBPValid(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32) -> Bool {
  return area >= 0 && area < 12 && slot >= 0 && slot < 8
    && a >= 0 && a < 36 && b >= 0 && b < 36 && c >= 0 && c < 36
    && a != b && a != c && b != c && ItemID.IsValid(this.CBPGetItem(area, slot));
}

@addMethod(PlayerPuppet)
public func CBPMatches(itemID: ItemID, record: TweakDBID, a: gamedataStatType, b: gamedataStatType, c: gamedataStatType, seed: Uint32) -> Bool {
  let params: ItemModParams;
  params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));
  params.quantity = 1;
  let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);
  ArrayPush(params.customPartsToInstall, shardID);
  let preview = Inventory.CreateItemData(params, this);
  if !IsDefined(preview) || !preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return false; }
  let shard: InnerItemData;
  preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
  return InnerItemData.GetStatValueByType(shard, a) > 0.0
    && InnerItemData.GetStatValueByType(shard, b) > 0.0
    && InnerItemData.GetStatValueByType(shard, c) > 0.0;
}

@addMethod(PlayerPuppet)
public func CBPSeedBonusValue(area: Int32, slot: Int32, bonus: Int32, seed: Uint32) -> Float {
  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 { return 0.0; }
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return 0.0; }
  let params: ItemModParams;
  params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));
  params.quantity = 1;
  let shardID = ItemID.CreateFromSeedWithOffset(this.CBPShardRecord(itemID), seed, 0);
  ArrayPush(params.customPartsToInstall, shardID);
  let preview = Inventory.CreateItemData(params, this);
  if !IsDefined(preview) || !preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return 0.0; }
  let shard: InnerItemData;
  preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
  return InnerItemData.GetStatValueByType(shard, this.CBPGetStat(bonus));
}

@addMethod(PlayerPuppet)
public func CBPCurrentBonusValue(area: Int32, slot: Int32, bonus: Int32) -> Float {
  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 { return 0.0; }
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return 0.0; }
  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);
  if !IsDefined(itemData) || !itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return 0.0; }
  let shard: InnerItemData;
  itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
  return InnerItemData.GetStatValueByType(shard, this.CBPGetStat(bonus));
}

@addMethod(PlayerPuppet)
public func CBPCurrentShardIsSeed(area: Int32, slot: Int32, seed: Uint32) -> Bool {
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return false; }
  let itemData = GameInstance.GetTransactionSystem(this.GetGame()).GetItemData(this, itemID);
  if !IsDefined(itemData) || !itemData.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") { return false; }
  let shard: InnerItemData;
  itemData.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
  let actual = InnerItemData.GetItemID(shard);
  let expected = ItemID.CreateFromSeedWithOffset(this.CBPShardRecord(itemID), seed, 0);
  return Equals(actual, expected);
}

@addMethod(PlayerPuppet)
public func CBPObserveBonusPatterns(area: Int32, slot: Int32, startSeed: Uint32, count: Int32) -> String {
  let itemID = this.CBPGetItem(area, slot);
  if !ItemID.IsValid(itemID) { return ""; }
  let record = this.CBPShardRecord(itemID);
  let seen: array<Bool>;
  let patterns: array<Bool>;
  let i: Int32 = 0;
  while i < 36 { ArrayPush(seen, false); i += 1; }
  i = 0;
  while i < 64 { ArrayPush(patterns, false); i += 1; }
  let n: Int32 = 0;
  while n < count {
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));
    params.quantity = 1;
    let shardID = ItemID.CreateFromSeedWithOffset(record, startSeed + Cast<Uint32>(n), 0);
    ArrayPush(params.customPartsToInstall, shardID);
    let preview = Inventory.CreateItemData(params, this);
    if IsDefined(preview) && preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {
      let shard: InnerItemData;
      preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
      let simple: Int32 = 0; let advanced: Int32 = 0; let specialized: Int32 = 0;
      i = 0;
      while i < 36 {
        if InnerItemData.GetStatValueByType(shard, this.CBPGetStat(i)) > 0.0 {
          seen[i] = true;
          if i < 10 { simple += 1; } else { if i < 22 { advanced += 1; } else { specialized += 1; } }
        }
        i += 1;
      }
      if simple < 4 && advanced < 4 && specialized < 4 { patterns[simple * 16 + advanced * 4 + specialized] = true; }
    }
    n += 1;
  }
  let mask: String = "";
  i = 0;
  while i < 36 { mask += seen[i] ? "1" : "0"; i += 1; }
  mask += "|";
  i = 0;
  while i < 64 { mask += patterns[i] ? "1" : "0"; i += 1; }
  return mask;
}

@addMethod(PlayerPuppet)
public func CBPFind(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32, startSeed: Uint32, count: Int32) -> Int32 {
  if !this.CBPValid(area, slot, a, b, c) { return -2; }
  let itemID = this.CBPGetItem(area, slot);
  let shardRecord = this.CBPShardRecord(itemID);
  let first = this.CBPGetStat(a); let second = this.CBPGetStat(b); let third = this.CBPGetStat(c);
  let i: Int32 = 0;
  while i < count {
    let seed = startSeed + Cast<Uint32>(i);
    if this.CBPMatches(itemID, shardRecord, first, second, third, seed) { return Cast<Int32>(seed); }
    i += 1;
  }
  return -1;
}

@addMethod(PlayerPuppet)
public func CBPFindTwo(area: Int32, slot: Int32, a: Int32, b: Int32, startSeed: Uint32, count: Int32) -> Int32 {
  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || a < 0 || a >= 36 || b < 0 || b >= 36 || a == b || !ItemID.IsValid(this.CBPGetItem(area, slot)) { return -2; }
  let itemID = this.CBPGetItem(area, slot);
  let record = this.CBPShardRecord(itemID);
  let first = this.CBPGetStat(a); let second = this.CBPGetStat(b);
  let i: Int32 = 0;
  while i < count {
    let seed = startSeed + Cast<Uint32>(i);
    if this.CBPMatches(itemID, record, first, second, first, seed) { return Cast<Int32>(seed); }
    i += 1;
  }
  return -1;
}

@addMethod(PlayerPuppet)
public func CBPFindBestOne(area: Int32, slot: Int32, bonus: Int32, startSeed: Uint32, count: Int32, ceiling: Float, excluded: String) -> String {
  if area < 0 || area >= 12 || slot < 0 || slot >= 8 || bonus < 0 || bonus >= 36 || !ItemID.IsValid(this.CBPGetItem(area, slot)) { return "-2|0"; }
  let itemID = this.CBPGetItem(area, slot);
  let record = this.CBPShardRecord(itemID);
  let stat = this.CBPGetStat(bonus);
  let bestSeed: Int32 = -1;
  let bestValue: Float = 0.0;
  let matched: Int32 = 0;
  let i: Int32 = 0;
  while i < count {
    let seed = startSeed + Cast<Uint32>(i);
    let params: ItemModParams;
    params.itemID = ItemID.FromTDBID(ItemID.GetTDBID(itemID));
    params.quantity = 1;
    let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);
    ArrayPush(params.customPartsToInstall, shardID);
    let preview = Inventory.CreateItemData(params, this);
    if IsDefined(preview) && preview.HasPartInSlot(t"AttachmentSlots.StatsShardSlot") {
      let shard: InnerItemData;
      preview.GetItemPart(shard, t"AttachmentSlots.StatsShardSlot");
      let value = InnerItemData.GetStatValueByType(shard, stat);
      if value > 0.0 { matched += 1; }
      if value > bestValue && value < ceiling && !StrContains(excluded, "," + ToString(seed) + ",") { bestValue = value; bestSeed = Cast<Int32>(seed); }
    }
    i += 1;
  }
  return ToString(bestSeed) + "|" + ToString(matched);
}

@addMethod(ItemModificationSystem)
public func CBPInstallShard(owner: ref<GameObject>, itemID: ItemID, shardID: ItemID) -> Bool {
  return this.InstallItemPart(owner, itemID, shardID, t"AttachmentSlots.StatsShardSlot");
}

@addMethod(PlayerPuppet)
public func CBPApply(area: Int32, slot: Int32, a: Int32, b: Int32, c: Int32, seed: Uint32) -> Bool {
  if !this.CBPValid(area, slot, a, b, c) { return false; }
  let itemID = this.CBPGetItem(area, slot);
  let record = this.CBPShardRecord(itemID);
  if !this.CBPMatches(itemID, record, this.CBPGetStat(a), this.CBPGetStat(b), this.CBPGetStat(c), seed) { return false; }
  let shardID = ItemID.CreateFromSeedWithOffset(record, seed, 0);
  let ts = GameInstance.GetTransactionSystem(this.GetGame());
  ts.GiveItem(this, shardID, 1);
  let mods = GameInstance.GetScriptableSystemsContainer(this.GetGame()).Get(n"ItemModificationSystem") as ItemModificationSystem;
  if !IsDefined(mods) { return false; }
  return mods.CBPInstallShard(this, itemID, shardID);
}
