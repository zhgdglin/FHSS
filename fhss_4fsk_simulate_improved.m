function result = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, doPlots, enableDoppler, enableLMS, enableViterbi)
%FHSS_4FSK_SIMULATE_IMPROVED  FH-4FSK 链路仿真与性能评估 (改进版)
%   result = fhss_4fsk_simulate_improved(g, fs, snrDb, delay, seed, doPlots, enableDoppler, enableLMS, enableViterbi)
%
% 参数说明：
% - g: 原始比特数
% - fs: 采样率（Hz）
% - snrDb: 信噪比（dB）
% - delay: 自延迟多径的样本数（整数）
% - seed: 随机种子
% - doPlots: 是否绘制诊断图（default: true）
% - enableDoppler: 启用多普勒补偿 (default: true)
% - enableLMS: 启用自适应LMS均衡 (default: true)
% - enableViterbi: 启用Viterbi解码 (default: true)
%
% 改进内容：
% 1) 多普勒补偿：在判决前扫描可能的多普勒频移范围
% 2) LMS自适应均衡：替换固定FIR低通滤波
% 3) Viterbi解码：卷积编码+软判决维特比解码

if nargin < 7
    enableDoppler = true;
end
if nargin < 8
    enableLMS = true;
end
if nargin < 9
    enableViterbi = true;
end
if nargin < 5
    seed = 1001203;
end
if nargin < 6
    doPlots = true;
end

samplesPerSymbol = 1000;
freqs = [9000 10000 11000 12000];

rng(seed, 'twister');

%% =====================================================================
% 第1步：比特生成与卷积编码
%% =====================================================================

txBits = round(rand(1, g));

% 卷积编码 (约束长度为3)
if enableViterbi
    % 生成多项式: [7 5] 对应 [1+D^2, 1+D+D^2]
    encoder = comm.ConvolutionalEncoder('TrellisStructure', poly2trellis(3, [7, 5]));
    codedBitsColumn = step(encoder, txBits(:));
    codedBits = codedBitsColumn.';  % 转换为行向量
    numCodedBits = length(codedBits);
else
    codedBits = txBits;
    numCodedBits = g;
end

% 补齐到偶数以便2比特映射
txBitsPadded = codedBits;
if mod(numCodedBits, 2) == 1
    txBitsPadded = [txBitsPadded 0];
end

%% =====================================================================
% 第2步：原始信号时域表示（用于绘图）
%% =====================================================================

signal1 = zeros(1, g * samplesPerSymbol);
for k = 1:g
    if txBits(k) == 0
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = -ones(1, samplesPerSymbol);
    else
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = ones(1, samplesPerSymbol);
    end
end

%% =====================================================================
% 第3步：4-FSK符号映射
%% =====================================================================

ns = numel(txBitsPadded) / 2;
symbolMap = zeros(1, ns);

tSymbol = (0:samplesPerSymbol-1) / fs;
signalFSK = zeros(1, ns * samplesPerSymbol);
for ksym = 1:ns
    b1 = txBitsPadded(2*ksym-1);
    b2 = txBitsPadded(2*ksym);
    idx = b1 * 2 + b2;
    symbolMap(ksym) = idx + 1;
    signalFSK((ksym-1)*samplesPerSymbol + (1:samplesPerSymbol)) = sin(2*pi*freqs(idx+1)*tSymbol);
end

%% =====================================================================
% 第4步：跳频序列生成
%% =====================================================================

t1 = (0:100*pi/999:100*pi);
t2 = (0:110*pi/999:110*pi);
t3 = (0:120*pi/999:120*pi);
t4 = (0:130*pi/999:130*pi);
t5 = (0:140*pi/999:140*pi);
t6 = (0:150*pi/999:150*pi);
t7 = (0:160*pi/999:160*pi);
t8 = (0:170*pi/999:170*pi);
c1 = cos(t1);
c2 = cos(t2);
c3 = cos(t3);
c4 = cos(t4);
c5 = cos(t5);
c6 = cos(t6);
c7 = cos(t7);
c8 = cos(t8);

adr1 = Mcreate(seed);
adr1 = [adr1, adr1(1), adr1(2)];
fhSeq = zeros(1, ns);
for k = 1:ns
    fhSeq(k) = adr1(3*k-2)*2^2 + adr1(3*k-1)*2 + adr1(3*k);
end

carrierTable = {c8, c1, c2, c3, c4, c5, c6, c7};
spreadSignal = zeros(1, ns * samplesPerSymbol);
fhp = zeros(1, ns);
for k = 1:ns
    c = fhSeq(k);
    spreadSignal((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = carrierTable{c+1};
    fhp(k) = 500*c + 5000;
end

%% =====================================================================
% 第5步：跳频扩频调制 + 可选的自延迟多径
%% =====================================================================

freqHoppedSig = signalFSK .* spreadSignal;

if delay > 0
    s = [zeros(1, delay) freqHoppedSig(1:max(0, ns*samplesPerSymbol-delay))];
    s = s(1:ns*samplesPerSymbol);
    freqHoppedSig = freqHoppedSig + s;
end

%% =====================================================================
% 第6步：AWGN信道
%% =====================================================================

noisySignal = awgn(freqHoppedSig, snrDb, 1/2);

%% =====================================================================
% 第7步：接收端解扩
%% =====================================================================

receiveSignal = noisySignal .* spreadSignal;

%% =====================================================================
% 第8步：自适应LMS均衡或简单低通滤波
%% =====================================================================

if enableLMS
    % LMS自适应均衡
    muLMS = 0.001;  % LMS步长
    filterLen = 32;  % 均衡滤波器长度
    w = ones(filterLen, 1) / filterLen;  % 初始权重
    signalOut = zeros(1, length(receiveSignal));
    
    % 已知序列辅助均衡（使用已知的展频信号作为参考）
    for n = filterLen:length(receiveSignal)
        x_vec = receiveSignal(n:-1:n-filterLen+1).';  % 输入向量
        y_est = w' * x_vec;  % 均衡输出
        d_ref = spreadSignal(n);  % 参考信号为原始展频序列
        
        % LMS更新
        e = d_ref - y_est;
        w = w + muLMS * e * x_vec;
        
        signalOut(n) = y_est;
    end
    signalOut(1:filterLen-1) = signalOut(filterLen);  % 填充起始部分
else
    % 原始方法：低通滤波
    cofBand = fir1(64, 1000/fs);
    signalOut = filter(cofBand, 1, receiveSignal);
    signalOut = [signalOut(33:end), zeros(1, 32)];
end

%% =====================================================================
% 第9步：多普勒补偿 + 相关器判决
%% =====================================================================

sentencedSymbol = zeros(1, ns);
softDecisions = zeros(ns, 4);  % 软判决值（用于Viterbi）
decisionMetricTrace = zeros(ns, 4);

if enableDoppler
    % 多普勒补偿范围设定
    dopplerRange = -50:10:50;  % Hz，可根据应用调整
else
    dopplerRange = 0;
end

for n = 1:ns
    idx1 = (n-1)*samplesPerSymbol + 1;
    idx2 = n * samplesPerSymbol;
    seg = signalOut(idx1:idx2);
    
    matchedEnergy = zeros(1, 4);
    maxEnergyOverDoppler = zeros(1, 4);
    bestDoppler = zeros(1, 4);
    
    % 对每个候选频点
    for ii = 1:4
        fc = freqs(ii);
        maxEnergy = 0;
        bestDop = 0;
        
        % 在多普勒范围内扫描
        for dop = dopplerRange
            fcDoppler = fc + dop;
            refCos = cos(2*pi*fcDoppler*tSymbol);
            refSin = sin(2*pi*fcDoppler*tSymbol);
            
            projCos = sum(seg .* refCos);
            projSin = sum(seg .* refSin);
            energy = projCos^2 + projSin^2;
            
            if energy > maxEnergy
                maxEnergy = energy;
                bestDop = dop;
            end
        end
        
        maxEnergyOverDoppler(ii) = maxEnergy;
        bestDoppler(ii) = bestDop;
    end
    
    % 选择能量最大的频点
    [~, imax] = max(maxEnergyOverDoppler);
    sentencedSymbol(n) = imax;
    
    % 保存软判决值（对数似然比）用于Viterbi
    softDecisions(n, :) = maxEnergyOverDoppler;
    decisionMetricTrace(n, :) = maxEnergyOverDoppler;
end

%% =====================================================================
% 第10步：Viterbi解码（可选）
%% =====================================================================

if enableViterbi
    % 生成软判决比特
    softBits = zeros(1, numCodedBits);
    for n = 1:ns
        b1 = floor((sentencedSymbol(n) - 1) / 2);
        b2 = mod(sentencedSymbol(n) - 1, 2);
        
        % 基于能量差计算软判决值
        energy_this = softDecisions(n, sentencedSymbol(n));
        energy_other = max(softDecisions(n, [1:sentencedSymbol(n)-1, sentencedSymbol(n)+1:4]));
        llr = energy_this - energy_other;  % log-likelihood ratio
        
        pos1 = 2*n - 1;
        pos2 = 2*n;
        if pos1 <= numCodedBits
            softBits(pos1) = llr * (2 * b1 - 1);  % 转换为±1格式
        end
        if pos2 <= numCodedBits
            softBits(pos2) = llr * (2 * b2 - 1);
        end
    end
    
    % Viterbi解码
    decoder = comm.ViterbiDecoder('TrellisStructure', poly2trellis(3, [7, 5]), ...
                                  'InputFormat', 'Soft', ...
                                  'SoftInputWordLength', 3);
    decodedBits_temp = step(decoder, softBits(:));
    decodedBits = decodedBits_temp(1:g).';  % 取原始比特长度
else
    % 直接从符号映射得到比特
    decodedBits = zeros(1, g);
    for i = 1:ns
        idx = sentencedSymbol(i) - 1;
        b1 = floor(idx / 2);
        b2 = mod(idx, 2);
        pos1 = 2*i - 1;
        pos2 = 2*i;
        if pos1 <= g
            decodedBits(pos1) = b1;
        end
        if pos2 <= g
            decodedBits(pos2) = b2;
        end
    end
end

%% =====================================================================
% 第11步：性能统计
%% =====================================================================

bitErrors = sum(decodedBits ~= txBits);
symErrors = sum(sentencedSymbol ~= symbolMap);

result = struct();
result.g = g;
result.fs = fs;
result.snrDb = snrDb;
result.delay = delay;
result.enableDoppler = enableDoppler;
result.enableLMS = enableLMS;
result.enableViterbi = enableViterbi;
result.txBits = txBits;
result.codedBits = codedBits;
result.signal1 = signal1;
result.SignalFSK = signalFSK;
result.spreadSignal = spreadSignal;
result.freqHoppedSig = freqHoppedSig;
result.noisySignal = noisySignal;
result.receiveSignal = receiveSignal;
result.signalOut = signalOut;
result.decodedBits = decodedBits;
result.ber = bitErrors / g;
result.ser = symErrors / ns;
result.symbolMap = symbolMap;
result.sentencedSymbol = sentencedSymbol;
result.softDecisions = softDecisions;
result.residualEnergyTrace = decisionMetricTrace;
result.fhp = fhp;

%% =====================================================================
% 第12步：绘图
%% =====================================================================

if doPlots
    figure(1);
    plot(signal1, 'b', 'LineWidth', 1);
    grid on;
    axis([-100 1000*g -1.5 1.5]);
    title('原始信源比特');
    
    figure(2);
    plot(signalFSK);
    axis([-100 1000*ns -3 3]);
    title('4-FSK信号 (9/10/11/12 kHz)');
    
    figure(3);
    plot(fhp, 's', 'MarkerFaceColor', 'b', 'MarkerSize', 12);
    grid on;
    title('跳频序列');
    
    figure(4);
    plot(1:ns*samplesPerSymbol, freqHoppedSig);
    axis([-100 ns*samplesPerSymbol -3 3]);
    title('跳频扩频后的信号');
    
    figure(7);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, noisySignal);
    title('加噪声后的信号');
    subplot(2,1,2);
    Plot_f(noisySignal, fs);
    title('加噪声后的频谱');
    
    figure(8);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, receiveSignal);
    title('解扩后的信号');
    subplot(2,1,2);
    Plot_f(receiveSignal, fs);
    title('解扩后的频谱');
    
    figure(9);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, signalOut);
    if enableLMS
        title('LMS均衡后的信号');
    else
        title('低通滤波后的信号');
    end
    subplot(2,1,2);
    Plot_f(signalOut, fs);
    title('均衡后的频谱');
    
    figure(12);
    plot(1:ns, decisionMetricTrace, 'LineWidth', 1.2);
    grid on;
    xlabel('符号序号');
    ylabel('相关能量');
    title('4个候选频点的相关能量');
    legend('9 kHz','10 kHz','11 kHz','12 kHz');
    
    figure(13);
    subplot(2,1,1)
    plot(signal1);
    axis([-100 1000*g -1.5 1.5]);
    title('原始信源');
    subplot(2,1,2)
    sentencedSignalWave = zeros(1, g * samplesPerSymbol);
    for k = 1:g
        if decodedBits(k) == 0
            sentencedSignalWave((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = -ones(1, samplesPerSymbol);
        else
            sentencedSignalWave((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = ones(1, samplesPerSymbol);
        end
    end
    plot(sentencedSignalWave);
    axis([-100 1000*g -1.5 1.5]);
    title('解码还原的信号');
    
    % 性能摘要
    figure(14);
    text(0.1, 0.9, sprintf('===== 性能摘要 ====='), 'FontSize', 12, 'FontWeight', 'bold');
    text(0.1, 0.8, sprintf('原始比特数: %d', g), 'FontSize', 10);
    text(0.1, 0.7, sprintf('编码后比特数: %d', numCodedBits), 'FontSize', 10);
    text(0.1, 0.6, sprintf('SNR: %.1f dB', snrDb), 'FontSize', 10);
    text(0.1, 0.5, sprintf('BER: %.4f', result.ber), 'FontSize', 10, 'Color', 'r');
    text(0.1, 0.4, sprintf('SER: %.4f', result.ser), 'FontSize', 10, 'Color', 'r');
    text(0.1, 0.3, sprintf('多普勒补偿: %s', mat2str(enableDoppler)), 'FontSize', 10);
    text(0.1, 0.2, sprintf('LMS均衡: %s', mat2str(enableLMS)), 'FontSize', 10);
    text(0.1, 0.1, sprintf('Viterbi解码: %s', mat2str(enableViterbi)), 'FontSize', 10);
    axis off;
end

end
