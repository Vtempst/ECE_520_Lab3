`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/17/2026 06:19:04 AM
// Design Name: 
// Module Name: tb_sc_fifo
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


module tb_sc_fifo();

parameter clk_period = 20;
parameter width = 16;
parameter depth = 32;
parameter read_latency = 1;
parameter num_words = 100;
parameter almost_empty_threshold = 1;
parameter almost_full_threshold = 31;

reg clock;
reg srst;
reg [width-1:0] data_in;
reg write_enable;
reg read_enable;

wire [$clog2(depth+1)-1:0] data_count;
wire [width-1:0] data_out;
wire valid;
wire full;
wire empty;
wire almost_full;
wire almost_empty;

integer errors = 0;
integer i;
integer j;
integer base;
integer batch_size;
integer raw_fd;
integer results_fd;

reg [width-1:0] file_data [0:num_words-1];
reg [width-1:0] expected_memory [0:depth-1];

integer expected_count;
integer write_index;
integer read_index;

reg [width-1:0] expected_data [0:read_latency-1];
reg expected_valid [0:read_latency-1];

sc_fifo #(
    .width(width),
    .depth(depth),
    .almost_empty_threshold(almost_empty_threshold),
    .almost_full_threshold(almost_full_threshold),
    .read_latency(read_latency)
) UUT (
    .clock(clock),
    .srst(srst),
    .data_in(data_in),
    .write_enable(write_enable),
    .read_enable(read_enable),
    .data_count(data_count),
    .valid(valid),
    .data_out(data_out),
    .almost_full(almost_full),
    .almost_empty(almost_empty),
    .full(full),
    .empty(empty)
);    

initial begin
    clock = 1'b0;
    forever #(clk_period / 2) clock = ~clock;
end

task fifo_cycle;
    input wr;
    input rd;
    input [width-1:0] din;
    
    reg accepted_write;
    reg accepted_read;
    reg [width-1:0] read_value;
    integer k;
    
    begin
        @(negedge clock);

        write_enable = wr;
        read_enable = rd;
        data_in = din;

        // Determine accepted operations
        accepted_write = wr && (expected_count < depth);
        accepted_read = rd && (expected_count > 0);

        read_value = 0;

        // Retrieve expected FIFO data
        if (accepted_read) 
        begin
            read_value = expected_memory[read_index];
            read_index = (read_index + 1) % depth;
        end

        // Store expected written data
        if (accepted_write) 
        begin
            expected_memory[write_index] = din;
            write_index = (write_index + 1) % depth;
        end

        // Update expected FIFO count
        if (accepted_write && !accepted_read) 
        begin
            expected_count = expected_count + 1;
        end 
        else if (!accepted_write && accepted_read)
        begin
            expected_count = expected_count - 1;
        end

        // Account for FIFO read latency
        for (k = read_latency-1; k > 0; k = k-1) begin
            expected_data[k] = expected_data[k-1];
            expected_valid[k] = expected_valid[k-1];
        end

        expected_data[0] = read_value;
        expected_valid[0] = accepted_read;

        @(posedge clock);
        #1;

        // Check FIFO count
        if (data_count !== expected_count) 
        begin
            errors = errors + 1;
            $fdisplay(results_fd, "[%0t] FAIL COUNT: current=%0d expected=%0d", $time, data_count, expected_count);
        end
        
        // check FIFO flags
        if(full !== (expected_count == depth))
        begin
            errors = errors + 1;
            $fdisplay(results_fd,
            "[%0t] FAIL: full flag", $time);
        end
        
        if(empty !== (expected_count == 0))
        begin
            errors = errors + 1;
            $fdisplay(results_fd,
            "[%0t] FAIL: empty flag", $time);
        end
        
        if(almost_full !== (expected_count >= almost_full_threshold))
        begin
            errors = errors + 1;
            $fdisplay(results_fd,
            "[%0t] FAIL: almost_full flag", $time);
        end
        
        if(almost_empty !== (expected_count <= almost_empty_threshold))
        begin
            errors = errors + 1;
            $fdisplay(results_fd,
            "[%0t] FAIL: almost_empty flag", $time);
        end

        // checks valid signal
        if (valid !== expected_valid[read_latency-1]) 
        begin
            errors = errors + 1;
            $fdisplay(results_fd, "[%0t] FAIL valid flag: current=%b expected=%b", $time, valid, expected_valid[read_latency-1]);
        end

        // check FIFO output and compare it to expected
        if (data_out !== (expected_valid[read_latency-1] ? expected_data[read_latency-1] : 0)) 
        begin
            errors = errors + 1;
            $fdisplay(results_fd, "[%0t] FAIL data_out: current=%h expected=%h", $time, data_out, expected_valid[read_latency-1] ? expected_data[read_latency-1] : {width{1'b0}});
        end

        // displays data_out values in txt_file
        if (valid === 1'b1) begin $fdisplay(results_fd, "[%0t] READ: data_out=%h", $time, data_out);
        
        end
    end
endtask

initial begin
    raw_fd = $fopen("test_results.txt");
    results_fd = raw_fd | 1;
    
    $readmemh("C:/Users/gilst/Documents/ECE520/sim/input_data.txt", file_data);
    
    srst = 1;
    write_enable = 0;
    read_enable = 0;
    data_in = 0;

    expected_count = 0;
    write_index = 0;
    read_index = 0;
    
    for (i = 0; i < read_latency; i = i+1) 
    begin
        expected_data[i] = 0;
        expected_valid[i] = 0;
    end
    
    repeat (2) @(posedge clock);
    #1;
    
    // verify reset
    if (data_out !== {width{1'b0}} || valid !== 1'b0 || data_count !== 0 || empty !== 1'b0) 
        begin
        errors = errors + 1;
        $fdisplay(results_fd, "FAIL: Reset test");
    end
    else begin
        $fdisplay(results_fd, "PASS: Reset test");
    end
    
    @(negedge clock);
    srst = 0;
    
    // Process data from text file in batches
    for (base = 0; base < num_words; base = base + depth) begin
        batch_size = num_words - base;

        if (batch_size > depth)
            batch_size = depth;
    
        // Write generated values into FIFO
        for (j = 0; j < batch_size; j = j+1) begin
            fifo_cycle(1'b1, 1'b0, file_data[base+j]);
        end

        // Test writing while full
        if (batch_size == depth)
            fifo_cycle(1'b1, 1'b0, file_data[base]);

        // Read values back from FIFO
        for (j = 0; j < batch_size; j = j+1) begin
            fifo_cycle(1'b0, 1'b1, {width{1'b0}});
        end

        // Test reading while empty
        fifo_cycle(1'b0, 1'b1, {width{1'b0}});
    end
    
    
    // Test Reset after read
    fifo_cycle(1'b1, 1'b0, 16'hABCD);
    fifo_cycle(1'b1, 1'b0, 16'h1234);
    fifo_cycle(1'b0, 1'b1, 16'h0000);
    
    @(negedge clock);
    srst = 1;
    write_enable = 0;
    read_enable = 0;
    
    @(posedge clock);
    #1;
    
    repeat (10) @(posedge clock);
    #1;
    
    @(negedge clock);
    srst = 0;
    
    repeat (5) @(posedge clock);
    #1;
    
    // Final results
    if (errors == 0) 
    begin
        $display("TEST PASSED");
        $fdisplay(results_fd, "TEST PASSED");
    end
    else 
    begin
        $display("TEST FAILED: %0d errors", errors);
        $fdisplay(results_fd, "TEST FAILED: %0d errors", errors);
    end
    
    $fclose(raw_fd);
    $finish;
end

endmodule
