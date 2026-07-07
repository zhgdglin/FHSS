% FHSS+4FSK 统一演示入口
clc;
clear;
close all;

% 基础参数
g = 200;
fs = 625000;
snrDb = 40;
delay = 0;
seed = 1001203;

% 统一可调开关（都在一个 opts 里）
opts = struct();
opts.dopplerHz = 0;              % 多普勒频移，可改为 0 / 25 / 50 / 100
opts.enableDopplerComp = false;    % 多普勒补偿扫描
opts.enableLMS = true;            % LMS 均衡
opts.enableViterbi = false;       % Viterbi 解码（需通信工具箱）
opts.symbolDurationMs = 20;       % 每个 MFSK 符号持续 20ms
opts.guardIntervalMs = 30;        % 保护间隔 30ms

% 可选调参
opts.dopplerCompRange = -50:10:50;
opts.lmsMu = 0.001;
opts.lmsFilterLen = 32;

result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, true, opts);

fprintf('BER=%.4f\n', result.ber);
fprintf('SER=%.4f\n', result.ser);

