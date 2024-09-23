#!/bin/bash


source /home/sysop/.bashrc     

DB=$4
ls $DB  || \
    (sqlite3 -batch -init $SEISCOMP_ROOT/share/db/sqlite3.sql $DB .exit && \
     sqlite3 -batch -init $SEISCOMP_ROOT/share/db/vs/sqlite3.sql $DB .exit && \
     sqlite3 -batch -init $SEISCOMP_ROOT/share/db/wfparam/sqlite3.sql $DB .exit)

import_inv help formats |grep $3 || exit 1
import_inv $3 $2 || exit 1         

FF=$SEISCOMP_ROOT/var/run/seedlink/mseedfifo 
(echo "msrtsimul = true";echo "plugins.mseedfifo.fifo = $FF") > $SEISCOMP_ROOT/etc/global.cfg 
D=$SEISCOMP_ROOT/etc/key/seedlink/ 
mkdir -p $D 
echo "sources = g:mseedfifo" > $D/profile_g 

python3 /usr/local/bin/mseed2key.py \
    $1 $SEISCOMP_ROOT/ \
    "seedlink:g" || exit 1
seiscomp  update-config    || exit 1

(ls $FF 2>/dev/null || ( mkdir -p $(dirname $FF) && mkfifo $FF )) 

scmssort -u -E -v $1 > /tmp/sorted.mseed 

seiscomp enable seedlink || exit 1

#(seiscomp restart seedlink && msrtsimul "${@:4}" /tmp/sorted.mseed) 

cp $4 /home/sysop/event_db.sqlite 

seiscomp exec python3 \
    /home/sysop/sc3-playback/playback.py \
    /home/sysop/event_db.sqlite \
    /tmp/sorted.mseed 
	