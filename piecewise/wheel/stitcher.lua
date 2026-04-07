local REGISTRY = {} ---@type RegisteredTexture[]
local Stitcher = {}

local lastColumnIndex = 0

local TEXTURE_MAP = textures:newTexture("Saved", 256, 256):fill(0, 0, 256, 256, vec(0, 0, 0, 0));

local function snapshot(vector, bounds, col, x, y)
    TEXTURE_MAP:setPixel(vector.x + x, vector.y + y, col)
end

---@class RegisteredTexture
---@field region Vector4 Uhhhh basically x and y are the lower right corners of the last texture, and w and h are the region taken up by it

---@param piece Toast.Piece
function Stitcher.addToRegistry(piece)
    local opts = piece.options
    if not opts or not opts.bounds or not opts.texture then return end
    local pieceW, pieceH = opts.bounds.z, opts.bounds.w
    local last = REGISTRY[#REGISTRY]
    local origin = vec(0, 0)

    if last then
        origin = last.region.xy
        print(last.region)
    end

    local x, y, z, w = opts.bounds:unpack()
    opts.texture
        :applyFunc(x, y, z, w,
            function(col, _x, _y) snapshot(origin, opts.bounds, col, _x, _y) end)
        :update()

    REGISTRY[#REGISTRY + 1] = { region = vec(origin.x + pieceW, origin.y, pieceW, pieceH) }
    host:setClipboard(TEXTURE_MAP:save())
end

return Stitcher
