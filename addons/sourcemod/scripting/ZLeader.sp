#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <multicolors>
#include <zombiereloaded>
#include <zleader>
#include "utilshelper.inc"

#undef REQUIRE_PLUGIN
#include <vip_core>
#include <ccc>

#pragma newdecls required

#define MAXEDICTS (GetMaxEntities() - 150)
#define MAXPOSSIBLELEADERS 999 // Determine maxium lines number of leaders.ini 
#define MK_CROSSHAIR 1
#define MK_CLIENT 0
#define SP_NONE -1
#define SP_FOLLOW 0

#define MK_NONE -1
#define MK_NORMAL 0
#define MK_DEFEND 1
#define MK_ZMTP 2
#define MK_NOHUG 3

ConVar 
	g_cvGlowLeader,
	g_cvNeonLeader,
	g_cvTrailPosition,
	g_cvEnableVIP;

int
	g_Serial_Gen = 0,
	g_BeamSprite = -1,
	g_HaloSprite = -1,
	g_iMarkerPos[MAXPLAYERS + 1],
	g_iSpriteFollow[MAXPLAYERS + 1],
	g_iSpriteLeader[MAXPLAYERS + 1],
	g_iNeonEntities[4][MAXPLAYERS + 1],
	g_iMarkerEntities[4][MAXPLAYERS + 1],
	g_iGlowColor[MAXPLAYERS + 1][3],
	g_iClientGetVoted[MAXPLAYERS + 1],
	g_iClientVoteWhom[MAXPLAYERS + 1],
	g_iClientMarker[4][MAXPLAYERS + 1],
	g_iClientLeaderSlot[MAXPLAYERS + 1],
	g_TrailModel[MAXPLAYERS + 1] = { 0, ... },
	g_BeaconSerial[MAXPLAYERS + 1] = {0, ... },
	g_iClientSprite[MAXPLAYERS + 1] = {-1, ...},
	g_iClientNextVote[MAXPLAYERS + 1] = { -1, ... },
	g_iButtonLeaderCount[MAXPLAYERS + 1] = {0, ... },
	g_iButtonMarkerCount[MAXPLAYERS + 1] = {0, ... },
	g_iCurrentLeader[MAXLEADER] = {-1, -1, -1, -1, -1};

bool
	g_ccc,
	vipcore,
	g_bShorcut[MAXPLAYERS + 1],
	g_bClientLeader[MAXPLAYERS + 1],
	g_bTrailActive[MAXPLAYERS + 1] = { false, ... },
	g_bBeaconActive[MAXPLAYERS + 1] = { false, ... };

char 
	szColorName[MAXPLAYERS + 1][MAX_NAME_LENGTH],
	szColorChat[MAXPLAYERS + 1][64],
	g_sLeaderAuth[MAXPOSSIBLELEADERS][MAX_AUTHID_LENGTH],
	g_sSteamIDs2[MAXPLAYERS+1][MAX_AUTHID_LENGTH],
	g_sSteamIDs64[MAXPLAYERS+1][MAX_AUTHID_LENGTH];

float g_pos[3];

Handle 
	g_hShortcut = INVALID_HANDLE,
	g_hMarkerPos = INVALID_HANDLE,
	g_hSetClientLeaderForward,
	g_hRemoveClientLeaderForward;

enum struct LeaderData {
	char L_Codename[48];
	int L_Slot;

	char L_TrailVMT[PLATFORM_MAX_PATH];
	char L_TrailVTF[PLATFORM_MAX_PATH];
	char L_CodeNameVMT[PLATFORM_MAX_PATH];
	char L_CodeNameVTF[PLATFORM_MAX_PATH];
	char L_FollowVMT[PLATFORM_MAX_PATH];
	char L_FollowVTF[PLATFORM_MAX_PATH];
	char L_MarkerMDL[PLATFORM_MAX_PATH];
	char L_MarkerVMT[PLATFORM_MAX_PATH];

	char L_MarkerArrowVMT[PLATFORM_MAX_PATH];
	char L_MarkerArrowVTF[PLATFORM_MAX_PATH];
	int L_iColorArrow[4];

	char L_MarkerZMTP_VMT[PLATFORM_MAX_PATH];
	char L_MarkerZMTP_VTF[PLATFORM_MAX_PATH];
	int L_iColorZMTP[4];

	char L_MarkerNOHUG_VMT[PLATFORM_MAX_PATH];
	char L_MarkerNOHUG_VTF[PLATFORM_MAX_PATH];
	int L_iColorNOHUG[4];

	char L_MarkerDefend_VMT[PLATFORM_MAX_PATH];
	char L_MarkerDefend_VTF[PLATFORM_MAX_PATH];
	int L_iColorDefend[4];
}

LeaderData g_LeaderData[MAXLEADER];

int TotalLeader;

public Plugin myinfo = {
	name = "ZLeader Remake",
	author = "Original by AntiTeal, nuclear silo, CNTT, colia || Remake by Oylsister, .Rushaway",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = "3.3.3",
	url = "https://github.com/oylsister/ZLeader-Remake"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("ZL_SetLeader", Native_SetLeader);
	CreateNative("ZL_IsClientLeader", Native_IsClientLeader);
	CreateNative("ZL_RemoveLeader", Native_RemoveLeader);
	CreateNative("ZL_GetClientLeaderSlot", Native_GetClientLeaderSlot);
	CreateNative("ZL_IsLeaderSlotFree", Native_IsLeaderSlotFree);
	CreateNative("ZL_IsPossibleLeader", Native_IsPossibleLeader);

	MarkNativeAsOptional("CCC_GetColorKey");
	RegPluginLibrary("zleader");

	return APLRes_Success;
}

public void OnPluginStart() {
	/* TRANSLATIONS */
	LoadTranslations("zleader.phrases.txt");
	LoadTranslations("common.phrases.txt");

	/* PUBLIC COMMANDS */
	RegConsoleCmd("sm_mark", Command_Marker, "Open Marker menu");
	RegConsoleCmd("sm_marker", Command_Marker, "Open Marker menu");
	RegConsoleCmd("sm_leader", Command_Leader, "Take the Leader role");
	RegConsoleCmd("sm_vl", Command_VoteLeader, "Vote for set a leader");
	RegConsoleCmd("sm_voteleader", Command_VoteLeader, "Vote for set a leader");
	RegConsoleCmd("sm_leaders", Command_PossibleLeaders, "Print all possible leaders");
	RegConsoleCmd("sm_currentleader", Command_CurrentLeader, "Print all active leaders");

	/* ADMINS COMMANDS */
	RegAdminCmd("sm_removeleader", Command_RemoveLeader, ADMFLAG_KICK, "Revome a current leader");
	RegAdminCmd("sm_reloadleaders", Command_ReloadLeaders, ADMFLAG_BAN, "Reload access for leader.ini");

	/* CONVARS */
	g_cvNeonLeader = CreateConVar("sm_zleader_neon", "1", "Put a neon light parented to the leader");
	g_cvGlowLeader = CreateConVar("sm_zleader_glow", "1", "Put a glow colors effect on the leader");
	g_cvTrailPosition = CreateConVar("sm_zleader_trail_position", "0.0 0.0 10.0", "The trail position (X Y Z)");
	g_cvEnableVIP = CreateConVar("sm_zleader_vip", "0", "VIP groups can be leader?", _, true, 0.0, true, 1.0);

	AddCommandListener(HookPlayerChat, "say");
	AddCommandListener(HookPlayerChatTeam, "say_team");
	AddCommandListener(QuickLeaderMenuCommand, "+lookatweapon");
	AddCommandListener(QuickMarkerMenuCommand, "-lookatweapon");

	/* HOOK EVENTS & RADIO */
	AddTempEntHook("Player Decal", HookDecal);
	HookEvent("player_team", OnPlayerTeam);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("round_end", OnRoundEnd);
	HookRadio();

	/* COOKIES */
	SetCookieMenuItem(ZLeaderCookieHandler, 0, "ZLeader Settings");
	g_hMarkerPos = RegClientCookie("zleader_makerpos", "ZLeader Marker Position", CookieAccess_Protected);
	g_hShortcut = RegClientCookie("zleader_shortcut", "ZLeader ShortCut", CookieAccess_Protected);

	/* ADD FILTERS */
	AddMultiTargetFilter("@leaders", Filter_Leaders, "Possible Leaders", false);
	AddMultiTargetFilter("@!leaders", Filter_NotLeaders, "Everyone but Possible Leaders", false);
	AddMultiTargetFilter("@leader", Filter_Leader, "Current Leader", false);
	AddMultiTargetFilter("@!leader", Filter_NotLeader, "Every one but the Current Leader", false);

	/* FORWARDS */
	g_hSetClientLeaderForward = CreateGlobalForward("Leader_SetClientLeader", ET_Ignore, Param_Cell, Param_String);
	g_hRemoveClientLeaderForward = CreateGlobalForward("Leader_RemoveClientLeader", ET_Ignore, Param_Cell);

	/* Late load */
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientConnected(i)) {
			OnClientPutInServer(i);
		}
	}
}

void LoadConfig() {
	char spath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, spath, sizeof(spath), "configs/zleader/configs.txt");

	if (!FileExists(spath)) {
		SetFailState("Couldn't find config file: %s", spath);
		return;
	}

	KeyValues kv = CreateKeyValues("zleader");

	FileToKeyValues(kv, spath);

	if (KvGotoFirstSubKey(kv)) {
		TotalLeader = 0;

		do {
			KvGetString(kv, "codename", g_LeaderData[TotalLeader].L_Codename, 48);

			g_LeaderData[TotalLeader].L_Slot = KvGetNum(kv, "leader_slot", -1);

			KvGetString(kv, "codename_vmt", g_LeaderData[TotalLeader].L_CodeNameVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "codename_vtf", g_LeaderData[TotalLeader].L_CodeNameVTF, PLATFORM_MAX_PATH);

			KvGetString(kv, "trail_vmt", g_LeaderData[TotalLeader].L_TrailVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "trail_vtf", g_LeaderData[TotalLeader].L_TrailVTF, PLATFORM_MAX_PATH);
			
			KvGetString(kv, "follow_vmt", g_LeaderData[TotalLeader].L_FollowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "follow_vtf", g_LeaderData[TotalLeader].L_FollowVTF, PLATFORM_MAX_PATH);

			KvGetString(kv, "marker_mdl", g_LeaderData[TotalLeader].L_MarkerMDL, PLATFORM_MAX_PATH);
			KvGetString(kv, "marker_vmt", g_LeaderData[TotalLeader].L_MarkerVMT, PLATFORM_MAX_PATH);

			KvGetString(kv, "arrow_vmt", g_LeaderData[TotalLeader].L_MarkerArrowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "arrow_vtf", g_LeaderData[TotalLeader].L_MarkerArrowVTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "arrow_color", g_LeaderData[TotalLeader].L_iColorArrow[0], g_LeaderData[TotalLeader].L_iColorArrow[1], g_LeaderData[TotalLeader].L_iColorArrow[2], g_LeaderData[TotalLeader].L_iColorArrow[3]);

			KvGetString(kv, "defend_vmt", g_LeaderData[TotalLeader].L_MarkerDefend_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "defend_vtf", g_LeaderData[TotalLeader].L_MarkerDefend_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "defend_color", g_LeaderData[TotalLeader].L_iColorDefend[0], g_LeaderData[TotalLeader].L_iColorDefend[1], g_LeaderData[TotalLeader].L_iColorDefend[2], g_LeaderData[TotalLeader].L_iColorDefend[3]);

			KvGetString(kv, "zmtp_vmt", g_LeaderData[TotalLeader].L_MarkerZMTP_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "zmtp_vtf", g_LeaderData[TotalLeader].L_MarkerZMTP_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "zmtp_color", g_LeaderData[TotalLeader].L_iColorZMTP[0], g_LeaderData[TotalLeader].L_iColorZMTP[1], g_LeaderData[TotalLeader].L_iColorZMTP[2], g_LeaderData[TotalLeader].L_iColorZMTP[3]);

			KvGetString(kv, "nodoorhug_vmt", g_LeaderData[TotalLeader].L_MarkerNOHUG_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "nodoorhug_vtf", g_LeaderData[TotalLeader].L_MarkerNOHUG_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "nodoorhug_color", g_LeaderData[TotalLeader].L_iColorNOHUG[0], g_LeaderData[TotalLeader].L_iColorNOHUG[1], g_LeaderData[TotalLeader].L_iColorNOHUG[2], g_LeaderData[TotalLeader].L_iColorNOHUG[3]);
			
			TotalLeader++;
		}
		while(KvGotoNextKey(kv));
	}

	delete kv;
}

void LoadDownloadTable() {
	char spath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, spath, sizeof(spath), "configs/zleader/downloads.txt");

	File file = OpenFile(spath, "r");

	char buffer[PLATFORM_MAX_PATH];
	while (!IsEndOfFile(file)) {
		ReadFileLine(file, buffer, sizeof(buffer));

		int pos;
		pos = StrContains(buffer, "//");
		if (pos != -1) buffer[pos] = '\0';
		
		pos = StrContains(buffer, "#");
		if (pos != -1) buffer[pos] = '\0';

		pos = StrContains(buffer, ";");
		if (pos != -1) buffer[pos] = '\0';

		pos = StrContains(buffer, "*");
		if (pos != -1) buffer[pos] = '\0';
		
		TrimString(buffer);
		if (buffer[0] == '\0') continue;

		AddFileToDownloadsTable(buffer);
	}

	delete file;
}

void PrecacheConfig() {
	for(int i = 0; i < TotalLeader; i++) {
		if (g_LeaderData[i].L_CodeNameVMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_CodeNameVMT, true);

		if (g_LeaderData[i].L_TrailVMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_TrailVMT, true);

		if (g_LeaderData[i].L_FollowVMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_FollowVMT, true);

		if (g_LeaderData[i].L_MarkerMDL[0] != '\0')
			PrecacheModel(g_LeaderData[i].L_MarkerMDL, true);

		if (g_LeaderData[i].L_MarkerVMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerVMT, true);

		if (g_LeaderData[i].L_MarkerArrowVMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerArrowVMT, true);

		if (g_LeaderData[i].L_MarkerZMTP_VMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerZMTP_VMT, true);

		if (g_LeaderData[i].L_MarkerNOHUG_VMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerNOHUG_VMT, true);

		if (g_LeaderData[i].L_MarkerDefend_VMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerDefend_VMT, true);
	}
}

/* =========================================================================
||  REMOVE ALL FILTERS
============================================================================ */
public void OnPluginEnd() {
	RemoveMultiTargetFilter("@leaders", Filter_Leaders);
	RemoveMultiTargetFilter("@!leaders", Filter_NotLeaders);
	RemoveMultiTargetFilter("@leader", Filter_Leader);
	RemoveMultiTargetFilter("@!leader", Filter_NotLeader);
}

/* =========================================================================
||  EXTERNAL PLUGINS
============================================================================ */
public void OnAllPluginsLoaded() {
	vipcore = LibraryExists("vip_core");
	g_ccc = LibraryExists("ccc");
}
public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "vip_core", false) == 0)
		vipcore = false;

	if (strcmp(name, "ccc", false) == 0)
		g_ccc = false;
}
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "vip_core", false) == 0)
		vipcore = true;

	if (strcmp(name, "ccc", false) == 0)
		g_ccc = true;
}

/* =========================================================================
||  INITIAL SETUP (Cache, dl table, load cfg..)
============================================================================ */
public void OnMapStart() {
	LoadConfig();
	LoadDownloadTable();
	PrecacheConfig();
	UpdateLeaders();

	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null) {
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
		g_BeamSprite = PrecacheModel(buffer);

	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
		g_HaloSprite = PrecacheModel(buffer);
}

/* =========================================================================
||  CLIENT CONNECTING (Index, Cookie, ..)
============================================================================ */
public void OnClientPutInServer(int client) {
	g_bClientLeader[client] = false;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientNextVote[client] = 0;
	g_iClientVoteWhom[client] = -1;

	if (AreClientCookiesCached(client))
		ReadClientCookies(client);

	char sSteamID2[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID2, sizeof(sSteamID2), false);
	FormatEx(g_sSteamIDs2[client], sizeof(g_sSteamIDs2[]), "%s", sSteamID2);

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64), false);
	FormatEx(g_sSteamIDs64[client], sizeof(g_sSteamIDs64[]), "%s", sSteamID64);
}

public void OnClientCookiesCached(int client) {
	ReadClientCookies(client);
}

public void ReadClientCookies(int client) {
	char buffer[32];
	GetClientCookie(client, g_hShortcut, buffer, 32);
	if (buffer[0] != '\0')
		g_bShorcut[client] = view_as<bool>(StringToInt(buffer));
	else
		g_bShorcut[client] = true;

	GetClientCookie(client, g_hMarkerPos, buffer, 32);
	if (buffer[0] != '\0')
		g_iMarkerPos[client] = StringToInt(buffer);
	else
		g_iMarkerPos[client] = MK_CROSSHAIR;
}

public void SetClientCookies(int client) {
	char sValue[8];

	Format(sValue, sizeof(sValue), "%i", g_bShorcut[client]);
	SetClientCookie(client, g_hShortcut, sValue);

	Format(sValue, sizeof(sValue), "%i", g_iMarkerPos[client]);
	SetClientCookie(client, g_hMarkerPos, sValue);
}

public void ZLeaderCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen) {
	switch (action) {
		case CookieMenuAction_SelectOption: {
			ZLeaderSetting(client);
		}
	}
}

public void ZLeaderSetting(int client) {
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

public int ZLeaderSettingHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_DisplayItem: {
			char info[64];
			char display[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0) {
				if (g_bShorcut[param1])
					Format(display, sizeof(display), "%T : %T", "Shortcut", param1, "Enabled", param1);
				else
					Format(display, sizeof(display), "%T : %T", "Shortcut", param1, "Disabled", param1);

				return RedrawMenuItem(display);
			} else if (strcmp(info, "markerpos", false) == 0) {
				char thepos[32];

				if (g_iMarkerPos[param1] == MK_CLIENT)
					Format(thepos, sizeof(thepos), "%T", "Client Position", param1);
				else
					Format(thepos, sizeof(thepos), "%T", "Client Crosshair", param1);

				Format(display, sizeof(display), "%T : %s", "Marker Pos", param1, thepos);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0) {
				char status[32];
				g_bShorcut[param1] = !g_bShorcut[param1];

				if (g_bShorcut[param1])
					Format(status, 64, "%T", "Enabled Chat", param1);
				else
					Format(status, 64, "%T", "Disabled Chat", param1);

				CPrintToChat(param1, "%T %T", "Prefix", param1, "You set shortcut", param1, status);
			} else if (strcmp(info, "markerpos", false) == 0) {
				if (g_iMarkerPos[param1] == MK_CLIENT) {
					g_iMarkerPos[param1] = MK_CROSSHAIR;
					CPrintToChat(param1, "%T %T", "Prefix", param1, "Marker Pos Crosshair", param1);
				} else {
					g_iMarkerPos[param1] = MK_CLIENT;
					CPrintToChat(param1, "%T %T", "Prefix", param1, "Marker Pos Player Postion", param1);
				}
			}

			ZLeaderSetting(param1);
		}
		case MenuAction_Cancel: {
			ShowCookieMenu(param1);
		}
		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

/* =========================================================================
||  Hook Event Stuff
============================================================================ */
public void OnClientDisconnect(int client) {
	if (IsClientLeader(client))
		RemoveLeader(client, R_DISCONNECTED, true);

	g_bClientLeader[client] = false;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientNextVote[client] = 0;
	g_iClientVoteWhom[client] = -1;

	FormatEx(g_sSteamIDs2[client], sizeof(g_sSteamIDs2[]), "");
	FormatEx(g_sSteamIDs64[client], sizeof(g_sSteamIDs64[]), "");

	SetClientCookies(client);
}

public Action ZR_OnClientInfect(int &client, int &attacker, bool &motherInfect, bool &respawnOverride, bool &respawn) {
	if (IsClientLeader(client)) {
		RemoveLeader(client, R_INFECTED, true);
	}

	return Plugin_Continue;
}


public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int team = event.GetInt("team");

	if (team == CS_TEAM_NONE || team == CS_TEAM_SPECTATOR)
		return;

	if (IsClientLeader(client))
		RemoveLeader(client, R_SPECTATOR, true);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsClientLeader(client))
		return;

	RemoveLeader(client, R_DIED, true);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherinfect, bool override, bool respawn)
{
	if (!IsClientLeader(client))
		return;

	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Get Infected", i, codename, client);
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	// We create timer for don't insta remove leader (usefull for API)
	CreateTimer(0.3, RoundEndClean, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	KillAllBeacons();
}
public Action RoundEndClean(Handle timer) {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
			g_iClientNextVote[i] = 0;
		if (IsClientLeader(i))
			RemoveLeader(i, R_ADMINFORCED, false);
	}
	return Plugin_Handled;
}

/* =========================================================================
||  Leader Command
============================================================================ */
public Action Command_Leader(int client, int args) {
	SetGlobalTransTarget(client);

	if (args == 0) {
		if (client <= 0)
			ReplyToCommand(client, "%t %t", "Prefix", "Target must be alive");

		if (IsPlayerAlive(client) && ZR_IsClientHuman(client) && IsClientLeader(client)) {
			LeaderMenu(client);
			return Plugin_Stop;
		}

		if (IsPossibleLeader(client)) {
			if (!IsClientLeader(client)) {
				if (!IsPlayerAlive(client)) {
					CReplyToCommand(client, "%t %t", "Prefix", "Target must be alive");
					return Plugin_Stop;
				}
				if (ZR_IsClientZombie(client)) {
					CReplyToCommand(client, "%t %t", "Prefix", "It's Zombie");
					return Plugin_Stop;
				}

				for (int i = 0; i < TotalLeader; i++) {
					if (IsLeaderSlotFree(i)) {
						SetClientLeader(client, _, i);
						LeaderMenu(client);
						return Plugin_Stop;
					}
				}

				CReplyToCommand(client, "%t %t", "Prefix", "Slot is full");
				return Plugin_Stop;
			}
		} else {
			CReplyToCommand(client, "%t {red}%t", "Prefix", "Request Access");
			return Plugin_Handled;
		}
	}

	if (args == 1) {
		char sArgs[64];
		GetCmdArg(1, sArgs, sizeof(sArgs));
		char sTargetName[MAX_TARGET_LENGTH];
		int iTargets[MAXPLAYERS];
		int TargetCount;
		bool TnIsMl;

		if ((TargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS,
			COMMAND_FILTER_CONNECTED | COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), TnIsMl)) <= 0)
		{
			/* IF MORE THAN ONE TARGET IN GAME FOUND */
			ReplyToTargetError(client, TargetCount);
			return Plugin_Handled;
		}

		/* IF NO TARGET FOUND */
		if (TargetCount == -1)
			return Plugin_Handled;

		int target = iTargets[0];

		if (target != -1) {
			if (!IsClientAdmin(client)) {
				CReplyToCommand(client, "%t %t", "Prefix", "Unable to target");
				return Plugin_Handled;
			}
			if (!IsClientInGame(target)) {
				CReplyToCommand(client, "%t %t", "Prefix", "Target is not in game");
				return Plugin_Handled;
			}
			if (!IsPlayerAlive(target)) {
				CReplyToCommand(client, "%t %t", "Prefix", "Target must be alive");
				return Plugin_Handled;
			}
			if (ZR_IsClientZombie(target)) {
				CReplyToCommand(client, "%t %t", "Prefix", "It's Zombie");
				return Plugin_Handled;
			}
			if (IsClientLeader(target)) {
				CReplyToCommand(client, "%t %t", "Prefix", "Already Leader", target);
				return Plugin_Handled;
			}

			for (int i = 0; i < TotalLeader; i++) {
				if (IsLeaderSlotFree(i)) {
					LogAction(client, target, "[ZLeader] \"%L\" have set leader on \"%L\"", client, target);
					CReplyToCommand(client, "%t %t", "Prefix", "You set client leader", target);
					SetClientLeader(target, client, i);
					LeaderMenu(target);
					return Plugin_Handled;
				}
			}

			CReplyToCommand(client, "%t %t", "Prefix", "Slot is full");
			return Plugin_Stop;
		} else {
			CReplyToCommand(client, "%t %t", "Prefix", "Leader usage");
			return Plugin_Handled;
		}
	}

	if (args > 1) {
		CReplyToCommand(client, "%t %t", "Prefix", "Leader usage");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public void LeaderMenu(int client) {
	SetGlobalTransTarget(client);
	Menu menu = new Menu(LeaderMenuHandler, MENU_ACTIONS_ALL);

	int Defend = g_iClientMarker[MK_DEFEND][client] != -1;
	int Arrow = g_iClientMarker[MK_NORMAL][client] != -1;
	int NoHug = g_iClientMarker[MK_NOHUG][client] != -1;
	int ZMTP = g_iClientMarker[MK_ZMTP][client] != -1;

	if (Arrow || Defend || NoHug || ZMTP) {
		char sds[64];
		if (Arrow)
			Format(sds, sizeof(sds), "%t", "Arrow Marker");
		if (Defend)
			Format(sds, sizeof(sds), "%t", "Defend Here");
		if (NoHug)
			Format(sds, sizeof(sds), "%t", "No Doorhug");
		if (ZMTP)
			Format(sds, sizeof(sds), "%t", "ZM Teleport");
		if (Arrow && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "ZM Teleport");
		if (Arrow && Defend) 
			Format(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "Defend Here");
		if (Arrow && NoHug) 
			Format(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "No Doorhug");
		if (NoHug && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t", "ZM Teleport", "No Doorhug");
		if (Defend && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t", "Defend Here", "ZM Teleport");
		if (NoHug && Defend)
			Format(sds, sizeof(sds), "%t\n→ %t", "Defend Here", "No Doorhug");
		if (Arrow && Defend && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Arrow Marker", "Defend Here", "No Doorhug");
		if (Arrow && NoHug && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Arrow Marker", "ZM Teleport", "No Doorhug");
		if (Defend && ZMTP && NoHug)
			Format(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Defend Here", "ZM Teleport", "No Doorhug");
		if (Arrow && Defend && NoHug && ZMTP)
			Format(sds, sizeof(sds), "%t\n→ %t\n→ %t\n→ %t", "Arrow Marker", "Defend Here", "ZM Teleport", "No Doorhug");

		menu.SetTitle("%T \nActive Marker:\n→ %s", "Menu Leader title", client, sds);
	} else
		menu.SetTitle("%T", "Menu Leader title", client);

	char follow[64], trail[64], beacon[64], marker[64], removemarker[64], resign[64];

	Format(follow, 64, "%T", "Follow Me", client);
	Format(trail, 64, "%T", "Toggle Trail", client);
	Format(beacon, 64, "%T", "Toggle Beacon", client);
	Format(marker, 64, "%T", "Place Marker", client);
	Format(removemarker, 64, "%T", "Remove Marker", client);
	Format(resign, 64, "%T", "Resign from Leader", client);

	menu.AddItem("follow", follow);
	menu.AddItem("trail", trail);
	menu.AddItem("beacon", beacon);
	menu.AddItem("marker", marker);
	menu.AddItem("removemarker", removemarker);
	menu.AddItem("resign", resign);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int LeaderMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (IsValidClient(param1) && IsClientLeader(param1)) {
		switch (action) {
			case MenuAction_DisplayItem: {
				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "follow", false) == 0) {
					char display[128];
					if (g_iClientSprite[param1] == SP_FOLLOW) {
						Format(display, sizeof(display), "%T (✘)", "Follow Me", param1);
						return RedrawMenuItem(display);
					}
				} else if (strcmp(info, "trail", false) == 0) {
					char display[128];
					if (g_bTrailActive[param1]) {
						Format(display, sizeof(display), "%T (✘)", "Toggle Trail", param1);
						return RedrawMenuItem(display);
					}
				} else if (strcmp(info, "beacon", false) == 0) {
					char display[128];
					if (g_bBeaconActive[param1]) {
						Format(display, sizeof(display), "%T (✘)", "Toggle Beacon", param1);
						return RedrawMenuItem(display);
					}
				}
			}

			case MenuAction_Select: {
				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				if (!ZR_IsClientZombie(param1)) {
					if (strcmp(info, "follow", false) == 0) {
						if (g_iClientSprite[param1] != SP_FOLLOW) {
							RemoveSpriteFollow(param1);
							g_iClientSprite[param1] = SP_FOLLOW;
							int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[param1]);
							if (g_LeaderData[slot].L_FollowVMT[0] != '\0')
								g_iSpriteFollow[param1] = AttachSprite(param1, g_LeaderData[slot].L_FollowVMT, 1);
						} else {
							RemoveSpriteFollow(param1);
							g_iClientSprite[param1] = SP_NONE;
						}

						LeaderMenu(param1);
					} else if (strcmp(info, "trail", false) == 0) {
						ToggleTrail(param1);
						LeaderMenu(param1);
					} else if (strcmp(info, "beacon", false) == 0) {
						ToggleBeacon(param1);
						LeaderMenu(param1);
					} else if (strcmp(info, "marker", false) == 0) {
						MarkerMenu(param1);
					} else if (strcmp(info, "removemarker", false) == 0) {
						for (int i = 0; i < 4; i++)
							RemoveMarker(param1, i);

						LeaderMenu(param1);
					} else if (strcmp(info, "resign", false) == 0) {
						ResignConfirmMenu(param1);
					}
				}
			}

			case MenuAction_End: {
				delete menu;
			}
		}
	}
	return 0;
}
/* =========================================================================
||  Reload Leader Access Command
============================================================================ */
public Action Command_ReloadLeaders(int client, int args) {
	UpdateLeaders();
	CReplyToCommand(client, "%T %T", "Prefix", client, "Leader cache refreshed", client);
	LogAction(client, -1, "[ZLeader] \"%L\" has refreshed Leaders cache.", client);
	return Plugin_Handled;
}

/* =========================================================================
||  Possible Leader Command
============================================================================ */
public Action Command_PossibleLeaders(int client, int args) {
	char aBuf[1024];
	char aBuf2[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && IsPossibleLeader(i)) {
			GetClientName(i, aBuf2, sizeof(aBuf2));
			StrCat(aBuf, sizeof(aBuf), aBuf2);
			StrCat(aBuf, sizeof(aBuf), ", ");
		}
	}

	if (strlen(aBuf)) {
		aBuf[strlen(aBuf) - 2] = 0;
		CReplyToCommand(client, "%T %T", "Prefix", client, "Possible Leaders", client, aBuf);
	} else {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Possible Leaders None", client);
	}

	return Plugin_Handled;
}

/* =========================================================================
||  Current Leader Command
============================================================================ */
public Action Command_CurrentLeader(int client, int args) {
	Menu menu = new Menu(CurrentLeaderMenuHandler);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Menu Leader list title", client);
	CReplyToCommand(client, "%T %T", "Prefix", client, "Current Leaders", client);
	
	for (int i = 0; i < TotalLeader; i++) {
		char codename[32];
		char sLine[128];

		GetLeaderCodename(i, codename, sizeof(codename));

		if (!IsLeaderSlotFree(i)) {
			CReplyToCommand(client, "{darkred}[{orange}%s{darkred}] {lightblue}%N", codename, g_iCurrentLeader[i]);
			Format(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		} else {
			Format(sLine, 128, "%s: %T", codename, "None", client);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int CurrentLeaderMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (IsValidClient(param1) && g_bClientLeader[param1]) {
		switch (action) {
			case MenuAction_End: {
				delete menu;
			}
		}
	}
	return 0;
}

/* =========================================================================
||  Vote Leader Command
============================================================================ */
public Action Command_VoteLeader(int client, int args) {
	if (client <= 0) {
		ReplyToCommand(client, "%T %T", "Prefix", client, "This command can only be used in-game.", client);
		return Plugin_Handled;
	}
	int count = 0;
	for (int i = 0; i < TotalLeader; i++) {
		if (!IsLeaderSlotFree(i))
			count++;
	}

	if (count >= 5) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Slot is full", client);
		return Plugin_Handled;
	}

	if (args < 1) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Vote leader usage", client);
		return Plugin_Handled;
	}

	char sArgs[64];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int TargetCount;
	bool TnIsMl;

	if ((TargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS,
		COMMAND_FILTER_CONNECTED | COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), TnIsMl)) <= 0)
	{
		/* IF MORE THAN ONE TARGET IN GAME FOUND */
		ReplyToTargetError(client, TargetCount);
		return Plugin_Handled;
	}

	/* IF NO TARGET FOUND */
	if (TargetCount == -1)
		return Plugin_Handled;

	int target = iTargets[0];

	if (g_iClientNextVote[client] > GetTime())
	{
		CReplyToCommand(client, "%T %T", "Prefix", client, "VoteLeader Cooldown", client, g_iClientNextVote[client] - GetTime());
		return Plugin_Handled;
	}

	if (!IsClientInGame(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Target is not in game", client);
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Target must be alive", client);
		return Plugin_Handled;
	}

	if (GetClientFromSerial(g_iClientVoteWhom[client]) == target) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Already vote client", client);
		return Plugin_Handled;
	}

	if (ZR_IsClientZombie(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Has to be human", client);
		return Plugin_Handled;
	}

	if (IsClientLeader(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Already Leader", client, target);
		return Plugin_Handled;
	}

	if (GetClientFromSerial(g_iClientVoteWhom[client]) != 0) {
		if (IsValidClient(GetClientFromSerial(g_iClientVoteWhom[client]))) 
			g_iClientGetVoted[GetClientFromSerial(g_iClientVoteWhom[client])]--;
	}

	g_iClientGetVoted[target]++;
	g_iClientVoteWhom[client] = GetClientSerial(target);
	g_iClientNextVote[client] = GetTime() + 10;

	int number = GetClientCount(true)/8;

	if (number == 0)
		number = 1;

	for (int i = 1; i <= MaxClients; i++) {
		SetGlobalTransTarget(i);

		if (IsClientInGame(i))
			CPrintToChat(i, "%t %t", "Prefix", "Vote for client", client, target, g_iClientGetVoted[target], number);
	}

	if (g_iClientGetVoted[target] >= number) {
		int slot = GetLeaderFreeSlot();

		if (slot == -1) {
			CReplyToCommand(client, "%T %T", "Prefix", client, "Slot is full", client);
			return Plugin_Handled;
		}
		
		SetClientLeader(target, -1, slot);
		LeaderMenu(target);
	}

	return Plugin_Handled;
}

/* =========================================================================
||  Remove Leader Command
============================================================================ */
public Action Command_RemoveLeader(int client, int args) {
	if (args < 1) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Remove leader usage", client);
		RemoveLeaderList(client);
		return Plugin_Handled;
	}

	char sArgs[64];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int TargetCount;
	bool TnIsMl;

	if ((TargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS,
		COMMAND_FILTER_CONNECTED | COMMAND_FILTER_ALIVE | COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_IMMUNITY, sTargetName, sizeof(sTargetName), TnIsMl)) <= 0)
	{
		/* IF MORE THAN ONE TARGET IN GAME FOUND */
		ReplyToTargetError(client, TargetCount);
		return Plugin_Handled;
	}

	/* IF NO TARGET FOUND */
	if (TargetCount == -1)
		return Plugin_Handled;

	int target = iTargets[0];

	if (target == -1) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Invalid client", client);
		return Plugin_Handled;
	}

	if (!IsClientLeader(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Client is not leader", client, target);
		return Plugin_Handled;
	}

	RemoveLeader(target, R_ADMINFORCED, true);
	LogAction(client, target, "[ZLeader] Leader \"%L\" has been resigned by \"%L\"", target, client);
	return Plugin_Handled;
}

public void RemoveLeaderList(int client) {
	if (!IsValidClient(client)) return;

	SetGlobalTransTarget(client);
	Menu menu = new Menu(RemoveLeaderListMenuHandler);

	char title[128];
	Format(title, sizeof(title), "%t %t \n%t", "Menu Prefix", "Menu Leader list title", "Menu Remove Leader title");
	menu.SetTitle("%s", title);
	
	for (int i = 0; i < TotalLeader; i++) {
		char codename[32];
		char sLine[128];

		GetLeaderCodename(i, codename, sizeof(codename));

		if (!IsLeaderSlotFree(i)) {
			Format(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine);
		} else {
			Format(sLine, 128, "%s: %t", codename, "None");
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return;
}

public int RemoveLeaderListMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			for (int i = 0; i < TotalLeader; i++) {
				if (param2 == i && !IsLeaderSlotFree(i)) {
					LogAction(param1, g_iCurrentLeader[i], "[ZLeader] Leader \"%L\" has been resigned by \"%L\"", g_iCurrentLeader[i], param1);
					RemoveLeader(g_iCurrentLeader[i], R_ADMINFORCED, true);
				}
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	return 0;
}

/* =========================================================================
||  Trails
============================================================================ */
stock void ToggleTrail(int client) {
	if (g_bTrailActive[client])
		g_bTrailActive[client] = false;
	else
		g_bTrailActive[client] = true;

	PerformTrail(client);
}

stock void PerformTrail(int client) {
	if (g_TrailModel[client] == 0)
		CreateTrail(client);
	else
		KillTrail(client);
}

stock void CreateTrail(int client) {
	if (!client)
		return;

	KillTrail(client);

	if (!IsPlayerAlive(client) || !(1 < GetClientTeam(client) < 4))
		return;
	
	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	g_TrailModel[client] = CreateEntityByName("env_spritetrail");

	if (g_TrailModel[client] != 0) {
		DispatchKeyValueFloat(g_TrailModel[client], "lifetime", 2.0);
		DispatchKeyValue(g_TrailModel[client], "startwidth", "25");
		DispatchKeyValue(g_TrailModel[client], "endwidth", "15");
		DispatchKeyValue(g_TrailModel[client], "spritename", g_LeaderData[slot].L_TrailVMT);
		DispatchKeyValue(g_TrailModel[client], "rendercolor", "255 255 255");
		DispatchKeyValue(g_TrailModel[client], "renderamt", "255");
		DispatchKeyValue(g_TrailModel[client], "rendermode", "0");
		DispatchKeyValue(g_TrailModel[client], "targetname", "trail");

		DispatchSpawn(g_TrailModel[client]);

		char sVectors[64];
		GetConVarString(g_cvTrailPosition, sVectors, sizeof(sVectors));

		float angles[3], origin[3]; 
		char angle[64][3];

		ExplodeString(sVectors, " ", angle, 3, sizeof(angle), false);
		angles[0] = StringToFloat(angle[0]);
		angles[1] = StringToFloat(angle[1]);
		angles[2] = StringToFloat(angle[2]);

		GetClientAbsOrigin(client, origin);
		origin[0] += angles[0];
		origin[1] += angles[1];
		origin[2] += angles[2];

		TeleportEntity(g_TrailModel[client], origin, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(g_TrailModel[client], "SetParent", client); 
		SetEntPropFloat(g_TrailModel[client], Prop_Send, "m_flTextureRes", 0.05);
		SetEntPropEnt(g_TrailModel[client], Prop_Send, "m_hOwnerEntity", client);
	}
}

stock void KillTrail(int client) {
	if (g_TrailModel[client] > MaxClients && IsValidEdict(g_TrailModel[client]))
		AcceptEntityInput(g_TrailModel[client], "kill");
	
	g_TrailModel[client] = 0;
}

/* =========================================================================
||  Beacon
============================================================================ */
public void ToggleBeacon(int client) {
	g_bBeaconActive[client] = !g_bBeaconActive[client];
	PerformBeacon(client);
}

public void CreateBeacon(int client) {
	g_BeaconSerial[client] = ++g_Serial_Gen;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void KillBeacon(int client) {
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
		SetEntityRenderColor(client, 255, 255, 255, 255);
}

public void KillAllBeacons() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bBeaconActive[i])
			g_bBeaconActive[i] = false;

		KillBeacon(i);
	}
}

public void PerformBeacon(int client) {
	if (g_BeaconSerial[client] == 0)
		CreateBeacon(client);
	else
		KillBeacon(client);
}

public Action Timer_Beacon(Handle timer, any value) {
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial) {
		KillBeacon(client);
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;

	// First beacon beam
	int greyColor[4] = {128, 128, 128, 255};
	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 20, 0.5, 12.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();

	// Second beacon beam
	int rainbowColor[4];
	float i = GetGameTime();
	float Frequency = 2.5;
	rainbowColor[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	rainbowColor[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	rainbowColor[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	rainbowColor[3] = 255;
	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 25.0, 0.5, rainbowColor, 10, 0);
	TE_SendToAll();

	GetClientEyePosition(client, vec);

	return Plugin_Continue;
}

/* =========================================================================
||  Sprite
============================================================================ */
public void RemoveSpriteFollow(int client) {
	if (g_iSpriteFollow[client] != -1 && IsValidEdict(g_iSpriteFollow[client])) {
		char m_szClassname[64];
		GetEdictClassname(g_iSpriteFollow[client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("env_sprite", m_szClassname)==0)
			AcceptEntityInput(g_iSpriteFollow[client], "Kill");
	}

	g_iSpriteFollow[client] = -1;
}
public void RemoveSpriteCodeName(int client) {
	if (g_iSpriteLeader[client] != -1 && IsValidEdict(g_iSpriteLeader[client])) {
		char m_szClassname[64];
		GetEdictClassname(g_iSpriteLeader[client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("env_sprite", m_szClassname)==0)
			AcceptEntityInput(g_iSpriteLeader[client], "Kill");
	}

	g_iSpriteLeader[client] = -1;
}

// https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
public int AttachSprite(int client, char[] sprite, int position) {
	if (!IsPlayerAlive(client))
		return -1;

	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%T Attach Sprite cancelled, too many Edicts. Try again later.", "Prefix", client);
		return -1;
	}

	char iTarget[16], sTargetname[64];

	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
	Format(iTarget, sizeof(iTarget), "Client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float Origin[3];
	GetClientEyePosition(client, Origin);
	// Position 0 = Close to top of head, Position 1 = Higher pos
	if (position != 1)
		Origin[2] += 68.0;
	if (position == 1)
		Origin[2] += 82.0;

	int Ent = CreateEntityByName("env_sprite");

	if (!Ent)
		return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchKeyValue(Ent, "renderamt", "255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

/* =========================================================================
||  Marker
============================================================================ */
public Action Command_Marker(int client, int args) {
	if (IsClientLeader(client)) {
		MarkerMenu(client);
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

public void MarkerMenu(int client) {
	Menu menu = new Menu(MarkerMenuHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Marker menu title", client);

	char normal[64], defend[64], zmtp[64], nohug[64], removemarker[64];

	Format(normal, 64, "%T", "Arrow Marker", client);
	Format(defend, 64, "%T", "Defend Here", client);
	Format(zmtp, 64, "%T", "ZM Teleport", client);
	Format(nohug, 64, "%T", "No Doorhug", client);
	Format(removemarker, 64, "%T", "Remove Marker", client);

	menu.AddItem("normal", normal);
	menu.AddItem("defend", defend);
	menu.AddItem("zmtp", zmtp);
	menu.AddItem("nohug", nohug);
	menu.AddItem("removemarker", removemarker);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MarkerMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (IsValidClient(param1) && IsClientLeader(param1)) {
		switch (action) {
			case MenuAction_DisplayItem: {
				char info[64];
				char display[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "normal", false) == 0) {
					if (g_iClientMarker[MK_NORMAL][param1] != -1) {
						Format(display, sizeof(display), "%T (✘)", "Arrow Marker", param1);
						return RedrawMenuItem(display);
					}
				} else if (strcmp(info, "defend", false) == 0) {
					if (g_iClientMarker[MK_DEFEND][param1] != -1) {
						Format(display, sizeof(display), "%T (✘)", "Defend Here", param1);
						return RedrawMenuItem(display);
					}
				} else if (strcmp(info, "zmtp", false) == 0) {
					if (g_iClientMarker[MK_ZMTP][param1] != -1) {
						Format(display, sizeof(display), "%T (✘)", "ZM Teleport", param1);
						return RedrawMenuItem(display);
					}
				} else if (strcmp(info, "nohug", false) == 0) {
					if (g_iClientMarker[MK_NOHUG][param1] != -1) {
						Format(display, sizeof(display), "%T (✘)", "No Doorhug", param1);
						return RedrawMenuItem(display);
					}
				}
			}

			case MenuAction_Select: {
				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "normal", false) == 0) {
					if (g_iClientMarker[MK_NORMAL][param1] != -1)
						RemoveMarker(param1, MK_NORMAL);
					else
						SpawnMarker(param1, MK_NORMAL);
				} else if (strcmp(info, "defend", false) == 0) {
					if (g_iClientMarker[MK_DEFEND][param1] != -1)
						RemoveMarker(param1, MK_DEFEND);
					else
						SpawnMarker(param1, MK_DEFEND);
				} else if (strcmp(info, "zmtp", false) == 0) {
					if (g_iClientMarker[MK_ZMTP][param1] != -1)
						RemoveMarker(param1, MK_ZMTP);
					else
						SpawnMarker(param1, MK_ZMTP);
				} else if (strcmp(info, "nohug", false) == 0) {
					if (g_iClientMarker[MK_NOHUG][param1] != -1)
						RemoveMarker(param1, MK_NOHUG);
					else
						SpawnMarker(param1, MK_NOHUG);
				} else if (strcmp(info, "removemarker", false) == 0) {
					for (int i = 0; i < 4; i++)
						RemoveMarker(param1, i);
				}

				MarkerMenu(param1);
			}

			case MenuAction_Cancel: {
				LeaderMenu(param1);
			}

			case MenuAction_End: {
				delete menu;
			}
		}
	}
	return 0;
}

public void RemoveMarker(int client, int type) {
	if (g_iClientMarker[type][client] != -1 && IsValidEdict(g_iClientMarker[type][client])) {
		char m_szClassname[64];
		GetEdictClassname(g_iClientMarker[type][client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("prop_dynamic", m_szClassname) == 0)
			AcceptEntityInput(g_iClientMarker[type][client], "Kill");

		if (g_iMarkerEntities[type][client] != -1 && IsValidEdict(g_iMarkerEntities[type][client])) {
			GetEdictClassname(g_iMarkerEntities[type][client], m_szClassname, sizeof(m_szClassname));

			if (strcmp("env_sprite", m_szClassname) == 0)
				AcceptEntityInput(g_iMarkerEntities[type][client], "Kill");
		}
	}

	// Turn Off Neon related to the marker
	char sTargetName[64];
	if (type == MK_NORMAL)
		Format(sTargetName, sizeof(sTargetName), "MK_NORMAL%d", g_sSteamIDs64[client]);
	else if (type == MK_DEFEND)
		Format(sTargetName, sizeof(sTargetName), "MK_DEFEND%d", g_sSteamIDs64[client]);
	else if (type == MK_NOHUG)
		Format(sTargetName, sizeof(sTargetName), "MK_NOHUG%d", g_sSteamIDs64[client]);
	else if (type == MK_ZMTP)
		Format(sTargetName, sizeof(sTargetName), "MK_ZMTP%d", g_sSteamIDs64[client]);

	int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, sTargetName, "light_dynamic");
	if (iCounter != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iCounter, "Kill");

	g_iClientMarker[type][client] = -1;
	g_iMarkerEntities[type][client] = -1;
	g_iNeonEntities[type][client] = -1;
}

public void SpawnMarker(int client, int type) {
	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%T Marker spawn cancelled, too many Edicts. Try again later.", "Prefix", client);
		return;
	}

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	if (type == MK_NORMAL) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerArrowVMT);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorArrow, type);
	} else if (type == MK_DEFEND) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerDefend_VMT);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorDefend, type);
	} else if (type == MK_NOHUG) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerNOHUG_VMT);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorNOHUG, type);
	} else if (type == MK_ZMTP) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerZMTP_VMT);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorZMTP, type);
	}

	g_iClientMarker[type][client] = SpawnAimMarker(client, g_LeaderData[slot].L_MarkerMDL, type);
}

public int SpawnAimMarker(int client, char[] model, int type) {
	if (!IsPlayerAlive(client))
		return -1;

	int Ent = CreateEntityByName("prop_dynamic");
	if (!Ent) return -1;

	if (g_iMarkerPos[client] == MK_CROSSHAIR)
		GetPlayerEye(client, g_pos);
	else
		GetClientAbsOrigin(client, g_pos);

	DispatchKeyValue(Ent, "model", model);
	DispatchKeyValue(Ent, "DefaultAnim", "default");
	DispatchKeyValue(Ent, "solid", "0");
	DispatchKeyValue(Ent, "spawnflags", "256");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchKeyValue(Ent, "renderamt", "200");
	DispatchKeyValue(Ent, "modelscale", "0.9");
	DispatchSpawn(Ent);

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	if (type == MK_NORMAL)
		SetEntityRenderColor(Ent, g_LeaderData[slot].L_iColorArrow[0], g_LeaderData[slot].L_iColorArrow[1], g_LeaderData[slot].L_iColorArrow[2], g_LeaderData[slot].L_iColorArrow[3]);
	else if (type  == MK_DEFEND)
		SetEntityRenderColor(Ent, g_LeaderData[slot].L_iColorDefend[0], g_LeaderData[slot].L_iColorDefend[1], g_LeaderData[slot].L_iColorDefend[2], g_LeaderData[slot].L_iColorDefend[3]);
	else if (type  == MK_NOHUG)
		SetEntityRenderColor(Ent, g_LeaderData[slot].L_iColorNOHUG[0], g_LeaderData[slot].L_iColorNOHUG[1], g_LeaderData[slot].L_iColorNOHUG[2], g_LeaderData[slot].L_iColorNOHUG[3]);
	else
		SetEntityRenderColor(Ent, g_LeaderData[slot].L_iColorZMTP[0], g_LeaderData[slot].L_iColorZMTP[1], g_LeaderData[slot].L_iColorZMTP[2], g_LeaderData[slot].L_iColorZMTP[3]);

	TeleportEntity(Ent, g_pos, NULL_VECTOR, NULL_VECTOR);
	SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 1);

	SetVariantString("disablereceiveshadows 1");
	AcceptEntityInput(Ent, "AddOutput");
	SetVariantString("disableshadows 1");
	AcceptEntityInput(Ent, "AddOutput");

	return Ent;
}

public int SpawnSpecialMarker(int client, char[] sprite) {
	if (!IsPlayerAlive(client))
		return -1;

	int Ent = CreateEntityByName("env_sprite");
	if (!Ent) return -1;

	if (g_iMarkerPos[client] == MK_CROSSHAIR) {
		GetPlayerEye(client, g_pos);
		g_pos[2] += 160.0;
	} else {
		GetClientAbsOrigin(client, g_pos);
		g_pos[2] += 160.0;
	}

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchKeyValue(Ent, "renderamt", "128");
	DispatchSpawn(Ent);

	SetVariantString("disablereceiveshadows 1");
	AcceptEntityInput(Ent, "AddOutput");
	SetVariantString("disableshadows 1");
	AcceptEntityInput(Ent, "AddOutput");

	TeleportEntity(Ent, g_pos, NULL_VECTOR, NULL_VECTOR);

	return Ent;
}

stock int SetupPlayerNeon(int client) {
	if (GetEdictsCount() > MAXEDICTS)
		return -1;

	int Neon = CreateEntityByName("light_dynamic");

	if (!IsValidEntity(Neon))
		return -1;

	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);

	char sTargetName[64];
	Format(sTargetName, sizeof(sTargetName), "light_%d", g_sSteamIDs64[client]);

	DispatchKeyValue(Neon, "targetname", sTargetName);
	DispatchKeyValue(Neon, "_light", "25 25 200 255");
	DispatchKeyValue(Neon, "brightness", "5");
	DispatchKeyValue(Neon, "distance", "150");
	DispatchKeyValue(Neon, "spotlight_radius", "50");
	DispatchKeyValue(Neon, "style", "0");
	DispatchSpawn(Neon);
	AcceptEntityInput(Neon, "TurnOn");

	TeleportEntity(Neon, fOrigin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(Neon, "SetParent", client, Neon, 0);
	return 0;
}

stock int RemovePlayerNeon(int client) {
	char sTargetName[64];
	Format(sTargetName, sizeof(sTargetName), "light_%d", g_sSteamIDs64[client]);

	int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, sTargetName, "light_dynamic");
	if (iCounter != INVALID_ENT_REFERENCE)
		AcceptEntityInput(iCounter, "Kill");
	return 0;
}

stock int SetupSpecialNeon(int client, int color[4], int type) {
	int Neon = CreateEntityByName("light_dynamic");

	if (!IsValidEntity(Neon))
		return -1;

	if (g_iMarkerPos[client] == MK_CROSSHAIR) {
		GetPlayerEye(client, g_pos);
		g_pos[2] += 10.0;
	} else {
		GetClientAbsOrigin(client, g_pos);
		g_pos[2] += 10.0;
	}

	char sColor[64], sTargetName[64];
	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	if (type == MK_NORMAL) {
		Format(sColor, sizeof(sColor), "%i %i %i %i", g_LeaderData[slot].L_iColorArrow[0], g_LeaderData[slot].L_iColorArrow[1], g_LeaderData[slot].L_iColorArrow[2], g_LeaderData[slot].L_iColorArrow[3]);
		Format(sTargetName, sizeof(sTargetName), "MK_NORMAL%d", g_sSteamIDs64[client]);
	} else if (type  == MK_DEFEND) {
		Format(sColor, sizeof(sColor), "%i %i %i %i", g_LeaderData[slot].L_iColorDefend[0], g_LeaderData[slot].L_iColorDefend[1], g_LeaderData[slot].L_iColorDefend[2], g_LeaderData[slot].L_iColorDefend[3]);
		Format(sTargetName, sizeof(sTargetName), "MK_DEFEND%d", g_sSteamIDs64[client]);
	} else if (type  == MK_NOHUG) {
		Format(sColor, sizeof(sColor), "%i %i %i %i", g_LeaderData[slot].L_iColorNOHUG[0], g_LeaderData[slot].L_iColorNOHUG[1], g_LeaderData[slot].L_iColorNOHUG[2], g_LeaderData[slot].L_iColorNOHUG[3]);
		Format(sTargetName, sizeof(sTargetName), "MK_NOHUG%d", g_sSteamIDs64[client]);
	} else {
		Format(sColor, sizeof(sColor), "%i %i %i %i", g_LeaderData[slot].L_iColorZMTP[0], g_LeaderData[slot].L_iColorZMTP[1], g_LeaderData[slot].L_iColorZMTP[2], g_LeaderData[slot].L_iColorZMTP[3]);
		Format(sTargetName, sizeof(sTargetName), "MK_ZMTP%d", g_sSteamIDs64[client]);
	}

	DispatchKeyValue(Neon, "targetname", sTargetName);
	DispatchKeyValue(Neon, "_light", sColor);
	DispatchKeyValue(Neon, "brightness", "5");
	DispatchKeyValue(Neon, "distance", "150");
	DispatchKeyValue(Neon, "spotlight_radius", "50");
	DispatchKeyValue(Neon, "style", "0");
	DispatchSpawn(Neon);
	AcceptEntityInput(Neon, "TurnOn");

	TeleportEntity(Neon, g_pos, NULL_VECTOR, NULL_VECTOR);
	return 0;
}

stock void GetPlayerEye(int client, float pos[3]) {
	float vAngles[3], vOrigin[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	TR_GetEndPosition(pos);
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients || !entity;
}

/* =========================================================================
||  Leader Chat
============================================================================ */
public Action HookPlayerChat(int client, char[] command, int args) {
	if (IsValidClient(client) && IsClientLeader(client)) {
		char LeaderText[256];
		GetCmdArgString(LeaderText, sizeof(LeaderText));
		StripQuotes(LeaderText);

		if (LeaderText[0] == '/' || LeaderText[0] == '@' || strlen(LeaderText) == 0 || IsChatTrigger())
			return Plugin_Handled;
	
		char codename[32];
		GetLeaderCodename(g_iClientLeaderSlot[client], codename, sizeof(codename));

		if (g_ccc) {
			CPrintToChatAll("{darkred}[{orange}Leader %s{darkred}] {%s}%N {default}: {%s}%s", 
				codename, szColorName[client], client, szColorChat[client], LeaderText);
			return Plugin_Handled;
		} else {
			CPrintToChatAll("{darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}: {default}%s", codename, client, LeaderText);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

public Action HookPlayerChatTeam(int client, char[] command, int args) {
	if (IsValidClient(client) && IsClientLeader(client)) {
		char LeaderText[256];
		GetCmdArgString(LeaderText, sizeof(LeaderText));
		StripQuotes(LeaderText);

		if (LeaderText[0] == '/' || LeaderText[0] == '@' || strlen(LeaderText) == 0 || IsChatTrigger())
			return Plugin_Handled;
	
		char codename[32], szMessage[255];
		GetLeaderCodename(g_iClientLeaderSlot[client], codename, sizeof(codename));

		if (g_ccc) {
			Format(szMessage, sizeof(szMessage), "(Human) {darkred}[{orange}Leader %s{darkred}] {%s}%N {default}: {%s}%s", 
				codename, szColorName[client], client, szColorChat[client], LeaderText);
		} else {
			Format(szMessage, sizeof(szMessage), "(Human) {darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}: {default}%s", codename, client, LeaderText);
		}

		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && GetClientTeam(i) == 3) {
				CPrintToChat(i, szMessage);
				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

void GetClientChat(int client) {
	CCC_GetColorKey(client, CCC_NameColor, szColorName[client], 64);
	CCC_GetColorKey(client, CCC_ChatColor, szColorChat[client], 64);

	// Check HEX to prevent issue
	char szColorNameSanitized[64], szColorChatSanitized[64];

	if (szColorName[client][0] != '\0' && IsValidHex(szColorName[client])) {
		Format(szColorNameSanitized, sizeof(szColorNameSanitized), "#%s", szColorName[client]);
		szColorName[client] = szColorNameSanitized;
	} else {
		szColorName[client] = "lightblue";
	}

	if (szColorChat[client][0] != '\0' && IsValidHex(szColorChat[client])) {
		Format(szColorChatSanitized, sizeof(szColorChatSanitized), "#%s", szColorChat[client]);
		szColorChat[client] = szColorChatSanitized;
	} else {
		szColorChat[client] = "default";
	}
}

/* =========================================================================
||  Radio
============================================================================ */
void HookRadio() {
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

public Action Radio(int client, const char[] command, int argc) {
	if (IsClientLeader(client)) {
		if (strcmp(command, "compliment", false) == 0) PrintRadio(client, "Nice!");
		if (strcmp(command, "coverme", false) == 0) PrintRadio(client, "Cover Me!");
		if (strcmp(command, "cheer", false) == 0) PrintRadio(client, "Cheer!");
		if (strcmp(command, "takepoint", false) == 0) PrintRadio(client, "You take the point.");
		if (strcmp(command, "holdpos", false) == 0) PrintRadio(client, "Hold This Position.");
		if (strcmp(command, "regroup", false) == 0) PrintRadio(client, "Regroup Team.");
		if (strcmp(command, "followme", false) == 0) PrintRadio(client, "Follow me.");
		if (strcmp(command, "takingfire", false) == 0) PrintRadio(client, "Taking fire... need assistance!"); 
		if (strcmp(command, "thanks", false) == 0) PrintRadio(client, "Thanks!"); 
		if (strcmp(command, "go", false) == 0) PrintRadio(client, "Go go go!");
		if (strcmp(command, "fallback", false) == 0) PrintRadio(client, "Team, fall back!");
		if (strcmp(command, "sticktog", false) == 0) PrintRadio(client, "Stick together, team.");
		if (strcmp(command, "report", false) == 0) PrintRadio(client, "Report in, team.");
		if (strcmp(command, "roger", false) == 0) PrintRadio(client, "Roger that."); 
		if (strcmp(command, "enemyspot", false) == 0) PrintRadio(client, "Enemy spotted.");
		if (strcmp(command, "needbackup", false) == 0) PrintRadio(client, "Need backup.");
		if (strcmp(command, "sectorclear", false) == 0) PrintRadio(client, "Sector clear.");
		if (strcmp(command, "inposition", false) == 0) PrintRadio(client, "I'm in position.");
		if (strcmp(command, "reportingin", false) == 0) PrintRadio(client, "Reporting In.");
		if (strcmp(command, "getout", false) == 0) PrintRadio(client, "Get out of there, it's gonna blow!.");
		if (strcmp(command, "negative", false) == 0) PrintRadio(client, "Negative.");
		if (strcmp(command, "enemydown", false) == 0) PrintRadio(client, "Enemy down.");
		
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void PrintRadio(int client, char[] text) {
	char szMessage[255], codename[32];

	if (IsClientLeader(client)) {
		GetLeaderCodename(g_iClientLeaderSlot[client], codename, sizeof(codename));
		Format(szMessage, sizeof(szMessage), "{darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}(RADIO): %s", codename, client, text);
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
				CPrintToChat(i, szMessage);
		}
	}
}

/* =========================================================================
||  Function
============================================================================ */
void SetClientLeader(int client, int adminset = -1, int slot) {
	if (!IsClientInGame(client)) {
		if (adminset != -1)
			CReplyToCommand(adminset, "%T %T", "Prefix", client, "Invalid client", client);

		return;
	}

	char codename[32];
	GetLeaderCodename(slot, codename, sizeof(codename));

	if (g_ccc)
		GetClientChat(client);

	if (g_LeaderData[slot].L_CodeNameVMT[0] != '\0')
		g_iSpriteLeader[client] = AttachSprite(client, g_LeaderData[slot].L_CodeNameVMT, 0);

	if (g_cvNeonLeader.BoolValue)
		SetupPlayerNeon(client);

	if (g_cvGlowLeader.BoolValue) {
		SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		ToolsSetEntityColor(client, g_iGlowColor[client][0], g_iGlowColor[client][1], g_iGlowColor[client][2]);
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Become New Leader", i, client, codename);
	}

	for (int i = 0; i < 4; i++) {
		g_iClientMarker[i][client] = -1;
	}

	g_bClientLeader[client] = true;
	g_iClientLeaderSlot[client] = slot;
	g_iCurrentLeader[slot] = client;
	g_iClientSprite[client] = SP_NONE;
	

	Call_StartForward(g_hSetClientLeaderForward);
	Call_PushCell(client);
	Call_PushString(codename);
	Call_Finish();
}

void RemoveLeader(int client, ResignReason reason, bool announce = true) {
	char codename[32];
	int slot = GetClientLeaderSlot(client);
	GetLeaderCodename(slot, codename, sizeof(codename));

	for (int i = 0; i < 4; i++)
		RemoveMarker(client, i);

	RemoveSpriteFollow(client);
	RemoveSpriteCodeName(client);

	if (g_cvNeonLeader.BoolValue)
		RemovePlayerNeon(client);

	if (g_cvGlowLeader.BoolValue) {
		SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		g_iGlowColor[client][0] = 255;
		g_iGlowColor[client][1] = 255;
		g_iGlowColor[client][2] = 255;
		ToolsSetEntityColor(client, g_iGlowColor[client][0], g_iGlowColor[client][1], g_iGlowColor[client][2]);
	}

	if (g_bTrailActive[client])
		KillTrail(client);

	if (g_bBeaconActive[client]) {
		ToggleBeacon(client);
		KillBeacon(client);
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;
			
		if (GetClientFromSerial(g_iClientVoteWhom[i]) == client)
			g_iClientVoteWhom[i] = -1;
	}

	Call_StartForward(g_hRemoveClientLeaderForward);
	Call_PushCell(client);
	Call_Finish();

	if (announce) {
		for (int i = 1; i < MaxClients; i++) {
			if (!IsClientInGame(i))
				continue;
				
			SetGlobalTransTarget(i);

			switch (reason) {
				case R_DISCONNECTED: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Disconnected", codename, client);
				}
				case R_ADMINFORCED: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Admin Force", codename, client);
				}
				case R_SELFRESIGN: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Self Resign", codename, client);
				}
				case R_SPECTATOR: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Spectator", codename, client);
				}
				case R_DIED: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Died", codename, client);
				}
				case R_INFECTED: {
					CPrintToChat(i, "%t %t", "Prefix", "Remove Infected", codename, client);
				}
			}
		}
	}

	g_bClientLeader[client] = false;
	g_iCurrentLeader[g_iClientLeaderSlot[client]] = -1;
	g_iClientLeaderSlot[client] = -1;
	g_iClientGetVoted[client] = 0;
	g_iClientSprite[client] = -1;
	g_bBeaconActive[client] = false;
	g_bTrailActive[client] = false;
}

/* =========================================================================
||  QuickCommand
============================================================================ */
// +lookatweapon exist only on CS:GO
public Action QuickLeaderMenuCommand(int client, const char[] command, int argc) {
	if (IsClientLeader(client))
		QuickLeaderCommand(client);

	return Plugin_Continue;
}

// -lookatweapon exist only on CS:GO
public Action QuickMarkerMenuCommand(int client, const char[] command, int argc) {
	if (IsClientLeader(client))
		QuickMarkerCommand(client);

	return Plugin_Continue;
}

// Flashlight : Marker Menu
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse) {
	if (IsValidClient(client) && IsPlayerAlive(client) && IsClientLeader(client)) {
		if (impulse == 0x64) {
			QuickMarkerCommand(client);
			return Plugin_Changed;
		}
		if (impulse == 0xC9) {
			QuickLeaderCommand(client);
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

// Spray : Leader Menu shortcut
public Action HookDecal(const char[] sTEName, const int[] iClients, int iNumClients, float fSendDelay) {
	int client = TE_ReadNum("m_nPlayer");
	RequestFrame(QuickLeaderCommand, client);
	return Plugin_Continue;
}

stock void QuickMarkerCommand(int client) {
	if (g_bShorcut[client]) {
		g_iButtonMarkerCount[client]++;
		CreateTimer(1.0, ResetMarkerButtonPressed, client);
	}

	if (g_iButtonMarkerCount[client] >= 2 && IsClientLeader(client))
		MarkerMenu(client);
}

stock void QuickLeaderCommand(int client) {
	if (g_bShorcut[client]) {
		g_iButtonLeaderCount[client]++;
		CreateTimer(1.0, ResetLeaderButtonPressed, client);
	}

	if (g_iButtonLeaderCount[client] >= 2 && IsClientLeader(client))
		LeaderMenu(client);
}

public Action ResetLeaderButtonPressed(Handle timer, any client) {
	g_iButtonLeaderCount[client] = 0;
	return Plugin_Handled;
}

public Action ResetMarkerButtonPressed(Handle timer, any client) {
	g_iButtonMarkerCount[client] = 0;
	return Plugin_Handled;
}

/* =========================================================================
||  VIP
============================================================================ */
stock bool IsClientVIP(int client) {
	if (!g_cvEnableVIP.BoolValue)
		return false;

	if (!vipcore)
		return false;

	char group[64];
	bool vip = VIP_GetClientVIPGroup(client, group, 64);

	if (!vip)
		return false;

	if ((strcmp(group, "Mapper", false) == 0) || (strcmp(group, "Retired Staff", false) == 0) || (strcmp(group, "Event Winner", false) == 0))
		return true;
	else
		return false;
}

/* =========================================================================
||  API
============================================================================ */
public int Native_SetLeader(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);

	SetClientLeader(client, -1, slot);
	return 0;
}

public int Native_IsClientLeader(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);
	return IsClientLeader(client);
}

public int Native_RemoveLeader(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);
	ResignReason reason = view_as<ResignReason>(GetNativeCell(2));
	bool announce = view_as<bool>(GetNativeCell(3));

	if (!IsClientLeader(client))
		return ThrowNativeError(1, "The client %N is not the leader", client);

	RemoveLeader(client, reason, announce);
	return 0;
}

public int Native_GetClientLeaderSlot(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);

	if (!IsClientLeader(client)) {
		ThrowNativeError(1, "The client %N is not the leader", client);
		return -1;
	}

	return GetClientLeaderSlot(client);
}

public int Native_IsLeaderSlotFree(Handle hPlugins, int numParams) {
	int slot = GetNativeCell(1);
	return IsLeaderSlotFree(slot);
}

public int Native_IsPossibleLeader(Handle hPlugins, int numParams) {
	int client = GetNativeCell(1);
	return IsPossibleLeader(client);
}

stock int GetLeaderIndexWithLeaderSlot(int slot) {
	for(int i = 0; i < TotalLeader; i++) {
		if (g_LeaderData[i].L_Slot == slot)
			return i;
	}
	return -1;
}

stock int GetLeaderCodename(int slot, char[] buffer, int maxlen) {
	for(int i = 0; i < TotalLeader; i++) {
		if (g_LeaderData[i].L_Slot == slot) {
			Format(buffer, maxlen, "%s", g_LeaderData[i].L_Codename);
			return 1;
		}
	}
	return -1;
}

stock int GetLeaderFreeSlot() {
	for (int i = 0; i < TotalLeader; i++) {
		if (IsLeaderSlotFree(i))
			return i;
	}
	return -1;
}

stock int GetClientLeaderSlot(int client) {
	return g_iClientLeaderSlot[client];
}

stock bool IsClientLeader(int client) {
	return g_bClientLeader[client];
}

stock bool IsLeaderSlotFree(int slot) {
	if (g_iCurrentLeader[slot] == -1)
		return true;

	return false;
}

stock bool IsClientAdmin(int client) {
	return CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN, true);
}

stock bool IsPossibleLeader(int client) {
	for (int i = 0; i <= (MAXPOSSIBLELEADERS - 1); i++) {
		if (IsClientAdmin(client))
			return true;

		if (IsClientVIP(client))
			return true;

		if (strcmp(g_sSteamIDs2[client], g_sLeaderAuth[i], false) == 0)
			return true;
	}
	return false;
}

stock bool IsLeaderOnline() {
	for (int i = 1; i <= (MAXPOSSIBLELEADERS); i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && IsPossibleLeader(i))
			return true;
	}
	return false;
}

stock bool IsValidHex(char[] arg) {
	if (SimpleRegexMatch(arg, "^(#?)([A-Fa-f0-9]{6})$") == 0)
		return false;
	return true;
}

/* =========================================================================
||  Filters
============================================================================ */
public bool Filter_Leaders(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && (IsPossibleLeader(i) || g_iCurrentLeader[i]))
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_NotLeaders(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && !IsPossibleLeader(i) && !g_iCurrentLeader[i])
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_Leader(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && g_iCurrentLeader[i])
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_NotLeader(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && !g_iCurrentLeader[i])
			PushArrayCell(hClients, i);
	}
	return true;
}

/* =========================================================================
||  Leaders.ini Access
============================================================================ */
stock void UpdateLeaders() {
	char g_sDataFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, g_sDataFile, sizeof(g_sDataFile), "configs/zleader/leaders.ini");
	for (int i = 0; i <= (MAXPOSSIBLELEADERS - 1); i++)
		g_sLeaderAuth[i] = "\0";

	File fFile = OpenFile(g_sDataFile, "rt");
	if (!fFile) {
		LogError("Access via Leader.ini will not work. Could not read from: %s", g_sDataFile);
		return;
	}

	char sAuth[MAX_AUTHID_LENGTH];
	int iIndex = 0;

	while (!fFile.EndOfFile()) {
		char line[512];
		if (!fFile.ReadLine(line, sizeof(line)))
			break;

		/* Trim comments */
		int len = strlen(line);
		bool ignoring = false;
		for (int i=0; i<len; i++) {
			if (ignoring) {
				if (line[i] == '"')
					ignoring = false;
			} else {
				if (line[i] == '"') {
					ignoring = true;
				} else if (line[i] == ';') {
					line[i] = '\0';
					break;
				} else if (line[i] == '/' && i != len - 1 && line[i+1] == '/') {
					line[i] = '\0';
					break;
				}
			}
		}

		TrimString(line);

		if ((line[0] == '/' && line[1] == '/') || (line[0] == ';' || line[0] == '\0'))
			continue;

		sAuth = "";
		BreakString(line, sAuth, sizeof(sAuth));
		g_sLeaderAuth[iIndex] = sAuth;
		iIndex ++;
	}
	fFile.Close();
}

/* =========================================================================
||  Safe solution to delete entity
============================================================================ */
public int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname) {
	int Wildcard = FindCharInString(sTargetname, '*');
	char sTargetnameBuf[64];

	while((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE) {
		if (GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
			continue;

		if (strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
			return entity;
	}
	return INVALID_ENT_REFERENCE;
}

/* =========================================================================
||  Glow & Rainbow Leader
============================================================================ */
public void OnPostThinkPost(int client) {
	float i = GetGameTime();
	float Frequency = 2.0;

	int Red   = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	int Green = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	int Blue  = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);

	ToolsSetEntityColor(client, Red, Green, Blue);
}

stock void ToolsGetEntityColor(int entity, int aColor[4]) {
	static bool s_GotConfig = false;
	static char s_sProp[32];

	if (!s_GotConfig) {
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", s_sProp, sizeof(s_sProp));
		CloseHandle(GameConf);

		if (!Exists)
			strcopy(s_sProp, sizeof(s_sProp), "m_clrRender");

		s_GotConfig = true;
	}

	int Offset = GetEntSendPropOffs(entity, s_sProp);

	for (int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, Offset + i, 1);
}

stock void ToolsSetEntityColor(int client, int Red, int Green, int Blue) {
	int aColor[4];
	ToolsGetEntityColor(client, aColor);

	SetEntityRenderColor(client, Red, Green, Blue, aColor[3]);
}

public void ResignConfirmMenu(int client) {
	Menu menu = new Menu(ResignConfirmMenuHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T ?", "Resign from Leader", client);

	char no[64], yes[64];
	Format(no, 64, "%T", "No", client);
	Format(yes, 64, "%T", "Yes", client);

	menu.AddItem("canceled", no);
	menu.AddItem("confirmed", yes);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ResignConfirmMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (IsValidClient(param1) && IsClientLeader(param1)) {
		switch (action) {
			case MenuAction_DisplayItem: {
				char info[64];
				char display[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "canceled", false) == 0) {
					Format(display, sizeof(display), "%T", "No", param1);
					return RedrawMenuItem(display);
				} else if (strcmp(info, "confirmed", false) == 0) {
					Format(display, sizeof(display), "%T", "Yes", param1);
					return RedrawMenuItem(display);
				}
			}
			case MenuAction_Select: {
				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "confirmed", false) == 0) {
					RemoveLeader(param1, R_SELFRESIGN, true);
				} else if (strcmp(info, "canceled", false) == 0) {
					LeaderMenu(param1);
				}
			}
			case MenuAction_Cancel: {
				LeaderMenu(param1);
			}
			case MenuAction_End: {
				delete menu;
			}
		}
	}
	return 0;
}
