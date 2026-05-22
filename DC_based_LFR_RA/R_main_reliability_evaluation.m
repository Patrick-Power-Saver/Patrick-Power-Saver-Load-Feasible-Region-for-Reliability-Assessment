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
CASENAME = 'RTS79_1';         % trans_opf_case_rbts RTS79_1 trans_opf_case_rts96
% ===================================================================
% --- 核心对比控制选项 ---
opts.rebuild_offline_lib = true;   % 【新增】true=重新生成离线库, false=加载已有库
opts.max_samples         = 2e6;     % 最大抽样次数
opts.conv_eps            = 0.01;    % 变异系数收敛阈值
opts.conv_check          = 2000;    % 每隔多少次检查收敛
opts.verbose             = true;   % 关闭底层的大量打印，保持主控制台整洁
% ------------------------

FIXED_SEED = 2026;  % 固定随机种子，保证在线蒙特卡洛抽到的故障序列绝对一致

% 加载基础负荷场景 (以基态负荷为例，若有连续时序负荷请自行替换)
[baseMVA, bus, ~,~,~,~,~,~,~,~,~,~,~] = feval(CASENAME);

L0 = bus(:, 3) / baseMVA; % 假设第3列为PD

strategies = {'Original_Theta', 'Improved_PBC_Theta'};
results = struct();

fprintf('==================================================\n');
fprintf('  启动 LFR 可靠性评估公平对比测试\n');
fprintf('  算例: %s | 重新建库: %d | 固定种子: %d\n', CASENAME, opts.rebuild_offline_lib, FIXED_SEED);
fprintf('==================================================\n');

for i = 1:length(strategies)
    mode_name = strategies{i};
    fprintf('\n>>> 当前评估策略: [%s]\n', mode_name);
    
    % 根据策略切换算子选项
    if strcmp(mode_name, 'Original_Theta')
        opts.use_tight_theta = false;
    else
        opts.use_tight_theta = true;
    end
    
    % ================================================================
    % 步骤 A: 离线负荷可行域建库 (或加载)
    % ================================================================
    lib_filename = sprintf('LFR_lib_%s_%s.mat', CASENAME, mode_name);
    
    if opts.rebuild_offline_lib || ~exist(lib_filename, 'file')
        fprintf('  [离线阶段] 正在生成 LFR 库 (耗时较长)...\n');
        % 注意：请确保你的 build_LFR_library_v2 内部能接收 opts.use_tight_theta
        % 并传递给 generalized_LFR_v3
        t_build = tic;
        LFR_lib = build_LFR_library_v2(CASENAME, opts);
        time_build = toc(t_build);
        save(lib_filename, 'LFR_lib', 'time_build');
        fprintf('  [离线阶段] 建库完成，已保存至 %s (耗时: %.2fs)\n', lib_filename, time_build);
    else
        fprintf('  [离线阶段] 发现已有缓存库，正在加载 %s...\n', lib_filename);
        load(lib_filename, 'LFR_lib', 'time_build');
        fprintf('  [离线阶段] 加载完成 (原建库耗时: %.2fs)\n', time_build);
    end
    
    % ================================================================
    % 步骤 B: 在线蒙特卡洛评估
    % ================================================================
    fprintf('  [在线阶段] 开始蒙特卡洛抽样...\n');
    
    % 【关键点】在每次策略开始前，重置随机数发生器，确保两套策略面对同样的故障场景
    rng(FIXED_SEED);
    
    t_mc = tic;
    [EENS, LOLP, details] = mc_reliability_with_LFR_v3(CASENAME, LFR_lib, L0, opts);
    time_mc = toc(t_mc);
    
    fprintf('  [在线阶段] 评估完成 (耗时: %.2fs，迭代: %d次)\n', time_mc, details.n_sample);
    
    % ================================================================
    % 步骤 C: 保存该策略的结果
    % ================================================================
    results.(mode_name).LOLP       = LOLP;
    % 转换为 MWh（假设评估周期 T=8760h）
    T_period = 8760;   % 小时/年
    results.(mode_name).EENS       = EENS * baseMVA * T_period;
    results.(mode_name).details    = details;
    results.(mode_name).time_build = time_build;
    results.(mode_name).time_mc    = time_mc;
    
    %% ===================================================================
    %  阶段3：在线逻辑演示（单状态分析示例）
    %  对应改进要求2的具体说明
    % ====================================================================
    fprintf('\n--- 阶段3：在线应用逻辑演示（单状态）---\n');
    demo_online_state_analysis(CASENAME, LFR_lib, L0, baseMVA);
    
    %% ===================================================================
    %  阶段4：可靠性灵敏度分析（论文第4章，可选）
    % ====================================================================
    fprintf('\n--- 阶段4：可靠性容量灵敏度分析（可选）---\n');
    run_sensitivity_analysis(CASENAME, LFR_lib, L0, baseMVA, ...
        EENS, details);
    
    %% ===================================================================
    %  结果汇总图表
    % ====================================================================
    plot_reliability_summary(details, results.(mode_name).EENS, LOLP);
    
    fprintf('\n========================================\n');
    fprintf('  评估完成\n');
    fprintf('========================================\n');
end

% ====================================================================
% 结果对比与打印
% ====================================================================
fprintf('\n==================================================\n');
fprintf('                  对比测试结果汇总\n');
fprintf('==================================================\n');
fprintf('%-20s | %-10s | %-12s | %-10s | %-10s\n', ...
    '策略', 'LOLP', 'EENS(pu)', '建库耗时(s)', '抽样耗时(s)');
fprintf('------------------------------------------------------------------\n');

for i = 1:length(strategies)
    m = strategies{i};
    fprintf('%-20s | %-10.6f | %-12.4f | %-10.2f | %-10.2f\n', ...
        m, results.(m).LOLP, results.(m).EENS, ...
        results.(m).time_build, results.(m).time_mc);
end
fprintf('==================================================\n');

% 提取一些关键底层指标对比
hit_rate_orig = results.Original_Theta.details.n_cache_hit / results.Original_Theta.details.n_sample;
hit_rate_impr = results.Improved_PBC_Theta.details.n_cache_hit / results.Improved_PBC_Theta.details.n_sample;

fprintf('\n诊断信息对比:\n');
fprintf('缓存命中率: 原始 = %.2f%%, 改进 = %.2f%%\n', hit_rate_orig*100, hit_rate_impr*100);
fprintf('充裕状态数: 原始 = %d, 改进 = %d\n', results.Original_Theta.details.n_adequate, results.Improved_PBC_Theta.details.n_adequate);

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