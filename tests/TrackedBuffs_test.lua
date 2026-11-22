local ns = {}
assert(loadfile("Modules/TrackedBuffs.lua"))("Devitools", ns)
local tracker, entries = ns.TrackedBuffs, {}
assert(tracker.Add(entries, "  Elixir of the Mongoose  "))
assert(entries[1].name == "Elixir of the Mongoose" and entries[1].enabled)
assert(not tracker.Add(entries, "elixir of the mongoose"), "duplicates should be rejected")
assert(not tracker.Add(entries, "|cffff0000bad"), "formatting codes should be rejected")
local function reminders(active)
    local result = {}
    tracker.Append(entries, active, 300, result)
    return result
end
local missing = reminders({})
assert(#missing == 1 and missing[1]:find("|cffff3333", 1, true))
assert(#reminders({ [entries[1].name] = 301 }) == 0)
local expiring = reminders({ [entries[1].name] = 300 })
assert(#expiring == 1 and expiring[1]:find("|cffffff00", 1, true))
assert(#reminders({ [entries[1].name] = true }) == 0)
entries[1].enabled = false
assert(#reminders({}) == 0, "disabled entries must not remind")
io.write("TrackedBuffs tests passed\n")
