# Credit goes to our friends at HPE for this useful snippet

### functions
function ht {
  if [ "$1" = "off" ]; then
      cores=$(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | sort -u \
                   | awk 'BEGIN {FS=","} /,/ { print $2 }')
      action="Disabling"
      value=0
  else
      cores=$(cat /sys/devices/system/cpu/offline | \
                    awk 'BEGIN { RS=","; FS="-" } { for(i=$1; i <=$2; i++) print i }')
      action="Enabling"
      value=1
  fi
  for core in $cores ; do
          echo "$action Logical CPU: $core"
          echo $value > /sys/devices/system/cpu/cpu$core/online
  done
  echo ""
  echo "Hyper-Threading is $1"
  echo ""
}

### main
case "$1" in
   start)
      echo -e "\E[36mRunning $0 ...\E[0m";
      ht off
      echo -e "\E[36mDone $0 \E[0m";
      echo ""
   ;;
   stop|restart)
      echo -e "\E[36mRunning $0 ...\E[0m";
      ht on
      echo -e "\E[36mDone $0 \E[0m";
      echo ""
   ;;
   *)
     echo "Usage $0 (start)"
      exit 1; 
   ;;
esac
