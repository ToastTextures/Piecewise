local page = action_wheel:newPage("Outfits")
local MAIN_PAGE = page -- HEY YOU, YES YOU | UPDATE THIS IF YOU USE THE ACTION WHEEL

local Piece, Outfit = require("../core") ---@type Toast.Piece, Toast.Outfit
local Tintable ---@type Toast.Tintable?
local utils = require("../utils") ---@type Toast.Utils
local validated, _t = pcall(function() return require("../tintable.tintable") end)
if validated then Tintable = _t end

if not host:isHost() then return end

local OUTFIT_OFFSET = vec(0, -4, 0)

local OUTFIT_TEXTURE_REGISTRY = {}

local prevPage ---@type Page
local categories = {} ---@type table<Toast.Part, Page>
local PART_TYPES = {
    HAT = "Hats",
    BODY_MAIN = "Body Bases",
    BODY_LAYER = "Body Layers",
    LEFT_HAND = "Left Hand Accessories",
    RIGHT_HAND = "Right Hand Accessories",
    PANTS = "Pants",
    SHOES = "Shoes",
    OUTFIT = "Loaded Outfits",
} ---@type table<Toast.Part, string>

local foundColors = {} ---@type table<string, Page>

local back = action_wheel:newAction()
    :setTitle("Back")
    :setItem("magenta_glazed_terracotta")
    :setOnLeftClick(function()
        action_wheel:setPage(prevPage)
    end)


for partName, title in pairs(PART_TYPES) do
    categories[partName] = action_wheel:newPage(partName)
    page:newAction()
        :setTitle(title)
        :setOnLeftClick(
            function()
                prevPage = page
                action_wheel:setPage(categories[partName])
            end
        )
    categories[partName]:setAction(-1, back)
end

---@param piece Toast.Tintable
local function addColors(piece, palette)
    local paletteOwner = piece.parent or piece.name
    foundColors[paletteOwner] = foundColors[paletteOwner] or palette
    if paletteOwner == piece.name then
        foundColors[piece.name] = action_wheel:newPage(piece.name .. ".Colors")

        for index, nestedPalette in ipairs(palette) do
            local color = nestedPalette[1].xyz
            foundColors[piece.name]:newAction()
                :color(color)
                :setTitle(vectors.rgbToHex(color))
                :setOnLeftClick(function() piece:setColor(index):equip() end)
        end
        foundColors[piece.name]:setAction(-1, back)
    end
end

local function justDeserialize(piece, buf) piece:deserialize(buf) end

local function registerFromStorage()
    for name, data in pairs(Outfit.cache) do
        local ids = {}
        for _, piece in ipairs(Outfit.runOnCompressed(data, justDeserialize)) do
            ids[#ids + 1] = piece.id
        end
        print(toJson(ids))
        categories.OUTFIT:newAction()
            :setTitle(name)
            :onLeftClick(function()
                if not host:isHost() then return end
                Outfit.runOnCompressed(data, justDeserialize)
            end)
            :setItem(utils.versions.formatList:format(avatar:getEntityName(), toJson(ids)))
    end
end
action_wheel:setPage(MAIN_PAGE)
local SKULL = models:newPart("Piecewise.Skull", "SKULL")

---@param piece Toast.Piece
local function clone(piece)
    local cloned

    for _, part in pairs(piece.options.modelParts) do
        cloned = utils.deepCopy(part)
        cloned:setPos(piece.options.skullOffset)
        SKULL:addChild(cloned)
    end
end

local function hideAll()
    for _, child in ipairs(SKULL:getChildren()) do
        child:setVisible(false)
    end
end

function events.SKULL_RENDER(_, _, item, _, _)
    if not item then return end
    local stored = utils.versions.parse(item)
    if type(stored) == "number" then
        stored = { stored }
    end
    hideAll()
    for _, id in ipairs(stored) do
        local piece = Piece._ALL[id]
        if not piece then return end
        for _, part in ipairs(piece.options.modelParts) do
            SKULL[part:getName()]:setVisible(true)
            if #stored > 1 then
                SKULL[part:getName()]:setPos(OUTFIT_OFFSET)
            else
                SKULL[part:getName()]:setPos(piece.options.skullOffset)
            end
        end
    end
end

---@generic T: Toast.Piece
for id, piece in pairs(Piece._ALL) do
    if type(piece) == "number" then goto continue end ---@cast piece T
    clone(piece)
    if not piece.options then goto continue end
    local partType = piece.options.part
    if not partType then goto continue end

    if piece.type == "Tintable" then ---@cast piece Toast.Tintable ---@cast piece.options Toast.Tintable.Options
        if piece.options.palette then
            addColors(piece, piece.options.palette)
        end
    end

    categories[partType]:newAction()
        :setItem(utils.versions.format:format(avatar:getEntityName(), id))
        :setTitle(piece.name)
        :onToggle(function(state, self)
            if state then piece:equip() else piece:unequip() end

            if piece.type == "Tintable" and piece.options.palette then ---@cast piece Toast.Tintable ---@cast piece.options Toast.Tintable.Options
                action_wheel:setPage(foundColors[piece.parent or piece.name])
            end
        end
        )
    ::continue::
end

registerFromStorage()
---@type Event.ChatSendMessage.func
local captureName = function(message)
    if message then
        print(Outfit:save(message))
    end
    events.CHAT_SEND_MESSAGE:remove("Capture Name")
    return nil
end


do
    categories.OUTFIT:newAction()
        :title("Save Outfit!")
        :setOnLeftClick(function()
            events.CHAT_SEND_MESSAGE:register(captureName, "Capture Name")
            printJson("Enter the name of the saved outfit: ")
            host:setChatColor(vectors.hexToRGB("8bf24b"))
        end)
end
