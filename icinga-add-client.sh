#!/bin/bash
#set -x #debug
# set wight bright of whiptail
W_WIDTH=12
W_HEIGHT=60

# set standard parameters
FQND="server.imi.de"
IP_OF_FQND="123.123.123.123"
PATH_OF_FILES="/home/ssn/Projekte/icinga-add-client/"

# function to set fqnd
function fqnd_ft {
	FQND=$(whiptail --title "FQND of new client" --inputbox "Give me your clients FQND?" $W_WIDTH $W_HEIGHT $FQND 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
}
# function to set ip of fqnd
function ip_of_fqnd_ft {
	IP_OF_FQND=$(whiptail --title "IP of your new client" --inputbox "Give me the IP-Adresse of your new client?" $W_WIDTH $W_HEIGHT $IP_OF_FQND 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
	check_ip_valid gui
}
# function to set path of files - saveing folder
function path_of_files_ft {
	PATH_OF_FILES=$(whiptail --title "Path of file" --inputbox "Path to save new files?" $W_WIDTH $W_HEIGHT $PATH_OF_FILES 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
	check_path_of_file_ending
}
#function to check if ip is valid
function check_ip_valid() {
	# checks if ip is valid
	if [[ $IP_OF_FQND =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
		:
	else
		if [[ "$1" = "gui" ]]; then
			whiptail --title "Invalid IP" --msgbox "try again !..." $W_WIDTH $W_HEIGHT
			ip_of_fqnd_ft
		elif [[ "$1" = "silenc" ]]; then
			:
		else
			echo "invalid ip"
		fi
		:
	fi
}

function check_path_of_file_ending {
	if [[ $(echo "$PATH_OF_FILES"|grep '/$'|wc -l) -eq 0 ]]; then
		PATH_OF_FILES="$PATH_OF_FILES/"
	else
		:
	fi
}


#function to check if settings are correct
function check_if_correct {
# check if all correct
	if (whiptail --title "Everything Correct?" --yesno "FQND = $FQND \nIP = $IP_OF_FQND \nPath = $PATH_OF_FILES \n \nare those correct?" $W_WIDTH $W_HEIGHT) then
		# when settings are fine do: look at the path an check if files already exist with the same name
		# check if files exist
		if [[ $(find $PATH_OF_FILES -type f -name "$FQND.conf"|wc -l) -gt 0 ]];then
			# when files exist do: ask to overwrite
			if (whiptail --title "Some files already exist" --yesno "Should I overwrite your files Yes or No." $W_WIDTH $W_HEIGHT) then
	    	:
			else
	    	echo "Bye Bye"
				exit
			fi
		else # end of function check_if_correct - files not existing - settings are fine - do: function create files
			:
		fi
	else
		#if settings are not fine: ask which one are not fine
		CORRECT=$(whiptail --title "Which one do you want to correct" --checklist --separate-output \
		"Choose:" $W_WIDTH $W_HEIGHT 3 "FQND" "$FQND" OFF "IP" "$IP_OF_FQND" OFF "PATH" "$PATH_OF_FILES" OFF 3>&1 1>&2 2>&3)
		if [[ -z "$CORRECT" ]]; then
			#if settings was right do: create files
			check_if_correct
		else
			# checking checkboxes
		  while read CHOICE
		  do
		      case $CHOICE in
		        FQND\ IP\ PATH ) fqnd_ft
						ip_of_fqnd_ft
						path_of_files_ft
		        ;;
		        FQND\ IP ) fqnd_ft
						ip_of_fqnd_ft
		        ;;
		        IP\ PATH ) ip_of_fqnd_ft
						path_of_files_ft
		        ;;
		        FQND ) fqnd_ft
		        ;;
		        IP ) ip_of_fqnd_ft
		        ;;
		        PATH ) path_of_files_ft
		        ;;
		        *) echo "should not outputted"
		        ;;
		      esac
		  done <<< $CORRECT
			check_if_correct
		fi
	fi
}
# create / overwrite files
function create_files {
	echo "object Host \"$FQND\" {
        import \"generic-host\"
        address = \"$IP_OF_FQND\"
        vars.nrpe_agent = \"Ja\"
        vars.os = \"Linux\"
        vars.rolle = \"\"
        vars.standort = \"\"
        vars.vm = \"\"
        vars.notification[\"mail\"] = {
                groups = [ \"administratoren\" ]
        }
        vars.notification[\"pushover\"] = {
                groups = [ \"administratoren\" ]
        }
        vars.notification[\"pager\"] = {
                groups = [ \"administratoren\" ]
        }
}" > $PATH_OF_FILES$FQND.conf

if [[ $(find $PATH_OF_FILES -type d -name "$FQND"|wc -l) -gt 0 ]];then
	# when files exist do nothing
	:
else
	mkdir $PATH_OF_FILES$FQND
fi

	echo "object Service \"apachestatus\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"check_apachastatus\"
        vars.apache_hostname = \"$IP_OF_FQND\"
        vars.apache_slots_warn = \"150\"
        vars.apache_slots_critical = \"75\"
}" > $PATH_OF_FILES$FQND/apachestatus.conf

	echo "object Service \"apt\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_apt\"
	enable_notifications = \"0\"
}" > $PATH_OF_FILES$FQND/apt.conf

	echo "object Service \"disk\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_disk\"
}" > $PATH_OF_FILES$FQND/disk.conf

	echo "object Service \"disk inodes\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_disk_inodes\"
}" > $PATH_OF_FILES$FQND/disk_inodes.conf

	echo "object Service \"load\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_load\"
}" > $PATH_OF_FILES$FQND/load.conf

	echo "object Service \"md_raid\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_md_raid\"
}" > $PATH_OF_FILES$FQND/md_raid.conf

	echo "object Service \"net traffic\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
	enable_notifications = \"0\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_net_traffic\"
}" > $PATH_OF_FILES$FQND/net_traffic.conf

	echo "object Service \"reboot_required\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_reboot_required\"
	enable_notifications = \"0\"
}" > $PATH_OF_FILES$FQND/reboot_required.conf

	echo "object Service \"rsnapshot\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_rsnapshot\"
}" > $PATH_OF_FILES$FQND/rsnapshot.conf

	echo "object Service \"smart\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_smart\"
}" > $PATH_OF_FILES$FQND/smart.conf

	echo "object Service \"smart_lsi\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_smart_lsi\"
}" > $PATH_OF_FILES$FQND/smart_lsi.conf

	echo "object Service \"total procs\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_total_procs\"
}" > $PATH_OF_FILES$FQND/total_procs.conf

	echo "object Service \"users\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_users\"
}" > $PATH_OF_FILES$FQND/users.conf

	echo "object Service \"zombie procs\" {
        import \"generic-service\"
        host_name = \"$FQND\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQND\"
        vars.check = \"check_zombie_procs\"
}" > $PATH_OF_FILES$FQND/zombie_procs.conf
}

if [ "$#" -eq 0 ] ;then

# start of frotnend
# asking for fqnd
	fqnd_ft
# asking for ip of fqnd
	ip_of_fqnd_ft
# asking of path of folder where to save files
	path_of_files_ft
# asking if settings are correct
	check_if_correct
# creating files
	whiptail --title "Create files" --msgbox "creating files..." $W_WIDTH $W_HEIGHT
	create_files
	whiptail --title "Done" --msgbox "Already finished ;)" $W_WIDTH $W_HEIGHT

#elif [[ ("$@" = "-h")  ||  ("$@" = "--help") || ("$@" = "-help")]]; then
#	echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f fqnd  -i ip -p path \ne.g: icinga-newclient.sh -f $FQND -i $IP_OF_FQND -p $PATH_OF_FILES"
else
	while getopts f:i:p:h option
	do
		case "${option}" in
	  	f) FQND=${OPTARG};;
	    i) IP_OF_FQND=${OPTARG}
			check_ip_valid "nogui";;
	    p) PATH_OF_FILES=${OPTARG}
			check_path_of_file_ending;;
			*) echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f fqnd  -i ip -p path \ne.g: icinga-newclient.sh -f server.imi.de -i 123.123.123.123 -p /PATH/TO/SAVE/FILES"
			exit;;
		esac
	done
	create_files
fi
