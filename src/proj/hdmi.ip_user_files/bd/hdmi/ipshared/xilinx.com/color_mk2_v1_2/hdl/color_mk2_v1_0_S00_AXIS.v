
`timescale 1 ns / 1 ps

	module color_mk2_v1_0_S00_AXIS #
	(
		// Users to add parameters here
        parameter integer NUMBER_OF_INPUT_WORDS  = 1920,
        parameter integer FIFO_DEPTH = 1920,
		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 24
	)
	(
		// Users to add ports here
        input wire [bit_num-1:0] read_pointer,
        output wire [C_S_AXIS_TDATA_WIDTH-1 : 0] READ_DATA,
        output reg FIFO_VALID,
		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
//		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);
	// function called clogb2 that returns an integer which has the 
	// value of the ceiling of the log base 2.
	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
	      bit_depth = bit_depth >> 1;
	  end
	endfunction

	// Total number of input data.
//	localparam NUMBER_OF_INPUT_WORDS  = 8;
	// bit_num gives the minimum number of bits needed to address 'NUMBER_OF_INPUT_WORDS' size of FIFO.
	localparam bit_num  = clogb2(NUMBER_OF_INPUT_WORDS-1);
	// Define the states of state machine
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO
	parameter [1:0] IDLE = 1'b0,        // This is the initial/idle state 

	                WRITE_FIFO  = 1'b1; // In this state FIFO is written with the
	                                    // input stream data S_AXIS_TDATA 
	wire  	axis_tready;
	// State variable
	reg mst_exec_state;  
	
	// FIFO implementation signals
	// FIFO write enable
	wire fifo_wren;
	// FIFO full flag
	reg fifo_full_flag;
	// FIFO write pointer
	reg [bit_num-1:0] write_pointer;
	// sink has accepted all the streaming data and stored in FIFO
	reg writes_done;
	// I/O Connections assignments

	assign S_AXIS_TREADY	= axis_tready;
	// Control state machine implementation
	always @(posedge S_AXIS_ACLK) 
	begin  
	  if (!S_AXIS_ARESETN) 
	  // Synchronous reset (active low)
	    begin
	      mst_exec_state <= IDLE;
	    end  
	  else
	    case (mst_exec_state)
	      IDLE: 
	        // The sink starts accepting tdata when 
	        // there tvalid is asserted to mark the
	        // presence of valid streaming data 
	          if (S_AXIS_TVALID && !FIFO_VALID)
	            begin
	              mst_exec_state <= WRITE_FIFO;
	            end
	          else
	            begin
	              mst_exec_state <= IDLE;
	            end
	      WRITE_FIFO: 
	        // When the sink has accepted all the streaming input data,
	        // the interface swiches functionality to a streaming master
	        if (writes_done)
	          begin
	            mst_exec_state <= IDLE;
	          end
	        else
	          begin
	            // The sink accepts and stores tdata 
	            // into FIFO
	            mst_exec_state <= WRITE_FIFO;
	          end

	    endcase
	end
	// AXI Streaming Sink 
	// 
	// The example design sink is always ready to accept the S_AXIS_TDATA  until
	// the FIFO is not filled with NUMBER_OF_INPUT_WORDS number of input words.
	assign axis_tready = ((mst_exec_state == WRITE_FIFO) && (write_pointer <= NUMBER_OF_INPUT_WORDS-1));

	always@(posedge S_AXIS_ACLK)
	begin
	  if(!S_AXIS_ARESETN)
	    begin
	      write_pointer <= 0;
	      writes_done <= 1'b0;
	    end  
	  else
	    if (write_pointer <= NUMBER_OF_INPUT_WORDS-1)
	      begin
	        if (fifo_wren)
	          begin
	            // write pointer is incremented after every write to the FIFO
	            // when FIFO write signal is enabled.
	            write_pointer <= write_pointer + 1;
//	            writes_done <= 1'b0;
	          end
	          if ((write_pointer == NUMBER_OF_INPUT_WORDS-1)|| S_AXIS_TLAST)
	            begin
	              // reads_done is asserted when NUMBER_OF_INPUT_WORDS numbers of streaming data 
	              // has been written to the FIFO which is also marked by S_AXIS_TLAST(kept for optional usage).
	              writes_done <= 1'b1;
	            end
	      end else begin
	           write_pointer <= 0;
	           writes_done <= 1'b0;
	      end
	end

	// FIFO write enable generation
	assign fifo_wren = S_AXIS_TVALID && axis_tready;

	// FIFO Implementation
	reg  [7:0] stream_data_fifo0 [0 : FIFO_DEPTH-1];
    reg  [7:0] stream_data_fifo1 [0 : FIFO_DEPTH-1];
    reg  [7:0] stream_data_fifo2 [0 : FIFO_DEPTH-1];
    reg mux_sel [0 : FIFO_DEPTH-1];
    wire sel = (S_AXIS_TDATA[7 : 0] <= 8'd150) && (S_AXIS_TDATA[15: 8] >= 8'd200) && (S_AXIS_TDATA[23: 16] <= 8'd150);
    
    always @( posedge S_AXIS_ACLK )
    begin
      if (fifo_wren) begin
        if(write_state==DETECTION) begin
            stream_data_fifo0[write_pointer] <= S_AXIS_TDATA[7 : 0];
            stream_data_fifo1[write_pointer] <= S_AXIS_TDATA[15: 8];
            stream_data_fifo2[write_pointer] <= S_AXIS_TDATA[23: 16];
            mux_sel[write_pointer] <= sel;
        end else if (write_state==REPLACEMENT && mux_sel[write_pointer]) begin
            stream_data_fifo0[write_pointer] <= S_AXIS_TDATA[7 : 0];
            stream_data_fifo1[write_pointer] <= S_AXIS_TDATA[15: 8];
            stream_data_fifo2[write_pointer] <= S_AXIS_TDATA[23: 16];
        end
      end
    end

	// Add user logic here
    assign READ_DATA = {stream_data_fifo2[read_pointer], stream_data_fifo1[read_pointer], stream_data_fifo0[read_pointer]};
    
    // FSM
    reg [1:0] write_state;
    parameter [1:0] DETECTION = 2'b00,
                      REPLACEMENT  = 2'b01,
                      STREAM  = 2'b10; 
                      
    always @(posedge S_AXIS_ACLK) 
    begin  
      if (!S_AXIS_ARESETN) 
        begin
          write_state <= DETECTION;
          FIFO_VALID <= 0;
        end  
      else
        case (write_state)
          DETECTION: 
              if (write_pointer == NUMBER_OF_INPUT_WORDS-1)
                begin
                  write_state <= REPLACEMENT;
                end
              else
                begin
                  write_state <= DETECTION;
                end
          REPLACEMENT: 
            if (write_pointer == NUMBER_OF_INPUT_WORDS-1)
              begin
                write_state <= STREAM;
                FIFO_VALID <= 1;
              end
            else
              begin
                write_state <= REPLACEMENT;
              end
           STREAM: 
              if (read_pointer == NUMBER_OF_INPUT_WORDS)
                begin
                  write_state <= DETECTION;
                  FIFO_VALID <= 0;
                end
              else
                begin
                  write_state <= STREAM;
                end
        endcase
    end
	// User logic ends

	endmodule