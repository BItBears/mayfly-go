#bin/bash

execfile=./mayfly-go
pidfile=./logs/mayfly-go.pid

if [ -f "${pidfile}" ]; then
  echo "The mayfly-go already running, shutdown and restart..."
  kill $(cat ${pidfile})
fi

if [ ! -x "${execfile}" ]; then
  sudo chmod +x "${execfile}"
fi

nohup "${execfile}" &

echo $! >${pidfile}
echo "The mayfly-go running..."
