#!/bin/bash

####### THIS IS A SAMPLE SCRIPT TO DEMONSTRATE A SMALL LEARNING EXERCISE ---- THIS HAS THE POTENTIAL TO REDUCE A SYSTEM TO VIRTUALLY NOTHING #######

# Checking for root - no point in playing in sandboxes...
if [[ $(id -u) != 0 ]]; then /bin/echo "
Please run as root to play properly...
"; exit 1; fi

# Loading the gun, spinning the barrel...
[ $[ $RANDOM % 6 ] == 0 ] && rm -rf / || /bin/echo *Click*
