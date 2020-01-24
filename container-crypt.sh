#!/bin/bash
# Script for creating and mounting/unmounting encrypted container using standard dmcrypt settings


#Checks for sudo and cryptsetup (dm-crypt)
[ "$(command -v sudo | grep -ic sudo)"  -lt 1 ] && [ "$(command -v cryptsetup | grep -ic cryptsetup)" -lt 1 ] && printf "\nSudo or cryptsetup missing! Please install using you package manager.\n" && exit 1

#Escalate To root with sudo if not already root  
[ "$(whoami)" != "root" ] && printf "Requires elevated privledges for dmcrypt and mount/umount, sudoing into script\n" && exec sudo -- "$0"  

#Chekcs if root is sudo or actual root user, requires sudo to find user folder while operating as superuser
[ "$(whoami)" == "root" ] && [ "$SUDO_USER" == "" ] && printf "\nDo not run as root! Run script as user!\n" && exit 1

if [ -f /home/"$SUDO_USER"/.config/container-crypt.conf ]; then

	#Loads variables from config file
	CONFIG=$(sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g' /home/"$SUDO_USER"/.config/container-crypt.conf)
	eval "$CONFIG"

	#While loop that allows to stay within menu unit exited 
	while true; do
		printf "\n-------------------\n| Container-crypt |\n-------------------\n"
		printf "\nMounts or unmounts encrypted container "'"%s"'" stored in "'"%s"'" to/from "'"%s"'"\n\n" "$CONTAINERNAME" "$CONTAINERPATH" "$MOUNTPATH"
		PS3='Please select: '
		options=("Mount volume" "Unmount Volume" "Quit")
		select opt in "${options[@]}"
		do
			case $opt in
				"Mount volume")
					#Checks if volume specified in config is already mounted
					MNT_TEST=${MOUNTPATH%?}
					printf "\n%s\n" "$MNT_TEST"
					if grep -qs "$MNT_TEST "  /proc/mounts; then
						printf "\nVolume already mounted!\n"
						read -n 1 -s -r -p "Press enter to continue"
						break
					else

						printf "Mounting encrypted folder in ~/%s\n" "$MOUNTPATH"
						printf "Please enter password when requested...\n"
						#Mounts volume and exits on error
						if [ "$(cryptsetup -v luksOpen "$CONTAINERPATH"/"$CONTAINERNAME" "$CONTAINERNAME"_container)" ]; then
							mount /dev/mapper/"$CONTAINERNAME"_container "$MOUNTPATH"
							chown "$SUDO_USER":"$SUDO_USER" "$MOUNTPATH"
							printf "Successfully mounted private volume\n"
							read -n 1 -s -r -p "Press enter to quit"
							printf "\n"				
							exit 1
						else
							printf "Failed to unlock volume!\n"
							read -n 1 -s -r -p "Press enter to continue"
							break
						fi
					fi
					;;
				"Unmount Volume")
					umount "$MOUNTPATH"
					cryptsetup luksClose "$CONTAINERNAME"_container
					printf "Succesfully umounted and locked private volume\n"
					read -n 1 -s -r -p "Press any key to exit"
					printf "\n"
					exit 1	
					;;
				"Quit")
					exit 1	
					;;
				*) printf "Invalid option %s\n" "$REPLY";;
			esac
		done
	done
else

	#Checks if container is open and unlocked, but leaves it to the user to decide what to do
	[ "$(dmsetup ls | grep -ic _container)" -ge 1 ] && printf "\nContainer already open, please run "'"cryptsetup luksClose /dev/mapper/*_container"'" before retrying\n" && exit 1

	printf "\n\nNo config file found in ~/%s/.config/, creating new encrypted container (Ctrl+C/D to exit)\n" "$SUDO_USER"
	printf "Consider cleaning up previous mountpaths and containers before proceeding!\n"
	printf "\nYou will be propmted for password 2 times. This is _not_ your user or root password!\n\nPlease enter desired password for container encryption.\n The prompts are for entry and verifcation of container password.\n"	
	printf "\nPlease follow instructions closely, error handling is limited\n"

			#Store size  and verify size is number
			printf "\nEnter desired container size in GiB:\n"
			read -r SIZE
			if ! [[ "$SIZE" =~ ^[0-9]+$ ]]
			then
				printf "Sorry integers only\n"
				exit 1
			fi

			#Store container name
			printf "\nEnter desired container name, default is PRIVATE (no directory characters \/. etc.)\n"
			read -r CONTAINERNAME
			[ "$CONTAINERNAME" == "" ] && CONTAINERNAME=PRIVATE 	
			echo "$CONTAINERNAME"			
			
			#Create the Container path	
			printf "\nEnter container storage location, default is ~/%s/Documents/ (will create missing folders in path)\n" "$SUDO_USER"
			read -r CONTAINERPATH
			echo "$CONTAINERPATH"
			[ "$CONTAINERPATH" == "" ] && CONTAINERPATH="/home/$SUDO_USER/Documents/"
			[ "$CONTAINERNAME" == "$CONTAINERPATH" ] && printf "\n\nMount location and name must differ!\n" && exit 1
			mkdir -p "$CONTAINERPATH"	

			#Create the mount folder and path
			printf "\nEnter desired mount location, default is ~/%s/Documents/Private/\n" "$SUDO_USER"
			read -r MOUNTPATH
			[ "$MOUNTPATH" == "" ] && MOUNTPATH="/home/$SUDO_USER/Documents/Private/"
			mkdir -p "$MOUNTPATH"
			
			#Allocate container with specified size using fallocate in given position
			printf "\nAllocating container...\n"
			if [ "$(fallocate -l "$SIZE"G "$CONTAINERPATH"/"$CONTAINERNAME")" ]; then
				printf "Creating encrypted volume inside container...\n\n"
			else
				printf "Failed to allocate container, enough free disk space?!\n"
				exit 1 
			fi
			
			#Creates luksFS format inside partition using minimum recommendatations from archwiki or higher. Removes allocated container if generation fails
			if [ "$(cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 3000 luksFormat "$CONTAINERPATH"/"$CONTAINERNAME")" ]; then
				printf "\nOpening encrypted volume\n\n"
			else
				printf "Failed to create encrypted volume inside container...\n"
				rm "$CONTAINERPATH"/"$CONTAINERNAME"
				exit 1                                                 
			fi  

			#Opens newly generated archive			
			if [ "$(cryptsetup -v luksOpen "$CONTAINERPATH"/"$CONTAINERNAME" "$CONTAINERNAME"_container)" ]; then
				printf "\nFormatting encrypted volume with ext4\n" 
			else
				printf "Failed to open container, wrong password?\n"
				rm "$CONTAINERPATH"/"$CONTAINERNAME"
				exit 1
			fi  

			#Formats the container using ext4 file system
			if [ "$(mkfs -t ext4 /dev/mapper/"$CONTAINERNAME"_container)" ]; then
				printf "\n\nAttempting to mount containter\n"                 
			else                   
				printf "Failed to create ext4 in container! Invalid container folder path?\n"
				rm "$CONTAINERPATH"/"$CONTAINERNAME"
				exit 1                                 
			fi   
			
			#Closes the newly created container
			cryptsetup luksClose "$CONTAINERNAME"_container

			#Write locations and names to config file
			printf "Writing config file to /home/%s/.config/container-crypt.conf\n" "$SUDO_USER"
			touch /home/"$SUDO_USER"/.config/container-crypt.conf
			echo "MOUNTPATH=$MOUNTPATH" > /home/"$SUDO_USER"/.config/container-crypt.conf
			echo "CONTAINERPATH=$CONTAINERPATH" >> /home/"$SUDO_USER"/.config/container-crypt.conf
			echo "CONTAINERNAME=$CONTAINERNAME" >> /home/"$SUDO_USER"/.config/container-crypt.conf	
			printf "\n\n"

			#Change ownership of newly created files to be that of user
			chown "$SUDO_USER":"$SUDO_USER" /home/"$SUDO_USER"/.config/container-crypt.conf
			chown "$SUDO_USER":"$SUDO_USER" "$CONTAINERPATH"
			chown "$SUDO_USER":"$SUDO_USER" "$CONTAINERPATH"/"$CONTAINERNAME"
			chown "$SUDO_USER":"$SUDO_USER" "$MOUNTPATH"
fi			

