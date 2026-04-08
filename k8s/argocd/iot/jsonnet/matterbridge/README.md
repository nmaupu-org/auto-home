# Matterbridge

Kubernetes deployment of [Matterbridge](https://github.com/Luligu/matterbridge) — a Matter bridge that exposes smart home devices (e.g. via Home Assistant) to Matter controllers such as Amazon Alexa, Apple Home, or Google Home.

## Overview

- Deploys `luligu/matterbridge` in the `matterbridge` namespace
- Connects to Home Assistant via WebSocket (`haWsUrl`)
- Exposes a Matter fabric on port `5540` and a web UI on port `8283`
- Manifests are generated with Jsonnet

## Configuration

Override defaults by editing `values.yaml` (merged on top of `values-default.yaml`).

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `luligu/matterbridge` | Container image |
| `image.tag` | `3.7.2` | Image tag |
| `pvc.data.size` | `100Mi` | Persistent storage size |
| `pvc.data.storageClass` | `openebs-hostpath` | Storage class |
| `haWsUrl` | `wss://hass.home.fossar.net` | Home Assistant WebSocket URL |
| `matterbridge.port` | `5540` | Matter protocol port |
| `matterbridge.passcode` | `20242025` | Matter pairing passcode |
| `matterbridge.discriminator` | `3840` | Matter discriminator |
| `matterbridge.frontendPort` | `8283` | Web UI port |
| `matterbridge.mdnsInterface` | `enp1s0` | mDNS network interface |

## Pairing with Alexa

1. Open the Matterbridge web UI and confirm devices are listed.
2. In the Alexa app: **Devices** > **+** > **Add Device** > **Other** > **Matter**.
3. Follow the on-screen pairing flow using the passcode/QR code shown in the UI.
