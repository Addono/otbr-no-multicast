# Custom OpenThread Border Router (OTBR) without Multicast

This repository contains a custom Docker build for the OpenThread Border Router (OTBR), which builds with multicast routing disabled.

## Purpose

The primary purpose of this custom build is to disable `OPENTHREAD_CONFIG_BACKBONE_ROUTER_MULTICAST_ROUTING_ENABLE`. This is necessary for environments where the host kernel does not support multicast routing (e.g., standard Talos Linux kernels), which causes the standard OTBR agent to crash.

To maintain Backbone Router functionality while disabling multicast routing, this build enables `OTBR_DUA_ROUTING` (Domain Unicast Address ND Proxying) as an alternative.

## Build Details

The Dockerfile:
1.  Clones the official [openthread/ot-br-posix](https://github.com/openthread/ot-br-posix) repository.
2.  Patches the CMake configuration to inject:
    -   `-DOPENTHREAD_CONFIG_BACKBONE_ROUTER_MULTICAST_ROUTING_ENABLE=0`
3.  Configures the build with:
    -   `-DOTBR_DUA_ROUTING=ON` (Required when multicast routing is disabled)
    -   Other standard OTBR flags.

## Usage

### Building Locally

```bash
docker build . -t otbr-custom
```

### GitHub Actions

The repository includes a GitHub Actions workflow that automatically builds and pushes the Docker image to GitHub Container Registry (ghcr.io) on changes to the `main` branch.

## License

See the original [openthread/ot-br-posix](https://github.com/openthread/ot-br-posix) license.
