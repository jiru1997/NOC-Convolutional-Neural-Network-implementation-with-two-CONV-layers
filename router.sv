`timescale 1ns/1ps

import SystemVerilogCSP::*;
import dataformat::*;

module router(interface p_in, p_out, ch1_in, ch1_out, ch2_in, ch2_out);

	parameter left_min = 1;
	parameter right_max = 13;
	parameter router_add = 2;
	parameter WIDTH_pack = 20;
	parameter WIDTH_add = 5;
	parameter WIDTH_data = 8;
	parameter WIDTH_type = 2;
	parameter CACHE_DEPTH = 25;
	parameter FL = 1;
	parameter BL = 1;
	parameter PACKDELAY = 1;
	
	logic [WIDTH_pack-1 : 0] pack;
	logic [WIDTH_add-1 : 0] receiver_add, sender_add;
	logic [WIDTH_pack-1 : 0] data, data_p, data_ch1, data_ch2;
	logic [WIDTH_type-1 : 0] typeofdata;
	bit[CACHE_DEPTH:0][WIDTH_pack - 1:0] parent_cache;     
	bit[CACHE_DEPTH:0][WIDTH_pack - 1:0] ch1_cache;       
	bit[CACHE_DEPTH:0][WIDTH_pack - 1:0] ch2_cache;
	integer parent_cache_head = 0, parent_cache_tail = 0;
	integer ch1_cache_head = 0, ch1_cache_tail = 0;
	integer ch2_cache_head = 0, ch2_cache_tail = 0;
	bit state = 0;
	int fpt;

	initial begin
	data = 0;
	data_p = 0;
	data_ch1 = 0;
	data_ch2 = 0;
	end

	always begin
		p_in.Receive(data_p);
		$fwrite(fpt,"%m data %b received at router %d, at time %t\n", data_p, router_add, $realtime);
		//$display("%m data %b received at router %d, at time %t", data_p, router_add, $realtime);
	    if((parent_cache_tail + 1) % (CACHE_DEPTH + 1) == parent_cache_head) begin
		    $display("router %d parent cache is full", router_add);
			$stop();
		end
		parent_cache[parent_cache_tail] = data_p;
		
		if(parent_cache_tail + 1 == (CACHE_DEPTH + 1)) begin
			parent_cache_tail = 0;
		end
		else begin
			parent_cache_tail = parent_cache_tail + 1;
		end
		#FL;
	end

	always begin
		ch1_in.Receive(data_ch1);
		if((ch1_cache_tail + 1) % (CACHE_DEPTH + 1) == ch1_cache_head) begin
		    $display("router %d child1 cache is full", router_add);
			$stop();
		end
		ch1_cache[ch1_cache_tail] = data_ch1;

		if(ch1_cache_tail + 1 == (CACHE_DEPTH + 1)) begin
			ch1_cache_tail = 0;
		end 
		else begin
		    ch1_cache_tail = ch1_cache_tail + 1;
		end
		#FL;
	end

	always begin
        ch2_in.Receive(data_ch2);
		if((ch2_cache_tail + 1) % (CACHE_DEPTH + 1) == ch2_cache_head) begin
			$display("router %d child2 cache is full", router_add);
			$stop();
		end
		ch2_cache[ch2_cache_tail] = data_ch2;
		if(ch2_cache_tail + 1 == (CACHE_DEPTH + 1)) begin
			ch2_cache_tail = 0;
		end
		else begin
			ch2_cache_tail = ch2_cache_tail + 1;
		end
		#BL;
	end

	always begin
	  wait(state == 0 && parent_cache_head != parent_cache_tail);
      state = 1;
	  receiver_add = dataformater::getreceaddr(parent_cache[parent_cache_head]);
	  #PACKDELAY;
	  if(receiver_add > router_add) begin
		ch2_out.Send(parent_cache[parent_cache_head]);
		$fwrite(fpt,"data %b is sent from router %d to it's child2 at time\n", parent_cache[parent_cache_head], router_add, $realtime);
		//$display("data %b is sent from router %d to it's child2 at time", parent_cache[parent_cache_pointer], router_add, $realtime);
	  end
	  else begin
		ch1_out.Send(parent_cache[parent_cache_head]);
		$fwrite(fpt,"data %b is sent from router %d to it's child2 at time\n", parent_cache[parent_cache_head], router_add, $realtime);
		//$display("data %b is sent from router %d to it's child1 at time", parent_cache[parent_cache_pointer], router_add, $realtime);
	  end
	  if(parent_cache_head + 1 == (CACHE_DEPTH + 1)) begin
		 parent_cache_head = 0;
	  end 
	  else begin
		 parent_cache_head = parent_cache_head + 1;
	  end
	  state = 0;
	  #BL;
	end

	always begin
	  wait(state == 0 && ch1_cache_head != ch1_cache_tail);
	  state = 1;
	  receiver_add = dataformater::getreceaddr(ch1_cache[ch1_cache_head]);
	  #PACKDELAY;
	  if((receiver_add > right_max) || (receiver_add < left_min)) begin
		  p_out.Send(ch1_cache[ch1_cache_head]);
		  $fwrite(fpt,"data %b is sent from router %d to it's parent at time\n", ch1_cache[ch1_cache_head], router_add, $realtime);
			  //$display("data %b is sent from router %d to it's parent at time", ch1_cache[ch1_cache_pointer], router_add, $realtime);
	  end
	  else begin
		  ch2_out.Send(ch1_cache[ch1_cache_head]);
		  $fwrite(fpt,"data %b is sent from router %d to it's child2 at time\n", ch1_cache[ch1_cache_head], router_add, $realtime);
			  //$display("data %b is sent from router %d to it's child2 at time", ch1_cache[ch1_cache_pointer], router_add, $realtime);
      end
	  if(ch1_cache_head + 1 == (CACHE_DEPTH + 1)) begin
		 ch1_cache_head = 0;
	  end 
	  else begin
	  	 ch1_cache_head = ch1_cache_head + 1;
	  end
	  state = 0;
	  #BL;
	end

	always begin
	  wait(state == 0 && ch2_cache_head != ch2_cache_tail);
      state = 1;
	  receiver_add = dataformater::getreceaddr(ch2_cache[ch2_cache_head]);
	  #PACKDELAY;
	  if((receiver_add > right_max) || (receiver_add < left_min)) begin
		  p_out.Send(ch2_cache[ch2_cache_head]);
		  $fwrite(fpt,"data %b is sent from router %d to it's parent (dest address is %d) at time\n", ch2_cache[ch2_cache_head], router_add, receiver_add, $realtime);	
		  //$display("data %b is sent from router %d to it's parent (dest address is %d) at time", ch2_cache[ch2_cache_pointer], router_add, receiver_add, $realtime);
	  end
	  else begin
		  ch1_out.Send(ch2_cache[ch2_cache_head]);
		  $fwrite(fpt,"data %b is sent from router %d to it's child1 (dest address is %d) at time\n", ch2_cache[ch2_cache_head], router_add, receiver_add, $realtime);
		  //$display("data %b is sent from router %d to it's child1 (dest address is %d) at time", ch2_cache[ch2_cache_pointer], router_add, receiver_add, $realtime);
	  end
	  if(ch2_cache_head + 1 == (CACHE_DEPTH + 1)) begin
		 ch2_cache_head = 0;
	  end 
	  else begin
		  ch2_cache_head = ch2_cache_head + 1;
	  end
	  state = 0;
	  #BL;
	end

	initial begin
	  fpt = $fopen("transcript.dump");
	end
endmodule


module router_top(interface ch1_in, ch1_out, ch2_in, ch2_out);

	parameter router_add = 8;
	parameter WIDTH_pack = 20;
	parameter WIDTH_add = 5;
	parameter WIDTH_data = 8;
	parameter WIDTH_type = 2;
	parameter CACHE_DEPTH = 25;
	parameter FL = 1;
	parameter BL = 1;
	parameter PACKDELAY = 1;

	logic [WIDTH_pack-1 : 0] pack;
	logic [WIDTH_add-1 : 0] receiver_add, sender_add;
	logic [WIDTH_pack-1 : 0] data, data_ch1, data_ch2;
	logic [WIDTH_type-1 : 0] typeofdata;
    bit[CACHE_DEPTH:0][WIDTH_pack - 1:0] ch1_cache;       
	bit[CACHE_DEPTH:0][WIDTH_pack - 1:0] ch2_cache;
	bit state = 0;
	integer ch1_cache_head = 0, ch1_cache_tail = 0;
	integer ch2_cache_head = 0, ch2_cache_tail = 0;
	int fpt; 

	initial begin
	fpt = $fopen("transcript.dump");
	data = 0;
	data_ch1 = 0;
	data_ch2 = 0;
	end

	always begin
		ch1_in.Receive(data_ch1);
		if((ch1_cache_tail + 1) % (CACHE_DEPTH + 1) == ch1_cache_head) begin
		    $display("router %d child1 cache is full", router_add);
			$stop();
		end
		ch1_cache[ch1_cache_tail] = data_ch1;

		if(ch1_cache_tail + 1 == (CACHE_DEPTH + 1)) begin
			ch1_cache_tail = 0;
		end 
		else begin
		    ch1_cache_tail = ch1_cache_tail + 1;
		end
		#FL;
	end

	always begin
        ch2_in.Receive(data_ch2);
		if((ch2_cache_tail + 1) % (CACHE_DEPTH + 1) == ch2_cache_head) begin
			$display("router %d child2 cache is full", router_add);
			$stop();
		end
		ch2_cache[ch2_cache_tail] = data_ch2;
		if(ch2_cache_tail + 1 == (CACHE_DEPTH + 1)) begin
			ch2_cache_tail = 0;
		end
		else begin
			ch2_cache_tail = ch2_cache_tail + 1;
		end
		#FL;
	end

	always begin
	  wait(state == 0 && ch1_cache_head != ch1_cache_tail);
	  state = 1;
	  receiver_add = dataformater::getreceaddr(ch1_cache[ch1_cache_head]);
	  #PACKDELAY;
	  ch2_out.Send(ch1_cache[ch1_cache_head]);
	  if(ch1_cache_head + 1 == (CACHE_DEPTH + 1)) begin
		 ch1_cache_head = 0;
	  end 
	  else begin
	  	 ch1_cache_head = ch1_cache_head + 1;
	  end
	  state = 0;
	  #BL;
	end

	always begin
	  wait(state == 0 && ch2_cache_head != ch2_cache_tail);
      state = 1;
	  receiver_add = dataformater::getreceaddr(ch2_cache[ch2_cache_head]);
	  #PACKDELAY;
	  ch1_out.Send(ch2_cache[ch2_cache_head]);
	  if(ch2_cache_head + 1 == (CACHE_DEPTH + 1)) begin
		 ch2_cache_head = 0;
	  end 
	  else begin
		  ch2_cache_head = ch2_cache_head + 1;
	  end
	  state = 0;
	  #BL;
	end
endmodule
