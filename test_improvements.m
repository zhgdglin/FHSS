%% FHSS_4FSK 改进版本对比测试
% 对比原始版本与改进版本（多普勒补偿、LMS均衡、Viterbi解码）的性能

clear; close all; clc;

%% 参数设置
g = 200;              % 原始比特数
fs = 100000;          % 采样率 (Hz)
snrDb_range = [0, 5, 10, 15, 20];  % SNR范围
delay = 5000;         % 自延迟多径样本数
seed = 1001203;
numTrials = 1;        % 每个SNR值下的试验次数（可增大获得平均性能）

%% 初始化结果存储
ber_baseline = zeros(1, length(snrDb_range));
ber_doppler = zeros(1, length(snrDb_range));
ber_lms = zeros(1, length(snrDb_range));
ber_combined = zeros(1, length(snrDb_range));

ser_baseline = zeros(1, length(snrDb_range));
ser_doppler = zeros(1, length(snrDb_range));
ser_lms = zeros(1, length(snrDb_range));
ser_combined = zeros(1, length(snrDb_range));

%% 性能评估循环
fprintf('\n========== FHSS_4FSK 改进版本对比测试 ==========\n\n');
fprintf('原始比特数: %d, 自延迟多径: %d 样本\n', g, delay);
fprintf('每个SNR值进行 %d 次试验\n\n', numTrials);

for snrIdx = 1:length(snrDb_range)
    snrDb = snrDb_range(snrIdx);
    fprintf('处理 SNR = %d dB ... ', snrDb);
    
    ber_b = 0;
    ber_d = 0;
    ber_l = 0;
    ber_c = 0;
    
    ser_b = 0;
    ser_d = 0;
    ser_l = 0;
    ser_c = 0;
    
    for trial = 1:numTrials
        trialSeed = seed + trial;
        
        % 版本1：基线版本（无改进）
        result_baseline = fhss_4fsk_simulate(g, fs, snrDb, delay, trialSeed, false);
        ber_b = ber_b + result_baseline.ber;
        ser_b = ser_b + result_baseline.ser;
        
        % 版本2：仅多普勒补偿
        result_doppler = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, trialSeed, false, true, false, false);
        ber_d = ber_d + result_doppler.ber;
        ser_d = ser_d + result_doppler.ser;
        
        % 版本3：仅LMS均衡
        result_lms = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, trialSeed, false, false, true, false);
        ber_l = ber_l + result_lms.ber;
        ser_l = ser_l + result_lms.ser;
        
        % 版本4：综合改进（多普勒+LMS+Viterbi）
        result_combined = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, trialSeed, false, true, true, true);
        ber_c = ber_c + result_combined.ber;
        ser_c = ser_c + result_combined.ser;
    end
    
    % 求平均
    ber_baseline(snrIdx) = ber_b / numTrials;
    ser_baseline(snrIdx) = ser_b / numTrials;
    
    ber_doppler(snrIdx) = ber_d / numTrials;
    ser_doppler(snrIdx) = ser_d / numTrials;
    
    ber_lms(snrIdx) = ber_l / numTrials;
    ser_lms(snrIdx) = ser_l / numTrials;
    
    ber_combined(snrIdx) = ber_c / numTrials;
    ser_combined(snrIdx) = ser_c / numTrials;
    
    fprintf('完成\n');
    fprintf('  基线 BER: %.4f | 多普勒 BER: %.4f | LMS BER: %.4f | 综合 BER: %.4f\n', ...
        ber_baseline(snrIdx), ber_doppler(snrIdx), ber_lms(snrIdx), ber_combined(snrIdx));
end

%% 绘制性能对比曲线
figure('Position', [100, 100, 1200, 500]);

% BER对比
subplot(1, 2, 1);
semilogy(snrDb_range, ber_baseline, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '基线版本');
hold on;
semilogy(snrDb_range, ber_doppler, 's-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '仅多普勒补偿');
semilogy(snrDb_range, ber_lms, '^-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '仅LMS均衡');
semilogy(snrDb_range, ber_combined, 'd-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '综合改进(D+L+V)');
grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('比特错误率 (BER)', 'FontSize', 11);
title('BER性能对比', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
set(gca, 'FontSize', 10);

% SER对比
subplot(1, 2, 2);
semilogy(snrDb_range, ser_baseline, 'o-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '基线版本');
hold on;
semilogy(snrDb_range, ser_doppler, 's-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '仅多普勒补偿');
semilogy(snrDb_range, ser_lms, '^-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '仅LMS均衡');
semilogy(snrDb_range, ser_combined, 'd-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', '综合改进(D+L+V)');
grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('符号错误率 (SER)', 'FontSize', 11);
title('SER性能对比', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
set(gca, 'FontSize', 10);

%% 生成性能改进表格
fprintf('\n========== 性能改进总结 ==========\n\n');
fprintf('SNR(dB) | 基线BER  | 多普勒BER | LMS BER  | 综合BER  | 多普勒增益 | LMS增益  | 综合增益\n');
fprintf('--------|----------|----------|----------|----------|-----------|----------|----------\n');

for i = 1:length(snrDb_range)
    doppler_gain = ber_baseline(i) / max(ber_doppler(i), 1e-6);
    lms_gain = ber_baseline(i) / max(ber_lms(i), 1e-6);
    combined_gain = ber_baseline(i) / max(ber_combined(i), 1e-6);
    
    fprintf('  %2d   | %.4f  | %.4f   | %.4f   | %.4f   |   %.2fx    |  %.2fx   |  %.2fx\n', ...
        snrDb_range(i), ber_baseline(i), ber_doppler(i), ber_lms(i), ber_combined(i), ...
        doppler_gain, lms_gain, combined_gain);
end

fprintf('\n');
fprintf('注释：\n');
fprintf('- 多普勒补偿: 在 ±50 Hz 范围内扫描多普勒偏移\n');
fprintf('- LMS均衡: 32阶自适应滤波器，步长 μ=0.001\n');
fprintf('- Viterbi解码: 约束长度3的卷积码，生成多项式 [7,5]\n');
fprintf('- 综合改进: 同时启用上述三项\n\n');

%% 详细测试：高SNR下的解调质量对比（可视化）
fprintf('生成详细对比图表...\n');

snrDb_detail = 15;  % 选择一个中等SNR进行详细分析
seed_detail = 2001;

result_detail_baseline = fhss_4fsk_simulate(g, fs, snrDb_detail, delay, seed_detail, false);
result_detail_improved = fhss_4fsk_simulate_improved(g, fs, snrDb_detail, delay, seed_detail, false, true, true, true);

figure('Position', [100, 620, 1200, 400]);

% 频谱对比
subplot(1, 3, 1);
Plot_f(result_detail_baseline.receiveSignal, fs);
title(sprintf('基线版本 (SNR=%d dB)\n解扩信号频谱', snrDb_detail), 'FontSize', 11);
grid on;

subplot(1, 3, 2);
Plot_f(result_detail_baseline.signalOut, fs);
title(sprintf('基线版本 (SNR=%d dB)\n低通滤波后频谱', snrDb_detail), 'FontSize', 11);
grid on;

subplot(1, 3, 3);
Plot_f(result_detail_improved.signalOut, fs);
title(sprintf('改进版本 (SNR=%d dB)\nLMS均衡后频谱', snrDb_detail), 'FontSize', 11);
grid on;

fprintf('✓ 测试完成！\n\n');
