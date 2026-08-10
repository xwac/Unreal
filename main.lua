repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

if identifyexecutor then
	if table.find({'Argon'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Unreal', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xwac/Unreal/'..readfile('unreal/profiles/commit.txt')..'/'..select(1, path:gsub('unreal/', ''))..'?v='..tick(), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local function escape(s)
    return s and s:gsub("\\", "\\\\"):gsub('"', '\\"') or ""
end
local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript =[[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('unreal/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/xwac/Unreal/'..readfile('unreal/profiles/commit.txt')..'/loader.lua?v='..tick(), true), 'loader')()
				end
			]]
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
			    teleportScript = 'shared.VapeCustomProfile = "'..escape(shared.VapeCustomProfile)..'"\n'..teleportScript
			end
			if getgenv().username then
			    teleportScript = 'getgenv().username = "'..escape(getgenv().username)..'"\n'..teleportScript
			end
			if getgenv().password then
			    teleportScript = 'getgenv().password = "'..escape(getgenv().password)..'"\n'..teleportScript
			end			
		
			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('Finished Loading', vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('unreal/profiles/gui.txt') then
	writefile('unreal/profiles/gui.txt', 'new')
end
local gui = readfile('unreal/profiles/gui.txt') or 'new'

if not isfolder('unreal/assets/'..gui) then
	makefolder('unreal/assets/'..gui)
end
vape = loadstring(downloadFile('unreal/guis/'..gui..'.lua'), 'gui')()
shared.vape = vape

task.spawn(function()
	if getgenv().Closet then
	local LogService = cloneref(game:GetService("LogService"))
	
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == "function" then
			local old
			old = hookfunction(getgenv()[funcName], function(...)
				return nil
			end)
		end
	end
	
	hook("print")
	hook("warn")
	hook("error")
	hook("info")
	
	pcall(function()
		LogService:ClearOutput()
	end)
	
	pcall(function()
		LogService.MessageOut:Connect(function()
			LogService:ClearOutput()
		end)
	end)
	end
end)

if not shared.VapeIndependent then
	loadstring(downloadFile('unreal/games/universal.lua'), 'universal')()

	if isfile('unreal/games/'..game.PlaceId..'.lua') then
		local gameFn = loadstring(readfile('unreal/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))
		if gameFn then gameFn() end
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/xwac/Unreal/'..readfile('unreal/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua?v='..tick(), true)
			end)
			if suc and res ~= '404: Not Found' then
				local gameFn = loadstring(downloadFile('unreal/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))
				if gameFn then gameFn() end
			end
		end
	end
	vape:CreateNotification('Unreal', 'This is in BETA. (Expect Bugs)', 5, 'alert')
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
