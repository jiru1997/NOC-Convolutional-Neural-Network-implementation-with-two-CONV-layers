//-------------------------------------------------------------------------------------------------
// control center module 
// control initialization of all PEs 
//-------------------------------------------------------------------------------------------------

`timescale 1ns/1ps
import SystemVerilogCSP::*;
import dataformat::*;

module add
  #(parameter WIDTH = 5,
  parameter DATA_WIDTH = 20,
  parameter FL = 2,
  parameter BL = 2,
  parameter PACKDEALY = 1)

  ( input bit[WIDTH - 1:0] _index,
    input bit[WIDTH - 1:0] _mem_index,
    interface RouterToAdd_in,
    interface RouterToAdd_out,
    interface ccToAdd,
    int _tot_time,
    int _tot_num);

  int tot_time = 3;
  int tot_num = 50;
  int times[int];
  int sum[int];
  int pointer, i;
  bit flag = 0;
  bit[WIDTH - 1:0] index;
  bit[WIDTH - 1:0] mem_index;
  bit[DATA_WIDTH - 1:0] data_pass_memory;               //memory数据包
  bit[DATA_WIDTH - 1:0] data_pass_PE;                   //memory数据包

  always begin
      RouterToAdd_in.Receive(data_pass_PE);
	  #FL;
      sum[data_pass_PE[DATA_WIDTH - 1:DATA_WIDTH-7]] += dataformater::unpackdata(data_pass_PE);
      times[data_pass_PE[DATA_WIDTH - 1:DATA_WIDTH-7]] += 1;
  end

  always begin
    wait(times[pointer] == tot_time);
    data_pass_memory = dataformater::packdata(index, mem_index, 0, sum[pointer]);
    #PACKDEALY;
    RouterToAdd_out.Send(data_pass_memory);
    times[pointer] = 0;
    sum[pointer] = 0;
    pointer = pointer + 1;
    #BL;
  end

  always begin
    wait(pointer == tot_num);
    ccToAdd.Send(flag);
	#BL;
    ccToAdd.Receive(flag);
	#FL;
    pointer = 0;
    tot_time = 1;
    tot_num = 75;
    for(i = 0; i < tot_num; i = i + 1) begin
      times[i] = 0;
      sum[i] = 0;
    end
  end

  initial begin
    #0.1;
    tot_time = _tot_time;
    tot_num = _tot_num;
    pointer = 0;
    index = _index;
    mem_index = _mem_index;
    for(i = 0; i < tot_num; i = i + 1) begin
      times[i] = 0;
      sum[i] = 0;
    end
    ccToAdd.Receive(flag);
	#FL;
  end

endmodule
