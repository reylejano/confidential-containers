#!/bin/bash

quiet_exec() {
	"$@" >/dev/null 2>&1
	return $?
}

print_banner() {
	gum style --align center --border double --margin "1" --padding "1 2" --border-foreground "2" \
		"Welcome to the $(gum style --foreground 3 'Confidential Containers Demo')." \
		"What would you like to do?"
}

validate_command() {
	local STATUS=$1
	if [ $STATUS -eq 0 ]; then
		echo ':heavy_check_mark:' | gum format -t emoji
		return 0
	else
		echo ':x:' | gum format -t emoji
		return 1
	fi
}

kind_cluster_installed() {
	kind get clusters -q | grep -q coco-test
	validate_command $?
}

install_kind() {
	gum spin --title "Installing Kind Cluster..." -- sleep 2
	kind create cluster --config /workspaces/confidential-containers/cluster-config/kind-config.yaml | gum pager
	clear
}

destroy_kind() {
	gum spin --title "Destroying Kind Cluster..." -- sleep 2
	kind delete cluster --name coco-test | gum pager
	clear
}

olm_installed() {
	quiet_exec kubectl cluster-info && \
	quiet_exec kubectl get -f /workspaces/confidential-containers/cluster-config/crds.yaml && \
	quiet_exec kubectl get -f /workspaces/confidential-containers/cluster-config/olm.yaml
	validate_command $?
}

install_olm() {
	gum spin --title "Installing Operator Lifecycle Manager..." -- sleep 2
	kubectl apply -f /workspaces/confidential-containers/cluster-config/crds.yaml --wait
	kubectl apply -f /workspaces/confidential-containers/cluster-config/olm.yaml --wait
	clear
}

coco_installed() {
	quiet_exec kubectl get deployment cc-operator-controller-manager -n confidential-containers-system
	validate_command $?
}

install_coco_operator() {
	gum spin --title "Installing Confidential Containers Operator..." -- sleep 2
	kubectl apply -f /workspaces/confidential-containers/coco-config/coco-operator.yaml --wait
	while ! quiet_exec kubectl get deployment cc-operator-controller-manager -n confidential-containers-system; do
		gum spin --title "Waiting for coco-operator deployment to be created..." -- sleep 5
	done
	gum spin --title "Waiting for coco-operator to be ready..." -- \
		bash -c "kubectl wait --for=condition=Available --timeout=120s deployment/cc-operator-controller-manager -n confidential-containers-system"
	clear
}

ccr_installed() {
	quiet_exec kubectl get ccr ccruntime-sample && \
	quiet_exec kubectl get runtimeclass kata-qemu-coco-dev
	validate_command $?
}

install_ccr() {
	gum spin --title "Installing Confidential Containers Runtime..." -- sleep 2
	kubectl apply -f /workspaces/confidential-containers/coco-config/ccruntime-sample.yaml --wait
	while ! quiet_exec kubectl diff -f /workspaces/confidential-containers/coco-config/ccruntime-sample.yaml; do
		gum spin --title "Waiting for kata-qemu-coco-dev runtimeclass to be created..." -- sleep 5
	done
	gum spin --title "kata-qemu-coco-dev runtimeclass created!" -- sleep 2
	clear
}

coco_demo_01() {
	quiet_exec kubectl get pod coco-demo-01 -n default
	validate_command $?
}

install_coco_demo_01() {
	gum spin --show-output --title "Testing Confidential Containers Runtime..." -- \
		bash -c "kubectl create -f /workspaces/confidential-containers/demo-pods/coco-demo-01.yaml"
	gum spin --title "Waiting for coco-demo-01 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-01 -n default"
	clear
}

coco_demo_02() {
	quiet_exec kubectl get pod coco-demo-02 -n default
	validate_command $?
}

install_coco_demo_02() {
	gum spin --show-output --title "Testing Confidential Containers Runtime With Policy..." -- \
		bash -c "kubectl create -f /workspaces/confidential-containers/demo-pods/coco-demo-02.yaml"
	gum spin --title "Waiting for coco-demo-02 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-02 -n default"
	clear
}

trustee_operator_installed() {
	quiet_exec kubectl get deployment trustee-operator-controller-manager -n trustee-system
	validate_command $?
}

install_trustee_operator() {
	gum spin --title "Installing Trustee Operator..." -- sleep 2
	kubectl apply -f /workspaces/confidential-containers/trustee-config/trustee-operator.yaml --wait
	while ! quiet_exec kubectl get deployment trustee-operator-controller-manager -n trustee-system; do
		gum spin --title "Waiting for trustee-operator deployment to be created..." -- sleep 5
	done
	gum spin --title "Waiting for trustee-operator to be ready..." -- \
		bash -c "kubectl wait --for=condition=Available --timeout=120s deployment/trustee-operator-controller-manager -n trustee-system"
	clear
}

trustee_instance_installed() {
	quiet_exec kubectl get deployment trustee-deployment -n trustee-system
	validate_command $?
}

install_trustee_instance() {
	gum spin --title "Installing Trustee Instance..." -- sleep 2
	kubectl create secret -n trustee-system generic kbs-auth-public-key --from-literal=kbs.pem="$(openssl genpkey -algorithm ed25519)"
	kubectl get secret -n trustee-system kbs-auth-public-key -o go-template='{{index .data "kbs.pem"}}' | base64 -d > /tmp/kbs.pem
	kubectl apply -f /workspaces/confidential-containers/trustee-config/kbs-configmap.yaml
	kubectl apply -f /workspaces/confidential-containers/trustee-config/rvps-reference-values-configmap.yaml
	kubectl apply -f /workspaces/confidential-containers/trustee-config/kbsconfig-sample.yaml
	while ! quiet_exec kubectl get deployment trustee-deployment -n trustee-system; do
		gum spin --title "Waiting for trustee-operator deployment to be created..." -- sleep 5
	done	
	gum spin --title "KBS created!" -- sleep 2
	gum spin --title "Waiting for trustee-operator to be ready..." -- \
		bash -c "kubectl wait --for=condition=Available --timeout=120s deployment/trustee-operator-controller-manager -n trustee-system"
	clear
}

coco_demo_03() {
	quiet_exec kubectl get pod coco-demo-03 -n default
	validate_command $?
}

install_coco_demo_03() {
	export KBS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' -n trustee-system)
	export KBS_PORT=$(kubectl get svc kbs-service -o jsonpath='{.spec.ports[0].nodePort}' -n trustee-system)
	envsubst < /workspaces/confidential-containers/demo-pods/coco-demo-03.yaml | kubectl create -f -
	gum spin --title "Waiting for coco-demo-03 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-03 -n default"
	clear
}

coco_demo_04() {
	quiet_exec kubectl get pod coco-demo-04 -n default
	validate_command $?
}

install_coco_demo_04() {
	export KBS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' -n trustee-system)
	export KBS_PORT=$(kubectl get svc kbs-service -o jsonpath='{.spec.ports[0].nodePort}' -n trustee-system)
	export KBS_PRIVATE_KEY="/tmp/kbs.pem"
	kbs-client --url "http://$KBS_HOST:$KBS_PORT" config --auth-private-key "$KBS_PRIVATE_KEY" set-resource --path default/secret/1 --resource-file /workspaces/confidential-containers/demo-pods/secret.txt
	envsubst < /workspaces/confidential-containers/demo-pods/coco-demo-04.yaml | kubectl create -f -
	gum spin --title "Waiting for coco-demo-04 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-04 -n default"
	clear
}

coco_demo_05() {
	quiet_exec kubectl get pod coco-demo-05 -n default
	validate_command $?
}

install_coco_demo_05() {
	export KBS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' -n trustee-system)
	export KBS_PORT=$(kubectl get svc kbs-service -o jsonpath='{.spec.ports[0].nodePort}' -n trustee-system)
	export KBS_PRIVATE_KEY="/tmp/kbs.pem"
	kbs-client --url "http://$KBS_HOST:$KBS_PORT" config --auth-private-key "$KBS_PRIVATE_KEY" set-resource-policy --policy-file /workspaces/confidential-containers/trustee-config/resources_policy.rego
	envsubst < /workspaces/confidential-containers/demo-pods/coco-demo-05.yaml | kubectl create -f -
	gum spin --title "Waiting for coco-demo-05 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-05 -n default"
	clear
}

show_menu() {

	ACTION=$(gum table --border rounded --padding "1 2" --height "15" -s ',' <<- EOF
		Step,Status
		Full Send!,$(echo ':rocket:' | gum format -t emoji)
		------------------------------------------,--
		Install Kind,$( kind_cluster_installed )
		Install Operator Lifecycle Manager,$( olm_installed )
		Install Confidential Containers Operator,$( coco_installed )
		Install Confidential Container Runtime,$( ccr_installed )
		Test Runtime,$( coco_demo_01 )
		Test Runtime With Policy,$( coco_demo_02 )
		Install Trustee Operator,$( trustee_operator_installed )
		Install Trustee Instance,$( trustee_instance_installed )
		Test Trustee Connection,$( coco_demo_03 )
		Test Trustee Secret,$( coco_demo_04 )
		Test Trustee Secret Policy,$( coco_demo_05 )
		------------------------------------------,--
		Restart ContainerD,$(echo ':wrench:' | gum format -t emoji)
		Run K9S,$(echo ':dog:' | gum format -t emoji)
		Clean Up Cluster,$(echo ':wastebasket:' | gum format -t emoji)
		Finish,$(echo ':checkered_flag:' | gum format -t emoji)
		EOF
	)
	echo $(echo $ACTION | cut -d ',' -f 1)
}

main() {

	clear

	gum style --align center --border double --margin "1" --padding "1 2" --border-foreground "2" \
		"Welcome to the $(gum style --foreground 3 'Confidential Containers Demo')." \
		"What would you like to do?"
	
	while true; do
		option=$(show_menu)
		case $option in
			Full\ Send!)
				destroy_kind
				install_kind
				install_olm
				install_coco_operator
				install_ccr
				install_coco_demo_01
				install_coco_demo_02
				install_trustee_operator
				install_trustee_instance
				install_coco_demo_03
				install_coco_demo_04
				install_coco_demo_05
				print_banner
				;;
			Install\ Kind)
				if quiet_exec kind_cluster_installed; then
					gum spin --title "Kind cluster is already installed." -- sleep 2
				else
					install_kind && print_banner
				fi
				;;
			Install\ Operator\ Lifecycle\ Manager)
				if quiet_exec olm_installed; then
					gum spin --title "Operator Lifecycle Manager is already installed." -- sleep 2
				else
					install_olm && print_banner
				fi
				;;
			Install\ Confidential\ Containers\ Operator)
				if quiet_exec coco_installed; then
					gum spin --title "Confidential Containers Operator is already installed." -- sleep 2
				else
					install_coco_operator
					print_banner
				fi
				;;
			Install\ Confidential\ Container\ Runtime)
				if quiet_exec ccr_installed; then
					gum spin --title "Confidential Containers Runtime is already installed." -- sleep 2
				else
					install_ccr
					print_banner
				fi
				;;
			Test\ Runtime)
				if quiet_exec coco_demo_01; then
					gum spin --title "Demo 01 is already installed." -- sleep 2
				else
					install_coco_demo_01
					print_banner
				fi
				;;
			Test\ Runtime\ With\ Policy)
				if quiet_exec coco_demo_02; then
					gum spin --title "Demo 02 is already installed." -- sleep 2
				else
					install_coco_demo_02
					print_banner
				fi
				;;
			Install\ Trustee\ Operator)
				if quiet_exec trustee_operator_installed; then
					gum spin --title "Trustee Operator is already installed." -- sleep 2
				else
					install_trustee_operator
					print_banner
				fi
				;;
			Install\ Trustee\ Instance)
				if quiet_exec trustee_instance_installed; then
					gum spin --title "Trustee Instance is already installed." -- sleep 2
				else
					install_trustee_instance
					print_banner
				fi
				;;
			Test\ Trustee\ Connection)
				if quiet_exec coco_demo_03; then
					gum spin --title "Demo 03 is already installed." -- sleep 2
				else
					install_coco_demo_03
					print_banner
				fi
				;;
			Test\ Trustee\ Secret)
				if quiet_exec coco_demo_04; then
					gum spin --title "Demo 04 is already installed." -- sleep 2
				else
					install_coco_demo_04
					print_banner
				fi
				;;
			Test\ Trustee\ Secret\ Policy)
				if quiet_exec coco_demo_05; then
					gum spin --title "Demo 05 is already installed." -- sleep 2
				else
					install_coco_demo_05
					print_banner
				fi
				;;
			Restart\ ContainerD)
				gum spin --title "Restarting ContainerD..." -- sleep 2
				docker exec -it coco-test-control-plane bash -c "systemctl restart containerd"
				print_banner
				;;
			Run\ K9S)
				k9s
				print_banner
				;;
			Clean\ Up\ Cluster)
				if ! quiet_exec kind_cluster_installed; then
					gum spin --title "No Kind cluster found to clean up." -- sleep 2
				else
					destroy_kind
					print_banner
				fi
				;;
			*)
				clear
				gum style --border double --margin "1" --padding "1 2" --border-foreground "2" \
					"Thank you for using the $(gum style --foreground 3 'Confidential Containers Demo')."
				break
				;;
		esac
	done
}

main