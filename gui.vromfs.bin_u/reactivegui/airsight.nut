let {PI, cos, sin} = require("%sqstd/math.nut")
let {
  IsMachineGunEmpty, GunOverheatState, GunDirectionX, IsCannonEmpty, isAllCannonsEmpty,
  GunDirectionY, GunDirectionVisible, GunInDeadZone, GunSightMode,
  TurretsDirectionX, TurretsDirectionY, TurretsOverheat, TurretsReloading, TurretsVisible,
  FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY, FixedGunSightMode, FixedGunOverheat,
  IsAgmEmpty, IsATGMOutOfTrackerSector, AtgmTrackerRadius, IsLaserDesignatorEnabled, Agm,
  RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode,
  NoLosToATGM, AlertColorHigh, HudColor, CurrentTime,
  BombReleaseVisible, BombReleaseDirX, BombReleaseDirY, BombReleaseOpacity,
  BombReleasePoints, BombReleaseRelativToTarget } = require("airState.nut")
let { TargetX, TargetY } = require("reactiveGui/hud/targetTrackerState.nut")

let { backgroundColor, mixColor, styleText, styleLineForeground, relativCircle } = require("style/airHudStyle.nut")

let { LaserPoint, HaveLaserPoint } = require("planeState/planeWeaponState.nut")

const NUM_TURRETS_MAX = 10
const NUM_CANNONS_MAX = 3

const NUM_BOMB_RELEASE_POINT = 80

let sqL = 80
let l = 20
let offset = (100 - sqL) * 0.5

let normalTurretSight = [
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset]
]

let ccipTurretSight = [
  [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
  [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
  [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
]

let dashTurretSight = [
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0]
]

let ccipDashTurretSight = [
  [VECTOR_LINE, 0, -50, 0, -50 + l],
  [VECTOR_LINE, 50 - l, 0, 50, 0],
  [VECTOR_LINE, 0, 50 - l, 0, 50],
  [VECTOR_LINE, -50, 0, -50 + l, 0],
  [VECTOR_LINE, 40, 40, 55, 55],
  [VECTOR_LINE, -40, 40, -55, 55],
  [VECTOR_LINE, 40, -40, 55, -55],
  [VECTOR_LINE, -40, -40, -55, -55]
]

let triggerGun = {}
let isGunBlinking = keepref(Computed(@() GunInDeadZone.value))
isGunBlinking.subscribe(@(v) v ? ::anim_start(triggerGun) : ::anim_request_stop(triggerGun))

let gunDirection = @(colorWatch, isSightHud, isBackground) function() {

  let watchList = [GunSightMode, GunOverheatState, IsMachineGunEmpty, GunDirectionX, GunDirectionY, colorWatch,
                     isAllCannonsEmpty, AlertColorHigh, GunDirectionVisible, IsCannonEmpty]
  let res = { watch = watchList}

  if (GunSightMode.value == 0 && isSightHud)
    return res
  if (!GunDirectionVisible.value)
    return res


  let mainCommands = []
  let overheatCommands = []
  let selectedSightCommands = GunSightMode.value == 0 ? normalTurretSight : ccipTurretSight

  for (local i = 0; i < selectedSightCommands.len(); ++i) {
    if (i >= GunOverheatState.value) {

      mainCommands.append(selectedSightCommands[i])
      if (!isAllCannonsEmpty.value || !IsMachineGunEmpty.value)
        mainCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
    }
    else {

      overheatCommands.append(selectedSightCommands[i])
      if (!isAllCannonsEmpty.value || !IsMachineGunEmpty.value)
        overheatCommands.append(GunSightMode.value == 0 ? dashTurretSight[i] : ccipDashTurretSight[i])
    }
  }

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    animations = [{ prop = AnimProp.opacity, from = 1, to = 0, duration = 0.5, loop = true, easing = InOutSine, trigger = triggerGun}]
    transform = {
      translate = [GunDirectionX.value, GunDirectionY.value]
    }
    children =
    [
      @() {
        watch = colorWatch
        rendObj = ROBJ_VECTOR_CANVAS
        size = [sh(2), sh(2)]
        color = colorWatch.value
        commands = mainCommands
      },
      @() {
        watch = AlertColorHigh
        rendObj = ROBJ_VECTOR_CANVAS
        size = [sh(2), sh(2)]
        color = isBackground ? backgroundColor : AlertColorHigh.value
        commands = overheatCommands
      }
    ]
  })
}

let dashCount = 36
const circleSize = 2.5
let angleReloadArrow = 90.0

let function reloadTurret(currentTime){
  let angleAnim = ((currentTime * 180) % 360) * (PI / 180)  // 360 per 2 sec
  let commands = []
  let angleDegree = angleReloadArrow / dashCount
  let angle = angleDegree * (PI / 180)
  for(local i = 0; i < dashCount; ++i) {
      commands.append([
        VECTOR_LINE,
        (cos(angle * (i-1) + angleAnim) - sin(angle * (i-1) + angleAnim)) * circleSize,
        (cos(angle * (i-1) + angleAnim) + sin(angle * (i-1) + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) - sin(angle * i + angleAnim)) * circleSize,
        (cos(angle * i + angleAnim) + sin(angle * i + angleAnim)) * circleSize
      ])
    }
  return commands
}

let createTurretSights = @(turretIndex, colorWatch) @() styleLineForeground.__merge({
  watch = [colorWatch, TurretsDirectionX[turretIndex], TurretsDirectionY[turretIndex], TurretsReloading[turretIndex], TurretsVisible[turretIndex]]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [TurretsDirectionX[turretIndex].value, TurretsDirectionY[turretIndex].value]
  color = colorWatch.value
  size = [sh(20), sh(20)]
  lineWidth = hdpx(1)
  fillColor = Color(0, 0, 0, 0)
  commands = TurretsReloading[turretIndex].value ? reloadTurret(CurrentTime.value)
    : TurretsVisible[turretIndex].value ? relativCircle(1, circleSize)
    : null
  children = @() styleLineForeground.__merge({
    watch = [AlertColorHigh, TurretsVisible[turretIndex], TurretsReloading[turretIndex], TurretsOverheat[turretIndex]]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    color = AlertColorHigh.value
    commands = (TurretsVisible[turretIndex].value && !TurretsReloading[turretIndex].value)
      ? relativCircle(TurretsOverheat[turretIndex].value, circleSize)
      : null
  })
})

let function aircraftTurretsComponent(colorWatch) {
  return {
    size = flex()
    children = array(NUM_TURRETS_MAX).map(@(_, i) createTurretSights(i, colorWatch))
  }
}



let function fixedGunsSight(sightId){
  local shifting = 30
  if (sightId == 0) {
    return [
      [VECTOR_LINE, 0, 50 + shifting, 0, 150 + shifting],
      [VECTOR_LINE, 0, -50 - shifting, 0, -150 - shifting],
      [VECTOR_LINE, 50 + shifting, 0, 150 + shifting, 0],
      [VECTOR_LINE, -50 - shifting, 0, -150 - shifting, 0],
    ]
  }
  else if (sightId == 1) {
    return [
      [VECTOR_LINE, 0, 50 + shifting, 0, 150 + shifting],
      [VECTOR_LINE, 0, -50 - shifting, 0, -150 - shifting],
      [VECTOR_LINE, 50 + shifting, 0, 150 + shifting, 0],
      [VECTOR_LINE, -50 - shifting, 0, -150 - shifting, 0],
      [VECTOR_LINE, 80, 80, 100, 100],
      [VECTOR_LINE, -80, 80, -100, 100],
      [VECTOR_LINE, 80, -80, 100, -100],
      [VECTOR_LINE, -80, -80, -100, -100],
    ]
  }

  return [
    [VECTOR_LINE, 0, 50, 0, 150],
    [VECTOR_LINE, 0, -50, 0, -150],
    [VECTOR_LINE, 50, 0, 150, 0],
    [VECTOR_LINE, -50, 0, -150, 0],
    [VECTOR_LINE, 60, 60, -60, 60],
    [VECTOR_LINE, 60, -60, -60, -60],
    [VECTOR_LINE, 60, 60, 60, -60],
    [VECTOR_LINE, -60, 60, -60, -60],
  ]
}

let fixedGunsDirection = @(_colorWatch, isBackground) function() {

  let res = { watch = [FixedGunDirectionVisible, FixedGunDirectionX, FixedGunDirectionY] }

  if (!FixedGunDirectionVisible.value)
    return res

  local overheatLines = @(color, width) function() {
    return {
      watch = [FixedGunOverheat]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(width)
      size = [sh(50), sh(50)]
      color
      fillColor = Color(0, 0, 0, 0)
      commands = relativCircle(FixedGunOverheat.value, circleSize)
    }
  }

  local lines = @() {
    watch = [FixedGunSightMode, HudColor, AlertColorHigh]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH)
    size = [sh(0.625), sh(0.625)]
    color = isBackground ? backgroundColor : HudColor.value
    commands = fixedGunsSight(FixedGunSightMode.value)
    children = overheatLines(AlertColorHigh.value, LINE_WIDTH)
  }

  local shadowLines = @() styleLineForeground.__merge({
    watch = [FixedGunSightMode, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(LINE_WIDTH + 2)
    size = [sh(0.625), sh(0.625)]
    fillColor = Color(0,0,0,0)
    color = Color(0, 0, 0, 120)
    commands = fixedGunsSight(FixedGunSightMode.value)
    children = overheatLines(Color(0, 0, 0, 120), LINE_WIDTH + 2)
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    children = [shadowLines, lines]
  })
}

let helicopterCCRP = @(colorWatch, isBackground) function() {

  let res =  { watch = [FixedGunDirectionX, FixedGunDirectionY, FixedGunDirectionVisible, FixedGunSightMode] }

  if (!FixedGunDirectionVisible.value || FixedGunSightMode.value != 2)
    return res

  let lines = @() styleLineForeground.__merge({
    watch = [TargetX, TargetY, colorWatch]
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(0.625), sh(0.625)]
    color = isBackground ? backgroundColor : colorWatch.value
    commands = [[VECTOR_LINE, 0,0, TargetX.value, TargetY.value]]
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [FixedGunDirectionX.value, FixedGunDirectionY.value]
    children = lines
  })
}

let function agmTrackZoneComponent(colorWatch, isBackground) {
  let function agmTrackZone(width, height, isBackground) {
    return @() styleLineForeground.__merge({
      watch = [IsAgmEmpty, IsATGMOutOfTrackerSector, NoLosToATGM, AtgmTrackerRadius, colorWatch]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      opacity = AtgmTrackerRadius.value > 0.0 ? 100 : 0
      color = isBackground ? backgroundColor : colorWatch.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = hdpx(LINE_WIDTH)
      commands = !IsAgmEmpty.value && IsATGMOutOfTrackerSector.value && !NoLosToATGM.value
        ?
        [
          [ VECTOR_ELLIPSE, 50, 50,
            AtgmTrackerRadius.value / width * 100,
            AtgmTrackerRadius.value / height * 100
          ]
        ]
        : null
    })
  }

  let width = sw(100)
  let height = sh(100)
  return {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1 duration = 0.5, play = true, loop = true, easing = InOutCubic}]
    children = agmTrackZone(width, height, isBackground)
  }
}

let function laserDesignatorComponent(colorWatch, isBackground) {
  let function laserDesignator(width, height, isBackground) {
    let lhl = 5
    let lvl = 7
    return @() styleLineForeground.__merge({
      watch = [IsAgmEmpty, colorWatch, AlertColorHigh]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [width, height]
      color = (!isBackground && IsAgmEmpty.value) ? AlertColorHigh.value
        : isBackground ? backgroundColor
        : colorWatch.value
      commands = [
        [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 + lhl, 50 - lvl],
        [VECTOR_LINE, 50 - lhl, 50 + lvl, 50 + lhl, 50 + lvl],
        [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 - lhl, 50 + lvl],
        [VECTOR_LINE, 50 + lhl, 50 - lvl, 50 + lhl, 50 + lvl],
      ]
    })
  }

  let width = hdpx(150)
  let height = hdpx(100)
  return @() {
    watch = IsLaserDesignatorEnabled
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    opacity = IsLaserDesignatorEnabled.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(width, height, isBackground)
  }
}


let laserTrigger = {}
IsLaserDesignatorEnabled.subscribe(@(v) !v ? ::anim_start(laserTrigger) : ::anim_request_stop(laserTrigger))

let function laserDesignatorStatusComponent(colorWatch, posX, posY, _isBackground) {
  let laserDesignatorStatus = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = IsLaserDesignatorEnabled.value ? ::loc("HUD/TXT_LASER_DESIGNATOR") : ::loc("HUD/TXT_ENABLE_LASER_NOW")
    color = colorWatch.value
    watch = [IsLaserDesignatorEnabled, colorWatch]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = !IsLaserDesignatorEnabled.value, loop = true, easing = InOutSine, trigger = laserTrigger }]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = [0, 0]
    watch = [IsLaserDesignatorEnabled, Agm.timeToHit, Agm.timeToWarning]
    children = IsLaserDesignatorEnabled.value || (Agm.timeToHit.value > 0 && Agm.timeToWarning.value <= 0) ? laserDesignatorStatus : null
  }
  return resCompoment
}

let function agmTrackerStatusComponent(colorWatch, posX, posY, _isBackground) {
  let agmTrackerStatus = @() styleText.__merge({
    rendObj = ROBJ_TEXT
    halign = ALIGN_CENTER
    text = NoLosToATGM.value ? ::loc("HUD/TXT_NO_LOS_ATGM") : ::loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR")
    color = colorWatch.value
    watch = [NoLosToATGM, colorWatch]
    animations = [{ prop = AnimProp.opacity, from = 0, to = 1, duration = 0.5, play = true, loop = true, easing = InOutCubic}]
  })

  let resCompoment = @() {
    pos = [posX, posY]
    halign = ALIGN_CENTER
    size = [0, 0]
    watch = [IsATGMOutOfTrackerSector, NoLosToATGM]
    children = IsATGMOutOfTrackerSector.value || NoLosToATGM.value ? agmTrackerStatus : null
  }
  return resCompoment
}

let function aircraftRocketSightMode(sightMode){

  if (sightMode == 0) {
    return [
      [VECTOR_LINE, 0, 0, 0, 300],
      [VECTOR_LINE, 20, 0, -20, 0],
      [VECTOR_LINE, 40, 100, -40, 100],
      [VECTOR_LINE, 60, 200, -60, 200],
      [VECTOR_LINE, 80, 300, -80, 300]
    ]
  }
  else if (sightMode == 1) {
    return [
      [VECTOR_LINE, -50, -50, -25, -25],
      [VECTOR_LINE, -50, 50, -25, 25],
      [VECTOR_LINE, 50, -50, 25, -25],
      [VECTOR_LINE, 50, 50, 25, 25],
      [VECTOR_ELLIPSE, 0, 0, 1.0, 1.0]
    ]
  }

  return [
    [VECTOR_LINE, -100, -100, 100, -100],
    [VECTOR_LINE, -100, 100, 100, 100],
    [VECTOR_LINE, -20, -100, -20, 100],
    [VECTOR_LINE, 20, -100, 20, 100],
    [VECTOR_LINE, 40, 40, -40, 40],
    [VECTOR_LINE, 40, -40, -40, -40],
    [VECTOR_LINE, 60, 20, 60, -20],
    [VECTOR_LINE, -60, 20, -60, -20],
  ]
}


let aircraftRocketSight = @(width, height) function() {

  let res = { watch = [RocketAimX, RocketAimY, RocketAimVisible, RocketSightMode] }

  if (!RocketAimVisible.value)
    return res

  let lines = @() styleLineForeground.__merge({
    watch = [RocketSightMode, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    color = HudColor.value
    fillColor = Color(0,0,0,0)
    lineWidth = hdpx(LINE_WIDTH)
    size = [width, height]
    commands = aircraftRocketSightMode(RocketSightMode.value)
  })

  let shadowLines = @() styleLineForeground.__merge({
    watch = [RocketSightMode, HudColor]
    rendObj = ROBJ_VECTOR_CANVAS
    color = Color(0,0,0,120)
    lineWidth = hdpx(LINE_WIDTH + 2)
    size = [width, height]
    commands = aircraftRocketSightMode(RocketSightMode.value)
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    pos = [RocketAimX.value, RocketAimY.value]
    children = [shadowLines, lines]
  })
}

let function laserPoint(colorWatch) {
  return {
    size = [ph(1.5), ph(1.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = colorWatch.value
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [LaserPoint[0], LaserPoint[1]]
      }
    }
  }
}

let function laserPointComponent(colorWatch, isBackground) {
  return @() {
    watch = HaveLaserPoint
    size = flex()
    children = HaveLaserPoint.value && !isBackground ? laserPoint(colorWatch) : null
  }
}

local bombSightComponent = @(width, height, _isBackground) function() {
  local res = { watch = [BombReleaseVisible, BombReleaseDirX, BombReleaseDirY, BombReleasePoints] }

  if (!BombReleaseVisible.value)
    return res

  local commands = []
  for (local i = 0; i < NUM_BOMB_RELEASE_POINT; i += 4) {
    commands.append([VECTOR_LINE, BombReleasePoints.value?[i], BombReleasePoints.value?[i + 1], BombReleasePoints.value?[i+2], BombReleasePoints.value?[i+3]])
  }

  local lines = @() styleLineForeground.__merge({
    watch = [HudColor, AlertColorHigh, BombReleaseRelativToTarget, BombReleaseOpacity,
      BombReleaseDirX, BombReleaseDirY]
    rendObj = ROBJ_VECTOR_CANVAS
    opacity = BombReleaseOpacity.value
    lineWidth = hdpx(LINE_WIDTH)
    fillColor = Color(0,0,0,0)
    size = [width, height]
    pos = [BombReleaseDirX.value,BombReleaseDirY.value]
    color = mixColor(HudColor.value, AlertColorHigh.value, BombReleaseRelativToTarget.value)
    commands
  })

  local shadowLines = @() styleLineForeground.__merge({
    watch = [BombReleaseOpacity, BombReleaseDirX, BombReleaseDirY]
    rendObj = ROBJ_VECTOR_CANVAS
    opacity = BombReleaseOpacity.value
    lineWidth = hdpx(LINE_WIDTH + 2)
    fillColor = Color(0,0,0,0)
    size = [width, height]
    pos = [BombReleaseDirX.value,BombReleaseDirY.value]
    color = Color(0, 0, 0, 120)
    commands
  })

  return res.__update({
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = HudColor.value
    pos = [0,0]
    children = [shadowLines, lines]
  })
}

return {
  aircraftTurretsComponent
  gunDirection
  fixedGunsDirection
  helicopterCCRP
  agmTrackerStatusComponent
  agmTrackZoneComponent
  laserDesignatorStatusComponent
  laserDesignatorComponent
  laserPointComponent
  aircraftRocketSight
  bombSightComponent
}