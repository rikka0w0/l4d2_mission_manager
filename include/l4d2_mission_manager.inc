#if defined _lmm_included_
 #endinput
#endif
#define _lmm_included_

#define LEN_MISSION_NAME 64		// e.g. L4D2C1
#define LEN_MAP_FILENAME 32		// e.g. c1m1_hotel
#define LEN_GAMEMODE_NAME 32	// e.g. coop, versus, scavenge, survival

enum LMM_GAMEMODE
{
	GAMEMODE_UNKNOWN = 0,
	GAMEMODE_COOP = 1,
	GAMEMODE_VERSUS = 2,
	GAMEMODE_SCAVENGE = 4,
	GAMEMODE_SURVIVAL = 8
};

native LMM_GAMEMODE LMM_GetCurrentGameMode();
native int LMM_GetNumberOfMissions(LMM_GAMEMODE gamemode);
native int LMM_GetMissionName(LMM_GAMEMODE gamemode, int missionIndex, char[] missionName, int length);
native int LMM_GetNumberOfMaps(LMM_GAMEMODE gamemode, int missionIndex);
native int LMM_GetMapName(LMM_GAMEMODE gamemode, int missionIndex, int mapIndex, char[] mapName, int length);

forward void OnLMMUpdateList();