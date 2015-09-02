#pragma semicolon 1 //Makes sourcepawn less shit

#include <sourcemod> //Makes sourcepawn work
#include <sdkhooks>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

new bool:g_Spycrabbing[MAXPLAYERS+1] = {false, ...}; //Stores whether bitches be spycrabbing

//When the plugin starts..
public OnPluginStart() {
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

//When a client disconnects..
public OnClientDisconnect(client) { //Incase they disconnect while spycrabbing? Retards
	g_Spycrabbing[client] = false;
}

//When a condition is added..
public TF2_OnConditionAdded(client, TFCond:condition) { //Stop anyone who's spycrabbing from disguising. Those bastards
	if(g_Spycrabbing[client] && condition == TFCond_Disguised) {
		TF2_RemovePlayerDisguise(client);
	}
}

//When a player spawns..
public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) { //Incase they suicide during a spycrab. Lolmadbru
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client)) {
		g_Spycrabbing[client] = false;
	}
}

//When the round starts..
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) { //Find the boxing and spycrabbing room and " pudge " them
	new i = -1;
	decl String:strName[50];
	while((i = FindEntityByClassname(i, "trigger_multiple")) != -1) { //Get all the trigger_multiple entities
		GetEntPropString(i, Prop_Data, "m_iName", strName, sizeof(strName)); //Gets the name of the entity
		if(strcmp(strName, "crabsOnly") == 0) {
			SDKHook(i, SDKHook_StartTouchPost, OnStartTouchCrabbing);
			SDKHook(i, SDKHook_EndTouch, OnStopTouchCrabbing);
		}
	}
}

//When dey touch le spycrabbing room
public OnStartTouchCrabbing(entity, client) {
	PrintToChatAll("%d touchy", client);
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		g_Spycrabbing[client] = true;
		if(TF2_GetPlayerClass(client) != TFClass_Spy) { //If dey no spy
			TF2_SetPlayerClass(client, TFClass_Spy); //Fuck em, they spy now lel
			TF2_RegeneratePlayer(client); //Remove civi bug
		} else {
			if(TF2_IsPlayerInCondition(client, TFCond_Disguised)) {
				TF2_RemovePlayerDisguise(client); //DON'T FUCKING RUN INTO SPYCRAB WITH A DISGUISE OK?
			}
		}
		for(new i=0; i<6; i++) { //Loop through deir weaponz
			if(GetPlayerWeaponSlot(client, i) != -1) { //If dey have weapon in dis slot
				TF2_RemoveWeaponSlot(client, i); //Tell it to go fuck itself
			}
		}
		new item = GivePlayerItem(client, "tf_weapon_pda_spy");
		EquipPlayerWeapon(client, item);
		ClientCommand(client, "slot4"); //Force them to equip kit
	}
}

//When they stop touching the crabbing box 
public OnStopTouchCrabbing(entity, client) {
	PrintToChatAll("%d no touchy", client);
	if(IsValidClient(client) && IsPlayerAlive(client)) {
		g_Spycrabbing[client] = false;
		TF2_RegeneratePlayer(client); //Give them back all their weapons.
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