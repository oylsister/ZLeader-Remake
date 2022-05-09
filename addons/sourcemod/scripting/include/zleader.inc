#if defined _zleader_included
	#endinput
#endif
#define _zleader_included

#define ALPHA 0
#define BRAVO 1
#define CHARLIE 2
#define DELTA 3
#define ECHO 4

#define MAXLEADER 5

enum ResignReason
{
	R_DISCONNECTED = 0,
	R_ADMINFORCED = 1,
	R_SELFRESIGN = 2,
	R_SPECTATOR = 3,
	R_DIED = 4,
	R_INFECTED = 5
}

native void ZL_SetLeader(int client);
native bool ZL_IsClientLeader(int client);
native void ZL_RemoveLeader(int client, ResignReason reason, bool announce);
native int ZL_GetClientLeaderSlot(int client);
native bool ZL_IsLeaderSlotFree(int slot);

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
}
#endif