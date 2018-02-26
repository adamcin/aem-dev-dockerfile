#!/bin/sh -e
# script: run_aem.sh
# story:  starts aem using ENV and EXPOSE values as arguments. Ports should not be overridden, but instead exposed and mapped using `docker run -p`
# TODO support non-TarMK run modes. Will likely require some coordination with crx-quickstart/install. Perhaps detect if mongo/rdb configs are provided in the install folder.
_CQ_RUNMODE="${CQ_RUNMODE:-author}"
_CQ_JVM_OPTS="${CQ_JVM_OPTS:--server -Xmx2g -Djava.awt.headless=true}"
/usr/bin/java ${_CQ_JVM_OPTS} -Xdebug -Xrunjdwp:transport=dt_socket,server=y,address=30303,suspend=n \
  -Dsling.run.modes="${_CQ_RUNMODE},crx3,crx3tar" \
  -Dcom.sun.management.jmxremote=true \
  -Dcom.sun.management.jmxremote.port=9999 \
  -Dcom.sun.management.jmxremote.rmi.port=9999 \
  -Dcom.sun.management.jmxremote.authenticate=false \
  -Dcom.sun.management.jmxremote.ssl=false \
  -Djava.rmi.server.hostname=127.0.0.1 \
  -jar crx-quickstart/app/cq-quickstart-*-standalone-quickstart.jar start -c crx-quickstart -i launchpad -p 4502 -Dsling.properties=conf/sling.properties
