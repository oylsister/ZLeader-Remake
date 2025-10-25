#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <regex>
#include <clientprefs>
#include <multicolors>
#include <zombiereloaded>
#include <zleader>
#include "utilshelper.inc"

#undef REQUIRE_PLUGIN
#tryinclude <vip_core>
#tryinclude <ccc>
#tryinclude <basecomm>
#tryinclude <sourcecomms>
#tryinclude <mapchooser_extended>
#define REQUIRE_PLUGIN

#pragma newdecls required

ConVar g_cvGlowLeader,
	g_cvNeonLeader,
	g_cvTrailPosition,
	g_cvEnableVIP,
	g_cvCooldown,
	g_cvMarkerNumber,
	g_cvMarkerTime,
	g_cvRemoveNomOnMute;

int g_Serial_Beacon = 0,
	g_Serial_Ping = 0,
	g_BeamSprite = -1,
	g_HaloSprite = -1,
	g_iPingCooldown,
	g_iMaximumMarker,
	g_iMarkerPos[MAXPLAYERS + 1],
	g_iSpriteFollow[MAXPLAYERS + 1],
	g_iSpriteLeader[MAXPLAYERS + 1],
	g_iNeonEntities[MAX_INDEX][MAXPLAYERS + 1],
	g_iMarkerEntities[MAX_INDEX][MAXPLAYERS + 1],
	g_iMarkerInUse[MAXPLAYERS + 1],
	g_iClientGetVoted[MAXPLAYERS + 1],
	g_iClientVoteWhom[MAXPLAYERS + 1],
	g_iClientMarker[MAX_INDEX][MAXPLAYERS + 1],
	g_iClientLeaderSlot[MAXPLAYERS + 1],
	g_TrailModel[MAXPLAYERS + 1] = { 0, ... },
	g_BeaconSerial[MAXPLAYERS + 1] = {0, ... },
	g_PingSerial[MAXPLAYERS + 1] = {0, ... },
	g_iClientSprite[MAXPLAYERS + 1] = {-1, ...},
	g_iClientNextVote[MAXPLAYERS + 1] = { -1, ... },
	g_iButtonLeaderCount[MAXPLAYERS + 1] = {0, ... },
	g_iButtonMarkerCount[MAXPLAYERS + 1] = {0, ... },
	g_iButtonPingCount[MAXPLAYERS + 1] = {0, ... },
	g_iCooldownBeamPing[MAXPLAYERS + 1] = {0, ... },
	g_iCurrentLeader[MAXLEADER] = {-1, -1, -1};

bool g_bLate,
	g_bPlugin_ccc,
	g_bPlugin_vipcore,
	g_Plugin_BaseComm,
	g_bPlugin_SourceCommsPP,
	g_bPlugin_MCE,
	g_bNeonLeader,
	g_bGlowLeader,
	g_bVIPGroups,
	g_bShorcut[MAXPLAYERS + 1],
	g_bPingSound[MAXPLAYERS + 1],
	g_bClientLeader[MAXPLAYERS + 1],
	g_bTrailActive[MAXPLAYERS + 1] = { false, ... },
	g_bBeaconActive[MAXPLAYERS + 1] = { false, ... },
	g_bPingBeamActive[MAXPLAYERS + 1] = { false, ... },
	g_bSuicideSpectate[MAXPLAYERS + 1] = { false, ... },
	g_bResignedByAdmin[MAXPLAYERS + 1] = { false, ... };

char g_sTrailPosition[64],
	g_sColorName[MAXPLAYERS + 1][MAX_NAME_LENGTH],
	g_sColorChat[MAXPLAYERS + 1][64],
	g_sLeaderAuth[MAXPOSSIBLELEADERS][MAX_AUTHID_LENGTH],
	g_sSteamIDs2[MAXPLAYERS+1][MAX_AUTHID_LENGTH],
	g_sSteamIDs64[MAXPLAYERS+1][MAX_AUTHID_LENGTH];

char g_sMarkerTypes[MK_TOTAL][32] = { "MK_NORMAL", "MK_DEFEND", "MK_ZMTP", "MK_NOHUG", "MK_PING" };
char g_sEntityTypes[ENTITIES_PER_MK][32] = { "prop_dynamic", "light_dynamic", "env_sprite" };

float g_fPos[3],
	g_fMarkerTime; 

Handle g_hZLeaderSettings = INVALID_HANDLE,
	g_hSetClientLeaderForward = INVALID_HANDLE,
	g_hRemoveClientLeaderForward = INVALID_HANDLE;

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

	char L_MarkerPing_VMT[PLATFORM_MAX_PATH];
	char L_MarkerPing_VTF[PLATFORM_MAX_PATH];
	int L_iColorPing[4]; 
	char L_MarkerPing_Sound[PLATFORM_MAX_PATH];
}

LeaderData g_LeaderData[MAXLEADER];

int g_iTotalLeader;

public Plugin myinfo = {
	name = "ZLeader Remake",
	author = "Original by AntiTeal, nuclear silo, CNTT, colia || Remake by Oylsister, .Rushaway",
	description = "Allows for a human to be a leader, and give them special functions with it.",
	version = ZLeader_VERSION,
	url = "https://github.com/oylsister/ZLeader-Remake"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLate = late;
	CreateNative("ZL_SetLeader", Native_SetLeader);
	CreateNative("ZL_IsClientLeader", Native_IsClientLeader);
	CreateNative("ZL_RemoveLeader", Native_RemoveLeader);
	CreateNative("ZL_GetClientLeaderSlot", Native_GetClientLeaderSlot);
	CreateNative("ZL_IsLeaderSlotFree", Native_IsLeaderSlotFree);
	CreateNative("ZL_IsPossibleLeader", Native_IsPossibleLeader);

	g_hSetClientLeaderForward = CreateGlobalForward("Leader_SetClientLeader", ET_Ignore, Param_Cell, Param_String);
	g_hRemoveClientLeaderForward = CreateGlobalForward("Leader_RemoveClientLeader", ET_Ignore, Param_Cell, Param_Cell);

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

	/* MARKER COMMANDS TO CREATE BINDS */
	RegConsoleCmd("sm_arrow", Command_Arrow, "Arrow a location");
	RegConsoleCmd("sm_defend", Command_Defend, "Defend a location");
	RegConsoleCmd("sm_zmtp", Command_ZMTP, "ZM Teleport a location");
	RegConsoleCmd("sm_nodoorhug", Command_NoDoorHug, "No Doorhug a location");
	RegConsoleCmd("sm_ping", Command_Ping, "Ping a location");
	RegConsoleCmd("sm_removemarker", Command_RemoveMarkers, "Remove all markers");

	/* ADMINS COMMANDS */
	RegAdminCmd("sm_removeleader", Command_RemoveLeader, ADMFLAG_KICK, "Revome a current leader");
	RegAdminCmd("sm_reloadleaders", Command_ReloadLeaders, ADMFLAG_BAN, "Reload access for leader.ini");

	/* CONVARS */
	g_cvNeonLeader = CreateConVar("sm_zleader_neon", "1", "Put a neon light parented to the leader", _, true, 0.0, true, 1.0);
	g_cvGlowLeader = CreateConVar("sm_zleader_glow", "1", "Put a glow colors effect on the leader", _, true, 0.0, true, 1.0);
	g_cvTrailPosition = CreateConVar("sm_zleader_trail_position", "0.0 0.0 10.0", "The trail position (X Y Z)");
	g_cvEnableVIP = CreateConVar("sm_zleader_vip", "0", "VIP groups can be leader?", _, true, 0.0, true, 1.0);
	g_cvCooldown = CreateConVar("sm_zleader_cooldown", "4", "Cooldown in seconds for ping beam");
	g_cvMarkerNumber = CreateConVar("sm_zleader_marker_number", "0", "Max markers per player [0 or lower: One marker of each type max | 1 or higher: Max markers in total]", _, true, 0.0, true, view_as<float>(MAX_MARKERS));
	g_cvMarkerTime = CreateConVar("sm_zleader_marker_time", "15", "Time to remove marker in seconds", _, true, 1.0);
	g_cvRemoveNomOnMute = CreateConVar("sm_zleader_remove_nominate_onmute", "1", "Remove a player's nomination when they are muted", 0, true, 0.0, true, 1.0);

	AutoExecConfig(true);

	/* HOOK CVARS */
	HookConVarChange(g_cvNeonLeader, OnConVarChanged);
	HookConVarChange(g_cvGlowLeader, OnConVarChanged);
	HookConVarChange(g_cvTrailPosition, OnConVarChanged);
	HookConVarChange(g_cvEnableVIP, OnConVarChanged);
	HookConVarChange(g_cvCooldown, OnConVarChanged);
	HookConVarChange(g_cvMarkerNumber, OnConVarChanged);
	HookConVarChange(g_cvMarkerTime, OnConVarChanged);
	
	/* INITIALIZE VALUES */
	g_bNeonLeader = GetConVarBool(g_cvNeonLeader);
	g_bGlowLeader = GetConVarBool(g_cvGlowLeader);
	GetConVarString(g_cvTrailPosition, g_sTrailPosition, sizeof(g_sTrailPosition));
	g_bVIPGroups = GetConVarBool(g_cvEnableVIP);
	g_iPingCooldown = GetConVarInt(g_cvCooldown);
	g_iMaximumMarker = GetConVarInt(g_cvMarkerNumber);
	g_fMarkerTime = GetConVarFloat(g_cvMarkerTime);

	if (g_iMaximumMarker > MAX_MARKERS)
		g_iMaximumMarker = MAX_MARKERS;

	AddCommandListener(HookPlayerChat, "say");
	AddCommandListener(HookPlayerChatTeam, "say_team");
	AddCommandListener(QuickLeaderMenuCommand, "+lookatweapon");
	AddCommandListener(QuickMarkerMenuCommand, "-lookatweapon");

	/* HOOK EVENTS & RADIO */
	AddTempEntHook("Player Decal", HookDecal);
	HookEvent("player_team", OnPlayerTeam, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("round_start", OnRoundStart);
	HookRadio();

	/* COOKIES */
	SetCookieMenuItem(ZLeaderCookieHandler, 0, "ZLeader Settings");
	g_hZLeaderSettings = RegClientCookie("zleader_settings", "ZLeader Settings", CookieAccess_Protected);

	/* ADD FILTERS */
	AddMultiTargetFilter("@leaders", Filter_Leaders, "Possible Leaders", false);
	AddMultiTargetFilter("@!leaders", Filter_NotLeaders, "Everyone but Possible Leaders", false);
	AddMultiTargetFilter("@leader", Filter_Leader, "Current Leader", false);
	AddMultiTargetFilter("@!leader", Filter_NotLeader, "Every one but the Current Leader", false);

	if (!g_bLate)
		return;

	/* Late load */
	char sSteam32ID[32];
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Steam2, sSteam32ID, sizeof(sSteam32ID)))
			OnClientAuthorized(i, sSteam32ID);
	}

	g_bLate = false;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (convar == g_cvNeonLeader)
		g_bNeonLeader = GetConVarBool(g_cvNeonLeader);
	else if (convar == g_cvGlowLeader)
		g_bGlowLeader = GetConVarBool(g_cvGlowLeader);
	else if (convar == g_cvTrailPosition)
		GetConVarString(g_cvTrailPosition, g_sTrailPosition, sizeof(g_sTrailPosition));
	else if (convar == g_cvEnableVIP)
		g_bVIPGroups = GetConVarBool(g_cvEnableVIP);
	else if (convar == g_cvCooldown)
		g_iPingCooldown = GetConVarInt(g_cvCooldown);
	else if (convar == g_cvMarkerNumber)
		g_iMaximumMarker = GetConVarInt(g_cvMarkerNumber);
	else if (convar == g_cvMarkerTime)
		g_fMarkerTime = GetConVarFloat(g_cvMarkerTime);

	if (g_iMaximumMarker > MAX_MARKERS)
		g_iMaximumMarker = MAX_MARKERS;
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
		g_iTotalLeader = 0;

		do {
			KvGetString(kv, "codename", g_LeaderData[g_iTotalLeader].L_Codename, 48);

			g_LeaderData[g_iTotalLeader].L_Slot = KvGetNum(kv, "leader_slot", -1);

			KvGetString(kv, "codename_vmt", g_LeaderData[g_iTotalLeader].L_CodeNameVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "codename_vtf", g_LeaderData[g_iTotalLeader].L_CodeNameVTF, PLATFORM_MAX_PATH);

			KvGetString(kv, "trail_vmt", g_LeaderData[g_iTotalLeader].L_TrailVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "trail_vtf", g_LeaderData[g_iTotalLeader].L_TrailVTF, PLATFORM_MAX_PATH);
			
			KvGetString(kv, "follow_vmt", g_LeaderData[g_iTotalLeader].L_FollowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "follow_vtf", g_LeaderData[g_iTotalLeader].L_FollowVTF, PLATFORM_MAX_PATH);

			KvGetString(kv, "marker_mdl", g_LeaderData[g_iTotalLeader].L_MarkerMDL, PLATFORM_MAX_PATH);
			KvGetString(kv, "marker_vmt", g_LeaderData[g_iTotalLeader].L_MarkerVMT, PLATFORM_MAX_PATH);

			KvGetString(kv, "arrow_vmt", g_LeaderData[g_iTotalLeader].L_MarkerArrowVMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "arrow_vtf", g_LeaderData[g_iTotalLeader].L_MarkerArrowVTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "arrow_color", g_LeaderData[g_iTotalLeader].L_iColorArrow[0], g_LeaderData[g_iTotalLeader].L_iColorArrow[1], g_LeaderData[g_iTotalLeader].L_iColorArrow[2], g_LeaderData[g_iTotalLeader].L_iColorArrow[3]);

			KvGetString(kv, "defend_vmt", g_LeaderData[g_iTotalLeader].L_MarkerDefend_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "defend_vtf", g_LeaderData[g_iTotalLeader].L_MarkerDefend_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "defend_color", g_LeaderData[g_iTotalLeader].L_iColorDefend[0], g_LeaderData[g_iTotalLeader].L_iColorDefend[1], g_LeaderData[g_iTotalLeader].L_iColorDefend[2], g_LeaderData[g_iTotalLeader].L_iColorDefend[3]);

			KvGetString(kv, "zmtp_vmt", g_LeaderData[g_iTotalLeader].L_MarkerZMTP_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "zmtp_vtf", g_LeaderData[g_iTotalLeader].L_MarkerZMTP_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "zmtp_color", g_LeaderData[g_iTotalLeader].L_iColorZMTP[0], g_LeaderData[g_iTotalLeader].L_iColorZMTP[1], g_LeaderData[g_iTotalLeader].L_iColorZMTP[2], g_LeaderData[g_iTotalLeader].L_iColorZMTP[3]);

			KvGetString(kv, "nodoorhug_vmt", g_LeaderData[g_iTotalLeader].L_MarkerNOHUG_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "nodoorhug_vtf", g_LeaderData[g_iTotalLeader].L_MarkerNOHUG_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "nodoorhug_color", g_LeaderData[g_iTotalLeader].L_iColorNOHUG[0], g_LeaderData[g_iTotalLeader].L_iColorNOHUG[1], g_LeaderData[g_iTotalLeader].L_iColorNOHUG[2], g_LeaderData[g_iTotalLeader].L_iColorNOHUG[3]);

			KvGetString(kv, "ping_vmt", g_LeaderData[g_iTotalLeader].L_MarkerPing_VMT, PLATFORM_MAX_PATH);
			KvGetString(kv, "ping_vtf", g_LeaderData[g_iTotalLeader].L_MarkerPing_VTF, PLATFORM_MAX_PATH);
			KvGetColor(kv, "ping_color", g_LeaderData[g_iTotalLeader].L_iColorPing[0], g_LeaderData[g_iTotalLeader].L_iColorPing[1], g_LeaderData[g_iTotalLeader].L_iColorPing[2], g_LeaderData[g_iTotalLeader].L_iColorPing[3]);
			KvGetString(kv, "ping_sound", g_LeaderData[g_iTotalLeader].L_MarkerPing_Sound, PLATFORM_MAX_PATH);
			
			g_iTotalLeader++;
		}
		while(KvGotoNextKey(kv));
	}

	delete kv;
}

void LoadDownloadTable() {
	char spath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, spath, sizeof(spath), "configs/zleader/downloads.txt");

	if (!FileExists(spath)) {
		SetFailState("Couldn't find config file: %s", spath);
		return;
	}

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
	for(int i = 0; i < g_iTotalLeader; i++) {
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

		if (g_LeaderData[i].L_MarkerPing_VMT[0] != '\0')
			PrecacheGeneric(g_LeaderData[i].L_MarkerPing_VMT, true);

		if (g_LeaderData[i].L_MarkerPing_Sound[0] != '\0')
			PrecacheSound(g_LeaderData[i].L_MarkerPing_Sound, true);
	}
}

/* =========================================================================
||  REMOVE ALL FILTERS / COMMAND LISTENER / CLOSE ALL HANDLES
============================================================================ */
public void OnPluginEnd() {
	RemoveMultiTargetFilter("@leaders", Filter_Leaders);
	RemoveMultiTargetFilter("@!leaders", Filter_NotLeaders);
	RemoveMultiTargetFilter("@leader", Filter_Leader);
	RemoveMultiTargetFilter("@!leader", Filter_NotLeader);

	RemoveCommandListener(HookPlayerChat, "say");
	RemoveCommandListener(HookPlayerChatTeam, "say_team");
	RemoveCommandListener(QuickLeaderMenuCommand, "+lookatweapon");
	RemoveCommandListener(QuickMarkerMenuCommand, "-lookatweapon");

	CloseHandle(g_hZLeaderSettings);
	CloseHandle(g_hSetClientLeaderForward);
	CloseHandle(g_hRemoveClientLeaderForward);
}

/* =========================================================================
||  EXTERNAL PLUGINS
============================================================================ */
public void OnAllPluginsLoaded() {
	g_bPlugin_vipcore = LibraryExists("vip_core");
	g_bPlugin_ccc = LibraryExists("ccc");
	g_Plugin_BaseComm = LibraryExists("basecomm");
	g_bPlugin_SourceCommsPP = LibraryExists("sourcecomms++");
	g_bPlugin_MCE = LibraryExists("mapchooser");
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "vip_core", false) == 0)
		g_bPlugin_vipcore = false;

	else if (strcmp(name, "ccc", false) == 0)
		g_bPlugin_ccc = false;

	else if (strcmp(name, "basecomm", false) == 0)
		g_Plugin_BaseComm = false;

	else if (strcmp(name, "sourcecomms++", false) == 0)
		g_bPlugin_SourceCommsPP = false;

	else if (strcmp(name, "mapchooser", false) == 0)
		g_bPlugin_MCE = false;
}

public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "vip_core", false) == 0)
		g_bPlugin_vipcore = true;

	else if (strcmp(name, "ccc", false) == 0)
		g_bPlugin_ccc = true;

	else if (strcmp(name, "basecomm", false) == 0)
		g_Plugin_BaseComm = true;

	else if (strcmp(name, "sourcecomms++", false) == 0)
		g_bPlugin_SourceCommsPP = true;

	else if (strcmp(name, "mapchooser", false) == 0)
		g_bPlugin_MCE = true;
}

/* =========================================================================
||  INITIAL SETUP (Cache, dl table, load cfg..)
============================================================================ */
public void OnMapStart() {
	Reset_AllLeaders();
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
public void OnClientAuthorized(int client, const char[] auth) {

	if (IsFakeClient(client))
		return;

	Reset_PlayerState(client);

	if (AreClientCookiesCached(client))
		ReadClientCookies(client);

	// Store the SteamID2 and SteamID64
	FormatEx(g_sSteamIDs2[client], sizeof(g_sSteamIDs2[]), "%s", auth);

	char sSteamID64[64];
	GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64), false);
	FormatEx(g_sSteamIDs64[client], sizeof(g_sSteamIDs64[]), "%s", sSteamID64);

}

public void OnClientCookiesCached(int client) {
	ReadClientCookies(client);
}

void ParseClientCookie(int client, bool &shortcut, bool &pingSound, int &markerPos) {
	char buffer[64];
	GetClientCookie(client, g_hZLeaderSettings, buffer, sizeof(buffer));

	// Parse chain format: shortcut|pingsound|markerpos
	if (buffer[0] != '\0') {
		char parts[3][16];
		int count = ExplodeString(buffer, "|", parts, 3, sizeof(parts[]));
		
		if (count >= 1) {
			shortcut = view_as<bool>(StringToInt(parts[0]));
		}
		if (count >= 2) {
			pingSound = view_as<bool>(StringToInt(parts[1]));
		}
		if (count >= 3) {
			markerPos = StringToInt(parts[2]);
		}
	}
	else {
		// Default values
		shortcut = true;
		pingSound = true;
		markerPos = MK_TYPE_CROSSHAIR;
	}
}

public void ReadClientCookies(int client) {
	bool shortcut, pingSound;
	int markerPos;

	ParseClientCookie(client, shortcut, pingSound, markerPos);

	g_bShorcut[client] = shortcut;
	g_bPingSound[client] = pingSound;
	g_iMarkerPos[client] = markerPos;
}

public void SetClientCookies(int client) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	// Read current cookie values
	bool currentShortcut, currentPingSound;
	int currentMarkerPos;
	ParseClientCookie(client, currentShortcut, currentPingSound, currentMarkerPos);

	// Check if values have changed
	bool shortcutChanged = g_bShorcut[client] != currentShortcut;
	bool pingSoundChanged = g_bPingSound[client] != currentPingSound;
	bool markerPosChanged = g_iMarkerPos[client] != currentMarkerPos;

	// If no values have changed, no need to save
	if (!shortcutChanged && !pingSoundChanged && !markerPosChanged) {
		return;
	}

	// Otherwise, save the chain format
	char sValue[64];
	FormatEx(sValue, sizeof(sValue), "%d|%d|%d", 
		g_bShorcut[client] ? 1 : 0,
		g_bPingSound[client] ? 1 : 0,
		g_iMarkerPos[client]);

	SetClientCookie(client, g_hZLeaderSettings, sValue);
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
	FormatEx(shortcut, 64, "%T", "Shortcut", client);
	FormatEx(markerpos, 64, "%T", "Marker Pos", client);

	menu.AddItem("shortcut", shortcut);
	menu.AddItem("markerpos", markerpos);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int ZLeaderSettingHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_DisplayItem: {
			char info[64], display[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0) {
				FormatEx(display, sizeof(display), "%T : %T", "Shortcut", param1, g_bShorcut[param1] ? "Enabled" : "Disabled", param1);
				return RedrawMenuItem(display);
			} else if (strcmp(info, "markerpos", false) == 0) {

				char thepos[64];
				FormatEx(thepos, sizeof(thepos), "%T", g_iMarkerPos[param1] == MK_TYPE_CLIENT ? "Client Position" : "Client Crosshair", param1);
				FormatEx(display, sizeof(display), "%T : %s", "Marker Pos", param1, thepos);
				return RedrawMenuItem(display);
			}
		}
		case MenuAction_Select: {
			char info[64];
			menu.GetItem(param2, info, sizeof(info));
			if (strcmp(info, "shortcut", false) == 0) {
				char status[32];
				g_bShorcut[param1] = !g_bShorcut[param1];
				FormatEx(status, 64, "%T", g_bShorcut[param1] ? "Enabled Chat" : "Disabled Chat", param1);
				CPrintToChat(param1, "%T %T", "Prefix", param1, "You set shortcut", param1, status);
				SetClientCookies(param1);
			} else if (strcmp(info, "markerpos", false) == 0) {
				g_iMarkerPos[param1] = (g_iMarkerPos[param1] == MK_TYPE_CLIENT) ? MK_TYPE_CROSSHAIR : MK_TYPE_CLIENT;
				CPrintToChat(param1, "%T %T", "Prefix", param1, (g_iMarkerPos[param1] == MK_TYPE_CLIENT) ? "Marker Pos Player Position" : "Marker Pos Crosshair", param1);
				SetClientCookies(param1);
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

	Reset_PlayerState(client);

	FormatEx(g_sSteamIDs2[client], sizeof(g_sSteamIDs2[]), "");
	FormatEx(g_sSteamIDs64[client], sizeof(g_sSteamIDs64[]), "");
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int iUserID = event.GetInt("userid");
	int client = GetClientOfUserId(iUserID);
	// We need to perform OnPlayerTeam after OnPlayerDeath, to check if leader moved to spec
	if (IsClientLeader(client))
		CreateTimer(0.2, Timer_OnTeamChange, iUserID, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int iUserID = event.GetInt("userid");
	int client = GetClientOfUserId(iUserID);
	if (IsClientLeader(client))
		CreateTimer(0.1, Timer_OnDeath, iUserID, TIMER_FLAG_NO_MAPCHANGE);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherinfect, bool override, bool respawn) {
	if (IsClientLeader(client))
		RemoveLeader(client, R_INFECTED, true);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	// We create timer for don't insta remove leader (usefull for API)
	CreateTimer(0.3, Timer_RoundEndClean, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
	KillAllBeacons();
	KillAllPingsBeam();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	Reset_AllLeaders();
	EnsureLeaderConsistency();
}

public Action Timer_RoundEndClean(Handle timer) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i))
			Reset_ClientNextVote(i);
		if (IsClientLeader(i))
			RemoveLeader(i, R_SELFRESIGN, false);
	}

	return Plugin_Handled;
}

public Action Timer_OnDeath(Handle timer, int iUserID) {
	int client = GetClientOfUserId(iUserID);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (GetClientTeam(client) <= CS_TEAM_SPECTATOR)
		g_bSuicideSpectate[client] = true;

	if (IsClientLeader(client) && !g_bSuicideSpectate[client])
		RemoveLeader(client, R_DIED, true);

	return Plugin_Continue;
}

public Action Timer_OnTeamChange(Handle timer, int iUserID) {
	int client = GetClientOfUserId(iUserID);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (IsClientLeader(client) && g_bSuicideSpectate[client]) {
		RemoveLeader(client, R_SPECTATOR, true);
		g_bSuicideSpectate[client] = false;
	}

	return Plugin_Continue;
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

		if (g_bResignedByAdmin[client]) {
			CReplyToCommand(client, "%t %t", "Prefix", "Leader was resigned by Admin", client);
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
				if (IsTargetMuted(client) || IsTargetGagged(client)) {
					CReplyToCommand(client, "%T %T", "Prefix", client, "Leader should not be muted", client);
					return Plugin_Stop;
				}

				for (int i = 0; i < g_iTotalLeader; i++) {
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
			if (IsTargetMuted(target) || IsTargetGagged(target)) {
				CReplyToCommand(client, "%T %T", "Prefix", client, "Leader should not be muted", client);
				return Plugin_Handled;
			}

			for (int i = 0; i < g_iTotalLeader; i++) {
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

	if (g_iMaximumMarker < 1) {
		int Defend = g_iClientMarker[MK_DEFEND][client] != -1;
		int Arrow = g_iClientMarker[MK_NORMAL][client] != -1;
		int NoHug = g_iClientMarker[MK_NOHUG][client] != -1;
		int ZMTP = g_iClientMarker[MK_ZMTP][client] != -1;

		if (Arrow || Defend || NoHug || ZMTP) {
			char sds[64];
			if (Arrow)
				FormatEx(sds, sizeof(sds), "%t", "Arrow Marker");
			if (Defend)
				FormatEx(sds, sizeof(sds), "%t", "Defend Here");
			if (NoHug)
				FormatEx(sds, sizeof(sds), "%t", "No Doorhug");
			if (ZMTP)
				FormatEx(sds, sizeof(sds), "%t", "ZM Teleport");
			if (Arrow && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "ZM Teleport");
			if (Arrow && Defend) 
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "Defend Here");
			if (Arrow && NoHug) 
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "Arrow Marker", "No Doorhug");
			if (NoHug && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "ZM Teleport", "No Doorhug");
			if (Defend && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "Defend Here", "ZM Teleport");
			if (NoHug && Defend)
				FormatEx(sds, sizeof(sds), "%t\n→ %t", "Defend Here", "No Doorhug");
			if (Arrow && Defend && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Arrow Marker", "Defend Here", "No Doorhug");
			if (Arrow && NoHug && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Arrow Marker", "ZM Teleport", "No Doorhug");
			if (Defend && ZMTP && NoHug)
				FormatEx(sds, sizeof(sds), "%t\n→ %t\n→ %t", "Defend Here", "ZM Teleport", "No Doorhug");
			if (Arrow && Defend && NoHug && ZMTP)
				FormatEx(sds, sizeof(sds), "%t\n→ %t\n→ %t\n→ %t", "Arrow Marker", "Defend Here", "ZM Teleport", "No Doorhug");

			menu.SetTitle("%T \nActive Marker:\n→ %s", "Menu Leader title", client, sds);
		} else
			menu.SetTitle("%T", "Menu Leader title", client);
	} else
		menu.SetTitle("%T", "Menu Leader title", client);

	char follow[64], trail[64], beacon[64], marker[64], removemarker[64], resign[64];

	FormatEx(follow, 64, "%T", "Follow Me", client);
	FormatEx(trail, 64, "%T", "Toggle Trail", client);
	FormatEx(beacon, 64, "%T", "Toggle Beacon", client);
	FormatEx(marker, 64, "%T", "Place Marker", client);
	FormatEx(removemarker, 64, "%T", "Remove Marker", client);
	FormatEx(resign, 64, "%T", "Resign from Leader", client);

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
				char info[64], display[128];
				menu.GetItem(param2, info, sizeof(info));
				if (strcmp(info, "follow", false) == 0 && g_iClientSprite[param1] == SP_FOLLOW) {
					FormatEx(display, sizeof(display), "%T (✘)", "Follow Me", param1);
					return RedrawMenuItem(display);
				} else if (strcmp(info, "trail", false) == 0 && g_bTrailActive[param1]) {
					FormatEx(display, sizeof(display), "%T (✘)", "Toggle Trail", param1);
					return RedrawMenuItem(display);
				} else if (strcmp(info, "beacon", false) == 0 && g_bBeaconActive[param1]) {
					FormatEx(display, sizeof(display), "%T (✘)", "Toggle Beacon", param1);
					return RedrawMenuItem(display);
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
							Reset_ClientSprite(param1);
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
						RemoveAllMarkers(param1);
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
	char aBuf[1024], aBuf2[MAX_NAME_LENGTH];
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
	
	char codename[32], sLine[128];
	for (int i = 0; i < g_iTotalLeader; i++) {
		GetLeaderCodename(i, codename, sizeof(codename));

		if (!IsLeaderSlotFree(i)) {
			CReplyToCommand(client, "{darkred}[{orange}%s{darkred}] {lightblue}%N", codename, g_iCurrentLeader[i]);
			FormatEx(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine, ITEMDRAW_DISABLED);
		} else {
			FormatEx(sLine, 128, "%s: %T", codename, "None", client);
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
	for (int i = 0; i < g_iTotalLeader; i++) {
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

	bool TnIsMl;
	int iTargets[MAXPLAYERS], TargetCount;
	char sArgs[64], sTargetName[MAX_TARGET_LENGTH];
	GetCmdArg(1, sArgs, sizeof(sArgs)); 

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

	if (g_bResignedByAdmin[target]) {
		CReplyToCommand(client, "%t %t", "Prefix", "Leader was resigned by Admin", target);
		return Plugin_Handled;
	}

	if (IsTargetMuted(target) || IsTargetGagged(target)) {
		CReplyToCommand(client, "%T %T", "Prefix", client, "Leader should not be muted", client);
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

	bool TnIsMl;
	int iTargets[MAXPLAYERS], TargetCount;
	char sArgs[64], sTargetName[MAX_TARGET_LENGTH];
	GetCmdArg(1, sArgs, sizeof(sArgs));

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
	FormatEx(title, sizeof(title), "%t %t \n%t", "Menu Prefix", "Menu Leader list title", "Menu Remove Leader title");
	menu.SetTitle("%s", title);
	
	for (int i = 0; i < g_iTotalLeader; i++) {
		char codename[32];
		char sLine[128];

		GetLeaderCodename(i, codename, sizeof(codename));

		if (!IsLeaderSlotFree(i)) {
			FormatEx(sLine, 128, "%s: %N", codename, g_iCurrentLeader[i]);
			menu.AddItem(codename, sLine);
		} else {
			FormatEx(sLine, 128, "%s: %t", codename, "None");
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
			for (int i = 0; i < g_iTotalLeader; i++) {
				if (param2 == i && !IsLeaderSlotFree(i)) {
					LogAction(param1, g_iCurrentLeader[i], "[ZLeader] Leader %N (%s) has been resigned by %N (%s)", g_iCurrentLeader[i], g_sSteamIDs2[g_iCurrentLeader[i]], param1 , g_sSteamIDs2[param1]);
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
	g_bTrailActive[client] = !g_bTrailActive[client];
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
	
	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%T %T", "Prefix", client, "Edicts Limit", client);
		return;
	}

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

		float angles[3], origin[3]; 
		char angle[64][3];

		ExplodeString(g_sTrailPosition, " ", angle, 3, sizeof(angle), false);
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
		AcceptEntityInput(g_TrailModel[client], "Kill");

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
	g_BeaconSerial[client] = ++g_Serial_Beacon;
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Beacon << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void KillBeacon(int client) {
	g_BeaconSerial[client] = 0;

	if (IsClientInGame(client))
		SetEntityRenderColor(client, 255, 255, 255, 255);
}

public void KillAllBeacons() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bBeaconActive[i])
			Reset_ClientBeaconActive(i);

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

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);
	if (slot == -1) {
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
	int iColor[4];
	iColor[0] = g_LeaderData[slot].L_iColorPing[0];
	iColor[1] = g_LeaderData[slot].L_iColorPing[1];
	iColor[2] = g_LeaderData[slot].L_iColorPing[2];
	iColor[3] = g_LeaderData[slot].L_iColorPing[3];
	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 25.0, 0.5, iColor, 10, 0);
	TE_SendToAll();

	return Plugin_Continue;
}

/* =========================================================================
||  Ping Marker
============================================================================ */
public void CreatePing(int client) {
	int cooldownDiff = GetTime() - g_iCooldownBeamPing[client];
	if (cooldownDiff < g_iPingCooldown + 1) {
		CPrintToChat(client, "%t %t", "Prefix", "Cooldown Ping", g_iPingCooldown - cooldownDiff);
		return;
	}

	g_bPingBeamActive[client] = !g_bPingBeamActive[client];
	PerformPingBeam(client);
}

public void KillPingBeam(int client) {
	g_PingSerial[client] = 0;
}

public void KillAllPingsBeam() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_bPingBeamActive[i])
			Reset_ClientPingBeamActive(i);

		KillPingBeam(i);
	}
}

public void PerformPingBeam(int client) {
	if (g_PingSerial[client] == 0)
		CreatePingBeam(client);
	else
		KillPingBeam(client);
}

stock void KillActivePingBeam(int client) {
	if (g_iClientMarker[MK_PING][client] != -1) {
		KillPingBeam(client);
		RemoveMarker(client, MK_PING);
	}
}

public void CreatePingBeam(int client) {
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;

	KillActivePingBeam(client);

	g_iCooldownBeamPing[client] = GetTime();
	g_PingSerial[client] = ++g_Serial_Ping;

	SpawnMarker(client, MK_PING);
	// Allow Ping Beam to don't have CD.
	float RemovePingMarker = g_cvCooldown.FloatValue;
	if (RemovePingMarker > 0)
		CreateTimer(RemovePingMarker, Timer_RemovePingMarker, client, TIMER_FLAG_NO_MAPCHANGE);
	
	CreateTimer(0.3, Timer_PingBeamRing, client | (g_Serial_Ping << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);
	for (int x = 1; x <= MaxClients; x++) {
		if (!IsClientInGame(x) || GetClientTeam(x) != 3)
			continue;
		EmitSoundToClient(x, g_LeaderData[slot].L_MarkerPing_Sound, client, SNDCHAN_AUTO, _, _, 1.0);
	}
}

public Action Timer_RemovePingMarker(Handle timer, any value) {
	int client = value & 0x7f;
	KillActivePingBeam(client);
	return Plugin_Continue;
}

public Action Timer_PingBeamRing(Handle timer, any value) {
	int client = value & 0x7f;
	int serial = value >> 7;

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_PingSerial[client] != serial) {
		KillPingBeam(client);
		return Plugin_Stop;
	}

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);
	if (slot == -1) {
		KillPingBeam(client);
		return Plugin_Stop;
	}

	float vec[3];
	vec[0] = g_fPos[0];
	vec[1] = g_fPos[1];
	vec[2] = g_fPos[2];

	// First ping beam ring
	int greyColor[4] = {128, 128, 128, 255};
	TE_SetupBeamRingPoint(vec, 10.0, 70.0, g_BeamSprite, g_HaloSprite, 0, 20, 0.5, 12.0, 0.0, greyColor, 10, 0);
	TE_SendToAll();

	// Second ping beam ring
	int iColor[4];
	iColor[0] = g_LeaderData[slot].L_iColorPing[0];
	iColor[1] = g_LeaderData[slot].L_iColorPing[1];
	iColor[2] = g_LeaderData[slot].L_iColorPing[2];
	iColor[3] = g_LeaderData[slot].L_iColorPing[3];

	TE_SetupBeamRingPoint(vec, 10.0, 130.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.6, 25.0, 0.5, iColor, 10, 0);
	TE_SendToAll();

	return Plugin_Continue;
}

/* =========================================================================
||  Sprite
============================================================================ */
public void RemoveSpriteFollow(int client) {
	if (g_iSpriteFollow[client] != -1 && IsValidEdict(g_iSpriteFollow[client])) {
		char m_szClassname[64];
		GetEdictClassname(g_iSpriteFollow[client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("env_sprite", m_szClassname) == 0)
			AcceptEntityInput(g_iSpriteFollow[client], "Kill");
	}

	g_iSpriteFollow[client] = -1;
}
public void RemoveSpriteCodeName(int client) {
	if (g_iSpriteLeader[client] != -1 && IsValidEdict(g_iSpriteLeader[client])) {
		char m_szClassname[64];
		GetEdictClassname(g_iSpriteLeader[client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("env_sprite", m_szClassname) == 0)
			AcceptEntityInput(g_iSpriteLeader[client], "Kill");
	}

	g_iSpriteLeader[client] = -1;
}

// https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
public int AttachSprite(int client, char[] sprite, int position) {
	if (!IsPlayerAlive(client))
		return -1;

	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%T %T", "Prefix", client, "Edicts Limit", client);
		return -1;
	}

	char iTarget[16], sTargetname[64];
	// Save original targetname
	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	// Set targetname to client
	FormatEx(iTarget, sizeof(iTarget), "Client%d", client);
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

	// Apply back original targetname
	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

/* =========================================================================
||  Marker
============================================================================ */
public Action Command_Marker(int client, int args) {
	if (IsClientLeader(client)) {
		MarkerMenu(client);
	}

	return Plugin_Handled;
}

public Action Command_Arrow(int client, int args) {
	if (IsClientLeader(client))
		ToggleMarkerState(client, MK_NORMAL);

	return Plugin_Handled;
}

public Action Command_Defend(int client, int args) {
	if (IsClientLeader(client))
		ToggleMarkerState(client, MK_DEFEND);

	return Plugin_Handled;
}

public Action Command_ZMTP(int client, int args) {
	if (IsClientLeader(client))
		ToggleMarkerState(client, MK_ZMTP);

	return Plugin_Handled;
}

public Action Command_NoDoorHug(int client, int args) {
	if (IsClientLeader(client))
		ToggleMarkerState(client, MK_NOHUG);

	return Plugin_Handled;
}

public Action Command_Ping(int client, int args) {
	if (IsClientLeader(client))
		CreatePing(client);
	
	return Plugin_Handled;
}

public Action Command_RemoveMarkers(int client, int args) {
	if (IsClientLeader(client)) 
		RemoveAllMarkers(client);

	return Plugin_Handled;
}

public void MarkerMenu(int client) {
	Menu menu = new Menu(MarkerMenuHandler, MENU_ACTIONS_ALL);

	menu.SetTitle("%T %T", "Menu Prefix", client, "Marker menu title", client);

	char normal[64], defend[64], zmtp[64], nohug[64], ping[64], removemarker[64];

	FormatEx(normal, 64, "%T", "Arrow Marker", client);
	FormatEx(defend, 64, "%T", "Defend Here", client);
	FormatEx(zmtp, 64, "%T", "ZM Teleport", client);
	FormatEx(nohug, 64, "%T", "No Doorhug", client);
	FormatEx(ping, 64, "%T", "Ping Marker", client);
	FormatEx(removemarker, 64, "%T", "Remove Marker", client);

	menu.AddItem("normal", normal);
	menu.AddItem("defend", defend);
	menu.AddItem("zmtp", zmtp);
	menu.AddItem("nohug", nohug);
	menu.AddItem("ping", ping);
	menu.AddItem("removemarker", removemarker);

	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MarkerMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (IsValidClient(param1) && IsClientLeader(param1)) {
		switch (action) {
			case MenuAction_DisplayItem: {
				if (g_iMaximumMarker < 1) {
					char info[64], display[64];
					menu.GetItem(param2, info, sizeof(info));

					if (strcmp(info, "normal", false) == 0 && g_iClientMarker[MK_NORMAL][param1] != -1) {
						FormatEx(display, sizeof(display), "%T (✘)", "Arrow Marker", param1);
						return RedrawMenuItem(display);
					} else if (strcmp(info, "defend", false) == 0 && g_iClientMarker[MK_DEFEND][param1] != -1) {
						FormatEx(display, sizeof(display), "%T (✘)", "Defend Here", param1);
						return RedrawMenuItem(display);
					} else if (strcmp(info, "zmtp", false) == 0 && g_iClientMarker[MK_ZMTP][param1] != -1) {
						FormatEx(display, sizeof(display), "%T (✘)", "ZM Teleport", param1);
						return RedrawMenuItem(display);
					} else if (strcmp(info, "nohug", false) == 0 && g_iClientMarker[MK_NOHUG][param1] != -1) {
						FormatEx(display, sizeof(display), "%T (✘)", "No Doorhug", param1);
						return RedrawMenuItem(display);
					}
				}
			}

			case MenuAction_Select: {
				char info[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "normal", false) == 0)
					ToggleMarkerState(param1, MK_NORMAL);
				else if (strcmp(info, "defend", false) == 0)
					ToggleMarkerState(param1, MK_DEFEND);
				else if (strcmp(info, "zmtp", false) == 0)
					ToggleMarkerState(param1, MK_ZMTP);
				else if (strcmp(info, "nohug", false) == 0)
					ToggleMarkerState(param1, MK_NOHUG);
				else if (strcmp(info, "ping", false) == 0)
					CreatePing(param1);
				else if (strcmp(info, "removemarker", false) == 0)
					RemoveAllMarkers(param1);

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

stock void ToggleMarkerState(int client, int type) {
	if (g_iClientMarker[type][client] != -1 && g_iMaximumMarker < 1)
		RemoveMarker(client, type);
	else
		SpawnMarker(client, type);
}

stock void RemoveAllMarkers(int client) {
	ForceRemoveMarkers(client, MK_NORMAL);
	ForceRemoveMarkers(client, MK_DEFEND);
	ForceRemoveMarkers(client, MK_NOHUG);
	ForceRemoveMarkers(client, MK_ZMTP);
	ForceRemoveMarkers(client, MK_PING);

	g_iMarkerInUse[client] = 0;

	if (g_bPingBeamActive[client])
		KillPingBeam(client);

	Reset_ClientMarkerInUse(client);
}

public void RemoveMarker(int client, int type) {
	if (g_iClientMarker[type][client] == -1 || !IsValidEdict(g_iClientMarker[type][client]))
		return;

	char m_szClassname[64];
	GetEdictClassname(g_iClientMarker[type][client], m_szClassname, sizeof(m_szClassname));

	if (strcmp("prop_dynamic", m_szClassname) == 0)
		SafelyKillEntity(g_iClientMarker[type][client]);

	if (g_iMarkerEntities[type][client] != -1 && IsValidEdict(g_iMarkerEntities[type][client])) {
		GetEdictClassname(g_iMarkerEntities[type][client], m_szClassname, sizeof(m_szClassname));

		if (strcmp("env_sprite", m_szClassname) == 0)
			SafelyKillEntity(g_iMarkerEntities[type][client]);
	}

	// Turn Off Neon related to the marker
	char sTargetName[128];
	GenerateTargetName(client, sTargetName, sizeof(sTargetName), type);

	int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, sTargetName, "light_dynamic");
	SafelyKillEntity(iCounter);

	Reset_ClientMarker(client, type);
	g_iMarkerEntities[type][client] = -1;
	g_iNeonEntities[type][client] = -1;
}

public void SpawnMarker(int client, int type) {
	if (type != MK_PING && g_iMaximumMarker > 0 && g_iMarkerInUse[client] >= g_iMaximumMarker) {
		CPrintToChat(client, "%T %T", "Prefix", client, "Marker Max Limit", client, g_iMaximumMarker);
		return;
	}

	if (GetEdictsCount() + 3 > MAXEDICTS) {
		CPrintToChat(client, "%T %T", "Prefix", client, "Edicts Limit", client);
		return;
	}

	if (g_iMarkerPos[client] == MK_TYPE_CROSSHAIR || type == MK_PING)
		GetPlayerEye(client, g_fPos);
	else
		GetClientAbsOrigin(client, g_fPos);

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	if (type == MK_NORMAL) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerArrowVMT, type);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorArrow, type);
	} else if (type == MK_DEFEND) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerDefend_VMT, type);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorDefend, type);
	} else if (type == MK_NOHUG) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerNOHUG_VMT, type);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorNOHUG, type);
	} else if (type == MK_ZMTP) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerZMTP_VMT, type);
		g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorZMTP, type);
	} else if (type == MK_PING) {
		g_iMarkerEntities[type][client] = SpawnSpecialMarker(client, g_LeaderData[slot].L_MarkerPing_VMT, type);
		// g_iNeonEntities[type][client] = SetupSpecialNeon(client, g_LeaderData[slot].L_iColorPing, type);
	}

	g_iClientMarker[type][client] = SpawnAimMarker(client, g_LeaderData[slot].L_MarkerMDL, type);

	// Only increase the counter if the marker is successfully spawned
	if (g_iMarkerEntities[type][client] != -1 && g_iNeonEntities[type][client] != -1 && g_iClientMarker[type][client] != -1 && type != MK_PING)
		g_iMarkerInUse[client]++;

	// Let the Verify function running to make sure the marker will be removed
	VerifyAutoRemove(client, g_iClientMarker[type][client], type);
	VerifyAutoRemove(client, g_iMarkerEntities[type][client], type);
	VerifyAutoRemove(client, g_iNeonEntities[type][client], type, true);
}

public int SpawnAimMarker(int client, char[] model, int type) {
	if (!IsPlayerAlive(client))
		return -1;

	int Ent = CreateEntityByName("prop_dynamic");
	if (!Ent) return -1;

	char sTargetName[128];
	GenerateTargetName(client, sTargetName, sizeof(sTargetName), type);

	DispatchKeyValue(Ent, "targetname", sTargetName);
	DispatchKeyValue(Ent, "model", model);
	DispatchKeyValue(Ent, "DefaultAnim", "default");
	DispatchKeyValue(Ent, "solid", "0");
	DispatchKeyValue(Ent, "spawnflags", "256");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchKeyValue(Ent, "renderamt", "200");
	DispatchKeyValue(Ent, "modelscale", "0.9");
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
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

	TeleportEntity(Ent, g_fPos, NULL_VECTOR, NULL_VECTOR);
	VerifyParentableSurface(client, Ent);

	return Ent;
}

public int SpawnSpecialMarker(int client, char[] sprite, int type) {
	if (!IsPlayerAlive(client))
		return -1;

	int Ent = CreateEntityByName("env_sprite");
	if (!Ent) return -1;

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	float vec[3];
	vec[0] = g_fPos[0];
	vec[1] = g_fPos[1];

	if (strcmp(sprite, g_LeaderData[slot].L_MarkerPing_VMT, false) == 0)
		vec[2] = g_fPos[2] + 40;
	else
		vec[2] = g_fPos[2] + 160;

	char sTargetName[128];
	GenerateTargetName(client, sTargetName, sizeof(sTargetName), type);

	DispatchKeyValue(Ent, "targetname", sTargetName);
	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchKeyValue(Ent, "renderamt", "128");
	DispatchKeyValue(Ent, "disablereceiveshadows", "1");
	DispatchKeyValue(Ent, "disableshadows", "1");
	DispatchSpawn(Ent);

	TeleportEntity(Ent, vec, NULL_VECTOR, NULL_VECTOR);
	VerifyParentableSurface(client, Ent);

	return Ent;
}

stock int SetupPlayerNeon(int client) {
	if (GetEdictsCount() > MAXEDICTS) {
		CPrintToChat(client, "%T %T", "Prefix", client, "Edicts Limit", client);
		return -1;
	}

	int Neon = CreateEntityByName("light_dynamic");

	if (!IsValidEntity(Neon))
		return -1;

	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	// fOrigin[2] -= 10;

	char sTargetName[64];
	FormatEx(sTargetName, sizeof(sTargetName), "MK_light_player_%s", g_sSteamIDs64[client]);

	int slot = GetLeaderIndexWithLeaderSlot(g_iClientLeaderSlot[client]);

	char sColor[64];
	FormatEx(sColor, sizeof(sColor), "%i %i %i %i", g_LeaderData[slot].L_iColorPing[0], g_LeaderData[slot].L_iColorPing[1], g_LeaderData[slot].L_iColorPing[2], g_LeaderData[slot].L_iColorPing[3]);

	DispatchKeyValue(Neon, "targetname", sTargetName);
	DispatchKeyValue(Neon, "_light", sColor);
	DispatchKeyValue(Neon, "brightness", "2");
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
	FormatEx(sTargetName, sizeof(sTargetName), "MK_light_player_%s", g_sSteamIDs64[client]);

	int iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, sTargetName, "light_dynamic");
	SafelyKillEntity(iCounter);
	return 0;
}

stock int SetupSpecialNeon(int client, int color[4], int type) {
	int Neon = CreateEntityByName("light_dynamic");

	if (!IsValidEntity(Neon))
		return -1;

	float vec[3];
	vec[0] = g_fPos[0];
	vec[1] = g_fPos[1];
	vec[2] = g_fPos[2];

	char sColor[64], sTargetName[128];
	GenerateTargetName(client, sTargetName, sizeof(sTargetName), type);
	FormatEx(sColor, sizeof(sColor), "%i %i %i %i", color[0], color[1], color[2], color[3]);

	DispatchKeyValue(Neon, "targetname", sTargetName);
	DispatchKeyValue(Neon, "_light", sColor);
	DispatchKeyValue(Neon, "brightness", "5");
	DispatchKeyValue(Neon, "distance", "150");
	DispatchKeyValue(Neon, "spotlight_radius", "50");
	DispatchKeyValue(Neon, "style", "0");
	DispatchSpawn(Neon);
	AcceptEntityInput(Neon, "TurnOn");

	TeleportEntity(Neon, vec, NULL_VECTOR, NULL_VECTOR);
	VerifyParentableSurface(client, Neon);

	return Neon;
}

stock void GetPlayerEye(int client, float pos[3]) {
	float vAngles[3], vOrigin[3];
	
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	TR_TraceRayFilter(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer);
	TR_GetEndPosition(pos);
}

stock int GetClientAimTargetPosition(int client, float fPosition[3]) {
	if (client < 1)
		return -1;

	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT_HULL, RayType_Infinite, TraceFilterAllEntities, client);
	TR_GetEndPosition(fPosition, trace);
	fPosition[2] += 5.0;

	int entity = TR_GetEntityIndex(trace);
	CloseHandle(trace);
	return entity;
}

stock bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients || !entity;
}

stock bool TraceFilterAllEntities(int entity, int contentsMask, int client) {
	return entity <= MaxClients ? false : true;
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
	
		char codename[32], szMessage[255];
		GetLeaderCodename(g_iClientLeaderSlot[client], codename, sizeof(codename));

		if (g_bPlugin_ccc) {
			FormatEx(szMessage, sizeof(szMessage), "{darkred}[{orange}Leader %s{darkred}] {%s}%N {default}: {%s}%s", 
				codename, g_sColorName[client], client, g_sColorChat[client], LeaderText);
		} else {
			FormatEx(szMessage, sizeof(szMessage), "{darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}: {default}%s", codename, client, LeaderText);
		}

		CPrintToChatAll(szMessage);
		return Plugin_Handled;
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

		if (g_bPlugin_ccc) {
			FormatEx(szMessage, sizeof(szMessage), "(Human) {darkred}[{orange}Leader %s{darkred}] {%s}%N {default}: {%s}%s", 
				codename, g_sColorName[client], client, g_sColorChat[client], LeaderText);
		} else {
			FormatEx(szMessage, sizeof(szMessage), "(Human) {darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}: {default}%s", codename, client, LeaderText);
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
	CCC_GetColorKey(client, CCC_NameColor, g_sColorName[client], 64);
	CCC_GetColorKey(client, CCC_ChatColor, g_sColorChat[client], 64);

	// Check HEX to prevent issue
	char g_sColorNameSanitized[64], g_sColorChatSanitized[64];

	if (g_sColorName[client][0] != '\0' && IsValidHex(g_sColorName[client])) {
		FormatEx(g_sColorNameSanitized, sizeof(g_sColorNameSanitized), "#%s", g_sColorName[client]);
		g_sColorName[client] = g_sColorNameSanitized;
	} else {
		g_sColorName[client] = "lightblue";
	}

	if (g_sColorChat[client][0] != '\0' && IsValidHex(g_sColorChat[client])) {
		FormatEx(g_sColorChatSanitized, sizeof(g_sColorChatSanitized), "#%s", g_sColorChat[client]);
		g_sColorChat[client] = g_sColorChatSanitized;
	} else {
		g_sColorChat[client] = "default";
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
		FormatEx(szMessage, sizeof(szMessage), "{darkred}[{orange}Leader %s{darkred}] {teamcolor}%N {default}(RADIO): %s", codename, client, text);
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

	g_bClientLeader[client] = true;
	g_iClientLeaderSlot[client] = slot;
	g_iCurrentLeader[slot] = client;
	Reset_ClientSprite(client);
	Reset_ClientResigned(client);

	char codename[32];
	GetLeaderCodename(slot, codename, sizeof(codename));

	if (g_bPlugin_ccc)
		GetClientChat(client);

	if (g_LeaderData[slot].L_CodeNameVMT[0] != '\0')
		g_iSpriteLeader[client] = AttachSprite(client, g_LeaderData[slot].L_CodeNameVMT, 0);

	if (g_bNeonLeader)
		SetupPlayerNeon(client);

	if (g_bGlowLeader)
		ToolsSetEntityColor(client, g_LeaderData[slot].L_iColorPing[0], g_LeaderData[slot].L_iColorPing[1], g_LeaderData[slot].L_iColorPing[2]);

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i))
			CPrintToChat(i, "%T %T", "Prefix", i, "Become New Leader", i, client, codename);
	}

	Reset_ClientMarkerInUse(client);
	for (int i = 0; i < MAX_MARKERS; i++) {
		Reset_ClientMarker(client, i);
	}

	Call_StartForward(g_hSetClientLeaderForward);
	Call_PushCell(client);
	Call_PushString(codename);
	Call_Finish();
}

void RemoveLeader(int client, ResignReason reason, bool announce = true) {
	char codename[32];
	bool wasLeader = g_bClientLeader[client];
	int slot = GetClientLeaderSlot(client);

	GetLeaderCodename(slot, codename, sizeof(codename));

	RemoveAllMarkers(client);
	RemoveSpriteFollow(client);
	RemoveSpriteCodeName(client);

	if (g_bNeonLeader)
		RemovePlayerNeon(client);

	if (g_bGlowLeader)
		ToolsSetEntityColor(client, 255, 255, 255);

	if (g_bTrailActive[client])
		KillTrail(client);

	if (g_bBeaconActive[client]) {
		ToggleBeacon(client);
		KillBeacon(client);
	}

	Reset_VotesForClient(client);
	Reset_ClientFromLeaderSlots(client);

	Reset_CurrentLeader(client);
	Reset_CurrentLeaderSlot(client);
	Reset_LeaderSlot(client);
	Reset_ClientGetVoted(client);
	Reset_ClientSprite(client);
	Reset_ClientBeaconActive(client);
	Reset_ClientPingBeamActive(client);
	Reset_ClientTrailActive(client);

	if (!wasLeader)
		return;

	Call_StartForward(g_hRemoveClientLeaderForward);
	Call_PushCell(client);
	Call_PushCell(reason);
	Call_Finish();

	if (reason == R_ADMINFORCED)
		g_bResignedByAdmin[client] = true;

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
}

void EnsureLeaderConsistency() {
	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client))
			continue;

		int slot = g_iClientLeaderSlot[client];
		bool isLeader = g_bClientLeader[client];

		if (isLeader) {
			if (slot < 0 || slot >= g_iTotalLeader || g_iCurrentLeader[slot] != client) {
				LogMessage("Inconsistent state: Client %d marked as leader but slot %d is invalid", client, slot);
				RemoveLeader(client, R_ADMINFORCED, false);
			}
		} else if (slot >= 0 && slot < g_iTotalLeader && g_iCurrentLeader[slot] == client) {
			LogMessage("Inconsistent state: Client %d in slot %d but not marked as leader", client, slot);
			Reset_LeaderSlotByIndex(slot);
			Reset_ClientLeaderSlot(client);
		}
	}
}

/* =========================================================================
||  QuickCommand
============================================================================ */
// +lookatweapon exist only on CS:GO
public Action QuickLeaderMenuCommand(int client, const char[] command, int argc) {
	if (IsClientLeader(client))
		QuickPingCommand(client);

	return Plugin_Continue;
}

// -lookatweapon exist only on CS:GO
public Action QuickMarkerMenuCommand(int client, const char[] command, int argc) {
	if (IsClientLeader(client))
		QuickMarkerCommand(client);

	return Plugin_Continue;
}

// Flashlight x2 : Marker Menu
// Spray x2 : Ping Shortcut
// +Attack3 x4 : Leader Menu (x4: +attack(<ANY>) = attack in loop)
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse) {
	if (IsValidClient(client) && IsPlayerAlive(client) && IsClientLeader(client)) {
		if (impulse == 0x64) {
			QuickMarkerCommand(client);
			return Plugin_Continue;
		}

		if (impulse == 0xC9) {
			QuickPingCommand(client);
			return Plugin_Continue;
		}

		if (buttons & IN_ATTACK3) {
			QuickLeaderCommand(client);
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

// Spray : Ping shortcut
public Action HookDecal(const char[] sTEName, const int[] iClients, int iNumClients, float fSendDelay) {
	int client = TE_ReadNum("m_nPlayer");
	RequestFrame(QuickPingCommand, client);
	return Plugin_Continue;
}

stock void QuickMarkerCommand(int client) {
	if (g_bShorcut[client]) {
		int iUserID = GetClientUserId(client);
		g_iButtonMarkerCount[client]++;
		CreateTimer(1.0, ResetMarkerButtonPressed, iUserID, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (g_iButtonMarkerCount[client] >= 2 && IsClientLeader(client))
		MarkerMenu(client);
}

stock void QuickPingCommand(int client) {
	if (g_bShorcut[client]) {
		int iUserID = GetClientUserId(client);
		g_iButtonPingCount[client]++;
		CreateTimer(1.0, ResetPingButtonPressed, iUserID, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (g_iButtonPingCount[client] >= 2 && IsClientLeader(client))
		CreatePing(client);
}

stock void QuickLeaderCommand(int client) {
	if (g_bShorcut[client]) {
		int iUserID = GetClientUserId(client);
		g_iButtonLeaderCount[client]++;
		CreateTimer(1.0, ResetLeaderButtonPressed, iUserID, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (g_iButtonLeaderCount[client] >= 4 && IsClientLeader(client))
		LeaderMenu(client);
}

public Action ResetLeaderButtonPressed(Handle timer, any iUserID) {
	int client = GetClientOfUserId(iUserID);
	if (!client)
		return Plugin_Handled;

	g_iButtonLeaderCount[client] = 0;
	return Plugin_Handled;
}

public Action ResetMarkerButtonPressed(Handle timer, any iUserID) {
	int client = GetClientOfUserId(iUserID);
	if (!client)
		return Plugin_Handled;

	g_iButtonMarkerCount[client] = 0;
	return Plugin_Handled;
}

public Action ResetPingButtonPressed(Handle timer, any iUserID) {
	int client = GetClientOfUserId(iUserID);
	if (!client)
		return Plugin_Handled;

	g_iButtonPingCount[client] = 0;
	return Plugin_Handled;
}

/* =========================================================================
||  VIP
============================================================================ */
stock bool IsClientVIP(int client) {
	if (!g_bVIPGroups || !g_bPlugin_vipcore)
		return false;

	char group[64];
	bool vip = VIP_GetClientVIPGroup(client, group, 64);

	if (!vip)
		return false;

	if (strcmp(group, "Retired Staff", false) == 0)
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
	for(int i = 0; i < g_iTotalLeader; i++) {
		if (g_LeaderData[i].L_Slot == slot)
			return i;
	}
	return -1;
}

stock int GetLeaderCodename(int slot, char[] buffer, int maxlen) {
	for(int i = 0; i < g_iTotalLeader; i++) {
		if (g_LeaderData[i].L_Slot == slot) {
			FormatEx(buffer, maxlen, "%s", g_LeaderData[i].L_Codename);
			return 1;
		}
	}
	return -1;
}

stock int GetLeaderFreeSlot() {
	for (int i = 0; i < g_iTotalLeader; i++) {
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
		if (g_bResignedByAdmin[client])
			return false;

		if (IsClientAdmin(client) || IsClientVIP(client))
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
		if (IsClientInGame(i) && !IsFakeClient(i) && (IsPossibleLeader(i) || (i < MAXLEADER && g_iCurrentLeader[i])))
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_NotLeaders(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && !IsPossibleLeader(i) && (i >= MAXLEADER || !g_iCurrentLeader[i]))
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_Leader(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && i < MAXLEADER && g_iCurrentLeader[i])
			PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_NotLeader(const char[] sPattern, Handle hClients) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidClient(i) && (i >= MAXLEADER || !g_iCurrentLeader[i]))
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
||  Glow Leader
============================================================================ */
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
	FormatEx(no, 64, "%T", "No", client);
	FormatEx(yes, 64, "%T", "Yes", client);

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
				char info[64], display[64];
				menu.GetItem(param2, info, sizeof(info));

				if (strcmp(info, "canceled", false) == 0) {
					FormatEx(display, sizeof(display), "%T", "No", param1);
					return RedrawMenuItem(display);
				} else if (strcmp(info, "confirmed", false) == 0) {
					FormatEx(display, sizeof(display), "%T", "Yes", param1);
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

/* =========================================================================
||  DRY
============================================================================ */
stock void GenerateTargetName(int client, char[] sTargetName, int size, int type) {
	FormatEx(sTargetName, size, "%s%s", g_sMarkerTypes[type], g_sSteamIDs64[client]);
}

stock void ForceRemoveMarkers(int client, int type) {
	char sTargetName[128];
	GenerateTargetName(client, sTargetName, sizeof(sTargetName), type);

	for (int i = 0; i < ENTITIES_PER_MK; i++) {
		RemoveMarkersByType(sTargetName, g_sEntityTypes[i]);
	}
}

stock void RemoveMarkersByType(const char[] sTargetName, const char[] sEntityType) {
	int iCounter = INVALID_ENT_REFERENCE;
	while ((iCounter = FindEntityByTargetname(INVALID_ENT_REFERENCE, sTargetName, sEntityType)) != INVALID_ENT_REFERENCE)
		SafelyKillEntity(iCounter);
}

stock void SafelyKillEntity(int Ent) {
	if (Ent > 0 && IsValidEdict(Ent)) {
		char sClass[64], sTargetname[64];
		GetEntityClassname(Ent, sClass, sizeof(sClass));

		if (strcmp(sClass, "env_sprite") != 0 && strcmp(sClass, "light_dynamic") != 0 && strcmp(sClass, "prop_dynamic") != 0)
			return;

		GetEntPropString(Ent, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
		if (sTargetname[0] == '\0' || StrContains(sTargetname, "MK_", false) == -1)
			return;

		// LogMessage("Removing entity %d (%s) with targetname %s", Ent, sClass, sTargetname);
		AcceptEntityInput(Ent, "Kill");
	}
}

stock bool IsTargetMuted(int target) {
	bool bIsMuted = false;
	bool bBaseCommsPP = g_Plugin_BaseComm && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "BaseComm_IsClientMuted") == FeatureStatus_Available;
	bool bSourceCommsPP = g_bPlugin_SourceCommsPP && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SourceComms_GetClientMuteType") == FeatureStatus_Available;
	if (bBaseCommsPP)
		bIsMuted = BaseComm_IsClientMuted(target);
	else if (bSourceCommsPP) {
		int iComms = SourceComms_GetClientMuteType(target);
		bIsMuted = iComms != 0 ? true : false;
	}

	return bIsMuted;
}

stock bool IsTargetGagged(int target) {
	bool bIsGagged = false;
	bool bBaseCommsPP = g_Plugin_BaseComm && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "BaseComm_IsClientGagged") == FeatureStatus_Available;
	bool bSourceCommsPP = g_bPlugin_SourceCommsPP && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SourceComms_GetClientGagType") == FeatureStatus_Available;
	if (bBaseCommsPP)
		bIsGagged = BaseComm_IsClientGagged(target);
	else if (bSourceCommsPP) {
		int iComms = SourceComms_GetClientGagType(target);
		bIsGagged = iComms != 0 ? true : false;
	}

	return bIsGagged;
}

stock void VerifyParentableSurface(int client, int Ent) {
	float Origin[3];
	int targetEnt = GetClientAimTargetPosition(client, Origin);
	// Thanks to Koen for this feature
	if (targetEnt != -1) {
		char class[64];
		GetEntityClassname(targetEnt, class, sizeof(class));
		if (strcmp(class, "func_breakable", false) == 0 || strcmp(class, "func_tracktrain", false) == 0 || strcmp(class, "func_movelinear", false) == 0 || strcmp(class, "func_door", false) == 0 ||
			StrContains(class, "prop_dynamic") != -1 || StrContains(class, "func_physbox") != -1 || StrContains(class, "prop_physics") != -1) {
			SetVariantString("!activator");
			AcceptEntityInput(Ent, "SetParent", targetEnt, Ent);
		}
	}
}

stock void VerifyAutoRemove(int client, int iEnt, int type, bool bDeductUse = false) {
	// Prevent server crash if entity is 0 or negative
	if (iEnt <= 0 || g_fMarkerTime <= 0.0 && g_iMaximumMarker < 1)
		return;

	if (g_fMarkerTime <= 0.0)
		g_fMarkerTime = 10.0;

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(iEnt);
	pack.WriteCell(type);
	pack.WriteCell(bDeductUse);
	CreateTimer(g_fMarkerTime, Timer_RemoveEdict, pack, TIMER_FLAG_NO_MAPCHANGE);
}

stock Action Timer_RemoveEdict(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int iEnt = pack.ReadCell();
	int type = pack.ReadCell();
	bool bDeductUse = pack.ReadCell();
	delete pack;

	if (!IsValidEdict(iEnt))
		return Plugin_Stop;

	RemoveMarker(client, type);

	if (bDeductUse && type != MK_PING)
		g_iMarkerInUse[client]--;

	SafelyKillEntity(iEnt);
	return Plugin_Stop;
}

/* =========================================================================
|| 3RD Party Integration
============================================================================ */
#if defined _sourcecomms_included
public void SourceComms_OnBlockAdded(int client, int target, int time, int type, char[] reason) {
	// Check for mute/silence type (1 = Mute, 2 = Gag, 3 = Silence)
	if (type == 1 || type == 2 || type == 3) {
		if (IsPossibleLeader(target)) {
			MCE_RemoveNomination(target);
		}

		if (IsClientLeader(target)) {
			RemoveLeader(target, R_ADMINFORCED, true);
		}
	}
}

public void SourceComms_OnBlockRemoved(int client, int target, int type, char[] reason) {
	// Check for (4) unmute - (6) unsilence  - (14) temp mute removed - (16) temp silence removed
	if (type == 4 || type == 6 || type == 14 || type == 16) {
		Reset_ClientResigned(target);
	}
}
#endif

#if defined _basecomm_included
public void BaseComm_OnClientMute(int client, bool muteState) {
	if (muteState && IsClientLeader(client)) {
		RemoveLeader(client, R_ADMINFORCED, true);
	}
	else {
		Reset_ClientResigned(client);
	}
}
#endif

stock void MCE_RemoveNomination(int client) {
	if (!g_cvRemoveNomOnMute.BoolValue)
		return;

	bool bNatives = g_bPlugin_MCE && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetNominationByOwner") == FeatureStatus_Available
		&& GetFeatureStatus(FeatureType_Native, "RemoveNominationByOwner") == FeatureStatus_Available
		&& GetFeatureStatus(FeatureType_Native, "IsMapLeaderRestricted") == FeatureStatus_Available;

	if (!bNatives)
		return;

#if defined _mapchooser_extended_included_
	// Client has a nomination and the map is leader nom only ? Remove it
	char map[PLATFORM_MAX_PATH];
	if (GetNominationByOwner(client, map) && IsMapLeaderRestricted(map)) {
		RemoveNominationByOwner(client);
	}
#endif
}

/* =========================================================================
||  Reset Values functions
============================================================================ */
stock void Reset_PlayerState(int client) {
	Reset_CurrentLeader(client);
	Reset_LeaderSlot(client);
	Reset_ClientGetVoted(client);
	Reset_ClientNextVote(client);
	Reset_ClientVoteWho(client);
	Reset_ClientResigned(client);
}

stock void Reset_CurrentLeaderSlot(int client) {
	int slot = g_iClientLeaderSlot[client];
	Reset_ClientLeaderSlot(client);
	Reset_LeaderSlotByIndex(slot);
}

stock void Reset_ClientLeaderSlot(int client) {
	g_iClientLeaderSlot[client] = -1;
}

stock void Reset_LeaderSlotByIndex(int slot) {
	if (slot >= 0 && slot < g_iTotalLeader)
		g_iCurrentLeader[slot] = -1;
}

stock void Reset_LeaderSlot(int client) {
	g_iClientLeaderSlot[client] = -1;
}

stock void Reset_CurrentLeader(int client) {
	g_bClientLeader[client] = false;
}

stock void Reset_ClientVoteWho(int client) {
	g_iClientVoteWhom[client] = -1;
}

stock void Reset_ClientGetVoted(int client) {
	g_iClientGetVoted[client] = 0;
}

stock void Reset_ClientNextVote(int client) {
	g_iClientNextVote[client] = 0;
}

stock void Reset_ClientSprite(int client) {
	g_iClientSprite[client] = -1;
}

stock void Reset_ClientBeaconActive(int client) {
	g_bBeaconActive[client] = false;
}

stock void Reset_ClientPingBeamActive(int client) {
	g_bPingBeamActive[client] = false;
}
stock void Reset_ClientTrailActive(int client) {
	g_bTrailActive[client] = false;
}

stock void Reset_ClientMarker(int client, int type) {
	g_iClientMarker[type][client] = -1;
}

stock void Reset_ClientMarkerInUse(int client) {
	g_iMarkerInUse[client] = 0;
}

stock void Reset_ClientResigned(int client) {
	g_bResignedByAdmin[client] = false;
}

void Reset_AllLeaders() {
	for (int i = 0; i < g_iTotalLeader; i++) {
		int client = g_iCurrentLeader[i];
		if (client != -1) {
			if (IsValidClient(client)) {
				RemoveLeader(client, R_ADMINFORCED, false);
			} else {
				Reset_LeaderSlotByIndex(i);
			}
		}
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			if (g_bClientLeader[i]) {
				RemoveLeader(i, R_ADMINFORCED, false);
			}
			Reset_ClientVoteWho(i);
			Reset_ClientNextVote(i);
		}
	}
}

void Reset_VotesForClient(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientFromSerial(g_iClientVoteWhom[i]) == client) {
			Reset_ClientVoteWho(i);  
		}
	}
}

void Reset_ClientFromLeaderSlots(int client) {
	for (int i = 0; i < g_iTotalLeader; i++) {
		if (g_iCurrentLeader[i] == client) {
			g_iCurrentLeader[i] = -1;
		}
	}
}
