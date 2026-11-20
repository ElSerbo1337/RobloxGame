--!strict
-- 3D sign texts in each player's language (#71): the server only stores a text key and
-- its arguments on the TextLabel (attributes TextKey, TextArgs as JSON, tag "SignText");
-- src/client/SignTexts.luau shows the text in the player's language. The label's own
-- Text is the German version, so German looks exactly as before.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Texts = require(ReplicatedStorage.Shared.Texts)

local SignText = {}

SignText.TAG = "SignText"

function SignText.set(label: TextLabel, key: string, args: Texts.SignArgs?)
	local text = Texts.render("de", key, args)
	if label.Text ~= text then
		label.Text = text
	end
	label:SetAttribute("TextArgs", if args then HttpService:JSONEncode(args) else nil)
	label:SetAttribute("TextKey", key)
	if not CollectionService:HasTag(label, SignText.TAG) then
		CollectionService:AddTag(label, SignText.TAG)
	end
end

return SignText
