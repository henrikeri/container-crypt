#!/bin/bash
# Script for mounting Encrypted Folder

printf "\n-------------------\n| Container-crypt |\n-------------------\n\nCreate, open or close encrypted container in "'"'~/$SUDO_USER/Documents'"'" requires elevated privileges\n\n"

#Chekcs if root is sudo or actual root user, requires sudo to find user folder
[ "$(whoami)" == "root" ] && [ "$SUDO_USER" == "" ] && printf "\nDo not run as root! Run script as user!\n" && exit 1

#Escalate To root with sudo if not already root
[ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"





PS4=' Please select: '
options=("Mount volume" "Unmount Volume" "Setup" "Quit")
select opt in "${options[@]}"
do
	case $opt in
		"Mount volume")
			printf "Mounting encrypted folder in ~/Documents/Private\n"
			printf "Please enter password when requested...\n"
			
			cryptsetup -v luksOpen /home/$SUDO_USER/Documents/PRIVATE container
			if [ $? -eq 0 ]; then
				mount /dev/mapper/container /home/$SUDO_USER/Documents/Private
				printf "Successfully mounted private volume\n"
				break
			else
				printf "Failed to unlock volume!\n"
				break
			fi
			;;
		"Unmount Volume")
			umount /home/$SUDO_USER/Documents/Private
			cryptsetup luksClose container
			printf "Succesfully umounted and locked private volume\n"
			break
			;;
		"Setup")
			printf "Creating new encrypted container (Ctrl+C/D to exit)\n"
			
			#Store size  and verify size is number
			printf "Enter desired size in GiB:\n"
			read SIZE
			if ! [[ "$SIZE" =~ ^[0-9]+$ ]]
    				then
        			printf "Sorry integers only\n"
				break
			fi

			#Store container name
			printf "Enter container name, default is PRIVATE (no directory characters \/. etc.)\n"
			read NAME
			[ "$NAME" == "" ] && NAME=PRIVATE
						
			#Create the Container path	
			printf "Enter container storage location, default is ~/$SUDO_USER/Documents/ (will create missing folders in path)\n"
			read CONTAINERPATH
			[ "$NAME" == "$CONTAINERPATH" ] && printf "Mount location and name must differ!\n" && exit 1
			[ "$CONTAINERPATH" == "" ] && CONTAINERPATH="/home/$SUDO_USER/Documents/"
			mkdir -p $CONTAINERPATH	
			
			#Create the mount folder and path
			printf "Enter desired mount location, default is ~/$SUDO_USER/Documents/Private/\n"
			read MOUNTPATH
			[ "$MOUNTPATH" == "" ] && MOUNTPATH="/home/$SUDO_USER/Documents/Private/"
			mkdir -p $MOUNTPATH



			printf "Allocating container...\n"
			fallocate -l "$SIZE"G $CONTAINERPATH/$NAME
			if [ $? -eq 0 ]; then
		                printf "Creating encrypted volume inside container...\n\n"
			 	 
			else
                                printf "Failed to allocate container, enough free disk space?!\n"
                                break
			fi
			
			  
			  
			 cryptsetup -v luksFormat $CONTAINERPATH/$NAME
                         if [ $? -eq 0 ]; then
				printf "Opening encrypted volume\n\n"
                         else
                                printf "Failed to create encrypted volume inside container...\n"
                                rm $CONTAINERPATH/$NAME
				break                                                 
                         fi  

			
			  
			 cryptsetup -v luksOpen $CONTAINERPATH/$NAME "$NAME"_container
                         if [ $? -eq 0 ]; then
                         	printf "Formatting encrypted volume with ext4\n" 
                         else
                                printf "Failed to open container, wrong password?\n"
                                rm $CONTAINERPATH/$NAME
				break                                                 
                         fi  


			 mkfs -t ext4 /dev/mapper/"$NAME"_container
			 if [ $? -eq 0 ]; then  
                                printf "Attempting to mount containter\n"                 
                         else                   
                                printf "Failed to create ext4 in container! Invalid container folder path?\n"
                                rm $CONTAINERPATH/$NAME
                                break                                 
                         fi   
			
			
			
			printf "Attempting to mount, unmount and close container\n\n"
			mkdir -p $MOUNTPATH
			mount /dev/mapper/"$NAME"_container $MOUNTPATH
			if [ $? -eq 0 ]; then
				printf "Unmounting and closing container!\n"
                        else
                                printf "Failed to mount container! Invalid mount folder path?\n"
                                rm $CONTAINERPATH/$NAME
                                break
			fi
			umount $MOUNTPATH
			cryptsetup luksClose "$NAME"_container
			
			printf "\n\n" 
			break
			;;
		"Quit")
			break
			;;
		*) printf "Invalid option $REPLY\n";;
	esac
done


