package de.civitascore.systemtests;

import org.robotframework.remoteserver.RemoteServer;

public class SystemTestRemoteServer {

  public static void main(String[] args) throws Exception {
    int port = resolvePort(args);
    RemoteServer.configureLogging();
    RemoteServer server = new RemoteServer(port);
    server.putLibrary("/", new SystemTestRemoteLibrary());
    server.start();
  }

  private static int resolvePort(String[] args) {
    if (args != null && args.length > 0 && args[0] != null && !args[0].isBlank()) {
      return Integer.parseInt(args[0]);
    }
    String value = System.getenv().getOrDefault("SYSTEM_TEST_REMOTE_PORT", "8270");
    return Integer.parseInt(value);
  }
}
