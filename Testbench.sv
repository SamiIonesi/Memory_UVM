interface Memory_itf;
  logic Clk, Reset;
  logic R_W, Valid;
  logic [7:0] Addr;
  logic [31:0] Din;
  logic [31:0] Dout;  
endinterface



class transaction;
  rand bit Operation;
  bit R_W;
  bit Valid;
  randc bit [7:0] Addr;
  randc bit [31:0] Din;
  bit [31:0] Dout;
  
  function void display(input string tag);
    $display("[%0s] -> Operation: %0b, Valid: %0b, Addr: %0h, Din: %0h, Dout: %0h", tag, Operation, Valid, Addr, Din, Dout);
  endfunction
  
  constraint operation_contraint{
    Operation dist {1 :/ 70, 0 :/ 30};
  }
  
  constraint Addr_min{
    Addr inside {[0 : 5]};
  }
endclass


class generator;
  transaction trans;
  mailbox #(transaction) mbx;
  event next;
  event done;
  int count;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    trans = new();
  endfunction
  
  task main();
    repeat(count) begin
      assert(trans.randomize()) else $display("Randomize failed!");
      mbx.put(trans);
      trans.display("GEN");
      @(next);
    end
    ->done;
  endtask
  
endclass



class driver;
  virtual Memory_itf itf;
  transaction trans;
  mailbox #(transaction) mbx;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task Reset();
    itf.Reset <= 1'b0;
    itf.R_W <= 1'b0;
    itf.Valid <= 1'b0;
    itf.Addr <= 8'b0;
    itf.Din <= 32'b0;
    @(posedge itf.Clk);
    itf.Reset <= 1'b1;
    repeat(2) @(posedge itf.Clk);
    itf.Reset <= 1'b0;
    $display("[DRV] -> RESET DONE.");
    $display("---------------------");
  endtask
  
  task Write();
    @(posedge itf.Clk);
    itf.Reset <= 1'b0;
    itf.R_W <= 1'b1;
    itf.Valid <= 1'b1;
    itf.Addr <= trans.Addr;
    itf.Din <= trans.Din;
    @(posedge itf.Clk);
    itf.R_W <= 1'b0;
    itf.Valid <= 1'b0;
    $display("[DRV] -> WRITE.");
    $display("[DRV] -> Data: %0h saved to Address: %0h", itf.Din, itf.Addr);
    @(posedge itf.Clk);
  endtask
  
  task Read();
    @(posedge itf.Clk);
    itf.Reset <= 1'b0;
    itf.R_W <= 1'b0;
    itf.Valid <= 1'b1;
    itf.Addr <= trans.Addr;
    itf.Din <= trans.Din;
    @(posedge itf.Clk);
    itf.R_W <= 1'b0;
    itf.Valid <= 1'b0;
    $display("[DRV] -> READ.");
    $display("[DRV] -> Data read from Address: %0h", itf.Addr);
    @(posedge itf.Clk);
  endtask
  
  task main();
    forever begin
      mbx.get(trans);
      if(trans.Operation == 1)
        Write();
      else
        Read();
    end
  endtask
  
endclass

class monitor;
  virtual Memory_itf itf;
  transaction trans;
  mailbox #(transaction) mbx;
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task main();
    trans = new();
    
    forever begin
      repeat(2) @(posedge itf.Clk);
      trans.R_W = itf.R_W;
      trans.Valid = itf.Valid;
      trans.Addr = itf.Addr;
      trans.Din = itf.Din;
      @(posedge itf.Clk);
      trans.Dout = itf.Dout;
      
      mbx.put(trans);
      $display("[MON] -> R_W: %0b, Valid: %0b, Addr: %0h, Din: %0h, Dout: %0h", trans.R_W, trans.Valid, trans.Addr, trans.Din, trans.Dout);
    end
    
  endtask
  
endclass



class scoreboard;
  transaction trans;
  mailbox #(transaction) mbx;
  event next;
  bit [31:0] memory[255:0];
  
  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction
  
  task main();
    forever begin
      mbx.get(trans);
      $display("[SCO] -> R_W: %0b, Valid: %0b, Addr: %0h, Din: %0h, Dout: %0h", trans.R_W, trans.Valid, trans.Addr, trans.Din, trans.Dout);

      if(trans.Valid == 1)
        if(trans.R_W == 1) begin
          memory[trans.Addr] = trans.Din;
      	  $display("[SCO] -> Data: %0h saved to Address: %0h", trans.Din, trans.Addr);
        end
        else begin
          if(trans.Dout == memory[trans.Addr]) begin
            $display("[SCO] -> Dout(%0h) == memory[%0h](%0h).", trans.Dout, trans.Addr, memory[trans.Addr]);
            $display("[SCO] -> Data matched.");
          end
          else begin
            $display("[SCO] -> Dout(%0h) != memory[%0h](%0h).", trans.Dout, trans.Addr, memory[trans.Addr]);
            $display("[SCO] -> Data mismatched.");
          end
        end
      else
        $display("No command in proccess.");
      
      $display("---------------------------------");
      -> next;
    end
    
  endtask
  
endclass


class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;  // Generator + Driver mailbox
  mailbox #(transaction) msmbx;  // Monitor + Scoreboard mailbox
  event nextgs;
  virtual Memory_itf itf;
  
  function new(virtual Memory_itf itf);
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);
    this.itf = itf;
    drv.itf = this.itf;
    mon.itf = this.itf;
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction
  
  task pre_test();
    drv.Reset();
  endtask
  
  task test();
    fork
      gen.main();
      drv.main();
      mon.main();
      sco.main();
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);  
    $finish();
  endtask
  
  task main();
    pre_test();
    test();
    post_test();
  endtask 
endclass



module testbench();
  
  Memory_itf itf();
  environment env;
  
  Memory DUT(
    .Clk(itf.Clk),
    .Reset(itf.Reset),
    .R_W(itf.R_W),
    .Valid(itf.Valid),
    .Addr(itf.Addr),
    .Din(itf.Din),
    .Dout(itf.Dout)
  );
  
  initial begin
    itf.Clk <= 1'b0;
  end
  
  always #5 itf.Clk <= ~itf.Clk;
  
  initial begin
    env = new(itf);
    env.gen.count = 30;
    env.main();
  end
    
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule