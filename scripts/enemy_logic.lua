local function has(code, count)
    return Tracker:ProviderCountForCode(code) >= (count or 1)
end

local function has_offerings(code, count)
    local item = Tracker:FindObjectForCode(code)
    return item ~= nil and item.CurrentStage >= count
end

local function has_soul(soul)
    local soul_shuffle = Tracker:FindObjectForCode("enemy_soul_shuffle_setting")
    if not soul_shuffle or not soul_shuffle.Active then
        return true
    end

    local code = ENEMY_SOUL_CODES[soul]
    return code ~= nil and has(code)
end

function enemy_soul_access(soul)
    return has_soul(soul)
end

function enemy_any_soul_access(...)
    for _, soul in ipairs({...}) do
        if has_soul(soul) then
            return true
        end
    end
    return false
end

local function has_melee()
    return has("stick") or has("sword")
end

local function has_sword()
    return has("sword")
end

local function has_wand()
    return has("staff")
end

local function has_orb()
    return has("orb")
end

local function has_short_ice_grapple(difficulty, soul)
    local setting = Tracker:FindObjectForCode("ice_grapple_off")
    return setting ~= nil and setting.CurrentStage >= difficulty
        and has("dagger") and has_orb() and (soul == nil or has_soul(soul))
end

function enemy_access(signature)
    local access = ENEMY_ACCESS_RULES[signature]
    if not access or not has_soul(access.soul) then
        return false
    end

    local rule = access.rule
    if rule == "soul_only" then
        return true
    elseif rule == "melee" then
        return has_melee()
    elseif rule == "sword" then
        return has_sword()
    elseif rule == "sword_or_gun" then
        return has_sword() or has("gun")
    elseif rule == "sword_or_wand" then
        return has_sword() or has_wand()
    elseif rule == "melee_or_wand_or_gun" then
        return has_melee() or has_wand() or has("gun")
    elseif rule == "sword_or_wand_or_gun" then
        return has_sword() or has_wand() or has("gun")
    elseif rule == "sword_orb" then
        return has_sword() and has_orb()
    elseif rule == "envoy" or rule == "envoy_combat" then
        return (has_sword() and has_orb()) or has("gun")
    elseif rule == "envoy_shop" then
        return has_sword() and has_soul("rudelings")
    elseif rule == "beefboy" then
        return has_sword() and (has_offerings("fangs", 2) or sword_upgrade_count() >= 4)
    elseif rule == "fairy" then
        return has_sword() or has_wand() or (has_melee() and has_orb())
    elseif rule == "fairy_gauntlet" then
        return has_wand() or (has_sword() and has_orb())
    elseif rule == "siege_engine" then
        if combat_logic_mode() >= 1 then
            return has_combat_reqs("siege_engine")
        end
        return has_sword() and has_wand()
    elseif rule == "crab_shell" then
        return has_melee() and has_orb()
    elseif rule == "librarian" then
        if combat_logic_mode() >= 1 then
            return has_ladder("ladders_in_library") and has_combat_reqs("librarian")
        end
        return has_sword() and has_ladder("ladders_in_library") and has_orb()
            and (has("gun") or has_wand())
    elseif rule == "boss_scavenger" then
        local accessible
        if combat_logic_mode() >= 1 then
            accessible = has_combat_reqs("boss_scavenger")
        else
            accessible = has_sword()
        end

        local ice_grapple = Tracker:FindObjectForCode("ice_grapple_off")
        if ice_grapple and ice_grapple.CurrentStage >= 2 then
            accessible = accessible and has_short_ice_grapple(2, "boss_scavenger")
        end
        return accessible
    elseif rule == "voidtouched" then
        return has_sword() and has("dash") and has_offerings("fangs", 3)
    elseif rule == "autobolt_gap" then
        return has("gun") or (has_sword() and (has_orb() or has("dash")))
    elseif rule == "frog_secret" then
        return has_sword() and (has("dash") or has_orb())
    elseif rule == "ice_grapple_blob" then
        return has("dagger") and has_wand() and has_orb() and has("icerod")
    elseif rule == "frog_atoll" then
        return has_sword() and (has_orb() or has("dash"))
    elseif rule == "scavenger_sniper" then
        return has_wand() or (has_sword() and has_orb())
    elseif rule == "laser_cathedral_orb" then
        return has_melee() and has_orb()
    elseif rule == "laser_cathedral_shop" then
        return has_sword() and has_soul("rudelings")
    end

    return false
end

function enemy_equipment_access(signature)
    local access = ENEMY_ACCESS_RULES[signature]
    if not access or not has_soul(access.soul) then return false end

    if access.rule == "voidtouched" then
        return has_sword()
    elseif access.rule == "siege_engine" and combat_logic_mode() >= 1 then
        return has_combat_equipment("siege_engine")
    elseif access.rule == "librarian" and combat_logic_mode() >= 1 then
        return has_ladder("ladders_in_library") and has_combat_equipment("librarian")
    elseif access.rule == "boss_scavenger" and combat_logic_mode() >= 1 then
        local accessible = has_combat_equipment("boss_scavenger")
        local ice_grapple = Tracker:FindObjectForCode("ice_grapple_off")
        if ice_grapple and ice_grapple.CurrentStage >= 2 then
            accessible = accessible and has_short_ice_grapple(2, "boss_scavenger")
        end
        return accessible
    end
    return enemy_access(signature)
end

function boss_reward_access(boss)
    if boss == "siege_engine" then
        return has_soul("siege_engine") and (
            (combat_logic_mode() >= 1 and has_combat_reqs("siege_engine"))
            or (combat_logic_mode() == 0 and has_sword() and has_wand())
        )
    elseif boss == "librarian" then
        return has_soul("librarian") and has_ladder("ladders_in_library") and (
            (combat_logic_mode() >= 1 and has_combat_reqs("librarian"))
            or (combat_logic_mode() == 0 and has_sword() and has_orb()
                and (has("gun") or has_wand()))
        )
    elseif boss == "boss_scavenger" then
        if not has_soul("boss_scavenger") then return false end
        if combat_logic_mode() >= 1 then
            local accessible = has_combat_reqs("boss_scavenger")
            local ice_grapple = Tracker:FindObjectForCode("ice_grapple_off")
            if ice_grapple and ice_grapple.CurrentStage >= 2 then
                accessible = accessible and has_short_ice_grapple(2, "boss_scavenger")
            end
            return accessible
        end
        return has_sword() or has_short_ice_grapple(2, "boss_scavenger")
    elseif boss == "gauntlet" then
        local souls = has_soul("fairies") and has_soul("fleemers")
            and has_soul("custodians") and has_soul("garden_knight")
            and has_soul("frogs") and has_soul("rudelings")
        if not souls then return false end
        if combat_logic_mode() >= 1 then
            return has_combat_reqs("gauntlet")
        end
        return has_sword() and has_wand()
    end
    return false
end

function boss_reward_equipment_access(boss)
    if boss == "siege_engine" then
        return has_soul("siege_engine") and (
            (combat_logic_mode() >= 1 and has_combat_equipment("siege_engine"))
            or (combat_logic_mode() == 0 and has_sword() and has_wand())
        )
    elseif boss == "librarian" then
        return has_soul("librarian") and has_ladder("ladders_in_library") and (
            (combat_logic_mode() >= 1 and has_combat_equipment("librarian"))
            or (combat_logic_mode() == 0 and has_sword() and has_orb()
                and (has("gun") or has_wand()))
        )
    elseif boss == "boss_scavenger" then
        if not has_soul("boss_scavenger") then return false end
        if combat_logic_mode() >= 1 then
            local accessible = has_combat_equipment("boss_scavenger")
            local ice_grapple = Tracker:FindObjectForCode("ice_grapple_off")
            if ice_grapple and ice_grapple.CurrentStage >= 2 then
                accessible = accessible and has_short_ice_grapple(2, "boss_scavenger")
            end
            return accessible
        end
        return has_sword() or has_short_ice_grapple(2, "boss_scavenger")
    elseif boss == "gauntlet" then
        local souls = has_soul("fairies") and has_soul("fleemers")
            and has_soul("custodians") and has_soul("garden_knight")
            and has_soul("frogs") and has_soul("rudelings")
        if not souls then return false end
        if combat_logic_mode() >= 1 then
            return has_combat_equipment("gauntlet")
        end
        return has_sword() and has_wand()
    end
    return false
end

function garden_knight_traversal_access()
    if not has_soul("garden_knight") then return false end
    if combat_logic_mode() == 0 then return has_sword() end
    return has_combat_reqs("garden_knight")
end

function garden_knight_traversal_equipment_access()
    if not has_soul("garden_knight") then return false end
    if combat_logic_mode() == 0 then return has_sword() end
    return has_combat_equipment("garden_knight")
end

function heir_combat_access()
    if not has_soul("the_heir") then return false end
    if combat_logic_mode() == 0 or is_hexquest_on() then return true end
    return has_combat_reqs("heir")
end

function heir_combat_equipment_access()
    if not has_soul("the_heir") then return false end
    if combat_logic_mode() == 0 or is_hexquest_on() then return true end
    return has_combat_equipment("heir")
end

function west_garden_bush_access()
    return has_soul("rudelings") or has_soul("chompignom")
        or has_sword() or has_wand() or has("dash") or has("gun")
        or (has_melee() and has("firesword"))
end

function west_garden_checkpoint_to_dagger_access()
    return west_garden_bush_access()
end

function west_garden_ice_soul_access()
    return has_soul("rudelings") or has_soul("chompignom")
end

function can_get_past_bushes_access()
    return has_sword() or has_wand() or has("dash") or has("gun")
        or (has_melee() and has("firesword"))
end

function east_forest_above_guard_house_access()
    return can_get_past_bushes_access()
        or has_soul("blobs") or has_soul("hedgehogs")
        or (has_soul("rudelings") and has_orb())
end

function forest_belltower_to_fortress_access()
    return has_soul("blobs") or can_get_past_bushes_access()
end

function fortress_to_forest_belltower_access()
    return can_get_past_bushes_access()
        or (has_soul("blobs") and has_orb())
end

function overworld_after_envoy_access()
    return has("dash") or has_orb()
        or (has_soul("envoy") and (has("gun") or has("bigsword")))
end

function forest_grave_path_bush_access()
    return has_soul("rudelings") or has_soul("hedgehogs")
        or has_sword() or has_wand() or has("dash") or has("gun")
        or (has_melee() and has("firesword"))
end

function hourglass_combat_access()
    if combat_logic_mode() ~= 2 then return true end
    return has_sword() and (has("shield") or sword_upgrade_count() >= 3)
end

function west_garden_tree_combat_access()
    return combat_logic_mode() ~= 2 or has_wand() or has("gun")
end

function ruined_atoll_birds_combat_access()
    return combat_logic_mode() ~= 2 or has_melee() or has("dash") or has("gun")
end

local function ruined_atoll_statue_route_access()
    if not has("pray") then return false end

    local fuse_shuffle = Tracker:FindObjectForCode("fuse_shuffle")
    if fuse_shuffle and fuse_shuffle.Active then
        if not (has("atoll_northeast_fuse") and has("atoll_northwest_fuse")
                and has("atoll_southeast_fuse") and has("atoll_southwest_fuse")) then
            return false
        end
    else
        local standard_route = has_ladder("ladders_in_south_atoll")
            and (has("dash") or has_orb())
            and (has_sword() or has("gun") or has_wand())
        local ladder_storage = Tracker:FindObjectForCode("ladder_storage_off")
        local hard_storage_route = ladder_storage and ladder_storage.CurrentStage >= 3
            and can_ls() and has_wand()
        if not standard_route and not hard_storage_route then return false end
    end

    return true
end

function ruined_atoll_statue_access()
    return ruined_atoll_statue_route_access()
        and (combat_logic_mode() ~= 2 or has_combat_reqs("ruined_atoll"))
end

function ruined_atoll_statue_equipment_access()
    return ruined_atoll_statue_route_access()
        and (combat_logic_mode() ~= 2 or has_combat_equipment("ruined_atoll"))
end

function frogs_above_vault_combat_access()
    return combat_logic_mode() ~= 2 or has("dash") or has_combat_reqs("frogs_domain")
end

function frogs_above_vault_combat_equipment_access()
    return combat_logic_mode() ~= 2 or has("dash") or has_combat_equipment("frogs_domain")
end

function ziggurat_bridge_switch_combat_access()
    local wand_route = has_wand() and has("dash")
    if combat_logic_mode() == 2 then
        return wand_route or has_combat_reqs("rooted_ziggurat")
    end
    return has_sword() or wand_route
end

function ziggurat_bridge_switch_combat_equipment_access()
    local wand_route = has_wand() and has("dash")
    if combat_logic_mode() == 2 then
        return wand_route or has_combat_equipment("rooted_ziggurat")
    end
    return has_sword() or wand_route
end

function ziggurat_miniboss_route_access()
    if combat_logic_mode() == 2 then
        return has_combat_reqs("rooted_ziggurat")
    end
    return has_sword()
end

function ziggurat_miniboss_route_equipment_access()
    if combat_logic_mode() == 2 then
        return has_combat_equipment("rooted_ziggurat")
    end
    return has_sword()
end

function even_lower_quarry_combat_access()
    if combat_logic_mode() == 2 then
        return has_combat_reqs("quarry")
    end
    return has("mask") or has("maskless")
end

function even_lower_quarry_combat_equipment_access()
    if combat_logic_mode() == 2 then
        return has_combat_equipment("quarry")
    end
    return has("mask") or has("maskless")
end

function swamp_dash_or_combat_access()
    return combat_logic_mode() ~= 2 or has("dash") or has_combat_reqs("swamp")
end

function swamp_dash_or_combat_equipment_access()
    return combat_logic_mode() ~= 2 or has("dash") or has_combat_equipment("swamp")
end

function cathedral_near_spikes_combat_access()
    if combat_logic_mode() ~= 2 then return true end
    return has_combat_reqs("swamp")
        or (has("laurels_zips") and has("dash"))
end

function cathedral_near_spikes_combat_equipment_access()
    if combat_logic_mode() ~= 2 then return true end
    return has_combat_equipment("swamp")
        or (has("laurels_zips") and has("dash"))
end

function cathedral_elevator_access()
    local ice = has_short_ice_grapple(2, "zombie_foxes")
    local fuses = Tracker:FindObjectForCode("fuse_shuffle")
    local fuse_shuffle = fuses and fuses.Active

    if fuse_shuffle then
        return ice or has("cathedral_elevator_fuse")
    end
    return ice or (has("pray")
        and (combat_logic_mode() ~= 2 or has_combat_reqs("swamp")))
end

function cathedral_elevator_equipment_access()
    local ice = has_short_ice_grapple(2, "zombie_foxes")
    local fuses = Tracker:FindObjectForCode("fuse_shuffle")
    local fuse_shuffle = fuses and fuses.Active

    if fuse_shuffle then
        return ice or has("cathedral_elevator_fuse")
    end
    return ice or (has("pray")
        and (combat_logic_mode() ~= 2 or has_combat_equipment("swamp")))
end
