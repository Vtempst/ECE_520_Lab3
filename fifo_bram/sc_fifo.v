`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/12/2026 06:35:14 AM
// Design Name: 
// Module Name: sc_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sc_fifo #(
parameter width = 16,
parameter depth = 32,
parameter almost_empty_threshold = 1,
parameter almost_full_threshold = 31,
parameter read_latency = 1
)(
input clock,
input srst,
input [width-1:0] data_in,
input write_enable,
input read_enable,

output reg [$clog2(depth+1)-1:0] data_count,
output wire valid,
output wire [width-1:0] data_out,
output wire almost_full,
output wire almost_empty,
output wire full,
output wire empty
    );
    
reg [$clog2(depth)-1:0] write_ptr;
reg [$clog2(depth)-1:0] read_ptr;
reg base_valid;

wire ena;
wire wea;
wire enb;
wire [width-1:0] doutb;

blk_mem_gen_0 bram_insta (
  .clka(clock),         // input wire clka
  .ena(ena),            // input wire ena
  .wea(wea),            // input wire [0 : 0] wea
  .addra(write_ptr),    // input wire [4 : 0] addra
  .dina(data_in),       // input wire [15 : 0] dina
  .clkb(clock),         // input wire clkb
  .enb(enb),            // input wire enb
  .addrb(read_ptr),     // input wire [4 : 0] addrb
  .doutb(doutb)         // output wire [15 : 0] doutb
);

assign wea = write_enable && !full && !srst;
assign ena = wea;
assign enb = read_enable && !empty && !srst;

always @(posedge clock)
begin
    if (srst)
    begin
        write_ptr <= 0;
        read_ptr <= 0;
    end
    else
    begin
        if(wea) // both signals have the same value, use wea instead of ena becaus it represents the accepted write operation
        begin
            write_ptr <= write_ptr + 1;
        end
        if(enb)
        begin
            read_ptr <= read_ptr + 1;
        end
    end
end

always @(posedge clock)
begin
    if(srst)
    begin
        data_count <= 0;
    end
    else
    begin
        if (!wea && enb)
        begin
            data_count <= data_count - 1;
        end
        else
        if (wea && !enb)
        begin
            data_count <= data_count + 1;
        end
    end
end

assign full = (data_count == depth);
assign empty = (data_count == 0);
assign almost_full = (data_count >= almost_full_threshold);
assign almost_empty = (data_count <= almost_empty_threshold);

always @(posedge clock)
begin
    if(srst)
    begin
        base_valid <= 0;
    end
    else
    begin
        base_valid <= enb;
    end
end

generate
    if (read_latency == 1) begin : no_pipeline
        assign valid = base_valid;
        assign data_out = base_valid ? doutb : {width{1'b0}};
    end
    else begin : pipeline
        reg [width-1:0] pipeline_register [0:read_latency-2]; // extra registers: if read_latency = 3, two additional registers so it should be [0:1]
        //stores actual data from BRAM
        reg valid_pipeline [0:read_latency-2];
        //stores whether the corresponding data is valid
        
        integer i;
        
        always @(posedge clock)
        begin
            if (srst)
            begin
                for (i = 0; i < read_latency-1; i = i + 1)
                begin
                    valid_pipeline[i] <= 0;
                end
            end
            else
            begin
                pipeline_register[0] <= doutb;
                valid_pipeline[0] <= base_valid;                
                for (i = 1; i < read_latency-1; i = i + 1)
                begin
                    pipeline_register[i] <= pipeline_register[i-1];
                    valid_pipeline[i] <= valid_pipeline[i-1];
                end       
            end
        end
        assign valid = valid_pipeline[read_latency - 2];
        assign data_out = valid_pipeline[read_latency - 2] ? pipeline_register[read_latency - 2] : {width{1'b0}};
    end        
endgenerate
endmodule
