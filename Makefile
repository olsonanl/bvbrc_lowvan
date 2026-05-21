TOP_DIR = ../..
include $(TOP_DIR)/tools/Makefile.common

DEPLOY_RUNTIME ?= /kb/runtime
TARGET ?= /kb/deployment

APP_SERVICE = app_service

SRC_PERL = $(wildcard scripts/*.pl)
BIN_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_PERL))))
DEPLOY_PERL = $(addprefix $(TARGET)/bin/,$(basename $(notdir $(SRC_PERL))))

SRC_SERVICE_PERL = $(wildcard service-scripts/*.pl)
BIN_SERVICE_PERL = $(addprefix $(BIN_DIR)/,$(basename $(notdir $(SRC_SERVICE_PERL))))
DEPLOY_SERVICE_PERL = $(addprefix $(SERVICE_DIR)/bin/,$(basename $(notdir $(SRC_SERVICE_PERL))))

CLIENT_TESTS = $(wildcard t/client-tests/*.t)
SERVER_TESTS = $(wildcard t/server-tests/*.t)
PROD_TESTS = $(wildcard t/prod-tests/*.t)

LOWVAN_PERL = $(wildcard Viral_Annotation/*.pl)
LOWVAN_BIN = $(addprefix $(BIN_DIR)/,$(notdir $(LOWVAN_PERL)))
LOWVAN_DEPLOY = $(addprefix $(TARGET)/bin/,$(notdir $(LOWVAN_PERL)))

LOWVAN_PERL_LIB = $(wildcard Viral_Annotation/*.pm)
LOWVAN_DEPLOY_LIB = $(addprefix $(TARGET)/lib/,$(notdir $(LOWVAN_PERL_LIB)))

LOWVAN_BUILD_DATA = $(shell realpath $(TOP_DIR)/modules/bvbrc_lowvan/$(REPO_DIR))
LOWVAN_DEPLOY_DATA = $(shell realpath $(TARGET))/services/bvbrc_lowvan/$(REPO_DIR)

STARMAN_WORKERS = 8
STARMAN_MAX_REQUESTS = 100

TPAGE_ARGS = --define kb_top=$(TARGET) --define kb_runtime=$(DEPLOY_RUNTIME) --define kb_service_name=$(SERVICE) \
	--define kb_service_port=$(SERVICE_PORT) --define kb_service_dir=$(SERVICE_DIR) \
	--define kb_sphinx_port=$(SPHINX_PORT) --define kb_sphinx_host=$(SPHINX_HOST) \
	--define kb_starman_workers=$(STARMAN_WORKERS) \
	--define kb_starman_max_requests=$(STARMAN_MAX_REQUESTS)

SOURCE_REPO = https://github.com/olsonanl/jdavis_lowvan
#SOURCE_VERSION = v1.0.0
#SOURCE_REPO = https://github.com/jimdavis1/Viral_Annotation
REPO_DIR = Viral_Annotation

all: pull-repo bin

pull-repo: $(REPO_DIR)

$(REPO_DIR): 
	rm -rf $(REPO_DIR)
	git clone --depth 1 $(SOURCE_REPO) $(REPO_DIR)
	# Capture git version
	cd $(REPO_DIR) && perl Other_Scripts/capture_version.pl LowVanVersionData.pm

bin: $(BIN_PERL) $(BIN_SERVICE_PERL) $(LOWVAN_BIN)
	echo $(LOWVAN_BUILD_DATA) $(LOWVAN_BIN)

$(BIN_DIR)/%: Viral_Annotation/% $(TOP_DIR)/user-env.sh
	WRAP_VARIABLES=LOWVAN_DATA_DIR; \
	LOWVAN_DATA_DIR=$(LOWVAN_BUILD_DATA); \
	$(WRAP_PERL_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@


deploy: deploy-all
deploy-all: deploy-client 
deploy-client: deploy-libs deploy-scripts deploy-docs

deploy-service: deploy-lowvan deploy-libs deploy-scripts deploy-service-scripts deploy-specs

#
# Here we need to deploy the underlying annotation scripts.
#
deploy-lowvan:
	if [ "$(KB_OVERRIDE_TOP)" != "" ] ; then sbase=$(KB_OVERRIDE_TOP) ; else sbase=$(TARGET); fi; \
	export WRAP_VARIABLES=LOWVAN_DATA_DIR;  \
	export LOWVAN_DATA_DIR=$(LOWVAN_DEPLOY_DATA); \
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib ; \
	for src in $(LOWVAN_PERL) ; do \
	        basefile=`basename $$src`; \
	        base=`basename $$src .pl`; \
	        echo install $$src $$base ; \
	        cp $$src $(TARGET)/plbin ; \
	        $(WRAP_PERL_SCRIPT) "$$sbase/plbin/$$basefile" $(TARGET)/bin/$$base.pl ; \
	done
	for src in $(LOWVAN_PERL_LIB) ; do \
	        cp $$src $(TARGET)/lib ; \
	done
	mkdir -p $(LOWVAN_DEPLOY_DATA)
	rsync -ar --delete $(REPO_DIR)/. $(LOWVAN_DEPLOY_DATA)/.

deploy-dir:
	if [ ! -d $(SERVICE_DIR) ] ; then mkdir $(SERVICE_DIR) ; fi
	if [ ! -d $(SERVICE_DIR)/bin ] ; then mkdir $(SERVICE_DIR)/bin ; fi

deploy-docs: 


clean:


$(BIN_DIR)/%: service-scripts/%.pl $(TOP_DIR)/user-env.sh
	$(WRAP_PERL_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

$(BIN_DIR)/%: service-scripts/%.py $(TOP_DIR)/user-env.sh
	$(WRAP_PYTHON_SCRIPT) '$$KB_TOP/modules/$(CURRENT_DIR)/$<' $@

include $(TOP_DIR)/tools/Makefile.common.rules
