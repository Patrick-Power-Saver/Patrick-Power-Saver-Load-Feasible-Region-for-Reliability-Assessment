function [AX, b, betaG, betaT, Gmax_node, line_idx_active] = ...
        generalized_LFR_v3(casename, BS1, GS1, P_ref, use_tight_theta)
% generalized_LFR_v3 - 负荷可行域建模（Bug修复 + 改进Θ算子）
%
% ===================================================================
%  Bug修复说明（相较于 v2）
% ===================================================================
%  原 v2 第125-126行存在两处错误：
%    (1) 该段代码为死代码（立即被128-130行覆盖），但MATLAB仍会先执行
%    (2) max(-Mat,0) .* (Gmax-Gmin)' * ones(nl,1)
%        维度为 [nl×nb] * [nl×1]，当 nb≠nl 时报错（如RBTS: nb=6, nl=9）
%  修复：直接删除125-126行，保留128-130行的正确计算。
%
% ===================================================================
%  改进Θ算子说明（power-balance-constrained Θ，简称PBC-Θ）
% ===================================================================
%  原始Θ算子（论文式2.12-2.14）：
%    b_upper_l = PF_MAX_l + Σ_k max(mat_{lk},0) * Gmax_k
%  问题：将所有正系数机组都设为最大出力，忽略了电力平衡约束
%         Σ_k G_k ≤ P_load（总发电不超过总负荷），导致过度放缩。
%
%  改进PBC-Θ：增加总量约束，求解带功率平衡约束的紧界
%    b_upper_l = PF_MAX_l + max{mat_l·G : 0≤G≤Gmax, 1ᵀG ≤ P_ref}
%  P_ref = 系统峰值负荷（覆盖所有运行场景的保守上界）
%
%  贪心求解（O(nb·log(nb)) per line，无需LP求解器）：
%    按 mat_{lk} 从大到小排序节点，依次按 Gmax_k 填充，
%    直到总量达到 P_ref，其余机组出力为 Gmin_k。
%
%  改进效果：betaG更稀疏（仅饱和机组有非零系数），LFR边界更紧，
%            切负荷计算误差更小，同时保留几何模型优势。
%
% 输入:
%   casename        - 算例名称
%   BS1             - 支路状态向量 (1=正常, 0=故障) [m_line×1]
%   GS1             - 发电机状态向量 (1=正常, 0=故障) [n_gen×1]
%   P_ref           - 功率平衡参考值(pu)，默认=系统峰值负荷之和
%                     设为Inf时退化为原始Θ算子
%   use_tight_theta - true=使用PBC-Θ（默认），false=原始Θ
%
% 输出:
%   AX              - 负荷可行域系数矩阵 Λ  [rows×nb]
%   b               - 右端向量 β            [rows×1]
%   betaG           - 发电容量修正系数矩阵  [rows×nb]
%   betaT           - 线路容量系数矩阵      [rows×nl_active]
%   Gmax_node       - 节点级最大发电容量    [nb×1]
%   line_idx_active - 有效线路在原始branch中的索引

% ====================================================================
%  0. 默认参数
% ====================================================================
if nargin < 4 || isempty(P_ref),           P_ref = [];          end
if nargin < 5 || isempty(use_tight_theta), use_tight_theta = true; end

% ====================================================================
%  1. 加载索引常量
% ====================================================================
[PQ, PV, REF, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
    VA, BASE_KV, VMAX, VMIN, PGMAX,PGMIN,QGMAX,QGMIN,PG,QG, ...
    LOLP,LOLE,LOLF,LOLD,EDNS,EENS, ...
    LAM_P,LAM_Q,MU_VMAX,MU_VMIN,MU_PMAX,MU_PMIN,MU_QMAX,MU_QMIN] = idx_bus;

[GEN_BUS, GEN_PMAX, GEN_PMIN, GEN_QMAX, GEN_QMIN, GEN_STATUS, ...
    GEN_LAMDA,GEN_MTTF,GEN_PG,GEN_QG,GEN_PFAILURE] = idx_gen;

[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE, TAP, SHIFT_ANGLE, BR_STATUS, ...
    BR_LAMDA, BR_MTTF, TCSC_X, BR_PFAILURE, PF, QF, PT, QT, ...
    MU_SF, MU_ST, KT_MAXANGLE_TPST, KT_MINANGLE_TPST, ...
    KT_MAX_X_TCSC, KT_MIN_X_TCSC] = idx_brch;

% ====================================================================
%  2. 读取算例数据，移除故障设备
% ====================================================================
[baseMVA, bus, ~, ~, ~, ~, ~, ~, gen, branch, ~, ~, ~] = feval(casename);

% 列向量化
if size(GS1,2) > size(GS1,1), GS1 = GS1'; end
if size(BS1,2) > size(BS1,1), BS1 = BS1'; end

% 记录有效线路索引
line_idx_active = find(BS1 == 1);
fault_line      = find(BS1 == 0);
fault_gen       = find(GS1 == 0);

branch_cur = branch;
gen_cur    = gen;
if ~isempty(fault_line), branch_cur(fault_line, :) = []; end
if ~isempty(fault_gen),  gen_cur(fault_gen,   :) = []; end

% ====================================================================
%  3. 基本参数
% ====================================================================
nb = size(bus,       1);
nl = size(branch_cur,1);
ng = size(gen_cur,   1);

PF_MAX   = branch_cur(:, RATE) / baseMVA;  % [nl×1]
FrBranch = branch_cur(:, F_BUS);
ToBranch = branch_cur(:, T_BUS);

% 节点-线路关联矩阵 [nb×nl]
Node_Branch = zeros(nb, nl);
for i = 1:nl
    Node_Branch(FrBranch(i), i) =  1;
    Node_Branch(ToBranch(i), i) = -1;
end

% 发电机参数
unit_bus  = gen_cur(:, GEN_BUS);
Pmax_unit = gen_cur(:, GEN_PMAX) / baseMVA;
Pmin_unit = gen_cur(:, GEN_PMIN) / baseMVA;

% 节点-发电机映射矩阵 [nb×ng]
Node_Unit = zeros(nb, ng);
for i = 1:ng
    Node_Unit(unit_bus(i), i) = 1;
end

Gmax_node = Node_Unit * Pmax_unit;   % [nb×1]
Gmin_node = Node_Unit * Pmin_unit;   % [nb×1]

% P_ref 默认取系统峰值总负荷（论文中用于限制总发电量上界）
if isempty(P_ref)
    P_ref = sum(bus(:, PD)) / baseMVA * 1.05;   % 峰值总负荷(pu)
end

% ====================================================================
%  4. PTDF矩阵 [nl×nb]
% ====================================================================
if nl == 0
    % 全部线路故障（孤岛）：无潮流约束
    AX    = -eye(nb);
    b     = zeros(nb, 1);
    betaG = zeros(nb, nb);
    betaT = zeros(nb, 0);
    return;
end

Mat = PTDF(branch_cur, bus, ones(1,nl), nl, nb, 1);

% ====================================================================
%  5. 第一类负荷可行域边界
%  ----------------------------------------------------------------
%  Bug修复：v2 第125-126行
%    原始死代码：max(-Mat,0) .* (Gmax-Gmin)' * ones(nl,1)
%    问题：[nl×nb] * [nl×1] 当 nb≠nl 时维度错误（RBTS: nb=6, nl=9）
%    修复：直接删除该段，使用下方正确的128-130行计算。
%  ----------------------------------------------------------------
%  PBC-Θ改进（仅当 use_tight_theta=true 且 P_ref < Inf）：
%    b_upper_l = PF_MAX_l + max{mat_l·G : Gmin≤G≤Gmax, 1ᵀG≤P_ref}
%    b_lower_l = PF_MAX_l + max{-mat_l·G : Gmin≤G≤Gmax, 1ᵀG≤P_ref}
%  贪心法求解，O(nb·log nb) per line
% ====================================================================
AX_type1 = [-Mat; Mat];                   % [2nl×nb]

if use_tight_theta && P_ref < sum(Gmax_node) - 1e-8
    % --- PBC-Θ改进版 ---
    [b_lower_G, b_upper_G, betaG_lower, betaG_upper] = ...
        pbc_theta(Mat, Gmax_node, Gmin_node, P_ref);
    %  b_upper = PF_MAX + b_upper_G,  b_lower = PF_MAX + b_lower_G
    b_type1     = [PF_MAX + b_lower_G; PF_MAX + b_upper_G];   % [2nl×1]
    betaG_type1 = [betaG_lower;        betaG_upper];           % [2nl×nb]
else
    % --- 原始Θ算子（论文式2.14） ---
    % [BUG FIX] 直接计算，无多余中间变量：
    b_lower     = PF_MAX - Mat*Gmin_node + max(-Mat,0)*(Gmax_node - Gmin_node);
    b_upper     = PF_MAX + Mat*Gmin_node + max( Mat,0)*(Gmax_node - Gmin_node);
    b_type1     = [b_lower; b_upper];                          % [2nl×1]
    betaG_type1 = [max(-Mat,0); max(Mat,0)];                   % [2nl×nb]
end

betaT_type1 = [eye(nl); eye(nl)];         % [2nl×nl]

% ====================================================================
%  6. 第二类负荷可行域边界（孤岛/关键区域，论文2.3.2节）
% ====================================================================
[AX_type2, b_type2, betaG_type2, betaT_type2] = ...
    build_type2_boundaries(bus, branch_cur, Gmax_node, PF_MAX, nb, nl);

% ====================================================================
%  7. 负荷下界（L ≥ 0）
% ====================================================================
AX_lb    = -eye(nb);
b_lb     = zeros(nb, 1);
betaG_lb = zeros(nb, nb);
betaT_lb = zeros(nb, nl);

% ====================================================================
%  8. 合并（论文式2.19-2.23）
% ====================================================================
AX    = [AX_type1;    AX_type2;    AX_lb];
b     = [b_type1;     b_type2;     b_lb];
betaG = [betaG_type1; betaG_type2; betaG_lb];
betaT = [betaT_type1; betaT_type2; betaT_lb];

% 移除全零行（冗余约束）
valid = any(abs(AX) > 1e-10, 2) | (b > 1e-10);
AX    = AX(valid, :);
b     = b(valid);
betaG = betaG(valid, :);
betaT = betaT(valid, :);

end   % ← 主函数结束

% ====================================================================
%  子函数1：PBC-Θ（Power-Balance-Constrained Theta）
%
%  对每条线路 l，求解：
%    max/min  mat_l · G
%    s.t.     Gmin_k ≤ G_k ≤ Gmax_k  ∀k
%             Σ_k G_k ≤ P_ref         （总量约束）
%
%  贪心最优解（线性规划特殊结构，O(nb log nb) per line）：
%    上界：按 mat_{lk} 降序分配 Gmax，直到总量达 P_ref
%    下界：按 mat_{lk} 升序分配 Gmax（等价于 -mat 的上界）
%
%  改进原理：
%    原始Θ假设所有正系数机组均满发，等价于 P_ref=Σ Gmax，
%    用峰值负荷 P_ref < Σ Gmax 可显著收紧边界。
%    例：某线路 mat_l = [0.5, 0.3, -0.2]，Gmax=[50,80,60]，P_ref=100
%      原始Θ: 0.5×50 + 0.3×80 = 49  （忽略平衡约束）
%      PBC-Θ: 贪心分配：节点1先满 50，再分50给节点2
%             bound = 0.5×50 + 0.3×50 = 40  （紧18%）
% ====================================================================
% ====================================================================
%  修正后的 PBC-Θ 逻辑
% ====================================================================
function [b_lower_G, b_upper_G, betaG_lower, betaG_upper] = ...
        pbc_theta(Mat, Gmax_node, Gmin_node, P_ref)

nl = size(Mat, 1);
nb = size(Mat, 2);

b_upper_G   = zeros(nl, 1);
b_lower_G   = zeros(nl, 1);
betaG_upper = zeros(nl, nb);
betaG_lower = zeros(nl, nb);

for l = 1:nl
    coeff = Mat(l, :)';    % [nb×1]

    % --- 右边界: Mat * L <= PF_MAX + Mat * G ---
    % 目标：寻找能提供最大支撑的 G，即 max(Mat * G)
    [val_u, bG_u] = greedy_max(coeff, Gmax_node, Gmin_node, P_ref);
    b_upper_G(l)      = val_u;
    betaG_upper(l, :) = bG_u; % 符号为正：Gmax减小 -> b减小 -> 区域收缩 (正确)

    % --- 左边界: -Mat * L <= PF_MAX - Mat * G ---
    % 目标：寻找能提供最大支撑的 G，即 min(Mat * G)
    % 等价于求解 max(-Mat * G)
    [val_lo, bG_lo] = greedy_max(-coeff, Gmax_node, Gmin_node, P_ref);
    b_lower_G(l)      = val_lo; 
    betaG_lower(l, :) = bG_lo; % 此时 AX 为 -Mat，b 为 PF_MAX + b_lower_G
end
end

% ====================================================================
%  修正后的贪心算子（确保灵敏度 betaG 物理一致）
% ====================================================================
function [obj_val, betaG_row] = greedy_max(coeff, Gmax, Gmin, P_ref)
nb = length(coeff);
G  = Gmin;                            
betaG_row = zeros(1, nb);

% 1. 基础出力贡献
current_sum = sum(Gmin);
remaining = P_ref - current_sum;
remaining = max(remaining, 0);

% 2. 只有系数为正的节点增加出力才能增大目标值
[sorted_c, sort_idx] = sort(coeff, 'descend');

for k = 1:nb
    idx = sort_idx(k);
    if sorted_c(k) <= 0, break; end % 系数非正，不再增加出力

    cap_k = Gmax(idx) - Gmin(idx);
    if cap_k < 1e-10, continue; end

    fill_k = min(cap_k, remaining);
    G(idx) = Gmin(idx) + fill_k;
    
    % 灵敏度修正：
    % 只有当该节点处于“饱和”状态（fill_k = cap_k）且系数为正时，
    % Gmax 的减小才会直接导致目标值 obj_val 的下降。
    if fill_k >= cap_k - 1e-10
        betaG_row(idx) = sorted_c(k); 
    end

    remaining = remaining - fill_k;
    if remaining < 1e-10, break; end
end

obj_val = dot(coeff, G);
end

% ====================================================================
%  子函数3：第二类负荷可行域边界（孤岛+关键区域）
%  论文第2.3.2节，式(2.16)(2.17)(2.18)
% ====================================================================
function [AX2, b2, betaG2, betaT2] = build_type2_boundaries( ...
        bus, branch_cur, Gmax_node, PF_MAX, nb, nl)

% F_BUS=1, T_BUS=2 符合MATPOWER/论文branch矩阵规范
F_BUS_col = 1;
T_BUS_col = 2;

AX2 = zeros(0, nb); b2 = zeros(0,1);
betaG2 = zeros(0, nb); betaT2 = zeros(0, nl);

% -------- BFS求连通分量 --------
adj = false(nb, nb);
for k = 1:nl
    f = branch_cur(k, F_BUS_col);
    t = branch_cur(k, T_BUS_col);
    adj(f,t) = true; adj(t,f) = true;
end

visited    = false(1, nb);
components = {};
for s = 1:nb
    if ~visited(s)
        comp = bfs_nodes(s, adj, nb);
        components{end+1} = comp; %#ok
        visited(comp) = true;
    end
end

% -------- 对每个连通分量建立第二类边界 --------
for c = 1:length(components)
    comp = components{c};

    % 找与该区域相连的外部线路
    ext_lines = [];
    for k = 1:nl
        f    = branch_cur(k, F_BUS_col);
        t    = branch_cur(k, T_BUS_col);
        f_in = ismember(f, comp);
        t_in = ismember(t, comp);
        if xor(f_in, t_in)
            ext_lines(end+1) = k; %#ok
        end
    end

    if isempty(ext_lines)
        % 真正孤岛：Σ_{i∈N} L_i ≤ Σ_{i∈N} Gmax_i （论文式2.17）
        row_AX    = zeros(1, nb); row_AX(comp)    = 1;
        row_betaG = zeros(1, nb); row_betaG(comp) = 1;
        row_betaT = zeros(1, nl);
        row_b     = sum(Gmax_node(comp));

    elseif length(ext_lines) == 1
        % 关键区域（单一外部线路）：式(2.16)
        %   Σ L ≤ Σ Gmax + PT_max
        row_AX    = zeros(1, nb); row_AX(comp)    = 1;
        row_betaG = zeros(1, nb); row_betaG(comp) = 1;
        row_betaT = zeros(1, nl); row_betaT(ext_lines) = 1;
        row_b     = sum(Gmax_node(comp)) + PF_MAX(ext_lines);

    else
        continue   % 多外部线路区域，跳过（非关键区域）
    end

    AX2    = [AX2;    row_AX];    %#ok
    b2     = [b2;     row_b];     %#ok
    betaG2 = [betaG2; row_betaG]; %#ok
    betaT2 = [betaT2; row_betaT]; %#ok
end
end   % build_type2_boundaries

% BFS求单个连通分量
function comp = bfs_nodes(start, adj, nb)
visited = false(1, nb);
queue   = start;
visited(start) = true;
comp    = [];
while ~isempty(queue)
    cur   = queue(1); queue = queue(2:end);
    comp(end+1) = cur; %#ok
    nbrs = find(adj(cur,:) & ~visited);
    visited(nbrs) = true;
    queue = [queue, nbrs]; %#ok
end
end
