#if defined _zleader_included
	#endinput
#endif
#define _zleader_included

#define ZLeader_V_MAJOR   "3"
#define ZLeader_V_MINOR   "7"
#define ZLeader_V_PATCH   "1"

#define ZLeader_VERSION   ZLeader_V_MAJOR..."."...ZLeader_V_MINOR..."."...ZLeader_V_PATCH

/**
 * Called when a player becomes leader.
 *
 * @param 		client The client index of the player who became leader.
 * @param 		codename The codename of the leader.
 * @noreturn
 */
forward void Leader_SetClientLeader(int client, char[] sReason);

/**
 * Called when a player loses leader.
 *
 * @param 		client The client index of the player who lost leader.
 * @param 		reason ResignReason Code of the leader.
 * @noreturn
 */
forward void Leader_RemoveClientLeader(int client, int reason);

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

#define MK_TOTAL 5 // 5 Markers Types

#define MAX_MARKERS 33 // Each Markers Type value * 3
#define MAX_INDEX (MK_TOTAL * MAX_MARKERS * MK_TOTAL)

#define ENTITIES_PER_MK 3

enum ResignReason
{
	R_DISCONNECTED = 0,
	R_ADMINFORCED = 1,
	R_SELFRESIGN = 2,
	R_SPECTATOR = 3,
	R_DIED = 4,
	R_INFECTED = 5
}

/**
 * Sets a client as leader in the specified slot.
 *
 * @param client        Client index
 * @param slot          Leader slot to assign
 * @noreturn
 * @error              Invalid client index or client not in game
 */
native void ZL_SetLeader(int client, int slot);

/**
 * Checks if a client is currently a leader.
 *
 * @param client        Client index
 * @return             True if client is leader, false otherwise
 * @error              Invalid client index
 */
native bool ZL_IsClientLeader(int client);

/**
 * Removes leader status from a client.
 *
 * @param client        Client index
 * @param reason        Reason for removal
 * @param announce      Whether to announce the removal
 * @noreturn
 * @error              Invalid client index or client not leader
 */
native void ZL_RemoveLeader(int client, ResignReason reason, bool announce);

/**
 * Gets the leader slot assigned to a client.
 *
 * @param client        Client index
 * @return             Leader slot number, or -1 if not leader
 * @error              Invalid client index or client not leader
 */
native int ZL_GetClientLeaderSlot(int client);

/**
 * Checks if a leader slot is available.
 *
 * @param slot          Slot number to check
 * @return             True if slot is free, false otherwise
 */
native bool ZL_IsLeaderSlotFree(int slot);

/**
 * Checks if a client is eligible to become leader.
 *
 * @param client        Client index
 * @return             True if client can be leader, false otherwise
 * @error              Invalid client index
 */
native bool ZL_IsPossibleLeader(int client);

public SharedPlugin __pl_zleader = 
{
	name = "zleader",
	file = "ZLeader.smx",
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
