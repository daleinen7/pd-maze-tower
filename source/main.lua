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

local font = gfx.font.new("fonts/peridot_7")
gfx.setFont(font)

local inventory = {
	coins = 0,
	planks = 0,
	torches = 0,
	ladders = 0,
}

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
local tilesheet = gfx.imagetable.new("Images/doubletime")

local currentLevel = 1

-- Create an empty tilemap
local tilemap = {}

local darknessSprite = nil

local function createDarknessSprite()
	local width, height = 400, 240 -- Playdate screen size

	-- Default is full blackout image
	local img = gfx.image.new(width, height)
	gfx.pushContext(img)
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(0, 0, width, height)
	gfx.popContext()

	darknessSprite = gfx.sprite.new(img)
	darknessSprite:setCenter(0, 0)
	darknessSprite:moveTo(0, 0)
	darknessSprite:setZIndex(300) -- Between background and player
	darknessSprite:setIgnoresDrawOffset(true)
	darknessSprite:add()
end

local darknessTimer = 0
local darknessThreshold = levels[currentLevel].darkTime[1] or 70000
local isDark = false

local torchActive = false
local torchDuration = 6000 -- 6 seconds of light
local torchEndTime = 0

local function spawnPickupSprite(tileIndex, tileID, zIndex)
	local tileX = tileIndex % 15
	local tileY = math.floor(tileIndex / 15)

	local img = tilesheet:getImage(tileID)
	local sprite = gfx.sprite.new(img)
	sprite:setCenter(0, 0)
	sprite:moveTo(tileX * 32, tileY * 32)
	sprite:setZIndex(zIndex)
	sprite:setIgnoresDrawOffset(false)
	sprite:add()
	return sprite
end

local function buildLevel(level)
	-- Clear previous level sprites
	gfx.sprite.removeAll()
	tilemap = {}

	player:add()
	createDarknessSprite()

	player:setZIndex(500)

	darknessTimer = 0
	darknessThreshold = level.darkTime[1] or 70000
	isDark = false

	pickupSprites = {
		coins = {},
		torches = {},
		planks = {},
		ladders = {},
	}

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

	for _, tileIndex in ipairs(level.coins) do
		local sprite = spawnPickupSprite(tileIndex, tilesetKeyTranslation["coins"], 400)
		table.insert(pickupSprites.coins, { tileIndex = tileIndex, sprite = sprite })
	end

	for _, tileIndex in ipairs(level.torches) do
		local sprite = spawnPickupSprite(tileIndex, tilesetKeyTranslation["torches"], 400)
		table.insert(pickupSprites.torches, { tileIndex = tileIndex, sprite = sprite })
	end

	for _, tileIndex in ipairs(level.planks) do
		local sprite = spawnPickupSprite(tileIndex, tilesetKeyTranslation["planks"], 400)
		table.insert(pickupSprites.planks, { tileIndex = tileIndex, sprite = sprite })
	end

	for _, tileIndex in ipairs(level.ladders) do
		local sprite = spawnPickupSprite(tileIndex, tilesetKeyTranslation["ladders"], 400)
		table.insert(pickupSprites.ladders, { tileIndex = tileIndex, sprite = sprite })
	end

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
	setTiles(level.holes, "holes")

	-- setTiles(level.torches, nil)
	-- setTiles(level.ladders, nil)
	-- setTiles(level.exit, nil)
	-- setTiles(level.planks, nil)
	-- setTiles(level.coins, nil)
	-- setTiles(level.entrance, nil)

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

function isWall(tileIndex)
	return isValueInTable(tileIndex, levels[currentLevel].walls)
end

function isExterior(tileIndex)
	return isValueInTable(tileIndex, {
		0,
		1,
		2,
		3,
		4,
		6,
		7,
		8,
		9,
		10,
		11,
		12,
		13,
		14,
		15,
		29,
		30,
		44,
		45,
		59,
		60,
		74,
		75,
		89,
		90,
		104,
		105,
		119,
		120,
		134,
		135,
		149,
		150,
		164,
		165,
		179,
		180,
		194,
		195,
		209,
		210,
		211,
		212,
		213,
		214,
		215,
		216,
		218,
		219,
		220,
		221,
		222,
		223,
		224,
	})
end

function isEntrance(tileIndex)
	return isValueInTable(tileIndex, levels[currentLevel].entrance)
end

function playerIsNotBlocked(x, y)
	local tileX = math.floor(x / 32) + 1
	local tileY = math.floor(y / 32) + 1
	local tileIndex = (tileY - 1) * 15 + tileX - 1

	if isEntrance(tileIndex) then
		return false
	end

	if isExterior(tileIndex) then
		return false
	end

	if isWall(tileIndex) then
		if inventory.ladders > 0 then
			-- Use a ladder to scale the wall
			inventory.ladders = inventory.ladders - 1
			print("Climbed over wall using a ladder!")

			tilemap[tileIndex + 1] = 295 -- ladder tile ID
			tm:setTiles(tilemap, 15)

			for i, v in ipairs(levels[currentLevel].walls) do
				if v == tileIndex then
					table.remove(levels[currentLevel].walls, i)
					break
				end
			end

			return true
		else
			-- Wall, no ladder = blocked
			return false
		end
	end

	-- Not a wall or entrance — it's fine!
	return true
end

function checkPickupAt(tileIndex, type)
	local items = levels[currentLevel][type]
	local sprites = pickupSprites[type]

	if not sprites then
		print("No sprite list for", type)
		return
	end
	for i, v in ipairs(items) do
		if v == tileIndex then
			print("Checking type:", type)
			print("Sprites table:", pickupSprites[type])
			print("Picked up:", type, "at tile", tileIndex)

			-- Remove tile visually
			tilemap[tileIndex + 1] = 0
			tm:setTiles(tilemap, 15)

			-- Remove from the level's pickup list
			table.remove(items, i)

			-- Update inventory
			inventory[type] = inventory[type] + 1

			-- Remove matching sprite
			for j, entry in ipairs(sprites) do
				if entry.tileIndex == tileIndex then
					entry.sprite:remove()
					table.remove(sprites, j)
					break
				end
			end

			break
		end
	end
end

function checkHole(tileIndex)
	local holes = levels[currentLevel].holes

	for i, v in ipairs(holes) do
		if v == tileIndex then
			if inventory.planks > 0 then
				-- Use a plank!
				inventory.planks = inventory.planks - 1

				-- Visually cover the hole
				tilemap[tileIndex + 1] = 262 -- plank tile ID
				tm:setTiles(tilemap, 15)

				-- Remove hole from the list so it doesn't trigger again
				table.remove(holes, i)

				print("Hole patched with plank!")
			else
				print("You fell in the hole! Game over.")
				-- You can trigger a lose state here
				playerDead = true -- or reload level, etc.
			end

			break
		end
	end
end

function updateDarkness()
	if not isDark then
		darknessSprite:setVisible(false)
		return
	end

	darknessSprite:setVisible(true)

	local width, height = 400, 240
	local img = gfx.image.new(width, height)
	gfx.pushContext(img)

	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(0, 0, width, height)

	if torchActive then
		local radius = 60
		local flicker = math.random(-3, 3)
		radius = radius + flicker

		local px, py = 200, 120 -- Center of screen (since we're ignoring draw offset)

		gfx.setColor(gfx.kColorClear)
		gfx.fillCircleAtPoint(px, py, radius)
	end

	gfx.popContext()

	darknessSprite:setImage(img)
end

function pd.update()
	local screenWidth, screenHeight = pd.display.getSize()

	gfx.setDrawOffset(-player.x + 200, -player.y + 120)

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

	if playerDead then
		gfx.setDrawOffset(0, 0)
		gfx.setColor(gfx.kColorBlack)
		gfx.fillRect(0, screenHeight / 2 - 10, screenWidth, 20)

		gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
		gfx.setColor(gfx.kColorWhite)
		gfx.drawText("You Died - Press A to Restart", 20, screenHeight / 2 - 5)

		if pd.buttonJustPressed(pd.kButtonA) then
			playerDead = false
			buildLevel(levels[currentLevel])
			playerX, playerY = initPlayerTileX * 32 - 16, initPlayerTileY * 32 - 16
			player:moveTo(playerX, playerY)
			inventory = { coins = 0, planks = 0, torches = 0, ladders = 0 }
		end

		return -- early out so nothing else runs
	end

	-- Check for level exit
	for _, v in ipairs(levels[currentLevel].exit) do
		if v == tileIndex then
			print("Level complete! Loading next level...")
			currentLevel = currentLevel + 1

			if currentLevel > #levels then
				print("You've beaten all levels!")
				-- Optionally reset to 1, show win screen, etc.
				currentLevel = 1
			end

			-- Reset everything
			buildLevel(levels[currentLevel])
			playerX, playerY = initPlayerTileX * 32 - 16, initPlayerTileY * 32 - 16
			player:moveTo(playerX, playerY)

			return -- stop running the rest of the update for this frame
		end
	end

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

	-- Check for pickups
	checkPickupAt(tileIndex, "coins")
	checkPickupAt(tileIndex, "planks")
	checkPickupAt(tileIndex, "torches")
	checkPickupAt(tileIndex, "ladders")

	-- Check for holes
	checkHole(tileIndex)

	-- Increment darkness timer
	darknessTimer = darknessTimer + pd.getElapsedTime()

	-- Trigger darkness
	if not isDark and darknessTimer > darknessThreshold then
		print("It is now dark...")
		isDark = true
	end

	gfx.sprite.update()
	pd.timer.updateTimers()

	updateDarkness()

	if isDark and pd.buttonJustPressed(pd.kButtonA) and inventory.torches > 0 and not torchActive then
		print("Torch lit!")
		torchActive = true
		torchEndTime = pd.getCurrentTimeMilliseconds() + torchDuration
		inventory.torches = inventory.torches - 1
	end

	-- Turn off torch after time expires
	if torchActive and pd.getCurrentTimeMilliseconds() > torchEndTime then
		-- Turn off torch
		print("Torch extinguished.")
		torchActive = false
	end

	-- === INVENTORY HUD ===
	-- Save current draw offset
	local ox, oy = gfx.getDrawOffset()

	gfx.setDrawOffset(0, 0)

	-- Draw background
	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(screenWidth - 80, screenHeight - 40, 78, 38)

	-- Border
	gfx.setColor(gfx.kColorWhite)
	gfx.drawRect(screenWidth - 80, screenHeight - 40, 78, 38)

	-- Text color
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	-- gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setColor(gfx.kColorWhite)

	-- Draw inventory
	gfx.drawText("Coins: " .. inventory.coins, screenWidth - 75, screenHeight - 35)
	gfx.drawText("Torches: " .. inventory.torches, screenWidth - 75, screenHeight - 28)
	gfx.drawText("Planks: " .. inventory.planks, screenWidth - 75, screenHeight - 21)
	gfx.drawText("Ladders: " .. inventory.ladders, screenWidth - 75, screenHeight - 14)

	-- Restore original draw offset
	gfx.setDrawOffset(ox, oy)
end
