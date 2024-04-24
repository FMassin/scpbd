#!/bin/bash


source /home/sysop/.bashrc      

DB=$4
ls $DB  || sqlite3 -batch -init $SEISCOMP_ROOT/share/db/sqlite3.sql $DB .exit

import_inv help formats |grep $3
import_inv $3 $2          

FF=$SEISCOMP_ROOT/var/run/seedlink/mseedfifo 
(echo "msrtsimul = true";echo "plugins.mseedfifo.fifo = $FF") > $SEISCOMP_ROOT/etc/global.cfg 
D=$SEISCOMP_ROOT/etc/key/seedlink/ 
mkdir -p $D 
echo "sources = g:mseedfifo" > $D/profile_g 

python3 /usr/local/bin/mseed2key.py \
    $1 /home/sysop/seiscomp/ \
    "seedlink:g"
seiscomp  update-config    

(ls $FF 2>/dev/null || ( mkdir -p $(dirname $FF) && mkfifo $FF )) 

scmssort -u -E -v $1 > /tmp/sorted.mseed 

seiscomp enable seedlink

#(seiscomp restart seedlink && msrtsimul "${@:4}" /tmp/sorted.mseed) 

cp $4 /home/sysop/event_db.sqlite
seiscomp exec python3 \
    /home/sysop/sc3-playback/playback.py \
    /home/sysop/event_db.sqlite \
    /tmp/sorted.mseed 
	