local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
-- Load Config
local Config = require(ReplicatedStorage:WaitForChild("CertiFyConfig"))

-- Setup group-specific DataStore and keys
local CertData = DataStoreService:GetDataStore("CertiFyDataStore_" .. tostring(Config.GroupId))
local UserListKey = "__UserIdList_" .. tostring(Config.GroupId)

local CertiFyData = {}

-- Fetch a single user's certifications
function CertiFyData.GetPlayerCerts(userId)
	if typeof(userId) ~= "number" then return {} end

	local success, data = pcall(function()
		return CertData:GetAsync(tostring(userId))
	end)

	if not success then
		warn("❌ Failed to fetch certifications for userId:", userId, "Error:", data)
	end

	return (success and type(data) == "table") and data or {}
end

-- Save a single user's certifications
function CertiFyData.SavePlayerCerts(userId, certs)
	if typeof(userId) ~= "number" or typeof(certs) ~= "table" then return end

	local success, err = pcall(function()
		CertData:SetAsync(tostring(userId), certs)
	end)

	if not success then
		warn("❌ Failed to save certifications for userId:", userId, "Error:", err)
	end
end

-- Add a user ID to the tracked certified users list
local function addUserIdToList(userId)
	local success, userList = pcall(function()
		return CertData:GetAsync(UserListKey)
	end)

	if not success then
		warn("❌ Failed to retrieve certified user list:", userList)
		userList = {}
	end

	userList = (type(userList) == "table") and userList or {}

	if not table.find(userList, userId) then
		table.insert(userList, userId)

		local saveSuccess, saveErr = pcall(function()
			CertData:SetAsync(UserListKey, userList)
		end)

		if not saveSuccess then
			warn("❌ Failed to update certified user list:", saveErr)
		end
	end
end

-- Remove a user ID from the certified users list if they have no certifications left
local function removeUserIdFromList(userId)
	local success, userList = pcall(function()
		return CertData:GetAsync(UserListKey)
	end)

	if success and typeof(userList) == "table" then
		local index = table.find(userList, userId)
		if index then
			table.remove(userList, index)

			local saveSuccess, saveErr = pcall(function()
				CertData:SetAsync(UserListKey, userList)
			end)

			if not saveSuccess then
				warn("❌ Failed to update certified user list after removal:", saveErr)
			end
		end
	end
end

-- Add a certification to a user
function CertiFyData.AddCert(userId, cert)
	if typeof(userId) ~= "number" or typeof(cert) ~= "string" then return end

	local certs = CertiFyData.GetPlayerCerts(userId)

	if not table.find(certs, cert) then
		table.insert(certs, cert)
		CertiFyData.SavePlayerCerts(userId, certs)
		addUserIdToList(userId)
		print("✅ Added certification '" .. cert .. "' to userId:", userId)
	end
end

-- Remove a certification from a user
function CertiFyData.RemoveCert(userId, cert)
	if typeof(userId) ~= "number" or typeof(cert) ~= "string" then return end

	local certs = CertiFyData.GetPlayerCerts(userId)
	local index = table.find(certs, cert)

	if index then
		table.remove(certs, index)

		if #certs > 0 then
			CertiFyData.SavePlayerCerts(userId, certs)
		else
			local success, err = pcall(function()
				CertData:RemoveAsync(tostring(userId))
			end)

			if not success then
				warn("❌ Failed to delete certifications for userId:", userId, "Error:", err)
			end

			removeUserIdFromList(userId)
		end

		print("✅ Removed certification '" .. cert .. "' from userId:", userId)
	end
end

-- Get all certified users and their certifications
function CertiFyData.GetAllCertifiedUsers()
	local result = {}

	local success, userList = pcall(function()
		return CertData:GetAsync(UserListKey)
	end)

	if not success then
		warn("❌ Failed to retrieve certified user list:", userList)
		return result
	end

	if typeof(userList) == "table" then
		for _, userId in ipairs(userList) do
			local certs = CertiFyData.GetPlayerCerts(userId)

			if #certs > 0 then
				local name
				local nameSuccess, nameErr = pcall(function()
					name = Players:GetNameFromUserIdAsync(userId)
				end)

				if nameSuccess then
					table.insert(result, name .. ": " .. table.concat(certs, ", "))
				else
					warn("❌ Failed to retrieve player name for userId:", userId, "Error:", nameErr)
					table.insert(result, "UserId " .. userId .. ": " .. table.concat(certs, ", "))
				end
			end
		end
	end

	return result
end




return CertiFyData
