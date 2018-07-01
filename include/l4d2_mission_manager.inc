#if defined _lmm_included_
 #endinput
#endif
#define _lmm_included_

#define LEN_MISSION_NAME 64		// e.g. L4D2C1
#define LEN_MAP_FILENAME 64		// e.g. c1m1_hotel
#define LEN_GAMEMODE_NAME 32	// e.g. coop, versus, scavenge, survival

enum LMM_GAMEMODE
{
	LMM_GAMEMODE_UNKNOWN = 0,
	LMM_GAMEMODE_COOP = 1,
	LMM_GAMEMODE_VERSUS = 2,
	LMM_GAMEMODE_SCAVENGE = 4,
	LMM_GAMEMODE_SURVIVAL = 8
};

native LMM_GAMEMODE LMM_GetCurrentGameMode();
native LMM_GAMEMODE LMM_StringToGamemode(const char[] name);
native int LMM_GamemodeToString(LMM_GAMEMODE gamemode, char[] name, int length);
native int LMM_GetNumberOfMissions(LMM_GAMEMODE gamemode);
native int LMM_FindMissionIndexByName(LMM_GAMEMODE gamemode, const char[] missionName);
native int LMM_GetMissionName(LMM_GAMEMODE gamemode, int missionIndex, char[] missionName, int length);
native int LMM_GetNumberOfMaps(LMM_GAMEMODE gamemode, int missionIndex);
native int LMM_GetMapName(LMM_GAMEMODE gamemode, int missionIndex, int mapIndex, char[] mapName, int length);
native int LMM_GetNumberOfInvalidMissions();
native int LMM_GetInvalidMissionName(int missionIndex, char[] mapName, int length);

/**
	This forward is called during the OnPluginStart() phase.
	Do NOT use any LMM APIs in OnPluginStart, due to the chance that your plugin is loaded prior to LMM.
	LMM APIs become available in OnAllPluginsLoaded().
*/
forward void OnLMMUpdateList();