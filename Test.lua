local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Vision_Lime"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

-- ==========================================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ДЛЯ ESP
-- ==========================================
local espStates = {
	Innocent = false,
	Gun = false,
	Marder = false,
	Sheriff = false
}

local espColors = {
	Innocent = Color3.fromRGB(0, 255, 0),
	Gun = Color3.fromRGB(255, 165, 0),
	Marder = Color3.fromRGB(255, 0, 0),
	Sheriff = Color3.fromRGB(0, 100, 255)
}

local activeHighlights = {}

-- ==========================================
-- ПЕРЕМЕННЫЕ ДЛЯ SILENT AIM КРУГА
-- ==========================================
local silentAimCircle = nil          -- сам круг (Frame)
local circleDragging = false         -- перетаскивается ли круг
local dragStart = nil                -- стартовая позиция мыши
local circleEnabled = false          -- включён ли круг в данный момент

-- ==========================================
-- ПЕРЕМЕННЫЕ ДЛЯ ВЫПАВШИХ ПИСТОЛЕТОВ
-- ==========================================
local droppedGuns = {}
local gunCleanupDelay = 30

-- ==========================================
-- ОПРЕДЕЛЕНИЕ РОЛИ ИГРОКА
-- ==========================================
local function GetPlayerRole(player)
	local character = player.Character
	if not character then return "Innocent" end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local toolName = tool.Name:lower()
		if toolName:find("knife") or toolName:find("dagger") then
			return "Marder"
		elseif toolName:find("gun") or toolName:find("revolver") or toolName:find("pistol") then
			return "Sheriff"
		else
			return "Gun"
		end
	end
	
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				local toolName = child.Name:lower()
				if toolName:find("knife") or toolName:find("dagger") then
					return "Marder"
				elseif toolName:find("gun") or toolName:find("revolver") or toolName:find("pistol") then
					return "Sheriff"
				else
					return "Gun"
				end
			end
		end
	end
	
	return "Innocent"
end

-- ==========================================
-- ФУНКЦИЯ ДЛЯ ПОЛУЧЕНИЯ БЛИЖАЙШЕГО MARDER
-- ==========================================
local function GetClosestMarder()
	local localPlayer = game.Players.LocalPlayer
	local localChar = localPlayer.Character
	if not localChar then return nil end
	
	local localRoot = localChar:FindFirstChild("HumanoidRootPart")
	if not localRoot then return nil end
	
	local closest = nil
	local closestDist = math.huge
	
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player ~= localPlayer and GetPlayerRole(player) == "Marder" then
			local char = player.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
				if root then
					local dist = (root.Position - localRoot.Position).Magnitude
					if dist < closestDist and dist < 150 then
						closest = char
						closestDist = dist
					end
				end
			end
		end
	end
	
	return closest
end

-- ==========================================
-- SILENT AIM: НАВЕДЕНИЕ + ВЫСТРЕЛ БЕЗ ДВИЖЕНИЯ КАМЕРЫ (1 КЛИК)
-- ==========================================
local function SilentAimShot()
	local localPlayer = game.Players.LocalPlayer
	local character = localPlayer.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	
	-- Находим ближайшего убийцу
	local targetChar = GetClosestMarder()
	if not targetChar then
		return
	end
	
	-- Цель: торс (HumanoidRootPart или Torso)
	local targetPart = targetChar:FindFirstChild("HumanoidRootPart")
	if not targetPart then
		targetPart = targetChar:FindFirstChild("Torso")
	end
	if not targetPart then return end
	
	-- Сохраняем текущую камеру
	local camera = workspace.CurrentCamera
	local oldCFrame = camera.CFrame
	
	-- Наводим камеру на цель (мгновенно)
	local newCFrame = CFrame.new(camera.CFrame.Position, targetPart.Position)
	camera.CFrame = newCFrame
	
	-- Небольшая задержка, чтобы игра успела обработать поворот камеры
	task.wait(0.05)
	
	-- Эмулируем выстрел: ищем активный инструмент у игрока
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		-- Попытка вызвать событие выстрела (для большинства оружий)
		if tool:FindFirstChild("Activated") then
			tool.Activated:Fire()
		end
		-- Альтернативный способ: нажать левую кнопку мыши через VirtualUser
		local vu = game:GetService("VirtualUser")
		if vu then
			vu:ClickButton1(Vector2.new(0, 0))
		end
	end
	
	-- Возвращаем камеру на место
	task.wait(0.05)
	camera.CFrame = oldCFrame
end

-- ==========================================
-- ФУНКЦИИ ДЛЯ ПЕРЕТАСКИВАЕМОГО КРУГА
-- ==========================================
local function CreateSilentAimCircle()
	-- Если круг уже существует, просто показываем его
	if silentAimCircle and silentAimCircle.Parent then
		silentAimCircle.Visible = true
		return
	end
	
	silentAimCircle = Instance.new("Frame", ScreenGui)
	silentAimCircle.Size = UDim2.new(0, 50, 0, 50)
	silentAimCircle.Position = UDim2.new(0.5, -25, 0.7, -25)
	silentAimCircle.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	silentAimCircle.BackgroundTransparency = 0.3
	silentAimCircle.BorderSizePixel = 0
	silentAimCircle.ZIndex = 10
	
	local circleCorner = Instance.new("UICorner", silentAimCircle)
	circleCorner.CornerRadius = UDim.new(1, 0)
	
	local stroke = Instance.new("UIStroke", silentAimCircle)
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	
	local text = Instance.new("TextLabel", silentAimCircle)
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "🎯"
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextSize = 30
	text.Font = Enum.Font.GothamBold
	
	-- Логика перетаскивания
	local dragStartMousePos = nil
	local dragStartPosition = nil
	
	silentAimCircle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStartMousePos = input.Position
			dragStartPosition = silentAimCircle.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	
	silentAimCircle.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStartMousePos
			local newX = dragStartPosition.X.Scale + (delta.X / screenGui.AbsoluteSize.X)
			local newY = dragStartPosition.Y.Scale + (delta.Y / screenGui.AbsoluteSize.Y)
			silentAimCircle.Position = UDim2.new(newX, 0, newY, 0)
		end
	end)
	
	-- Клик по кругу = выстрел
	silentAimCircle.MouseButton1Click:Connect(function()
		SilentAimShot()
	end)
	
	silentAimCircle.Visible = true
end

local function HideSilentAimCircle()
	if silentAimCircle then
		silentAimCircle.Visible = false
	end
end

local function ToggleSilentAimCircle()
	if not circleEnabled then
		CreateSilentAimCircle()
		circleEnabled = true
	else
		HideSilentAimCircle()
		circleEnabled = false
	end
end

-- ==========================================
-- ФУНКЦИИ ДЛЯ ВЫПАВШЕГО ПИСТОЛЕТА
-- ==========================================
local function RemoveDroppedGun(gun)
	local highlight = droppedGuns[gun]
	if highlight then highlight:Destroy() end
	gun:Destroy()
	droppedGuns[gun] = nil
end

local function SpawnSheriffGun(position)
	local gun = Instance.new("Part")
	gun.Size = Vector3.new(1, 0.5, 0.2)
	gun.Shape = Enum.PartType.Block
	gun.BrickColor = BrickColor.new("Dark stone grey")
	gun.Material = Enum.Material.SmoothPlastic
	gun.Position = position + Vector3.new(0, 1, 0)
	gun.Anchored = false
	gun.CanCollide = true
	gun.Name = "SheriffGun"
	
	local pointLight = Instance.new("PointLight", gun)
	pointLight.Color = Color3.fromRGB(255, 200, 100)
	pointLight.Range = 8
	pointLight.Brightness = 1.5
	
	local barrel = Instance.new("Part", gun)
	barrel.Size = Vector3.new(0.3, 0.3, 0.8)
	barrel.Position = Vector3.new(0, 0, 0.5)
	barrel.BrickColor = BrickColor.new("Black")
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = false
	barrel.CanCollide = false
	local weld = Instance.new("WeldConstraint", gun)
	weld.Part0 = gun
	weld.Part1 = barrel
	
	local grip = Instance.new("Part", gun)
	grip.Size = Vector3.new(0.5, 0.5, 0.3)
	grip.Position = Vector3.new(0, -0.3, -0.2)
	grip.BrickColor = BrickColor.new("Brown")
	grip.Material = Enum.Material.Wood
	grip.Anchored = false
	grip.CanCollide = false
	local weld2 = Instance.new("WeldConstraint", gun)
	weld2.Part0 = gun
	weld2.Part1 = grip
	
	local highlight = Instance.new("Highlight")
	highlight.Parent = gun
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 0.2
	highlight.FillColor = Color3.fromRGB(255, 215, 0)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	
	droppedGuns[gun] = highlight
	gun.Parent = workspace
	game:GetService("Debris"):AddItem(gun, gunCleanupDelay)
	
	task.wait(gunCleanupDelay)
	if gun and gun.Parent then
		RemoveDroppedGun(gun)
	end
end

-- ==========================================
-- ОТСЛЕЖИВАНИЕ СМЕРТИ ШЕРИФА
-- ==========================================
local function TrackPlayerDeath(player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local diedConnection
	diedConnection = humanoid.Died:Connect(function()
		if GetPlayerRole(player) == "Sheriff" then
			local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
			if rootPart then
				SpawnSheriffGun(rootPart.Position)
			end
		end
		diedConnection:Disconnect()
	end)
end

-- ==========================================
-- ОБНОВЛЕНИЕ ESP
-- ==========================================
local function UpdateESP()
	local localPlayer = game.Players.LocalPlayer
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player == localPlayer then continue end
		
		local character = player.Character
		if not character then
			if activeHighlights[player] then
				activeHighlights[player]:Destroy()
				activeHighlights[player] = nil
			end
			continue
		end
		
		local role = GetPlayerRole(player)
		local shouldHighlight = role and espStates[role] == true
		
		if shouldHighlight then
			local highlight = activeHighlights[player]
			if not highlight or highlight.Parent ~= character then
				if highlight then highlight:Destroy() end
				highlight = Instance.new("Highlight")
				highlight.Parent = character
				activeHighlights[player] = highlight
			end
			highlight.FillTransparency = 0.5
			highlight.OutlineTransparency = 0.3
			highlight.FillColor = espColors[role]
			highlight.OutlineColor = espColors[role]
		else
			if activeHighlights[player] then
				activeHighlights[player]:Destroy()
				activeHighlights[player] = nil
			end
		end
	end
end

-- Автообновление ESP
spawn(function()
	while true do
		wait(0.5)
		UpdateESP()
	end
end)

-- Обработка новых игроков и их смерти
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		TrackPlayerDeath(player)
	end)
end)

for _, player in ipairs(game.Players:GetPlayers()) do
	if player.Character then
		TrackPlayerDeath(player)
	end
	player.CharacterAdded:Connect(function()
		TrackPlayerDeath(player)
	end)
end

-- ==========================================
-- ИНТЕРФЕЙС UI
-- ==========================================
local VisionBtn = Instance.new("TextButton", ScreenGui)
VisionBtn.Size = UDim2.new(0, 140, 0, 35)
VisionBtn.Position = UDim2.new(0.5, -70, 0.02, 0)
VisionBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
VisionBtn.Text = "⚡ VISION"
VisionBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
VisionBtn.Font = Enum.Font.GothamBold
VisionBtn.TextSize = 20
local VCorner = Instance.new("UICorner", VisionBtn)
VCorner.CornerRadius = UDim.new(0, 4)

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0.75, 0, 0.55, 0)
Main.Position = UDim2.new(0.125, 0, 0.12, 0)
Main.BackgroundColor3 = Color3.fromRGB(150, 255, 80)
Main.BorderSizePixel = 0
Main.Active = false
Main.Draggable = false
Main.Visible = true

local UICorner = Instance.new("UICorner", Main)
UICorner.CornerRadius = UDim.new(0, 6)

local UIStroke = Instance.new("UIStroke", Main)
UIStroke.Color = Color3.fromRGB(50, 100, 255)
UIStroke.Thickness = 2

local CloseBtn = Instance.new("TextButton", Main)
CloseBtn.Size = UDim2.new(0, 50, 0, 50)
CloseBtn.Position = UDim2.new(1, -60, 0, 10)
CloseBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 24
CloseBtn.Font = Enum.Font.GothamBold
local CloseCorner = Instance.new("UICorner", CloseBtn)
CloseCorner.CornerRadius = UDim.new(1, 0)

VisionBtn.MouseButton1Click:Connect(function()
	Main.Visible = not Main.Visible
end)

CloseBtn.MouseButton1Click:Connect(function()
	Main.Visible = false
end)

local ContentFrame = Instance.new("Frame", Main)
ContentFrame.Size = UDim2.new(0.7, 0, 1, -20)
ContentFrame.Position = UDim2.new(0.28, 0, 0.02, 0)
ContentFrame.BackgroundTransparency = 1

local function CreateCheckbox(parent, text, yPos, stateKey)
	local frame = Instance.new("Frame", parent)
	frame.Size = UDim2.new(1, -20, 0, 40)
	frame.Position = UDim2.new(0, 10, 0, yPos)
	frame.BackgroundTransparency = 1
	
	local label = Instance.new("TextLabel", frame)
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(0, 0, 0)
	label.TextSize = 18
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	
	local btn = Instance.new("TextButton", frame)
	btn.Size = UDim2.new(0, 80, 0, 30)
	btn.Position = UDim2.new(0.7, 0, 0.05, 0)
	btn.BackgroundColor3 = espStates[stateKey] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
	btn.Text = espStates[stateKey] and "ВКЛ" or "ВЫКЛ"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)
	
	btn.MouseButton1Click:Connect(function()
		espStates[stateKey] = not espStates[stateKey]
		btn.BackgroundColor3 = espStates[stateKey] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
		btn.Text = espStates[stateKey] and "ВКЛ" or "ВЫКЛ"
		UpdateESP()
	end)
end

-- ВКЛАДКА ESP
local function CreateEspTab()
	for _, v in pairs(ContentFrame:GetChildren()) do v:Destroy() end
	
	local Title = Instance.new("TextLabel", ContentFrame)
	Title.Size = UDim2.new(1, 0, 0, 40)
	Title.Position = UDim2.new(0, 0, 0, 10)
	Title.BackgroundTransparency = 1
	Title.Text = "ESP Highlights"
	Title.TextColor3 = Color3.fromRGB(0, 0, 0)
	Title.TextSize = 26
	Title.Font = Enum.Font.GothamBold
	
	CreateCheckbox(ContentFrame, "🔫 Innocent (невинные)", 60, "Innocent")
	CreateCheckbox(ContentFrame, "💥 Gun (оружие)", 110, "Gun")
	CreateCheckbox(ContentFrame, "🔪 Marder (убийца)", 160, "Marder")
	CreateCheckbox(ContentFrame, "⭐ Sheriff (шериф)", 210, "Sheriff")
	
	local Info = Instance.new("TextLabel", ContentFrame)
	Info.Size = UDim2.new(1, 0, 0, 100)
	Info.Position = UDim2.new(0, 0, 0, 270)
	Info.BackgroundTransparency = 1
	Info.Text = "Роли определяются автоматически:\n• Sheriff — пистолет\n• Marder — нож\n• Gun — другое оружие\n• Innocent — без оружия\n\n⭐ При смерти Шерифа выпадает пистолет с золотой подсветкой"
	Info.TextColor3 = Color3.fromRGB(50, 50, 50)
	Info.TextSize = 14
	Info.Font = Enum.Font.Gotham
	Info.TextXAlignment = Enum.TextXAlignment.Left
end

-- ВКЛАДКА AIMBOT (с кнопкой включения круга)
local function CreateAimbotTab()
	for _, v in pairs(ContentFrame:GetChildren()) do v:Destroy() end
	
	local Title = Instance.new("TextLabel", ContentFrame)
	Title.Size = UDim2.new(1, 0, 0, 40)
	Title.Position = UDim2.new(0, 0, 0, 10)
	Title.BackgroundTransparency = 1
	Title.Text = "Silent Aim (круг)"
	Title.TextColor3 = Color3.fromRGB(0, 0, 0)
	Title.TextSize = 26
	Title.Font = Enum.Font.GothamBold
	
	-- Кнопка включения круга
	local toggleFrame = Instance.new("Frame", ContentFrame)
	toggleFrame.Size = UDim2.new(1, -20, 0, 50)
	toggleFrame.Position = UDim2.new(0, 10, 0, 60)
	toggleFrame.BackgroundTransparency = 1
	
	local toggleLabel = Instance.new("TextLabel", toggleFrame)
	toggleLabel.Size = UDim2.new(0.5, 0, 1, 0)
	toggleLabel.BackgroundTransparency = 1
	toggleLabel.Text = "🎯 Показать круг (перетаскивается)"
	toggleLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	toggleLabel.TextSize = 18
	toggleLabel.Font = Enum.Font.GothamBold
	toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	
	local toggleBtn = Instance.new("TextButton", toggleFrame)
	toggleBtn.Size = UDim2.new(0, 120, 0, 40)
	toggleBtn.Position = UDim2.new(0.7, 0, 0.05, 0)
	toggleBtn.BackgroundColor3 = circleEnabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
	toggleBtn.Text = circleEnabled and "Скрыть" or "Показать"
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 16
	local btnCorner = Instance.new("UICorner", toggleBtn)
	btnCorner.CornerRadius = UDim.new(0, 4)
	
	toggleBtn.MouseButton1Click:Connect(function()
		ToggleSilentAimCircle()
		toggleBtn.BackgroundColor3 = circleEnabled and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
		toggleBtn.Text = circleEnabled and "Скрыть" or "Показать"
	end)
	
	local desc = Instance.new("TextLabel", ContentFrame)
	desc.Size = UDim2.new(1, 0, 0, 100)
	desc.Position = UDim2.new(0, 10, 0, 130)
	desc.BackgroundTransparency = 1
	desc.Text = "Как использовать:\n1. Нажми «Показать», появится красный круг.\n2. Перетащи его в любое место на экране.\n3. Когда увидишь убийцу (Marder), нажми на круг —\n   произойдёт мгновенное наведение + выстрел.\n   Камера вернётся в исходное положение."
	desc.TextColor3 = Color3.fromRGB(80, 80, 80)
	desc.TextSize = 14
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
end

-- Боковое меню
local Sidebar = Instance.new("Frame", Main)
Sidebar.Size = UDim2.new(0.25, 0, 1, 0)
Sidebar.Position = UDim2.new(0, 0, 0, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 38)

local function CreateTabButton(name, yPos)
	local btn = Instance.new("TextButton", Sidebar)
	btn.Size = UDim2.new(0.9, 0, 0.15, 0)
	btn.Position = UDim2.new(0.05, 0, yPos, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 18
	btn.Font = Enum.Font.GothamBold
	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(0, 4)
	return btn
end

local BtnAimbot = CreateTabButton("1. Silent Aim", 0.1)
local BtnEsp = CreateTabButton("2. ESP", 0.3)

BtnAimbot.MouseButton1Click:Connect(CreateAimbotTab)
BtnEsp.MouseButton1Click:Connect(CreateEspTab)

CreateEspTab()  -- открываем ESP по умолчанию

print("✅ ESP + Silent Aim круг (перетаскиваемый, клик → выстрел в Marder) + выпадение пистолета шерифа - готово!")-- MM2 SCRIPT ULTIMATE (ESP + AUTO FARM + OTHER)
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local camera = workspace.CurrentCamera
local sg = Instance.new
("ScreenGui")
sg.Name
 = "MM2GUI"
sg.Parent = player:WaitForChild("PlayerGui")
sg.ResetOnSpawn = false
-- ДИЗАЙН (чёрно-белый градиент)
local bgDark = Color3.fromRGB(12, 12, 16)
local bgLight = Color3.fromRGB(28, 28, 36)
local accent = Color3.fromRGB(220, 220, 240)
local neon = Color3.fromRGB(255, 255, 255)
local menu = Instance.new
("Frame")
menu.Size = UDim2.new
(0, 680, 0, 600)
menu.Position = UDim2.new
(0.5, -340, 0.5, -300)
menu.BackgroundColor3 = bgDark
menu.BackgroundTransparency = 0.1
menu.BorderSizePixel = 0
menu.Visible = true
menu.Parent = sg
local grad = Instance.new
("UIGradient")
grad.Color = ColorSequence.new
({ColorSequenceKeypoint.new
(0,bgDark), ColorSequenceKeypoint.new
(1,bgLight)})
grad.Rotation = 135
grad.Parent = menu
local corner = Instance.new
("UICorner")
corner.CornerRadius = UDim.new
(0, 14)
corner.Parent = menu
local stroke = Instance.new
("UIStroke")
stroke.Color = neon
stroke.Thickness = 1.2
stroke.Transparency = 0.4
stroke.Parent = menu
local titleBar = Instance.new
("Frame")
titleBar.Size = UDim2.new
(1,0,0,55)
titleBar.BackgroundColor3 = Color3.fromRGB(18,18,24)
titleBar.BackgroundTransparency = 0.2
titleBar.Parent = menu
local titleCorner = Instance.new
("UICorner")
titleCorner.CornerRadius = UDim.new
(0,14)
titleCorner.Parent = titleBar
local titleText = Instance.new
("TextLabel")
titleText.Size = UDim2.new
(1,-80,1,0)
titleText.Position = UDim2.new
(0,20,0,0)
titleText.BackgroundTransparency = 1
titleText.Text = "MM2 SCRIPT"
titleText.TextColor3 = neon
titleText.TextSize = 28
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.TextYAlignment = Enum.TextYAlignment.Center
titleText.Parent = titleBar
local minimizeBtn = Instance.new
("TextButton")
minimizeBtn.Size = UDim2.new
(0,36,0,36)
minimizeBtn.Position = UDim2.new
(1,-44,0,10)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(80,80,90)
minimizeBtn.BackgroundTransparency = 0.4
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.new
(1,1,1)
minimizeBtn.TextSize = 32
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = titleBar
local minCorner = Instance.new
("UICorner")
minCorner.CornerRadius = UDim.new
(0,8)
minCorner.Parent = minimizeBtn
local floatBtn = Instance.new
("TextButton")
floatBtn.Size = UDim2.new
(0,55,0,55)
floatBtn.Position = UDim2.new
(0,20,0,100)
floatBtn.BackgroundColor3 = bgDark
floatBtn.BackgroundTransparency = 0.15
floatBtn.BorderSizePixel = 1
floatBtn.BorderColor3 = neon
floatBtn.Text = "†"
floatBtn.TextColor3 = Color3.new
(1,1,1)
floatBtn.TextSize = 46
floatBtn.TextScaled = true
floatBtn.Font = Enum.Font.GothamBold
floatBtn.Visible = true
floatBtn.Parent = sg
local floatCorner = Instance.new
("UICorner")
floatCorner.CornerRadius = UDim.new
(0,12)
floatCorner.Parent = floatBtn
local drag = false
local dragStart = nil
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = Vector2.new
(i.Position.X - menu.AbsolutePosition.X, i.Position.Y - menu.AbsolutePosition.Y)
    end
end)
uis.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)
uis.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        menu.Position = UDim2.new
(0, i.Position.X - dragStart.X, 0, i.Position.Y - dragStart.Y)
    end
end)
minimizeBtn.MouseButton1Click:Connect(function() menu.Visible = false end)
floatBtn.MouseButton1Click:Connect(function() menu.Visible = true end)
uis.InputBegan:Connect(function(i,g) if g then return end if i.KeyCode == Enum.KeyCode.Insert then menu.Visible = not menu.Visible end end)
-- Вкладки
local tabs= {}
local contentFrame = Instance.new
("Frame")
contentFrame.Size = UDim2.new
(0.72, -20, 1, -75)
contentFrame.Position = UDim2.new
(0.27, 10, 0, 65)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = menu
local function createTab(name)
    local btn = Instance.new
("TextButton")
    btn.Size = UDim2.new
(0.23,0,0,44)
    btn.Position = UDim2.new
(0.02,0,0,65 + (#tabs)*48)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,38)
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 1
    btn.BorderColor3 = accent
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(240,240,250)
    btn.TextSize = 17
    btn.Font = Enum.Font.GothamBold
    btn.Parent = menu
    local btnCorner = Instance.new
("UICorner")
    btnCorner.CornerRadius = UDim.new
(0,8)
    btnCorner.Parent = btn
    
    local content = Instance.new
("ScrollingFrame")
    content.Size = UDim2.new
(1,0,1,0)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 5
    content.Visible = false
    content.Parent = contentFrame
    
    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabs) do
            t.content.Visible = false
            t.button.BackgroundTransparency = 0.3
            t.button.BackgroundColor3 = Color3.fromRGB(30,30,38)
            t.button.BorderColor3 = accent
        end
        content.Visible = true
        btn.BackgroundTransparency = 0.7
        btn.BackgroundColor3 = neon
        btn.BorderColor3 = Color3.new
(1,1,1)
    end)
    table.insert(tabs, {button=btn, content=content})
    return content
end
local espTab = createTab(" ESP ")
local otherTab = createTab(" OTHER ")
-- ===== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ =====
local espEnabled = false
local espHighlights = {}
-- Автофарм
local autoFarmEnabled = false
local farmConnection = nil
local farmTarget = nil
-- Other функции (spin, fling, noclip, fly, speedhack, godmode)
local spinEnabled = false
local flingEnabled = false
local noclipActive = false
local flyEnabled = false
local speedhackEnabled = false
local godmodeEnabled = false
local flingTask = nil
local spinBody = nil
local flyGyro, flyVelocity, flyLoop, flyKeys = nil, nil, nil, nil
local flyControls = {f=0,b=0,l=0,r=0}
local flySpeedVal = 0
local maxFlySpeed = 75
local flyAnimationTrack = nil
local flyAnimator = nil
-- ===== ОПРЕДЕЛЕНИЕ РОЛЕЙ MM2 =====
local function getPlayerRole(plr)
    if plr == player then return nil end
    local char = plr.Character
    if not char then return "Innocent" end
    -- Оружие
    local tool = plr.Backpack:FindFirstChildWhichIsA("Tool") or (char:FindFirstChildWhichIsA("Tool"))
    if tool then
        local name = tool.Name:lower()
        if name:find("knife") or name:find("murder") then
            return "Murderer"
        elseif name:find("gun") or name:find("pistol") then
            return "Sheriff"
        end
    end
    -- Значок
    local billboard = char:FindFirstChild("BillboardGui") or char:FindFirstChild("HeadTag")
    if billboard then
        local text = billboard:FindFirstChild("TextLabel")
        if text then
            local txt = text.Text:lower()
            if txt:find("murderer") then return "Murderer"
            elseif txt:find("sheriff") then return "Sheriff"
            end
        end
    end
    return "Innocent"
end
local function getRoleColor(role)
    if role == "Murderer" then return Color3.new
(1, 0, 0)
    elseif role == "Sheriff" then return Color3.new
(0, 0.5, 1)
    else return Color3.new
(0, 1, 0) end
end
local function updateESP()
    for _, hl in pairs(espHighlights) do hl:Destroy() end
    espHighlights = {}
    if not espEnabled then return end
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local role = getPlayerRole(plr)
            local color = getRoleColor(role)
            local hl = Instance.new
("Highlight")
            hl.Parent = sg
            hl.Adornee = plr.Character
            hl.FillColor = color
            hl.FillTransparency = 0.5
            hl.OutlineColor = Color3.new
(1,1,1)
            hl.OutlineTransparency = 0.2
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            espHighlights[plr] = hl
        end
    end
end
local function setESP(state)
    espEnabled = state
    updateESP()
end
-- События для обновления ESP
game.Players.PlayerAdded:Connect(updateESP)
game.Players.PlayerRemoving:Connect(updateESP)
for _, plr in pairs(game.Players:GetPlayers()) do
    plr.CharacterAdded:Connect(updateESP)
    plr.Backpack.ChildAdded:Connect(updateESP)
    plr.Backpack.ChildRemoved:Connect(updateESP)
    if plr.Character then
        plr.Character.ChildAdded:Connect(updateESP)
    end
end
rs.RenderStepped:Connect(updateESP)
-- ===== АВТО-ФАРМ МОНЕТ =====
-- Ищем все монеты (Cash) в workspace
local function getCoins()
    local coins = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        -- Монеты в MM2 обычно называются "Cash" или "Money", могут быть Part с прозрачностью и свечением
        if obj:IsA("BasePart") and (obj.Name:lower():find("cash") or obj.Name:lower():find("money") or obj.Name:lower():find("coin")) then
            if obj:FindFirstChild("BillboardGui") or obj.Material == Enum.Material.Neon then
                table.insert(coins, obj)
            end
        end
        -- Другой вариант: ищем объекты с типом "Value" или "Collectible"
        if obj:IsA("Model") and (obj.Name:lower():find("cash") or obj.Name:lower():find("money")) then
            table.insert(coins, obj)
        end
    end
    return coins
end
local function getClosestCoin(characterRoot)
    local coins = getCoins()
    local closest = nil
    local closestDist = math.huge
    for _, coin in pairs(coins) do
        local pos = coin:IsA("BasePart") and coin.Position or (coin:FindFirstChildWhichIsA("BasePart") and coin:FindFirstChildWhichIsA("BasePart").Position)
        if pos then
            local dist = (characterRoot.Position - pos).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = coin
            end
        end
    end
    return closest, closestDist
end
local function collectCoin(coin)
    -- Телепортируемся к монете и слегка встряхиваем
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root and coin then
        local coinPos = coin:IsA("BasePart") and coin.Position or (coin:FindFirstChildWhichIsA("BasePart") and coin:FindFirstChildWhichIsA("BasePart").Position)
        if coinPos then
            root.CFrame = CFrame.new
(coinPos)
        end
    end
end
local function farmLoop()
    while autoFarmEnabled and player.Character do
        local root = player.Character:FindFirstChild("HumanoidRootPart")
        if not root then break end
        local closestCoin, dist = getClosestCoin(root)
        if closestCoin and dist < 100 then
            collectCoin(closestCoin)
        end
        task.wait(0.1)
    end
end
local function setAutoFarm(state)
    autoFarmEnabled = state
    if autoFarmEnabled then
        if farmConnection then farmConnection:Disconnect() end
        farmConnection = rs.Stepped:Connect(farmLoop)
    else
        if farmConnection then farmConnection:Disconnect() farmConnection = nil end
    end
end
-- ===== ДРУГИЕ ФУНКЦИИ (спин, флинг, ноклип, флай, спидхак, гудмод) =====
-- Noclip (постоянный)
local noclipConnection = nil
local function applyNoclipToChar(char)
    if not char or not noclipActive then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end
local function startNoclip()
    if noclipConnection then
        if noclipConnection.charDescConn then noclipConnection.charDescConn:Disconnect() end
        if noclipConnection.stepConn then noclipConnection.stepConn:Disconnect() end
        noclipConnection = nil
    end
    local char = player.Character
    if nogTask then flingTask:Disconnect() end
    flingTask = rs.Stepped:Connect(function()
        if not flingEnabled then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                if tRoot and (root.Position - tRoot.Position).Magnitude < 18 then
                    flingPlayer(plr)
                    wait(0.4)
                end
            end
        end
    end)
end
local function setFling(state)
    flingEnabled = state
    if flingEnabled then flingLoop() else if flingTask then flingTask:Disconnect() flingTask = nil end end
end
-- Speedhack
local function setSpeedhack(state)
    speedhackEnabled = state
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedhackEnabled and 80 or 16 end
    end
end
-- God Mode
local function setGodMode(state)
    godmodeEnabled = state
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if godmodeEnabled then
                hum.MaxHealth = math.huge
                hum.Health
 = math.huge
                hum.BreakJointsOnDeath = false
                hum:GetPropertyChangedSignal("Health"):Connect(function()
                    if godmodeEnabled and hum.Health
 <= 0 then
                        hum.Health
 = hum.MaxHealth
                    end
                end)
            else
                hum.MaxHealth = 100
                if hum.Health
 > 100 then hum.Health
 = 100 end
                hum.BreakJointsOnDeath = true
            end
        end
    end
end
-- Fly (с позой супермена)
local function loadSupermanAnimation()
    local animId = "rbxassetid://10734341438"
    local anim = Instance.new
("Animation")
    anim.AnimationId = animId
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local animator = hum:FindFirstChild("Animator") or Instance.new
("Animator", hum)
            flyAnimator = animator
            flyAnimationTrack = animator:LoadAnimation(anim)
            flyAnimationTrack.Looped = true
            flyAnimationTrack.Priority = Enum.AnimationPriority.Action
        end
    end
end
local function startFly()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = hum and hum.RootPart
    if not hum or not root then return end
    hum.PlatformStand = true
    if char:FindFirstChild("Animate") then char.Animate.Disabled = true end
    if not flyAnimationTrack then loadSupermanAnimation() end
    if flyAnimationTrack and flyAnimator then flyAnimationTrack:Play() end
    local bg = Instance.new
("BodyGyro")
    bg.P = 9e4
    bg.maxTorque = Vector3.new
(9e9,9e9,9e9)
    bg.Parent = root
    local bv = Instance.new
("BodyVelocity")
    bv.MaxForce = Vector3.new
(9e9,9e9,9e9)
    bv.Parent = root
    flyGyro, flyVelocity = bg, bv
    flyControls = {f=0,b=0,l=0,r=0}
    flySpeedVal = 0
    local function keyDown(key)
        if key=="w" then flyControls.f=1 elseif key=="s" then flyControls.b=1
        elseif key=="a" then flyControls.l=1 elseif key=="d" then flyControls.r=1 end
    end
    local function keyUp(key)
        if key=="w" then flyControls.f=0 elseif key=="s" then flyControls.b=0
        elseif key=="a" then flyControls.l=0 elseif key=="d" then flyControls.r=0 end
    end
    local c1 = uis.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Keyboard then keyDown(i.KeyCode.Name:lower()) end
    end)
    local c2 = uis.InputEnded:Connect(function(i)
        ifi.UserInputType == Enum.UserInputType.Keyboard then keyUp(i.KeyCode.Name:lower()) end
    end)
    flyKeys = {c1,c2}
    flyLoop = rs.RenderStepped:Connect(function()
        if not flyEnabled or not flyVelocity then return end
        local move = Vector3.new
(flyControls.r - flyControls.l, 0, flyControls.f - flyControls.b)
        if move.Magnitude > 0 then move = move.unit end
        if move.Magnitude > 0 then flySpeedVal = math.min(flySpeedVal + 1.2, maxFlySpeed)
        else flySpeedVal = math.max(flySpeedVal - 2, 0) end
        local vel = (camera.CFrame.lookVector * move.Z + camera.CFrame.rightVector * move.X) * flySpeedVal
        flyVelocity.Velocity = vel
        flyGyro.CFrame = camera.CFrame * CFrame.Angles(-math.rad((flyControls.f+flyControls.b)*35),0,0)
    end)
end
local function stopFly()
    if flyLoop then flyLoop:Disconnect() flyLoop = nil end
    if flyGyro then flyGyro:Destroy() flyGyro = nil end
    if flyVelocity then flyVelocity:Destroy() flyVelocity = nil end
    if flyKeys then for _,c in pairs(flyKeys) do c:Disconnect() end flyKeys = nil end
    if flyAnimationTrack then flyAnimationTrack:Stop() flyAnimationTrack = nil end
    flyAnimator = nil
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            if char:FindFirstChild("Animate") then char.Animate.Disabled = false end
            local animator = hum:FindFirstChild("Animator")
            if animator then for _, track in pairs(animator:GetPlayingAnimationTracks()) do track:Stop() end end
        end
    end
end
local function setFly(state)
    flyEnabled = state
    if flyEnabled then startFly() else stopFly() end
end
-- ===== КНОПКИ МЕНЮ =====
local function addButton(tab, text, callback, yStart)
    local btn = Instance.new
("TextButton")
    btn.Size = UDim2.new
(0.7,0,0,42)
    btn.Position = UDim2.new
(0.15,0,0,yStart)
    btn.BackgroundColor3 = Color3.fromRGB(35,35,45)
    btn.BackgroundTransparency = 0.3
    btn.BorderSizePixel = 1
    btn.BorderColor3 = accent
    btn.Text = text .. " • OFF"
    btn.TextColor3 = Color3.fromRGB(240,240,250)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.Parent = tab
    local btnCorner = Instance.new
("UICorner")
    btnCorner.CornerRadius = UDim.new
(0,10)
    btnCorner.Parent = btn
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. (state and " • ON" or " • OFF")
        callback(state)
        if state then
            btn.BackgroundColor3 = neon
            btn.BackgroundTransparency = 0.6
            btn.TextColor3 = Color3.new
(0,0,0)
            btn.BorderColor3 = Color3.new
(1,1,1)
        else
            btn.BackgroundColor3 = Color3.fromRGB(35,35,45)
            btn.BackgroundTransparency = 0.3
            btn.TextColor3 = Color3.fromRGB(240,240,250)
            btn.BorderColor3 = accent
        end
    end)
    return yStart + 52
end
-- ESP вкладка
local espY = 30
espY = addButton(espTab, "ESP PLAYERS", setESP, espY)
-- OTHER вкладка
local otherY = 30
otherY = addButton(otherTab, "AUTO FARM", setAutoFarm, otherY)
otherY = addButton(otherTab, "SPINBOT", setSpinbot, otherY)
otherY = addButton(otherTab, "FLING", setFling, otherY)
otherY = addButton(otherTab, "NOCLIP", setNoclip, otherY)
otherY = addButton(otherTab, "FLY", setFly, otherY)
otherY = addButton(otherTab, "SPEEDHACK", setSpeedhack, otherY)
otherY = addButton(otherTab, "GOD MODE", setGodMode, otherY)
-- Активируем первую вкладку
if tabs[1] then tabs[1].button.MouseButton1Click:Fire() end
-- Перерождение
player.CharacterAdded:Connect(function()
    task.wait(0.6)
    if noclipActive then setNoclip(true) end
    if flyEnabled then setFly(true) end
    if spinEnabled then setSpinbot(true) end
    if speedhackEnabled then setSpeedhack(true) end
    if godmodeEnabled then setGodMode(true) end
    if espEnabled then updateESP() endif autoFarmEnabled then setAutoFarm(true) end
end)
print("MM2 Script ULTIMATE с AUTO FARM загружен. AutoFarm собирает монеты автоматически (ищет Cash/Money). Остальные функции работают.")
