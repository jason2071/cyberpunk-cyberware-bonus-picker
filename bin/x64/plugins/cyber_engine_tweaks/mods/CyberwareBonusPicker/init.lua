-- CET picker for equipped cyberware. The game keeps the installed vanilla shard in the save.
local areas = {"Frontal Cortex", "Eyes", "Operating System", "Circulatory System", "Immune System", "Nervous System", "Integumentary System", "Skeleton", "Hands", "Arms", "Legs", "Extra Ability"}
local bonuses = {"Health", "Armor", "Carry Capacity", "Melee Resistance", "Stealth Hit Damage Bonus", "Melee Damage Bonus %", "Reload Speed Bonus %", "Healing Items Effect Bonus %", "Health Regen Percent", "Explosion Damage Bonus %", "Explosion Resistance", "Bonus Quickhack Damage", "Healing Items Charges Regen Mult", "Recoil Bonus %", "Damage Over Time Resistance", "Ram On Kill", "Bonus Ricochet Damage", "Grenades Charges Regen Mult", "ADSSpeed Bonus %", "Headshot Damage Multiplier", "Visibility Reduction", "Damage Over Time Bonus %", "Crit Chance", "Crit Damage", "Mitigation Chance", "Mitigation Strength", "Bonus Percent Damage To Enemies Below Half Health", "Bonus Percent Damage To Enemies At Full Health", "Percent Damage Reduction From Poisoned Enemies", "Dodge Stamina Cost Reduction", "Chemical Damage Bonus %", "Thermal Damage Bonus %", "Electric Damage Bonus %", "Heal On Killing Bleeding Target", "Bonus Crit Chance Vs Electrocuted Enemies", "Bonus Percent Damage Vs Burning Enemies"}
local percentBonuses = {[5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [11] = true, [12] = true, [13] = true, [15] = true, [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [35] = true}
local items, selected, choices = {}, 1, {}
local itemFilter, bonusFilter = "", ""
local overlayOpen, running, verifying = false, false, false
local foundSeed, foundValues, foundBonuses, beforeValues, afterValues = nil, nil, nil, nil, nil
local nextSeed, scanEnd, scanStart = 0, 0, 0
local batch, windowSize, hardLimit, seedLimitInput = 40, 60000, 100000, 100000
local target, bestSeed, bestValues, bestScore = nil, nil, nil, -1
local matches, minimums, maximums = 0, nil, nil
local verifyFrames, rollCursors = 0, {}
local status = "Load a save, then refresh equipped Cyberware."
local currentValues, valuesChanged
local observed, patterns, observedCount, patternCount = {}, {}, 0, 0
local analyzing, sampledSeeds, sampleLimit, sampleBatch = false, 0, 2000, 20
local equippedBonuses = {}
local beforeFingerprint = nil

local function say(message)
  status = message
  print("[CyberwareBonusPicker] " .. message)
end

local function loadCursors()
  local file = io.open("roll_cursor.json", "r")
  if not file then return end
  local contents = file:read("*a")
  file:close()
  local ok, saved = pcall(function() return json.decode(contents) end)
  if ok and type(saved) == "table" then rollCursors = saved end
end

local function saveCursors()
  local ok, encoded = pcall(function() return json.encode(rollCursors) end)
  if not ok then return end
  local file = io.open("roll_cursor.json", "w")
  if file then file:write(encoded); file:close() end
end

local function englishItemName(recordID)
  local raw = tostring(recordID):gsub("^Items%.", "")
  for _, tier in ipairs({"Legendary", "Epic", "Rare", "Uncommon", "Common"}) do
    raw = raw:gsub(tier .. "PlusPlus$", ""):gsub(tier .. "Plus$", ""):gsub(tier .. "$", "")
  end
  raw = raw:gsub("^Advanced", "")
  local aliases = {SelfIce = "Self-ICE", ExDisk = "Ex-Disk", Axolotl = "Axolotl"}
  if aliases[raw] then return aliases[raw] end
  return raw:gsub("([a-z])([A-Z])", "%1 %2"):gsub("([A-Z])([A-Z][a-z])", "%1 %2")
end

local function clearResult()
  running, verifying = false, false
  foundSeed, foundValues, foundBonuses, beforeValues, afterValues = nil, nil, nil, nil, nil
  target, bestSeed, bestValues, bestScore = nil, nil, nil, -1
  matches, minimums, maximums = 0, nil, nil
  beforeFingerprint = nil
end

local function refreshEquippedBonuses()
  equippedBonuses = {}
  local item, player = items[selected], Game.GetPlayer()
  if not item or not player then return end
  for index = 0, #bonuses - 1 do
    local ok, value = pcall(function() return player:CBPCurrentBonusValue(item.area, item.slot, index) end)
    if ok and type(value) == "number" and value > 0.00001 then
      equippedBonuses[#equippedBonuses + 1] = {index=index, value=value}
    end
  end
end

local function equippedFingerprint()
  local parts = {}
  for _, entry in ipairs(equippedBonuses) do
    parts[#parts + 1] = entry.index .. ":" .. string.format("%.5f", entry.value)
  end
  return table.concat(parts, ",")
end

local function equippedMatchesSelection()
  if not target or #equippedBonuses ~= 3 then return false end
  for _, chosen in ipairs(foundBonuses or target.choices) do
    local matched = false
    for _, entry in ipairs(equippedBonuses) do
      if entry.index == chosen then matched = true; break end
    end
    if not matched then return false end
  end
  return true
end

local function resetObservation()
  observed, patterns, observedCount, patternCount = {}, {}, 0, 0
  sampledSeeds, analyzing = 0, false
end

local function startObservation()
  resetObservation()
  analyzing = items[selected] ~= nil
end

local function refresh()
  clearResult()
  items, selected, choices = {}, 1, {}
  local player = Game.GetPlayer()
  if not player then say("Load a save first."); return end
  for area = 0, #areas - 1 do
    for slot = 0, 7 do
      local ok, name = pcall(function() return player:CBPItemName(area, slot) end)
      if ok and name and name ~= "" then
        items[#items + 1] = {area=area, slot=slot, label=areas[area + 1] .. " / " .. englishItemName(name)}
      end
    end
  end
  resetObservation()
  refreshEquippedBonuses()
  say("Found " .. tostring(#items) .. " equipped Cyberware items.")
end

local function choicePosition(index)
  for position, value in ipairs(choices) do
    if value == index then return position end
  end
  return nil
end

local function bonusGroup(index)
  if index < 10 then return 1 end
  if index < 22 then return 2 end
  return 3
end

local function patternAllows(values)
  if analyzing or patternCount == 0 then return true end
  local counts = {0, 0, 0}
  for _, value in ipairs(values) do counts[bonusGroup(value)] = counts[bonusGroup(value)] + 1 end
  for patternIndex in pairs(patterns) do
    local code = patternIndex - 1
    if math.floor(code / 16) >= counts[1]
      and math.floor((code % 16) / 4) >= counts[2]
      and code % 4 >= counts[3] then return true end
  end
  return false
end

local function bonusAvailable(candidate)
  if choicePosition(candidate) then return true end
  if analyzing then return true end
  if observedCount > 0 and not observed[candidate + 1] then return false end
  local selectedValues = {}
  local limit = math.min(#choices, 2)
  for i = 1, limit do selectedValues[#selectedValues + 1] = choices[i] end
  selectedValues[#selectedValues + 1] = candidate
  return patternAllows(selectedValues)
end

local function observeBatch()
  if not analyzing then return end
  local item, player = items[selected], Game.GetPlayer()
  if not item or not player then analyzing = false; return end
  local ok, result = pcall(function()
    return player:CBPObserveBonusPatterns(item.area, item.slot, sampledSeeds, sampleBatch)
  end)
  local bonusMask, groupMask
  if ok and type(result) == "string" then bonusMask, groupMask = result:match("^(.-)|(.+)$") end
  if not bonusMask or #bonusMask ~= 36 or not groupMask or #groupMask ~= 64 then
    analyzing = false
    say("Bonus filter unavailable; showing all bonuses.")
    return
  end
  for index = 1, 36 do
    if bonusMask:sub(index, index) == "1" and not observed[index] then
      observed[index] = true
      observedCount = observedCount + 1
    end
  end
  for index = 1, 64 do
    if groupMask:sub(index, index) == "1" and not patterns[index] then
      patterns[index] = true
      patternCount = patternCount + 1
    end
  end
  sampledSeeds = sampledSeeds + sampleBatch
  if sampledSeeds >= sampleLimit then
    analyzing = false
    say("Bonus filter ready for " .. item.label .. " (" .. observedCount .. " types, " .. patternCount .. " group patterns).")
  end
end

local function selectionKey(item)
  local sorted = {}
  for _, value in ipairs(choices) do sorted[#sorted + 1] = value end
  table.sort(sorted)
  return tostring(item.area) .. ":" .. tostring(item.slot) .. ":" .. item.label .. ":" .. table.concat(sorted, ",") .. ":" .. (#choices == 1 and "focus" or "best") .. ":" .. tostring(hardLimit)
end

local function startSearch()
  local item = items[selected]
  if not item or #choices < 1 or #choices > 3 then say("Select one, two, or three bonuses."); return end
  if analyzing then say("Please wait for the bonus filter to finish."); return end
  if not patternAllows(choices) then
    say("This bonus combination was not seen on this item. Untick one bonus.")
    return
  end
  clearResult()
  local key = selectionKey(item)
  local focusMode = #choices == 1
  nextSeed = focusMode and 0 or (tonumber(rollCursors[key]) or -1) + 1
  if nextSeed >= hardLimit then
    say("Search limit reached for this item and bonus set.")
    return
  end
  target = {area=item.area, slot=item.slot, key=key, mode=focusMode and "focus" or (#choices == 2 and "pair" or "triple"), choices={choices[1], choices[2], choices[3]}}
  scanStart = nextSeed
  scanEnd = focusMode and hardLimit or math.min(nextSeed + windowSize, hardLimit)
  running = true
  say(focusMode and ("Finding the highest " .. bonuses[choices[1] + 1] .. " within " .. hardLimit .. " seeds.") or ("Searching vanilla rolls for " .. item.label .. "."))
end

local function score(values)
  local product = 1
  for _, value in ipairs(values) do product = product * value end
  return product
end

local function resolveFocusCandidate(player)
  foundBonuses, foundValues = {}, {}
  for bonus = 0, #bonuses - 1 do
    local value = player:CBPSeedBonusValue(target.area, target.slot, bonus, bestSeed)
    if value > 0.00001 then
      foundBonuses[#foundBonuses + 1] = bonus
      foundValues[#foundValues + 1] = value
    end
  end
  local selectedPresent = true
  for _, selectedBonus in ipairs(target.choices) do
    local found = false
    for _, bonus in ipairs(foundBonuses) do
      if bonus == selectedBonus then found = true; break end
    end
    if not found then selectedPresent = false; break end
  end
  if #foundBonuses ~= 3 or not selectedPresent then
    foundSeed, foundValues, foundBonuses = nil, nil, nil
    say("Best seed did not resolve to exactly three bonuses. No item changed.")
    return false
  end
  return true
end

local function scanBatch()
  if not running or not target then return end
  local player = Game.GetPlayer()
  if not player then running = false; say("Load a save first."); return end
  local last = math.min(nextSeed + (target.mode == "focus" and 80 or batch), scanEnd)
  local ok, failure = pcall(function()
    if target.mode == "focus" then
      local result = player:CBPFindBestOne(target.area, target.slot, target.choices[1], nextSeed, last - nextSeed)
      local seedText, countText = tostring(result):match("^(%-?%d+)|(%d+)$")
      if not seedText then error("Could not read focus search result") end
      local seed = tonumber(seedText)
      matches = matches + tonumber(countText)
      if seed == -2 then error("Selected item or focus bonus is invalid") end
      if seed >= 0 then
        local value = player:CBPSeedBonusValue(target.area, target.slot, target.choices[1], seed)
        if value > bestScore then bestSeed, bestScore = seed, value end
      end
      return
    end
    local cursor = nextSeed
    while cursor < last do
      local c = target.choices
      local seed
      if target.mode == "pair" then
        seed = player:CBPFindTwo(target.area, target.slot, c[1], c[2], cursor, last - cursor)
      else
        seed = player:CBPFind(target.area, target.slot, c[1], c[2], c[3], cursor, last - cursor)
      end
      if seed == -2 then error("Selected item or bonuses are invalid") end
      if seed < 0 then break end
      local values = {}
      for _, bonus in ipairs(c) do
        values[#values + 1] = player:CBPSeedBonusValue(target.area, target.slot, bonus, seed)
      end
      matches = matches + 1
      if not minimums then
        minimums, maximums = {}, {}
        for i = 1, #values do minimums[i], maximums[i] = values[i], values[i] end
      else
        for i = 1, #values do
          minimums[i] = math.min(minimums[i], values[i])
          maximums[i] = math.max(maximums[i], values[i])
        end
      end
      local valueScore = score(values)
      if valueScore > bestScore then
        bestSeed, bestValues, bestScore = seed, values, valueScore
      end
      cursor = seed + 1
    end
  end)
  if not ok then running = false; say("Search failed: " .. tostring(failure)); return end
  nextSeed = last
  if nextSeed < scanEnd then return end
  if bestSeed then
    running, foundSeed = false, bestSeed
    if target.mode ~= "triple" then
      local resolved, reason = pcall(function() return resolveFocusCandidate(player) end)
      if not resolved then say("Could not read the best roll: " .. tostring(reason)); return end
      if not reason then return end
    else
      foundBonuses, foundValues = target.choices, bestValues
    end
    local readOk, current = pcall(function() return currentValues(player) end)
    if readOk then beforeValues = current end
    if target.mode ~= "focus" then
      rollCursors[target.key] = scanEnd - 1
      saveCursors()
    end
    if target.mode == "focus" then
      say("Highest " .. bonuses[target.choices[1] + 1] .. " found within " .. hardLimit .. " seeds. Check the game tooltip after Apply.")
    elseif target.mode == "pair" then
      say("Best of " .. tostring(matches) .. " matching two-bonus rolls in this range. Review the third bonus before Apply.")
    elseif beforeValues and valuesChanged(beforeValues, foundValues) then
      say("Best of " .. tostring(matches) .. " matching rolls. Compare the equipped values before Apply.")
    else
      say("Best matching roll has the same raw values as the equipped item in this range.")
    end
  elseif scanEnd < hardLimit then
    scanEnd = math.min(scanEnd + windowSize, hardLimit)
    say("No matching roll yet. Continuing search automatically.")
  else
    running = false
    rollCursors[target.key] = scanEnd - 1
    saveCursors()
    say("No matching roll found within the search limit. Try another bonus set.")
  end
end

currentValues = function(player)
  local c = target.choices
  local values = {}
  for _, bonus in ipairs(c) do
    values[#values + 1] = player:CBPCurrentBonusValue(target.area, target.slot, bonus)
  end
  return values
end

valuesChanged = function(a, b)
  if not a or not b then return false end
  if #a ~= #b then return true end
  for i = 1, #b do if math.abs(a[i] - b[i]) > 0.00001 then return true end end
  return false
end

local function formatValue(index, value)
  return string.format("%.4f", value)
end

local function applyRoll()
  if not foundSeed or not target or not foundBonuses or #foundBonuses ~= 3 then return end
  local player = Game.GetPlayer()
  if not player then say("Load a save first."); return end
  local ok, result = pcall(function()
    beforeValues = currentValues(player)
    refreshEquippedBonuses()
    beforeFingerprint = equippedFingerprint()
    if player:CBPCurrentShardIsSeed(target.area, target.slot, foundSeed) then return "already" end
    local c = foundBonuses
    return player:CBPApply(target.area, target.slot, c[1], c[2], c[3], foundSeed)
  end)
  if not ok then say("Apply failed: " .. tostring(result)); return end
  if result == "already" then afterValues = beforeValues; say("This exact roll is already installed."); return end
  if not result then say("Install request was rejected. Refresh the item to check its bonuses."); refreshEquippedBonuses(); return end
  verifying, verifyFrames = true, 0
  say("Install request sent. Checking the equipped shard...")
end

local function verifyApply()
  if not verifying or not target then return end
  verifyFrames = verifyFrames + 1
  if verifyFrames % 10 ~= 0 then return end
  local player = Game.GetPlayer()
  if not player then verifying = false; say("Cannot verify without a loaded save."); return end
  local ok, installed, values = pcall(function()
    return player:CBPCurrentShardIsSeed(target.area, target.slot, foundSeed), currentValues(player)
  end)
  if not ok then verifying = false; say("Verification failed: " .. tostring(installed)); return end
  if installed then
    verifying, afterValues = false, values
    refreshEquippedBonuses()
    if valuesChanged(beforeValues, afterValues) then
      say("Installed and verified. Save and reload to confirm the displayed values.")
    else
      say("Installed seed verified, but the raw bonus values did not change.")
    end
  else
    refreshEquippedBonuses()
    if beforeFingerprint and equippedFingerprint() ~= beforeFingerprint and equippedMatchesSelection() then
      verifying, afterValues = false, values
      say("Equipped bonuses changed to the selected types. Exact seed ID was not confirmed; check the game tooltip.")
      return
    end
  end
  if verifying and verifyFrames >= 600 then
    verifying = false
    say("No matching bonus change detected yet. Use Recheck apply or inspect the game tooltip.")
  end
end

registerForEvent("onInit", function() loadCursors(); say("Ready. Open CET and refresh Cyberware.") end)
registerForEvent("onOverlayOpen", function() overlayOpen = true end)
registerForEvent("onOverlayClose", function() overlayOpen = false end)

registerForEvent("onDraw", function()
  if not overlayOpen then return end
  observeBatch()
  scanBatch()
  verifyApply()
  ImGui.SetNextWindowSize(1750, 790, ImGuiCond.Always)
  if not ImGui.Begin("Cyberware Bonus Picker") then ImGui.End(); return end
  ImGui.BeginChild("##status", 0, 44, false)
  if ImGui.TextWrapped then ImGui.TextWrapped(status) else ImGui.Text(status) end
  ImGui.EndChild()
  if ImGui.Button("Refresh items") then refresh() end
  if #items > 0 then
    ImGui.BeginGroup()
    ImGui.Text("Cyberware")
    ImGui.SetNextItemWidth(420)
    itemFilter, _ = ImGui.InputTextWithHint("##itemSearch", "Search equipped item", itemFilter, 128)
    ImGui.BeginChild("##itemList", 420, 600, true)
    for index, item in ipairs(items) do
      if itemFilter == "" or item.label:lower():find(itemFilter:lower(), 1, true) then
        if ImGui.Selectable(item.label .. "##item" .. index, selected == index) and selected ~= index then
          selected, choices = index, {}
          clearResult()
          refreshEquippedBonuses()
          resetObservation()
          say("Selected " .. item.label .. ". Choose bonuses or filter them first.")
        end
      end
    end
    ImGui.EndChild()
    ImGui.EndGroup()

    ImGui.SameLine()
    ImGui.BeginChild("##bonusPane", 650, 665, true)
    ImGui.Text("Bonuses (" .. #choices .. " selected)")
    ImGui.Text("1: maximize it. 2 or 3: require and balance selected bonuses.")
    if ImGui.Button(analyzing and "Filtering bonuses..." or "Filter compatible bonuses") and not analyzing then
      if running or verifying then
        say("Stop the current operation before filtering bonuses.")
      else
        startObservation()
      end
    end
    ImGui.Text(analyzing and ("Checking bonus groups: " .. sampledSeeds .. "/" .. sampleLimit)
      or (observedCount > 0 and ("Filter ready: " .. observedCount .. " types") or "Filter optional; all bonuses shown."))
    if #choices == 3 then ImGui.Text("Untick one bonus to choose another.") end
    ImGui.Text("Selected:")
    for i = 1, 3 do
      ImGui.Text(i .. ". " .. (choices[i] and bonuses[choices[i] + 1] or (i == 1 and "--" or "Any bonus")))
    end
    if ImGui.Button("Clear bonuses") then choices = {}; clearResult() end
    ImGui.Separator()
    bonusFilter, _ = ImGui.InputTextWithHint("##bonusSearch", "Search bonus", bonusFilter, 128)
    ImGui.BeginChild("##bonuses", 0, 400, false)
    local shown = 0
    for index, bonus in ipairs(bonuses) do
      if bonusAvailable(index - 1) and (bonusFilter == "" or bonus:lower():find(bonusFilter:lower(), 1, true)) then
        shown = shown + 1
        local position = choicePosition(index - 1)
        local checked, changed = ImGui.Checkbox(bonus .. "##bonus" .. index, position ~= nil)
        if changed and checked ~= (position ~= nil) then
          if checked and #choices < 3 then
            choices[#choices + 1] = index - 1
            clearResult()
          elseif not checked and position then
            table.remove(choices, position)
            clearResult()
          end
        end
      end
    end
    if shown == 0 then ImGui.Text("No compatible bonuses in this sample. Untick one selection.") end
    ImGui.EndChild()
    ImGui.EndChild()

    ImGui.SameLine()
    ImGui.BeginChild("##resultPane", 630, 665, true)
    ImGui.Text("Current item")
    if ImGui.Button("Refresh current bonuses") then refreshEquippedBonuses() end
    if #equippedBonuses == 0 then
      ImGui.Text("No positive shard bonuses read. Check the game tooltip.")
    else
      for _, entry in ipairs(equippedBonuses) do
        if ImGui.TextWrapped then ImGui.TextWrapped(bonuses[entry.index + 1]) else ImGui.Text(bonuses[entry.index + 1]) end
      end
    end
    ImGui.Separator()
    ImGui.Text("Candidate roll")
    ImGui.Text("Search up to " .. hardLimit .. " seeds (default 100000)")
    seedLimitInput, _ = ImGui.InputInt("##seedLimit", seedLimitInput, 10000, 50000)
    ImGui.SameLine()
    if ImGui.Button("Set limit") then
      if running or verifying then
        say("Finish or stop the current operation before changing the seed limit.")
      else
        hardLimit = math.max(1000, math.min(1000000, math.floor(tonumber(seedLimitInput) or hardLimit)))
        seedLimitInput = hardLimit
        clearResult()
        say("Seed limit set to " .. hardLimit .. ". The next search uses this limit.")
      end
    end
    if running then
      ImGui.Text("Searching seed " .. nextSeed .. " / " .. hardLimit .. "  |  matches " .. matches)
      if ImGui.Button("Stop") then
        running = false
        say("Search stopped. No item changed.")
      end
    elseif not verifying then
      local searchLabel = #choices == 1 and "Find highest focus bonus" or (foundSeed and "Find another best roll" or "Find best roll")
      if ImGui.Button(searchLabel) then startSearch() end
    end

    if foundSeed and foundValues then
      if target.mode == "focus" then
        ImGui.Text("Highest focus bonus found in " .. hardLimit .. " seeds")
      else
        ImGui.Text("Best found among " .. matches .. " matching rolls")
      end
      ImGui.Text("Seed " .. foundSeed)
      ImGui.Separator()
      for i = 1, #foundBonuses do
        local bonus = foundBonuses[i]
        local name = (target.mode == "focus" and bonus == target.choices[1] and "FOCUS: " or "") .. bonuses[bonus + 1]
        if ImGui.TextWrapped then ImGui.TextWrapped(name) else ImGui.Text(name) end
        ImGui.Text("Raw shard value: " .. formatValue(bonus, foundValues[i]))
        ImGui.Separator()
      end
      if minimums and maximums then
        local spread = false
        for i = 1, #minimums do if maximums[i] - minimums[i] > 0.00001 then spread = true end end
        if not spread and matches > 1 then ImGui.Text("All matching seeds had the same raw values.") end
      end
      ImGui.Text("Raw shard values are for ranking; check final numbers in the game tooltip.")
      if not verifying and not afterValues and ImGui.Button("Apply roll") then applyRoll() end
      if not verifying and beforeFingerprint and not afterValues and ImGui.Button("Recheck apply") then
        verifying, verifyFrames = true, 0
        say("Rechecking the equipped shard...")
      end
    elseif not running then
      ImGui.Text("Select one, two, or three bonuses, then search.")
    end
    ImGui.EndChild()
  end
  ImGui.End()
end)
