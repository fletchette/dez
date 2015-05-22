#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

ConVar g_Enabled;
new g_PlayersInSpycrab = 0;
new bool:g_Spycrabbing[MAXPLAYERS+1] = {false, ...};
new bool:g_AllowTaunt[MAXPLAYERS+1] = {false, ...};
new g_Spycrabs[MAXPLAYERS+1] = {0, ...};
new g_SpycrabEventStatus = 0; //Inactive, Counting Down, In Progress, Showdown


new Handle:gHud;

public OnPluginStart() {
	//Event hooks
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(Event_Taunt, "taunt");
	AddCommandListener(Event_Taunt, "+taunt");
	
	//Cvars
	g_Enabled = CreateConVar("sm_dez_crabhammer_enabled", "1", "Enables/Disables the plugin");
	
	//Hud
	gHud = CreateHudSynchronizer();
	if(gHud == INVALID_HANDLE) {
		SetFailState("HUD synchronisation is not supported by this mod");
	}
}

public OnMapStart() {
	g_SpycrabEventStatus = 0;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	new i = -1;
	decl String:strName[50];
	while((i = FindEntityByClassname(i, "trigger_multiple")) != -1) {
		GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName));
		if(strcmp(strName, "crabHammer") == 0) {
			SDKHook(i, SDKHook_StartTouchPost, OnStartTouchCrab);
			SDKHook(i, SDKHook_EndTouch, OnStopTouchCrab);
		}
	}
}

public OnClientDisconnect(client) {
	LeaveCrab(client);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) { //Incase they suicide during a spycrab. Lolmadbru
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client)) {
		LeaveCrab(client);
	}
}

public OnEntityCreated(entity, const String:classname[]) {
    if(StrEqual(classname, "instanced_scripted_scene", false)) {
		SDKHook(entity, SDKHook_Spawn, OnSceneSpawned);
	}
}

public Action:Event_Taunt(client, const String:strCommand[], iArgs) {
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

public OnSceneSpawned(entity) {
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwner"), String:scenefile[128];
	if(g_Spycrabbing[client]) {
		GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
		if(StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd")) {
			HandleCrab(client);
		}
	}
} 

public OnStartTouchCrab(entity, client) {
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		JoinCrab(client);
	}
}

public OnStopTouchCrab(entity, client) {
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		LeaveCrab(client);
	}
}

public JoinCrab(client) {
	if(!g_Spycrabbing[client]) {
		if(g_SpycrabEventStatus < 2) {
			g_Spycrabbing[client] = true;
			g_PlayersInSpycrab++;
			ModifyCrabEvent();
		} else {
			DenyCrab(client);
		}
	}
}

public LeaveCrab(client) {
	if(g_Spycrabbing[client]) {
		ResetVars(client);
		g_PlayersInSpycrab--;
		ModifyCrabEvent();
	}
}

public HandleCrab(client) {
	if(g_SpycrabEventStatus == 2) {
		CreateTimer(3.0, KillCrab, client);
	} else if(g_SpycrabEventStatus == 3) {
		g_Spycrabs[client]++;
		if(g_Spycrabs[client] == 3) {
			CreateTimer(3.0, KillCrab, client);
		}
	}
}

public Action:KillCrab(Handle:timer, client) {
	ForcePlayerSuicide(client);
}

public ModifyCrabEvent() {
	if(g_SpycrabEventStatus == 0) {
		if(g_PlayersInSpycrab > 1) {
			g_SpycrabEventStatus = 1;
			PrintHudCentreText("A spy crab tournament challenge has been issued", 5.0);
			CreateTimer(7.0, CountdownMessage, 0);
		}
	} else if(g_SpycrabEventStatus == 2) {
		if(g_PlayersInSpycrab < 3) {
			g_SpycrabEventStatus = 3;
			PrintToChatAll("ENDING SPYCRAB");
			 //End crab and do showdown
		}
	}
}

public Action:CountdownMessage(Handle:timer, any:counter) {
	if(counter == 0) {
		PrintHudCentreText("Say !teleport to move to the arena and accept the crab king's challenge", 8.0);
		CreateTimer(10.0, CountdownMessage, 1);
	} else if(counter == 1) {
		PrintHudCentreText("60 seconds remaining", 4.0);
		CreateTimer(30.0, CountdownMessage, 2);
	} else if(counter == 2) {
		PrintHudCentreText("30 seconds remaining", 4.0);
		CreateTimer(25.0, StartCountdownFive);
	}
}

public Action:StartCountdownFive(Handle:timer) {
	CreateTimer(1.0, CountdownFive, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:CountdownFive(Handle:timer) {
	static counter = 5;
	if(counter < 1) {
		counter = 5;
		g_SpycrabEventStatus = 2;
		CreateTimer(7.0, StartCrab, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	
	decl String:buffer[22];
	Format(buffer, sizeof(buffer), "%d seconds remaining", counter);
	
	PrintHudCentreText(buffer, 1.0);
	
	counter--;
	return Plugin_Continue;
}

public Action:StartCrab(Handle:timer) {
	if(g_SpycrabEventStatus == 2) {
		PrintToChatAll("Crabbing");
		for(new client=0; client<MaxClients; client++) {
			if(IsValidClient(client)) {
				if(g_Spycrabbing[client]) {
					g_AllowTaunt[client] = true;
					FakeClientCommand(client, "taunt");
				}
			}
		}
		return Plugin_Continue;
	} else {
		return Plugin_Stop;
	}
}

public DenyCrab(client) {
	ForcePlayerSuicide(client);
	PrintCenterText(client, "TESTSA tournament is already under way");
}

public ResetVars(client) {
	g_Spycrabbing[client] = false;
	g_AllowTaunt[client] = false;
	g_Spycrabs[client] = 0;
}

//Stocks
stock PrintHudCentreText(String:text[], Float:time) {
	SetHudTextParams(-1.0, 0.3, time, 0, 255, 0, 1);
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