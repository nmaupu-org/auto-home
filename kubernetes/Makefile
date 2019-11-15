.PHONY: helm
helm:
	kubectl apply -f tiller/deployment.yaml
	kubectl apply -f tiller/service.yaml
	kubectl apply -f tiller/service-account.yaml
	# Needed for installing mosquitto (MQTT) chart
	helm repo add smizy https://smizy.github.io/charts
	helm repo update

.PHONY: ingress-controller
ingress-controller:
	helm upgrade --install \
		--namespace proxy \
		--set controller.service.type=NodePort \
		--set controller.service.externalTrafficPolicy=Cluster \
		--set controller.service.enableHttps=false \
		--set controller.service.nodePorts.http=30080 \
		--set rbac.create=true \
		ingco \
		stable/nginx-ingress

.PHONY: freenas-provisioner
.SILENT: freenas-provisioner
freenas-provisioner: check-vault
	helm upgrade --install \
		--namespace tools \
		--set deployment.image.tag=2.5 \
		--set freenas.username=$(shell vault read -field username secret/nas) \
		--set freenas.password=$(shell vault read -field password secret/nas) \
		--set freenas.host=$(shell vault read -field ip secret/nas) \
		--set freenas.port=:80 \
		--set freenas.protocol=http \
		--set freenas.allowInsecure=true \
		--set storageclass.reclaimPolicy=Delete \
		--set storageclass.datasetParentName=tank/kube-nfs/provisioner \
		--set storageclass.shareAllowedNetworks=192.168.12.0/24 \
		--set storageclass.shareRetainPreExisting=false \
		fp \
		freenas-provisioner

.PHONY: mosquitto
mosquitto:
	helm upgrade --install \
		--namespace iot \
		--set persistence.enabled=true \
		--set persistence.size=20Gi \
		--set persistence.storageClass=freenas-nfs \
		--set deployment.resources.limits.cpu=200m \
		--set deployment.resources.limits.memory=256Mi \
		--set deployment.hostNetwork=true \
		--set mDNS.enabled=true \
		mos \
		mosquitto

#.PHONY: gonaomi
#gonaomi:
#	helm upgrade --install \
#		--namespace tools \
#		gon \
#		gonaomi

.PHONY: check-vault
check-vault:
	@vault token lookup >/dev/null 2>&1
