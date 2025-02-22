//   ==================================================================
//   >>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
//   ------------------------------------------------------------------
//   Copyright (c) 2006-2011 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED 
//   ------------------------------------------------------------------
//
//   IMPORTANT: THIS FILE IS AUTO-GENERATED BY THE LATTICEMICO SYSTEM.
//
//   Permission:
//
//      Lattice Semiconductor grants permission to use this code
//      pursuant to the terms of the Lattice Semiconductor Corporation
//      Open Source License Agreement.  
//
//   Disclaimer:
//
//      Lattice Semiconductor provides no warranty regarding the use or
//      functionality of this code. It is the user's responsibility to
//      verify the user�s design for consistency and functionality through
//      the use of formal verification methods.
//
//   --------------------------------------------------------------------
//
//                  Lattice Semiconductor Corporation
//                  5555 NE Moore Court
//                  Hillsboro, OR 97214
//                  U.S.A
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                         503-286-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
//   --------------------------------------------------------------------
//                         FILE DETAILS
// Project          : SPI Flash Controller
// File             : spi_flash.v
// Title            : Toplevel module of SPI Flash Controller.
// Version          : 3.0
//                  : Initial Version (replaces deprecated SPI Flash ROM v3.1)
// Version          : 3.2
//                  : Support for 8-bit WISHBONE Data Bus (to design systems
//                  : for LM8).
// =============================================================================
module spi_flash
   #(parameter LATTICE_FAMILY    = "ECP2",
     parameter S_WB_ADR_WIDTH    = 32,
     parameter S_WB_DAT_WIDTH    = 32,
     parameter C_PORT_ENABLE     = 0,
     parameter C_WB_ADR_WIDTH    = 11,
     parameter C_WB_DAT_WIDTH    = 32,
     parameter PAGE_PRG_BUF_ENA  = 0,
     parameter PAGE_READ_BUF_ENA = 0,
	 parameter PAGE_PRG_BUFFER_EBR = 0,
	 parameter PAGE_PRG_BUFFER_DISTRIBUTED_RAM = 1,
	 parameter PAGE_READ_BUFFER_EBR = 0,
	 parameter PAGE_READ_BUFFER_DISTRIBUTED_RAM = 1,
     parameter SECTOR_SIZE       = 32768,
     parameter PAGE_SIZE         = 256,
     parameter CLOCK_SEL         = 1,
     parameter SPI_READ          = 8'h03,
     parameter SPI_FAST_READ     = 8'h0b,
     parameter SPI_BYTE_PRG      = 8'h02,
     parameter SPI_PAGE_PRG      = 8'h02,
     parameter SPI_BLK1_ERS      = 8'h20,
     parameter SPI_BLK2_ERS      = 8'h52,
     parameter SPI_BLK3_ERS      = 8'hd8,
     parameter SPI_CHIP_ERS      = 8'h60,
     parameter SPI_WRT_ENB       = 8'h06,
     parameter SPI_WRT_DISB      = 8'h04,
     parameter SPI_READ_STAT     = 8'h05,
     parameter SPI_WRT_STAT      = 8'h01,
     parameter SPI_PWD_DOWN      = 8'hb9,
     parameter SPI_PWD_UP        = 8'hab,
     parameter SPI_DEV_ID        = 8'h9f)
   (
    // wishbone PORT A signals
    input [S_WB_ADR_WIDTH-1:0] S_ADR_I,
    input [S_WB_DAT_WIDTH-1:0] S_DAT_I,
    input S_WE_I,
    input S_STB_I,
    input S_CYC_I,
    input [S_WB_DAT_WIDTH/8-1:0] S_SEL_I,
    input [2:0] S_CTI_I,
    input [1:0] S_BTE_I,
    input  S_LOCK_I,
    output [S_WB_DAT_WIDTH-1:0] S_DAT_O,
    output S_ACK_O,
    output S_ERR_O,
    output S_RTY_O,
    
    // wishbone PORT B signals
    input [C_WB_ADR_WIDTH-1:0] C_ADR_I,
    input [C_WB_DAT_WIDTH-1:0] C_DAT_I,
    input C_WE_I,
    input C_STB_I,
    input C_CYC_I,
    input [C_WB_DAT_WIDTH/8-1:0] C_SEL_I,
    input [2:0] C_CTI_I,
    input [1:0] C_BTE_I,
    input C_LOCK_I,
    output [C_WB_DAT_WIDTH-1:0] C_DAT_O,
    output C_ACK_O,
    output C_ERR_O,
    output C_RTY_O,
    
    // SPI flash signals
    output SI, // Serial data from FPGA to SPI flash
    input SO, // Serial data from SPI flash to FPGA
    output CEJ, // SPI flash chip select
    output SCK, // Serial clock to SPI flash
    output WPJ, // Write protect
    
    // system signals
    input CLK_I,
    input RST_I
    );
   
   function integer clogb2;
      input [31:0] value;
      begin
	 for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1)
           value = value >> 1;
      end
   endfunction

   parameter WB_DAT_WIDTH = (S_WB_DAT_WIDTH == 32) ? 32 : (C_WB_DAT_WIDTH == 32) ? 32 : 8;
   parameter BUF_SIZE     = (C_WB_DAT_WIDTH == 8) ? PAGE_SIZE : PAGE_SIZE>>2;
   parameter PAGE_WIDTH   = ((PAGE_PRG_BUF_ENA == 1) || (PAGE_READ_BUF_ENA == 1)) ? clogb2(PAGE_SIZE) - 1 : 2;
   parameter BUF_WIDTH    = ((PAGE_PRG_BUF_ENA == 1) || (PAGE_READ_BUF_ENA == 1)) ? ((C_WB_DAT_WIDTH == 8) ? PAGE_WIDTH : PAGE_WIDTH - 2) : 0;
   
   wire                   spi_clk;        // spi flash clock
   reg                    clk_div;        // clock divided by CLOCK_SEL
   wire [3:0] 		  div_num;        // clock divide number
   reg [3:0] 		  clk_cnt;        // clock number counter
   // page program buffer signals
   wire [C_WB_DAT_WIDTH-1:0] wb2spi_data;     // write port data
   wire [BUF_WIDTH-1:0]      wb2spi_wr_addr;  // write port address
   wire  		     wb2spi_we;       // write enable
   wire [BUF_WIDTH-1:0]      wb2spi_rd_addr;  // read port address
   wire [C_WB_DAT_WIDTH-1:0] wb2spi_q;        // read port data
   // page read buffer signals
   wire [BUF_WIDTH-1:0]      spi2wb_wr_addr;  // write port address
   wire [C_WB_DAT_WIDTH-1:0] spi2wb_data;     // write port data
   wire 		     spi2wb_we;       // write enable
   wire [BUF_WIDTH-1:0]      spi2wb_rd_addr;  // read port address
   wire [C_WB_DAT_WIDTH-1:0] spi2wb_q;        // read port data
   
   // command from wishbone to SPI flash signals
   wire [31:0] 		     spi_cmd;         // command and address send to spi flash
   wire [31:0] 		     spi_cmd_ext;     // extended high 4 bytes of command address send to spi flash
   // only used for arbitrary command
   wire [3:0] 		     cmd_bytes;       // command and address byte numbers send to spi flash
   wire [PAGE_WIDTH:0] 	     byte_length;     // data bytes after address command
   wire 		     page_cmd;        // page program or page read command
   wire 		     wr_enb;          // precede a write enable command
   wire [WB_DAT_WIDTH-1:0]   read_data;       // return data from spi flash
   wire [WB_DAT_WIDTH-1:0]   write_data;      // data write to spi flash
   wire [7:0] 		     spi_wrt_enb;     // spi write enable command byte
   wire [7:0] 		     spi_read_stat;   // spi read status register command byte
   wire 		     fast_read;       // read command is fast read
   wire 		     spi_wr;          // asserted when spi write command
   wire 		     spi_req;         // request a spi command, deasserted when detect a positive edge on spi_ack
   wire 		     spi_ack;         // acknowledge a spi command, deasserted when the transaction is finished
   
   assign div_num = fast_read ? CLOCK_SEL>>1 : CLOCK_SEL;
   assign spi_clk = div_num > 0 ? clk_div : CLK_I;
   
   always @(posedge CLK_I or posedge RST_I)
     if(RST_I) begin
	clk_cnt <= 4'h0;
	clk_div <= 0;
     end
     else if(clk_cnt == div_num - 1) begin
	clk_div <= ~clk_div;
	clk_cnt <= 4'h0;
     end else
       clk_cnt <= clk_cnt + 1;
   
   // ====================================================================
   // Instiantiate page program buffer and page read buffer
   // ====================================================================
   generate
      if (PAGE_PRG_BUF_ENA == 1) begin
	    if (PAGE_PRG_BUFFER_DISTRIBUTED_RAM == 1) begin
	 // Page Program Buffer
	 pmi_distributed_dpram 
	   #(
	     .pmi_addr_depth      (BUF_SIZE               ),       // 64,
	     .pmi_addr_width      (BUF_WIDTH              ),       // 6,
	     .pmi_data_width      (C_WB_DAT_WIDTH         ),       // 32,
	     .pmi_regmode         ("noreg"                ),       // "reg",
	     .pmi_init_file       ("none"                 ),       // "none",
	     .pmi_init_file_format("binary"               ),       // "binary",
	     .pmi_family          (LATTICE_FAMILY         ),       // "EC",
	     .module_type         ("pmi_distributed_dpram"))       // "pmi_distributed_dpram")
	 page_prg_buf_inst
	   (
	    .WrAddress    (wb2spi_wr_addr ),
	    .Data         (wb2spi_data    ),
	    .WrClock      (CLK_I          ),
	    .WE           (wb2spi_we      ),
	    .WrClockEn    (1'b1           ),
	    .RdAddress    (wb2spi_rd_addr ),
	    .RdClock      (spi_clk        ),
	    .RdClockEn    (1'b1           ),
	    .Reset        (RST_I          ),
	    .Q            (wb2spi_q       ));
        end
		else if( PAGE_PRG_BUFFER_EBR == 1) begin
	 // Page Program Buffer
	 pmi_ram_dp 
	   #(
		     .pmi_wr_addr_depth   (BUF_SIZE         ),       // 64,
		     .pmi_wr_addr_width   (BUF_WIDTH        ),       // 6,
		     .pmi_wr_data_width   (C_WB_DAT_WIDTH   ),       // 32,
		     .pmi_rd_addr_depth   (BUF_SIZE         ),       // 64,
		     .pmi_rd_addr_width   (BUF_WIDTH        ),       // 6,
		     .pmi_rd_data_width   (C_WB_DAT_WIDTH   ),       // 32,
		     .pmi_regmode         ("noreg"          ),       // "reg",
		     .pmi_gsr             ("enable"         ), 
		     .pmi_resetmode       ("sync"           ),
		     .pmi_init_file       ("none"           ),       // "none",
		     .pmi_init_file_format("binary"         ),       // "binary",
		     .pmi_family          (LATTICE_FAMILY   ),       // "EC",
		     .module_type         ("pmi_ram_dp"     ))       // "pmi_ram_dp" 
		page_prg_buf_inst
		  (
		   // ----- Inputs -----
		   .Data         (wb2spi_data    ),
		   .WrAddress    (wb2spi_wr_addr ),
		   .RdAddress    (wb2spi_rd_addr ),
		   .WrClock      (CLK_I          ),
		   .RdClock      (spi_clk        ),
		   .WrClockEn    (1'b1           ),
		   .RdClockEn    (1'b1           ),
		   .WE           (wb2spi_we      ),
		   .Reset        (RST_I          ),
		   // ----- Outputs -----
		   .Q            (wb2spi_q       ));
        end
	  end
      else
	assign wb2spi_q = 0;
      
   endgenerate

   generate
      if (PAGE_READ_BUF_ENA == 1 ) begin
		if( PAGE_READ_BUFFER_DISTRIBUTED_RAM == 1) begin
	 // Page Read Buffer
	 pmi_distributed_dpram 
	   #(
	     .pmi_addr_depth      (BUF_SIZE               ),       // 64,
	     .pmi_addr_width      (BUF_WIDTH              ),       // 6,
	     .pmi_data_width      (C_WB_DAT_WIDTH         ),       // 32,
	     .pmi_regmode         ("noreg"                ),       // "reg",
	     .pmi_init_file       ("none"                 ),       // "none",
	     .pmi_init_file_format("binary"               ),       // "binary",
	     .pmi_family          (LATTICE_FAMILY         ),       // "EC",
	     .module_type         ("pmi_distributed_dpram"))       // "pmi_distributed_dpram")
	 page_read_buf_inst 
	   (
	    .WrAddress    (spi2wb_wr_addr),
	    .Data         (spi2wb_data   ),
	    .WrClock      (spi_clk       ),
	    .WE           (spi2wb_we     ),
	    .WrClockEn    (1'b1          ),
	    .RdAddress    (spi2wb_rd_addr),
	    .RdClock      (CLK_I         ),
	    .RdClockEn    (1'b1          ),
	    .Reset        (RST_I         ),
	    .Q            (spi2wb_q      ));
		end
	  end
   endgenerate
   
   generate
      if (PAGE_READ_BUF_ENA == 1) begin
	    if( PAGE_READ_BUFFER_EBR == 1) begin
	 // Page Read Buffer
	 pmi_ram_dp 
	   #(
		     .pmi_wr_addr_depth   (BUF_SIZE         ),       // 64,
		     .pmi_wr_addr_width   (BUF_WIDTH        ),       // 6,
		     .pmi_wr_data_width   (C_WB_DAT_WIDTH   ),       // 32,
		     .pmi_rd_addr_depth   (BUF_SIZE         ),       // 64,
		     .pmi_rd_addr_width   (BUF_WIDTH        ),       // 6,
		     .pmi_rd_data_width   (C_WB_DAT_WIDTH   ),       // 32,
		     .pmi_regmode         ("noreg"          ),       // "reg",
		     .pmi_gsr             ("enable"         ), 
		     .pmi_resetmode       ("sync"           ),
		     .pmi_init_file       ("none"           ),       // "none",
		     .pmi_init_file_format("binary"         ),       // "binary",
		     .pmi_family          (LATTICE_FAMILY   ),       // "EC",
		     .module_type         ("pmi_ram_dp"     ))       // "pmi_ram_dp" 
	 page_read_buf_inst
		  (
		   // ----- Inputs -----
		   .Data         (spi2wb_data    ),
		   .WrAddress    (spi2wb_wr_addr ),
		   .RdAddress    (spi2wb_rd_addr ),
		   .WrClock      (spi_clk        ),
		   .RdClock      (CLK_I          ),
		   .WrClockEn    (1'b1           ),
		   .RdClockEn    (1'b1           ),
		   .WE           (spi2wb_we      ),
		   .Reset        (RST_I          ),
		   // ----- Outputs -----
		   .Q            (spi2wb_q       ));
		end
      end
   endgenerate
   // ====================================================================
   // Instiantiate WISHBONE bus for Control Port
   // ====================================================================
   wire [C_WB_DAT_WIDTH/8-1:0] INT_SEL_I;
   wire [C_WB_ADR_WIDTH-1:0]   INT_ADR_I;
   wire [C_WB_DAT_WIDTH-1:0]   INT_DAT_I, INT_DAT_O;
   wire [2:0] 		       INT_CTI_I;
   wire [1:0] 		       INT_BTE_I;
   wire 		       INT_CYC_I, INT_STB_I, INT_WE_I;
   wire 		       INT_ACK_O, INT_ERR_O, INT_RTY_O;
   
   generate
      if (C_PORT_ENABLE == 1) begin
	 assign INT_ADR_I = C_ADR_I;
	 assign INT_DAT_I = C_DAT_I;
	 assign INT_WE_I  = C_WE_I;
	 assign INT_STB_I = C_STB_I;
	 assign INT_CYC_I = C_CYC_I;
	 assign INT_SEL_I = C_SEL_I;
	 assign INT_CTI_I = C_CTI_I;
	 assign INT_BTE_I = C_BTE_I;
	 assign C_DAT_O   = INT_DAT_O;
	 assign C_ACK_O   = INT_ACK_O;
	 assign C_ERR_O   = INT_ERR_O;
	 assign C_RTY_O   = INT_RTY_O;
      end
      else begin
	 assign INT_ADR_I = 0;
	 assign INT_DAT_I = 0;
	 assign INT_WE_I  = 0;
	 assign INT_STB_I = 0;
	 assign INT_CYC_I = 0;
	 assign INT_SEL_I = 0;
	 assign INT_CTI_I = 0;
	 assign INT_BTE_I = 0;
	 assign C_DAT_O   = 0;
	 assign C_ACK_O   = 0;
	 assign C_ERR_O   = 0;
	 assign C_RTY_O   = 0;
      end
   endgenerate
   
   // ====================================================================
   // Instantiate wishbone interface module
   // ====================================================================
   wb_intf 
     #(.S_WB_ADR_WIDTH    (S_WB_ADR_WIDTH   ),
       .S_WB_DAT_WIDTH    (S_WB_DAT_WIDTH   ),
       .C_PORT_ENABLE     (C_PORT_ENABLE    ),
       .C_WB_ADR_WIDTH    (C_WB_ADR_WIDTH   ),
       .C_WB_DAT_WIDTH    (C_WB_DAT_WIDTH   ),
       .WB_DAT_WIDTH      (WB_DAT_WIDTH     ),
       .PAGE_PRG_BUF_ENA  (PAGE_PRG_BUF_ENA ),
       .PAGE_READ_BUF_ENA (PAGE_READ_BUF_ENA),
       .BUF_WIDTH         (BUF_WIDTH        ),
       .PAGE_WIDTH        (PAGE_WIDTH       ),
       .SPI_READ          (SPI_READ         ),
       .SPI_FAST_READ     (SPI_FAST_READ    ),
       .SPI_BYTE_PRG      (SPI_BYTE_PRG     ),
       .SPI_PAGE_PRG      (SPI_PAGE_PRG     ),
       .SPI_BLK1_ERS      (SPI_BLK1_ERS     ),
       .SPI_BLK2_ERS      (SPI_BLK2_ERS     ),
       .SPI_BLK3_ERS      (SPI_BLK3_ERS     ),
       .SPI_CHIP_ERS      (SPI_CHIP_ERS     ),
       .SPI_WRT_ENB       (SPI_WRT_ENB      ),
       .SPI_WRT_DISB      (SPI_WRT_DISB     ),
       .SPI_READ_STAT     (SPI_READ_STAT    ),
       .SPI_WRT_STAT      (SPI_WRT_STAT     ),
       .SPI_PWD_DOWN      (SPI_PWD_DOWN     ),
       .SPI_PWD_UP        (SPI_PWD_UP       ),
       .SPI_DEV_ID        (SPI_DEV_ID       ))
   wb_intf_inst
     (
      // wishbone PORT A signals
      .S_ADR_I       (S_ADR_I       ),
      .S_DAT_I       (S_DAT_I       ),
      .S_WE_I        (S_WE_I        ),
      .S_STB_I       (S_STB_I       ),
      .S_CYC_I       (S_CYC_I       ),
      .S_SEL_I       (S_SEL_I       ),
      .S_CTI_I       (S_CTI_I       ),
      .S_BTE_I       (S_BTE_I       ),
      .S_DAT_O       (S_DAT_O       ),
      .S_ACK_O       (S_ACK_O       ),
      .S_ERR_O       (S_ERR_O       ),
      .S_RTY_O       (S_RTY_O       ),
      // wishbone PORT B signals
      .C_ADR_I       (INT_ADR_I     ),
      .C_DAT_I       (INT_DAT_I     ),
      .C_WE_I        (INT_WE_I      ),
      .C_STB_I       (INT_STB_I     ),
      .C_CYC_I       (INT_CYC_I     ),
      .C_SEL_I       (INT_SEL_I     ),
      .C_CTI_I       (INT_CTI_I     ),
      .C_BTE_I       (INT_BTE_I     ),
      .C_DAT_O       (INT_DAT_O     ),
      .C_ACK_O       (INT_ACK_O     ),
      .C_ERR_O       (INT_ERR_O     ),
      .C_RTY_O       (INT_RTY_O     ),
      // command from wishbone to SPI flash signals
      .spi_cmd       (spi_cmd       ),
      .spi_cmd_ext   (spi_cmd_ext   ),
      .cmd_bytes     (cmd_bytes     ),
      .byte_length   (byte_length   ),
      .page_cmd      (page_cmd      ),
      .wr_enb        (wr_enb        ),
      .read_data     (read_data     ),
      .write_data    (write_data    ),
      .spi_wrt_enb   (spi_wrt_enb   ),
      .spi_read_stat (spi_read_stat ),
      .fast_read     (fast_read     ),
      .spi_wr        (spi_wr        ),
      .spi_req       (spi_req       ),
      .spi_ack       (spi_ack       ),
      .wb2spi_wr_addr(wb2spi_wr_addr),
      .wb2spi_data   (wb2spi_data   ),
      .wb2spi_we     (wb2spi_we     ),
      .spi2wb_rd_addr(spi2wb_rd_addr),
      .spi2wb_q      (spi2wb_q      ),
      // system signals
      .CLK_I         (CLK_I         ),
      .RST_I         (RST_I         )
      );
   
   // ====================================================================
   // instantiate spi flash interface module
   // ====================================================================
   spi_flash_intf
     #(.C_PORT_ENABLE     (C_PORT_ENABLE    ),
       .C_WB_DAT_WIDTH    (C_WB_DAT_WIDTH   ),
       .WB_DAT_WIDTH      (WB_DAT_WIDTH     ),
       .PAGE_PRG_BUF_ENA  (PAGE_PRG_BUF_ENA ),
       .PAGE_READ_BUF_ENA (PAGE_READ_BUF_ENA),
       .BUF_WIDTH         (BUF_WIDTH        ),
       .PAGE_WIDTH        (PAGE_WIDTH       ))
   spi_flash_intf_inst
     (
      // SPI flash signals
      .SI            (SI            ),
      .SO            (SO            ),
      .CS            (CEJ           ),
      .SCK           (SCK           ),
      .WP            (WPJ           ),
      // command from wishbone to SPI flash signals
      .spi_cmd       (spi_cmd       ),
      .spi_cmd_ext   (spi_cmd_ext   ),
      .cmd_bytes     (cmd_bytes     ),
      .byte_length   (byte_length   ),
      .page_cmd      (page_cmd      ),
      .wr_enb        (wr_enb        ),
      .read_data     (read_data     ),
      .write_data    (write_data    ),
      .spi_wrt_enb   (spi_wrt_enb   ),
      .spi_read_stat (spi_read_stat ),
      .fast_read     (fast_read     ),
      .spi_wr        (spi_wr        ),
      .spi_req       (spi_req       ),
      .spi_ack       (spi_ack       ),
      .wb2spi_rd_addr(wb2spi_rd_addr),
      .wb2spi_q      (wb2spi_q      ),
      .spi2wb_wr_addr(spi2wb_wr_addr),
      .spi2wb_data   (spi2wb_data   ),
      .spi2wb_we     (spi2wb_we     ),
      // system signals
      .spi_clk       (spi_clk       ),
      .RST_I         (RST_I         )
      );
   
endmodule
