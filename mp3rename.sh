#!/bin/bash

# Defining versions and authors
SCRIPT_VERSION='0.3.0'

# Issues:
# TODO Solve issues with directories containing & character (amp not displayed)
# TODO Solve issues with titles containging URLS (starting with http://)
# TODO Detect sets (ex Majestic), for sets do not use artist name in directory name (majestic casual)
# TODO For mp3 files in sets the naming convention should be TRACK ARTIST - TITLE
# TODO Implement scenatio for colisions with file/directory names
# TODO Issues with CD1 and CD2 (Tool the best of)

# TODO Fix move folder bug when there are less than 4 files in the folder

# Sample output
# id3v2 tag info for file.mp3:
# TALB (Album/Movie/Show title): Majestic Casual - Chapter 2
# TPE1 (Lead performer(s)/Soloist(s)): AlunaGeorge
# TPE2 (Band/orchestra/accompaniment): Various Artists
# TCOM (Composer): G. Reid & A. Francis/media/mint/MUZYKA/Alternative/Grimes/
# TCON (Content type): Electronic (52)
# TCMP ():  frame
# TIT2 (Title/songname/content description): You Know You Like It (Wilfred Giroux Remix)
# TRCK (Track number/Position in set): 1
# TYER (Year): 2014
# APIC (Attached picture): ()[, 3]: image/jpeg, 239811 bytes
# Parsing http://stackoverflow.com/questions/5285838/get-mp3-id3-v2-tags-using-id3v2

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
OPTION_VERBOSE=false
OPTION_VERY_VERBOSE=false
OPTION_VERY_VERY_VERBOSE=false
OPTION_DRYRUN=false
OPTION_SKIP_FILES=false
OPTION_SKIP_DIRECTORIES=false
OPTION_CONVERT_FLAC_TO_MP3=false

# Arguments array
declare -a ARGUMENTS=()

echo
echo -e "MP3 rename tool ${COLOR_BLUE}${SCRIPT_VERSION}${COLOR_NORMAL}"

################################################################################
# Parsing input flags
################################################################################
for PARAM in $*
do
    if [ "${PARAM:0:2}" = "--" ]
    then
        if [ "${PARAM}" = '--help' ]
        then
            OPTION_HELP=true
        elif [ "${PARAM}" = '--remove-non-music-files' ]
        then
            OPTION_NON_MP3_NOR_FLAC_FILES=true
        elif [ "${PARAM}" = '--verbose' ]
        then
            OPTION_VERBOSE=true
        elif [ "${PARAM}" = '--very-verbose' ]
        then
            OPTION_VERBOSE=true
            OPTION_VERY_VERBOSE=true
          elif [ "${PARAM}" = '--very-very-verbose' ]
          then
              OPTION_VERBOSE=true
              OPTION_VERY_VERBOSE=true
              OPTION_VERY_VERY_VERBOSE=true
        elif [ "${PARAM}" = '--dry-run' ]
        then
            OPTION_DRYRUN=true
            echo -e "${COLOR_YELLOW}Running in dry run mode. Directories and files will be untouched.${COLOR_NORMAL}"
        elif [ "${PARAM}" = '--skip-files' ]
        then
            OPTION_SKIP_FILES=true
        elif [ "${PARAM}" = '--skip-directories' ]
        then
            OPTION_SKIP_DIRECTORIES=true
        elif [ "${PARAM}" = '--convert-flac-to-mp3' ]
        then
            OPTION_CONVERT_FLAC_TO_MP3=true
        else
            OPTION_HAS_UNKNOWN_FLAG=true
            echo -e "${COLOR_RED}Unknown flag ${PARAM}${COLOR_NORMAL}"
        fi
    else
        # Adding arguments
        ARGUMENTS+=("${PARAM}")
    fi
done
echo

################################################################################
# Functions
################################################################################
function sugestHelp {
    echo -e "For help type ${COLOR_YELLOW}./mp3rename.sh --help${COLOR_NORMAL}"
}

function abortScript {
    echo -e "${COLOR_RED}${1}${COLOR_NORMAL}"
    sugestHelp
    exit $2
}

function getTrack {
    TRACK=`echo "${1}" | sed -n '/^TRCK/s/^.*: //p' | sed 's/ (.*//' | sed 's/\/.*//'`
    # Try TRK in case TRCK is empty  (some iTunes encoded mp3)
    if [ "$TRACK" = '' ]
    then
        TRACK=`echo "${1}" | sed -n '/^TRK/s/^.*: //p' | sed 's/ (.*//' | sed 's/\/.*//'`
    fi

    # Removing zeros from the begining of the track number
    TRACK=$(echo $TRACK | sed 's/^0*//')

    echo $TRACK
}

function getTitle {
    TITLE=`echo "${1}" | sed -n '/^TIT2/s/^.*: //p' | sed 's/ (.*//'`
    # Try TT2 if TIT2 is not present (some iTunes encoded mp3)
    if [ "$TITLE" = '' ]
    then
        TITLE=`echo "${1}" | sed -n '/^TT2/s/^.*: //p' | sed 's/ (.*//'`
    fi

    echo $TITLE
}

function getAlbum {
    ALBUM=`echo "${INFO}" | sed -n '/^TALB/s/^.*: //p' | sed 's/ (.*//'`

    # Try TP1 if TALB is not present (some iTunes encoded mp3)
    if [ "${ALBUM}" = '' ]
    then
        ALBUM=`echo "${INFO}" | sed -n '/^TAL/s/^.*: //p' | sed 's/ (.*//'`
    fi

    echo $ALBUM
}

function getArtist {
    ARTIST=`echo "${INFO}" | sed -n '/^TPE1/s/^.*: //p' | sed 's/ (.*//'`

    # Try TP1 if TPE1 is not present (some iTunes encoded mp3)
    if [ "${ARTIST}" = '' ]
    then
        ARTIST=`echo "${INFO}" | sed -n '/^TP1/s/^.*: //p' | sed 's/ (.*//'`
    fi

    echo $ARTIST
}

function getYear {
    YEAR=`echo "${INFO}" | sed -n '/^TYER/s/^.*: //p' | sed 's/ (.*//'`

    # Taking only 4 first characters out of the year variable
    # This is an extra protection against incorrectly encoded tags storing timestamps
    YEAR=${YEAR:0:4}

    echo $YEAR
}

function getNormalizedFileName {
    # Removing special characters
    DESIRED_FILENAME=`echo ${1} | sed -e "s/[?\.:|&!@#$%^&*()_+\"\/]//g"`
    # Removing multiple spaces
    DESIRED_FILENAME=`echo ${DESIRED_FILENAME} | sed -e "s/  / /g"`
    # Adding extension
    DESIRED_FILENAME="${DESIRED_FILENAME}.mp3"

    # Appending 0 to songs having number less than 10
    if [ "${DESIRED_FILENAME:1:1}" = ' ' ]
    then
        DESIRED_FILENAME="0${DESIRED_FILENAME}"
    fi

    echo $DESIRED_FILENAME
}

function getNormalizedDirName {
    # Some albums do not have any valid year, thus leaving an empty space in directory name
    DESIRED_DIRNAME=`echo "${1}" | sed "s/\-  \-/\-/"`
    # Removing special characters
    DESIRED_DIRNAME=`echo $DESIRED_DIRNAME | sed -e "s/[?\.:|&!@#$%^&*()_+\"\/]//g"`
    # Removing multiple spaces
    DESIRED_DIRNAME=`echo $DESIRED_DIRNAME | sed -e "s/  / /g"`

    echo $DESIRED_DIRNAME
}

function getLowercase {
    echo ${1} | tr '[:upper:]' '[:lower:]'
}

################################################################################
# Displaying error message for unknown flag
################################################################################
if [ $OPTION_HAS_UNKNOWN_FLAG = true ]
then
    sugestHelp
    exit 9
fi


################################################################################
# Displaying help page
################################################################################
if [ $OPTION_HELP = true ]
then
    echo "Renames MP3 files and their directories according to ID3 tags"
    echo
    echo -e "Syntax: ${COLOR_GREEN}./mp3rename.sh DIRECTORY [--help] [--remove-non-music-files] [--verbose]${COLOR_NORMAL}"
    echo
    echo -e "  ${COLOR_YELLOW}--help${COLOR_NORMAL}                        Displays (this) help screen"
    echo -e "  ${COLOR_YELLOW}--remove-non-music-files${COLOR_NORMAL}      Removes files different than MP3/FLAC"
    echo -e "  ${COLOR_YELLOW}--verbose${COLOR_NORMAL}                     Displays extra debug information"
    echo -e "  ${COLOR_YELLOW}--very-verbose${COLOR_NORMAL}                Displays basic ID3 tags for each file"
    echo -e "  ${COLOR_YELLOW}--very-very-verbose${COLOR_NORMAL}           Displays full ID3 tags for each file"
    echo -e "  ${COLOR_YELLOW}--dry-run${COLOR_NORMAL}                     Dry run, do not change anything"
    echo -e "  ${COLOR_YELLOW}--skip-files${COLOR_NORMAL}                  Skips renaming files"
    echo -e "  ${COLOR_YELLOW}--skip-directories${COLOR_NORMAL}            Skips renaming directories"
    echo -e "  ${COLOR_YELLOW}--convert-flac-to-mp3${COLOR_NORMAL}         Converts FLAC to MP3 320kb and replaces the file"
    echo
    echo -e "Script maintained by ${COLOR_BLUE}piotr@polak.ro${COLOR_NORMAL}"
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
    abortScript "Specified path is not a valid directory. Aborting." 9
fi


################################################################################
# Displaying error message for no arguments
################################################################################
if [ ${#ARGUMENTS[@]} -lt 1 ]
then
    abortScript "Working directory is not specified. Aborting." 9
fi


################################################################################
# Testing whether mp3info command is available
################################################################################
which id3v2 > /dev/null
if [ $? -ne 0 ]
then
    echo -e "${COLOR_RED}ERROR: id3v2 is not installed${COLOR_NORMAL}"
    echo -e "${COLOR_RED}Please install id3v2 by executing ${COLOR_YELLOW}sudo apt-get install id3v2${COLOR_NORMAL}"
    echo -e "${COLOR_RED}Aborting${COLOR_NORMAL}"
    echo
    exit 1
fi

################################################################################
# Testing whether ffmpeg command is available
################################################################################
if [ $OPTION_CONVERT_FLAC_TO_MP3 = true ]
then
    which ffmpeg > /dev/null
    if [ $? -ne 0 ]
    then
        echo -e "${COLOR_RED}ERROR: ffmpeg is not installed${COLOR_NORMAL}"
        echo -e "${COLOR_RED}Please install ffmpeg by executing ${COLOR_YELLOW}sudo apt-get install ffmpeg${COLOR_NORMAL}"
        echo -e "${COLOR_RED}Aborting${COLOR_NORMAL}"
        echo
        exit 1
    fi
fi


################################################################################
# Removing non MP3/FLAC files
################################################################################
if [ $OPTION_NON_MP3_NOR_FLAC_FILES = true ]
then
    echo "Removing files other that MP3 and FLAC..."
    NON_MP3_NOR_FLAC_FILES=`find $WORKING_DIRECTORY*/ -type f -not -iname "*.mp3" -not -iname "*.flac"  -not -iname ".mp3skip" -printf "%p|" 2> /dev/null`
    COUNTER=0

    # Readint item by item
    while read -d "|" NON_MP3_NOR_FLAC_FILE
    do
        if [ $OPTION_DRYRUN = false ]
        then
            rm "${NON_MP3_NOR_FLAC_FILE}"
        fi

        # Printing debug information
        if [[ $? -eq 0 ]] || [[ $OPTION_DRYRUN = false ]]
        then
            COUNTER=$((COUNTER+1))

            if [ $OPTION_VERBOSE = true ]
            then
                echo -e "Removed ${COLOR_YELLOW}${NON_MP3_NOR_FLAC_FILE}${COLOR_NORMAL}"
            else
                echo -en "${COLOR_GREEN}.${COLOR_NORMAL}"
            fi
        fi

    done <<< "$NON_MP3_NOR_FLAC_FILES" # Quotation is required for multiple spaces

    echo -e "${COLOR_GREEN}Removed ${COLOR_YELLOW}${COUNTER}${COLOR_GREEN} non MP3/FLAC files${COLOR_NORMAL}"
    echo
fi


# Exit if there is nothing to be renamed
if [[ $OPTION_SKIP_FILES = true ]] && [[ $OPTION_SKIP_DIRECTORIES = true ]]
then
    exit 0
fi

################################################################################
# Reading directories and executing the main logic`
################################################################################

# Note! File directories should not contain | character
DIRECTORIES=`find $WORKING_DIRECTORY*/ -type d -printf "%p|" 2> /dev/null`

# Statistics counter
DIRECTORY_RENAME_COUNTER=0
FILE_RENAME_COUNTER=0;

# The main loop
while read -d "|" ADIRECTORY
do

    if [ -f "${ADIRECTORY}/.mp3skip" ]
    then
        if [ $OPTION_VERBOSE = true ]
        then
            echo -e "Skipping ${COLOR_YELLOW}${ADIRECTORY}${COLOR_NORMAL}"
        fi

        continue
    fi

    # Representative file containing tags to be taken when renaming directory
    ADIRECTORY_REPRESENTATIVE_FILE=''
    # Variable helping to detect whether a directory has MP3 files and should be renamed or just a group of albums
    ADIRECTORY_HAS_MP3_FILES=false

    # Helper variables used to detect whether the directory is an album
    PREVIOUS_ALBUM=''
    PREVIOUS_ARTIST=''
    ADIRECTORY_REPEATING_ALBUM_AND_ARTIST=0;


    if [ $OPTION_CONVERT_FLAC_TO_MP3 = true ]
    then
        FLAC_IN_DIRECTORY=`find "$ADIRECTORY" -type f -iname "*.flac" -maxdepth 1 -printf "%p|" 2> /dev/null`

        RES="${FLAC_IN_DIRECTORY//[^|]}"
        NUMBER_OF_FLAC_IN_DIRECTORY="${#RES}"

        if [ $? -ne 0 ]
        then
           echo -e "${COLOR_RED}No flac files in directory ${COLOR_YELLOW}${ADIRECTORY}${COLOR_NORMAL}"
        else
            echo -e "Found $NUMBER_OF_FLAC_IN_DIRECTORY flac files${COLOR_NORMAL}"
            while read -d "|" FLAC
            do
                CONVERT_SUCCESS=1
                if [ $OPTION_DRYRUN = false ]
                then
                    # https://unix.stackexchange.com/questions/36310/strange-errors-when-using-ffmpeg-in-a-loop
                    < /dev/null ffmpeg -i "$FLAC" -ab 320k -map_metadata 0 -id3v2_version 3 "$FLAC.mp3" 2> /dev/null && unlink "$FLAC"
                    CONVERT_SUCCESS=$?
                fi

                if [ $CONVERT_SUCCESS -ne 0 ]
                then
                    echo -e "${COLOR_RED}Error converting ${COLOR_YELLOW}${FLAC}${COLOR_NORMAL}${COLOR_YELLOW}${COLOR_NORMAL}"
                else
                    if [ $OPTION_VERBOSE = true ]
                    then
                        echo -e "Converted ${COLOR_YELLOW}${FLAC}${COLOR_NORMAL} to ${COLOR_GREEN}MP3 format${COLOR_NORMAL}"
                    else
                        echo -en "${COLOR_BLUE}.${COLOR_NORMAL}"
                    fi
                fi
           done  <<< "$FLAC_IN_DIRECTORY" # Done reading flac, quotation is required for multiple spaces
        fi
    fi

    # Read list of MP3s inside the directory (without recursion)
    MP3S_IN_DIRECTORY=`find "${ADIRECTORY}" -type f -iname "*.mp3" -maxdepth 1 -printf "%p|" 2> /dev/null`
    if [ $? -ne 0 ]
    then
        echo -e "${COLOR_RED}Given file does not exist or file path contains invalid characters ${COLOR_YELLOW}${ADIRECTORY}${COLOR_NORMAL}"
    fi

    RES="${MP3S_IN_DIRECTORY//[^|]}"
    NUMBER_OF_MP3S_IN_DIRECTORY="${#RES}"

    # For every MP3 file
    while read -d "|" MP3
    do
        # Checking if the path is not empty string
        if [ "${MP3}" != "" ]
        then
            # Checking whether the file exists and the filename is valid
            if [ -f "${MP3}" ]
            then
                # Overwrite variable
                ADIRECTORY_HAS_MP3_FILES=true

                # Getting MP3 info
                INFO=`id3v2 -l "${MP3}" 2> /dev/null`

                # Checking whether the MP3 file contains valid tags
                if [ $? -eq 0 ]
                then
                    # Geting directory
                    DIRNAME=`dirname "${MP3}"`
                    CURRENT_FILE="${MP3}"

                    # Parsing title and track
                    TITLE=`getTitle "${INFO}"`
                    TRACK=`getTrack "${INFO}"`

                    if [ $OPTION_VERY_VERBOSE = true ]
                    then
                        ALBUM=`getAlbum "${INFO}"`
                        ARTIST=`getArtist "${INFO}"`

                        echo -en "INFO: ${COLOR_YELLOW}${MP3}${COLOR_NORMAL} - "
                        echo -en "${COLOR_BLUE}ALBUM:${COLOR_NORMAL} ${ALBUM} "
                        echo -en "${COLOR_BLUE}ARTIST:${COLOR_NORMAL} ${ARTIST} "
                        echo -en "${COLOR_BLUE}TITLE:${COLOR_NORMAL} ${TITLE} "
                        echo -e "${COLOR_BLUE}TRACK:${COLOR_NORMAL} ${TRACK}"
                    fi

                    # Displaying full info for very very verbose mode
                    if [ $OPTION_VERY_VERY_VERBOSE = true ]
                    then
                        echo "[INFO]: $INFO"
                        echo
                    fi

                    if [ "${TRACK}" != '' ] && [ "${TITLE}" != '' ]
                    then
                        if [ $OPTION_SKIP_FILES = false ]
                        then
                            # Desired file name composed out of the MP3 info
                            DESIRED_FILENAME=`getNormalizedFileName "${TRACK} ${TITLE}"`

                            # Old filename
                            MP3_FILENAME=`basename "${MP3}"`

                            # This is needed for FAT partitions only
                            # Please keep the variables quoted otherwise multiple spaces will be ignored!
                            DESIRED_FILENAME_LOWER=`getLowercase "${DESIRED_FILENAME}"`
                            MP3_FILENAME_LOWER=`getLowercase "${MP3_FILENAME}"`

                            # Rename file only if the newly generated filename is different
                            if [ "${DESIRED_FILENAME_LOWER}" != "${MP3_FILENAME_LOWER}" ];
                            then
                                if [ $OPTION_DRYRUN = false ]
                                then
                                    CURRENT_FILE="${DIRNAME}/${DESIRED_FILENAME}"
                                    mv "${MP3}" "${CURRENT_FILE}"
                                fi

                                # Printing debug information
                                if [[ $? -eq 0 ]] || [[ $OPTION_DRYRUN = false ]]
                                then
                                    FILE_RENAME_COUNTER=$((FILE_RENAME_COUNTER+1))

                                    if [ $OPTION_VERBOSE = true ]
                                    then
                                        echo -e "Renamed ${COLOR_YELLOW}${MP3}${COLOR_NORMAL} to ${COLOR_GREEN}${DESIRED_FILENAME}${COLOR_NORMAL}"
                                    else
                                        echo -en "${COLOR_GREEN}.${COLOR_NORMAL}"
                                    fi
                                fi
                            fi
                        fi

                        if [ $OPTION_SKIP_DIRECTORIES = false ]
                        then
                            # Picking a representative file only if the file was not previously selected
                            if [ "${ADIRECTORY_REPRESENTATIVE_FILE}" = '' ]
                            then
                                # Variables needed for checking whether the folder is an album
                                ALBUM=`getAlbum "${INFO}"`
                                ARTIST=`getArtist "${INFO}"`

                                # Both album and artist must be non-empty and must be equal to the previously picked values
                                if [ "${ALBUM}" != '' ] && [ "${ARTIST}" != '' ]
                                then
                                    # TODO Check whether lowerecase artist TPE2 contains "various"
                                    if [ "${ALBUM}" = "${PREVIOUS_ALBUM}" ] && [ "${ARTIST}" = "${PREVIOUS_ARTIST}" ]
                                    then
                                        # Incrementing counter
                                        ADIRECTORY_REPEATING_ALBUM_AND_ARTIST=$((ADIRECTORY_REPEATING_ALBUM_AND_ARTIST+1))

                                        # Picking one valid file if there are at least 4 consecutive OR all files of the same album and artist
                                        if [ $ADIRECTORY_REPEATING_ALBUM_AND_ARTIST -ge 4 ] || [ $ADIRECTORY_REPEATING_ALBUM_AND_ARTIST -eq $((NUMBER_OF_MP3S_IN_DIRECTORY-1)) ]
                                        then
                                            ADIRECTORY_REPRESENTATIVE_FILE=$CURRENT_FILE
                                        fi
                                    fi
                                else
                                    # Reseting the counter
                                    ADIRECTORY_REPEATING_ALBUM_AND_ARTIST=0
                                fi # End checking album and artist

                                # Saving variables for next loop, outside the IF
                                PREVIOUS_ALBUM="${ALBUM}"
                                PREVIOUS_ARTIST="${ARTIST}"

                            fi # End checking whether the representative file was selected
                        fi # End checking if skip directories
                    fi # End checking track and title
                else
                    echo -e "${COLOR_RED}Unable to read MP3 tags for ${COLOR_YELLOW}${MP3}${COLOR_NORMAL}"
                fi # End checking exit code
            else
                echo -e "${COLOR_RED}Given file does not exist or file path contains invalid characters ${COLOR_YELLOW}${MP3}${COLOR_NORMAL}"
            fi
        fi
    done  <<< "$MP3S_IN_DIRECTORY" # Done reading mp3s, quotation is required for multiple spaces

    if [ $OPTION_SKIP_DIRECTORIES = false ]
    then
        # If there were any music files inside the directory
        if [ "${ADIRECTORY_REPRESENTATIVE_FILE}" != '' ]
        then
            # Renaming directories
            DIRNAME=`dirname "${ADIRECTORY_REPRESENTATIVE_FILE}"`

            # Getting base directory
            BASE=`dirname "$DIRNAME"`

            # Getting MP3 info
            INFO=`id3v2 -l "${ADIRECTORY_REPRESENTATIVE_FILE}" 2> /dev/null`;

            # Checking whether the MP3 file contains valid tags
            if [ $? -eq 0 ]
            then
                # Parsing http://stackoverflow.com/questions/5285838/get-mp3-id3-v2-tags-using-id3v2
                ARTIST=`getArtist "${INFO}"`
                ALBUM=`getAlbum "${INFO}"`
                YEAR=`getYear "${INFO}"`

                # Checking whether the minimal required tags are specified
                if [ "${ARTIST}" != '' ] && [ "${ALBUM}" != '' ]
                then
                    # Computing directory name out of the tags
                    DESIRED_DIRNAME=`getNormalizedDirName "${ARTIST} - ${YEAR} - ${ALBUM}"`
                    # Computing the desired directoryname
                    DESIRED_DIRNAME="${BASE}/${DESIRED_DIRNAME}"

                    # This is needed for FAT partitions only
                    # Please keep the variables quoted otherwise multiple spaces will be ignored!
                    DESIRED_DIRNAME_LOWER=`getLowercase "${DESIRED_DIRNAME}"`
                    DIRNAME_LOWER=`getLowercase "${DIRNAME}"`

                    # Renaming directory name only when needed
                    if [ "${DESIRED_DIRNAME_LOWER}" != "${DIRNAME_LOWER}" ]
                    then
                        if [ $OPTION_DRYRUN = false ]
                        then
                            # TODO Add a protection whether $DESIRED_DIRNAME already exists
                            mv "${DIRNAME}" "${DESIRED_DIRNAME}"
                        fi

                        # Printing debug information
                        if [[ $? -eq 0 ]] || [[ $OPTION_DRYRUN = false ]]
                        then
                            DIRECTORY_RENAME_COUNTER=$((DIRECTORY_RENAME_COUNTER+1))
                            if [ $OPTION_VERBOSE = true ]
                            then
                                echo -e "Moved ${COLOR_YELLOW}${DIRNAME}${COLOR_NORMAL} to ${COLOR_YELLOW}${DESIRED_DIRNAME}${COLOR_NORMAL}"
                            else
                                echo -en "${COLOR_GREEN}.${COLOR_NORMAL}"
                            fi
                        fi
                    fi
                else
                    echo -e "\n${COLOR_RED}No valid artist or album for file ${COLOR_YELLOW}${ADIRECTORY_REPRESENTATIVE_FILE}${COLOR_NORMAL}"
                fi
            fi
        else # No representative file
            # Displaying warning for directories having MP3 files but no valid tags
            # Preventing from displaying this error for directories having other directories
            if [ $ADIRECTORY_HAS_MP3_FILES = true ]
            then
                echo -e "${COLOR_RED}No ID3 tags or not an album for directory ${COLOR_YELLOW}${ADIRECTORY}${COLOR_NORMAL}"
            fi
        fi
    fi
done <<< "$DIRECTORIES" # Quotation is required for multiple spaces

echo -e "${COLOR_GREEN}Renamed ${COLOR_YELLOW}${FILE_RENAME_COUNTER}${COLOR_GREEN} files and ${COLOR_YELLOW}${DIRECTORY_RENAME_COUNTER}${COLOR_GREEN} directories${COLOR_NORMAL}"
exit 0
