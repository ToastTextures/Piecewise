local Piece, Outfit = require("../core") ---@type Toast.Piece, Toast.Outfit
local Tintable ---@type Toast.Tintable? 
local validated, _t = pcall(function() return require("../tintable.tintable") end)
if validated then Tintable = _t end

if not host:isHost() then return end

local page = action_wheel:newPage("Outfits")

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

for partName, title in pairs(PART_TYPES) do
    categories[partName] = action_wheel:newPage(partName)
    page:newAction()
        :setTitle(title)
        :setOnLeftClick(
            function()
                action_wheel:setPage(categories[partName])
            end
        )
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
    end
end

local function registerFromStorage()
    for name, data in pairs(Outfit.cache) do
        categories.OUTFIT:newAction()
            :setTitle(name)
            :onLeftClick(function() Outfit:load(name) end)
            :setItem(("minecraft:player_head{SkullOwner:%s,Data:%s}"):format(avatar:getEntityName(), data))
    end
    print(Outfit.cache)
end


action_wheel:setPage(page)

---@generic T: Toast.Piece
for id, piece in pairs(Piece._ALL) do
    if type(piece) == "number" then goto continue end ---@cast piece T
    
    if not piece.options then goto continue end
    local partType = piece.options.part
    if not partType then goto continue end

    if piece.type == "Tintable" then ---@cast piece Toast.Tintable ---@cast piece.options Toast.Tintable.Options
        if piece.options.palette then 
            addColors(piece, piece.options.palette)
        end
        --updateColorsPage(piece)
    end
    
    categories[partType]:newAction()
        :setTitle(piece.name)
        :onToggle(function(state, self)
            if state then piece:equip() else piece:unequip() end
            
            if piece.type == "Tintable" and piece.options.palette then ---@cast piece Toast.Tintable ---@cast piece.options Toast.Tintable.Options
                 action_wheel:setPage(foundColors[piece.parent or piece.name])
            end
        end
        )

    registerFromStorage()    
    ::continue::
end


local pieceRenderer = {}

function pieceRenderer:render()
end

function pieceRenderer:renderCompressed()
end