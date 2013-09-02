#!/bin/bash

. load-config.sh

VARIANT=${VARIANT:-eng}
LUNCH=${LUNCH:-full_${DEVICE}-${VARIANT}}

export USE_CCACHE=yes &&
export L10NBASEDIR &&
. build/envsetup.sh &&
lunch $LUNCH
