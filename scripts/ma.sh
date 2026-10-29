#!/bin/bash
exec sudo -u mathaudit env -i HOME=/home/mathaudit USER=mathaudit LOGNAME=mathaudit SHELL=/bin/bash LANG=C.UTF-8 PATH=/home/mathaudit/.elan/bin:/home/mathaudit/go/bin:/home/mathaudit/bin:/usr/local/bin:/usr/bin:/bin bash -c "$*"
