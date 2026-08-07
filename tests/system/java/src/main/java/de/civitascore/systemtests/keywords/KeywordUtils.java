package de.civitascore.systemtests.keywords;

import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

class KeywordUtils {

  static String firstNonBlank(String first, String second) {
    if (first != null && !first.isBlank()) {
      return first.trim();
    }
    return second;
  }

  static String sanitizeSuffix(String suffix) {
    return suffix == null ? "" : suffix.toLowerCase().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
  }

  static boolean parseBoolean(String raw) {
    return raw != null && Boolean.parseBoolean(raw.trim());
  }

  static String generatedSuffix() {
    return Long.toString(Math.abs(ThreadLocalRandom.current().nextLong()), 36)
        + "-"
        + UUID.randomUUID().toString().substring(0, 8);
  }

  static int parsePositiveInt(String raw, int fallback) {
    if (raw == null || raw.isBlank()) {
      return fallback;
    }
    try {
      int value = Integer.parseInt(raw.trim());
      return value > 0 ? value : fallback;
    } catch (NumberFormatException ex) {
      return fallback;
    }
  }

  private KeywordUtils() {}
}
