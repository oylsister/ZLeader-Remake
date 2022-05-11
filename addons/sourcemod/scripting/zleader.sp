#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <scp>
#include <zleader>

#pragma newdecls required

// Status
int g_iCurrentLeader[MAXLEADER] = {-1, -1, -1, -1, -1};

bool g_bClientLeader[MAXPLAYERS+1];
int g_iClientLeaderSlot[MAXPLAYERS+1];
int g_iClientGetVoted[MAXPLAYERS+1];
int g_iClientVoteWhom[MAXPLAYERS+1];

// ConVar
ConVar g_Cvar_RemoveOnDie;
bool g_bRemoveOnDie;

// Leader Marker and Sprite
int g_iClientSprite[MAXPLAYERS+1] = -1;
int spriteEntities[MAXPLAYERS+1];
int g_iClientMarker[MAXPLAYERS+1];

char g_sDefendVMT[PLATFORM_MAX_PATH];
char g_sDefendVTF[PLATFORM_MAX_PATH];
char g_sFollowVMT[PLATFORM_MAX_PATH];
char g_sFollowVTF[PLATFORM_MAX_PATH];

char g_sMarkerModel[PLATFORM_MAX_PATH];
char g_sMarkerVMT[PLATFORM_MAX_PATH];

float g_pos[3];

#define SP_NONE -1
#define SP_DEFEND 0
#define SP_FOLLOW 1

// Beacon
bool g_bBeaconActive[MAXPLAYERS+1] = false;
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... };
int g_BeamSprite = -1;
int g_HaloSprite = -1;
int g_Serial_Gen = 0;
int greyColor[4] = {128, 128, 128, 255};

public Plugin myinfo = 
{
	name = "ZLeader Remake",
	author = "Oylsister Original by AntiTeal, nuclear silo, CNTT, colia",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_leader", Command_Leader);
	RegConsoleCmd("sm_l", Command_Leader);

	RegConsoleCmd("sm_currentleader", Command_CurrentLeader);

	RegConsoleCmd("sm_voteleader", Command_VoteLeader);
	RegConsoleCmd("sm_vl", Command_VoteLeader);
	RegAdminCmd("sm_removeleader", Command_RemoveLeader, ADMFLAG_BAN);

	HookEvent("player_team", OnPlayerTeam);
	HookEvent("player_death", OnPlayerDeath);

	g_Cvar_RemoveOnDie = CreateConVar("sm_leader_remove_on_die", "1.0", "Remove Leader if leader get infected or died", _, true, 0.0, true, 1.0);

	HookConVarChange(g_Cvar_RemoveOnDie, OnConVarChanged);

	HookRadio();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ZL_SetLeader", Native_SetLeader);
	CreateNative("ZL_IsClientLeader", Native_IsClientLeader);
	CreateNative("ZL_RemoveLeader", Native_RemoveLeader);
	CreateNative("ZL_GetClientLeaderSlot", Native_RemoveLeader);
	CreateNative("ZL_IsLeaderSlotFree", Native_IsLeaderSlotFree);

	RegPluginLibrary("zleader");

	return APLRes_Success;
}

/* =========================================================================
||
||  Hook Event Stuff
||
============================================================================ */

public void OnConVarChanged(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if(cvar == g_Cvar_RemoveOnDie)
		g_bRemoveOnDie = g_Cvar_RemoveOnDie.BoolValue;
}

public void OnMapStart()
{
	LoadConfig();
	LoadDownloadTable();

	AddFileToDownloadsTable(g_sDefendVMT);
	PrecacheGeneric(g_sDefendVMT, true);
	AddFileToDownloadsTable(g_sDefendVTF);
	AddFileToDownloadsTable(g_sFollowVMT);
	PrecacheGeneric(g_sFollowVMT, true);
	AddFileToDownloadsTable(g_sFollowVTF);

	PrecacheModel(g_sMarkerModel, true);
	AddFileToDownloadsTable(g_sMarkerModel);

	PrecacheGeneric(g_sMarkerVMT, true);
	AddFileToDownloadsTable(g_sMarkerVMT);

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
}

public void OnConfigsExecuted()
{
	g_bRemoveOnDie = g_Cvar_RemoveOnDie.BoolValue;
}

public void OnClientPostAdminCheck(int client)
{
	g_bClientLeader[client] = false;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientVoteWhom[client] = -1;
}

public void OnClientDisconnect(int client)
{
	if(IsClientLeader(client))
	{
		RemoveLeader(client, R_DISCONNECTED, true);
	}

	g_bClientLeader[client] = false;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientVoteWhom[client] = -1;
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");

	if(team != CS_TEAM_SPECTATOR)
		return;

	if(IsClientLeader(client))
	{
		RemoveLeader(client, R_SPECTATOR, true);
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(!IsClientLeader(client))
		return;

	if(g_bRemoveOnDie)
	{
		RemoveLeader(client, R_DIED, true);
		return;
	}

	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));
	PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 get infected!", codename, client);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherinfect, bool override, bool respawn)
{
	if(!IsClientLeader(client))
		return;

	if(g_bRemoveOnDie)
	{
		RemoveLeader(client, R_INFECTED, true);
		return;
	}

	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));
	PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 get infected!", codename, client);
}

/* =========================================================================
||
||  Config Loading
||
============================================================================ */

void LoadConfig()
{
	char spath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, spath, sizeof(spath), "configs/zleader/configs.txt");

	if(!FileExists(spath))
	{
		SetFailState("Couldn't find config file: %s", spath);
		return;
	}

	KeyValues kv = CreateKeyValues("zleader");

	FileToKeyValues(kv, spath);

	char sSection[64];

	if(KvGotoFirstSubKey(kv))
	{
		KvGetSectionName(kv, sSection, 64);
		if(StrEqual(sSection, "default"))
		{
			KvGetString(kv, "defend_vmt", g_sDefendVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "defend_vtf", g_sDefendVTF, PLATFORM_MAX_PATH);
			KvGetString(kv, "follow_vmt", g_sFollowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "follow_vtf", g_sFollowVTF, PLATFORM_MAX_PATH);

			KvGetString(kv, "marker_mdl", g_sMarkerModel, PLATFORM_MAX_PATH);
			KvGetString(kv, "marker_vmt", g_sMarkerVMT, PLATFORM_MAX_PATH);
		}
	}
}

void LoadDownloadTable()
{
	char spath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, spath, sizeof(spath), "configs/zleader/downloads.txt");

	File file = OpenFile(spath, "r");

	char buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file))
	{
		ReadFileLine(file, buffer, sizeof(buffer));

		int pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) buffer[pos] = '\0';
		
		pos = StrContains(buffer, "#");
		if (pos != -1) buffer[pos] = '\0';

		pos = StrContains(buffer, ";");
		if (pos != -1) buffer[pos] = '\0';
		
		TrimString(buffer);
		if (buffer[0] == '\0') continue;

		AddFileToDownloadsTable(buffer);
	}

	delete file;
}

/* =========================================================================
||
||  Leader Command
||
============================================================================ */

public Action Command_Leader(int client, int args)
{
	if(args == 0)
	{
		if(IsClientLeader(client))
		{
			if(IsPlayerAlive(client) && ZR_IsClientHuman(client))
			{
				LeaderMenu(client);
				return Plugin_Stop;
			}
		}

		if(IsClientAdmin(client))
		{
			if(!IsClientLeader(client))
			{
				if(!IsPlayerAlive(client) || ZR_IsClientZombie(client))
				{
					return Plugin_Stop;
				}

				for(int i = 0; i < MAXLEADER; i++)
				{
					if(IsLeaderSlotFree(i))
					{
						SetClientLeader(client, _, i);
						LeaderMenu(client);
						return Plugin_Stop;
					}

					ReplyToCommand(client, " \x04[ZLeader]\x01 All Leader slot is full!");
					return Plugin_Stop;
				}
			}
		}
	}

	char sArg[64];
	GetCmdArg(1, sArg, sizeof(sArg));

	int target = FindTarget(client, sArg, false, false);
	if (target != -1)
	{
		for(int i = 0; i < MAXLEADER; i++)
		{
			if(IsLeaderSlotFree(i))
			{
				SetClientLeader(target, client, i);
				ReplyToCommand(client, " \x04[ZLeader]\x01 You have set leader on \x06%N", target);
				LeaderMenu(target);
				return Plugin_Handled;
			}
		}

		ReplyToCommand(client, " \x04[ZLeader]\x01 All Leader slot is full!");
		return Plugin_Stop;
	}

	return Plugin_Handled;
}

public void LeaderMenu(int client)
{
	Menu menu = new Menu(LeaderMenuHandler);

	menu.SetTitle("[ZLeader] Leader menu");
	menu.AddItem("defend", "Defend Here");
	menu.AddItem("follow", "Follow Me");
	menu.AddItem("beacon", "Toggle Beacon");
	menu.AddItem("marker", "Place Marker");
	menu.AddItem("removemarker", "Remove Marker");
	menu.AddItem("resign", "Resign from Leader");

	menu.ExitButton = true;
	menu.Display(client, 30);
}

public int LeaderMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if(StrEqual(info, "defend", false))
			{
				char display[128];
				if(g_iClientSprite[param1] == SP_DEFEND)
				{
					Format(display, sizeof(display), "Defend Here (√)");
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "follow", false))
			{
				char display[128];
				if(g_iClientSprite[param1] == SP_FOLLOW)
				{
					Format(display, sizeof(display), "Follow Me (√)");
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "beacon", false))
			{
				char display[128];
				if(g_bBeaconActive[param1])
				{
					Format(display, sizeof(display), "Toggle Beacon (√)");
					return RedrawMenuItem(display);
				}
			}
		}

		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if(!ZR_IsClientZombie(param1))
			{
				if(StrEqual(info, "defend", false))
				{
					if(g_iClientSprite[param1] != SP_DEFEND)
					{
						RemoveSprite(param1);
						g_iClientSprite[param1] = SP_DEFEND;
						spriteEntities[param1] = AttachSprite(param1, g_sDefendVMT);
					}
					else
					{
						RemoveSprite(param1);
						g_iClientSprite[param1] = SP_NONE;
					}

					LeaderMenu(param1);
				}

				else if(StrEqual(info, "follow", false))
				{
					if(g_iClientSprite[param1] != SP_FOLLOW)
					{
						RemoveSprite(param1);
						g_iClientSprite[param1] = SP_FOLLOW;
						spriteEntities[param1] = AttachSprite(param1, g_sFollowVMT);
					}
					else
					{
						RemoveSprite(param1);
						g_iClientSprite[param1] = SP_NONE;
					}

					LeaderMenu(param1);
				}

				else if(StrEqual(info, "beacon", false))
				{
					ToggleBeacon(param1);
					LeaderMenu(param1);
				}

				else if(StrEqual(info, "marker", false))
				{
					RemoveMarker(param1);
					g_iClientMarker[param1] = SpawnAimMarker(param1, g_sMarkerModel);
					LeaderMenu(param1);
				}

				else if(StrEqual(info, "removemarker", false))
				{
					RemoveMarker(param1);
					LeaderMenu(param1);
				}

				else if(StrEqual(info, "resign", false))
				{
					RemoveLeader(param1, R_SELFRESIGN, true);
				}
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

/* =========================================================================
||
||  Current Leader Command
||
============================================================================ */

public Action Command_CurrentLeader(int client, int args)
{
	Menu menu = new Menu(CurrentLeaderMenuHandler);

	menu.SetTitle("[ZLeader] Leader list menu");
	
	for(int i = 0; i < MAXLEADER; i++)
	{
		char codename[32];
		char sLine[128];

		GetLeaderCodename(i, codename, 32);

		if(!IsLeaderSlotFree(i))
		{
			Format(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
		else
		{
			Format(sLine, 128, "%s: None", codename);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int CurrentLeaderMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

/* =========================================================================
||
||  Vote Leader Command
||
============================================================================ */

public Action Command_VoteLeader(int client, int args)
{
	int count = 0;
	for(int i = 0; i < MAXLEADER; i++)
	{
		if(!IsLeaderSlotFree(i))
			count++;
	}

	if(count >= 5)
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 All leader slot is now full!");
		return Plugin_Handled;
	}

	if(args < 1)
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 Usage: sm_voteleader <player>");
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iClientVoteWhom[client]) == target)
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 You've already voted for this person!");
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(target))
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 You have to vote for a human!");
		return Plugin_Handled;
	}

	if(GetClientFromSerial(g_iClientVoteWhom[client]) != 0)
	{
		if(IsValidClient(GetClientFromSerial(g_iClientVoteWhom[client]))) 
		{
			g_iClientGetVoted[GetClientFromSerial(g_iClientVoteWhom[client])]--;
		}
	}

	g_iClientGetVoted[target]++;

	int number = GetClientCount(true)/10;

	if(number == 0)
		number = 1;

	PrintToChatAll(" \x04[ZLeader]\x01 %N has voted for %N to be the leader (%i/%i votes)", client, target, g_iClientGetVoted[target], number);

	if(g_iClientGetVoted[target] >= number)
	{
		int slot = GetLeaderFreeSlot();

		if(slot == -1)
		{
			ReplyToCommand(client, " \x04[ZLeader]\x01 All leader slot is currently full!");
			return Plugin_Handled;
		}
		
		SetClientLeader(target, -1, slot);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}

/* =========================================================================
||
||  Remove Leader Command
||
============================================================================ */

public Action Command_RemoveLeader(int client, int args)
{
	if(args < 1)
	{
		RemoveLeaderList(client);
		return Plugin_Handled;
	}

	char arg[64];
	GetCmdArg(1, arg, sizeof(arg));
	int target = FindTarget(client, arg, false, false);
	if (target == -1)
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 Invalid client.");
		return Plugin_Handled;
	}

	if(!IsClientLeader(target))
	{
		ReplyToCommand(client, " \x04[ZLeader]\x01 %N is not the leader!", target);
		return Plugin_Handled;
	}

	RemoveLeader(target, R_ADMINFORCED, true);
	return Plugin_Handled;
}

public void RemoveLeaderList(int client)
{
	Menu menu = new Menu(RemoveLeaderListMenuHandler);

	menu.SetTitle("[ZLeader] Leader list menu \nSelect leader to remove them");
	
	for(int i = 0; i < MAXLEADER; i++)
	{
		char codename[32];
		char sLine[128];

		GetLeaderCodename(i, codename, 32);

		if(!IsLeaderSlotFree(i))
		{
			Format(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine);
		}
		else
		{
			Format(sLine, 128, "%s: None", codename);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int RemoveLeaderListMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			for(int i = 0; i < MAXLEADER; i++)
			{
				if(param2 == i && !IsLeaderSlotFree(i))
					RemoveLeader(g_iCurrentLeader[i], R_ADMINFORCED, true);
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}
}

/* =========================================================================
||
||  Beacon
||
============================================================================ */

public void ToggleBeacon(int client)
{
	g_bBeaconActive[client] = !g_bBeaconActive[client];
	PerformBeacon(client);
}

public void CreateBeacon(int client)
{
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void KillBeacon(int client)
{
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
	{
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
}

public void KillAllBeacons()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		KillBeacon(i);
	}
}

public void PerformBeacon(int client)
{
	if (g_BeaconSerial[client] == 0)
	{
		CreateBeacon(client);
		LogAction(client, client, "\"%L\" set a beacon on himself", client);
	}
	else
	{
		KillBeacon(client);
		LogAction(client, client, "\"%L\" removed a beacon on himself", client);
	}
}

public Action Timer_Beacon(Handle timer, any value)
{
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial)
	{
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();

	int rainbowColor[4];
	float i = GetGameTime();
	float Frequency = 2.5;
	rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	rainbowColor[3] = 255;

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbowColor, 10, 0);

	TE_SendToAll();

	GetClientEyePosition(client, vec);

	return Plugin_Continue;
}

/* =========================================================================
||
||  Sprite
||
============================================================================ */

public void RemoveSprite(int client)
{
	if (spriteEntities[client] != -1 && IsValidEdict(spriteEntities[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(spriteEntities[client], m_szClassname, sizeof(m_szClassname));

		if(strcmp("env_sprite", m_szClassname)==0)
			AcceptEntityInput(spriteEntities[client], "Kill");
	}

	spriteEntities[client] = -1;
}

public int AttachSprite(int client, char[] sprite) //https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	char iTarget[16], sTargetname[64];
	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	Format(iTarget, sizeof(iTarget), "Client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 82.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

/* =========================================================================
||
||  Marker
||
============================================================================ */

public void RemoveMarker(int client)
{
	if (g_iClientMarker[client] != -1 && IsValidEdict(g_iClientMarker[client]))
	{
		char m_szClassname[64];
		GetEdictClassname(g_iClientMarker[client], m_szClassname, sizeof(m_szClassname));

		if(strcmp("prop_dynamic", m_szClassname) == 0)
			AcceptEntityInput(g_iClientMarker[client], "Kill");
	}
	g_iClientMarker[client] = -1;
}

public int SpawnAimMarker(int client, char[] model)
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	int Ent = CreateEntityByName("prop_dynamic");
	if(!Ent) return -1;

	GetPlayerEye(client, g_pos);

	DispatchKeyValue(Ent, "model", model);
	DispatchKeyValue(Ent, "DefaultAnim", "default");
	DispatchKeyValue(Ent, "classname", "prop_dynamic");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);

	TeleportEntity(Ent, g_pos, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 1);

	return Ent;
}

stock void GetPlayerEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	TR_GetEndPosition(pos);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

/* =========================================================================
||
||  Leader Chat
||
============================================================================ */

public Action OnChatMessage(int &client, ArrayList recipient, char[] name, char[] message)
{
	char codename[32];

	if(IsClientLeader(client))
	{
		GetLeaderCodename(g_iClientLeaderSlot[client], codename, 32);

		Format(name, 128, " \x02[\x10Leader %s\x02] \x0E%s", codename, name);
		Format(message, 250, "\x04%s", message);

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

void HookRadio()
{
	AddCommandListener(Radio, "compliment");
	AddCommandListener(Radio, "coverme");
	AddCommandListener(Radio, "cheer");
	AddCommandListener(Radio, "takepoint");
	AddCommandListener(Radio, "holdpos");
	AddCommandListener(Radio, "regroup");
	AddCommandListener(Radio, "followme");
	AddCommandListener(Radio, "takingfire");
	AddCommandListener(Radio, "thanks");
	AddCommandListener(Radio, "go");
	AddCommandListener(Radio, "fallback");
	AddCommandListener(Radio, "sticktog");
	AddCommandListener(Radio, "getinpos");
	AddCommandListener(Radio, "stormfront");
	AddCommandListener(Radio, "report");
	AddCommandListener(Radio, "roger");
	AddCommandListener(Radio, "enemyspot");
	AddCommandListener(Radio, "needbackup");
	AddCommandListener(Radio, "sectorclear");
	AddCommandListener(Radio, "inposition");
	AddCommandListener(Radio, "reportingin");
	AddCommandListener(Radio, "getout");
	AddCommandListener(Radio, "negative");
	AddCommandListener(Radio, "enemydown");
}

public Action Radio(int client, const char[] command, int argc)
{
	if(IsClientLeader(client))
	{
		if(StrEqual(command, "compliment")) PrintRadio(client, "Nice!");
		if(StrEqual(command, "coverme")) PrintRadio(client, "Cover Me!");
		if(StrEqual(command, "cheer")) PrintRadio(client, "Cheer!");
		if(StrEqual(command, "takepoint")) PrintRadio(client, "You take the point.");
		if(StrEqual(command, "holdpos")) PrintRadio(client, "Hold This Position.");
		if(StrEqual(command, "regroup")) PrintRadio(client, "Regroup Team.");
		if(StrEqual(command, "followme")) PrintRadio(client, "Follow me.");
		if(StrEqual(command, "takingfire")) PrintRadio(client, "Taking fire... need assistance!");
		if(StrEqual(command, "thanks"))  PrintRadio(client, "Thanks!");
		if(StrEqual(command, "go"))  PrintRadio(client, "Go go go!");
		if(StrEqual(command, "fallback"))  PrintRadio(client, "Team, fall back!");
		if(StrEqual(command, "sticktog"))  PrintRadio(client, "Stick together, team.");
		if(StrEqual(command, "report"))  PrintRadio(client, "Report in, team.");
		if(StrEqual(command, "roger"))  PrintRadio(client, "Roger that.");
		if(StrEqual(command, "enemyspot"))  PrintRadio(client, "Enemy spotted.");
		if(StrEqual(command, "needbackup"))  PrintRadio(client, "Need backup.");
		if(StrEqual(command, "sectorclear"))  PrintRadio(client, "Sector clear.");
		if(StrEqual(command, "inposition"))  PrintRadio(client, "I'm in position.");
		if(StrEqual(command, "reportingin"))  PrintRadio(client, "Reporting In.");
		if(StrEqual(command, "getout"))  PrintRadio(client, "Get out of there, it's gonna blow!.");
		if(StrEqual(command, "negative"))  PrintRadio(client, "Negative.");
		if(StrEqual(command, "enemydown"))  PrintRadio(client, "Enemy down.");
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void PrintRadio(int client, char[] text)
{
	char leadertag[64], szMessage[256], codename[32];
	GetLeaderCodename(g_iClientLeaderSlot[client], codename, sizeof(codename));
	Format(leadertag, sizeof(leadertag), "⋆Leader (%s)", codename);

	Format(szMessage, sizeof(szMessage), " \x10%s %N (RADIO): %s", leadertag, client, text);
	PrintToChatAll(szMessage);
}

/* =========================================================================
||
||  Function
||
============================================================================ */

void SetClientLeader(int client, int adminset = -1, int slot)
{
	if(!IsClientInGame(client))
	{
		if(adminset != -1)
			ReplyToCommand(adminset, " \x04[ZLeader]\x01 Invalid client.");

		return;
	}

	char codename[32];
	GetLeaderCodename(slot, codename, sizeof(codename));
	PrintToChatAll(" \x04[ZLeader]\x01 \x0B%N\x01 has become a new \x10Leader %s\x01!", client, codename);

	g_bClientLeader[client] = true;
	g_iClientLeaderSlot[client] = slot;
	g_iCurrentLeader[slot] = client;
	g_iClientSprite[client] = SP_NONE;
}

void RemoveLeader(int client, ResignReason reason, bool announce)
{
	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));

	RemoveMarker(client);
	RemoveSprite(client);

	if(g_bBeaconActive[client])
		ToggleBeacon(client);

	g_bClientLeader[client] = false;
	g_iCurrentLeader[g_iClientLeaderSlot[client]] = -1;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientSprite[client] = -1;
	g_bBeaconActive[client] = false;

	if(announce)
	{
		switch (reason)
		{
			case R_DISCONNECTED:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 has disconnected from the server!", codename, client);
			}
			case R_ADMINFORCED:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 has been resigned by admin!", codename, client);
			}
			case R_SELFRESIGN:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 has resigned by him/herself!", codename, client);
			}
			case R_SPECTATOR:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 has been resigned for moving to spectator!", codename, client);
			}
			case R_DIED:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 is died and get resigned!", codename, client);
			}
			case R_INFECTED:
			{
				PrintToChatAll(" \x04[ZLeader]\x01 Leader \x10%s\x01 \x07%N\x01 get infected and get resigned!", codename, client);
			}
		}
	}
}

stock bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

/* =========================================================================
||
||  API
||
============================================================================ */

public int Native_SetLeader(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);

	SetClientLeader(client, -1, slot);
}

public int Native_IsClientLeader(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);

	return IsClientLeader(client);
}

public int Native_RemoveLeader(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);
	ResignReason reason = view_as<ResignReason>(GetNativeCell(2));
	bool announce = view_as<bool>(GetNativeCell(3));

	if(!IsClientLeader(client))
	{
		ThrowNativeError(1, "the client %N is not the leader", client);
		return;
	}

	RemoveLeader(client, reason, announce);
}

public int Native_GetClientLeaderSlot(Handle hPlugins, int numParams)
{
	int client = GetNativeCell(1);

	if(!IsClientLeader(client))
	{
		ThrowNativeError(1, "the client %N is not the leader", client);
		return -1;
	}

	return GetClientLeaderSlot(client);
}

public int Native_IsLeaderSlotFree(Handle hPlugins, int numParams)
{
	int slot = GetNativeCell(1);
	return IsLeaderSlotFree(slot);
}

stock void GetLeaderCodename(int slot, char[] buffer, int maxlen)
{
	if(slot == ALPHA)
		Format(buffer, maxlen, "Alpha");

	else if(slot == BRAVO)
		Format(buffer, maxlen, "Bravo");

	else if(slot == CHARLIE)
		Format(buffer, maxlen, "Charlie");
	
	else if(slot == DELTA)
		Format(buffer, maxlen, "Delta");

	else
		Format(buffer, maxlen, "Echo");
}

stock int GetLeaderFreeSlot()
{
	for(int i = 0; i < MAXLEADER; i++)
	{
		if(IsLeaderSlotFree(i))
			return i;
	}
	return -1;
}

stock int GetClientLeaderSlot(int client)
{
	return g_iClientLeaderSlot[client];
}

stock bool IsClientLeader(int client)
{
	return g_bClientLeader[client];
}

stock bool IsLeaderSlotFree(int slot)
{
	if(g_iCurrentLeader[slot] == -1)
		return true;

	return false;
}

stock bool IsClientAdmin(int client)
{
	return CheckCommandAccess(client, "sm_admin", ADMFLAG_BAN);
}