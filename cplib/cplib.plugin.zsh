#!/usr/bin/env zsh

##==============================================================================
##== CPLIB Configuration
##==============================================================================
#region PLIB Configuration

export -a CPLIB_EXTENSIONS=(mp4 mov wmv avi flv swf mkv webm)

## @ _cpl_extglob()
alias _cpl_extglob="echo \"${(j:|:)CPLIB_EXTENSIONS[@]}\""

#endregion

##==============================================================================
##== File Finding
##==============================================================================
#region File Finding

## @ cplvids-find, cplvids-find-recursive
## Find videos recursively from current directory, or only on root directory.
alias cplvids-find="/usr/bin/ls -1 ./*.($(_cpl_extglob))"
alias cplvids-find-recursive="/usr/bin/ls -1 ./**/*.($(_cpl_extglob))"

## * cplvids-find-nosheet()
## Find videos without sheets, just pasted here..
cplvids-find-nosheet() {
	while read f; do
		[[ ! -e ${f%.*}.jpg ]] && printf '%s\n' "$f"
	done < <(cplvids-find-recursive)
}

## * cpldirs-find-empty()
cpldirs-find-empty() {
	for d in ./**/*/; do
		fc="$(/usr/bin/ls -A1 "$d" | wc -l)"
		[ $fc -eq 0 ] && printf '%s\n' "$d"
	done
}

## @ cplfiles-find-extras
alias cplfiles-find-extras="find . -type f -regextype posix-egrep -not -iregex \".*.($(_cpl_extglob))\""

#endregion

##==============================================================================
##== File/Directory Modifications
##==============================================================================
#region File/Directory Modifications

## * cplvids-move-fromsubdirs()
## Move all sub-directory videos into current directory.
cplvids-move-fromsubdirs() {
	while read f; do
		tgtfile="$(echo "${f#./}" | sed -E -e 's/ - /-/g' -e 's/(- | -)/-/g' -e 's/\s+/-/g' -e 's/\//--/g')"
		mv -v "$f" "$tgtfile"
	done < <(cplvids)
}

## * cpldirs-rm-empty()
cpldirs-rm-empty() {
	local -a dirs=()
	cpldirs-find-empty | while read d; do
		dirs+=("$d");
	done

	if [ $#dirs -gt 0 ]; then
		printf '######## Empty Directories: ########\n'
		printf '%s\n' "${dirs[@]}"
		printf '\nDelete them all? [y/N]: '
		read -k1 yn
		printf '\e[0m\n'
		[[ $yn =~ '^[yY]$' ]] && for d in "${dirs[@]}"; do rm -dfv "$d"; done
	fi
}

## * cplfiles-rm-extra()
cplfiles-rm-extra() {
	local -a files=()
	cplfiles-find-extras | while read d; do
		files+=("$d");
	done

	if [ $#files -gt 0 ]; then
		printf '######## Extra Files: ########\n'
		printf '%s\n' "${files[@]}"
		printf '\nDelete them all? [y/N]: '
		read -k1 yn
		printf '\e[0m\n'
		[[ $yn =~ '^[yY]$' ]] && for d in "${files[@]}"; do rm -fv "$d"; done
	fi
}

#endregion

##==============================================================================
##== Action Functions
##==============================================================================
#region Action Functions

## * cplprevloop()
## Scans directories for videos and manages video collection.
##
## This function will search videos in provided directories with associated
## preview picture (same name as the video, but .jpg extension instead). Found
## videos with previews are added to a list, and when it's finally time for the
## preview loop, a 'yad' window will open.
##
## This window will display random shuffled picture from found vid/pic pairs. It
## provides buttons for moving the video in question to either: .vip (VIP, Most
## Important), .fav (Favourites), .lib (Bookmarks) and .del (To-Delete).
## Additionally, you may choose whether to open the video in background (paused
## and muted in mpv), or whether to skip the video. Additionally, there are
## buttons for deleting the video, or just skipping it with no action.
##
## Once selection has been made regarding a video, actions like moving it if
## requested and opening it in MPV if needed, are performed, after which the
## next randomized preview picture is presented.
##
## USAGE:
##
##   cplprevloop [PATH] ([PATH2] ...)
##
## 	 PATH:
## 		 Path to the directory which is the root of the video collection, which
## 		 will be scanned for video+picture pairs. Multiple paths can be provided
## 		 to include more libraries in one scan.
##
cplprevloop() {(
	# If -h|--help specified or no args provided, output help information.
	if [[ $# -eq 0 || $@ =~ '(^-h| -h|--help$|--help |^-[[:alnum:]]*h| -[[:alnum:]]*h)' ]]; then
		cat <<-EOF | sed -E 's/\| /\t/g' && return 0
		$funcstack[1] - Scans directories for videos and manages video collection.

		This function will search videos in provided directories with associated
		preview picture (same name as the video, but .jpg extension instead). Found
		videos with previews are added to a list, and when it's finally time for the
		preview loop, a 'yad' window will open.

		This window will display random shuffled picture from found vid/pic pairs.
		It provides buttons for moving the video in question to either: .vip (VIP,
		Most Important), .fav (Favourites), .lib (Bookmarks) and .del (To-Delete).
		Additionally, you may choose whether to open the video in background (paused
		and muted in mpv), or whether to skip the video. Additionally, there are
		buttons for deleting the video, or just skipping it with no action.

		Once selection has been made regarding a video, actions like moving it if
		requested and opening it in MPV if needed, are performed, after which the
		next randomized preview picture is presented.

		USAGE:

		| $funcstack[1] [PATH] ([PATH2] ...)

		| PATH:
		| | Path to the directory which is the root of the video collection, which
		| | will be scanned for video+picture pairs. Multiple paths can be provided
		| | to include more libraries in one scan.

		EOF
	fi

	# Initialize & handle option arguments.
	_cpl_out_msg "Initializing and processing options"

	# Array for paths to scan for videos.
	typeset -a target_paths=()  # for directories to scan for videos
	typeset -a target_files=()  # for paths to found videos

	# Ensure globdots option is enabled because it is required by the script.
	if ! setopt | grep -wq globdots; then
		_cpl_out_msg 'Enabling required DOT_GLOB (GLOB_DOTS) shell option.'
		setopt DOT_GLOB
	fi

	# Process command line arguments.
	for current_input in $@; do
		if [[ ! -d $current_input || ! -r $current_input ]]; then
			_cpl_out_error 7 "Invalid argument: Path not found or not readable: $current_input" || return $?
		else
			printf 'Adding path to scanned directories list: %s\n' $current_input
			target_paths+=( "${current_input:A}" )
		fi
	done

	# Exit script if no target paths were found.
	if (( $#target_paths == 0 )); then
		_cpl_out_error 1 "Root directory not provided." || return $?
	fi

	# CD to first target path
	cd ${target_paths[1]}

	# Process directories and scan for files.
	_cpl_out_msg "Scanning directory contents from all paths."
  _cpl_out_msg "Directories are checked carefully to be valid targets."
	_cpl_out_msg "Missing sub-directories are created automatically."

  # Loop directories and look for videos.
	for dir in ${target_paths[@]}; do

    # Ensure the path points to valid directory.
		_cpl_out_msg ">> Validating directory: $dir"
		if [[ ! -e $dir ]]; then
			_cpl_out_error 1 "Directory does not seem to exist: $dir" || return $?
		elif [[ ! -d $dir ]]; then
			_cpl_out_error 1 "Path points to a non-directory object: $dir" || return $?
		elif [[ ! -r $dir ]]; then
			_cpl_out_error 2 "Directory lacks read permissions: $dir" || return $?
		fi

		_cpl_out_msg ">> Processing directory: $dir"
		path_tier0="$dir/.vip"
		path_tier1="$dir/.fav" # For now; t1: .fav, t2: .lib, t5: .del (until updated)
		path_tier2="$dir/.lib"
		path_tier5="$dir/.del"

    # Check subdirectories and create missing ones.
		_cpl_out_msg "Checking required sub-directories, and creating any missing ones."
		for dirname in $path_tier0 $path_tier1 $path_tier2 $path_tier5; do
			if [[ ! -e $dirname ]]; then
				if ! mkdir "$dirname" 1>/dev/null; then
					_cpl_out_error 12 "$dirname (Unable to create directory)" || return $?
				else
					_cpl_out_msg "$dirname"
				fi
			elif [[ ! -d $dirname ]]; then
				_cpl_out_error 13 "$dirname (Path doesn't point to a directory)" || return $?
			elif [[ ! -r $dirname ]]; then
				_cpl_out_error 14 "$dirname (Directory is unreadable)"
				printf "Change ownership via sudo chown & chmod? [Y/n]: "
				read -k1 yn; echo -
				if [[ $yn =~ '^[Nn]$' ]]; then
					_cpl_out_msg "Aborting due to user request."
					return 0
				else
					sudo chown -v -R $UID:$GID "$dirname" || _cpl_out_error 13 "Changing ownership failed." || return $?
					sudo chmod -v 0700 "$dirname" || _cpl_out_error 14 "Changing file permissions failed." || return $?
				fi
			fi
		done

		local videos_dir=0    # Counter for videos found in each directory
		local videos_total=0  # Counter for total videos found

		printf 'Scanning directory: %s.. ' $dir
		find -L $dir/ -maxdepth 6 -xtype f -readable -not -path "$dir/.*" -regextype egrep -regex '^(.*/)*.*?\.('$(_cpl_extglob)')$' | while read f; do
			target_files+=( "${f:A}" )
			((videos_dir++, videos_total++))
		done
		printf '+%i videos\n' $videos_dir
		videos_dir=0

		for category_subdir in .vip .fav .lib .del .jav; do
			printf 'Scanning directory: %s/%s.. ' "$dir" "$category_subdir"
			find -L $dir/$category_subdir -maxdepth 5 -xtype f -readable -regextype egrep -regex '^(.*/)*.*?\.('$(_cpl_extglob)')$' | while read f; do
				target_files+=( "${f:A}" )
				((videos_dir++, videos_total++))
			done
			printf '+%i videos!\n' $videos_dir
			videos_dir=0
		done

		_cpl_out_msg n "${videos_total} videos found from current directory." "Total count: ${#target_files}"
	done

	_cpl_out_msg n "Finished scanning directories: Found ${#target_files} videos." "Press any key to begin yad preview loop"
	read -k1

	while (( ${#target_files} > 0 )); do

		# Get random index within bounds of the videos array. Arrays are not
		# zero-indexed in ZSH, so increment by 1 just in case.
		local rnd=$(( ((RANDOM) << 1 % $#target_files) + 1 ))

		# Path to this video file and associated preview pic, which should have the
		# same name, except .jpg extension. Also calculate the path to parent
		# directory containing current video.
		local file_path="$target_files[$rnd]"
		local preview_pic_path="${file_path/%$file_path:e/jpg}"
		local file_parent_dir="${file_path:h}"

		# Unset this file from the target_files array.
		target_files[$rnd]=()

		# Text output to terminal and displayed in yad title bar.
		pic_num_text="$rnd/$((${#target_files}+1)): $preview_pic_path"

		# Specify the directories for favourites, bookmarks and archived content.
		[[ $file_parent_dir = *.vip ]] && path_tier0="$file_parent_dir" || path_tier0="$file_parent_dir/.vip"
		[[ $file_parent_dir = *.fav ]] && path_tier1="$file_parent_dir" || path_tier1="$file_parent_dir/.fav"
		[[ $file_parent_dir = *.lib ]] && path_tier2="$file_parent_dir" || path_tier2="$file_parent_dir/.lib"
		[[ $file_parent_dir = *.del ]] && path_tier5="$file_parent_dir" || path_tier5="$file_parent_dir/.del"

		# Ensure target video is available to view.
		if [[ ! -r $file_path ]]; then
			_cpl_out_error 7 "Video file not found or not readable. It may have been deleted after start of script." || return $?
		elif [[ ! -r $preview_pic_path ]]; then
			_cpl_out_error 8 "Preview sheet not found or not readable. It may have been deleted after start of script." || return $?
		fi

		# Open main preview window with buttons for controlling where the video
		# belongs, and whether to open it right now.
		yad --picture --width=1920 --height=1080 --maximized --center \
			--undecorated --borders=0 --size=fit --text="$pic_num_text" --filename="$preview_pic_path" \
			--button='!edit-redo!Go to next preview.':1 \
			--button='!filenew!Add video to bookmarks and go to next preview.':2 \
			--button='!appointment-missed!Add video to favourites and go to next preview.':3 \
			--button='!emblem-xapp-favorite!Add video to VIP and go to next preview.':4 \
			--button='!!' \
			--button='!list-add!Open the video and go to next preview.':5 \
			--button='!dropboxstatus-busy!Add to bookmarks, open the video and go to next preview.':6 \
			--button='!appointment-soon!Add to favorites, open the video and go to next preview.':7 \
			--button='!emblem-xapp-favorite!Add to VIP, open the video and go to next preview.':8 \
			--button='!!' \
			--button='!rotation-locked-symbolic!Archive and hide in future, and go to the next preview.':9 \
			--button='!list-add!Archive and hide in future, open the video and go to the next preview.':9 \
			--button='!!' \
			--button='!!' \
			--button='!list-remove!Delete video permanently and go to next preview.':10 \
			--button='!yad-quit!Exit the preview loop.':11

		# Handle 'yad' return value; The return value tells which action user
		# performed (or, most often, which button was pressed).
		case $? in

			# Go to next preview.
			1)
				printf 'Skipping to next preview.\n'
			;;

			# Add video to bookmarks and move to next preview.
			2)
				if [[ ! -d $path_tier2 || ! -w $path_tier2 ]]; then
					_cpl_out_error 36 "Bookmarks directory not found or not writable: $path_tier2" || return $?
				else
					printf 'Moving video to .lib (bookmarks) --> %s\n' $path_tier2/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier2/"
				fi
			;;

			# Add video to favorites and move to next preview.
			3)
				if [[ ! -d $path_tier1 || ! -w $path_tier1 ]]; then
					_cpl_out_error 24 "Favourites directory not found or not writable: $path_tier1" || return $?
				else
					printf 'Moving file to .fav (favourites) --> %s\n' $path_tier1/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier1/"
				fi
			;;

			# Add video to VIP and move to next preview.
			4)
				if [[ ! -d $path_tier0 || ! -w $path_tier0 ]]; then
					_cpl_out_error 24 "VIP directory not found or not writable: $path_tier0" || return $?
				else
					printf 'Moving video to .vip (VIP collection) --> %s\n' $path_tier0/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier0/"
				fi
			;;

			# Open the video and go to next preview.
			5)
				_cpl_plaympv "$file_path"
			;;

			# Add video to bookmarks, open the video and move to next preview.
			6)
				if [[ ! -d $path_tier2 || ! -w $path_tier2 ]]; then
					_cpl_out_error 36 "Bookmarks directory not found or not writable: $path_tier2" || return $?
				else
					printf 'Moving video to .lib (bookmarks) --> %s\n' $path_tier2/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier2/"
					file_path="$path_tier2/${file_path:t}"
					_cpl_plaympv "$file_path"
				fi
			;;

			# Add video to favorites, open the video and move to next preview.
			7)
				if [[ ! -d $path_tier1 || ! -w $path_tier1 ]]; then
					_cpl_out_error 24 "Favourites directory not found or not writable: $path_tier1" || return $?
				else
					printf 'Moving file to .fav (favourites) --> %s\n' $path_tier1/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier1/"
					file_path="$path_tier1/${file_path:t}"
					_cpl_plaympv "$file_path"
				fi
			;;

			# Add video to VIP, open the video and move to next preview.
			8)
				if [[ ! -d $path_tier0 || ! -w $path_tier0 ]]; then
					_cpl_out_error 37 "VIP directory not found or not writable: $path_tier0" || return $?
				else
					printf 'Moving video to .vip --> %s\n' $path_tier0/
					mv -n "${file_path%.*}".{${file_path:e},jpg} $path_tier0/
					file_path="$path_tier0/${file_path:t}"
					_cpl_plaympv "$file_path"
				fi
			;;

			# Add video to archive and move to next preview.
			9)
				if [[ ! -d $path_tier5 || ! -w $path_tier5 ]]; then
					_cpl_out_error 37 "The folder .del (purgatory) was not found or is not writable: $path_tier5" || return $?
				else
					printf 'Moving video to .del (archive) --> %s\n' $path_tier5/
					mv -n "${file_path%.*}".{${file_path:e},jpg} "$path_tier5/"
				fi
			;;

			# Delete video permanently and go to next preview.
			10)
				printf '!! Deleting current video and preview sheet.\n'
				rm -fv "${file_path%.*}".{${file_path:e},jpg}
			;;

			# Exit preview loop.
			11)
				return 0
			;;

			# Force exit or something
			127)
				printf "Loop stopped by forced exit. (127)\n"
				return 0
			;;

			# User exit by pressing esc
			252)
				printf "Escape button was pressed, stopping loop. (252)\n"
				return 0
			;;

			# Catch any weird bugs that should be impossible, but never know about yad..
			*)
				_cpl_out_error n $? "(Outside case limits) Invalid yad exit value: $?"
				return $?
			;;
		esac
	done
)}

#endregion

##==============================================================================
##== Private Helper Functions
##==============================================================================
#region Private Helper Functions

## * _cpl_out_msg()
## Print a helpful message. Mainly for cplprevloop().
_cpl_out_msg() {
	local nl=false
	[[ $1 == 'n' ]] && nl=true && shift
	(( $# > 1 )) && printf '\e[32m%s.\e[2m (%s)\e[0m\n' "$1" "$2" || printf '\e[32m%s\e[0m\n' "$1"
	$nl && printf '\n'
	return 0
}

## * _cpl_out_error()
## Print a helpful tip about an error. Mainly for cplprevloop().
_cpl_out_error() {
	local nl=false
	[[ $1 == 'n' ]] && nl=true && shift
	(( $# > 2 )) && printf '\e[1;31m(Error:%i) %s: \e[2m%s\e[0m\n' $1 "$2" "$3" >&2 || printf '\e[1;31m(Error:%i) %s\e[0m\n' $1 "$2" >&2
	$nl && printf '\n'
	return $1
}

## * _cpl_plaympv()
_cpl_plaympv() {
	if (($# == 0)); then
		printf 'Error: Filename not provided.\n' >&2 && return 1
	elif [[ ! -f $1 || ! -r $1 ]]; then
		printf 'Error: File not found or cannot be read.\n' >&2 && return 2
	else
		printf '\e[36;1m>> \e[34mOpening Video:\e[0m \033[38;2;60;110;190;1m  %s  \e[0m\n' "${1#./}"
		(mpv --pause "$1" &>/dev/null &)
	fi
}

#endregion

##==============================================================================
##== Old/WIP/Obsolete/Broken Code Vault
##==============================================================================
#region Old/WIP/Obsolete/Broken Code Vault

		#--button='!yad-no!Go to next preview.':1 \
		#--button='!yad-ok!Add video to bookmarks and go to next preview.':2 \
		#--button='!emblem-xapp-favorite!Add video to favourites and go to next preview.':3 \
		#--button='!starred-symbolic!Add video to VIP and go to next preview.':4 \
		#--button='!!' \
		#--button='!yad-open!Open the video and go to next preview.':5 \
		#--button='!yad-save!Add to bookmarks, open the video and go to next preview.':6 \
		#--button='!emblem-xapp-favorite!Add to favorites, open the video and go to next preview.':7 \
		#--button='!starred-symbolic!Add to VIP, open the video and go to next preview.':8 \
		#--button='!!' \
		#--button='!rotation-locked-symbolic!Archive video to hide from future previews and go to next preview.':9 \
		#--button='!yad-remove!Delete video permanently and go to next preview.':10 \
		#--button='!yad-quit!Exit the preview loop.':11

		#--button='!media-skip-forward-symbolic!Go to next preview.':1 \
		#--button='!star-new-symbolic!Add video to bookmarks and go to next preview.':2 \
		#--button='!starred-symbolic!Add video to favourites and go to next preview.':3 \
		#--button='!emblem-xapp-favorite!Add video to VIP and go to next preview.':4 \
		#--button='!!' \
		#--button='!dialog-question-symbolic!Open the video and go to next preview.':5 \
		#--button='!document-preview!Add to bookmarks, open the video and go to next preview.':6 \
		#--button='!edit-add!Add to favorites, open the video and go to next preview.':7 \
		#--button='!emblem-xapp-favorite!Add to VIP, open the video and go to next preview.':8 \
		#--button='!!' \
		#--button='!rotation-locked-symbolic!Archive video to hide from future previews and go to next preview.':9 \
		#--button='!edit-delete-symbolic!Delete video permanently and go to next preview.':10

# 		yad --width=1920 --height=1080 --center --maximized --undecorated --borders=0 --text="$pic_num_text" \
# 			--picture --filename="$preview_pic_path" --size=fit \
# 			--form --align=right --columns=1 --separator="|" \
# 			--field "!edit-redo!Continue (skip):BTN" \
# 			--field "!player_play!Open the video and continue:BTN" \
# 			--field "||:H" \
# 			--field "5!folder-heart!5 VIP+Play   Best of the best. Assign rating and play video:BTN" \
# 			--field "4!!4 FAVOURITE+Play   The good stuff. Assign rating and play video:BTN" \
# 			--field "3!!3 BOOKMARK+Play   Neutral, good stuff. Assign rating and play video:BTN" \
# 			--field "2!!2 COLLECTION+Play   All sorts of stuff, which may actually be better! Assign rating and play video:BTN" \
# 			--field "1!gtk-undelete!1 ARCHIVE+Play   Mediocre, so remove from loops, but keep the file. Assign rating and play video:BTN" \
# 			--field "||:H" \
# 			--field "1!gtk-undelete!1 ARCHIVE+Skip   Mediocre, so remove from loops, but keep the file. Assign rating and continue:BTN" \
# 			--field "2!!2 COLLECTION+Skip   All sorts of stuff, which may actually be better! Assign rating and continue:BTN" \
# 			--field "3!!3 BOOKMARK+Skip   Neutral, good stuff. Assign rating and continue:BTN" \
# 			--field "4!!4 FAVOURITE+Skip   The good stuff. Assign rating and continue:BTN" \
# 			--field "5!folder-heart!5 VIP+Skip   Best of the best. Assign rating and continue:BTN" \
# 			--field "||:H" \
# 			--field "1!emptytrash!1 TRASH   Some things seem good at first and turn out to be, well, not that:BTN" \
# 			--field "!yad-quit|Exit the preview loop:BTN"

#endregion
