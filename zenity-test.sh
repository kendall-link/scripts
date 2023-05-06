#!/bin/bash

updates="$(apt list --upgradable 2>/dev/null | grep upgradable | wc -l)"
echo $updates

if [ $updates != 0 ]
then

  rc=1 # OK button return code =0 , all others =1

  while [ $rc -eq 1 ]; do
    ans=$(zenity --info --title 'Linux Updater' \
        --text 'There are '$updates' Security and Application updates available for your system' \
        --ok-label Quit \
        --extra-button 'Update Now' \
        )
    rc=$?
    echo "${rc}-${ans}"
    echo $ans
    if [[ $ans = "Update Now" ]]
    then
          echo "Updating system"
          PASSWORD=$(zenity --password --title 'Linux Updater')
          echo $PASSWORD | sudo -S sudo apt-get --with-new-pkgs upgrade | zenity --progress --title="Linux Updater"
          rc=0
    fi
  done

fi