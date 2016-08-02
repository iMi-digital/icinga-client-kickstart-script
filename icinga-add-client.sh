#!/bin/bash
#set -x #debug
# set wight bright of whiptail
W_WIDTH=12
W_HEIGHT=60

# set standard parameters
FQDN="server.imi.de"
IP_OF_FQDN="123.123.123.123"
PATH_OF_FILES="/home/ssn/Projekte/icinga-add-client/"

# function to set FQDN
function FQDN_ft {
	FQDN=$(whiptail --title "FQDN of new client" --inputbox "Give me your clients FQDN?" $W_WIDTH $W_HEIGHT $FQDN 3>&1 1>&2 2>&3)
	exitstatus=$?
	if [ $exitstatus = 0 ]; then
  	:
	else
    exit
	fi
}
# function to set ip of FQDN
function ip_of_FQDN_ft {
	IP_OF_FQDN=$(whiptail --title "IP of your new client" --inputbox "Give me the IP-Adresse of your new client?" $W_WIDTH $W_HEIGHT $IP_OF_FQDN 3>&1 1>&2 2>&3)
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
	if [[ $IP_OF_FQDN =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
		:
	else
		if [[ "$1" = "gui" ]]; then
			whiptail --title "Invalid IP" --msgbox "try again !..." $W_WIDTH $W_HEIGHT
			ip_of_FQDN_ft
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
	if (whiptail --title "Everything Correct?" --yesno "FQDN = $FQDN \nIP = $IP_OF_FQDN \nPath = $PATH_OF_FILES \n \nare those correct?" $W_WIDTH $W_HEIGHT) then
		# when settings are fine do: look at the path an check if files already exist with the same name
		# check if files exist
		if [[ $(find $PATH_OF_FILES -type f -name "$FQDN.conf"|wc -l) -gt 0 ]];then
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
		"Choose:" $W_WIDTH $W_HEIGHT 3 "FQDN" "$FQDN" OFF "IP" "$IP_OF_FQDN" OFF "PATH" "$PATH_OF_FILES" OFF 3>&1 1>&2 2>&3)
		if [[ -z "$CORRECT" ]]; then
			#if settings was right do: ask again if all correct
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

#token counter
FQDN_TK=0
IP_OF_FQDN_TK=0
PATH_OF_FILES_TK=0
#counter
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
# asking for FQDN
	FQDN_ft
# asking for ip of FQDN
	ip_of_FQDN_ft
# asking of path of folder where to save files
	path_of_files_ft
# asking if settings are correct
	check_if_correct
# creating files
	whiptail --title "Create files" --msgbox "creating files..." $W_WIDTH $W_HEIGHT
	create_files
	whiptail --title "Done" --msgbox "Already finished ;)" $W_WIDTH $W_HEIGHT

elif [[ ("$@" = "-h")  ||  ("$@" = "--help") || ("$@" = "-help") || ( ! -z "$7") ]]; then
	echo -e "Usage: icinga-add-client.sh for GUI OR\nGive parameters with flags: -f FQDN  -i ip -p path \ne.g: icinga-newclient.sh -f server.imi.de -i 123.123.123.123 -p /PATH/TO/SAVE/FILES"
else
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
