#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <multicolors>
#include <zombiereloaded>
#include <zleader>

// If you want to use Simple Chat-Processor make sure CCC is unloaded
// If you want to use CCC make sure Simple Chat-Processor is unloaded
#undef REQUIRE_PLUGIN
#include <scp>
#include <vip_core>
#include <ccc>

#pragma newdecls required

bool vipcore;
bool g_ccc;

char szClientTag[MAXPLAYERS+1][64];

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
int g_iClientSprite[MAXPLAYERS+1] = {-1, ...};
int spriteEntities[MAXPLAYERS+1];
int g_iClientMarker[3][MAXPLAYERS+1];
int markerEntities[3][MAXPLAYERS+1];

char g_sDefendVMT[PLATFORM_MAX_PATH];
char g_sDefendVTF[PLATFORM_MAX_PATH];
char g_sFollowVMT[PLATFORM_MAX_PATH];
char g_sFollowVTF[PLATFORM_MAX_PATH];
char g_sMarkerModel[PLATFORM_MAX_PATH];
char g_sMarkerVMT[PLATFORM_MAX_PATH];

char g_sMarkerArrowVMT[PLATFORM_MAX_PATH];
char g_sMarkerArrowVTF[PLATFORM_MAX_PATH];
int g_iColorArrow[4];

char g_sMarkerZMTP_VMT[PLATFORM_MAX_PATH];
char g_sMarkerZMTP_VTF[PLATFORM_MAX_PATH];
int g_iColorZMTP[4];

char g_sMarkerNoHug_VMT[PLATFORM_MAX_PATH];
char g_sMarkerNoHug_VTF[PLATFORM_MAX_PATH];
int g_iColorNoHug[4];

float g_pos[3];

#define SP_NONE -1
#define SP_DEFEND 0
#define SP_FOLLOW 1

#define MK_NONE -1
#define MK_NORMAL 0
#define MK_ZMTP 1
#define MK_NOHUG 2

int g_iButtoncount[MAXPLAYERS+1] = {0, ... };

// Beacon
bool g_bBeaconActive[MAXPLAYERS+1] = {false, ...};
int g_BeaconSerial[MAXPLAYERS+1] = {0, ... };
int g_BeamSprite = -1;
int g_HaloSprite = -1;
int g_Serial_Gen = 0;
int greyColor[4] = {128, 128, 128, 255};

// Client Preference
#define MK_CLIENT 0
#define MK_CROSSHAIR 1

Handle g_CMarkerPos = INVALID_HANDLE;
Handle g_CShortcut = INVALID_HANDLE;

bool g_bShorcut[MAXPLAYERS+1];
int g_iMarkerPos[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "ZLeader Remake",
	author = "Oylsister Original from ZR-Leader by AntiTeal, nuclear silo, CNTT, colia",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = "2.1",
	url = "https://github.com/oylsister/ZLeader-Remake"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_leader", Command_Leader);
	RegConsoleCmd("sm_l", Command_Leader);

	RegConsoleCmd("sm_currentleader", Command_CurrentLeader);

	RegConsoleCmd("sm_voteleader", Command_VoteLeader);
	RegConsoleCmd("sm_vl", Command_VoteLeader);
	RegAdminCmd("sm_removeleader", Command_RemoveLeader, ADMFLAG_BAN);
	RegConsoleCmd("sm_mark", Command_Marker);
	RegConsoleCmd("sm_marker", Command_Marker);

	AddCommandListener(QuickCommand, "+lookatweapon");

	HookEvent("player_team", OnPlayerTeam);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_start", OnRoundStart);

	g_Cvar_RemoveOnDie = CreateConVar("sm_leader_remove_on_die", "1.0", "Remove Leader if leader get infected or died", _, true, 0.0, true, 1.0);
	HookConVarChange(g_Cvar_RemoveOnDie, OnConVarChanged);

	g_CMarkerPos = RegClientCookie("zleader_makerpos", "ZLeader Marker Position", CookieAccess_Protected);
	g_CShortcut = RegClientCookie("zleader_shortcut", "ZLeader ShortCut", CookieAccess_Protected);

	SetCookieMenuItem(ZLeaderCookieHandler, 0, "[ZLeader] Client Setting");

	LoadTranslations("zleader.phrases.txt");
	LoadTranslations("common.phrases.txt");
	HookRadio();
	
	for(int i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(!AreClientCookiesCached(i))
				OnClientCookiesCached(i);
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ZL_SetLeader", Native_SetLeader);
	CreateNative("ZL_IsClientLeader", Native_IsClientLeader);
	CreateNative("ZL_RemoveLeader", Native_RemoveLeader);
	CreateNative("ZL_GetClientLeaderSlot", Native_RemoveLeader);
	CreateNative("ZL_IsLeaderSlotFree", Native_IsLeaderSlotFree);

	MarkNativeAsOptional("CCC_GetTag");
	MarkNativeAsOptional("CCC_SetTag");
	MarkNativeAsOptional("CCC_ResetTag");

	RegPluginLibrary("zleader");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	vipcore = LibraryExists("vip_core");
	g_ccc = LibraryExists("ccc");
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "vip_core"))
		vipcore = false;

	if(StrEqual(name, "ccc"))
		g_ccc = true;
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "vip_core"))
		vipcore = true;

	if(StrEqual(name, "ccc"))
		g_ccc = true;
}

/* =========================================================================
||
||  Cookies
||
============================================================================ */

public void OnClientCookiesCached(int client)
{
	char buffer[32];
	GetClientCookie(client, g_CShortcut, buffer, 32);
	if(buffer[0] != '\0')
	{
		g_bShorcut[client] = view_as<bool>(StringToInt(buffer));
	}
	else
	{
		g_bShorcut[client] = true;
	}

	GetClientCookie(client, g_CMarkerPos, buffer, 32);
	if(buffer[0] != '\0')
	{
		g_iMarkerPos[client] = StringToInt(buffer);
	}
	else
	{
		g_iMarkerPos[client] = MK_CROSSHAIR;
	}
}

public void ZLeaderCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			ZLeaderSetting(client);
		}
	}
}

public void ZLeaderSetting(int client)
{
	Menu menu = new Menu(ZLeaderSettingHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Client Setting", client);

	char shortcut[64], markerpos[64];
	Format(shortcut, 64, "%T", "Shortcut", client);
	Format(markerpos, 64, "%T", "Marker Pos", client);

	menu.AddItem("shortcut", shortcut);
	menu.AddItem("markerpos", markerpos);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ZLeaderSettingHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char info[64];
			char display[64];
			menu.GetItem(param2, info, sizeof(info));
			if(StrEqual(info, "shortcut"))
			{
				if(g_bShorcut[param1])
					Format(display, sizeof(display), "%T : %T", "Shortcut", param1, "Enabled", param1);

				else
					Format(display, sizeof(display), "%T : %T", "Shortcut", param1, "Disabled", param1);

				return RedrawMenuItem(display);
			}

			else if(StrEqual(info, "markerpos"))
			{
				char thepos[32];

				if(g_iMarkerPos[param1] == MK_CLIENT)
					Format(thepos, sizeof(thepos), "%T", "Client Position", param1);

				else
					Format(thepos, sizeof(thepos), "%T", "Client Crosshair", param1);

				Format(display, sizeof(display), "%T : %s", "Marker Pos", param1, thepos);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if(StrEqual(info, "shortcut"))
			{
				char status[32];
				g_bShorcut[param1] = !g_bShorcut[param1];

				if(g_bShorcut[param1])
					Format(status, 64, "%T", "Enabled Chat", param1);

				else
					Format(status, 64, "%T", "Disabled Chat", param1);

				CPrintToChat(param1, "%T %T", "Prefix", param1, "You set shortcut", param1, status);
			}
			else if(StrEqual(info, "markerpos"))
			{
				if(g_iMarkerPos[param1] == MK_CLIENT)
				{
					g_iMarkerPos[param1] = MK_CROSSHAIR;
					CPrintToChat(param1, "%T %T", "Prefix", param1, "Marker Pos Crosshair", param1);
				}

				else
				{
					g_iMarkerPos[param1] = MK_CLIENT;
					CPrintToChat(param1, "%T %T", "Prefix", param1, "Marker Pos Player Postion", param1);
				}
			}

			ZLeaderSetting(param1);
		}
		case MenuAction_Cancel:
		{
			ShowCookieMenu(param1);
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

	PrecacheGeneric(g_sMarkerArrowVMT, true);
	AddFileToDownloadsTable(g_sMarkerArrowVMT);
	AddFileToDownloadsTable(g_sMarkerArrowVTF);

	PrecacheGeneric(g_sMarkerZMTP_VMT, true);
	AddFileToDownloadsTable(g_sMarkerZMTP_VMT);
	AddFileToDownloadsTable(g_sMarkerZMTP_VTF);

	PrecacheGeneric(g_sMarkerNoHug_VMT, true);
	AddFileToDownloadsTable(g_sMarkerNoHug_VMT);
	AddFileToDownloadsTable(g_sMarkerNoHug_VTF);

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

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Has Died", i, codename, client);
	}
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	KillAllBeacons();
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

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Get Infected", i, codename, client);
	}
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

			KvGetString(kv, "arrow_vmt", g_sMarkerArrowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "arrow_vtf", g_sMarkerArrowVTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "arrow_color", g_iColorArrow[0], g_iColorArrow[1], g_iColorArrow[2], g_iColorArrow[3]);

			KvGetString(kv, "zmtp_vmt", g_sMarkerZMTP_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "zmtp_vtf", g_sMarkerZMTP_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "zmtp_color", g_iColorZMTP[0], g_iColorZMTP[1], g_iColorZMTP[2], g_iColorZMTP[3]);

			KvGetString(kv, "nodoorhug_vmt", g_sMarkerNoHug_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "nodoorhug_vtf", g_sMarkerNoHug_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "nodoorhug_color", g_iColorNoHug[0], g_iColorNoHug[1], g_iColorNoHug[2], g_iColorNoHug[3]);
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
	SetGlobalTransTarget(client);

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

		if(IsClientAdmin(client) || IsClientVIP(client))
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

					CReplyToCommand(client, "%t %t", "Prefix", "Slot is full");
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
		if(IsClientLeader(target))
		{
			CReplyToCommand(client, "%t %t", "Prefix", "Already Leader", target);
			return Plugin_Handled;
		}

		if(ZR_IsClientZombie(target))
		{
			CReplyToCommand(client, "%t %t", "Prefix", "It's Zombie");
			return Plugin_Handled;
		}

		for(int i = 0; i < MAXLEADER; i++)
		{
			if(IsLeaderSlotFree(i))
			{
				SetClientLeader(target, client, i);
				CReplyToCommand(client, "%t %t", "Prefix", "You set client leader", target);
				LeaderMenu(target);
				return Plugin_Handled;
			}
		}

		CReplyToCommand(client, "%t %t", "Prefix", "Slot is full");
		return Plugin_Stop;
	}

	return Plugin_Handled;
}

public void LeaderMenu(int client)
{
	Menu menu = new Menu(LeaderMenuHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Menu Leader title", client);

	char defend[64], follow[64], beacon[64], marker[64], removemarker[64], resign[64];

	Format(defend, 64, "%T", "Defend Here", client);
	Format(follow, 64, "%T", "Follow Me", client);
	Format(beacon, 64, "%T", "Toggle Beacon", client);
	Format(marker, 64, "%T", "Place Marker", client);
	Format(removemarker, 64, "%T", "Remove Marker", client);
	Format(resign, 64, "%T", "Resign from Leader", client);

	menu.AddItem("defend", defend);
	menu.AddItem("follow", follow);
	menu.AddItem("beacon", beacon);
	menu.AddItem("marker", marker);
	menu.AddItem("removemarker", removemarker);
	menu.AddItem("resign", resign);

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
					Format(display, sizeof(display), "%T (√)", "Defend Here", param1);
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "follow", false))
			{
				char display[128];
				if(g_iClientSprite[param1] == SP_FOLLOW)
				{
					Format(display, sizeof(display), "%T (√)", "Follow Me", param1);
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "beacon", false))
			{
				char display[128];
				if(g_bBeaconActive[param1])
				{
					Format(display, sizeof(display), "%T (√)", "Toggle Beacon", param1);
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
					MarkerMenu(param1);
				}

				else if(StrEqual(info, "removemarker", false))
				{
					for(int i = 0; i < 3; i++)
						RemoveMarker(param1, i);

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

	menu.SetTitle("%T %T", "Menu Prefix", client, "Menu Leader list title", client);
	
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
			Format(sLine, 128, "%s: %T", codename, "None", client);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
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
	return 0;
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
		CReplyToCommand(client, "%T %T", "Prefix", client, "Slot is full", client);
		return Plugin_Handled;
	}

	if(args < 1)
	{
		CReplyToCommand(client, "%T %T", "Prefix", client, "Vote leader usage", client);
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
		CReplyToCommand(client, "%T %T", "Prefix", client, "Already vote client", client);
		return Plugin_Handled;
	}

	if(ZR_IsClientZombie(target))
	{
		CReplyToCommand(client, "%T %T", "Prefix", client, "Has to be human", client);
		return Plugin_Handled;
	}

	if(IsClientLeader(target))
	{
		CReplyToCommand(client, "%T %T", "Prefix", client, "Already Leader", client);
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
	g_iClientVoteWhom[client] = GetClientSerial(target);

	int number = GetClientCount(true)/10;

	if(number == 0)
		number = 1;

	for(int i = 1; i <= MaxClients; i++)
	{
		SetGlobalTransTarget(i);

		if(IsClientInGame(i))
			CPrintToChat(i, "%t %t", "Prefix", "Vote for client", client, target, g_iClientGetVoted[target], number);
	}

	if(g_iClientGetVoted[target] >= number)
	{
		int slot = GetLeaderFreeSlot();

		if(slot == -1)
		{
			CReplyToCommand(client, "%T %T", "Prefix", client, "Slot is full", client);
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
		CReplyToCommand(client, "%T %T", "Prefix", client, "Invalid client", client);
		return Plugin_Handled;
	}

	if(!IsClientLeader(target))
	{
		CReplyToCommand(client, "%T %T", "Prefix", client, "Client is not leader", client, target);
		return Plugin_Handled;
	}

	RemoveLeader(target, R_ADMINFORCED, true);
	return Plugin_Handled;
}

public void RemoveLeaderList(int client)
{
	SetGlobalTransTarget(client);
	Menu menu = new Menu(RemoveLeaderListMenuHandler);

	char title[128];
	Format(title, sizeof(title), "%t %t \n%t", "Menu Prefix", "Menu Leader list title", "Menu Remove Leader title");
	menu.SetTitle("%s", title);
	
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
			Format(sLine, 128, "%s: %t", codename, "None");
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
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
	return 0;
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
		if(g_bBeaconActive[i])
			g_bBeaconActive[i] = false;

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

public Action Command_Marker(int client, int args)
{
	if(IsClientLeader(client))
	{
		MarkerMenu(client);
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public void MarkerMenu(int client)
{
	Menu menu = new Menu(MarkerMenuHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Marker menu title", client);

	char normal[64], zmtp[64], nohug[64];

	Format(normal, 64, "%T", "Marker Only", client);
	Format(zmtp, 64, "%T", "ZM Teleport", client);
	Format(nohug, 64, "%T", "No Doorhug", client);

	menu.AddItem("normal", normal);
	menu.AddItem("zmtp", zmtp);
	menu.AddItem("nohug", nohug);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MarkerMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DisplayItem:
		{
			char info[64];
			char display[64];
			menu.GetItem(param2, info, sizeof(info));

			if(StrEqual(info, "normal"))
			{
				if(g_iClientMarker[MK_NORMAL][param1] != -1)
				{
					Format(display, sizeof(display), "%T (√)", "Marker Only", param1);
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "zmtp"))
			{
				if(g_iClientMarker[MK_ZMTP][param1] != -1)
				{
					Format(display, sizeof(display), "%T (√)", "ZM Teleport", param1);
					return RedrawMenuItem(display);
				}
			}

			else if(StrEqual(info, "nohug"))
			{
				if(g_iClientMarker[MK_NOHUG][param1] != -1)
				{
					Format(display, sizeof(display), "%T (√)", "No Doorhug", param1);
					return RedrawMenuItem(display);
				}
			}
		}
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if(StrEqual(info, "normal"))
			{
				if(g_iClientMarker[MK_NORMAL][param1] != -1)
					RemoveMarker(param1, MK_NORMAL);

				else
					SpawnMarker(param1, MK_NORMAL);
			}

			else if(StrEqual(info, "zmtp"))
			{
				if(g_iClientMarker[MK_ZMTP][param1] != -1)
					RemoveMarker(param1, MK_ZMTP);

				else
					SpawnMarker(param1, MK_ZMTP);
			}

			else if(StrEqual(info, "nohug"))
			{
				if(g_iClientMarker[MK_NOHUG][param1] != -1)
					RemoveMarker(param1, MK_NOHUG);

				else
					SpawnMarker(param1, MK_NOHUG);
			}

			MarkerMenu(param1);
		}
		case MenuAction_Cancel:
		{
			LeaderMenu(param1);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public void RemoveMarker(int client, int type)
{
	if (g_iClientMarker[type][client] != -1 && IsValidEdict(g_iClientMarker[type][client]))
	{
		char m_szClassname[64];
		GetEdictClassname(g_iClientMarker[type][client], m_szClassname, sizeof(m_szClassname));

		if(strcmp("prop_dynamic", m_szClassname) == 0)
			AcceptEntityInput(g_iClientMarker[type][client], "Kill");

		if (markerEntities[type][client] != -1 && IsValidEdict(markerEntities[type][client]))
		{
			GetEdictClassname(markerEntities[type][client], m_szClassname, sizeof(m_szClassname));

			if(strcmp("env_sprite", m_szClassname) == 0)
				AcceptEntityInput(markerEntities[type][client], "Kill");
		}
	}

	g_iClientMarker[type][client] = -1;
	markerEntities[type][client] = -1;
}

public void SpawnMarker(int client, int type)
{
	if (type == MK_NORMAL)
		markerEntities[type][client] = SpawnSpecialMarker(client, g_sMarkerArrowVMT);

	else if(type == MK_ZMTP)
		markerEntities[type][client] = SpawnSpecialMarker(client, g_sMarkerZMTP_VMT);

	else
		markerEntities[type][client] = SpawnSpecialMarker(client, g_sMarkerNoHug_VMT);

	g_iClientMarker[type][client] = SpawnAimMarker(client, g_sMarkerModel, type);
}

public int SpawnAimMarker(int client, char[] model, int type)
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	int Ent = CreateEntityByName("prop_dynamic");
	if(!Ent) return -1;

	if(g_iMarkerPos[client] == MK_CROSSHAIR)
		GetPlayerEye(client, g_pos);

	else
		GetClientAbsOrigin(client, g_pos);


	DispatchKeyValue(Ent, "model", model);
	DispatchKeyValue(Ent, "DefaultAnim", "default");
	DispatchKeyValue(Ent, "classname", "prop_dynamic");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);

	if(type == MK_NORMAL)
		SetEntityRenderColor(Ent, g_iColorArrow[0], g_iColorArrow[1], g_iColorArrow[2], g_iColorArrow[3]);

	else if(type  == MK_NOHUG)
		SetEntityRenderColor(Ent, g_iColorNoHug[0], g_iColorNoHug[1], g_iColorNoHug[2], g_iColorNoHug[3]);

	else
		SetEntityRenderColor(Ent, g_iColorZMTP[0], g_iColorZMTP[1], g_iColorZMTP[2], g_iColorZMTP[3]);


	TeleportEntity(Ent, g_pos, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 1);

	return Ent;
}

public int SpawnSpecialMarker(int client, char[] sprite)
{
	if(!IsPlayerAlive(client))
	{
		return -1;
	}

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	if(g_iMarkerPos[client] == MK_CROSSHAIR)
	{
		GetPlayerEye(client, g_pos);
		g_pos[2] += 80.0;
	}

	else
	{
		GetClientAbsOrigin(client, g_pos);
		g_pos[2] += 80.0;
	}

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);

	TeleportEntity(Ent, g_pos, NULL_VECTOR, NULL_VECTOR);

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

void SetClientChat(int client, int slot)
{
	CCC_GetTag(client, szClientTag[client], 64);

	CCC_ResetTag(client);

	char codename[32];
	GetLeaderCodename(slot , codename, 32);

	char newtag[64];
	Format(newtag, 64, "{darkred}[{orange}Leader %s{darkred}] ", codename);
	CCC_SetTag(client, newtag);
}

void RemoveClientChat(int client)
{
	if(strlen(szClientTag[client]) <= 0)
		CCC_ResetTag(client);

	else
		CCC_SetTag(client, szClientTag[client]);
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
			CReplyToCommand(adminset, "%T %T", "Prefix", client, "Invalid client", client);

		return;
	}

	char codename[32];
	GetLeaderCodename(slot, codename, sizeof(codename));

	if(g_ccc)
		SetClientChat(client, slot);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Become New Leader", i, client, codename);
	}

	for(int i = 0; i < 3; i++)
	{
		g_iClientMarker[i][client] = -1;
	}

	g_bClientLeader[client] = true;
	g_iClientLeaderSlot[client] = slot;
	g_iCurrentLeader[slot] = client;
	g_iClientSprite[client] = SP_NONE;
}

void RemoveLeader(int client, ResignReason reason, bool announce = true)
{
	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));

	for(int i = 0; i < 3; i++)
		RemoveMarker(client, i);

	RemoveSprite(client);

	if(g_ccc)
		RemoveClientChat(client);

	if(g_bBeaconActive[client])
	{
		ToggleBeacon(client);
		KillBeacon(client);
	}

	g_bClientLeader[client] = false;
	g_iCurrentLeader[g_iClientLeaderSlot[client]] = -1;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientSprite[client] = -1;
	g_bBeaconActive[client] = false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(GetClientFromSerial(g_iClientVoteWhom[i]) == client)
		{
			g_iClientVoteWhom[i] = -1;
		}
	}

	if(announce)
	{
		for(int i = 1; i < MaxClients; i++)
		{
			if(!IsClientInGame(i))
				continue;
				
			SetGlobalTransTarget(i);

			switch (reason)
			{
				case R_DISCONNECTED:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Disconnected", codename, client);
				}
				case R_ADMINFORCED:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Admin Force", codename, client);
				}
				case R_SELFRESIGN:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Self Resign", codename, client);
				}
				case R_SPECTATOR:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Spectator", codename, client);
				}
				case R_DIED:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Died", codename, client);
				}
				case R_INFECTED:
				{
					CPrintToChat(i, "%t %t", "Prefix", "Remove Infected", codename, client);
				}
			}
		}
	}
}

public Action QuickCommand(int client, const char[] command, int argc)
{
	if(IsClientLeader(client))
	{
		if(g_bShorcut[client])
		{
			g_iButtoncount[client]++;
			CreateTimer(1.5, ResetButtonPressed, client);
		}

		if (g_iButtoncount[client] >= 2)
		{
			if(IsClientLeader(client))
				LeaderMenu(client);
		}
	}
	return Plugin_Continue;
}

public Action ResetButtonPressed(Handle timer, any client)
{
	g_iButtoncount[client] = 0;
	return Plugin_Handled;
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
||  VIP
||
============================================================================ */

stock bool IsClientVIP(int client)
{
	if(!vipcore)
		return false;

	char group[64];
	bool vip = VIP_GetClientVIPGroup(client, group, 64);

	if(!vip)
		return false;

	if(!StrEqual(group, "Supporter", false))
		return false;

	else
		return true;
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
	return 0;
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
		return ThrowNativeError(1, "the client %N is not the leader", client);
	}

	RemoveLeader(client, reason, announce);
	return 0;
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
