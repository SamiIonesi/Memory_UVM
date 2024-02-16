module Memory 
  #(parameter WIDTH = 8, parameter DinLENGTH = 32, parameter MemorySIZE = 2 ** WIDTH)
(Din, Addr, R_W, Valid, Reset, Clk, Dout);
    input Reset, Clk, R_W, Valid;
    input [WIDTH - 1:0] Addr;
    input [DinLENGTH - 1:0] Din;
    output reg [DinLENGTH - 1:0] Dout;
    
  reg [DinLENGTH - 1:0] memory [0:MemorySIZE - 1];
    shortint counter;
    
    always @(posedge Clk or posedge Reset) begin
        if(Reset) begin
            counter = 0;
            while(counter < MemorySIZE) begin
                memory[counter] <= 32'h0;
                counter++;
            end
            Dout <= 32'h0;
        end 
        else begin
            if(Valid) begin
                if(R_W) begin
                    memory[Addr] <= Din;
                    Dout <= 32'h0;
                end
                else begin
                    Dout <= memory[Addr];
                end
            end
            else begin
                Dout <= 32'h0;
            end          
        end
    end
endmodule
