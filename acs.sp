//////////////////////////////////////////
// Automatic Campaign Switcher for L4D2 //
// Version 1.2.2                        //
// Compiled May 21, 2011                //
// Programmed by Chris Pringle          //
//////////////////////////////////////////

/*==================================================================================================

	This plugin was written in response to the server kicking everyone if the vote is not passed
	at the end of the campaign. It will automatically switch to the appropriate map at all the
	points a vote would be automatically called, by the game, to go to the lobby or play again.
	ACS also includes a voting system in which people can vote for their favorite campaign/map
	on a finale or scavenge map.  The winning campaign/map will become the next map the server
	loads.

	Supported Game Modes in Left 4 Dead 2
	
		Coop
		Realism
		Versus
		Team Versus
		Scavenge
		Team Scavenge
		Mutation 1-20
		Community 1-5

	Change Log
		
		v1.2.2 (May 21, 2011)	- Added message for new vote winner when a player disconnects
								- Fixed the sound to play to all the players in the game
								- Added a max amount of coop finale map failures cvar
								- Changed the wait time for voting ad from round_start to the 
								  player_left_start_area event 
								- Added the voting sound when the vote menu pops up
		
		v1.2.1 (May 18, 2011)	- Fixed mutation 15 (Versus Survival)
		
		v1.2.0 (May 16, 2011)	- Changed some of the text to be more clear
								- Added timed notifications for the next map
								- Added a cvar for how to advertise the next map
								- Added a cvar for the next map advertisement interval
								- Added a sound to help notify players of a new vote winner
								- Added a cvar to enable/disable sound notification
								- Added a custom wait time for coop game modes
								
		v1.1.0 (May 12, 2011)	- Added a voting system
								- Added error checks if map is not found when switching
								- Added a cvar for enabling/disabling voting system
								- Added a cvar for how to advertise the voting system
								- Added a cvar for time to wait for voting advertisement
								- Added all current Mutation and Community game modes
								
		v1.0.0 (May 5, 2011)	- Initial Release

===================================================================================================*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <l4d2_mission_manager>

#define PLUGIN_VERSION	"v1.9.0"

//Define the wait time after round before changing to the next map in each game mode
#define WAIT_TIME_BEFORE_SWITCH_COOP			7.0
#define WAIT_TIME_BEFORE_SWITCH_VERSUS			6.0
#define WAIT_TIME_BEFORE_SWITCH_SCAVENGE		11.0

//Define Game Modes
#define GAMEMODE_UNKNOWN	LMM_GAMEMODE_UNKNOWN
#define GAMEMODE_COOP 		LMM_GAMEMODE_COOP
#define GAMEMODE_VERSUS 	LMM_GAMEMODE_VERSUS
#define GAMEMODE_SCAVENGE 	LMM_GAMEMODE_SCAVENGE
#define GAMEMODE_SURVIVAL 	LMM_GAMEMODE_SURVIVAL

#define DISPLAY_MODE_DISABLED	0
#define DISPLAY_MODE_HINT		1
#define DISPLAY_MODE_CHAT		2
#define DISPLAY_MODE_MENU		3

#define SOUND_NEW_VOTE_START	"ui/Beep_SynthTone01.wav"
#define SOUND_NEW_VOTE_WINNER	"ui/alert_clink.wav"


//Global Variables
LMM_GAMEMODE g_iGameMode;			//Integer to store the gamemode
new g_iRoundEndCounter;				//Round end event counter for versus
new g_iCoopFinaleFailureCount;		//Number of times the Survivors have lost the current finale
new bool:g_bFinaleWon;				//Indicates whether a finale has be beaten or not

//Voting Variables					
new bool:g_bClientShownVoteAd[MAXPLAYERS + 1];				//If the client has seen the ad already
new bool:g_bClientVoted[MAXPLAYERS + 1];					//If the client has voted on a map
new g_iClientVote[MAXPLAYERS + 1];							//The value of the clients vote
new g_iWinningMapIndex;										//Winning map/campaign's index
new g_iWinningMapVotes;										//Winning map/campaign's number of votes
new Handle:g_hMenu_Vote[MAXPLAYERS + 1]	= INVALID_HANDLE;	//Handle for each players vote menu

//Console Variables (CVars)
ConVar g_hCVar_VotingEnabled;			//Tells if the voting system is on	
ConVar g_hCVar_VoteWinnerSoundEnabled;	//Sound plays when vote winner changes
ConVar g_hCVar_VotingAdMode;			//The way to advertise the voting system
ConVar g_hCVar_VotingAdDelayTime;		//Time to wait before showing advertising			
ConVar g_hCVar_NextMapAdMode;			//The way to advertise the next map 
ConVar g_hCVar_NextMapAdInterval;		//Interval for ACS next map advertisement
ConVar g_hCVar_MaxFinaleFailures;		//Amount of times Survivors can fail before ACS switches in coop
ConVar g_hCVar_ChMapAnnounceMode;		//How to advertise "!chmap"
ConVar g_hCVar_ChMapBroadcastInterval;	//The interval for advertising "!chmap"

Handle g_hTimer_Broadcast;


/*=========================================================
#########       Mission Cycle Data Storage        #########
=========================================================*/
#define LEN_CFG_LINE 256
#define LEN_CFG_SEGMENT 128
#define CHAR_CYCLE_SEPARATOR "// 3-rd maps(Do not delete/modify this line!)"

ArrayList g_hInt_CoopMapIndexes;
ArrayList g_hBool_CoopNameHasTranslation;
int g_int_CoopCyclingCount;
ArrayList g_hInt_VersusMapIndexes;
ArrayList g_hBool_VersusNameHasTranslation;
int g_int_VersusCyclingCount;
ArrayList g_hInt_ScavengeMapIndexes;
ArrayList g_hBool_ScavengeNameHasTranslation;
int g_int_ScavengeCyclingCount;
ArrayList g_hInt_SurvivalMapIndexes;
ArrayList g_hBool_SurvivalNameHasTranslation;
int g_int_SurvivalCyclingCount;

void ACS_InitLists() {
	g_hInt_CoopMapIndexes = new ArrayList(1);
	// g_hBool_CoopNameHasTranslation = new ArrayList(1);
	g_int_CoopCyclingCount=0;
	g_hInt_VersusMapIndexes = new ArrayList(1);
	// g_hBool_VersusNameHasTranslation = new ArrayList(1);
	g_int_VersusCyclingCount=0;
	g_hInt_ScavengeMapIndexes = new ArrayList(1);
	// g_hBool_ScavengeNameHasTranslation = new ArrayList(1);
	g_int_ScavengeCyclingCount=0;
	g_hInt_SurvivalMapIndexes = new ArrayList(1);
	// g_hBool_SurvivalNameHasTranslation = new ArrayList(1);
	g_int_SurvivalCyclingCount=0;
}

void ACS_FreeLists() {
	delete g_hInt_CoopMapIndexes;
	delete g_hBool_CoopNameHasTranslation;
	delete g_hInt_VersusMapIndexes;
	delete g_hBool_VersusNameHasTranslation;
	delete g_hInt_ScavengeMapIndexes;
	delete g_hBool_ScavengeNameHasTranslation;
	delete g_hInt_SurvivalMapIndexes;
	delete g_hBool_SurvivalNameHasTranslation;
}

ArrayList ACS_GetMissionIndexList(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hInt_CoopMapIndexes;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hInt_VersusMapIndexes;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hInt_ScavengeMapIndexes;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hInt_SurvivalMapIndexes;
		}
	}
	
	return null;
}

ArrayList ACS_NewHasTranslationList(LMM_GAMEMODE gamemode) {
	ArrayList hasTranslationList = new ArrayList(1, ACS_GetMissionIndexList(gamemode).Length);
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			g_hBool_CoopNameHasTranslation = hasTranslationList;
			return hasTranslationList;
		}
		case LMM_GAMEMODE_VERSUS: {
			g_hBool_VersusNameHasTranslation = hasTranslationList;
			return hasTranslationList;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			g_hBool_ScavengeNameHasTranslation = hasTranslationList;
			return hasTranslationList;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			g_hBool_SurvivalNameHasTranslation = hasTranslationList;
			return hasTranslationList;
		}
	}
	
	return null;
}

ArrayList ACS_GetHasTranslationList(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_hBool_CoopNameHasTranslation;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_hBool_VersusNameHasTranslation;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_hBool_ScavengeNameHasTranslation;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_hBool_SurvivalNameHasTranslation;
		}
	}
	
	return null;
}

void ACS_SetCyclingCount(LMM_GAMEMODE gamemode, int count) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			g_int_CoopCyclingCount = count;
		}
		case LMM_GAMEMODE_VERSUS: {
			g_int_VersusCyclingCount = count;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			g_int_ScavengeCyclingCount = count;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			g_int_SurvivalCyclingCount = count;
		}
	}
}

// Used by the ACS
int ACS_GetCycledMissionCount(LMM_GAMEMODE gamemode) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			return g_int_CoopCyclingCount;
		}
		case LMM_GAMEMODE_VERSUS: {
			return g_int_VersusCyclingCount;
		}
		case LMM_GAMEMODE_SCAVENGE: {
			return g_int_ScavengeCyclingCount;
		}
		case LMM_GAMEMODE_SURVIVAL: {
			return g_int_SurvivalCyclingCount;
		}
	}
	
	return -1;
}

int ACS_GetMissionCount(LMM_GAMEMODE gamemode){
	ArrayList missionIndexList = ACS_GetMissionIndexList(gamemode);
	return missionIndexList.Length;
}

int ACS_GetFirstMapName(LMM_GAMEMODE gamemode, int cycleIndex, char[] mapname, int length){
	ArrayList missionIndexList = ACS_GetMissionIndexList(gamemode);
	if (missionIndexList == null) {
		return -1;
	}
	
	int iMission = missionIndexList.Get(cycleIndex);
	return LMM_GetMapName(gamemode, iMission, 0, mapname, length);
}

int ACS_GetLastMapName(LMM_GAMEMODE gamemode, int cycleIndex, char[] mapname, int length){
	ArrayList missionIndexList = ACS_GetMissionIndexList(gamemode);
	if (missionIndexList == null) {
		return -1;
	}
	
	int iMission = missionIndexList.Get(cycleIndex);
	int mapCount = LMM_GetNumberOfMaps(gamemode, iMission);
	return LMM_GetMapName(gamemode, iMission, mapCount-1, mapname, length);
}

bool ACS_GetLocalizedMissionName(LMM_GAMEMODE gamemode, int cycleIndex, int client, char[] localizedName, int length) {
	ArrayList hasTranslationList = ACS_GetMissionIndexList(gamemode);
	if (hasTranslationList == null)
		return false;
	
	char missionName[LEN_MISSION_NAME];
	int missionIndex = hasTranslationList.Get(cycleIndex);
	LMM_GetMissionName(gamemode, missionIndex, missionName, sizeof(missionName));
	if (ACS_GetHasTranslationList(gamemode).Get(cycleIndex, 0, true) > 0) {
		// Has translation
		Format(localizedName, length, "%T", missionName, client);
		return true;
	} else {
		strcopy(localizedName, length, missionName);
		return false;
	}
}

/*================================================================
#########       Mission Name Localization Parsing        #########
=================================================================*/
LMM_GAMEMODE g_MissionNameLocalization_Gamemode;
int g_MissionNameLocalization_State;
int g_MissionNameLocalization_UnknownCurLayer;
int g_MissionNameLocalization_UnknownPreState;
#define MNLS_UNKNOWN -1
#define MNLS_ROOT 0
#define MNLS_PHRASES 1
public SMCResult MissionNameLocalizationParser_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
	switch (g_MissionNameLocalization_State) {
		case MNLS_ROOT: {
			if(strcmp("Phrases", name, false)==0) {
				g_MissionNameLocalization_State = MNLS_PHRASES;
			} else {
				g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
				g_MissionNameLocalization_UnknownCurLayer = 1;
				g_MissionNameLocalization_State = MNLS_UNKNOWN;
			}
		}
		case MNLS_PHRASES: {
			int index = LMM_FindMissionIndexByName(g_MissionNameLocalization_Gamemode, name);
			if (index > -1) {
				ArrayList missionIndexList = ACS_GetMissionIndexList(g_MissionNameLocalization_Gamemode);
				index = missionIndexList.FindValue(index);
				ACS_GetHasTranslationList(g_MissionNameLocalization_Gamemode).Set(index, 1, 0, true);
			}
			
			// Do not traverse further
			g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
			g_MissionNameLocalization_UnknownCurLayer = 1;
			g_MissionNameLocalization_State = MNLS_UNKNOWN;
		}
		
		case MNLS_UNKNOWN: { // Traverse through unknown structures
			g_MissionNameLocalization_UnknownCurLayer++;
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionNameLocalizationParser_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	return SMCParse_Continue;
}

public SMCResult MissionNameLocalizationParser_EndSection(SMCParser parser) {
	switch (g_MissionNameLocalization_State) {
		case MNLS_PHRASES: {
			return SMCParse_Halt;
		}
		
		case MNLS_UNKNOWN: { // Traverse through unknown structures
			g_MissionNameLocalization_UnknownCurLayer--;
			if (g_MissionNameLocalization_UnknownCurLayer == 0) {
				g_MissionNameLocalization_State = g_MissionNameLocalization_UnknownPreState;
			}
		}
	}
	
	return SMCParse_Continue;
}

/*====================================================
#########       Mission Cycle Parsing        #########
====================================================*/
bool HasMissionCycleFile(LMM_GAMEMODE gamemode) {
	char path[PLATFORM_MAX_PATH];
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.coop.txt");
		}
		case LMM_GAMEMODE_VERSUS: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.versus.txt");
		}
		case LMM_GAMEMODE_SCAVENGE: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.scavenge.txt");
		}
		case LMM_GAMEMODE_SURVIVAL: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.survival.txt");
		}
		default: {
			return false;
		}
	}
	
	return FileExists(path);
}

File OpenMissionCycleFile(LMM_GAMEMODE gamemode, const char[] mode) {
	char path[PLATFORM_MAX_PATH];
	switch (gamemode) {
		case LMM_GAMEMODE_COOP: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.coop.txt");
		}
		case LMM_GAMEMODE_VERSUS: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.versus.txt");
		}
		case LMM_GAMEMODE_SCAVENGE: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.scavenge.txt");
		}
		case LMM_GAMEMODE_SURVIVAL: {
			BuildPath(Path_SM, path, sizeof(path), "configs/missioncycle.survival.txt");
		}
		default: {
			return null;
		}
	}
	
	return OpenFile(path, mode);
}

void PopulateDefaultMissionCycle(LMM_GAMEMODE gamemode, File missionCycleFile) {
	switch (gamemode) {
		case LMM_GAMEMODE_COOP, LMM_GAMEMODE_VERSUS: {
			missionCycleFile.WriteLine("L4D2C1");
			missionCycleFile.WriteLine("L4D2C2");
			missionCycleFile.WriteLine("L4D2C3");
			missionCycleFile.WriteLine("L4D2C4");
			missionCycleFile.WriteLine("L4D2C5");
			missionCycleFile.WriteLine("L4D2C6");
			missionCycleFile.WriteLine("L4D2C7");
			missionCycleFile.WriteLine("L4D2C8");
			missionCycleFile.WriteLine("L4D2C9");
			missionCycleFile.WriteLine("L4D2C10");
			missionCycleFile.WriteLine("L4D2C11");
			missionCycleFile.WriteLine("L4D2C12");
			missionCycleFile.WriteLine("L4D2C13");
		}
		case LMM_GAMEMODE_SCAVENGE: {
			missionCycleFile.WriteLine("L4D2C1");
			missionCycleFile.WriteLine("L4D2C2");
			missionCycleFile.WriteLine("L4D2C3");
			missionCycleFile.WriteLine("L4D2C4");
			missionCycleFile.WriteLine("L4D2C5");
			missionCycleFile.WriteLine("L4D2C6");
			missionCycleFile.WriteLine("L4D2C7");
			missionCycleFile.WriteLine("L4D2C8");
			missionCycleFile.WriteLine("L4D2C10");
			missionCycleFile.WriteLine("L4D2C11");
			missionCycleFile.WriteLine("L4D2C12");
		}
		case LMM_GAMEMODE_SURVIVAL: {
			missionCycleFile.WriteLine("L4D2C1");
			missionCycleFile.WriteLine("L4D2C2");
			missionCycleFile.WriteLine("L4D2C3");
			missionCycleFile.WriteLine("L4D2C4");
			missionCycleFile.WriteLine("L4D2C5");
			missionCycleFile.WriteLine("L4D2C6");
			missionCycleFile.WriteLine("L4D2C7");
			missionCycleFile.WriteLine("L4D2C8");
		}
	}
}

void LoadMissionList(LMM_GAMEMODE gamemode) {
	ArrayList missionIndexList = ACS_GetMissionIndexList(gamemode);

	char buffer[LEN_CFG_LINE];
	char buffer_split[3][LEN_CFG_SEGMENT];
	File missionCycleFile;
	char missionName[LEN_MISSION_NAME];
	char gamemodeName[LEN_GAMEMODE_NAME];
	LMM_GamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));
	
	// Create default mission cycle file if not existed yet
	if (!HasMissionCycleFile(gamemode)){
		missionCycleFile = OpenMissionCycleFile(gamemode, "w+");
		missionCycleFile.WriteLine("// Do not delete this line! format: <Mission Name(see txt files in missions.cache folder)>");
		PopulateDefaultMissionCycle(gamemode, missionCycleFile);
		missionCycleFile.WriteLine(CHAR_CYCLE_SEPARATOR);
		delete missionCycleFile;
	}
	
	missionCycleFile = OpenMissionCycleFile(gamemode, "r");
	missionCycleFile.ReadLine(buffer, sizeof(buffer));
	while(!missionCycleFile.EndOfFile() && missionCycleFile.ReadLine(buffer, sizeof(buffer))) {
		ReplaceString(buffer, sizeof(buffer), "\n", "");
		TrimString(buffer);
		if (StrContains(buffer, "//") == 0) {
			if (StrContains(buffer, CHAR_CYCLE_SEPARATOR) == 0) {
				ACS_SetCyclingCount(gamemode, missionIndexList.Length);
			}

			// Ignore comments
		} else {
			int numOfStrings = ExplodeString(buffer, ",", buffer_split, LEN_CFG_LINE, LEN_CFG_SEGMENT);
			TrimString(buffer_split[0]);	// Mission name
			if (numOfStrings > 1) {
				// For future use
			}
			
			int iMission = LMM_FindMissionIndexByName(gamemode, buffer_split[0]);
			if (iMission >= 0) {	// The mission is valid
				missionIndexList.Push(iMission);
			} else {
				LogError("Mission \"%s\" (Gamemode: %s) is not in the mission cache or no longer exists!\n", buffer_split[0], gamemodeName);
			}
		}
	}
	delete missionCycleFile;
	
	// Missions in missionIndexList are in the cyclic order and all valid
	// But l4d2_mission_manager may have some new missions
	// Then append new missions to the end of mission cycle and store the new mission cycle!
	missionCycleFile = OpenMissionCycleFile(gamemode, "a");
	for (int iMission=0; iMission<LMM_GetNumberOfMissions(gamemode); iMission++) {
		if (missionIndexList.FindValue(iMission) < 0) {
			// Found a new mission
			LMM_GetMissionName(gamemode, iMission, missionName, sizeof(missionName));
			LogMessage("Found new %s mission \"%s\" !", gamemodeName, missionName);
			missionCycleFile.WriteLine(missionName);
		}
	}
	
	delete missionCycleFile;
	// Mission list is complete and finalized
	
	// Check existance of default(English) localization
	char mapsPhrasesEnglish[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapsPhrasesEnglish, sizeof(mapsPhrasesEnglish), "translations/maps.phrases.txt");

	if (!FileExists(mapsPhrasesEnglish)) {
		// TO-DO:
	}
	
	LoadTranslations("maps.phrases");
	
	// Init array
	ACS_NewHasTranslationList(gamemode);
	SMCParser parser = SMC_CreateParser();
	parser.OnEnterSection = MissionNameLocalizationParser_NewSection;
	parser.OnKeyValue = MissionNameLocalizationParser_KeyValue;
	parser.OnLeaveSection = MissionNameLocalizationParser_EndSection;
 
	g_MissionNameLocalization_Gamemode = gamemode;
	g_MissionNameLocalization_State = MNLS_ROOT;
	
	SMCError err = parser.ParseFile(mapsPhrasesEnglish);
	if (err != SMCError_Okay) {
		LogError("An error occured while parsing maps.phrases.txt(English), code:%d", err);
	}
}

void DumpMissionInfo(int client, LMM_GAMEMODE gamemode) {
	char gamemodeName[LEN_GAMEMODE_NAME];
	LMM_GamemodeToString(gamemode, gamemodeName, sizeof(gamemodeName));

	ArrayList missionIndexList = ACS_GetMissionIndexList(gamemode);
	int missionCount = ACS_GetMissionCount(gamemode);
	
	char missionName[LEN_MISSION_NAME];
	char firstMap[LEN_MAP_FILENAME];
	char lastMap[LEN_MAP_FILENAME];
	char localizedName[LEN_MISSION_NAME];

	ReplyToCommand(client, "Gamemode = %s (%d missions, %d in cycle)", gamemodeName, missionCount, ACS_GetCycledMissionCount(gamemode));

	for (int cycleIndex=0; cycleIndex<missionCount; cycleIndex++) {
		int iMission = missionIndexList.Get(cycleIndex);
		int mapCount = LMM_GetNumberOfMaps(gamemode, iMission);
		LMM_GetMissionName(gamemode, iMission, missionName, sizeof(missionName));
		ACS_GetFirstMapName(gamemode, cycleIndex, firstMap, sizeof(firstMap));
		ACS_GetLastMapName(gamemode, cycleIndex, lastMap, sizeof(lastMap));
		if (ACS_GetLocalizedMissionName(gamemode, cycleIndex, client, localizedName, sizeof(localizedName))) {
			ReplyToCommand(client, "%d.%s (%s) = %s -> %s (%d maps)", cycleIndex+1 , localizedName, missionName, firstMap, lastMap, mapCount);
		} else {
			ReplyToCommand(client, "%d.%s <Missing localization> = %s -> %s (%d maps)", cycleIndex+1, missionName, firstMap, lastMap, mapCount);
		}
	}
	ReplyToCommand(client, "-------------------");
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("l4d2_mission_manager")) {
		SetFailState("l4d2_mission_manager was not found.");
	}
	
	ACS_InitLists();
	LoadMissionList(LMM_GAMEMODE_COOP);
	LoadMissionList(LMM_GAMEMODE_VERSUS);
	LoadMissionList(LMM_GAMEMODE_SCAVENGE);
	LoadMissionList(LMM_GAMEMODE_SURVIVAL);
	
	DumpMissionInfo(0, LMM_GAMEMODE_COOP);
	DumpMissionInfo(0, LMM_GAMEMODE_VERSUS);
	DumpMissionInfo(0, LMM_GAMEMODE_SCAVENGE);
	DumpMissionInfo(0, LMM_GAMEMODE_SURVIVAL);
}

public void OnPluginEnd() {
	ACS_FreeLists();
}

/*======================================================================================
##################            A C S   M A P   S T R I N G S            #################
========================================================================================
###                                                                                  ###
###      ***  EDIT THESE STRINGS TO CHANGE THE MAP ROTATIONS TO YOUR LIKING  ***     ###
###                                                                                  ###
========================================================================================
###                                                                                  ###
###       Note: The order these strings are stored is important, so make             ###
###             sure these match up or it will not work properly.                    ###
###                                                                                  ###
###       Notice, all of the strings corresponding with [1] in the array match.      ###
###                                                                                  ###
======================================================================================*/
#define LEN_MAPFILE 32
#define LEN_MAX_PATH 260

ArrayList g_hBoolCampaignHasTranslation;
ArrayList g_hStrCampaignName;
ArrayList g_hStrCampaignFirstMap;
ArrayList g_hStrCampaignLastMap;
int numberOfCyclingCampaignMap;

new Handle:g_hStrScavengeMap = INVALID_HANDLE;
new Handle:g_hStrScavengeName = INVALID_HANDLE;
new numberOfCyclingScavengeMap;

stock void SetupMapStrings() {	
	char buffer[LEN_CFG_LINE];
	char buffer_split[3][LEN_CFG_SEGMENT];

	g_hStrCampaignName = CreateArray(LEN_MISSION_NAME);
	g_hStrCampaignFirstMap = CreateArray(LEN_MAPFILE);
	g_hStrCampaignLastMap = CreateArray(LEN_MAPFILE);
	g_hStrScavengeMap = CreateArray(LEN_MAPFILE);
	g_hStrScavengeName = CreateArray(LEN_MISSION_NAME);

	ArrayList orderedCoopName = CreateArray(LEN_MISSION_NAME);
	ArrayList orderedCoopFirstMap = CreateArray(LEN_MAPFILE);
	ArrayList orderedCoopLastMap = CreateArray(LEN_MAPFILE);
	
	
	// Popup g_hStrCampaignName, g_hStrCampaignFirstMap and g_hStrCampaignLastMap with data from existing maps
	EnumerateMissions();
	
	File coopMapCycle;
	char campaignListFile[LEN_MAX_PATH];
	BuildPath(Path_SM, campaignListFile, sizeof(campaignListFile), "configs/maplist.txt");
	
	char coopNameBuffer[LEN_MISSION_NAME];
	char mapFileNameBuffer[LEN_MAPFILE];
	if(!FileExists(campaignListFile)) {
		coopMapCycle = OpenFile(campaignListFile, "w+");
		coopMapCycle.WriteLine("// Do not delete this line! format: <Mission Name(see txt files in missions.cache folder)>");
		coopMapCycle.WriteLine("L4D2C1");
		coopMapCycle.WriteLine("L4D2C2");
		coopMapCycle.WriteLine("L4D2C3");
		coopMapCycle.WriteLine("L4D2C4");
		coopMapCycle.WriteLine("L4D2C5");
		coopMapCycle.WriteLine("L4D2C6");
		coopMapCycle.WriteLine("L4D2C7");
		coopMapCycle.WriteLine("L4D2C8");
		coopMapCycle.WriteLine("L4D2C9");
		coopMapCycle.WriteLine("L4D2C10");
		coopMapCycle.WriteLine("L4D2C11");
		coopMapCycle.WriteLine("L4D2C12");
		coopMapCycle.WriteLine("L4D2C13");
		coopMapCycle.WriteLine("// 3-rd maps(Do not delete/modify this line!)");
		CloseHandle(coopMapCycle);
	}
	
	coopMapCycle = OpenFile(campaignListFile, "r");
	
	coopMapCycle.ReadLine(buffer, sizeof(buffer));
	while(!coopMapCycle.EndOfFile() && coopMapCycle.ReadLine(buffer, sizeof(buffer))) {
		ReplaceString(buffer, sizeof(buffer), "\n", "");
		TrimString(buffer);
		if (StrContains(buffer, "//") == 0) {
			if (StrContains(buffer, "// 3-rd maps(Do not delete/modify this line!)") == 0) {
				numberOfCyclingCampaignMap = orderedCoopName.Length;
			}

			// Ignore comments
		} else {
			int numOfStrings = ExplodeString(buffer, ",", buffer_split, LEN_CFG_LINE, LEN_CFG_SEGMENT);
			TrimString(buffer_split[0]);	// Map name
			if (numOfStrings > 1) {
			
			}
				
			int index = g_hStrCampaignName.FindString(buffer_split[0]);
			if (index>=0) {	// The mission exists
				orderedCoopName.PushString(buffer_split[0]);
				g_hStrCampaignFirstMap.GetString(index, mapFileNameBuffer, sizeof(mapFileNameBuffer));
				orderedCoopFirstMap.PushString(mapFileNameBuffer);
				g_hStrCampaignLastMap.GetString(index, mapFileNameBuffer, sizeof(mapFileNameBuffer));
				orderedCoopLastMap.PushString(mapFileNameBuffer);
			} else {
				PrintToServer("Map \"%s\" no longer exists!\n", buffer_split[0]);
			}
		}
	}
	CloseHandle(coopMapCycle);
		
	// Maps in orderedCoopName, orderedCoopFirstMap and orderedCoopLastMap are in the cyclic order and all valid
	// But g_hStrCampaignName may have some new maps
	// Then append new maps to the end of maplist.txt and map cycle!
	coopMapCycle = OpenFile(campaignListFile, "a");
	for (int index=0; index<g_hStrCampaignName.Length; index++) {
		g_hStrCampaignName.GetString(index, coopNameBuffer, sizeof(coopNameBuffer));
		if (orderedCoopName.FindString(coopNameBuffer) < 0) {
			// Found a new map
			PrintToServer("Found new map \"%s\" !\n", coopNameBuffer);
			
			orderedCoopName.PushString(coopNameBuffer);
			g_hStrCampaignFirstMap.GetString(index, mapFileNameBuffer, sizeof(mapFileNameBuffer));
			orderedCoopFirstMap.PushString(mapFileNameBuffer);
			g_hStrCampaignLastMap.GetString(index, mapFileNameBuffer, sizeof(mapFileNameBuffer));
			orderedCoopLastMap.PushString(mapFileNameBuffer);
				
			coopMapCycle.WriteLine("%s", coopNameBuffer);
		}
	}
	CloseHandle(coopMapCycle);
	
	// Free the temp arraylist, replace it with the sorted one
	delete g_hStrCampaignFirstMap;
	delete g_hStrCampaignLastMap;
	delete g_hStrCampaignName;
	g_hStrCampaignName = orderedCoopName;
	g_hStrCampaignFirstMap = orderedCoopFirstMap;
	g_hStrCampaignLastMap = orderedCoopLastMap;
	
	// Check existance for English localization texts
	LoadMissionTranslations();
	
	PrintToServer("MapCycle=%s", campaignListFile);	
	PrintToServer("Num of Campaign=%d, %d", numberOfCyclingCampaignMap, getNumberOfCampaign());
	Command_MapList(0, 0);

	//The following string variables are only for Scavenge
	addScavengeMap("c8m1_apartment", "Apartments");
	addScavengeMap("c8m5_rooftop", "Rooftop");
	addScavengeMap("c1m4_atrium", "Mall Atrium");
	addScavengeMap("c7m1_docks", "Brick Factory");
	addScavengeMap("c7m2_barge", "Barge");
	addScavengeMap("c6m1_riverbank", "Riverbank");
	addScavengeMap("c6m2_bedlam", "Underground");
	addScavengeMap("c6m3_port", "Port");
	addScavengeMap("c2m1_highway", "Motel");
	addScavengeMap("c3m1_plankcountry", "Plank Country");
	addScavengeMap("c4m1_milltown_a", "Milltown");
	addScavengeMap("c4m2_sugarmill_a", "Sugar Mill");
	addScavengeMap("c5m2_park", "Park");
	numberOfCyclingScavengeMap = getNumberOfScavengeMap();
}



addCampaignMap(const char[] firstMap, const char[] lastMap, const char[] name){
	PushArrayString(g_hStrCampaignFirstMap, firstMap);
	PushArrayString(g_hStrCampaignLastMap, lastMap);
	PushArrayString(g_hStrCampaignName, name);
}

int getNumberOfCampaign() {
	return GetArraySize(g_hStrCampaignFirstMap);
}

addScavengeMap(char[] map, char[] name) {
	PushArrayString(g_hStrScavengeMap, map);
	PushArrayString(g_hStrScavengeName, name);
}

String:getScavengeMap(index) {
	decl String:mapFileName[LEN_MAPFILE];
	GetArrayString(g_hStrScavengeMap, index, mapFileName, LEN_MAPFILE);
	return mapFileName;
}

String:getScavengeName(index) {
	decl String:mapName[LEN_MISSION_NAME];
	GetArrayString(g_hStrScavengeName, index, mapName, LEN_MISSION_NAME);
	return mapName;
}

int getNumberOfScavengeMap() {
	return GetArraySize(g_hStrScavengeMap);
}

#define MPR_UNKNOWN 0
#define MPR_COOP 1
// MissionParser results
int g_MissionParser_SupportedGameTypes;
char g_MissionParser_MissionName[LEN_MISSION_NAME];
char g_MissionParser_FirstMapName[LEN_MAPFILE];
char g_MissionParser_LastMapName[LEN_MAPFILE];
int g_MissionParser_LastMapID;
// MissionParser input and state variables
int g_MissionParser_UnknownCurLayer;
int g_MissionParser_UnknownPreState;
int g_MissionParser_State;
#define MPS_UNKNOWN -1
#define MPS_ROOT 0
#define MPS_MISSION 1
#define MPS_MODES 2
#define MPS_COOP 3
#define MPS_MAP 4
#define MPS_MAP_FIRST 5
#define MPS_MAP_LAST 6

public SMCResult MissionParser_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
	switch (g_MissionParser_State) {
		case MPS_ROOT: {
			if(strcmp("mission", name, false)==0) {
				g_MissionParser_State = MPS_MISSION;
			} else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MISSION: {
			if(strcmp("modes", name, false)==0) {
				g_MissionParser_State = MPS_MODES;
				g_MissionParser_SupportedGameTypes = 0;
			} else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MODES: {
			if(strcmp("coop", name, false)==0) {
				g_MissionParser_State = MPS_COOP;
				g_MissionParser_LastMapID = 1;
				g_MissionParser_SupportedGameTypes |= MPR_COOP;
			} else {
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_COOP: {
			int mapID = StringToInt(name);
			if (mapID > 0) {	// Valid map section
				if (mapID == 1) {
					g_MissionParser_State = MPS_MAP_FIRST;
				} else if (mapID > g_MissionParser_LastMapID) {
					g_MissionParser_State = MPS_MAP_LAST;
					g_MissionParser_LastMapID = mapID;
				} else {
					g_MissionParser_State = MPS_MAP;
				}
			} else {
				// Skip invalid sections
				g_MissionParser_UnknownPreState = g_MissionParser_State;
				g_MissionParser_UnknownCurLayer = 1;
				g_MissionParser_State = MPS_UNKNOWN;
				//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
			}
		}
		case MPS_MAP, MPS_MAP_FIRST, MPS_MAP_LAST: {
			// Do not traverse further
			g_MissionParser_UnknownPreState = g_MissionParser_State;
			g_MissionParser_UnknownCurLayer = 1;
			g_MissionParser_State = MPS_UNKNOWN;
			//PrintToServer("MissionParser_NewSection found an unknown structure: %s\n",name);
		}
		
		case MPS_UNKNOWN: { // Traverse through unknown structures
			g_MissionParser_UnknownCurLayer++;
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionParser_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	switch (g_MissionParser_State) {
		case MPS_MISSION: {
			if (strcmp("Name", key, false)==0) {
				strcopy(g_MissionParser_MissionName, LEN_MISSION_NAME, value);
			}
		}
		case MPS_MAP_FIRST: {
			if (strcmp("Map", key, false)==0) {
				strcopy(g_MissionParser_FirstMapName, LEN_MAPFILE, value);
				//PrintToServer("First Map: %s\n", g_MissionParser_FirstMapName);
			}
		}
		case MPS_MAP_LAST: {
			if (strcmp("Map", key, false)==0) {
				strcopy(g_MissionParser_LastMapName, LEN_MAPFILE, value);
				//PrintToServer("Last Map: %s\n", g_MissionParser_LastMapName);
			}
		}
		case MPS_MAP: {
			//PrintToServer("Map: %s\n", value);
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionParser_EndSection(SMCParser smc) {
	switch (g_MissionParser_State) {
		case MPS_MISSION: {
			g_MissionParser_State = MPS_ROOT;
			if (g_MissionParser_SupportedGameTypes & MPR_COOP) {
				if (g_MissionParser_LastMapID == 1) {
					// This mission only has one campaign
					addCampaignMap(g_MissionParser_FirstMapName, g_MissionParser_FirstMapName, g_MissionParser_MissionName);
				} else {
					addCampaignMap(g_MissionParser_FirstMapName, g_MissionParser_LastMapName, g_MissionParser_MissionName);
				}
			}
		}
		case MPS_MODES: {
			g_MissionParser_State = MPS_MISSION;
		}
		case MPS_COOP: {
			g_MissionParser_State = MPS_MODES;

		}
		case MPS_MAP, MPS_MAP_FIRST, MPS_MAP_LAST: {
			g_MissionParser_State = MPS_COOP;
		}
		
		case MPS_UNKNOWN: { // Traverse through unknown structures
			g_MissionParser_UnknownCurLayer--;
			if (g_MissionParser_UnknownCurLayer == 0) {
				g_MissionParser_State = g_MissionParser_UnknownPreState;
			}
		}
	}
	
	return SMCParse_Continue;
}

CopyFile(const char[] src, const char[] target) {
	File fileSrc;
	fileSrc = OpenFile(src, "rb", true, NULL_STRING);
	if (fileSrc != null) {
		File fileTarget;
		fileTarget = OpenFile(target, "wb", true, NULL_STRING);
		if (fileTarget != null) {
			int buffer[256]; // 256Bytes each time
			int numOfElementRead;
			while (!fileSrc.EndOfFile()){
				numOfElementRead = fileSrc.Read(buffer, 256, 1);
				fileTarget.Write(buffer, numOfElementRead, 1);
			}
			FlushFile(fileTarget);
			fileTarget.Close();
		}
		fileSrc.Close();
	}
}

CacheMissions() {
	DirectoryListing dirList;
	dirList = OpenDirectory("missions", true, NULL_STRING);

	if (dirList == null) {
        LogError("[SM] Plugin is not running! Could not locate mission folder");
        SetFailState("Could not locate mission folder");
	} else {	
		if (!DirExists("missions.cache")) {
			CreateDirectory("missions.cache", 777);
		}
		
		char missionFileName[LEN_MAX_PATH];
		FileType fileType;
		while(dirList.GetNext(missionFileName, LEN_MAX_PATH, fileType)) {
			if (fileType == FileType_File &&
			strcmp("credits.txt", missionFileName, false) != 0
			) {
				char missionSrc[LEN_MAX_PATH];
				char missionCache[LEN_MAX_PATH];
				missionSrc = "missions/";

				Format(missionSrc, LEN_MAX_PATH, "missions/%s", missionFileName);
				Format(missionCache, LEN_MAX_PATH, "missions.cache/%s", missionFileName);
				// PrintToServer("Cached mission file %s\n", missionFileName);
				
				if (!FileExists(missionCache, true, NULL_STRING)) {
					CopyFile(missionSrc, missionCache);
				}
			}
			
		}
		
		CloseHandle(dirList);
	}
}

EnumerateMissions() {
	CacheMissions();
	
	DirectoryListing dirList;
	dirList = OpenDirectory("missions.cache", true, NULL_STRING);
	
	if (dirList == null) {
	
	} else {
		// Create the parser
		SMCParser parser = SMC_CreateParser();
		parser.OnEnterSection = MissionParser_NewSection;
		parser.OnLeaveSection = MissionParser_EndSection;
		parser.OnKeyValue = MissionParser_KeyValue;
	
		char missionCache[LEN_MAX_PATH];
		char missionFileName[LEN_MAX_PATH];
		FileType fileType;
		while(dirList.GetNext(missionFileName, LEN_MAX_PATH, fileType)) {
			if (fileType == FileType_File) {
				Format(missionCache, LEN_MAX_PATH, "missions.cache/%s", missionFileName);
				
				// Process the mission file				
				g_MissionParser_State = MPS_ROOT;
				SMCError err = parser.ParseFile(missionCache);
				if (err != SMCError_Okay) {
					LogError("An error occured while parsing %s, code:%d\n", missionCache, err);
				}
			}
		}
		
		CloseHandle(dirList);	
	}
	//PrintToServer("QuQ = %t\n", "#L4D360UI_CampaignName_C11", LANG_SERVER);
}

/*===================================================
#########       Localization support        #########
===================================================*/
public SMCResult MissionNameLocalization_NewSection(SMCParser smc, const char[] name, bool opt_quotes) {
	switch (g_MissionNameLocalization_State) {
		case MNLS_ROOT: {
			if(strcmp("Phrases", name, false)==0) {
				g_MissionNameLocalization_State = MNLS_PHRASES;
			} else {
				g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
				g_MissionNameLocalization_UnknownCurLayer = 1;
				g_MissionNameLocalization_State = MNLS_UNKNOWN;
			}
		}
		case MNLS_PHRASES: {
			int index = g_hStrCampaignName.FindString(name);
			if (index > -1) {
				g_hBoolCampaignHasTranslation.Set(index, 1, 0, true);
			}
			
			// Do not traverse further
			g_MissionNameLocalization_UnknownPreState = g_MissionNameLocalization_State;
			g_MissionNameLocalization_UnknownCurLayer = 1;
			g_MissionNameLocalization_State = MNLS_UNKNOWN;
		}
		
		case MNLS_UNKNOWN: { // Traverse through unknown structures
			g_MissionNameLocalization_UnknownCurLayer++;
		}
	}
	
	return SMCParse_Continue;
}

public SMCResult MissionNameLocalization_KeyValue(SMCParser smc, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	return SMCParse_Continue;
}

public SMCResult MissionNameLocalization_EndSection(Handle parser) {
	switch (g_MissionNameLocalization_State) {
		case MNLS_PHRASES: {
			return SMCParse_Halt;
		}
		
		case MNLS_UNKNOWN: { // Traverse through unknown structures
			g_MissionNameLocalization_UnknownCurLayer--;
			if (g_MissionNameLocalization_UnknownCurLayer == 0) {
				g_MissionNameLocalization_State = g_MissionNameLocalization_UnknownPreState;
			}
		}
	}
	
	return SMCParse_Continue;
}

stock void LoadMissionTranslations() {
	char mapsPhrasesEnglish[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapsPhrasesEnglish, sizeof(mapsPhrasesEnglish), "translations/maps.phrases.txt");

	if (!FileExists(mapsPhrasesEnglish)) {
		// TO-DO:
	}
	
	LoadTranslations("maps.phrases");
	
	int numOfMissions = getNumberOfCampaign();

	// Init array
	g_hBoolCampaignHasTranslation = CreateArray(1, numOfMissions); 
	for (int i=0; i<numOfMissions; i++) {
		g_hBoolCampaignHasTranslation.Set(i, 0, 0, true);
	}
	
	SMCParser parser = SMC_CreateParser();
	parser.OnEnterSection = MissionNameLocalization_NewSection;
	parser.OnKeyValue = MissionNameLocalization_KeyValue;
	parser.OnLeaveSection = MissionNameLocalization_EndSection;
	
	g_MissionNameLocalization_State = MNLS_ROOT;
	SMCError err = parser.ParseFile(mapsPhrasesEnglish);
	if (err != SMCError_Okay) {
		LogError("An error occured while parsing maps.phrases.txt(English), code:%d\n", err);
	}
}

stock bool getLocalizedMissionName(int index, char[] localizedName, int length, int client) {
	char missionName[LEN_MISSION_NAME];
	g_hStrCampaignName.GetString(index, missionName, LEN_MISSION_NAME);
	if (g_hBoolCampaignHasTranslation.Get(index, 0, true) > 0) {
		// Has translation
		Format(localizedName, length, "%T", missionName, client);
		return true;
	} else {
		strcopy(localizedName, length, missionName);
		return false;
	}
}

/*======================================================================================
#####################             P L U G I N   I N F O             ####################
======================================================================================*/

public Plugin myinfo = {
	name = "Automatic Campaign Switcher (ACS)",
	author = "Rikka0w0, Chris Pringle",
	description = "Automatically switches to the next campaign when the previous campaign is over",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=308708"
}

/*======================================================================================
#################             O N   P L U G I N   S T A R T            #################
======================================================================================*/

public OnPluginStart() {
	LoadTranslations("acs.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
	
	decl String: game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false) && !StrEqual(game_name, "left4dead2", false)) {
		SetFailState("Use this in Left 4 Dead or Left 4 Dead 2 only.");
	}

	SetupMapStrings();
	
	//Create custom console variables
	CreateConVar("acs_version", PLUGIN_VERSION, "Version of Automatic Campaign Switcher (ACS) on this server", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVar_VotingEnabled = CreateConVar("acs_voting_system_enabled", "1", "Enables players to vote for the next map or campaign [0 = DISABLED, 1 = ENABLED]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCVar_VoteWinnerSoundEnabled = CreateConVar("acs_voting_sound_enabled", "1", "Determines if a sound plays when a new map is winning the vote [0 = DISABLED, 1 = ENABLED]", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hCVar_VotingAdMode = CreateConVar("acs_voting_ad_mode", "3", "Sets how to advertise voting at the start of the map [0 = DISABLED, 1 = HINT TEXT, 2 = CHAT TEXT, 3 = OPEN VOTE MENU]\n * Note: This is only displayed once during a finale or scavenge map *", FCVAR_PLUGIN, true, 0.0, true, 3.0);
	g_hCVar_VotingAdDelayTime = CreateConVar("acs_voting_ad_delay_time", "10.0", "Time, in seconds, to wait after survivors leave the start area to advertise voting as defined in acs_voting_ad_mode\n * Note: If the server is up, changing this in the .cfg file takes two map changes before the change takes place *", FCVAR_PLUGIN, true, 0.1, false);
	g_hCVar_NextMapAdMode = CreateConVar("acs_next_map_ad_mode", "2", "Sets how the next campaign/map is advertised during a finale or scavenge map [0 = DISABLED, 1 = HINT TEXT, 2 = CHAT TEXT]", FCVAR_PLUGIN, true, 0.0, true, 2.0);
	g_hCVar_NextMapAdInterval = CreateConVar("acs_next_map_ad_interval", "60.0", "The time, in seconds, between advertisements for the next campaign/map on finales and scavenge maps", FCVAR_PLUGIN, true, 60.0, false);
	g_hCVar_MaxFinaleFailures = CreateConVar("acs_max_coop_finale_failures", "0", "The amount of times the survivors can fail a finale in Coop before it switches to the next campaign [0 = INFINITE FAILURES]", FCVAR_PLUGIN, true, 0.0, false);
	g_hCVar_ChMapAnnounceMode = CreateConVar("acs_chmap_announce_mode", "3", "Controls how to advertise the \"!chmap\" command, 0 - disabled, 1 - chat, 2 - hint text, 3 - both");
	g_hCVar_ChMapBroadcastInterval =  CreateConVar("acs_chmap_broadcast_interval", "180.0", "controls the frequency of the \"!chmap\" advertisement, in second.");	
	
	//Hook console variable changes
	HookConVarChange(g_hCVar_VotingEnabled, CVarChange_Voting);
	HookConVarChange(g_hCVar_VoteWinnerSoundEnabled, CVarChange_NewVoteWinnerSound);
	HookConVarChange(g_hCVar_VotingAdMode, CVarChange_VotingAdMode);
	HookConVarChange(g_hCVar_VotingAdDelayTime, CVarChange_VotingAdDelayTime);
	HookConVarChange(g_hCVar_NextMapAdMode, CVarChange_NewMapAdMode);
	HookConVarChange(g_hCVar_NextMapAdInterval, CVarChange_NewMapAdInterval);
	HookConVarChange(g_hCVar_MaxFinaleFailures, CVarChange_MaxFinaleFailures);
	HookConVarChange(g_hCVar_ChMapAnnounceMode, CVarChange_ChMapBroadcast);
	HookConVarChange(g_hCVar_ChMapBroadcastInterval, CVarChange_ChMapBroadcast);
	
	AutoExecConfig(true, "acs");
	
	//Hook the game events
	//HookEvent("round_start", Event_RoundStart);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("finale_win", Event_FinaleWin);
	HookEvent("scavenge_match_finished", Event_ScavengeMapFinished);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	
	//Register custom console commands
	RegConsoleCmd("mapvote", MapVote);
	RegConsoleCmd("mapvotes", DisplayCurrentVotes);
	RegConsoleCmd("sm_chmap", Command_ChangeMapVote);
	RegConsoleCmd("sm_changemapvote", Command_ChangeMapVote);
	RegConsoleCmd("sm_acs_maps", Command_MapList);
}

public void OnConfigsExecuted() {
	MakeChMapBroadcastTimer();
}

void MakeChMapBroadcastTimer() {
	if (g_hTimer_Broadcast != null) {
		KillTimer(g_hTimer_Broadcast);
		g_hTimer_Broadcast = null;
	}

	if(g_hCVar_ChMapAnnounceMode.IntValue != 0)
		g_hTimer_Broadcast = CreateTimer(g_hCVar_ChMapBroadcastInterval.FloatValue, Timer_WelcomeMessage, INVALID_HANDLE, TIMER_REPEAT);
}

public Action Timer_WelcomeMessage(Handle timer, any param) {
	PrintToChatAll("\x03[ACS]\x01 %t: \x04!chmap\x01 %t.", "Announce", "Announce2");
}

/*======================================================================================
##########           C V A R   C A L L B A C K   F U N C T I O N S           ###########
======================================================================================*/
public CVarChange_ChMapBroadcast(Handle:hCVar, const String:strOldValue[], const String:strNewValue[]) {
	MakeChMapBroadcastTimer();
}

//Callback function for the cvar for voting system
public void CVarChange_Voting(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//If the value was changed, then set it and display a message to the server and players
	if (StringToInt(strNewValue) == 1) {
		PrintToServer("[ACS] ConVar changed: Voting System ENABLED");
		PrintToChatAll("[ACS] ConVar changed: Voting System ENABLED");
	} else {
		PrintToServer("[ACS] ConVar changed: Voting System DISABLED");
		PrintToChatAll("[ACS] ConVar changed: Voting System DISABLED");
	}
}

//Callback function for enabling or disabling the new vote winner sound
public void CVarChange_NewVoteWinnerSound(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//If the value was changed, then set it and display a message to the server and players
	if (StringToInt(strNewValue) == 1) {
		PrintToServer("[ACS] ConVar changed: New vote winner sound ENABLED");
		PrintToChatAll("[ACS] ConVar changed: New vote winner sound ENABLED");
	} else {
		PrintToServer("[ACS] ConVar changed: New vote winner sound DISABLED");
		PrintToChatAll("[ACS] ConVar changed: New vote winner sound DISABLED");
	}
}

//Callback function for how the voting system is advertised to the players at the beginning of the round
public void CVarChange_VotingAdMode(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//If the value was changed, then set it and display a message to the server and players
	switch(StringToInt(strNewValue)) {
		case 0:	{
			PrintToServer("[ACS] ConVar changed: Voting display mode: DISABLED");
			PrintToChatAll("[ACS] ConVar changed: Voting display mode: DISABLED");
		}
		case 1:	{
			PrintToServer("[ACS] ConVar changed: Voting display mode: HINT TEXT");
			PrintToChatAll("[ACS] ConVar changed: Voting display mode: HINT TEXT");
		}
		case 2:	{
			PrintToServer("[ACS] ConVar changed: Voting display mode: CHAT TEXT");
			PrintToChatAll("[ACS] ConVar changed: Voting display mode: CHAT TEXT");
		}
		case 3:	{
			PrintToServer("[ACS] ConVar changed: Voting display mode: OPEN VOTE MENU");
			PrintToChatAll("[ACS] ConVar changed: Voting display mode: OPEN VOTE MENU");
		}
	}
}

//Callback function for the cvar for voting display delay time
public void CVarChange_VotingAdDelayTime(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//Get the new value
	float fDelayTime = StringToFloat(strNewValue);
	
	//If the value was changed, then set it and display a message to the server and players
	if (fDelayTime > 0.1)
	{
		PrintToServer("[ACS] ConVar changed: Voting advertisement delay time changed to %f", fDelayTime);
		PrintToChatAll("[ACS] ConVar changed: Voting advertisement delay time changed to %f", fDelayTime);
	}
	else
	{
		PrintToServer("[ACS] ConVar changed: Voting advertisement delay time changed to 0.1");
		PrintToChatAll("[ACS] ConVar changed: Voting advertisement delay time changed to 0.1");
	}
}

//Callback function for how ACS and the next map is advertised to the players during a finale
public CVarChange_NewMapAdMode(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//If the value was changed, then set it and display a message to the server and players
	switch(StringToInt(strNewValue)) {
		case 0:	{
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: DISABLED");
			PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: DISABLED");
		}
		case 1:	{
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: HINT TEXT");
			PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: HINT TEXT");
		}
		case 2:	{
			PrintToServer("[ACS] ConVar changed: Next map advertisement display mode: CHAT TEXT");
			PrintToChatAll("[ACS] ConVar changed: Next map advertisement display mode: CHAT TEXT");
		}
	}
}

//Callback function for the interval that controls the timer that advertises ACS and the next map
public CVarChange_NewMapAdInterval(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//Get the new value
	float fDelayTime = StringToFloat(strNewValue);
	
	//If the value was changed, then set it and display a message to the server and players
	if (fDelayTime > 60.0) {
		PrintToServer("[ACS] ConVar changed: Next map advertisement interval changed to %f", fDelayTime);
		PrintToChatAll("[ACS] ConVar changed: Next map advertisement interval changed to %f", fDelayTime);
	} else {
		PrintToServer("[ACS] ConVar changed: Next map advertisement interval changed to 60.0");
		PrintToChatAll("[ACS] ConVar changed: Next map advertisement interval changed to 60.0");
	}
}

//Callback function for the amount of times the survivors can fail a coop finale map before ACS switches
public CVarChange_MaxFinaleFailures(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;
	
	//Get the new value
	int iMaxFailures = StringToInt(strNewValue);
	
	//If the value was changed, then set it and display a message to the server and players
	if (iMaxFailures > 0) {
		PrintToServer("[ACS] ConVar changed: Max Coop finale failures changed to %f", iMaxFailures);
		PrintToChatAll("[ACS] ConVar changed: Max Coop finale failures changed to %f", iMaxFailures);
	} else {
		PrintToServer("[ACS] ConVar changed: Max Coop finale failures changed to 0");
		PrintToChatAll("[ACS] ConVar changed: Max Coop finale failures changed to 0");
	}
}
/*======================================================================================
#################                     E V E N T S                      #################
======================================================================================*/

public OnMapStart()
{
	//Execute config file
	//decl String:strFileName[64];
	//Format(strFileName, sizeof(strFileName), "Automatic_Campaign_Switcher_%s", PLUGIN_VERSION);
	//AutoExecConfig(true, strFileName);
	
	//Set all the menu handles to invalid
	CleanUpMenuHandles();
	
	//Set the game mode
	g_iGameMode = LMM_GetCurrentGameMode();
	
	//Precache sounds
	PrecacheSound(SOUND_NEW_VOTE_START);
	PrecacheSound(SOUND_NEW_VOTE_WINNER);
	
	
	//Display advertising for the next campaign or map
	if(g_hCVar_NextMapAdMode.IntValue != DISPLAY_MODE_DISABLED)
		CreateTimer(g_hCVar_NextMapAdInterval.FloatValue, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	
	g_iRoundEndCounter = 0;			//Reset the round end counter on every map start
	g_iCoopFinaleFailureCount = 0;	//Reset the amount of Survivor failures
	g_bFinaleWon = false;			//Reset the finale won variable
	ResetAllVotes();				//Reset every player's vote
}

//Event fired when the Survivors leave the start area
public Action Event_PlayerLeftStartArea(Handle hEvent, const char[] strName, bool bDontBroadcast) {	
	if(g_hCVar_VotingEnabled.BoolValue == true && OnFinaleOrScavengeMap() == true)
		CreateTimer(g_hCVar_VotingAdDelayTime.FloatValue, Timer_DisplayVoteAdToAll, _, TIMER_FLAG_NO_MAPCHANGE);
	
	return Plugin_Continue;
}

//Event fired when the Round Ends
public Action:Event_RoundEnd(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	// PrintToChatAll("\x03[ACS]\x04 Event_RoundEnd");
	//Check to see if on a finale map, if so change to the next campaign after two rounds
	if(g_iGameMode == GAMEMODE_VERSUS && OnFinaleOrScavengeMap() == true)
	{
		g_iRoundEndCounter++;
		
		if(g_iRoundEndCounter >= 4)	//This event must be fired on the fourth time Round End occurs.
			CheckMapForChange();	//This is because it fires twice during each round end for
									//some strange reason, and versus has two rounds in it.
	}
	//If in Coop and on a finale, check to see if the surviors have lost the max amount of times
	else if(g_iGameMode == GAMEMODE_COOP && OnFinaleOrScavengeMap() == true &&
			g_hCVar_MaxFinaleFailures.IntValue > 0 && g_bFinaleWon == false &&
			++g_iCoopFinaleFailureCount >= g_hCVar_MaxFinaleFailures.IntValue)
	{
		CheckMapForChange();
	}
	
	return Plugin_Continue;
}

//Event fired when a finale is won
public Action:Event_FinaleWin(Handle:hEvent, const String:strName[], bool:bDontBroadcast) {
	// PrintToChatAll("\x03[ACS]\x04 Event_FinaleWin");
	g_bFinaleWon = true;	//This is used so that the finale does not switch twice if this event
							//happens to land on a max failure count as well as this
	
	//Change to the next campaign
	if(g_iGameMode == GAMEMODE_COOP)
		CheckMapForChange();
	
	return Plugin_Continue;
}

//Event fired when a map is finished for scavenge
public Action:Event_ScavengeMapFinished(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	//Change to the next Scavenge map
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		ChangeScavengeMap();
	
	return Plugin_Continue;
}

//Event fired when a player disconnects from the server
public Action:Event_PlayerDisconnect(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(iClient	< 1)
		return Plugin_Continue;
	
	//Reset the client's votes
	g_bClientVoted[iClient] = false;
	g_iClientVote[iClient] = -1;
	
	//Check to see if there is a new vote winner
	SetTheCurrentVoteWinner();
	
	return Plugin_Continue;
}


/*======================================================================================
#################             A C S   C H A N G E   M A P              #################
======================================================================================*/

//Check to see if the current map is a finale, and if so, switch to the next campaign
CheckMapForChange() {
	char strCurrentMap[LEN_MAPFILE];
	GetCurrentMap(strCurrentMap,sizeof(strCurrentMap));					//Get the current map from the game

	char firstMap[LEN_MAPFILE];
	char localizedName[LEN_MISSION_NAME];
	for(new iMapIndex = 0; iMapIndex < getNumberOfCampaign(); iMapIndex++) {
	
		g_hStrCampaignLastMap.GetString(iMapIndex, firstMap, sizeof(firstMap));	// Use "firstMap" to store the name of the last map
		if(StrEqual(strCurrentMap, firstMap, false) == true) {
			for (int client = 1; client <= MaxClients; client++) {
				if (IsClientInGame(client)) {
					getLocalizedMissionName(iMapIndex, localizedName, sizeof(localizedName), client);
					PrintToChat(client, "\x03[ACS] \x05 %t: \x04%s", "Campaign finished", localizedName);
				}
			}
			
			//Check to see if someone voted for a campaign, if so, then change to the winning campaign
			if(g_hCVar_VotingEnabled.BoolValue && g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0) {
				g_hStrCampaignFirstMap.GetString(g_iWinningMapIndex, firstMap, sizeof(firstMap));
				if(IsMapValid(firstMap) == true) {
					for (int client = 1; client <= MaxClients; client++) {
						if (IsClientInGame(client)) {
							getLocalizedMissionName(g_iWinningMapIndex, localizedName, sizeof(localizedName), client);
							PrintToChat(client, "\x03[ACS] \x05 %t: \x04%s", "Switching map to the vote winner", localizedName);
						}
					}
					
					if(g_iGameMode == GAMEMODE_VERSUS)
						CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, g_iWinningMapIndex);
					else if(g_iGameMode == GAMEMODE_COOP)
						CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, g_iWinningMapIndex);
					
					return;
				}
				else
					LogError("Error: %s is an invalid map name, attempting normal map rotation.", firstMap);
			}
			
			//If no map was chosen in the vote, then go with the automatic map rotation
			
			if(iMapIndex >= numberOfCyclingCampaignMap - 1)	//Check to see if it reaches/exceed the end of official map list
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0
			
			g_hStrCampaignFirstMap.GetString(iMapIndex + 1, firstMap, sizeof(firstMap));
			if(IsMapValid(firstMap) == true) {
				for (int client = 1; client <= MaxClients; client++) {
					if (IsClientInGame(client)) {
						getLocalizedMissionName(iMapIndex + 1, localizedName, sizeof(localizedName), client);
						PrintToChat(client, "\x03[ACS] \x05 %t: \x04%s", "Switching campaign to", localizedName);
					}
				}
				
				if(g_iGameMode == GAMEMODE_VERSUS)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_VERSUS, Timer_ChangeCampaign, iMapIndex + 1);
				else if(g_iGameMode == GAMEMODE_COOP)
					CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, iMapIndex + 1);
			}
			else
				LogError("Error: %s is an invalid map name, unable to switch map.", firstMap);
			
			return;
		}
	}
}

//Change to the next scavenge map
ChangeScavengeMap() {
	//Check to see if someone voted for a map, if so, then change to the winning map
	if(g_hCVar_VotingEnabled.BoolValue && g_iWinningMapVotes > 0 && g_iWinningMapIndex >= 0)
	{
		if(IsMapValid(getScavengeMap(g_iWinningMapIndex)) == true) {
			PrintToChatAll("\x03[ACS] \x05 %t: \x04%s", "Switching map to the vote winner", getScavengeName(g_iWinningMapIndex));
			
			CreateTimer(WAIT_TIME_BEFORE_SWITCH_SCAVENGE, Timer_ChangeScavengeMap, g_iWinningMapIndex);
			
			return;
		}
		else
			LogError("Error: %s is an invalid map name, attempting normal map rotation.", getScavengeMap(g_iWinningMapIndex));
	}
	
	//If no map was chosen in the vote, then go with the automatic map rotation
	
	decl String:strCurrentMap[LEN_MAPFILE];
	GetCurrentMap(strCurrentMap, LEN_MAPFILE);					//Get the current map from the game
	
	//Go through all maps and to find which map index it is on, and then switch to the next map
	for(new iMapIndex = 0; iMapIndex < getNumberOfScavengeMap(); iMapIndex++)
	{
		if(StrEqual(strCurrentMap, getScavengeMap(iMapIndex), false) == true)
		{
			if(iMapIndex >= numberOfCyclingScavengeMap - 1)//Check to see if its the end of the array
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0 
			
			//Make sure the map is valid before changing and displaying the message
			if(IsMapValid(getScavengeMap(iMapIndex + 1)) == true) {
				PrintToChatAll("\x03[ACS] \x05 %t: \x04%s", "Switching campaign to", getScavengeName(iMapIndex + 1));
				
				CreateTimer(WAIT_TIME_BEFORE_SWITCH_SCAVENGE, Timer_ChangeScavengeMap, iMapIndex + 1);
			}
			else
				LogError("Error: %s is an invalid map name, unable to switch map.", getScavengeMap(iMapIndex + 1));
			
			return;
		}
	}
}

//Change campaign to its index
public Action Timer_ChangeCampaign(Handle timer, any iCampaignIndex) {
	char firstMap[LEN_MAPFILE];
	g_hStrCampaignFirstMap.GetString(iCampaignIndex, firstMap, sizeof(firstMap));
	ForceChangeLevel(firstMap, "ACS action"); //Change the campaign
	
	return Plugin_Stop;
}

//Change scavenge map to its index
public Action:Timer_ChangeScavengeMap(Handle:timer, any:iMapIndex)
{
	ServerCommand("changelevel %s", getScavengeMap(iMapIndex));			//Change the map
	
	return Plugin_Stop;
}

/*======================================================================================
#################            A C S   A D V E R T I S I N G             #################
======================================================================================*/

public Action:Timer_AdvertiseNextMap(Handle:timer, any:iMapIndex)
{
	//If next map advertising is enabled, display the text and start the timer again
	if(g_hCVar_NextMapAdMode.IntValue != DISPLAY_MODE_DISABLED)
	{
		DisplayNextMapToAll();
		CreateTimer(g_hCVar_NextMapAdInterval.FloatValue, Timer_AdvertiseNextMap, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Stop;
}

DisplayNextMapToAll() {
	char localizedName[LEN_MISSION_NAME];
	//If there is a winner to the vote display the winner if not display the next map in rotation
	if(g_iWinningMapIndex >= 0) {
		if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_HINT) {		
			//Display the map that is currently winning the vote to all the players using hint text
			if(g_iGameMode == GAMEMODE_SCAVENGE) {
				PrintHintTextToAll("The next map is currently %s", getScavengeName(g_iWinningMapIndex));
			} else {
				for (int client = 1; client <= MaxClients; client++) {
					if (IsClientInGame(client)) {
						getLocalizedMissionName(g_iWinningMapIndex, localizedName, sizeof(localizedName), client);
						PrintHintText(client, "The next campaign is currently %s", localizedName);
					}
				}
			}
		} else if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_CHAT)	{
			//Display the map that is currently winning the vote to all the players using chat text
			if(g_iGameMode == GAMEMODE_SCAVENGE) {
				PrintToChatAll("\x03[ACS] \x05The next map is currently \x04%s", getScavengeName(g_iWinningMapIndex));
			} else {
				for (int client = 1; client <= MaxClients; client++) {
					if (IsClientInGame(client)) {
						getLocalizedMissionName(g_iWinningMapIndex, localizedName, sizeof(localizedName), client);
						PrintToChat(client, "The next campaign is currently %s", localizedName);
					}
				}
			}
		}
	} else {
		char strCurrentMap[LEN_MAPFILE];
		GetCurrentMap(strCurrentMap, LEN_MAPFILE);					//Get the current map from the game
		
		if(g_iGameMode == GAMEMODE_SCAVENGE)
		{
			//Go through all maps and to find which map index it is on, and then switch to the next map
			for(int iMapIndex = 0; iMapIndex < getNumberOfScavengeMap(); iMapIndex++)
			{
				if(StrEqual(strCurrentMap, getScavengeMap(iMapIndex), false) == true)
				{
					if(iMapIndex == getNumberOfScavengeMap() - 1)	//Check to see if its the end of the array
						iMapIndex = -1;								//If so, start the array over by setting to -1 + 1 = 0
					
					//Display the next map in the rotation in the appropriate way
					if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_HINT)
						PrintHintTextToAll("The next map is currently %s", getScavengeName(iMapIndex + 1));
					else if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_CHAT)
						PrintToChatAll("\x03[ACS] \x05The next map is currently \x04%s", getScavengeName(iMapIndex + 1));
				}
			}
		}
		else
		{
			//Go through all maps and to find which map index it is on, and then switch to the next map
			char lastMap[LEN_MAPFILE];
			for(int iMapIndex = 0; iMapIndex < getNumberOfCampaign(); iMapIndex++) {
				g_hStrCampaignLastMap.GetString(iMapIndex, lastMap, sizeof(lastMap));
				if(StrEqual(strCurrentMap, lastMap, false) == true)
				{
					if(iMapIndex == getNumberOfCampaign() - 1)	//Check to see if its the end of the array
						iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0
					
					//Display the next map in the rotation in the appropriate way
					for (int client = 1; client <= MaxClients; client++) {
						if (IsClientInGame(client)) {
							getLocalizedMissionName(iMapIndex + 1, localizedName, sizeof(localizedName), client);
							
							if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_HINT)
								PrintHintText(client, "The next campaign is currently %s", localizedName);
							else if(g_hCVar_NextMapAdMode.IntValue == DISPLAY_MODE_CHAT)
								PrintToChat(client, "\x03[ACS] \x05The next campaign is currently \x04%s", localizedName);
						}
					}

				}
			}
		}
	}
}

/*======================================================================================
#################              V O T I N G   S Y S T E M               #################
======================================================================================*/

/*======================================================================================
################             P L A Y E R   C O M M A N D S              ################
======================================================================================*/

//Command that a player can use to vote/revote for a map/campaign
public Action MapVote(iClient, args) {
	if(g_hCVar_VotingEnabled.BoolValue == false) {
		PrintToChat(iClient, "\x03[ACS] \x05Voting has been disabled on this server.");
		return;
	}
	
	if(OnFinaleOrScavengeMap() == false)
	{
		PrintToChat(iClient, "\x03[ACS] \x05Voting is only enabled on a Scavenge or finale map.");
		return;
	}
	
	//Open the vote menu for the client if they arent using the server console
	if(iClient < 1)
		PrintToServer("You cannot vote for a map from the server console, use the in-game chat");
	else
		VoteMenuDraw(iClient);
}

//Command that a player can use to see the total votes for all maps/campaigns
public Action DisplayCurrentVotes(iClient, args) {
	char localizedName[LEN_MISSION_NAME];
	if(g_hCVar_VotingEnabled.BoolValue == false) {
		ReplyToCommand(iClient, "\x03[ACS] \x05Voting has been disabled on this server.");
		return;
	}
	
	if(OnFinaleOrScavengeMap() == false)
	{
		ReplyToCommand(iClient, "\x03[ACS] \x05Voting is only enabled on a Scavenge or finale map.");
		return;
	}
	
	decl iPlayer, iMap, iNumberOfMaps;
	
	//Get the total number of maps for the current game mode
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		iNumberOfMaps = getNumberOfScavengeMap();
	else
		iNumberOfMaps = getNumberOfCampaign();
		
	//Display to the client the current winning map
	if(g_iWinningMapIndex != -1) {
		if(g_iGameMode == GAMEMODE_SCAVENGE) {
			ReplyToCommand(iClient, "\x03[ACS] \x05Currently winning the vote: \x04%s", getScavengeName(g_iWinningMapIndex));
		} else {
			getLocalizedMissionName(g_iWinningMapIndex, localizedName, sizeof(localizedName), iClient);
			ReplyToCommand(iClient, "\x03[ACS] \x05Currently winning the vote: \x04%s", localizedName);
		}
	}
	else
		ReplyToCommand(iClient, "\x03[ACS] \x05No one has voted yet.");
	
	//Loop through all maps and display the ones that have votes
	new iMapVotes[iNumberOfMaps];
	
	for(iMap = 0; iMap < iNumberOfMaps; iMap++)
	{
		iMapVotes[iMap] = 0;
		
		//Tally votes for the current map
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;
		
		//Display this particular map and its amount of votes it has to the client
		if(iMapVotes[iMap] > 0)
		{
			if(g_iGameMode == GAMEMODE_SCAVENGE) {
				ReplyToCommand(iClient, "\x04          %s: \x05%d votes", getScavengeName(iMap), iMapVotes[iMap]);
			} else {
				getLocalizedMissionName(iMap, localizedName, sizeof(localizedName), iClient);
				ReplyToCommand(iClient, "\x04          %s: \x05%d votes", localizedName, iMapVotes[iMap]);
			}
				
		}
	}
}

/*======================================================================================
###############                   V O T E   M E N U                       ##############
======================================================================================*/

//Timer to show the menu to the players if they have not voted yet
public Action Timer_DisplayVoteAdToAll(Handle hTimer, any iData) {
	if(g_hCVar_VotingEnabled.BoolValue == false || OnFinaleOrScavengeMap() == false)
		return Plugin_Stop;
	
	for(int iClient = 1;iClient <= MaxClients; iClient++) {
		if(
			g_bClientShownVoteAd[iClient] == false && g_bClientVoted[iClient] == false &&
			IsClientInGame(iClient) == true && IsFakeClient(iClient) == false
		){
			switch(g_hCVar_VotingAdMode.IntValue) {
				case DISPLAY_MODE_MENU: VoteMenuDraw(iClient);
				case DISPLAY_MODE_HINT: PrintHintText(iClient, "To vote for the next map, type: !mapvote\nTo see all the votes, type: !mapvotes");
				case DISPLAY_MODE_CHAT: PrintToChat(iClient, "\x03[ACS] \x05To vote for the next map, type: \x04!mapvote\n           \x05To see all the votes, type: \x04!mapvotes");
			}
			
			g_bClientShownVoteAd[iClient] = true;
		}
	}
	
	return Plugin_Stop;
}

//Draw the menu for voting
public Action:VoteMenuDraw(iClient)
{
	if(iClient < 1 || IsClientInGame(iClient) == false || IsFakeClient(iClient) == true)
		return Plugin_Handled;
	
	//Create the menu
	g_hMenu_Vote[iClient] = CreateMenu(VoteMenuHandler);
	
	//Give the player the option of not choosing a map
	AddMenuItem(g_hMenu_Vote[iClient], "option1", "I Don't Care");
	
	//Populate the menu with the maps in rotation for the corresponding game mode
	if(g_iGameMode == GAMEMODE_SCAVENGE)
	{
		SetMenuTitle(g_hMenu_Vote[iClient], "Vote for the next map\n ");

		for(new iCampaign = 0; iCampaign < getNumberOfScavengeMap(); iCampaign++)
			AddMenuItem(g_hMenu_Vote[iClient], getScavengeName(iCampaign), getScavengeName(iCampaign));
	}
	else
	{
		SetMenuTitle(g_hMenu_Vote[iClient], "Vote for the next campaign\n ");

		char localizedName[LEN_MISSION_NAME];
		for(new iCampaign = 0; iCampaign < getNumberOfCampaign(); iCampaign++) {
			getLocalizedMissionName(iCampaign, localizedName, sizeof(localizedName), iClient);
			AddMenuItem(g_hMenu_Vote[iClient], "Useless Info", localizedName);
		}
	}
	
	//Add an exit button
	SetMenuExitButton(g_hMenu_Vote[iClient], true);
	
	//And finally, show the menu to the client
	DisplayMenu(g_hMenu_Vote[iClient], iClient, MENU_TIME_FOREVER);
	
	//Play a sound to indicate that the user can vote on a map
	EmitSoundToClient(iClient, SOUND_NEW_VOTE_START);
	
	return Plugin_Handled;
}

//Handle the menu selection the client chose for voting
public VoteMenuHandler(Handle hMenu, MenuAction maAction, iClient, iItemNum) {
	if(maAction == MenuAction_Select) 
	{
		g_bClientVoted[iClient] = true;
		
		//Set the players current vote
		if(iItemNum == 0)
			g_iClientVote[iClient] = -1;
		else
			g_iClientVote[iClient] = iItemNum - 1;
			
		//Check to see if theres a new winner to the vote
		SetTheCurrentVoteWinner();
		
		//Display the appropriate message to the voter
		char localizedName[LEN_MISSION_NAME];
		if(iItemNum == 0) {
			PrintHintText(iClient, "You did not vote.\nTo vote, type: !mapvote");
		} else if(g_iGameMode == GAMEMODE_SCAVENGE) {
			PrintHintText(iClient, "You voted for %s.\n- To change your vote, type: !mapvote\n- To see all the votes, type: !mapvotes", getScavengeName(iItemNum - 1));
		} else {
			getLocalizedMissionName(iItemNum - 1, localizedName, sizeof(localizedName), iClient);
			PrintHintText(iClient, "You voted for %s.\n- To change your vote, type: !mapvote\n- To see all the votes, type: !mapvotes", localizedName);
		}
	}
}

//Resets all the menu handles to invalid for every player, until they need it again
CleanUpMenuHandles()
{
	for(new iClient = 0; iClient <= MAXPLAYERS; iClient++)
	{
		if(g_hMenu_Vote[iClient] != INVALID_HANDLE)
		{
			CloseHandle(g_hMenu_Vote[iClient]);
			g_hMenu_Vote[iClient] = INVALID_HANDLE;
		}
	}
}

/*======================================================================================
#########       M I S C E L L A N E O U S   V O T E   F U N C T I O N S        #########
======================================================================================*/

//Resets all the votes for every player
void ResetAllVotes() {
	for(int iClient = 1; iClient <= MaxClients; iClient++) {
		g_bClientVoted[iClient] = false;
		g_iClientVote[iClient] = -1;
		
		//Reset so that the player can see the advertisement
		g_bClientShownVoteAd[iClient] = false;
	}
	
	//Reset the winning map to NULL
	g_iWinningMapIndex = -1;
	g_iWinningMapVotes = 0;
}

//Tally up all the votes and set the current winner
void SetTheCurrentVoteWinner() {
	int iPlayer, iNumberOfMaps;
	
	//Store the current winnder to see if there is a change
	int iOldWinningMapIndex = g_iWinningMapIndex;
	
	//Get the total number of maps for the current game mode
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		iNumberOfMaps = getNumberOfScavengeMap();
	else
		iNumberOfMaps = getNumberOfCampaign();
	
	//Loop through all maps and get the highest voted map	
	decl iMapVotes[iNumberOfMaps];
	int iCurrentlyWinningMapVoteCounts = 0;
	bool bSomeoneHasVoted = false;
	
	for(int iMap = 0; iMap < iNumberOfMaps; iMap++) {
		iMapVotes[iMap] = 0;
		
		//Tally votes for the current map
		for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			if(g_iClientVote[iPlayer] == iMap)
				iMapVotes[iMap]++;
		
		//Check if there is at least one vote, if so set the bSomeoneHasVoted to true
		if(bSomeoneHasVoted == false && iMapVotes[iMap] > 0)
			bSomeoneHasVoted = true;
		
		//Check if the current map has more votes than the currently highest voted map
		if(iMapVotes[iMap] > iCurrentlyWinningMapVoteCounts)
		{
			iCurrentlyWinningMapVoteCounts = iMapVotes[iMap];
			
			g_iWinningMapIndex = iMap;
			g_iWinningMapVotes = iMapVotes[iMap];
		}
	}
	
	//If no one has voted, reset the winning map index and votes
	//This is only for if someone votes then their vote is removed
	if(bSomeoneHasVoted == false)
	{
		g_iWinningMapIndex = -1;
		g_iWinningMapVotes = 0;
	}
	
	//If the vote winner has changed then display the new winner to all the players
	if(g_iWinningMapIndex > -1 && iOldWinningMapIndex != g_iWinningMapIndex)
	{
		//Send sound notification to all players
		if(g_hCVar_VoteWinnerSoundEnabled.BoolValue == true)
			for(iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
				if(IsClientInGame(iPlayer) == true && IsFakeClient(iPlayer) == false)
					EmitSoundToClient(iPlayer, SOUND_NEW_VOTE_WINNER);
		
		char localizedName[LEN_MISSION_NAME];
		//Show message to all the players of the new vote winner
		if(g_iGameMode == GAMEMODE_SCAVENGE) {
			PrintToChatAll("\x03[ACS] \x04%s \x05is now winning the vote.", getScavengeName(g_iWinningMapIndex));
		} else {
			//Display the next map in the rotation in the appropriate way
			for (int client = 1; client <= MaxClients; client++) {
				if (IsClientInGame(client)) {
					getLocalizedMissionName(g_iWinningMapIndex, localizedName, sizeof(localizedName), client);
					PrintToChat(client,"\x03[ACS] \x04%s \x05%t.", localizedName, "Map is now winning the vote");
				}
			}
		}
	}
}

//Check if the current map is the last in the campaign if not in the Scavenge game mode
bool OnFinaleOrScavengeMap() {
	if(g_iGameMode == GAMEMODE_SCAVENGE)
		return true;
	
	if(g_iGameMode == GAMEMODE_SURVIVAL)
		return false;
	
	char strCurrentMap[LEN_MAPFILE];
	GetCurrentMap(strCurrentMap, LEN_MAPFILE);			//Get the current map from the game
	
	char lastMap[LEN_MAPFILE];
	//Run through all the maps, if the current map is a last campaign map, return true
	for(int iMapIndex = 0; iMapIndex < getNumberOfCampaign(); iMapIndex++) {
		g_hStrCampaignLastMap.GetString(iMapIndex, lastMap, sizeof(lastMap));
		if(StrEqual(strCurrentMap, lastMap, false) == true)
			return true;
	}
	
	return false;
}

/*======================================================================================
##########                                 Map Votes                        ###########
======================================================================================*/
#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"
public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Display) { // Localize title
		char title[4];
		menu.GetTitle(title, sizeof(title));
		
		char localizedMapName[LEN_MISSION_NAME];
	 	char buffer[255];
		int index = StringToInt(title);
		getLocalizedMissionName(index, localizedMapName, sizeof(localizedMapName), param1);
		Format(buffer, sizeof(buffer), "%T", "Change Map To", param1, localizedMapName);

		Panel panel = view_as<Panel>(param2);
		panel.SetTitle(buffer);
	} else if (action == MenuAction_DisplayItem) {
		char display[64];
		menu.GetItem(param2, "", 0, _, display, sizeof(display));
	 
	 	if (strcmp(display, "No") == 0 || strcmp(display, "Yes") == 0)
	 	{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", display, param1);

			return RedrawMenuItem(buffer);
		}
	} else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes) {
		PrintToChatAll("[SM] %t", "No Votes Cast");
	} else if (action == MenuAction_VoteEnd) {
		char item[16];
		float percent, limit;
		int votes, totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		menu.GetItem(param1, item, sizeof(item), _, "", 0);
		
		if (strcmp(item, VOTE_NO) == 0 && param1 == 1) {
			votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
		}
		
		percent = float(votes) / float(totalVotes);
		
		ConVar limitConVar = FindConVar("sm_vote_map");
		if (limitConVar == null) {
			limit = 0.6;
		} else {
			limit = limitConVar.FloatValue;
		}
		
		// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
		if (strcmp(item, VOTE_NO) == 0 && param1 == 1) {
			LogAction(-1, -1, "Vote failed.");
			PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
		} else {
			PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
			
			char title[4];
			menu.GetTitle(title, sizeof(title));
			
			char localizedMapName[LEN_MISSION_NAME];
			int index = StringToInt(title);
			getLocalizedMissionName(index, localizedMapName, sizeof(localizedMapName), param1);
			PrintToChatAll("[SM] %t", "Changing map", localizedMapName);
			
			CreateTimer(WAIT_TIME_BEFORE_SWITCH_COOP, Timer_ChangeCampaign, index);
		}
	} else if (action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

public Action Command_ChangeMapVote(int iClient, int args) {
	if(iClient < 1 || IsClientInGame(iClient) == false || IsFakeClient(iClient) == true)
		return Plugin_Handled;
	
	//Create the menu
	Menu menuVoteCampaign = CreateMenu(VoteCampaignMenuHandler, MenuAction_Select | MenuAction_DisplayItem | MenuAction_End);
	
	//Populate the menu with the maps in rotation for the corresponding game mode
	menuVoteCampaign.SetTitle("%T", "Choose a Map", iClient);
	
	for(int iCampaign = 0; iCampaign < getNumberOfCampaign(); iCampaign++) {
		menuVoteCampaign.AddItem("Useless Info", "Name to be translated");
	}
	
	//Add an exit button
	menuVoteCampaign.ExitButton = true;
	
	//And finally, show the menu to the client
	menuVoteCampaign.Display(iClient, MENU_TIME_FOREVER);
	
	//Play a sound to indicate that the user can vote on a map
	EmitSoundToClient(iClient, SOUND_NEW_VOTE_START);
	
	return Plugin_Handled;	
}

public int VoteCampaignMenuHandler(Menu menu, MenuAction action, int client, int item) {
	char localizedName[LEN_MISSION_NAME];	
	// Change the map to the selected item.
	if(action == MenuAction_Select)	{
		if (item < 0) {
			// Not a valid map option
			return 0;
		}

		getLocalizedMissionName(item, localizedName, sizeof(localizedName), client);		
		switch (g_hCVar_ChMapAnnounceMode.IntValue) {
			case 1: 
			{
				PrintToChatAll("\x05[SM] \x04 %t : \x05 %s", "Voting for map", localizedName);
			}
			case 2: 
			{
				PrintHintTextToAll("\x05[SM] \x04 %t : \x05 %s", "Voting for map", localizedName);
			}
			case 3: 
			{
				PrintToChatAll("\x05[SM] \x04 %t : \x05 %s", "Voting for map", localizedName);
				PrintHintTextToAll("\x05[SM] \x04 %t : \x05 %s", "Voting for map", localizedName);
			}
			default: 
			{
				// Nothing to display
			}
		}
		
		if (IsVoteInProgress()) {
			ReplyToCommand(client, "[SM] %t", "Vote in Progress");
			return 0;
		} else {
			char stringInt[4];
			IntToString(item, stringInt, sizeof(stringInt));
			
			Menu menuVote = CreateMenu(Handler_VoteCallback, MENU_ACTIONS_ALL);
			
			menuVote.SetTitle("%s", stringInt);
			menuVote.AddItem(VOTE_YES, "Yes");
			menuVote.AddItem(VOTE_NO, "No");
			menuVote.ExitButton = false;
			menuVote.DisplayVoteToAll(MENU_TIME_FOREVER);	
		}	
	} else if (action == MenuAction_DisplayItem) {
		getLocalizedMissionName(item, localizedName, sizeof(localizedName), client);		
		RedrawMenuItem(localizedName);
	} else if (action == MenuAction_End) {
		delete menu;
	}
	
	return 0;
}

public Action Command_MapList(int iClient, int args) {
	char mapName[LEN_MISSION_NAME];
	char firstMap[LEN_MAPFILE];
	char lastMap[LEN_MAPFILE];
	char localizedName[LEN_MISSION_NAME];
	for(int iCampaign = 0; iCampaign < getNumberOfCampaign(); iCampaign++) {
		g_hStrCampaignName.GetString(iCampaign, mapName, sizeof(mapName));
		g_hStrCampaignFirstMap.GetString(iCampaign, firstMap, sizeof(firstMap));
		g_hStrCampaignLastMap.GetString(iCampaign, lastMap, sizeof(lastMap));
		if (getLocalizedMissionName(iCampaign, localizedName, sizeof(localizedName), iClient)) {
			ReplyToCommand(iClient, "%d.%s(%s) = %s -> %s", iCampaign + 1, localizedName, mapName, firstMap, lastMap);
		} else {
			ReplyToCommand(iClient, "%d.%s<Missing localization> = %s -> %s ", iCampaign + 1, mapName, firstMap, lastMap);
		}
	}

	return Plugin_Handled;	
}