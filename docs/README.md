# PCLA Wrapper Documentation

This directory contains operational documentation for the PCLA PISA AV
service.

- [Configuration](configuration.md): every wrapper config key, precedence, and
  compatibility behavior.
- [Agents and weights](agents.md): agent naming, registry lookup, route
  dependencies, and weight placement.
- [Deployment](deployment.md): image contract, volumes, internal/external
  CARLA modes, and startup examples.
- [Lifecycle](lifecycle.md): ownership and execution order for Init, Reset,
  Step, ShouldQuit, and Stop.
- [Troubleshooting](troubleshooting.md): common startup, map, route, sensor, and
  model failures.

The configuration reference contains a runnable flat-key baseline.
