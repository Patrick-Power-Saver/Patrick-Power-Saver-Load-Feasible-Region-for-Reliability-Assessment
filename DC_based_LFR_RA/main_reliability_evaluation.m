%% main_reliability_evaluation.m
% 基于负荷可行域的电力系统可靠性评估主脚本
%
% 完整实现论文第2-3章方法，包含：
%   1. 离线建库（build_LFR_library）
%   2. 在线蒙特卡洛评估（mc_reliability_with_LFR）
%      - 状态去重抽样（改进1）
%      - 充裕性判断 + 近似距离切负荷（改进2）
%      - 解耦修正模型（改进3）
%   3. 对比分析（LFR方法 vs 传统OPF方法的计时对比）
%
% 依赖文件：
%   generalized_LFR_v2.m      - 改进版LFR建模（分离betaG）
%   build_LFR_library.m       - 离线LFR库建立
%   mc_reliability_with_LFR.m - 在线MC评估
%   approx_distance_loadshedding.m - 近似距离切负荷

clear; clc; close all;
fprintf('========================================\n');
fprintf('  基于负荷可行域的电力系统可靠性评估\n');
fprintf('========================================\n\n');

%% ===================================================================
%  用户配置区
% ====================================================================
CASENAME = 'RTS79_1';         % 算例名称（需对应 RBTS.m 等函数文件）
% 配置示例：线路≤2阶，机组≤1阶，总阶数≤3
opts.max_line_order  = 2;
opts.max_gen_order   = 1;
opts.max_total_order = 3;   % 防止组合爆炸
opts.use_tight_theta = false;
CONV_EPS  = 0.01;            % 蒙特卡洛收敛精度 β（论文推荐0.01）
MAX_SAMPLES = 2e6;           % 最大抽样次数

%% ===================================================================
%  读取系统数据，构造负荷向量
% ====================================================================
[baseMVA, bus, ~, ~, ~, ~, ~, ~, gen, branch, ~, ~, ~] = feval(CASENAME);

[PQ, PV, REF, BUS_I, BUS_TYPE, PD, QD, GS, BS, BUS_AREA, VM, ...
    VA, BASE_KV, VMAX, VMIN, PGMAX,PGMIN,QGMAX,QGMIN,PG,QG, ...
    LOLP_idx,LOLE,LOLF,LOLD,EDNS,EENS_idx,~,~,~,~,~,~,~,~] = idx_bus;

% 峰值负荷场景（pu）
L0_peak = bus(:, PD) / baseMVA;
nb = size(bus, 1);

fprintf('系统基本信息：\n');
fprintf('  节点数: %d，线路数: %d，发电机数: %d\n', ...
        nb, size(branch,1), size(gen,1));
fprintf('  峰值总负荷: %.2f MW (%.4f pu)\n', sum(bus(:,PD)), sum(L0_peak));
fprintf('\n');

%% ===================================================================
%  阶段1：离线建立负荷可行域库
%  对应论文3.5节："离线建模-在线评估"框架的离线部分
% ====================================================================
fprintf('--- 阶段1：离线建立负荷可行域库 ---\n');
t_offline = tic;

LFR_lib = build_LFR_library_v2(CASENAME, opts);

t_offline_elapsed = toc(t_offline);
fprintf('离线建库耗时: %.2f 秒\n\n', t_offline_elapsed);

%% ===================================================================
%  阶段2：在线蒙特卡洛可靠性评估
%  对应论文3.5节在线评估部分
% ====================================================================
fprintf('--- 阶段2：在线蒙特卡洛可靠性评估（峰值负荷场景）---\n');

% 配置选项
options.max_samples     = MAX_SAMPLES;
options.conv_eps        = CONV_EPS;
options.conv_check      = 2000;
options.use_OPF_fallback= false;   % 高阶线路故障是否回退OPF
options.verbose         = true;

t_online = tic;
[EENS_pu, LOLP_val, details] = mc_reliability_with_LFR_v3( ...
        CASENAME, LFR_lib, L0_peak, options);
t_online_elapsed = toc(t_online);

% 转换为 MWh（假设评估周期 T=8760h）
T_period = 8760;   % 小时/年
EENS_MWh = EENS_pu * baseMVA * T_period;

fprintf('\n--- 最终可靠性指标 ---\n');
fprintf('  LOLP:      %.6f\n', LOLP_val);
fprintf('  EENS:      %.2f MWh/年\n', EENS_MWh);
fprintf('  在线评估耗时: %.2f 秒\n', t_online_elapsed);
fprintf('  离线建库耗时: %.2f 秒\n', t_offline_elapsed);

%% ===================================================================
%  阶段3：在线逻辑演示（单状态分析示例）
%  对应改进要求2的具体说明
% ====================================================================
fprintf('\n--- 阶段3：在线应用逻辑演示（单状态）---\n');
demo_online_state_analysis(CASENAME, LFR_lib, L0_peak, baseMVA);

%% ===================================================================
%  阶段4：可靠性灵敏度分析（论文第4章，可选）
% ====================================================================
fprintf('\n--- 阶段4：可靠性容量灵敏度分析（可选）---\n');
run_sensitivity_analysis(CASENAME, LFR_lib, L0_peak, baseMVA, ...
                          EENS_pu, details);

%% ===================================================================
%  结果汇总图表
% ====================================================================
plot_reliability_summary(details, EENS_MWh, LOLP_val);

fprintf('\n========================================\n');
fprintf('  评估完成\n');
fprintf('========================================\n');

%% ===================================================================
%  局部函数：在线逻辑演示
% ====================================================================
function demo_online_state_analysis(casename, LFR_lib, L0, baseMVA)
fprintf('演示：输入负荷矩阵 x（峰值负荷），执行充裕性判断和切负荷\n');

% 从库中取第一个有效状态
keys_list = keys(LFR_lib);
if isempty(keys_list)
    fprintf('  LFR库为空，跳过演示\n');
    return;
end

% 演示状态1：正常运行（无故障）
key0 = 'L0';
if isKey(LFR_lib, key0)
    entry = LFR_lib(key0);
    AX = entry.AX;
    b  = entry.b;
else
    entry = LFR_lib(keys_list{1});
    AX = entry.AX;
    b  = entry.b;
end

fprintf('\n[场景A] 正常运行（无故障），峰值负荷\n');
fprintf('  步骤1: 计算 J = max(AX * x - b)\n');
J_A = AX * L0 - b;
J_max_A = max(J_A);
fprintf('  J_max = %.6f\n', J_max_A);
if J_max_A <= 1e-8
    fprintf('  → J ≤ 0：系统充裕，★不失负荷★\n');
else
    fprintf('  → J > 0：系统不充裕，调用近似距离模型\n');
    [Pls_A, ~, kappa_A, ~] = approx_distance_loadshedding(AX, b, L0);
    fprintf('  κmin = %.4f，切负荷 = %.4f pu = %.2f MW\n', ...
            kappa_A, Pls_A, Pls_A * baseMVA);
end

% 演示状态2：重负荷（放大到110%）
L0_heavy = L0 * 1.1;
fprintf('\n[场景B] 重负荷（110%%峰值），相同故障状态\n');
fprintf('  步骤1: 计算 J = max(AX * x_heavy - b)\n');
J_B = AX * L0_heavy - b;
J_max_B = max(J_B);
fprintf('  J_max = %.6f\n', J_max_B);
if J_max_B <= 1e-8
    fprintf('  → J ≤ 0：系统充裕，★不失负荷★\n');
else
    fprintf('  → J > 0：系统不充裕，调用近似距离模型\n');
    [Pls_B, Lc_B, kappa_B, ~] = approx_distance_loadshedding(AX, b, L0_heavy);
    fprintf('  κmin = %.4f，切负荷 = %.4f pu = %.2f MW\n', ...
            kappa_B, Pls_B, Pls_B * baseMVA);
    fprintf('  可供给负荷: [%s] (pu)\n', ...
            num2str(Lc_B', '%.3f '));
end
end

%% ===================================================================
%  局部函数：可靠性容量灵敏度（论文第4章简化版）
%  SEN_k = Σ_s { betaG_ac,k(s) / (Λ_ac(s) * L0) * Pr(s) }
% ====================================================================
function run_sensitivity_analysis(casename, LFR_lib, L0, baseMVA, ...
                                   EENS_base, details)
fprintf('（容量灵敏度分析需要详细的MC状态记录，此处为框架演示）\n');
% 完整实现见 reliability_sensitivity.m
% 核心公式（论文式4.7）：
%   SenCG_k(s) = betaG_ac,i(s) * IG_k(s) / (Λ_ac(s) * L0)
%   SENG_k = T * Σ_s { SenCG_k(s) * Pr(s) }
fprintf('  EENS基准值: %.6f pu/次\n', EENS_base);
fprintf('  如需完整灵敏度，请运行 reliability_sensitivity.m\n');
end

%% ===================================================================
%  局部函数：结果图表
%% ====================================================================
function plot_reliability_summary(details, EENS_MWh, LOLP_val)

figure('Name','可靠性评估结果汇总','Position',[100 100 920 420]);

% --- 子图1：计算时间分解 ---
subplot(1, 2, 1);
times  = [details.t_adequacy, details.t_loadshed, ...
          details.t_correct,  details.t_cache];
labels = {'充裕性判断','切负荷计算','LFR修正','缓存查询'};

% 过滤掉时间为0的项（pie不接受全零）
valid = times > 1e-6;
if any(valid)
    pie(times(valid) + eps, labels(valid));
    title('计算时间分解（在线阶段）','FontSize',12);
else
    text(0.5,0.5,'无计时数据','HorizontalAlignment','center');
    axis off;
end

% --- 子图2：状态分布 ---
subplot(1, 2, 2);
n_LFR_new = max(0, details.n_LFR_used - details.n_cache_hit);
counts  = [details.n_adequate, details.n_cache_hit, n_LFR_new];
labels2 = {'充裕状态（直接跳过）','缓存命中（状态去重）','LFR新建分析'};
colors  = [0.3 0.7 0.3; 0.3 0.5 0.9; 0.9 0.5 0.3];

bar(counts, 'FaceColor','flat');
if sum(counts) > 0
    b_obj = bar(counts);
    b_obj.CData = colors;
end
set(gca,'XTickLabel', labels2,'XTickLabelRotation',12,'FontSize',9);
ylabel('次数'); grid on;
title(sprintf('状态分布（共%d次抽样）', details.n_sample),'FontSize',12);

sgtitle(sprintf('LOLP=%.4f，EENS=%.1f MWh/年', LOLP_val, EENS_MWh), ...
        'FontSize',13,'FontWeight','bold');
end