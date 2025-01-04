`include "lib/defines.vh" 
// 将结果写回寄存器
// 从MEM/WB流水线寄存器中读取数据并将它写回图中部的寄存器堆中。

// 和IF段类似，暂时没有需要改动的东西

module WB(
    input wire clk,  // 时钟信号，用于同步操作
    input wire rst,  // 重置信号，控制模块复位
    // input wire flush, // 控制信号，流水线刷新，当前注释未使用
    input wire [`StallBus-1:0] stall,  // 控制信号，流水线暂停控制信号

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // 从MEM阶段传递到WB阶段的总线数据，包括写回寄存器的地址、数据等

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,  // 输出到寄存器文件的总线数据，包括写使能、写地址和写数据

    output wire [31:0] debug_wb_pc,  // 调试信号，记录当前指令的PC值
    output wire [3:0] debug_wb_rf_wen,  // 调试信号，记录写使能信号的状态
    output wire [4:0] debug_wb_rf_wnum,  // 调试信号，记录写回寄存器的地址
    output wire [31:0] debug_wb_rf_wdata  // 调试信号，记录写回寄存器的值
);

    // MEM/WB阶段总线数据寄存器，保存从MEM阶段传递过来的数据
    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;  

    // 时钟上升沿触发的操作
    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // 复位时将总线寄存器清零
        end
        // else if (flush) begin
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // 注释掉的flush逻辑，表示在流水线刷新时清空寄存器
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;  // 遇到暂停信号时清空总线寄存器
        end
        else if (stall[4]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;  // 正常情况下将MEM/WB总线的数据传递到寄存器
        end
    end

    // 从MEM/WB总线寄存器中解包出各个信号
    wire [31:0] wb_pc;    // 写回的PC值
    wire rf_we;           // 寄存器文件写使能信号
    wire [4:0] rf_waddr;  // 寄存器文件写地址
    wire [31:0] rf_wdata; // 寄存器文件写数据

    // 从mem_to_wb_bus_r中提取写回所需的信号
    assign {
        wb_pc,        // 当前指令的PC值
        rf_we,        // 寄存器写使能信号
        rf_waddr,     // 寄存器写地址
        rf_wdata      // 寄存器写数据
    } = mem_to_wb_bus_r;

    // 将处理后的信号打包成输出总线wb_to_rf_bus，传递给寄存器文件
    assign wb_to_rf_bus = {
        rf_we,        // 寄存器写使能信号
        rf_waddr,     // 寄存器写地址
        rf_wdata      // 寄存器写数据
    };

    // 用于调试的信号，输出当前指令的PC值
    assign debug_wb_pc = wb_pc;

    // 用于调试的信号，记录写使能信号的状态，若写使能信号为1，则设置为4'b1111
    assign debug_wb_rf_wen = {4{rf_we}};  

    // 用于调试的信号，输出寄存器文件写回的寄存器地址
    assign debug_wb_rf_wnum = rf_waddr;

    // 用于调试的信号，输出寄存器文件写回的数据
    assign debug_wb_rf_wdata = rf_wdata;

endmodule
