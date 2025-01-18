# Before installing

Create a user with uid and group number _1001_

Create the following dataset/directories (chown with 1001)

- dls-tmp/incoming-rtorrent
- dls-tmp/nzbget-intermediate

- tank/dls/plex/Movies
- tank/dls/plex/TVShows-sonarr
- tank/dls/configs/nzbget
- tank/dls/configs/plex
- tank/dls/configs/prowlarr
- tank/dls/configs/sonarr
- tank/dls/configs/heimdall


# Bootstrapping

As of 2024, I migrated home nas to Truenas Scale (k8s with k3s instead of jails + debian os).
iX Systems tries to make everything using the GUI, this is unacceptable so we will be using argocd!

Beware: DO NOT UPGRADE truenas as k3s is deprecated and will be removed!

## Preamble

Install gcloud and create a service account for cert-manager DNS-01 challenge solving:

```sh
PROJECT_ID="..."
gcloud iam service-accounts create home-dns01-solver --display-name "home-dns01-solver"
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:home-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com --role roles/dns.admin
```

After create, key can be retrieve with the following command (this is done in Makefile automatically):

```sh
gcloud iam service-accounts keys create google-key.json --iam-account home-dns01-solver@$PROJECT_ID.iam.gserviceaccount.com
```

## Sealed-secrets

Get `sealed-secrets.key` from password manager and save it in this directory.

## Bootstrap

To bootstrap, finally execute:

```sh
GOOGLE_PROJECT_ID=... make
```

# Final notes

## Plex initialization

When fresh installing, plex **will not** be connected. To connect, simply port-forward the service:

```
kubectl -n plex port-forward svc/plex 32400:32400
```

Connect with a browser to http://localhost:32400/web and sign-in the server.

## Creating a sealed secrets

Secrets can be sealed using using the following command (with the current k8s context pointing to the target cluster with sealed secret pod running):

``` bash
cat secret.yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets --format yaml > secret-sealed.yaml
```

# Other cluster notes

There are two directories: `deploy/` and `statics`.

- `deploy/` directory contains ArgoCD `Application`s. Any files in that directory will be deployed as is on the cluster hosting ArgoCD.
- `statics` directory contains static files which have to be deployed in the target cluster (not the one hosting ArgoCD).

So for instance, bgp configuration being custom resources (static files), they are lying in the `statics` directory instead of `deploy` (otherwise, they would be deployed on the ArgoCD cluster which is not what we want!)
