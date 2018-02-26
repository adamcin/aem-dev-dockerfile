import java.util.ConcurrentModificationException;
import java.util.Set;
import java.util.HashSet;
import java.util.Arrays;
import java.rmi.RemoteException;
import javax.management.MBeanServerConnection;
import javax.management.ObjectName;
import javax.management.RuntimeMBeanException;
import javax.management.InstanceNotFoundException;
import javax.management.remote.JMXConnector;
import javax.management.remote.JMXConnectorFactory;
import javax.management.remote.JMXServiceURL;

/**
 * Waits on key JMX objects in AEM to determine when installation is fully complete.
 * */
public class InstallWatcher {

    static final String ON_REPOSITORY = "com.adobe.granite:type=Repository";
    static final String ON_PACKAGER = "org.apache.jackrabbit.vault.packaging:type=manager";
    static final String ON_INSTALLER = "org.apache.sling.installer:name=Sling OSGi Installer,type=Installer";

    // this is necessary because JMX will look for the first non-loopback interface to resolve the default IP
    // address when running in docker.
    static final String JMX_HOST="127.0.0.1";

    /**
     * returns when everything has been installed and the osgi installer has been inactive for at least 10 milliseconds.
     * */
    public static void main(String[] args) throws Exception {
        JMXServiceURL url = new JMXServiceURL(String.format("service:jmx:rmi://%s/jndi/rmi://%s:9999/jmxrmi", JMX_HOST, JMX_HOST));
        JMXConnector jmxc = JMXConnectorFactory.connect(url, null);

        MBeanServerConnection mbsc = jmxc.getMBeanServerConnection();

        final ObjectName namePackager = ObjectName.getInstance(ON_PACKAGER);
        final ObjectName nameInstaller = ObjectName.getInstance(ON_INSTALLER);
        final ObjectName nameRepository = ObjectName.getInstance(ON_REPOSITORY);

        final Set<String> requiredServices = new HashSet<>(Arrays.asList(ON_INSTALLER, ON_REPOSITORY, ON_PACKAGER));

        /*
         * The Sling Installer actually starts up before the Oak repository and FileVault package manager,
         * so there is a phase in the installation where the OsgiInstaller finishes a batch of resources, 
         * then the JCR installer kicks in and adds a bunch more. We need to wait for each of these 
         * dependencies to be active before we start paying attention to the installer metrics.
         * */
        while (!requiredServices.isEmpty()) {
            echo(String.format("Waiting for JMX Services: %s", requiredServices));
            Set<ObjectName> matches = mbsc.queryNames(null, null);
            if (matches.contains(nameRepository)) {
                requiredServices.remove(ON_REPOSITORY);
            }
            if (matches.contains(namePackager)) {
                requiredServices.remove(ON_PACKAGER);
            }
            if (matches.contains(nameInstaller)) {
                requiredServices.remove(ON_INSTALLER);
            }
            fortyWinks();
        }

        final long waitForSec = 5L;
        // this is in nanos, not millis.
        long suspendedSince = -1L;
        String activeResourceCount = "-1";
        while (suspendedSince < 0L || !"0".equals(activeResourceCount)
                || (1000L * System.currentTimeMillis() < suspendedSince + waitForSec * 1000000L)) {
            try {
                suspendedSince = (long) mbsc.getAttribute(nameInstaller, "SuspendedSince");
                activeResourceCount = String.valueOf(mbsc.getAttribute(nameInstaller, "ActiveResourceCount"));
                echo("Installable Resources Remaining: " + activeResourceCount);
            } catch (InstanceNotFoundException | RemoteException e) {
                echo("Connection terminated. Restart InstallWatcher to resume monitoring. (exception: " + e.getMessage() + ")");
                break;
            } catch (RuntimeMBeanException e) {
                // there is a bug where the installer will throw this error when the state is modified as it
                // is being aggregated for returning for the getAttribute method. Just ignore and continue
                // when this happens.
                if (e.getCause() instanceof ConcurrentModificationException) {
                    continue;
                } else {
                    throw e;
                }
            }
            fortyWinks();
        }
    }

    static void fortyWinks() throws InterruptedException {
        Thread.sleep(5000L);
    }

    static void echo(String echoed) {
        System.out.println(echoed);
    }
}

