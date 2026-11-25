--!strict
-- "Was ist neu" window (#106, feature "whatsNew"): the MEGA UPDATE news, the same list
-- as the "Neu im Update!" board on the spawn island.
-- * Opens by itself once per player: until the player closed it with "Los geht's!" or
--   "X", which sends the wish HintSeen(GameConfig.spawnMarket.whatsNewHint); the server
--   remembers it in the PlayerState (attribute SeenHints). Waits for the end of the
--   tutorial and for the login calendar window, so it never covers them. Closed by
--   another menu (one menu at a time), it comes again on the next join.
-- * The ProximityPrompt "WhatsNewPrompt" on the update board opens it again any time.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage.Shared.Features)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Net = require(ReplicatedStorage.Shared.Net)
local Lang = require(script.Parent.Lang)
local LoginCalendarMenu = require(script.Parent.LoginCalendarMenu)
local UiKit = require(script.Parent.UiKit)

local PANEL_SIZE = Vector2.new(640, 600)
local PROMPT_NAME = "WhatsNewPrompt"

local WhatsNewMenu = {}

function WhatsNewMenu.start()
	if not Features.new(GameConfig.features).enabled("whatsNew") then
		return
	end
	local player = Players.LocalPlayer
	local hint = GameConfig.spawnMarket.whatsNewHint
	local hintSeen = Net.event("HintSeen")

	local gui = Instance.new("ScreenGui")
	gui.Name = "WhatsNewMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	UiKit.autoScale(gui)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = UiKit.CREAM
	panel.Visible = false
	UiKit.corner(panel, 24)
	UiKit.stroke(panel, 4)
	UiKit.placeMenu(gui, panel, PANEL_SIZE)

	local title = UiKit.label(panel, Lang.t("whatsNew.title"))
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.new(1, -120, 0, 52)

	local subtitle = UiKit.label(panel, Lang.t("whatsNew.subtitle"))
	subtitle.Position = UDim2.fromOffset(24, 68)
	subtitle.Size = UDim2.new(1, -48, 0, 36)
	subtitle.TextColor3 = UiKit.ORANGE

	local list = UiKit.label(panel, Lang.t("whatsNew.list"))
	list.Name = "List"
	list.Position = UDim2.fromOffset(32, 118)
	list.Size = UDim2.new(1, -64, 0, 370)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.LineHeight = 1.15

	local closeButton = UiKit.button(panel, "X", UiKit.RED)
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.fromOffset(72, 72)

	local okButton = UiKit.button(panel, Lang.t("whatsNew.ok"), UiKit.GREEN)
	okButton.Name = "Ok"
	okButton.AnchorPoint = Vector2.new(0.5, 1)
	okButton.Position = UDim2.new(0.5, 0, 1, -18)
	okButton.Size = UDim2.fromOffset(300, 68)

	gui.Parent = player:WaitForChild("PlayerGui")

	local function seen(): boolean
		local hints = player:GetAttribute("SeenHints")
		return type(hints) == "string" and table.find(string.split(hints, ","), hint) ~= nil
	end

	local function close()
		panel.Visible = false
	end
	UiKit.registerMenu("whatsNew", close)

	local function open()
		panel.Visible = true
		UiKit.menuOpened("whatsNew")
		UiKit.pop(panel)
	end

	-- Closed by the player: never opens by itself again.
	local function dismiss()
		close()
		if not seen() then
			hintSeen:FireServer(hint)
		end
	end
	closeButton.Activated:Connect(dismiss)
	okButton.Activated:Connect(function()
		UiKit.pop(okButton)
		dismiss()
	end)

	-- Update board on the spawn island: prompt text in the player's language, opens the window.
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == PROMPT_NAME then
			prompt.ActionText = Lang.t("whatsNew.prompt")
			prompt.ObjectText = Lang.t("whatsNew.board")
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if prompt.Name == PROMPT_NAME and who == player then
			open()
		end
	end)

	-- Once per player: after the state arrived, the tutorial and the login calendar.
	task.spawn(function()
		while player:GetAttribute("SeenHints") == nil do
			task.wait(1)
		end
		if seen() then
			return
		end
		local hadTutorial = false
		while player:GetAttribute("TutorialStep") ~= "" do
			hadTutorial = true
			task.wait(1)
		end
		-- After the tutorial the login calendar opens 5 s later; let it go first.
		task.wait(if hadTutorial then 8 else 3)
		while LoginCalendarMenu.isOpen() do
			task.wait(1)
		end
		if not seen() and not panel.Visible then
			open()
		end
	end)
end

return WhatsNewMenu
