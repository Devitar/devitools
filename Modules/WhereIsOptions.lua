local _, ns = ...

local defaults = {
    showMinimap = true,
    showWorldMap = true,
    autoClear = true,
    arrivalDistance = 3,
    lockButton = false,
    searchOtherZones = true,
    allowClassic = true,
    showSource = false,
    chatMessages = true,
}

local function saved()
    if type(DevitoolsDB) == "table" and type(DevitoolsDB.whereIsOptions) == "table" then
        return DevitoolsDB.whereIsOptions
    end
end

local function get(key)
    local settings = saved()
    local value = settings and settings[key]
    if key == "arrivalDistance" then
        if type(value) == "number" and value >= 1 and value <= 100 and value % 1 == 0 then return value end
    elseif type(value) == "boolean" then
        return value
    end
    return defaults[key]
end

local function set(key, value)
    if type(DevitoolsDB) ~= "table" then
        DevitoolsDB = {}
    end
    if type(DevitoolsDB.whereIsOptions) ~= "table" then
        DevitoolsDB.whereIsOptions = {}
    end
    DevitoolsDB.whereIsOptions[key] = value
end

local function serviceEnabled(key)
    local settings = saved()
    return not settings or type(settings.services) ~= "table" or settings.services[key] ~= false
end

local function setService(key, enabled)
    local settings = saved()
    if not settings then
        set("services", {})
        settings = saved()
    end
    if type(settings.services) ~= "table" then
        settings.services = {}
    end
    settings.services[key] = enabled
end

ns.WhereIsOptions = { Get = get, Set = set, ServiceEnabled = serviceEnabled, SetService = setService }
