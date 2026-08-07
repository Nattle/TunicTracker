-- TUNIC combat calculator
-- Ported from tunic/combat_logic.py in APWorld 5.0.1.

local function make_area(values)
    return {
        att = values[1],
        def = values[2],
        potion = values[3],
        hp = values[4],
        sp = values[5],
        mp = values[6],
        potions = values[7],
        equipment = values[8],
        is_boss = values[9],
    }
end

local function has_code(code)
    return Tracker:ProviderCountForCode(code) > 0
end

local function stage_count(code)
    local item = Tracker:FindObjectForCode(code)
    return item and item.CurrentStage or 0
end

local function acquired_count(code)
    local item = Tracker:FindObjectForCode(code)
    return item and item.AcquiredCount or 0
end

function sword_upgrade_count()
    local sword_setting = Tracker:FindObjectForCode("progswordSetting")
    if not sword_setting or sword_setting.CurrentStage ~= 1 then
        return 0
    end

    local receipt_counter = Tracker:FindObjectForCode("sword_upgrade_count")
    local receipts = receipt_counter and receipt_counter.AcquiredCount or 0
    if receipts > 0 or has_code("start_with_sword_setting") or SLOT_DATA ~= nil then
        return receipts
    end

    -- Manual/offline fallback for states created before the receipt counter.
    local visible_sword = Tracker:FindObjectForCode("progsword")
    if visible_sword and visible_sword.Active then
        return visible_sword.CurrentStage
    end
    return 0
end

local function read_combat_state()
    return {
        att_offerings = stage_count("fangs"),
        def_offerings = stage_count("idols"),
        potion_offerings = stage_count("powder"),
        hp_offerings = stage_count("flowers"),
        sp_offerings = stage_count("leaves"),
        mp_offerings = stage_count("shrooms"),

        att_relic = has_code("attrelic"),
        def_relic = has_code("defrelic"),
        potion_relic = has_code("potionrelic"),
        hp_relic = has_code("hprelic"),
        sp_relic = has_code("sprelic"),
        mp_relic = has_code("mprelic"),

        secret_legend = has_code("tunic"),
        phonomath = has_code("phonomath"),
        pals = has_code("pals"),
        spring_falls = has_code("spring"),
        back_to_work = has_code("work"),
        mr_mayor = has_code("mayor"),
        power_up = has_code("powerup"),
        regal_weasel = has_code("weasel"),
        forever_friend = has_code("friend"),
        sacred_geometry = has_code("geometry"),
        vintage = has_code("vintage"),
        dusty = has_code("dusty"),

        stick = has_code("stick"),
        sword = has_code("sword"),
        sword_upgrades = sword_upgrade_count(),
        wand = has_code("staff"),
        gun = has_code("gun"),
        shield = has_code("shield"),
        laurels = has_code("dash"),

        flasks = acquired_count("heal"),
        flask_shards = acquired_count("healshard"),
        effigies = acquired_count("effigy_count"),
        money_128 = acquired_count("combat_money_128_count"),
        money_200 = acquired_count("combat_money_200_count"),
        money_255 = acquired_count("combat_money_255_count"),
    }
end

local function bool_count(...)
    local result = 0
    for _, value in ipairs({...}) do
        if value then result = result + 1 end
    end
    return result
end

local function get_att_level(state)
    local upgrades = bool_count(state.att_relic)
    if state.sword_upgrades >= 3 then
        upgrades = upgrades + math.min(2, state.sword_upgrades - 2)
    end
    return math.min(8, 1 + state.att_offerings + upgrades)
        + (state.laurels and 1 or 0), state.att_offerings
end

local function get_def_level(state)
    local level = math.min(8, 1 + state.def_offerings
        + bool_count(state.def_relic, state.secret_legend, state.phonomath))
    level = level + (state.shield and 2 or 0) + (state.laurels and 2 or 0)
    return level, state.def_offerings
end

local function get_potion_level(state)
    local offerings = math.min(2, state.potion_offerings)
    return 1 + offerings
        + bool_count(state.potion_relic, state.pals, state.spring_falls, state.back_to_work), offerings
end

local function get_hp_level(state)
    return 1 + state.hp_offerings + bool_count(state.hp_relic), state.hp_offerings
end

local function get_sp_level(state)
    return 1 + state.sp_offerings
        + bool_count(state.sp_relic, state.mr_mayor, state.power_up,
            state.regal_weasel, state.forever_friend), state.sp_offerings
end

local function get_mp_level(state)
    return 1 + state.mp_offerings
        + bool_count(state.mp_relic, state.sacred_geometry, state.vintage, state.dusty), state.mp_offerings
end

local function get_potion_count(state)
    return state.flasks + math.floor(state.flask_shards / 3)
end

local function calc_effective_hp(hp_level, potion_level, potion_count)
    local hp = 60 + hp_level * 20
    local healing = math.floor(0.75 * potion_count * math.min(hp, 20 + 10 * potion_level))
    return hp + healing
end

local function get_money_count(state)
    local money = state.money_255 * 255 + state.money_200 * 200 + state.money_128 * 128
    local value = 8
    for _ = 1, math.min(28, state.effigies) do
        money = money + value
        value = math.min(512, value * 2)
    end
    return money
end

local function calc_hp_potion_cost(hp_upgrades, potion_upgrades)
    local money = 0
    local hp_cost = 200
    for _ = 1, hp_upgrades do
        money = money + hp_cost
        hp_cost = hp_cost + 50
    end

    local potion_cost = 100
    for _ = 1, potion_upgrades do
        money = money + potion_cost
        if potion_cost == 100 then
            potion_cost = 300
        elseif potion_cost == 300 then
            potion_cost = 1000
        else
            potion_cost = potion_cost + 200
        end
    end
    return money
end

local function calc_def_sp_cost(def_upgrades, sp_upgrades)
    local money = 0
    local def_cost = 100
    for _ = 1, def_upgrades do
        money = money + def_cost
        def_cost = def_cost + 50
    end

    local sp_cost = 200
    for _ = 1, sp_upgrades do
        money = money + sp_cost
        sp_cost = sp_cost + 200
    end
    return money
end

local function has_required_stats(data, state)
    local money_required = 0
    local att_required = data.att
    local player_att, att_offerings = get_att_level(state)

    if data.mp > 1 and data.equipment.Magic then
        if player_att < data.att + 2 then
            local player_mp, mp_offerings = get_mp_level(state)
            if player_mp < data.mp then return false end

            local extra_mp = player_mp - data.mp
            local paid_mp = math.max(0, mp_offerings - extra_mp)
            local mp_cost = 300
            for _ = 1, paid_mp do
                money_required = money_required + mp_cost
                mp_cost = mp_cost + 50
            end
        else
            att_required = att_required + 2
        end
    end

    if player_att < att_required then return false end
    local paid_att = math.max(0, att_offerings - (player_att - att_required))
    local att_cost = 100
    for _ = 1, paid_att do
        money_required = money_required + att_cost
        att_cost = att_cost + 50
    end

    if data.def + data.sp > 2 then
        local player_def, def_offerings = get_def_level(state)
        local player_sp, sp_offerings = get_sp_level(state)
        local required = data.def + data.sp
        if player_def + player_sp < required then return false end

        local free_def = player_def - def_offerings
        local free_sp = player_sp - sp_offerings
        if free_def + free_sp < required then
            local stats_to_buy = required - free_def - free_sp
            local cheapest = nil
            for paid_def = 0, math.min(def_offerings, stats_to_buy) do
                local paid_sp = stats_to_buy - paid_def
                if paid_sp >= 0 and sp_offerings >= paid_sp then
                    local cost = calc_def_sp_cost(paid_def, paid_sp)
                    if cheapest == nil or cost < cheapest then cheapest = cost end
                end
            end
            if cheapest == nil then return false end
            money_required = money_required + cheapest
        end
    end

    local required_hp = calc_effective_hp(data.hp, data.potion, data.potions)
    local player_potion, potion_offerings = get_potion_level(state)
    local player_hp, hp_offerings = get_hp_level(state)
    local potion_count = get_potion_count(state)
    if calc_effective_hp(player_hp, player_potion, potion_count) < required_hp then return false end

    local free_potion = player_potion - potion_offerings
    local free_hp = player_hp - hp_offerings
    if calc_effective_hp(free_hp, free_potion, potion_count) < required_hp then
        local cheapest = nil
        local lowest_hp_added = hp_offerings + 1
        for paid_potion = 0, potion_offerings do
            for paid_hp = 0, lowest_hp_added - 1 do
                if calc_effective_hp(free_hp + paid_hp, free_potion + paid_potion, potion_count) >= required_hp then
                    local cost = calc_hp_potion_cost(paid_hp, paid_potion)
                    if cheapest == nil or cost < cheapest then cheapest = cost end
                    lowest_hp_added = paid_hp
                    break
                end
            end
        end
        if cheapest == nil then return false end
        money_required = money_required + cheapest
    end

    return get_money_count(state) >= money_required
end

local function list_to_set(values)
    local result = {}
    for _, value in ipairs(values) do result[value] = true end
    return result
end

local function copy_set(values)
    local result = {}
    for key, value in pairs(values) do result[key] = value end
    return result
end

local function check_combat_reqs(area_name, state, alternate)
    local source = alternate or (COMBAT_AREA_DATA[area_name] and make_area(COMBAT_AREA_DATA[area_name]))
    if not source then return false end

    local extra_att = 0
    local extra_def = 0
    local extra_mp = 0
    local has_magic = state.wand or state.gun
    local has_sword = state.sword
    local has_melee = has_sword or state.stick or state.sword_upgrades > 0
    local required_equipment
    if #source.equipment > 0 then
        required_equipment = list_to_set(source.equipment)
    else
        required_equipment = copy_set(source.equipment)
    end
    local equipment = copy_set(required_equipment)

    for item, _ in pairs(required_equipment) do
        if item == "Stick" and not has_melee then
            if not has_magic then return false end
            equipment.Stick = nil
            equipment.Magic = true
            extra_mp = extra_mp + 2
            extra_att = extra_att - 32
        elseif item == "Sword" and not has_sword then
            if source.is_boss then return false end
            if not has_melee then return false end
            equipment.Sword = nil
            equipment.Stick = true
            extra_att = extra_att + 3
            extra_def = extra_def + 2
            extra_mp = extra_mp + 4
        elseif item == "Shield" then
            equipment.Shield = nil
            extra_def = extra_def + 2
        elseif item == "Laurels" and not state.laurels then
            return false
        elseif item == "Magic" and not has_magic then
            equipment.Magic = nil
            extra_att = extra_att + 2
            extra_def = extra_def + 2
            extra_mp = extra_mp - 32
        end
    end

    local modified = {
        att = source.att + extra_att,
        def = source.def + extra_def,
        potion = source.potion,
        hp = source.hp,
        sp = source.sp,
        mp = source.mp + extra_mp,
        potions = source.potions,
        equipment = equipment,
        is_boss = source.is_boss,
    }
    if has_required_stats(modified, state) then return true end

    if has_sword and equipment.Sword and has_magic then
        local magic_only = copy_set(equipment)
        magic_only.Sword = nil
        magic_only.Magic = true
        return check_combat_reqs("none", state, {
            att = modified.att - 32,
            def = modified.def,
            potion = modified.potion,
            hp = modified.hp,
            sp = modified.sp,
            mp = modified.mp + 4,
            potions = modified.potions,
            equipment = magic_only,
            is_boss = modified.is_boss,
        })
    elseif has_melee and equipment.Stick and has_magic then
        local magic_only = copy_set(equipment)
        magic_only.Stick = nil
        magic_only.Magic = true
        return check_combat_reqs("none", state, {
            att = modified.att - 32,
            def = modified.def,
            potion = modified.potion,
            hp = modified.hp,
            sp = modified.sp,
            mp = modified.mp + 2,
            potions = modified.potions,
            equipment = magic_only,
            is_boss = modified.is_boss,
        })
    end

    return false
end

function combat_logic_mode()
    local setting = Tracker:FindObjectForCode("combat_logic_setting")
    return setting and setting.CurrentStage or 0
end

function has_combat_reqs(area_name)
    return check_combat_reqs(area_name, read_combat_state())
end

function evaluate_combat_reqs(area_name, state)
    return check_combat_reqs(area_name, state)
end

function combat_logic_bosses(area_name)
    return combat_logic_mode() == 0 or has_combat_reqs(area_name)
end

function combat_logic_on(area_name, dagger_bypass, laurels_bypass)
    if combat_logic_mode() ~= 2 then return true end
    return has_combat_reqs(area_name)
        or (dagger_bypass == "dagger" and has_code("dagger"))
        or (laurels_bypass == "laurels" and has_code("dash"))
end
