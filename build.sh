#!/bin/bash
# Assumes Sourcemod 1.10+ and 64 bit Linux OS (or WSL)

SRC_DIR="./scripting/"
OUTPUT_DIR="./plugins"
SRCMOD_ROOT="../"
SRCMOD_COMPILER="spcomp64"

test -e $OUTPUT_DIR || mkdir $OUTPUT_DIR

SRCMOD_COMPILE="$(cd $SRCMOD_ROOT ; pwd)/scripting/$SRCMOD_COMPILER"
SRCMOD_INC="$(cd $SRCMOD_ROOT ; pwd)/scripting/include"
SRCMOD_COMPILE_CMD="$SRCMOD_COMPILE -i$SRCMOD_INC -D$(cd $SRC_DIR ; pwd) "
SRCMOD_OUTPUT_DIR="$(cd $OUTPUT_DIR ; pwd)"

echo "Sourcemod.include = $SRCMOD_INC"
echo "Sourcemod.compiler = $SRCMOD_COMPILE"
echo "Sourcemod.compile_cmd = $SRCMOD_COMPILE_CMD"
echo "Sourcemod.output_dir = $SRCMOD_OUTPUT_DIR"

srcmod_compile () {
	sourcefile=$1
	echo -e "\nCompiling $sourcefile ..."
	smxfile="`echo $sourcefile | sed -e 's/\.sp$/\.smx/'`"
	$SRCMOD_COMPILE_CMD $sourcefile -o$SRCMOD_OUTPUT_DIR/$smxfile
}

srcmod_compile acs.sp
srcmod_compile l4d2_changelevel.sp
srcmod_compile l4d2_mission_manager.sp
srcmod_compile l4d2_mm_adminmenu.sp