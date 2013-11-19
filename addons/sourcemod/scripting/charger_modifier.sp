#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdktools_functions> 
#include <sdkhooks>

#define TEAM_SURVIVOR           2 
#define TEAM_INFECTED           3

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define CHARGER_DMG_DEFAULT     10.0
#define CHARGER_DMG_STUMBLE      2.0
#define CHARGER_DMG_POUND       15.0

#define CHARGER_KILL_TIME       0.05


enum TankOrSIWeapon
{
    TANKWEAPON,
    CHARGERWEAPON,
    SIWEAPON
}

new Handle: hInflictorTrie = INVALID_HANDLE;                    // names to look up
new bool: bLateLoad;

new Handle: hDmgPunch = INVALID_HANDLE;                         // damage per normal punch
new Handle: hDmgFirst = INVALID_HANDLE;                         // damage for first punch after spawning
new Handle: hDmgSmash = INVALID_HANDLE;                         // damage for the smash-inpact (def.10)
new Handle: hDmgStumble = INVALID_HANDLE;                       // damage for stumble
new Handle: hDmgPound = INVALID_HANDLE;                         // damage for pound-slams (replaces natural cvar)

new bool: bChargerPunched[MAXPLAYERS + 1];                      // whether charger player got a punch in current life
new bool: bChargerCharging[MAXPLAYERS + 1];                     // whether the charger is in a charge


/*
    -----------------------------------------------------------------------------------------------------------------------------------------------------

    Changelog
    ---------


    -----------------------------------------------------------------------------------------------------------------------------------------------------
 */


public Plugin:myinfo = 
{
    name = "Charger Damage Modifier",
    author = "Tabun",
    description = "Modifies charger damage",
    version = "0.1c_pm",
    url = "nope"
}

/* -------------------------------
 *      Init
 * ------------------------------- */

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax)
{
    bLateLoad = late;
    return APLRes_Success;
}

public OnPluginStart()
{
    // hook already existing clients if loading late
    if (bLateLoad) {
        for (new i = 1; i < MaxClients+1; i++) {
            if (IsClientInGame(i)) {
                SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
    
    // cvars
    hDmgPunch = CreateConVar("charger_dmg_punch",          "8",    "Damage per (normal) charger punch.", FCVAR_PLUGIN, true, 0.0);
    hDmgFirst = CreateConVar("charger_dmg_firstpunch",     "8",    "Damage for first charger punch (in its life).", FCVAR_PLUGIN, true, 0.0);
    hDmgSmash = CreateConVar("charger_dmg_impact",         "10",    "Damage for impact after a charge.", FCVAR_PLUGIN, true, 0.0);
    hDmgStumble = CreateConVar("charger_dmg_stumble",      "2",    "Damage for impact after a charge.", FCVAR_PLUGIN, true, 0.0);
    hDmgPound = CreateConVar("charger_dmg_pound",          "15",    "Damage for pounds after charge/collision completed.", FCVAR_PLUGIN, true, 0.0);
    
    // hooks
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
    HookEvent("player_spawn", PlayerSpawn_Event, EventHookMode_Post);
    HookEvent("charger_charge_start", ChargeStart_Event, EventHookMode_Post);
    HookEvent("charger_charge_end", ChargeEnd_Event, EventHookMode_Post);
    
    // trie
    hInflictorTrie = BuildInflictorTrie();
}


/* -------------------------------
 *      General hooks / events
 * ------------------------------- */

public OnClientPostAdminCheck(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnMapStart()
{
    setCleanSlate();
}

public Action: RoundStart_Event (Handle:event, const String:name[], bool:dontBroadcast)
{
    setCleanSlate();
}

public Action:PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    //if (!GetConVarBool(hPluginEnabled))                                 { return Plugin_Continue; }
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));

    // the usual checks, only actual jockeys
    if (!IsClientAndInGame(client))                                     { return Plugin_Continue; }
    if (GetClientTeam(client) != TEAM_INFECTED)                         { return Plugin_Continue; }
    if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_CHARGER)   { return Plugin_Continue; }
    
    // just spawned, prepare for that first punch
    bChargerPunched[client] = false;
    bChargerCharging[client] = false;
    
    return Plugin_Continue;
}

public ChargeStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new clientId = GetEventInt(event, "userid");
    new client = GetClientOfUserId(clientId);
    
    if (IsClientAndInGame(client)) {
        bChargerCharging[client] = true;
    }    
}
public ChargeEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
    new clientId = GetEventInt(event, "userid");
    new client = GetClientOfUserId(clientId);
    
    if (IsClientAndInGame(client)) {
        bChargerCharging[client] = false;
    }   
}

/* --------------------------------------
 *     GOT MY EYES ON YOU, DAMAGE
 * -------------------------------------- */

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damageType, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
    //if (!GetConVarBool(hPluginEnabled)) { return Plugin_Continue; }
    if (!inflictor || !attacker || !victim || !IsValidEdict(victim) || !IsValidEdict(inflictor)) { return Plugin_Continue; }

    // only check player-to-player damage
    decl String:classname[64];
    if (IsClientAndInGame(attacker) && IsClientAndInGame(victim))
    {
        if (attacker == inflictor)                                              // for claws
        {
            GetClientWeapon(inflictor, classname, sizeof(classname));
        }
        else
        {
            GetEdictClassname(inflictor, classname, sizeof(classname));         // for tank punch/rock
        }
    }
    else { return Plugin_Continue; }
    
    // check teams
    if (GetClientTeam(attacker) != TEAM_INFECTED || GetClientTeam(victim) != TEAM_SURVIVOR) { return Plugin_Continue; }
    
    // only allow chargers
    if (GetEntProp(attacker, Prop_Send, "m_zombieClass") != ZC_CHARGER) { return Plugin_Continue; }
    
    // test:
    //PrintToChatAll("[test:] inflictor class: [%s] type [%d] damage [%.0f] force [%.0f %.0f %.0f]", classname, damageType, damage, damageForce[0], damageForce[1], damageForce[2]);
    
    // only check tank punch/rock and SI claws (also rules out anything but infected-to-survivor damage)
    new TankOrSIWeapon: inflictorID;
    if (!GetTrieValue(hInflictorTrie, classname, inflictorID)) { return Plugin_Continue; }
    if (inflictorID != CHARGERWEAPON) { return Plugin_Continue; }
    
    
    // okay, it is a charger
    
    // punch =          10 + has force > 0,0,0
    // bowl =           10 + has force > 0,0,0
    // stumble =        2 (+ small force)
    // charge impact =  10 + force 0,0,0
    // pound =          15 + force 0,0,0
    
    if (damage == CHARGER_DMG_DEFAULT)
    {
        if (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0) {
            // CHARGE IMPACT
            
            damage = GetConVarFloat(hDmgSmash);
            return Plugin_Changed;
            
            } else {

            // PUNCH
            
            if (!bChargerPunched[attacker])
            {
                // this is the first attack
                bChargerPunched[attacker] = true;
                damage = GetConVarFloat(hDmgFirst);
                return Plugin_Changed;
            }
            // this is a (second+) charger punch
            damage = GetConVarFloat(hDmgPunch);
            return Plugin_Changed;
        }
    }
    else if (damage == CHARGER_DMG_STUMBLE)
    {
        // STUMBLE
        damage = GetConVarFloat(hDmgStumble);
        return Plugin_Changed;
    }
    else if (damage == CHARGER_DMG_POUND && (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0))
    {
        // POUND
        damage = GetConVarFloat(hDmgPound);
        return Plugin_Changed;
    }
    /*
    // this is a (second+) charger punch
    damage = GetConVarFloat(hDmgPunch);
    return Plugin_Changed;
    */
    PrintToChatAll("\x04Warning! \x05Charger doing a type of damage it shouldn't! infl.: [%s] type [%d] damage [%.0f] force [%.0f %.0f %.0f]", classname, damageType, damage, damageForce[0], damageForce[1], damageForce[2]);
    return Plugin_Handled;
}

/* --------------------------------------
 *     Shared function(s)
 * -------------------------------------- */

bool:IsClientAndInGame(index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}

setCleanSlate()
{
    new i, maxplayers = MAXPLAYERS;
    for (i = 1; i <= maxplayers; i++)
    {
        bChargerPunched[i] = false;
        bChargerCharging[i] = false;
    }
}

Handle:BuildInflictorTrie()
{
    new Handle: trie = CreateTrie();
    SetTrieValue(trie, "weapon_tank_claw",      TANKWEAPON);
    SetTrieValue(trie, "tank_rock",             TANKWEAPON);
    //SetTrieValue(trie, "weapon_boomer_claw",    SIWEAPON);
    SetTrieValue(trie, "weapon_charger_claw",   CHARGERWEAPON);
    //SetTrieValue(trie, "weapon_hunter_claw",    SIWEAPON);
    //SetTrieValue(trie, "weapon_jockey_claw",    SIWEAPON);
    //SetTrieValue(trie, "weapon_smoker_claw",    SIWEAPON);
    //SetTrieValue(trie, "weapon_spitter_claw",   SIWEAPON);
    return trie;    
}
