#!/bin/bash

# Defining versions and authors
SCRIPT_VERSION='0.1'

# Defining echo colors
# http://misc.flogisoft.com/bash/tip_colors_and_formatting
COLOR_NORMAL="\e[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[36m"

echo
echo "MP3 order tool ${COLOR_BLUE}$SCRIPT_VERSION${COLOR_NORMAL}"

# Testing whether mp3info command is available
which mp3info > /dev/null;
if [ $? -ne 0 ]
then
    echo -e "${COLOR_RED}mp3info is not installed, aborting${COLOR_NORMAL}"
    exit -1
fi


# Removing non MP3/FLAC files
echo "Removing files other that MP3 and FLAC..."
NON_MP3_NOR_FLAC_FILES=`find ./*/ -type f -not -iname "*.mp3" -not -iname "*.flac" -printf "%p|"`
COUNTER=0;
while read -d "|" NON_MP3_NOR_FLAC_FILE
do
    rm "$NON_MP3_NOR_FLAC_FILE" && COUNTER=$((COUNTER+1))
done <<< $NON_MP3_NOR_FLAC_FILES

echo -e "${COLOR_GREEN}Removed ${COLOR_YELLOW}$COUNTER${COLOR_GREEN} non MP3/FLAC files${COLOR_NORMAL}"
echo


# Note! File directories should not contain | character
DIRECTORIES=`find ./*/ -type d -printf "%p|"`

# Statistics counter
DIRECTORY_RENAME_COUNTER=0
FILE_RENAME_COUNTER=0;

# The main loop
while read -d "|" ADIRECTORY
do
    # TODO Check if the directory is album directory (at least 3 files having the same album name)

    ADIRECTORY_REPRESENTATIVE_FILE=''

    MP3S_IN_DIRECTORY=`find "$ADIRECTORY" -type f -iname "*.mp3" -printf "%p|"`

    while read -d "|" MP3; do
        if [ "$MP3" != "" ]
        then
          DIRNAME=`dirname "$MP3"`

          # TODO Add 0 at the beginigng
          DESIRED_FILENAME=`mp3info -p "%n - %t" "$MP3"` > /dev/null

          # Checking whether the MP3 file contains valid tags
          if [ $? -eq 0 ]
          then
              if [[ $DESIRED_FILENAME == *"invalid encoding"* ]]
              then
                  echo -r "${COLOR_YELLOW}valid encoding inside $MP3${COLOR_NORMAL}"
              else
                  # Appending 0 to songs having number less than 10
                  if [ "${DESIRED_FILENAME:1:1}" == ' ' ]
                  then
                    DESIRED_FILENAME="0$DESIRED_FILENAME"
                  fi

                  # Prepending file dirname
                  DESIRED_FILENAME="$DESIRED_FILENAME.mp3"

                  # Old filename
                  MP3_FILENAME=`basename "$MP3"`

                  # Rename file only if the newly generated filename is different
                  if [ "$DESIRED_FILENAME" != "$MP3_FILENAME" ];
                  then
                      mv "$MP3" "$DIRNAME/$DESIRED_FILENAME" && FILE_RENAME_COUNTER=$((FILE_RENAME_COUNTER+1))
                  fi

                  # Picking one valid file
                  ADIRECTORY_REPRESENTATIVE_FILE="$DIRNAME/$DESIRED_FILENAME"
              fi
            fi
        fi
    done  <<< $MP3S_IN_DIRECTORY # Done reading mp3s

    # If there were any music files inside the directory
    if [ "$ADIRECTORY_REPRESENTATIVE_FILE" != '' ]
    then
        # Renaming directories
        DIRNAME=`dirname "$ADIRECTORY_REPRESENTATIVE_FILE"`

        # TODO Checking whether the directory has no subdirectories

        BASE=`dirname "$DIRNAME"`
        DESIRED_DIRNAME=`mp3info -p "%a - %y - %l" "$ADIRECTORY_REPRESENTATIVE_FILE"`
        DESIRED_DIRNAME=`echo "$DESIRED_DIRNAME" | sed "s/\-  \-/\-/"`

        # Checking whether the MP3 file contains valid tags
        if [ $? -eq 0 ]
        then
            # Computing the desired directoryname
            DESIRED_DIRNAME="$BASE/$DESIRED_DIRNAME"

            # Renaming directory name only when needed
            if [ "$DESIRED_DIRNAME" != "$DIRNAME" ];
            then
                # TODO Add a protection whether $DESIRED_DIRNAME already exists
                mv "$DIRNAME" "$DESIRED_DIRNAME" && DIRECTORY_RENAME_COUNTER=$((DIRECTORY_RENAME_COUNTER+1))
            fi
        fi
    fi
done <<< $DIRECTORIES

echo -e "${COLOR_GREEN}Renamed ${COLOR_YELLOW}$DIRECTORY_RENAME_COUNTER${COLOR_GREEN} files and ${COLOR_YELLOW}$DIRECTORY_RENAME_COUNTER${COLOR_GREEN} directories${COLOR_NORMAL}"
exit 0
