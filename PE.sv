//-------------------------------------------------------------------------------------------------
// PE module 
// submodule : multipler adder split accumulator control
//-------------------------------------------------------------------------------------------------

`timescale 1ns/1fs
import SystemVerilogCSP::*;
import dataformat::*;
module PE
	#(parameter WIDTH = 5,
	parameter FILTER_WIDTH = 3,
	parameter IFMAP_WIDTH = 7,
	parameter DATA_WIDTH = 20,
	parameter VALID_DATA_WIDTH = 8,
	parameter FL = 2,
	parameter BL = 2,
	parameter PACKDEALY = 1)

	( input bit[WIDTH - 1:0] _index,
	  input bit[WIDTH - 1:0] _inner_index,
	  input bit[WIDTH - 1:0] _sum_index,
	  input bit[WIDTH - 1:0] _mem_index,
	  input bit[WIDTH - 1:0] _next_pe_index,
	  input bit[WIDTH - 1:0] _tot_pe_num,
	  input bit[WIDTH - 1:0] _tot_round,
	  input bit[VALID_DATA_WIDTH - 1:0] _filter_pointer,
	  input bit[VALID_DATA_WIDTH - 1:0] _ifmap_pointer,
	  int _result_index,
	  interface RouterToPE_in,
	  interface RouterToPE_out,
	  interface ccToPE);

    bit              beginflag;
    bit[WIDTH - 1:0] index;
    bit[WIDTH - 1:0] inner_index;                         //判断是否需要对到memory中更新数据
	bit[WIDTH - 1:0] sum_index;
	bit[WIDTH - 1:0] mem_index;
	bit[WIDTH - 1:0] next_pe_index;
	bit[WIDTH - 1:0] tot_pe_num;
	bit[WIDTH - 1:0] tot_round;
	bit[VALID_DATA_WIDTH - 1:0] final_result;             //最后运算结果
	bit[DATA_WIDTH - 1:0] data_pass_memory;               //memory数据包
    bit[DATA_WIDTH - 1:0] data_pass_add;                  //add模块数据包
    bit[DATA_WIDTH - 1:0] data_pass_next;                 //next PE数据包
    bit[DATA_WIDTH - 1:0] data_pass_prev;                 //previous PE数据包
	bit[VALID_DATA_WIDTH - 1:0] filter_pointer;           //filter索取指针
	bit[VALID_DATA_WIDTH - 1:0] ifmap_pointer;            //mapper索取指针
	bit[VALID_DATA_WIDTH - 1:0] flag;                     //启动和停止的标志位
	bit[FILTER_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0] filter_data;     //存放三个数据
	bit[FILTER_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0] copyfilter_data; //存放三个数据
	bit[IFMAP_WIDTH - 1:0][VALID_DATA_WIDTH - 1:0]  ifmap_data;       //存放五个数据
    bit[FILTER_WIDTH-1:0] addr_in_filter;
	bit[FILTER_WIDTH-1:0] addr_in_mapper;
	bit filter_renew;
	bit ifmap_renew;
	int i, result_index;

    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  Start ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  Done ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PsumToAdder (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  SplitToPsum (); 
	Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PEToMult_filter (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  PEToMult_mapper (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  MultToAdd (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  AcToAdd ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToAdd (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  AdderToSplit (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToSplit (); 
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  SplitToAc ();  
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  ControlToAc ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  FilterAddr ();
    Channel #(.hsProtocol(P4PhaseBD), .WIDTH(VALID_DATA_WIDTH))  IfmapAddr (); 
    
    multipler #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    mp(.PEToMult_filter(PEToMult_filter), .PEToMult_mapper(PEToMult_mapper), .MultToAdder(MultToAdd));

    adder #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    ad(.MultToAdder (MultToAdd), .AcToAdder(AcToAdd), .PsumToAdder(PsumToAdder), .ControlToAdder(ControlToAdd), .AdderToSplit(AdderToSplit));

    split #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    sp(.AdderToSplit(AdderToSplit), .ControlToSplit(ControlToSplit), .SplitToPsum(SplitToPsum), .SplitToAc(SplitToAc));

    accumulator #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2))
    ac(.SplitToAc(SplitToAc), .ControlToAc(ControlToAc), .AcToAdder(AcToAdd));

    control #(.WIDTH(VALID_DATA_WIDTH), .FL(2), .BL(2), .FILTER_WIDTH(FILTER_WIDTH), .IFMAP_WIDTH(IFMAP_WIDTH))
    cl(.FilterAddr(FilterAddr), .IfmapAddr(IfmapAddr), .ControlToAdd(ControlToAdd), .ControlToAc(ControlToAc), .ControlToSplit(ControlToSplit), .Start (Start), .Done (Done));

	
	//返回给mult map数据
	always begin
	  IfmapAddr.Receive(addr_in_mapper);
	  #FL;
	  wait(ifmap_renew == 1);
	  PEToMult_mapper.Send(ifmap_data[addr_in_mapper]);
	  #BL;
	end
	
	//返回给mult filter数据
	always begin
	  FilterAddr.Receive(addr_in_filter);
	  #FL;
	  wait(filter_renew == 1);
	  PEToMult_filter.Send(filter_data[addr_in_filter]);
	  #BL;
	end	
	
	//不断发送0
	always begin
	  PsumToAdder.Send(0);
	  #BL;
	end
	
	//将最后的结果发送到ADD module
	always begin
	  SplitToPsum.Receive(final_result);
	  data_pass_add = dataformater::packdata(result_index[4:0], sum_index, result_index[6:5], final_result);
	  # PACKDEALY;
	  RouterToPE_out.Send(data_pass_add);
	  //$display("%m final result is %d", final_result);
	  result_index = result_index + 1;
	  #BL;
	end
	
	//监测是否已经完成此次的计算任务
	always begin
	  Done.Receive(flag);
	  tot_round = tot_round - 1;
	  if(tot_round == 0) begin
        ccToPE.Send(flag);
		$display("%m finished work at %t",$time);
		wait(1 == 0);
	  end
	  else begin
	    if(inner_index == 0) begin                                                              // 如果是第一个数据那么要从memory里面重新load数据
		   for(i = 0; i < IFMAP_WIDTH; i = i + 1) begin                                         // 从memory中更新mapper数据
	        data_pass_memory = dataformater::packdata(index, mem_index, 1, ifmap_pointer);
			#PACKDEALY;
		    RouterToPE_out.Send(data_pass_memory);
			#BL;
			RouterToPE_in.Receive(data_pass_memory);
			#FL;
		    ifmap_data[i] = dataformater::unpackdata(data_pass_memory);  
			#PACKDEALY;
		    ifmap_pointer = ifmap_pointer + 1;
		   end
		   ifmap_renew = 1;
		   ifmap_pointer = ifmap_pointer + (FILTER_WIDTH - 1) * IFMAP_WIDTH;

           if(tot_pe_num > 1) begin
			   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin                                        //向下一个模块发送filter数据
				data_pass_next = dataformater::packdata(index, next_pe_index, 3, filter_data[i]);
				#PACKDEALY;
				RouterToPE_out.Send(data_pass_next);
				#BL;
			   end
			   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin                                        //接受上一个模块发送filter数据
				RouterToPE_in.Receive(data_pass_prev);
			    filter_data[i] = dataformater::unpackdata(data_pass_prev); 
                #PACKDEALY;				
			    //$display("receive data from previous filter data %d", filter_data[i]);
			    #FL;
			  end
           end	
		  filter_renew = 1;
		  inner_index = (inner_index - 1 + tot_pe_num) % tot_pe_num;                             //改变inner_index
		  Start.Send(1);  
		  #BL;
		end 
		else begin
		   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin                                        //接受上一个模块发送filter数据
			RouterToPE_in.Receive(data_pass_prev);
		    copyfilter_data[i] = dataformater::unpackdata(data_pass_prev); 
            #PACKDEALY;			
			#FL;	
           end			
		   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin                                        //向下一个模块发送filter数据
			data_pass_next = dataformater::packdata(index, next_pe_index, 3, filter_data[i]);
			#PACKDEALY;
			RouterToPE_out.Send(data_pass_next);
			#BL;
		   end
		   for(i = 0; i < FILTER_WIDTH; i = i + 1) begin
		   	filter_data[i] = copyfilter_data[i];
		   end
           ifmap_renew = 1;
		   filter_renew = 1;
		   inner_index = (inner_index - 1 + tot_pe_num) % tot_pe_num;                                         //改变inner_index
		   Start.Send(1);
           #BL;		   
		end
	  end
	  #FL;
	end 
	
	initial begin
	  #0.1;
	  result_index = _result_index;
	  index = _index;
	  inner_index = _inner_index;
	  sum_index = _sum_index;
	  mem_index = _mem_index;
	  next_pe_index = _next_pe_index;
	  tot_pe_num = _tot_pe_num;
	  tot_round = _tot_round;
	  filter_pointer = _filter_pointer;
	  ifmap_pointer = _ifmap_pointer;
	  filter_renew = 0;
	  ifmap_renew = 0;
	  
	  //初始化filter数据
	  ccToPE.Receive(beginflag);
	  #FL;
	  for(i = 0; i < FILTER_WIDTH; i = i + 1) begin
        data_pass_memory = dataformater::packdata(index, mem_index, 2, filter_pointer);
	    RouterToPE_out.Send(data_pass_memory);
		#BL;
		RouterToPE_in.Receive(data_pass_memory);
		#FL;
	    filter_data[i] = dataformater::unpackdata(data_pass_memory);  
	    //$display("%m filter data: mem[%d]= %d",i, filter_data[i]);
	    filter_pointer = filter_pointer + 1;
	  end
	  filter_renew = 1;
	  filter_pointer = filter_pointer + (FILTER_WIDTH - 1) * IFMAP_WIDTH;

      //初始化mapper数据
	  for(i = 0; i < IFMAP_WIDTH; i = i + 1) begin
        data_pass_memory = dataformater::packdata(index, mem_index, 1, ifmap_pointer);
	    RouterToPE_out.Send(data_pass_memory);
		#BL;
		RouterToPE_in.Receive(data_pass_memory);
		#FL;
	    ifmap_data[i] = dataformater::unpackdata(data_pass_memory);  
	    //$display("%m mapper data: mem[%d]= %d",i, ifmap_data[i]);
	    ifmap_pointer = ifmap_pointer + 1;
	  end
	  ifmap_renew = 1;
	  ifmap_pointer = ifmap_pointer + (FILTER_WIDTH - 1) * IFMAP_WIDTH;
	  //$display("load finish at time %t", $time);
	  Start.Send(1);
	  #BL;
	end
endmodule

//-------------------------------------------------------------------------------------------------
// control module 
// send filter and map address to PE module
//-------------------------------------------------------------------------------------------------
module control
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8,
	  parameter FILTER_WIDTH = 3,
	  parameter IFMAP_WIDTH = 7)

	( interface FilterAddr,
	  interface IfmapAddr,
	  interface ControlToAdd,
	  interface ControlToAc,
	  interface ControlToSplit,
	  interface Start,
	  interface Done );

    int i, j;
    logic [WIDTH-1:0] flag = 8'b00000000;
    logic [WIDTH-1:0] high = 8'b00000001;
    logic [WIDTH-1:0] low =  8'b00000000;

    always begin
    	wait(flag == 1);
	    for(i = 0; i < IFMAP_WIDTH - FILTER_WIDTH + 1; i = i + 1) begin
			ControlToAc.Send(high); 
            for(j = 0; j < FILTER_WIDTH; j = j + 1) begin
            	fork
	                ControlToSplit.Send(low);
					//低电平->数据传回accumulator
	                ControlToAdd.Send(high);
					//高电平->memory数据相加
	                FilterAddr.Send(j);
					//filter地址
	                IfmapAddr.Send(i + j);
					//ifmap地址
	                ControlToAc.Send(low);  
					//split->accumlator
	            join
	            #BL;
            end
            fork
               FilterAddr.Send(0);
	           IfmapAddr.Send(0);    //send two sudoaddress
	           ControlToAc.Send(low);
	           ControlToAdd.Send(low);
	           ControlToSplit.Send(high); 
            join
	    end
	    flag = 0;
	    Done.Send(high);
		#BL;
    end

    always begin
        Start.Receive(flag);
        #FL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// multipler module 
// get data from PE, do multiplication , send to adder module
//-------------------------------------------------------------------------------------------------
module multipler
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface PEToMult_filter,
	  interface PEToMult_mapper,
	  interface MultToAdder);

    logic [WIDTH-1:0] data_filter;
    logic [WIDTH-1:0] data_ifmap;

    always begin
	  fork 
		PEToMult_filter.Receive(data_filter);
		PEToMult_mapper.Receive(data_ifmap);
	  join
	  #FL;
	  MultToAdder.Send(data_filter * data_ifmap);
	  #BL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// adder module 
// receive data from accumulator multiplier and psum
//-------------------------------------------------------------------------------------------------
module adder
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface MultToAdder,
	  interface AcToAdder,
	  interface PsumToAdder,
	  interface ControlToAdder,
	  interface AdderToSplit);

    logic [WIDTH-1:0] data_mult;
    logic [WIDTH-1:0] data_ac;
    logic [WIDTH-1:0] data_psum;
    logic [WIDTH-1:0] contralData;

    always begin
    	fork
            ControlToAdder.Receive(contralData);    //control signal from control module
        	MultToAdder.Receive(data_mult);         //data from mult module
	        AcToAdder.Receive(data_ac);             //data from accumulator module
	        PsumToAdder.Receive(data_psum);       //data from psum
        join
    	# FL;
    	if(contralData == 1) begin
	    	AdderToSplit.Send(data_mult + data_ac);
        end
        else begin
	    	AdderToSplit.Send(data_ac + data_psum);
        end        	
	    # BL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// split module 
// receive data from control and send output to accumulator or psumout
//-------------------------------------------------------------------------------------------------
module split
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface AdderToSplit,
	  interface ControlToSplit,
	  interface SplitToPsum,
	  interface SplitToAc);

    logic [WIDTH-1:0] data_add;
    logic [WIDTH-1:0] contralData;

    always begin
    	fork 
    		AdderToSplit.Receive(data_add);
            ControlToSplit.Receive(contralData);
    	join
    	# FL;
    	if(contralData == 0) begin    //低电平->数据传回accumulator
	    	SplitToAc.Send(data_add);
        end
        else begin
	    	SplitToPsum.Send(data_add);
	    	SplitToAc.Send(data_add);
        end        	
	    # BL;
    end
endmodule

//-------------------------------------------------------------------------------------------------
// accumulator module 
// receive data from split and send to adder
//-------------------------------------------------------------------------------------------------
module accumulator
	#(parameter BL = 2,
	  parameter FL = 4,
	  parameter WIDTH = 8)

	( interface SplitToAc,
	  interface ControlToAc,
	  interface AcToAdder);

    logic [WIDTH-1:0] data_current;
    logic [WIDTH-1:0] controlData;
    logic [WIDTH-1:0] data_previous = 8'b00000000;

    always begin
    	ControlToAc.Receive(controlData);
    	# FL;
    	if(controlData == 0) begin
    		fork
	            SplitToAc.Receive(data_current);
		    	AcToAdder.Send(data_previous);
	        join
	        data_previous = data_current;
        end
        else begin
	    	data_previous = 8'b00000000;
        end        	
	    # BL;
    end
endmodule

