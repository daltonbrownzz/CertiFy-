local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Remotes = ReplicatedStorage:WaitForChild("CertiFyRemotes")
local RequestCerts = Remotes:WaitForChild("RequestCerts")
local AddCert = Remotes:WaitForChild("AddCert")
local RemoveCert = Remotes:WaitForChild("RemoveCert")
local GetAuditLog = Remotes:WaitForChild("GetAuditLog")
local NotifyClients = Remotes:FindFirstChild("NotifyClients")

-- UI
local frame = script.Parent
local overviewTab = frame:WaitForChild("OverviewTab")
local addRemoveTab = frame:WaitForChild("AddRemoveTab")
local auditTab = frame:WaitForChild("AuditTab")

local certList = overviewTab:WaitForChild("CertList")
local userBox = addRemoveTab:WaitForChild("UserBox")
local certDropdown = addRemoveTab:WaitForChild("CertDropdown")
local submitBtn = addRemoveTab:WaitForChild("SubmitBtn")
local revokeBtn = addRemoveTab:WaitForChild("RevokeBtn")
local outputLabel = addRemoveTab:WaitForChild("OutputLabel")
local auditLogLabel = auditTab:WaitForChild("AuditLog")

-- Tabs
local tabs = {
	Overview = {
		Button = frame.TabButtonsFrame:WaitForChild("OverviewBtn"),
		Tab = overviewTab
	},
	AddRemove = {
		Button = frame.TabButtonsFrame:WaitForChild("AddRemoveBtn"),
		Tab = addRemoveTab
	},
	Audit = {
		Button = frame.TabButtonsFrame:WaitForChild("AuditBtn"),
		Tab = auditTab
	}
}

-- Switch tab with animation
local function switchTab(tabName)
	for name, data in pairs(tabs) do
		local tab = data.Tab
		if name == tabName then
			tab.Visible = true
			tab.BackgroundTransparency = 1

			local fadeIn = TweenService:Create(tab, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
			fadeIn:Play()
		else
			if tab.Visible then
				local fadeOut = TweenService:Create(tab, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
				fadeOut:Play()
				fadeOut.Completed:Connect(function()
					tab.Visible = false
				end)
			end
		end
	end
end

switchTab("Overview")

for name, data in pairs(tabs) do
	data.Button.MouseButton1Click:Connect(function()
		switchTab(name)
	end)
end

-- Overview: show all certified users
local function updateCertList()
	local success, certLines = pcall(function()
		return RequestCerts:InvokeServer()
	end)

	if success and typeof(certLines) == "table" then
		certList.Text = table.concat(certLines, "\n")
	else
		warn("❌ Failed to update certification list:", certLines)
		certList.Text = "❌ Failed to load certifications."
	end
end

-- Audit tab
local function updateAuditLog()
	local success, result = pcall(function()
		return GetAuditLog:InvokeServer()
	end)

	if success then
		auditLogLabel.Text = result
	else
		warn("❌ Failed to update audit log:", result)
		auditLogLabel.Text = "❌ Failed to load audit log."
	end
end

-- Add cert
submitBtn.MouseButton1Click:Connect(function()
	local username = userBox.Text
	local cert = certDropdown.Text
	local userId

	local ok, err = pcall(function()
		userId = Players:GetUserIdFromNameAsync(username)
	end)

	if not ok or not userId then
		outputLabel.Text = "❌ Invalid username."
		warn("❌ Failed to get userId for:", username, err)
		return
	end

	AddCert:FireServer(userId, cert)
	outputLabel.Text = "✅ Certification added (if valid)."
end)

-- Revoke cert
revokeBtn.MouseButton1Click:Connect(function()
	local username = userBox.Text
	local cert = certDropdown.Text
	local userId

	local ok, err = pcall(function()
		userId = Players:GetUserIdFromNameAsync(username)
	end)

	if not ok or not userId then
		outputLabel.Text = "❌ Invalid username."
		warn("❌ Failed to get userId for:", username, err)
		return
	end

	RemoveCert:FireServer(userId, cert)
	outputLabel.Text = "❌ Certification removed (if it existed)."
end)

-- Auto-refresh on server update
if NotifyClients then
	NotifyClients.OnClientEvent:Connect(function()
		if overviewTab.Visible then updateCertList() end
		if auditTab.Visible then updateAuditLog() end
	end)
end

-- Initial fetch
updateCertList()
updateAuditLog()

-- Backup polling every 3s
task.spawn(function()
	while true do
		task.wait(3)
		if overviewTab.Visible then updateCertList() end
		if auditTab.Visible then updateAuditLog() end
	end
end)


