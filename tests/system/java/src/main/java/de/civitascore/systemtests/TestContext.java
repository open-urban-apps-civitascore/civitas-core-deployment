package de.civitascore.systemtests;

import com.fasterxml.jackson.databind.ObjectMapper;
import de.civitascore.systemtests.client.KeycloakClient;
import de.civitascore.systemtests.client.PortalBackendClient;
import java.net.http.HttpClient;
import java.time.Duration;

public final class TestContext {

  private static final SystemTestConfig config = SystemTestConfig.fromEnvironment();
  private static final ObjectMapper mapper = new ObjectMapper();
  private static final HttpClient httpClient =
      HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15)).build();
  private static final SystemTestState state = new SystemTestState();
  private static final KeycloakClient keycloakClient = new KeycloakClient(config, httpClient, mapper);
  private static final PortalBackendClient portalClient =
      new PortalBackendClient(config, httpClient, mapper);

  private TestContext() {}

  public static SystemTestConfig config() { return config; }
  public static ObjectMapper mapper() { return mapper; }
  public static HttpClient httpClient() { return httpClient; }
  public static SystemTestState state() { return state; }
  public static KeycloakClient keycloakClient() { return keycloakClient; }
  public static PortalBackendClient portalClient() { return portalClient; }
}
