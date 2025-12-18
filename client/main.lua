local config = require 'config.client'

local currentGear = {
    mask = 0,
    tank = 0,
    enabled = false,
    uses = 0,
    hasTankFilled = false
}

local oxygenLevel = 0

local function enableScuba()
    SetEnableScuba(cache.ped, true)
    SetPedMaxTimeUnderwater(cache.ped, 2000.0)
end

local function disableScuba()
    SetEnableScuba(cache.ped, false)
    SetPedMaxTimeUnderwater(cache.ped, 1.0)
end

lib.callback.register('qbx_divegear:client:fillTank', function()
    if IsPedSwimmingUnderWater(cache.ped) then
        exports.qbx_core:Notify(locale('error.underwater'), 'error')
        return false
    end

    if lib.progressBar({
        duration = config.refillTankTimeMs,
        label = locale('info.filling_air'),
        canCancel = true,
        anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' }
    }) then
        oxygenLevel = config.startingOxygenLevel
        currentGear.hasTankFilled = true
        exports.qbx_core:Notify(locale('success.tube_filled'), 'success')

        if currentGear.enabled then
            enableScuba()
        end

        return true
    end

    return false
end)

local function deleteGear()
    if currentGear.mask ~= 0 then
        DeleteEntity(currentGear.mask)
        currentGear.mask = 0
    end

    if currentGear.tank ~= 0 then
        DeleteEntity(currentGear.tank)
        currentGear.tank = 0
    end
end

local function attachGear()
    lib.requestModel(`p_d_scuba_mask_s`)
    lib.requestModel(`p_s_scuba_tank_s`)

    currentGear.tank = CreateObject(`p_s_scuba_tank_s`, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(
        currentGear.tank, cache.ped, GetPedBoneIndex(cache.ped, 24818),
        -0.25, -0.25, 0.0, 180.0, 90.0, 0.0,
        true, true, false, false, 2, true
    )

    currentGear.mask = CreateObject(`p_d_scuba_mask_s`, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(
        currentGear.mask, cache.ped, GetPedBoneIndex(cache.ped, 12844),
        0.0, 0.0, 0.0, 180.0, 90.0, 0.0,
        true, true, false, false, 2, true
    )
end

local function startOxygenThreads()
    CreateThread(function()
        while currentGear.enabled do
            if IsPedSwimmingUnderWater(cache.ped) and oxygenLevel > 0 then
                oxygenLevel -= 1
                if oxygenLevel <= 0 then
                    disableScuba()
                end
            end
            Wait(1000)
        end
    end)

    CreateThread(function()
        while currentGear.enabled do
            if IsPedSwimmingUnderWater(cache.ped) then
                qbx.drawText2d({
                    text = oxygenLevel .. '⏱',
                    coords = vec2(1.0, 1.42),
                    scale = 0.45
                })
            end
            Wait(0)
        end
    end)
end

local function putOnSuit()
    if IsPedSwimming(cache.ped) or cache.vehicle then
        exports.qbx_core:Notify(locale('error.not_standing_up'), 'error')
        return false
    end

    if lib.progressBar({
        duration = config.putOnSuitTimeMs,
        label = locale('info.put_suit'),
        canCancel = true,
        anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' }
    }) then
        deleteGear()
        attachGear()
        enableScuba()
        currentGear.enabled = true
        startOxygenThreads()
        return true
    end

    return false
end

local function takeOffSuit()
    if lib.progressBar({
        duration = config.takeOffSuitTimeMs,
        label = locale('info.pullout_suit'),
        canCancel = true,
        anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' }
    }) then
        disableScuba()
        deleteGear()
        currentGear.enabled = false

        currentGear.uses -= 1

        if currentGear.uses <= 0 then
            oxygenLevel = 0
            currentGear.hasTankFilled = false
        end

        TriggerServerEvent('qbx_divegear:server:returnGearItem', currentGear.uses)
        exports.qbx_core:Notify(locale('success.took_out'), 'success')
    end
end

RegisterNetEvent('qbx_divegear:client:tryEquip', function(uses)
    if currentGear.enabled then
        exports.qbx_core:Notify(locale('error.already_using'), 'error')
        return
    end

    if oxygenLevel <= 0 then
        exports.qbx_core:Notify(locale('error.tank_empty'), 'error')
        return
    end

    currentGear.uses = uses
    TriggerServerEvent('qbx_divegear:server:removeGearItem')
    putOnSuit()
end)

RegisterCommand(config.removeCommand, function()
    if not currentGear.enabled then
        exports.qbx_core:Notify(locale('error.not_using'), 'error')
        return
    end

    takeOffSuit()
end, false)

RegisterKeyMapping(
    config.removeCommand,
    config.removeDescription,
    'keyboard',
    config.removeKey
)
