# Live probe inventory — 2026-11-14

Baseline from context `home`, 65 controller templates / 87 regular-container definitions.
No secrets, environment values, or replica-expanded Pod data are included.

`S` = startup, `L` = liveness, `R` = readiness; `—` = absent.
Changes listed here are repository proposals, not deployed state.

| Namespace | Kind | Workload | Container | Baseline probes | Repository change |
| --- | --- | --- | --- | --- | --- |
| argocd | Deployment | argocd-applicationset-controller | applicationset-controller | — | Add L/R |
| argocd | Deployment | argocd-dex-server | dex-server | — | Unchanged |
| argocd | Deployment | argocd-notifications-controller | notifications-controller | — | Add L/R |
| argocd | Deployment | argocd-redis | redis | — | Add L/R |
| argocd | Deployment | argocd-repo-server | repo-server | L/R | Unchanged |
| argocd | Deployment | argocd-repo-server | cmp-custom-jsonnet | — | Unchanged |
| argocd | Deployment | argocd-server | server | L/R | Unchanged |
| cert-manager | Deployment | cert-manager | cert-manager-controller | L | Unchanged |
| cert-manager | Deployment | cert-manager-cainjector | cert-manager-cainjector | — | Unchanged |
| cert-manager | Deployment | cert-manager-webhook | cert-manager-webhook | L/R | Unchanged |
| cnpg | Deployment | cnpg-cloudnative-pg | manager | L/R | Unchanged |
| cocktails | Deployment | cocktails-app-template | cocktails-app-template | S/L/R | Unchanged |
| descheduler | Deployment | descheduler | descheduler | L | Unchanged |
| dls | Deployment | bazarr | bazarr | S/L/R | Unchanged |
| dls | Deployment | prowlarr | prowlarr-exportarr | S/L/R | Unchanged |
| dls | Deployment | prowlarr | prowlarr | S/L/R | Unchanged |
| dls | Deployment | prowlarr-exportarr | prowlarr | S/L/R | Unchanged |
| dls | Deployment | radarr | radarr-exportarr | S/L/R | Unchanged |
| dls | Deployment | radarr | radarr | S/L/R | Unchanged |
| dls | Deployment | radarr-exportarr | radarr | S/L/R | Unchanged |
| dls | Deployment | rtorrent-rutorrent | rtorrent-rutorrent | S/L/R | Unchanged |
| dls | Deployment | sabnzbd | sabnzbd | S/L/R | Unchanged |
| dls | Deployment | sonarr | sonarr-exportarr | S/L/R | Unchanged |
| dls | Deployment | sonarr | sonarr | S/L/R | Unchanged |
| dls | Deployment | sonarr-exportarr | sonarr | S/L/R | Unchanged |
| gotomation | Deployment | gotomation | gotomation | L/R | Unchanged |
| gotomation | Deployment | gotomation | git-refresher | — | Unchanged |
| hass | Deployment | home-assistant | home-assistant-conf-reloader | — | Add S/L heartbeat |
| hass | Deployment | home-assistant | home-assistant | S/L/R | Unchanged |
| headlamp | Deployment | headlamp | headlamp | L/R | Unchanged |
| heimdall | Deployment | heimdall | heimdall | S/L/R | Unchanged |
| ingress-controller | Deployment | traefik | traefik | L/R | Unchanged |
| kube-system | Deployment | coredns | coredns | L/R | Unchanged |
| kube-system | Deployment | metrics-server | metrics-server | L/R | Unchanged |
| longhorn-system | Deployment | csi-attacher | csi-attacher | — | Unchanged |
| longhorn-system | Deployment | csi-provisioner | csi-provisioner | — | Unchanged |
| longhorn-system | Deployment | csi-resizer | csi-resizer | — | Unchanged |
| longhorn-system | Deployment | csi-snapshotter | csi-snapshotter | — | Unchanged |
| longhorn-system | Deployment | longhorn-driver-deployer | longhorn-driver-deployer | — | Unchanged |
| longhorn-system | Deployment | longhorn-ui | longhorn-ui | — | Unchanged |
| matterbridge | Deployment | matterbridge | matterbridge | — | Add S/L/R |
| metallb | Deployment | metallb-controller | controller | L/R | Unchanged |
| monitoring | Deployment | kube-prometheus-stack-grafana | grafana-sc-dashboard | — | Unchanged |
| monitoring | Deployment | kube-prometheus-stack-grafana | grafana-sc-datasources | — | Unchanged |
| monitoring | Deployment | kube-prometheus-stack-grafana | grafana | L/R | Unchanged |
| monitoring | Deployment | kube-prometheus-stack-kube-state-metrics | kube-state-metrics | L/R | Unchanged |
| monitoring | Deployment | kube-prometheus-stack-operator | kube-prometheus-stack | — | Unchanged |
| mosquitto | Deployment | mosquitto | mosquitto | S/L/R | Unchanged |
| nfs-provisioner | Deployment | nfs-provisioner-nfs-subdir-external-provisioner | nfs-subdir-external-provisioner | — | Unchanged |
| openebs | Deployment | iot-openebs-localpv-provisioner | iot-openebs-localpv-provisioner | L | Unchanged |
| openebs | Deployment | openebs-localpv-provisioner | openebs-localpv-provisioner | L | Unchanged |
| openebs | Deployment | openebs-zfs-localpv-controller | csi-resizer | — | Unchanged |
| openebs | Deployment | openebs-zfs-localpv-controller | csi-snapshotter | — | Unchanged |
| openebs | Deployment | openebs-zfs-localpv-controller | snapshot-controller | — | Unchanged |
| openebs | Deployment | openebs-zfs-localpv-controller | csi-provisioner | — | Unchanged |
| openebs | Deployment | openebs-zfs-localpv-controller | openebs-zfs-plugin | — | Unchanged |
| plex | Deployment | plex | plex | S/L/R | Unchanged |
| reloader | Deployment | reloader-reloader | reloader-reloader | L/R | Unchanged |
| scan-http | Deployment | scan-http-app-template | scan-http-app-template | S/L/R | Unchanged |
| sealed-secrets | Deployment | sealed-secrets | controller | L/R | Unchanged |
| timesheet | Deployment | timesheet-app-template | timesheet-app-template | S/L/R | Unchanged |
| tools | Deployment | sshd | sshd | L/R | Unchanged |
| tools | Deployment | web-static-static-web-server | web-static-static-web-server | S/L/R | Unchanged |
| vault | Deployment | vault-autounseal | vault-autounseal | — | Unchanged |
| argocd | StatefulSet | argocd-application-controller | application-controller | R | Unchanged |
| monitoring | StatefulSet | prometheus-kube-prometheus-stack-prometheus | prometheus | S/L/R | Unchanged |
| monitoring | StatefulSet | prometheus-kube-prometheus-stack-prometheus | config-reloader | — | Unchanged |
| vault | StatefulSet | vault | vault | R | Add L |
| zigbee2mqtt | StatefulSet | zigbee2mqtt-misc | zigbee2mqtt | L | Unchanged |
| zigbee2mqtt | StatefulSet | zigbee2mqtt-xiaomi | zigbee2mqtt | L | Unchanged |
| longhorn-system | DaemonSet | engine-image-ei-75a03ec3 | engine-image-ei-75a03ec3 | L/R | Unchanged |
| longhorn-system | DaemonSet | longhorn-csi-plugin | node-driver-registrar | — | Unchanged |
| longhorn-system | DaemonSet | longhorn-csi-plugin | longhorn-liveness-probe | — | Unchanged |
| longhorn-system | DaemonSet | longhorn-csi-plugin | longhorn-csi-plugin | S/L | Unchanged |
| longhorn-system | DaemonSet | longhorn-manager | longhorn-manager | R | Unchanged |
| longhorn-system | DaemonSet | longhorn-manager | pre-pull-share-manager-image | — | Unchanged |
| metallb | DaemonSet | metallb-speaker | speaker | L/R | Unchanged |
| metallb | DaemonSet | metallb-speaker | frr | S/L | Unchanged |
| metallb | DaemonSet | metallb-speaker | reloader | — | Unchanged |
| metallb | DaemonSet | metallb-speaker | frr-metrics | — | Unchanged |
| monitoring | DaemonSet | kube-prometheus-stack-prometheus-node-exporter | node-exporter | L/R | Unchanged |
| openebs | DaemonSet | iot-openebs-alloy | alloy | R | Unchanged |
| openebs | DaemonSet | iot-openebs-alloy | config-reloader | — | Unchanged |
| openebs | DaemonSet | openebs-alloy | alloy | R | Add L |
| openebs | DaemonSet | openebs-alloy | config-reloader | — | Unchanged |
| openebs | DaemonSet | openebs-zfs-localpv-node | csi-node-driver-registrar | — | Unchanged |
| openebs | DaemonSet | openebs-zfs-localpv-node | openebs-zfs-plugin | — | Unchanged |
