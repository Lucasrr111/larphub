--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local runtimeEnvironment = {};
if (type(getfenv) == "function") then
	local ok, value = pcall(getfenv, 0);
	if (ok and (type(value) == "table")) then
		runtimeEnvironment = value;
	end
end
local RELOAD_STATE = rawget(runtimeEnvironment, "STATE");
local standaloneCleanup = function()
end;
if not RELOAD_STATE then
	local scriptGlobals = nil;
	if (type(getscriptglobals) == "function") then
		local ok, value = pcall(getscriptglobals);
		if (ok and (type(value) == "table")) then
			scriptGlobals = value;
		end
	end
	local sharedEnvironment = (scriptGlobals and rawget(scriptGlobals, "shared")) or rawget(runtimeEnvironment, "shared");
	if (type(sharedEnvironment) ~= "table") then
		sharedEnvironment = {};
	end
	local previousCleanup = sharedEnvironment.__SAHARA_AUTO_JOB_CLEANUP;
	if (type(previousCleanup) == "function") then
		pcall(previousCleanup);
	end
	local alive = true;
	local cleanupCallbacks = {};
	local function cleanup()
		if not alive then
			return;
		end
		alive = false;
		for index = #cleanupCallbacks, 1, -1 do
			pcall(cleanupCallbacks[index]);
		end
		table.clear(cleanupCallbacks);
		if (sharedEnvironment.__SAHARA_AUTO_JOB_CLEANUP == cleanup) then
			sharedEnvironment.__SAHARA_AUTO_JOB_CLEANUP = nil;
		end
	end
	RELOAD_STATE = {alive=function()
		return alive;
	end,onCleanup=function(callback)
		if alive then
			table.insert(cleanupCallbacks, callback);
		else
			pcall(callback);
		end
	end,connect=function(signal, callback)
		local connection = signal:Connect(callback);
		table.insert(cleanupCallbacks, function()
			if connection.Connected then
				connection:Disconnect();
			end
		end);
		return connection;
	end};
	standaloneCleanup = cleanup;
	sharedEnvironment.__SAHARA_AUTO_JOB_CLEANUP = cleanup;
end
local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");
local Lighting = game:GetService("Lighting");
local Stats = game:GetService("Stats");
local HttpService = game:GetService("HttpService");
local SCRIPT_VERSION = "2.9.4";
local player = Players.LocalPlayer;
local KEYAUTH_APP_NAME = "LarpHub";
local KEYAUTH_OWNER_ID = "wuEInLZtyE";
local KEYAUTH_APP_VERSION = "1.0";
local KEYAUTH_VERIFY_URL = "https://larphub-keys.larphubservices.workers.dev/api/verify";
local KEY_SYSTEM_URL = "https://larphub-keys.larphubservices.workers.dev/";
local KEYAUTH_KEY_CACHE = "larphub_keyauth.key";
local KEYAUTH_GATE_NAME = "GreenHubKeyAuthGate";
local function trimKeyText(value)
	return tostring(value or ""):match("^%s*(.-)%s*$");
end
local function getLarpHubHwid()
	local providers = {};
	if (type(gethwid) == "function") then
		table.insert(providers, gethwid);
	end
	if (type(get_hwid) == "function") then
		table.insert(providers, get_hwid);
	end
	for _, provider in ipairs(providers) do
		local ok, value = pcall(provider);
		value = (ok and trimKeyText(value)) or "";
		if (#value >= 4) then
			return value;
		end
	end
	local analyticsOk, analyticsId = pcall(function()
		return game:GetService("RbxAnalyticsService"):GetClientId();
	end);
	analyticsId = (analyticsOk and trimKeyText(analyticsId)) or "";
	if (#analyticsId >= 4) then
		return analyticsId;
	end
	local localPlayer = Players.LocalPlayer;
	return string.format("roblox-%s-%s", tostring((localPlayer and localPlayer.UserId) or 0), tostring(game.GameId));
end
local function requestKeyAuth(payload)
	local encoded = HttpService:JSONEncode(payload);
	local body = nil;
	local requestError = "No compatible HTTP method";
	local requestFunction = nil;
	if (type(request) == "function") then
		requestFunction = request;
	elseif (type(http_request) == "function") then
		requestFunction = http_request;
	elseif ((type(syn) == "table") and (type(syn.request) == "function")) then
		requestFunction = syn.request;
	elseif ((type(http) == "table") and (type(http.request) == "function")) then
		requestFunction = http.request;
	end
	if requestFunction then
		local ok, response = pcall(requestFunction, {Url=KEYAUTH_VERIFY_URL,Method="POST",Headers={Accept="application/json",["Content-Type"]="application/json"},Body=encoded});
		if (ok and (type(response) == "table")) then
			body = response.Body or response.body;
			if (type(body) ~= "string") then
				local statusCode = tonumber(response.StatusCode or response.Status or response.status_code) or 0;
				requestError = "Verification returned HTTP " .. tostring(statusCode);
			end
		else
			requestError = tostring(response);
		end
	end
	if (type(body) ~= "string") then
		local ok, response = pcall(function()
			return game:HttpPost(KEYAUTH_VERIFY_URL, encoded, Enum.HttpContentType.ApplicationJson, false);
		end);
		if (ok and (type(response) == "string")) then
			body = response;
		elseif not requestFunction then
			requestError = tostring(response);
		end
	end
	if (type(body) ~= "string") then
		return nil, "KeyAuth request failed: " .. tostring(requestError);
	end
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, body);
	if (not ok or (type(decoded) ~= "table")) then
		return nil, "KeyAuth returned an invalid response";
	end
	return decoded, nil;
end
local function formatKeyTime(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0));
	local hours = math.floor(seconds / 3600);
	local minutes = math.floor((seconds % 3600) / 60);
	if (hours > 0) then
		return string.format("%dh %02dm", hours, minutes);
	end
	return string.format("%dm", minutes);
end
local function validateKeyAuthLicense(license)
	license = trimKeyText(license);
	if (#license < 8) then
		return false, "Paste the complete LarpHub license";
	end
	local response, requestError = requestKeyAuth({key=license,hwid=getLarpHubHwid(),app=KEYAUTH_APP_NAME,ownerid=KEYAUTH_OWNER_ID,version=KEYAUTH_APP_VERSION});
	if not response then
		return false, requestError;
	end
	if (response.success ~= true) then
		return false, ((trimKeyText(response.message) ~= "") and tostring(response.message)) or "License is invalid or expired";
	end
	local info = response.info;
	local subscriptions = ((type(info) == "table") and info.subscriptions) or nil;
	local firstSubscription = ((type(subscriptions) == "table") and subscriptions[1]) or nil;
	local timeLeft = ((type(firstSubscription) == "table") and tonumber(firstSubscription.timeleft)) or nil;
	if (timeLeft and (timeLeft > 0)) then
		return true, "License accepted - " .. formatKeyTime(timeLeft) .. " remaining";
	end
	return true, "License accepted";
end
local function readCachedKeyAuthLicense()
	if ((type(isfile) ~= "function") or (type(readfile) ~= "function")) then
		return nil;
	end
	local ok, exists = pcall(isfile, KEYAUTH_KEY_CACHE);
	if (not ok or not exists) then
		return nil;
	end
	local readOk, value = pcall(readfile, KEYAUTH_KEY_CACHE);
	value = (readOk and trimKeyText(value)) or "";
	return ((value ~= "") and value) or nil;
end
local function saveCachedKeyAuthLicense(license)
	if (type(writefile) == "function") then
		pcall(writefile, KEYAUTH_KEY_CACHE, trimKeyText(license));
	end
end
local function clearCachedKeyAuthLicense()
	if (type(delfile) == "function") then
		pcall(delfile, KEYAUTH_KEY_CACHE);
	end
end
local function runKeyAuthGate()
	local cachedLicense = readCachedKeyAuthLicense();
	local cachedMessage = nil;
	if cachedLicense then
		local valid, message = validateKeyAuthLicense(cachedLicense);
		if valid then
			return true;
		end
		cachedMessage = message;
	end
	local localPlayer = Players.LocalPlayer;
	local guiParent = localPlayer:WaitForChild("PlayerGui");
	if (type(gethui) == "function") then
		local parentOk, value = pcall(gethui);
		if (parentOk and (typeof(value) == "Instance")) then
			guiParent = value;
		end
	end
	local oldGui = guiParent:FindFirstChild(KEYAUTH_GATE_NAME);
	if oldGui then
		oldGui:Destroy();
	end
	local keyGui = Instance.new("ScreenGui");
	keyGui.Name = KEYAUTH_GATE_NAME;
	keyGui.ResetOnSpawn = false;
	keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
	keyGui.DisplayOrder = 100001;
	keyGui.Parent = guiParent;
	local panel = Instance.new("Frame");
	panel.Name = "Main";
	panel.Size = UDim2.fromOffset(420, 286);
	panel.Position = UDim2.new(0.5, -210, 0.5, -143);
	panel.BackgroundColor3 = Color3.fromRGB(6, 18, 12);
	panel.BackgroundTransparency = 0.04;
	panel.BorderSizePixel = 0;
	panel.Active = true;
	panel.Draggable = true;
	panel.Parent = keyGui;
	local panelCorner = Instance.new("UICorner");
	panelCorner.CornerRadius = UDim.new(0, 12);
	panelCorner.Parent = panel;
	local panelStroke = Instance.new("UIStroke");
	panelStroke.Color = Color3.fromRGB(104, 230, 154);
	panelStroke.Thickness = 1.5;
	panelStroke.Parent = panel;
	local function addLabel(text, position, size, textSize, bold)
		local label = Instance.new("TextLabel");
		label.Position = position;
		label.Size = size;
		label.BackgroundTransparency = 1;
		label.Font = (bold and Enum.Font.GothamBold) or Enum.Font.Gotham;
		label.Text = text;
		label.TextColor3 = Color3.fromRGB(226, 248, 234);
		label.TextSize = textSize;
		label.TextWrapped = true;
		label.TextXAlignment = Enum.TextXAlignment.Left;
		label.Parent = panel;
		return label;
	end
	local function addButton(name, text, position, size, color)
		local button = Instance.new("TextButton");
		button.Name = name;
		button.Position = position;
		button.Size = size;
		button.BackgroundColor3 = color;
		button.BorderSizePixel = 0;
		button.Font = Enum.Font.GothamBold;
		button.Text = text;
		button.TextColor3 = Color3.new(1, 1, 1);
		button.TextSize = 12;
		button.Parent = panel;
		local corner = Instance.new("UICorner");
		corner.CornerRadius = UDim.new(0, 8);
		corner.Parent = button;
		return button;
	end
	addLabel("GREEN HUB @lucasrrra  |  KEY SYSTEM", UDim2.fromOffset(18, 0), UDim2.new(1, -70, 0, 48), 14, true);
	local closeButton = addButton("Close", "X", UDim2.new(1, -44, 0, 7), UDim2.fromOffset(34, 34), Color3.fromRGB(23, 60, 39));
	local description = addLabel("Complete the steps, reveal your key, then paste it below.", UDim2.fromOffset(18, 51), UDim2.new(1, -36, 0, 38), 11, false);
	description.TextColor3 = Color3.fromRGB(158, 205, 174);
	local keyBox = Instance.new("TextBox");
	keyBox.Name = "Key";
	keyBox.Position = UDim2.fromOffset(18, 96);
	keyBox.Size = UDim2.new(1, -36, 0, 44);
	keyBox.BackgroundColor3 = Color3.fromRGB(9, 29, 18);
	keyBox.BorderSizePixel = 0;
	keyBox.ClearTextOnFocus = false;
	keyBox.Font = Enum.Font.Code;
	keyBox.PlaceholderText = "Paste LarpHub license";
	keyBox.PlaceholderColor3 = Color3.fromRGB(91, 126, 103);
	keyBox.Text = cachedLicense or "";
	keyBox.TextColor3 = Color3.fromRGB(220, 245, 228);
	keyBox.TextSize = 13;
	keyBox.TextXAlignment = Enum.TextXAlignment.Left;
	keyBox.Parent = panel;
	local keyBoxCorner = Instance.new("UICorner");
	keyBoxCorner.CornerRadius = UDim.new(0, 8);
	keyBoxCorner.Parent = keyBox;
	local keyBoxPadding = Instance.new("UIPadding");
	keyBoxPadding.PaddingLeft = UDim.new(0, 12);
	keyBoxPadding.PaddingRight = UDim.new(0, 12);
	keyBoxPadding.Parent = keyBox;
	local getKeyButton = addButton("GetKey", "COPY GET-KEY LINK", UDim2.fromOffset(18, 152), UDim2.fromOffset(183, 42), Color3.fromRGB(29, 83, 52));
	local verifyButton = addButton("Verify", "VERIFY KEY", UDim2.fromOffset(219, 152), UDim2.fromOffset(183, 42), Color3.fromRGB(35, 145, 87));
	local statusLabel = addLabel(cachedMessage or "Waiting for a LarpHub license...", UDim2.fromOffset(18, 207), UDim2.new(1, -36, 0, 61), 11, false);
	statusLabel.Name = "Status";
	statusLabel.BackgroundTransparency = 0;
	statusLabel.BackgroundColor3 = Color3.fromRGB(9, 29, 18);
	statusLabel.TextColor3 = (cachedMessage and Color3.fromRGB(235, 137, 143)) or Color3.fromRGB(158, 205, 174);
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center;
	local statusCorner = Instance.new("UICorner");
	statusCorner.CornerRadius = UDim.new(0, 8);
	statusCorner.Parent = statusLabel;
	local completed = false;
	local accepted = false;
	local busy = false;
	local function submitKey()
		if (completed or busy) then
			return;
		end
		busy = true;
		verifyButton.Text = "VERIFYING...";
		verifyButton.BackgroundColor3 = Color3.fromRGB(69, 91, 77);
		statusLabel.Text = "Checking license with KeyAuth...";
		statusLabel.TextColor3 = Color3.fromRGB(158, 205, 174);
		task.spawn(function()
			local license = trimKeyText(keyBox.Text);
			local valid, message = validateKeyAuthLicense(license);
			if valid then
				saveCachedKeyAuthLicense(license);
				accepted = true;
				completed = true;
				statusLabel.Text = message .. " - loading hub...";
				task.wait(0.25);
				if keyGui.Parent then
					keyGui:Destroy();
				end
				return;
			end
			statusLabel.Text = message;
			statusLabel.TextColor3 = Color3.fromRGB(235, 137, 143);
			verifyButton.Text = "VERIFY KEY";
			verifyButton.BackgroundColor3 = Color3.fromRGB(35, 145, 87);
			busy = false;
		end);
	end
	getKeyButton.Activated:Connect(function()
		local copied = false;
		if (type(setclipboard) == "function") then
			copied = pcall(setclipboard, KEY_SYSTEM_URL);
		elseif (type(toclipboard) == "function") then
			copied = pcall(toclipboard, KEY_SYSTEM_URL);
		end
		statusLabel.TextColor3 = Color3.fromRGB(158, 205, 174);
		statusLabel.Text = (copied and "Link copied. Paste it into your browser.") or KEY_SYSTEM_URL;
	end);
	verifyButton.Activated:Connect(submitKey);
	keyBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitKey();
		end
	end);
	closeButton.Activated:Connect(function()
		accepted = false;
		completed = true;
		keyGui:Destroy();
	end);
	while not completed and keyGui.Parent do
		task.wait(0.1);
	end
	return accepted;
end
if not runKeyAuthGate() then
	return;
end
local remotes = ReplicatedStorage:WaitForChild("Remote");
local sessionVehicles = workspace:WaitForChild("SessionVehicles");
local JOB_NAME = "Sahara Delivery Worker";
local VEHICLE_ID = "4548";
local DELIVERY_COOLDOWN_MIN = 10.25;
local DELIVERY_COOLDOWN_MAX = 11;
local SERVER_COOLDOWN_RETRY_MIN = 2.25;
local SERVER_COOLDOWN_RETRY_MAX = 4.75;
local BONUS_TIMEOUT = 15;
local NETWORK_RETRY_DELAY = 1.5;
local POST_BONUS_DELAY_MIN = 1.25;
local POST_BONUS_DELAY_MAX = 2.25;
local ROUTE_STATE_POLL_INTERVAL = 1.5;
local REMOTE_MIN_GAP = 0.35;
local DAILY_TASK_POLL_INTERVAL = 300;
local DAILY_TASK_RETRY_INTERVAL = 10;
local DAILY_REWARD_POLL_INTERVAL = 300;
local DAILY_REWARD_VERIFY_INTERVAL = 5;
local BACKGROUND_WAIT_SLICE = 5;
local MEMORY_SAMPLE_INTERVAL = 15;
local MEMORY_ABSOLUTE_LIMIT_MB = 6144;
local MEMORY_GROWTH_LIMIT_MB = 6144;
local function nextDeliveryCooldown()
	return DELIVERY_COOLDOWN_MIN + (math.random() * (DELIVERY_COOLDOWN_MAX - DELIVERY_COOLDOWN_MIN));
end
local function randomBetween(minimum, maximum)
	return minimum + (math.random() * (maximum - minimum));
end
local POTATO_FPS = 10;
local IDLE_GUARD_REFRESH_SECONDS = 45;
local running = false;
local workerToken = 0;
local completionSerial = 0;
local cycles = 0;
local delivered = 0;
local currentRemaining = 0;
local autoClaims = 0;
local antiAfkPulses = 0;
local lastAntiAfkAt = -math.huge;
local elapsedRunSeconds = 0;
local antiAfkEnabled = RELOAD_STATE.antiKickEnabled == true;
local idleConnectionProvider = nil;
if (type(getconnections) == "function") then
	idleConnectionProvider = getconnections;
elseif (type(get_signal_cons) == "function") then
	idleConnectionProvider = get_signal_cons;
elseif (type(getsignals) == "function") then
	idleConnectionProvider = getsignals;
end
local antiAfkMethodAvailable = type(idleConnectionProvider) == "function";
local guardedIdleConnections = {};
local guardedIdleConnectionSet = {};
local memoryBaselineMb = 0;
local memoryCurrentMb = 0;
local sessionEarnings = 0;
local lastObservedMoney = tonumber(player:GetAttribute("Money")) or 0;
local nextDeliveryAttemptAt = 0;
local claimAttempts = {};
local pendingClaims = {};
local nextDailyRewardCheckAt = 0;
local dailyRewardPending = false;
local dailyRewardLastAttempt = 0;
local potatoMode = RELOAD_STATE.potatoEnabled == true;
local destroyed = false;
local savedFpsCap = 60;
if (type(getfpscap) == "function") then
	local ok, value = pcall(getfpscap);
	if (ok and (type(value) == "number") and (value >= 0)) then
		savedFpsCap = value;
	end
end
local savedQualityLevel = settings().Rendering.QualityLevel;
local savedGlobalShadows = Lighting.GlobalShadows;
local guiParent = game:GetService("CoreGui");
if (type(gethui) == "function") then
	local ok, value = pcall(gethui);
	if (ok and (typeof(value) == "Instance")) then
		guiParent = value;
	end
end
local oldGui = guiParent:FindFirstChild("SaharaAutoJob");
if oldGui then
	local oldShutdown = oldGui:FindFirstChild("__Shutdown");
	if (oldShutdown and oldShutdown:IsA("BindableEvent")) then
		pcall(function()
			oldShutdown:Fire();
		end);
	end
	oldGui:Destroy();
end
local gui = Instance.new("ScreenGui");
gui.Name = "SaharaAutoJob";
gui.ResetOnSpawn = false;
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
local parented = pcall(function()
	gui.Parent = guiParent;
end);
if not parented then
	guiParent = player:WaitForChild("PlayerGui");
	gui.Parent = guiParent;
end
local shutdownEvent = Instance.new("BindableEvent");
shutdownEvent.Name = "__Shutdown";
shutdownEvent.Parent = gui;
local main = Instance.new("Frame");
main.Name = "Main";
main.Size = UDim2.fromOffset(370, 326);
main.Position = UDim2.new(0.5, -185, 0.5, -163);
main.BackgroundColor3 = Color3.fromRGB(7, 17, 12);
main.BorderSizePixel = 0;
main.Parent = gui;
local mainCorner = Instance.new("UICorner");
mainCorner.CornerRadius = UDim.new(0, 12);
mainCorner.Parent = main;
local stroke = Instance.new("UIStroke");
stroke.Color = Color3.fromRGB(104, 230, 154);
stroke.Thickness = 1.5;
stroke.Transparency = 0.15;
stroke.Parent = main;
local header = Instance.new("Frame");
header.Name = "Header";
header.Size = UDim2.new(1, 0, 0, 48);
header.BackgroundColor3 = Color3.fromRGB(12, 35, 23);
header.BorderSizePixel = 0;
header.Parent = main;
local headerCorner = Instance.new("UICorner");
headerCorner.CornerRadius = UDim.new(0, 12);
headerCorner.Parent = header;
local headerMask = Instance.new("Frame");
headerMask.Size = UDim2.new(1, 0, 0, 12);
headerMask.Position = UDim2.new(0, 0, 1, -12);
headerMask.BackgroundColor3 = header.BackgroundColor3;
headerMask.BorderSizePixel = 0;
headerMask.Parent = header;
local title = Instance.new("TextLabel");
title.Size = UDim2.new(1, -58, 1, 0);
title.Position = UDim2.fromOffset(16, 0);
title.BackgroundTransparency = 1;
title.Font = Enum.Font.GothamBold;
title.Text = "GREEN HUB @lucasrrra  •  v" .. SCRIPT_VERSION;
title.TextColor3 = Color3.fromRGB(226, 248, 234);
title.TextSize = 16;
title.TextXAlignment = Enum.TextXAlignment.Left;
title.Parent = header;
local closeButton = Instance.new("TextButton");
closeButton.Name = "Close";
closeButton.Size = UDim2.fromOffset(34, 34);
closeButton.Position = UDim2.new(1, -42, 0, 7);
closeButton.BackgroundColor3 = Color3.fromRGB(24, 57, 39);
closeButton.BorderSizePixel = 0;
closeButton.Font = Enum.Font.GothamBold;
closeButton.Text = "×";
closeButton.TextColor3 = Color3.fromRGB(213, 238, 222);
closeButton.TextSize = 22;
closeButton.Parent = header;
local closeCorner = Instance.new("UICorner");
closeCorner.CornerRadius = UDim.new(0, 8);
closeCorner.Parent = closeButton;
local statusCaption = Instance.new("TextLabel");
statusCaption.Size = UDim2.fromOffset(90, 18);
statusCaption.Position = UDim2.fromOffset(18, 63);
statusCaption.BackgroundTransparency = 1;
statusCaption.Font = Enum.Font.GothamBold;
statusCaption.Text = "STATUS";
statusCaption.TextColor3 = Color3.fromRGB(113, 232, 160);
statusCaption.TextSize = 11;
statusCaption.TextXAlignment = Enum.TextXAlignment.Left;
statusCaption.Parent = main;
local statusLabel = Instance.new("TextLabel");
statusLabel.Name = "Status";
statusLabel.Size = UDim2.new(1, -36, 0, 48);
statusLabel.Position = UDim2.fromOffset(18, 81);
statusLabel.BackgroundColor3 = Color3.fromRGB(10, 27, 18);
statusLabel.BorderSizePixel = 0;
statusLabel.Font = Enum.Font.Gotham;
statusLabel.Text = "Ready  •  v" .. SCRIPT_VERSION .. " loaded  •  Anti-AFK starts OFF";
statusLabel.TextColor3 = Color3.fromRGB(210, 235, 219);
statusLabel.TextSize = 13;
statusLabel.TextWrapped = true;
statusLabel.TextXAlignment = Enum.TextXAlignment.Left;
statusLabel.Parent = main;
local statusPadding = Instance.new("UIPadding");
statusPadding.PaddingLeft = UDim.new(0, 12);
statusPadding.PaddingRight = UDim.new(0, 12);
statusPadding.Parent = statusLabel;
local statusCorner = Instance.new("UICorner");
statusCorner.CornerRadius = UDim.new(0, 8);
statusCorner.Parent = statusLabel;
local statsLabel = Instance.new("TextLabel");
statsLabel.Name = "Stats";
statsLabel.Size = UDim2.new(1, -36, 0, 32);
statsLabel.Position = UDim2.fromOffset(18, 145);
statsLabel.BackgroundTransparency = 1;
statsLabel.Font = Enum.Font.GothamMedium;
statsLabel.Text = "C: 0  •  D: 0  •  Left: 0  •  Claims: 0\nEarned: $0";
statsLabel.TextColor3 = Color3.fromRGB(158, 200, 173);
statsLabel.TextSize = 11;
statsLabel.TextXAlignment = Enum.TextXAlignment.Left;
statsLabel.TextYAlignment = Enum.TextYAlignment.Top;
statsLabel.TextWrapped = true;
statsLabel.Parent = main;
local runtimeLabel = Instance.new("TextLabel");
runtimeLabel.Name = "Runtime";
runtimeLabel.Size = UDim2.new(0.55, -18, 0, 38);
runtimeLabel.Position = UDim2.fromOffset(18, 177);
runtimeLabel.BackgroundTransparency = 1;
runtimeLabel.Font = Enum.Font.Gotham;
runtimeLabel.Text = "Runtime: 00:00:00\nAnti-Kick: ON | Event-driven";
runtimeLabel.TextColor3 = Color3.fromRGB(112, 151, 126);
runtimeLabel.TextSize = 11;
runtimeLabel.TextXAlignment = Enum.TextXAlignment.Left;
runtimeLabel.TextYAlignment = Enum.TextYAlignment.Center;
runtimeLabel.Parent = main;
local toggleButton = Instance.new("TextButton");
toggleButton.Name = "Toggle";
toggleButton.Size = UDim2.new(0.4, -18, 0, 42);
toggleButton.Position = UDim2.new(0.6, 0, 0, 176);
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 145, 87);
toggleButton.BorderSizePixel = 0;
toggleButton.Font = Enum.Font.GothamBold;
toggleButton.Text = "START";
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255);
toggleButton.TextSize = 14;
toggleButton.Parent = main;
local toggleCorner = Instance.new("UICorner");
toggleCorner.CornerRadius = UDim.new(0, 9);
toggleCorner.Parent = toggleButton;
local antiAfkButton = Instance.new("TextButton");
antiAfkButton.Name = "AntiAfk";
antiAfkButton.Size = UDim2.new(1, -36, 0, 38);
antiAfkButton.Position = UDim2.fromOffset(18, 228);
antiAfkButton.BackgroundColor3 = Color3.fromRGB(28, 55, 39);
antiAfkButton.BorderSizePixel = 0;
antiAfkButton.Font = Enum.Font.GothamBold;
antiAfkButton.Text = "ANTI-AFK: OFF";
antiAfkButton.TextColor3 = Color3.fromRGB(255, 255, 255);
antiAfkButton.TextSize = 11;
antiAfkButton.TextWrapped = true;
antiAfkButton.Parent = main;
local antiAfkCorner = Instance.new("UICorner");
antiAfkCorner.CornerRadius = UDim.new(0, 9);
antiAfkCorner.Parent = antiAfkButton;
local potatoButton = Instance.new("TextButton");
potatoButton.Name = "PotatoMode";
potatoButton.Size = UDim2.new(1, -36, 0, 38);
potatoButton.Position = UDim2.fromOffset(18, 274);
potatoButton.BackgroundColor3 = Color3.fromRGB(64, 69, 31);
potatoButton.BorderSizePixel = 0;
potatoButton.Font = Enum.Font.GothamBold;
potatoButton.Text = "POTATO MODE: OFF";
potatoButton.TextColor3 = Color3.fromRGB(255, 255, 255);
potatoButton.TextSize = 13;
potatoButton.Parent = main;
local potatoCorner = Instance.new("UICorner");
potatoCorner.CornerRadius = UDim.new(0, 9);
potatoCorner.Parent = potatoButton;
local function setStatus(text)
	if (not destroyed and statusLabel.Parent) then
		statusLabel.Text = text;
	end
end
local function formatRuntime(totalSeconds)
	local wholeSeconds = math.max(0, math.floor(totalSeconds));
	local hours = math.floor(wholeSeconds / 3600);
	local minutes = math.floor((wholeSeconds % 3600) / 60);
	local seconds = wholeSeconds % 60;
	return string.format("%02d:%02d:%02d", hours, minutes, seconds);
end
local function sampleMemoryMb()
	local ok, value = pcall(function()
		return Stats:GetTotalMemoryUsageMb();
	end);
	value = tonumber(value);
	if (not ok or not value or (value ~= value) or (value <= 0)) then
		return nil;
	end
	memoryCurrentMb = value;
	return value;
end
local function updateRuntimeLabel()
	if (destroyed or not runtimeLabel.Parent) then
		return;
	end
	local idleState = "OFF";
	if antiAfkEnabled then
		if not antiAfkMethodAvailable then
			idleState = "NO SIGNAL API";
		elseif (antiAfkPulses > 0) then
			idleState = "BACKGROUND ARMED";
		else
			idleState = "BACKGROUND READY";
		end
	end
	local memoryText = ((memoryCurrentMb > 0) and string.format("%dMB", math.floor(memoryCurrentMb + 0.5))) or "--";
	runtimeLabel.Text = string.format("Runtime: %s | RAM: %s\nAnti-AFK: %s | Guards: %d", formatRuntime(elapsedRunSeconds), memoryText, idleState, antiAfkPulses);
end
local function restoreIdleGuard()
	for index = #guardedIdleConnections, 1, -1 do
		local connection = guardedIdleConnections[index];
		pcall(function()
			connection:Enable();
		end);
	end
	table.clear(guardedIdleConnections);
	table.clear(guardedIdleConnectionSet);
	antiAfkPulses = 0;
end
local function maintainIdleGuard()
	if (not antiAfkEnabled or destroyed or not RELOAD_STATE.alive()) then
		return false;
	end
	antiAfkMethodAvailable = type(idleConnectionProvider) == "function";
	if not antiAfkMethodAvailable then
		updateRuntimeLabel();
		return false;
	end
	local ok, connections = pcall(idleConnectionProvider, player.Idled);
	if (not ok or (type(connections) ~= "table")) then
		antiAfkMethodAvailable = false;
		updateRuntimeLabel();
		return false;
	end
	local changed = false;
	for _, connection in ipairs(connections) do
		if not guardedIdleConnectionSet[connection] then
			local wasEnabled = true;
			pcall(function()
				wasEnabled = connection.Enabled ~= false;
			end);
			if wasEnabled then
				local disabled = pcall(function()
					connection:Disable();
				end);
				if disabled then
					guardedIdleConnectionSet[connection] = true;
					table.insert(guardedIdleConnections, connection);
					changed = true;
				end
			end
		end
	end
	lastAntiAfkAt = os.clock();
	antiAfkPulses = #guardedIdleConnections;
	updateRuntimeLabel();
	return changed or (antiAfkPulses > 0);
end
local function runRuntimeClock()
	local lastTick = os.clock();
	while not destroyed and gui.Parent and RELOAD_STATE.alive() do
		task.wait(1);
		local now = os.clock();
		if running then
			elapsedRunSeconds = elapsedRunSeconds + (now - lastTick);
		end
		if (antiAfkEnabled and ((now - lastAntiAfkAt) >= IDLE_GUARD_REFRESH_SECONDS)) then
			maintainIdleGuard();
		end
		lastTick = now;
		updateRuntimeLabel();
	end
end
local function formatCash(value)
	local digits = tostring(math.max(0, math.floor(tonumber(value) or 0)));
	local reversed = string.reverse(digits);
	local grouped = string.gsub(reversed, "(%d%d%d)", "%1,");
	local formatted = string.reverse(grouped);
	local cleaned = string.gsub(formatted, "^,", "");
	return cleaned;
end
local function updateStats()
	if (not destroyed and statsLabel.Parent) then
		statsLabel.Text = string.format("C: %d  •  D: %d  •  Left: %d  •  Claims: %d\nEarned: $%s", cycles, delivered, currentRemaining, autoClaims, formatCash(sessionEarnings));
	end
end
local function setButtonState(enabled)
	if (destroyed or not toggleButton.Parent) then
		return;
	end
	if enabled then
		toggleButton.Text = "STOP";
		toggleButton.BackgroundColor3 = Color3.fromRGB(184, 65, 73);
	else
		toggleButton.Text = "START";
		toggleButton.BackgroundColor3 = Color3.fromRGB(35, 145, 87);
	end
end
local function updateAntiAfkButton()
	if (destroyed or not antiAfkButton.Parent) then
		return;
	end
	if antiAfkEnabled then
		antiAfkButton.Text = "ANTI-AFK: ON  •  BACKGROUND";
		antiAfkButton.BackgroundColor3 = Color3.fromRGB(39, 139, 84);
	else
		antiAfkButton.Text = "ANTI-AFK: OFF";
		antiAfkButton.BackgroundColor3 = Color3.fromRGB(28, 55, 39);
	end
end
local function setAntiAfkEnabled(enabled)
	enabled = enabled == true;
	if (antiAfkEnabled == enabled) then
		if enabled then
			maintainIdleGuard();
		end
		updateAntiAfkButton();
		updateRuntimeLabel();
		return;
	end
	if not enabled then
		restoreIdleGuard();
	end
	antiAfkEnabled = enabled;
	RELOAD_STATE.antiKickEnabled = enabled;
	lastAntiAfkAt = -math.huge;
	if enabled then
		maintainIdleGuard();
	end
	updateAntiAfkButton();
	updateRuntimeLabel();
end
local function updatePotatoButton()
	if (destroyed or not potatoButton.Parent) then
		return;
	end
	if potatoMode then
		potatoButton.Text = string.format("POTATO MODE: ON  •  HEADLESS %d FPS", POTATO_FPS);
		potatoButton.BackgroundColor3 = Color3.fromRGB(38, 112, 70);
	else
		potatoButton.Text = "POTATO MODE: OFF";
		potatoButton.BackgroundColor3 = Color3.fromRGB(64, 69, 31);
	end
end
local function setPotatoMode(enabled, preservePreference)
	potatoMode = enabled;
	if not preservePreference then
		RELOAD_STATE.potatoEnabled = enabled;
	end
	if enabled then
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01;
		end);
		pcall(function()
			Lighting.GlobalShadows = false;
		end);
		pcall(function()
			if (type(setfpscap) == "function") then
				setfpscap(POTATO_FPS);
			end
		end);
		pcall(function()
			RunService:Set3dRenderingEnabled(false);
		end);
	else
		pcall(function()
			RunService:Set3dRenderingEnabled(true);
		end);
		pcall(function()
			if (type(setfpscap) == "function") then
				setfpscap(savedFpsCap);
			end
		end);
		pcall(function()
			settings().Rendering.QualityLevel = savedQualityLevel;
		end);
		pcall(function()
			Lighting.GlobalShadows = savedGlobalShadows;
		end);
	end
	updatePotatoButton();
end
local function isActive(token)
	return running and not destroyed and (gui.Parent ~= nil) and (workerToken == token) and RELOAD_STATE.alive();
end
local function interruptibleWait(seconds, token)
	local deadline = os.clock() + seconds;
	while isActive(token) and (os.clock() < deadline) do
		task.wait(math.min(0.5, deadline - os.clock()));
	end
	return isActive(token);
end
local function backgroundWait(seconds, token)
	local deadline = os.clock() + seconds;
	while isActive(token) and (os.clock() < deadline) do
		task.wait(math.min(BACKGROUND_WAIT_SLICE, deadline - os.clock()));
	end
	return isActive(token);
end
local remoteCallBusy = false;
local lastRemoteCallAt = -math.huge;
local function acquireRemoteSlot()
	while remoteCallBusy do
		task.wait(0.05);
	end
	remoteCallBusy = true;
	local remaining = REMOTE_MIN_GAP - (os.clock() - lastRemoteCallAt);
	if (remaining > 0) then
		task.wait(remaining);
	end
end
local function releaseRemoteSlot()
	lastRemoteCallAt = os.clock();
	remoteCallBusy = false;
end
local function invoke(remote, ...)
	local args = table.pack(...);
	acquireRemoteSlot();
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n));
	end);
	releaseRemoteSlot();
	if not ok then
		return false, result;
	end
	return true, result;
end
local function fire(remote, ...)
	local args = table.pack(...);
	acquireRemoteSlot();
	local ok, result = pcall(function()
		remote:FireServer(table.unpack(args, 1, args.n));
	end);
	releaseRemoteSlot();
	if not ok then
		return false, result;
	end
	return true, nil;
end
local function claimCompletedDailyTasks()
	local ok, dailyData = invoke(remotes.DailyTasksF);
	if not ok then
		error("Daily task refresh failed: " .. tostring(dailyData));
	end
	if ((type(dailyData) ~= "table") or (type(dailyData.Tasks) ~= "table")) then
		error("Daily task refresh returned invalid data");
	end
	local now = os.clock();
	for index = 1, 4 do
		local taskData = dailyData.Tasks[index];
		if (type(taskData) == "table") then
			if taskData.Claimed then
				if pendingClaims[index] then
					pendingClaims[index] = nil;
					autoClaims = autoClaims + 1;
					updateStats();
				end
				claimAttempts[index] = nil;
			elseif taskData.Completed then
				local lastAttempt = claimAttempts[index];
				if (not lastAttempt or ((now - lastAttempt) >= DAILY_TASK_RETRY_INTERVAL)) then
					local fired = fire(remotes.DailyTasksE, "Claim", index);
					if fired then
						claimAttempts[index] = now;
						pendingClaims[index] = true;
					end
				end
			else
				claimAttempts[index] = nil;
				pendingClaims[index] = nil;
			end
		end
	end
end
local function claimDailyLoginReward()
	local now = os.clock();
	if (now < nextDailyRewardCheckAt) then
		return;
	end
	local ok, rewardData = invoke(remotes.DailyRewards);
	if not ok then
		nextDailyRewardCheckAt = now + DAILY_REWARD_VERIFY_INTERVAL;
		error("Daily login reward refresh failed: " .. tostring(rewardData));
	end
	if (type(rewardData) ~= "table") then
		if dailyRewardPending then
			dailyRewardPending = false;
			autoClaims = autoClaims + 1;
			updateStats();
		end
		nextDailyRewardCheckAt = now + DAILY_REWARD_POLL_INTERVAL;
		return;
	end
	if (not dailyRewardPending or ((now - dailyRewardLastAttempt) >= DAILY_TASK_RETRY_INTERVAL)) then
		local fired, fireError = fire(remotes.DailyRewardsE);
		if not fired then
			nextDailyRewardCheckAt = now + DAILY_REWARD_VERIFY_INTERVAL;
			error("Daily login reward claim failed: " .. tostring(fireError));
		end
		dailyRewardPending = true;
		dailyRewardLastAttempt = now;
	end
	nextDailyRewardCheckAt = now + DAILY_REWARD_VERIFY_INTERVAL;
end
local function runAutoTaskClaimer(token)
	while isActive(token) do
		pcall(claimCompletedDailyTasks);
		pcall(claimDailyLoginReward);
		if not backgroundWait(DAILY_TASK_POLL_INTERVAL, token) then
			break;
		end
	end
end
local function routeCount(state)
	if ((type(state) ~= "table") or (type(state.ActiveLocations) ~= "table")) then
		return -1;
	end
	return #state.ActiveLocations;
end
local function waitForCondition(timeoutSeconds, token, callback)
	local deadline = os.clock() + timeoutSeconds;
	while isActive(token) and (os.clock() < deadline) do
		local value = callback();
		if value then
			return value;
		end
		task.wait(0.25);
	end
	return nil;
end
local function ensureJob(token)
	if (player.Team and (player.Team.Name == JOB_NAME)) then
		return true;
	end
	setStatus("Joining the Sahara Delivery Worker job...");
	local ok, result = invoke(remotes.ChangeJob, JOB_NAME);
	if not ok then
		error("ChangeJob failed: " .. tostring(result));
	end
	local joined = waitForCondition(10, token, function()
		return player.Team and (player.Team.Name == JOB_NAME);
	end);
	if not joined then
		error("Timed out while joining the Sahara job");
	end
	return true;
end
local validVehicleIds = {["4548"]=true,["4549"]=true,["4550"]=true};
local function getValidVan()
	local car = sessionVehicles:FindFirstChild(player.Name .. "-Car");
	if not car then
		return nil;
	end
	local carId = car:FindFirstChild("CarID");
	if (carId and carId:IsA("StringValue") and validVehicleIds[carId.Value]) then
		return car;
	end
	return nil;
end
local function ensureVan(token)
	local existing = getValidVan();
	if existing then
		return existing;
	end
	setStatus("Spawning the Sahara delivery van...");
	local ok, result = invoke(remotes.SpawnJobVehicle, {ID=VEHICLE_ID});
	if not ok then
		error("SpawnJobVehicle failed: " .. tostring(result));
	end
	local van = waitForCondition(15, token, getValidVan);
	if not van then
		error("The Sahara van did not spawn");
	end
	return van;
end
local function requestState()
	local ok, state = invoke(remotes.AmazonJob);
	if not ok then
		error("AmazonJob state request failed: " .. tostring(state));
	end
	if (type(state) ~= "table") then
		error("AmazonJob returned no route state");
	end
	return state;
end
local function beginOrResumeRoute(token)
	local state = requestState();
	local count = routeCount(state);
	if (count > 0) then
		currentRemaining = count;
		updateStats();
		setStatus("Resuming the active delivery route...");
		return state;
	end
	local boxAmount = tonumber(state.BoxAmount) or 0;
	setStatus(string.format("Loading %d Sahara packages into the van...", boxAmount));
	local ok, loadedState = invoke(remotes.AmazonJob, {"GL"});
	if not ok then
		error("Package loading failed: " .. tostring(loadedState));
	end
	if ((type(loadedState) == "table") and (routeCount(loadedState) > 0)) then
		currentRemaining = routeCount(loadedState);
		updateStats();
		return loadedState;
	end
	local nextStatePollAt = 0;
	local ready = waitForCondition(10, token, function()
		local now = os.clock();
		if (now < nextStatePollAt) then
			return nil;
		end
		nextStatePollAt = now + ROUTE_STATE_POLL_INTERVAL;
		local nextState = requestState();
		if (routeCount(nextState) > 0) then
			return nextState;
		end
		return nil;
	end);
	if not ready then
		error("The server did not start a delivery route");
	end
	currentRemaining = routeCount(ready);
	updateStats();
	return ready;
end
local function waitForBonus(serialBefore, token)
	setStatus("Route complete — waiting for the completion bonus...");
	local deadline = os.clock() + BONUS_TIMEOUT;
	while isActive(token) and (completionSerial <= serialBefore) and (os.clock() < deadline) do
		task.wait(0.2);
	end
	if ((completionSerial <= serialBefore) and isActive(token)) then
		setStatus("Completion signal delayed; syncing the route state...");
		local ok, state = pcall(requestState);
		if (ok and (routeCount(state) == 0)) then
			cycles = cycles + 1;
			currentRemaining = 0;
			updateStats();
			setStatus("Route completion synced. Preparing the next package load...");
			interruptibleWait(randomBetween(POST_BONUS_DELAY_MIN, POST_BONUS_DELAY_MAX), token);
			return true;
		end
		interruptibleWait(randomBetween(2.5, 4), token);
		return false;
	end
	if isActive(token) then
		cycles = cycles + 1;
		currentRemaining = 0;
		updateStats();
		setStatus("Bonus confirmed. Preparing the next package load...");
		interruptibleWait(randomBetween(POST_BONUS_DELAY_MIN, POST_BONUS_DELAY_MAX), token);
	end
	return true;
end
local function deliverRoute(initialState, token)
	local state = initialState;
	local rejectionStreak = 0;
	while isActive(token) do
		local beforeCount = routeCount(state);
		if (beforeCount <= 0) then
			return true;
		end
		currentRemaining = beforeCount;
		updateStats();
		ensureJob(token);
		ensureVan(token);
		local cooldownRemaining = nextDeliveryAttemptAt - os.clock();
		if (cooldownRemaining > 0) then
			setStatus(string.format("Server delivery window — ready in %.1fs...", cooldownRemaining));
			if not interruptibleWait(cooldownRemaining, token) then
				return false;
			end
		end
		setStatus(string.format("Delivering package %d — %d stops remaining...", delivered + 1, beforeCount));
		local target = state.ActiveLocations[1];
		local targetPosition = nil;
		if (typeof(target) == "CFrame") then
			targetPosition = target.Position;
		elseif (typeof(target) == "Vector3") then
			targetPosition = target;
		elseif (type(target) == "table") then
			targetPosition = target.Position;
		end
		if (typeof(targetPosition) ~= "Vector3") then
			error("The current route target is invalid");
		end
		local serialBefore = completionSerial;
		local ok, response = invoke(remotes.AmazonJob, {"C",targetPosition});
		if not ok then
			rejectionStreak = math.min(rejectionStreak + 1, 4);
			setStatus("Delivery request failed; retrying...");
			local retryDelay = NETWORK_RETRY_DELAY + (rejectionStreak * 0.5) + (math.random() * 0.5);
			if not interruptibleWait(retryDelay, token) then
				return false;
			end
			state = requestState();
		else
			local afterCount = routeCount(response);
			if (afterCount == (beforeCount - 1)) then
				rejectionStreak = 0;
				delivered = delivered + 1;
				currentRemaining = afterCount;
				nextDeliveryAttemptAt = os.clock() + nextDeliveryCooldown();
				updateStats();
				if (afterCount == 0) then
					return waitForBonus(serialBefore, token);
				end
				setStatus(string.format("Delivery accepted. Cooling down — %d stops remain...", afterCount));
				state = response;
			else
				rejectionStreak = math.min(rejectionStreak + 1, 4);
				local retryDelay = math.min(SERVER_COOLDOWN_RETRY_MAX, SERVER_COOLDOWN_RETRY_MIN + ((rejectionStreak - 1) * 0.7) + (math.random() * 0.5));
				setStatus(string.format("Server delivery window active; checking again in %.1fs...", retryDelay));
				nextDeliveryAttemptAt = os.clock() + retryDelay;
				if not interruptibleWait(retryDelay, token) then
					return false;
				end
				state = ((type(response) == "table") and response) or requestState();
			end
		end
	end
	return false;
end
local function runWorker(token)
	while isActive(token) do
		local ok, result = pcall(function()
			ensureJob(token);
			ensureVan(token);
			local state = beginOrResumeRoute(token);
			return deliverRoute(state, token);
		end);
		if not isActive(token) then
			break;
		end
		if not ok then
			setStatus("Error: " .. tostring(result) .. " — retrying shortly");
			if not interruptibleWait(randomBetween(3, 4.5), token) then
				break;
			end
		elseif (result == false) then
			if not interruptibleWait(randomBetween(2.5, 4), token) then
				break;
			end
		end
	end
end
local function stopWorker(message)
	running = false;
	workerToken = workerToken + 1;
	setButtonState(false);
	updateRuntimeLabel();
	currentRemaining = 0;
	updateStats();
	setStatus(message or "Stopped. The current route can be resumed later.");
end
local function runMemoryGuard(token)
	while isActive(token) do
		if not backgroundWait(MEMORY_SAMPLE_INTERVAL, token) then
			break;
		end
		local current = sampleMemoryMb();
		if current then
			if (memoryBaselineMb <= 0) then
				memoryBaselineMb = current;
			end
			updateRuntimeLabel();
			local excessiveTotal = current >= MEMORY_ABSOLUTE_LIMIT_MB;
			local excessiveGrowth = (current - memoryBaselineMb) >= MEMORY_GROWTH_LIMIT_MB;
			if (excessiveTotal or excessiveGrowth) then
				setAntiAfkEnabled(false);
				stopWorker(string.format("Memory guard stopped automation at %d MB.", math.floor(current + 0.5)));
				break;
			end
		end
	end
end
local function startWorker()
	if running then
		return;
	end
	elapsedRunSeconds = 0;
	sessionEarnings = 0;
	lastObservedMoney = tonumber(player:GetAttribute("Money")) or lastObservedMoney;
	memoryCurrentMb = sampleMemoryMb() or memoryCurrentMb;
	memoryBaselineMb = memoryCurrentMb;
	running = true;
	workerToken = workerToken + 1;
	local token = workerToken;
	setButtonState(true);
	updateRuntimeLabel();
	setStatus("Starting Sahara automation...");
	task.spawn(function()
		runWorker(token);
	end);
	task.spawn(function()
		runAutoTaskClaimer(token);
	end);
	task.spawn(function()
		runMemoryGuard(token);
	end);
end
RELOAD_STATE.connect(remotes.SaharaJob.OnClientEvent, function()
	completionSerial = completionSerial + 1;
end);
RELOAD_STATE.connect(player:GetAttributeChangedSignal("Money"), function()
	local currentMoney = tonumber(player:GetAttribute("Money"));
	if not currentMoney then
		return;
	end
	if (running and (currentMoney > lastObservedMoney)) then
		sessionEarnings = sessionEarnings + (currentMoney - lastObservedMoney);
	end
	lastObservedMoney = currentMoney;
	updateStats();
end);
task.spawn(runRuntimeClock);
RELOAD_STATE.connect(toggleButton.Activated, function()
	if running then
		stopWorker();
	else
		startWorker();
	end
end);
RELOAD_STATE.connect(antiAfkButton.Activated, function()
	setAntiAfkEnabled(not antiAfkEnabled);
end);
RELOAD_STATE.connect(potatoButton.Activated, function()
	setPotatoMode(not potatoMode);
end);
RELOAD_STATE.connect(shutdownEvent.Event, function()
	if destroyed then
		return;
	end
	setPotatoMode(false);
	setAntiAfkEnabled(false);
	stopWorker("Replaced by a newer Sahara runtime");
	destroyed = true;
	if gui.Parent then
		gui:Destroy();
	end
	standaloneCleanup();
end);
RELOAD_STATE.connect(closeButton.Activated, function()
	setPotatoMode(false);
	setAntiAfkEnabled(false);
	stopWorker("Closed");
	destroyed = true;
	gui:Destroy();
	standaloneCleanup();
end);
local dragging = false;
local dragStart = Vector2.zero;
local startPosition = main.Position;
RELOAD_STATE.connect(header.InputBegan, function(input)
	if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
		dragging = true;
		dragStart = input.Position;
		startPosition = main.Position;
	end
end);
RELOAD_STATE.connect(UserInputService.InputEnded, function(input)
	if ((input.UserInputType == Enum.UserInputType.MouseButton1) or (input.UserInputType == Enum.UserInputType.Touch)) then
		dragging = false;
	end
end);
RELOAD_STATE.connect(UserInputService.InputChanged, function(input)
	if not dragging then
		return;
	end
	if ((input.UserInputType == Enum.UserInputType.MouseMovement) or (input.UserInputType == Enum.UserInputType.Touch)) then
		local delta = input.Position - dragStart;
		main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y);
	end
end);
if antiAfkEnabled then
	maintainIdleGuard();
end
RELOAD_STATE.antiKickEnabled = antiAfkEnabled;
updateRuntimeLabel();
updateAntiAfkButton();
setPotatoMode(potatoMode);
RELOAD_STATE.onCleanup(function()
	setPotatoMode(false, true);
	running = false;
	local preserveIdleGuard = antiAfkEnabled;
	setAntiAfkEnabled(false);
	RELOAD_STATE.antiKickEnabled = preserveIdleGuard;
	workerToken = workerToken + 1;
	destroyed = true;
	if gui.Parent then
		gui:Destroy();
	end
end);