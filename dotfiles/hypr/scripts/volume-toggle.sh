#!/bin/sh

# We removed '-x' so it matches any process containing "pavucontrol"
if pgrep "pavucontrol" > /dev/null
then
    pkill pavucontrol
else
    pavucontrol -t 3
fi