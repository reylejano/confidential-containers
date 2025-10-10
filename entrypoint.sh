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
	kind create cluster --config kind-config.yaml | gum pager
	clear
}

destroy_kind() {
	gum spin --title "Destroying Kind Cluster..." -- sleep 2
	kind delete cluster --name coco-test | gum pager
	clear
}

olm_installed() {
	quiet_exec kubectl cluster-info && \
	quiet_exec kubectl get -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml && \
	quiet_exec kubectl get -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml
	validate_command $?
}

install_olm() {
	gum spin --title "Installing Operator Lifecycle Manager..." -- sleep 2
	kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml --wait
	kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml --wait
	clear
}

coco_installed() {
	quiet_exec kubectl get deployment cc-operator-controller-manager -n confidential-containers-system
	validate_command $?
}

install_coco_operator() {
	gum spin --title "Installing Confidential Containers Operator..." -- sleep 2
	kubectl apply -f coco-operator.yaml --wait
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
	kubectl apply -k github.com/confidential-containers/operator/config/samples/ccruntime/default?ref=v0.14.0 --wait
	while ! quiet_exec kubectl diff -f kata-runtimeclass.yaml; do
		gum spin --title "Waiting for kata-qemu-coco-dev runtimeclass to be created..." -- sleep 5
	done
	gum spin --title "kata-qemu-coco-dev runtimeclass created!" -- sleep 2
	gum spin --title "Checking ContainerD" -- \
		bash -c "docker exec coco-test-control-plane bash -c 'crictl rmi --prune && systemctl restart containerd'"
	clear
}

coco_demo_01() {
	quiet_exec kubectl get pod coco-demo-01 -n default
	validate_command $?
}

install_coco_demo_01() {
	gum spin --show-output --title "Testing Confidential Containers Runtime..." -- \
		bash -c "kubectl create -f coco-demo-01.yaml"
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
		bash -c "kubectl create -f coco-demo-02.yaml"
	gum spin --title "Waiting for coco-demo-02 to be running..." --timeout 60s -- \
		bash -c "kubectl wait --for=condition=Ready --timeout=120s pod/coco-demo-02 -n default"
	clear
}

show_menu() {

	ACTION=$(gum table --border rounded --padding "1 2" --height "30" -s ',' <<- EOF
		Step,Status
		Full Send!,$(echo ':rocket:' | gum format -t emoji)
		------------------------------------------,--
		Install Kind,$( kind_cluster_installed )
		Install Operator Lifecycle Manager,$( olm_installed )
		Install Confidential Containers Operator,$( coco_installed )
		Install Confidential Container Runtime,$( ccr_installed )
		Test Runtime,$( coco_demo_01 )
		Test Runtime With Policy,$( coco_demo_02 )
		------------------------------------------,--
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