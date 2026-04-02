package tools;

import jason.infra.local.RunLocalMAS;

/**
 * Minimal launcher for local MAS execution without the default RMI/MBean/web startup.
 * It also allows passing a custom logging configuration before the MAS starts.
 *
 * The caller controls whether AWT runs headless via the normal java.awt.headless
 * system property on the java command line.
 */
public class HeadlessRunner extends RunLocalMAS {

    public static void main(String[] args) {
        if (args.length != 2) {
            System.err.println("Usage: tools.HeadlessRunner <mas2j-file> <log-config-file>");
            System.exit(2);
        }

        try {
            HeadlessRunner runnerImpl = new HeadlessRunner();
            runner = runnerImpl;
            System.out.println("HEADLESS_RUNNER init " + args[0]);
            runnerImpl.init(new String[] { args[0], "--no-net", "--log-conf", args[1] });
            System.out.println("HEADLESS_RUNNER create");
            runnerImpl.create();
            System.out.println("HEADLESS_RUNNER agents " + runnerImpl.getNbAgents());
            System.out.println("HEADLESS_RUNNER names " + runnerImpl.getAgs().keySet());
            String startDelayMs = System.getProperty("goldminers.start.delay.ms", "0");
            long startDelay = Long.parseLong(startDelayMs);
            if (startDelay > 0) {
                System.out.println("HEADLESS_RUNNER start_delay " + startDelay);
                Thread.sleep(startDelay);
            }
            System.out.println("HEADLESS_RUNNER start");
            runnerImpl.start();
            System.out.println("HEADLESS_RUNNER wait");
            runnerImpl.waitEnd();
            System.out.println("HEADLESS_RUNNER finish");
            runnerImpl.finish(0, true, 0);
        } catch (Exception e) {
            e.printStackTrace();
            System.exit(1);
        }
    }
}
