#!/bin/bash
# Script for mounting Encrypted Folder

#Get home folder of user and elevate to root
echo "Lock or unlock encrypted volume in "'"'~/$USER/Documents'"'" requires elevated privileges"
[ "$(whoami)" != "root" ] && exec sudo -- "$0" "$@"

PS3='Please select: '
options=("Mount volume" "Unmount Volume" "Quit")
select opt in "${options[@]}"
do
	case $opt in
		"Mount volume")
			echo "Mounting encrypted folder in ~/Documents/Private"
			echo "Please enter password when requested..."
			
			cryptsetup -v luksOpen /home/$SUDO_USER/Documents/PRIVATE private_file
			if [ $? -eq 0 ]; then
				mount /dev/mapper/private_file /home/$SUDO_USER/Documents/Private
				echo "Successfully mounted private volume"
				break
			else
				echo "Failed to unlock volume!"
				break
			fi
			;;
		"Unmount Volume")
			umount /home/$SUDO_USER/Documents/Private
			cryptsetup luksClose private_file
			echo "Succesfully umounted and locked private volume"
			break
			;;
		"Quit")
			break
			;;
		*) echo "Invalid option $REPLY";;
	esac
done


