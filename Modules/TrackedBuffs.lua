local _, ns = ...

local function normalize(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or name:find("[|%c]") then return nil end
    return name
end

local function add(list, name)
    name = normalize(name)
    if not name then return false, "Enter a buff name." end
    for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name:lower() == name:lower() then
            return false, "That buff is already in the list."
        end
    end
    list[#list + 1] = { name = name, enabled = true }
    return true
end

local function append(list, active, threshold, reminders)
    for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.enabled ~= false then
            local remaining = active[entry.name]
            if remaining ~= true and (not remaining or remaining <= threshold) then
                local color = remaining and "|cffffff00" or "|cffff3333"
                reminders[#reminders + 1] = color .. entry.name .. (remaining and " (expiring)|r" or " (missing)|r")
            end
        end
    end
end

ns.TrackedBuffs = { Add = add, Append = append }
