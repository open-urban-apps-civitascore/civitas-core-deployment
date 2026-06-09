package de.civitascore.systemtests;

import org.robotframework.javalib.library.AnnotationLibrary;

public class SystemTestRemoteLibrary extends AnnotationLibrary {

  public SystemTestRemoteLibrary() {
    super("de/civitascore/systemtests/SystemTestKeywords.class");
  }
}
