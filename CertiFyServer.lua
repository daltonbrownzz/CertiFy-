--[[
	CertiFy Handler
	Handles certification requests, audit logging, and Discord webhook notifications.
	Author: @daltn
]]

local Parcel = require(9428572121)

if Parcel:Whitelist("67d76d29d04c4b125a25bc8c", "po7n68nafidv5zgbiyrg9maaono2") then

	-- Services
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")

	-- Modules
	local Config, Data
	do
		local success, result = pcall(function()
			return require(ReplicatedStorage:WaitForChild("CertiFyConfig"))
		end)
		if not success then
			error("❌ Failed to load CertiFyConfig.")
		end
		Config = result
	end

	do
		local success, result = pcall(function()
			return require(script.Parent:WaitForChild("CertiFyData"))
		end)
		if not success then 
			error("❌ Failed to load CertiFyData.")
		end
		Data = result
	end

	-- Constants
	local WEBHOOK_URL = Config.WebhookUrl
	local MAX_AUDIT_LOG_ENTRIES = 50

	-- Variables
	local AuditLog = {}

	-- Remotes
	local RemotesFolder = ReplicatedStorage:FindFirstChild("CertiFyRemotes")
	if not RemotesFolder then
		error("❌ CertiFyRemotes folder is missing in ReplicatedStorage.")
	end

	local RequestCerts = RemotesFolder:FindFirstChild("RequestCerts")
	local AddCert = RemotesFolder:FindFirstChild("AddCert")
	local RemoveCert = RemotesFolder:FindFirstChild("RemoveCert")
	local GetAuditLog = RemotesFolder:FindFirstChild("GetAuditLog")
	local NotifyClients = RemotesFolder:FindFirstChild("NotifyClients")

	if not (RequestCerts and AddCert and RemoveCert and GetAuditLog and NotifyClients) then
		error("❌ One or more remote events/functions are missing in CertiFyRemotes.")
	end

	--// Functions

	local function sendEmbedNotification(message)
		local data = {
			embeds = { {
				title = "CertiFy Notification",
				description = message,
				color = 0xFFA500, -- Orange
				fields = {
					{ name = "Status", value = "Certification updated!", inline = true },
					{ name = "Details", value = message, inline = true }
				},
				footer = { text = "CertiFy System" },
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
			} }
		}

		local jsonData = HttpService:JSONEncode(data)
		local success, response = pcall(function()
			HttpService:PostAsync(WEBHOOK_URL, jsonData, Enum.HttpContentType.ApplicationJson)
		end)

		if not success then
			warn("❌ Failed to send webhook: " .. response)
		end
	end

	--// Remote Event Handlers

	RequestCerts.OnServerInvoke = function(player)
		local success, result = pcall(function()
			return Data.GetAllCertifiedUsers()
		end)
		if success then
			return result
		else
			warn("❌ Failed to fetch certification data.")
			return {}
		end
	end

	AddCert.OnServerEvent:Connect(function(player, userId, cert)
		if typeof(userId) ~= "number" or typeof(cert) ~= "string" then
			warn("❌ Invalid add certification request from:", player.Name)
			return
		end

		local success = pcall(function()
			Data.AddCert(userId, cert)
		end)

		if success then
			table.insert(AuditLog, player.Name .. " added '" .. cert .. "' to userId " .. userId)
			NotifyClients:FireAllClients()
			sendEmbedNotification(player.Name .. " added the '" .. cert .. "' certification to userId " .. userId)
		else
			warn("❌ Failed to add certification:", cert, "to", userId)
		end
	end)

	RemoveCert.OnServerEvent:Connect(function(player, userId, cert)
		if typeof(userId) ~= "number" or typeof(cert) ~= "string" then
			warn("❌ Invalid remove certification request from:", player.Name)
			return
		end

		local success = pcall(function()
			Data.RemoveCert(userId, cert)
		end)

		if success then
			table.insert(AuditLog, player.Name .. " removed '" .. cert .. "' from userId " .. userId)
			NotifyClients:FireAllClients()
			sendEmbedNotification(player.Name .. " removed the '" .. cert .. "' certification from userId " .. userId)
		else
			warn("❌ Failed to remove certification:", cert, "from", userId)
		end
	end)

	GetAuditLog.OnServerInvoke = function(player)
		local log = {}
		for i = math.max(1, #AuditLog - MAX_AUDIT_LOG_ENTRIES + 1), #AuditLog do
			table.insert(log, AuditLog[i])
		end
		return table.concat(log, "\n")
	end

	--// Initialization Log
	print("\n==========[ CertiFy System Loaded ]==========")
	print("✔️  Status: Initialized successfully")
	print("👤  Developer: dalton_brownzz")
	print("📦  Module: CertiFy Handler")
	print("🕒  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
	print("=============================================\n")

	--// Global Kill Switch via GitHub JSON
	task.spawn(function()
		local url = "https://raw.githubusercontent.com/daltonbrownzz/CertiFy-/main/certify-status.json"
		local success, result = pcall(function()
			return HttpService:GetAsync(url)
		end)

		if success then
			print("Successfully fetched GitHub status.")
			local decoded = HttpService:JSONDecode(result)
			print("Decoded JSON: ", decoded)
			if decoded and decoded.certifyEnabled == false then
				warn("⚠️ CertiFy is disabled globally. Destroying handler...")
				script:Destroy()
			else
				print("✅ CertiFy is enabled.")
			end
		else
			warn("⚠️ Failed to fetch CertiFy toggle. Assuming enabled.")
		end
	end)
end
