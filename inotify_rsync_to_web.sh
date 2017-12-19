#!/bin/bash

pid_file='/var/run/inotify_bak_dir.pid'
if [ -f $pid_file ];then
    echo 'This script is running!!!'
    exit 0;
else
	touch $pid_file
	chmod 600 $pid_file
fi

JUMPSERVER_IP_PORT="http:IP:PORT/
GROUP_ID=18
GROUP_NAME="rsync_web"
GROUP_URL=$JUMPSERVER_IP_PORT"/japi/listgroup/"
HOSTS_URL=$JUMPSERVER_IP_PORT"/japi/listasset/?groupid="$GROUP_ID   #请求api地址

bkdir="/home/rsync_dir/"
to_rsync_mod="rsync_dir"   #远程同步主机需要开通rsync服务，开启873端口访问，配置文件中指定rsync_dir具体信息。
log_path='/home/inotify_adm_rsync.log'
#hosts=$(curl $HOSTS_URL|egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}"|xargs) #匹配出IP地址
#to_hosts=($hosts)  #将IP地址变为数组


/usr/local/inotify-tool/bin/inotifywait  --timefmt '%d/%m/%y %H:%M' --format '%T %w %f' -mrq -e close_write,modify,delete,create,attrib $bkdir | while read DATE TIME DIR FILE;do
        FILECHANGE=${DIR}${FILE}

	hosts=$(curl $HOSTS_URL|egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}"|xargs) #匹配出IP地址
	to_hosts=($hosts)  #将IP地址变为数组

        for host in ${to_hosts[@]}
        do
                /usr/bin/rsync -avH --delete $bkdir $host::$to_rsync_mod --log-file=/var/rsync.log &
				echo $host >> /var/rsync.log
        done
        echo $FILECHANGE >> $log_path

done

#脚本功能：根据api动态获取rsync_web组下的所有主机，使用inotifywait持续监控，并将本机下的/home/rsync_dir/文件远程同步到各个主机。
#脚本运行：#nohup sh inotify_rsync_to_web.sh &

#脚本若重启，需要先删除/var/run/inotify_bak_dir.pid文件，确保唯一实例运行。

#groups-api获取到的数据格式
#｛"1":"tmp","2","web"｝

#单个组(根据组id)返回的数据格式如下
#{"1": {"ip": "192.168.1.2", "hostname": "tmp1"},"2": {"ip": "192.168.1.3", "hostname": "tmp2"}}
