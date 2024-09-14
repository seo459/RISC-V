module HybridBranchPredictor(
    input clk,
    input reset,
    input [31:0] pc,
    output prediction,

    input update,                // 업데이트 신호
    input [31:0] update_pc,
    input taken,                 // 실제 브랜치 결과
    input mispredict             // 미스프레딕션 여부
);

    // 파라미터 정의
    parameter PC_INDEX_BITS = 10;         // 로컬 히스토리 테이블 인덱스 비트 수
    parameter GHR_BITS = 12;              // 글로벌 히스토리 레지스터 비트 수

    // 로컬 브랜치 예측기 구성 요소
    reg [9:0] local_history_table [0:(1<<PC_INDEX_BITS)-1];   // 로컬 히스토리 테이블 (10비트 히스토리)
    reg [1:0] local_pht [0:1023];                             // 로컬 패턴 히스토리 테이블 (2비트 saturating counter)

    // 글로벌 브랜치 예측기 구성 요소
    reg [GHR_BITS-1:0] global_history;                        // 글로벌 히스토리 레지스터
    reg [1:0] global_pht [0:(1<<GHR_BITS)-1];                 // 글로벌 패턴 히스토리 테이블

    // 선택기 (Chooser)
    reg [1:0] chooser [0:(1<<GHR_BITS)-1];                    // 선택기 테이블

    // 인덱스 계산
    wire [PC_INDEX_BITS-1:0] pc_index = pc[PC_INDEX_BITS+1:2];  // 로컬 히스토리 테이블 인덱스
    wire [GHR_BITS-1:0] ghr_index = global_history;             // 글로벌 PHT 및 선택기 인덱스

    // 로컬 예측
    wire [9:0] local_history = local_history_table[pc_index];
    wire [1:0] local_counter = local_pht[local_history];
    wire local_pred = local_counter[1];  // MSB 사용

    // 글로벌 예측
    wire [1:0] global_counter = global_pht[ghr_index];
    wire global_pred = global_counter[1];  // MSB 사용

    // 선택기 기반 최종 예측
    wire [1:0] chooser_counter = chooser[ghr_index];
    assign prediction = (chooser_counter[1]) ? global_pred : local_pred;

    // 업데이트 로직
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // 모든 테이블 초기화
            for (i = 0; i < (1<<PC_INDEX_BITS); i = i + 1) begin
                local_history_table[i] <= 10'b0;
            end
            for (i = 0; i < 1024; i = i + 1) begin
                local_pht[i] <= 2'b01;  // 약한 Not Taken으로 초기화
            end
            for (i = 0; i < (1<<GHR_BITS); i = i + 1) begin
                global_pht[i] <= 2'b01; // 약한 Not Taken으로 초기화
                chooser[i] <= 2'b10;    // 글로벌 예측기를 선호하도록 초기화
            end
            global_history <= {GHR_BITS{1'b0}};
        end else if (update) begin
            // 로컬 히스토리 업데이트
            local_history_table[pc_index] <= {local_history[8:0], taken};

            // 로컬 PHT 업데이트
            if (taken) begin
                if (local_pht[local_history] != 2'b11)
                    local_pht[local_history] <= local_pht[local_history] + 1;
            end else begin
                if (local_pht[local_history] != 2'b00)
                    local_pht[local_history] <= local_pht[local_history] - 1;
            end

            // 글로벌 PHT 업데이트
            if (taken) begin
                if (global_pht[ghr_index] != 2'b11)
                    global_pht[ghr_index] <= global_pht[ghr_index] + 1;
            end else begin
                if (global_pht[ghr_index] != 2'b00)
                    global_pht[ghr_index] <= global_pht[ghr_index] - 1;
            end

            // 선택기 업데이트
            if (local_pred != global_pred) begin
                if (global_pred == taken) begin
                    // 글로벌 예측이 맞았을 때
                    if (chooser[ghr_index] != 2'b11)
                        chooser[ghr_index] <= chooser[ghr_index] + 1;
                end else if (local_pred == taken) begin
                    // 로컬 예측이 맞았을 때
                    if (chooser[ghr_index] != 2'b00)
                        chooser[ghr_index] <= chooser[ghr_index] - 1;
                end
            end

            // 글로벌 히스토리 업데이트
            global_history <= {global_history[GHR_BITS-2:0], taken};
        end
    end

endmodule
