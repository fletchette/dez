#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define BRUSH_CRABHAMMER "crabHammer"
#define BRUSH_CRABWINNER "kingcrab"
#define BRUSH_CRABSHOWDOWN "crabShowdown"

#define PLUGIN_VERSION "0.1.5"

public Plugin:myinfo =
{
	name = "Crabhammer",
	author = "fletch",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
}

ConVar g_cEnabled;

new Handle:gHud;

new bool:g_Spycrabbing[MAXPLAYERS+1] = {false, ...}; //Touching one of the spycrabbing ents
new bool:g_AllowTaunt[MAXPLAYERS+1] = {false, ...};
new g_Spycrabs[MAXPLAYERS+1] = {0, ...};

new g_PlayersInSpycrab = 0; //The number of players currently spycrabbing, no matter what the Event Status is
new g_SpycrabEventStatus = 0; //Inactive, Counting Down, In Progress, Showdown

new g_Showdown[2] = {-1, -1}; //This struct stores the two players in the showdown

new bool:g_Enabled = true;

//Events

public OnPluginStart() {
	//Hooks
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(Event_Taunt, "taunt");
	AddCommandListener(Event_Taunt, "+taunt");
	AddCommandListener(Event_Suicide, "explode");
	AddCommandListener(Event_Suicide, "kill");
	AddCommandListener(Event_Suicide, "jointeam");
	AddCommandListener(Event_Suicide, "joinclass");

	//Cvars
	g_cEnabled = CreateConVar("sm_dez_crabhammer_enabled", "1", "Enables/Disables the plugin");
	
	//Hud
	gHud = CreateHudSynchronizer();
	if(gHud == INVALID_HANDLE) {
		SetFailState("HUD synchronisation is not supported by this mod (fuck off)");
	}
}

public OnMapStart() {
	ResetCrab();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	new i = -1,
		bool:found = false;
	
	decl String:strName[50];
	
	while((i = FindEntityByClassname(i, "trigger_multiple")) != -1) {
		GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, BRUSH_CRABHAMMER)) {
			found = true;
			SDKHook(i, SDKHook_StartTouchPost, OnStartTouchCrab);
			SDKHook(i, SDKHook_EndTouch, OnStopTouchCrab);
		}
	}
	if(!found) {
		g_Enabled = false;
	}
}

//Prevent spycrabbers from taunting
public Action:Event_Taunt(client, const String:strCommand[], args) {
	if(IsValidClient(client)) {
		if(g_Spycrabbing[client]) {
			if(g_AllowTaunt[client]) {
				g_AllowTaunt[client] = false;
			} else {
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

//Prevent spycrabbers from jumping
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	if(IsValidClient(client)) {
		if(g_Spycrabbing[client]) {
			if(buttons & IN_JUMP) {
				//return Plugin_Handled;
			}
			if(impulse & 1 << 3) {
				PrintToChatAll("Disguising");
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

//Prevent spycrabbers from suiciding
public Action:Event_Suicide(client, const String:strCommand[], iArgs) {
    if(IsValidClient(client)) {
		if(g_Spycrabbing[client]) {
			return Plugin_Handled;
		}
	}
    return Plugin_Continue;
}

public OnEntityCreated(entity, const String:classname[]) {
    if(StrEqual(classname, "instanced_scripted_scene", false)) {
		SDKHook(entity, SDKHook_Spawn, OnSceneSpawned);
	}
}

public OnSceneSpawned(entity) {
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwner"), 
		String:scenefile[128];
		
	if(g_Spycrabbing[client]) {
		GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
		if(StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd")) {
			g_Spycrabs[client]++;
		}
	}
}

//Tracking crabbers

public OnStartTouchCrab(entity, client) {
	JoinCrab(client);
}

public OnStopTouchCrab(entity, client) {
	if(!IsClientInShowdown(client)) {
		LeaveCrab(client);
	}
}

public OnClientDisconnect(client) {
	LeaveCrab(client);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	LeaveCrab(client);
}

//Functions

public JoinCrab(client) {
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		if(!g_Spycrabbing[client]) {
			//If the spycrab hasn't started yet
			if(g_SpycrabEventStatus < 2) {
				g_Spycrabbing[client] = true;
				g_PlayersInSpycrab++;
				CheckCrabEventStart();
			} else {
				DenyCrabEntry(client);
			}
		}
	}
}

public LeaveCrab(client) {
	if(IsValidClient(client)) {
		if(g_Spycrabbing[client]) {
			ResetVars(client);
			g_Spycrabbing[client] = false;
			g_PlayersInSpycrab--;
		}
	}
}

public IsClientInShowdown(client) {
	if(g_SpycrabEventStatus == 3) {
		if(client == g_Showdown[0] || client == g_Showdown[1]) {
			return true;
		}
	}
	return false;
}

public DenyCrabEntry(client) {
	ForcePlayerSuicide(client);
	PrintCenterText(client, "A tournament is already under way");
}

public CheckCrabEventStart() {
	if(g_SpycrabEventStatus == 0) {
		if(g_PlayersInSpycrab > 1) {
			g_SpycrabEventStatus = 1;
			PrintHudCentreText("A spy crab tournament challenge has been issued", 5.0);
			CreateTimer(7.0, CountdownMessage, 0);
		}
	}
}

public Action:CountdownMessage(Handle:timer, any:counter) {
	if(counter == 0) {
		PrintHudCentreText("Take the teleport to the arena and accept the crab king's challenge", 8.0);
		CreateTimer(10.0, CountdownMessage, 1);
	} else if(counter == 1) {
		PrintHudCentreText("60 seconds remaining", 4.0);
		CreateTimer(30.0, CountdownMessage, 2);
	} else if(counter == 2) {
		PrintHudCentreText("30 seconds remaining", 4.0);
		CreateTimer(25.0, CountdownMessage, 3);
	} else if(counter == 3) {
		CreateTimer(1.0, CountdownFive, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:CountdownFive(Handle:timer) {
	static counter = 5;
	if(counter < 1) {
		counter = 5;
		if(g_PlayersInSpycrab > 2) {
			g_SpycrabEventStatus = 2;
			CreateTimer(7.0, TauntCrabbers, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(1.0, FreezeCrabbers);
		} else {
			PrintHudCentreText("Tournament cancelled", 4.0);
			ResetCrab();
		}
		return Plugin_Stop;
	}
	
	decl String:buffer[22];
	Format(buffer, sizeof(buffer), "%d seconds remaining", counter);
	
	PrintHudCentreText(buffer, 1.0);
	
	counter--;
	return Plugin_Continue;
}

public Action:FreezeCrabbers(Handle:timer) {
	for(new client=0; client<MaxClients; client++) {
		if(IsValidClient(client)) {
			if(g_Spycrabbing[client]) {
				SetEntityMoveType(client, MOVETYPE_STEP);
			}
		}
	}
}

public Unfreeze(client) {
	if(IsValidClient(client)) { 
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}

public Action:TauntCrabbers(Handle:timer) {
	if(g_SpycrabEventStatus > 1) {
		for(new client=0; client<MaxClients; client++) {
			if(IsValidClient(client)) {
				if(g_Spycrabbing[client]) {
					g_AllowTaunt[client] = true;
					FakeClientCommand(client, "taunt");
				}
			}
		}
		CreateTimer(3.0, HandleCrabs);
		return Plugin_Continue;
	} else {
		return Plugin_Stop;
	}
}

public Action:HandleCrabs(Handle:timer) {
	//Calculate remaining players

	for(new client=0; client<MaxClients; client++) {
		if(IsValidClient(client)) {
			if(g_SpycrabEventStatus == 2) {
				if(g_Spycrabbing[client]) {
					if(g_Spycrabs[client] > 0) {
						ForcePlayerSuicide(client);
					}
				}
			} else if(g_SpycrabEventStatus == 3) {
				if(g_Spycrabbing[client]) {
					if(IsClientInShowdown(client)) {
						if(g_Spycrabs[client] > 2) {
							ForcePlayerSuicide(client);
						}
					}
				}
			}
		}
	}
	

	PrintToChatAll("RemainingPlayers: %d", g_PlayersInSpycrab);
	
		
	if(g_SpycrabEventStatus == 2) {
		if(g_PlayersInSpycrab == 2) {
			decl String:nameOne[64], String:nameTwo[64], String:buffer[162];
			for(new client=0; client<MaxClients; client++) {
				if(g_Spycrabbing[client]) {
					if(g_Showdown[0] == -1) {
						g_Showdown[0] = client;
						GetClientName(client, nameOne, 64);
					} else {
						g_Showdown[1] = client;
						GetClientName(client, nameTwo, 64);
					}
				}
			}
			
			if(IsValidClient(g_Showdown[0]) && IsValidClient(g_Showdown[1])) {
				g_SpycrabEventStatus = 3;
				
				Format(buffer, sizeof(buffer), "%s vs %s - first to three spycrabs loses", nameOne, nameTwo);
				PrintHudCentreText(buffer, 4.0);
				
				Unfreeze(g_Showdown[0]);
				Unfreeze(g_Showdown[1]);
				
				TeleportToShowdown(g_Showdown[0], 0);
				TeleportToShowdown(g_Showdown[1], 1);
				CreateTimer(0.5, FreezeCrabbers);
			} else {
				PrintToChatAll("Error #1 :(");
				ResetCrab();
			}
			
		} else if(g_PlayersInSpycrab == 1) {
			for(new client=0; client<MaxClients; client++) {
				if(g_Spycrabbing[client]) {
					g_SpycrabEventStatus = 0;
					SpycrabWinner(client);
				}
			}
			ResetCrab();
		} else if(g_PlayersInSpycrab < 1) {
			PrintHudCentreText("Don't buy a lottery ticket..", 5.0);
			ResetCrab();
		}
	} else if(g_SpycrabEventStatus == 3) { //Showdown mode
		if(g_PlayersInSpycrab == 1) {
			g_SpycrabEventStatus = 0;
			if(g_Spycrabbing[g_Showdown[0]]) { //g_Showdown[0] won
				SpycrabWinner(g_Showdown[0]);
			} else {
				SpycrabWinner(g_Showdown[1]);
			}
		} else if(g_PlayersInSpycrab == 0) {
			PrintHudCentreText("Don't buy a lottery ticket..", 5.0);
		}
		
		if(g_PlayersInSpycrab < 2) {
			ResetCrab();
		}
	} else {
		PrintToChatAll("Unknown error #2 :(");
		ResetCrab();
	}
}

public SpycrabWinner(client) {
	Unfreeze(client);
	TeleportToWinner(client);
	decl String:name[64], String:buffer[90];
	GetClientName(client, name, 64);
	Format(buffer, sizeof(buffer), "%s is the new spycrab king!", name);
	PrintHudCentreText(buffer, 4.0);
}

public ResetVars(client) {
	g_AllowTaunt[client] = false;	
	g_Spycrabs[client] = 0;
}

public ResetVarsAll() {
	for(new client=0; client<MaxClients; client++) {
		ResetVars(client);	
	}
}

public ResetCrab() {
	g_SpycrabEventStatus = 0;
	g_Showdown = {-1, -1};
	ResetVarsAll();
}

public TeleportToShowdown(client, side) { //0=Left, 1=Right
	decl String:strName[50];
	new entity = -1, 
		pointer = -1;

	while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE) {	
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, BRUSH_CRABSHOWDOWN)) {
			pointer = entity;
			break;
		}
	}
	
	decl Float:min[3], Float:max[3], Float:origin[3];
	if(pointer != -1) {
		GetEntPropVector(pointer, Prop_Send, "m_vecMins", min);
		GetEntPropVector(pointer, Prop_Send, "m_vecMaxs", max);
		GetEntPropVector(pointer, Prop_Send, "m_vecOrigin", origin);
		
		origin[2] += min[2] / 2;
		origin[0] += (side == 0 ? max[0] : min[0]) * 0.6;
		
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}
}

public TeleportToWinner(client) {
	decl String:strName[50];
	new entity = -1;
	while((entity = FindEntityByClassname(entity, "info_teleport_destination")) != INVALID_ENT_REFERENCE) {	
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(StrEqual(strName, BRUSH_CRABWINNER)) {
			new Float:pos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
			if(IsValidClient(client)) {
				TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}


//Stocks
stock PrintHudCentreTextClient(client, String:text[], Float:time) {
	SetHudTextParams(-1.0, 0.3, time, 155, 48, 255, 1);
	if(IsValidClient(client) && !IsFakeClient(client)) {
		ShowSyncHudText(client, gHud, "%s", text);
	}
}

stock PrintHudCentreText(String:text[], Float:time) {
	SetHudTextParams(-1.0, 0.3, time, 155, 48, 255, 1);
	for(new client=0; client<MaxClients; client++) {
		if(IsValidClient(client) && !IsFakeClient(client)) {
			ShowSyncHudText(client, gHud, "%s", text);
		}
	}
}

stock bool:IsValidClient(iClient, bool:bReplay = true) {
	if(iClient <= 0 || iClient > MaxClients)
		return false;
	if(!IsClientInGame(iClient))
		return false;
	if(bReplay && (IsClientSourceTV(iClient) || IsClientReplay(iClient)))
		return false;
	return true;
}
