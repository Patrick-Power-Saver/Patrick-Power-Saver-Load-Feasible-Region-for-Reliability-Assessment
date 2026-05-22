function LFR_lib = build_LFR_library_v2(casename, opts)
% build_LFR_library_v2 - 离线建立负荷可行域库（支持线路+机组联合故障枚举）
%
% ===================================================================
%  相较于 v1 的改进
% ===================================================================
%  v1 只枚举线路故障，机组故障由在线betaG修正处理。
%  v2 同时枚举线路+机组故障组合，使在线阶段可直接命中精确LFR，
%  无需修正（减少在线修正误差，尤其在机组容量大幅变化时更准确）。
%
%  权衡：
%    - 库大小：从 O(C(m,2)) → O(C(m,2) × C(ng,1))，适度增大
%    - 在线精度↑：机组故障状态可直接命中，无需betaG修正
%    - 离线时间↑：但仍为一次性离线代价
%    - 推荐配置：max_gen_order=1（覆盖99%+的机组故障状态）
%
%  键格式：'L{l1}_{l2}_G{g1}_{g2}'
%    纯线路故障：'L1_3_G'（无机组故障，G段为空）
%    纯机组故障：'LG2_5'
%    联合故障：  'L2_G3'
%
% ===================================================================
%  输入参数（opts结构体）
% ===================================================================
%   opts.max_line_order  - 最大线路故障阶数（默认2）
%   opts.max_gen_order   - 最大机组故障阶数（默认1）
%   opts.max_total_order - 线路+机组阶数之和上限（默认3，防止组合爆炸）
%   opts.P_ref           - PBC-Θ功率参考值(pu)（默认=系统峰值负荷）
%   opts.use_tight_theta - 是否使用改进Θ（默认true）
%   opts.verbose         - 打印详细进度（默认true）

% ====================================================================
%  参数处理
% ====================================================================
if nargin < 2, opts = struct(); end

max_line_order  = getfield_default(opts, 'max_line_order',  2);
max_gen_order   = getfield_default(opts, 'max_gen_order',   1);
max_total_order = getfield_default(opts, 'max_total_order', 3);
P_ref           = getfield_default(opts, 'P_ref',           []);
use_tight_theta = getfield_default(opts, 'use_tight_theta', true);
verbose         = getfield_default(opts, 'verbose',         true);

% ====================================================================
%  读取系统基础数据
% ====================================================================
[baseMVA, bus, ~, ~, ~, ~, ~, ~, gen, branch, ~, ~, ~] = feval(casename);

[GEN_BUS, GEN_PMAX, GEN_PMIN, GEN_QMAX, GEN_QMIN, GEN_STATUS, ...
    GEN_LAMDA, GEN_MTTF, GEN_PG, GEN_QG, GEN_PFAILURE] = idx_gen;
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE, TAP, SHIFT_ANGLE, BR_STATUS, BR_LAMDA, ...
    BR_MTTF, TCSC_X, BR_PFAILURE] = idx_brch;

m_line = size(branch, 1);
n_gen  = size(gen,    1);
nb     = size(bus,    1);

% 峰值功率参考（用于PBC-Θ）
if isempty(P_ref)
    P_ref = sum(bus(:, 3)) / baseMVA;   % 峰值总负荷(pu)，bus第3列为PD
end

if verbose
    fprintf('=== 离线建立负荷可行域库 v2（线路+机组联合枚举）===\n');
    fprintf('算例: %s  线路数: %d  机组数: %d\n', casename, m_line, n_gen);
    fprintf('枚举配置：线路≤%d阶，机组≤%d阶，总阶数≤%d\n', ...
            max_line_order, max_gen_order, max_total_order);
    fprintf('PBC-Θ改进: %s，P_ref=%.4f pu\n', ...
            yesno(use_tight_theta), P_ref);
end

% ====================================================================
%  初始化库
% ====================================================================
LFR_lib     = containers.Map('KeyType','char','ValueType','any');
total_built = 0;
total_skip  = 0;
t_start     = tic;

% ====================================================================
%  枚举所有 (线路故障阶数, 机组故障阶数) 组合
%  约束：line_order + gen_order ≤ max_total_order
% ====================================================================
for line_order = 0 : max_line_order
    line_combos = enum_combos(1:m_line, line_order);

    for gen_order = 0 : max_gen_order
        if line_order + gen_order > max_total_order
            continue;   % 超过总阶数限制，跳过
        end

        gen_combos = enum_combos(1:n_gen, gen_order);

        n_pairs = length(line_combos) * length(gen_combos);
        if verbose
            fprintf('  线路%d阶 × 机组%d阶 = %d 个状态\n', ...
                    line_order, gen_order, n_pairs);
        end

        for lc = 1 : length(line_combos)
            fault_lines = line_combos{lc};

            % 孤岛检测：若故障线路造成系统完全断开，负荷可行域退化
            % （此处简化：仍尝试建模，由generalized_LFR_v3内部处理）

            BS1 = ones(m_line, 1);
            if ~isempty(fault_lines), BS1(fault_lines) = 0; end

            for gc = 1 : length(gen_combos)
                fault_gens = gen_combos{gc};

                GS1 = ones(n_gen, 1);
                if ~isempty(fault_gens), GS1(fault_gens) = 0; end

                % 唯一键
                key = make_key(fault_lines, fault_gens);

                if isKey(LFR_lib, key)
                    total_skip = total_skip + 1;
                    continue;
                end

                % 建立LFR
                try
                    [AX, b, betaG, betaT, Gmax0, lidx] = ...
                        generalized_LFR_v3(casename, BS1, GS1, P_ref, use_tight_theta);

                    entry.AX              = AX;
                    entry.b               = b;
                    entry.betaG           = betaG;
                    entry.betaT           = betaT;
                    entry.Gmax0           = Gmax0;
                    entry.line_idx_active = lidx;
                    entry.fault_lines     = fault_lines;
                    entry.fault_gens      = fault_gens;
                    entry.line_order      = line_order;
                    entry.gen_order       = gen_order;

                    LFR_lib(key)  = entry;
                    total_built   = total_built + 1;

                catch ME
                    if verbose
                        warning('LFR建立失败（%s）：%s', key, ME.message);
                    end
                end
            end  % gc
        end  % lc
    end  % gen_order
end  % line_order

elapsed = toc(t_start);
if verbose
    fprintf('\n离线建库完成：\n');
    fprintf('  成功建立: %d 个LFR\n', total_built);
    fprintf('  跳过(重复): %d 个\n', total_skip);
    fprintf('  总耗时: %.2f 秒\n', elapsed);

    % 按阶数统计
    fprintf('  库内存估计: %.1f MB\n', ...
            estimate_memory_MB(LFR_lib));
end
end   % ← 主函数结束

% ====================================================================
%  辅助函数
% ====================================================================

% 生成 k 阶组合的 cell 数组
function combos = enum_combos(items, k)
if k == 0
    combos = {[]};
    return;
end
mat    = nchoosek(items, k);
combos = cell(size(mat,1), 1);
for i = 1:size(mat,1)
    combos{i} = mat(i,:);
end
end

% 生成唯一键：'L{故障线路}_G{故障机组}'
function key = make_key(fault_lines, fault_gens)
if isempty(fault_lines)
    lpart = 'L';
else
    lpart = ['L' sprintf('%d_', sort(fault_lines(:)'))];
end
if isempty(fault_gens)
    gpart = 'G';
else
    gpart = ['G' sprintf('%d_', sort(fault_gens(:)'))];
end
key = [lpart gpart];
end

% 结构体字段默认值获取
function val = getfield_default(s, field, default)
if isfield(s, field) && ~isempty(s.(field))
    val = s.(field);
else
    val = default;
end
end

% 估计库内存（MB）
function mb = estimate_memory_MB(lib)
keys_list = keys(lib);
mb = 0;
for k = 1:min(5, length(keys_list))  % 抽样5个估计
    e = lib(keys_list{k});
    mb = mb + numel(e.AX)*8 + numel(e.b)*8 + ...
              numel(e.betaG)*8 + numel(e.betaT)*8;
end
if ~isempty(keys_list)
    mb = mb / min(5,length(keys_list)) * length(keys_list) / 1e6;
end
end

function s = yesno(flag)
if flag, s='是'; else, s='否'; end
end
