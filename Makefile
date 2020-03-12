# Makefile
# Shortcuts to invoke OSISM testbed stack generation
# Pass STACKNAME=XXX to change the name of the deployed stack (default: testbed),
# STACK_PARAMS= (e.g. --parameter XYZ=abs) if you want to pass parameter to heat
# TMPL_PARAMS= (e.g. -Dnumber_of_volumes=4) if you want to modify the stack
#  generation from the template.
# ENVIRONMENT= allows to override the default environment.yml file to be used.
# If you have not configured your OS_ environment such that openstack works without
# --os-cloud parameter, you can override teh testbed default by passing OS_CLOUD=.
#
# (c) Kurt Garloff <scs@garloff.de>, 3/2020, Apache2 License

STACKNAME = testbed
ENVIRONMENT = environment.yml

NEED_OSCLOUD := $(shell test -z "$$OS_PASSWORD" -a -z "$$OS_CLOUD" && echo 1 || echo 0)
ifeq ($(NEED_OSCLOUD),1)
  OS_CLOUD=testbed
  OPENSTACK=openstack --os-cloud $(OS_CLOUD)
else
  OPENSTACK=openstack
endif

default: stack.yml stack-single.yml

stack.yml: templates/stack.yml.j2
	jinja2 -o $@ $(TMPL_PARAMS) $^

stack-single.yml: templates/stack.yml.j2
	jinja2 -o $@ $(TMPL_PARAMS) -Dnumber_of_nodes=0 $^

dry-run: stack.yml $(ENVIRONMENT)
	$(OPENSTACK) stack create --dry-run -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) $(STACKNAME) -f json; echo

deploy: stack.yml $(ENVIRONMENT)
	@touch .deploy.$(STACKNAME)
	$(OPENSTACK) stack create --timeout 45 -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) $(STACKNAME)

create: deploy

deploy-infra: stack.yml $(ENVIRONMENT)
	@touch .deploy.$(STACKNAME)
	$(OPENSTACK) stack create --timeout 70 -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) --parameter deploy_infrastructure=true $(STACKNAME)

deploy-ceph: stack.yml $(ENVIRONMENT)
	@touch .deploy.$(STACKNAME)
	$(OPENSTACK) stack create --timeout 70 -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) --parameter deploy_ceph=true $(STACKNAME)

# do it all
deploy-openstack: stack.yml $(ENVIRONMENT)
	@touch .deploy.$(STACKNAME)
	$(OPENSTACK) stack create --timeout 150 -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) --parameter deploy_infrastructure=true --parameter deploy_ceph=true --parameter deploy_openstack=true $(STACKNAME)

# this will not do kolla purges etc. so do this before manually if you have deployed infra, ceph or openstack
update: stack.yml $(ENVIRONMENT)
	@touch .deploy.$(STACKNAME)
	$(OPENSTACK) stack update -t $< -e $(ENVIRONMENT) $(STACK_PARAMS) $(STACKNAME)

# Cleanup
clean:
	$(OPENSTACK) stack delete -y $(STACKNAME)
	@rm -f .deploy.$(STACKNAME) .MANAGER_ADDRESS.$(STACKNAME)
	rm -f ~/.ssh/id_rsa.$(STACKNAME)

clean-wait:
	$(OPENSTACK) stack delete -y --wait $(STACKNAME)
	@rm -f .deploy.$(STACKNAME) .MANAGER_ADDRESS.$(STACKNAME)
	rm -f ~/.ssh/id_rsa.$(STACKNAME)

list:
	$(OPENSTACK) stack list

# To recover from stale cached ssh-key and MANAGER_ADDRESS
reset:
	@rm .deploy.$(STACKNAME)

# Watch the creation of the stack
watch: .deploy.$(STACKNAME)
	MGR_ADR=""; STAT=""; while true; do\
		date; openstack stack list; \
		SRV=$$(openstack server list -f value -c "Name" -c "Status" | grep testbed-manager | cut -d ' ' -f2); \
		$(OPENSTACK) server list; \
		if test -z "$$MGR_ADR" -a "$$SRV" = "ACTIVE"; then \
			$(OPENSTACK) stack output show $(STACKNAME) private_key -f value -c output_value > ~/.ssh/id_rsa.$(STACKNAME); \
			chmod 0600 ~/.ssh/id_rsa.$(STACKNAME); \
			MGR_ADR=$$(openstack stack output show $(STACKNAME) manager_address -f value -c output_value); \
			echo "MANAGER_ADDRESS=$$MGR_ADR" > .MANAGER_ADDRESS.$(STACKNAME); \
		fi; \
		if test -n "$$MGR_ADR"; then ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.$(STACKNAME) ubuntu@$$MGR_ADR "sudo grep PLAY /var/log/cloud-init-output.log | grep -v 'PLAY \(\[\(Group hosts\|Gather facts\)\|RECAP\)' | tail -n3; sudo tail -n12 /var/log/cloud-init-output.log"; fi; \
		STAT=$$(openstack stack list -f value -c "Stack Name" -c "Stack Status" | grep $(STACKNAME) | cut -d' ' -f2); \
		if test "$$STAT" == "CREATE_COMPLETE"; then break; fi; \
		if test "$$STAT" == "CREATE_FAILED"; then openstack stack show $(STACKNAME) -f value -c "stack_status_reason"; break; fi; \
		echo; sleep 30; \
	done

# Look for stack
.deploy.$(STACKNAME):
	STAT=$$(openstack stack list -f value -c "Stack Name" -c "Stack Status" | grep $(STACKNAME) | cut -d' ' -f2); \
	if test -n "$$STAT"; then touch .deploy.$(STACKNAME); else echo "use make deploy or deploy-infra or ...."; exit 1; fi

# Get output
~/.ssh/id_rsa.$(STACKNAME): .deploy.$(STACKNAME)
	$(OPENSTACK) stack output show $(STACKNAME) private_key -f value -c output_value > $@
	chmod 0600 $@

.MANAGER_ADDRESS.$(STACKNAME): .deploy.$(STACKNAME)
	@MANAGER_ADDRESS=$$(openstack stack output show $(STACKNAME) manager_address -f value -c output_value); \
	echo "MANAGER_ADDRESS=$$MANAGER_ADDRESS" > $@; \
	echo $$MANAGER_ADDRESS

# Convenience: sshuttle invocation
sshuttle: ~/.ssh/id_rsa.$(STACKNAME) .MANAGER_ADDRESS.$(STACKNAME)
	source ./.MANAGER_ADDRESS.$(STACKNAME); \
	sshuttle --ssh-cmd "ssh -i $<" -r dragon@$$MANAGER_ADDRESS 192.168.40.0/24 192.168.50.0/24 192.168.90.0/24

ssh: ~/.ssh/id_rsa.$(STACKNAME) .MANAGER_ADDRESS.$(STACKNAME)
	source ./.MANAGER_ADDRESS.$(STACKNAME); \
	ssh -i $< dragon@$$MANAGER_ADDRESS

# avoid confusing make by non-file targets
.PHONY: clean clean-wait reset watch sshuttle ssh dry-run list create deploy deploy-infra deploy-ceph deploy-openstack
