---@class Toast.Utils
local utils = {}

---- Run Later by manuel_2867 ----
local tmrs = {}
local t = 0
function utils.runLater(ticks, next, discard)
    local x = type(ticks) == "number"
    table.insert(tmrs,
        {
            t = x and t + ticks,
            p = x and function() end or ticks,
            n = next,
            discard = (discard == nil) and true or
                discard
        })
end

function events.TICK()
    t = t + 1
    for key, timer in pairs(tmrs) do
        if timer.p() or (timer.t and t >= timer.t) then
            timer.n()
            if (timer.discard) then
                tmrs[key] = nil
            end
        end
    end
end

---Prints stuff nicely
---@param name string
---@param color string
---@param ... any
local function prettyPrint(name, color, ...)
    if not ... then return end

    local json = {
        { text = ("[%s] "):format(name), color = color },
        { text = avatar:getEntityName(), color = "white" },
        { text = " : ",                  color = color },
    }
    for _, value in ipairs({ ... }) do
        if type(value) ~= "string" then value = tostring(value) end
        table.insert(json, { text = value .. "\n", color = color })
    end
    table.insert(json, { text = "\n" })
    printJson(toJson(json))
end

local Logger = { level = 2, levels = -1 } --- only shows warns in prod

function utils.newLogger(name, color)
    Logger.levels = Logger.levels + 1
    return setmetatable({ level = Logger.levels, name = name, color = color }, {
        __call = function(tab, ...)
            if not host:isHost() then return false end
            if (tab.level >= Logger.level) then
                prettyPrint(name, color, ...)
                return true
            end
            return false
        end,
    })
end

function utils.base64(str)
    local buffer = data:createBuffer()
    buffer:writeByteArray(str)
    buffer:setPosition(0)
    local output = buffer:readBase64()
    buffer:close()
    return output
end

function utils.transferElements(from, to)
    for key, element in from do
        to[key] = element
    end
end

function utils.stringHash(str)
    local hash = 0x811C9DC5
    for i = 1, #str do
        hash = bit32.bxor(hash, str:byte(i))
        hash = (hash * 0x01000193) % 0xFFFFFFFF
    end
    return bit32.band(hash, 0xFFFFFF)
end

function utils.swapValues(tab)
    local output = {}
    for id, name in pairs(tab) do
        output[name] = id
    end
    return output
end

function utils.deepCopy(model)
    local copy = model:copy(model:getName())
    for _, child in pairs(copy:getChildren()) do
        copy:removeChild(child):addChild(utils.deepCopy(child):setParentType("NONE"))
    end
    return copy
end

Logger.debug = utils.newLogger("debug", "dark_aqua")
Logger.info = utils.newLogger("info", "green")
Logger.warn = utils.newLogger("warn", "yellow")

utils.Logger = Logger


local MINECRAFT_FORMATS = {
    PRE_COMPONENT = {
        parse = function(item) return item:getTag().PiecewiseData end,
        format = "minecraft:player_head{SkullOwner:%s,PiecewiseData:%d}",
        formatList = "minecraft:player_head{SkullOwner:%s,PiecewiseData:%s}"
    },
    POST_COMPONENT = {
        parse = function(item) return item:getTag()["minecraft:custom_data"].PiecewiseData end,
        format = "minecraft:player_head[profile=%s,custom_data={PiecewiseData:%d}]",
        formatList = "minecraft:player_head[profile=%s,custom_data={PiecewiseData:%s}]"
    }
}

local versions = client.compareVersions(client:getVersion(), "1.20.5") >= 0
    and MINECRAFT_FORMATS.POST_COMPONENT or MINECRAFT_FORMATS.PRE_COMPONENT

utils.versions = versions
return utils
