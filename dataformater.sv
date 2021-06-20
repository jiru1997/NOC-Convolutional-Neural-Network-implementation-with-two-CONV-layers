//-------------------------------------------------------------------------------------------------
//  Written by JiruXu
//  SystemVerilogCSP: make the data format
//  University of Southern California
//-------------------------------------------------------------------------------------------------


package dataformat;

	class dataformater;
	
        /* 	    
        @name packdata
		@brief pack data into standard format
		@param bit[4:0] senderaddr   sender address
		@param bit[4:0] receaddr     receiver address
		@param bit[1:0] typeofdata   type of data   type = 0 -> data from PE to Adder or Adder to Memory| type = 1 -> data of ifmap | type = 2 -> data of filter | type = 3 -> data from one PE to another PE
		@param bit[7:0] data         data 
		@return bit[19:0] pdata      Standard data  
		*/      
		
		static function bit[19:0] packdata(bit[4:0] senderaddr, bit[4:0] receaddr, bit[1:0] typeofdata, bit[7:0] data);
		  bit[19:0] pdata = {typeofdata, senderaddr, receaddr, data};
		  return pdata;
		endfunction
		
        /* 	    
        @name unpackdata
		@brief unpack data to get the data in it
		@param bit[17:0] inputdata   input data
		@return bit[7:0] unpdata     data in the package
		*/ 		
		
		static function bit[7:0] unpackdata(bit[19:0] inputdata);
		  bit[7:0] unpdata = inputdata[7:0];
		  return unpdata;
		endfunction

		static function bit[4:0] getsendaddr(bit[19:0] inputdata);
		  bit[4:0] unpdata = inputdata[17:13];
		  return unpdata;
		endfunction		

		static function bit[4:0] getreceaddr(bit[19:0] inputdata);
		  bit[4:0] unpdata = inputdata[12:8];
		  return unpdata;
		endfunction		
		
	endclass

endpackage : dataformat
 
// import dataformat::*;
// module tb();

//     bit[3:0] senderaddr;
// 	bit[3:0] receaddr;
// 	bit[1:0] typeofdata;
// 	bit[7:0] data;
// 	bit[17:0] res;
//     bit[7:0] result;

//     initial begin
// 	    senderaddr = 4'b1010;
// 		receaddr = 4'b1111;
// 		typeofdata = 1;
// 		data = 8'b11100001;
		
// 		res = dataformater::packdata(senderaddr, receaddr, typeofdata, data);
// 		$display("data is %b", res);
//         result = dataformater::unpackdata(res);
// 		$display("data is %b", result);
// 		senderaddr = dataformater::getsendaddr(res);
// 		$display("data is %b", senderaddr);
// 		receaddr = dataformater::getreceaddr(res);
// 		$display("data is %b", receaddr);
// 	end
	
// endmodule 
