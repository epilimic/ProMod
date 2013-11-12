#include <sourcemod>
new bool:RB_bIsNoGlows = false;
new bool:RB_bNoGlowsRequest[2] = { false, false };
new bool:RB_bIsRealismMode = false;
new bool:RB_bRealismRequest[2] = { false, false };
new String:	g_sTeamName[8][]					= {"Spectator", "" , "Survivor", "Infected", "", "Infected", "Survivors", "Infected"};
const 	NUM_OF_SURVIVORS 	= 4;
const 	TEAM_SURVIVOR		= 2;
const 	TEAM_INFECTED 		= 3;

public Plugin:myinfo = {
    name        = "Glowism Toggler",
    author      = "epilimic, credit to ProdigySim - this began as the old BuffSI.",
    version     = "1",
    description = "!realism !unrealism !noglows !glows - Turn them on or off. Admins: !forceglows etc"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_realism", RB_Command_RealismMode);
	RegConsoleCmd("sm_unrealism", RB_Command_UnRealismMode);
	RegAdminCmd("sm_forcerealism", RB_Command_ForceRealismMode, ADMFLAG_BAN, "Shits about to get real(ism).");
	RegAdminCmd("sm_forceunrealism", RB_Command_ForceUnRealismMode, ADMFLAG_BAN, "Shits about to get unreal(ism).");
	RegConsoleCmd("sm_noglows", RB_Command_NoGlows);
	RegConsoleCmd("sm_glows", RB_Command_Glows);
	RegAdminCmd("sm_forcenoglows", RB_Command_ForceNoGlows, ADMFLAG_BAN, "No More Glows.");
	RegAdminCmd("sm_forceglows", RB_Command_ForceGlows, ADMFLAG_BAN, "Glows!");
}

public Action:RB_Command_RealismMode(client, args)
{
	if(RB_bIsRealismMode)
	{
		PrintToChatAll("Realism mode is already enabled.");
		return Plugin_Handled;
	}
	
	new iTeam = GetClientTeam(client);
	if((iTeam == 2 || iTeam == 3) && !RB_bRealismRequest[iTeam-2])
	{
		RB_bRealismRequest[iTeam-2] = true;
	}
	else
	{
		return Plugin_Handled;
	}
	
	if(RB_bRealismRequest[0] && RB_bRealismRequest[1])
	{
		PrintToChatAll("\x01Both teams have agreed to enable \x05Realism\x01.");
		RB_bIsRealismMode = true;
		RealismMode(true);
	}
	else if(RB_bRealismRequest[0] || RB_bRealismRequest[1])
	{
		PrintToChatAll("\x01The \x05%s \x01have requested to enable \x05Realism\x01. The \x05%s \x01must accept with the \x04!realism \x01command.",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
		CreateTimer(30.0, RP_RealismModeRequestTimeout);
	}
	
	return Plugin_Handled;
}

public Action:RB_Command_UnRealismMode(client, args)
{
	if(!RB_bIsRealismMode)
	{
		PrintToChatAll("Realism mode is already disabled.");
		return Plugin_Handled;
	}
	
	new iTeam = GetClientTeam(client);
	if((iTeam == 2 || iTeam == 3) && !RB_bRealismRequest[iTeam-2])
	{
		RB_bRealismRequest[iTeam-2] = true;
	}
	else
	{
		return Plugin_Handled;
	}
	
	if(RB_bRealismRequest[0] && RB_bRealismRequest[1])
	{
		PrintToChatAll("\x01Both teams have agreed to disable \x05Realism\x01.");
		RB_bIsRealismMode = false;
		RealismMode(false);
	}
	else if(RB_bRealismRequest[0] || RB_bRealismRequest[1])
	{
		PrintToChatAll("\x01The \x05%s \x01have requested to disable \x05Realism\x01. The \x05%s \x01must accept with the \x04!unrealism \x01command.",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
		CreateTimer(30.0, RP_RealismModeRequestTimeout);
	}
	
	return Plugin_Handled;
}

public Action:RB_Command_ForceRealismMode(client, args)
{
	if(RB_bIsRealismMode)
	{
		PrintToChatAll("Realism mode is already enabled.");
		return Plugin_Handled;
	}
	RB_bIsRealismMode = true;
	RealismMode(true);
	PrintToChatAll("\x05Realism \x01mode has been enabled by an admin.");
	return Plugin_Handled;
}

public Action:RB_Command_ForceUnRealismMode(client, args)
{
	if(!RB_bIsRealismMode)
	{
		PrintToChatAll("Realism mode is already disabled.");
		return Plugin_Handled;
	}
	RB_bIsRealismMode = false;
	RealismMode(false);
	PrintToChatAll("\x05Realism \x01mode has been disabled by an admin.");
	return Plugin_Handled;
}

public Action:RP_RealismModeRequestTimeout(Handle:timer)
{
	if(RB_bIsRealismMode){return;}
	RP_ResetRealismModeRequest();
}

RP_ResetRealismModeRequest()
{
	RB_bRealismRequest[0] = false;
	RB_bRealismRequest[1] = false;
	PrintToChatAll("The Realism Mode request timer has expired.");
}

RealismMode(bool:enable)
{
	if (enable)
	{
		SetConVarBool(FindConVar("sv_disable_glow_survivors"), true);
		SetConVarBool(FindConVar("sv_disable_glow_faritems"), true);
		SetConVarFloat(FindConVar("z_non_head_damage_factor_multiplier"), 0.5);
		SetConVarBool(FindConVar("z_head_damage_causes_wounds"), true);
		SetConVarBool(FindConVar("z_use_next_difficulty_damage_factor"), true);
		SetConVarBool(FindConVar("z_witch_always_kills"), true);
	}
	else
	{
		ResetConVar(FindConVar("sv_disable_glow_survivors"));
		ResetConVar(FindConVar("sv_disable_glow_faritems"));
		ResetConVar(FindConVar("z_non_head_damage_factor_multiplier"));
		ResetConVar(FindConVar("z_head_damage_causes_wounds"));
		ResetConVar(FindConVar("z_use_next_difficulty_damage_factor"));
		ResetConVar(FindConVar("z_witch_always_kills"));
	}
}

public Action:RB_Command_NoGlows(client, args)
{
	if(RB_bIsNoGlows)
	{
		PrintToChatAll("Glows are already disabled.");
		return Plugin_Handled;
	}
	
	new iTeam = GetClientTeam(client);
	if((iTeam == 2 || iTeam == 3) && !RB_bNoGlowsRequest[iTeam-2])
	{
		RB_bNoGlowsRequest[iTeam-2] = true;
	}
	else
	{
		return Plugin_Handled;
	}
	
	if(RB_bNoGlowsRequest[0] && RB_bNoGlowsRequest[1])
	{
		PrintToChatAll("\x01Both teams have agreed to \x05disable glows\x01.");
		RB_bIsNoGlows = true;
		NoGlows(true);
	}
	else if(RB_bNoGlowsRequest[0] || RB_bNoGlowsRequest[1])
	{
		PrintToChatAll("\x01The \x05%s \x01have requested to \x05disable glows\x01. The \x05%s \x01must accept with the \x04!noglows \x01command.",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
		CreateTimer(30.0, RP_NoGlowsRequestTimeout);
	}
	
	return Plugin_Handled;
}

public Action:RB_Command_Glows(client, args)
{
	if(!RB_bIsNoGlows)
	{
		PrintToChatAll("Glows are already enabled.");
		return Plugin_Handled;
	}
	
	new iTeam = GetClientTeam(client);
	if((iTeam == 2 || iTeam == 3) && !RB_bNoGlowsRequest[iTeam-2])
	{
		RB_bNoGlowsRequest[iTeam-2] = true;
	}
	else
	{
		return Plugin_Handled;
	}
	
	if(RB_bNoGlowsRequest[0] && RB_bNoGlowsRequest[1])
	{
		PrintToChatAll("\x01Both teams have agreed to \x05enable glows\x01.");
		RB_bIsNoGlows = false;
		NoGlows(false);
	}
	else if(RB_bNoGlowsRequest[0] || RB_bNoGlowsRequest[1])
	{
		PrintToChatAll("\x01The \x05%s \x01have requested to \x05enable glows\x01. The \x05%s \x01must accept with the \x04!glows \x01command.",g_sTeamName[iTeam+4],g_sTeamName[iTeam+3]);
		CreateTimer(30.0, RP_NoGlowsRequestTimeout);
	}
	
	return Plugin_Handled;
}

public Action:RB_Command_ForceNoGlows(client, args)
{
	if(RB_bIsNoGlows)
	{
		PrintToChatAll("Glows are already disabled.");
		return Plugin_Handled;
	}
	RB_bIsNoGlows = true;
	NoGlows(true);
	PrintToChatAll("\x05Glows \x01have been disabled by an admin.");
	return Plugin_Handled;
}

public Action:RB_Command_ForceGlows(client, args)
{
	if(!RB_bIsNoGlows)
	{
		PrintToChatAll("Glows are already enabled.");
		return Plugin_Handled;
	}
	RB_bIsNoGlows = false;
	NoGlows(false);
	PrintToChatAll("\x05Glows \x01have been enabled by an admin.");
	return Plugin_Handled;
}

public Action:RP_NoGlowsRequestTimeout(Handle:timer)
{
	if(RB_bIsNoGlows){return;}
	RP_ResetNoGlowsRequest();
}

RP_ResetNoGlowsRequest()
{
	PrintToChatAll("The No Glows Mode request timer has expired.");
	RB_bNoGlowsRequest[0] = false;
	RB_bNoGlowsRequest[1] = false;
}

NoGlows(bool:enable)
{
	if (enable)
	{
		SetConVarBool(FindConVar("sv_disable_glow_survivors"), true);
		SetConVarBool(FindConVar("sv_disable_glow_faritems"), true);
	}
	else
	{
		ResetConVar(FindConVar("sv_disable_glow_survivors"));
		ResetConVar(FindConVar("sv_disable_glow_faritems"));
	}
}

public OnPluginEnd()
{
	RealismMode(false);
	NoGlows(false);
}
