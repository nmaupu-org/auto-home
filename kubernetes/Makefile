.PHONY: helm
helm:
	kubectl apply -f misc/tiller
	# Needed for installing mosquitto (MQTT) chart
	helm repo add smizy https://smizy.github.io/charts
	helm repo update

.PHONY: ingress-controller
ingress-controller:
	kubectl apply -f misc/ingress-controller

.PHONY: freenas-provisioner
.SILENT: freenas-provisioner
freenas-provisioner: check-vault
	helm upgrade --install \
		--namespace tools \
		--set deployment.image.tag=2.5 \
		--set freenas.username=$(shell vault read -field username secret/nas) \
		--set freenas.password=$(shell vault read -field password secret/nas) \
		--set freenas.host=$(shell vault read -field ip secret/nas) \
		-f helm-values/freenas-provisioner.yaml \
		fp \
		charts/freenas-provisioner

.PHONY: prometheus-operator
.SILENT: prometheus-operator
prometheus-operator: check-vault
	helm upgrade --install \
		--namespace monitoring \
        --version 8.2.0 \
		-f helm-values/prometheus-operator.yaml \
		--set grafana.adminPassword="$(shell vault read -field password secret/grafana)" \
		p8s \
		stable/prometheus-operator

.PHONY: grafana-dashboards
grafana-dashboards:
	kubectl apply -f grafana-dashboards

.PHONY: mqtt-gateway
.SILENT: mqtt-gateway
mqttgateway: check-vault
	helm upgrade --install \
		--namespace iot \
		--version 1.0 \
		--set mqtt.address=tcp://192.168.12.1:1883 \
		--set mqtt.username=$(shell vault read -field username secret/mqtt) \
		--set mqtt.password=$(shell vault read -field password secret/mqtt) \
		-f helm-values/mqttgateway.yaml \
		mg \
		charts/mqttgateway

.PHONY: gladys
gladys:
	helm upgrade --install \
		--namespace iot \
		--set ingress.enabled=true \
		--set ingress.hosts[0].host=gladys.foo.home.fossar.net \
		--set ingress.hosts[0].paths[0]=/ \
		g \
		charts/gladys

# Installed directly on openwrt router
# .PHONY: mosquitto
# mosquitto:
# 	helm upgrade --install \
# 		--namespace iot \
# 		--set persistence.enabled=true \
# 		--set persistence.size=20Gi \
# 		--set persistence.storageClass=freenas-nfs \
# 		--set deployment.resources.limits.cpu=200m \
# 		--set deployment.resources.limits.memory=256Mi \
# 		--set deployment.hostNetwork=true \
# 		mos \
# 		charts/mosquitto

#.PHONY: gonaomi
#gonaomi:
#	helm upgrade --install \
#		--namespace tools \
#		gon \
#		charts/gonaomi

.PHONY: check-vault
check-vault:
	@vault token lookup >/dev/null 2>&1
