#!/bin/sh -e
# script: install_aem.sh
# story:  1. fully extracts and installs AEM as author node
#         2. shuts it down
#         3. removes persistent sling id and run mode
#         4. deletes logs and install directory contents for use as clean docker mounts
#         5. deletes original quickstart jar
BASEDIR=$(dirname "$0")

# compile the watcher so that compile failure happens fast.
javac InstallWatcher.java

# extract the quickstart jar
java -Djava.awt.headless=true -jar "${BASEDIR}"/AEM_*_Quickstart.jar -unpack

# build JVM options
CQ_JVM_OPTS="-server -Xmx2g -Djava.awt.headless=true"
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Dcom.sun.management.jmxremote=true"
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Dcom.sun.management.jmxremote.port=9999"
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Dcom.sun.management.jmxremote.rmi.port=9999"
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Dcom.sun.management.jmxremote.authenticate=false"
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Dcom.sun.management.jmxremote.ssl=false"
# force the JMX rmi server to listen on localhost
CQ_JVM_OPTS="${CQ_JVM_OPTS} -Djava.rmi.server.hostname=127.0.0.1"
# use the start script to run the application in the background
CQ_JVM_OPTS="${CQ_JVM_OPTS}" "${BASEDIR}/crx-quickstart/bin/start"

# sleep for five seconds to give the JMX Management Service time to boot up.
sleep 5

# run the watcher to wait for installation to complete
java InstallWatcher

# stop the server
"${BASEDIR}/crx-quickstart/bin/stop"

# wait for all bg'd child processes to complete
wait

# remove serialized run modes and sling instance id so that this instance can operate as a publish node or in a cluster.
find "${BASEDIR}/crx-quickstart/launchpad/felix" -name 'sling.options.file' -exec rm -f '{}' \;
find "${BASEDIR}/crx-quickstart/launchpad/felix" -name 'sling.id.file' -exec rm -f '{}' \;

# clean the mountable paths
rm -rf "${BASEDIR}/crx-quickstart/logs/*"
rm -rf "${BASEDIR}/crx-quickstart/install/*"

# remove the now-unnecessary quickstart jar
rm -f "${BASEDIR}"/AEM_*_Quickstart.jar
