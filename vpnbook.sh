#!/bin/bash

#The following script connects you to vpnbook VPN servises following 
#a simple choose and go procedure.
#Tools needed:
#	lynx
#	net-tools (arch-linux)
#	xterm

killIpV6(){
	sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
	sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
}

startIpV6(){
	sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
	sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
}

populateDns(){
	#Have to be done.... somehow
	CLOUDFLARE="1.1.1.1;1.0.0.1;"
	GOOGLE="8.8.8.8;8.8.4.4;"
	#NETINTERFACE=$(ip link | awk -F: '$0 !~ "lo|vir|enp|^[^0-9]"{print $2;getline}')
	#ESSID="CYTA5ADF" # $(iwgetid -r)
	echo "Change DNS server to CLOUDFLARE, GOOGLE"	
}

populateDns

int_verification(){
CHECK=0
if [ -n "$1" ] && [ "$1" -eq "$1" ] 2>/dev/null
then
   MAX_INT_ALLOWED=$(($2-1))
   if [ "$1" -lt "0" ] || [ "$1" -gt "$MAX_INT_ALLOWED" ]	
   then	
       CHECK=0 #INCORRECT
   else
       CHECK=1 #CORRECT
   fi
fi
}


while :
do
    clear
    #Root access not allowed!
	if [ "$EUID" -eq 0 ]
	then 
		echo "Do not run as Root! (It is dangerous)"
    	exit 1
	fi
	#Check if you are connected to a VPN
	if [ "0" == $(ifconfig | grep tun | wc -l) ] 
	then
	
		#Initialize the procedure
		NAME_OF_FILE=".user_pass"
		USER=$(whoami)
		WORKING_DIR=/home/$USER/.vpnbook_conf/
		AUTH_FILE=$WORKING_DIR$NAME_OF_FILE
		rm -f $WORKING_DIR/*.ovpn
		rm -f $AUTH_FILE	
		touch $AUTH_FILE
		#Scrape the credentials
    		PASSWORD=$(curl -s "https://twitter.com/vpnbook" | grep Password: | cut -c 160- | sed 's/.\{4\}$//' | head -n 1)
    		USERNAME=vpnbook
    		AVAILABLE_VPNS=( $(lynx   -dump -listonly  https://www.vpnbook.com/freevpn | grep "VPNBook.com-OpenVPN-" | cut -c 72-) ) 
		#Append the credentials to the file
		echo $USERNAME >> $AUTH_FILE
		echo $PASSWORD >> $AUTH_FILE
		
		#Print the list of vpns
		echo -----------------------------------
    		for ((i=0; i<${#AVAILABLE_VPNS[@]}; i++))
    		do
    	    		echo "[$i]--" ${AVAILABLE_VPNS[i]} 
    		done
		echo -----------------------------------
		echo "Choose VPN."
		
		#Read the input 
		read input
		int_verification "$input" "${#AVAILABLE_VPNS[@]}"
		while [ $CHECK -ne "1" ]
		do
			echo "Error!"
			read input
			int_verification "$input" "${#AVAILABLE_VPNS[@]}"
		done
		clear

		#Download and extract the vpn to the working directory 
		VPN="https://www.vpnbook.com/free-openvpn-account/VPNBook.com-OpenVPN-"${AVAILABLE_VPNS[input]}
		FILE="VPNBook.com-OpenVPN-"${AVAILABLE_VPNS[input]}
		wget -q -P $WORKING_DIR $VPN
 		unzip -q -o "$WORKING_DIR"$FILE -d $WORKING_DIR
		rm -f "$WORKING_DIR"$FILE
		
		#Print the configuration files of the vpn
		AVAILABLE_FILES=( $(ls $WORKING_DIR) )
		echo -----------------------------------
		for ((i=0; i<${#AVAILABLE_FILES[@]}; i++))
    		do
    			echo "[$i]--" ${AVAILABLE_FILES[i]} 
    		done
		echo -----------------------------------
		echo "Choose file."
	
		#Read the input 
		read input
		int_verification "$input" "${#AVAILABLE_FILES[@]}"
		while [ $CHECK -ne "1" ]
		do
			echo "Error!"
			read input
			int_verification "$input" "${#AVAILABLE_FILES[@]}"
		done
		clear
		VPN_TO_SETUP=$WORKING_DIR${AVAILABLE_FILES[input]}
	
		#Connect!
		echo "Terminate the xterm to disconnect (Ctr-C)"
		#Check and kill ipv6 (for security purposes)
		if [ "0" == $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) ]
		then
			echo "Disabling ipv6..."
			killIpV6
		fi
		sudo xterm -e openvpn --config $VPN_TO_SETUP --auth-user-pass $AUTH_FILE 
		#Restore ipv6
		if [ "1" == $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) ]
		then
			echo "Enabling ipv6..."
			startIpV6
		fi
	
	else	 
    	echo "You are connected to a VPN. Try to disconnect fist!"
	read 
 	fi	
done
