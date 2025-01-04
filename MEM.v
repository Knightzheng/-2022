`include "lib/defines.vh"
// 访问内存操作
// 可能从EX/MEM流水线寄存器中得到地址读取数据寄存器，并将数据存入MEM/WB流水线寄存器。

// 接收并处理访存的结果，并选择写回结果
// 对于需要访存的指令在此段接收访存结果

module MEM(
    input wire clk,  // 时钟信号，用于同步操作
    input wire rst,  // 重置信号，控制模块复位
    // input wire flush, // 控制信号，流水线刷新，当前注释未使用
    input wire [`StallBus-1:0] stall,  // 控制信号，流水线暂停控制信号

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,  // 从EX阶段传递过来的数据，包含地址、指令类型等信息

    input wire [31:0] data_sram_rdata,  // 从数据存储器读取的数据（32位）
    input wire [3:0] data_ram_sel,     // 数据存储器字节选择信号，用于选择访问的字节（四个字节）
    input wire [`LoadBus-1:0] ex_load_bus,  // 从EX阶段传递的载入指令类型信号，如字节加载（lb, lbu等）

    output wire stallreq_for_load,  // 请求暂停的信号（加载指令时）
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,  // 从MEM阶段传递到WB阶段的数据，包括写回信息
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus  // 从MEM阶段传递到RF阶段的数据，包括写回寄存器的内容
);
    // 寄存器用于保存从EX阶段传递过来的数据
    reg [`LoadBus-1:0] ex_load_bus_r;  // 存储从EX阶段传来的加载指令类型
    reg [3:0] data_ram_sel_r;         // 存储从EX阶段传来的数据存储器字节选择信号

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;  // 存储从EX阶段传来的总线数据
    // 时钟上升沿触发的操作
    always @ (posedge clk) begin
        if (rst) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 复位时将所有寄存器清零
            data_ram_sel_r <= 3'b0;               // 清零数据存储器字节选择信号
            ex_load_bus_r <= `LoadBus'b0;         // 清零加载指令类型信号
        end
        // else if (flush) begin
        //     ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 注释掉的flush逻辑，表示在流水线刷新时清空寄存器
        // end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 如果遇到暂停信号，清空EX/MEM总线寄存器
            data_ram_sel_r <= 3'b0;               // 清空字节选择信号
            ex_load_bus_r <= `LoadBus'b0;         // 清空加载指令类型信号
        end
        else if (stall[3]==`NoStop) begin
            ex_to_mem_bus_r <= ex_to_mem_bus;  // 正常情况下将EX/MEM总线的数据传递到寄存器
            data_ram_sel_r <= data_ram_sel;    // 同步更新数据存储器字节选择信号
            ex_load_bus_r <= ex_load_bus;      // 同步更新加载指令类型信号
        end
    end

    // 定义与内存操作相关的信号
    wire [31:0] mem_pc;  // 当前指令的PC值
    wire data_ram_en;    // 数据存储器使能信号
    wire [3:0] data_ram_wen;  // 数据存储器写使能信号
    wire sel_rf_res;     // 是否选择访存结果作为写回数据
    wire rf_we;          // 寄存器文件写使能信号
    wire [4:0] rf_waddr;  // 寄存器文件写地址
    wire [31:0] rf_wdata;  // 寄存器文件写数据
    wire [31:0] ex_result;  // EX阶段计算的结果
    wire [31:0] mem_result;  // MEM阶段的最终结果

    // load 指令类型信号
    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;

    // 数据存储器访问相关的中间数据
    wire [7:0] b_data;  // 处理字节数据
    wire [15:0] h_data; // 处理半字数据
    wire [31:0] w_data; // 处理字数据

    // 从EX/MEM总线中提取相关的信号
    assign {
        mem_pc,         // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    } =  ex_to_mem_bus_r;

    // 从EX阶段传递的加载指令类型信号，判断是否为字节、半字或字加载
    assign {
        inst_lb,        // 字节加载指令
        inst_lbu,       // 无符号字节加载指令
        inst_lh,        // 半字加载指令
        inst_lhu,       // 无符号半字加载指令
        inst_lw         // 字加载指令
    } = ex_load_bus_r;

// sb指令一次只写入一个字节，所以可能是4'b0001 4'b0010 4'b0100 4'b1000这四种情况，
// 具体选择那种，根据写地址的最低两位addr[1:0]判断。
// 00对应最低位字节(data_sram_wen应为4'b0001)；
// 11对应最高位字节(data_sram_wen应为4'b1000)。
// sh指令类似于sb指令，但其只有两种情况，地址最低两位为00对应低位两个字节(data_sram_wen应为4'b0011)；
// 地址最低两位为10时对应高位两个字节(data_sram_wen应为4'b1100)。

// load类指令与store类指令略有不同，
// 由于这个存储器只配置了片选(4byte)使能和字节写使能，
// 所以读取的时候一律是先读回CPU(此时不区分是哪个load指令)，
// 在MEM段再进行更细分的操作。
// load类指令的字节选择方法和store类相同

    // 处理字节选择逻辑，根据字节选择信号选择相应的字节数据
    assign b_data = data_ram_sel_r[3] ? data_sram_rdata[31:24] : 
                    data_ram_sel_r[2] ? data_sram_rdata[23:16] :
                    data_ram_sel_r[1] ? data_sram_rdata[15: 8] : 
                    data_ram_sel_r[0] ? data_sram_rdata[ 7: 0] : 8'b0;

    // 处理半字选择逻辑，根据字节选择信号选择相应的半字数据
    assign h_data = data_ram_sel_r[2] ? data_sram_rdata[31:16] :
                    data_ram_sel_r[0] ? data_sram_rdata[15: 0] : 16'b0;

    // 处理字数据
    assign w_data = data_sram_rdata;

    // 根据指令类型选择最终的访存结果
    assign mem_result = inst_lb     ? {{24{b_data[7]}},b_data} :
                        inst_lbu    ? {{24{1'b0}},b_data} :
                        inst_lh     ? {{16{h_data[15]}},h_data} :
                        inst_lhu    ? {{16{1'b0}},h_data} :
                        inst_lw     ? w_data : 32'b0; 

    // 根据访存使能信号和选择标志决定写回的数据源
    assign rf_wdata =   sel_rf_res & data_ram_en ? mem_result :  // 如果选择访存结果且使能，则写访存结果
                        ex_result;  // 否则写EX阶段的计算结果

    // 将MEM阶段的结果打包并输出到WB阶段
    assign mem_to_wb_bus = {
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

    // 将MEM阶段的结果打包并输出到RF阶段
    assign mem_to_rf_bus = {
        // mem_pc,     // 69:38 // 注释掉的代码，当前不传送PC到RF
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };

endmodule
