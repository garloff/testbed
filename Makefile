# Makefile
# Common operations
default: stack.yml stack-single.yml

STACKNAME = testbed

stack.yml: templates/stack.yml.j2
	jinja2 -o $@ $^

stack-single.yml: templates/stack.yml.j2
	jinja2 -o $@ -Dnumber_of_nodes=0 $^

deploy: stack.yml environment.yml
	openstack stack create -t $< -e environment.yml $(STACK_PARAMS) $(STACKNAME)

deploy-infra: stack.yml environment.yml
	openstack stack create -t $< -e environment.yml $(STACK_PARAMS) --parameter deploy_infrastructure=true $(STACKNAME)

deploy-infra-ceph: stack.yml environment.yml
	openstack stack create -t $< -e environment.yml $(STACK_PARAMS) --parameter deploy_infrastructure=true --parameter deploy_ceph=true $(STACKNAME)

deploy-infra-ceph-openstack: stack.yml environment.yml
	openstack stack create -t $< -e environment.yml $(STACK_PARAMS) --parameter deploy_infrastructure=true --parameter deploy_ceph=true --parameter deploy_openstack=true $(STACKNAME)

clean:
	openstack stack delete -y $(STACKNAME)

~/.ssh/id_rsa.testbed:
	openstack stack output show $(STACKNAME) private_key -f value -c output_value > $@
	chmod 0600 $@

MANAGER_ADDRESS:
	@openstack stack output show $(STACKNAME) manager_address -f value -c output_value

.PHONY: clean ~/.ssh/id_rsa.testbed MANAGER_ADDRESS deploy deploy-infra deploy-infra-ceph deploy-infra-ceph-openstack
