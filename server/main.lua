local config = require 'config.client'

exports.qbx_core:CreateUseableItem('diving_gear', function(source)
    local src = source

    local item = exports.ox_inventory:GetSlotWithItem(src, 'diving_gear')
    if not item then return end

    local uses = item.metadata and item.metadata.uses or config.divingGearUses

    if uses <= 0 then
        TriggerClientEvent(
            'qbx_core:Notify',
            src,
            'Esse equipamento de mergulho está quebrado.',
            'error'
        )
        return
    end

    TriggerClientEvent('qbx_divegear:client:tryEquip', src, uses)
end)

RegisterNetEvent('qbx_divegear:server:removeGearItem', function()
    local src = source
    exports.ox_inventory:RemoveItem(src, 'diving_gear', 1)
end)

RegisterNetEvent('qbx_divegear:server:returnGearItem', function(uses)
    local src = source

    if uses <= 0 then
        TriggerClientEvent(
            'qbx_core:Notify',
            src,
            'Seu equipamento de mergulho quebrou.',
            'error'
        )
        return
    end

    exports.ox_inventory:AddItem(src, 'diving_gear', 1, {
        uses = uses
    })
end)

exports.qbx_core:CreateUseableItem('diving_fill', function(source)
    local success = lib.callback.await('qbx_divegear:client:fillTank', source)
    if success then
        exports.ox_inventory:RemoveItem(source, 'diving_fill', 1)
    end
end)
