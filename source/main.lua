import("CoreLibs/object")
import("CoreLibs/graphics")
import("CoreLibs/sprites")
import("CoreLibs/timer")
import("CoreLibs/math")
import("CoreLibs/crank")
import("CoreLibs/animation")

import("levels")

local pd <const> = playdate
local gfx <const> = pd.graphics

-- Set background to black
gfx.setColor(gfx.kColorBlack)
gfx.fillRect(0, 0, 800, 480)
gfx.setBackgroundColor(gfx.kColorBlack)

local initPlayerTileX, initPlayerTileY = 8, 14
playerX, playerY = initPlayerTileX * 32 - 16, initPlayerTileY * 32 - 16
gfx.setDrawOffset(-playerX + 200, -playerY + 120)

local playerSprite = gfx.image.new("Images/mazzy.png")

local player = gfx.sprite.new(playerSprite)

player:add()

-- Import the tileset
tilesheet = gfx.imagetable.new("Images/doubletime")

currentLevel = 1

-- Create an empty tilemap
local tilemap = {}

function buildLevel(level)
	local tilesetKeyTranslation = {
		walls = 844,
		torches = 191,
		ladders = 295,
		holes = 302,
		planks = 262,
		coins = 219,
		exit = 451,
		entrance = 452,
	}

	-- Create an empty tilemap
	-- Initialize the tilemap with empty tiles
	for i = 1, 225 do
		tilemap[i] = 0
	end

	-- function to iterate through table and set tiles
	local function setTiles(tiles, tilesetKey)
		for i = 1, #tiles do
			tilemap[tiles[i] + 1] = tilesetKeyTranslation[tilesetKey]
		end
	end

	-- Set the tiles
	setTiles(level.walls, "walls")
	setTiles(level.torches, "torches")
	setTiles(level.ladders, "ladders")
	setTiles(level.holes, "holes")
	setTiles(level.planks, "planks")
	setTiles(level.coins, "coins")
	setTiles(level.exit, "exit")
	setTiles(level.entrance, "entrance")

	-- Create a tilemap object
	tm = gfx.tilemap.new()
	tm:setImageTable(tilesheet)
	tm:setTiles(tilemap, 15)
	tm:draw(0, 0)

	background = gfx.sprite.new(tm)
	background:setCenter(0, 0)
	background:add()
end

buildLevel(levels[currentLevel])

local lerpFactor = 0.25

function isValueInTable(value, table)
	for _, v in pairs(table) do
		if v == value then
			return true
		end
	end
	return false
end

function playerIsNotBlocked(x, y, direction)
	-- Convert pixel coordinates to tile coordinates
	local tileX = (math.floor(x / 32)) + 1
	local tileY = (math.floor(y / 32)) + 1

	print("--- TARGET ---")
	print(tileX)
	print("---")
	print(tileY)
	print("---")

	-- print(isValueInTable(((tileY - 1) * 15 + tileX) - 1, levels[currentLevel].walls))

	-- print(isValueInTable((tyleY - 1) * 15 + tileX, levels[currentLevel].walls))

	return not isValueInTable(((tileY - 1) * 15 + tileX) - 1, levels[currentLevel].walls)
end

function checkPickupAt(tileIndex, type)
	local items = levels[currentLevel][type]

	for i, v in ipairs(items) do
		if v == tileIndex then
			-- Remove tile visually
			tilemap[tileIndex + 1] = 0
			tm:setTiles(tilemap, 15)

			-- Remove from the level's pickup list
			table.remove(items, i)

			-- Optional: Custom logic per type
			if type == "coins" then
				print("Coin collected!")
				-- playdate.sound.sampleplayer.new("Sounds/coin.pdm"):play()
			elseif type == "planks" then
				print("Got a plank!")
			end

			break
		end
	end
end

function pd.update()
	gfx.setDrawOffset(-player.x + 200, -player.y + 120)

	local targetX, targetY = playerX, playerY -- Store the target coordinates

	-- Check for arrow key presses and update player coordinates
	if pd.buttonJustPressed(pd.kButtonUp) and playerIsNotBlocked(targetX, targetY - 32) then
		playerY = playerY - 32
	elseif pd.buttonJustPressed(pd.kButtonDown) and playerIsNotBlocked(targetX, targetY + 32) then
		playerY = playerY + 32
	elseif pd.buttonJustPressed(pd.kButtonLeft) and playerIsNotBlocked(targetX - 32, targetY) then
		playerX = playerX - 32
	elseif pd.buttonJustPressed(pd.kButtonRight) and playerIsNotBlocked(targetX + 32, targetY) then
		playerX = playerX + 32
	end

	-- Calculate the difference between the current and target positions
	local deltaX = playerX - player.x
	local deltaY = playerY - player.y

	-- Apply linear interpolation to smooth the movement
	player.x = player.x + (deltaX * lerpFactor)
	player.y = player.y + (deltaY * lerpFactor)

	-- Update the player's position
	player:moveTo(player.x, player.y)

	local tileX = math.floor(playerX / 32)
	local tileY = math.floor(playerY / 32)
	local tileIndex = tileY * 15 + tileX

	-- Check for pickups
	checkPickupAt(tileIndex, "coins")
	checkPickupAt(tileIndex, "planks")
	checkPickupAt(tileIndex, "torches")
	checkPickupAt(tileIndex, "ladders")

	gfx.sprite.update()
	pd.timer.updateTimers()
end
