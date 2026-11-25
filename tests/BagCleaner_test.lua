local frames, named, popups, events, strings = {}, {}, {}, {}, {}
local methods = {}
methods.__index = function(_, key) return methods[key] or function() end end
function methods:SetScript(key, fn) self[key] = fn end
function methods:SetText(text)
    self.text = text
    if rawget(self, "hookOnTextChanged") then self.hookOnTextChanged(self) end
end
function methods:GetText() return self.text end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and rawget(self, "OnHide") then self.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:RegisterEvent(event) events[event] = self end
function methods:RegisterForClicks(...) self.clickButtons = { ... } end
function methods:SetParent(parent) self.parent = parent end
function methods:GetFrameLevel() return 5 end
function methods:GetRight() return 1000 end
function methods:HookScript(event, fn) self["hook" .. event] = fn end
function methods:CreateFontString()
    local result = setmetatable({}, methods)
    strings[#strings + 1] = result
    return result
end
function methods:CreateTexture() return setmetatable({}, methods) end
CreateFrame = function(kind, name, parent, template)
    local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, Text = setmetatable({}, methods) }, methods)
    frames[#frames + 1] = f
    if name then named[name] = f end
    return f
end
UIParent, MainMenuBarBackpackButton, GameTooltip = setmetatable({}, methods), {}, setmetatable({}, methods)
StaticPopupDialogs, CANCEL = {}, "Cancel"
StaticPopup_Show = function(name, a, b, data) popups[#popups + 1] = { name = name, data = data, warning = b } end
SetItemButtonTexture = function() end
SetItemButtonCount = function() end
InCombatLockdown = function() return false end
CursorHasItem = function() return false end
GetCursorInfo = function() return nil end
local tooltipLine
GameTooltip.AddLine = function(_, text) if text:find("Total vendor value:", 1, true) then tooltipLine = text end end
local menuOptions = {}
MenuUtil = { CreateContextMenu = function(owner, callback)
    menuOptions = {}
    callback(owner, { CreateButton = function(_, label, fn) menuOptions[label] = fn end })
end }
NUM_BAG_SLOTS = 0
local bag = {
    { itemID = 1, hyperlink = "item:1", stackCount = 5, iconFileID = 1 },
    { itemID = 2, hyperlink = "item:2", stackCount = 1, iconFileID = 2 },
    { itemID = 3, hyperlink = "item:3", stackCount = 1, iconFileID = 3 },
    { itemID = 6948, hyperlink = "item:6948", stackCount = 1, iconFileID = 4 },
    { itemID = 6265, hyperlink = "item:6265", stackCount = 1, iconFileID = 5 },
    { itemID = 2512, hyperlink = "item:2512", stackCount = 20, iconFileID = 6 },
    { itemID = 7777, hyperlink = "item:7777", stackCount = 1, iconFileID = 7, conjured = true },
}
ITEM_CONJURED = "Conjured Item"
GetLocale = function() return "enUS" end
local unavailableSlot, noValueID
C_TooltipInfo = { GetBagItem = function(_, slot)
    if not bag[slot] or slot == unavailableSlot then return nil end
    return { lines = { { leftText = "Item" }, { leftText = bag[slot].conjured and ITEM_CONJURED or "Ordinary" } } }
end }
local pickups = 0
C_Container = {
    GetContainerNumSlots = function() return #bag end,
    GetContainerItemInfo = function(_, slot) return bag[slot] end,
    GetContainerItemQuestInfo = function(_, slot) return { questID = slot == 3 and 123 or 0 } end,
    PickupContainerItem = function() pickups = pickups + 1 end,
}
C_Item = { GetItemInfo = function(link) return ({ ["item:1"] = "Stone", ["item:2"] = "Fish", ["item:3"] = "Quest", ["item:6948"] = "Hearthstone", ["item:4"] = "Other" })[link] or "Item",nil,link == "item:1" and 1 or 0,nil,nil,nil,nil,nil,nil,nil, link == noValueID and 0 or (link == "item:1" and 2 or 4), link == "item:2512" and 6 or 2 end }
DeleteCursorItem = function() error("Must not delete changed items") end
local openedSettings
local ns = { Settings = { RegisterPage = function() return CreateFrame("Frame") end,
    Open = function(page) openedSettings = page end } }
assert(loadfile("Modules/BagCleaner.lua"))("Devitools", ns)
named.DevitoolsBagCleanerSettingsButton.OnClick(named.DevitoolsBagCleanerSettingsButton)
assert(openedSettings == "Bag Cleaner", "the settings cog must open the Bag Cleaner page")
events.PLAYER_LOGIN.OnEvent(events.PLAYER_LOGIN, "PLAYER_LOGIN")
assert(named.DevitoolsBagCleanerDefaultSlots:GetText() == "5", "the default count must be initialized")
local defaultVisible = false
for _, label in ipairs(strings) do
    if rawget(label, "text") == "5" then defaultVisible = true end
end
assert(defaultVisible, "the unfocused default count must have a visible text display")
local enabledBox = named.DevitoolsBagCleanerEnabled
assert(enabledBox.checked == true, "the enabled checkbox must reflect the default on login")
DevitoolsDB = { bagCleanerEnabled = false }
DevitoolsCharacterDB = {}
events.PLAYER_LOGIN.OnEvent(events.PLAYER_LOGIN, "PLAYER_LOGIN")
assert(enabledBox.checked == false, "the enabled checkbox must reflect a saved disabled setting")
local disabledCharacter = DevitoolsCharacterDB
DevitoolsDB = {}
DevitoolsCharacterDB = {}
events.PLAYER_LOGIN.OnEvent(events.PLAYER_LOGIN, "PLAYER_LOGIN")
assert(enabledBox.checked and disabledCharacter.bagCleanerEnabled == false, "bag cleaner visibility must be per character")
enabledBox.checked = false
enabledBox.OnClick(enabledBox)
local otherCharacter = DevitoolsCharacterDB
assert(otherCharacter.bagCleanerEnabled == false and DevitoolsDB.bagCleanerEnabled == nil, "the toggle must not change the account-wide setting")
DevitoolsCharacterDB = {}
events.PLAYER_LOGIN.OnEvent(events.PLAYER_LOGIN, "PLAYER_LOGIN")
assert(enabledBox.checked and otherCharacter.bagCleanerEnabled == false, "disabling an alt must not hide the tool for another character")
assert(not named.DevitoolsBagCleanerButton.shown, "button must stay hidden when no bag is open")
ContainerFrameCombinedBags = setmetatable({}, methods)
ContainerFrameCombinedBags.shown = true
events.BAG_UPDATE_DELAYED.OnEvent(events.BAG_UPDATE_DELAYED, "BAG_UPDATE_DELAYED")
assert(named.DevitoolsBagCleanerButton.parent == ContainerFrameCombinedBags, "button should attach to the combined bag when available")
assert(named.DevitoolsBagCleanerButton.shown, "button should appear when the bag opens")
ContainerFrameCombinedBags.shown = false
ContainerFrameCombinedBags.hookOnHide()
assert(not named.DevitoolsBagCleanerButton.shown, "button should hide when the bag closes")
ContainerFrameCombinedBags.shown = true
ContainerFrameCombinedBags.hookOnShow()
assert(named.DevitoolsBagCleanerButton.shown, "button should reappear when the bag reopens")
named.DevitoolsBagCleanerButton.OnClick(named.DevitoolsBagCleanerButton)
local itemButtons = {}
for _, f in ipairs(frames) do if rawget(f, "name") and f.name:match("^DevitoolsBagCleanerItem%d+$") then itemButtons[#itemButtons + 1] = f end end
assert(itemButtons[1].item.id == 2 and itemButtons[2].item.id == 1, "must sort by total stack value")
assert(itemButtons[1].clickButtons[2] == "RightButtonUp", "item buttons must accept right clicks")
local findForMenu, countForMenu
for _, f in ipairs(frames) do
    if rawget(f, "text") == "Find" then findForMenu = f end
    if f.parent == named.DevitoolsBagCleanerFrame and f.kind == "EditBox" then countForMenu = f end
end
bag[8] = { itemID = 8, hyperlink = "item:8", stackCount = 1, iconFileID = 8 }
countForMenu:SetText("2")
findForMenu.OnClick(findForMenu)
itemButtons[1].OnClick(itemButtons[1], "RightButton")
assert(menuOptions["Ignore Suggestion"] and menuOptions["Add to Exclude List"], "right click must show both actions")
menuOptions["Ignore Suggestion"]()
assert(itemButtons[1].item.id == 8 and itemButtons[2].item.id == 1 and #DevitoolsCharacterDB.bagCleanerExcluded == 0, "ignoring must replace the item with the next eligible suggestion")
findForMenu.OnClick(findForMenu)
assert(itemButtons[1].item.id == 2, "ignored suggestions must return after a new search")
itemButtons[1].OnClick(itemButtons[1], "RightButton")
menuOptions["Add to Exclude List"]()
assert(DevitoolsCharacterDB.bagCleanerExcluded[1] == "Fish", "right-click exclusion must be saved")
assert(itemButtons[1].item.id == 8 and itemButtons[2].item.id == 1, "excluding must replace the item with the next eligible suggestion")
local firstMenuRemove
for _, f in ipairs(frames) do if rawget(f, "text") == "Remove" then firstMenuRemove = f end end
firstMenuRemove.OnClick(firstMenuRemove)
assert(itemButtons[1].item.id == 2, "removing the exclusion should restore the item on the refreshed search")
bag[8] = nil
countForMenu:SetText("5")
findForMenu.OnClick(findForMenu)
itemButtons[1].OnClick(itemButtons[1], "RightButton")
menuOptions["Add to Exclude List"]()
assert(DevitoolsCharacterDB.bagCleanerExcluded[1] == "Fish" and itemButtons[1].item.id == 1, "right-click exclusion must save the name and update results")
local menuRemove
for _, f in ipairs(frames) do if rawget(f, "text") == "Remove" then menuRemove = f end end
menuRemove.OnClick(menuRemove)
assert(#DevitoolsCharacterDB.bagCleanerExcluded == 0 and itemButtons[1].item.id == 2, "right-click exclusions must be removable in settings")
itemButtons[1].OnEnter(itemButtons[1])
assert(tooltipLine == "Total vendor value: 4c", "hover must format vendor value without a client-specific helper")
itemButtons[1].item.value = 0
itemButtons[1].OnEnter(itemButtons[1])
assert(tooltipLine == "Total vendor value: 0c", "zero-value items must have a usable tooltip")
assert(not itemButtons[3] or rawget(itemButtons[3], "item") == nil, "quest items, Hearthstones, Soul Shards, ammo and conjured items must be excluded")
local poorOnly = named.DevitoolsBagCleanerPoorOnly
poorOnly:SetChecked(true)
poorOnly.OnClick(poorOnly)
assert(itemButtons[1].item.id == 2 and rawget(itemButtons[2], "item") == nil, "poor-quality filter must hide non-poor items")
poorOnly:SetChecked(false)
poorOnly.OnClick(poorOnly)
local sellableOnly = named.DevitoolsBagCleanerSellableOnly
noValueID = "item:2"
sellableOnly:SetChecked(true)
sellableOnly.OnClick(sellableOnly)
assert(itemButtons[1].item.id == 1 and rawget(itemButtons[2], "item") == nil, "sellable filter must hide zero-value items")
sellableOnly:SetChecked(false)
noValueID = nil
sellableOnly.OnClick(sellableOnly)
unavailableSlot = 2
poorOnly.OnClick(poorOnly)
assert(itemButtons[1].item.id == 1 and rawget(itemButtons[2], "item") == nil, "unknown tooltip data must not be treated as safe")
unavailableSlot = nil
poorOnly.OnClick(poorOnly)
local addButton, excludeInput
for _, f in ipairs(frames) do if rawget(f, "text") == "Add" then addButton = f end end
for _, f in ipairs(frames) do
    if f.parent == addButton.parent and f.kind == "EditBox" then excludeInput = f end
end
excludeInput:SetText("  fIsH  ")
addButton.OnClick(addButton)
assert(DevitoolsCharacterDB.bagCleanerExcluded[1] == "fIsH", "exclusions must be trimmed and saved per character")
assert(itemButtons[1].item.id == 1 and rawget(itemButtons[2], "item") == nil, "excluded names must match case-insensitively and refresh results")
local removeButton
for _, f in ipairs(frames) do if rawget(f, "text") == "Remove" then removeButton = f end end
removeButton.OnClick(removeButton)
assert(#DevitoolsCharacterDB.bagCleanerExcluded == 0 and itemButtons[1].item.id == 2, "removing an exclusion must restore the item")
itemButtons[2].OnClick(itemButtons[2])
assert(named.DevitoolsBagCleanerQueue.shown, "individual deletion must use the shared confirmation window")
local singleWarning = false
for _, label in ipairs(strings) do
    if rawget(label, "text") and label.text:find("all 5 items", 1, true) then singleWarning = true end
end
assert(singleWarning, "individual confirmation must warn about the full quantity")
local cancelButton
for _, f in ipairs(frames) do
    if f.parent == named.DevitoolsBagCleanerQueue and rawget(f, "text") == "Cancel" then cancelButton = f end
end
cancelButton.OnClick(cancelButton)
itemButtons[1].OnClick(itemButtons[1])
assert(named.DevitoolsBagCleanerQueue.shown, "item deletion must be confirmed")
local singleInstruction, singleName = false, false
for _, label in ipairs(strings) do
    if rawget(label, "text") == "Drag this window to move it." then singleInstruction = true end
    if rawget(label, "text") == "Fish" then singleName = true end
end
assert(singleInstruction and singleName, "single-item confirmation must not show bulk instructions or a remaining count")
bag[2] = { itemID = 4, hyperlink = "item:4", stackCount = 1 }
named.DevitoolsBagCleanerQueueDelete.OnClick(named.DevitoolsBagCleanerQueueDelete)
assert(pickups == 0, "changed slots must never be picked up")
local initialFind
for _, f in ipairs(frames) do if rawget(f, "text") == "Find" then initialFind = f end end
initialFind.OnClick(initialFind)


local cursor, deletes = false, 0
CursorHasItem = function() return cursor end
C_Container.PickupContainerItem = function(_, slot) cursor = slot end
DeleteCursorItem = function() bag[cursor] = nil; cursor = false; deletes = deletes + 1 end
local bulk
for _, f in ipairs(frames) do if f.text == "Delete all results..." then bulk = f end end
assert(bulk, "bulk action must be available")
bulk.OnClick(bulk)
assert(named.DevitoolsBagCleanerQueue.shown, "bulk action must open its confirmation window")
assert(named.DevitoolsBagCleanerQueue.OnDragStart and named.DevitoolsBagCleanerQueue.OnDragStop, "confirmation window must be draggable")
assert(deletes == 0, "confirming the queue must not delete items")
named.DevitoolsBagCleanerQueueDelete.OnClick(named.DevitoolsBagCleanerQueueDelete)
assert(deletes == 1, "one click must delete at most one stack")
assert(named.DevitoolsBagCleanerQueue.shown, "the confirmation window must remain open for the next stack")
local foundWarning = false
for _, label in ipairs(strings) do
    if rawget(label, "text") and label.text:find("all 5 items", 1, true) then foundWarning = true end
end
assert(foundWarning, "bulk confirmation must warn about the next item's full quantity")
bag[1] = { itemID = 9, hyperlink = "item:9", stackCount = 1 }
named.DevitoolsBagCleanerQueueDelete.OnClick(named.DevitoolsBagCleanerQueueDelete)
assert(deletes == 1 and not named.DevitoolsBagCleanerQueue.shown, "a changed slot must stop the queue without deleting")

bag = {}
C_Container.GetContainerItemQuestInfo = function() return nil end
for i = 1, 30 do
    bag[i] = { itemID = 100 + i, hyperlink = "item:" .. (100 + i), stackCount = 1, iconFileID = i }
end
local countInput, findButton
for _, f in ipairs(frames) do
    if f.parent == named.DevitoolsBagCleanerFrame and f.kind == "EditBox" then countInput = f end
    if rawget(f, "text") == "Find" then findButton = f end
end
countInput:SetText("30")
findButton.OnClick(findButton)
assert(named.DevitoolsBagCleanerItem30.item ~= nil, "requests above 25 must show all requested items")
countInput:SetText("99")
findButton.OnClick(findButton)
assert(countInput:GetText() == "30", "requests must be clamped to total bag capacity")
local applyDefault
for _, f in ipairs(frames) do if rawget(f, "text") == "Apply" then applyDefault = f end end
named.DevitoolsBagCleanerDefaultSlots:SetText("12")
applyDefault.OnClick(applyDefault)
assert(DevitoolsDB.bagCleanerOptions.defaultSlots == 12, "the default count must be saved")
named.DevitoolsBagCleanerDefaultSlots.hookOnShow(named.DevitoolsBagCleanerDefaultSlots)
assert(named.DevitoolsBagCleanerDefaultSlots:GetText() == "12", "showing the field must restore the saved count")
named.DevitoolsBagCleanerFrame:Hide()
named.DevitoolsBagCleanerButton.OnClick(named.DevitoolsBagCleanerButton)
assert(countInput:GetText() == "12", "opening the cleaner must use the saved default")
named.DevitoolsBagCleanerItem1.OnClick(named.DevitoolsBagCleanerItem1)
bag[1].conjured = true
named.DevitoolsBagCleanerQueueDelete.OnClick(named.DevitoolsBagCleanerQueueDelete)
assert(deletes == 1, "conjured status must be checked again before deletion")

print("Bag Cleaner tests passed")

