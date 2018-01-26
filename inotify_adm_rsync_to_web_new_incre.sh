#!/bin/bash

pid_file='/var/run/inotify_bak_dir.pid'
if [ -f $pid_file ];then
    echo 'inotify_adm_rsync_to_web.sh is running!!!'
    exit 0;
else
	touch $pid_file
	chmod 600 $pid_file
fi

JUMPSERVER_IP_PORT="http://IP:PORT"
GROUP_ID=35
GROUP_NAME="adm_rsync"
GROUP_URL=$JUMPSERVER_IP_PORT"/japi/listgroup/"
HOSTS_URL=$JUMPSERVER_IP_PORT"/japi/listasset/?groupid="$GROUP_ID

bkdir="/home/adm_rsync_dir/"
cd ${bkdir}
to_rsync_mod="adm_rsync_dir"
log_path='/home/inotify_adm_rsync.log'
save_time_file=adm_time.txt
hosts=$(curl $HOSTS_URL|egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}"|xargs)
to_hosts=($hosts)
function dateDiffer()
{
    #86400=1day,43200=0.5day
    dvalue=43200
    dstart=`cat $save_time_file`
    dend=`date +%s`
    differ=`expr $dend - $dstart`
    if [ $dvalue -gt $differ ]
    then
        return 1
    fi

    return 0
}


/usr/local/inotify-tools/bin/inotifywait --format '%Xe %w%f' -mrq -e close_write,modify,delete,create,attrib,move ./ | while read FILE;do
	
        INO_EVENT=$(echo $FILE | awk '{print $1}')
	INO_FILE=$(echo $FILE | awk '{print $2}')
        FILECHANGE=${INO_FILE}
		
	dateDiffer
	result=`echo $?`
	
	if [ $result -eq 0 ]
	then
		echo `date +%s` > ${save_time_file}
		hosts=$(curl $HOSTS_URL|egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}"|xargs)
		to_hosts=($hosts)
	fi
	
        for host in ${to_hosts[@]}
        do
		echo "----------$(date)---------------" >> /var/rsync.log

		if [[ $INO_EVENT =~ 'CREATE' ]] || [[ $INO_EVENT =~ 'MODIFY' ]] || [[ $INO_EVENT =~ 'CLOSE_WRITE' ]] || [[ $INO_EVENT =~ 'MOVED_TO' ]]
		then
			echo 'CREATE or MODIFY or CLOSE_WRITE or MOVED_TO' >> /var/rsync.log
			/usr/bin/rsync -avzcR  $(dirname ${INO_FILE}) $host::$to_rsync_mod --log-file=/var/rsync.log &  
		fi
		if [[ $INO_EVENT =~ 'DELETE' ]] || [[ $INO_EVENT =~ 'MOVED_FROM' ]]
		then
			echo 'DELETE or MOVED_FROM' >> /var/rsync.log
			/usr/bin/rsync -avzR --delete  $(dirname ${INO_FILE}) $host::$to_rsync_mod --log-file=/var/rsync.log & 
		fi
		if [[ $INO_EVENT =~ 'ATTRIB' ]]
		then
			echo 'ATTRIB'  >> /var/rsync.log
			if [ ! -d "$INO_FILE" ]
			then           
				/usr/bin/rsync -avzcR $(dirname ${INO_FILE}) $host::$to_rsync_mod --log-file=/var/rsync.log &
			fi
		fi
		
		echo $host >> /var/rsync.log
        done
        echo $FILECHANGE >> $log_path

done
