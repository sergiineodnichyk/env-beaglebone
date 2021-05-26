SHELL := /bin/bash
MAKEFLAGS += -rR --no-print-directory

WS :=  $(shell pwd)
BUILD_DIR := $(WS)/build
ENV_DIR := $(WS)/env
CONF_DIR := $(ENV_DIR)/bb-conf

BBLAYERS_CONF := $(CONF_DIR)/bblayers.conf
LOCAL_CONF_LIST := $(notdir $(filter-out $(BBLAYERS_CONF),$(wildcard $(CONF_DIR)/*.conf)))
LOCAL_CONF_DEFAULT := $(word 1,$(LOCAL_CONF_LIST))

ifndef LOCAL_CONF
  LOCAL_CONF := $(LOCAL_CONF_DEFAULT)
endif
BBLOCAL_CONF := $(addprefix $(CONF_DIR)/,$(LOCAL_CONF))
ifeq ("$(wildcard $(BBLOCAL_CONF))","")
  $(error Config file $(BBLOCAL_CONF) not found!)
endif

TARGET ?= beaglebone-image-minimal

ifndef VERBOSE
  VERBOSE := 0
endif

ifeq ($(VERBOSE),0)
  BB_VERBOSE :=
else ifeq ($(VERBOSE),1)
  BB_VERBOSE := -v
else ifeq ($(VERBOSE),2)
  BB_VERBOSE := -vD
else ifeq ($(VERBOSE),3)
  BB_VERBOSE := -vDD
else ifeq ($(VERBOSE),4)
  BB_VERBOSE := -vDDD
else
  $(error Wrong verbosity level '$(VERBOSE)'! Should be: 0..4)
endif


distclean:
	@echo "Clean Yocto environment"
	@rm -rf $(BUILD_DIR)

config:
	@echo "Create Yocto environment using '$(BBLOCAL_CONF)'"
	@source ./sources/poky/oe-init-build-env $(BUILD_DIR) > /dev/null
	@cp $(BBLAYERS_CONF) $(BUILD_DIR)/conf/bblayers.conf
	@cp $(BBLOCAL_CONF) $(BUILD_DIR)/conf/local.conf

bb-exec: config
ifeq ($(origin BB_ARGS),undefined)
	$(error Empty 'BB_ARGS' not allowed!)
else
	@echo "Executing bitbake command: '$(BB_ARGS)'"
	@(source ./sources/poky/oe-init-build-env $(BUILD_DIR) && bitbake $(BB_VERBOSE) $(BB_ARGS))
endif

bb-layers-exec: config
ifeq ($(origin BB_ARGS),undefined)
	$(error Empty 'BB_ARGS' not allowed!)
else
	@echo "Executing bitbake-layers command: '$(BB_ARGS)'"
	@(source ./sources/poky/oe-init-build-env $(BUILD_DIR) && bitbake-layers $(BB_VERBOSE) $(BB_ARGS))
endif

bsp:
	$(MAKE) bb-exec BB_ARGS="$(TARGET)"

sdk: bsp
	$(MAKE) bb-exec BB_ARGS="-c populate_sdk $(TARGET)"

sdcard:
	@echo "Generate sdcard image"
	@(source ./sources/poky/oe-init-build-env $(BUILD_DIR) && ../sources/poky/scripts/wic create sdimage-bootpart -e $(TARGET)) 

all: bsp sdk

help:
	$(info Help)
	$(info --------------------------------------------------------------------------------)
	$(info make help                          - this help text)
	$(info make LOCAL_CONF=<local.conf> all   - build bsp and sdk)
	$(info make LOCAL_CONF=<local.conf> bsp   - build BSP target images)
	$(info make LOCAL_CONF=<local.conf> sdcard - build BSP target sdcard image)
	$(info make LOCAL_CONF=<local.conf> sdk   - build cross-toolchain installer)
	$(info make distclean                     - remove build)
	$(info make bb-exec BB_ARGS=<args>        - execute bitbake with arguments, for other Yocto commands)
	$(info make bb-layers-exec BB_ARGS=<args> - execute bitbake-layers with arguments, for other Yocto commands)
	$(info --------------------------------------------------------------------------------)
	$(info Bitbake verbosity level can be set by argument VERBOSE [1..4], eg: make VERBOSE=1 ...)
	$(info Bitbake local.conf file can be set by argument LOCAL_CONF, eg: make LOCAL_CONF=$(LOCAL_CONF_DEFAULT) ...)
	$(info Available local.conf: $(LOCAL_CONF_LIST))
	$(info Default local.conf: $(LOCAL_CONF_DEFAULT))
	@exit 0
