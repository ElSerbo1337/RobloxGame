--!strict
-- Fills every server-built 3D sign (#71) in this player's language: TextLabels tagged
-- "SignText" carry a text key (attribute TextKey) and its arguments (TextArgs, JSON;
-- see Texts.render). Signs added later and changed keys/arguments are followed too.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Lang = require(script.Parent.Lang)

local TAG = "SignText"

local SignTexts = {}

local function render(label: TextLabel)
	local key = label:GetAttribute("TextKey")
	if type(key) ~= "string" then
		return
	end
	local args = nil
	local raw = label:GetAttribute("TextArgs")
	if type(raw) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then
			args = decoded
		end
	end
	local text = Lang.render(key, args)
	if label.Text ~= text then
		label.Text = text
	end
end

local function watch(instance: Instance)
	if not instance:IsA("TextLabel") then
		return
	end
	local label = instance :: TextLabel
	render(label)
	label:GetAttributeChangedSignal("TextKey"):Connect(function()
		render(label)
	end)
	label:GetAttributeChangedSignal("TextArgs"):Connect(function()
		render(label)
	end)
	-- The server writes the German text; replace it again whenever it arrives.
	label:GetPropertyChangedSignal("Text"):Connect(function()
		render(label)
	end)
end

function SignTexts.start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	for _, instance in CollectionService:GetTagged(TAG) do
		watch(instance)
	end
end

return SignTexts
