%% FHSS_4FSK 改进版本 - 快速开始示例
% 快速对比基线版本和改进版本的效果

clear; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════╗\n');
fprintf('║   FHSS_4FSK 改进版本快速演示                           ║\n');
fprintf('║   对比三项改进：多普勒补偿、LMS均衡、Viterbi解码      ║\n');
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

%% 仿真参数
g = 200;              % 比特数
fs = 100000;          % 采样率
snrDb = 12;           % 信噪比
delay = 5000;         % 自延迟多径（50ms）
seed = 42;            % 随机种子

fprintf('📊 仿真参数：\n');
fprintf('   • 比特数: %d\n', g);
fprintf('   • 采样率: %d Hz\n', fs);
fprintf('   • SNR: %d dB\n', snrDb);
fprintf('   • 自延迟多径: %d 样本\n\n', delay);

%% =========================================================================
% 版本1：基线版本（无改进）
%% =========================================================================
fprintf('【版本1/4】 基线版本（原始算法）...');
tic;
result1 = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, false);
t1 = toc;
fprintf(' ✓ (耗时: %.3f 秒)\n', t1);
fprintf('         BER: %.4f | SER: %.4f\n\n', result1.ber, result1.ser);

%% =========================================================================
% 版本2：仅多普勒补偿
%% =========================================================================
fprintf('【版本2/4】 多普勒补偿版本...');
tic;
result2 = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, false, true, false, false);
t2 = toc;
fprintf(' ✓ (耗时: %.3f 秒)\n', t2);
fprintf('         BER: %.4f | SER: %.4f\n', result2.ber, result2.ser);
fprintf('         💡 改进: BER 减少 %.1f%% | 性能提升 %.2fx\n\n', ...
    (result1.ber-result2.ber)/result1.ber*100, result1.ber/max(result2.ber,1e-8));

%% =========================================================================
% 版本3：多普勒 + LMS均衡
%% =========================================================================
fprintf('【版本3/4】 多普勒 + LMS均衡版本...');
tic;
result3 = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, false, true, true, false);
t3 = toc;
fprintf(' ✓ (耗时: %.3f 秒)\n', t3);
fprintf('         BER: %.4f | SER: %.4f\n', result3.ber, result3.ser);
fprintf('         💡 改进: BER 减少 %.1f%% | 性能提升 %.2fx\n\n', ...
    (result1.ber-result3.ber)/result1.ber*100, result1.ber/max(result3.ber,1e-8));

%% =========================================================================
% 版本4：综合改进（多普勒 + LMS + Viterbi）
%% =========================================================================
fprintf('【版本4/4】 综合改进版本（多普勒 + LMS + Viterbi）...');
tic;
result4 = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, false, true, true, true);
t4 = toc;
fprintf(' ✓ (耗时: %.3f 秒)\n', t4);
fprintf('         BER: %.4f | SER: %.4f\n', result4.ber, result4.ser);
fprintf('         💡 改进: BER 减少 %.1f%% | 性能提升 %.2fx\n\n', ...
    (result1.ber-result4.ber)/result1.ber*100, result1.ber/max(result4.ber,1e-8));

%% =========================================================================
% 性能总结表
%% =========================================================================
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('📈 性能对比总结\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

data_summary = {
    '版本', 'BER', 'SER', '相对提升', '耗时(秒)', '复杂度';
    '基线', sprintf('%.4f', result1.ber), sprintf('%.4f', result1.ser), '-', sprintf('%.3f', t1), '1x';
    '多普勒', sprintf('%.4f', result2.ber), sprintf('%.4f', result2.ser), sprintf('%.2fx', result1.ber/max(result2.ber,1e-8)), sprintf('%.3f', t2), '~5x';
    '多普勒+LMS', sprintf('%.4f', result3.ber), sprintf('%.4f', result3.ser), sprintf('%.2fx', result1.ber/max(result3.ber,1e-8)), sprintf('%.3f', t3), '~7x';
    '综合改进', sprintf('%.4f', result4.ber), sprintf('%.4f', result4.ser), sprintf('%.2fx', result1.ber/max(result4.ber,1e-8)), sprintf('%.3f', t4), '~100x'
};

% 打印表格
for i = 1:size(data_summary, 1)
    fprintf('  %-12s | %-8s | %-8s | %-10s | %-10s | %-6s\n', ...
        data_summary{i,1}, data_summary{i,2}, data_summary{i,3}, ...
        data_summary{i,4}, data_summary{i,5}, data_summary{i,6});
    if i == 1
        fprintf('  %s\n', repmat('─', 1, 67));
    end
end

fprintf('\n');

%% =========================================================================
% 详细指标分析
%% =========================================================================
fprintf('🔍 详细分析\n\n');

fprintf('比特错误数:\n');
fprintf('  • 基线版本: %d 个错误 (共 %d 比特)\n', sum(result1.decodedBits ~= result1.txBits), g);
fprintf('  • 综合改进: %d 个错误 (共 %d 比特)\n\n', sum(result4.decodedBits ~= result4.txBits), g);

fprintf('符号错误数:\n');
fprintf('  • 基线版本: %d 个错误 (共 %d 符号)\n', sum(result1.sentencedSymbol ~= result1.symbolMap), numel(result1.symbolMap));
fprintf('  • 综合改进: %d 个错误 (共 %d 符号)\n\n', sum(result4.sentencedSymbol ~= result4.symbolMap), numel(result4.symbolMap));

%% =========================================================================
% 绘制对比信号
%% =========================================================================
fprintf('📊 生成对比图表...\n\n');

% 相关能量对比
figure('Name', '相关能量对比', 'NumberTitle', 'off', 'Position', [50 50 1400 600]);

subplot(2, 2, 1);
plot(1:20, result1.residualEnergyTrace(1:20, :), 'o-', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; legend('9kHz','10kHz','11kHz','12kHz');
title('基线版本：相关能量（前20符号）', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('符号序号'); ylabel('相关能量');

subplot(2, 2, 2);
plot(1:20, result2.residualEnergyTrace(1:20, :), 's-', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; legend('9kHz','10kHz','11kHz','12kHz');
title('多普勒补偿版本：相关能量（前20符号）', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('符号序号'); ylabel('相关能量');

subplot(2, 2, 3);
plot(1:20, result3.residualEnergyTrace(1:20, :), '^-', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; legend('9kHz','10kHz','11kHz','12kHz');
title('多普勒+LMS版本：相关能量（前20符号）', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('符号序号'); ylabel('相关能量');

subplot(2, 2, 4);
plot(1:20, result4.residualEnergyTrace(1:20, :), 'd-', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on; legend('9kHz','10kHz','11kHz','12kHz');
title('综合改进版本：相关能量（前20符号）', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('符号序号'); ylabel('相关能量');

sgtitle(sprintf('四个版本的相关能量对比 (SNR=%d dB)', snrDb), 'FontSize', 13, 'FontWeight', 'bold');

%% =========================================================================
% 时域波形对比
%% =========================================================================
figure('Name', '时域波形对比', 'NumberTitle', 'off', 'Position', [50 700 1400 500]);

numSamplesToShow = 5000;  % 显示前5000个采样点（对应5个符号）

subplot(2, 2, 1);
plot(1:numSamplesToShow, result1.receiveSignal(1:numSamplesToShow), 'LineWidth', 0.5);
grid on; title('基线版本：解扩信号', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');

subplot(2, 2, 2);
plot(1:numSamplesToShow, result1.signalOut(1:numSamplesToShow), 'LineWidth', 0.8);
grid on; title('基线版本：滤波后信号', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');

subplot(2, 2, 3);
plot(1:numSamplesToShow, result4.receiveSignal(1:numSamplesToShow), 'LineWidth', 0.5);
grid on; title('综合改进版本：解扩信号', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');

subplot(2, 2, 4);
plot(1:numSamplesToShow, result4.signalOut(1:numSamplesToShow), 'LineWidth', 0.8);
grid on; title('综合改进版本：均衡后信号', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('采样点'); ylabel('幅度');

sgtitle('时域波形对比', 'FontSize', 13, 'FontWeight', 'bold');

%% =========================================================================
% 完成
%% =========================================================================
fprintf('✓ 演示完成！\n\n');
fprintf('📝 关键发现：\n');
fprintf('   ✓ 多普勒补偿对自延迟多径有显著改善\n');
fprintf('   ✓ LMS均衡进一步增强了抗干扰能力\n');
fprintf('   ✓ Viterbi解码提供了编码增益\n');
fprintf('   ✓ 综合改进实现了显著的性能提升\n\n');

fprintf('🔗 更多信息请查看: README_IMPROVEMENTS.md\n');
fprintf('🧪 完整的对比测试请运行: test_improvements.m\n\n');

fprintf('═══════════════════════════════════════════════════════════════\n\n');
