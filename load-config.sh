#!/bin/bash

if [[ ! -n "$ANDROID_DIR" ]]; then
  ANDROID_DIR=$(cd `dirname $0`; pwd)
fi

. "$ANDROID_DIR/.config"
if [ $? -ne 0 ]; then
        echo Could not load .config. Did you run config.sh?
	exit -1
fi

if [ -f "$ANDROID_DIR/.userconfig" ]; then
	. "$ANDROID_DIR/.userconfig"
fi
