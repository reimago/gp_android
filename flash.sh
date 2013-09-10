#!/bin/bash

. load-config.sh

ADB=${ADB:-adb}
FASTBOOT=${FASTBOOT:-fastboot}
HEIMDALL=${HEIMDALL:-heimdall}
VARIANT=${VARIANT:-eng}

if [ ! -f "`which \"$ADB\"`" ]; then
	ADB=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/adb
fi
if [ ! -f "`which \"$FASTBOOT\"`" ]; then
	FASTBOOT=out/host/`uname -s | tr "[[:upper:]]" "[[:lower:]]"`-x86/bin/fastboot
fi

run_adb()
{
	$ADB $ADB_FLAGS $@
}

run_fastboot()
{
	if [ "$1" = "devices" ]; then
		$FASTBOOT $@
	else
		$FASTBOOT $FASTBOOT_FLAGS $@
	fi
	return $?
}

update_time()
{
	if [ `uname` = Darwin ]; then
		OFFSET=`date +%z`
		OFFSET=${OFFSET:0:3}
		TIMEZONE=`date +%Z$OFFSET|tr +- -+`
	else
		TIMEZONE=`date +%Z%:::z|tr +- -+`
	fi
	echo Attempting to set the time on the device
	run_adb wait-for-device &&
	run_adb shell toolbox date `date +%s` &&
	run_adb shell setprop persist.sys.timezone $TIMEZONE
}

fastboot_flash_image()
{
	# $1 = {userdata,boot,system}
	imgpath="out/target/product/$DEVICE/$1.img"
	out="$(run_fastboot flash "$1" "$imgpath" 2>&1)"
	rv="$?"
	echo "$out"

	if [[ "$rv" != "0" ]]; then
		# Print a nice error message if we understand what went wrong.
		if grep -q "too large" <(echo "$out"); then
			echo ""
			echo "Flashing $imgpath failed because the image was too large."
			echo "Try re-flashing after running"
			echo "  \$ rm -rf $(dirname "$imgpath")/data && ./build.sh"
		fi
		return $rv
	fi
}

flash_fastboot()
{
	run_adb reboot bootloader

	run_fastboot devices &&
	( [ "$1" = "nounlock" ] || run_fastboot oem unlock || true )

	if [ $? -ne 0 ]; then
		echo Couldn\'t setup fastboot
		return -1
	fi
	case $2 in
	"system" | "boot" | "userdata")
		fastboot_flash_image $2 &&
		run_fastboot reboot
		;;

	*)
		run_fastboot erase cache &&
		run_fastboot erase userdata
		if [ $? -ne 0 ]; then
			return $?
		fi

		fastboot_flash_image userdata &&
		([ ! -e out/target/product/$DEVICE/boot.img ] ||
		fastboot_flash_image boot) &&
		fastboot_flash_image system &&
		run_fastboot reboot &&
		update_time
		;;
	esac
	echo -ne \\a
}

while [ $# -gt 0 ]; do
	case "$1" in
	"-s")
		ADB_FLAGS+="-s $2"
		FASTBOOT_FLAGS+="-s $2"
		shift
		;;
	*)
		PROJECT=$1
		;;
	esac
	shift
done

case "$PROJECT" in
"time")
	update_time
	exit $?
	;;
esac

case "$DEVICE" in
"peak"|"keon")
	flash_fastboot nounlock $PROJECT
	;;

*)
	if [[ $(type -t flash_${DEVICE}) = function ]]; then
		flash_${DEVICE} $PROJECT
	else
		echo Unsupported device \"$DEVICE\", can\'t flash
		exit -1
	fi
	;;
esac
