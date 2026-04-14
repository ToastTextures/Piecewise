local REGISTRY = {} ---@type RegisteredTexture[]
local Stitcher = {}

local rowLargestTex = 0
local lastColumnIndex = 0
local origin = vec(0, 0)

local TEXTURE_MAP = textures:newTexture("Saved", 256, 256):fill(0, 0, 256, 256, vec(0, 0, 0, 0));

local function snapshot(base, col, x, y)
    TEXTURE_MAP:setPixel(base.x + x, base.y + y, col)
end


---@class RegisteredTexture
---@field region Vector4 Uhhhh basically x and y are the lower right corners of the last texture, and w and h are the region taken up by it

---@param piece Toast.Piece
function Stitcher.addToRegistry(piece)
    local opts = piece.options
    if not opts or not opts.bounds or not opts.texture then return end
    local pieceW, pieceH = opts.bounds.z, opts.bounds.w
    local last = REGISTRY[#REGISTRY]

    if last then
        origin = last.region.xy
        if (last.region.x + pieceW > TEXTURE_MAP:getDimensions().x) then
            origin.x = 0
            origin.y = rowLargestTex
        end
    end

    local x, y, z, w = opts.bounds:unpack()
    local xy = opts.bounds.xy
    opts.texture
        :applyFunc(x, y, z, w,
            function(col, _x, _y) snapshot(origin - xy, col, _x, _y) end)
        :update()
    local updatedCoords = { region = vec(origin.x + pieceW, origin.y, pieceW, pieceH) }

    if (updatedCoords.region.w > rowLargestTex) then
        rowLargestTex = updatedCoords.region.w
    end

    REGISTRY[#REGISTRY + 1] = updatedCoords

    return updatedCoords.region, TEXTURE_MAP
end

Stitcher.map = TEXTURE_MAP

return Stitcher
