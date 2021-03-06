# MP3 bulk rename and FLAC conversion tool

A command line tool that renames MP3 files and their directories according to ID3 tags.

The tool is able to automatically transform FLAC files to MP3.

## Usage
Use the following command to clean up your music library:
`./mp3rename.sh DIRECTORY [--help] [--remove-non-music-files] [--verbose]`

 * `--help`                        Displays help screen
 * `--remove-non-music-files`      Removes files different than MP3/FLAC
 * `--verbose`                     Displays extra debug information
 * `--very-verbose`                Displays basic ID3 tags for each file
 * `--very-very-verbose`           Displays full ID3 tags for each file
 * `--dry-run`                     Only displays operations, does not rename anything
 * `--skip-files`                  Skips renaming files
 * `--skip-directories`            Skips renaming directories
 * `--convert-flac-to-mp3`         Converts FLAC to MP3 320kb and replaces the file

## Directory and file naming conventions

The naming convention for directories is `ARTIST - YEAR - ALBUM`,
for files `TRACKNO TITLE`. TRACKNO is automatically prepended with 0 for track
number less than 10.

Add a `.mp3skip` file inside any directory to to prevent it and its contents from
being renamed. This might be useful if the ID3 tags are broken or missing.
