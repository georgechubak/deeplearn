PHONY: clean data lint requirements sync_data_to_cluster sync_data_from_cluster test_environment clean_hoomd install_hoomd


#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_NAME = deeplearn
MODULE_NAME = src
CLUSTER_HOSTNAME = [OPTIONAL] Hostname of the cluster you want to use.
CLUSTER_USERNAME = [OPTIONAL] Your username on the cluster.
CLUSTER_PROJECT_ROOT_DIR = [OPTIONAL] Full path to your project root directory on the cluster (to be used with rsync).
PYTHON_INTERPRETER = python3
VIRTUALENV = conda

ifeq (conda,$(VIRTUALENV))
	CONDA_EXE := $(shell which conda)
endif

EXTERNAL_SOURCE_DIR := $(PROJECT_DIR)/src/external
HOOMD_DIR := $(EXTERNAL_SOURCE_DIR)/hoomd-blue
HOOMD_URL := https://github.com/glotzerlab/hoomd-blue

#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Lint using flake8
lint:
	flake8 src

## Upload data to cluster
sync_data_to_cluster:
	rsync -avhe 'ssh' --progress data/ $(CLUSTER_USERNAME)@$(CLUSTER_HOSTNAME):$(CLUSTER_PROJECT_ROOT_DIR)/$(PROJECT_NAME)/data/

## Download data from cluster
sync_data_from_cluster:
	rsync -avhe 'ssh' --progress $(CLUSTER_USERNAME)@$(CLUSTER_HOSTNAME):$(CLUSTER_PROJECT_ROOT_DIR)/$(PROJECT_NAME)/data/ data/

## Clean the current installation of hoomd
clean_hoomd:
	# Clean the current build directoty
	rm -rfv $(HOOMD_DIR)/build
	# Clean the installed Python package
	rm -rfv `python3 -c "import site; print(site.getsitepackages()[0])"`/hoomd

## Download and install hoomd
install_hoomd: 
	# Fetch the most recent sources
	mkdir -p $(EXTERNAL_SOURCE_DIR)
	if [ ! -d $(HOOMD_DIR) ] ; then git clone --recursive $(HOOMD_URL) $(HOOMD_DIR); else cd $(HOOMD_DIR); git pull $(HOOMD_URL); fi
	# Clean the installed Python package
	rm -rfv `python3 -c "import site; print(site.getsitepackages()[0])"`/hoomd
	# Configure the build
	mkdir -p $(HOOMD_DIR)/build; cd $(HOOMD_DIR)/build; \
	cmake ../ -DCMAKE_INSTALL_PREFIX=`python3 -c "import site; print(site.getsitepackages()[0])"` \
	-DCMAKE_CXX_FLAGS=-march=native -DCMAKE_C_FLAGS=-march=native -DENABLE_CUDA=ON -DENABLE_MPI=ON #-DBUILD_TESTING=OFF; \
	# Compile and install into the current environment
	make -C "$(HOOMD_DIR)/build" -j16 install

#################################################################################
# ENVIRONMENT                                                                   #
#################################################################################

## Set up virtual environment for this project
create_environment:
ifeq (conda,$(VIRTUALENV))
	@echo ">>> Detected conda in '$(CONDA_EXE)', creating conda environment."
ifneq ("X$(wildcard ./environment_lock.yml)","X")
	$(CONDA_EXE) env create --name $(PROJECT_NAME) -f environment_lock.yml
else
	@echo ">>> Creating lockfile from $(CONDA_EXE) environment specification."
	$(CONDA_EXE) env create --name $(PROJECT_NAME) -f environment.yml
	$(CONDA_EXE) env export --name $(PROJECT_NAME) -f environment_lock.yml
endif
	@echo ">>> New conda env created. Activate with: 'conda activate $(PROJECT_NAME)'"
else
	$(PYTHON_INTERPRETER) -m pip install -q virtualenv virtualenvwrapper
	@echo ">>> Installing virtualenvwrapper if not already intalled.\nMake sure the following lines are in shell startup file\n\
	export WORKON_HOME=$$HOME/.virtualenvs\nexport PROJECT_HOME=$$HOME/Devel\nsource /usr/local/bin/virtualenvwrapper.sh\n"
	@bash -c "source `which virtualenvwrapper.sh`;mkvirtualenv $(PROJECT_NAME) --python=$(PYTHON_INTERPRETER)"
	@echo ">>> New virtualenv created. Activate with:\nworkon $(PROJECT_NAME)"
endif

## Install or update Python dependencies
requirements: test_environment environment.lock requirements.lock

requirements.lock: requirements.txt
ifneq (conda,$(VIRTUALENV))
	@echo ">>> Updating virtualenv specifications."
	$(PYTHON_INTERPRETER) -m pip install -U pip setuptools wheel
	$(PYTHON_INTERPRETER) -m pip install -r requirements.txt
endif

environment.lock: environment.yml
ifeq (conda,$(VIRTUALENV))
	@echo ">>> Updating conda specifications."
	$(CONDA_EXE) env update -n $(PROJECT_NAME) -f $<
	$(CONDA_EXE) env export -n $(PROJECT_NAME) -f environment_lock.yml
	# pip install -e .  # uncomment for conda <= 4.3
endif

## Delete the virtual environment for this project
delete_environment:
ifeq (conda,$(VIRTUALENV))
	@echo "Deleting conda environment."
	$(CONDA_EXE) activate
	$(CONDA_EXE) env remove -n $(PROJECT_NAME)
else
	@echo "Deleting virtualenv environment."
	deactivate
	rm -r $(WORKON_HOME)/$(PROJECT_NAME)
endif

## Test python environment is set-up correctly
test_environment:
ifeq (conda,$(VIRTUALENV))
ifneq (${CONDA_DEFAULT_ENV}, $(PROJECT_NAME))
	$(error Must activate `$(PROJECT_NAME)` environment before proceeding)
endif
endif
	$(PYTHON_INTERPRETER) test_environment.py

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := show-help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: show-help


print-%  : ; @echo $* = $($*)

HELP_VARS := PROJECT_NAME

help-prefix:
	@echo "To get started:"
	@echo "  >>> $$(tput bold)make create_environment$$(tput sgr0)"
	@echo "  >>> $$(tput bold)conda activate $(PROJECT_NAME)$$(tput sgr0)"
	@echo
	@echo "$$(tput bold)Project Variables:$$(tput sgr0)"

show-help: help-prefix $(addprefix print-, $(HELP_VARS))
	@echo
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
