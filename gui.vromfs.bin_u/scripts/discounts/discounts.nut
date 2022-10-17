let { format } = require("string")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let { targetPlatform, isPlatformPC, isPlatformPS4 } = require("%scripts/clientState/platform.nut")

let { canUseIngameShop,
        haveDiscount,
        getShopItemsTable,
        needEntStoreDiscountIcon } = require("%scripts/onlineShop/entitlementsStore.nut")

let { getEntitlementId } = require("%scripts/onlineShop/onlineBundles.nut")
let { getEntitlementConfig } = require("%scripts/onlineShop/entitlements.nut")

let buttonsList = require("%scripts/mainmenu/topMenuButtons.nut").buttonsListWatch
let topMenuOnlineShopId = ::Computed(@() buttonsList.value?.ONLINE_SHOP.id ?? "")
let { eachBlock } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { promoteUnits } = require("%scripts/unit/remainingTimeUnit.nut")

let platformMapForDiscountFromGuiBlk = {
  pc = isPlatformPC
  ps4_scee = isPlatformPS4 && ::ps4_get_region() == ::SCE_REGION_SCEE
  ps4_scea = isPlatformPS4 && ::ps4_get_region() == ::SCE_REGION_SCEA
  ps4_scej = isPlatformPS4 && ::ps4_get_region() == ::SCE_REGION_SCEJ
}
local updateGiftUnitsDiscountTask = -1

::g_discount <- {
  [PERSISTENT_DATA_PARAMS] = ["discountsList"]

  getDiscountIconId = @(name) name + "_discount"
  canBeVisibleOnUnit = @(unit) unit && unit.isVisibleInShop() && !unit.isBought()
  discountsList = {}
  consoleEntitlementUnits = {} //It must not be cleared in common func

  function updateOnlineShopDiscounts()
  {
    consoleEntitlementUnits.clear()

    if (!needEntStoreDiscountIcon)
      return

    let isDiscountAvailable = haveDiscount()
    discountsList[topMenuOnlineShopId.value] = isDiscountAvailable

    if (isDiscountAvailable)
      foreach (label, item in getShopItemsTable()) {
        if (item.haveDiscount()) {
          let entId = getEntitlementId(item.id)
          let config = getEntitlementConfig(entId)
          let unitsList = config?.aircraftGift ?? []
          foreach (unitName in unitsList)
            consoleEntitlementUnits[unitName] <- item.getDiscountPercent()
        }
      }

    updateDiscountData()
  }

  onEventXboxShopDataUpdated = @(p) updateOnlineShopDiscounts()
  onEventPs4ShopDataUpdated = @(p) updateOnlineShopDiscounts()
  onEventEpicShopDataUpdated = @(p) updateOnlineShopDiscounts()
  onEventEpicShopItemUpdated = @(p) updateOnlineShopDiscounts()

  function updateGiftUnitsDiscountFromGuiBlk(giftUnits) { // !!!FIX ME Remove this function when gift units discount will received from char
    if (updateGiftUnitsDiscountTask >= 0) {
      ::periodic_task_unregister(updateGiftUnitsDiscountTask)
      updateGiftUnitsDiscountTask = -1
    }

    let discountsBlk = GUI.get()?.entitlement_units_discount
    if (discountsBlk == null)
      return

    local minUpdateDiscountsTimeSec = null
    for(local i = 0; i < discountsBlk.blockCount(); i++) {
      let discountConfigBlk = discountsBlk.getBlock(i)
      let platforms = (discountConfigBlk?.platform ?? "pc").split(";")
      local isSuitableForCurrentPlatform = false
      foreach (platform in platforms) {
        if (targetPlatform != platform && !(platformMapForDiscountFromGuiBlk?[platform] ?? false))
          continue

        isSuitableForCurrentPlatform = true
        break
      }

      if (!isSuitableForCurrentPlatform)
        continue

      let startTime = getTimestampFromStringUtc(discountConfigBlk.beginDate)
      let endTime = getTimestampFromStringUtc(discountConfigBlk.endDate)
      let currentTime = get_charserver_time_sec()
      if (currentTime >= endTime)
        continue

      if (currentTime < startTime) {
        let updateTimeSec = startTime - currentTime
        minUpdateDiscountsTimeSec = min(minUpdateDiscountsTimeSec ?? updateTimeSec, updateTimeSec)
        continue
      }

      let updateTimeSec = endTime - currentTime
      minUpdateDiscountsTimeSec = min(minUpdateDiscountsTimeSec ?? updateTimeSec, updateTimeSec)
      foreach (unitName, discount in discountConfigBlk)
        if (unitName in giftUnits)
          discountsList.entitlementUnits[unitName] <- discount
    }

    if (minUpdateDiscountsTimeSec != null)
      updateGiftUnitsDiscountTask = ::periodic_task_register(this,
        @(dt) updateDiscountData(), minUpdateDiscountsTimeSec)
  }
}

g_discount.clearDiscountsList <- function clearDiscountsList()
{
  foreach (button in buttonsList.value)
    if (button.needDiscountIcon)
      discountsList[button.id] <- false
  discountsList.changeExp <- false
  discountsList.topmenu_research <- false

  discountsList.entitlements <- {}

  discountsList.entitlementUnits <- {}
  discountsList.airList <- {}
}

::g_discount.clearDiscountsList()

//return 0 if when discount not visible
g_discount.getUnitDiscount <- function getUnitDiscount(unit)
{
  if (!canBeVisibleOnUnit(unit))
    return 0
  return max(getUnitDiscountByName(unit.name),
               getEntitlementUnitDiscount(unit.name))
}

g_discount.getGroupDiscount <- function getGroupDiscount(list)
{
  local res = 0
  foreach(unit in list)
    res = max(res, getUnitDiscount(unit))
  return res
}

g_discount.pushDiscountsUpdateEvent <- function pushDiscountsUpdateEvent()
{
  ::update_gamercards()
  ::broadcastEvent("DiscountsDataUpdated")
}

g_discount.onEventUnitBought <- function onEventUnitBought(p)
{
  let unitName = ::getTblValue("unitName", p)
  if (!unitName)
    return

  if (getUnitDiscountByName(unitName) == 0 && getEntitlementUnitDiscount(unitName) == 0)
    return

  updateDiscountData()
  //push event after current event completely finished
  ::get_gui_scene().performDelayed(this, pushDiscountsUpdateEvent)
}

g_discount.updateDiscountData <- function updateDiscountData(isSilentUpdate = false)
{
  clearDiscountsList()

  let pBlk = ::get_price_blk()

  let chPath = ["exp_to_gold_rate"]
  chPath.append(shopCountriesList)
  discountsList.changeExp = getDiscountByPath(chPath, pBlk) > 0

  let giftUnits = {}

  foreach(air in ::all_units)
    if (::isCountryAvailable(air.shopCountry)
        && !air.isBought()
        && air.isVisibleInShop())
    {
      if (::isUnitGift(air))
      {
        if (isPlatformPC)
          giftUnits[air.name] <- 0
        continue
      }

      let path = ["aircrafts", air.name]
      let discount = ::getDiscountByPath(path, pBlk)
      if (discount > 0)
        discountsList.airList[air.name] <- discount
    }

  eachBlock(::get_entitlements_price_blk(), @(b, n) checkEntitlement(n, b, giftUnits), this)

  updateGiftUnitsDiscountFromGuiBlk(giftUnits)  // !!!FIX ME Remove this function when gift units discount will received from char

  if (canUseIngameShop() && needEntStoreDiscountIcon)
    discountsList[topMenuOnlineShopId.value] = haveDiscount()

  discountsList.entitlementUnits.__update(consoleEntitlementUnits)

  local isShopDiscountVisible = false
  foreach(airName, discount in discountsList.airList)
    if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
    {
      isShopDiscountVisible = true
      break
    }
  if (!isShopDiscountVisible)
    foreach(airName, discount in discountsList.entitlementUnits)
      if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
      {
        isShopDiscountVisible = true
        break
      }
  discountsList.topmenu_research = isShopDiscountVisible

  if (!isSilentUpdate)
    pushDiscountsUpdateEvent()
}

g_discount.checkEntitlement <- function checkEntitlement(entName, entlBlock, giftUnits)
{
  let discountItemList = ["premium", "warpoints", "eagles", "campaign", "bonuses"]
  local chapter = entlBlock?.chapter
  if (!::isInArray(chapter, discountItemList))
    return

  local discount = ::get_entitlement_gold_discount(entName)
  let singleDiscount = entlBlock?.singleDiscount && !::has_entitlement(entName)
                            ? entlBlock.singleDiscount
                            : 0

  discount = max(discount, singleDiscount)
  if (discount == 0)
    return

  discountsList.entitlements[entName] <- discount

  if (chapter == "campaign" || chapter == "bonuses")
  {
    if (canUseIngameShop())
      chapter = topMenuOnlineShopId.value
  }

  local chapterVal = true
  if (chapter == topMenuOnlineShopId.value)
    chapterVal = canUseIngameShop() || isPlatformPC
  discountsList[chapter] <- chapterVal

  if (entlBlock?.aircraftGift)
    foreach(unitName in entlBlock % "aircraftGift")
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
}

g_discount.generateDiscountInfo <- function generateDiscountInfo(discountsTable, headerLocId = "")
{
  local maxDiscount = 0
  let headerText = ::loc(headerLocId == ""? "discount/notification" : headerLocId) + "\n"
  local discountText = ""
  foreach(locId, discount in discountsTable)
  {
    if (discount <= 0)
      continue

    discountText += ::loc("discount/list_string", {itemName = ::loc(locId), discount = discount}) + "\n"
    maxDiscount = max(maxDiscount, discount)
  }

  if (discountsTable.len() > 20)
    discountText = format(::loc("discount/buy/tooltip"), maxDiscount.tostring())

  if (discountText == "")
    return {}

  discountText = headerText + discountText

  return {maxDiscount = maxDiscount, discountTooltip = discountText}
}

g_discount.updateDiscountNotifications <- function updateDiscountNotifications(scene = null)
{
  foreach(name in ["topmenu_research", "changeExp"])
  {
    let id = getDiscountIconId(name)
    let obj = ::checkObj(scene)? scene.findObject(id) : ::get_cur_gui_scene()[id]
    if (!(obj?.isValid() ?? false))
      continue

    let discount = getDiscount(name)
    let hasDiscount = name == "topmenu_research"
      ? discount && !(promoteUnits.value.findvalue(@(d) d.isActive) != null)
      : discount
    obj.show(hasDiscount)
  }

  let section = ::g_top_menu_right_side_sections.getSectionByName("shop")
  let sectionId = section.getTopMenuButtonDivId()
  let shopObj = ::checkObj(scene)? scene.findObject(sectionId) : ::get_cur_gui_scene()[sectionId]
  if (!::checkObj(shopObj))
    return

  let stObj = shopObj.findObject(section.getTopMenuDiscountId())
  if (!::checkObj(stObj))
    return

  local haveAnyDiscount = false
  foreach (column in section.buttons)
  {
    foreach (button in column)
    {
      if (!button.needDiscountIcon)
        continue

      let id = getDiscountIconId(button.id)
      let dObj = shopObj.findObject(id)
      if (!::checkObj(dObj))
        continue

      let discountStatus = getDiscount(button.id)
      haveAnyDiscount = haveAnyDiscount || discountStatus
      dObj.show(discountStatus)
    }
  }

  stObj.show(haveAnyDiscount)
}

g_discount.getDiscount <- function getDiscount(id, defVal = false)
{
  return discountsList?[id] ?? defVal
}

g_discount.getEntitlementDiscount <- function getEntitlementDiscount(id)
{
  return discountsList.entitlements?[id] || 0
}

g_discount.getEntitlementUnitDiscount <- function getEntitlementUnitDiscount(unitName)
{
  return discountsList.entitlementUnits?[unitName] || 0
}

g_discount.getUnitDiscountByName <- function getUnitDiscountByName(unitName)
{
  return discountsList.airList?[unitName] || 0
}

g_discount.haveAnyUnitDiscount <- function haveAnyUnitDiscount()
{
  return discountsList.entitlementUnits.len() > 0 || discountsList.airList.len() > 0
}

g_discount.getUnitDiscountList <- function getUnitDiscountList(countryId = null)
{
  if (!haveAnyUnitDiscount())
    return {}

  let discountsList = {}
  foreach(unit in ::all_units)
    if (!countryId || unit.shopCountry == countryId)
    {
      let discount = getUnitDiscount(unit)
      if (discount > 0)
        discountsList[unit.name + "_shop"] <- discount
    }

  return discountsList
}

// Independent Modules
require("%scripts/slotbar/elems/discountIconElem.nut")

::subscribe_handler(::g_discount, ::g_listener_priority.CONFIG_VALIDATION)
::g_script_reloader.registerPersistentDataFromRoot("g_discount")