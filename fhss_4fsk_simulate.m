function result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, doPlots)
%FHSS_4FSK_SIMULATE  FH-4FSK 链路仿真与性能评估
%   result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, doPlots)
%
% 参数说明：
% - g: 比特数（binary bits），按每 2 个比特构成一个 4-FSK 符号
% - fs: 采样率（Hz）
% - snrDb: 信噪比（dB），传入给 `awgn` 用于加噪声
% - delay: 自延迟多径的样本数（整数），用于模拟自干扰（可为 0）
% - seed: 随机种子（影响跳频序列与随机比特生成）
% - doPlots: 是否绘制诊断图（true/false）
%
% 算法概要：
% 1) 生成随机比特并按 2 比特映射到 4-FSK 的 4 个频点
% 2) 使用预定义的周期载波序列对每个符号做简单跳频扩频（点乘）
% 3) 通过 AWGN 信道并在接收端乘回同一扩频载波以解扩
% 4) 对低通滤波后的每个符号，针对 4 个候选频点使用一个
%    简单的基于两参考（cos/sin）的 LMS 更新来近似“反向 Notch”滤波器，
%    用输出能量作为判决量选择候选频点
% 5) 返回解调结果和若干用于调试的中间变量

if nargin < 5
    seed = 1001203;
end
if nargin < 6
    doPlots = true;
end

samplesPerSymbol = 1000;
freqs = [9000 10000 11000 12000];
% 每个符号的采样点数与 4-FSK 的四个基带频率（Hz）

rng(seed, 'twister');

txBits = round(rand(1, g));
txBitsPadded = txBits;
if mod(g, 2) == 1
    txBitsPadded = [txBitsPadded 0];
end

% `txBits` 为随机生成的比特序列，长度为 g。
% 若 g 为奇数，最后填充一个 0，以便每 2 比特组成一个符号。

signal1 = zeros(1, g * samplesPerSymbol);
for k = 1:g
    if txBits(k) == 0
        % `signal1` 为用 ±1 表示的原始比特脉冲序列（每比特重复 samplesPerSymbol 次）
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = -ones(1, samplesPerSymbol);
    else
        signal1((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = ones(1, samplesPerSymbol);
    end
end

% `signal1` 可用于时域可视化：每个比特被扩展为 samplesPerSymbol 个采样点，值为 ±1。

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
% `signalFSK` 为按符号映射后的 4-FSK 基带信号（每个符号对应一个正弦载波）

% 说明：`idx` 在 0..3 之间，表示四个候选频点；`symbolMap` 存储 1..4 的索引

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

% 这里构造了 8 个短周期载波（只是示例周期序列），用于对每个符号做“跳频”扩频。
% 载波长度较短，会在每个符号内周期重复匹配 samplesPerSymbol（在赋值时发生截断/循环）。

adr1 = Mcreate(seed);
adr1 = [adr1, adr1(1), adr1(2)];
fhSeq = zeros(1, ns);
for k = 1:ns
    fhSeq(k) = adr1(3*k-2)*2^2 + adr1(3*k-1)*2 + adr1(3*k);
end

% `Mcreate(seed)` 产生一个伪随机序列（实现位于 `Mcreate.m`），这里将其按 3 位一组
% 转换为 0..7 的索引，用于在 `carrierTable` 中选择对应的短载波。
% `fhSeq` 的值就是每个符号的跳频编号（0..7）。

carrierTable = {c8, c1, c2, c3, c4, c5, c6, c7};
spreadSignal = zeros(1, ns * samplesPerSymbol);
fhp = zeros(1, ns);
for k = 1:ns
    c = fhSeq(k);
    spreadSignal((k-1)*samplesPerSymbol + (1:samplesPerSymbol)) = carrierTable{c+1};
    fhp(k) = 500*c + 5000;
end

% 将每个符号对应的短载波写入 `spreadSignal`：该序列与 `signalFSK` 点乘实现扩频。
% `fhp` 只是为了可视化，给出每个跳频序号对应的近似频点（仅用于绘图）。

freqHoppedSig = signalFSK .* spreadSignal;

if delay > 0
    s = [zeros(1, delay) freqHoppedSig(1:max(0, ns*samplesPerSymbol-delay))];
    s = s(1:ns*samplesPerSymbol);
    freqHoppedSig = freqHoppedSig + s;
end

% 可选的自延迟多径（自干扰）模拟：将原始信号延迟若干采样并叠加。

noisySignal = awgn(freqHoppedSig, snrDb, 1/2);
receiveSignal = noisySignal .* spreadSignal;
cofBand = fir1(64, 1000/fs);
signalOut = filter(cofBand, 1, receiveSignal);
signalOut = [signalOut(33:end), zeros(1, 32)];

% 信道：使用 `awgn` 加 Gaussian 噪声。接收端先乘以同一 `spreadSignal` 完成解扩，
% 然后用低通 FIR 滤波器去掉高频分量并平滑解扩结果得到 `signalOut`。
% 这里补偿了 64 阶线性相位 FIR 的群延迟（32 个采样点），避免符号边界整体右移。

sentencedSymbol = zeros(1, ns);
uout = zeros(1, ns * samplesPerSymbol);
decisionMetricTrace = zeros(ns, 4);
tSeg = (0:samplesPerSymbol-1) / fs;
mu = 0.02;
A = 1;

for n = 1:ns
    idx1 = (n-1)*samplesPerSymbol + 1;
    idx2 = n * samplesPerSymbol;
    seg = signalOut(idx1:idx2);
    decisionMetric = zeros(1, 4);
    candidateOutput = zeros(4, samplesPerSymbol);
    % 这里改用残差能量作为判决量：正确候选频点应当让 seg 和重构输出的误差更小。

    % 对于每个符号，针对 4 个候选频点做相关器判决：
    % - 构造参考正弦/余弦 `refCos`、`refSin`
    % - 计算 seg 与参考基函数的相关能量
    % - 相关能量最大的候选频点，就是最可能发送的 4-FSK 频点

    for ii = 1:4
        fc = freqs(ii);
        refCos = cos(2*pi*fc*tSeg);
        refSin = sin(2*pi*fc*tSeg);
        projCos = sum(seg .* refCos);
        projSin = sum(seg .* refSin);
        matchedEnergy = projCos^2 + projSin^2;

        % 用投影后的重构波形作为输出，方便后续绘图观察。
        candidateOutput(ii,:) = (projCos / samplesPerSymbol) * refCos + (projSin / samplesPerSymbol) * refSin;
        decisionMetric(ii) = -matchedEnergy;
    end
        % 这里保存的是负相关能量，后面用 `min` 选取最小者，相当于选最大匹配度。

    decisionMetricTrace(n,:) = decisionMetric;
    [~, imax] = min(decisionMetric);
    sentencedSymbol(n) = imax;
    uout(idx1:idx2) = candidateOutput(imax,:);
end

% 注：这里用相关能量做判决，`min(decisionMetric)` 等价于选择相关能量最大的候选频点。

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

% 将每个符号的判决结果 `sentencedSymbol` 解映射回比特序列 `decodedBits`（长度为 g）。

bitErrors = sum(decodedBits ~= txBits);
symErrors = sum(sentencedSymbol ~= symbolMap);

result = struct();
result.g = g;
result.fs = fs;
result.snrDb = snrDb;
result.delay = delay;
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

if doPlots
    figure(1);
    plot(signal1, 'b', 'LineWidth', 1);
    grid on;
    axis([-100 1000*g -1.5 1.5]);
    title('信号源');

    figure(2);
    plot(signalFSK);
    axis([-100 1000*ns -3 3]);
    title('4-FSK Signal (9/10/11/12 kHz)');

    figure(3);
    plot(fhp, 's', 'MarkerFaceColor', 'b', 'MarkerSize', 12);
    grid on;
    title('跳频图案');

    figure(4);
    plot(1:ns*samplesPerSymbol, freqHoppedSig);
    axis([-100 ns*samplesPerSymbol -2 2]);
    title('跳频扩频后的时域信号');

    figure(7);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, noisySignal);
    title('扩频调制后加高斯白噪声的信号');
    subplot(2,1,2);
    Plot_f(noisySignal, fs);
    title('扩频调制后加高斯白噪声的信号频谱');

    figure(8);
    subplot(2,1,1);
    plot(1:ns*samplesPerSymbol, receiveSignal);
    title('混频后的信号');
    subplot(2,1,2);
    Plot_f(receiveSignal, fs);
    title('混频后的频谱');

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
    ylabel('输出能量');
    title('4个候选频点的自适应 Notch 输出能量');
    legend('9 kHz','10 kHz','11 kHz','12 kHz');

    figure(13);
    Plot_f(uout, fs);
    title('nocth滤波器输出的频谱图');

    figure(10);
    subplot(2,1,1)
    plot(signal1);
    axis([-100 1000*g -1.5 1.5]);
    title('原始信源');
    subplot(2,1,2)
    Plot_f(uout, fs);
    title('y(k) 的频谱');

    figure(11),subplot(2,1,1)
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
end
end