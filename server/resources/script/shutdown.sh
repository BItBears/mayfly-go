#bin/bash
pidfile=./logs/mayfly-go.pid
if [ ! -f "${pidfile}" ]; then
        echo "No mayfly-go running."
        exit -1
fi
pid=$(cat ${pidfile})
echo "The mayfly-go(${pid}) is running..."

kill ${pid}
rm -rf ${pidfile}
echo "Send shutdown request to mayfly-go(${pid}) OK"
