#!/bin/bash

#############################################################################################################
##                                                                                                         ##
##      This script is Free Software, it's licensed under the GPLv3 and has ABSOLUTELY NO WARRANTY         ##
##      you can find and read the complete version of the GPLv3 @ http://www.gnu.org/licenses/gpl.html     ##
##                                                                                                         ##
#############################################################################################################
##                                                                                                         ##
##      Please see the README file for any informations such as FAQs, Version History and TODO             ##
##                                                                                                         ##
#############################################################################################################
##                                                                                                         ##
##      Name:           dellbiosupdate.sh                                                                  ##
##      Version:        0.1.0                                                                              ##
##      Date:           Thu, Mar 26 2009                                                                   ##
##      Author:         Callea Gaetano Andrea (aka cga)                                                    ##
##      Contributors:                                                                                      ##
##                                                                                                         ##
#############################################################################################################

## let's roll!!!

## here the scripts checks if the needed tools are installed:
if which dellBiosUpdate curl html2text >/dev/null 2>&1 ; then
	sleep 1
else
 	## if the script doesn't find the needed tools..........
	echo
	echo "Either libsmbios, html2text or curl was NOT found! should I install it for you?"
	echo

	## .........you get prompted to install libsmbios for you specific distro:
	select distro in "Debian, Ubuntu and derivatives" "Red Hat, Fedora, CentOS and derivatives" "SuSE, OpenSuSE and derivatives" "Arch and derivatives" "Gentoo and derivatives" "Quit, I will install it myself" "Ok, I'm done installing. Let's move on!" ; do
	if [ "$distro" == "Debian, Ubuntu and derivatives" ] ; then
		apt-get install libsmbios-bin curl html2text
	fi
	if [ "$distro" == "Red Hat, Fedora, CentOS and derivatives" ] ; then
		yum install firmware-addon-dell libsmbios curl html2text
	fi
	if [ "$distro" == "SuSE, OpenSuSE and derivatives" ] ; then
		zypper install libsmbios-bin curl html2text
	fi
	if [ "$distro" == "Arch and derivatives" ] ; then
		pacman -S libsmbios curl html2text
	fi
	if [ "$distro" == "Gentoo and derivatives" ] ; then
		emerge -av libsmbios curl html2text
	fi
	if [ "$distro" == "Quit, I will install it myself" ] ; then
		echo
		echo "Please install libsmbios, html2text and curl"
		echo
		exit 1
	fi
	if [ "$distro" == "Ok, I'm done installing. Let's move on!" ] ; then
		break 1	
	fi
done
fi

## now the script shows helpful informations about your DELL such as libsmbios version, SystemId (we need this) and BIOS version (wee need this):
echo
echo "These are some useful informations about your DELL, some of them are needed to update the BIOS:"
echo
getSystemId
echo

## now let's get the data we need in order to get the right BIOS: "Syste ID" and "BIOS Version":
SYSTEM_ID=$(getSystemId | grep "System ID:" | cut -f6 -d' ')
BIOS_VERSION_BASE=$(getSystemId | grep "BIOS Version:" | cut -f3 -d' ')
## plus the model of your computer:
COMPUTER=$(getSystemId | grep "Product Name:" | cut -f3,4,5 -d' ')

## now we 1) notify the current installed BIOS and 2) fetch all the available BIOS for your system.........
echo "Your currently installed BIOS Version is ${BIOS_VERSION_BASE}, getting the available BIOS updates for your ${COMPUTER}....."
echo
a=($(curl http://linux.dell.com/repo/firmware/bios-hdrs/ 2>/dev/null | html2text | grep "system_bios_ven_0x1028_dev_${SYSTEM_ID}_version_*" | cut -f2 -d' ' | tr -d '/' | sed 's/.*_//'))

## ......and we make them selectable:
echo "These are the available BIOS updates available for your ${COMPUTER}:"
echo

## just to make sure PS3 doesn't get changed forever:
oldPS3=$PS3 
COLUMNS=10
PS3=$'\nNote that you actually *can* install the latest BIOS update without updating the immediately subsequent version.\n\nChoose the BIOS Version you want to install by typing the corresponding number: ' ; 
select BIOS_VERSION in "${a[@]}" ; do [[ $BIOS_VERSION ]] && echo && break ; done
COLUMNS=
PS3=$oldPS3

## now that we have all the data, we need to set the URL to download the right BIOS:
URL=http://linux.dell.com/repo/firmware/bios-hdrs/system_bios_ven_0x1028_dev_${SYSTEM_ID}_version_${BIOS_VERSION}/bios.hdr

## if an unknown bios.hdr version exist then mv it and append $DATE; finally download the bios.hdr file with the version saved in the file name:
if [ -f "/root/bios.hdr" ] ; then
	echo "I found an existing BIOS file (/root/bios.hdr) of which I don't know the version and I'm going to back it up as /root/bios-$(date +%Y-%m-%d).hdr"
	echo
	sleep 1
        mv /root/bios.hdr /root/bios-$(date +%Y-%m-%d).hdr
	sleep 1
	echo "Downloading selected BIOS Version ${BIOS_VERSION} for your ${COMPUTER} and saving it as /root/bios-${BIOS_VERSION}.hdr"
	echo
	sleep 1
curl ${URL} -o /root/bios-${BIOS_VERSION}.hdr
echo
else
	echo "Downloading selected BIOS Version ${BIOS_VERSION} for your ${COMPUTER} and saving it as /root/bios-${BIOS_VERSION}.hdr"
	echo
	sleep 1
curl ${URL} -o /root/bios-${BIOS_VERSION}.hdr
echo
fi

## now we check that the BIOS Version you chose is appropriate for the computer:
echo "Checking if BIOS Version ${BIOS_VERSION} for your ${COMPUTER} is valid............."
sleep 3
echo
## if not the script will exit and remove the downloaded BIOS:
dellBiosUpdate -t -f /root/bios-${BIOS_VERSION}.hdr >/dev/null 2>&1; STATUS_FAIL=$?
if (( ${STATUS_FAIL} > 0 )) ; then
	echo "WARNING: BIOS HDR file BIOS version appears to be less than or equal to current BIOS version."
	echo "This may result in bad things happening!!!!"
	echo
	rm -f /root/bios-${BIOS_VERSION}.hdr
	echo "The downloaded /root/bios-${BIOS_VERSION}.hdr has been deleted."
	echo
	exit 2

## if BIOS is valid we load the needed DELL module and proceed with the update:
else 
	echo "This is a valid BIOS Version for your ${COMPUTER}, telling the operating system I want to update the BIOS:"
	echo
	modprobe dell_rbu
	echo "The necessary 'dell_rbu' module has been loaded"
	echo
## the actual update:
	dellBiosUpdate -u -f /root/bios-${BIOS_VERSION}.hdr
	echo
fi

## to complete the update we must *soft* reboot:
echo
read -p "In order to update the BIOS you must *soft* reboot your system, do you want to reboot now? [Y/n]"; 
if [[ $REPLY = [yY] ]] ; then 
	echo
	echo "Rebooting in 5 seconds. Press CTRL+c to NOT reboot."
	sleep 5
	reboot
else
	echo
	echo "Don't forget to reboot your system or the BIOS will NOT update!!"
fi 
exit 0