/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : April, 2021
 *  Description   : HPDcache top
 *  History       :
 */
`include "hpdcache_typedef.svh"

module hpdcache
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type wbuf_timecnt_t = logic,

    //  Request Interface Definitions
    //  {{{
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_data_word_t = logic,
    parameter type hpdcache_data_be_t = logic,
    parameter type hpdcache_req_offset_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    //  }}}

    //  Memory Interface Definitions
    //  {{{
    parameter type hpdcache_mem_addr_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_data_t = logic,
    parameter type hpdcache_mem_be_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic,
    //  }}}

    localparam int nReqs  = HPDcacheCfg.u.nRequesters,
    localparam int nBanks = HPDcacheCfg.u.nBanks
)
    //  }}}

    //  Ports
    //  {{{
(
    //      Clock and reset signals
    input  logic                          clk_i,
    input  logic                          rst_ni,

    //      Force the write buffer to send all pending writes
    input  logic                          wbuf_flush_i,

    //      Core request interface
    //         1st cycle
    input  logic                          core_req_valid_i [nReqs],
    output logic                          core_req_ready_o [nReqs],
    input  hpdcache_req_t                 core_req_i       [nReqs],
    //         2nd cycle
    input  logic                          core_req_abort_i [nReqs],
    input  hpdcache_tag_t                 core_req_tag_i   [nReqs],
    input  hpdcache_pma_t                 core_req_pma_i   [nReqs],

    //      Core response interface
    output logic                          core_rsp_valid_o [nReqs],
    output hpdcache_rsp_t                 core_rsp_o       [nReqs],

    //      Read / Invalidation memory interface
    input  logic                          mem_req_read_ready_i,
    output logic                          mem_req_read_valid_o,
    output hpdcache_mem_req_t             mem_req_read_o,

    output logic                          mem_resp_read_ready_o,
    input  logic                          mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t          mem_resp_read_i,
`ifdef HPDCACHE_OPENPITON
    input  logic                          mem_resp_read_inval_i,
    input  hpdcache_nline_t               mem_resp_read_inval_nline_i,
`endif

    //      Write memory interface
    input  logic                          mem_req_write_ready_i,
    output logic                          mem_req_write_valid_o,
    output hpdcache_mem_req_t             mem_req_write_o,

    input  logic                          mem_req_write_data_ready_i,
    output logic                          mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t           mem_req_write_data_o,

    output logic                          mem_resp_write_ready_o,
    input  logic                          mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t          mem_resp_write_i,

    //      Performance events
    output logic [nBanks-1:0]             evt_cache_write_miss_o,
    output logic [nBanks-1:0]             evt_cache_read_miss_o,
    output logic [nBanks-1:0]             evt_uncached_req_o,
    output logic [nBanks-1:0]             evt_cmo_req_o,
    output logic [nBanks-1:0]             evt_write_req_o,
    output logic [nBanks-1:0]             evt_read_req_o,
    output logic [nBanks-1:0]             evt_prefetch_req_o,
    output logic [nBanks-1:0]             evt_req_on_hold_o,
    output logic [nBanks-1:0]             evt_rtab_rollback_o,
    output logic [nBanks-1:0]             evt_stall_refill_o,
    output logic [nBanks-1:0]             evt_stall_o,

    //      Status interface
    output logic [nBanks-1:0]             wbuf_empty_o,

    //      Configuration interface
    input  logic                          cfg_enable_i,
    input  wbuf_timecnt_t                 cfg_wbuf_threshold_i,
    input  logic                          cfg_wbuf_reset_timecnt_on_write_i,
    input  logic                          cfg_wbuf_sequential_waw_i,
    input  logic                          cfg_wbuf_inhibit_write_coalescing_i,
    input  logic                          cfg_prefetch_updt_plru_i,
    input  logic                          cfg_error_on_cacheable_amo_i,
    input  logic                          cfg_rtab_single_entry_i,
    input  logic                          cfg_default_wb_i
);
    //  }}}

    //  Declaration of internal constants and types
    //  {{{

    localparam int BankIdWidth = nBanks > 1 ? $clog2(nBanks) : 1;
    localparam int FLUSH_MODULE_NREQUESTERS = nBanks + 1;
    localparam int CMO_FLUSH_REQ_INDEX = FLUSH_MODULE_NREQUESTERS - 1;

    typedef logic [HPDcacheCfg.u.paWidth-1:0] hpdcache_req_addr_t;
    typedef logic [HPDcacheCfg.nlineWidth-1:0] hpdcache_nline_t;
    typedef logic [HPDcacheCfg.setWidth-1:0] hpdcache_set_t;
    typedef logic [HPDcacheCfg.clOffsetWidth-1:0] hpdcache_offset_t;
    typedef logic unsigned [HPDcacheCfg.clWordIdxWidth-1:0] hpdcache_word_t;
    typedef logic unsigned [HPDcacheCfg.u.ways-1:0] hpdcache_way_vector_t;
    typedef logic unsigned [HPDcacheCfg.wayIndexWidth-1:0] hpdcache_way_t;
    typedef logic [HPDcacheCfg.mshrIdWidth-1:0] hpdcache_mshr_id_t;
    typedef logic [BankIdWidth-1:0] hpdcache_bank_id_t;

    //  Cache Directory entry definition
    //  {{{
    typedef struct packed {
        //  Cacheline state
        //  Encoding: {valid, wb, dirty, fetch}
        //            {0,X,X,0}: Invalid
        //            {0,X,X,1}: Invalid and Fetching
        //            {1,X,X,1}: Valid and Fetching (cacheline being replaced is accessible)
        //            {1,0,0,0}: Write-through
        //            {1,1,0,0}: Write-back (clean)
        //            {1,1,1,0}: Write-back (dirty)
        //  {{{
        logic valid; //  valid cacheline
        logic wback; //  cacheline in write-back mode
        logic dirty; //  cacheline is locally modified (memory is obsolete)
        logic fetch; //  cacheline is reserved for a new cacheline being fetched
        //  }}}

        //  Cacheline address tag
        //  {{{
        hpdcache_tag_t tag;
        //  }}}
    } hpdcache_dir_entry_t;
    //  }}}

    typedef hpdcache_data_word_t [HPDcacheCfg.u.accessWords-1:0] hpdcache_access_data_t;
    typedef hpdcache_data_be_t [HPDcacheCfg.u.accessWords-1:0] hpdcache_access_be_t;

    typedef hpdcache_req_addr_t wbuf_addr_t;
    typedef hpdcache_req_data_t wbuf_data_t;
    typedef hpdcache_req_be_t wbuf_be_t;

    typedef struct packed {
        hpdcache_cmoh_op_t  op;
        hpdcache_req_addr_t addr;
        hpdcache_req_data_t wdata;
        logic [nBanks-1:0]  bank;
    } hpdcache_cmo_req_t;

    typedef struct packed {
        hpdcache_nline_t       nline;
        hpdcache_way_vector_t  way;
        hpdcache_bank_id_t     bank_id;
    } hpdcache_flush_req_t;
    //  }}}

    //  Declaration of internal signals
    //  {{{
    logic                  core_rsp_valid [nReqs];
    logic                  core_rsp_ready [nReqs];
    hpdcache_rsp_t         core_rsp       [nReqs];

    logic                  bank_rsp_valid [nBanks];
    logic                  bank_rsp_ready [nBanks];
    hpdcache_rsp_t         bank_rsp       [nBanks];

    logic                  refill_req_valid  [nBanks];
    logic                  refill_req_ready  [nBanks];
    logic                  refill_is_error;
    logic [nBanks-1:0]     refill_busy;
    logic                  refill_write_dir  [nBanks];
    logic                  refill_write_data [nBanks];
    hpdcache_word_t        refill_word;
    hpdcache_access_data_t refill_data;
    logic                  refill_updt_rtab  [nBanks];

    logic                  inval_check_dir        [nBanks];
    logic                  inval_write_dir        [nBanks];
    hpdcache_nline_t       inval_nline;
    logic                  inval_hit              [nBanks];

    logic                  uc_busy;
    logic                  uc_req_valid                [nBanks];
    logic [nBanks-1:0]     uc_ready;
    hpdcache_uc_op_t       uc_req_op                   [nBanks];
    hpdcache_req_addr_t    uc_req_addr                 [nBanks];
    hpdcache_req_size_t    uc_req_size                 [nBanks];
    hpdcache_req_data_t    uc_req_data                 [nBanks];
    hpdcache_req_be_t      uc_req_be                   [nBanks];
    logic                  uc_req_uncacheable          [nBanks];
    hpdcache_req_sid_t     uc_req_sid                  [nBanks];
    hpdcache_req_tid_t     uc_req_tid                  [nBanks];
    logic                  uc_req_need_rsp             [nBanks];
    logic                  uc_wbuf_flush_all;
    logic                  uc_dir_amo_match            [nBanks];
    hpdcache_set_t         uc_dir_amo_match_set;
    hpdcache_tag_t         uc_dir_amo_match_tag;
    logic                  uc_dir_amo_updt_sel_victim;
    hpdcache_way_vector_t  uc_dir_amo_hit_way          [nBanks];
    logic                  uc_data_amo_write           [nBanks];
    logic                  uc_data_amo_write_enable    [nBanks];
    hpdcache_set_t         uc_data_amo_write_set;
    hpdcache_req_size_t    uc_data_amo_write_size;
    hpdcache_word_t        uc_data_amo_write_word;
    hpdcache_req_data_t    uc_data_amo_write_data;
    hpdcache_req_be_t      uc_data_amo_write_be;
    logic                  uc_lrsc_snoop               [nBanks];
    hpdcache_req_addr_t    uc_lrsc_snoop_addr          [nBanks];
    hpdcache_req_size_t    uc_lrsc_snoop_size          [nBanks];
    logic                  uc_core_rsp_ready           [nBanks];
    logic                  uc_core_rsp_valid           [nBanks];
    hpdcache_rsp_t         uc_core_rsp;

    logic [nBanks-1:0]     cmo_req_valid;
    hpdcache_cmo_req_t [nBanks-1:0] cmo_req;
    logic                  cmo_ready;
    logic                  cmo_busy;
    logic                  cmo_wbuf_flush_all;
    logic                  cmo_dir_check_nline;
    logic                  cmo_dir_check_nline_bank [nBanks];
    hpdcache_set_t         cmo_dir_check_nline_set;
    hpdcache_tag_t         cmo_dir_check_nline_tag;
    hpdcache_way_vector_t  cmo_dir_check_nline_hit_way;
    hpdcache_way_vector_t  cmo_dir_check_nline_hit_way_bank [nBanks];
    logic                  cmo_dir_check_nline_dirty;
    logic                  cmo_dir_check_nline_dirty_bank   [nBanks];
    logic                  cmo_dir_check_entry;
    logic                  cmo_dir_check_entry_bank         [nBanks];
    hpdcache_set_t         cmo_dir_check_entry_set;
    hpdcache_way_vector_t  cmo_dir_check_entry_way;
    logic                  cmo_dir_check_entry_valid;
    logic                  cmo_dir_check_entry_valid_bank   [nBanks];
    logic                  cmo_dir_check_entry_dirty;
    logic                  cmo_dir_check_entry_dirty_bank   [nBanks];
    hpdcache_tag_t         cmo_dir_check_entry_tag;
    hpdcache_tag_t         cmo_dir_check_entry_tag_bank     [nBanks];
    logic                  cmo_dir_inval;
    logic                  cmo_dir_inval_bank [nBanks];
    hpdcache_set_t         cmo_dir_inval_set;
    hpdcache_way_vector_t  cmo_dir_inval_way;
    logic [nBanks-1:0]     cmo_dir_bank_sel;
    logic                  cmo_wait;
    logic                  cmo_flush_alloc;
    hpdcache_nline_t       cmo_flush_alloc_nline;
    hpdcache_way_vector_t  cmo_flush_alloc_way;

    logic                  flush_empty;
    logic                  flush_busy;
    hpdcache_nline_t       flush_check_nline     [nBanks];
    logic                  flush_check_hit       [nBanks];
    logic  [FLUSH_MODULE_NREQUESTERS-1:0] flush_alloc;
    logic                  flush_alloc_ready;
    logic [FLUSH_MODULE_NREQUESTERS-1:0]     flush_alloc_ready_requester;
    hpdcache_flush_req_t [FLUSH_MODULE_NREQUESTERS-1:0] flush_req;
    logic                  flush_data_read;
    logic                  flush_data_read_bank [nBanks];
    hpdcache_set_t         flush_data_read_set;
    hpdcache_word_t        flush_data_read_word;
    hpdcache_way_vector_t  flush_data_read_way;
    hpdcache_access_data_t flush_data_read_data;
    hpdcache_access_data_t flush_data_read_data_bank  [nBanks];
    logic                  flush_ack;
    hpdcache_nline_t       flush_ack_nline;

    logic [nBanks-1:0]     bank_rtab_empty;
    logic [nBanks-1:0]     bank_ctrl_empty;
    logic [nBanks-1:0]     bank_mshr_empty;
    logic                  rtab_empty;
    logic                  ctrl_empty;
    logic                  mshr_empty;

    logic                  bank_req_valid [nBanks];
    logic                  bank_req_ready [nBanks];
    hpdcache_req_t         bank_req       [nBanks];
    logic                  bank_abort     [nBanks];
    hpdcache_tag_t         bank_tag       [nBanks];
    hpdcache_pma_t         bank_pma       [nBanks];

    logic                  mem_req_read_miss_ready;
    logic                  mem_req_read_miss_valid;
    hpdcache_mem_req_t     mem_req_read_miss;

    logic                  mem_resp_read_miss_ready;
    logic                  mem_resp_read_miss_valid;
    hpdcache_mem_resp_r_t  mem_resp_read_miss;
    logic                  mem_resp_read_miss_inval;
    hpdcache_nline_t       mem_resp_read_miss_inval_nline;

    logic                  mem_req_read_uc_ready;
    logic                  mem_req_read_uc_valid;
    hpdcache_mem_req_t     mem_req_read_uc;

    logic                  mem_resp_read_uc_ready;
    logic                  mem_resp_read_uc_valid;
    hpdcache_mem_resp_r_t  mem_resp_read_uc;

    logic                  mem_req_write_wbuf_ready[nBanks];
    logic                  mem_req_write_wbuf_valid[nBanks];
    hpdcache_mem_req_t     mem_req_write_wbuf[nBanks];

    logic                  mem_req_write_wbuf_data_ready[nBanks];
    logic                  mem_req_write_wbuf_data_valid[nBanks];
    hpdcache_mem_req_w_t   mem_req_write_wbuf_data[nBanks];

    logic                  mem_resp_write_wbuf_ready[nBanks];
    logic                  mem_resp_write_wbuf_valid[nBanks];
    hpdcache_mem_resp_w_t  mem_resp_write_wbuf[nBanks];

    logic                  mem_req_write_flush_ready;
    logic                  mem_req_write_flush_valid;
    hpdcache_mem_req_t     mem_req_write_flush;

    logic                  mem_req_write_flush_data_ready;
    logic                  mem_req_write_flush_data_valid;
    hpdcache_mem_req_w_t   mem_req_write_flush_data;

    logic                  mem_resp_write_flush_ready;
    logic                  mem_resp_write_flush_valid;
    hpdcache_mem_resp_w_t  mem_resp_write_flush;

    logic                  mem_req_write_uc_ready;
    logic                  mem_req_write_uc_valid;
    hpdcache_mem_req_t     mem_req_write_uc;

    logic                  mem_req_write_uc_data_ready;
    logic                  mem_req_write_uc_data_valid;
    hpdcache_mem_req_w_t   mem_req_write_uc_data;

    logic                  mem_resp_write_uc_ready;
    logic                  mem_resp_write_uc_valid;
    hpdcache_mem_resp_w_t  mem_resp_write_uc;

    logic                  cfg_default_wb;

    localparam logic [HPDcacheCfg.u.memIdWidth-1:0] HPDCACHE_UC_READ_ID =
        {HPDcacheCfg.u.memIdWidth{1'b1}};
    localparam logic [HPDcacheCfg.u.memIdWidth-1:0] HPDCACHE_UC_WRITE_ID =
        {HPDcacheCfg.u.memIdWidth{1'b1}};

    logic                  miss_req_valid   [nBanks];
    logic                  miss_req_ready   [nBanks];
    hpdcache_nline_t       miss_req_nline   [nBanks];
    hpdcache_mshr_id_t     miss_req_mshr_id [nBanks];

    logic                  mshr_ack    [nBanks];
    logic                  mshr_ack_cs [nBanks];
    hpdcache_mshr_id_t     mshr_ack_id [nBanks];

    genvar gen_bank;
    genvar gen_req;
    //  }}}

    //  HPDcache controller
    //  {{{
    if (HPDcacheCfg.u.wtEn && HPDcacheCfg.u.wbEn) begin : gen_cfg_default_external
        assign cfg_default_wb = cfg_default_wb_i;
    end else if (HPDcacheCfg.u.wbEn) begin : gen_cfg_default_wb
        assign cfg_default_wb = 1'b1;
    end else begin : gen_cfg_default_wt
        assign cfg_default_wb = 1'b0;
    end

    //  bank crossbar
    //  {{{
    typedef hpdcache_bank_id_t[2**BankIdWidth-1:0] bank_rt_t;

    function automatic bank_rt_t buildBankRt();
        bank_rt_t ret;
        for (int unsigned i = 0; i < 2**BankIdWidth; i++) begin
            ret[i] = hpdcache_bank_id_t'(i % nBanks);
        end
        return ret;
    endfunction

    localparam bank_rt_t bank_rt = buildBankRt();

    //  The HPDcache makes the assumption that the requester is always ready
    //  to accept a response
    for (gen_req = 0; gen_req < nReqs; gen_req++) begin
        assign core_rsp_ready[gen_req] = 1'b1;
    end

    hpdcache_bank_xbar #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_tag_t                     (hpdcache_tag_t),
        .hpdcache_req_t                     (hpdcache_req_t),
        .hpdcache_rsp_t                     (hpdcache_rsp_t),
        .routing_table_t                    (bank_rt_t),
        .offStart                           (HPDcacheCfg.clOffsetWidth),
        .offWidth                           (BankIdWidth),
        .rt                                 (bank_rt)
    ) bank_xbar_i(
        .clk_i,
        .rst_ni,

        .core_req_valid_i,
        .core_req_ready_o,
        .core_req_i,
        .core_req_abort_i,
        .core_req_tag_i,
        .core_req_pma_i,
        .core_rsp_valid_o,
        .core_rsp_ready_i                   (core_rsp_ready),
        .core_rsp_o,

        .bank_req_valid_o                   (bank_req_valid),
        .bank_req_ready_i                   (bank_req_ready),
        .bank_req_o                         (bank_req),
        .bank_abort_o                       (bank_abort),
        .bank_tag_o                         (bank_tag),
        .bank_pma_o                         (bank_pma),
        .bank_rsp_valid_i                   (bank_rsp_valid),
        .bank_rsp_ready_o                   (bank_rsp_ready),
        .bank_rsp_i                         (bank_rsp)
    );
    //  }}}

    for (gen_bank = 0; gen_bank < nBanks; gen_bank++) begin: gen_banks
        //  bank controller
        //  {{{
        hpdcache_ctrl #(
            .HPDcacheCfg                        (HPDcacheCfg),
            .hpdcache_nline_t                   (hpdcache_nline_t),
            .hpdcache_tag_t                     (hpdcache_tag_t),
            .hpdcache_set_t                     (hpdcache_set_t),
            .hpdcache_word_t                    (hpdcache_word_t),
            .hpdcache_data_word_t               (hpdcache_data_word_t),
            .hpdcache_data_be_t                 (hpdcache_data_be_t),
            .hpdcache_dir_entry_t               (hpdcache_dir_entry_t),
            .hpdcache_way_vector_t              (hpdcache_way_vector_t),
            .hpdcache_way_t                     (hpdcache_way_t),
            .hpdcache_mshr_id_t                 (hpdcache_mshr_id_t),
            .wbuf_addr_t                        (wbuf_addr_t),
            .wbuf_data_t                        (wbuf_data_t),
            .wbuf_be_t                          (wbuf_be_t),
            .wbuf_timecnt_t                     (wbuf_timecnt_t),
            .hpdcache_access_data_t             (hpdcache_access_data_t),
            .hpdcache_access_be_t               (hpdcache_access_be_t),
            .hpdcache_req_addr_t                (hpdcache_req_addr_t),
            .hpdcache_req_offset_t              (hpdcache_req_offset_t),
            .hpdcache_req_tid_t                 (hpdcache_req_tid_t),
            .hpdcache_req_sid_t                 (hpdcache_req_sid_t),
            .hpdcache_req_data_t                (hpdcache_req_data_t),
            .hpdcache_req_be_t                  (hpdcache_req_be_t),
            .hpdcache_req_t                     (hpdcache_req_t),
            .hpdcache_rsp_t                     (hpdcache_rsp_t),
            .hpdcache_mem_id_t                  (hpdcache_mem_id_t),
            .hpdcache_mem_req_t                 (hpdcache_mem_req_t),
            .hpdcache_mem_req_w_t               (hpdcache_mem_req_w_t),
            .hpdcache_mem_resp_w_t              (hpdcache_mem_resp_w_t)
        ) hpdcache_ctrl_i(
            .clk_i,
            .rst_ni,

            .cfg_prefetch_updt_sel_victim_i     (cfg_prefetch_updt_plru_i),

            .core_req_valid_i                   (bank_req_valid[gen_bank]),
            .core_req_ready_o                   (bank_req_ready[gen_bank]),
            .core_req_i                         (bank_req[gen_bank]),
            .core_req_abort_i                   (bank_abort[gen_bank]),
            .core_req_tag_i                     (bank_tag[gen_bank]),
            .core_req_pma_i                     (bank_pma[gen_bank]),

            .core_rsp_valid_o                   (bank_rsp_valid[gen_bank]),
            .core_rsp_ready_i                   (bank_rsp_ready[gen_bank]),
            .core_rsp_o                         (bank_rsp[gen_bank]),

            .wbuf_flush_i,

            .cachedir_hit_o                     (/* unused */),

            .miss_req_valid_o                   (miss_req_valid[gen_bank]),
            .miss_req_ready_i                   (miss_req_ready[gen_bank]),
            .miss_req_nline_o                   (miss_req_nline[gen_bank]),
            .miss_req_mshr_id_o                 (miss_req_mshr_id[gen_bank]),

            .mshr_ack_i                         (mshr_ack[gen_bank]),
            .mshr_ack_cs_i                      (mshr_ack_cs[gen_bank]),
            .mshr_ack_id_i                      (mshr_ack_id[gen_bank]),

            .mshr_full_o                        (/* unused */),
            .mshr_empty_o                       (bank_mshr_empty[gen_bank]),

            .refill_req_valid_i                 (refill_req_valid[gen_bank]),
            .refill_req_ready_o                 (refill_req_ready[gen_bank]),
            .refill_is_error_i                  (refill_is_error),
            .refill_busy_i                      (refill_busy[gen_bank]),
            .refill_write_dir_i                 (refill_write_dir[gen_bank]),
            .refill_write_data_i                (refill_write_data[gen_bank]),
            .refill_word_i                      (refill_word),
            .refill_data_i                      (refill_data),
            .refill_updt_rtab_i                 (refill_updt_rtab[gen_bank]),

            .flush_busy_i                       (flush_busy),
            .flush_check_nline_o                (flush_check_nline[gen_bank]),
            .flush_check_hit_i                  (flush_check_hit[gen_bank]),
            .flush_alloc_o                      (flush_alloc[gen_bank]),
            .flush_alloc_ready_i                (flush_alloc_ready_requester[gen_bank]),
            .flush_alloc_nline_o                (flush_req[gen_bank].nline),
            .flush_alloc_way_o                  (flush_req[gen_bank].way),
            .flush_data_read_i                  (flush_data_read_bank[gen_bank]),
            .flush_data_read_set_i              (flush_data_read_set),
            .flush_data_read_word_i             (flush_data_read_word),
            .flush_data_read_way_i              (flush_data_read_way),
            .flush_data_read_data_o             (flush_data_read_data_bank[gen_bank]),
            .flush_ack_i                        (flush_ack),
            .flush_ack_nline_i                  (flush_ack_nline),

            .inval_check_dir_i                  (inval_check_dir[gen_bank]),
            .inval_write_dir_i                  (inval_write_dir[gen_bank]),
            .inval_nline_i                      (inval_nline),
            .inval_hit_o                        (inval_hit[gen_bank]),

            .wbuf_empty_o                       (wbuf_empty_o[gen_bank]),

            .mem_req_write_wbuf_ready_i         (mem_req_write_wbuf_ready[gen_bank]),
            .mem_req_write_wbuf_valid_o         (mem_req_write_wbuf_valid[gen_bank]),
            .mem_req_write_wbuf_o               (mem_req_write_wbuf[gen_bank]),

            .mem_req_write_wbuf_data_ready_i    (mem_req_write_wbuf_data_ready[gen_bank]),
            .mem_req_write_wbuf_data_valid_o    (mem_req_write_wbuf_data_valid[gen_bank]),
            .mem_req_write_wbuf_data_o          (mem_req_write_wbuf_data[gen_bank]),

            .mem_resp_write_wbuf_ready_o        (mem_resp_write_wbuf_ready[gen_bank]),
            .mem_resp_write_wbuf_valid_i        (mem_resp_write_wbuf_valid[gen_bank]),
            .mem_resp_write_wbuf_i              (mem_resp_write_wbuf[gen_bank]),

            .uc_busy_i                          (uc_busy),
            .uc_ready_i                         (uc_ready[gen_bank]),
            .uc_lrsc_snoop_o                    (uc_lrsc_snoop[gen_bank]),
            .uc_lrsc_snoop_addr_o               (uc_lrsc_snoop_addr[gen_bank]),
            .uc_lrsc_snoop_size_o               (uc_lrsc_snoop_size[gen_bank]),
            .uc_req_valid_o                     (uc_req_valid[gen_bank]),
            .uc_req_op_o                        (uc_req_op[gen_bank]),
            .uc_req_addr_o                      (uc_req_addr[gen_bank]),
            .uc_req_size_o                      (uc_req_size[gen_bank]),
            .uc_req_data_o                      (uc_req_data[gen_bank]),
            .uc_req_be_o                        (uc_req_be[gen_bank]),
            .uc_req_uc_o                        (uc_req_uncacheable[gen_bank]),
            .uc_req_sid_o                       (uc_req_sid[gen_bank]),
            .uc_req_tid_o                       (uc_req_tid[gen_bank]),
            .uc_req_need_rsp_o                  (uc_req_need_rsp[gen_bank]),
            .uc_wbuf_flush_all_i                (uc_wbuf_flush_all),
            .uc_dir_amo_match_i                 (uc_dir_amo_match[gen_bank]),
            .uc_dir_amo_match_set_i             (uc_dir_amo_match_set),
            .uc_dir_amo_match_tag_i             (uc_dir_amo_match_tag),
            .uc_dir_amo_updt_sel_victim_i       (uc_dir_amo_updt_sel_victim),
            .uc_dir_amo_hit_way_o               (uc_dir_amo_hit_way[gen_bank]),
            .uc_data_amo_write_i                (uc_data_amo_write[gen_bank]),
            .uc_data_amo_write_enable_i         (uc_data_amo_write_enable[gen_bank]),
            .uc_data_amo_write_set_i            (uc_data_amo_write_set),
            .uc_data_amo_write_size_i           (uc_data_amo_write_size),
            .uc_data_amo_write_word_i           (uc_data_amo_write_word),
            .uc_data_amo_write_data_i           (uc_data_amo_write_data),
            .uc_data_amo_write_be_i             (uc_data_amo_write_be),
            .uc_core_rsp_ready_o                (uc_core_rsp_ready[gen_bank]),
            .uc_core_rsp_valid_i                (uc_core_rsp_valid[gen_bank]),
            .uc_core_rsp_i                      (uc_core_rsp),

            .cmo_busy_i                         (cmo_busy),
            .cmo_wait_i                         (cmo_wait),
            .cmo_req_valid_o                    (cmo_req_valid[gen_bank]),
            .cmo_req_op_o                       (cmo_req[gen_bank].op),
            .cmo_req_addr_o                     (cmo_req[gen_bank].addr),
            .cmo_req_wdata_o                    (cmo_req[gen_bank].wdata),
            .cmo_wbuf_flush_all_i               (cmo_wbuf_flush_all),
            .cmo_dir_check_nline_i              (cmo_dir_check_nline_bank[gen_bank]),
            .cmo_dir_check_nline_set_i          (cmo_dir_check_nline_set),
            .cmo_dir_check_nline_tag_i          (cmo_dir_check_nline_tag),
            .cmo_dir_check_nline_hit_way_o      (cmo_dir_check_nline_hit_way_bank[gen_bank]),
            .cmo_dir_check_nline_dirty_o        (cmo_dir_check_nline_dirty_bank[gen_bank]),
            .cmo_dir_check_entry_i              (cmo_dir_check_entry_bank[gen_bank]),
            .cmo_dir_check_entry_set_i          (cmo_dir_check_entry_set),
            .cmo_dir_check_entry_way_i          (cmo_dir_check_entry_way),
            .cmo_dir_check_entry_valid_o        (cmo_dir_check_entry_valid_bank[gen_bank]),
            .cmo_dir_check_entry_dirty_o        (cmo_dir_check_entry_dirty_bank[gen_bank]),
            .cmo_dir_check_entry_tag_o          (cmo_dir_check_entry_tag_bank[gen_bank]),
            .cmo_dir_inval_i                    (cmo_dir_inval_bank[gen_bank]),
            .cmo_dir_inval_set_i                (cmo_dir_inval_set),
            .cmo_dir_inval_way_i                (cmo_dir_inval_way),

            .rtab_empty_o                       (bank_rtab_empty[gen_bank]),
            .ctrl_empty_o                       (bank_ctrl_empty[gen_bank]),

            .cfg_enable_i,
            .cfg_prefetch_updt_plru_i,
            .cfg_rtab_single_entry_i,
            .cfg_default_wb_i                   (cfg_default_wb),

            .cfg_wbuf_threshold_i,
            .cfg_wbuf_reset_timecnt_on_write_i,
            .cfg_wbuf_sequential_waw_i,
            .cfg_wbuf_inhibit_write_coalescing_i,

            .evt_cache_write_miss_o             (evt_cache_write_miss_o[gen_bank]),
            .evt_cache_read_miss_o              (evt_cache_read_miss_o[gen_bank]),
            .evt_uncached_req_o                 (evt_uncached_req_o[gen_bank]),
            .evt_cmo_req_o                      (evt_cmo_req_o[gen_bank]),
            .evt_write_req_o                    (evt_write_req_o[gen_bank]),
            .evt_read_req_o                     (evt_read_req_o[gen_bank]),
            .evt_prefetch_req_o                 (evt_prefetch_req_o[gen_bank]),
            .evt_req_on_hold_o                  (evt_req_on_hold_o[gen_bank]),
            .evt_rtab_rollback_o                (evt_rtab_rollback_o[gen_bank]),
            .evt_stall_refill_o                 (evt_stall_refill_o[gen_bank]),
            .evt_stall_o                        (evt_stall_o[gen_bank])
        );

        assign cmo_req[gen_bank].bank = 1 << gen_bank;
        assign flush_req[gen_bank].bank_id = gen_bank;
        //  }}}
    end

    assign rtab_empty = &bank_rtab_empty;
    assign ctrl_empty = &bank_ctrl_empty;
    assign mshr_empty = &bank_mshr_empty;
    //  }}}

    //  Miss handler
    //  {{{
    hpdcache_miss_handler #(
        .HPDcacheCfg                        (HPDcacheCfg),
        .hpdcache_nline_t                   (hpdcache_nline_t),
        .hpdcache_word_t                    (hpdcache_word_t),
        .hpdcache_way_vector_t              (hpdcache_way_vector_t),
        .hpdcache_way_t                     (hpdcache_way_t),
        .hpdcache_refill_data_t             (hpdcache_access_data_t),
        .hpdcache_mshr_id_t                 (hpdcache_mshr_id_t),
        .hpdcache_req_data_t                (hpdcache_req_data_t),
        .hpdcache_req_offset_t              (hpdcache_req_offset_t),
        .hpdcache_req_sid_t                 (hpdcache_req_sid_t),
        .hpdcache_req_tid_t                 (hpdcache_req_tid_t),
        .hpdcache_req_t                     (hpdcache_req_t),
        .hpdcache_rsp_t                     (hpdcache_rsp_t),
        .hpdcache_mem_id_t                  (hpdcache_mem_id_t),
        .hpdcache_mem_req_t                 (hpdcache_mem_req_t),
        .hpdcache_mem_resp_r_t              (hpdcache_mem_resp_r_t),
        .hpdcache_bank_id_t                 (hpdcache_bank_id_t)
    ) hpdcache_miss_handler_i(
        .clk_i,
        .rst_ni,

        .miss_req_valid_i                   (miss_req_valid),
        .miss_req_ready_o                   (miss_req_ready),
        .miss_req_nline_i                   (miss_req_nline),
        .miss_req_mshr_id_i                 (miss_req_mshr_id),

        .refill_req_ready_i                 (refill_req_ready),
        .refill_req_valid_o                 (refill_req_valid),
        .refill_is_error_o                  (refill_is_error),
        .refill_busy_o                      (refill_busy),
        .refill_write_dir_o                 (refill_write_dir),
        .refill_write_data_o                (refill_write_data),
        .refill_data_o                      (refill_data),
        .refill_word_o                      (refill_word),
        .refill_updt_rtab_o                 (refill_updt_rtab),

        .inval_check_dir_o                  (inval_check_dir),
        .inval_write_dir_o                  (inval_write_dir),
        .inval_nline_o                      (inval_nline),
        .inval_hit_i                        (inval_hit),

        .mshr_ack_o                         (mshr_ack),
        .mshr_ack_cs_o                      (mshr_ack_cs),
        .mshr_ack_id_o                      (mshr_ack_id),

        .mem_req_ready_i                    (mem_req_read_miss_ready),
        .mem_req_valid_o                    (mem_req_read_miss_valid),
        .mem_req_o                          (mem_req_read_miss),

        .mem_resp_ready_o                   (mem_resp_read_miss_ready),
        .mem_resp_valid_i                   (mem_resp_read_miss_valid),
        .mem_resp_i                         (mem_resp_read_miss),
        .mem_resp_inval_i                   (mem_resp_read_miss_inval),
        .mem_resp_inval_nline_i             (mem_resp_read_miss_inval_nline)
    );
    //  }}}

    //  Uncacheable request handler
    //  {{{
    hpdcache_uncached #(
        .HPDcacheCfg                   (HPDcacheCfg),
        .hpdcache_nline_t              (hpdcache_nline_t),
        .hpdcache_tag_t                (hpdcache_tag_t),
        .hpdcache_set_t                (hpdcache_set_t),
        .hpdcache_offset_t             (hpdcache_offset_t),
        .hpdcache_word_t               (hpdcache_word_t),
        .hpdcache_req_addr_t           (hpdcache_req_addr_t),
        .hpdcache_req_tid_t            (hpdcache_req_tid_t),
        .hpdcache_req_sid_t            (hpdcache_req_sid_t),
        .hpdcache_req_data_t           (hpdcache_req_data_t),
        .hpdcache_req_be_t             (hpdcache_req_be_t),
        .hpdcache_way_vector_t         (hpdcache_way_vector_t),
        .hpdcache_req_t                (hpdcache_req_t),
        .hpdcache_rsp_t                (hpdcache_rsp_t),
        .hpdcache_mem_addr_t           (hpdcache_mem_addr_t),
        .hpdcache_mem_id_t             (hpdcache_mem_id_t),
        .hpdcache_mem_req_t            (hpdcache_mem_req_t),
        .hpdcache_mem_req_w_t          (hpdcache_mem_req_w_t),
        .hpdcache_mem_resp_r_t         (hpdcache_mem_resp_r_t),
        .hpdcache_mem_resp_w_t         (hpdcache_mem_resp_w_t),
        .hpdcache_bank_id_t            (hpdcache_bank_id_t)
    ) hpdcache_uc_i(
        .clk_i,
        .rst_ni,

        .wbuf_empty_i                  (wbuf_empty_o),
        .mshr_empty_i                  (mshr_empty),
        .refill_busy_i                 (|refill_busy),
        .rtab_empty_i                  (rtab_empty),
        .ctrl_empty_i                  (ctrl_empty),
        .flush_empty_i                 (flush_empty),
        .uc_busy_o                     (uc_busy),

        .req_valid_i                   (uc_req_valid),
        .req_ready_o                   (uc_ready),
        .req_op_i                      (uc_req_op),
        .req_addr_i                    (uc_req_addr),
        .req_size_i                    (uc_req_size),
        .req_data_i                    (uc_req_data),
        .req_be_i                      (uc_req_be),
        .req_uc_i                      (uc_req_uncacheable),
        .req_sid_i                     (uc_req_sid),
        .req_tid_i                     (uc_req_tid),
        .req_need_rsp_i                (uc_req_need_rsp),

        .wbuf_flush_all_o              (uc_wbuf_flush_all),

        .dir_amo_match_o               (uc_dir_amo_match),
        .dir_amo_match_set_o           (uc_dir_amo_match_set),
        .dir_amo_match_tag_o           (uc_dir_amo_match_tag),
        .dir_amo_updt_sel_victim_o     (uc_dir_amo_updt_sel_victim),
        .dir_amo_hit_way_i             (uc_dir_amo_hit_way),

        .data_amo_write_o              (uc_data_amo_write),
        .data_amo_write_enable_o       (uc_data_amo_write_enable),
        .data_amo_write_set_o          (uc_data_amo_write_set),
        .data_amo_write_size_o         (uc_data_amo_write_size),
        .data_amo_write_word_o         (uc_data_amo_write_word),
        .data_amo_write_data_o         (uc_data_amo_write_data),
        .data_amo_write_be_o           (uc_data_amo_write_be),

        .lrsc_snoop_i                  (uc_lrsc_snoop),
        .lrsc_snoop_addr_i             (uc_lrsc_snoop_addr),
        .lrsc_snoop_size_i             (uc_lrsc_snoop_size),

        .core_rsp_ready_i              (uc_core_rsp_ready),
        .core_rsp_valid_o              (uc_core_rsp_valid),
        .core_rsp_o                    (uc_core_rsp),

        .mem_read_id_i                 (HPDCACHE_UC_READ_ID),
        .mem_write_id_i                (HPDCACHE_UC_WRITE_ID),

        .mem_req_read_ready_i          (mem_req_read_uc_ready),
        .mem_req_read_valid_o          (mem_req_read_uc_valid),
        .mem_req_read_o                (mem_req_read_uc),

        .mem_resp_read_ready_o         (mem_resp_read_uc_ready),
        .mem_resp_read_valid_i         (mem_resp_read_uc_valid),
        .mem_resp_read_i               (mem_resp_read_uc),

        .mem_req_write_ready_i         (mem_req_write_uc_ready),
        .mem_req_write_valid_o         (mem_req_write_uc_valid),
        .mem_req_write_o               (mem_req_write_uc),

        .mem_req_write_data_ready_i    (mem_req_write_uc_data_ready),
        .mem_req_write_data_valid_o    (mem_req_write_uc_data_valid),
        .mem_req_write_data_o          (mem_req_write_uc_data),

        .mem_resp_write_ready_o        (mem_resp_write_uc_ready),
        .mem_resp_write_valid_i        (mem_resp_write_uc_valid),
        .mem_resp_write_i              (mem_resp_write_uc),

        .cfg_error_on_cacheable_amo_i
    );
    //  }}}

    //  CMO Request Handler
    //  {{{

    // Request arbiter & mux
    logic [nBanks-1:0]    cmo_arb_req_gnt;
    logic                 cmo_arb_req_valid;
    hpdcache_cmo_req_t    cmo_arb_req;

    hpdcache_fxarb #(.N(nBanks)) cmo_req_arbiter_i(
        .clk_i,
        .rst_ni,
        .req_i          (cmo_req_valid),
        .gnt_o          (cmo_arb_req_gnt),
        .ready_i        (cmo_ready)
    );

    assign cmo_arb_req_valid = |cmo_arb_req_gnt;

    hpdcache_mux #(
        .NINPUT         (nBanks),
        .DATA_WIDTH     ($bits(hpdcache_cmo_req_t)),
        .ONE_HOT_SEL    (1'b1)
    ) cmo_req_mux_i(
        .data_i         (cmo_req),
        .sel_i          (cmo_arb_req_gnt),
        .data_o         (cmo_arb_req)
    );

    // Directory interface mux & demux
    always_comb begin : dir_interface_mux_demux_comb
        cmo_dir_check_nline_hit_way = '0;
        cmo_dir_check_nline_dirty   = '0;
        cmo_dir_check_entry_valid   = '0;
        cmo_dir_check_entry_dirty   = '0;
        cmo_dir_check_entry_tag     = '0;

        for (int unsigned bank = 0; bank < nBanks; bank++) begin
            if (cmo_dir_bank_sel[bank]) begin
                cmo_dir_check_nline_bank[bank] = cmo_dir_check_nline;
                cmo_dir_check_entry_bank[bank] = cmo_dir_check_entry;
                cmo_dir_inval_bank[bank]       = cmo_dir_inval;

                cmo_dir_check_nline_hit_way |= cmo_dir_check_nline_hit_way_bank[bank];
                cmo_dir_check_nline_dirty   |= cmo_dir_check_nline_dirty_bank[bank];
                cmo_dir_check_entry_valid   |= cmo_dir_check_entry_valid_bank[bank];
                cmo_dir_check_entry_dirty   |= cmo_dir_check_entry_dirty_bank[bank];
                cmo_dir_check_entry_tag     |= cmo_dir_check_entry_tag_bank[bank];
            end else begin
                cmo_dir_check_nline_bank[bank] = 1'b0;
                cmo_dir_check_entry_bank[bank] = 1'b0;
                cmo_dir_inval_bank[bank]       = 1'b0;
            end
        end
    end

    hpdcache_cmo #(
        .HPDcacheCfg                     (HPDcacheCfg),

        .hpdcache_nline_t                (hpdcache_nline_t),
        .hpdcache_tag_t                  (hpdcache_tag_t),
        .hpdcache_set_t                  (hpdcache_set_t),
        .hpdcache_data_word_t            (hpdcache_data_word_t),
        .hpdcache_way_vector_t           (hpdcache_way_vector_t),

        .hpdcache_req_addr_t             (hpdcache_req_addr_t),
        .hpdcache_req_data_t             (hpdcache_req_data_t)
    ) hpdcache_cmo_i(
        .clk_i,
        .rst_ni,

        .wbuf_empty_i                  (wbuf_empty_o),
        .mshr_empty_i                  (mshr_empty),
        .refill_busy_i                 (|refill_busy),
        .rtab_empty_i                  (rtab_empty),
        .ctrl_empty_i                  (ctrl_empty),

        .req_valid_i                   (cmo_arb_req_valid),
        .req_ready_o                   (cmo_ready),
        .req_op_i                      (cmo_arb_req.op),
        .req_addr_i                    (cmo_arb_req.addr),
        .req_wdata_i                   (cmo_arb_req.wdata),
        .req_bank_src_i                (cmo_arb_req.bank),
        .req_wait_o                    (cmo_wait),

        .wbuf_flush_all_o              (cmo_wbuf_flush_all),

        .dir_check_nline_o             (cmo_dir_check_nline),
        .dir_check_nline_set_o         (cmo_dir_check_nline_set),
        .dir_check_nline_tag_o         (cmo_dir_check_nline_tag),
        .dir_check_nline_hit_way_i     (cmo_dir_check_nline_hit_way),
        .dir_check_nline_dirty_i       (cmo_dir_check_nline_dirty),

        .dir_check_entry_o             (cmo_dir_check_entry),
        .dir_check_entry_set_o         (cmo_dir_check_entry_set),
        .dir_check_entry_way_o         (cmo_dir_check_entry_way),
        .dir_check_entry_valid_i       (cmo_dir_check_entry_valid),
        .dir_check_entry_dirty_i       (cmo_dir_check_entry_dirty),
        .dir_check_entry_tag_i         (cmo_dir_check_entry_tag),

        .dir_inval_o                   (cmo_dir_inval),
        .dir_inval_set_o               (cmo_dir_inval_set),
        .dir_inval_way_o               (cmo_dir_inval_way),

        .dir_bank_sel_o                (cmo_dir_bank_sel),

        .flush_empty_i                 (flush_empty),
        .flush_alloc_o                 (flush_alloc[CMO_FLUSH_REQ_INDEX]),
        .flush_alloc_ready_i           (flush_alloc_ready_requester[CMO_FLUSH_REQ_INDEX]),
        .flush_alloc_nline_o           (flush_req[CMO_FLUSH_REQ_INDEX].nline),
        .flush_alloc_way_o             (flush_req[CMO_FLUSH_REQ_INDEX].way)
    );

    hpdcache_1hot_to_binary #(.N(nBanks)) cmo_bank_vec_to_id_i (
        .val_i(cmo_dir_bank_sel),
        .val_o(flush_req[CMO_FLUSH_REQ_INDEX].bank_id)
    );

    assign cmo_busy = ~cmo_ready | |cmo_req_valid;
    //  }}}

    //  Flush controller
    //  {{{
    if (HPDcacheCfg.u.wbEn) begin : gen_flush
        // Request arbiter & mux of the individual banks and the CMO
        logic [FLUSH_MODULE_NREQUESTERS-1:0] flush_arb_req_gnt;
        logic                                flush_arb_req_valid;
        hpdcache_flush_req_t                 flush_arb_req;
        hpdcache_bank_id_t                   flush_rsp_bank_id;

        hpdcache_fxarb #(.N(FLUSH_MODULE_NREQUESTERS)) flush_req_arbiter_i(
            .clk_i,
            .rst_ni,
            .req_i          (flush_alloc),
            .gnt_o          (flush_arb_req_gnt),
            .ready_i        (flush_alloc_ready)
        );

        assign flush_arb_req_valid = |flush_arb_req_gnt;
        assign flush_alloc_ready_requester = flush_arb_req_gnt & {FLUSH_MODULE_NREQUESTERS{flush_alloc_ready}};

        hpdcache_mux #(
            .NINPUT         (FLUSH_MODULE_NREQUESTERS),
            .DATA_WIDTH     ($bits(hpdcache_flush_req_t)),
            .ONE_HOT_SEL    (1'b1)
        ) flush_req_mux_i(
            .data_i         (flush_req),
            .sel_i          (flush_arb_req_gnt),
            .data_o         (flush_arb_req)
        );

        always_comb begin : flush_data_mux_demux_comb
            flush_data_read_data = '0;

            for (int unsigned bank = 0; bank < nBanks; bank++) begin
                if (bank == flush_rsp_bank_id) begin
                    flush_data_read_bank[bank] = flush_data_read;
                    flush_data_read_data = flush_data_read_data_bank[bank];
                end else begin
                    flush_data_read_bank[bank] = 1'b0;
                end
            end
        end

        hpdcache_flush #(
            .HPDcacheCfg                   (HPDcacheCfg),

            .hpdcache_nline_t              (hpdcache_nline_t),
            .hpdcache_set_t                (hpdcache_set_t),
            .hpdcache_word_t               (hpdcache_word_t),
            .hpdcache_way_vector_t         (hpdcache_way_vector_t),
            .hpdcache_access_data_t        (hpdcache_access_data_t),

            .hpdcache_mem_id_t             (hpdcache_mem_id_t),
            .hpdcache_mem_data_t           (hpdcache_mem_data_t),
            .hpdcache_mem_req_t            (hpdcache_mem_req_t),
            .hpdcache_mem_req_w_t          (hpdcache_mem_req_w_t),
            .hpdcache_mem_resp_w_t         (hpdcache_mem_resp_w_t)
        ) flush_i(
            .clk_i,
            .rst_ni,

            .flush_empty_o                 (flush_empty),
            .flush_full_o                  (/* open */),
            .flush_busy_o                  (flush_busy),

            .flush_check_nline_i           (flush_check_nline),
            .flush_check_hit_o             (flush_check_hit),

            .flush_alloc_i                 (flush_arb_req_valid),
            .flush_alloc_ready_o           (flush_alloc_ready),
            .flush_alloc_nline_i           (flush_arb_req.nline),
            .flush_alloc_way_i             (flush_arb_req.way),
            .flush_alloc_bank_id_i         (flush_arb_req.bank_id),

            .flush_data_read_o             (flush_data_read),
            .flush_data_read_bank_id_o     (flush_rsp_bank_id),
            .flush_data_read_set_o         (flush_data_read_set),
            .flush_data_read_word_o        (flush_data_read_word),
            .flush_data_read_way_o         (flush_data_read_way),
            .flush_data_read_data_i        (flush_data_read_data),

            .flush_ack_o                   (flush_ack),
            .flush_ack_nline_o             (flush_ack_nline),

            .mem_req_write_ready_i         (mem_req_write_flush_ready),
            .mem_req_write_valid_o         (mem_req_write_flush_valid),
            .mem_req_write_o               (mem_req_write_flush),

            .mem_req_write_data_ready_i    (mem_req_write_flush_data_ready),
            .mem_req_write_data_valid_o    (mem_req_write_flush_data_valid),
            .mem_req_write_data_o          (mem_req_write_flush_data),

            .mem_resp_write_ready_o        (mem_resp_write_flush_ready),
            .mem_resp_write_valid_i        (mem_resp_write_flush_valid),
            .mem_resp_write_i              (mem_resp_write_flush)
        );
    end else begin : gen_no_flush
        //  The flush controller behaves as a black-hole: consumes but do not produce data
        assign flush_empty                     = 1'b1;
        assign flush_busy                      = 1'b0;
        assign flush_check_hit                 = '{default: '0};
        assign flush_alloc_ready               = 1'b1;
        assign flush_data_read                 = 1'b0;
        assign flush_data_read_set             = '0;
        assign flush_data_read_word            = '0;
        assign flush_data_read_way             = '0;
        assign flush_ack                       = 1'b0;
        assign flush_ack_nline                 = '0;
        assign mem_req_write_flush_valid       = 1'b0;
        assign mem_req_write_flush             = '{
            mem_req_command: HPDCACHE_MEM_READ,
            mem_req_atomic : HPDCACHE_MEM_ATOMIC_ADD,
            default        : '0
        };
        assign mem_req_write_flush_data_valid  = 1'b0;
        assign mem_req_write_flush_data        = '0;
        assign mem_resp_write_flush_ready      = 1'b1;
    end
    //  }}}

    //  Read and Write Arbiters for Memory interfaces
    //  {{{

    //      Read request interface
    //
    //      There is a fixed-priority arbiter between:
    //      - the miss_handler (higher priority);
    //      - the uncacheable request handler (lower priority)
    logic              [1:0] arb_mem_req_read_ready;
    logic              [1:0] arb_mem_req_read_valid;
    hpdcache_mem_req_t [1:0] arb_mem_req_read;

    assign mem_req_read_miss_ready = arb_mem_req_read_ready[0];
    assign arb_mem_req_read_valid[0] = mem_req_read_miss_valid;
    assign arb_mem_req_read[0] = mem_req_read_miss;

    assign mem_req_read_uc_ready = arb_mem_req_read_ready[1];
    assign arb_mem_req_read_valid[1] = mem_req_read_uc_valid;
    assign arb_mem_req_read[1] = mem_req_read_uc;

    hpdcache_mem_req_read_arbiter #(
        .N                     (2),
        .hpdcache_mem_req_t    (hpdcache_mem_req_t)
    ) hpdcache_mem_req_read_arbiter_i(
        .clk_i,
        .rst_ni,

        .mem_req_read_ready_o  (arb_mem_req_read_ready),
        .mem_req_read_valid_i  (arb_mem_req_read_valid),
        .mem_req_read_i        (arb_mem_req_read),

        .mem_req_read_ready_i,
        .mem_req_read_valid_o,
        .mem_req_read_o        (mem_req_read_o)
    );

    //      Read response interface
    always_comb
    begin : mem_resp_read_demux_comb
        mem_resp_read_uc_valid = 1'b0;
        mem_resp_read_miss_valid = 1'b0;
        mem_resp_read_ready_o = 1'b0;
        if (mem_resp_read_valid_i) begin
            if (mem_resp_read_i.mem_resp_r_id == {HPDcacheCfg.u.memIdWidth{1'b1}}) begin
                mem_resp_read_uc_valid = 1'b1;
                mem_resp_read_ready_o = mem_resp_read_uc_ready;
            end else begin
                mem_resp_read_miss_valid = 1'b1;
                mem_resp_read_ready_o = mem_resp_read_miss_ready;
            end
        end
    end

    assign mem_resp_read_uc               = mem_resp_read_i;
    assign mem_resp_read_miss             = mem_resp_read_i;
`ifdef HPDCACHE_OPENPITON
    assign mem_resp_read_miss_inval       = mem_resp_read_inval_i;
    assign mem_resp_read_miss_inval_nline = mem_resp_read_inval_nline_i;
`else
    assign mem_resp_read_miss_inval       = 1'b0;
    assign mem_resp_read_miss_inval_nline = '0;
`endif

    //      Write request interface
    //
    //      There is a fixed-priority arbiter between:
    //      - the write buffer (higher priority)
    //      - the flush controller
    //      - the uncacheable request handler (lower priori

    localparam int unsigned writeArbNRequesters = nBanks + 2;

    localparam int unsigned flushCtrlWriteArbId = nBanks;
    localparam int unsigned uncacheableWriteArbId = nBanks + 1;

    logic                [writeArbNRequesters-1:0] arb_mem_req_write_ready;
    logic                [writeArbNRequesters-1:0] arb_mem_req_write_valid;
    hpdcache_mem_req_t   [writeArbNRequesters-1:0] arb_mem_req_write;

    logic                [writeArbNRequesters-1:0] arb_mem_req_write_data_valid;
    logic                [writeArbNRequesters-1:0] arb_mem_req_write_data_ready;
    hpdcache_mem_req_w_t [writeArbNRequesters-1:0] arb_mem_req_write_data;

    //      Split the ID space into 3 segments:
    //      1111...1111  -> Uncached writes
    //      1xxx...xxxx  -> Flush writes (where at least one x is 0)
    //      0bbx...xxxx  -> Write buffer writes (where b is the bank id)
    function automatic hpdcache_mem_req_t hpdcache_req_write_sel_id(
        hpdcache_mem_req_t req, int unsigned bank, int kind
    );
        //  Request from the write buffer
        unique if (kind == 0) begin
            if (nBanks > 1) begin
                req.mem_req_id = {1'b0, bank[BankIdWidth-1:0], req.mem_req_id[0 +: HPDcacheCfg.u.memIdWidth-BankIdWidth-1]};
            end else begin
                req.mem_req_id = {1'b0, req.mem_req_id[0 +: HPDcacheCfg.u.memIdWidth-1]};
            end
        end
        //  Request from the flush controller
        else if (kind == 1) begin
            req.mem_req_id = {1'b1, req.mem_req_id[0 +: HPDcacheCfg.u.memIdWidth-1]};
        end
        //  Request from the uncached controller
        else if (kind == 2) begin
            req.mem_req_id = '1;
        end
        return req;
    endfunction

    function automatic hpdcache_mem_resp_w_t hpdcache_resp_write_sel_id(
        hpdcache_mem_resp_w_t resp, int kind
    );
        //  Response to the write buffer
        unique if (kind == 0) begin
            if (nBanks > 1) begin
                resp.mem_resp_w_id = {1'b0, {BankIdWidth{1'b0}}, resp.mem_resp_w_id[0 +: HPDcacheCfg.u.memIdWidth-BankIdWidth-1]};
            end else begin
                resp.mem_resp_w_id = {1'b0, resp.mem_resp_w_id[0 +: HPDcacheCfg.u.memIdWidth-1]};
            end
        end
        //  Response to the flush controller
        else if (kind == 1) begin
            resp.mem_resp_w_id = {1'b0, resp.mem_resp_w_id[0 +: HPDcacheCfg.u.memIdWidth-1]};
        end
        //  Response to the uncached controller
        else if (kind == 2) begin
            resp.mem_resp_w_id = '1;
        end
        return resp;
    endfunction

    generate
        genvar wArbBankId;
        for (wArbBankId = 0; wArbBankId < nBanks; wArbBankId++) begin: gen_write_arb_intf
            assign mem_req_write_wbuf_ready[wArbBankId]      = arb_mem_req_write_ready[wArbBankId];
            assign arb_mem_req_write_valid[wArbBankId]       = mem_req_write_wbuf_valid[wArbBankId];
            assign arb_mem_req_write[wArbBankId]             = hpdcache_req_write_sel_id(mem_req_write_wbuf[wArbBankId], wArbBankId, 0);

            assign mem_req_write_wbuf_data_ready[wArbBankId] = arb_mem_req_write_data_ready[wArbBankId];
            assign arb_mem_req_write_data_valid[wArbBankId]  = mem_req_write_wbuf_data_valid[wArbBankId];
            assign arb_mem_req_write_data[wArbBankId]        = mem_req_write_wbuf_data[wArbBankId];
        end
    endgenerate

    assign mem_req_write_flush_ready                           = arb_mem_req_write_ready[flushCtrlWriteArbId];
    assign arb_mem_req_write_valid[flushCtrlWriteArbId]        = mem_req_write_flush_valid;
    assign arb_mem_req_write[flushCtrlWriteArbId]              = hpdcache_req_write_sel_id(mem_req_write_flush, 0, 1);

    assign mem_req_write_flush_data_ready                      = arb_mem_req_write_data_ready[flushCtrlWriteArbId];
    assign arb_mem_req_write_data_valid[flushCtrlWriteArbId]   = mem_req_write_flush_data_valid;
    assign arb_mem_req_write_data[flushCtrlWriteArbId]         = mem_req_write_flush_data;

    assign mem_req_write_uc_ready                              = arb_mem_req_write_ready[uncacheableWriteArbId];
    assign arb_mem_req_write_valid[uncacheableWriteArbId]      = mem_req_write_uc_valid;
    assign arb_mem_req_write[uncacheableWriteArbId]            = hpdcache_req_write_sel_id(mem_req_write_uc, 0, 2);

    assign mem_req_write_uc_data_ready                         = arb_mem_req_write_data_ready[uncacheableWriteArbId];
    assign arb_mem_req_write_data_valid[uncacheableWriteArbId] = mem_req_write_uc_data_valid;
    assign arb_mem_req_write_data[uncacheableWriteArbId]       = mem_req_write_uc_data;

    hpdcache_mem_req_write_arbiter #(
        .N                             (writeArbNRequesters), // 1 write buffer * nBanks + flush controller + uncacheables
        .hpdcache_mem_req_t            (hpdcache_mem_req_t),
        .hpdcache_mem_req_w_t          (hpdcache_mem_req_w_t)
    ) hpdcache_mem_req_write_arbiter_i (
        .clk_i,
        .rst_ni,

        .mem_req_write_ready_o         (arb_mem_req_write_ready),
        .mem_req_write_valid_i         (arb_mem_req_write_valid),
        .mem_req_write_i               (arb_mem_req_write),

        .mem_req_write_data_ready_o    (arb_mem_req_write_data_ready),
        .mem_req_write_data_valid_i    (arb_mem_req_write_data_valid),
        .mem_req_write_data_i          (arb_mem_req_write_data),

        .mem_req_write_ready_i,
        .mem_req_write_valid_o,
        .mem_req_write_o               (mem_req_write_o),

        .mem_req_write_data_ready_i,
        .mem_req_write_data_valid_o,
        .mem_req_write_data_o          (mem_req_write_data_o)
    );

    //      Write response interface
    always_comb
    begin : mem_resp_write_demux_comb
        automatic int b;

        for (int bank = 0; bank < nBanks; bank++) begin
            mem_resp_write_wbuf_valid[bank] = 1'b0;
        end
        mem_resp_write_flush_valid = 1'b0;
        mem_resp_write_uc_valid = 1'b0;
        mem_resp_write_ready_o = 1'b0;

        if (nBanks > 1) begin
            b = int'(mem_resp_write_i.mem_resp_w_id[HPDcacheCfg.u.memIdWidth-2 -: BankIdWidth]);
        end else begin
            b = 0;
        end

        if (mem_resp_write_valid_i) begin
            if (mem_resp_write_i.mem_resp_w_id == {HPDcacheCfg.u.memIdWidth{1'b1}}) begin
                mem_resp_write_uc_valid = 1'b1;
                mem_resp_write_ready_o = mem_resp_write_uc_ready;
            end else if (mem_resp_write_i.mem_resp_w_id[HPDcacheCfg.u.memIdWidth-1]) begin
                mem_resp_write_flush_valid = 1'b1;
                mem_resp_write_ready_o = mem_resp_write_flush_ready;
            end else begin
                mem_resp_write_wbuf_valid[b] = 1'b1;
                mem_resp_write_ready_o = mem_resp_write_wbuf_ready[b];
            end
        end
    end

    generate
        genvar wbufRespBankId;
        for (wbufRespBankId = 0; wbufRespBankId < nBanks; wbufRespBankId++) begin: gen_wbuf_resp
            assign mem_resp_write_wbuf[wbufRespBankId] = hpdcache_resp_write_sel_id(mem_resp_write_i, 0);
        end
    endgenerate

    assign mem_resp_write_flush = hpdcache_resp_write_sel_id(mem_resp_write_i, 1);
    assign mem_resp_write_uc = hpdcache_resp_write_sel_id(mem_resp_write_i, 2);
    //  }}}

    //  Assertions
    //  {{{
`ifndef HPDCACHE_ASSERT_OFF
    initial begin
        word_width_assert:
            assert (HPDcacheCfg.u.wordWidth inside {32, 64}) else
                $fatal("word width shall be 32 or 64");
        req_access_width_assert:
            assert (HPDcacheCfg.u.reqWords <= HPDcacheCfg.u.accessWords) else
                $fatal("req data width shall be l.e. to cache access width");
        refill_access_width_assert:
            assert (HPDcacheCfg.u.clWords >= HPDcacheCfg.u.accessWords) else
                $fatal("cache access width shall be l.e. to cache-line width");
        cl_words_assert:
            assert (HPDcacheCfg.u.clWords > 1) else
                $fatal("cacheline words shall be greater than 1");
        mem_width_assert:
            assert (HPDcacheCfg.u.memDataWidth >= HPDcacheCfg.reqDataWidth) else
                $fatal("memory interface data width shall be g.e. to req data width");
        miss_mem_id_width_assert:
            assert (HPDcacheCfg.u.memIdWidth >=
                ($clog2(HPDcacheCfg.u.mshrWays * HPDcacheCfg.u.mshrSets) + 1)) else
                $fatal("insufficient ID bits on the mem interface to transport misses");
        wbuf_mem_id_width_assert:
            assert (HPDcacheCfg.u.memIdWidth >= (HPDcacheCfg.wbufDirPtrWidth + $clog2(nBanks) + 1)) else
                $fatal("insufficient ID bits on the mem interface to transport writes");
        //wt_or_wb_assert:
        //    assert (HPDcacheCfg.u.wtEn || HPDcacheCfg.u.wbEn) else
        //        $fatal("the cache shall be configured to support WT, WB or both");
    end
`endif
    // }}}

endmodule
