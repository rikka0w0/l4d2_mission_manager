# L4D2 Mission Manager

This plugin provides a set of APIs which allows other plugins to access the mission/map list: e.g. which map comes after the current one. Coop, versus, scavenge and survival modes are currently supported.

The AlliedModder page is available [here](http://forums.alliedmods.net/showthread.php?t=308725).

## Installation
Drop l4d2_mission_manager.smx into the "left4dead2/addons/sourcemod/plugins" folder

## Function Description
This plugin itself does not affect the game play. There is only one command available: "sm_lmm_list", which lists installed maps on the server. "sm_lmm_list" can have one of the following as paramter:
`coop, versus, scavenge, survival or invalid`. The last one prints all maps/missions with error, helps server admins to locate them.Sample usage and output:
```sm_lmm_list coop
Gamemode = coop (17 missions)

1. L4D2C1 (4 maps)
, c1m1_hotel
, c1m2_streets
, c1m3_mall
, c1m4_atrium
2. L4D2C10 (5 maps)
, c10m1_caves
, c10m2_drainage
, c10m3_ranchhouse
, c10m4_mainstreet
, c10m5_houseboat
3. L4D2C11 (5 maps)
, c11m1_greenhouse
, c11m2_offices
, c11m3_garage
, c11m4_terminal
, c11m5_runway
4. L4D2C12 (5 maps)
, C12m1_hilltop
, C12m2_traintunnel
, C12m3_bridge
, C12m4_barn
, C12m5_cornfield
5. L4D2C13 (4 maps)
, c13m1_alpinecreek
, c13m2_southpinestream
, c13m3_memorialbridge
, c13m4_cutthroatcreek
6. L4D2C2 (5 maps)
, c2m1_highway
, c2m2_fairgrounds
, c2m3_coaster
, c2m4_barns
, c2m5_concert
7. L4D2C3 (4 maps)
, c3m1_plankcountry
, c3m2_swamp
, c3m3_shantytown
, c3m4_plantation
8. L4D2C4 (5 maps)
, c4m1_milltown_a
, c4m2_sugarmill_a
, c4m3_sugarmill_b
, c4m4_milltown_b
, c4m5_milltown_escape
9. L4D2C5 (5 maps)
, c5m1_waterfront
, c5m2_park
, c5m3_cemetery
, c5m4_quarter
, c5m5_bridge
10. L4D2C6 (3 maps)
, c6m1_riverbank
, c6m2_bedlam
, c6m3_port
11. L4D2C7 (3 maps)
, c7m1_docks
, c7m2_barge
, c7m3_port
12. L4D2C8 (5 maps)
, c8m1_apartment
, c8m2_subway
, c8m3_sewers
, c8m4_interior
, c8m5_rooftop
13. L4D2C9 (2 maps)
, c9m1_alleys
, c9m2_lots
14. CrashBandicootTheReturn (6 maps)
, CrashBandicootMap1
, CrashBandicootMap2
, CrashBandicootMap3
, CrashBandicootMap4
, CrashBandicootMap5
, CrashBandicootMap6
15. l4d2CrashBandicoot2 (4 maps)
, l4d2_CrashBandicootvs1
, l4d2_CrashBandicootvs2
, l4d2_CrashBandicootvs3
, l4d2_CrashBandicootvs4
16. QuestionableEthicsAlphaTest (5 maps)
, qe2_ep1
, qe2_ep2
, qe2_ep3
, qe2_ep4
, qe2_ep5
17. QuestionableEthics (4 maps)
, qe_1_cliche
, qe_2_remember_me
, qe_3_unorthodox_paradox
, qe_4_ultimate_test
-------------------
```

During the loading of server, the plugins scans for installed maps/missions and copies all text files in the mission "virtual folder" into mission.cache folder. (mission folder is "virtual" because it is not located on the real filesystem, instead, those text files are in VPK files and mapped to a in-game filesystem by the Source engine)

## API Usage
If you want to use this API, you should include l4d2_mission_manager.inc in your sp file:
```#include <l4d2_mission_manager>```

Do __NOT__ call any LMM APIs in OnPluginStart(), due to the chance that your plugin is loaded prior to LMM.	LMM APIs become available in OnAllPluginsLoaded().

## Notes
During our test, some maps' mission file have problems:
1. Questionable Ethics 1 & 2 dont have "}" at the end of the mission file. Altough it can be loaded by LMM, it is an error that should be corrected by the map author.
1. Crashbandicoot2 have zero-index for its survival and scavenge mode, and these two modes are ignored by LMM. __The first map should always have an index of 1!__