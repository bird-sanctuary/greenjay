# set current revision
REVISION ?= REV16_7

# targets
TARGETS      = A B C D E F G H I J K L M N O P Q R S T U V W Z
MCUS         = H L
TARGETS_X    = A B C
MCUS_X       = X
FETON_DELAYS = 0 5 10 15 20 25 30 40 50 70 90

# example single target
VARIANT     ?= A
MCU         ?= H
FETON_DELAY ?= 5

# Select which phase pair should be the active one (set only one to 1)
USE_PHASES_AB = 1
USE_PHASES_BC = 0
USE_PHASES_CA = 0

# path to the keil binaries
KEIL_PATH	?= ~/.wine/drive_c/Keil_v5/C51/BIN

# some directory config
OUTPUT_DIR     ?= build
HEX_DIR        ?= $(OUTPUT_DIR)/hex

# define the assembler/linker scripts
AX51_BIN = $(KEIL_PATH)/AX51.exe
LX51_BIN = $(KEIL_PATH)/LX51.exe
OX51_BIN = $(KEIL_PATH)/Ohx51.exe
AX51 = wine $(AX51_BIN)
LX51 = wine $(LX51_BIN)
OX51 = wine $(OX51_BIN)

# set up flags
AX51_FLAGS = DEBUG MACRO NOMOD51 COND SYMBOLS PAGEWIDTH(120) PAGELENGTH(65)
LX51_FLAGS = PAGEWIDTH (120) PAGELENGTH (65)

# set up sources
ASM_SRC = BLHeli_S.asm
ASM_INC = $(TARGETS:=.inc) BLHeliBootLoad.inc BLHeliPgm.inc SI_EFM8BB1_Defs.inc SI_EFM8BB2_Defs.inc SI_EFM8BB51_Defs.inc

# check that wine/simplicity studio is available
EXECUTABLES = $(AX51_BIN) $(LX51_BIN) $(OX51_BIN)
DUMMYVAR := $(foreach exec, $(EXECUTABLES), \
		$(if $(wildcard $(exec)),found, \
		$(error "Could not find $(exec). Make sure to set the correct paths to the simplicity install location")))

# Set up efm8load
EFM8_LOAD_BIN  ?= tools/efm8load.py
EFM8_LOAD_PORT ?= /dev/ttyUSB0
EFM8_LOAD_BAUD ?= 57600

# make sure the list of obj files is expanded twice
.SECONDEXPANSION:
OBJS =

define MAKE_OBJ
OBJS += $(1)_$(2)_$(3)_$(REVISION).OBJ
$(OUTPUT_DIR)/$(1)_$(2)_$(3)_$(REVISION).OBJ : $(ASM_SRC) $(ASM_INC)
	$(eval _ESC         := $(1))
	$(eval _ESC_INT     := $(shell printf "%d" "'${_ESC}"))
	$(eval _ESCNO       := $(shell echo $$(( $(_ESC_INT) - 65 + 1))))

	$(if $(shell if [ ${2} = "X" ]; then echo "TRUE"; fi),$(eval _ESCNO := $(shell echo $$(( $(_ESCNO) + 29)))),)

	$(eval _MCU_48MHZ   := $(subst L,0,$(subst H,1,$(subst X,2,$(2)))))
	$(eval _FETON_DELAY := $(3))
	$$(eval _LST		:= $$(patsubst %.OBJ,%.LST,$$@))
	@mkdir -p $(OUTPUT_DIR)
	@echo "AX51 : $$@"
	@$(AX51) $(ASM_SRC) \
		"DEFINE(ESCNO=$(_ESCNO)) " \
		"DEFINE(MCU_48MHZ=$(_MCU_48MHZ)) "\
		"DEFINE(FETON_DELAY=$(_FETON_DELAY)) "\
		"DEFINE(USE_PHASES_AB=$(USE_PHASES_AB)) "\
		"DEFINE(USE_PHASES_BC=$(USE_PHASES_BC)) "\
		"DEFINE(USE_PHASES_CA=$(USE_PHASES_CA)) "\
		"OBJECT($$@) "\
		"PRINT($$(_LST)) "\
		"$(AX51_FLAGS)" > /dev/null 2>&1 || (grep -B 3 -E "\*\*\* (ERROR|WARNING)" $$(_LST); exit 1)

endef

SINGLE_TARGET_HEX = $(HEX_DIR)/$(VARIANT)_$(MCU)_$(FETON_DELAY)_$(REVISION).HEX

single_target : $(SINGLE_TARGET_HEX)

# create all obj targets using macro expansion
$(foreach _e, $(TARGETS), \
	$(foreach _m, $(MCUS), \
		$(foreach _f, $(FETON_DELAYS), \
			$(eval $(call MAKE_OBJ,$(_e),$(_m),$(_f))))))

$(foreach _e, $(TARGETS_X), \
	$(foreach _m, $(MCUS_X), \
		$(foreach _f, $(FETON_DELAYS), \
			$(eval $(call MAKE_OBJ,$(_e),$(_m),$(_f))))))


HEX_TARGETS = $(OBJS:%.OBJ=$(HEX_DIR)/%.hex)

all : $$(HEX_TARGETS)
	@echo "\nbuild finished. built $(shell ls -l $(HEX_DIR) | wc -l) hex targets\n"

$(OUTPUT_DIR)/%.OMF : $(OUTPUT_DIR)/%.OBJ
	$(eval MAP := $(OUTPUT_DIR)/$(shell echo $(basename $(notdir $@)).MAP | tr 'a-z' 'A-Z'))
	@echo "LX51 : linking $< to $@"
#	Linking should produce exactly 1 warning
	@$(LX51) "$<" TO "$@" "$(LX51_FLAGS)" > /dev/null 2>&1; \
		test $$? -lt 2 && grep -q "1 WARNING" $(MAP) || \
		(grep -A 3 -E "\*\*\* (ERROR|WARNING)" $(MAP); exit 1)

$(HEX_DIR)/%.hex : $(OUTPUT_DIR)/%.OMF
	@mkdir -p $(HEX_DIR)
	@echo "OHX  : generating hex file $@"
	@$(OX51) "$<" "HEXFILE ($@)" > /dev/null 2>&1 || (echo "Error: Could not make hex file"; exit 1)

help:
	@echo ""
	@echo "usage examples:"
	@echo "================================================================="
	@echo "make all                              # build all targets"
	@echo "make VARIANT=A MCU=H FETON_DELAY=5    # to build a single target"
	@echo

clean:
	@rm -rf $(LOG_DIR)/*
	@rm -rf $(OUTPUT_DIR)/*

efm8load: single_target
	$(EFM8_LOAD_BIN) -p $(EFM8_LOAD_PORT) -b $(EFM8_LOAD_BAUD) -w $(SINGLE_TARGET_HEX)


.PHONY: all clean help efm8load

