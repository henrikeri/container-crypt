#!/bin/bash
# Script for creating and mounting/unmounting encrypted container using standard dmcrypt settings

clear
printf "\n-------------------\n| Container-crypt |\n-------------------\n"

#Escalate To root with sudo if not already root
[ "$(whoami)" != "root" ] && printf "\nRequires elevated privledges for dmcrypt and mount/umount\n" && exec sudo -- "$0" "$@"  

#Chekcs if root is sudo or actual root user, requires sudo to find user folder
[ "$(whoami)" == "root" ] && [ "$SUDO_USER" == "" ] && printf "\nDo not run as root! Run script as user!\n" && exit 1


if [ -f /home/$SUDO_USER/.config/container-crypt.conf ]; then

	CONFIG=$(cat /home/$SUDO_USER/.config/container-crypt.conf | sed -r '/[^=]+=[^=]+/!d;s/\s+=\s/=/g')
	eval "$CONFIG"
	clear
	while true; do
		printf "\n-------------------\n| Container-crypt |\n-------------------\n\nMounts or unmounts encrypted container "'"'$CONTAINERNAME'"'" stored in "'"'$CONTAINERPATH'"'" to/from "'"'$MOUNTPATH'"'",  requires elevated privileges\n\n"

		PS3='Please select: '
		options=("Mount volume" "Unmount Volume" "Quit")
		select opt in "${options[@]}"
		do
			case $opt in
				"Mount volume")
					MNT_TEST=${MOUNTPATH%?}
					printf "\n$MNT_TEST\n"
					if grep -qs "$MNT_TEST "  /proc/mounts; then
						printf "\nVolume already mounted!\n"
						read -n 1 -s -r -p "Press enter to continue"
						break
					else

						printf "Mounting encrypted folder in ~/$MOUNTPATH\n"
						printf "Please enter password when requested...\n"
						cryptsetup -v luksOpen $CONTAINERPATH/$CONTAINERNAME "$CONTAINERNAME"_container

			#cryptsetup -v luksOpen /home/$SUDO_USER/Documents/PRIVATE container
			if [ $? -eq 0 ]; then
				#mount /dev/mapper/container /home/$SUDO_USER/Documents/Private
				mount /dev/mapper/"$CONTAINERNAME"_container $MOUNTPATH
				chown $SUDO_USER $MOUNTPATH
				chgrp $SUDO_USER $MOUNTPATH
				printf "Successfully mounted private volume\n"
				read -n 1 -s -r -p "Press enter to quit"
				exit 1
			else
				printf "Failed to unlock volume!\n"
				read -n 1 -s -r -p "Press enter to continue"
				break
			fi
					fi
					;;
				"Unmount Volume")
					umount $MOUNTPATH
					cryptsetup luksClose "$CONTAINERNAME"_container
					printf "Succesfully umounted and locked private volume\n"
					read -n 1 -s -r -p "Press any key to exit"
					exit 1	
					;;
				"Quit")
					exit 1	
					;;
				*) printf "Invalid option $REPLY\n";;
			esac
		done
		clear
	done

else




	[ "$(dmsetup ls | grep -ic _container)" -ge 1 ] && printf "\nContainer already open, please run "'"cryptsetup luksClose /dev/mapper/*_container"'" before retrying\n" && exit 1



	printf "\n\nNo config file found in ~/$SUDO_USER/.config/, creating new encrypted container (Ctrl+C/D to exit)\n"
	printf "Consider cleaning up previous mountpaths and containers before proceeding!\n"
	printf "\nYou will be propmted for password 3 times. This is _not_ your user or root password!\n\nPlease enter desired password for container encryption. First two prompts are for entry and verifcation. Third is for mount and unmount test.\n"	

	printf "\nPlease follow instructions closely, error handling is limited\n"

			#Store size  and verify size is number
			printf "\nEnter desired container size in GiB:\n"
			read SIZE
			if ! [[ "$SIZE" =~ ^[0-9]+$ ]]
			then
				printf "Sorry integers only\n"
				exit 1
			fi

			#Store container name
			printf "\nEnter desired container name, default is PRIVATE (no directory characters \/. etc.)\n"
			read CONTAINERNAME
			[ "$CONTAINERNAME" == "" ] && CONTAINERNAME=PRIVATE 	

			echo "$CONTAINERNAME"			
			#Create the Container path	
			printf "\nEnter container storage location, default is ~/$SUDO_USER/Documents/ (will create missing folders in path)\n"
			read CONTAINERPATH
			echo "$CONTAINERPATH"
			[ "$CONTAINERPATH" == "" ] && CONTAINERPATH="/home/$SUDO_USER/Documents/"
			[ "$CONTAINERAME" == "$CONTAINERPATH" ] && printf "\n\nMount location and name must differ!\n" && exit 1
			mkdir -p $CONTAINERPATH	

			#Create the mount folder and path
			printf "\nEnter desired mount location, default is ~/$SUDO_USER/Documents/Private/\n"
			read MOUNTPATH
			[ "$MOUNTPATH" == "" ] && MOUNTPATH="/home/$SUDO_USER/Documents/Private/"
			mkdir -p $MOUNTPATH



			printf "\nAllocating container...\n"
			fallocate -l "$SIZE"G $CONTAINERPATH/$CONTAINERNAME
			if [ $? -eq 0 ]; then
				printf "Creating encrypted volume inside container...\n\n"

			else
				printf "Failed to allocate container, enough free disk space?!\n"
				exit 1 
			fi


			cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 3000 luksFormat $CONTAINERPATH/$CONTAINERNAME


			if [ $? -eq 0 ]; then
				printf "\nOpening encrypted volume\n\n"
			else
				printf "Failed to create encrypted volume inside container...\n"
				rm $CONTAINERPATH/$CONTAINERNAME
				exit 1                                                 
			fi  



			cryptsetup -v luksOpen $CONTAINERPATH/$CONTAINERNAME "$CONTAINERNAME"_container
			if [ $? -eq 0 ]; then
				printf "\nFormatting encrypted volume with ext4\n" 
			else
				printf "Failed to open container, wrong password?\n"
				rm $CONTAINERPATH/$CONTAINERNAME
				exit 1
			fi  


			mkfs -t ext4 /dev/mapper/"$CONTAINERNAME"_container
			if [ $? -eq 0 ]; then  
				printf "\n\nAttempting to mount containter\n"                 
			else                   
				printf "Failed to create ext4 in container! Invalid container folder path?\n"
				rm $CONTAINERPATH/$CONTAINERNAME
				exit 1                                 
			fi   



			printf "\nAttempting to mount, unmount and close container\n\n"
			mkdir -p $MOUNTPATH
			mount /dev/mapper/"$CONTAINERNAME"_container $MOUNTPATH
			if [ $? -eq 0 ]; then
				printf "\nUnmounting and closing container!\n"
			else
				printf "Failed to mount container! Invalid mount folder path?\n"
				rm $CONTAINERPATH/$CONTAINERNAME
				exit 1
			fi
			umount $MOUNTPATH
			cryptsetup luksClose "$CONTAINERNAME"_container

			printf "Writing config file to /home/$SUDO_USER/.config/container-crypt.conf\n"
			touch /home/$SUDO_USER/.config/container-crypt.conf
			$(echo "MOUNTPATH=$MOUNTPATH" > /home/$SUDO_USER/.config/container-crypt.conf)
			$(echo "CONTAINERPATH=$CONTAINERPATH" >> /home/$SUDO_USER/.config/container-crypt.conf)
			$(echo "CONTAINERNAME=$CONTAINERNAME" >> /home/$SUDO_USER/.config/container-crypt.conf)	
			printf "\n\n"



			#Change ownership of newly created files to be that of user
			$(chown $SUDO_USER /home/$SUDO_USER/.config/container-crypt.conf)
			$(chgrp $SUDO_USER /home/$SUDO_USER/.config/container-crypt.conf)

			$(chown $SUDO_USER $CONTAINERPATH)
			$(chgrp $SUDO_USER $CONTAINERPATH)

			$(chown $SUDO_USER $CONTAINERPATH/$CONTAINERNAME)
			$(chgrp $SUDO_USER $CONTAINERPATH/$CONTAINERNAME)

			$(chown $SUDO_USER $MOUNTPATH)
			$(chgrp $SUDO_USER $MOUNTPATH)

fi			

