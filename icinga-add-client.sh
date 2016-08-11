#!/bin/bash
#set -x #debug
# set width and height of whiptail window
W_WIDTH=12
W_HEIGHT=60

# set standard parameters
FQDN="server.imi.de"
IP_OF_FQDN="123.123.123.123"
PATH_OF_FILES="/etc/icinga2/conf.d/hosts/"

# function to set FQDN
function FQDN_ft {
	FQDN=$(whiptail --title "FQDN of new client" --inputbox "Give me your host's FQDN?" $W_WIDTH $W_HEIGHT $FQDN 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
}
# function to save the ip of the host as variable
function ip_of_FQDN_ft {
	IP_OF_FQDN=$(whiptail --title "IP address of your new host" --inputbox "Enter your IP address of the new host?" $W_WIDTH $W_HEIGHT $IP_OF_FQDN 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
	check_ip_valid gui
}
# function to set where the files should be stored
function path_of_files_ft {
	PATH_OF_FILES=$(whiptail --title "Path to store files" --inputbox "Where should the files be stored?" $W_WIDTH $W_HEIGHT $PATH_OF_FILES 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
	check_path_of_file_ending
}
#function to check if IP address is valid
function check_ip_valid() {
	# checks if IP address is valid
	if [[ $IP_OF_FQDN =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
		:
	else
		if [[ "$1" = "gui" ]]; then
			whiptail --title "Invalid IP address" --msgbox "Please try again ..." $W_WIDTH $W_HEIGHT
			ip_of_FQDN_ft
		else
			echo "invalid IP address"
		fi
		:
	fi
}

# function to check if the path ends with a slash
function check_path_of_file_ending {
	if [[ $(echo "$PATH_OF_FILES"|grep '/$'|wc -l) -eq 0 ]]; then
		PATH_OF_FILES="$PATH_OF_FILES/"
	else
		:
	fi
}


# function to check if settings are correct
function check_if_correct {
# check if all settings are correct
	if (whiptail --title "Check settings" --yesno "FQDN = $FQDN \nIP = $IP_OF_FQDN \nPath = $PATH_OF_FILES \n \nare those correct?" $W_WIDTH $W_HEIGHT) then
		# check if configuration file for this host alreday exists
		if [[ $(find $PATH_OF_FILES -type f -name "$FQDN.conf"|wc -l) -gt 0 ]];then
			# when file exist - do: ask to overwrite
			if (whiptail --title "Configuration file already exists" --yesno "Should I overwrite your files?" $W_WIDTH $W_HEIGHT) then
	    	:
			else
	    	echo "Not overwriting files"
				exit
			fi
		else
			:
		fi
	else
		#if settings are not correct: ask which one are not correct
		CORRECT=$(whiptail --title "Which one do you want to correct" --checklist --separate-output \
		"Choose:" $W_WIDTH $W_HEIGHT 3 "FQDN" "$FQDN" OFF "IP" "$IP_OF_FQDN" OFF "PATH" "$PATH_OF_FILES" OFF 3>&1 1>&2 2>&3)
		if [[ -z "$CORRECT" ]]; then
			#if settings are correct do
			check_if_correct
		else
			# checking checkboxes
		  while read CHOICE
		  do
		      case $CHOICE in
		        FQDN\ IP\ PATH ) FQDN_ft
						ip_of_FQDN_ft
						path_of_files_ft
		        ;;
		        FQDN\ IP ) FQDN_ft
						ip_of_FQDN_ft
		        ;;
		        IP\ PATH ) ip_of_FQDN_ft
						path_of_files_ft
		        ;;
		        FQDN ) FQDN_ft
		        ;;
		        IP ) ip_of_FQDN_ft
		        ;;
		        PATH ) path_of_files_ft
		        ;;
		      esac
		  done <<< $CORRECT
			# ask again if settings are correct
			check_if_correct
		fi
	fi
}
# create / overwrite files
function create_files {
	echo "object Host \"$FQDN\" {
        import \"generic-host\"
        address = \"$IP_OF_FQDN\"
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
}" > $PATH_OF_FILES$FQDN.conf

if [[ $(find $PATH_OF_FILES -type d -name "$FQDN"|wc -l) -gt 0 ]];then
	# when files exist do nothing
	:
else
	mkdir $PATH_OF_FILES$FQDN
fi

	echo "object Service \"apachestatus\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"check_apachastatus\"
        vars.apache_hostname = \"$IP_OF_FQDN\"
        vars.apache_slots_warn = \"150\"
        vars.apache_slots_critical = \"75\"
}" > $PATH_OF_FILES$FQDN/apachestatus.conf

	echo "object Service \"apt\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_apt\"
	enable_notifications = \"0\"
}" > $PATH_OF_FILES$FQDN/apt.conf

	echo "object Service \"disk\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_disk\"
}" > $PATH_OF_FILES$FQDN/disk.conf

	echo "object Service \"disk inodes\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_disk_inodes\"
}" > $PATH_OF_FILES$FQDN/disk_inodes.conf

	echo "object Service \"load\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_load\"
}" > $PATH_OF_FILES$FQDN/load.conf

	echo "object Service \"md_raid\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_md_raid\"
}" > $PATH_OF_FILES$FQDN/md_raid.conf

	echo "object Service \"net traffic\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
	enable_notifications = \"0\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_net_traffic\"
}" > $PATH_OF_FILES$FQDN/net_traffic.conf

	echo "object Service \"reboot_required\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_reboot_required\"
	enable_notifications = \"0\"
}" > $PATH_OF_FILES$FQDN/reboot_required.conf

	echo "object Service \"rsnapshot\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_rsnapshot\"
}" > $PATH_OF_FILES$FQDN/rsnapshot.conf

	echo "object Service \"smart\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_smart\"
}" > $PATH_OF_FILES$FQDN/smart.conf

	echo "object Service \"smart_lsi\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_smart_lsi\"
}" > $PATH_OF_FILES$FQDN/smart_lsi.conf

	echo "object Service \"total procs\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_total_procs\"
}" > $PATH_OF_FILES$FQDN/total_procs.conf

	echo "object Service \"users\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_users\"
}" > $PATH_OF_FILES$FQDN/users.conf

	echo "object Service \"zombie procs\" {
        import \"generic-service\"
        host_name = \"$FQDN\"
        check_command = \"nrpe-check-1arg\"
        vars.host = \"$IP_OF_FQDN\"
        vars.check = \"check_zombie_procs\"
}" > $PATH_OF_FILES$FQDN/zombie_procs.conf
}

# token counter
FQDN_TK=0
IP_OF_FQDN_TK=0
PATH_OF_FILES_TK=0
# counter
function token() {
	export $1=${!1}+1
	if [[ $1 -gt 1 ]]; then
		echo "Same parameters multipletimes - exit"
		echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f FQDN  -i ip -p path \ne.g: icinga-newclient.sh -f server.imi.de -i 123.123.123.123 -p /PATH/TO/SAVE/FILES"
		exit
	fi
}

if [ "$#" -eq 0 ] ;then

	# start of frontend
	# ask for FQDN
	FQDN_ft
	# ask for ip of FQDN
	ip_of_FQDN_ft
	# ask for path of folder where to save files
	path_of_files_ft
	# ask if settings are correct
	check_if_correct
	# creating files
	whiptail --title "Create files" --msgbox "creating files..." $W_WIDTH $W_HEIGHT
	create_files
	whiptail --title "Done" --msgbox "Already finished ;)" $W_WIDTH $W_HEIGHT
# output help / usage
elif [[ ("$@" = "-h")  ||  ("$@" = "--help") || ("$@" = "-help") || ( ! -z "$7") ]]; then
	echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f FQDN  -i ip -p path \ne.g: icinga-newclient.sh -f server.imi.de -i 123.123.123.123 -p /PATH/TO/SAVE/FILES"
else
	# catching parameters
	while getopts f:i:p: option
	do
		case "${option}" in
	  	f) FQDN=${OPTARG}
			token "FQDN_TK";;

	    i) IP_OF_FQDN=${OPTARG}
			check_ip_valid "nogui"
			token "IP_OF_FQDN_TK";;

	    p) PATH_OF_FILES=${OPTARG}
			check_path_of_file_ending
			token "PATH_OF_FILES_TK";;

			*) echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f FQDN  -i ip -p path \ne.g: icinga-newclient.sh -f server.imi.de -i 123.123.123.123 -p /PATH/TO/SAVE/FILES"
			exit;;
		esac
	done
	create_files
fi
