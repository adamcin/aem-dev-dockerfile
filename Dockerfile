# AEM 6.3 developer image
FROM java:8-jdk

COPY app /app

WORKDIR /app

ADD license.properties .
ADD AEM_6.3_Quickstart.jar .
ADD oak-run-1.6.1.jar .

RUN bash ./install_aem.sh

EXPOSE 4502 9999 30303
ENV CQ_RUNMODE author
ENV CQ_JVM_OPTS -server -Xmx2g -Djava.awt.headless=true

VOLUME /app/crx-quickstart/install
VOLUME /app/crx-quickstart/logs

CMD bash ./run_aem.sh
