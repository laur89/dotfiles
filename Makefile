SHELL = /bin/bash

.PHONY: install_work install_personal reload_shell clean

install_work: bootstrap_work reload_shell

install_personal: bootstrap_personal reload_shell

bootstrap_work:
	.bootstrap/install_system.sh work

bootstrap_personal:
	.bootstrap/install_system.sh personal

reload_shell:
	cd && . ~/.bashrc
	. ~/.bash_env_vars
	. ~/.bash_env_vars_overrides
	. $_SCRIPTS_COMMONS 
	. ~/.bash_functions

clean:
	git add . && git reset --hard HEAD

