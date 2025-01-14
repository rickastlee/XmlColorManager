#!/bin/bash

BOLD="\e[1m"
RED="\e[91m"
GREEN="\e[92m"
END="\e[0m"

OPTION_CREATE="Create a new project"
OPTION_OPEN="Open an existing project"
OPTION_DELETE="Delete a project"
OPTION_QUIT="Quit"
OPTION_BACKUP="Backup XML"
OPTION_RESTORE="Restore a backup"
OPTION_RM_FIRST_HALF="Remove first half"
OPTION_RM_SECOND_HALF="Remove second half"

MSG_CHOOSE="Choose one of the options below"
MSG_CONFIG="Enter some details below"
MSG_CHOICE="Choice: "
MSG_QUIT="Quitting..."
MSG_PROJECT_LIST="Below is a list of your existing projects."
MSG_BACKUP_LIST="Below is a list of your backups."
MSG_TO_DELETE="Choose one to delete."
MSG_TO_OPEN="Choose one to open."
MSG_TO_RESTORE="Choose one to restore."
MSG_CONFIRM_DELETE="Are you sure you want to delete the project"

INPUT_NAME="Name: "
INPUT_XML_PATH="XML path: "
INPUT_AUTO_BACKUP="Automatic backups (y/n): "

PROJECT_NAME_REGEX='^[a-zA-Z0-9\ ._-]{4,64}$'
NOT_NUMBER='[^0-9]'

# $1 bool at least one available project
display_menu () {
	clear
	echo -e "$MSG_CHOOSE\n"
	OPTIONS="$OPTION_CREATE"
	if [ $1 -eq 1 ]; then
		OPTIONS="$OPTIONS,$OPTION_OPEN,$OPTION_DELETE"
	fi
	OPTIONS="$OPTIONS,$OPTION_QUIT"
	
	IFS=',' read -r -a array <<< "$OPTIONS"
	
	len=-1
	for index in "${!array[@]}"; do
		echo "[$index] ${array[index]}"
		len=$(expr $len + 1)
	done

	echo ""
	while
		valid=1
		echo -e "$MSG_CHOICE\c"
		read c
		if [ -z $c ] || [[ "$c" =~ $NOT_NUMBER ]]; then
			valid=0
			printf "${BOLD}${RED}Please enter a number${END}\n\n"
		elif [ "$c" -gt $len ]; then
			valid=0
			printf "${BOLD}${RED}No option found with the ID ${c}${END}\n\n"
		fi	
		[ $valid -eq 0 ]
	do true; done
	
	run_command "${array[$c]}"
}

run_command()
{
	clear
	case "$1" in

		"$OPTION_QUIT")
			echo -e "$MSG_QUIT"
			exit 0
		;;

		"$OPTION_CREATE")
			echo -e "$MSG_CONFIG"
			LC_ALL=POSIX
			while
				valid=1
				echo -e "\n$INPUT_NAME\c"
				read name
				if ! [[ "$name" =~ $PROJECT_NAME_REGEX ]]; then
					valid=0
					printf "${BOLD}${RED}Invalid name${END}\n"
				elif [ -d "$PROJECTS/$name" ]; then
					valid=0
					printf "${BOLD}${RED}A project with this name already exists${END}\n"
				fi
				[ $valid -eq 0 ]
			do true; done
	
			while
				valid=1
				echo -e "\n$INPUT_XML_PATH\c"
				read xml_path
				
				if [ ! -e $xml_path ]; then
					valid=0
					printf "${BOLD}${RED}The path "$xml_path" does not exist\n${END}"
				elif [ ! -f $xml_path ]; then
					valid=0
					printf "${BOLD}${RED}The path "$xml_path" is not a file\n${END}"
				elif [[ "$xml_path" != *.xml ]]; then
					valid=0
					printf "${BOLD}${RED}The file "$xml_path" is not an XML\n${END}"
				fi
				[ $valid -eq 0 ]
			do true; done
			
			while
				echo -e "\n$INPUT_AUTO_BACKUP\c"
				read auto_backup
				[[ $auto_backup != "y" && $auto_backup != "n" ]]
			do
				printf "${BOLD}${RED}Invalid option: ${auto_backup}\n${END}"
			done
	
			PROJECT_DIR="$PROJECTS/$name"
			mkdir -p "$PROJECT_DIR" 
			cd "$PROJECT_DIR"
			touch .config
			echo "$xml_path" > .config
			echo $auto_backup >> .config
			printf "${BOLD}${GREEN}\nProject ${name} created successfully\n${END}"
		;;

		"$OPTION_DELETE")
			echo -e "$MSG_PROJECT_LIST $MSG_TO_DELETE\n"
			ls -A -1 "$PROJECTS"
			
			while
				echo -e "\n$MSG_CHOICE\c"
				read name
				[ ! -d "$PROJECTS/$name" ]
			do
				printf "${BOLD}${RED}No project named ${name} found.\n${END}"
			done

			while
				echo -e "\n$MSG_CONFIRM_DELETE $name (y/n): \c"
				read confirm
				[[ $confirm != "y" && $confirm != "n" ]]
			do
				printf "${BOLD}${RED}Invalid option: ${confirm}\n${END}"
			done
			if [ $confirm == "y" ]; then
				rm -rf "$PROJECTS/$name"
				printf "${BOLD}${GREEN}\nProject ${name} deleted successfully\n${END}"
			fi
		;;

		"$OPTION_OPEN")
			echo -e "$MSG_PROJECT_LIST $MSG_TO_OPEN\n"
			ls -At -1 "$PROJECTS" | awk '{print "[" NR "]", $0}'
			projects_count=$(ls -A -1 "$PROJECTS" | wc -l)

			while
				valid=1
				echo -e "\n$MSG_CHOICE\c"
				read p
				if [ -z "$p" ] || [[ "$p" =~ $NOT_NUMBER ]]; then
					valid=0
					printf "${BOLD}${RED}Please enter a number${END}\n"
				elif [ "$p" -gt $projects_count ]; then
					valid=0
					printf "${BOLD}${RED}Please enter a number between 1 and ${projects_count}${END}\n"
				fi
				[ $valid -eq 0 ]
			do true; done

			name=$(ls -At -1 "$PROJECTS" | head -n$p | tail -n1)

			clear
			PROJECT_DIR="$PROJECTS/$name"
			cd "$PROJECT_DIR"
			xml=$(head -n1 .config)
			auto_backup=$(tail -n1 .config)
			# echo "XML to open: "$xml""
			if [ ! -f "$xml" ]; then
				printf "${BOLD}${RED}\nThe XML ${xml} does not exist. Edit the project config.\n${END}"
			fi

			while true; do
				SECOND_HALF_END=$(expr $(wc -l < "$xml") - 3)
				FIRST_HALF_END=$(expr $SECOND_HALF_END / 2)
				SECOND_HALF_START=$(expr $FIRST_HALF_END + 1)
			
				echo -e "$MSG_CHOOSE\n"
				OPTIONS="$OPTION_BACKUP"

				if [ -d "$PROJECT_DIR/backups" ] && [ ! -z "$(ls -A "$PROJECT_DIR/backups")" ]; then
					OPTIONS="$OPTIONS,$OPTION_RESTORE"
				fi

				if [ $SECOND_HALF_END -gt 1 ]; then
					OPTIONS="$OPTIONS,$OPTION_RM_FIRST_HALF,$OPTION_RM_SECOND_HALF"
				fi

				OPTIONS="$OPTIONS,$OPTION_QUIT"

				IFS=',' read -r -a array <<< "$OPTIONS"

				len=-1
				for index in "${!array[@]}"; do
					echo "[$index] ${array[index]}"
					len=$(expr $len + 1)
				done

				echo ""
				while
					valid=1
					echo -e "$MSG_CHOICE\c"
					read c
					if [ -z $c ] || [[ "$c" =~ $NOT_NUMBER ]]; then
						valid=0
						printf "${BOLD}${RED}Please enter a number${END}\n\n"
					elif [ "$c" -gt $len ]; then
						valid=0
						printf "${BOLD}${RED}No option found with the ID ${c}${END}\n\n"
					fi	
					[ $valid -eq 0 ]
				do true; done

				command="${array[$c]}"

				clear
				case "$command" in

					"$OPTION_QUIT")
						echo -e "$MSG_QUIT"
						exit 0
					;;

					"$OPTION_BACKUP")
						backup "$PROJECT_DIR" "$xml"
					;;

					"$OPTION_RESTORE")
						echo -e "$MSG_BACKUP_LIST $MSG_TO_RESTORE\n"
						ls -At -1 "$PROJECT_DIR/backups" | awk '{print "[" NR "]", $0}'
						backups_count=$(ls -A -1 "$PROJECT_DIR/backups" | wc -l)

						while
							valid=1
							echo -e "\n$MSG_CHOICE\c"
							read b
							if [ -z "$b" ] || [[ "$b" =~ $NOT_NUMBER ]]; then
								valid=0
								printf "${BOLD}${RED}Please enter a number${END}\n"
							elif [ "$b" -gt $backups_count ]; then
								valid=0
								printf "${BOLD}${RED}Please enter a number between 1 and ${backups_count}${END}\n"
							fi
							[ $valid -eq 0 ]
						do true; done

						TO_RESTORE=$(ls -At -1 "$PROJECT_DIR/backups" | head -n$b | tail -n1)
						rm "$xml"
						cp "$PROJECT_DIR/backups/$TO_RESTORE/$(ls "$PROJECT_DIR/backups/$TO_RESTORE")" "$xml"
						clear
					;;

					"$OPTION_RM_FIRST_HALF")
						cat "$xml" | head -n2 > "tmp.xml"
						cat "$xml" | tail -n$(expr $SECOND_HALF_END - $FIRST_HALF_END + 1) >> "tmp.xml"
						cp "tmp.xml" "$xml"
						rm "tmp.xml"
						auto_backup "$auto_backup" "$PROJECT_DIR" "$xml"
					;;

					"$OPTION_RM_SECOND_HALF")
						cat "$xml" | head -n$(expr $FIRST_HALF_END + 2) > "tmp.xml"
						cat "$xml" | tail -n1 >> "tmp.xml"
						cp "tmp.xml" "$xml"
						rm "tmp.xml"
						auto_backup "$auto_backup" "$PROJECT_DIR" "$xml"
					;;
				esac
			done
		;;
	esac
}

backup()
{
	BACKUP_NAME=$(date "+%Y-%m-%d %T")
	BACKUP_DIR="$1/backups"
	mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
	cp "$2" "$BACKUP_DIR/$BACKUP_NAME"
}

auto_backup()
{
	if [ $1 == "y" ]; then
		backup "$2" "$3"
	fi
}

if [ -z "$TERMUX_VERSION" ]; then
	INTERNAL_STORAGE="$HOME"
else
	INTERNAL_STORAGE="$HOME/storage/shared"
fi

WORKDIR="$INTERNAL_STORAGE/XmlColorManager"
PROJECTS="$WORKDIR/projects"

if [ ! -d "$PROJECTS" ] || [ -z "$(ls -A "$PROJECTS")" ]; then
	display_menu 0
else
	display_menu 1
fi
