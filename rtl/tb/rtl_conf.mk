##
#  Copyright 2023,2024 CEA*
#  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
#  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
#  may not use this file except in compliance with the License, or, at your
#  option, the Apache License version 2.0. You may obtain a copy of the
#  License at
#
#  https://solderpad.org/licenses/SHL-2.1/
#
#  Unless required by applicable law or agreed to in writing, any work
#  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
##
##
#  Author     : Cesar Fuguet
#  Date       : October, 2024
#  Description: HPDCACHE Test Makefile
##
ifdef CONF_HPDCACHE_PA_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_PA_WIDTH=$(CONF_HPDCACHE_PA_WIDTH)
endif
ifdef CONF_HPDCACHE_SETS
  CONF_DEFINES += -DCONF_HPDCACHE_SETS=$(CONF_HPDCACHE_SETS)
endif
ifdef CONF_HPDCACHE_WAYS
  CONF_DEFINES += -DCONF_HPDCACHE_WAYS=$(CONF_HPDCACHE_WAYS)
endif
ifdef CONF_HPDCACHE_WORD_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_WORD_WIDTH=$(CONF_HPDCACHE_WORD_WIDTH)
endif
ifdef CONF_HPDCACHE_CL_WORDS
  CONF_DEFINES += -DCONF_HPDCACHE_CL_WORDS=$(CONF_HPDCACHE_CL_WORDS)
endif
ifdef CONF_HPDCACHE_REQ_WORDS
  CONF_DEFINES += -DCONF_HPDCACHE_REQ_WORDS=$(CONF_HPDCACHE_REQ_WORDS)
endif
ifdef CONF_HPDCACHE_REQ_TRANS_ID_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_REQ_TRANS_ID_WIDTH=$(CONF_HPDCACHE_REQ_TRANS_ID_WIDTH)
endif
ifdef CONF_HPDCACHE_REQ_SRC_ID_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_REQ_SRC_ID_WIDTH=$(CONF_HPDCACHE_REQ_SRC_ID_WIDTH)
endif
ifdef CONF_HPDCACHE_VICTIM_SEL
  CONF_DEFINES += -DCONF_HPDCACHE_VICTIM_SEL=$(CONF_HPDCACHE_VICTIM_SEL)
endif
ifdef CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD
  CONF_DEFINES += -DCONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD=$(CONF_HPDCACHE_DATA_WAYS_PER_RAM_WORD)
endif
ifdef CONF_HPDCACHE_DATA_SETS_PER_RAM
  CONF_DEFINES += -DCONF_HPDCACHE_DATA_SETS_PER_RAM=$(CONF_HPDCACHE_DATA_SETS_PER_RAM)
endif
ifdef CONF_HPDCACHE_DATA_RAM_WBYTEENABLE
  CONF_DEFINES += -DCONF_HPDCACHE_DATA_RAM_WBYTEENABLE=$(CONF_HPDCACHE_DATA_RAM_WBYTEENABLE)
endif
ifdef CONF_HPDCACHE_ACCESS_WORDS
  CONF_DEFINES += -DCONF_HPDCACHE_ACCESS_WORDS=$(CONF_HPDCACHE_ACCESS_WORDS)
endif
ifdef CONF_HPDCACHE_WBUF_DIR_ENTRIES
  CONF_DEFINES += -DCONF_HPDCACHE_WBUF_DIR_ENTRIES=$(CONF_HPDCACHE_WBUF_DIR_ENTRIES)
endif
ifdef CONF_HPDCACHE_WBUF_DATA_ENTRIES
  CONF_DEFINES += -DCONF_HPDCACHE_WBUF_DATA_ENTRIES=$(CONF_HPDCACHE_WBUF_DATA_ENTRIES)
endif
ifdef CONF_HPDCACHE_WBUF_WORDS
  CONF_DEFINES += -DCONF_HPDCACHE_WBUF_WORDS=$(CONF_HPDCACHE_WBUF_WORDS)
endif
ifdef CONF_HPDCACHE_WBUF_TIMECNT_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_WBUF_TIMECNT_WIDTH=$(CONF_HPDCACHE_WBUF_TIMECNT_WIDTH)
endif
ifdef CONF_HPDCACHE_WBUF_SEND_FEEDTHROUGH
  CONF_DEFINES += -DCONF_HPDCACHE_WBUF_SEND_FEEDTHROUGH=$(CONF_HPDCACHE_WBUF_SEND_FEEDTHROUGH)
endif
ifdef CONF_HPDCACHE_MSHR_SETS
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_SETS=$(CONF_HPDCACHE_MSHR_SETS)
endif
ifdef CONF_HPDCACHE_MSHR_WAYS
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_WAYS=$(CONF_HPDCACHE_MSHR_WAYS)
endif
ifdef CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD=$(CONF_HPDCACHE_MSHR_WAYS_PER_RAM_WORD)
endif
ifdef CONF_HPDCACHE_MSHR_SETS_PER_RAM
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_SETS_PER_RAM=$(CONF_HPDCACHE_MSHR_SETS_PER_RAM)
endif
ifdef CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_RAM_WBYTEENABLE=$(CONF_HPDCACHE_MSHR_RAM_WBYTEENABLE)
endif
ifdef CONF_HPDCACHE_MSHR_USE_REGBANK
  CONF_DEFINES += -DCONF_HPDCACHE_MSHR_USE_REGBANK=$(CONF_HPDCACHE_MSHR_USE_REGBANK)
endif
ifdef CONF_HPDCACHE_REFILL_FIFO_DEPTH
  CONF_DEFINES += -DCONF_HPDCACHE_REFILL_FIFO_DEPTH=$(CONF_HPDCACHE_REFILL_FIFO_DEPTH)
endif
ifdef CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH
  CONF_DEFINES += -DCONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH=$(CONF_HPDCACHE_REFILL_CORE_RSP_FEEDTHROUGH)
endif
ifdef CONF_HPDCACHE_RTAB_ENTRIES
  CONF_DEFINES += -DCONF_HPDCACHE_RTAB_ENTRIES=$(CONF_HPDCACHE_RTAB_ENTRIES)
endif
ifdef CONF_HPDCACHE_FLUSH_ENTRIES
  CONF_DEFINES += -DCONF_HPDCACHE_FLUSH_ENTRIES=$(CONF_HPDCACHE_FLUSH_ENTRIES)
endif
ifdef CONF_HPDCACHE_FLUSH_FIFO_DEPTH
  CONF_DEFINES += -DCONF_HPDCACHE_FLUSH_FIFO_DEPTH=$(CONF_HPDCACHE_FLUSH_FIFO_DEPTH)
endif
ifdef CONF_HPDCACHE_MEM_ADDR_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_MEM_ADDR_WIDTH=$(CONF_HPDCACHE_MEM_ADDR_WIDTH)
endif
ifdef CONF_HPDCACHE_MEM_ID_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_MEM_ID_WIDTH=$(CONF_HPDCACHE_MEM_ID_WIDTH)
endif
ifdef CONF_HPDCACHE_MEM_DATA_WIDTH
  CONF_DEFINES += -DCONF_HPDCACHE_MEM_DATA_WIDTH=$(CONF_HPDCACHE_MEM_DATA_WIDTH)
endif
ifdef CONF_HPDCACHE_WT_ENABLE
  CONF_DEFINES += -DCONF_HPDCACHE_WT_ENABLE=$(CONF_HPDCACHE_WT_ENABLE)
endif
ifdef CONF_HPDCACHE_WB_ENABLE
  CONF_DEFINES += -DCONF_HPDCACHE_WB_ENABLE=$(CONF_HPDCACHE_WB_ENABLE)
endif
ifdef CONF_HPDCACHE_HIGH_THROUGHPUT
  CONF_DEFINES += -DCONF_HPDCACHE_HIGH_THROUGHPUT=$(CONF_HPDCACHE_HIGH_THROUGHPUT)
endif