# MP3 rename tool

A command line tool that renames MP3 files and their directories according to ID3 tags.

## Usage
Use the following command to clean up your music library:
`./mp3rename.sh DIRECTORY [--help] [--remove-non-music-files] [--verbose]`

 * `--help`                        Displays help screen
 * `--remove-non-music-files`      Removes files different than MP3/FLAC
 * `--verbose`                     Displays extra debug information
 * `--dry-run`                     Only displays operations, does not rename anything.
 * `--skip-files`                  Skips renaming files.
 * `--skip-directories`            Skips renaming directories.

## Directory and file naming conventions

The naming convention for directories is `ARTIST - YEAR - ALBUM`, for files `TRACKNO TITLE`. TRACKNO is automatically prepended with 0 for track number less than 10.
