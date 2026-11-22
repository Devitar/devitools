# Bundled walking router

This is Polestar's GPL-3.0-or-later walking router and generated collision maps from commit `ce25c5e9f` of https://github.com/fitzforge/polestar. The router began with Shortest Path Forever by Cillian Berragan. The copyright notices, full license, and upstream credits are preserved in this directory.

The map headers identify their inputs as Polestar's navigation grid generated from Forever client build 1.60.1.70425. This revision predates the later `--leffe` map builds. The map data and router must be updated together. Game content remains Blizzard Entertainment's property.

Devitools changes: the `PolestarPathData` global is renamed to `DevitoolsPathData` so it does not conflict with Polestar, and `API.lua` exposes the engine through the Devitools namespace rather than `Polestar_NavEngine`. The unused chokepoint data is not loaded. Other source and map contents are unchanged.
