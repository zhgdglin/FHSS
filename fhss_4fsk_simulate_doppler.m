function result = fhss_4fsk_simulate_doppler(g, fs, snrDb, delay, seed, doPlots, dopplerHz)
%FHSS_4FSK_SIMULATE_DOPPLER  FH-4FSK 链路仿真与性能评估 (支持多普勒频移)
%   result = fhss_4fsk_simulate_doppler(g, fs, snrDb, delay, seed, doPlots, dopplerHz)
%
% 参数说明：
% - g: 比特数（binary bits），按每 2 个比特构成一个 4-FSK 符号
% - fs: 采样率（Hz）
% - snrDb: 信噪比（dB）
% - delay: 自延迟多径的样本数（整数，可为0）
% - seed: 随机种子
% - doPlots: 是否绘制诊断图（true/false）
% - dopplerHz: 多普勒频移（Hz），模拟移动源/接收器效应 (default: 0)
%
% 功能特性：
% 【新增】多普勒频移模拟：
%   - 正值：表示源/接收器靠近（频率升高）
%   - 负值：表示源/接收器远离（频率下降）
%   - 示例：dopplerHz = 50 表示50 Hz的频率升高
%
% 应用场景：
%   • 船舶移动通信：速度v (m/s) → doppler ≈ v * f_carrier / c
%   • 水声通信：声速c ≈ 1500 m/s
%   • 例子：速度5 m/s，载波14 kHz → doppler ≈ 5*14000/1500 ≈ 47 Hz

if nargin < 5
    seed = 1001203;
end
if nargin < 6
    doPlots = true;
end
if nargin < 7
    dopplerHz = 0;  % 默认无多普勒频移
end

samplesPerSymbol = 1000;
freqs = [9000 10000 11000 12000];

rng(seed, 'twister');

%% =====================================================================
% 第1步：生成随机比特
%% =====================================================================

txBits = round(rand(1, g));
txBitsPadded = txBits;
if mod(g, 2) == 1
    txBitsPadded = [txBitsPadded 0];
end

% 用于时域可视化
signal1 = zeros(1, g * samplesPerSymbol);
for k = 1:g
    if txBits(k) == 0
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = -ones(1, samplesPerSymbol);
    else
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = ones(1, samplesPerSymbol);
    end
end

%% =====================================================================
% 第2步：4-FSK 符号映射
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
% 第3步：跳频序列生成
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
% 第4步：跳频扩频调制
%% =====================================================================

freqHoppedSig = signalFSK .* spreadSignal;

% 可选的自延迟多径
if delay > 0
    s = [zeros(1, delay) freqHoppedSig(1:max(0, ns*samplesPerSymbol-delay))];
    s = s(1:ns*samplesPerSymbol);
    freqHoppedSig = freqHoppedSig + s;
end

%% =====================================================================
% 第5步：【新增】多普勒频移应用
%% =====================================================================

if abs(dopplerHz) > 1e-6
    % 构建时间轴
    t_total = (0:length(freqHoppedSig)-1) / fs;
    
    % 应用多普勒频移：乘以时变相位项
    % y(n) = x(n) * exp(j * 2π * dopplerHz * t(n))
    doppler_phase = exp(1j * 2 * pi * dopplerHz * t_total);
    freqHoppedSig_doppler = freqHoppedSig .* doppler_phase;
    freqHoppedSig = real(freqHoppedSig_doppler);  % 取实部
    
    % 标记已应用多普勒
    doppler_applied = true;
else
    doppler_applied = false;
end

%% =====================================================================
% 第6步：AWGN 信道
%% =====================================================================

noisySignal = awgn(freqHoppedSig, snrDb, 1/2);

%% =====================================================================
% 第7步：接收端解扩
%% =====================================================================

receiveSignal = noisySignal .* spreadSignal;

%% =====================================================================
% 第8步：低通滤波
%% =====================================================================

cofBand = fir1(64, 1000/fs);
signalOut = filter(cofBand, 1, receiveSignal);
signalOut = [signalOut(33:end), zeros(1, 32)];

%% =====================================================================
% 第9步：相关器判决
%% =====================================================================

sentencedSymbol = zeros(1, ns);
uout = zeros(1, ns * samplesPerSymbol);
decisionMetricTrace = zeros(ns, 4);
tSeg = (0:samplesPerSymbol-1) / fs;

for n = 1:ns
    idx1 = (n-1)*samplesPerSymbol + 1;
    idx2 = n * samplesPerSymbol;
    seg = signalOut(idx1:idx2);
    decisionMetric = zeros(1, 4);
    candidateOutput = zeros(4, samplesPerSymbol);

    for ii = 1:4
        fc = freqs(ii);
        refCos = cos(2*pi*fc*tSeg);
        refSin = sin(2*pi*fc*tSeg);
        projCos = sum(seg .* refCos);
        projSin = sum(seg .* refSin);
        matchedEnergy = projCos^2 + projSin^2;

        candidateOutput(ii,:) = (projCos / samplesPerSymbol) * refCos + (projSin / samplesPerSymbol) * refSin;
        decisionMetric(ii) = -matchedEnergy;
    end

    decisionMetricTrace(n,:) = decisionMetric;
    [~, imax] = min(decisionMetric);
    sentencedSymbol(n) = imax;
    uout(idx1:idx2) = candidateOutput(imax,:);
end

%% =====================================================================
% 第10步：比特解映射与错误统计
%% =====================================================================

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

bitErrors = sum(decodedBits ~= txBits);
symErrors = sum(sentencedSymbol ~= symbolMap);

%% =====================================================================
% 第11步：返回结果
%% =====================================================================

result = struct();
result.g = g;
result.fs = fs;
result.snrDb = snrDb;
result.delay = delay;
result.dopplerHz = dopplerHz;  % 【新增】保存多普勒参数
result.doppler_applied = doppler_applied;  % 【新增】标记是否应用了多普勒
result.txBits = txBits;
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
result.uout = uout;
result.notchOutput = uout;
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
    title('4-FSK 信号 (9/10/11/12 kHz)');

    figure(3);
    plot(fhp, 's', 'MarkerFaceColor', 'b', 'MarkerSize', 12);
    grid on;
    title('跳频序列');

    figure(4);
    plot(1:ns*samplesPerSymbol, freqHoppedSig);
    axis([-100 ns*samplesPerSymbol -3 3]);
    if abs(dopplerHz) > 1e-6
        title(sprintf('跳频扩频信号 (多普勒: %.0f Hz)', dopplerHz));
    else
        title('跳频扩频信号');
    end

    figure(7);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, noisySignal);
    if abs(dopplerHz) > 1e-6
        title(sprintf('加噪声信号 (多普勒: %.0f Hz)', dopplerHz));
    else
        title('加噪声信号');
    end
    subplot(2,1,2);
    Plot_f(noisySignal, fs);
    title('加噪声信号的频谱');

    figure(8);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, receiveSignal);
    title('解扩信号');
    subplot(2,1,2);
    Plot_f(receiveSignal, fs);
    title('解扩信号的频谱');

    figure(9);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, signalOut);
    title('低通滤波后的信号');
    subplot(2,1,2);
    Plot_f(signalOut, fs);
    title('低通滤波后的频谱');

    figure(12);
    plot(1:ns, decisionMetricTrace, 'LineWidth', 1.2);
    grid on;
    xlabel('符号序号');
    ylabel('相关能量');
    if abs(dopplerHz) > 1e-6
        title(sprintf('4个候选频点的相关能量 (多普勒: %.0f Hz)', dopplerHz));
    else
        title('4个候选频点的相关能量');
    end
    legend('9 kHz','10 kHz','11 kHz','12 kHz');

    figure(13);
    Plot_f(uout, fs);
    title('解调后信号的频谱');

    figure(10);
    subplot(2,1,1)
    plot(signal1);
    axis([-100 1000*g -1.5 1.5]);
    title('原始信源');
    subplot(2,1,2)
    Plot_f(uout, fs);
    title('y(k) 的频谱');

    figure(11);
    subplot(2,1,1)
    plot(signal1);
    axis([-100 1000*g -1.5 1.5]);
    title('信源序列');
    subplot(2,1,2)
    sentencedSignalWave = zeros(1, g * samplesPerSymbol);
    for k = 1:g
        if result.decodedBits(k) == 0
            sentencedSignalWave((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = -ones(1, samplesPerSymbol);
        else
            sentencedSignalWave((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = ones(1, samplesPerSymbol);
        end
    end
    plot(sentencedSignalWave);
    axis([-100 1000*g -1.5 1.5]);
    title('还原后的信号序列');
    
    % 性能摘要
    if abs(dopplerHz) > 1e-6
        fprintf('\n【多普勒频移仿真】\n');
        fprintf('多普勒频移: %.0f Hz\n', dopplerHz);
        fprintf('BER: %.4f\n', result.ber);
        fprintf('SER: %.4f\n', result.ser);
        fprintf('\n');
    end
end

end
