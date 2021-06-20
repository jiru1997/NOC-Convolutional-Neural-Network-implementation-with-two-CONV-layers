//-------------------------------------------------------------------------------------------------
//  SystemVerilogCSP: testbench
//  University of Southern California
//-------------------------------------------------------------------------------------------------
`timescale 1ns/1fs
import SystemVerilogCSP::*;
import dataformat::*;
module ctrl_tb

 #(parameter WIDTH = 8,
 parameter DEPTH_I = 7,
 parameter WIDTH_I = 7,
 parameter ADDR_I = 8, 
 parameter DEPTH_F1 = 3,
 parameter WIDTH_F1 = 3,
 parameter DEPTH_F2 = 1,
 parameter WIDTH_F2 = 1,
 parameter ADDR_F = 8,
 parameter DEPTH_R = 5,
 parameter WIDTH_R = 5,
 parameter READ_FINAL_F_MAP = 0,
 parameter NUM_OF_FILTER1 = 2,
 parameter NUM_OF_FILTER2 = 3)

   (interface mem_data, 
  interface mem_addr,
  interface datain_filter, 
  interface addrin_filter,
  interface start,
  interface done,
  interface result_addr,
  interface result_data,
  output reg reset);
 
 logic d;
 bit don_e;
 logic [WIDTH - 1:0] data_ifmap, data_filter, res;
 logic [ADDR_F-1:0] addr_filter = 0;
 logic [ADDR_I-1:0] addr_ifmap = 0;
 logic [WIDTH-1:0] psum_o;
 logic [WIDTH-1:0] comp[DEPTH_R*WIDTH_R*NUM_OF_FILTER2-1:0];
 integer count, error_count, fpo, fpt, fpi_f, fpi_i, fpi_r,status = 0;

 initial begin
   $timeformat(-9, 2, " ns");
   reset = 0;
   fpi_f = $fopen("filter.txt","r");
   fpi_i = $fopen("ifmap.txt","r");
   fpi_r = $fopen("golden_result.txt","r");
   fpo = $fopen("test.dump","w");
   fpt = $fopen("transcript.dump");
   if(!fpi_f || !fpi_i) begin
       $display("A file cannot be opened!");
       $stop;
   end
   for(integer i=0; i<(DEPTH_F1*WIDTH_F1*NUM_OF_FILTER1 + DEPTH_F2*WIDTH_F2*NUM_OF_FILTER2); i++) begin
	    if(!$feof(fpi_f)) begin
	     status = $fscanf(fpi_f,"%d\n", data_filter);
	     //$display("fpf data read:%d", data_filter);
	     addrin_filter.Send(addr_filter);
	     datain_filter.Send(data_filter); 
	     //$display("filter memory: mem[%d]= %d",addr_filter,data_filter);
	     addr_filter++;
	     //$display("addr_filter=%d",addr_filter);
	   end 
   end
   for(integer i=0; i<(DEPTH_I*WIDTH_I); i++) begin
	    if (!$feof(fpi_i)) begin
	     status = $fscanf(fpi_i,"%d\n", data_ifmap);
	     //$display("fpi data read:%d", data_ifmap);
	     mem_addr.Send(addr_ifmap);
	     mem_data.Send(data_ifmap); 
	     //$display("ifmap memory: mem[%d]= %d",addr_ifmap, data_ifmap);
	     addr_ifmap++;
	   end 
   end

   for(integer i=0; i<(DEPTH_R*WIDTH_R*NUM_OF_FILTER2); i++) begin
	    if(!$feof(fpi_r)) begin
	     status = $fscanf(fpi_r,"%d\n", res);
	     //$display("fpi_r data read:%d", res);
	     comp[i] = res;
	     //$fdisplay(fpt,"comp[%d]= %d",i,res); 
	     //$display("comp[%d]= %d",i,res);
        end 
   end

	// starting the system
	 #0.1;
    reset = 1;
	start.Send(0); 
	$fdisplay(fpt,"%m sent start token at %t",$realtime);
	$display("%m sent start token at %t",$realtime);
    #0.1;
    done.Receive(don_e);
    $fdisplay(fpt,"%m done token received at %t",$realtime);
    // comparing results
    error_count = 0;
    count = READ_FINAL_F_MAP;
    for(integer i=0; i<DEPTH_R*WIDTH_R*NUM_OF_FILTER2; i++) begin
	  result_addr.Send(count);
	  count++;
	  result_data.Receive(res);
	  if (res !== comp[i])  begin
	   $fdisplay(fpo,"%d != %d error!",res,comp[i]);
	   $fdisplay(fpt,"%d != %d error!",res,comp[i]);
	   $display("%d != %d error!",res,comp[i]);
	   $fdisplay(fpt,"mem[%d] = %d == comp[%d] = %d",count, res, i, comp[i]);
	   $fdisplay(fpo,"mem[%d] = %d == comp[%d] = %d",count, res, i, comp[i]);
	   error_count++;
	  end 
	  else begin
	   $display(fpt,"mem[%d] = %d == comp[%d] = %d",count, res, i, comp[i]);
	   $fdisplay(fpo,"mem[%d] = %d == comp[%d] = %d",count, res, i, comp[i]);
	   $display("%m result value %0d: %d received at %t",i, res, $realtime);
	  end
	end
	$fdisplay(fpo,"total errors = %d",error_count);
	$fdisplay(fpt,"total errors = %d",error_count);
	$display("total errors = %d",error_count); 
 
	$display("%m Results compared, ending simulation at %t",$realtime);
	$fdisplay(fpt,"%m Results compared, ending simulation at %t",$realtime);
	$fdisplay(fpo,"%m Results compared, ending simulation at %t",$realtime);
	$fclose(fpt);
	$fclose(fpo);
	$stop;
 end
 
 // watchdog timer
 initial begin
	#10000;
	$display("*** Stopped by watchdog timer ***");
	$stop;
 end

endmodule // pe_tb

//testbench instantiation
module testbench;

 wire rst;
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) addrin_mapper();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) addrin_filter();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) datain_filter();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) datain_mapper();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) result_addr();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(8)) result_data();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(20)) intf  [40:1] (); 
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE0 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE1 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE2 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE3 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE4 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE5 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE6 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE7 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToPE8 ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToMem ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  ccToAdd ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  start ();
 Channel #(.hsProtocol(P4PhaseBD), .WIDTH(1))  done ();

  ctrl_tb tb ( .reset(rst), .start(start), .mem_data(datain_mapper), .mem_addr(addrin_mapper),
    .result_data(result_data), .result_addr(result_addr), .done(done), .datain_filter(datain_filter), 
    .addrin_filter(addrin_filter));

 add ad(._index(5'b10101), ._mem_index(5'b00001), .RouterToAdd_in(intf[32]), .RouterToAdd_out(intf[31]), .ccToAdd(ccToAdd), ._tot_time(3), ._tot_num(50));

 system_control sys_ctrl(.ccToPE0(ccToPE0), .ccToPE1(ccToPE1), .ccToPE2(ccToPE2), .ccToPE3(ccToPE3), .ccToPE4(ccToPE4),
 	.ccToPE5(ccToPE5), .ccToPE6(ccToPE6), .ccToPE7(ccToPE7), .ccToPE8(ccToPE8), .start(start), .done(done), .ccToAdd(ccToAdd), .ccToMem(ccToMem));

 memory memo(._index(5'b00001), .sys_addr_out(addrin_mapper), .sys_addr_in(addrin_filter), 
 	.sys_data_in(datain_filter), .sys_data_out(datain_mapper), .tb_addr_out(intf[1]), 
 	.tb_addr_in(intf[2]), .result_data(result_data), .result_addr(result_addr), .ccToMem(ccToMem));

 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe1(._index(5'b00011), ._inner_index(5'b00000), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b00101), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00000000), ._ifmap_pointer(8'b00000000),
  	.RouterToPE_in(intf[4]), .RouterToPE_out(intf[3]), .ccToPE(ccToPE0), ._result_index(0));
 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe2(._index(5'b00101), ._inner_index(5'b00001), ._sum_index(5'b10101), 
 	._mem_index(5'b00001), ._next_pe_index(5'b00111), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00000011), ._ifmap_pointer(8'b00000111),
 	.RouterToPE_in(intf[12]), .RouterToPE_out(intf[11]), .ccToPE(ccToPE1), ._result_index(0));
 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe3(._index(5'b00111), ._inner_index(5'b00010), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b00011), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00000110), ._ifmap_pointer(8'b00001110),
  	.RouterToPE_in(intf[14]), .RouterToPE_out(intf[13]), .ccToPE(ccToPE2), ._result_index(0));

 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe4(._index(5'b01001), ._inner_index(5'b00000), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b01011), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00001001), ._ifmap_pointer(8'b00000000),
  	.RouterToPE_in(intf[22]), .RouterToPE_out(intf[21]), .ccToPE(ccToPE3), ._result_index(25));
 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe5(._index(5'b01011), ._inner_index(5'b00001), ._sum_index(5'b10101), 
 	._mem_index(5'b00001), ._next_pe_index(5'b01101), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00001100), ._ifmap_pointer(8'b00000111),
 	.RouterToPE_in(intf[24]), .RouterToPE_out(intf[23]), .ccToPE(ccToPE4), ._result_index(25));
 PE #(.FILTER_WIDTH(3), .IFMAP_WIDTH(7))
    pe6(._index(5'b01101), ._inner_index(5'b00010), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b01001), ._tot_pe_num(5'b00011), ._tot_round(5'b00101), ._filter_pointer(8'b00001111), ._ifmap_pointer(8'b00001110),
  	.RouterToPE_in(intf[26]), .RouterToPE_out(intf[25]), .ccToPE(ccToPE5), ._result_index(25));

 PE #(.FILTER_WIDTH(1), .IFMAP_WIDTH(5))
    pe7(._index(5'b01111), ._inner_index(5'b00000), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b01111), ._tot_pe_num(5'b00001), ._tot_round(5'b00101), ._filter_pointer(8'b00010010), ._ifmap_pointer(8'b00000000),
  	.RouterToPE_in(intf[28]), .RouterToPE_out(intf[27]), .ccToPE(ccToPE6), ._result_index(0));

 PE #(.FILTER_WIDTH(1), .IFMAP_WIDTH(5))
    pe8(._index(5'b10001), ._inner_index(5'b00000), ._sum_index(5'b10101), 
 	._mem_index(5'b00001), ._next_pe_index(5'b10001), ._tot_pe_num(5'b00001), ._tot_round(5'b00101), ._filter_pointer(8'b00010011), ._ifmap_pointer(8'b00000000),
 	.RouterToPE_in(intf[34]), .RouterToPE_out(intf[33]), .ccToPE(ccToPE7), ._result_index(25));

 PE #(.FILTER_WIDTH(1), .IFMAP_WIDTH(5))
    pe9(._index(5'b10011), ._inner_index(5'b00000), ._sum_index(5'b10101), 
  	._mem_index(5'b00001), ._next_pe_index(5'b10011), ._tot_pe_num(5'b00001), ._tot_round(5'b00101), ._filter_pointer(8'b00010100), ._ifmap_pointer(8'b00000000),
  	.RouterToPE_in(intf[36]), .RouterToPE_out(intf[35]), .ccToPE(ccToPE8), ._result_index(50));
 
 router #(.left_min(1), .right_max(3), .router_add(2)) r2 
 (.p_in(intf[6]), .p_out(intf[5]), .ch1_in(intf[1]), .ch1_out(intf[2]), .ch2_in(intf[3]), .ch2_out(intf[4]));
 router #(.left_min(1), .right_max(7), .router_add(4)) r4 
 (.p_in(intf[8]), .p_out(intf[7]), .ch1_in(intf[5]), .ch1_out(intf[6]), .ch2_in(intf[9]), .ch2_out(intf[10]));
 router #(.left_min(5), .right_max(7), .router_add(6)) r6 
 (.p_in(intf[10]), .p_out(intf[9]), .ch1_in(intf[11]), .ch1_out(intf[12]), .ch2_in(intf[13]), .ch2_out(intf[14]));
 router #(.left_min(9), .right_max(11), .router_add(10)) r10 
 (.p_in(intf[18]), .p_out(intf[17]), .ch1_in(intf[21]), .ch1_out(intf[22]), .ch2_in(intf[23]), .ch2_out(intf[24]));
 router #(.left_min(9), .right_max(15), .router_add(12)) r12 
 (.p_in(intf[16]), .p_out(intf[15]), .ch1_in(intf[17]), .ch1_out(intf[18]), .ch2_in(intf[19]), .ch2_out(intf[20]));
 router #(.left_min(13), .right_max(15), .router_add(14)) r14 
 (.p_in(intf[20]), .p_out(intf[19]), .ch1_in(intf[25]), .ch1_out(intf[26]), .ch2_in(intf[27]), .ch2_out(intf[28]));
 router #(.left_min(1), .right_max(15), .router_add(8)) r8 
 (.p_in(intf[38]), .p_out(intf[37]), .ch1_in(intf[7]), .ch1_out(intf[8]), .ch2_in(intf[15]), .ch2_out(intf[16]));
 router #(.left_min(17), .right_max(19), .router_add(18)) r18 
 (.p_in(intf[30]), .p_out(intf[29]), .ch1_in(intf[33]), .ch1_out(intf[34]), .ch2_in(intf[35]), .ch2_out(intf[36]));
 router #(.left_min(17), .right_max(21), .router_add(20)) r20 
 (.p_in(intf[40]), .p_out(intf[39]), .ch1_in(intf[29]), .ch1_out(intf[30]), .ch2_in(intf[31]), .ch2_out(intf[32]));

 router_top #(.router_add(16)) r16 (.ch1_in(intf[37]), .ch1_out(intf[38]), .ch2_in(intf[39]), .ch2_out(intf[40]));

endmodule