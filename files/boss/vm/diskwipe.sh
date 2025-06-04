# !!! ADDED FOR LABINATOR USAGE !!!
clear
for DEV in vda sda;do
    test -f /sys/block/${DEV}/size || continue

    COUNT=34 #2 sectors + 16K for partition entries
    NUMBLOCKS=`cat /sys/block/${DEV}/size`
    SEEK=$(($NUMBLOCKS - $COUNT))

    # Wipe the first (MBR/GPT main partitions) and last (GPT backup partition) 1Mb
    dd if=/dev/zero of=/dev/${DEV} bs=512 count=${COUNT}
    dd if=/dev/zero of=/dev/${DEV} bs=512 count=${COUNT} seek=${SEEK}
done

while ! wget -O - "http://boss.local:8080/callbacks?key=wipe&val=`hostname`" | grep received;do
    sleep 2
done

echo;echo;echo;echo;echo
echo "`hostname` disk wipe complete"