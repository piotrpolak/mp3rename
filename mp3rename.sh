#!/bin/bash

# Defining versions and authors
SCRIPT_VERSION='0.2'

# Issues:
# TODO Solve issues with directories containing & character (amp not displayed)
# TODO Solve issues with titles containging URLS (starting with http://)

# Defining echo colors
# http://misc.flogisoft.com/bash/tip_colors_and_formatting
COLOR_NORMAL="\e[0m"
COLOR_RED="\e[91m"
COLOR_GREEN="\e[32m"
COLOR_YELLOW="\e[33m"
COLOR_BLUE="\e[36m"

# Possible options
OPTION_HELP=false
OPTION_HAS_UNKNOWN_FLAG=false
OPTION_NON_MP3_NOR_FLAC_FILES=false

# Arguments array
declare -a ARGUMENTS=()

echo
echo -e "MP3 rename tool ${COLOR_BLUE}$SCRIPT_VERSION${COLOR_NORMAL}"

################################################################################
# Parsing input flags
################################################################################
for PARAM in $*
do
    if [ "${PARAM:0:2}" == "--" ]
    then
        if [ "$PARAM" == '--help' ]
        then
            OPTION_HELP=true
        elif [ "$PARAM" == '--remove-non-music-files' ]
        then
            OPTION_NON_MP3_NOR_FLAC_FILES_=true
        else
            OPTION_HAS_UNKNOWN_FLAG=true
            echo -e "${COLOR_RED}Unknown flag $e${COLOR_NORMAL}"
        fi
    else
        # Adding arguments
        ARGUMENTS+=("$PARAM")
    fi
done
echo


################################################################################
# Displaying error message for unknown flag
################################################################################
if [ $OPTION_HAS_UNKNOWN_FLAG == true ]
then
    echo -e "Aborting, for help type ${COLOR_GREEN}./mp3rename.sh --help${COLOR_NORMAL}"
    exit 9
fi


################################################################################
# Displaying help page
################################################################################
if [ $OPTION_HELP == true ]
then
    echo "Renames MP3 files and their directories according to ID3 tags"
    echo
    echo -e "Syntax: ${COLOR_GREEN}./mp3rename.sh DIRECTORY [--help] [--remove-non-music-files]${COLOR_NORMAL}"
    echo
    echo -e "  ${COLOR_YELLOW}--help${COLOR_NORMAL}                        Displays (this) help screen"
    echo -e "  ${COLOR_YELLOW}--remove-non-music-files${COLOR_NORMAL}      Removes files different than MP3/FLAC"
    echo
    echo -e "Script maintained by ${COLOR_BLUE}pepis@closbrothers.pl${COLOR_NORMAL}"
    echo
    exit 0
fi

# Getting working directory out of the arguments
WORKING_DIRECTORY=${ARGUMENTS[0]}

# Appending the trailing slash if missing - this is required for security reasons
if [ "${WORKING_DIRECTORY#${WORKING_DIRECTORY%?}}" != "/" ]
then
    WORKING_DIRECTORY="$WORKING_DIRECTORY/"
fi


# Checking whether the working directory exits
if [ ! -d "$WORKING_DIRECTORY" ]
then
    echo -e "${COLOR_RED}Specified path is not a valid directory ${COLOR_YELLOW}./mp3rename.sh --help${COLOR_NORMAL}"
    exit 9
fi


################################################################################
# Displaying error message for no arguments
################################################################################
if [ ${#ARGUMENTS[@]} -lt 1 ]
then
    echo -e "Working directory is not specified. Aborting, for help type ${COLOR_GREEN}./mp3rename.sh --help${COLOR_NORMAL}"
    exit 9
fi


################################################################################
# Testing whether mp3info command is available
################################################################################
which id3v2 > /dev/null
if [ $? -ne 0 ]
then
    echo -e "${COLOR_RED}id3v2 is not installed, aborting${COLOR_NORMAL}"
    exit -1
fi


################################################################################
# Removing non MP3/FLAC files
################################################################################
if [ OPTION_NON_MP3_NOR_FLAC_FILES = true ]
then
    echo "Removing files other that MP3 and FLAC..."
    NON_MP3_NOR_FLAC_FILES=`find $WORKING_DIRECTORY*/ -type f -not -iname "*.mp3" -not -iname "*.flac" -printf "%p|"`
    COUNTER=0

    # Readint item by item
    while read -d "|" NON_MP3_NOR_FLAC_FILE
    do
        rm "$NON_MP3_NOR_FLAC_FILE" && COUNTER=$((COUNTER+1))
    done <<< $NON_MP3_NOR_FLAC_FILES

    echo -e "${COLOR_GREEN}Removed ${COLOR_YELLOW}$COUNTER${COLOR_GREEN} non MP3/FLAC files${COLOR_NORMAL}"
    echo
fi


################################################################################
# Reading directories and executing the main logic`
################################################################################

# Note! File directories should not contain | character
DIRECTORIES=`find $WORKING_DIRECTORY*/ -type d -printf "%p|"`

# Statistics counter
DIRECTORY_RENAME_COUNTER=0
FILE_RENAME_COUNTER=0;

# The main loop
while read -d "|" ADIRECTORY
do
    ADIRECTORY_REPRESENTATIVE_FILE=''
    PREVIOUS_ALBUM=''
    PREVIOUS_ARTIST=''

    # Read list of MP3s inside the directory (withour recursion)
    MP3S_IN_DIRECTORY=`find "$ADIRECTORY" -type f -iname "*.mp3" -maxdepth 1 -printf "%p|" 2> /dev/null`
    if [ $? -ne 0 ]
    then
        echo -e "${COLOR_RED}Given file does not exist or file path contains invalid characters ${COLOR_YELLOW}${ADIRECTORY}${COLOR_NORMAL}"
    fi

    # For every MP3 file
    while read -d "|" MP3; do

        # Checking if the path is not empty string
        if [ "$MP3" != "" ]
        then
            # Checking whether the file exists and the filename is valid
            if [ -f "$MP3" ]
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

                    if [ "$TRACK" != '' ] && [ "$TITLE" != '' ]
                    then
                        # Desired file name composed out of the MP3 info
                        DESIRED_FILENAME="${TRACK} ${TITLE}"
                        # Removing special characters
                        DESIRED_FILENAME=`echo $DESIRED_FILENAME | sed -e "s/[?\.:|&!@#$%^&*()_+\"\/]//g"`
                        # Removing multiple spaces
                        DESIRED_FILENAME=`echo $DESIRED_FILENAME | sed -e "s/  / /g"`
                        # Adding extension
                        DESIRED_FILENAME="${DESIRED_FILENAME}.mp3"

                        # Appending 0 to songs having number less than 10
                        if [ "${DESIRED_FILENAME:1:1}" == ' ' ]
                        then
                          DESIRED_FILENAME="0$DESIRED_FILENAME"
                        fi

                        # Old filename
                        MP3_FILENAME=`basename "$MP3"`

                        # This is needed for FAT partitions only
                        # Please keep the variables quoted otherwise multiple spaces will be ignored!
                        DESIRED_FILENAME_LOWER=`echo "$DESIRED_FILENAME" | tr '[:upper:]' '[:lower:]'`
                        MP3_FILENAME_LOWER=`echo "$MP3_FILENAME" | tr '[:upper:]' '[:lower:]'`

                        # Rename file only if the newly generated filename is different
                        if [ "$DESIRED_FILENAME_LOWER" != "$MP3_FILENAME_LOWER" ];
                        then
                            mv "$MP3" "$DIRNAME/$DESIRED_FILENAME" && FILE_RENAME_COUNTER=$((FILE_RENAME_COUNTER+1)) && echo -en "${COLOR_GREEN}.${COLOR_NORMAL}"
                        fi

                        # Picking a representative file only if the file was not previously selected
                        if [ "$ADIRECTORY_REPRESENTATIVE_FILE" = '' ]
                        then
                            # Parsing album and artist
                            ALBUM=`echo "$INFO" | sed -n '/^TALB/s/^.*: //p' | sed 's/ (.*//'` # Variable needed for checking whether the folder is an album
                            ARTIST=`echo "$INFO" | sed -n '/^TALB/s/^.*: //p' | sed 's/ (.*//'` # Variable needed for checking whether the folder is an album

                            # Both album and artist must be non-empty and must be equal to the previously picked values
                            if [ "$ALBUM" != '' ] && [ "$ARTIST" != '' ]
                            then
                                if [ "$ALBUM" = "$PREVIOUS_ALBUM" ] && [ "$ARTIST" = "$PREVIOUS_ARTIST" ]
                                then
                                    # Picking one valid file
                                    ADIRECTORY_REPRESENTATIVE_FILE="$DIRNAME/$DESIRED_FILENAME"
                                else
                                    PREVIOUS_ALBUM="$ALBUM"
                                    PREVIOUS_ARTIST="$ARTIST"
                                fi
                            fi # End checking album and artist
                        fi # End checking whether the representative file was selected
                    fi # End checking track and title
                fi # End checking exit code
            else
                  echo -e "${COLOR_RED}Given file does not exist or file path contains invalid characters ${COLOR_YELLOW}${MP3}${COLOR_NORMAL}"
            fi
        fi
    done  <<< "$MP3S_IN_DIRECTORY" # Done reading mp3s, quotation is required for multiple spaces

    # If there were any music files inside the directory
    if [ "$ADIRECTORY_REPRESENTATIVE_FILE" != '' ]
    then
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

            # Taking only 4 first characters out of the year variable
            # This is an extra protection against incorrectly encoded tags storing timestamps
            YEAR=${YEAR:0:4}

            # Checking whether the minimal required tags are specified
            if [ "$ARTIST" != '' ] && [ "$ALBUM" != '' ]
            then
                # Computing directory name out of the tags
                DESIRED_DIRNAME="${ARTIST} - ${YEAR} - ${ALBUM}"
                # Some albums do not have any valid year, thus leaving an empty space in directory name
                DESIRED_DIRNAME=`echo "$DESIRED_DIRNAME" | sed "s/\-  \-/\-/"`
                # Removing special characters
                DESIRED_DIRNAME=`echo $DESIRED_DIRNAME | sed -e "s/[?\.:|&!@#$%^&*()_+\"\/]//g"`
                # Removing multiple spaces
                DESIRED_DIRNAME=`echo $DESIRED_DIRNAME | sed -e "s/  / /g"`
                # Computing the desired directoryname
                DESIRED_DIRNAME="$BASE/$DESIRED_DIRNAME"

                # This is needed for FAT partitions only
                # Please keep the variables quoted otherwise multiple spaces will be ignored!
                DESIRED_DIRNAME_LOWER=`echo "$DESIRED_DIRNAME" | tr '[:upper:]' '[:lower:]'`
                DIRNAME_LOWER=`echo "$DIRNAME" | tr '[:upper:]' '[:lower:]'`

                # Renaming directory name only when needed
                if [ "$DESIRED_DIRNAME_LOWER" != "$DIRNAME_LOWER" ]
                then
                    # TODO Add a protection whether $DESIRED_DIRNAME already exists
                    mv "$DIRNAME" "$DESIRED_DIRNAME" && DIRECTORY_RENAME_COUNTER=$((DIRECTORY_RENAME_COUNTER+1))
                fi
            else
                echo -e "${COLOR_RED}No valid artist or album for file ${COLOR_YELLOW}$ADIRECTORY_REPRESENTATIVE_FILE${COLOR_NORMAL}"
            fi
        fi
    else
        # TODO Check whether the directory is album directory and prevent this error from being displayed for directories with no MP3s
        echo -e "${COLOR_RED}No ID3 tags for directory ${COLOR_YELLOW}$ADIRECTORY${COLOR_NORMAL}"
    fi
done <<< "$DIRECTORIES" # Quotation is required for multiple spaces

echo -e "${COLOR_GREEN}Renamed ${COLOR_YELLOW}$FILE_RENAME_COUNTER${COLOR_GREEN} files and ${COLOR_YELLOW}$DIRECTORY_RENAME_COUNTER${COLOR_GREEN} directories${COLOR_NORMAL}"
exit 0
