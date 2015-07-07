#!/bin/bash

# Defining versions and authors
SCRIPT_VERSION='0.1'

# Issues:
# TODO Solve problem with filenames containing multiple spaces in row


# Defining echo colors
# http://misc.flogisoft.com/bash/tip_colors_and_formatting
COLOR_NORMAL="\e[0m"
COLOR_RED="\033[31m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[36m"

echo
echo -e "MP3 order tool ${COLOR_BLUE}$SCRIPT_VERSION${COLOR_NORMAL}"

# Testing whether mp3info command is available
which id3v2 > /dev/null
if [ $? -ne 0 ]
then
    echo -e "${COLOR_RED}id3v2 is not installed, aborting${COLOR_NORMAL}"
    exit -1
fi


# Removing non MP3/FLAC files
echo "Removing files other that MP3 and FLAC..."
NON_MP3_NOR_FLAC_FILES=`find ./*/ -type f -not -iname "*.mp3" -not -iname "*.flac" -printf "%p|"`
COUNTER=0

# Readint item by item
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

    # Read list of MP3s inside the directory (withour recursion)
    MP3S_IN_DIRECTORY=`find "$ADIRECTORY" -type f -iname "*.mp3" -maxdepth 1 -printf "%p|"`

    # For every MP3 file
    while read -d "|" MP3; do
        if [ "$MP3" != "" ]
        then

          # Getting MP3 info
          INFO=`id3v2 -l "$MP3" 2> /dev/null`

          # Checking whether the MP3 file contains valid tags
          if [ $? -eq 0 ]
          then
              # Geting directory
              DIRNAME=`dirname "$MP3"`

              # Parsing http://stackoverflow.com/questions/5285838/get-mp3-id3-v2-tags-using-id3v2
              TITLE=`echo "$INFO" | sed -n '/^TIT2/s/^.*: //p' | sed 's/ (.*//'`
              TRACK=`echo "$INFO" | sed -n '/^TRCK/s/^.*: //p' | sed 's/ (.*//' | sed 's/\/.*//'`

              # Desired file name composed out of the MP3 info
              DESIRED_FILENAME="${TRACK} ${TITLE}.mp3"

              # Appending 0 to songs having number less than 10
              if [ "${DESIRED_FILENAME:1:1}" == ' ' ]
              then
                DESIRED_FILENAME="0$DESIRED_FILENAME"
              fi

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
    done  <<< $MP3S_IN_DIRECTORY # Done reading mp3s

    # If there were any music files inside the directory
    if [ "$ADIRECTORY_REPRESENTATIVE_FILE" != '' ]
    then

        # TODO Checking whether the directory has no subdirectories

        # Renaming directories
        DIRNAME=`dirname "$ADIRECTORY_REPRESENTATIVE_FILE"`

        # Getting base directory
        BASE=`dirname "$DIRNAME"`

        # Getting MP3 info
        INFO=`id3v2 -l "$ADIRECTORY_REPRESENTATIVE_FILE" 2> /dev/null`;

        # Checking whether the MP3 file contains valid tags
        if [ $? -eq 0 ]
        then
            # Parsing http://stackoverflow.com/questions/5285838/get-mp3-id3-v2-tags-using-id3v2
            ARTIST=`echo "$INFO" | sed -n '/^TPE1/s/^.*: //p' | sed 's/ (.*//'`
            ALBUM=`echo "$INFO" | sed -n '/^TALB/s/^.*: //p' | sed 's/ (.*//'`
            YEAR=`echo "$INFO" | sed -n '/^TYER/s/^.*: //p' | sed 's/ (.*//'`

            # Extra protection against timestamps - taking only 4 first characters
            YEAR=${YEAR:0:4}

            # Checking whether the minimal required tags are specified
            if [ "$ARTIST" != '' ] && [ "$ALBUM" != '' ]
            then
                # Computing directory name out of the tags
                DESIRED_DIRNAME="${ARTIST} - ${YEAR} - ${ALBUM}"

                # Some albums do not have any valid year, thus leaving an empty space in directory name
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
            else
                echo -e "${COLOR_RED}No valid artist for file $ADIRECTORY_REPRESENTATIVE_FILE${COLOR_NORMAL}"
            fi
        fi
    fi
done <<< $DIRECTORIES

echo -e "${COLOR_GREEN}Renamed ${COLOR_YELLOW}$FILE_RENAME_COUNTER${COLOR_GREEN} files and ${COLOR_YELLOW}$DIRECTORY_RENAME_COUNTER${COLOR_GREEN} directories${COLOR_NORMAL}"
exit 0
