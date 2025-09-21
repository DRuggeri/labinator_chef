if [ -z "$PORT" ];then
  PORT=22
fi

if [ -z "$HOST" -o -z "$RECIPE" ];then
  echo "HOST or RECIPE is not set!"
  exit 1
else
  echo "Transferring files to $HOST..."
  while ! rsync --delete --info=progress2 --archive \
    --rsh="ssh -p $PORT" . \
    --exclude .git --exclude "*.swp" \
    root@$HOST:/var/chef/cookbooks/labinator;do
    if [ -z "$BOOTSTRAPTRIED" ];then
      BOOTSTRAP_TRIED=1
    else
      exit
    fi
    BOOTSTRAP="bash /tmp/init.sh"
    echo -n "Enter account name to init as (root as default): "
    read BOOTSTRAP_USER

    if [ -z "$BOOTSTRAP_USER" -o "$BOOTSTRAP_USER" = "root" ];then
      scp -P $PORT init.sh root@$HOST:/tmp/init.sh
      ssh -p$PORT root@$HOST "$BOOTSTRAP"
    else
      scp -P $PORT init.sh $BOOTSTRAP_USER@$HOST:/tmp/init.sh
      ssh -p $PORT $BOOTSTRAP_USER@$HOST "if which sudo >/dev/null 2>&1;then sudo bash -l -c '$BOOTSTRAP';else su -c '$BOOTSTRAP';fi"
    fi
  done

  echo "Executing converge..."
  time ssh -p $PORT root@$HOST "chef-solo -o 'labinator::$RECIPE'" 2>&1 | tee output
fi
