-- extra modules for Bedwars (6872274481)

local vape = shared.vape
if not vape or (vape.Place or game.PlaceId) ~= 6872274481 then
	return
end

task.spawn(function()
	while not (shared.bedwars and shared.store and shared.remotes and shared.vapeEvents) do
		task.wait(0.1)
	end

	local bedwars = shared.bedwars
	local store = shared.store
	local remotes = shared.remotes
	local vapeEvents = shared.vapeEvents

	if not (bedwars and store and remotes and vapeEvents) then
		return
	end

	while not (store.blocks and vapeEvents.EntityDamageEvent and vapeEvents.InventoryChanged) do
		task.wait(0.1)
	end

	local Players = cloneref(game:GetService('Players'))
	local RunService = cloneref(game:GetService('RunService'))
	local UserInputService = cloneref(game:GetService('UserInputService'))
	local TweenService = cloneref(game:GetService('TweenService'))
	local CollectionService = cloneref(game:GetService('CollectionService'))

	local lplr = Players.LocalPlayer
	local currentCamera = workspace.CurrentCamera

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
		return bedwars.BlockController:getStore():getBlockAt(grid)
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
		while true do
			local ok, ping = pcall(function()
				return lplr:GetNetworkPing() / 1000
			end)
			if ok then
				store.ping.total = ping
				store.ping.incoming = ping
			end
			store.airRay.FilterDescendantsInstances = {lplr.Character}
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
	local targetAdornment = Instance.new('BoxHandleAdornment')
	targetAdornment.Adornee = nil
	targetAdornment.AlwaysOnTop = false
	targetAdornment.Size = Vector3.new(3, 5, 3)
	targetAdornment.CFrame = CFrame.new(0, -0.5, 0)
	targetAdornment.ZIndex = 0
	targetAdornment.Parent = vape.gui

	local function getAuraWeapon()
		if not entity.isAlive then
			return
		end

		if mouseDownToggle.Enabled and not UserInputService:IsMouseButtonPressed(0) and 0.3 < tick() - bedwars.SwordController.lastSwing then
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

		local mouseLocation = UserInputService:GetMouseLocation()
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
			targetAdornment.Adornee = nil
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
				targetAdornment.Adornee = nil
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
				targetAdornment.Adornee = (showTargetToggle.Enabled and target and target.RootPart) or nil
				targetAdornment.Transparency = 1 - activeColor.Opacity
				targetAdornment.Color3 = Color3.fromHSV(activeColor.Hue, activeColor.Sat, activeColor.Value)

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

						local aimSource = (UserInputService.KeyboardEnabled and workspace.CurrentCamera) or entity.character.RootPart
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
							if previous then
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
					local player = Players:GetPlayerFromCharacter(damage.fromEntity)
					if player and player ~= lplr then
						if os.clock() - (lastHit[player] or 0) <= 0.28 then
							hits[player] = (hits[player] or 0) + 1

							task.delay(60, function()
								if cheatDetector.Enabled and hits[player] then
									hits[player] = math.max(hits[player] - 1, 0)
								end
							end)

							if hits[player] > 2 then
								notify(
									'CheatDetector',
									damage.fromEntity.Name .. ' may be using killaura (went over 34 hits)',
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
					local player = Players:GetPlayerFromCharacter(damage.fromEntity)
					if player and player ~= lplr then
						local attackerPosition = damage.fromEntity.PrimaryPart.Position
						local victimPosition = damage.entityInstance.PrimaryPart.Position
						local distance = (attackerPosition - victimPosition).Magnitude

						local hand = (store.inventories[player] or {}).hand
						local sword = hand and hand.tool and (bedwars.ItemMeta[hand.tool.Name] or {}).sword or nil
						local range = (sword and sword.attackRange or 14.4) + 4

						if range * (0.99 + store.ping.total) < distance then
							notify(
								'CheatDetector',
								damage.fromEntity.Name .. ' may be using reach (went over 15 studs of range)',
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
