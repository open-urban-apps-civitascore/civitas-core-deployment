package de.civitascore.systemtests;

import java.util.List;
import org.robotframework.javalib.library.AnnotationLibrary;

public class SystemTestRemoteLibrary extends AnnotationLibrary {

  public SystemTestRemoteLibrary() {
    super(List.of(
        "de/civitascore/systemtests/keywords/SystemTestKeywords.class",
        "de/civitascore/systemtests/keywords/DataStructureKeywords.class",
        "de/civitascore/systemtests/keywords/DataSourceKeywords.class",
        "de/civitascore/systemtests/keywords/DataSetKeywords.class",
        "de/civitascore/systemtests/keywords/PipelineKeywords.class",
        "de/civitascore/systemtests/keywords/GatewayKeywords.class",
        "de/civitascore/systemtests/keywords/DatapoolKeywords.class"));
  }
}
