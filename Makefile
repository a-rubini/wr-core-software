PLATFORM = lm32

OBJS_WRC = wrc_main.o dev/uart.o dev/endpoint.o dev/minic.o dev/pps_gen.o dev/timer.o dev/softpll.o lib/mprintf.o dev/i2c.o monitor/monitor.o

D = ptp-noposix
PTPD_CFLAGS  = -ffreestanding -DPTPD_FREESTANDING -DWRPC_EXTRA_SLIM -DPTPD_MSBF -DPTPD_DBG
PTPD_CFLAGS += -Wall -ggdb -I$D/wrsw_hal \
	-I$D/libptpnetif -I$D/PTPWRd \
	-include $D/compat.h -include $D/PTPWRd/dep/trace.h -include $D/libposix/ptpd-wrappers.h
PTPD_CFLAGS += -DPTPD_NO_DAEMON -DNEW_SINGLE_WRFSM -DPTPD_TRACE_MASK=0x2804

OBJS_PTPD = $D/PTPWRd/arith.o
OBJS_PTPD += $D/PTPWRd/bmc.o
OBJS_PTPD += $D/PTPWRd/dep/msg.o
OBJS_PTPD += $D/PTPWRd/dep/net.o
OBJS_PTPD += $D/PTPWRd/dep/servo.o
OBJS_PTPD += $D/PTPWRd/dep/sys.o
OBJS_PTPD += $D/PTPWRd/dep/timer.o
OBJS_PTPD += $D/PTPWRd/dep/wr_servo.o
OBJS_PTPD += $D/PTPWRd/protocol.o
OBJS_PTPD += $D/PTPWRd/wr_protocol.o
OBJS_PTPD_FREE   = $D/libposix/freestanding-startup.o
OBJS_PTPD_FREE	+= $D/libposix/freestanding-display.o
OBJS_PTPD_FREE	+= $D/libposix/wr_nolibs.o
OBJS_PTPD_FREE	+= $D/libposix/freestanding-wrapper.o

ifeq ($(PLATFORM), zpu)
CFLAGS_PLATFORM = -abel -Wl,--relax -Wl,--gc-sections
LDFLAGS_PLATFORM = -abel -Wl,--relax -Wl,--gc-sections
OBJS_PLATFORM=
else
CROSS_COMPILE ?= /opt/gcc-lm32/bin/lm32-elf-
CFLAGS_PLATFORM  = -mmultiply-enabled -mbarrel-shift-enabled 

####################################################################
## Select here WR_MASTER (primary clock) or WR_SLAVE mode of WRPC ##
####################################################################
#CFLAGS_PLATFORM += -DWRPC_MASTER
CFLAGS_PLATFORM += -DWRPC_SLAVE

LDFLAGS_PLATFORM = -mmultiply-enabled -mbarrel-shift-enabled   -nostdlib -T target/lm32/ram.ld 
OBJS_PLATFORM=target/lm32/crt0.o target/lm32/irq.o
endif


CC=$(CROSS_COMPILE)gcc
OBJCOPY=$(CROSS_COMPILE)objcopy
OBJDUMP=$(CROSS_COMPILE)objdump
CFLAGS= $(CFLAGS_PLATFORM) -ffunction-sections -fdata-sections -Os -Iinclude -include include/trace.h $(PTPD_CFLAGS) -Iptp-noposix/PTPWRd
LDFLAGS= $(LDFLAGS_PLATFORM) -ffunction-sections -fdata-sections -Os -Iinclude
SIZE = $(CROSS_COMPILE)size
OBJS=$(OBJS_PLATFORM) $(OBJS_WRC) $(OBJS_PTPD) $(OBJS_PTPD_FREE) 
OUTPUT=wrc

all: 		$(OBJS)
				$(SIZE) -t $(OBJS)
				${CC} -o $(OUTPUT).elf $(OBJS) $(LDFLAGS) 
				${OBJCOPY} -O binary $(OUTPUT).elf $(OUTPUT).bin
#				${OBJDUMP} -d $(OUTPUT).elf > $(OUTPUT)_disasm.S
				./tools/genraminit $(OUTPUT).bin 0 > $(OUTPUT).ram

clean:	
	rm -f $(OBJS) $(OUTPUT).elf $(OUTPUT).bin $(OUTPUT).ram

%.o:		%.c
				${CC} $(CFLAGS) $(PTPD_CFLAGS) $(INCLUDE_DIR) $(LIB_DIR) -c $^ -o $@

load:	all
		./tools/zpu-loader $(OUTPUT).bin

tools:
			make -C tools
		
fpga:
		- killall -9 vuart_console
		../loadfile ../spec_top.bin
		./tools/zpu-loader $(OUTPUT).bin
