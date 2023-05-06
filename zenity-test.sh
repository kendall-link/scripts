#!/bin/bash

# Determine the number of packages that are upgradeable
updates="$(apt list --upgradable 2>/dev/null | grep upgradable | wc -l)"

echo $updates # Check to validate the number of avalable updates

# If there are no packages to update, exit.  Otherwise enter the IF.
if [ $updates != 0 ]
then

  # Set the return code (rc) to a value of 1
  rc=1
  
  # As long as the rc value is equal to one, it will stay in the do while loop.
  while [ $rc -eq 1 ]; do

    choice=$(zenity --info --title 'Linux Updater' \
        --text "There's $updates Security and Application update(s) available for your system" \
        --ok-label Quit \
        --extra-button 'Update Now' \
        )
    rc=$?

    echo "${rc}-${choice}" # Check to validate rc value and user choice

    if [[ $choice = "Update Now" ]]
    then

          echo "Updating system" # Check to validate it's in the Update Now loop

          PASSWORD=$(zenity --password --title 'Linux Updater')
          echo $PASSWORD | sudo -S sudo apt-get --with-new-pkgs upgrade | zenity --progress --title="Linux Updater"
          rc=0
    fi
  done

fi