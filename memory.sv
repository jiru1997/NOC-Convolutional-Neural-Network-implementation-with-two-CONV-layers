//-------------------------------------------------------------------------------------------------
// memory module 
// function:load data from filter and send them to PES
//-------------------------------------------------------------------------------------------------
`timescale 1ns/1fs
import SystemVerilogCSP::*;
import dataformat::*;

module memory

	#(parameter WIDTH = 5,
	parameter VALID_DATA_WIDTH = 8,
	parameter FILTER_WIDTH = 50,
	parameter IFMAP_WIDTH = 50,
    parameter RESULT_WIDTH = 80,
	parameter DATA_WIDTH = 20,
	parameter FILTER_NUM1 = 3,
	parameter FILTER_NUM2 = 1,
	parameter IFMAP_NUM = 7,
	parameter NUM_OF_FILTER1 = 2,
	parameter NUM_OF_FILTER2 = 3,
	parameter DEPTH_R1 = 5,
	parameter WIDTH_R1 = 5,
	parameter DEPTH_R2 = 5,
	parameter WIDTH_R2 = 5,
	parameter WIDTH_POOL = 2,
	parameter FL = 12,
	parameter BL = 4,
	parameter PACKDEALY = 1)

	(input bit[WIDTH - 1:0] _index,
   interface sys_data_in, 
   interface sys_addr_in,
   interface sys_data_out,
   interface sys_addr_out,
   interface tb_addr_in,
   interface tb_addr_out,
     interface result_addr,
     interface result_data,
     interface ccToMem);

    int fpt;
    bit poolflag;
    bit finishflag;
    bit filterflag;
    bit mapperflag;
    bit flag = 0;
    bit[WIDTH - 1:0] index;
    bit[WIDTH - 1:0] rece_index;
    bit[VALID_DATA_WIDTH - 1:0] f_addr;
    bit[VALID_DATA_WIDTH - 1:0] m_addr;
    bit[VALID_DATA_WIDTH - 1:0] r_addr;
    bit[VALID_DATA_WIDTH - 1:0] f_data;
    bit[VALID_DATA_WIDTH - 1:0] m_data;
    bit[VALID_DATA_WIDTH - 1:0] r_data;
    bit[DATA_WIDTH - 1:0] data_send;                                    //发送 PE数据包
    bit[DATA_WIDTH - 1:0] data_rece;                                    //接收 PE数据包
    bit[FILTER_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0] filter_data;        //存放filter数据
	bit[RESULT_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0]  ifmap_data;         //存放mapper数据
	bit[RESULT_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0]  final_data;         //存放最终结果
	bit[VALID_DATA_WIDTH - 1:0] filter_pointer = 0;
	bit[VALID_DATA_WIDTH - 1:0] ifmapper_pointer = 0;
	bit[VALID_DATA_WIDTH - 1:0] final_pointer = 0;
    int round = 0, i, j, k, pooloffset;

    always begin
      result_addr.Receive(r_addr);
      #FL;
      result_data.Send(ifmap_data[r_addr]);
	  #BL;
    end

    always begin
      fork
      datain_filter.Receive(f_data);
      addrin_filter.Receive(f_addr);
      join
      # FL;
      filter_data[f_addr] = f_data;
      //$display("filter data: mem[%d]= %d",f_addr, filter_data[f_addr]);
      $fwrite(fpt,"filter data: mem[%d]= %d\n",f_addr, filter_data[f_addr]);
      if(f_addr == (FILTER_NUM1 * FILTER_NUM1 * NUM_OF_FILTER1 + FILTER_NUM2 * FILTER_NUM2 * NUM_OF_FILTER2) - 1) begin
        filterflag = 1;
      end
    end

    always begin
      fork
      datain_mapper.Receive(m_data);
      addrin_mapper.Receive(m_addr);
      join
      # FL;
      ifmap_data[m_addr] = m_data;
      //$display("mapper data: mem[%d]= %d",m_addr, ifmap_data[m_addr]);
      $fwrite(fpt,"mapper data: mem[%d]= %d\n",m_addr, ifmap_data[m_addr]);
      if(m_addr == (IFMAP_NUM * IFMAP_NUM) - 1) begin
        mapperflag = 1;
      end
    end

    always begin
      tb_addr_in.Receive(data_rece);
      wait(mapperflag == 1 && filterflag == 1);
      if(data_rece[DATA_WIDTH - 1] == 0 && data_rece[DATA_WIDTH - 2] == 1) begin          
      	 rece_index = dataformater::getsendaddr(data_rece);
		 #PACKDEALY;
         ifmapper_pointer = dataformater::unpackdata(data_rece); 
		 #PACKDEALY;
         data_send = dataformater::packdata(index, rece_index, 1, ifmap_data[ifmapper_pointer]);
		 #PACKDEALY;
         tb_addr_out.Send(data_send);
		 #BL;
      end
      else if(data_rece[DATA_WIDTH - 1] == 1 && data_rece[DATA_WIDTH - 2] == 0) begin    
      	 rece_index = dataformater::getsendaddr(data_rece); 
         #PACKDEALY;		 
         filter_pointer = dataformater::unpackdata(data_rece); 
		 #PACKDEALY;
         data_send = dataformater::packdata(index, rece_index, 2, filter_data[filter_pointer]);
		 #PACKDEALY;
         tb_addr_out.Send(data_send);
		 #BL;
      end
      else if(data_rece[DATA_WIDTH - 1] == 0 && data_rece[DATA_WIDTH - 2] == 0) begin  
      	 ifmap_data[final_pointer] = dataformater::unpackdata(data_rece);  
         //$display("-----memory fianl result %d", ifmap_data[final_pointer]);
		 #PACKDEALY;
      	 final_pointer = final_pointer + 1;
         if(final_pointer == DEPTH_R2 * WIDTH_R2 * NUM_OF_FILTER2 && round == 1) begin
          ccToMem.Send(flag);
		  #BL;
          final_pointer = 0; 
          finishflag = 1;
          wait(1 == 0);         
         end
         if(final_pointer == DEPTH_R1 * WIDTH_R1 * NUM_OF_FILTER1 && round == 0) begin
          ccToMem.Send(flag);
		  #BL;
          ccToMem.Receive(flag);
          final_pointer = 0;
          round = round + 1;
         end
      end
      #BL;
    end

    always begin
      wait(poolflag == 1 && finishflag == 1);
      for(integer k = 0; k < NUM_OF_FILTER2; k ++) begin
         pooloffset = k * (WIDTH_POOL * WIDTH_POOL);
         for(integer i = 1; i <= WIDTH_R2; i ++) begin
            for(integer j = 1; j <= DEPTH_R2; j ++) begin
               if(i + 1 <= WIDTH_R2 && final_data[(i + 1) / 4 * 2 + j / 4 + pooloffset] < ifmap_data[final_pointer]) begin
                 final_data[(i + 1) / 4 * 2 + j / 4 + pooloffset] = ifmap_data[final_pointer];
               end
               if(j + 1 <= WIDTH_R2 && final_data[i / 4 * 2 + (j + 1) / 4 + pooloffset] < ifmap_data[final_pointer]) begin
                 final_data[i / 4 * 2 + (j + 1) / 4 + pooloffset] = ifmap_data[final_pointer];
               end
			   if(i + 1 <= WIDTH_R2 && j + 1 <= WIDTH_R2 && final_data[(i + 1) / 4 * 2 + (j + 1) / 4 + pooloffset] < ifmap_data[final_pointer]) begin
			     final_data[(i + 1) / 4 * 2 + (j + 1) / 4 + pooloffset] = ifmap_data[final_pointer];
			   end
               if(final_data[i / 4 * 2 + j / 4 + pooloffset] < ifmap_data[final_pointer]) begin
                 final_data[i / 4 * 2 + j / 4 + pooloffset] = ifmap_data[final_pointer];
               end
               final_pointer = final_pointer + 1;
            end
         end
      end
      for(integer i = 0; i < 12; i ++) begin
        $display("POOL_data[%d] is %d", i, final_data[i]);
      end
      poolflag = 0;
    end

  initial begin
 	#0.1;
    fpt = $fopen("transcript.dump");
    poolflag = 1;
    finishflag = 0;
    index = _index;
    filterflag = 0;
    mapperflag = 0;
    ccToMem.Receive(flag);
	#FL;
  end

endmodule
