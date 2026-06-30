%% FHSS_4FSK 多普勒影响的SNR扫描
% 在多个SNR值下评估多普勒频移的性能影响

clear; close all; clc;

fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════╗\n');
fprintf('║   多普勒频移性能影响 - SNR扫描评估                         ║\n');
fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

%% 参数设置
g = 200;                              % 比特数
fs = 100000;                          % 采样率
snrDb_range = [5, 10, 15, 20];        % SNR范围
doppler_range = [0, 25, 50, 100];     % 多普勒范围 (Hz)
delay = 5000;                         % 自延迟多径
seed = 42;                            % 随机种子

fprintf('📊 实验参数：\n');
fprintf('   • 比特数: %d\n', g);
fprintf('   • 采样率: %d Hz\n', fs);
fprintf('   • SNR范围: %d - %d dB\n', min(snrDb_range), max(snrDb_range));
fprintf('   • 多普勒范围: 0 - 100 Hz\n');
fprintf('   • 自延迟多径: %d 样本\n\n', delay);

%% =====================================================================
% 性能评估
%% =====================================================================

fprintf('🔬 运行仿真...\n\n');

ber_matrix = zeros(length(snrDb_range), length(doppler_range));
ser_matrix = zeros(length(snrDb_range), length(doppler_range));

for snr_idx = 1:length(snrDb_range)
    snrDb = snrDb_range(snr_idx);
    fprintf('SNR = %d dB: ', snrDb);
    
    for dop_idx = 1:length(doppler_range)
        doppler = doppler_range(dop_idx);
        
        result = fhss_4fsk_simulate_doppler(g, fs, snrDb, delay, seed, false, doppler);
        ber_matrix(snr_idx, dop_idx) = result.ber;
        ser_matrix(snr_idx, dop_idx) = result.ser;
        
        fprintf('.');
    end
    fprintf(' ✓\n');
end

fprintf('\n');

%% =====================================================================
% 生成热力图和性能曲线
%% =====================================================================

figure('Name', '多普勒频移性能影响分析', 'NumberTitle', 'off', 'Position', [50 50 1400 900]);

% BER热力图
subplot(2, 3, 1);
imagesc(doppler_range, snrDb_range, ber_matrix);
colorbar;
set(gca, 'YDir', 'normal');
xlabel('多普勒频移 (Hz)', 'FontSize', 11);
ylabel('SNR (dB)', 'FontSize', 11);
title('BER热力图', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 10);
colormap('hot');

% SER热力图
subplot(2, 3, 2);
imagesc(doppler_range, snrDb_range, ser_matrix);
colorbar;
set(gca, 'YDir', 'normal');
xlabel('多普勒频移 (Hz)', 'FontSize', 11);
ylabel('SNR (dB)', 'FontSize', 11);
title('SER热力图', 'FontSize', 12, 'FontWeight', 'bold');
set(gca, 'FontSize', 10);
colormap('hot');

% 不同SNR下的BER曲线
subplot(2, 3, 3);
for snr_idx = 1:length(snrDb_range)
    plot(doppler_range, ber_matrix(snr_idx, :), 'o-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
end
hold off;
grid on;
xlabel('多普勒频移 (Hz)', 'FontSize', 11);
ylabel('比特错误率 (BER)', 'FontSize', 11);
title('BER vs 多普勒频移（各SNR)', 'FontSize', 12, 'FontWeight', 'bold');
legend(sprintf('SNR=%d dB', snrDb_range(1)), sprintf('SNR=%d dB', snrDb_range(2)), ...
       sprintf('SNR=%d dB', snrDb_range(3)), sprintf('SNR=%d dB', snrDb_range(4)), ...
       'FontSize', 10);
set(gca, 'FontSize', 10);

% 不同多普勒下的BER曲线
subplot(2, 3, 4);
for dop_idx = 1:length(doppler_range)
    plot(snrDb_range, ber_matrix(:, dop_idx), 's-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
end
hold off;
grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('比特错误率 (BER)', 'FontSize', 11);
title('BER vs SNR（各多普勒)', 'FontSize', 12, 'FontWeight', 'bold');
legend(sprintf('Doppler=%d Hz', doppler_range(1)), sprintf('Doppler=%d Hz', doppler_range(2)), ...
       sprintf('Doppler=%d Hz', doppler_range(3)), sprintf('Doppler=%d Hz', doppler_range(4)), ...
       'FontSize', 10);
set(gca, 'FontSize', 10);

% 不同多普勒下的SER曲线
subplot(2, 3, 5);
for dop_idx = 1:length(doppler_range)
    plot(snrDb_range, ser_matrix(:, dop_idx), '^-', 'LineWidth', 2, 'MarkerSize', 8);
    hold on;
end
hold off;
grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('符号错误率 (SER)', 'FontSize', 11);
title('SER vs SNR（各多普勒)', 'FontSize', 12, 'FontWeight', 'bold');
legend(sprintf('Doppler=%d Hz', doppler_range(1)), sprintf('Doppler=%d Hz', doppler_range(2)), ...
       sprintf('Doppler=%d Hz', doppler_range(3)), sprintf('Doppler=%d Hz', doppler_range(4)), ...
       'FontSize', 10);
set(gca, 'FontSize', 10);

% 性能劣化（相对于无多普勒）
subplot(2, 3, 6);
degradation = (ber_matrix(:, 2:end) - repmat(ber_matrix(:, 1), 1, length(doppler_range)-1)) ...
              ./ repmat(ber_matrix(:, 1) + 1e-6, 1, length(doppler_range)-1) * 100;
bar(snrDb_range, degradation);
grid on;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('性能劣化 (%)', 'FontSize', 11);
title('多普勒引起的BER性能劣化', 'FontSize', 12, 'FontWeight', 'bold');
legend(sprintf('Doppler=%d Hz', doppler_range(2)), sprintf('Doppler=%d Hz', doppler_range(3)), ...
       sprintf('Doppler=%d Hz', doppler_range(4)), 'FontSize', 10);
set(gca, 'FontSize', 10);

sgtitle('多普勒频移对FHSS_4FSK性能的影响分析', 'FontSize', 14, 'FontWeight', 'bold');

%% =====================================================================
% 生成性能表格
%% =====================================================================

fprintf('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('📊 性能汇总表 (BER)\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

fprintf('  SNR (dB) |');
for dop = doppler_range
    fprintf(' %6d Hz |', dop);
end
fprintf('\n');

fprintf('  ---------|');
for i = 1:length(doppler_range)
    fprintf('---------|');
end
fprintf('\n');

for snr_idx = 1:length(snrDb_range)
    fprintf('    %2d   |', snrDb_range(snr_idx));
    for dop_idx = 1:length(doppler_range)
        fprintf(' %.4f |', ber_matrix(snr_idx, dop_idx));
    end
    fprintf('\n');
end

fprintf('\n');

fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('📊 性能汇总表 (SER)\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n');

fprintf('  SNR (dB) |');
for dop = doppler_range
    fprintf(' %6d Hz |', dop);
end
fprintf('\n');

fprintf('  ---------|');
for i = 1:length(doppler_range)
    fprintf('---------|');
end
fprintf('\n');

for snr_idx = 1:length(snrDb_range)
    fprintf('    %2d   |', snrDb_range(snr_idx));
    for dop_idx = 1:length(doppler_range)
        fprintf(' %.4f |', ser_matrix(snr_idx, dop_idx));
    end
    fprintf('\n');
end

fprintf('\n');

%% =====================================================================
% 关键指标
%% =====================================================================

fprintf('\n🔍 关键发现\n\n');

% 找最坏情况（BER最高）
[max_ber, max_idx] = max(ber_matrix(:));
[snr_max, dop_max] = ind2sub(size(ber_matrix), max_idx);
fprintf('最坏情况: SNR=%d dB, Doppler=%d Hz, BER=%.4f\n', ...
    snrDb_range(snr_max), doppler_range(dop_max), max_ber);

% 找最佳情况（BER最低）
[min_ber, min_idx] = min(ber_matrix(:));
[snr_min, dop_min] = ind2sub(size(ber_matrix), min_idx);
fprintf('最佳情况: SNR=%d dB, Doppler=%d Hz, BER=%.4f\n\n', ...
    snrDb_range(snr_min), doppler_range(dop_min), min_ber);

% 多普勒的平均影响（在所有SNR值上平均）
doppler_impact = mean(ber_matrix, 1);
fprintf('平均性能（在所有SNR值上）:\n');
for dop_idx = 1:length(doppler_range)
    fprintf('  Doppler=%3d Hz: 平均BER=%.4f\n', doppler_range(dop_idx), doppler_impact(dop_idx));
end

fprintf('\n');

%% =====================================================================
% 使用建议
%% =====================================================================

fprintf('\n💡 使用建议和应用场景\n\n');

fprintf('1. 仿真多普勒频移效应：\n');
fprintf('   >> fhss_4fsk_simulate_doppler(200, 100000, 15, 5000, seed, true, 50);\n\n');

fprintf('2. 多SNR性能评估：\n');
fprintf('   >> doppler_snr_sweep  % 运行此脚本\n\n');

fprintf('3. 多普勒补偿：\n');
fprintf('   >> fhss_4fsk_simulate_improved(..., enableDoppler=true, ...);\n\n');

fprintf('4. 实际应用参考值（水声通信，c≈1500 m/s，f≈14 kHz）:\n');
fprintf('   • 静止: v=0 m/s → Doppler=0 Hz\n');
fprintf('   • 低速移动: v≈2.7 m/s → Doppler≈25 Hz\n');
fprintf('   • 中速移动: v≈5.4 m/s → Doppler≈50 Hz\n');
fprintf('   • 高速移动: v≈10.7 m/s → Doppler≈100 Hz\n\n');

fprintf('═════════════════════════════════════════════════════════════════\n\n');
