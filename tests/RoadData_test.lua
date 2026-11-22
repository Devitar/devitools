-- Run with a Lua 5.1-compatible interpreter from the project root.
local ns = { WalkingRoadContext = { RULESET = "forever" } }
assert(loadfile("Vendor/Mapzeroth/Roads.lua"))("Devitools", ns)
assert(loadfile("Vendor/Mapzeroth/Steep.lua"))("Devitools", ns)
assert(loadfile("Vendor/Mapzeroth/RoadNet.lua"))("Devitools", ns)
local length, straight, points = ns.WalkingRoadContext.RoadNet:Route(0, -12428, 217, -12000, -400)
assert(length and straight and points and #points > 0, "real road data must produce a route near Grom'gol")
assert(length >= straight, "route length cannot be less than the straight-line distance")
io.write("Road data test passed\n")
