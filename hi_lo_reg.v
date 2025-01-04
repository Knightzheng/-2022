`include "lib/defines.vh"
// hi和lo属于协处理器，不在通用寄存器的范围内。
// 这两个寄存器主要是在用来处理乘法和除法。
// 以乘法作为示例，如果两个整数相乘，那么乘法的结果低位保存在lo寄存器，高位保存在hi寄存器。
// 当然，这两个寄存器也可以独立进行读取和写入。读的时候，使用mfhi、mflo；写入的时候，用mthi、mtlo。
// 和通用寄存器不同，mfhi、mflo是在执行阶段才开始从hi、lo寄存器获取数值的。写入则和通用寄存器一样，也是在写回的时候完成的。

module hi_lo_reg(
    input wire clk,  // 时钟信号，用于同步模块操作
    input wire [`StallBus-1:0] stall,  // 控制信号，是否暂停模块操作
    input wire hi_we,  // 控制信号，是否写入到 hi 寄存器
    input wire lo_we,  // 控制信号，是否写入到 lo 寄存器
    input wire [31:0] hi_wdata,  // 要写入 hi 寄存器的数据（32 位）
    input wire [31:0] lo_wdata,  // 要写入 lo 寄存器的数据（32 位）
    output wire [31:0] hi_rdata,  // 读取 hi 寄存器的输出（32 位）
    output wire [31:0] lo_rdata   // 读取 lo 寄存器的输出（32 位）
);

    // 定义 32 位宽的寄存器用于存储 hi 和 lo 的值
    reg [31:0] reg_hi;
    reg [31:0] reg_lo;

    // 在时钟的上升沿进行操作
    always @ (posedge clk) begin
        // 如果同时写入 hi 和 lo 寄存器
        if (hi_we & lo_we) begin
            reg_hi <= hi_wdata;  // 将 hi_wdata 写入到 reg_hi
            reg_lo <= lo_wdata;  // 将 lo_wdata 写入到 reg_lo
        end
        // 如果只写入 lo 寄存器
        if (~hi_we & lo_we) begin
            reg_lo <= lo_wdata;  // 将 lo_wdata 写入到 reg_lo
        end
        // 如果只写入 hi 寄存器
        if (hi_we & ~lo_we) begin
            reg_hi <= hi_wdata;  // 将 hi_wdata 写入到 reg_hi
        end
    end

    // 将寄存器值输出到对应的外部信号
    assign hi_rdata = reg_hi;  // 输出 reg_hi 的值到 hi_rdata
    assign lo_rdata = reg_lo;  // 输出 reg_lo 的值到 lo_rdata

    // always @ (posedge clk) begin
    //     if (rst) begin
    //         reg_hi <= 32'b0;
    //         reg_lo <= 32'b0;
    //     end
    //     else if (wb_lo_we) begin
    //         reg_hi <= wb_hi_in;
    //         reg_lo <= wb_lo_in;
    //     end
    // end



endmodule