--#region Toast.Core.Defaults
local utils = require("./utils") ---@type Toast.Utils
local Logger = utils.Logger

local CURRENT_OUTFIT = {} ---@generic T: Toast.Piece ---@type T[]
local ALL_MODEL_PARTS = {} ---@type table<string, ModelPart>

local EMPTY_VECTOR = vec(0, 0, 0)
local BODY_OFFSET = vec(0, -12, 0)

local PIECEWISE_VERSION = "0.1.0"

---@type table<Toast.Part, Vector3> The default offsets for each part type. This is used to determine the offset for the skull position.
local DEFAULT_SKULL_OFFSETS = {
    HAT = vec(0, -24, 0),
    BODY_MAIN = BODY_OFFSET,
    BODY_LAYER = BODY_OFFSET,
    LEFT_HAND = BODY_OFFSET,
    RIGHT_HAND = BODY_OFFSET,
    PANTS = EMPTY_VECTOR,
    SHOES = EMPTY_VECTOR,
}

---@type table<Toast.Extra.Layer, integer>
local layerTypes = {
    LOW = 1,
    HALF = 2,
    FULL = 3
}

--#endregion Toast.Core.Defaults

---@class Toast.Piece
local Piece = { _ALL = { count = 0 }, type = "Piece" }
Piece.__index = Piece

--- Initialization ---

function Piece:updateModelParts(parts)
    self.options.modelParts = parts
    for _, part in pairs(self.options.modelParts) do
        ALL_MODEL_PARTS[part:getName()] = ALL_MODEL_PARTS[part:getName()] or part
    end
    return self
end

function Piece:new(name, options)
    options = options or {} ---@type Toast.Piece.Options
    if options.compatibility and client.compareVersions(PIECEWISE_VERSION, options.compatibility) ~= 0 then
        Logger.warn(("Version incompatibility, this Piece expects %s, found %s!"):format(PIECEWISE_VERSION,
            options.compatibility))
    end
    options.skullOffset = options.skullOffset or (options.part and DEFAULT_SKULL_OFFSETS[options.part]) or EMPTY_VECTOR
    options.modelParts = options.modelParts or {}
    ---@generic T: Toast.Piece
    ---@type T
    local inst = setmetatable({ name = name, options = options, onToggle = {} }, {
        __index = function(t, k)
            return k == "_ALL" and nil or self[k]
        end
    })
    inst.id = utils.stringHash(name)
    Piece._ALL[inst.id] = inst
    Piece._ALL.count = Piece._ALL.count + 1
    inst:updateModelParts(options.modelParts)
    return inst
end

function Piece:copy(name, options)
    for option, value in pairs(self.options) do
        options[option] = options[option] or value
    end
    local inst = self:new(name, options)
    inst.parent = self.name
    return inst
end

function Piece:isCopy()
    return self.parent ~= nil
end

--- Conditionals ---

function Piece:registerToggle(fun)
    self.onToggle[#self.onToggle + 1] = fun
end

function Piece:__toggle()
    for _, event in ipairs(self.onToggle) do
        event(self.visibility)
    end
    return self
end

function Piece:equipWhen(fun)
    local scope = { prev = self.visibility }
    utils.runLater(function()
            local curr = fun(self)

            if curr ~= scope.prev then
                scope.prev = curr
                return true
            end
        end,
        function()
            self:setEquipped(not self.visibility)
        end, false)
    return self
end

--- Packet Stuff ---

function Piece:simplify()
    return { name = self.name, version = self.options.compatibility or PIECEWISE_VERSION }
end

function Piece:serialize(buf)
    buf:writeInt(self.id)
end

function Piece:deserialize(buf)
    return self
end

--- Modifiers ---

function Piece:updateLayers(layer)
    if not self.options.layers then return end
    if not self.options.layers[layer] then return end
    for type, modelList in pairs(self.options.layers) do
        for _, modelPart in ipairs(modelList) do
            modelPart:setVisible(layerTypes[type] <= layerTypes[layer])
        end
    end
end

function Piece:setVisible(visible)
    for _, part in pairs(self.options.modelParts) do
        part:setVisible(visible)
    end
    if self.visibility ~= visible then self:__toggle() end
    self.visibility = visible
    return self
end

function Piece:setUV()
    for _, value in pairs(self.options.modelParts) do
        if not (self.options.texture or self.options.bounds) then break end -- Just stop
        if self.options.texture then
            value:setPrimaryTexture("CUSTOM", self.options.texture)
        end
        if self.options.bounds then
            value:setUVPixels(self.options.bounds.xy)
        end
    end
    return self
end

function Piece:equip()
    Logger.debug(self.name, "has been equipped")
    CURRENT_OUTFIT[self.id] = self
    self:setVisible(true):setUV()
    if self.options.layer then
        self:updateLayers(self.options.layer)
    end
    return self
end

function Piece:unequip()
    CURRENT_OUTFIT[self.id] = nil
    self:setVisible(false)
    return self
end

function Piece:setEquipped(state)
    if state then self:equip() else self:unequip() end
end

--#endregion Toast.Piece

--#region Toast.Outfit

config:setName("Toast.Piecewise")
config:save("version", PIECEWISE_VERSION)

---@class Toast.Outfit
local Outfit = {
    cache = config:load("saved") or {}
}

config:save("saved", Outfit.cache)

function Outfit.runOnCompressed(str, op)
    local collected = {}
    local buf = data:createBuffer(#str)
    buf:writeByteArray(str)
    buf:setPosition(0)

    for _ = 1, Piece._ALL.count do  --- Limit so we don't have an infinite loop, but still have a chance to read everything
        local piece = Piece._ALL[buf:readInt()]
        if not piece then break end --- Reading was somehow corrupted, will wait until the next sync ping
        collected[#collected + 1] = piece
        if buf:available() <= 0 then break end
        op(piece, buf)
    end
    buf:close()
    return collected
end

function Outfit.serialize(pieces)
    local buf = data:createBuffer(256)
    for _, piece in pairs(pieces) do
        Logger.debug("Deserializing", piece.id)
        piece:serialize(buf)
    end
    buf:setPosition(0)
    local output = buf:readByteArray()
    buf:close()
    return output
end

function Outfit.simplify()
    local output = {}
    for _, piece in pairs(CURRENT_OUTFIT) do
        output[#output + 1] = piece:simplify()
    end
    return output
end

function Outfit.deserialize(str)
    for _, modelPart in pairs(ALL_MODEL_PARTS) do
        modelPart:setVisible(false)
    end
    for _, piece in pairs(CURRENT_OUTFIT) do
        piece:unequip()
    end
    Outfit.runOnCompressed(str, function(piece, buf)
        piece:deserialize(buf):equip()
    end)
end

function pings.updateOutfit(serialized)
    if not host:isHost() then
        Outfit.deserialize(serialized) --- The host already ran the operations
    end
    local outfitView = Outfit.simplify()
    avatar:store("Piecewise.Current", outfitView)
end

__name = nil
function Outfit:save(name)
    if (self.cache[name]) then
        if Logger.warn("Overwriting piece with same name!",
                "Changes will be applied when the avatar is reloaded")
        then
            __name = utils.base64(self.cache[name])
            printJson(toJson({
                text = "[Copy old code to clipboard]",
                color = "green",
                clickEvent = {
                    action = "figura_function",
                    value =
                    "require(\"piecewise.core\") host:clipboard(__name) __name = nil",

                }
            }))
        end
    end

    self.cache[name] = self.serialize(CURRENT_OUTFIT) --- SHUT UP I KNOW WHAT'S IN THE TABLE
    config:setName("Toast.Piecewise")
    config:save("saved", self.cache)
    return self.cache[name]
end

function Outfit:load(name)
    if not self.cache[name] then
        Logger.debug(("No outfit found with name '%s', ignoring"):format(name))
        return
    end

    pings.updateOutfit(self.cache[name])
    return self.cache[name]
end

local timer = -20
local function scheduledPing()
    timer = timer + 1
    if timer % 80 == 0 then
        pings.updateOutfit(Outfit.serialize(CURRENT_OUTFIT))
    end
end

events.TICK:register(scheduledPing, "scheduledPing")

--#endregion Toast.Outfit

return Piece, Outfit
