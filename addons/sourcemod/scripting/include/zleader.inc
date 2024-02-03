#if defined _zleader_included
	#endinput
#endif
#define _zleader_included

forward void Leader_SetClientLeader(int client, char[] sReason);
forward void Leader_RemoveClientLeader(int client);

#define MAXLEADER 5
#define MAXEDICTS (GetMaxEntities() - 150)
#define MAXPOSSIBLELEADERS 999 // Determine maxium lines number of leaders.ini 

#define MK_TYPE_CROSSHAIR 1
#define MK_TYPE_CLIENT 0

#define SP_FOLLOW 0

#define MK_NORMAL 0
#define MK_DEFEND 1
#define MK_ZMTP 2
#define MK_NOHUG 3
#define MK_PING 4

#define MK_TOTAL (MK_NORMAL + MK_DEFEND + MK_ZMTP + MK_NOHUG + MK_PING)

enum ResignReason
{
	R_DISCONNECTED = 0,
	R_ADMINFORCED = 1,
	R_SELFRESIGN = 2,
	R_SPECTATOR = 3,
	R_DIED = 4,
	R_INFECTED = 5
}

native void ZL_SetLeader(int client, int slot);
native bool ZL_IsClientLeader(int client);
native void ZL_RemoveLeader(int client, ResignReason reason, bool announce);
native int ZL_GetClientLeaderSlot(int client);
native bool ZL_IsLeaderSlotFree(int slot);
native bool ZL_IsPossibleLeader(int client);

public SharedPlugin __pl_zleader = 
{
	name = "zleader",
	file = "zleader.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public __pl_zleader_SetNTVOptional()
{
	MarkNativeAsOptional("ZL_SetLeader");
	MarkNativeAsOptional("ZL_IsClientLeader");
	MarkNativeAsOptional("ZL_RemoveLeader");
	MarkNativeAsOptional("ZL_GetClientLeaderSlot");
	MarkNativeAsOptional("ZL_IsLeaderSlotFree");
	MarkNativeAsOptional("ZL_IsPossibleLeader");
}
#endif