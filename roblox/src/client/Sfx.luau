--!strict
-- The Godot game's own sounds, played on Roblox. They all live in one uploaded audio file (the "sound sheet",
-- made by tools/export_sounds.sh): each sound is a stretch of it, played with PlaybackRegion.
-- Also the forest: the breeze, birds now and then, and short pieces of plucked guitar with long quiet gaps.
-- GitHub uploads the sheet and writes its id into Shared.Assets (tools/roblox_assets.py). No Roblox sounds are used
-- anywhere (even the character's own footsteps are replaced: see overrides/RbxCharacterSounds).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Assets) :: { [string]: string }
local Sheet = require(ReplicatedStorage.Shared.SoundSheet)

local Sfx = {}
Sfx.musicVolume = 0.5

local SHEET = if Assets.SoundSheet then "rbxassetid://" .. Assets.SoundSheet else nil
local BASE_VOLUME = 0.7          -- Godot's 0 dB
local STUDS = 3                  -- studs per Godot metre

local function volumeOf(db: number): number
	return BASE_VOLUME * 10 ^ (db / 20)
end

local function make(name: string, pitch: number, db: number): (Sound?, number)
	local region = Sheet.sounds[name]
	local s = Instance.new("Sound")
	local length = 1
	if SHEET and region then
		s.SoundId = SHEET
		s.PlaybackRegionsEnabled = true
		s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
		length = region[2]
	else
		s:Destroy()
		return nil, 0
	end
	s.PlaybackSpeed = pitch
	s.Volume = volumeOf(db)
	return s, length / pitch
end

local function fire(s: Sound, seconds: number)
	s:Play()
	task.delay(seconds + 0.2, function()
		s:Destroy()
	end)
end

-- A sound everywhere at once (UI, your own tool). Pitch wobbles a little, like the Godot game.
function Sfx.play(name: string, pitch: number?, db: number?)
	local s, seconds = make(name, (pitch or 1) * (0.94 + math.random() * 0.12), db or 0)
	if s then
		s.Parent = SoundService
		fire(s, seconds)
	end
end

-- A sound from a place in the world: louder close by, gone far away.
function Sfx.playAt(name: string, at: Vector3, pitch: number?, db: number?)
	local s, seconds = make(name, (pitch or 1) * (0.94 + math.random() * 0.12), db or 0)
	if s then
		local a = Instance.new("Attachment")
		a.WorldPosition = at
		a.Parent = Workspace.Terrain
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 4 * STUDS
		s.RollOffMaxDistance = 45 * STUDS
		s.Parent = a
		s:Play()
		task.delay(seconds + 0.2, function()
			a:Destroy()
		end)
	end
end

-- A sound that loops until you stop it (returns the Sound; Destroy it to stop).
function Sfx.loop(name: string, db: number?, parent: Instance?): Sound?
	local region = Sheet.sounds[name]
	if not SHEET or not region then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = SHEET
	s.PlaybackRegionsEnabled = true
	s.PlaybackRegion = NumberRange.new(region[1], region[1] + region[2])
	s.LoopRegion = s.PlaybackRegion
	s.Looped = true
	s.Volume = volumeOf(db or 0)
	s.Parent = parent or SoundService
	s:Play()
	return s
end

-- ------------------------------------------------------------------ the forest
-- the same pieces as the Godot game: four chords, arpeggiated in eighths, a melody note now and then
local PROGRESSIONS = {
	{ { 48, 55, 60, 64 }, { 45, 52, 57, 60 }, { 41, 48, 53, 57 }, { 43, 50, 55, 59 } },   -- C  Am F  G
	{ { 41, 48, 53, 57 }, { 43, 50, 55, 59 }, { 40, 47, 52, 55 }, { 45, 52, 57, 60 } },   -- F  G  Em Am
	{ { 48, 55, 60, 64 }, { 43, 50, 55, 59 }, { 45, 52, 57, 60 }, { 41, 48, 53, 57 } },   -- C  G  Am F
}
local ARP = { 1, 2, 3, 4, 3, 2, 3, 4 }
local MELODY = { 72, 74, 76, 79, 81, 76, 74 }
local EIGHTH = 0.4

local function pluck(m: number, db: number)
	if Sfx.musicVolume <= 0.001 then
		return
	end
	local s, seconds = make("note" .. m, 1, db + 20 * math.log10(Sfx.musicVolume))
	if s then
		s.Parent = SoundService
		fire(s, seconds)
	end
end

local function playPiece()
	local prog = PROGRESSIONS[math.random(#PROGRESSIONS)]
	for step = 0, 8 * 8 - 1 do
		local chord = prog[(step // 8) % 4 + 1]
		local i = ARP[step % 8 + 1]
		pluck(chord[i], if i == 1 then -16 else -19)
		if step % 8 == 0 and math.random() < 0.6 then
			pluck(MELODY[math.random(#MELODY)], -18)
		end
		task.wait(EIGHTH * (0.97 + math.random() * 0.06))     -- a little human timing
	end
end

function Sfx.start()
	if not SHEET then
		return       -- the breeze, birds and music need the uploaded sheet
	end
	-- preload the sheet so the first chop isn't silent
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = SHEET
		game:GetService("ContentProvider"):PreloadAsync({ probe })
		probe:Destroy()
	end)
	Sfx.loop("wind", -17)
	task.spawn(function()
		while true do
			task.wait(2 + math.random() * 5)
			Sfx.play("bird" .. math.random(0, 2), 0.9 + math.random() * 0.3, -8)
		end
	end)
	task.spawn(function()
		task.wait(30)          -- quiet before the first piece
		while true do
			playPiece()
			task.wait(50 + math.random() * 60)
		end
	end)
end

return Sfx
