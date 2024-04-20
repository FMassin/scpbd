#!/bin/bash

invarray=(${2/,/ })

source /home/sysop/.bashrc      

import_inv help formats |grep ${invarray[1]} 
import_inv ${invarray[1]} $(basename ${invarray[0]})           
seiscomp  update-config inventory     

FF=$SEISCOMP_ROOT/var/run/seedlink/mseedfifo 
(ls $FF 2>/dev/null || ( mkdir -p $(dirname $FF) && mkfifo $FF )) 

(echo "msrtsimul = true";echo "plugins.mseedfifo.fifo = $FF") > $SEISCOMP_ROOT/etc/global.cfg 
D=$SEISCOMP_ROOT/etc/key/global/ 
mkdir -p $D 
echo "" > $D/profile_g 
D=$SEISCOMP_ROOT/etc/key/seedlink/ 
mkdir -p $D &&
echo "sources = g:mseedfifo" > $D/profile_g 
(echo "set profile global g *";echo "set profile seedlink g *";echo exit)|seiscomp  shell 
seiscomp  update-config    
         
scmssort -u -E -v $(basename $1) > sorted.mseed 
echo $IP is my IP 

seiscomp enable seedlink

ls $(basename $3) ||
    (seiscomp restart seedlink && msrtsimul "${@:4}" sorted.mseed) &&
	seiscomp exec python3 /home/sysop/sc3-playback/playback.py $(basename $3) sorted.mseed  
	