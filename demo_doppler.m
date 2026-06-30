%% FHSS_4FSK 多普勒频移演示
% 对比无多普勒、小多普勒和大多普勒下的性能差异

clear; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║   FHSS_4FSK 多普勒频移仿真演示                             ║\n');
fprintf('║   对比多普勒效应对性能的影响                               ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

%% 仿真参数
g = 200;              % 比特数
fs = 100000;          % 采样率 (Hz)
snrDb = 15;           % 信噪比
delay = 5000;         % 自延迟多径（50ms）
seed = 42;            % 随机种子

fprintf('📊 基础参数：\n');
fprintf('   • 比特数: %d\n', g);
fprintf('   • 采样率: %d Hz\n', fs);
fprintf('   • SNR: %d dB\n', snrDb);
fprintf('   • 自延迟多径: %d 样本\n\n', delay);

%% 多普勒频移场景
doppler_values = [0, 25, 50, 100];  % Hz

fprintf('🌊 多普勒频移场景说明：\n');
fprintf('   假设水声通信系统，声速 c ≈ 1500 m/s，载波 f ≈ 14 kHz\n');
fprintf('   多普勒频移 fd ≈ v * f / c，其中 v 是相对速度\n\n');
fprintf('   • 0 Hz: 静止（无多普勒）\n');
fprintf('   • 25 Hz: v ≈ 2.7 m/s (轻微靠近)\n');
fprintf('   • 50 Hz: v ≈ 5.4 m/s (中等靠近)\n');
fprintf('   • 100 Hz: v ≈ 10.7 m/s (高速靠近)\n\n');

%% =====================================================================
% 仿真不同多普勒频移下的性能
%% =====================================================================

fprintf('🔬 运行仿真...\n\n');

results = cell(length(doppler_values), 1);
ber_values = zeros(length(doppler_values), 1);
ser_values = zeros(length(doppler_values), 1);

for i = 1:length(doppler_values)
    doppler = doppler_values(i);
    
    if doppler == 0
        fprintf('【%d/%d】 无多普勒 (0 Hz)', i, length(doppler_values));
    else
        fprintf('【%d/%d】 多普勒 = %d Hz', i, length(doppler_values), doppler);
    end
    
    tic;
    result = fhss_4fsk_simulate_doppler(g, fs, snrDb, delay, seed, false, doppler);
    elapsed = toc;
    
    results{i} = result;
    ber_values(i) = result.ber;
    ser_values(i) = result.ser;
    
    fprintf(' ... ');
    if ber_values(i) == 0
        fprintf('✓ 完全正确 (耗时: %.2f秒)\n', elapsed);
    else
        fprintf('✓ BER: %.4f, SER: %.4f (耗时: %.2f秒)\n', ber_values(i), ser_values(i), elapsed);
    end
end

fprintf('\n');

%% =====================================================================
% 性能对比表
%% =====================================================================

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('📈 性能对比汇总\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

fprintf('  多普勒 (Hz) | BER      | SER      | 性能劣化 | 相对速度\n');
fprintf('  ─────────────|──────────|──────────|────────--|─────────────\n');

for i = 1:length(doppler_values)
    doppler = doppler_values(i);
    if doppler == 0
        fprintf('  %5d      | %.4f  | %.4f  |   -    | 0 m/s\n', doppler, ber_values(i), ser_values(i));
        baseline_ber = ber_values(i);
        baseline_ser = ser_values(i);
    else
        % 计算性能劣化（相对于无多普勒情况）
        ber_degradation = (ber_values(i) - baseline_ber) / max(baseline_ber, 1e-6) * 100;
        % 估计相对速度 v = doppler * c / f
        v_est = doppler * 1500 / 14000;
        fprintf('  %5d      | %.4f  | %.4f  | %6.1f%% | %.1f m/s\n', ...
            doppler, ber_values(i), ser_values(i), ber_degradation, v_est);
    end
end

fprintf('\n');

%% =====================================================================
% 绘制性能对比
%% =====================================================================

figure('Name', '多普勒频移影响分析', 'NumberTitle', 'off', 'Position', [100 100 1200 600]);

% BER 对比
subplot(2, 2, 1);
plot(doppler_values, ber_values, 'o-', 'LineWidth', 2, 'MarkerSize', 10);
grid on;
xlabel('多普勒频移 (Hz)', 'FontSize', 11);
ylabel('比特错误率 (BER)', 'FontSize', 11);
title('多普勒频移对BER的影响', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 10);

% SER 对比
subplot(2, 2, 2);
plot(doppler_values, ser_values, 's-', 'LineWidth', 2, 'MarkerSize', 10, 'Color', 'r');
grid on;
xlabel('多普勒频移 (Hz)', 'FontSize', 11);
ylabel('符号错误率 (SER)', 'FontSize', 11);
title('多普勒频移对SER的影响', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 10);

% 相关能量分析
subplot(2, 2, 3);
legend_labels = cell(length(doppler_values), 1);
for i = 1:length(doppler_values)
    doppler = doppler_values(i);
    plot(1:20, results{i}.residualEnergyTrace(1:20, :), '-', 'LineWidth', 1.2);
    hold on;
    if doppler == 0
        legend_labels{i} = 'Doppler=0 Hz';
    else
        legend_labels{i} = sprintf('Doppler=%d Hz', doppler);
    end
end
hold off;
grid on;
xlabel('符号序号', 'FontSize', 11);
ylabel('相关能量', 'FontSize', 11);
title('4个候选频点的相关能量对比（前20符号）', 'FontSize', 12, 'FontWeight', 'bold');
legend(legend_labels, 'FontSize', 9);
set(gca, 'FontSize', 10);

% 频谱对比（无多普勒 vs 大多普勒）
subplot(2, 2, 4);
Plot_f(results{1}.noisySignal, fs);
hold on;
title('信号频谱对比：黑线=无多普勒，蓝线=50Hz多普勒', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'FontSize', 10);

sgtitle(sprintf('多普勒频移影响分析 (SNR=%.0f dB, delay=%d)', snrDb, delay), ...
    'FontSize', 13, 'FontWeight', 'bold');

%% =====================================================================
% 时域波形对比（无多普勒 vs 50Hz多普勒）
%% =====================================================================

figure('Name', '时域波形对比', 'NumberTitle', 'off', 'Position', [100 750 1200 400]);

numSamplesToShow = 5000;  % 显示5000个采样点（5个符号）

subplot(1, 2, 1);
plot(1:numSamplesToShow, results{1}.freqHoppedSig(1:numSamplesToShow), 'LineWidth', 0.8);
grid on;
title('无多普勒：发送信号时域波形', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');
set(gca, 'FontSize', 10);

subplot(1, 2, 2);
plot(1:numSamplesToShow, results{3}.freqHoppedSig(1:numSamplesToShow), 'LineWidth', 0.8, 'Color', 'r');
grid on;
title('50 Hz多普勒：发送信号时域波形', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');
set(gca, 'FontSize', 10);

sgtitle('发送信号对比', 'FontSize', 13, 'FontWeight', 'bold');

%% =====================================================================
% 详细分析
%% =====================================================================

fprintf('\n🔍 详细分析\n\n');

fprintf('比特错误统计:\n');
for i = 1:length(doppler_values)
    doppler = doppler_values(i);
    num_errors = sum(results{i}.decodedBits ~= results{i}.txBits);
    fprintf('  多普勒 %3d Hz: %3d 个比特错误 (共 %d)\n', doppler, num_errors, g);
end

fprintf('\n符号错误统计:\n');
for i = 1:length(doppler_values)
    doppler = doppler_values(i);
    num_errors = sum(results{i}.sentencedSymbol ~= results{i}.symbolMap);
    fprintf('  多普勒 %3d Hz: %3d 个符号错误 (共 %d)\n', doppler, num_errors, numel(results{i}.symbolMap));
end

%% =====================================================================
% 多普勒补偿效果演示
%% =====================================================================

fprintf('\n\n💡 多普勒补偿效果演示\n\n');

% 使用改进版本进行多普勒补偿
fprintf('使用改进版本 (enableDoppler=true) 对抗 50 Hz 多普勒频移...\n');

if ~exist('fhss_4fsk_simulate_improved', 'file')
    fprintf('⚠️  改进版本不可用，跳过此步骤\n');
else
    tic;
    result_compensated = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, false, true, false, false);
    elapsed = toc;
    
    fprintf('✓ 使用多普勒补偿后\n');
    fprintf('  BER: %.4f (无补偿: %.4f，改进: %.2fx)\n', ...
        result_compensated.ber, ber_values(3), ber_values(3)/max(result_compensated.ber, 1e-8));
    fprintf('  SER: %.4f (无补偿: %.4f，改进: %.2fx)\n', ...
        result_compensated.ser, ser_values(3), ser_values(3)/max(result_compensated.ser, 1e-8));
    fprintf('  耗时: %.2f秒\n\n', elapsed);
end

%% =====================================================================
% 使用建议
%% =====================================================================

fprintf('\n📝 使用建议\n\n');

fprintf('基础版本（无多普勒）:\n');
fprintf('  >> result = fhss_4fsk_simulate(200, 100000, 15, 5000, 42, true);\n\n');

fprintf('多普勒频移版本（模拟移动源/接收器）:\n');
fprintf('  >> result = fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, 42, true, 50);\n\n');

fprintf('多普勒补偿版本（抗多普勒）:\n');
fprintf('  >> result = fhss_4fsk_simulate_improved(200, 100000, 15, 5000, 42, true, true, false, false);\n\n');

fprintf('综合版本（多普勒补偿+LMS均衡+Viterbi):\n');
fprintf('  >> result = fhss_4fsk_simulate_improved(200, 100000, 15, 5000, 42, true, true, true, true);\n\n');

fprintf('═══════════════════════════════════════════════════════════════\n\n');
