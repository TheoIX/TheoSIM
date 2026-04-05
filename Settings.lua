TWS = TWS or {}

TWS.defaults = {
    window = {
        point = "CENTER",
        x = 0,
        y = 0,
        width = 420,
        height = 420,
    },
    sim = {
        sims = 500,
        targetLevel = 63,
        targetCount = 1,
        baseArmor = 4211,
        useSunder = 1,
        useFaerieFire = 1,
        useCurseOfRecklessness = 0,
        useExposeArmor = 0,
        useHomunculi = 0,
        abilities = {
            bloodthirst = 1,
            whirlwind = 1,
            execute = 1,
            heroicstrike = 1,
            cleave = 0,
            hamstring = 0,
            pummel = 0,
            slam = 0,
        },
    },
}

local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return dst end
    if type(dst) ~= "table" then dst = {} end

    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end

    return dst
end

function TWS:InitDB()
    if type(TheoSIMDB) ~= "table" then
        TheoSIMDB = {}
    end
    TheoSIMDB = CopyDefaults(self.defaults, TheoSIMDB)
    self.db = TheoSIMDB
end
