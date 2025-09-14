local ADDON_NAME = ... ---@type string
local Addon = select(2, ...) ---@type Addon
local Actions = Addon:GetModule("Actions")
local Colors = Addon:GetModule("Colors")
local Commands = Addon:GetModule("Commands")
local JunkFilter = Addon:GetModule("JunkFilter")
local L = Addon:GetModule("Locale")
local StateManager = Addon:GetModule("StateManager")
local TSM = Addon:GetModule("TSM")
local TickerManager = Addon:GetModule("TickerManager")
local Widgets = Addon:GetModule("Widgets")

local TSM_JUNK_TEXT_FORMAT = Colors.Grey("(%s)"):format(Colors.White("%s"))
local PROFIT_TEXT_FORMAT = Colors.Grey("(%s, %s)")
local LABEL_TEXT_FORMAT = Colors.Grey("(%s/%s)"):format(Colors.White("%s"), Colors.Red("%s"))

-- ============================================================================
-- Local Functions
-- ============================================================================

local function GetMoneyStringNoCopper(amount)
  if not amount or amount <= 0 then return "" end
  local gold = floor(amount / 10000)
  local silver = floor(amount / 100) % 100

  local goldString = gold > 0 and ("%d|T%s:0|t"):format(gold, "Interface\\MoneyFrame\\UI-GoldIcon") or ""
  local silverString = silver > 0 and ("%d|T%s:0|t"):format(silver, "Interface\\MoneyFrame\\UI-SilverIcon") or ""

  if gold > 0 and silver > 0 then
    return goldString .. " " .. silverString
  end
  return goldString .. silverString
end

-- ============================================================================
-- Initialize
-- ============================================================================

--- @class MerchantButtonWidget : ButtonWidget
local frame = Widgets:Button({
  name = ADDON_NAME .. "_MerchantButton",
  parent = _G.MerchantFrame,
  width = 108,
  labelText = LABEL_TEXT_FORMAT:format(0, 0),
  labelColor = Colors.Blue,
  enableClickHandling = true,
  enableDragging = true,
  onUpdateTooltip = function(this, tooltip)
    tooltip:SetOwner(this, "ANCHOR_RIGHT")

    if IsAltKeyDown() then
      local item = JunkFilter:GetNextDestroyableJunkItem()
      if item then
        tooltip:SetBagItem(item.bag, item.slot)
        tooltip:AddLine(" ")
        tooltip:AddDoubleLine(L.RIGHT_CLICK, Colors.Red(L.DESTROY))
        tooltip:Show()
        return
      end
    end

    tooltip:AddDoubleLine(Colors.Blue(ADDON_NAME), Colors.Grey(Addon.VERSION))
    tooltip:AddLine(Addon:SubjectDescription(L.LEFT_CLICK, L.START_SELLING))
    tooltip:AddLine(Addon:SubjectDescription(L.RIGHT_CLICK, L.TOGGLE_OPTIONS_FRAME))
    tooltip:AddLine(Addon:SubjectDescription(Addon:Concat("+", L.CONTROL_KEY, L.LEFT_CLICK), L.START_SELLING .. " TSM Junk"))
    tooltip:AddLine(Addon:SubjectDescription(Addon:Concat("+", L.SHIFT_KEY, L.LEFT_CLICK), L.TOGGLE_JUNK_FRAME))
    tooltip:AddLine(Addon:SubjectDescription(Addon:Concat("+", L.SHIFT_KEY, L.RIGHT_CLICK), L.RESET_POSITION))
    tooltip:AddLine(Addon:SubjectDescription(Addon:Concat("+", L.ALT_KEY, L.RIGHT_CLICK), Colors.Red(L.DESTROY_NEXT_ITEM)))
    tooltip:Show()
  end
})

Widgets:ConfigureForPointSync(frame, "MerchantButton")

-- Click handlers.
frame:SetClickHandler("LeftButton", "NONE", Commands.sell)
frame:SetClickHandler("LeftButton", "SHIFT", Commands.junk)
frame:SetClickHandler("LeftButton", "CONTROL", Commands.sellTsm)
frame:SetClickHandler("RightButton", "NONE", Commands.options)
frame:SetClickHandler("RightButton", "SHIFT", function()
  StateManager:Dispatch(Actions:ResetMerchantButtonPoint())
end)
frame:SetClickHandler("RightButton", "ALT", Commands.destroy)

-- Child frame.
frame.childFrame = Widgets:Frame({
  name = "$parent_ChildFrame",
  parent = frame,
  points = { { "CENTER" } }
})
frame.childFrame:SetBackdrop(nil)

-- Icon.
frame.icon = frame:CreateTexture("$parent_Icon", "ARTWORK")
frame.icon:SetTexture(Addon:GetAsset("dejunk-icon"))
frame.icon:SetPoint("LEFT", frame.childFrame)
local iconSize = math.floor(frame:GetHeight()) - Widgets:Padding(0.5)
frame.icon:SetSize(iconSize, iconSize)

-- Reposition the label.
frame.label:ClearAllPoints()
frame.label:SetPoint("LEFT", frame.icon, "RIGHT", 0, 0)
frame.label:SetJustifyH("LEFT")

-- OnUpdate.
frame:HookScript("OnUpdate", function(_, elapsed)
  frame:SetEnabled(not Addon:IsBusy())

  frame.delayTimer = (frame.delayTimer or 0.1) + elapsed
  if frame.delayTimer < 0.1 then return end
  frame.delayTimer = 0

  -- Update label text.
  if frame:IsMouseOver() and IsControlKeyDown() then
    JunkFilter.forceTsmCheck = true
    local tsmJunk = JunkFilter:GetSellableTsmJunkItems()
    JunkFilter.forceTsmCheck = false

    local totalProfit = 0
    for _, item in ipairs(tsmJunk) do
      local disenchantValue = TSM:GetDisenchantValue(item.link) or 0
      totalProfit = totalProfit + (item.price - disenchantValue)
    end

    if totalProfit > 0 then
      frame.label:SetText(PROFIT_TEXT_FORMAT:format(#tsmJunk, GetMoneyStringNoCopper(totalProfit)))
    else
      frame.label:SetText(TSM_JUNK_TEXT_FORMAT:format(#tsmJunk))
    end
  else
    local numSellable, numDestroyable = JunkFilter:GetNumJunkItems()
    frame.label:SetText(LABEL_TEXT_FORMAT:format(numSellable, numDestroyable))
  end

  -- Resize child frame.
  local width = frame.icon:GetWidth() + frame.label:GetStringWidth()
  frame.childFrame:SetWidth(width)
end)

-- OnDragStart.
frame:HookScript("OnDragStart", function()
  frame:GetScript("OnLeave")(frame)
end)

-- OnDragStop.
frame:HookScript("OnDragStop", function()
  if frame:IsMouseOver() then
    frame:GetScript("OnEnter")(frame)
  end
end)

-- ============================================================================
-- Ticker to update visibility.
-- ============================================================================

TickerManager:NewTicker(0.01, function()
  if Addon:IsAtMerchant() and StateManager:GetGlobalState().merchantButton then
    frame:Show()
  else
    frame:Hide()
  end
end)
