# L4D2 Mission Manager & Automatic Campaign Switcher

The "L4D2 Mission Manager" (`l4d2_mission_manager`) provides a set of APIs which allows other plugins to access the mission/map list: e.g. which map comes after the current one. Coop, versus, scavenge and survival modes are currently supported. \
Automatic Campaign Switcher, or "ACS", was written as an easy way to keep the Left4Dead 2 default map rotation going on a server without people being booted because the vote to restart a campaign was not passed. 
ACS also includes a voting system in which people can vote for their favorite campaign/map on a finale or scavenge map. The winning campaign/map will become the next map the server loads. \
There is also an admin menu plugin (`l4d2_mm_adminmenu`), which adds a map switching option to the "Server Commands" of the "Admin Menu".

The AlliedModder pages are available: \
[L4D2 Mission Manager](http://forums.alliedmods.net/showthread.php?t=308725) 
and [Automatic Campaign Switcher](https://forums.alliedmods.net/showthread.php?t=308708).

## Installation
An easy-to-deploy zip file (`acs_ready_to_go.zip`) can be found in the [AlliedModder page of Automatic Campaign Switcher](https://forums.alliedmods.net/showthread.php?t=308708). \
Drop all smx files into the `"left4dead2/addons/sourcemod/plugins"` folder, then copy the "translations" and "scripting" folder to merge with the existing folders in `"left4dead2/addons/sourcemod"`.

## Function Description
Function description and usage of "Automatic Campaign Switcher" should refer to the [AlliedModder page of Automatic Campaign Switcher](https://forums.alliedmods.net/showthread.php?t=308708). \
"L4D2 Mission Manager" itself does not affect the game play. There is only one command available: "sm_lmm_list", which lists installed maps on the server. "sm_lmm_list" can have one of the following as paramter:
`coop, versus, scavenge, survival or invalid`. The last one prints all maps/missions with error, helps server admins to locate them.Sample usage and output:
```sm_lmm_list coop
Gamemode = coop (14 missions)

1. #L4D360UI_CampaignName_C1 (4 maps)
;c1m1_hotel
;c1m2_streets
;c1m3_mall
;c1m4_atrium

2. #L4D360UI_CampaignName_C2 (5 maps)
;c2m1_highway
;c2m2_fairgrounds
;c2m3_coaster
;c2m4_barns
;c2m5_concert

3. #L4D360UI_CampaignName_C3 (4 maps)
;c3m1_plankcountry
;c3m2_swamp
;c3m3_shantytown
;c3m4_plantation

4. #L4D360UI_CampaignName_C4 (5 maps)
;c4m1_milltown_a
;c4m2_sugarmill_a
;c4m3_sugarmill_b
;c4m4_milltown_b
;c4m5_milltown_escape

5. #L4D360UI_CampaignName_C5 (5 maps)
;c5m1_waterfront
;c5m2_park
;c5m3_cemetery
;c5m4_quarter
;c5m5_bridge

6. #L4D360UI_CampaignName_C6 (3 maps)
;c6m1_riverbank
;c6m2_bedlam
;c6m3_port

7. #L4D360UI_CampaignName_C7 (3 maps)
;c7m1_docks
;c7m2_barge
;c7m3_port

8. #L4D360UI_CampaignName_C8 (5 maps)
;c8m1_apartment
;c8m2_subway
;c8m3_sewers
;c8m4_interior
;c8m5_rooftop

9. #L4D360UI_CampaignName_C9 (2 maps)
;c9m1_alleys
;c9m2_lots

10. #L4D360UI_CampaignName_C10 (5 maps)
;c10m1_caves
;c10m2_drainage
;c10m3_ranchhouse
;c10m4_mainstreet
;c10m5_houseboat

11. #L4D360UI_CampaignName_C11 (5 maps)
;c11m1_greenhouse
;c11m2_offices
;c11m3_garage
;c11m4_terminal
;c11m5_runway

12. #L4D360UI_CampaignName_C12 (5 maps)
;c12m1_hilltop
;c12m2_traintunnel
;c12m3_bridge
;c12m4_barn
;c12m5_cornfield

13. #L4D360UI_CampaignName_C13 (4 maps)
;c13m1_alpinecreek
;c13m2_southpinestream
;c13m3_memorialbridge
;c13m4_cutthroatcreek

14. #L4D360UI_CampaignName_C14 (2 maps)
;c14m1_junkyard
;c14m2_lighthouse
```

---

During server starting-up, "L4D2 Mission Manager" scans for installed maps/missions and copies all text files in the mission "virtual folder" into mission.cache folder. (mission folder is "virtual" because it is not located on the real filesystem, instead, those text files are in VPK files and mapped to a in-game filesystem by the Source engine)

## API Usage
If you want to use this API, you should include "l4d2_mission_manager.inc" in your sp file:
```#include <l4d2_mission_manager>```

Do __NOT__ call any LMM APIs in OnPluginStart(), due to the chance that your plugin is loaded prior to LMM.	LMM APIs become available in OnAllPluginsLoaded().

## Notes
During our test, some maps' mission file have problems:
1. Questionable Ethics 1 & 2 dont have "}" at the end of the mission file. Altough it can be loaded by "L4D2 Mission Manager", it is an error that should be corrected by the map author.
1. Crashbandicoot2 have zero-index for its survival and scavenge mode, and these two modes are ignored by LMM. __The first map should always have an index of 1!__

## FAQ
1. The "mission.cache" folder is empty\
Due to a bug in previous version of "l4d2_mission_manager", on Linux, the "mission.cache" folder does not have the correct permission. The latest version has fixed this bug.
If upgrading "l4d2_mission_manager" does not solve the problem, try "chmod 777 mission.cache" and restart your server.
1. Some addon maps are not shown in ACS\
Some addon maps have malformed mission information file, which cannot be parsed by the Sourcemod's parser.\
Common problems include: missing "}" at the end of section, using "0" instead of "1" for index of the first map. \The map author is responsible for problem.\
Type `sm_lmm_list invalid` in the server console and it should give you a list of maps that cannot be recognized.
You should manually fix those files in the "mission.cache" folder. Changes to existing files in the "mission.cache" folder will never be overwriten by the plugin.
