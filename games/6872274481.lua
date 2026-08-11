
local run = function(func) if shared.VapeSmoothBoot then task.wait() end func() end

local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		local result = rawget(self, index)
		if result == nil then
			result = Instance.new('BindableEvent')
			rawset(self, index, result)
		end
		return result
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))
local lightingService = cloneref(game:GetService('Lighting'))
local teleportService = cloneref(game:GetService("TeleportService"))
local virtualInputManager = cloneref(game:GetService('VirtualInputManager'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = os.clock(),
	damageBlockFail = os.clock(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('unreal/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestSlot, highestDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local meta = bedwars.ItemMeta[item.itemType]
		if meta then
			local source = meta.projectileSource
			if source and table.find(source.ammoItemTypes, "arrow") then
				local damage = (bedwars.ProjectileMeta[source.projectileType("arrow")] or {}).combat and bedwars.ProjectileMeta[source.projectileType("arrow")].combat.damage or 0
				if damage > highestDamage then
					bestBow, bestSlot, highestDamage = item, slot, damage
				end
			end
		end
	end
	return bestBow, bestSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item and item.itemType == itemName then
			return item, slot
		end
	end
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local best, slot, maxDmg = nil, nil, 0
	for i, item in store.inventory.inventory.items do
		local meta = bedwars.ItemMeta[item.itemType]
		local sword = meta and meta.sword
		if sword then
			local dmg = sword.damage or 0
			if dmg > maxDmg then
				best, slot, maxDmg = item, i, dmg
			end
		end
	end
	return best, slot
end

local function getTool(breakType)
	local best, slot, maxDmg = nil, nil, 0
	for i, item in store.inventory.inventory.items do
		local meta = bedwars.ItemMeta[item.itemType]
		local tool = meta and meta.breakBlock
		if tool then
			local dmg = tool[breakType] or 0
			if dmg > maxDmg then
				best, slot, maxDmg = item, i, dmg
			end
		end
	end
	return best, slot
end

-- Fallback for a block type nothing in the inventory is specialised for -- wool while
-- carrying a pickaxe but no shears, say. getTool only matches a tool declaring the
-- block's own breakType, so it returns nil there and the swap was skipped entirely,
-- leaving the sword in hand. A break tool still beats that, so take the strongest one
-- available judged by its best break value across all types. Only consulted after an
-- exact type match fails, so shears still win for wool whenever they're carried.
local function getBestBreakTool()
	local best, maxDmg = nil, 0
	for _, item in store.inventory.inventory.items do
		local meta = bedwars.ItemMeta[item.itemType]
		local breakBlock = meta and meta.breakBlock
		if breakBlock then
			for _, dmg in breakBlock do
				if type(dmg) == 'number' and dmg > maxDmg then
					best, maxDmg = item, dmg
				end
			end
		end
	end
	return best
end

local function getWool(inv)
	for _, item in (inv or store.inventory.inventory.items) do
		if item and item.itemType and item.itemType:find("wool") then
			return item.itemType, item.amount
		end
	end
end

local function getStrength(plr)
	if not (plr and plr.Player) then return 0 end
	local strength = 0
	local inv = store.inventories[plr.Player]
	if not inv then return 0 end

	for _, v in inv.items do
		local meta = bedwars.ItemMeta[v.itemType]
		if meta and meta.sword and meta.sword.damage > strength then
			strength = meta.sword.damage
		end
	end
	return strength
end

local function getPlacedBlock(pos)
	if not pos then return end
	local blockPos = bedwars.BlockController:getBlockPosition(pos)
	local store = bedwars.BlockController:getStore()
	return store and store:getBlockAt(blockPos), blockPos
end

local function getBlocksInPoints(s, e)
	local store = bedwars.BlockController:getStore()
	if not store then return {} end
	local blocks, list = store, {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					list[#list + 1] = vec * 3
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPos = entitylib.character.RootPart.Position
	local closest, bestMag = nil, 60
	local s, e = bedwars.BlockController:getBlockPosition(localPos - range), bedwars.BlockController:getBlockPosition(localPos + range)
	local blocks = getBlocksInPoints(s, e)

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local mag = (localPos - v).Magnitude
			if mag < bestMag then
				bestMag, closest = mag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local total = 0
	for name, val in char:GetAttributes() do
		if type(val) == "number" and val > 0 and name:find("Shield") then
			total += val
		end
	end
	return total
end

local function _baseGetSpeed()
    local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

    for v in modifiers do
        local val = v.constantSpeedMultiplier or 0
        if val > math.max(multi, 1) then
            increase = false
            multi = val - (0.06 * math.round(val))
        end
    end

    for v in modifiers do
        multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
    end

    if multi > 0 and increase then
        multi += 0.16 + (0.02 * math.round(multi))
    end

    return 20 * (multi + 1)
end

local function getSpeed()
    -- Delegate to shared.bedwars.getSpeed if DamageBoost has wrapped it
    local bw = shared.bedwars
    if bw and type(bw.getSpeed) == "function" then
        return bw.getSpeed()
    end
    return _baseGetSpeed()
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = os.clock() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < os.clock() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		-- acos is monotonically DECREASING on [-1, 1], so comparing the raw dots
		-- the other way round gives the identical ordering without two acos calls
		-- per comparison -- this runs O(n log n) per Heartbeat when sorting by Angle
		local selfroot = entitylib.character.RootPart
		local selfrootpos = selfroot.Position
		local localfacing = selfroot.CFrame.LookVector * Vector3.new(1, 0, 1)
		local dota = localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit)
		local dotb = localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit)
		return dota > dotb
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = os.clock(),
					Jumping = false,
					LandTick = os.clock(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = os.clock()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = os.clock()
										entity.Jumps += 1
										entity.LandTick = os.clock() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

-- pistonware funcs

local genv = getgenv()
-- Idempotent shared-state defaults: fill a key only if a previous execution
-- hasn't already set it. Add new flags here instead of another line below.
-- (== nil, not `or`, so a stored `false` is never clobbered back to default.)
for key, default in pairs({
	AntiLagbackDelayFactor   = 1,
	IsLongJumping            = false,
	LongJumpFireballThrown   = false,
	ItemOwner                = "none",
	ProjectileAuraFiringLock = false,
}) do
	if genv[key] == nil then
		genv[key] = default
	end
end

local function ensureCharPrimaryPart(char)
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp and char.PrimaryPart ~= hrp then
        pcall(function() char.PrimaryPart = hrp end)
    end
end

ensureCharPrimaryPart(lplr.Character)
lplr.CharacterAdded:Connect(function(c)
    c:WaitForChild("HumanoidRootPart", 5)
    ensureCharPrimaryPart(c)
end)

-- == shared __namecall guard ==
-- There is exactly ONE global __namecall hook in the whole product and it lives
-- here, in the unobfuscated file. Every namecall in the game -- including the
-- tens of thousands Roact issues while it builds and re-renders the item shop --
-- passes through this function, so it must stay native-speed Lua. A hook
-- installed from bedwars.lua costs a Luraph VM re-entry on each of those calls,
-- which is what turned opening the shop (and every purchase re-render) into a
-- visible hitch while leaving the unobfuscated build smooth.
--
-- Modules that need to see or block a specific remote register the exact
-- (Instance, method) pair here via shared.bedwars.namecallGuard instead. The hot
-- path cost is one hash lookup; handlers only ever run for instances somebody
-- actually asked about.
local namecallWatch = {}
local namecallGuard = {}

-- handler may be `true` to swallow the call outright, or a function -- return a
-- truthy value from it to swallow the call, nil/false to let it through.
-- Method names are matched exactly as getnamecallmethod() reports them.
function namecallGuard.watch(inst, method, handler)
    if typeof(inst) ~= 'Instance' or type(method) ~= 'string' then return false end
    local entry = namecallWatch[inst]
    if not entry then
        entry = {}
        namecallWatch[inst] = entry
    end
    entry[method] = handler or true
    return true
end

function namecallGuard.block(inst, method)
    return namecallGuard.watch(inst, method, true)
end

function namecallGuard.unwatch(inst, method)
    local entry = inst and namecallWatch[inst]
    if not entry then return end
    if method then
        entry[method] = nil
        if next(entry) == nil then
            namecallWatch[inst] = nil
        end
    else
        namecallWatch[inst] = nil
    end
end

local getnamecallmethod = getnamecallmethod
local mt = getrawmetatable(game)
setreadonly(mt, false)
local oldNamecall = mt.__namecall
mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    if method == "GetPrimaryPartCFrame" and self and self:IsA("Model") then
        local pp = self.PrimaryPart
            or self:FindFirstChild("HumanoidRootPart")
            or self:FindFirstChildWhichIsA("BasePart")
        if pp then
            return pp.CFrame
        else
            return CFrame.new()
        end
    end
    local entry = namecallWatch[self]
    if entry then
        local handler = entry[method]
        if handler == true then
            return
        elseif handler then
            local ok, blocked = pcall(handler, self, ...)
            if ok and blocked then return end
        end
    end
    return oldNamecall(self, ...)
end
setreadonly(mt, true)

local blankFunction = function(...) return ... end

local RunLoops = {RenderStepTable = {}, StepTable = {}, HeartTable = {}}
local vapeConnections = {}

function RunLoops:BindToRenderStep(name, func)
    if RunLoops.RenderStepTable[name] == nil then
        RunLoops.RenderStepTable[name] = runService.RenderStepped:Connect(func)
    end
end

function RunLoops:UnbindFromRenderStep(name)
    if RunLoops.RenderStepTable[name] then
        RunLoops.RenderStepTable[name]:Disconnect()
        RunLoops.RenderStepTable[name] = nil
    end
end

function RunLoops:BindToStepped(name, func)
    if RunLoops.StepTable[name] == nil then
        RunLoops.StepTable[name] = runService.Stepped:Connect(func)
    end
end

function RunLoops:UnbindFromStepped(name)
    if RunLoops.StepTable[name] then
        RunLoops.StepTable[name]:Disconnect()
        RunLoops.StepTable[name] = nil
    end
end

function RunLoops:BindToHeartbeat(name, func)
    if RunLoops.HeartTable[name] == nil then
        RunLoops.HeartTable[name] = runService.Heartbeat:Connect(func)
    end
end

function RunLoops:UnbindFromHeartbeat(name)
    if RunLoops.HeartTable[name] then
        RunLoops.HeartTable[name]:Disconnect()
        RunLoops.HeartTable[name] = nil
    end
end

local function entryMatches(objName, list)
    if not list or not list.Objects then return false end
    local lowerName = objName:lower()
    for _, entry in pairs(list.Objects) do
        local nameString
        if typeof(entry) == "string" then
            nameString = entry
        elseif entry:IsA("TextButton") or entry:IsA("TextLabel") then
            nameString = entry.Text ~= "" and entry.Text or entry.Name
        else
            nameString = entry.Name
        end
        if nameString then
            nameString = nameString:lower():gsub("^%s*(.-)%s*$", "%1")
            if nameString ~= "" and lowerName:find(nameString) then
                return true
            end
        end
    end
    return false
end

local function safeGetProto(func, index)
    if not func then return nil end
    local success, proto = pcall(debug.getproto, func, index)
    if success then
        return proto
    else
        warn("function:", func, "index:", index)
        return nil
    end
end

-- pistonware funcs

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AdetundeUpgradeMeta = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-upgrades']).FrostyHammerUpgradeMeta,
		AdetundeUtil = require(replicatedStorage.TS.games.bedwars.items['frosty-hammer']['frosty-hammer-util']).FrostyHammerUtil,
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DamageIndicator = Knit.Controllers.DamageIndicatorController.spawnDamageIndicator,
		DefaultKillEffect = require(lplr.PlayerScripts.TS.controllers.global.locker["kill-effect"].effects['default-kill-effect']),
		EmoteType = require(replicatedStorage.TS.locker.emote['emote-type']).EmoteType,
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		PingController = require(lplr.PlayerScripts.TS.controllers.game.ping["ping-controller"]).PingController,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		StatusEffectUtil = require(replicatedStorage.TS['status-effect']['status-effect-util']).StatusEffectUtil,
		StatusEffectMeta = require(replicatedStorage.TS['status-effect']['status-effect-type']).StatusEffectType,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		SummonerKitBalance = require(replicatedStorage.TS.games.bedwars.kit.kits.summoner['summoner-kit-balance']).SummonerKitBalance,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 7),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = safeGetProto(Knit.Controllers.AfkController.KnitStart, 1),
		AttackEntity = Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController.trigger,
		CannonAim = safeGetProto(Knit.Controllers.CannonController.startAiming, 5),
		CannonLaunch = Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = safeGetProto(Knit.Controllers.BatteryController.onKitLocalActivated, 1),
		ConsumeItem = safeGetProto(Knit.Controllers.ConsumeController.onEnable, 1),
		ConsumeSoul = Knit.Controllers.GrimReaperController.consumeSoul,
		DepositPinata = safeGetProto(safeGetProto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5),
		DragonBreath = safeGetProto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5),
		DragonEndFly = safeGetProto(Knit.Controllers.VoidDragonController.flapWings, 1),
		DragonFly = Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = safeGetProto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4),
		FireProjectile = debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2),
		GroundHit = Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController.performHeal,
		HannahKill = safeGetProto(Knit.Controllers.HannahController.registerExecuteInteractions, 1),
		HarvestCrop = safeGetProto(safeGetProto(Knit.Controllers.CropController.KnitStart, 4), 1),
		KaliyahPunch = safeGetProto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1),
		MageSelect = safeGetProto(Knit.Controllers.MageController.registerTomeInteraction, 1),
		MinerDig = safeGetProto(Knit.Controllers.MinerController.setupMinerPrompts, 1),
		PickupItem = Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = safeGetProto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4),
		ReportPlayer = require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer,
		ResetCharacter = safeGetProto(Knit.Controllers.ResetController.createBindable, 1),
		SpawnRaven = safeGetProto(Knit.Controllers.RavenController.KnitStart, 1),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = safeGetProto(Knit.Controllers.WarlockStaffController.KnitStart, 2)
	}

	local function dumpRemote(tab)
		local ind
		for i, v in tab do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and tab[ind + 1] or ''
	end

	for i, v in remoteNames do
		local remote = dumpRemote(debug.getconstants(v))
		if remote == '' then
			--notif('Unreal', 'Failed to grab remote ('..i..')', 10, 'alert')
		end
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = os.clock() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local store = bedwars.BlockController:getStore()
		if not store then return OldBreak(self, breakTable, plr) end
		local obj = store:getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local store = bedwars.BlockController:getStore()
		if not store then return block:GetAttribute('Health') end
		local blockdata = store:getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	-- Walks the block grid from a target cell back toward the player and returns the first
	-- solid cell standing in the way -- i.e. what someone standing here could actually put a
	-- tool on. calculatePath calls a cell diggable when ANY of its six faces touches air,
	-- including the face underneath it or the one on the far side, so its answer on its own
	-- happily digs a covered bed straight through its cover.
	--
	-- Done against the block store rather than with a raycast: blocks render through chunked
	-- geometry, so a ray reports chunk parts instead of the block the store hands back and
	-- cannot tell a target apart from whatever covers it.
	local function frontOf(worldpos)
		if not entitylib.isAlive then return worldpos end
		local origin = entitylib.character.RootPart.Position
		for _ = 1, 12 do
			local direction = origin - worldpos
			-- close enough to be the cell we are standing in; nothing left in the way
			if direction.Magnitude <= 3 then break end
			local ax, ay, az = math.abs(direction.X), math.abs(direction.Y), math.abs(direction.Z)
			local step
			if ax >= ay and ax >= az then
				step = Vector3.new(direction.X > 0 and 3 or -3, 0, 0)
			elseif ay >= az then
				step = Vector3.new(0, direction.Y > 0 and 3 or -3, 0)
			else
				step = Vector3.new(0, 0, direction.Z > 0 and 3 or -3)
			end
			local nextblock = getPlacedBlock(worldpos + step)
			-- open air on the way to the player: the current cell is the exposed one
			if not nextblock or nextblock:GetAttribute('NoBreak') then break end
			worldpos = worldpos + step
		end
		return worldpos
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	-- blockcheck: when true, walk the chosen dig spot back to whatever physically stands
	--   between it and the player, so cover comes off first instead of being mined through.
	--   Anything else (false, or the nil every other caller passes) leaves the original
	--   behaviour completely alone -- pathfind and dig, cover or no cover.
	-- method: 'Distance' ranks candidates by how far the dig spot is from the player;
	--   anything else keeps the original ranking, fewest hits to get through. The ranking
	--   still decides which cell is aimed at; blockcheck only walks that choice back to
	--   whatever is physically in front of it.
	-- autotool: pick the tool by selecting its hotbar slot (what the AutoTool module does)
	--   instead of equipping it directly. The correct tool is equipped either way -- this
	--   only decides which route gets used.
	-- The ranking matters: picking purely by hit count can settle on a spot on the far side
	-- of the block, and the 30-stud guard below then aborts the break outright.
	bedwars.breakBlock = function(block, effects, anim, customHealthbar, blockcheck, method, autotool)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge
		local selfpos = entitylib.character.RootPart.Position
		local positions = (handler and handler:getContainedPositions(block)) or {block.Position / 3}

		for _, v in positions do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			if dpos then
				local score = method == 'Distance' and (selfpos - dpos).Magnitude or dcost
				if score < cost then
					cost, pos, target, path = score, dpos, v * 3, dpath
				end
			end
		end

		-- Block Check. The spot chosen above is picked by the selected metric, but it can sit
		-- behind the cover (an air face under the bed, or one on its far side) and hitting it
		-- there is what reads as mining straight through the blocks. Step back along the line
		-- to the player and take the first cell actually in the way, so the cover comes off
		-- first from the side the player is standing on.
		if blockcheck and pos then
			local front = frontOf(pos)
			if front ~= pos then
				-- path described the old target; drop it so the visualiser stops drawing a
				-- chain that no longer leads anywhere
				pos, path = front, nil
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			-- The recent-swing gate keeps the sword in hand mid-fight for callers that
			-- pass autotool=false. When the caller explicitly asked for AutoTool it has
			-- to win instead: Breaker runs its loop continuously, so with a killaura or
			-- autoclicker active lastAttack is refreshed constantly, this window never
			-- opened and the tool swap simply never happened -- the block got mined with
			-- whatever was already held.
			local blockmeta = bedwars.ItemMeta[dblock.Name]
			blockmeta = blockmeta and blockmeta.block
			if blockmeta and (autotool or (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4) then
				local breaktype = blockmeta.breakType
				-- store.tools is only rebuilt when the Rodux inventory fires an items
				-- change, so it can still be empty (or stale) at the moment a break
				-- starts. Rescan on a miss rather than silently skipping the swap --
				-- a nil here meant the whole block below was skipped and the block got
				-- mined with the sword, which looks exactly like AutoTool doing nothing.
				local tool = breaktype and (store.tools[breaktype] or getTool(breaktype))
				-- Exact type match first (shears for wool), then the best break tool
				-- carried (a pickaxe on wool). Gated on autotool so the other callers,
				-- which pass it nil, keep their previous hold-the-sword behaviour.
				if not tool and autotool then
					tool = getBestBreakTool()
				end
				if tool and tool.tool then
					-- autotool: move the hotbar selection onto the tool the way the AutoTool
					-- module does it -- an InventorySelectHotbarSlot dispatch, i.e. the same
					-- path as pressing the number key -- so the swap happens through the
					-- game's own selection instead of a bare EquipItem.
					local slot
					if autotool then
						for i, v in store.inventory.hotbar or {} do
							if v.item and v.item.itemType == tool.itemType then
								slot = i - 1
								break
							end
						end
					end
					-- Both, not either. The hotbar dispatch only moves the client's
					-- selected slot; it is not proof the character actually ended up
					-- holding the tool. Treating a successful dispatch as "done" and
					-- skipping the equip is what left the sword in hand while the UI
					-- showed the pickaxe selected -- and block damage is resolved from
					-- what is actually held (BlockEngine.calculateBlockDamage takes the
					-- player), so the block still got mined with the sword. switchItem
					-- no-ops when the tool is already in hand, so this costs nothing.
					if slot then
						hotbarSwitch(slot)
					end
					switchItem(tool.tool)
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = os.clock() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							if bedwars.BlockBreaker.healthbarMaid then
								bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							end
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	-- Coalesces inventory-change fan-out so a single shop purchase (which causes
	-- multiple bedwars.Store updates in one frame) only notifies the downstream
	-- listeners (AutoBuy / AutoConsume / AutoHotbar, each doing full inventory
	-- scans) once per frame instead of once per store dispatch. The synchronous
	-- store.tools/store.hand updates are kept inline so nothing reads stale data.
	local invFireQueued = false
	local pendingAmount = false
	local function flushInventoryEvents()
		invFireQueued = false
		local amount = pendingAmount
		pendingAmount = false
		vapeEvents.InventoryChanged:Fire()
		if amount then
			vapeEvents.InventoryAmountChanged:Fire()
		end
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			local invChanged    = newinv ~= oldinv
			local itemsChanged  = newinv.inventory.items ~= oldinv.inventory.items

			if itemsChanged then
				-- keep tool cache synchronous (small scans, read elsewhere immediately)
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
				pendingAmount = true
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end

			-- Defer the event fan-out to end-of-frame so multiple dispatches in the
			-- same frame coalesce into a single notification to each listener.
			if invChanged and not invFireQueued then
				invFireQueued = true
				task.defer(flushInventoryEvents)
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})
	
	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end
	
	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	-- cache projectile names we care about
	local validProjectiles = {
		arrow = true,
		snowball = true
	}

	-- optimized ZapNetworking hook
	vape:Clean(bedwars.ZapNetworking.ProjectileLaunchZap.On(function(origin, projectileType, tool, shooter)
		task.defer(function()
			local lowerType = tostring(projectileType):lower()
			if validProjectiles[lowerType] then
				-- only search nearby objects, not entire workspace
				for _, obj in ipairs(workspace:GetChildren()) do
					if validProjectiles[obj.Name:lower()] then
						local root = obj:FindFirstChildWhichIsA("BasePart")
						if root and (root.Position - origin).Magnitude < 25 then
							vapeEvents.ProjectileFired:Fire({
								origin = origin,
								projectile = obj,
								tool = tool,
								shooter = shooter
							})
							break -- stop after first match
						end
					end
				end
			end
		end)
	end))

	local projectileNames = {arrow = true, snowball = true}
	vape:Clean(workspace.ChildAdded:Connect(function(child)
		if projectileNames[child.Name:lower()] then
			task.defer(function()
				local root = child:FindFirstChildWhichIsA("BasePart")
				if root then
					vapeEvents.ProjectileFired:Fire({
						origin = root.Position,
						projectile = child,
						tool = nil,
						shooter = lplr.Character
					})
				end
			end)
		end
	end))
	
	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end	

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and os.clock() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or os.clock()
				if (os.clock() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery', 'Swim', 'Jesus', 'Invisible', 'Desync', 'Waypoints', 'PlayerModel', 'Schematica'} do
	vape:Remove(v)
end
run(function()
	local AimAssist
	local Targets
	local Sort
	local AimSpeed
	local Distance
	local AngleSlider
	local StrafeIncrease
	local KillauraTarget
	local ClickAim

	-- Ignore decoy/NPC models named "Falcon" (e.g. workspace["Falcon-1"]).
	-- A real player named Falcon still has a backing Player object AND a valid
	-- (hyphen-free) username, so gating on "no Player" only skips fake models
	-- while never sparing an actual person called Falcon.
	local function isFalconDecoy(ent)
		if not ent or ent.Player then return false end
		local name = ent.Character and ent.Character.Name
		return name ~= nil and (name == 'Falcon' or name:match('^Falcon%-') ~= nil)
	end

	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		Function = function(callback)
			if callback then
				AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
					if entitylib.isAlive and store.hand.toolType == 'sword' and ((not ClickAim.Enabled) or (os.clock() - bedwars.SwordController.lastSwing) < 0.4) then
						local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
							Range = Distance.Value,
							Part = 'RootPart',
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						}) or store.KillauraTarget
	
						if ent then
							if isFalconDecoy(ent) then return end
							local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
							if angle >= (math.rad(AngleSlider.Value) / 2) then return end
							targetinfo.Targets[ent] = tick() + 1
							gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, ent.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt)
						end
					end
				end))
			end
		end,
		Tooltip = 'Smoothly aims to closest valid target with sword'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AimAssist:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim Speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffx = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click Aim',
		Default = true
	})
	KillauraTarget = AimAssist:CreateToggle({
		Name = 'Use killaura target'
	})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
end)
	
run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = os.clock()
					return false
				end
			else
				bedwars.SwordController.isClickingTooFast = old
			end
		end,
		Tooltip = 'Remove the CPS cap'
	})
end)
	
run(function()
	local Value
	
	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and Value.Value + 2 or 14.4
		end,
		Tooltip = 'Extends attack reach'
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Function = function(val)
			if Reach.Enabled then
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local Sprint
	local old
	
	Sprint = vape.Categories.Combat:CreateModule({
		Name = 'Sprint',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then 
					pcall(function()
						lplr.PlayerGui.MobileUI['4'].Visible = false 
					end)
				end
				old = bedwars.SprintController.stopSprinting
				bedwars.SprintController.stopSprinting = function(...)
					local call = old(...)
					bedwars.SprintController:startSprinting()
					return call
				end
				Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
					task.delay(0.1, function() 
						bedwars.SprintController:stopSprinting() 
					end) 
				end))
				bedwars.SprintController:stopSprinting()
			else
				if inputService.TouchEnabled then 
					pcall(function() 
						lplr.PlayerGui.MobileUI['4'].Visible = true 
					end) 
				end
				bedwars.SprintController.stopSprinting = old
				bedwars.SprintController:stopSprinting()
			end
		end,
		Tooltip = 'Sets your sprinting to true.'
	})
end)
	
run(function()
	local TriggerBot
	local CPS
	local rayParams = RaycastParams.new()
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		Function = function(callback)
			if callback then
				repeat
					local doAttack
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
							local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
							rayParams.FilterDescendantsInstances = {lplr.Character}
	
							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								for _, ent in entitylib.List do
									doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end
	
							doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
					end
	
					task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Automatically swings when hovering over a entity'
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
end)
	
run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local TargetCheck
	local rand, old = Random.new()
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				old = bedwars.KnockbackUtil.applyKnockback
				bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
					if rand:NextNumber(0, 100) > Chance.Value then return end
					local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true
					})
	
					if check then
						knockback = knockback or {}
						if Horizontal.Value == 0 and Vertical.Value == 0 then return end
						knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
						knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
					end
					
					return old(root, mass, dir, knockback, ...)
				end
			else
				bedwars.KnockbackUtil.applyKnockback = old
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = function(val) return '%' end
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = function(val) return '%' end
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = function(val) return '%' end
	})
	TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		local store = bedwars.BlockController:getStore()
		if not store then return end
		for _, pos in store:getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1) until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), os.clock()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < os.clock() then
							debounce = os.clock() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)
	
run(function()
	local FastBreak
	local Time
	local BlacklistBeds
	local BlacklistOres

	-- The cooldown the game ships with, restored on disable and used as the "don't
	-- speed this one up" value for blacklisted blocks.
	local VANILLA_COOLDOWN = 0.3

	-- Name of the block currently under the crosshair, read through the same block
	-- selector AutoTool and Schematica use. Mode 1 is SELECT (the block being looked
	-- at); mode 0 is PLACE, which resolves to the empty cell in front of it instead.
	local function targetedBlockName()
		local ok, name = pcall(function()
			local breaker = bedwars.BlockBreakController.blockBreaker
			local info = breaker.clientManager:getBlockSelector():getMouseInfo(1)
			local target = info and info.target
			local block = target and target.blockInstance
			return block and block.Name
		end)
		return ok and name or nil
	end

	-- Ores are named <material>_ore_mesh_block. Matched as a plain substring plus a
	-- trailing _ore, so diamond/emerald/gold are covered without hardcoding a list
	-- that a new ore would silently fall out of. Neither pattern can hit 'store' or
	-- 'core' -- both need the underscore.
	local function isOre(name)
		return name:find('ore_mesh_block', 1, true) ~= nil or name:match('_ore$') ~= nil
	end

	local function currentCooldown()
		local name = targetedBlockName()
		if name then
			if BlacklistBeds.Enabled and name == 'bed' then return VANILLA_COOLDOWN end
			if BlacklistOres.Enabled and isOre(name) then return VANILLA_COOLDOWN end
		end
		return Time.Value
	end

	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				repeat
					-- With both blacklists off this is the original once-per-100ms
					-- setCooldown and costs exactly what it used to. With one on we need
					-- to react the frame the crosshair moves onto a bed/ore, otherwise
					-- the stale value lets a fast hit or two through before the next
					-- poll catches up -- so tighten to per-frame only in that case.
					local filtering = BlacklistBeds.Enabled or BlacklistOres.Enabled
					bedwars.BlockBreakController.blockBreaker:setCooldown(filtering and currentCooldown() or Time.Value)
					if filtering then
						task.wait()
					else
						task.wait(0.1)
					end
				until not FastBreak.Enabled
			else
				bedwars.BlockBreakController.blockBreaker:setCooldown(VANILLA_COOLDOWN)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = function(val) return 's' end
	})
	BlacklistBeds = FastBreak:CreateToggle({
		Name = 'Blacklist Beds',
		Tooltip = 'Breaks beds at the normal speed instead'
	})
	BlacklistOres = FastBreak:CreateToggle({
		Name = 'Blacklist Ores',
		Tooltip = 'Breaks ores at the normal speed instead'
	})
end)
	
local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end

				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))

				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
						local char = entitylib.character
						local balloons = lplr.Character:GetAttribute('InflatedBalloons')  -- one attribute read, not two
						local flyAllowed = (balloons and balloons > 0) or store.matchState == 2
						local mass = (1.5 + (flyAllowed and 6 or 0) * (os.clock() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = char.RootPart, char.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))

				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))

				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))

				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})

	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})

	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
end)
	
run(function()
	local Mode
	local Expand
	local objects, set = {}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					pcall(function() bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = (Expand.Value / 3) + 3.8 end)
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					pcall(function() bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = 3.8 end)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					pcall(function() bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = (val / 3) + 3.8 end)
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local AngleSlider
	local UpdateRate
	local MaxTargets
	local HitChance
	local AttackSpeed
	local Mouse
	local Swing
	local GUI
	local Attackable
	local BoxSwingColor
	local BoxAttackColor
	local BoxAnim
	local BoxAnimSpeed
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local FastHits
	local Projectiles
	local LegitSwitch
	local FireRate
	local Particles, Boxes = {}, {}
	local anims = vape.Libraries.auraanims
	if not anims then
		anims = {
			Stab = {{CFrame = CFrame.Angles(math.rad(40), 0, 0), Time = 0.1}},
			Slash = {{CFrame = CFrame.Angles(0, math.rad(-120), 0), Time = 0.1}},
			Horizontal = {{CFrame = CFrame.Angles(0, math.rad(-80), 0), Time = 0.08}, {CFrame = CFrame.Angles(0, math.rad(80), 0), Time = 0.08}},
			Vertical = {{CFrame = CFrame.Angles(math.rad(-80), 0, 0), Time = 0.08}, {CFrame = CFrame.Angles(math.rad(80), 0, 0), Time = 0.08}},
			Diagonal = {{CFrame = CFrame.Angles(math.rad(60), math.rad(60), 0), Time = 0.12}},
			Spin = {{CFrame = CFrame.Angles(0, math.rad(180), 0), Time = 0.1}, {CFrame = CFrame.Angles(0, math.rad(360), 0), Time = 0.1}}
		}
		vape.Libraries.auraanims = anims
	end
	local AnimDelay, AnimTween, armC0 = tick()
	local AttackRemote = {FireServer = function() end}
	local Attacking = false
	task.spawn(function()
		AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	local function fireProjectileAt(ent)
		for _, item in store.inventory.inventory.items do
			if not item.tool or not item.tool.Parent then continue end
			local name = item.itemType or ''
			for _, p in pairs(Projectiles.List) do
				if name == p or name:find(p) ~= nil then
					pcall(function()
						switchItem(item.tool, 0)
						local src = bedwars.ItemMeta and bedwars.ItemMeta[name] and bedwars.ItemMeta[name].projectileSource
						if src and bedwars.ProjectileController and bedwars.ProjectileController.startCharging then
							local projType = name
							if src.projectileType then
								local ok, result = pcall(src.projectileType, src)
								if ok and result then projType = result end
							end
							bedwars.ProjectileController:startCharging(projType, entitylib.character.RootPart.CFrame)
							task.wait(FireRate.Value)
							if bedwars.ProjectileController.releaseProjectile then
								bedwars.ProjectileController:releaseProjectile(entitylib.character.RootPart.CFrame)
							end
						end
					end)
					return true
				end
			end
		end
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled then
					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in pairs(anims[AnimationMode.Value]) do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = Sort.Value == 'Distance' and function(a, b)
								local root = entitylib.character and entitylib.character.RootPart
								if not root then return false end
								if not a.RootPart then return false end
								if not b.RootPart then return true end
								local apos = a.RootPart.Position - root.Position
								local bpos = b.RootPart.Position - root.Position
								return apos.Magnitude < bpos.Magnitude
							end or sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position
							local localfacing = entitylib.character and entitylib.character.RootPart and (entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1))
							if not selfpos or not localfacing then continue end

							for i, v in pairs(plrs) do
								if not v.RootPart then continue end
								if Attackable.Enabled and not v.Targetable then continue end
								if HitChance.Value < 100 and math.random() > (HitChance.Value / 100) then continue end

								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and (meta.sword.attackSpeed or 0.11) or 0.11)
										pcall(function()
											bedwars.SwordController:playSwordEffect(meta, false)
											if meta.displayName and meta.displayName:find(' Scythe') then
												bedwars.ScytheController:playLocalAnimation()
											end
										end)

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								if delta.Magnitude > AttackRange.Value then continue end

								local actualRoot = v.Character and v.Character.PrimaryPart
								if actualRoot then
									if FastHits.Enabled and i == 1 then
										fireProjectileAt(v)
									end
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (delta.Magnitude * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									AttackRemote:FireServer({
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = actualRoot.Position},
											selfPosition = {value = pos}
										}
									})

									if AttackSpeed.Value > 0 then
										task.wait(AttackSpeed.Value)
									end
								end
							end
						end
					end

					for i, v in pairs(Boxes) do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
							local base = Vector3.new(3, 5, 3)
							if BoxAnim.Value == 'Bounce' then
								local s = math.abs(math.sin(tick() * (BoxAnimSpeed.Value + 1) * 3))
								v.Size = base * (0.6 + s * 0.8)
							else
								local progress = math.clamp((tick() % 1) * (BoxAnimSpeed.Value + 1) * 2, 0, 1)
								v.Size = base * (0.4 + 0.6 * progress)
							end
						end
					end

					for i, v in pairs(Particles) do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					task.wait(#attacked > 0 and #attacked * 0.02 or 1 / UpdateRate.Value)
				until not Killaura.Enabled
			else
				store.KillauraTarget = nil
				for _, v in pairs(Boxes) do
					v.Adornee = nil
				end
				for _, v in pairs(Particles) do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in pairs(sortmethods) do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 28,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 5,
		Default = 5
	})
	HitChance = Killaura:CreateSlider({
		Name = 'Hit chance',
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	AttackSpeed = Killaura:CreateSlider({
		Name = 'Attack speed',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0,
		Suffix = function(val) return val == 1 and 'second' or 'seconds' end
	})
	FastHits = Killaura:CreateToggle({
		Name = 'Fast Hits',
		Default = false,
		Function = function(enabled)
			pcall(function()
				Projectiles.Object.Visible = enabled
				LegitSwitch.Object.Visible = enabled
				FireRate.Object.Visible = enabled
			end)
		end,
		Tooltip = 'Deals more damage quicker using projectiles'
	})
	Projectiles = Killaura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'},
		Darker = true,
		Visible = false,
		Tooltip = 'Projectiles to use for fasthits'
	})
	LegitSwitch = Killaura:CreateToggle({
		Name = 'Legit Switch',
		Darker = true,
		Visible = false
	})
	FireRate = Killaura:CreateSlider({
		Name = 'Fire rate',
		Suffix = 'seconds',
		Min = 0,
		Max = 2,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Default = 0.05
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	Attackable = Killaura:CreateToggle({Name = 'Attackable check'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			BoxAnim.Object.Visible = callback
			BoxAnimSpeed.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in pairs(Boxes) do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	local boxAnimationModes = {'Bounce'}
	for _, easingStyle in Enum.EasingStyle:GetEnumItems() do
		if not table.find(boxAnimationModes, easingStyle.Name) then
			table.insert(boxAnimationModes, easingStyle.Name)
		end
	end
	BoxAnim = Killaura:CreateDropdown({
		Name = 'Box Animation',
		List = boxAnimationModes,
		Darker = true,
		Visible = false
	})
	BoxAnimSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in pairs(Particles) do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in pairs(Particles) do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in pairs(Particles) do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in pairs(Particles) do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in pairs(Particles) do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in pairs(anims) do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)
run(function()
	local SafeWalk
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local module, old
	
	SafeWalk = vape.Categories.World:CreateModule({
		Name = 'SafeWalk',
		Function = function(callback)
			if callback then
				if not module then
					local suc = pcall(function() 
						module = require(lplr.PlayerScripts.PlayerModule).controls 
					end)
					if not suc then module = {} end
				end
				
				old = module.moveFunction
				module.moveFunction = function(self, vec, face)
					if entitylib.isAlive then
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						local root = entitylib.character.RootPart
						local movedir = root.Position + vec
						local ray = workspace:Raycast(movedir, Vector3.new(0, -15, 0), rayCheck)
						if not ray then
							local check = workspace:Blockcast(root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(entitylib.character.HipHeight + 1), 0), rayCheck)
							if check then
								vec = (check.Instance:GetClosestPointOnSurface(movedir) - root.Position) * Vector3.new(1, 0, 1)
							end
						end
					end
	
					return old(self, vec, face)
				end
			else
				if module and old then
					module.moveFunction = old
				end
			end
		end,
		Tooltip = 'Prevents you from walking off the edge of parts'
	})
end)

run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
	
run(function()
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
						if entitylib.isAlive and not Fly.Enabled and not vape.Modules.LongJump.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local char = entitylib.character
						local hum = char.Humanoid
						local state = hum:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end

						local root, velo = char.RootPart, getSpeed()
						local moveDirection = AntiFallDirection or hum.MoveDirection
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
	
						if WallCheck.Enabled then
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end
	
						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
							hum:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)
	
run(function()
	local BedESP
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function Added(bed)
		if not BedESP.Enabled then return end
		local BedFolder = Instance.new('Folder')
		BedFolder.Parent = Folder
		Reference[bed] = BedFolder
		local parts = bed:GetChildren()
		table.sort(parts, function(a, b)
			return a.Name > b.Name
		end)
	
		for _, part in parts do
			if part:IsA('BasePart') and part.Name ~= 'Blanket' then
				local handle = Instance.new('BoxHandleAdornment')
				handle.Size = part.Size + Vector3.new(.01, .01, .01)
				handle.AlwaysOnTop = true
				handle.ZIndex = 2
				handle.Visible = true
				handle.Adornee = part
				handle.Color3 = part.Color
				if part.Name == 'Legs' then
					handle.Color3 = Color3.fromRGB(167, 112, 64)
					handle.Size = part.Size + Vector3.new(.01, -1, .01)
					handle.CFrame = CFrame.new(0, -0.4, 0)
					handle.ZIndex = 0
				end
				handle.Parent = BedFolder
			end
		end
	
		table.clear(parts)
	end
	
	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
					task.delay(0.2, Added, bed)
				end))
				BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
					if Reference[bed] then
						Reference[bed]:Destroy()
						Reference[bed] = nil
					end
				end))
				for _, bed in collectionService:GetTagged('bed') do
					Added(bed)
				end
			else
				Folder:ClearAllChildren()
				table.clear(Reference)
			end
		end,
		Tooltip = 'Render Beds through walls'
	})
end)
	
run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
		Name = 'Health',
		Function = function(callback)
			if callback then
				local label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 30)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' â¤ï¸' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				label.TextSize = 18
				label.Font = Enum.Font.Arial
				label.Parent = vape.gui
				Health:Clean(label)
				Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
					label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' â¤ï¸' or ''
					label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
				end))
			end
		end,
		Tooltip = 'Displays your health in the center of your screen.'
	})
end)
	
run(function()
    local KitESP
    local Background
    local Color = {}
    local Reference = {}
    -- model -> adornee part recorded at billboard creation, so removal cleanup
    -- doesn't depend on PrimaryPart still being set (it's often nil by then)
    local ModelParts = {}
    -- per-kit tag connections, disconnected whenever the tracked kit changes
    local kitConns = {}
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local ESPKits = {
        alchemist = {'alchemist_ingedients', 'wild_flower'},
        beekeeper = {'bee', 'bee'},
        bigman = {'treeOrb', 'natures_essence_1'},
        ghost_catcher = {'ghost', 'ghost_orb'},
        metal_detector = {'hidden-metal', 'iron'},
        sheep_herder = {'SheepModel', 'purple_hay_bale'},
        sorcerer = {'alchemy_crystal', 'wild_flower'},
        star_collector = {'stars', 'crit_star'}
    }

    local function Added(v, icon)
        if not v then return end
        -- Billboards live under vape.gui (CoreGui). Tag/added signals invoke this
        -- on game threads at identity 2, where parenting into CoreGui silently
        -- throws â€” which is why only enable-time (exploit thread) objects showed.
        if vape.ThreadFix then
            setthreadidentity(8)
        end
        if Reference[v] then
            if Reference[v].Billboard then
                Reference[v].Billboard:Destroy()
            end
            Reference[v] = nil
        end

        local billboard = Instance.new('BillboardGui')
        billboard.Parent = Folder
        billboard.Name = icon
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
        billboard.Size = UDim2.fromOffset(36, 36)
        billboard.AlwaysOnTop = true
        billboard.ClipsDescendants = false
        billboard.Adornee = v

        local blur = addBlur(billboard)
        blur.Visible = Background.Enabled

        local image = Instance.new('ImageLabel')
        image.Name = "ImageLabel"
        image.Size = UDim2.fromOffset(36, 36)
        image.Position = UDim2.fromScale(0.5, 0.5)
        image.AnchorPoint = Vector2.new(0.5, 0.5)
        image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
        image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
        image.BorderSizePixel = 0
        image.Image = bedwars.getIcon({itemType = icon}, true)
        image.Parent = billboard

        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 4)
        uicorner.Parent = image

        -- Store all references including Blur and ImageLabel
        Reference[v] = {
            Billboard = billboard,
            Blur = blur,
            ImageLabel = image
        }
    end

    -- A model is often tagged a frame before its PrimaryPart is assigned. Reading
    -- v.PrimaryPart at tag time then gives nil and the billboard is skipped forever
    -- (why it only worked after a disable/re-enable, once the models were fully built).
    -- Wait for PrimaryPart before adding.
    local function addWhenReady(v, icon)
        if not v then return end
        if v.PrimaryPart then
            ModelParts[v] = v.PrimaryPart
            Added(v.PrimaryPart, icon)
            return
        end
        task.spawn(function()
            local timeout = os.clock() + 5
            while not v.PrimaryPart and v.Parent and os.clock() < timeout do
                task.wait()
            end
            if v.PrimaryPart and KitESP and KitESP.Enabled then
                ModelParts[v] = v.PrimaryPart
                Added(v.PrimaryPart, icon)
            end
        end)
    end

    -- Drops every billboard and per-kit tag connection. Called on disable AND on
    -- kit change, so stale objects from the previous kit can't linger.
    local function clearTracked()
        for _, c in kitConns do
            pcall(function() c:Disconnect() end)
        end
        table.clear(kitConns)
        if vape.ThreadFix then
            setthreadidentity(8)
        end
        Folder:ClearAllChildren()
        table.clear(Reference)
        table.clear(ModelParts)
    end

    local function addKit(tag, icon)
        table.insert(kitConns, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
            addWhenReady(v, icon)
        end))

        table.insert(kitConns, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
            local part = ModelParts[v] or v.PrimaryPart
            ModelParts[v] = nil
            if part and Reference[part] then
                if vape.ThreadFix then
                    setthreadidentity(8)
                end
                if Reference[part].Billboard then
                    Reference[part].Billboard:Destroy()
                end
                Reference[part] = nil
            end
        end))

        for _, v in pairs(collectionService:GetTagged(tag)) do
            addWhenReady(v, icon)
        end
    end

    -- Bumped each toggle so a stale enable-loop from a quick off/on can't keep
    -- running alongside the new one.
    local loopId = 0

    KitESP = vape.Categories.Render:CreateModule({
        Name = 'KitESP',
        Function = function(callback)
            loopId += 1
            if callback then
                local myId = loopId

                if KitESP.Clean then
                    KitESP:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
                        local deadEnt = entitylib.getEntity(deathTable.entityInstance)
                        if deadEnt and deadEnt.RootPart and Reference[deadEnt.RootPart] then
                            if vape.ThreadFix then
                                setthreadidentity(8)
                            end
                            if Reference[deadEnt.RootPart].Billboard then
                                Reference[deadEnt.RootPart].Billboard:Destroy()
                            end
                            Reference[deadEnt.RootPart] = nil
                        end
                    end))
                end

                -- Kits can change mid-session (kit swap, new match): whenever the
                -- equipped kit differs from what we're tracking, wipe the old
                -- kit's billboards/connections and start tracking the new tag.
                local lastKit = nil
                repeat
                    local kit = store.equippedKit
                    if kit ~= lastKit then
                        lastKit = kit
                        clearTracked()
                        local info = ESPKits[kit]
                        if info then
                            addKit(info[1], info[2])
                        end
                    end
                    task.wait(0.5)
                until (not KitESP.Enabled) or loopId ~= myId
            else
                clearTracked()
            end
        end,
        Tooltip = 'ESP for certain kit related objects'
    })

    Background = KitESP:CreateToggle({
        Name = 'Background',
        Function = function(callback)
            if Color.Object then Color.Object.Visible = callback end
            for _, v in pairs(Reference) do
                if v.ImageLabel then
                    v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
                end
                if v.Blur then
                    v.Blur.Visible = callback
                end
            end
        end,
        Default = true
    })

    Color = KitESP:CreateColorSlider({
        Name = 'Background Color',
        DefaultValue = 0,
        DefaultOpacity = 0.5,
        Function = function(hue, sat, val, opacity)
            for _, v in pairs(Reference) do
                if v.ImageLabel then
                    v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
                    v.ImageLabel.BackgroundTransparency = 1 - opacity
                end
            end
        end,
        Darker = true
    })
end)

run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local DisplayName
	local Health
	local Distance
	local Equipment
	local Rank
	local Device
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder
	
	pcall(function()
		Folder = Instance.new('Folder')
		Folder.Parent = vape.gui
	end)
	
	local methodused
	-- assigned once the Updated table below exists; lets the rank fetch redraw a tag when
	-- the division finally lands
	local refreshTag

	local RankMeta = (function()
		local suc, res = pcall(function()
			return require(replicatedStorage.TS.rank['rank-meta']).RankMeta
		end)
		return suc and res or nil
	end)()

	local rankRequested = {}

	local function getRankImage(plr)
		if not (RankMeta and plr) then return nil end
		local controller = bedwars.RankController
		local cache = controller and controller.rankCache
		local division = cache and cache[plr.UserId]
		local meta = division and RankMeta[division]
		return meta and meta.image or nil
	end

	-- the icon rides the right edge of the text, so everywhere that re-measures the tag has
	-- to move it as well
	local function positionRankIcon(nametag, width)
		local icon = nametag:FindFirstChild('RankIcon')
		if icon then
			icon.Position = UDim2.fromOffset(width + 10, -4)
		end
	end

	local function requestRank(plr, ent)
		if not plr or rankRequested[plr.UserId] then return end
		local controller = bedwars.RankController
		if not (controller and controller.getRanks) then return end
		rankRequested[plr.UserId] = true
		task.spawn(function()
			pcall(function()
				-- forced: getRanks skips the server call once its cache holds anything, so
				-- an uncached player would otherwise never resolve
				controller:getRanks({plr.UserId}, true):andThen(function()
					if refreshTag then refreshTag(ent) end
				end)
			end)
		end)
	end

	local deviceEmojis = {gamepad = 'ðŸŽ®', touch = 'ðŸ“±', keyboard = 'ðŸ–¥ï¸'}

	local function getDeviceEmoji(plr)
		if not plr then return nil end
		-- checked on the character too, in case the attribute is written there
		local inputType = plr:GetAttribute('UserInputType')
		if inputType == nil and plr.Character then
			inputType = plr.Character:GetAttribute('UserInputType')
		end
		if inputType == nil then return nil end
		if type(inputType) == 'number' then
			-- Enum.UserInputType values: Touch 7, Keyboard 8, Gamepad1..8 9-16
			if inputType == 7 then return deviceEmojis.touch end
			if inputType == 8 then return deviceEmojis.keyboard end
			if inputType >= 9 and inputType <= 16 then return deviceEmojis.gamepad end
			return deviceEmojis.keyboard
		end
		-- covers a plain string and an EnumItem alike ("Enum.UserInputType.Touch"), and the
		-- platform-flavoured values some servers write instead of the enum names
		local name = tostring(inputType):lower()
		if name:find('gamepad') or name:find('console') or name:find('xbox') or name:find('playstation') then
			return deviceEmojis.gamepad
		end
		if name:find('touch') or name:find('mobile') or name:find('phone') or name:find('tablet') then
			return deviceEmojis.touch
		end
		-- anything left that carries a value at all is a desktop input (keyboard, any of
		-- the mouse variants, MouseMovement, TextInput...), so fall through rather than
		-- silently showing nothing
		return name ~= '' and deviceEmojis.keyboard or nil
	end

	local Added = {
		Normal = function(ent)
			pcall(function()
				if not Targets.Players.Enabled and ent.Player then return end
				if not Targets.NPCs.Enabled and ent.NPC then return end
				if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
				if Reference[ent] then return end -- Prevent duplicates

				local nametag = Instance.new('TextLabel')
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

				if Device.Enabled and ent.Player then
					local emoji = getDeviceEmoji(ent.Player)
					if emoji then
						Strings[ent] = emoji..' '..Strings[ent]
					end
				end

				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end

				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end

				if Equipment.Enabled then
					for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
						local Icon = Instance.new('ImageLabel')
						Icon.Name = v
						Icon.Size = UDim2.fromOffset(30, 30)
						Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
						Icon.BackgroundTransparency = 1
						Icon.Image = ''
						Icon.Parent = nametag
					end
				end

				nametag.TextSize = 14 * Scale.Value
				nametag.FontFace = FontOption.Value
				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)

				-- Rank Icon: sits immediately to the right of the text, so it has to be
				-- built after the text has been measured
				if Rank.Enabled and ent.Player then
					local Icon = Instance.new('ImageLabel')
					Icon.Name = 'RankIcon'
					Icon.Size = UDim2.fromOffset(30, 30)
					Icon.Position = UDim2.fromOffset(size.X + 10, -4)
					Icon.BackgroundTransparency = 1
					Icon.Image = getRankImage(ent.Player) or ''
					Icon.Parent = nametag
					if Icon.Image == '' then
						requestRank(ent.Player, ent)
					end
				end
				nametag.AnchorPoint = Vector2.new(0.5, 1)
				nametag.BackgroundColor3 = Color3.new()
				nametag.BackgroundTransparency = Background.Value
				nametag.BorderSizePixel = 0
				nametag.Visible = false
				nametag.Text = Strings[ent]
				nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				nametag.RichText = true
				nametag.Parent = Folder
				Reference[ent] = nametag
			end)
		end,
		Drawing = function(ent)
			pcall(function()
				if not Targets.Players.Enabled and ent.Player then return end
				if not Targets.NPCs.Enabled and ent.NPC then return end
				if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end
				if Reference[ent] then return end

				local nametag = {}
				nametag.BG = Drawing.new('Square')
				nametag.BG.Filled = true
				nametag.BG.Transparency = 1 - Background.Value
				nametag.BG.Color = Color3.new()
				nametag.BG.ZIndex = 1
				nametag.Text = Drawing.new('Text')
				nametag.Text.Size = 15 * Scale.Value
				nametag.Text.Font = 0
				nametag.Text.ZIndex = 2
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

				-- Drawing text only; the rank icon needs an ImageLabel, which this render
				-- path has no equivalent for
				if Device.Enabled and ent.Player then
					local emoji = getDeviceEmoji(ent.Player)
					if emoji then
						Strings[ent] = emoji..' '..Strings[ent]
					end
				end

				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end

				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
				end

				nametag.Text.Text = Strings[ent]
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				Reference[ent] = nametag
			end)
		end
	}
	
	local Removed = {
		Normal = function(ent)
			pcall(function()
				local v = Reference[ent]
				if v then
					Reference[ent] = nil
					Strings[ent] = nil
					Sizes[ent] = nil
					v:Destroy()
				end
			end)
		end,
		Drawing = function(ent)
			pcall(function()
				local v = Reference[ent]
				if v then
					Reference[ent] = nil
					Strings[ent] = nil
					Sizes[ent] = nil
					for _, obj in v do
						pcall(function()
							obj.Visible = false
							obj:Remove()
						end)
					end
				end
			end)
		end
	}
	
	local Updated = {
		Normal = function(ent)
			pcall(function()
				local nametag = Reference[ent]
				if not nametag or not nametag.Parent then return end
				
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

				if Device.Enabled and ent.Player then
					local emoji = getDeviceEmoji(ent.Player)
					if emoji then
						Strings[ent] = emoji..' '..Strings[ent]
					end
				end

				if Health.Enabled then
					local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
					Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
				end

				if Distance.Enabled then
					Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
				end

				if Equipment.Enabled and store.inventories[ent.Player] and nametag:FindFirstChild("Hand") then
					local kit = ent.Player:GetAttribute('PlayingAsKit')
					local inventory = store.inventories[ent.Player]
					nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
					nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
					nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
					nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
					nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
				end

				if Rank.Enabled and ent.Player then
					local icon = nametag:FindFirstChild('RankIcon')
					if icon then
						icon.Image = getRankImage(ent.Player) or ''
					end
				end

				local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
				nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
				positionRankIcon(nametag, size.X)
				nametag.Text = Strings[ent]
			end)
		end,
		Drawing = function(ent)
			pcall(function()
				local nametag = Reference[ent]
				if not nametag then return end
				
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				Sizes[ent] = nil
				Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

				if Device.Enabled and ent.Player then
					local emoji = getDeviceEmoji(ent.Player)
					if emoji then
						Strings[ent] = emoji..' '..Strings[ent]
					end
				end

				if Health.Enabled then
					Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
				end

				if Distance.Enabled then
					Strings[ent] = '[%s] '..Strings[ent]
					nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
				else
					nametag.Text.Text = Strings[ent]
				end

				nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
				nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			end)
		end
	}
	
	refreshTag = function(ent)
		if Reference[ent] and Updated[methodused] then
			Updated[methodused](ent)
		end
	end

	local ColorFunc = {
		Normal = function(hue, sat, val)
			pcall(function()
				local color = Color3.fromHSV(hue, sat, val)
				for i, v in Reference do
					if v and v.Parent then
						v.TextColor3 = entitylib.getEntityColor(i) or color
					end
				end
			end)
		end,
		Drawing = function(hue, sat, val)
			pcall(function()
				local color = Color3.fromHSV(hue, sat, val)
				for i, v in Reference do
					if v and v.Text then
						v.Text.Color = entitylib.getEntityColor(i) or color
					end
				end
			end)
		end
	}
	
	local Loop = {
		Normal = function()
			pcall(function()
				-- Local player's position is identical for every nametag this frame;
				-- resolve the property chain once instead of per-entity.
				local selfPos = entitylib.isAlive and entitylib.character.RootPart.Position
				for ent, nametag in Reference do
					if not nametag or not nametag.Parent then
						Reference[ent] = nil
						continue
					end
					
					if DistanceCheck.Enabled then
						local distance = selfPos and (selfPos - ent.RootPart.Position).Magnitude or math.huge
						if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
							nametag.Visible = false
							continue
						end
					end

					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
					nametag.Visible = headVis
					if not headVis then
						continue
					end

					if Distance.Enabled then
						local mag = selfPos and math.floor((selfPos - ent.RootPart.Position).Magnitude) or 0
						if Sizes[ent] ~= mag then
							nametag.Text = string.format(Strings[ent], mag)
							local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
							nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
							positionRankIcon(nametag, ize.X)
							Sizes[ent] = mag
						end
					end
					nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
				end
			end)
		end,
		Drawing = function()
			pcall(function()
				-- Local player's position is identical for every nametag this frame;
				-- resolve the property chain once instead of per-entity.
				local selfPos = entitylib.isAlive and entitylib.character.RootPart.Position
				for ent, nametag in Reference do
					if not nametag or not nametag.Text or not nametag.BG then
						Reference[ent] = nil
						continue
					end

					if DistanceCheck.Enabled then
						local distance = selfPos and (selfPos - ent.RootPart.Position).Magnitude or math.huge
						if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
							nametag.Text.Visible = false
							nametag.BG.Visible = false
							continue
						end
					end

					local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
					nametag.Text.Visible = headVis
					nametag.BG.Visible = headVis
					if not headVis then
						continue
					end

					if Distance.Enabled then
						local mag = selfPos and math.floor((selfPos - ent.RootPart.Position).Magnitude) or 0
						if Sizes[ent] ~= mag then
							nametag.Text.Text = string.format(Strings[ent], mag)
							nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
							Sizes[ent] = mag
						end
					end
					nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
					nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
				end
			end)
		end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
		Name = 'NameTags',
		Function = function(callback)
			if callback then
				methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
				if Removed[methodused] then
					NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
				end
				if Added[methodused] then
					for _, v in entitylib.List do
						if Reference[v] then
							Removed[methodused](v)
						end
						Added[methodused](v)
					end
					NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
						if Reference[ent] then
							Removed[methodused](ent)
						end
						Added[methodused](ent)
					end))
				end
				if Updated[methodused] then
					NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
					for _, v in entitylib.List do
						Updated[methodused](v)
					end
				end
				if ColorFunc[methodused] then
					NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
						ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
					end))
				end
				if Loop[methodused] then
					NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
				end

				-- UserInputType can replicate after the tag was built (and changes when a
				-- player switches input), and the tag is only rebuilt on health/equipment
				-- updates -- which is why the emoji was missing on some players and not
				-- others. Redraw whoever's attribute lands or changes.
				local function watchDevice(plr)
					NameTags:Clean(plr:GetAttributeChangedSignal('UserInputType'):Connect(function()
						if not Device.Enabled then return end
						local ent = entitylib.getEntity(plr)
						if ent then
							refreshTag(ent)
						end
					end))
				end

				for _, plr in playersService:GetPlayers() do
					watchDevice(plr)
				end
				NameTags:Clean(playersService.PlayerAdded:Connect(watchDevice))
			else
				if Removed[methodused] then
					for i in Reference do
						Removed[methodused](i)
					end
				end
			end
		end,
		Tooltip = 'Renders nametags on entities through walls.'
	})
	Targets = NameTags:CreateTargets({
		Players = true,
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	FontOption = NameTags:CreateFont({
		Name = 'Font',
		Blacklist = 'Arial',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Color = NameTags:CreateColorSlider({
		Name = 'Player Color',
		Function = function(hue, sat, val)
			if NameTags.Enabled and ColorFunc[methodused] then
				ColorFunc[methodused](hue, sat, val)
			end
		end
	})
	Scale = NameTags:CreateSlider({
		Name = 'Scale',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10
	})
	Background = NameTags:CreateSlider({
		Name = 'Transparency',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = 0.5,
		Min = 0,
		Max = 1,
		Decimal = 10
	})
	Health = NameTags:CreateToggle({
		Name = 'Health',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Distance = NameTags:CreateToggle({
		Name = 'Distance',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Equipment = NameTags:CreateToggle({
		Name = 'Equipment',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end
	})
	Rank = NameTags:CreateToggle({
		Name = 'Show Rank',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Tooltip = 'Shows the ranked division icon above the nametag'
	})
	Device = NameTags:CreateToggle({
		Name = 'Show Device',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Tooltip = 'Shows ðŸŽ® / ðŸ–¥ï¸ / ðŸ“± for the input device the player is on'
	})
	DisplayName = NameTags:CreateToggle({
		Name = 'Use Displayname',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	Teammates = NameTags:CreateToggle({
		Name = 'Priority Only',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
		Default = true
	})
	DrawingToggle = NameTags:CreateToggle({
		Name = 'Drawing',
		Function = function()
			if NameTags.Enabled then
				NameTags:Toggle()
				NameTags:Toggle()
			end
		end,
	})
	DistanceCheck = NameTags:CreateToggle({
		Name = 'Distance Check',
		Function = function(callback)
			DistanceLimit.Object.Visible = callback
		end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
		Name = 'Player Distance',
		Min = 0,
		Max = 256,
		DefaultMin = 0,
		DefaultMax = 64,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local StorageESP
	local List
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function nearStorageItem(item)
		for _, v in List.ListEnabled do
			if item:find(v) then return v end
		end
	end
	
	local function refreshAdornee(v)
		local chest = v.Adornee:FindFirstChild('ChestFolderValue')
		chest = chest and chest.Value or nil
		if not chest then
			v.Enabled = false
			return
		end
	
		local chestitems = chest and chest:GetChildren() or {}
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		v.Enabled = false
		local alreadygot = {}
		for _, item in chestitems do
			if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
				alreadygot[item.Name] = true
				v.Enabled = true
				local blockimage = Instance.new('ImageLabel')
				blockimage.Size = UDim2.fromOffset(32, 32)
				blockimage.BackgroundTransparency = 1
				blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
				blockimage.Parent = v.Frame
			end
		end
		table.clear(chestitems)
	end
	
	local function Added(v)
		local chest = v:WaitForChild('ChestFolderValue', 3)
		if not (chest and StorageESP.Enabled) then return end
		chest = chest.Value
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'chest'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		StorageESP:Clean(chest.ChildAdded:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
			if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
				refreshAdornee(billboard)
			end
		end))
		task.spawn(refreshAdornee, billboard)
	end
	
	StorageESP = vape.Categories.Render:CreateModule({
		Name = 'StorageESP',
		Function = function(callback)
			if callback then
				StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
				for _, v in collectionService:GetTagged('chest') do
					task.spawn(Added, v)
				end
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays items in chests'
	})
	List = StorageESP:CreateTextList({
		Name = 'Item',
		Function = function()
			for _, v in Reference do
				task.spawn(refreshAdornee, v)
			end
		end
	})
	Background = StorageESP:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then Color.Object.Visible = callback end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = StorageESP:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local AutoBalloon
	
	AutoBalloon = vape.Categories.Utility:CreateModule({
		Name = 'AutoBalloon',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1) until store.matchState ~= 0 or (not AutoBalloon.Enabled)
				if not AutoBalloon.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then 
						lowestpoint = point 
					end
				end
	
				repeat
					if entitylib.isAlive then
						if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
							local balloon = getItem('balloon')
							if balloon then
								for _ = 1, 3 do 
									bedwars.BalloonController:inflateBalloon() 
								end
							end
							task.wait(0.1)
						end
					end
					task.wait(0.1)
				until not AutoBalloon.Enabled
			end
		end,
		Tooltip = 'Inflates when you fall into the void'
	})
end)
	
run(function()
	local AutoKit
	local Legit
	local Toggles = {}
	
	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or v.PrimaryPart
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end
	
	local AutoKitFunctions = {
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end
	
			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...
	
				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false, nil, true)
					end
				end
	
				return unpack(res)
			end
	
			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end
	
				if ent and getItem('guitar') then
					bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
						healTarget = ent.Character
					})
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped
	
			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end
	
			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)
	
			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})
	
					if plr then
						bedwars.Client:Get(remotes.DragonBreath):SendToServer({
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})
	
					if plr and plr.Character ~= lastTarget then
						if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
							target = plr.Character
						}) then
							plr = nil
						end
					end
	
					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end
	
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
	}
	
	AutoKit = vape.Categories.Utility:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1) until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = bedwars.BedwarsKitMeta[v].name,
			Default = true
		})
	end
end)
	
run(function()
	local AutoPlay
	local Random
	
	local function isEveryoneDead()
		return #bedwars.Store:getState().Party.members <= 0
	end
	
	local function joinQueue()
		if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
			if Random.Enabled then
				local listofmodes = {}
				for i, v in bedwars.QueueMeta do
					if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
						table.insert(listofmodes, i) 
					end
				end
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
			else
				bedwars.QueueController:joinQueue(store.queueType)
			end
		end
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
	Random = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)
	
run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait(0.1) 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)
	
run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Inventory:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1) until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', os.clock() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)
	
run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)

run(function()
	local PickupRange
	local Range
	local Network
	local Lower
	
	PickupRange = vape.Categories.Utility:CreateModule({
		Name = 'PickupRange',
		Function = function(callback)
			if callback then
				local items = collection('ItemDrop', PickupRange)
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in items do
							if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
							if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
								v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
							end
							
							if (localPosition - v.Position).Magnitude <= Range.Value then
								if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
								task.spawn(function()
									bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.SoundManager:playSound(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
							end
						end
					end
					task.wait(0.1)
				until not PickupRange.Enabled
			end
		end,
		Tooltip = 'Picks up items from a farther distance'
	})
	Range = PickupRange:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(val) 
			return val == 1 and 'stud' or 'studs' 
		end
	})
	Network = PickupRange:CreateToggle({
		Name = 'Network TP',
		Default = true
	})
	Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)

run(function()
	local RavenTP
	
	RavenTP = vape.Categories.Utility:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('raven') and plr then
					bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart
	
							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)
	
run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined = {}

	if vape.ThreadFix then
		setthreadidentity(8)
	end
	
	local function getRole(plr, id)
		local suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if not suc then
			notif('StaffDetector', res, 30, 'alert')
		end
		return suc and res or 0
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then
			repeat task.wait(0.1) until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function checkFriends(list)
		for _, v in list do
			if joined[v] then
				return joined[v]
			end
		end
		return nil
	end
	
	-- MatchState.RUNNING (match-state module: PRE 0, RUNNING 1, POST 2).
	local MATCH_RUNNING = 1
	-- A whole queue teleports into the server at once, but slow clients keep trickling in for a
	-- while after the match has already flipped to RUNNING, and until the server finishes with
	-- them they look exactly like a mid-match join: Spectator with no Team. Anyone who turns up
	-- inside this window counts as part of the original queue.
	local JOIN_GRACE = 45
	-- Time to let a Team assignment land before calling someone team-less.
	local SETTLE = 10
	local matchRunningSince
	-- Weak keys: entries for players who left go away on their own instead of pinning the Player
	-- instance for the rest of the session.
	local arrivedAfter = setmetatable({}, {__mode = 'k'})
	local resolved = setmetatable({}, {__mode = 'k'})

	-- Seconds the match has been RUNNING, or nil if it is not. Injecting mid-match starts this
	-- clock at injection rather than at the true match start, which only ever makes the check
	-- below more conservative. Read straight off the store rather than store.matchState: the
	-- mirror is only filled in by the Store.changed handler, so it still reads PRE for the first
	-- dispatch or two after injecting into an already-running match.
	local function matchRunningFor()
		if bedwars.Store:getState().Game.matchState ~= MATCH_RUNNING then
			matchRunningSince = nil
			return nil
		end
		matchRunningSince = matchRunningSince or os.clock()
		return os.clock() - matchRunningSince
	end

	local function isSpectating(plr)
		return plr:GetAttribute('Spectator') == true and not plr:GetAttribute('Team')
	end

	local function checkJoin(plr)
		if resolved[plr] or not isSpectating(plr) then return end
		if bedwars.Store:getState().Game.customMatch then return end

		-- Gate on when the player ARRIVED, not on when this check happens to fire. A late
		-- loader's Spectator attribute can settle minutes into the match, long past the grace
		-- window, so keying the window off 'now' -- as this did by having no window at all --
		-- is what flagged them. nil means they were already here when StaffDetector turned on,
		-- and we never saw them arrive, so there is nothing to judge.
		local arrival = arrivedAfter[plr]
		if not arrival or arrival < JOIN_GRACE then return end

		resolved[plr] = true
		-- Let them finish loading before deciding they have no team. 'PlayerConnected' is the
		-- game's own has-this-client-finished-connecting flag (GamePlayer.hasFinishedConnecting).
		local deadline = os.clock() + 30
		while plr.Parent and plr:GetAttribute('PlayerConnected') ~= true and os.clock() < deadline do
			task.wait(0.5)
		end
		task.wait(SETTLE)
		-- Re-verify. A late loader has a Team by now, at which point there was never anything
		-- to report; clearing resolved lets a genuine later transition still be caught.
		if not plr.Parent or not isSpectating(plr) then
			resolved[plr] = nil
			return
		end

		local suc, tab = pcall(function()
			local ids, pages = {}, playersService:GetFriendsAsync(plr.UserId)
			for _ = 1, 4 do
				for _, v in pages:GetCurrentPage() do
					table.insert(ids, v.Id)
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
			return ids
		end)
		-- GetFriendsAsync throws on rate limits and on private friend lists. A failed lookup is
		-- not evidence of anything -- treating it as 'has no friends here' would flag on nothing.
		if not suc then
			resolved[plr] = nil
			return
		end

		local friend = checkFriends(tab)
		if not friend then
			staffFunction(plr, 'impossible_join')
		else
			notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
		end
	end

	local function playerAdded(plr, existing)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
		if not existing then
			arrivedAfter[plr] = matchRunningFor()
		end

		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
		elseif getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
		else
			-- Spawned rather than called inline: checkJoin now yields while the player settles,
			-- and blocking the signal handler would stall every later attribute change on them.
			StaffDetector:Clean(plr:GetAttributeChangedSignal('Spectator'):Connect(function()
				task.spawn(checkJoin, plr)
			end))
			-- Covers a mid-match join whose Spectator attribute replicated with the player, so
			-- no change signal ever fires for it.
			task.spawn(checkJoin, plr)

			if not plr:GetAttribute('ClanTag') then
				plr:GetAttributeChangedSignal('ClanTag'):Wait()
			end

			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
				resolved[plr] = true
				staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					-- existing = true: these were already here, so no arrival stamp and no
					-- impossible-join check. The blacklist and staff-role checks still run.
					task.spawn(playerAdded, v, true)
				end
			else
				table.clear(joined)
				table.clear(arrivedAfter)
				table.clear(resolved)
				matchRunningSince = nil
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			if StaffDetector and StaffDetector.Toggle then
			StaffDetector:Toggle()
		end
		end
	end)
end)
	
run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'TrapDisabler',
		Tooltip = 'Disables Snap Traps'
	})
end)
	
run(function()
	vape.Categories.World:CreateModule({
		Name = 'Anti-AFK',
		Function = function(callback)
			if callback then
				for _, v in getconnections(lplr.Idled) do
					v:Disconnect()
				end

				for _, v in getconnections(runService.Heartbeat) do
					if type(v.Function) == 'function' and islclosure(v.Function) then
						local ok, constants = pcall(debug.getconstants, v.Function)
						if ok and table.find(constants, remotes.AfkStatus) then
							v:Disconnect()
						end
					end
				end

				bedwars.Client:Get(remotes.AfkStatus):SendToServer({
					afk = false
				})
			end
		end,
		Tooltip = 'Lets you stay ingame without getting kicked'
	})
end)
	
run(function()
	local AutoSuffocate
	local Range
	local LimitItem
	
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end
	
	AutoSuffocate = vape.Categories.World:CreateModule({
		Name = 'AutoSuffocate',
		Function = function(callback)
			if callback then
				repeat
					local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()
	
					if item then
						local plrs = entitylib.AllPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = true
						})
	
						for _, ent in plrs do
							local needPlaced = {}
	
							for _, side in Enum.NormalId:GetEnumItems() do
								side = Vector3.fromNormalId(side)
								if side.Y ~= 0 then continue end
	
								side = fixPosition(ent.RootPart.Position + side * 2)
								if not getPlacedBlock(side) then
									table.insert(needPlaced, side)
								end
							end
	
							if #needPlaced < 3 then
								table.insert(needPlaced, fixPosition(ent.Head.Position))
								table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))
	
								for _, pos in needPlaced do
									if not getPlacedBlock(pos) then
										task.spawn(bedwars.placeBlock, pos, item)
										break
									end
								end
							end
						end
					end
	
					task.wait(0.09)
				until not AutoSuffocate.Enabled
			end
		end,
		Tooltip = 'Places blocks on nearby confined entities'
	})
	Range = AutoSuffocate:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 20,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	LimitItem = AutoSuffocate:CreateToggle({
		Name = 'Limit to Items',
		Default = true
	})
end)
	
run(function()
	local AutoTool
	local old, event
	
	local function switchHotbarItem(block)
		if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
			local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
			if tool then
				for i, v in store.inventory.hotbar do
					if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
				end
	
				if hotbarSwitch(slot) then
					if inputService:IsMouseButtonPressed(0) then 
						event:Fire() 
					end
					return true
				end
			end
		end
	end
	
	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				event = Instance.new('BindableEvent')
				AutoTool:Clean(event)
				AutoTool:Clean(event.Event:Connect(function()
					contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
				end))
				old = bedwars.BlockBreaker.hitBlock
				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
					if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
					return old(self, maid, raycastparams, ...)
				end
			else
				bedwars.BlockBreaker.hitBlock = old
				old = nil
			end
		end,
		Tooltip = 'Automatically selects the correct tool'
	})
end)
	
run(function()
	local BedProtector
	
	local function getBedNear()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude < 20 and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
				return v
			end
		end
	end
	
	local function getBlocks()
		local blocks = {}
		for _, item in store.inventory.inventory.items do
			local block = bedwars.ItemMeta[item.itemType].block
			if block then
				table.insert(blocks, {item.itemType, block.health})
			end
		end
		table.sort(blocks, function(a, b) 
			return a[2] > b[2]
		end)
		return blocks
	end
	
	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end
	
	BedProtector = vape.Categories.World:CreateModule({
		Name = 'BedProtector',
		Function = function(callback)
			if callback then
				local bed = getBedNear()
				bed = bed and bed.Position or nil
				if bed then
					for i, block in getBlocks() do
						for _, pos in getPyramid(i, 3) do
							if not BedProtector.Enabled then break end
							if getPlacedBlock(bed + pos) then continue end
							bedwars.placeBlock(bed + pos, block[1], false)
						end
					end
					if BedProtector.Enabled then 
						BedProtector:Toggle() 
					end
				else
					notif('BedProtector', 'Unable to locate bed', 5)
					BedProtector:Toggle()
				end
			end
		end,
		Tooltip = 'Automatically places strong blocks around the bed.'
	})
end)
	
run(function()
	local ChestSteal
	local Range
	local Open
	local Skywars
	local Delays = {}
	
	local function lootChest(chest)
		chest = chest and chest.Value or nil
		local chestitems = chest and chest:GetChildren() or {}
		if #chestitems > 1 and (Delays[chest] or 0) < tick() then
			Delays[chest] = tick() + 0.2
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)
	
			for _, v in chestitems do
				if v:IsA('Accessory') then
					task.spawn(function()
						pcall(function()
							bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
						end)
					end)
				end
			end
	
			bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
		end
	end
	
	ChestSteal = vape.Categories.World:CreateModule({
		Name = 'ChestSteal',
		Function = function(callback)
			if callback then
				local chests = collection('chest', ChestSteal)
				repeat task.wait() until store.queueType ~= 'bedwars_test'
				if (not Skywars.Enabled) or store.queueType:find('skywars') then
					repeat
						if entitylib.isAlive and store.matchState ~= 2 then
							if Open.Enabled then
								if bedwars.AppController:isAppOpen('ChestApp') then
									lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
								end
							else
								local localPosition = entitylib.character.RootPart.Position
								for _, v in chests do
									if (localPosition - v.Position).Magnitude <= Range.Value then
										lootChest(v:FindFirstChild('ChestFolderValue'))
									end
								end
							end
						end
						task.wait(0.1)
					until not ChestSteal.Enabled
				end
			end
		end,
		Tooltip = 'Grabs items from near chests.'
	})
	Range = ChestSteal:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
	Skywars = ChestSteal:CreateToggle({
		Name = 'Only Skywars',
		Function = function()
			if ChestSteal.Enabled then
				ChestSteal:Toggle()
				ChestSteal:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local Schematica
	local File
	local Mode
	local Transparency
	local parts, guidata, poschecklist = {}, {}, {}
	local point1, point2
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				if Vector3.new(x, y, z) ~= Vector3.zero then
					table.insert(poschecklist, Vector3.new(x, y, z))
				end
			end
		end
	end
	
	local function checkAdjacent(pos)
		for _, v in poschecklist do
			if getPlacedBlock(pos + v) then return true end
		end
		return false
	end
	
	local function getPlacedBlocksInPoints(s, e)
		local store = bedwars.BlockController:getStore()
		if not store then return {} end
		local list, blocks = {}, store
		for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
			for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
				for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
					local vec = Vector3.new(x, y, z)
					local block = blocks:getBlockAt(vec)
					if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
						list[vec] = block
					end
				end
			end
		end
		return list
	end
	
	local function loadMaterials()
		for _, v in guidata do 
			v:Destroy() 
		end
		local suc, read = pcall(function() 
			return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
		end)
	
		if suc and read then
			local items = {}
			for _, v in read do 
				items[v[2]] = (items[v[2]] or 0) + 1 
			end
			
			for i, v in items do
				local holder = Instance.new('Frame')
				holder.Size = UDim2.new(1, 0, 0, 32)
				holder.BackgroundTransparency = 1
				holder.Parent = Schematica.Children
				local icon = Instance.new('ImageLabel')
				icon.Size = UDim2.fromOffset(24, 24)
				icon.Position = UDim2.fromOffset(4, 4)
				icon.BackgroundTransparency = 1
				icon.Image = bedwars.getIcon({itemType = i}, true)
				icon.Parent = holder
				local text = Instance.new('TextLabel')
				text.Size = UDim2.fromOffset(100, 32)
				text.Position = UDim2.fromOffset(32, 0)
				text.BackgroundTransparency = 1
				text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
				text.TextXAlignment = Enum.TextXAlignment.Left
				text.TextColor3 = uipallet.Text
				text.TextSize = 14
				text.FontFace = uipallet.Font
				text.Parent = holder
				table.insert(guidata, holder)
			end
			table.clear(read)
			table.clear(items)
		end
	end
	
	local function save()
		if point1 and point2 then
			local tab = getPlacedBlocksInPoints(point1, point2)
			local savetab = {}
			point1 = point1 * 3
			for i, v in tab do
				i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
				table.insert(savetab, {
					{
						x = i.X, 
						y = i.Y, 
						z = i.Z
					}, 
					v.Name
				})
			end
			point1, point2 = nil, nil
			writefile(File.Value, httpService:JSONEncode(savetab))
			notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
			loadMaterials()
			table.clear(tab)
			table.clear(savetab)
		else
			local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
			if mouseinfo and mouseinfo.target then
				if point1 then
					point2 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
				else
					point1 = mouseinfo.target.blockRef.blockPosition
					notif('Schematica', 'Selected position 1', 3)
				end
			end
		end
	end
	
	local function load(read)
		local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
		if mouseinfo and mouseinfo.target then
			local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)
	
			for _, v in read do
				local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
				if parts[blockpos] then continue end
				local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
				if handler then
					local part = handler:place(blockpos / 3, 0)
					part.Transparency = Transparency.Value
					part.CanCollide = false
					part.Anchored = true
					part.Parent = workspace
					parts[blockpos] = part
				end
			end
			table.clear(read)
	
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in parts do
						if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
							if not Schematica.Enabled then break end
							if not getItem(v.Name) then continue end
							bedwars.placeBlock(i, v.Name, false)
							task.delay(0.1, function()
								local block = getPlacedBlock(i)
								if block then
									v:Destroy()
									parts[i] = nil
								end
							end)
						end
					end
				end
				task.wait(0.1)
			until getTableSize(parts) <= 0
	
			if getTableSize(parts) <= 0 and Schematica.Enabled then
				notif('Schematica', 'Finished building', 5)
				Schematica:Toggle()
			end
		end
	end
	
	Schematica = vape.Categories.World:CreateModule({
		Name = 'Schematica',
		Function = function(callback)
			if callback then
				if not File.Value:find('.json') then
					notif('Schematica', 'Invalid file', 3)
					Schematica:Toggle()
					return
				end
	
				if Mode.Value == 'Save' then
					save()
					Schematica:Toggle()
				else
					local suc, read = pcall(function() 
						return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
					end)
	
					if suc and read then
						load(read)
					else
						notif('Schematica', 'Missing / corrupted file', 3)
						Schematica:Toggle()
					end
				end
			else
				for _, v in parts do 
					v:Destroy() 
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Save and load placements of buildings'
	})
	File = Schematica:CreateTextBox({
		Name = 'File',
		Function = function()
			loadMaterials()
			point1, point2 = nil, nil
		end
	})
	Mode = Schematica:CreateDropdown({
		Name = 'Mode',
		List = {'Load', 'Save'}
	})
	Transparency = Schematica:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Default = 0.7,
		Decimal = 10,
		Function = function(val)
			for _, v in parts do 
				v.Transparency = val 
			end
		end
	})
end)
	
run(function()
	local ArmorSwitch
	local Mode
	local Targets
	local Range
	
	ArmorSwitch = vape.Categories.Inventory:CreateModule({
		Name = 'ArmorSwitch',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Toggle' then
					repeat
						local state = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						}) and true or false
	
						for i = 0, 2 do
							if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
								bedwars.Store:dispatch({
									type = 'InventorySetArmorItem',
									item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
									armorSlot = i
								})
								vapeEvents.InventoryChanged.Event:Wait()
							end
						end
						task.wait(0.1)
					until not ArmorSwitch.Enabled
				else
					ArmorSwitch:Toggle()
					for i = 0, 2 do
						bedwars.Store:dispatch({
							type = 'InventorySetArmorItem',
							item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
							armorSlot = i
						})
						vapeEvents.InventoryChanged.Event:Wait()
					end
				end
			end
		end,
		Tooltip = 'Puts on / takes off armor when toggled for baiting.'
	})
	Mode = ArmorSwitch:CreateDropdown({
		Name = 'Mode',
		List = {'Toggle', 'On Key'}
	})
	Targets = ArmorSwitch:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = ArmorSwitch:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local TierCheck
	local BedwarsCheck
	local GUI
	local SmartCheck
	local Custom = {}
	local CustomPost = {}
	local UpgradeToggles = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()
	
	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}
	
	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}
	
	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}
	
	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				-- GetPivot rather than .Position: the BedwarsItemShop tag sits on the
				-- shop container, not on a part -- the game's own getShopkeeperModel
				-- resolves the NPC as tagged:FindFirstChildWhichIsA('Model'), so the
				-- tagged instance is whatever holds desertMerchant. When that's a
				-- Model, .Position doesn't exist and indexing it throws, taking this
				-- whole function down so no shop ever registers. GetPivot is defined
				-- on both Model and BasePart, so it works either way.
				if (v.RootPart:GetPivot().Position - localPosition).Magnitude <= 20 then
					shop = v.Upgrades or v.Shop or nil
					upgrades = upgrades or v.Upgrades
					items = items or v.Shop
					newid = v.Shop and v.Id or newid
				end
			end
		end
		return shop, items, upgrades, newid
	end
	
	local function canBuy(item, currencytable, amount)
		amount = amount or 1
		if not currencytable[item.currency] then
			local currency = getItem(item.currency)
			currencytable[item.currency] = currency and currency.amount or 0
		end
		if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
		if item.lockedByForge or item.disabled then return false end
		if item.require and item.require.teamUpgrade then
			if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
				return false
			end
		end
		return currencytable[item.currency] >= (item.price * amount)
	end
	
	local function buyItem(item, currencytable)
		if not id then return end
		notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
		bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
			shopItem = item,
			shopId = id
		}):andThen(function(suc)
			if suc then
				bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
				bedwars.Store:dispatch({
					type = 'BedwarsAddItemPurchased',
					itemType = item.itemType
				})
				bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
			end
		end)
		currencytable[item.currency] -= item.price
	end
	
    local function buyUpgrade(upgradeType, currencytable)
        if not Upgrades.Enabled then return end
        local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
        local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
        local currentTier = (currentUpgrades[upgradeType] or 0) + 1
        local bought = false
    
        for i = currentTier, #upgrade.tiers do
            local tier = upgrade.tiers[i]
            if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end
    
            if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
                notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
                bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
                currencytable.diamond -= tier.cost
                bought = true
            else
                break
            end
        end
    
        return bought
    end
	
	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge
	
		for i = tool, #tools do
			local v = bedwars.Shop.getShopItem(tools[i], lplr)
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Armor.Enabled then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Sword.Enabled then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if TierCheck.Enabled and v.nextTier then break end
		end
	
		if buyable then
			buyItem(buyable, currencytable)
		end
	
		return bought
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				repeat task.wait(0.1) until store.queueType ~= 'bedwars_test'
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end
	
				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					if (npctick - tick()) > 1 then npctick = tick() end
				end))
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled then
						if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
							npc = nil
						end
					end
	
					if npc and lastupgrades ~= upgrades then
						if (npctick - tick()) > 1 then npctick = tick() end
						lastupgrades = upgrades
					end
	
					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								if callback(currencytable, shop, upgrades) then
									waitcheck = true
								end
							end
						end
						npctick = tick() + (waitcheck and 0.4 or math.huge)
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
	
				if store.equippedKit == 'dasher' then
					swords = {
						[1] = 'wood_dao',
						[2] = 'stone_dao',
						[3] = 'iron_dao',
						[4] = 'diamond_dao',
						[5] = 'emerald_dao'
					}
				elseif store.equippedKit == 'ice_queen' then
					swords[5] = 'ice_sword'
				elseif store.equippedKit == 'ember' then
					swords[5] = 'infernal_saber'
				elseif store.equippedKit == 'lumen' then
					swords[5] = 'light_sword'
				end
	
				return buyTool(store.tools.sword, swords, currencytable)
			end or nil
		end
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
				currentarmor = currentarmor and currentarmor.itemType or 'none'
				return buyTool({itemType = currentarmor}, armors, currencytable)
			end or nil
		end,
		Default = true
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Axe',
		Function = function(callback)
			npctick = tick()
			Functions[3] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
			end or nil
		end
	})
	AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[4] = callback and function(currencytable, shop)
				if not shop then return end
				return buyTool(store.tools.stone, pickaxes, currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end
	TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armor before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end
	
						local v = bedwars.Shop.getShopItem(tab[2], lplr)
						if v then
							local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
							item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
							if item > 0 and canBuy(v, currencytable, item) then
								for _ = 1, item do
									buyItem(v, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)
	
run(function()
	local AutoConsume
	local Health
	local SpeedPotion
	local Apple
	local ShieldPotion
	
	local function consumeCheck(attribute)
		if entitylib.isAlive then
			if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
				local speedpotion = getItem('speed_potion')
				if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
					for _ = 1, 4 do
						if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
					end
				end
			end
	
			if Apple.Enabled and (not attribute or attribute:find('Health')) then
				if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
					local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
					
					if apple then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = apple.tool
						})
					end
				end
			end
	
			if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
				if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
					local shield = getItem('big_shield') or getItem('mini_shield')
	
					if shield then
						bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
							item = shield.tool
						})
					end
				end
			end
		end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						consumeCheck(attribute)
					end
				end))
				consumeCheck()
			end
		end,
		Tooltip = 'Automatically heals for you when health or shield is under threshold.'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = function(val) return '%' end
	})
	SpeedPotion = AutoConsume:CreateToggle({
		Name = 'Speed Potions',
		Default = true
	})
	Apple = AutoConsume:CreateToggle({
		Name = 'Apple',
		Default = true
	})
	ShieldPotion = AutoConsume:CreateToggle({
		Name = 'Shield Potions',
		Default = true
	})
end)
	
run(function()
	local AutoHotbar
	local Mode
	local Clear
	local List
	local Active
	
	local function CreateWindow(self)
		local selectedslot = 1
		local window = Instance.new('Frame')
		window.Name = 'HotbarGUI'
		window.Size = UDim2.fromOffset(660, 465)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.BackgroundColor3 = uipallet.Main
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Visible = false
		window.Parent = vape.gui.ScaledGui
		local title = Instance.new('TextLabel')
		title.Name = 'Title'
		title.Size = UDim2.new(1, -10, 0, 20)
		title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
		title.BackgroundTransparency = 1
		title.Text = 'AutoHotbar'
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = uipallet.Text
		title.TextSize = 13
		title.FontFace = uipallet.Font
		title.Parent = window
		local divider = Instance.new('Frame')
		divider.Name = 'Divider'
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Position = UDim2.fromOffset(0, 40)
		divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		divider.BorderSizePixel = 0
		divider.Parent = window
		addBlur(window)
		local modal = Instance.new('TextButton')
		modal.Text = ''
		modal.BackgroundTransparency = 1
		modal.Modal = true
		modal.Parent = window
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = window
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(24, 24)
		close.Position = UDim2.new(1, -35, 0, 9)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('unreal/assets/new/close.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = window
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			window.Visible = false
			vape.gui.ScaledGui.ClickGui.Visible = true
		end)
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		local bigslot = Instance.new('Frame')
		bigslot.Size = UDim2.fromOffset(110, 111)
		bigslot.Position = UDim2.fromOffset(11, 71)
		bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		bigslot.Parent = window
		local bigslotcorner = Instance.new('UICorner')
		bigslotcorner.CornerRadius = UDim.new(0, 4)
		bigslotcorner.Parent = bigslot
		local bigslotstroke = Instance.new('UIStroke')
		bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
		bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bigslotstroke.Parent = bigslot
		local slotnum = Instance.new('TextLabel')
		slotnum.Size = UDim2.fromOffset(80, 20)
		slotnum.Position = UDim2.fromOffset(25, 200)
		slotnum.BackgroundTransparency = 1
		slotnum.Text = 'SLOT 1'
		slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
		slotnum.TextSize = 12
		slotnum.FontFace = uipallet.Font
		slotnum.Parent = window
		for i = 1, 9 do
			local slotbkg = Instance.new('TextButton')
			slotbkg.Name = 'Slot'..i
			slotbkg.Size = UDim2.fromOffset(51, 52)
			slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = window
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = ''
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			local slotstroke = Instance.new('UIStroke')
			slotstroke.Color = color.Light(uipallet.Main, 0.04)
			slotstroke.Thickness = 2
			slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			slotstroke.Enabled = i == selectedslot
			slotstroke.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				window['Slot'..selectedslot].UIStroke.Enabled = false
				selectedslot = i
				slotstroke.Enabled = true
				slotnum.Text = 'SLOT '..selectedslot
			end)
			slotbkg.MouseButton2Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..i].ImageLabel.Image = ''
					obj.Hotbar[tostring(i)] = nil
					obj.Object['Slot'..i].Image = '	'
				end
			end)
		end
		local searchbkg = Instance.new('Frame')
		searchbkg.Size = UDim2.fromOffset(496, 31)
		searchbkg.Position = UDim2.fromOffset(142, 80)
		searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		searchbkg.Parent = window
		local search = Instance.new('TextBox')
		search.Size = UDim2.new(1, -10, 0, 31)
		search.Position = UDim2.fromOffset(10, 0)
		search.BackgroundTransparency = 1
		search.Text = ''
		search.PlaceholderText = ''
		search.TextXAlignment = Enum.TextXAlignment.Left
		search.TextColor3 = uipallet.Text
		search.TextSize = 12
		search.FontFace = uipallet.Font
		search.ClearTextOnFocus = false
		search.Parent = searchbkg
		local searchcorner = Instance.new('UICorner')
		searchcorner.CornerRadius = UDim.new(0, 4)
		searchcorner.Parent = searchbkg
		local searchicon = Instance.new('ImageLabel')
		searchicon.Size = UDim2.fromOffset(14, 14)
		searchicon.Position = UDim2.new(1, -26, 0, 8)
		searchicon.BackgroundTransparency = 1
		searchicon.Image = getcustomasset('unreal/assets/new/search.png')
		searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
		searchicon.Parent = searchbkg
		local children = Instance.new('ScrollingFrame')
		children.Name = 'Children'
		children.Size = UDim2.fromOffset(500, 240)
		children.Position = UDim2.fromOffset(144, 122)
		children.BackgroundTransparency = 1
		children.BorderSizePixel = 0
		children.ScrollBarThickness = 2
		children.ScrollBarImageTransparency = 0.75
		children.CanvasSize = UDim2.new()
		children.Parent = window
		local windowlist = Instance.new('UIGridLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.FillDirectionMaxCells = 9
		windowlist.CellSize = UDim2.fromOffset(51, 52)
		windowlist.CellPadding = UDim2.fromOffset(4, 3)
		windowlist.Parent = children
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
		end)
		table.insert(vape.Windows, window)
	
		local function createitem(id, image)
			local slotbkg = Instance.new('TextButton')
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			slotbkg.Text = ''
			slotbkg.AutoButtonColor = false
			slotbkg.Parent = children
			local slotimage = Instance.new('ImageLabel')
			slotimage.Size = UDim2.fromOffset(32, 32)
			slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
			slotimage.BackgroundTransparency = 1
			slotimage.Image = image
			slotimage.Parent = slotbkg
			local slotcorner = Instance.new('UICorner')
			slotcorner.CornerRadius = UDim.new(0, 4)
			slotcorner.Parent = slotbkg
			slotbkg.MouseEnter:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
			end)
			slotbkg.MouseLeave:Connect(function()
				slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
			end)
			slotbkg.MouseButton1Click:Connect(function()
				local obj = self.Hotbars[self.Selected]
				if obj then
					window['Slot'..selectedslot].ImageLabel.Image = image
					obj.Hotbar[tostring(selectedslot)] = id
					obj.Object['Slot'..selectedslot].Image = image
				end
			end)
		end
	
		local function indexSearch(text)
			for _, v in children:GetChildren() do
				if v:IsA('TextButton') then
					v:ClearAllChildren()
					v:Destroy()
				end
			end
	
			if text == '' then
				for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
					createitem(v, bedwars.ItemMeta[v].image)
				end
				return
			end
	
			for i, v in bedwars.ItemMeta do
				if text:lower() == i:lower():sub(1, text:len()) then
					if not v.image then continue end
					createitem(i, v.image)
				end
			end
		end
	
		search:GetPropertyChangedSignal('Text'):Connect(function()
			indexSearch(search.Text)
		end)
		indexSearch('')
	
		return window
	end
	
	vape.Components.HotbarList = function(optionsettings, children, api)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		local optionapi = {
			Type = 'HotbarList',
			Hotbars = {},
			Selected = 1
		}
		local hotbarlist = Instance.new('TextButton')
		hotbarlist.Name = 'HotbarList'
		hotbarlist.Size = UDim2.fromOffset(220, 40)
		hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
		hotbarlist.Text = ''
		hotbarlist.BorderSizePixel = 0
		hotbarlist.AutoButtonColor = false
		hotbarlist.Parent = children
		local textbkg = Instance.new('Frame')
		textbkg.Name = 'BKG'
		textbkg.Size = UDim2.new(1, -20, 0, 31)
		textbkg.Position = UDim2.fromOffset(10, 4)
		textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		textbkg.Parent = hotbarlist
		local textbkgcorner = Instance.new('UICorner')
		textbkgcorner.CornerRadius = UDim.new(0, 4)
		textbkgcorner.Parent = textbkg
		local textbutton = Instance.new('TextButton')
		textbutton.Name = 'HotbarList'
		textbutton.Size = UDim2.new(1, -2, 1, -2)
		textbutton.Position = UDim2.fromOffset(1, 1)
		textbutton.BackgroundColor3 = uipallet.Main
		textbutton.Text = ''
		textbutton.AutoButtonColor = false
		textbutton.Parent = textbkg
		textbutton.MouseEnter:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.14)
			})
		end)
		textbutton.MouseLeave:Connect(function()
			tween:Tween(textbkg, TweenInfo.new(0.2), {
				BackgroundColor3 = color.Light(uipallet.Main, 0.034)
			})
		end)
		local textbuttoncorner = Instance.new('UICorner')
		textbuttoncorner.CornerRadius = UDim.new(0, 4)
		textbuttoncorner.Parent = textbutton
		local textbuttonicon = Instance.new('ImageLabel')
		textbuttonicon.Size = UDim2.fromOffset(12, 12)
		textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
		textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
		textbuttonicon.BackgroundTransparency = 1
		textbuttonicon.Image = getcustomasset('unreal/assets/new/add.png')
		textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
		textbuttonicon.Parent = textbutton
		local childrenlist = Instance.new('Frame')
		childrenlist.Size = UDim2.new(1, 0, 1, -40)
		childrenlist.Position = UDim2.fromOffset(0, 40)
		childrenlist.BackgroundTransparency = 1
		childrenlist.Parent = hotbarlist
		local windowlist = Instance.new('UIListLayout')
		windowlist.SortOrder = Enum.SortOrder.LayoutOrder
		windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
		windowlist.Padding = UDim.new(0, 3)
		windowlist.Parent = childrenlist
		windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
		end)
		textbutton.MouseButton1Click:Connect(function()
			optionapi:AddHotbar()
		end)
		optionapi.Window = CreateWindow(optionapi)
	
		function optionapi:Save(savetab)
			local hotbars = {}
			for _, v in self.Hotbars do
				table.insert(hotbars, v.Hotbar)
			end
			savetab.HotbarList = {
				Selected = self.Selected,
				Hotbars = hotbars
			}
		end
	
		function optionapi:Load(savetab)
			for _, v in self.Hotbars do
				v.Object:ClearAllChildren()
				v.Object:Destroy()
				table.clear(v.Hotbar)
			end
			table.clear(self.Hotbars)
			for _, v in savetab.Hotbars do
				self:AddHotbar(v)
			end
			self.Selected = savetab.Selected or 1
		end
	
		function optionapi:AddHotbar(data)
			local hotbardata = {Hotbar = data or {}}
			table.insert(self.Hotbars, hotbardata)
			local hotbar = Instance.new('TextButton')
			hotbar.Size = UDim2.fromOffset(200, 27)
			hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
			hotbar.Text = ''
			hotbar.AutoButtonColor = false
			hotbar.Parent = childrenlist
			hotbardata.Object = hotbar
			local hotbarcorner = Instance.new('UICorner')
			hotbarcorner.CornerRadius = UDim.new(0, 4)
			hotbarcorner.Parent = hotbar
			for i = 1, 9 do
				local slot = Instance.new('ImageLabel')
				slot.Name = 'Slot'..i
				slot.Size = UDim2.fromOffset(17, 18)
				slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
				slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
				slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				slot.BorderSizePixel = 0
				slot.Parent = hotbar
			end
			hotbar.MouseButton1Click:Connect(function()
				local ind = table.find(optionapi.Hotbars, hotbardata)
				if ind == optionapi.Selected then
					vape.gui.ScaledGui.ClickGui.Visible = false
					optionapi.Window.Visible = true
					for i = 1, 9 do
						optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
					end
				else
					if optionapi.Hotbars[optionapi.Selected] then
						optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
					end
					hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
					optionapi.Selected = ind
				end
			end)
			local close = Instance.new('ImageButton')
			close.Name = 'Close'
			close.Size = UDim2.fromOffset(16, 16)
			close.Position = UDim2.new(1, -23, 0, 6)
			close.BackgroundColor3 = Color3.new(1, 1, 1)
			close.BackgroundTransparency = 1
			close.Image = getcustomasset('unreal/assets/new/closemini.png')
			close.ImageColor3 = color.Light(uipallet.Text, 0.2)
			close.ImageTransparency = 0.5
			close.AutoButtonColor = false
			close.Parent = hotbar
			local closecorner = Instance.new('UICorner')
			closecorner.CornerRadius = UDim.new(1, 0)
			closecorner.Parent = close
			close.MouseEnter:Connect(function()
				close.ImageTransparency = 0.3
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.6
				})
			end)
			close.MouseLeave:Connect(function()
				close.ImageTransparency = 0.5
				tween:Tween(close, TweenInfo.new(0.2), {
					BackgroundTransparency = 1
				})
			end)
			close.MouseButton1Click:Connect(function()
				local ind = table.find(self.Hotbars, hotbardata)
				local obj = self.Hotbars[self.Selected]
				local obj2 = self.Hotbars[ind]
				if obj and obj2 then
					obj2.Object:ClearAllChildren()
					obj2.Object:Destroy()
					table.remove(self.Hotbars, ind)
					ind = table.find(self.Hotbars, obj)
					self.Selected = table.find(self.Hotbars, obj) or 1
				end
			end)
		end
	
		api.Options.HotbarList = optionapi
	
		return optionapi
	end
	
	local function getBlock()
		local clone = table.clone(store.inventory.inventory.items)
		table.sort(clone, function(a, b)
			return a.amount < b.amount
		end)
	
		for _, item in clone do
			local block = bedwars.ItemMeta[item.itemType].block
			if block and not block.seeThrough then
				return item
			end
		end
	end
	
	local function getCustomItem(v)
		if v == 'diamond_sword' then
			local sword = store.tools.sword
			v = sword and sword.itemType or 'wood_sword'
		elseif v == 'diamond_pickaxe' then
			local pickaxe = store.tools.stone
			v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
		elseif v == 'diamond_axe' then
			local axe = store.tools.wood
			v = axe and axe.itemType or 'wood_axe'
		elseif v == 'wood_bow' then
			local bow = getBow()
			v = bow and bow.itemType or 'wood_bow'
		elseif v == 'wool_white' then
			local block = getBlock()
			v = block and block.itemType or 'wool_white'
		end
	
		return v
	end
	
	local function findItemInTable(tab, item)
		for slot, v in tab do
			if item.itemType == getCustomItem(v) then
				return tonumber(slot)
			end
		end
	end
	
	local function findInHotbar(item)
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType == item.itemType then
				return i - 1, v.item
			end
		end
	end
	
	local function findInInventory(item)
		for _, v in store.inventory.inventory.items do
			if v.itemType == item.itemType then
				return v
			end
		end
	end
	
	local function dispatch(...)
		bedwars.Store:dispatch(...)
		vapeEvents.InventoryChanged.Event:Wait()
	end
	
	local function sortCallback()
		if Active then return end
		Active = true
		local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})
	
		for _, v in store.inventory.inventory.items do
			local slot = findItemInTable(items, v)
			if slot then
				local olditem = store.inventory.hotbar[slot]
				if olditem.item and olditem.item.itemType == v.itemType then continue end
				if olditem.item then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = slot - 1
					})
				end
	
				local newslot = findInHotbar(v)
				if newslot then
					dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
					if olditem.item then
						dispatch({
							type = 'InventoryAddToHotbar',
							item = findInInventory(olditem.item),
							slot = newslot
						})
					end
				end
	
				dispatch({
					type = 'InventoryAddToHotbar',
					item = findInInventory(v),
					slot = slot - 1
				})
			elseif Clear.Enabled then
				local newslot = findInHotbar(v)
				if newslot then
				   	dispatch({
						type = 'InventoryRemoveFromHotbar',
						slot = newslot
					})
				end
			end
		end
	
		Active = false
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
		Name = 'AutoHotbar',
		Function = function(callback)
			if callback then
				task.spawn(sortCallback)
				if Mode.Value == 'On Key' then
					AutoHotbar:Toggle()
					return
				end
	
				AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
			end
		end,
		Tooltip = 'Automatically arranges hotbar to your liking.'
	})
	Mode = AutoHotbar:CreateDropdown({
		Name = 'Activation',
		List = {'Toggle', 'On Key'},
		Function = function()
			if AutoHotbar.Enabled then
				AutoHotbar:Toggle()
				AutoHotbar:Toggle()
			end
		end
	})
	Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
	List = AutoHotbar:CreateHotbarList({})
end)
	
run(function()
	local Value
	local oldclickhold, oldshowprogress
	
	local FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			if callback then
				oldclickhold = bedwars.ClickHold.startClick
				oldshowprogress = bedwars.ClickHold.showProgress
				bedwars.ClickHold.startClick = function(self)
					self.startedClickTime = os.clock()
					local handle = self:showProgress()
					local clicktime = self.startedClickTime
					bedwars.RuntimeLib.Promise.defer(function()
						task.wait(self.durationSeconds * (Value.Value / 40))
						if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
							self:hideProgress()
							if self.onComplete then self.onComplete() end
							if self.onPartialComplete then self.onPartialComplete(1) end
							self.startedClickTime = -1
						end
					end)
				end
	
				bedwars.ClickHold.showProgress = function(self)
					local roact = debug.getupvalue(oldshowprogress, 1)
					local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
						[roact.Ref] = self.wrapperRef,
						Size = UDim2.new(),
						Position = UDim2.fromScale(0.5, 0.55),
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.8
					}, { roact.createElement('Frame', {
						[roact.Ref] = self.progressRef,
						Size = UDim2.fromScale(0, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.5
					}) }) }), lplr:FindFirstChild('PlayerGui'))
	
					self.handle = countdown
					local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
						Size = UDim2.fromScale(0.11, 0.005)
					})
					local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
						Size = UDim2.fromScale(1, 1)
					})
	
					sizetween:Play()
					countdowntween:Play()
					table.insert(self.tweens, countdowntween)
					table.insert(self.tweens, sizetween)
					
					return countdown
				end
			else
				bedwars.ClickHold.startClick = oldclickhold
				bedwars.ClickHold.showProgress = oldshowprogress
				oldclickhold = nil
				oldshowprogress = nil
			end
		end,
		Tooltip = 'Use/Consume items quicker.'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100
	})
end)
	
run(function()
	local FastDrop
	
	FastDrop = vape.Categories.Inventory:CreateModule({
		Name = 'FastDrop',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
						task.spawn(bedwars.ItemDropController.dropItemInHand)
						task.wait(0.1)
					else
						task.wait(0.1)
					end
				until not FastDrop.Enabled
			end
		end,
		Tooltip = 'Drops items fast when you hold Q'
	})
end)
	
run(function()
	local BedPlates
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, side in sides do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self then break end
				if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
					table.insert(tab, block.Name)
				end
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local alreadygot = {}
		scanSide(v.Adornee, start, alreadygot)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
		end)
		v.Enabled = #alreadygot > 0
	
		for _, block in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.Minigames:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do 
					task.spawn(Added, v) 
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then 
				Color.Object.Visible = callback 
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local BedBreakEffect
	local Mode
	local List
	local NameToId = {}
	
	BedBreakEffect = vape.Legit:CreateModule({
		Name = 'Bed Break Effect',
		Function = function(callback)
			if callback then
	            BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
	                firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
	                    player = data.player,
	                    position = data.bedBlockPosition * 3,
	                    effectType = NameToId[List.Value],
	                    teamId = data.brokenBedTeam.id,
	                    centerBedPosition = data.bedBlockPosition * 3
	                })
	            end))
	        end
		end,
		Tooltip = 'Custom bed break effects'
	})
	local BreakEffectName = {}
	for i, v in bedwars.BedBreakEffectMeta do
		table.insert(BreakEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(BreakEffectName)
	List = BedBreakEffect:CreateDropdown({
		Name = 'Effect',
		List = BreakEffectName
	})
end)
	
run(function()
	vape.Legit:CreateModule({
		Name = 'Clean Kit',
		Function = function(callback)
			if callback then
				bedwars.WindWalkerController.spawnOrb = function() end
				local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
				if zephyreffect then 
					zephyreffect.Visible = false 
				end
			end
		end,
		Tooltip = 'Removes zephyr status indicator'
	})
end)
	
run(function()
	local old
	local Image
	
	local Crosshair = vape.Legit:CreateModule({
		Name = 'Crosshair',
		Function = function(callback)
			if callback then
				old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
			else
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
				debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
				old = nil
			end
	
			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = 'Custom first person crosshair depending on the image choosen.'
	})
	Image = Crosshair:CreateTextBox({
		Name = 'Image',
		Placeholder = 'image id (roblox)',
		Function = function(enter)
			if enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)
	
run(function()
	local DamageIndicator
	local FontOption
	local Color
	local Size
	local Anchor
	local Stroke
	local suc, tab = pcall(function()
		return debug.getupvalue(bedwars.DamageIndicator, 2)
	end)
	tab = suc and tab or {}
	local oldvalues, oldfont = {}
	
	DamageIndicator = vape.Legit:CreateModule({
		Name = 'Damage Indicator',
		Function = function(callback)
			if callback then
				oldvalues = table.clone(tab)
				oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
				debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
				tab.strokeThickness = Stroke.Enabled and 1 or false
				tab.textSize = Size.Value
				tab.blowUpSize = Size.Value
				tab.blowUpDuration = 0
				tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
				tab.blowUpCompleteDuration = 0
				tab.anchoredDuration = Anchor.Value
			else
				for i, v in oldvalues do
					tab[i] = v
				end
				debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
				debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
			end
		end,
		Tooltip = 'Customize the damage indicator'
	})
	local fontitems = {'GothamBlack'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'GothamBlack' then
			table.insert(fontitems, v.Name)
		end
	end
	FontOption = DamageIndicator:CreateDropdown({
		Name = 'Font',
		List = fontitems,
		Function = function(val)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
			end
		end
	})
	Color = DamageIndicator:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		Function = function(hue, sat, val)
			if DamageIndicator.Enabled then
				tab.baseColor = Color3.fromHSV(hue, sat, val)
			end
		end
	})
	Size = DamageIndicator:CreateSlider({
		Name = 'Size',
		Min = 1,
		Max = 32,
		Default = 32,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.textSize = val
				tab.blowUpSize = val
			end
		end
	})
	Anchor = DamageIndicator:CreateSlider({
		Name = 'Anchor',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(val)
			if DamageIndicator.Enabled then
				tab.anchoredDuration = val
			end
		end
	})
	Stroke = DamageIndicator:CreateToggle({
		Name = 'Stroke',
		Function = function(callback)
			if DamageIndicator.Enabled then
				debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
				tab.strokeThickness = callback and 1 or false
			end
		end
	})
end)
	
run(function()
	local FOV
	local Value
	local old, old2
	
	FOV = vape.Legit:CreateModule({
		Name = 'FOV',
		Function = function(callback)
			if callback then
				old = bedwars.FovController.setFOV
				old2 = bedwars.FovController.getFOV
				bedwars.FovController.setFOV = function(self) 
					return old(self, Value.Value) 
				end
				bedwars.FovController.getFOV = function() 
					return Value.Value 
				end
			else
				bedwars.FovController.setFOV = old
				bedwars.FovController.getFOV = old2
			end
			
			bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
		end,
		Tooltip = 'Adjusts camera vision'
	})
	Value = FOV:CreateSlider({
		Name = 'FOV',
		Min = 30,
		Max = 120
	})
end)
	
run(function()
	local FPSBoost
	local Kill
	local Visualizer
	local effects, util = {}, {}
	
	FPSBoost = vape.Legit:CreateModule({
		Name = 'FPS Boost',
		Function = function(callback)
			if callback then
				if Kill.Enabled then
					for i, v in bedwars.KillEffectController.killEffects do
						if not i:find('Custom') then
							effects[i] = v
							bedwars.KillEffectController.killEffects[i] = {
								new = function() 
									return {
										onKill = function() end, 
										isPlayDefaultKillEffect = function() 
											return true 
										end
									} 
								end
							}
						end
					end
				end
	
				if Visualizer.Enabled then
					for i, v in bedwars.VisualizerUtils do
						util[i] = v
						bedwars.VisualizerUtils[i] = function() end
					end
				end
	
				repeat task.wait(0.1) until store.matchState ~= 0
				if not bedwars.AppController then return end
				bedwars.NametagController.addGameNametag = function() end
				for _, v in bedwars.AppController:getOpenApps() do
					if tostring(v):find('Nametag') then
						bedwars.AppController:closeApp(tostring(v))
					end
				end
			else
				for i, v in effects do 
					bedwars.KillEffectController.killEffects[i] = v 
				end
				for i, v in util do 
					bedwars.VisualizerUtils[i] = v 
				end
				table.clear(effects)
				table.clear(util)
			end
		end,
		Tooltip = 'Improves the framerate by turning off certain effects'
	})
	Kill = FPSBoost:CreateToggle({
		Name = 'Kill Effects',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
	Visualizer = FPSBoost:CreateToggle({
		Name = 'Visualizer',
		Function = function()
			if FPSBoost.Enabled then
				FPSBoost:Toggle()
				FPSBoost:Toggle()
			end
		end,
		Default = true
	})
end)
	
run(function()
	local HitColor
	local Color
	-- weak keys so highlights destroyed mid-session don't sit in here until disable
	local done = setmetatable({}, {__mode = 'k'})
	
	HitColor = vape.Legit:CreateModule({
		Name = 'Hit Color',
		Function = function(callback)
			if callback then
				repeat
					-- same colour for every entity this tick; compute once, not per-entity
					local fill = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					local trans = Color.Opacity
					for _, v in entitylib.List do
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then
							-- set, not array: the table.find here was a linear scan
							-- per entity per tick that only grew as highlights piled up
							done[highlight] = true
							highlight.FillColor = fill
							highlight.FillTransparency = trans
						end
					end
					task.wait(0.1)
				until not HitColor.Enabled
			else
				for v in next, done do
					v.FillColor = Color3.new(1, 0, 0)
					v.FillTransparency = 0.4
				end
				table.clear(done)
			end
		end,
		Tooltip = 'Customize the hit highlight options'
	})
	Color = HitColor:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.4
	})
end)
	
run(function()
	local RaycastFix
	local BlockHit
	local KbNormalize
	local HitDelayOpt
	local ReachSync
	local HitEffect
	local Priority

	local function apply(callback)
		pcall(function()
			if not (bedwars and bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse) then return end
			local swing = bedwars.SwordController.swingSwordAtMouse
			if callback then
				debug.setconstant(swing, 23, 'raycast')
				debug.setupvalue(swing, 4, bedwars.QueryUtil or workspace)
			else
				debug.setconstant(swing, 23, 'Raycast')
				debug.setupvalue(swing, 4, workspace)
			end
		end)
		if callback and ReachSync and ReachSync.Value > 0 then
			pcall(function() bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = ReachSync.Value + 2 end)
		end
	end

	RaycastFix = vape.Categories.Blatant:CreateModule({
		Name = 'HitFix',
		Function = function(callback)
			if not callback then
				apply(false)
				return
			end
			apply(true)
			store.HitFixPriority = Priority.Value
			store.HitFixHitEffect = HitEffect.Enabled
		end,
		Tooltip = 'Forces the correct raycast query on sword swings so hits register properly'
	})
	BlockHit = RaycastFix:CreateToggle({
		Name = 'Hit through blocks',
		Default = true,
		Tooltip = 'Attempts to hit targets that are occluded by blocks'
	})
	KbNormalize = RaycastFix:CreateToggle({
		Name = 'Knockback normalize',
		Tooltip = 'Reduces knockback received while enabled'
	})
	HitDelayOpt = RaycastFix:CreateSlider({
		Name = 'Extra hit delay',
		Min = 0,
		Max = 200,
		Default = 0,
		Decimal = 0,
		Suffix = 'ms',
		Tooltip = 'Additional delay between attacks in milliseconds'
	})
	ReachSync = RaycastFix:CreateSlider({
		Name = 'Forced reach',
		Min = 0,
		Max = 18,
		Default = 0,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'Override the sword attack reach (0 = default)'
	})
	HitEffect = RaycastFix:CreateToggle({
		Name = 'Hit effect',
		Tooltip = 'Render a highlight when a target is struck'
	})
	Priority = RaycastFix:CreateDropdown({
		Name = 'Priority',
		List = {'None', 'Nearest', 'Lowest Health', 'Highest Health', 'Most Misses'},
		Default = 'None',
		Tooltip = 'Target priority order used by Killaura'
	})
end)
	
run(function()
	local Interface
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local old, new = {}, {}
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val
	
		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	Interface = vape.Legit:CreateModule({
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
		end,
		Tooltip = 'Customize bedwars UI'
	})
	local fontitems = {'LuckiestGuy'}
	for _, v in Enum.Font:GetEnumItems() do
		if v.Name ~= 'LuckiestGuy' then
			table.insert(fontitems, v.Name)
		end
	end
	Interface:CreateDropdown({
		Name = 'Health Font',
		List = fontitems,
		Function = function(val)
			modifyconstant(HotbarHealthbar.render, 77, val)
		end
	})
	Interface:CreateColorSlider({
		Name = 'Health Color',
		Function = function(hue, sat, val)
			modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			if Interface.Enabled then
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
				if hotbar then
					hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				end
			end
		end
	})
	Interface:CreateColorSlider({
		Name = 'Hotbar Color',
		DefaultOpacity = 0.8,
		Function = function(hue, sat, val, opacity)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
			modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
			modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		end
	})
end)
	
run(function()
	local KillEffect
	local Mode
	local List
	local NameToId = {}
	
	local killeffects = {
		Gravity = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			local nametag = char:FindFirstChild('Nametag', true)
			if highlight then
				highlight:Destroy()
			end
			if nametag then
				nametag:Destroy()
			end
	
			task.spawn(function()
				local partvelo = {}
				for _, v in char:GetDescendants() do
					if v:IsA('BasePart') then
						partvelo[v.Name] = v.Velocity
					end
				end
				char.Archivable = true
				local clone = char:Clone()
				clone.Humanoid.Health = 100
				clone.Parent = workspace
				game:GetService('Debris'):AddItem(clone, 30)
				char:Destroy()
				task.wait(0.01)
				clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				clone:BreakJoints()
				task.wait(0.01)
				for _, v in clone:GetDescendants() do
					if v:IsA('BasePart') then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
						bodyforce.Parent = v
						v.CanCollide = true
						v.Velocity = partvelo[v.Name] or Vector3.zero
					end
				end
			end)
		end,
		Lightning = function(_, _, char, _)
			char:BreakJoints()
			local highlight = char:FindFirstChildWhichIsA('Highlight')
			if highlight then
				highlight:Destroy()
			end
			local startpos = 1125
			local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
			local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)
	
			for i = startpos - 75, 0, -75 do
				local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
				if i == 0 then
					newpos2 = Vector3.zero
				end
				local part = Instance.new('Part')
				part.Size = Vector3.new(1.5, 1.5, 77)
				part.Material = Enum.Material.SmoothPlastic
				part.Anchored = true
				part.Material = Enum.Material.Neon
				part.CanCollide = false
				part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
				part.Parent = workspace
				local part2 = part:Clone()
				part2.Size = Vector3.new(3, 3, 78)
				part2.Color = Color3.new(0.7, 0.7, 0.7)
				part2.Transparency = 0.7
				part2.Material = Enum.Material.SmoothPlastic
				part2.Parent = workspace
				game:GetService('Debris'):AddItem(part, 0.5)
				game:GetService('Debris'):AddItem(part2, 0.5)
				bedwars.QueryUtil:setQueryIgnored(part, true)
				bedwars.QueryUtil:setQueryIgnored(part2, true)
				if i == 0 then
					local soundpart = Instance.new('Part')
					soundpart.Transparency = 1
					soundpart.Anchored = true
					soundpart.Size = Vector3.zero
					soundpart.Position = startcf
					soundpart.Parent = workspace
					bedwars.QueryUtil:setQueryIgnored(soundpart, true)
					local sound = Instance.new('Sound')
					sound.SoundId = 'rbxassetid://6993372814'
					sound.Volume = 2
					sound.Pitch = 0.5 + (math.random(1, 3) / 10)
					sound.Parent = soundpart
					sound:Play()
					sound.Ended:Connect(function()
						soundpart:Destroy()
					end)
				end
				newpos = newpos2
			end
		end,
		Delete = function(_, _, char, _)
			char:Destroy()
		end
	}
	
	KillEffect = vape.Legit:CreateModule({
		Name = 'Kill Effect',
		Function = function(callback)
			if callback then
				for i, v in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = {
						new = function()
							return {
								onKill = v,
								isPlayDefaultKillEffect = function()
									return false
								end
							}
						end
					}
				end
				KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
					lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
				end))
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			else
				for i in killeffects do
					bedwars.KillEffectController.killEffects['Custom'..i] = nil
				end
				lplr:SetAttribute('KillEffectType', 'default')
			end
		end,
		Tooltip = 'Custom final kill effects'
	})
	local modes = {'Bedwars'}
	for i in killeffects do
		table.insert(modes, i)
	end
	Mode = KillEffect:CreateDropdown({
		Name = 'Mode',
		List = modes,
		Function = function(val)
			List.Object.Visible = val == 'Bedwars'
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
			end
		end
	})
	local KillEffectName = {}
	for i, v in bedwars.KillEffectMeta do
		table.insert(KillEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(KillEffectName)
	List = KillEffect:CreateDropdown({
		Name = 'Bedwars',
		List = KillEffectName,
		Function = function(val)
			if KillEffect.Enabled then
				lplr:SetAttribute('KillEffectType', NameToId[val])
			end
		end,
		Darker = true
	})
end)
	
run(function()
	local ReachDisplay
	local label
	
	ReachDisplay = vape.Legit:CreateModule({
		Name = 'Reach Display',
		Function = function(callback)
			if callback then
				repeat
					label.Text = (store.attackReachUpdate > os.clock() and store.attackReach or '0.00')..' studs'
					task.wait(0.4)
				until not ReachDisplay.Enabled
			end
		end,
		Size = UDim2.fromOffset(100, 41)
	})
	ReachDisplay:CreateFont({
		Name = 'Font',
		Blacklist = 'Gotham',
		Function = function(val)
			label.FontFace = val
		end
	})
	ReachDisplay:CreateColorSlider({
		Name = 'Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			label.BackgroundTransparency = 1 - opacity
		end
	})
	label = Instance.new('TextLabel')
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.5
	label.TextSize = 15
	label.Font = Enum.Font.Gotham
	label.Text = '0.00 studs'
	label.TextColor3 = Color3.new(1, 1, 1)
	label.BackgroundColor3 = Color3.new()
	label.Parent = ReachDisplay.Children
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
end)
	
run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local alreadypicked = {}
	local beattick = os.clock()
	local oldfov, songobj, songbpm, songtween
	
	local function choosesong()
		local list = List.ListEnabled
		if #alreadypicked >= #list then 
			table.clear(alreadypicked) 
		end
	
		if #list <= 0 then
			notif('SongBeats', 'no songs', 10)
			SongBeats:Toggle()
			return
		end
	
		local chosensong = list[math.random(1, #list)]
		if #list > 1 and table.find(alreadypicked, chosensong) then
			repeat 
				task.wait(0.1) 
				chosensong = list[math.random(1, #list)] 
			until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
		end
		if not SongBeats.Enabled then return end
	
		local split = chosensong:split('/')
		if not isfile(split[1]) then
			notif('SongBeats', 'Missing song ('..split[1]..')', 10)
			SongBeats:Toggle()
			return
		end
	
		songobj.SoundId = assetfunction(split[1])
		repeat task.wait(0.1) until songobj.IsLoaded or not SongBeats.Enabled
		if SongBeats.Enabled then
			beattick = os.clock() + (tonumber(split[3]) or 0)
			songbpm = 60 / (tonumber(split[2]) or 50)
			songobj:Play()
		end
	end
	
	SongBeats = vape.Legit:CreateModule({
		Name = 'Song Beats',
		Function = function(callback)
			if callback then
				songobj = Instance.new('Sound')
				songobj.Volume = Volume.Value / 100
				songobj.Parent = workspace
				repeat
					if not songobj.Playing then choosesong() end
					if beattick < os.clock() and SongBeats.Enabled and FOV.Enabled then
						beattick = os.clock() + songbpm
						oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
						gameCamera.FieldOfView = oldfov - FOVValue.Value
						songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
						songtween:Play()
					end
					task.wait(0.1)
				until not SongBeats.Enabled
			else
				if songobj then
					songobj:Destroy()
				end
				if songtween then
					songtween:Cancel()
				end
				if oldfov then
					gameCamera.FieldOfView = oldfov
				end
				table.clear(alreadypicked)
			end
		end,
		Tooltip = 'Built in mp3 player'
	})
	List = SongBeats:CreateTextList({
		Name = 'Songs',
		Placeholder = 'filepath/bpm/start'
	})
	FOV = SongBeats:CreateToggle({
		Name = 'Beat FOV',
		Function = function(callback)
			if FOVValue.Object then
				FOVValue.Object.Visible = callback
			end
			if SongBeats.Enabled then
				SongBeats:Toggle()
				SongBeats:Toggle()
			end
		end,
		Default = true
	})
	FOVValue = SongBeats:CreateSlider({
		Name = 'Adjustment',
		Min = 1,
		Max = 30,
		Default = 5,
		Darker = true
	})
	Volume = SongBeats:CreateSlider({
		Name = 'Volume',
		Function = function(val)
			if songobj then 
				songobj.Volume = val / 100 
			end
		end,
		Min = 1,
		Max = 100,
		Default = 100,
		Suffix = function(val) return '%' end
	})
end)

run(function()
	local SoundChanger
	local List
	local Volume
	local trackedSounds = {}
	local customSounds = {}
	local capturedRegistry = {}
	local old, oldRegister
	
	local function updateVolumes()
		local volMultiplier = (Volume and Volume.Value or 100) / 100
		for id, props in pairs(capturedRegistry) do
			if type(props) == "table" then
				if props._originalVolume == nil then
					props._originalVolume = props.volume or props.Volume or 1
				end
				if trackedSounds[id] then
					props.volume = props._originalVolume * volMultiplier
					props.Volume = props.volume
				else
					props.volume = props._originalVolume
					props.Volume = props._originalVolume
				end
			end
		end
	end

	SoundChanger = vape.Legit:CreateModule({
		Name = 'SoundChanger',
		Function = function(callback)
			if callback then
				old = bedwars.SoundManager.playSound
				bedwars.SoundManager.playSound = function(self, id, ...)
					local args = {...}
					local isTracked = trackedSounds[id]
					
					if isTracked then
						if customSounds[id] then
							id = customSounds[id]
						end
						
						local volMultiplier = (Volume and Volume.Value or 100) / 100
						
						for i, v in ipairs(args) do
							if type(v) == "table" then
								local newProps = {}
								for k, val in pairs(v) do newProps[k] = val end
								local baseVol = newProps.volume or newProps.Volume or 1
								newProps.volume = baseVol * volMultiplier
								newProps.Volume = newProps.volume
								args[i] = newProps
							end
						end
					end
					
					local result = old(self, id, table.unpack(args))
					
					if isTracked and result and typeof(result) == "Instance" and result:IsA("Sound") then
						local volMultiplier = (Volume and Volume.Value or 100) / 100
						result.Volume = result.Volume * volMultiplier
					end
					
					return result
				end

				oldRegister = bedwars.SoundManager.registerSound
				if oldRegister then
					bedwars.SoundManager.registerSound = function(self, id, props)
						capturedRegistry[id] = props
						if type(props) == "table" then
							if props._originalVolume == nil then
								props._originalVolume = props.volume or props.Volume or 1
							end
							if trackedSounds[id] then
								local volMultiplier = (Volume and Volume.Value or 100) / 100
								props.volume = props._originalVolume * volMultiplier
								props.Volume = props.volume
							end
						end
						return oldRegister(self, id, props)
					end
				end

				if type(bedwars.SoundManager) == "table" then
					for k, v in pairs(bedwars.SoundManager) do
						if type(v) == "table" then
							for rk, rv in pairs(v) do
								if type(rk) == "string" and rk:find("rbxassetid://") and type(rv) == "table" then
									if not capturedRegistry[rk] then
										capturedRegistry[rk] = rv
									end
								end
							end
						end
					end
				end

				updateVolumes()
			else
				if old then
					bedwars.SoundManager.playSound = old
					old = nil
				end
				if oldRegister then
					bedwars.SoundManager.registerSound = oldRegister
					oldRegister = nil
				end
				
				for id, props in pairs(capturedRegistry) do
					if type(props) == "table" and props._originalVolume ~= nil then
						props.volume = props._originalVolume
						props.Volume = props._originalVolume
					end
				end
			end
		end,
		Tooltip = 'Change ingame sounds to custom ones and adjust their volume.'
	})
	
	List = SoundChanger:CreateTextList({
		Name = 'Sounds',
		Placeholder = '(EQUIP_DEFAULT or EQUIP_DEFAULT/custom.mp3)',
		Function = function()
			table.clear(trackedSounds)
			table.clear(customSounds)
			local soundTable = bedwars.SoundList or bedwars.GameSound or bedwars.Sounds or {}
			for _, entry in ipairs(List.ListEnabled) do
				local split = entry:split('/')
				local name = split[1]
				local id = soundTable[name]
				
				if id then
					trackedSounds[id] = true
					if #split > 1 and split[2] ~= "" then
						local path = split[2]
						local custom = path:find('rbxasset') and path or isfile(path) and assetfunction(path) or nil
						if custom then
							customSounds[id] = custom
						end
					end
				end
			end
			updateVolumes()
		end
	})
	
	Volume = SoundChanger:CreateSlider({
		Name = 'Volume',
		Min = 0,
		Max = 200,
		Default = 100,
		Suffix = function(val) return '%' end,
		Function = function()
			updateVolumes()
		end
	})
end)
	
run(function()
	local UICleanup
	local OpenInv
	local KillFeed
	local OldTabList
	local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	local old, new = {}, {}
	local oldkillfeed
	
	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)
	
	local function modifyconstant(func, ind, val)
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			local typing = type(old[func][ind])
			if typing == 'function' or typing == 'userdata' then return end
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) and val ~= nil then return end
	
		new[func][ind] = val
		if UICleanup.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end
	
	UICleanup = vape.Legit:CreateModule({
		Name = 'UI Cleanup',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				if OpenInv.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				end
	
				if KillFeed.Enabled then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
	
				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
	
				if OldTabList.Enabled then
					starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Cleans up the UI for kits & main'
	})
	UICleanup:CreateToggle({
		Name = 'Resize Health',
		Function = function(callback)
			modifyconstant(HotbarApp, 60, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 15).render, 30, callback and 1 or nil)
			modifyconstant(debug.getupvalue(HotbarApp, 23).tweenPosition, 16, callback and 0 or nil)
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'No Hotbar Numbers',
		Function = function(callback)
			local func = oldinvrender or HotbarOpenInventory.render
			modifyconstant(debug.getupvalue(HotbarApp, 23).render, 90, callback and 0 or nil)
			modifyconstant(func, 71, callback and 0 or nil)
		end,
		Default = true
	})
	OpenInv = UICleanup:CreateToggle({
		Name = 'No Inventory Button',
		Function = function(callback)
			modifyconstant(HotbarApp, 78, callback and 0 or nil)
			if UICleanup.Enabled then
				if callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = 'No Kill Feed',
		Function = function(callback)
			if UICleanup.Enabled then
				if callback then
					oldkillfeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = oldkillfeed
					oldkillfeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = 'Old Player List',
		Function = function(callback)
			if UICleanup.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = 'Fix Queue Card',
		Function = function(callback)
			modifyconstant(bedwars.QueueCard.render, 15, callback and 0.1 or nil)
		end,
		Default = true
	})
end)
	
run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local NoBob
	local Rots = {}
	local old, oldc1
	
	Viewmodel = vape.Legit:CreateModule({
		Name = 'Viewmodel',
		Function = function(callback)
			local viewmodel = gameCamera:FindFirstChild('Viewmodel')
			if callback then
				old = bedwars.ViewmodelController.playAnimation
				oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
				if NoBob.Enabled then
					bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
						if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
						return old(self, animtype, ...)
					end
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				if viewmodel then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
			else
				bedwars.ViewmodelController.playAnimation = old
				if viewmodel then
					viewmodel.RightHand.RightWrist.C1 = oldc1
				end
	
				bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
				old = nil
			end
		end,
		Tooltip = 'Changes the viewmodel animations'
	})
	Depth = Viewmodel:CreateSlider({
		Name = 'Depth',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
			end
		end
	})
	Horizontal = Viewmodel:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 2,
		Default = 0.8,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
			end
		end
	})
	Vertical = Viewmodel:CreateSlider({
		Name = 'Vertical',
		Min = -0.2,
		Max = 2,
		Default = -0.2,
		Decimal = 10,
		Function = function(val)
			if Viewmodel.Enabled then
				lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
			end
		end
	})
	for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
		table.insert(Rots, Viewmodel:CreateSlider({
			Name = name,
			Min = 0,
			Max = 360,
			Function = function(val)
				if Viewmodel.Enabled then
					gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
				end
			end
		}))
	end
	NoBob = Viewmodel:CreateToggle({
		Name = 'No Bobbing',
		Default = true,
		Function = function()
			if Viewmodel.Enabled then
				Viewmodel:Toggle()
				Viewmodel:Toggle()
			end
		end
	})
end)
	
run(function()
	local WinEffect
	local List
	local NameToId = {}
	
	WinEffect = vape.Legit:CreateModule({
		Name = 'WinEffect',
		Function = function(callback)
			if callback then
				WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
					for i, v in getconnections(bedwars.Client:Get('WinEffectTriggered').instance.OnClientEvent) do
						if v.Function then
							v.Function({
								winEffectType = NameToId[List.Value],
								winningPlayer = lplr
							})
						end
					end
				end))
			end
		end,
		Tooltip = 'Allows you to select any clientside win effect'
	})
	local WinEffectName = {}
	for i, v in bedwars.WinEffectMeta do
		table.insert(WinEffectName, v.name)
		NameToId[v.name] = i
	end
	table.sort(WinEffectName)
	List = WinEffect:CreateDropdown({
		Name = 'Effects',
		List = WinEffectName
	})
end)

local WizardUtil
pcall(function()
	WizardUtil = require(game:GetService('ReplicatedStorage').TS.games.bedwars.items['wizard-staff']['wizard-util']).WizardUtil
end)
if not WizardUtil then
	pcall(function()
		WizardUtil = require(lplr.PlayerScripts.TS.games.bedwars.items['wizard-staff']['wizard-util']).WizardUtil
	end)
end
run(function()

	local entity = vape.Libraries.entity
	local targetinfo = vape.Libraries.targetinfo
	local prediction = vape.Libraries.prediction

	local clientEvents = {
		EntityDamageEvent = vapeEvents.EntityDamageEvent
	}

	local function notify(title, text, duration, kind)
		if vape and vape.CreateNotification then
			vape:CreateNotification(title or 'Unreal', text or '', duration or 10, kind or 'alert')
		end
	end

	local run = function(callback)
		callback()
	end

	-- bridges
	local function getBlockAt(pos)
		local grid = bedwars.BlockController:getBlockPosition(pos)
		local store = bedwars.BlockController:getStore()
		return store and store:getBlockAt(grid)
	end

	local function getItem(itemName, inv)
		for _, item in (inv or store.inventory.inventory.items) do
			if item and item.itemType == itemName then
				return item
			end
		end
	end

	local function getItemSlot(tool)
		for slot, item in store.inventory.inventory.items do
			if item and item.tool == tool then
				return slot
			end
		end
	end

	local function switchItem(slot)
		if slot and store.inventory.hotbarSlot ~= slot then
			bedwars.Store:dispatch({
				type = 'InventorySelectHotbarSlot',
				slot = slot
			})
			vapeEvents.InventoryChanged.Event:Wait()
			return true
		end
		return false
	end

	local equipItem = switchItem
	local findItemForTool = getItemSlot

	local function equipTool(tool, delay)
		local slot = getItemSlot(tool)
		if slot then
			switchItem(slot)
			if delay and delay > 0 then
				task.wait(delay)
			end
		end
	end

	local function getTrackedTable(tag, module)
		local tracked = {}

		local function add(obj)
			if typeof(obj) == 'Instance' and obj:GetAttribute('PlacedByUserId') == lplr.UserId then
				table.insert(tracked, obj)
			end
		end

		local function remove(obj)
			local ind = table.find(tracked, obj)
			if ind then
				table.remove(tracked, ind)
			end
		end

		if type(tag) == 'string' then
			for _, obj in CollectionService:GetTagged(tag) do
				add(obj)
			end
			module:Clean(CollectionService:GetInstanceAddedSignal(tag):Connect(add))
			module:Clean(CollectionService:GetInstanceRemovedSignal(tag):Connect(remove))
		else
			for obj in tag do
				add(obj)
			end
		end

		return tracked
	end

	-- target sorting
	local targetSorts = {
		Distance = function(a, b)
			return a.Magnitude < b.Magnitude
		end,
		Health = function(a, b)
			return (a.Entity.Health or 0) < (b.Entity.Health or 0)
		end,
		Damage = function(a, b)
			return (a.Entity.Health or 0) < (b.Entity.Health or 0)
		end
	}
	local sortFunctions = targetSorts

	-- ping + air ray
	store.ping = {
		incoming = 0,
		total = 0
	}

	store.airRay = RaycastParams.new()
	store.airRay.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pingStore = {
			incoming = 0,
			total = 0
		}
		store.ping = pingStore
		while true do
			local ok, ping = pcall(function()
				return lplr:GetNetworkPing() / 1000
			end)
			if ok and ping then
				pingStore.total = ping
				pingStore.incoming = ping
			end
			local airRay = store.airRay
			if not airRay then
				airRay = RaycastParams.new()
				airRay.FilterType = Enum.RaycastFilterType.Exclude
				store.airRay = airRay
			end
			local character = lplr.Character
			airRay.FilterDescendantsInstances = character and {character} or {}
			task.wait(0.5)
		end
	end)

	-- SilentAura
	local silentAura
	local auraTargets
	local aimSpeedSlider
	local extraSwingDistanceSlider
	local maxAngleSlider
	local targetModeDropdown
	local targetAreaDropdown
	local swingOnlyToggle
	local mouseDownToggle
	local dynamicHitsToggle
	local limitToItemsToggle
	local silentAimToggle
	local swingTimeSlider
	local perfectSwingToggle
	local showTargetToggle
	local targetColorSlider
	local attackColorSlider
	local characterPartCache = {}
	local targetBox = Drawing.new('Square')
	targetBox.Visible = false
	targetBox.Filled = false
	targetBox.Thickness = 1

	local function updateTargetBox(part, color, opacity)
		if part and part.Parent then
			local pos, onScreen = currentCamera:WorldToViewportPoint(part.Position)
			if onScreen then
				local distance = math.max((currentCamera.CFrame.Position - part.Position).Magnitude, 1)
				local size = math.clamp(1200 / distance, 24, 180)
				targetBox.Position = Vector2.new(pos.X - size / 2, pos.Y - size * 0.85)
				targetBox.Size = Vector2.new(size, size * 1.7)
				targetBox.Color = color
				targetBox.Transparency = 1 - opacity
				targetBox.Visible = true
				return
			end
		end
		targetBox.Visible = false
	end

	local function getAuraWeapon()
		if not entity.isAlive then
			return
		end

		if mouseDownToggle.Enabled and not inputService:IsMouseButtonPressed(0) and 0.3 < tick() - bedwars.SwordController.lastSwing then
			return
		end

		if swingOnlyToggle.Enabled and 0.3 < tick() - bedwars.SwordController.lastSwing then
			return
		end

		local stunnedUntil = lplr.Character:GetAttribute('StunnedUntilTime') or 0
		if 0 < stunnedUntil - workspace:GetServerTimeNow() then
			return
		end

		if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
			return
		end

		local slot = limitToItemsToggle.Enabled and store.hand
		if not slot then
			slot = store.tools.sword
		end

		if not slot or not slot.tool then
			return
		end

		local itemMeta = bedwars.ItemMeta[slot.tool.Name]

		if not limitToItemsToggle.Enabled then
			return slot, itemMeta
		end

		if store.hand.toolType == 'sword' and not bedwars.DaoController.chargingMaid then
			return slot, itemMeta
		end
	end

	local function getDynamicHitDelay(target, itemMeta)
		local delay = ((itemMeta.displayName:find(' Chainsaw') and 0.11) or 0.29) + 0.03

		if dynamicHitsToggle.Enabled then
			local distance = math.min(14.4, (entity.character.RootPart.Position - target.RootPart.Position).Magnitude)
			return delay * distance / 14.4
		end

		return delay
	end

	local function getAuraAimPoint(target)
		if targetAreaDropdown.Value ~= 'Closest' then
			return target.RootPart.Position
		end

		if not characterPartCache[target.Character] then
			characterPartCache[target.Character] = target.Character:GetChildren()
		end

		local mouseLocation = inputService:GetMouseLocation()
		local closestDistance = 9000000000
		local closestPart = nil

		for _, part in characterPartCache[target.Character] do
			if part and part.Parent and part:IsA('BasePart') then
				local screenPoint, onScreen = currentCamera:WorldToViewportPoint(part.Position)
				if onScreen then
					local distance = (mouseLocation - Vector2.new(screenPoint.x, screenPoint.y)).Magnitude
					if distance < closestDistance then
						closestDistance = distance
						closestPart = part
					end
				end
			end
		end

		if not closestPart then
			return target.RootPart.Position
		end

		return closestPart.Position
	end

	local function easeInOutCubic(alpha)
		if alpha < 0.5 then
			return 4 * alpha * alpha * alpha
		end

		return 1 - math.pow(-2 * alpha + 2, 3) / 2
	end

	local function getAuraCameraCFrame(cameraCFrame, target, deltaTime, aimStartTime)
		local progress = easeInOutCubic(math.min((tick() - aimStartTime) / (1 / (aimSpeedSlider.Value * 0.5)), 1))
		local generator = Random.new()
		local aimRate = aimSpeedSlider.Value * progress

		local jitter = Vector3.new(
			(generator:NextNumber() - 0.5) * 15 * deltaTime,
			(generator:NextNumber() - 0.5) * 15 * deltaTime,
			(generator:NextNumber() - 0.5) * 15 * deltaTime
		)

		local goal = CFrame.lookAt(cameraCFrame.p, getAuraAimPoint(target) + jitter)

		return cameraCFrame:Lerp(goal, aimRate * deltaTime), aimRate
	end

	local function runSilentAura(enabled)
		if not enabled then
			if entity.character and entity.character.Humanoid then
				entity.character.Humanoid.AutoRotate = false
			end
			updateTargetBox(nil)
			return
		end

		local aimTarget = nil
		local lastTargetTime = 0
		local aimStartTime = tick()
		local lastAttackVisualTime = tick()

		silentAura:Clean(RunService.PostSimulation:Connect(function(deltaTime)
			if not entity.isAlive or not aimTarget then
				if entity.isAlive then
					entity.character.Humanoid.AutoRotate = false
				end
				return
			end

			if not aimTarget.RootPart or not aimTarget.RootPart.Parent or not (tick() - lastTargetTime < 0.5) then
				if entity.isAlive then
					entity.character.Humanoid.AutoRotate = false
				end
				return
			end

			targetinfo.Targets[aimTarget] = tick() + 0.5
			entity.character.Humanoid.AutoRotate = not silentAimToggle.Enabled

			local aimedCFrame, aimRate = getAuraCameraCFrame(workspace.CurrentCamera.CFrame, aimTarget, deltaTime, aimStartTime)
			if not silentAimToggle.Enabled then
				workspace.CurrentCamera.CFrame = aimedCFrame
			else
				local rootPart = entity.character.RootPart
				local targetRoot = aimTarget.RootPart
				local flatDirection = Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z - rootPart.Position.Z)
				if flatDirection.Magnitude > 0 then
					rootPart.CFrame = rootPart.CFrame:Lerp(
						CFrame.lookAlong(rootPart.Position, flatDirection),
						math.clamp((aimRate + 2) * deltaTime, 0, 1)
					)
				end
			end
		end))

		local lastAttackTime = 0
		local swingCounter = 9000000000

		repeat
			task.wait()

			local heldItem, itemMeta = getAuraWeapon()
			if not heldItem then
				updateTargetBox(nil)
				lastTargetTime = 0
				swingCounter = 0
			else
				local origin = entity.character.RootPart.Position

				local query = {Origin = origin}
				query.Range = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE + extraSwingDistanceSlider.Value
				query.Wallcheck = auraTargets.Walls.Enabled or nil
				query.Part = 'RootPart'
				query.Players = auraTargets.Players.Enabled
				query.NPCs = auraTargets.NPCs.Enabled
				query.Limit = 1
				query.Sort = sortFunctions[targetModeDropdown.Value or 'Distance']

				local target = entity.EntityPosition(query)

				local activeColor = (tick() - lastAttackVisualTime < 0.1 and attackColorSlider) or targetColorSlider
				updateTargetBox((showTargetToggle.Enabled and target and target.RootPart) or nil, Color3.fromHSV(activeColor.Hue, activeColor.Sat, activeColor.Value), activeColor.Opacity)

				if not target then
					lastTargetTime = 0
					swingCounter = 0
				else
					local hand = store.hand
					if not hand or hand.tool ~= heldItem.tool then
						local slot = findItemForTool(heldItem.tool)
						if slot then
							equipItem(slot)
						end
					end

					hand = store.hand
					if hand and hand.tool == heldItem.tool then
						if 50 < swingCounter then
							swingCounter = 0
						end
						swingCounter = swingCounter + 1

						local aimSource = (inputService.KeyboardEnabled and workspace.CurrentCamera) or entity.character.RootPart
						local lookDirection = aimSource.CFrame.LookVector * Vector3.new(1, 0, 1)
						local toTarget = target.RootPart.Position - origin
						local flatToTarget = (target.RootPart.Position - origin) * Vector3.new(1, 0, 1)

						local facing
						if flatToTarget.Magnitude > 0 and lookDirection.Magnitude > 0 then
							facing = (lookDirection / lookDirection.Magnitude):Dot(flatToTarget / flatToTarget.Magnitude)
						end
						facing = facing or 0

						if not (facing < math.cos(math.rad(maxAngleSlider.Value) / 2)) then
							if not swingOnlyToggle.Enabled then
								local sinceSwing = tick() - bedwars.SwordController.lastSwing
								local swingDelay
								if perfectSwingToggle.Enabled then
									swingDelay = itemMeta.sword.attackSpeed or 0.11
								end
								if not swingDelay then
									swingDelay = math.max(swingTimeSlider.Value, 0.11)
								end
								if swingDelay <= sinceSwing then
									bedwars.SwordController:playSwordEffect(itemMeta, false)
									bedwars.SwordController.lastSwing = tick()
								end
							end

							aimTarget = target
							lastTargetTime = tick()

							if not (bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE < toTarget.Magnitude) then
								lastAttackVisualTime = tick()

								local readyToHit
								if dynamicHitsToggle.Enabled then
									readyToHit = tick() - lastAttackTime >= getDynamicHitDelay(target, itemMeta)
								end
								if not readyToHit then
									readyToHit = bedwars.SwordController:getRemainingSwingCooldown(heldItem.tool.Name) <= 0
								end

								if readyToHit then
									local cursorDirection = CFrame.lookAt(origin, target.RootPart.Position).LookVector
									local selfPosition = origin + cursorDirection * math.max(toTarget.Magnitude - 14.4, 0)

									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									lastAttackTime = tick()

									bedwars.Client:Get(remotes.AttackEntity):SendToServer({
										weapon = heldItem.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = target.Character,
										validate = {
											raycast = {
												cameraPosition = {value = workspace.CurrentCamera.CFrame.Position},
												cursorDirection = {value = cursorDirection},
											},
											targetPosition = {value = target.Character:GetPivot().Position},
											selfPosition = {value = selfPosition},
										},
									})
								end
							end
						end
					end
				end
			end
		until not silentAura.Enabled
	end

	silentAura = vape.Categories.Combat:CreateModule({
		Name = 'SilentAura',
		Function = runSilentAura,
		Tooltip = 'Automatically aims and attacks nearby target',
	})

	auraTargets = silentAura:CreateTargets({Players = false, NPCs = false})

	aimSpeedSlider = silentAura:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 10,
		Default = 6,
		Decimal = 5,
		Tooltip = 'How fast the Aura is going to aim',
	})

	swingTimeSlider = silentAura:CreateSlider({
		Name = 'Swing time',
		Darker = false,
		Visible = false,
		Min = 0,
		Max = 0.5,
		Default = 0.42,
		Decimal = 100,
	})

	extraSwingDistanceSlider = silentAura:CreateSlider({
		Name = 'Extra swing distance',
		Tooltip = 'Where you will start swinging, not attacking',
		Min = 0,
		Max = 6,
		Suffix = function()
			return 'stud'
		end,
		Decimal = 5,
		Default = 3,
	})

	maxAngleSlider = silentAura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 180,
	})

	local auraTargetModes = {'Damage', 'Distance'}
	for sortName in sortFunctions do
		if not table.find(auraTargetModes, sortName) then
			table.insert(auraTargetModes, sortName)
		end
	end

	targetModeDropdown = silentAura:CreateDropdown({
		Name = 'Target mode',
		Default = 'Health',
		List = auraTargetModes,
		Tooltip = 'How Aura should prioritize targets',
	})

	targetAreaDropdown = silentAura:CreateDropdown({
		Name = 'Target area',
		List = {'Center', 'Closest'},
		Default = 'Center',
		Visible = false,
		Tooltip = 'Where the Aura will aim towards',
	})

	perfectSwingToggle = silentAura:CreateToggle({
		Name = 'Perfect Swing',
		Default = false,
		Tooltip = 'Follows sword item\'s swing time',
	})

	mouseDownToggle = silentAura:CreateToggle({Name = 'Require mouse down'})

	dynamicHitsToggle = silentAura:CreateToggle({
		Name = 'Dynamic hits',
		Default = false,
		Tooltip = 'Calculates the best hitreg for you, based off how far you are to the opponent.',
	})

	swingOnlyToggle = silentAura:CreateToggle({Name = 'Swing only'})

	limitToItemsToggle = silentAura:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks when the sword is held',
	})

	silentAimToggle = silentAura:CreateToggle({
		Name = 'Silent Aim',
		Function = function(enabled)
			targetAreaDropdown.Object.Visible = not enabled
		end,
		Default = false,
		Tooltip = 'Silently aims while looking legit',
	})

	showTargetToggle = silentAura:CreateToggle({
		Name = 'Show target',
		Default = false,
		Function = function(enabled)
			if targetColorSlider and targetColorSlider.Object then
				targetColorSlider.Object.Visible = enabled
			end
			if attackColorSlider and attackColorSlider.Object then
				attackColorSlider.Object.Visible = enabled
			end
		end,
	})

	targetColorSlider = silentAura:CreateColorSlider({
		Name = 'Target color',
		Darker = false,
		DefaultOpacity = 0.5,
		DefaultHue = 1,
	})

	attackColorSlider = silentAura:CreateColorSlider({
		Name = 'Attack color',
		Darker = false,
		DefaultOpacity = 0.5,
	})

	-- AutoBeekeeper
	run(function()
		local autoBeekeeper, collectBees, collectRange, collectDelay, limitToItem
		local depositBees, depositRange, depositDelay
		local minigames = vape.Categories.Minigames

		autoBeekeeper = minigames:CreateModule({
			Name = 'AutoBeekeeper',
			Function = function(enabled)
				if enabled then
					local beehives = getTrackedTable('beehive', autoBeekeeper)
					repeat
						if entity.isAlive then
							pcall(function()
								if collectBees.Enabled then
									if not limitToItem.Enabled then
										local position = entity.character.RootPart.Position
										for _, bee in CollectionService:GetTagged('bee') do
											if (position - bee.PrimaryPart.Position).Magnitude <= collectRange.Value then
												bedwars.Client:Get('PickUpBee'):SendToServer({
													beeId = bee:GetAttribute('BeeId'),
												})
												if collectDelay.Value > 0 then
													task.wait(collectDelay.Value)
												end
											end
										end
									else
										local hand = store.hand
										if hand.tool and hand.tool.Name == 'bee_net' then
											for _, bee in CollectionService:GetTagged('bee') do
											end
										end
									end
								end

								if depositBees.Enabled and getItem('bee') then
									local position = entity.character.RootPart.Position
									for _, hive in beehives do
										if not getItem('bee') then
											return
										end
										local level = hive:GetAttribute('Level') or 0
										if level < 10 then
											if hive:GetAttribute('PlacedByUserId') == lplr.UserId
												and (position - hive.Position).Magnitude <= depositRange.Value then
												pcall(function()
													task.spawn(function()
														pcall(fireproximityprompt or function() end, hive.ProximityPrompt)
end)
	
													if depositDelay.Value > 0 then
														task.wait(depositDelay.Value)
													end
												end)
											end
										end
									end
								end
							end)
						end
						task.wait(0.1)
					until not autoBeekeeper.Enabled
				end
			end,
			Tooltip = 'Automatically deposit bees, and collects nearby bees',
		})

		collectBees = autoBeekeeper:CreateToggle({
			Name = 'Collect bees',
			Default = false,
			Function = function(enabled)
				pcall(function()
					collectRange.Object.Visible = enabled
					collectDelay.Object.Visible = enabled
					limitToItem.Object.Visible = enabled
				end)
			end,
		})

		collectRange = autoBeekeeper:CreateSlider({
			Name = 'Collect Range',
			Min = 1,
			Max = 22,
			Default = 20,
			Darker = false,
			Suffix = function(value)
				return value <= 1 and 'stud' or 'studs'
			end,
		})

		collectDelay = autoBeekeeper:CreateSlider({
			Name = 'Collect delay',
			Min = 0,
			Max = 2,
			Decimal = 100,
			Default = 0.1,
			Darker = false,
		})

		limitToItem = autoBeekeeper:CreateToggle({
			Name = 'Limit to item',
			Darker = false,
		})

		depositBees = autoBeekeeper:CreateToggle({
			Name = 'Deposit bees',
			Function = function(enabled)
				pcall(function()
					depositDelay.Object.Visible = enabled
				end)
			end,
			Tooltip = 'Automatically puts the bees into a beehive',
		})

		depositRange = autoBeekeeper:CreateSlider({
			Name = 'Deposit Range',
			Min = 1,
			Max = 14,
			Default = 14,
			Darker = false,
			Visible = false,
			Suffix = function(value)
				return value <= 1 and 'stud' or 'studs'
			end,
		})

		depositDelay = autoBeekeeper:CreateSlider({
			Name = 'Deposit Delay',
			Min = 0,
			Max = 2,
			Decimal = 100,
			Default = 0.1,
			Visible = false,
			Darker = false,
		})
	end)

	-- AutoDavey
	run(function()
		local autoDavey, legitSwitch, breakOnImpact, jumpOnImpact
		local originalLaunchSelf
		local minigames = vape.Categories.Minigames

		autoDavey = minigames:CreateModule({
			Name = 'AutoDavey',
			Function = function(enabled)
				if not enabled then
					if originalLaunchSelf then
						bedwars.CannonHandController.launchSelf = originalLaunchSelf
						originalLaunchSelf = nil
					end
				else
					originalLaunchSelf = bedwars.CannonHandController.launchSelf
					bedwars.CannonHandController.launchSelf = function(...)
						local results = {originalLaunchSelf(...)}
						local landedBlock

						if autoDavey.Enabled and breakOnImpact.Enabled then
							if landedBlock and landedBlock.Parent and entity.isAlive then
								local offset = landedBlock.Position - entity.character.RootPart.Position
								if offset.Magnitude <= 30 then
									task.delay(0.02, function()
										if landedBlock.Parent then
											local breakArgument
											for _ = 1, 2 do
												task.spawn(bedwars.breakBlock, landedBlock, false, false, nil, breakArgument)
											end
										end
									end)
								end
							end
						end

						if autoDavey.Enabled and jumpOnImpact.Enabled and entity.isAlive then
							entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end

						return table.unpack(results)
					end
				end
			end,
			Tooltip = 'Automatically breaks cannon/jump on launch',
		})

		jumpOnImpact = autoDavey:CreateToggle({Name = 'Jump on impact'})
		breakOnImpact = autoDavey:CreateToggle({Name = 'Break on impact'})
		legitSwitch = autoDavey:CreateToggle({Name = 'Legit switch'})
	end)

	-- AutoDrill
	run(function()
		local autoDrill, autoCollect, notifyOnCollect, autoAttack, legitRange
		local range, attackDelay, collectDelay, targets, sortMode
		local activeDrill
		local attackCooldowns = {}
		local collectCooldowns = {}

		local function getDrillPart(drill)
			local part = drill.PrimaryPart
			if not part then
				part = drill:FindFirstChild('RootPart')
			end
			if not part then
				part = drill:FindFirstChildWhichIsA('BasePart')
			end
			return part
		end

		local function addDrill(list, seen, drill)
			if typeof(drill) == 'Instance' then
				if not seen[drill] then
					if drill:GetAttribute('PlacedByUserId') == lplr.UserId then
						if getDrillPart(drill) then
							seen[drill] = false
							table.insert(list, drill)
						end
					end
				end
			end
		end

		local function getDrills(tracked)
			local drills = {}
			local seen = {}

			for _, drill in tracked do
				addDrill(drills, seen, drill)
			end

			local drillList = bedwars.DrillTabletController
			if drillList then
				drillList = bedwars.DrillTabletController.drillList
			end

			for _, drill in drillList or {} do
				addDrill(drills, seen, drill)
			end

			return drills
		end

		local function getDrillResourceCount(drill)
			local diamonds = drill:GetAttribute('diamond') or 0
			local emeralds = drill:GetAttribute('emerald') or 0
			return diamonds + emeralds
		end

		local function collectFromDrill(drill)
			return pcall(function()
				bedwars.Client:Get('ExtractFromDrill'):SendToServer({drill = drill})
			end)
		end

		local function useDrill(drill)
			if activeDrill ~= drill then
				pcall(function()
					return bedwars.Client:Get('PlayerUseDrillController')
				end)
				activeDrill = drill
			end
		end

		local function attackWithDrill(drill, target)
			useDrill(drill)
			return pcall(function()
				bedwars.Client:Get('DrillAttack'):SendToServer({
					targetPosition = target.RootPart.Position,
				})
			end)
		end

		local function findDrillTarget(origin)
			local query = {}
			query.Origin = origin
			query.Range = (legitRange.Enabled and 10) or range.Value
			query.Part = 'RootPart'
			query.Players = targets.Players.Enabled
			query.NPCs = targets.NPCs.Enabled
			query.Sort = targetSorts[sortMode.Value]
			return entity.EntityPosition(query)
		end

		local function updateAttackOptions()
			pcall(function()
				local enabled = autoAttack.Enabled
				legitRange.Object.Visible = enabled
				range.Object.Visible = enabled and not legitRange.Enabled
				attackDelay.Object.Visible = enabled
				targets.Object.Visible = enabled
				sortMode.Object.Visible = enabled
			end)
		end

		local minigames = vape.Categories.Minigames

		autoDrill = minigames:CreateModule({
			Name = 'AutoDrill',
			Function = function(enabled)
				if not enabled then
					activeDrill = nil
					table.clear(attackCooldowns)
					table.clear(collectCooldowns)
				else
					local trackedDrills = getTrackedTable('Drill', autoDrill)

					repeat
						task.wait()
					until (store.matchState ~= 0 and store.equippedKit == 'drill') or not autoDrill.Enabled

					repeat
						if entity.isAlive and store.equippedKit == 'drill' then
							local now = tick()
							for _, drill in getDrills(trackedDrills) do
								local part = getDrillPart(drill)
								if part then
									if autoCollect.Enabled and getDrillResourceCount(drill) > 0 then
										if (collectCooldowns[drill] or 0) < now then
											if collectFromDrill(drill) and notifyOnCollect.Enabled then
												notify('Auto Drill', 'Collected drill resources', 4, 'info')
											end
											collectCooldowns[drill] = now + collectDelay.Value
										end
									end

									if autoAttack.Enabled then
										if (attackCooldowns[drill] or 0) < now then
											local target = findDrillTarget(part.Position)
											if target then
												targetinfo.Targets[target] = now + 1
												if attackWithDrill(drill, target) then
													attackCooldowns[drill] = now + attackDelay.Value
												end
											end
										end
									end
								end
							end
						end
						task.wait(0.1)
					until not autoDrill.Enabled
				end
			end,
			Tooltip = 'Automatically collects resources and attacks with placed drills.',
		})

		autoCollect = autoDrill:CreateToggle({
			Name = 'Auto collect',
			Default = false,
			Function = function(enabled)
				pcall(function()
					notifyOnCollect.Object.Visible = enabled
					collectDelay.Object.Visible = enabled
				end)
			end,
		})

		notifyOnCollect = autoDrill:CreateToggle({
			Name = 'Notify on collect',
			Darker = false,
		})

		autoAttack = autoDrill:CreateToggle({
			Name = 'Auto attack',
			Default = false,
			Function = updateAttackOptions,
		})

		range = autoDrill:CreateSlider({
			Name = 'Range',
			Min = 1,
			Max = 10,
			Default = 10,
			Suffix = function(value)
				return value == 1 and 'stud' or 'studs'
			end,
		})

		legitRange = autoDrill:CreateToggle({
			Name = 'Legit Range',
			Default = false,
			Function = updateAttackOptions,
		})

		attackDelay = autoDrill:CreateSlider({
			Name = 'Attack delay',
			Min = 0.1,
			Max = 1,
			Default = 0.3,
			Decimal = 100,
			Suffix = function(value)
				return value == 1 and 'sec' or 'secs'
			end,
		})

		collectDelay = autoDrill:CreateSlider({
			Name = 'Collect delay',
			Min = 0.1,
			Max = 3,
			Default = 0.5,
			Decimal = 10,
			Suffix = function(value)
				return value == 1 and 'sec' or 'secs'
			end,
		})

		targets = autoDrill:CreateTargets({
			Players = false,
			NPCs = false,
		})

		local sortList = {'Distance', 'Health', 'Damage'}
		for sortName in targetSorts do
			if not table.find(sortList, sortName) then
				table.insert(sortList, sortName)
			end
		end

		sortMode = autoDrill:CreateDropdown({
			Name = 'Sort',
			List = sortList,
			Default = 'Distance',
		})

		updateAttackOptions()
	end)

	-- AutoGrim
	run(function()
		local autoGrim, grimRange, grimDelay
		local minigames = vape.Categories.Minigames

		autoGrim = minigames:CreateModule({
			Name = 'AutoGrim',
			Function = function(enabled)
				if enabled then
					local souls = getTrackedTable(bedwars.GrimReaperController.soulsByPosition, autoGrim)
					if entity.isAlive then
					end
				end
			end,
		})

		grimRange = autoGrim:CreateSlider({
			Name = 'Range',
			Min = 1,
			Max = 120,
			Default = 12,
			Suffix = function(value)
				return value <= 1 and 'stud' or 'studs'
			end,
		})

		autoGrim:CreateButton({
			Name = 'Sync to legit range',
		})

		grimDelay = autoGrim:CreateSlider({
			Name = 'Delay',
			Min = 0,
			Max = 2,
			Default = 0.1,
			Suffix = 'seconds',
			Decimal = 10,
		})
	end)

	-- AutoKrystal
	run(function()
		local autoKrystal

		local function nearBreakableBed()
			local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero
			for _, bed in CollectionService:GetTagged('bed') do
				if (origin - bed.Position).Magnitude <= 22 then
					local team = lplr:GetAttribute('Team') or -1
					if not bed:GetAttribute('Team' .. team .. 'NoBreak') then
						return true
					end
				end
			end
			return false
		end

		local minigames = vape.Categories.Minigames

		autoKrystal = minigames:CreateModule({
			Name = 'AutoKrystal',
			Function = function(enabled)
				if enabled then
					if entity.isAlive and store.equippedKit == 'glacial_skater' then
					end
				end
			end,
			Tooltip = 'Automatically uses freeze ability when near\nopponent\'s bed defense.',
		})
	end)

	-- AutoRagnar
	run(function()
		local autoRagnar

		local function nearBreakableBed()
			local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero
			for _, bed in CollectionService:GetTagged('bed') do
				if (origin - bed.Position).Magnitude <= 22 then
					local team = lplr:GetAttribute('Team') or -1
					if not bed:GetAttribute('Team' .. team .. 'NoBreak') then
						return true
					end
				end
			end
			return false
		end

		local minigames = vape.Categories.Minigames

		autoRagnar = minigames:CreateModule({
			Name = 'AutoRagnar',
			Function = function(enabled)
				if enabled then
					repeat
						if entity.isAlive and store.equippedKit == 'berserker' then
							local abilityController = bedwars.AbilityController
							if abilityController:canUseAbility('berserker_rage') and nearBreakableBed() then
								bedwars.AbilityController:useAbility('berserker_rage')
							end
						end
						task.wait(0.1)
					until not autoRagnar.Enabled
				end
			end,
			Tooltip = 'Automatically uses "Berserker Rage" ability when near\nopponent\'s bed.',
		})
	end)

	-- AutoVanessa
	run(function()
		local autoVanessa
		local originalGetChargeTime, chargeTimeHook, originalOverchargeStartTime, tripleShotController
		local minigames = vape.Categories.Minigames

		autoVanessa = minigames:CreateModule({
			Name = 'AutoVanessa',
			Function = function(enabled)
				if not enabled then
					if originalGetChargeTime and tripleShotController then
						if tripleShotController.getChargeTime == chargeTimeHook then
							tripleShotController.getChargeTime = originalGetChargeTime
							tripleShotController.overchargeStartTime = originalOverchargeStartTime
						end
					end
					originalGetChargeTime = nil
					chargeTimeHook = nil
					originalOverchargeStartTime = nil
					tripleShotController = nil
				else
					autoVanessa:Clean(task.spawn(function()
						local controller
						repeat
							task.wait()
							controller = bedwars.TripleShotProjectileController
						until controller or not autoVanessa.Enabled

						if controller then
							tripleShotController = bedwars.TripleShotProjectileController
							originalGetChargeTime = tripleShotController.getChargeTime

							if typeof(originalGetChargeTime) == 'function' then
								originalOverchargeStartTime = tripleShotController.overchargeStartTime
								chargeTimeHook = function(...)
									if autoVanessa.Enabled then
										return
									end
									return originalGetChargeTime(...)
								end
								tripleShotController.getChargeTime = chargeTimeHook
								tripleShotController.overchargeStartTime = tick()
							else
								tripleShotController = nil
								originalGetChargeTime = nil
							end
						end
					end))
				end
			end,
			Tooltip = 'Fully charges your bow instantly and enables triple shot as Vanessa',
		})
	end)

	-- AutoZeno
	run(function()
		local autoZeno, targets, targetMode, limitToItem, autoShockwave
		local shockwaveRange, useLightningStrike, useLightningStorm, zenoRange, zenoDelay

		local function equipWizardStaff()
			if not bedwars.WizardUtil then
				return
			end

			if not limitToItem.Enabled then
				for _, item in store.inventory.inventory.items do
					if bedwars.WizardUtil:isWizardStaff(item.itemType) and item.tool then
						equipTool(item.tool, 0)
						return
					end
				end
				return
			end

			local tool = store.hand.tool
			local heldName = tool and tool.Name
			if not heldName or not bedwars.WizardUtil:isWizardStaff(heldName) then
				return
			end
		end

		local function canUseWizardAbility(ability, staff)
			if not bedwars.WizardUtil then
				return false
			end

			if bedwars.WizardUtil:hasAbility(staff, ability) then
				local staffController = bedwars.WizardStaffController
				if staffController then
					local castOk, canCast = pcall(staffController.canCastAbility, staffController, ability)
					if castOk and canCast then
						local abilityController = bedwars.AbilityController
						local useOk, canUse = pcall(abilityController.canUseAbility, abilityController, ability)
						if useOk then
							return canUse
						end
					end
				end
			end
		end

		local function useWizardAbility(ability, target)
			local args = {}
			args.target = (ability == 'SHOCKWAVE' and Vector3.zero) or target
			local abilityController = bedwars.AbilityController
		end

		local minigames = vape.Categories.Minigames

		autoZeno = minigames:CreateModule({
			Name = 'AutoZeno',
			Function = function(enabled)
				if enabled then
					local abilityCooldowns = {}
					if entity.isAlive then
					end
				end
			end,
			Tooltip = 'Automatically uses zeno\'s staff.',
		})

		targets = autoZeno:CreateTargets({
			Players = false,
			NPCs = false,
		})

		local sortList = {'Damage', 'Distance'}
		for sortName in targetSorts do
			if not table.find(sortList, sortName) then
				table.insert(sortList, sortName)
			end
		end

		targetMode = autoZeno:CreateDropdown({
			Name = 'Target Mode',
			List = sortList,
			Default = 'Distance',
		})

		limitToItem = autoZeno:CreateToggle({
			Name = 'Limit to item',
			Default = false,
		})

		useLightningStrike = autoZeno:CreateToggle({
			Name = 'Use Lightning Strike',
			Default = false,
		})

		useLightningStorm = autoZeno:CreateToggle({
			Name = 'Use Lightning Storm',
		})

		autoShockwave = autoZeno:CreateToggle({
			Name = 'Auto Shockwave',
			Function = function(enabled)
				pcall(function()
					shockwaveRange.Object.Visible = enabled
				end)
			end,
			Tooltip = 'Automatically uses the shockwave ability when a target is near',
		})

		shockwaveRange = autoZeno:CreateSlider({
			Name = 'Shockwave Range',
			Visible = false,
			Darker = false,
			Min = 1,
			Max = 12,
			Suffix = function(value)
				return value > 1 and 'studs' or 'stud'
			end,
			Decimal = 5,
			Default = 12,
		})

		zenoRange = autoZeno:CreateSlider({
			Name = 'Range',
			Min = 1,
			Max = 60,
			Default = 35,
			Suffix = function(value)
				return value > 1 and 'studs' or 'stud'
			end,
			Decimal = 5,
		})

		zenoDelay = autoZeno:CreateSlider({
			Name = 'Delay',
			Min = 0,
			Max = 10,
			Default = 0.5,
			Decimal = 5,
			Suffix = function(value)
				return value > 1 and 'secs' or 'sec'
			end,
		})
	end)

	-- CheatDetector
	do
		local cheatDetector
		local checks = {}

		checks.Speed = function()
			local positions = {}
			repeat
				if store.ping.incoming > 0.5 then
					task.wait(0.2)
					table.clear(positions)
				else
					for _, target in entity.List do
						local player = target.Player
						if player and (not positions[player] or positions[player].Time < tick()) then
							local flatPosition = target.RootPart.Position * Vector3.new(1, 0, 1)
							local previous = positions[player]
							if previous and previous.Delta then
								local lastTeleported = player:GetAttribute('LastTeleported') or 0
								if workspace:GetServerTimeNow() - lastTeleported > 0.4 then
									local travelled = (flatPosition - previous.Position) / previous.Delta
									if travelled.Magnitude > 23 then
										notify(
											'CheatDetector',
											player.Name .. ' may be speeding (exceeded 22 studs per secs)',
											10,
											'alert'
										)
									end
								end
							end

							positions[player] = {
								Time = tick() + 0.2,
								Position = flatPosition
							}

							task.spawn(function()
								positions[player].Delta = task.wait(0.2)
							end)
						end
					end
					task.wait()
				end
			until not cheatDetector.Enabled
		end

		checks.Killaura = function()
			local lastHit = {}
			local hits = {}

			cheatDetector:Clean(clientEvents.EntityDamageEvent.Event:Connect(function(damage)
				if damage.damageType == 0 and damage.fromEntity then
					local player = playersService:GetPlayerFromCharacter(damage.fromEntity)
					if player and player ~= lplr then
						if os.clock() - (lastHit[player] or 0) <= 0.15 then
							hits[player] = (hits[player] or 0) + 1

							task.delay(30, function()
								if cheatDetector.Enabled and hits[player] then
									hits[player] = math.max(hits[player] - 1, 0)
								end
							end)

							if hits[player] > 5 then
								notify(
									'CheatDetector',
									damage.fromEntity.Name .. ' may be using killaura (excessive hit rate)',
									10,
									'alert'
								)
							end
						end
						lastHit[player] = os.clock()
					end
				end
			end))
		end

		checks.Reach = function()
			cheatDetector:Clean(clientEvents.EntityDamageEvent.Event:Connect(function(damage)
				if damage.damageType == 0 and damage.fromEntity and damage.entityInstance then
					if not (damage.fromEntity.PrimaryPart and damage.entityInstance.PrimaryPart) then
						return
					end
					local player = playersService:GetPlayerFromCharacter(damage.fromEntity)
					if player and player ~= lplr then
						local attackerPosition = damage.fromEntity.PrimaryPart.Position
						local victimPosition = damage.entityInstance.PrimaryPart.Position
						local distance = (attackerPosition - victimPosition).Magnitude

						local hand = (store.inventories[player] or {}).hand
						local sword = hand and hand.tool and (bedwars.ItemMeta[hand.tool.Name] or {}).sword or nil
						local range = (sword and sword.attackRange or 14.4) + 6

						if range * (0.95 + store.ping.total) < distance then
							notify(
								'CheatDetector',
								damage.fromEntity.Name .. ' may be using reach',
								10,
								'alert'
							)
						end
					end
				end
			end))
		end

		local utility = vape.Categories.Utility

		cheatDetector = utility:CreateModule({
			Name = 'CheatDetector',
			Function = function(enabled)
				if enabled then
					for _, check in checks do
						task.spawn(check)
					end
				end
			end,
			Tooltip = 'Detects possible cheaters in ur game'
		})

		for name in checks do
			cheatDetector:CreateToggle({
				Name = name,
				Default = false
			})
		end
	end

	-- DeviceSpoofer
	do
		local deviceSpoofer
		local device
		local realInputType
		local realGetUserInputType

		local utility = vape.Categories.Utility

		deviceSpoofer = utility:CreateModule({
			Name = 'DeviceSpoofer',
			Function = function(enabled)
				if enabled then
					realInputType = bedwars.UserInputController:getUserInputType()
					realGetUserInputType = bedwars.UserInputController.getUserInputType

					bedwars.UserInputController.getUserInputType = function()
						return device.Value:upper()
					end

					pcall(function()
						bedwars.Client:Get('SendUserInputType'):SendToServer({
							userInputType = device.Value:upper()
						})
					end)
				else
					bedwars.UserInputController.getUserInputType = realGetUserInputType

					pcall(function()
						bedwars.Client:Get('SendUserInputType'):SendToServer({
							userInputType = realInputType
						})
					end)

					realGetUserInputType = nil
				end
			end,
			ExtraText = function()
			end,
			Tooltip = 'Spoofs the device you show up as to the server'
		})

		device = deviceSpoofer:CreateDropdown({
			Name = 'Device',
			List = {'Mobile', 'PC', 'Gamepad'},
			Function = function(value)
				if deviceSpoofer.Enabled then
					pcall(function()
						bedwars.Client:Get('SendUserInputType'):SendToServer({
							userInputType = value:upper()
						})
					end)
				end
			end
		})
	end

	-- BedPatcher
	do
		local bedPatcher
		local placeRange
		local whitelist
		local mode
		local autoSwitch
		local limitToItem

		local function findBed()
			local origin = entity.isAlive and entity.character.RootPart.Position or Vector3.zero

			for _, bed in CollectionService:GetTagged('bed') do
				if (origin - bed.Position).Magnitude < 14 then
					local team = lplr:GetAttribute('Team') or -1
					if bed:GetAttribute('Team' .. team .. 'NoBreak') then
						return bed
					end
				end
			end
		end

		local function getBlock()
			if limitToItem.Enabled and store.hand.toolType == 'block' then
				local handName = store.hand.tool.Name
				if table.find(whitelist.ListEnabled, handName:find('wool') and 'wool' or store.hand.tool.Name) then
					return {store.hand.tool.Name}
				end
			end

			local blocks = {}

			for _, item in store.inventory.inventory.items do
				local block = bedwars.ItemMeta[item.itemType].block
				if block then
					if table.find(whitelist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then
						table.insert(blocks, {item.itemType, block.health, item.tool})
					end
				end
			end

			if #blocks > 1 then
				table.sort(blocks, function(a, b)
					return a[2] > b[2]
				end)
			end

			return blocks[1] or {}
		end

		local function ringOffsets(radius, spacing)
			local offsets = {}

			for i = radius, 0, -1 do
				for j = i, 0, -1 do
					table.insert(offsets, Vector3.new(j, radius - i, i + 1 - j) * spacing)
					table.insert(offsets, Vector3.new(j * -1, radius - i, i + 1 - j) * spacing)
					table.insert(offsets, Vector3.new(j, radius - i, (i - j) * -1) * spacing)
					table.insert(offsets, Vector3.new(j * -1, radius - i, (i - j) * -1) * spacing)
				end
			end

			return offsets
		end

		local world = vape.Categories.World

		bedPatcher = world:CreateModule({
			Name = 'BedPatcher',
			Function = function(enabled)
				if not enabled then
					return
				end

				while true do
					local bed = findBed()

					if bed then
						for i = 0, 6 do
							local up = Vector3.yAxis * (3 * i)

							if getBlockAt(bed.Position + up) then
								for _, offset in ringOffsets(i, 3) do
									local blockName, _, blockTool = table.unpack(getBlock())

									if blockName then
										local position = (bed.CFrame * CFrame.new(offset)).Position

										if not getBlockAt(position) then
											local rootPosition = entity.character.RootPart.Position

											if (rootPosition - position).Magnitude <= placeRange.Value then
												if autoSwitch.Enabled and getItemSlot(blockTool) then
													if switchItem(getItemSlot(blockTool)) then
														task.wait()
													end
												end

												task.spawn(bedwars.placeBlock, position, blockName, false)
												task.wait(0.1)
											end
										end
									end
								end
							else
								local front = ((bed.CFrame + up) * CFrame.new(0, 0, 3)).Position
								if getBlockAt(front) then
									ringOffsets(i, 3)
								end
							end
						end
					elseif mode.Value == 'On Key' then
						notify('BedPatcher', 'Unable to locate bed', 5)
						bedPatcher:Toggle()
					end

					task.wait(0.5)

					if mode.Value == 'On Key' then
						bedPatcher:Toggle()
						break
					end

					if not bedPatcher.Enabled then
						break
					end
				end
			end,
			Tooltip = 'Automatically replaces missing blocks near bed.'
		})

		mode = bedPatcher:CreateDropdown({
			Name = 'Mode',
			List = {'Toggle', 'On Key'},
			Default = 'Toggle'
		})

		whitelist = bedPatcher:CreateTextList({
			Name = 'Whitelist',
			Default = {'wool', 'obsidian'}
		})

		placeRange = bedPatcher:CreateSlider({
			Name = 'Place Range',
			Min = 1,
			Max = 60,
			Default = 15
		})

		bedPatcher:CreateToggle({
			Name = 'Wool only',
			Tooltip = 'Only uses wools to patch.'
		})

		autoSwitch = bedPatcher:CreateToggle({
			Name = 'Auto Switch'
		})

		limitToItem = bedPatcher:CreateToggle({
			Name = 'Limit to item'
		})
	end

	-- Block-In
	do
		local blockIn
		local placeDelay
		local blockPriority
		local returnToLastSlot
		local woolOnly
		local blacklist

		local WALL_DIRECTIONS = {
			Vector3.new(1, 0, 0),
			Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1),
			Vector3.new(0, 0, -1)
		}

		local blockSorters = {
			['Lowest cost'] = function(a, b)
				return a[2] < b[2]
			end,
			Hardest = function(a, b)
				return a[2] > b[2]
			end
		}

		local function roundToGrid(position)
			return Vector3.new(
				math.floor(position.X / 3 + 0.5) * 3,
				math.floor(position.Y / 3 + 0.5) * 3,
				math.floor(position.Z / 3 + 0.5) * 3
			)
		end

		local function findSupportY(hasBlock, position, topY)
			local y = topY
			local lowestY = topY - 30

			while lowestY <= y do
				if hasBlock(roundToGrid(Vector3.new(position.X, y, position.Z))) then
					return y
				end
				y = y - 3
			end
		end

		local function collectColumn(hasBlock, origin, direction, height)
			local offsets = {}
			local base = origin + direction * 3
			local topY = origin.Y + 6
			local supportY = findSupportY(hasBlock, base, topY)
			local startY

			if supportY then
				startY = supportY + 3
			end

			local y = startY
			while y <= topY do
				table.insert(offsets, Vector3.new(direction.X * 3, y - origin.Y, direction.Z * 3))
				y = y + 3
			end

			return offsets
		end

		local function buildWallOffsets(origin, hasBlock)
			local wall = {}
			local candidates = {}

			for _, direction in ipairs(WALL_DIRECTIONS) do
				local column = collectColumn(hasBlock, origin, direction, 2)
				table.insert(candidates, {
					dir = direction,
					out = column,
					cost = #column
				})
			end

			table.sort(candidates, function(a, b)
				return a.cost < b.cost
			end)

			local best = candidates[1]
			best.out = collectColumn(hasBlock, origin, candidates[1].dir, 2)
			candidates[1].cost = #candidates[1].out

			local highestY = 0
			for _, candidate in ipairs(candidates) do
				if #candidate.out > 0 then
					local top = candidate.out[#candidate.out]
					if highestY < top.Y then
						highestY = top.Y
					end
				end
			end

			for _, offset in ipairs(candidates[1].out) do
				table.insert(wall, offset)
			end

			table.insert(wall, Vector3.new(0, highestY, 0))

			for i = 2, #candidates do
				for _, offset in ipairs(candidates[i].out) do
					if offset.Y ~= highestY then
						table.insert(wall, offset)
					end
				end
			end

			return wall
		end

		local function getBlocks()
			local blocks = {}

			for _, item in store.inventory.inventory.items do
				local block = bedwars.ItemMeta[item.itemType].block
				if block then
					if woolOnly.Enabled then
						if item.itemType:find('wool') then
							table.insert(blocks, {item.itemType, block.health, item.tool})
						end
					elseif not table.find(blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then
						table.insert(blocks, {item.itemType, block.health, item.tool})
					end
				end
			end

			if #blocks > 1 then
				table.sort(blocks, blockSorters[blockPriority.Value])
			end

			return blocks
		end

		local world = vape.Categories.World

		blockIn = world:CreateModule({
			Name = 'Block-In',
			Function = function(enabled)
				if not enabled then
					return
				end

				blockIn:Toggle()

				if not entity.isAlive then
					return
				end

				local lastSlot = (store.hand.tool and getItemSlot(store.hand.tool)) or 0
				local position = entity.character.RootPart.Position
				local wall = buildWallOffsets(position, getBlockAt)

				if #wall > 0 then
					for _, block in getBlocks() do
						local slot = getItemSlot(block[3])

						if slot then
							switchItem(slot)

							for _, offset in wall do
								if entity.isAlive then
									if not getBlockAt(position + offset) then
										task.spawn(bedwars.placeBlock, position + offset, block[1], false)

										local delay = placeDelay:GetRandomValue() / 1000
										if delay > 0 then
											task.wait(delay)
										end
									end
								end
							end
						end
					end
				end

				if lastSlot then
					switchItem(lastSlot)
				end
			end,
			Tooltip = 'Automatically blocks you in by building walls around you'
		})

		placeDelay = blockIn:CreateTwoSlider({
			Name = 'Place delay',
			Min = 1,
			Max = 250,
			DefaultMin = 30,
			DefaultMax = 50
		})

		blockPriority = blockIn:CreateDropdown({
			Name = 'Block priority',
			List = {'Lowest cost', 'Hardest'},
			Default = 'Lowest cost'
		})

		returnToLastSlot = blockIn:CreateToggle({
			Name = 'Return to last slot',
			Default = false
		})

		woolOnly = blockIn:CreateToggle({
			Name = 'Wool only'
		})

		blacklist = blockIn:CreateTextList({
			Name = 'Blacklist',
			Default = {'cannon', 'siege_tnt', 'tnt'}
		})
	end

	-- DaveyAim
	do
		local daveyAim
		local searchRange
		local aimMode
		local launchCannon

		local raycastParams = RaycastParams.new()
		raycastParams.RespectCanCollide = false

		local minigames = vape.Categories.Minigames

		daveyAim = minigames:CreateModule({
			Name = 'DaveyAim',
			Function = function(enabled)
				if not enabled then
					return
				end

				daveyAim:Toggle()

				if not entity.isAlive then
					return
				end

				local unitRay = cloneref(lplr:GetMouse()).UnitRay
				raycastParams.FilterDescendantsInstances = {lplr.Character, currentCamera}

				local hit = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000000, raycastParams)
				local aimPosition
				if hit then
					aimPosition = hit.Position
				end
				if not aimPosition then
					return
				end

				local searchDistance = math.huge

				for _, block in store.blocks do
					local rootPosition = entity.character.RootPart.Position
					local distance = (rootPosition - block.Position).Magnitude

					if block.Name ~= 'cannon' or not (distance < searchDistance) then
						continue
					end

					searchDistance = distance

					local cannonBlockPos = bedwars.BlockController:getBlockPosition(block.Position)

					if aimMode.Value ~= 'Legit' then
						local aimRemote = bedwars.Client:Get('AimCannonw')
						aimRemote:SendToServer({
							cannonBlockPos = cannonBlockPos,
							lookVector = CFrame.lookAt(block.Position, aimPosition).LookVector * 200
						})

						task.wait(0.5)

						if launchCannon.Enabled then
							bedwars.CannonHandController:launchSelf(block)
						end
					else
						block.AimPrompt:InputHoldBegin()
						task.wait(block.AimPrompt.HoldDuration)

						local finishTime = tick() + 0.3
						repeat
							local cameraCFrame = currentCamera.CFrame
							local aimCFrame = CFrame.lookAt(currentCamera.CFrame.p, aimPosition)
							local step = RunService.PostSimulation:Wait()
							currentCamera.CFrame = cameraCFrame:Lerp(aimCFrame, 22 * step)

							local aimRemote = bedwars.Client:Get('AimCannon')
							aimRemote:SendToServer({
								cannonBlockPos = cannonBlockPos,
								lookVector = currentCamera.CFrame.LookVector
							})
						until finishTime < tick()

						block.StopAimingPrompt:InputHoldBegin()
						task.wait(block.StopAimingPrompt.HoldDuration + RunService.PostSimulation:Wait())

						if launchCannon.Enabled then
							block.LaunchSelfPrompt:InputHoldBegin()
							task.wait(block.LaunchSelfPrompt.HoldDuration + RunService.PostSimulation:Wait())
						end
					end

					return
				end
			end,
			Tooltip = 'Automatically aims cannon'
		})

		aimMode = daveyAim:CreateDropdown({
			Name = 'Aim Mode',
			List = {'Fast', 'Legit'},
			Default = 'Fast'
		})

		daveyAim:CreateDropdown({
			Name = 'Position Mode',
			List = {'Mouse', 'Camera'},
			Default = 'Mouse'
		})

		searchRange = daveyAim:CreateSlider({
			Name = 'Search Range',
			Min = 1,
			Max = 30,
			Default = 10,
			Suffix = function(value)
				return value <= 1 and 'stud' or 'studs'
			end
		})

		launchCannon = daveyAim:CreateToggle({
			Name = 'Launch Cannon',
			Default = false
		})
	end

	-- InfiniteKrystal
	do
		local infiniteKrystal
		local originalUpdateMomentum
		local hookedUpdateMomentum

		local minigames = vape.Categories.Minigames

		infiniteKrystal = minigames:CreateModule({
			Name = 'InfiniteKrystal',
			Tooltip = 'Gives you max momentum forever',
			Function = function(enabled)
				if not enabled then
					if originalUpdateMomentum then
						if bedwars.GlacialSkaterController.updateMomentum == hookedUpdateMomentum then
							bedwars.GlacialSkaterController.updateMomentum = originalUpdateMomentum
						end
					end

					originalUpdateMomentum = nil
					hookedUpdateMomentum = nil
				else
					originalUpdateMomentum = bedwars.GlacialSkaterController.updateMomentum

					hookedUpdateMomentum = function(skater)
						if infiniteKrystal.Enabled then
							skater.momentum = 1000
							skater.lastMomentumReport = workspace:GetServerTimeNow()
						end
					end

					bedwars.GlacialSkaterController.updateMomentum = hookedUpdateMomentum
				end
			end
		})
	end

	-- JadeExtender
	do
		local jadeExtender
		local multiplier
		local originalUseJadeHammer
		local hookedUseJadeHammer
		local jadeHammerController

		local minigames = vape.Categories.Minigames

		local function installHook()
			while true do
				task.wait()
				if bedwars.JadeHammerController then
					break
				end
				if not jadeExtender.Enabled then
					break
				end
			end

			if not jadeExtender.Enabled then
				return
			end
			if not bedwars.JadeHammerController then
				return
			end

			local useJadeHammer = bedwars.JadeHammerController.useJadeHammer
			if typeof(useJadeHammer) ~= 'function' then
				return
			end

			originalUseJadeHammer = useJadeHammer
			jadeHammerController = bedwars.JadeHammerController

			hookedUseJadeHammer = function(controller)
				local canUseAbility = bedwars.AbilityController:canUseAbility('jade_hammer_jump')

				useJadeHammer(controller)

				if jadeExtender.Enabled and canUseAbility then
					if store.equippedKit == 'jade' and entity.isAlive then
						local rootPart = entity.character.RootPart
						local impulse = rootPart.AssemblyMass * (multiplier.Value - 1) * 20.5
						rootPart:ApplyImpulse(Vector3.new(0, impulse, 0))
					end
				end
			end

			jadeHammerController.useJadeHammer = hookedUseJadeHammer
		end

		jadeExtender = minigames:CreateModule({
			Name = 'JadeExtender',
			Function = function(enabled)
				if not enabled then
					if originalUseJadeHammer and jadeHammerController then
						if jadeHammerController.useJadeHammer == hookedUseJadeHammer then
							jadeHammerController.useJadeHammer = originalUseJadeHammer
						end
					end

					originalUseJadeHammer = nil
					hookedUseJadeHammer = nil
					jadeHammerController = nil
				else
					jadeExtender:Clean(task.spawn(installHook))
				end
			end,
			Tooltip = 'Extends how far the Jade Hammer jump launches you'
		})

		multiplier = jadeExtender:CreateSlider({
			Name = 'Multiplier',
			Min = 1,
			Max = 5,
			Default = 2,
			Decimal = 10,
			Suffix = 'x'
		})
	end

	-- PhaseMine
	do
		local phaseMine
		local ignoredParts = {}

		local function ignoreCharacter(character)
			for _, part in character:QueryDescendants('BasePart') do
				table.insert(ignoredParts, part)
				bedwars.QueryUtil:setQueryIgnored(part, false)
			end

			phaseMine:Clean(character.ChildAdded:Connect(function(child)
				if child:IsA('BasePart') then
					table.insert(ignoredParts, child)
					bedwars.QueryUtil:setQueryIgnored(child, false)
				end
			end))
		end

		local minigames = vape.Categories.Minigames

		phaseMine = minigames:CreateModule({
			Name = 'PhaseMine',
			Function = function(enabled)
				if not enabled then
					for _, part in ignoredParts do
						if part and part.Parent then
							bedwars.QueryUtil:setQueryIgnored(part, false)
						end
					end

					table.clear(ignoredParts)
				else
					phaseMine:Clean(entity.Events.EntityAdded:Connect(function(newEntity)
						if newEntity.Player then
							task.delay(1, ignoreCharacter, newEntity.Character)
						end
					end))

					for _, listedEntity in entity.List do
						if listedEntity.Character then
							ignoreCharacter(listedEntity.Character)
						end
					end
				end
			end,
			Tooltip = 'Allows you to mine through opponents'
		})
	end

	-- VoidRegentExtender
	do
		local voidRegentExtender
		local multiplier
		local originalUseVoidAxe
		local hookedUseVoidAxe
		local voidAxeController

		local minigames = vape.Categories.Minigames

		local function installHook()
			while true do
				task.wait()
				if bedwars.VoidAxeController then
					break
				end
				if not voidRegentExtender.Enabled then
					break
				end
			end

			if not voidRegentExtender.Enabled then
				return
			end
			if not bedwars.VoidAxeController then
				return
			end

			local useVoidAxe = bedwars.VoidAxeController.useVoidAxe
			if typeof(useVoidAxe) ~= 'function' then
				return
			end

			originalUseVoidAxe = useVoidAxe
			voidAxeController = bedwars.VoidAxeController

			hookedUseVoidAxe = function(controller)
				local canUseAbility = bedwars.AbilityController:canUseAbility('void_axe_jump')

				useVoidAxe(controller)

				if voidRegentExtender.Enabled then
					if canUseAbility and store.equippedKit == 'regent' and entity.isAlive then
						local rootPart = entity.character.RootPart
						local direction = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local impulse = direction * rootPart.AssemblyMass * (multiplier.Value - 1)
						rootPart:ApplyImpulse(impulse * 70)
					end
				end
			end

			voidAxeController.useVoidAxe = hookedUseVoidAxe
		end

		voidRegentExtender = minigames:CreateModule({
			Name = 'VoidRegentExtender',
			Function = function(enabled)
				if not enabled then
					if originalUseVoidAxe and voidAxeController and voidAxeController.useVoidAxe == hookedUseVoidAxe then
						voidAxeController.useVoidAxe = originalUseVoidAxe
					end

					originalUseVoidAxe = nil
					hookedUseVoidAxe = nil
					voidAxeController = nil
				else
					voidRegentExtender:Clean(task.spawn(installHook))
				end
			end,
			Tooltip = 'Extends how far the Void Regent axe dash launches you'
		})

		multiplier = voidRegentExtender:CreateSlider({
			Name = 'Multiplier',
			Min = 1,
			Max = 5,
			Default = 2,
			Decimal = 10,
			Suffix = 'x'
		})
	end

	-- VulcanAssist
	do
		local vulcanAssist
		local targets
		local range
		local targetMode

		local minigames = vape.Categories.Minigames

		vulcanAssist = minigames:CreateModule({
			Name = 'VulcanAssist',
			Function = function(enabled)
				if not enabled then
					return
				end

				repeat
					if entity.isAlive then
						local selectedTurret = bedwars.Store:getState().Game.selectedTurret

						if selectedTurret then
							local origin = selectedTurret.Rotate.Position

							local target = entity.EntityMouse({
								Range = range.Value,
								Origin = origin,
								Wallcheck = targets.Walls.Enabled or nil,
								Part = 'RootPart',
								Players = targets.Players.Enabled,
								NPCs = targets.NPCs.Enabled,
								Sort = targetSorts[targetMode.Value]
							})

							if target then
								local airborne = target.Humanoid.FloorMaterial == Enum.Material.Air
								if not airborne then
									airborne = math.abs(target.RootPart.AssemblyLinearVelocity.Y) > 0.01
								end

								local solved = prediction.SolveTrajectory(
									origin,
									320,
									10,
									target.RootPart.Position,
									target.RootPart.AssemblyLinearVelocity,
									workspace.Gravity,
									target.HipHeight,
									nil,
									store.airRay,
									airborne,
									target.RootPart.Position,
									target.RootPart
								)

								if solved then
									local offset = solved - origin

									bedwars.TurretCameraController.angleX = math.atan2(-offset.X, -offset.Z)

									local flat = math.sqrt(offset.X ^ 2 + offset.Z ^ 2)
									bedwars.TurretCameraController.angleY = math.clamp(math.atan2(offset.Y, flat), -0.8, 0.8)
								end
							end
						end
					end

					task.wait(0.1)
				until not vulcanAssist.Enabled
			end,
			Tooltip = 'Automatically aims turret camera toward opponents'
		})

		targets = vulcanAssist:CreateTargets({
			Walls = false,
			Players = false
		})

		local sortModes = {'Distance', 'Damage'}
		for sortName in targetSorts do
			if not table.find(sortModes, sortName) then
				table.insert(sortModes, sortName)
			end
		end

		targetMode = vulcanAssist:CreateDropdown({
			Name = 'Target mode',
			List = sortModes,
			Default = sortModes[1]
		})

		range = vulcanAssist:CreateSlider({
			Name = 'Range',
			Min = 1,
			Max = 1000,
			Default = 500
		})
	end

	-- CatExtender
	do
		local catExtender
		local multiplier
		local originalLeap
		local hookedLeap
		local catController

		local minigames = vape.Categories.Minigames

		local function installHook()
			while true do
				task.wait()
				if bedwars.CatController then
					break
				end
				if not catExtender.Enabled then
					break
				end
			end

			if not catExtender.Enabled then
				return
			end
			if not bedwars.CatController then
				return
			end

			local leap = bedwars.CatController.leap
			if typeof(leap) ~= 'function' then
				return
			end

			originalLeap = leap
			catController = bedwars.CatController

			hookedLeap = function(controller, character, direction)
				leap(controller, character, direction)

				if catExtender.Enabled and store.equippedKit == 'cat' then
					if typeof(direction) == 'Vector3' and 0 < direction.Magnitude then
						local rootPart = character:FindFirstChild('HumanoidRootPart')

						if rootPart then
							local flatDirection = direction * Vector3.new(1, 0, 1)

							if 0 < flatDirection.Magnitude then
								local impulse = flatDirection.Unit * rootPart.AssemblyMass * (multiplier.Value - 1)
								rootPart:ApplyImpulse(impulse * 70)
							end
						end
					end
				end
			end

			catController.leap = hookedLeap
		end

		catExtender = minigames:CreateModule({
			Name = 'CatExtender',
			Function = function(enabled)
				if not enabled then
					if originalLeap and catController then
						if catController.leap == hookedLeap then
							catController.leap = originalLeap
						end
					end

					originalLeap = nil
					hookedLeap = nil
					catController = nil
					return
				end

				catExtender:Clean(task.spawn(installHook))
			end,
			Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
		})

		multiplier = catExtender:CreateSlider({
			Name = 'Multiplier',
			Min = 1,
			Max = 5,
			Default = 2,
			Decimal = 10,
			Suffix = 'x'
		})
	end

	-- YuziExtender
	do
		local yuziExtender
		local multiplier
		local originalDashForward
		local hookedDashForward
		local daoController

		local minigames = vape.Categories.Minigames

		local function installHook()
			while true do
				task.wait()
				if bedwars.DaoController then
					break
				end
				if not yuziExtender.Enabled then
					break
				end
			end

			if not yuziExtender.Enabled then
				return
			end
			if not bedwars.DaoController then
				return
			end

			local dashForward = bedwars.DaoController.dashForward
			if typeof(dashForward) ~= 'function' then
				return
			end

			originalDashForward = dashForward
			daoController = bedwars.DaoController

			hookedDashForward = function(controller, direction)
				dashForward(controller, direction)

				if yuziExtender.Enabled and store.equippedKit == 'dasher' and entity.isAlive then
					if typeof(direction) == 'Vector3' then
						local rootPart = entity.character.RootPart
						local flatDirection = direction * Vector3.new(1, 0, 1)

						if 0 < flatDirection.Magnitude then
							local impulse = flatDirection.Unit * rootPart.AssemblyMass * (multiplier.Value - 1)
							rootPart:ApplyImpulse(impulse * 70)
						end
					end
				end
			end

			daoController.dashForward = hookedDashForward
		end

		yuziExtender = minigames:CreateModule({
			Name = 'YuziExtender',
			Function = function(enabled)
				if not enabled then
					if originalDashForward and daoController and daoController.dashForward == hookedDashForward then
						daoController.dashForward = originalDashForward
					end

					originalDashForward = nil
					hookedDashForward = nil
					daoController = nil
				else
					yuziExtender:Clean(task.spawn(installHook))
				end
			end,
			Tooltip = 'Extends how far the yuzi dash launches you.'
		})

	multiplier = yuziExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end
end)

local function isGUIOpen()
	if not vape or not vape.Categories or not vape.Categories.Main then return false end
	local main = vape.Categories.Main
	return main.Visible or (main.Options and main.Options['GUI bind indicator'] and main.Options['GUI bind indicator'].Enabled)
end

local function isFirstPerson()
	local char = entitylib.character
	if not char or not char.PrimaryPart or not currentCamera then return false end
	local head = char:FindFirstChild('Head')
	if not head then return false end
	local dist = (currentCamera.CFrame.Position - head.Position).Magnitude
	return dist < 4
end

local function cloneRaycast()
	return RaycastParams.new()
end

local function setupProjectileAimbot()
    local TargetPart
    local Targets
    local FOV
    local Range
    local OtherProjectiles
    local Blacklist
    local SortMethod
    local UnrealPAChargePercent
    local RandomHeadPercent
    local RandomTorsoPercent
    local CustomPrediction
    local HorizontalMultiplier
    local VerticalMultiplier
    local UnrealPAWorkMode
    local UnrealPAHideCursor
    local UnrealPACursorViewMode
    local UnrealPACursorLimitBow
    local UnrealPACursorShowGUI
    local cursorRenderConnection
    local lastGUIState = false
    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    local old
    local math_sqrt = math.sqrt
    local math_rad = math.rad
    local math_cos = math.cos
    local math_clamp = math.clamp
    local math_min = math.min
    local math_max = math.max
    local lockedRandomPart = nil
    local wasHovering = false
    local PAFOVCircle
    local ProjectileAimbot
    local paFOVCircleDrawing = nil
    local AutoCharge
    local paFOVCircleConnection = nil
    local function runPAFOVCircle(call)
        if paFOVCircleConnection then
            paFOVCircleConnection:Disconnect()
            paFOVCircleConnection = nil
        end
        if paFOVCircleDrawing then
            paFOVCircleDrawing:Remove()
            paFOVCircleDrawing = nil
        end
        if call then
            paFOVCircleDrawing = Drawing.new('Circle')
            paFOVCircleDrawing.Visible = false
            paFOVCircleDrawing.Thickness = 1
            paFOVCircleDrawing.Color = Color3.fromRGB(255, 255, 255)
            paFOVCircleDrawing.Filled = false
            paFOVCircleDrawing.NumSides = 64
            paFOVCircleConnection = runService.RenderStepped:Connect(function()
                if paFOVCircleDrawing and FOV and FOV.Value then
                    local shouldShow = false
                    if PAFOVCircle and PAFOVCircle.Enabled and ProjectileAimbot and ProjectileAimbot.Enabled then
                        local tool = store.hand and store.hand.tool
                        local itemType = tool and tool.Name or ""
                        local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
                        if itemMeta and itemMeta.projectileSource then
                            local src = itemMeta.projectileSource
                            local isArrow = src.ammoItemTypes and table.find(src.ammoItemTypes, 'arrow')
                            local isHeadhunter = itemType:find('headhunter')
                            if isArrow or isHeadhunter then
                                shouldShow = true
                            elseif OtherProjectiles and OtherProjectiles.Enabled then
                                local projectileType = src.projectileType and (type(src.projectileType) == 'function' and src.projectileType('arrow') or src.projectileType) or ""
                                local blacklisted = false
                                for _, black in ipairs(Blacklist and Blacklist.ListEnabled or {}) do
                                    if tostring(projectileType):find(black) then
                                        blacklisted = true
                                        break
                                    end
                                end
                                if not blacklisted then
                                    shouldShow = true
                                end
                            end
                        end
                    end
                    paFOVCircleDrawing.Visible = shouldShow
                    local mousePos = inputService:GetMouseLocation()
                    paFOVCircleDrawing.Position = Vector2.new(mousePos.X, mousePos.Y)
                    paFOVCircleDrawing.Radius = FOV.Value
                end
            end)
        end
    end

    local function hasBowEquipped()
        if not store.hand or not store.hand.toolType then return false end
        return store.hand.toolType == 'bow' or store.hand.toolType == 'crossbow'
    end

    local function shouldHideCursor()
        if not UnrealPAHideCursor or not UnrealPAHideCursor.Enabled then return false end
        if UnrealPACursorShowGUI and UnrealPACursorShowGUI.Enabled and isGUIOpen() then return false end
        if UnrealPACursorLimitBow and UnrealPACursorLimitBow.Enabled and not hasBowEquipped() then return false end
        local inFirstPerson = isFirstPerson()
        if UnrealPACursorViewMode then
            if UnrealPACursorViewMode.Value == 'First Person' then return inFirstPerson
            elseif UnrealPACursorViewMode.Value == 'Third Person' then return not inFirstPerson
            end
        end
        return true
    end

    local function updateCursor()
        pcall(function() inputService.MouseIconEnabled = not shouldHideCursor() end)
    end

    local function checkGUIState()
        local currentGUIState = isGUIOpen()
        if lastGUIState ~= currentGUIState then
            updateCursor()
            lastGUIState = currentGUIState
        end
    end

    local function shouldPAWork()
        if not UnrealPAWorkMode then return true end
        local inFirstPerson = isFirstPerson()
        if UnrealPAWorkMode.Value == 'First Person' then return inFirstPerson
        elseif UnrealPAWorkMode.Value == 'Third Person' then return not inFirstPerson
        end
        return true
    end

    local function isBlacklisted(projectileName)
        if not OtherProjectiles.Enabled then
            local isTurret = projectileName:find('turret') ~= nil or projectileName:find('vulcan') ~= nil
            return not projectileName:find('arrow') and not isTurret
        end
        for _, black in ipairs(Blacklist.ListEnabled) do
            if projectileName:find(black) then
                return true
            end
        end
        return false
    end

    local function getValidTargets(originPos, maxDist, maxAngle, sortMethod)
        local valid = {}
        local fovThreshold = math_cos(math_rad(maxAngle) / 2)
        local rangeSq = maxDist * maxDist

        for _, ent in ipairs(entitylib.List) do
            if not Targets.Players.Enabled and ent.Player then continue end
            if (not Targets.NPCs or not Targets.NPCs.Enabled) and ent.NPC then continue end
            if not ent.Targetable then continue end
            if not ent.Character or not ent.RootPart or not ent.RootPart.Parent then continue end

            local delta = ent.RootPart.Position - originPos
            local distSq = delta.X*delta.X + delta.Y*delta.Y + delta.Z*delta.Z
            if distSq > rangeSq then continue end

            if maxAngle < 360 then
                local facing = gameCamera.CFrame.LookVector
                if delta.Magnitude > 0.001 then
                    local dot = facing:Dot(delta.Unit)
                    if dot < fovThreshold then continue end
                end
            end

            if Targets.Walls.Enabled then
                local ray = workspace:Raycast(originPos, delta, rayCheck)
                if ray then continue end
            end

            if sortMethod == "Cursor" then
                local mousePos = inputService:GetMouseLocation()
                local screenPos, onScreen = gameCamera:WorldToScreenPoint(ent.RootPart.Position)
                if not onScreen then continue end
                local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if screenDist > FOV.Value then continue end
            end

            table.insert(valid, {Entity = ent})
        end

        if #valid == 0 then return {} end

        local sortFunc = sortmethods[sortMethod] or sortmethods.Distance
        table.sort(valid, sortFunc)
        local unwrapped = {}
        for _, v in ipairs(valid) do
            table.insert(unwrapped, v.Entity)
        end
        return unwrapped
    end

    local function pickRandomPart(character)
        local roll = math.random(1, 100)
        if roll <= RandomHeadPercent.Value then
            return character:FindFirstChild('Head') or character:FindFirstChild('HumanoidRootPart')
        else
            return character:FindFirstChild('HumanoidRootPart')
        end
    end

    local function getClosestPart(character, mousePos)
        local parts = {
            'HumanoidRootPart', 'Head', 'LeftHand', 'RightHand',
            'LeftLowerArm', 'RightLowerArm', 'LeftUpperArm', 'RightUpperArm',
            'LeftFoot', 'RightFoot', 'LeftLowerLeg', 'RightLowerLeg',
            'LeftUpperLeg', 'RightUpperLeg', 'LowerTorso', 'UpperTorso'
        }
        local camera = gameCamera
        local rayOrigin = camera.CFrame.Position
        local rayDir = camera:ScreenPointToRay(mousePos.X, mousePos.Y, 0).Direction
        local bestAngle = math.huge
        local bestPart = nil

        for _, partName in ipairs(parts) do
            local part = character:FindFirstChild(partName)
            if part then
                local dirToPart = (part.Position - rayOrigin).Unit
                local angle = math.acos(math_clamp(rayDir:Dot(dirToPart), -1, 1))
                if angle < bestAngle then
                    bestAngle = angle
                    bestPart = part
                end
            end
        end
        return bestPart or character:FindFirstChild('HumanoidRootPart')
    end

    ProjectileAimbot = vape.Categories.Blatant:CreateModule({
        Name = 'ProjectileAimbot',
        Function = function(callback)
            if callback then
                    if PAFOVCircle then
                        runPAFOVCircle(PAFOVCircle.Enabled)
                    end
                    if UnrealPAHideCursor and UnrealPAHideCursor.Enabled and not cursorRenderConnection then
                        cursorRenderConnection = runService.RenderStepped:Connect(function()
                            checkGUIState()
                            updateCursor()
                        end)
                    end

                    old = bedwars.ProjectileController.calculateImportantLaunchValues
                    bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
                    local self, projmeta, worldmeta, origin, shootpos = ...
                    local originPos = entitylib.isAlive and (shootpos or (entitylib.character and entitylib.character.RootPart and entitylib.character.RootPart.Position)) or Vector3.zero
                    if not wasHovering then lockedRandomPart = nil end
                    wasHovering = true
                    local entityPart = (TargetPart.Value == 'Head') and 'Head' or 'RootPart'
                    local plr = entitylib.EntityMouse({
                        Part = entityPart,
                        Range = FOV.Value,
                        Players = Targets.Players.Enabled,
                        NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
                        Wallcheck = Targets.Walls.Enabled,
                        Origin = originPos
                    })

                    if not plr then
                        wasHovering = false
                        local s, r = pcall(old, ...)
                        return s and r or nil
                    end

                    if not shouldPAWork() then
                        wasHovering = false
                        return old(...)
                    end

                    local targetBodyPart = nil
                    if TargetPart.Value == 'Dynamic' then
                        local tool = store.hand and store.hand.tool
                        local itemType = tostring(tool and tool.Name or ""):lower()
                        local isHH = itemType:find("headhunter")
                        targetBodyPart = isHH and (plr.Character:FindFirstChild("Head") or plr.RootPart) or plr.RootPart
                    elseif TargetPart.Value == 'RootPart' then
                        targetBodyPart = plr.RootPart
                    elseif TargetPart.Value == 'Head' then
                        targetBodyPart = plr.Head or plr.RootPart
                    elseif TargetPart.Value == 'Closest' then
                        local mousePos = inputService:GetMouseLocation()
                        targetBodyPart = getClosestPart(plr.Character, mousePos)
                    elseif TargetPart.Value == 'Randomize' then
                        if not lockedRandomPart or not lockedRandomPart.Parent then
                            lockedRandomPart = pickRandomPart(plr.Character)
                        end
                        targetBodyPart = lockedRandomPart
                    else
                        targetBodyPart = plr.RootPart
                    end

                    if not targetBodyPart then
                        wasHovering = false
                        return old(...)
                    end

                    local dist = (targetBodyPart.Position - originPos).Magnitude
                    if dist > Range.Value then
                        wasHovering = false
                        return old(...)
                    end

                    local pos = shootpos or self:getLaunchPosition(origin)
                    if not pos then
                        wasHovering = false
                        return old(...)
                    end

                    local projectileName = projmeta.projectile or ""
                    if isBlacklisted(projectileName) then
                        wasHovering = false
                        return old(...)
                    end

                    local meta = projmeta:getProjectileMeta()
                    local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
                    local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
                    local projSpeed = (meta.launchVelocity or 100)
                    local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
                    local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
                    local playerGravity = workspace.Gravity
                    if balloons and balloons > 0 then
                        playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
                    end
                    if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
                        playerGravity = 6
                    end
                    if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
                        for _, owl in ipairs(collectionService:GetTagged('Owl')) do
                            if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
                                playerGravity = 0
                                break
                            end
                        end
                    end

                    local targetVelocity = targetBodyPart.Velocity
                    if CustomPrediction and CustomPrediction.Enabled then
                        local hMult = (HorizontalMultiplier and HorizontalMultiplier.Value or 100) / 100
                        local vMult = (VerticalMultiplier and VerticalMultiplier.Value or 100) / 100
                        targetVelocity = Vector3.new(
                            targetVelocity.X * hMult,
                            targetVelocity.Y * vMult,
                            targetVelocity.Z * hMult
                        )
                    end
                    local bowRelX = bedwars.BowConstantsTable.RelX or 0
                    local bowRelY = bedwars.BowConstantsTable.RelY or 0
                    local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
                    local newlook = CFrame.new(offsetpos, targetBodyPart.Position) *
                        CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or
                            Vector3.new(bowRelX, bowRelY, bowRelZ))

                    local calc = prediction.SolveTrajectory(
                        newlook.p, projSpeed, gravity,
                        targetBodyPart.Position,
                        projmeta.projectile == 'telepearl' and Vector3.zero or targetVelocity,
                        playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck
                    )

                    if calc then
                        if targetinfo and targetinfo.Targets then
                            targetinfo.Targets[plr] = tick() + 1
                        end

                        local customDrawDuration = 5
                        if AutoCharge.Enabled then
                            if projmeta.projectile:find('arrow') then
                                customDrawDuration = 0.58 * (UnrealPAChargePercent.Value / 100)
                            elseif projmeta.projectile:find('frosty_snowball') then
                                local tool = store.hand and store.hand.tool
                                if tool and tool.Name:find('frost_staff') then
                                    local cd = (tool.Name:find('frost_staff_3') and 0.16) or
                                            (tool.Name:find('frost_staff_2') and 0.18) or 0.2
                                    customDrawDuration = cd * (UnrealPAChargePercent.Value / 100)
                                end
                            end
                        else
                                customDrawDuration = 0.05
                        end

                        wasHovering = false
                        return {
                            initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
                            positionFrom = offsetpos,
                            deltaT = lifetime,
                            gravitationalAcceleration = gravity,
                            drawDurationSeconds = customDrawDuration
                        }
                    end

                    wasHovering = false
                    return old(...)
                end
            else
                bedwars.ProjectileController.calculateImportantLaunchValues = old
                wasHovering = false
                lockedRandomPart = nil
                if cursorRenderConnection then
                    cursorRenderConnection:Disconnect()
                    cursorRenderConnection = nil
                end
                runPAFOVCircle(false)
                pcall(function() inputService.MouseIconEnabled = true end)
                task.defer(function()
                    pcall(function() inputService.MouseIconEnabled = true end)
                    pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
                end)
            end
        end,
        Tooltip = 'Silently adjusts your aim towards the enemy'
    })

    Targets = ProjectileAimbot:CreateTargets({
        Players = true,
        NPCs = true,
        Walls = true
    })

    local function updateRandomizeVisibility()
        local vis = (TargetPart.Value == 'Randomize')
        RandomHeadPercent.Object.Visible = vis
        RandomTorsoPercent.Object.Visible = vis
    end

    TargetPart = ProjectileAimbot:CreateDropdown({
        Name = 'Part',
        List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
        Default = 'RootPart',
        Tooltip = 'Select which body part to aim at',
        Function = function()
            lockedRandomPart = nil
            wasHovering = false
            updateRandomizeVisibility()
        end
    })

    SortMethod = ProjectileAimbot:CreateDropdown({
        Name = 'Sort Method',
        List = {'Distance', 'Damage', 'Threat', 'Kit', 'Health', 'Angle', 'Cursor', 'Forest'},
        Default = 'Distance',
        Tooltip = 'Prioritize targets when multiple are in range'
    })

    UnrealPAWorkMode = ProjectileAimbot:CreateDropdown({
        Name = 'PA Work Mode',
        List = {'First Person', 'Third Person', 'Both'},
        Default = 'Both',
        Tooltip = 'Which perspective the aimbot works in'
    })

    Range = ProjectileAimbot:CreateSlider({
        Name = 'Range',
        Min = 10,
        Max = 500,
        Default = 100,
        Tooltip = 'Maximum distance (in studs) for targeting'
    })



    FOV = ProjectileAimbot:CreateSlider({
        Name = 'FOV',
        Min = 1,
        Max = 1000,
        Default = 1000
    })

    PAFOVCircle = ProjectileAimbot:CreateToggle({
        Name = 'FOV Circle',
        Tooltip = 'Shows a circle representing your FOV on screen',
        Function = function(call)
            runPAFOVCircle(call)
        end
    })

    RandomHeadPercent = ProjectileAimbot:CreateSlider({
        Name = 'Head Chance',
        Min = 0,
        Max = 100,
        Default = 50,
        Darker = true,
        Tooltip = 'Chance to aim at head when Part is set to Randomize',
        Visible = false
    })

    RandomTorsoPercent = ProjectileAimbot:CreateSlider({
        Name = 'Torso Chance',
        Min = 0,
        Max = 100,
        Default = 50,
        Darker = true,
        Tooltip = 'Chance to aim at torso when Part is set to Randomize',
        Visible = false
    })

    updateRandomizeVisibility()

    UnrealPAHideCursor = ProjectileAimbot:CreateToggle({
        Name = 'Hide Cursor',
        Default = false,
        Tooltip = 'Hides the cursor while aiming',
        Function = function(callback)
            if UnrealPACursorViewMode then UnrealPACursorViewMode.Object.Visible = callback end
            if UnrealPACursorLimitBow then UnrealPACursorLimitBow.Object.Visible = callback end
            if UnrealPACursorShowGUI then UnrealPACursorShowGUI.Object.Visible = callback end
            if callback and ProjectileAimbot.Enabled then
                if not cursorRenderConnection then
                    cursorRenderConnection = runService.RenderStepped:Connect(function()
                        checkGUIState()
                        updateCursor()
                    end)
                end
                updateCursor()
            else
                if cursorRenderConnection then
                    cursorRenderConnection:Disconnect()
                    cursorRenderConnection = nil
                end
                pcall(function() inputService.MouseIconEnabled = true end)
                task.defer(function()
                    pcall(function() inputService.MouseIconEnabled = true end)
                    pcall(function() game:GetService('UserInputService').MouseIconEnabled = true end)
                end)
            end
        end
    })

    UnrealPACursorViewMode = ProjectileAimbot:CreateDropdown({
        Name = 'Cursor View Mode',
        List = {'First Person', 'Third Person', 'Both'},
        Default = 'First Person',
        Darker = true,
        Visible = false,
        Function = function()
            if ProjectileAimbot.Enabled and UnrealPAHideCursor.Enabled then
                updateCursor()
            end
        end
    })

    UnrealPACursorLimitBow = ProjectileAimbot:CreateToggle({
        Name = 'Limit to Bow',
        Darker = true,
        Visible = false,
        Tooltip = 'Only hides cursor when bow/crossbow is equipped',
        Function = function()
            if ProjectileAimbot.Enabled and UnrealPAHideCursor.Enabled then
                updateCursor()
            end
        end
    })

    UnrealPACursorShowGUI = ProjectileAimbot:CreateToggle({
        Name = 'Show on GUI',
        Darker = true,
        Visible = false,
        Tooltip = 'Shows cursor when a GUI is open',
        Function = function()
            if ProjectileAimbot.Enabled and UnrealPAHideCursor.Enabled then
                updateCursor()
            end
        end
    })

    CustomPrediction = ProjectileAimbot:CreateToggle({
        Name = 'Custom Prediction',
        Default = false,
        Tooltip = 'Enable to customize horizontal/vertical prediction multipliers',
        Function = function()
            if HorizontalMultiplier then
                HorizontalMultiplier.Object.Visible = CustomPrediction.Enabled
            end
            if VerticalMultiplier then
                VerticalMultiplier.Object.Visible = CustomPrediction.Enabled
            end
        end
    })

    HorizontalMultiplier = ProjectileAimbot:CreateSlider({
        Name = 'Horizontal Multiplier',
        Min = 0,
        Max = 200,
        Default = 100,
        Suffix = '%',
        Darker = true,
        Visible = false,
        Tooltip = 'Adjust horizontal prediction strength (0% = none, 100% = normal, 200% = double)'
    })

    VerticalMultiplier = ProjectileAimbot:CreateSlider({
        Name = 'Vertical Multiplier',
        Min = 0,
        Max = 200,
        Default = 100,
        Suffix = '%',
        Darker = true,
        Visible = false,
        Tooltip = 'Adjust vertical prediction strength (0% = none, 100% = normal, 200% = double)'
    })

    OtherProjectiles = ProjectileAimbot:CreateToggle({
        Name = 'Other Projectiles',
        Default = true,
        Function = function(call)
            if Blacklist then Blacklist.Object.Visible = call end
        end
    })

    Blacklist = ProjectileAimbot:CreateTextList({
        Name = 'Blacklist',
        Darker = true,
        Default = {'telepearl'},
        Visible = OtherProjectiles.Enabled
    })

    AutoCharge = ProjectileAimbot:CreateToggle({
        Name = "AutoCharge",
        Default = true,
        Function = function(v)
            if UnrealPAChargePercent and UnrealPAChargePercent.Object then UnrealPAChargePercent.Object.Visible = v end
        end
    })
    UnrealPAChargePercent = ProjectileAimbot:CreateSlider({
        Name = 'Charge Percent',
        Min = 1,
        Max = 100,
        Default = 100,
        Tooltip = 'Bow/frost staff charge percentage (affects damage)'
    })
end

setupProjectileAimbot()



